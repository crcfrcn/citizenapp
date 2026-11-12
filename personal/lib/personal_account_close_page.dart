import 'package:citizen_widgets/chain_balance_scope.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_scanner/address_scan_button.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_widgets/chain_progress_banner.dart';

import 'package:citizen_personal/personal_manage_service.dart';
import 'package:citizen_personal/personal_proposal_history_service.dart';

import 'package:citizen_system/theme/app_layout.dart';

/// 关闭个人多签账户提案页面。
///
/// 指定受益人地址后发起个人多签账户关闭提案。
class PersonalAccountClosePage extends StatefulWidget {
  const PersonalAccountClosePage({
    super.key,
    required this.institution,
    required this.adminWallets,
  });

  final InstitutionInfo institution;
  final List<CitizenWalletStateAccount> adminWallets;

  @override
  State<PersonalAccountClosePage> createState() =>
      _PersonalAccountClosePageState();
}

class _PersonalAccountClosePageState extends State<PersonalAccountClosePage> {
  final _beneficiaryController = TextEditingController();
  late final PersonalManageService _manageService;
  late final ProposalQueryService _proposalQuery;
  bool _dependenciesReady = false;

  bool _submitting = false;
  String? _addressError;
  CitizenChainSyncStatus? _chainProgress;
  String? _chainProgressError;

  late CitizenWalletStateAccount _selectedWallet;
  late String _accountSs58;

  @override
  void initState() {
    super.initState();
    _selectedWallet = widget.adminWallets.first;
    _accountSs58 = citizenSs58FromAccountId(widget.institution.accountId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _manageService = PersonalManageService(chain: sdk, transactions: sdk);
    _proposalQuery = ProposalQueryService(chain: sdk);
    _dependenciesReady = true;
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    super.dispose();
  }

  /// 页面进入读取 wallet 持久余额，交易前校验由既有余额守卫强制刷新。
  CitizenBalanceState<CitizenAccountBalance> get _balance => context
      .read<CitizenSdk>()
      .balances
      .accountState(widget.institution.accountId);
  BigInt? get _availableBalance => _balance.value?.freeFen;
  bool get _loadingBalance => _balance.value == null && !_balance.hasError;

  // ──── 校验 ────

  bool _validateAddress(String address) {
    if (address.isEmpty) {
      setState(() => _addressError = '请输入受益人地址');
      return false;
    }
    try {
      citizenAccountIdBytesFromSs58(address);
    } catch (_) {
      setState(() => _addressError = '地址格式无效');
      return false;
    }

    // 受益人不能是多签账户本身
    if (address == _accountSs58) {
      setState(() => _addressError = '受益人不能与个人多签账户相同');
      return false;
    }

    setState(() => _addressError = null);
    return true;
  }

  // ──── 提交 ────

  Future<void> _submit() async {
    final chain = context.read<CitizenSdk>();
    final blockedReason = _submitBlockedReason;
    if (blockedReason != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(blockedReason)));
      return;
    }

    if (_submitting) return;
    final beneficiary = _beneficiaryController.text.trim();
    if (!_validateAddress(beneficiary)) return;
    final wallet = _selectedWallet;
    setState(() => _submitting = true);

    try {
      await context.read<CitizenSdk>().getAccountBalance(
        widget.institution.accountId,
      );
      if (!mounted) return;
      final balanceFen = _availableBalance!;
      final fees = await chain.getFeeSnapshot(amountFen: balanceFen);
      if (!mounted ||
          wallet != _selectedWallet ||
          beneficiary != _beneficiaryController.text.trim()) {
        return;
      }
      final requiredFen = fees.feeFen + fees.existentialDepositFen;
      if (balanceFen < requiredFen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('账户余额不足（执行费和 ED 至少需要 ${formatFen(requiredFen)} 元）'),
          ),
        );
        return;
      }
      final publicKeyBytes = citizenAccountIdBytes(wallet.accountId);

      // 提前查链上 NextProposalId 作为本次关闭提案的预测 ID(req 5 历史保留)。
      final predictedProposalId = await _proposalQuery.fetchNextProposalId();

      final result = await _manageService.submitProposeClosePersonal(
        accountId: widget.institution.accountId,
        beneficiaryAddress: beneficiary,
        signerPublicKey: Uint8List.fromList(publicKeyBytes),
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      // 写入 Isar `action`,详情页提案列表才能显示。
      await PersonalProposalHistoryService(chain: chain).recordOrUpdate(
        accountId: widget.institution.accountId,
        proposalId: predictedProposalId,
        actionKind: PersonalProposalAction.close,
        status: PersonalProposalStatus.voting,
        // 发起关闭提案签名成功后，投票引擎已自动记录发起人的赞成票。
        yesCount: 1,
        noCount: 0,
        snapshot: {'beneficiary': beneficiary},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('提案已提交：${_truncateAddress(result.txHash)}'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _handleChainProgressChanged(CitizenChainSyncStatus? progress) {
    if (!mounted) return;
    setState(() {
      _chainProgress = progress;
    });
  }

  void _handleChainProgressErrorChanged(String? error) {
    if (!mounted) return;
    setState(() {
      _chainProgressError = error;
    });
  }

  bool get _canSubmit => !_submitting && _submitBlockedReason == null;

  /// 关闭个人多签会直接动到账户资金，链不同步时不允许继续发起。
  String? get _submitBlockedReason {
    final progress = _chainProgress;
    if (progress == null) {
      return _chainProgressError ?? '正在读取区块链状态，请稍后再试';
    }
    if (progress.peerCount == BigInt.zero) {
      return '轻节点尚未连接到区块链网络，暂不能发起关闭个人多签提案';
    }
    if (progress.isSyncing) {
      return '轻节点仍在验证或同步链状态，完成后才能发起关闭个人多签提案';
    }
    if (!progress.isUsable) {
      return _chainProgressError ?? '区块链状态尚未就绪，暂不能发起关闭个人多签提案';
    }
    return null;
  }

  // ──── UI ────

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: [widget.institution.accountId],
    builder: _buildBalanceView,
  );
  Widget _buildBalanceView(BuildContext context, CitizenBalances balances) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '关闭个人多签',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 个人多签账户（只读）
              _buildSectionTitle('个人多签账户'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              Container(
                padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: Text(
                  _accountSs58,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 13),
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 16)),
              // 当前余额
              _buildSectionTitle('个人多签余额'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              Container(
                padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: _loadingBalance
                    ? SizedBox(
                        height: AppLayout.scaled(context, 16),
                        width: AppLayout.scaled(context, 16),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _availableBalance != null
                            ? '${formatFen(_availableBalance!)} 元'
                            : '查询失败',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w600,
                          color: _availableBalance != null
                              ? AppTheme.primaryDark
                              : AppTheme.danger,
                        ),
                      ),
              ),
              SizedBox(height: AppLayout.scaled(context, 20)),
              _buildSectionTitle('阈值规则', note: '注销须全员同意'),
              SizedBox(height: AppLayout.scaled(context, 20)),
              // 受益人地址
              _buildSectionTitle('受益人地址'),
              SizedBox(height: AppLayout.scaled(context, 8)),
              TextField(
                controller: _beneficiaryController,
                decoration: InputDecoration(
                  hintText: '输入或扫码',
                  errorText: _addressError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(10),
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppLayout.scaled(context, 12),
                    vertical: AppLayout.scaled(context, 10),
                  ),
                  suffixIcon: AddressScanButton(
                    onAddressScanned: (accountAddress) => setState(
                      () => _beneficiaryController.text = accountAddress,
                    ),
                  ),
                ),
              ),
              if (widget.adminWallets.length > 1) ...[
                SizedBox(height: AppLayout.scaled(context, 20)),
                _buildSectionTitle('签名钱包'),
                SizedBox(height: AppLayout.scaled(context, 8)),
                DropdownButtonFormField<CitizenWalletStateAccount>(
                  initialValue: _selectedWallet,
                  items: widget.adminWallets.map((w) {
                    return DropdownMenuItem(
                      value: w,
                      child: Text(
                        '${w.name} (${_truncateAddress(w.ss58Address)})',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 13),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (w) {
                    if (w != null) setState(() => _selectedWallet = w);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppLayout.scaled(context, 12),
                      vertical: AppLayout.scaled(context, 10),
                    ),
                  ),
                ),
              ],
              SizedBox(height: AppLayout.scaled(context, 28)),
              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaled(context, 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(12),
                      ),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: AppLayout.scaled(context, 18),
                          height: AppLayout.scaled(context, 18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '发起关闭个人多签提案',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (_submitBlockedReason != null) ...[
                SizedBox(height: AppLayout.scaled(context, 10)),
                Text(
                  _submitBlockedReason!,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          ChainProgressBanner(
            busy: _submitting || _loadingBalance,
            onProgressChanged: _handleChainProgressChanged,
            onErrorChanged: _handleChainProgressErrorChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? note}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppLayout.scaledValue(14),
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryDark,
          ),
        ),
        if (note != null) ...[
          SizedBox(width: AppLayout.scaledValue(8)),
          Text(
            note,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(12),
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  // ──── 工具 ────

  String _truncateAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }
}
