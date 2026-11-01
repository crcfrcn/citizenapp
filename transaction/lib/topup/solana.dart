import 'package:citizen_transaction/topup/topup_models.dart';

/// Solana原SPL Token的USDC转账；收款地址是owner，由官方SDK推导/建立ATA。
Map<String, Object> solanaPayment(TopupRail rail, TopupPayment payment) {
  if (rail.network != TopupNetwork.solana ||
      rail.token != 'USDC' ||
      payment.network != rail.network) {
    throw const FormatException('Solana付款上下文无效');
  }
  return {
    'rpc': TopupRpcConfig.url(TopupRpcConfig.solana),
    'mint': rail.asset,
    'receiver': rail.recvAddress,
    'amount': payment.payAmount,
    'decimals': rail.decimals,
  };
}

/// 原USDC SPL Token事实来自同一finalized交易与所属区块，不使用余额差猜付款。
Future<TopupProof> verifySolanaPayment(
  TopupPayment payment,
  String payer,
  String txid,
  Future<Object?> Function(String, List<Object?>) rpc, {
  required String binding,
  int? now,
}) async {
  Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Solana最终付款证据不完整');
    }
    return value;
  }

  if (await rpc('getGenesisHash', []) !=
      '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d') {
    throw const FormatException('不是Solana主网');
  }
  final tx = object(
    await rpc('getTransaction', [
      txid,
      {
        'commitment': 'finalized',
        'encoding': 'jsonParsed',
        'maxSupportedTransactionVersion': 0,
      },
    ]),
  );
  final meta = object(tx['meta']), transaction = object(tx['transaction']);
  final signatures = transaction['signatures'];
  if (!meta.containsKey('err') ||
      meta['err'] != null ||
      !(tx['version'] == 'legacy' || tx['version'] == 0) ||
      signatures is! List ||
      signatures.isEmpty ||
      signatures.first != txid) {
    throw const FormatException('Solana付款尚未最终执行成功');
  }
  final slot = tx['slot'],
      seconds = tx['blockTime'],
      checked = now ?? DateTime.now().millisecondsSinceEpoch;
  if (slot is! int ||
      slot < 0 ||
      seconds is! int ||
      seconds * 1000 < payment.createdAt ~/ 1000 * 1000 ||
      seconds * 1000 > checked) {
    throw const FormatException('Solana付款时间无效');
  }
  final message = object(transaction['message']), keys = message['accountKeys'];
  if (keys is! List || keys.length > 256) {
    throw const FormatException('Solana账户定位无效');
  }
  const program = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
  final owners = <String, String>{}, facts = <int, String>{};
  final before = meta['preTokenBalances'], after = meta['postTokenBalances'];
  if (before is! List || after is! List) {
    throw const FormatException('Solana付款Token事实缺失');
  }
  for (final raw in [...before, ...after]) {
    final b = object(raw), index = b['accountIndex'];
    if (index is! int || index < 0 || index >= keys.length) {
      throw const FormatException('SolanaToken账户位置无效');
    }
    final fact = '${b['mint']}|${b['owner']}|${b['programId']}';
    if (facts.containsKey(index) && facts[index] != fact) {
      throw const FormatException('SolanaToken归属矛盾');
    }
    facts[index] = fact;
    if (b['mint'] != payment.asset) continue;
    if (b['programId'] != program ||
        object(b['uiTokenAmount'])['decimals'] != 6) {
      throw const FormatException('Solana资产程序或精度不一致');
    }
    final account = object(keys[index])['pubkey'], owner = b['owner'];
    if (account is! String ||
        owner is! String ||
        payment.network.address(account) != account ||
        payment.network.address(owner) != owner) {
      throw const FormatException('SolanaToken所有者无效');
    }
    if (owners.containsKey(account) && owners[account] != owner) {
      throw const FormatException('SolanaToken所有者冲突');
    }
    owners[account] = owner;
  }
  final original = message['instructions'];
  if (original is! List || original.length > 1024) {
    throw const FormatException('Solana付款指令无效');
  }
  final first = keys.isEmpty ? null : keys.first;
  if (first is! Map || first['pubkey'] != payer || first['signer'] != true) {
    throw const FormatException('真实付款账户没有签此交易');
  }
  final instructions = original;
  int? position;
  for (var i = 0; i < instructions.length; i++) {
    final instruction = object(instructions[i]);
    if (instruction['programId'] != program) continue;
    final parsed = object(instruction['parsed']), type = parsed['type'];
    if (type != 'transfer' && type != 'transferChecked') continue;
    final info = object(parsed['info']);
    if (owners[info['source']] != payer ||
        owners[info['destination']] != payment.recvAddress) {
      continue;
    }
    final Object? amount;
    if (type == 'transferChecked') {
      final tokenAmount = object(info['tokenAmount']);
      if (info['mint'] != payment.asset || tokenAmount['decimals'] != 6) {
        throw const FormatException('SolanaToken付款资产不一致');
      }
      amount = tokenAmount['amount'];
    } else {
      amount = info['amount'];
    }
    if (i == 0) throw const FormatException('付款缺少前置绑定');
    final memo = object(original[i - 1]);
    if (memo['programId'] != 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr' ||
        memo['parsed'] != 'topup:$binding' ||
        info['authority'] != payer) {
      throw const FormatException('付款指令没有对应原充值绑定');
    }
    if (decimal(amount) != payment.payAmount || position != null) {
      throw const FormatException('Solana金额不一致或付款不唯一');
    }
    position = i;
  }
  if (position == null) throw const FormatException('没有匹配原订单的Solana付款');
  final block = object(
    await rpc('getBlock', [
      slot,
      {
        'commitment': 'finalized',
        'transactionDetails': 'signatures',
        'rewards': false,
        'maxSupportedTransactionVersion': 0,
      },
    ]),
  );
  final hashes = block['signatures'], bh = block['blockhash'];
  if (hashes is! List ||
      hashes.length > 10000 ||
      hashes.where((x) => x == txid).length != 1 ||
      block['blockTime'] != seconds ||
      bh is! String ||
      payment.network.address(bh) != bh) {
    throw const FormatException('Solana付款不属于最终块');
  }
  return TopupProof.fromJson({
    'network': 'solana',
    'binding_hash': binding,
    'payment_txid': txid,
    'payer_address': payer,
    'asset': payment.asset,
    'recv_address': payment.recvAddress,
    'pay_amount': payment.payAmount,
    'block_hash': bh,
    'block_number': slot,
    'block_at': seconds * 1000,
    'transfer_index': position,
    'checked_at': checked,
    'finalized': true,
    'succeeded': true,
  });
}
