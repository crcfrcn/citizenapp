import 'package:citizen_transaction/topup/topup_models.dart';

// ERC-20 `transfer(address,uint256)` calldata 编码。
//
// selector = keccak256("transfer(address,uint256)")[0..4] = 0xa9059cbb;
// 参数各右对齐补齐到 32 字节。App 用它构造 eth_sendTransaction 的 data。

const String _transferSelector = 'a9059cbb';

/// 构造 ERC-20 transfer 的 0x calldata。
/// [toEvmAddress] 收款 EVM 地址（0x + 40 位 hex）；[amount] 为稳定币最小单位数额。
String encodeErc20Transfer(String toEvmAddress, BigInt amount, String binding) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(binding)) {
    throw const FormatException('充值绑定无效');
  }
  final to = toEvmAddress.trim().toLowerCase().replaceFirst('0x', '');
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(to)) {
    throw ArgumentError('收款地址不是合法 EVM 地址');
  }
  if (amount < BigInt.zero) {
    throw ArgumentError('金额不能为负');
  }
  final amountHex = amount.toRadixString(16);
  if (amountHex.length > 64) {
    throw ArgumentError('金额超出 uint256 范围');
  }
  final toWord = to.padLeft(64, '0');
  final amountWord = amountHex.padLeft(64, '0');
  return '0x$_transferSelector$toWord$amountWord$binding';
}

/// 单轮EVM付款证据核验，逐条RPC计数；11轮与退避只由App根层调度。
Future<TopupProof> verifyErc20Payment(
  TopupPayment payment,
  String payer,
  String txid,
  Future<Object?> Function(String, List<Object?>) rpc, {
  required String binding,
  int? now,
}) async {
  if (payment.network.evmId == null ||
      !payment.network.transaction(txid) ||
      payment.network.address(payer) != payer) {
    throw const FormatException('EVM付款定位无效');
  }
  int quantity(Object? value) {
    if (value is! String ||
        !RegExp(r'^0x(?:0|[1-9a-f][0-9a-f]*)$').hasMatch(value)) {
      throw const FormatException('EVM数量无效');
    }
    final number = BigInt.parse(value.substring(2), radix: 16);
    if (number > BigInt.from(9007199254740991)) {
      throw const FormatException('EVM高度溢出');
    }
    return number.toInt();
  }

  Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('付款网络尚未提供完整回执');
    }
    return value;
  }

  String hash(Object? value) {
    if (value is! String || !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value)) {
      throw const FormatException('EVM哈希无效');
    }
    return value;
  }

  if (quantity(await rpc('eth_chainId', [])) != payment.network.evmId) {
    throw const FormatException('付款网络不一致');
  }
  final receipt = object(await rpc('eth_getTransactionReceipt', [txid]));
  if (hash(receipt['transactionHash']) != txid ||
      quantity(receipt['status']) != 1) {
    throw const FormatException('付款交易尚未执行成功');
  }
  final transaction = object(await rpc('eth_getTransactionByHash', [txid]));
  if (hash(transaction['hash']) != txid ||
      transaction['from'] != payer ||
      transaction['to'] != payment.asset ||
      quantity(transaction['value']) != 0 ||
      transaction['input'] !=
          encodeErc20Transfer(
            payment.recvAddress,
            BigInt.parse(payment.payAmount),
            binding,
          ) ||
      transaction['blockHash'] != receipt['blockHash'] ||
      transaction['blockNumber'] != receipt['blockNumber'] ||
      transaction['transactionIndex'] != receipt['transactionIndex']) {
    throw const FormatException('付款签名未覆盖原充值绑定');
  }
  final number = quantity(receipt['blockNumber']),
      blockHash = hash(receipt['blockHash']),
      index = quantity(receipt['transactionIndex']);
  final tag = '0x${number.toRadixString(16)}';
  final block = object(await rpc('eth_getBlockByNumber', [tag, false]));
  final transactions = block['transactions'];
  if (hash(block['hash']) != blockHash ||
      quantity(block['number']) != number ||
      transactions is! List ||
      transactions.length > 10000 ||
      index >= transactions.length ||
      transactions[index] != txid ||
      transactions.where((x) => x == txid).length != 1) {
    throw const FormatException('付款区块归属不一致');
  }
  final head = object(await rpc('eth_getBlockByNumber', ['finalized', false]));
  hash(head['hash']);
  if (quantity(head['number']) < number) {
    throw const FormatException('付款尚未最终确认');
  }
  final checked = now ?? DateTime.now().millisecondsSinceEpoch,
      at = quantity(block['timestamp']) * 1000;
  if (at < payment.createdAt ~/ 1000 * 1000 || at > checked) {
    throw const FormatException('付款时间与原订单不一致');
  }
  final logs = receipt['logs'];
  if (logs is! List || logs.length > 1024) {
    throw const FormatException('付款日志不完整');
  }
  const transfer =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
  String address(Object? topic) {
    if (topic is! String || !RegExp(r'^0x0{24}[0-9a-f]{40}$').hasMatch(topic)) {
      throw const FormatException('付款日志地址无效');
    }
    return '0x${topic.substring(26)}';
  }

  int? transferIndex;
  for (final raw in logs) {
    final log = object(raw);
    if (log['address'] != payment.asset) continue;
    final topics = log['topics'];
    if (topics is! List || topics.isEmpty || topics.first != transfer) continue;
    if (topics.length != 3 || log['removed'] != false) {
      throw const FormatException('付款日志不可信');
    }
    if (address(topics[1]) != payer ||
        address(topics[2]) != payment.recvAddress) {
      continue;
    }
    final data = log['data'];
    if (data is! String ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(data) ||
        BigInt.parse(data.substring(2), radix: 16) !=
            BigInt.parse(payment.payAmount)) {
      throw const FormatException('付款金额必须与套餐严格相等');
    }
    if (log['transactionHash'] != txid ||
        log['blockHash'] != blockHash ||
        quantity(log['blockNumber']) != number ||
        quantity(log['transactionIndex']) != index ||
        transferIndex != null) {
      throw const FormatException('付款事件不唯一或定位不一致');
    }
    transferIndex = quantity(log['logIndex']);
  }
  if (transferIndex == null) throw const FormatException('没有匹配原订单的真实付款');
  final again = object(await rpc('eth_getBlockByNumber', [tag, false]));
  if (hash(again['hash']) != blockHash || quantity(again['number']) != number) {
    throw const FormatException('付款区块发生变化');
  }
  return TopupProof.fromJson({
    'binding_hash': binding,
    'network': payment.network.wire,
    'payment_txid': txid,
    'payer_address': payer,
    'asset': payment.asset,
    'recv_address': payment.recvAddress,
    'pay_amount': payment.payAmount,
    'block_hash': blockHash,
    'block_number': number,
    'block_at': at,
    'transfer_index': transferIndex,
    'checked_at': checked,
    'finalized': true,
    'succeeded': true,
  });
}
