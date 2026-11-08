import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:math';
import 'dart:typed_data';

/// 扫码支付 Step 2c-i:**L3 扫码支付意图**(`NodePaymentIntent`)。
///
///
/// 与链端 PaymentIntent 字段顺序一致。清算行字段为变长机构CID，SCALE编码为
/// Compact(len)||UTF-8字节；payer/recipient为32字节账户，金额和手续费以分为单位。
/// nonce由节点读取，expires_at是链上块高；txId为本次付款独立随机32字节标识。
/// signingHash复用SDK公开签名原语。ACK须绑定本次txId；在可信ACK签名身份合同
/// 完成前，节点响应不能作为付款成功证明，也不能自动重发生成新付款。
class NodePaymentIntent {
  NodePaymentIntent({
    required this.txId,
    required this.payer,
    required this.payerBankCid,
    required this.recipient,
    required this.recipientBankCid,
    required this.amount,
    required this.fee,
    required this.nonce,
    required this.expiresAt,
  }) : assert(txId.length == 32, 'tx_id 必须 32 字节'),
       assert(payer.length == 32, 'payer 必须 32 字节'),
       assert(
         payerBankCid.isNotEmpty && payerBankCid.length <= 32,
         'payer_bank_cid 长度必须 1..32',
       ),
       assert(recipient.length == 32, 'recipient 必须 32 字节'),
       assert(
         recipientBankCid.isNotEmpty && recipientBankCid.length <= 32,
         'recipient_bank_cid 长度必须 1..32',
       ),
       assert(amount >= BigInt.zero, 'amount 不得为负'),
       assert(fee >= BigInt.zero, 'fee 不得为负'),
       assert(nonce >= BigInt.zero, 'nonce 不得为负'),
       assert(
         expiresAt >= 0 && expiresAt <= 0xFFFFFFFF,
         'expires_at 必须 u32 范围',
       );

  final Uint8List txId;
  final Uint8List payer;

  /// 付款方绑定清算行 CID(机构唯一永久主键);SCALE = Compact(len)||bytes。
  final Uint8List payerBankCid;
  final Uint8List recipient;

  /// 收款方绑定清算行 CID。
  final Uint8List recipientBankCid;
  final BigInt amount;
  final BigInt fee;
  final BigInt nonce;
  final int expiresAt;

  /// SCALE 编码(变长:bank 字段为 CID = Compact(len)||bytes,与 runtime
  /// `InstitutionCidNumber = BoundedVec<u8>` 逐字节等价)。
  Uint8List scaleEncode() {
    // 运行时强制 CID 长度不变量:assert 在 release 被裁剪,而 CID 来自扫码原始输入,
    // 编码进签名前必须显式校验,不能只靠调用方前置检查兜底。
    if (payerBankCid.isEmpty || payerBankCid.length > 32) {
      throw ArgumentError('payerBankCid 长度须 1..=32,实际 ${payerBankCid.length}');
    }
    if (recipientBankCid.isEmpty || recipientBankCid.length > 32) {
      throw ArgumentError(
        'recipientBankCid 长度须 1..=32,实际 ${recipientBankCid.length}',
      );
    }
    final out = BytesBuilder(copy: false);
    out.add(txId);
    out.add(payer);
    out.add(CitizenScale.compact(payerBankCid.length));
    out.add(payerBankCid);
    out.add(recipient);
    out.add(CitizenScale.compact(recipientBankCid.length));
    out.add(recipientBankCid);
    out.add(CitizenScale.unsigned(amount, 16));
    out.add(CitizenScale.unsigned(fee, 16));
    out.add(CitizenScale.unsigned(nonce, 8));
    out.add(CitizenScale.unsigned(BigInt.from(expiresAt), 4));
    return out.toBytes();
  }

  /// 待签名哈希:`blake2_256(GMB || OP_SIGN_L3_PAY(0x15) || scaleEncode())`。
  ///
  /// 经全仓签名唯一原语 [CitizenSdk.encodePayload] 构造,逐字节对齐链端
  /// `primitives::sign::signing_message(OP_SIGN_L3_PAY, SCALE(intent))`。
  Future<Uint8List> signingHash() => CitizenSdk.encodePayload(
    CitizenSigningPayload.message(
      opTag: kOpSignL3Pay,
      scalePayload: scaleEncode(),
    ),
  );

  /// 生成一个加密随机的 32 字节 `tx_id`,用作本笔支付的唯一标识 + 防重放键。
  ///
  /// `dart:math.Random.secure()` 在桌面/移动端均由 OS CSPRNG 提供。调用方不需要
  /// 自行维护熵源。
  static Uint8List randomTxId() {
    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

}

/// hex utils(含 `0x` 前缀 decode + encode)。
String bytesToHex(Uint8List bytes) {
  final buf = StringBuffer('0x');
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

Uint8List hexToBytes(String hex) {
  final text = hex.startsWith('0x') ? hex.substring(2) : hex;
  if (text.length.isOdd) {
    throw FormatException('hex 长度必须偶数:$hex');
  }
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(text.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
