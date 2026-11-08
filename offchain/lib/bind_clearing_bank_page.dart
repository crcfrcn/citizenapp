import 'package:citizen_system/security/account_security_exception.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_offchain/clearing_bank_directory.dart';
import 'package:citizen_offchain/onchain_clearing_bank_chain.dart';
import 'package:citizen_offchain/clearing_bank_prefs.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 绑定**清算行**(L2)确认页。
///
/// 设置页选择 finalized 目录中的机构，确认后以机构 CID 绑定或切换。
/// 绑定即开户，无预存和业务开户费，签名者支付链上交易费。
class BindClearingBankPage extends StatefulWidget {
  const BindClearingBankPage({
    super.key,
    required this.accountId,
    required this.bank,
    this.switchMode = false,
    this.chain,
    this.readFees,
  });

  /// L3 用户链账户主键(0x+64hex):按账户签名、构造 signerPublicKey、绑定缓存键。
  final String accountId;

  final ClearingBankCandidate bank;
  final bool switchMode;
  final OnchainClearingBankChain? chain;
  final Future<CitizenFeeSnapshot> Function()? readFees;

  @override
  State<BindClearingBankPage> createState() => _BindClearingBankPageState();
}

class _BindClearingBankPageState extends State<BindClearingBankPage> {
  bool _submitting = false;
  BigInt? _feeFen;

  @override
  Widget build(BuildContext context) {
    final b = widget.bank;
    final title = b.displayTitle.isEmpty ? '(未设置全称)' : b.displayTitle;
    return Scaffold(
      appBar: AppBar(title: Text(widget.switchMode ? '切换清算行' : '绑定清算行')),
      body: ListView(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        children: [
          ListTile(title: const Text('清算行'), subtitle: Text(title)),
          ListTile(
            title: const Text('所在地'),
            subtitle: Text(b.areaPath.isEmpty ? '-' : b.areaPath),
          ),
          ListTile(
            title: const Text('CID'),
            subtitle: SelectableText(b.cidNumber),
          ),
          ListTile(
            title: const Text('主账户'),
            subtitle: SelectableText('0x${b.mainAccountId}'),
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaledValue(12)),
              child: Text(
                '说明:\n'
                '· 绑定即开户,无需预存\n'
                '${_feeFen == null ? '· 提交前读取链上手续费' : '· 预估链上手续费：${formatFen(_feeFen!)} 元'}\n'
                '· 同一时间只能绑定一家清算行\n'
                '· 切换前需把当前清算行存款全部提现',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 13),
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 24)),
          FilledButton(
            onPressed: _submitting ? null : _confirmBind,
            child: _submitting
                ? SizedBox(
                    width: AppLayout.scaled(context, 20),
                    height: AppLayout.scaled(context, 20),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.switchMode ? '确认切换' : '确认绑定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBind() async {
    if (_submitting) return;
    final bank = widget.bank;

    setState(() {
      _submitting = true;
      _feeFen = null;
    });
    try {
      final publicKeyBytes = citizenAccountIdBytes(widget.accountId);

      final fees = await (widget.readFees?.call() ??
          context.read<CitizenSdk>().getFeeSnapshot());
      if (!mounted) return;
      setState(() => _feeFen = fees.feeFen);
      final chain = widget.chain ??
          OnchainClearingBankChain(transactions: context.read<CitizenSdk>());
      final result = widget.switchMode
          ? await chain.switchBank(
              signerPublicKey: publicKeyBytes,
              bankCid: bank.cidNumber,
              externalSigning: (pending) => showCitizenSdkQrResponse(
                context,
                request: pending.qrRequest,
                expiresAt: BigInt.from(
                  pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            )
          : await chain.bindClearingBank(
              signerPublicKey: publicKeyBytes,
              bankCid: bank.cidNumber,
              externalSigning: (pending) => showCitizenSdkQrResponse(
                context,
                request: pending.qrRequest,
                expiresAt: BigInt.from(
                  pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            );

      // 最终成功与本地展示缓存分别报告。返回后设置页仍重新读链。
      var cacheFailed = false;
      try {
        final endpoint = bank.endpoint;
        final now = DateTime.now().millisecondsSinceEpoch;
        await ClearingBankPrefs.saveSnapshot(
          widget.accountId,
          ClearingBankBindingSnapshot(
            cidNumber: bank.cidNumber,
            fullName: bank.fullName,
            shortName: bank.shortName ?? '',
            mainAccountId: bank.mainAccountId.substring(2),
            feeAccountId: bank.feeAccountId.substring(2),
            peerId: endpoint.peerId,
            rpcDomain: endpoint.rpcDomain,
            rpcPort: endpoint.rpcPort,
            boundAtMs: now,
            lastVerifiedAtMs: now,
          ),
        );
      } catch (_) {
        cacheFailed = true;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.switchMode ? '切换' : '绑定'}已确认，交易 ${_short(result.txHash)}'
            '${cacheFailed ? '（本地缓存未更新）' : ''}',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on AccountSecurityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('${widget.switchMode ? '切换' : '绑定'}失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _short(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}
