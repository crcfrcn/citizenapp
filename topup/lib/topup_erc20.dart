import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart'
    show encodeErc20Transfer, verifyErc20Transfer;
import 'package:citizen_topup/topup_models.dart';

/// 按原订单冻结合约、链号、零原生币金额和附有完整绑定的交易输入。
Map<String, Object> erc20Transaction(TopupPayment payment, String binding) => {
  'to': payment.asset,
  'value': '0x0',
  'chainId': '0x${payment.network.evmId.toRadixString(16)}',
  'data': encodeErc20Transfer(
    payment.recvAddress,
    BigInt.parse(payment.payAmount),
    suffix: _bindingBytes(binding),
  ),
};

/// 将 SDK 的单轮链上事实归入原订单，重试和发币由 App 调度。
Future<TopupProof> verifyErc20Payment(
  TopupPayment payment,
  String? payer,
  String txid,
  Future<Object?> Function(String, List<Object?>) rpc, {
  required String binding,
  int? now,
}) async {
  final receipt = await verifyErc20Transfer(
    rpc,
    chainId: payment.network.evmId,
    txid: txid,
    token: payment.asset,
    recipient: payment.recvAddress,
    amount: BigInt.parse(payment.payAmount),
    sender: payer,
    suffix: _bindingBytes(binding),
    minBlockAt: payment.createdAt ~/ 1000 * 1000,
    now: now,
  );
  return TopupProof.fromJson({
    'binding_hash': binding,
    'network': payment.network.wire,
    'payment_txid': txid,
    'payer_address': receipt.sender,
    'asset': payment.asset,
    'recv_address': payment.recvAddress,
    'pay_amount': payment.payAmount,
    'block_hash': receipt.blockHash,
    'block_number': receipt.blockNumber,
    'block_at': receipt.blockAt,
    'transfer_index': receipt.logIndex,
    'checked_at': receipt.checkedAt,
    'finalized': true,
    'succeeded': true,
  });
}

/// 订单绑定为恰好 32 字节的小写十六进制正文。
Uint8List _bindingBytes(String binding) {
  if (binding.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(binding)) {
    throw const FormatException('充值绑定无效');
  }
  return Uint8List.fromList(
    List<int>.generate(
      32,
      (i) => int.parse(binding.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
}
