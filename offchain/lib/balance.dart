// 零钱账户、存款和取款页面。

import 'dart:async';
import 'package:citizen_offchain/bank.dart' show ClearingBankBinding, ClearingBankDirectory;
import 'package:citizen_offchain/rpc.dart' show ClearingBalance, ClearingBalances;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_offchain/chain.dart' show OnchainClearingBankChain;

// 展示清算零钱包余额及充值、提现和清算行管理入口。

/// 零钱包详情页(链下清算行零钱包)。
///
/// 从账户详情「零钱包」按钮进入。承接原动作卡上的「充值到清算行」入口,并提供:
/// - 零钱包余额(节点端 `offchain_queryBalance`);
/// - 充值到清算行(链上账户 → 清算行零钱包,原 `DepositPage`);
/// - 提现到链上(清算行 → 链上账户,`WithdrawPage`)。
/// 一律按 `account_id` 键控,单钱包多账户下每账户独立零钱包。
class PettyWalletPage extends StatefulWidget {
  const PettyWalletPage({
    super.key,
    required this.accountId,
  });

  /// 该账户链账户主键(0x+64hex)。
  final String accountId;

  @override
  State<PettyWalletPage> createState() => _PettyWalletPageState();
}

class _PettyWalletPageState extends State<PettyWalletPage> {
  late final ClearingBankDirectory _directory;
  ClearingBankBinding? _walletBinding;
  ClearingBalance? _walletBalance;
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;
  int _bindingRead = 0;

  String get _balanceText {
    if (_loading) return '查询中';
    if (_failed) return '绑定待核对';
    if (_walletBinding == null) return '未绑定';
    final value = _walletBalance?.value;
    if (value != null) return '¥${formatFen(value)}';
    return _walletBalance?.hasError == true ? '节点不可达' : '查询中';
  }

  @override
  void initState() {
    super.initState();
    _directory = context.read<ClearingBankDirectory?>() ??
        ClearingBankDirectory(chain: context.read<CitizenSdk>());
    unawaited(_loadBalance());
  }

  void _walletChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PettyWalletPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _walletBinding = null;
      unawaited(_loadBalance());
    }
  }

  @override
  void dispose() {
    _walletBalance?.removeListener(_walletChanged);
    super.dispose();
  }

  // 下拉和返回都重新核对节点，再刷新当前清算行的余额。
  Future<void> _loadBalance({bool forceRefresh = false}) async {
    final accountId = widget.accountId;
    final read = ++_bindingRead;
    setState(() => _loading = true);
    ClearingBankBinding? bank;
    var failed = false;
    try {
      bank = await _directory.fetchUserBank(accountId);
    } catch (_) {
      failed = true;
    }
    if (!mounted || read != _bindingRead) return;
    _walletBalance?.removeListener(_walletChanged);
    final balance = bank == null
        ? null
        : ClearingBalances.instance.state(
            accountId: accountId,
            wssUrl: bank.endpoint.wssUrl,
          );
    balance?.addListener(_walletChanged);
    setState(() {
      _walletBinding = bank;
      _walletBalance = balance;
      _loading = false;
      _failed = failed;
    });
    await balance?.load(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('零钱包'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () => _loadBalance(forceRefresh: true),
        child: ListView(
          padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.all(AppLayout.scaled(context, 20)),
              decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _walletBinding?.title ?? '清算行',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 13),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 10)),
                  Text(
                    _balanceText,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 28),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 4)),
                  Text(
                    '零钱包余额（链下清算行）',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            _ActionTile(
              icon: Icons.arrow_circle_down_outlined,
              title: '充值到清算行',
              subtitle: '从链上账户转入清算行零钱包',
              onTap: () => _open(withdraw: false),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            _ActionTile(
              icon: Icons.arrow_circle_up_outlined,
              title: '提现到链上',
              subtitle: '从零钱包提现回链上账户',
              onTap: () => _open(withdraw: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open({required bool withdraw}) async {
    if (_opening) return;
    _opening = true;
    final accountId = widget.accountId;
    try {
      final reload = _loadBalance();
      final read = _bindingRead;
      await reload;
      if (!mounted || widget.accountId != accountId || read != _bindingRead) {
        return;
      }
      final bank = _walletBinding;
      if (bank == null || _loading) {
        final message = _failed || _loading
            ? '无法核对当前清算行，请重试'
            : '请先绑定清算行';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => withdraw
              ? WithdrawPage(
                  accountId: accountId,
                  directory: _directory,
                  bank: bank,
                )
              : DepositPage(
                  accountId: accountId,
                  directory: _directory,
                  bank: bank,
                ),
        ),
      );
      if (mounted) await _loadBalance(forceRefresh: submitted == true);
    } finally {
      _opening = false;
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
          decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
          child: Row(
            children: [
              Container(
                width: AppLayout.scaled(context, 44),
                height: AppLayout.scaled(context, 44),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppLayout.scaled(context, 22),
                  color: AppTheme.primaryDark,
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 16),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppLayout.scaled(context, 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppLayout.scaled(context, 18),
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 填写并确认向当前绑定清算行充值，提交前复核链状态及费用。

/// 扫码支付清算体系 Step 1 新增:**充值** L3 自持账户 → 清算行主账户。
///
///
/// - 充值前重新核对清算行，资金由链端按当前绑定划入清算账户。
/// - 链上费由 SDK 读取链上报价，由 runtime 唯一 `RuntimeFeeRouter` 指定签名者付款。
/// - 钱包账户由 CitizenSDK 严格分流：热账户本机签名，冷账户交给独立公民钱包扫码。
class DepositPage extends StatefulWidget {
  const DepositPage({
    super.key,
    required this.accountId,
    required this.directory,
    required this.bank,
  });

  /// L3 用户的规范 AccountId，用于读取绑定和签名。
  final String accountId;
  final ClearingBankDirectory directory;
  final ClearingBankBinding bank;

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  final TextEditingController _depositAmountCtrl = TextEditingController();
  bool _depositSubmitting = false;
  BigInt? _depositFeeFen;
  late ClearingBankBinding? _depositBinding = widget.bank;

  @override
  void dispose() {
    _depositAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充值到清算行')),
      body: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _depositBinding == null
                  ? '请先绑定清算行后再充值。'
                  : '转入 ${_depositBinding!.title}',
              style: const TextStyle(color: Colors.grey),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            TextField(
              controller: _depositAmountCtrl,
              enabled: !_depositSubmitting,
              onChanged: (_) => setState(() => _depositFeeFen = null),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '充值金额(元)',
                hintText: '例如 100.00',
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 24)),
            FilledButton(
              onPressed: _depositSubmitting ? null : _depositSubmit,
              child: _depositSubmitting
                  ? SizedBox(
                      width: AppLayout.scaled(context, 20),
                      height: AppLayout.scaled(context, 20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认充值'),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            Text(
              _depositFeeFen == null
                  ? '提交前读取链上手续费'
                  : '预估链上手续费：${formatFen(_depositFeeFen!)} 元',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 12),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _depositSubmit() async {
    if (_depositSubmitting) return;
    final amountFen = parseFen(_depositAmountCtrl.text);
    if (amountFen == null || amountFen <= BigInt.zero) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的充值金额(元)')));
      return;
    }

    setState(() {
      _depositSubmitting = true;
      _depositFeeFen = null;
    });
    try {
      final latest = await widget.directory.fetchUserBank(widget.accountId);
      if (!mounted) return;
      if (latest == null || _depositBinding?.endpoint.sameTarget(latest.endpoint) != true) {
        setState(() => _depositBinding = latest);
        final message = latest == null
            ? '请先绑定清算行'
            : '清算行已变化，请重新确认';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      final publicKeyBytes = citizenAccountIdBytes(widget.accountId);
      final sdk = context.read<CitizenSdk>();
      final fees = await sdk.getFeeSnapshot(amountFen: amountFen);
      if (!mounted) return;
      setState(() => _depositFeeFen = fees.feeFen);
      final chain = OnchainClearingBankChain(transactions: sdk);
      final result = await chain.deposit(
        signerPublicKey: publicKeyBytes,
        amountFen: amountFen,
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('充值已提交,tx=${_depositShort(result.txHash)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('充值失败:$e')));
    } finally {
      if (mounted) setState(() => _depositSubmitting = false);
    }
  }

  static String _depositShort(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}

// 填写并执行当前清算行存款提现，按SDK链报价展示费用。

/// 扫码支付清算体系 Step 1 新增:**提现** 清算行主账户 → L3 自持账户。
///
///
/// - 调链上 `withdraw(amount)`(call_index 32)。
/// - 链上费由 SDK 读取链上报价。
/// - 提现前重新核对当前绑定，并向该行节点刷新余额。
class WithdrawPage extends StatefulWidget {
  const WithdrawPage({
    super.key,
    required this.accountId,
    required this.directory,
    required this.bank,
  });

  /// L3 用户链账户主键(0x+64hex):由 CitizenSDK 分流签名并构造 signerPublicKey。
  final String accountId;
  final ClearingBankDirectory directory;
  final ClearingBankBinding bank;

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final TextEditingController _withdrawAmountCtrl = TextEditingController();
  bool _withdrawSubmitting = false;
  BigInt? _withdrawFeeFen;
  late ClearingBankBinding? _withdrawBinding = widget.bank;
  ClearingBalance? _withdrawBalance;

  @override
  void initState() {
    super.initState();
    _setBank(widget.bank);
  }

  void _setBank(ClearingBankBinding? bank) {
    _withdrawBalance?.removeListener(_withdrawChanged);
    _withdrawBinding = bank;
    final balance = bank == null
        ? null
        : ClearingBalances.instance.state(
            accountId: widget.accountId,
            wssUrl: bank.endpoint.wssUrl,
          );
    _withdrawBalance = balance;
    balance?.addListener(_withdrawChanged);
    if (balance != null) unawaited(balance.load());
  }

  void _withdrawChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _withdrawBalance?.removeListener(_withdrawChanged);
    _withdrawAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('从清算行提现')),
      body: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_withdrawBinding case final bank?) Text(bank.title),
            _buildBalanceLine(),
            SizedBox(height: AppLayout.scaled(context, 16)),
            TextField(
              controller: _withdrawAmountCtrl,
              enabled: !_withdrawSubmitting,
              onChanged: (_) => setState(() => _withdrawFeeFen = null),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '提现金额(元)',
                hintText: '例如 50.00',
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 24)),
            FilledButton(
              onPressed: _withdrawSubmitting ? null : _withdrawSubmit,
              child: _withdrawSubmitting
                  ? SizedBox(
                      width: AppLayout.scaled(context, 20),
                      height: AppLayout.scaled(context, 20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认提现'),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            Text(
              _withdrawFeeFen == null
                  ? '提交前读取链上手续费'
                  : '预估链上手续费：${formatFen(_withdrawFeeFen!)} 元',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 12),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceLine() {
    final balance = _withdrawBalance;
    if (balance == null) {
      return const Text(
        '当前清算行存款余额:未连接节点',
        style: TextStyle(color: Colors.grey),
      );
    }
    if (balance.hasError && balance.value == null) {
      return const Text('查询余额失败:节点不可达', style: TextStyle(color: Colors.red));
    }
    if (balance.value == null) {
      return const Text('正在查询清算行存款余额...', style: TextStyle(color: Colors.grey));
    }
    return Text(
      '当前清算行存款余额:¥${formatFen(balance.value!)}',
      style: TextStyle(fontSize: AppLayout.scaledValue(14)),
    );
  }

  Future<void> _withdrawSubmit() async {
    if (_withdrawSubmitting) return;
    final amountFen = parseFen(_withdrawAmountCtrl.text);
    if (amountFen == null || amountFen <= BigInt.zero) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的提现金额(元)')));
      return;
    }

    setState(() {
      _withdrawSubmitting = true;
      _withdrawFeeFen = null;
    });
    try {
      final latest = await widget.directory.fetchUserBank(widget.accountId);
      if (!mounted) return;
      if (latest == null || _withdrawBinding?.endpoint.sameTarget(latest.endpoint) != true) {
        setState(() => _setBank(latest));
        final message = latest == null
            ? '请先绑定清算行'
            : '清算行已变化，请重新确认';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      final publicKeyBytes = citizenAccountIdBytes(widget.accountId);
      final sdk = context.read<CitizenSdk>();
      final fees = await sdk.getFeeSnapshot(amountFen: amountFen);
      if (!mounted) return;
      setState(() => _withdrawFeeFen = fees.feeFen);
      final balance = await _withdrawBalance!.refresh();
      if (!mounted) return;
      if (amountFen > balance) throw StateError('零钱包余额不足');
      final chain = OnchainClearingBankChain(transactions: sdk);
      final result = await chain.withdraw(
        signerPublicKey: publicKeyBytes,
        amountFen: amountFen,
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提现已提交,tx=${_withdrawShort(result.txHash)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提现失败:$e')));
    } finally {
      if (mounted) setState(() => _withdrawSubmitting = false);
    }
  }

  static String _withdrawShort(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}
