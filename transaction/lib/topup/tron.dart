import 'dart:convert';
import 'package:citizen_transaction/topup/topup_models.dart';

/// Tron参数来自本地冻结订单；交易构造与序列化由随包TronWeb完成。
Map<String, Object> tronPayment(TopupRail rail, TopupPayment payment) {
  if (rail.network != TopupNetwork.tron ||
      rail.token != 'USDT' ||
      payment.network != rail.network) {
    throw const FormatException('Tron付款上下文无效');
  }
  return {
    'rpc': TopupRpcConfig.url(TopupRpcConfig.tron),
    'asset': rail.asset,
    'receiver': rail.recvAddress,
    'amount': payment.payAmount,
  };
}

/// 固化节点事实的一轮验款：主网、原交易、成功回执、区块归属及严格等额。
Future<TopupProof> verifyTronPayment(
  TopupPayment payment,
  String payer,
  String txid,
  Future<Object?> Function(String, List<Object?>) rpc, {
  required String binding,
  int? now,
}) async {
  Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Tron付款证据不完整');
    }
    return value;
  }

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, Object?> value,
  ) async => object(await rpc('walletsolidity/$method', [value]));
  String hexAddress(String value) => base58Bytes(
    value,
  ).take(21).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final genesis = await call('getblockbynum', {'num': 0});
  if (genesis['blockID'] !=
      '00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc') {
    throw const FormatException('不是Tron主网');
  }
  final transaction = await call('gettransactionbyid', {'value': txid});
  final receipt = await call('gettransactioninfobyid', {'value': txid});
  final ret = transaction['ret'];
  if (transaction['txID'] != txid ||
      receipt['id'] != txid ||
      ret is! List ||
      ret.length != 1 ||
      object(ret.single)['contractRet'] != 'SUCCESS' ||
      object(receipt['receipt'])['result'] != 'SUCCESS') {
    throw const FormatException('Tron付款尚未固化成功');
  }
  final number = receipt['blockNumber'];
  if (number is! int || number <= 0) throw const FormatException('Tron付款区块无效');
  final block = await call('getblockbynum', {'num': number});
  final header = object(object(block['block_header'])['raw_data']);
  final at = header['timestamp'], bh = block['blockID'];
  final checked = now ?? DateTime.now().millisecondsSinceEpoch;
  if (header['number'] != number ||
      at is! int ||
      at < payment.createdAt ~/ 1000 * 1000 ||
      at > checked ||
      receipt['blockTimeStamp'] != at ||
      bh is! String ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(bh)) {
    throw const FormatException('Tron付款时间或区块无效');
  }
  final txs = block['transactions'];
  if (txs is! List ||
      txs.length > 10000 ||
      txs.where((item) => object(item)['txID'] == txid).length != 1) {
    throw const FormatException('Tron交易不属于固化块');
  }
  final expectedMemo = utf8
      .encode('topup:$binding')
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  if (object(transaction['raw_data'])['data'] != expectedMemo) {
    throw const FormatException('付款签名未覆盖原充值绑定');
  }
  final raw = object(transaction['raw_data']), contracts = raw['contract'];
  if (contracts is! List || contracts.length != 1) {
    throw const FormatException('Tron付款调用不唯一');
  }
  final contract = object(contracts.single),
      parameter = object(contract['parameter']),
      value = object(parameter['value']);
  if (contract['type'] != 'TriggerSmartContract' ||
      parameter['type_url'] !=
          'type.googleapis.com/protocol.TriggerSmartContract' ||
      value['owner_address'] != hexAddress(payer) ||
      value['contract_address'] != hexAddress(payment.asset)) {
    throw const FormatException('Tron付款人与资产不一致');
  }
  final logs = receipt['log'];
  if (logs is! List || logs.length > 1024) {
    throw const FormatException('Tron付款日志无效');
  }
  const transfer =
      'ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
  int? position;
  for (var i = 0; i < logs.length; i++) {
    final log = object(logs[i]);
    if (log['address'] != hexAddress(payment.asset).substring(2)) continue;
    final topics = log['topics'];
    if (topics is! List || topics.isEmpty || topics.first != transfer) continue;
    if (topics.length != 3 || topics[1] is! String || topics[2] is! String) {
      throw const FormatException('Tron事件地址无效');
    }
    final from = topics[1] as String, to = topics[2] as String;
    if (!RegExp(r'^0{24}[0-9a-f]{40}$').hasMatch(from) ||
        !RegExp(r'^0{24}[0-9a-f]{40}$').hasMatch(to)) {
      throw const FormatException('Tron事件地址未规范化');
    }
    if (from.substring(24) != hexAddress(payer).substring(2) ||
        to.substring(24) != hexAddress(payment.recvAddress).substring(2)) {
      continue;
    }
    final data = log['data'];
    if (data is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(data) ||
        BigInt.parse(data, radix: 16) != BigInt.parse(payment.payAmount) ||
        position != null) {
      throw const FormatException('Tron付款金额不一致或付款不唯一');
    }
    position = i;
  }
  if (position == null) throw const FormatException('没有匹配原订单的Tron付款');
  if ((await call('getblockbynum', {'num': number}))['blockID'] != bh) {
    throw const FormatException('Tron固化块不一致');
  }
  return TopupProof.fromJson({
    'network': 'tron',
    'binding_hash': binding,
    'payment_txid': txid,
    'payer_address': payer,
    'asset': payment.asset,
    'recv_address': payment.recvAddress,
    'pay_amount': payment.payAmount,
    'block_hash': bh,
    'block_number': number,
    'block_at': at,
    'transfer_index': position,
    'checked_at': checked,
    'finalized': true,
    'succeeded': true,
  });
}
