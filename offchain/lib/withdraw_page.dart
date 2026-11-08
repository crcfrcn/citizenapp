import 'dart:async';

import 'package:citizen_offchain/clearing_bank_directory.dart';
import 'package:citizen_offchain/offchain_clearing_rpc.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_offchain/onchain_clearing_bank_chain.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
  final TextEditingController _amountCtrl = TextEditingController();
  bool _submitting = false;
  BigInt? _feeFen;
  late ClearingBankBinding? _binding = widget.bank;
  ClearingBalance? _balance;

  @override
  void initState() {
    super.initState();
    _setBank(widget.bank);
  }

  void _setBank(ClearingBankBinding? bank) {
    _balance?.removeListener(_changed);
    _binding = bank;
    final balance = bank == null
        ? null
        : ClearingBalances.instance.state(
            accountId: widget.accountId,
            wssUrl: bank.endpoint.wssUrl,
          );
    _balance = balance;
    balance?.addListener(_changed);
    if (balance != null) unawaited(balance.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _balance?.removeListener(_changed);
    _amountCtrl.dispose();
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
            if (_binding case final bank?) Text(bank.title),
            _buildBalanceLine(),
            SizedBox(height: AppLayout.scaled(context, 16)),
            TextField(
              controller: _amountCtrl,
              enabled: !_submitting,
              onChanged: (_) => setState(() => _feeFen = null),
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      width: AppLayout.scaled(context, 20),
                      height: AppLayout.scaled(context, 20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认提现'),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            Text(
              _feeFen == null
                  ? '提交前读取链上手续费'
                  : '预估链上手续费：${formatFen(_feeFen!)} 元',
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
    final balance = _balance;
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

  Future<void> _submit() async {
    if (_submitting) return;
    final amountFen = parseFen(_amountCtrl.text);
    if (amountFen == null || amountFen <= BigInt.zero) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的提现金额(元)')));
      return;
    }

    setState(() {
      _submitting = true;
      _feeFen = null;
    });
    try {
      final latest = await widget.directory.fetchUserBank(widget.accountId);
      if (!mounted) return;
      if (latest == null || _binding?.endpoint.sameTarget(latest.endpoint) != true) {
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
      setState(() => _feeFen = fees.feeFen);
      final balance = await _balance!.refresh();
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
        SnackBar(content: Text('提现已提交,tx=${_short(result.txHash)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提现失败:$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _short(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}
