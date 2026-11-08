import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_offchain/onchain_clearing_bank_chain.dart';
import 'package:citizen_offchain/clearing_bank_directory.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
  final TextEditingController _amountCtrl = TextEditingController();
  bool _submitting = false;
  BigInt? _feeFen;
  late ClearingBankBinding? _binding = widget.bank;

  @override
  void dispose() {
    _amountCtrl.dispose();
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
              _binding == null
                  ? '请先绑定清算行后再充值。'
                  : '转入 ${_binding!.title}',
              style: const TextStyle(color: Colors.grey),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            TextField(
              controller: _amountCtrl,
              enabled: !_submitting,
              onChanged: (_) => setState(() => _feeFen = null),
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      width: AppLayout.scaled(context, 20),
                      height: AppLayout.scaled(context, 20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认充值'),
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

  Future<void> _submit() async {
    if (_submitting) return;
    final amountFen = parseFen(_amountCtrl.text);
    if (amountFen == null || amountFen <= BigInt.zero) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的充值金额(元)')));
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
        setState(() => _binding = latest);
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
        SnackBar(content: Text('充值已提交,tx=${_short(result.txHash)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('充值失败:$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _short(String h) {
    if (h.length <= 14) return h;
    return '${h.substring(0, 8)}…${h.substring(h.length - 4)}';
  }
}
