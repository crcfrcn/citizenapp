import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:citizenapp/network/citizen_serve_api_config.dart';

/// 精确主网标识；会话批准的链列表不等于钱包的本次付款网络。
enum TopupNetwork {
  ethereum('ethereum', 'eip155:1', 1),
  base('base', 'eip155:8453', 8453),
  bnb('bnb', 'eip155:56', 56),
  tron('tron', 'tron:0x2b6653dc', null),
  solana('solana', 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp', null);

  const TopupNetwork(this.wire, this.caip2, this.evmId);
  final String wire;
  final String caip2;
  final int? evmId;
  static TopupNetwork parse(Object? value) => values.firstWhere(
    (n) => n.wire == value,
    orElse: () => throw const FormatException('不支持的付款网络'),
  );
  String address(String value) {
    if (evmId != null) {
      final v = value.toLowerCase();
      if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(v) || v == '0x${'0' * 40}') {
        throw const FormatException('EVM地址无效');
      }
      return v;
    }
    final bytes = base58Bytes(value);
    if (this == solana && bytes.length == 32) return value;
    if (this == tron && bytes.length == 25 && bytes.first == 0x41) {
      final checksum = sha256
          .convert(sha256.convert(bytes.sublist(0, 21)).bytes)
          .bytes;
      if (List.generate(4, (i) => bytes[21 + i] == checksum[i]).every((v) => v))
        return value;
    }
    throw const FormatException('付款地址无效');
  }

  bool transaction(String value) => this == solana
      ? value.length <= 88 && _base58Length(value, 64)
      : RegExp(this == tron ? r'^[0-9a-f]{64}$' : r'^0x[0-9a-f]{64}$')
            .hasMatch(value);
  void signature(String value) {
    final valid = this == solana
        ? value.length <= 88 && _base58Length(value, 64)
        : RegExp(
            this == tron
                ? r'^0x[0-9a-fA-F]{130}$'
                : r'^0x(?:[0-9a-fA-F]{2}){1,4096}$',
          ).hasMatch(value);
    if (!valid) throw const FormatException('付款授权签名无效');
  }
}

/// Base58是地址/签名编码，不承担任何签名或私钥功能。
List<int> base58Bytes(String text) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (text.isEmpty || text.length > 128)
    throw const FormatException('Base58编码无效');
  var value = BigInt.zero;
  for (final c in text.split('')) {
    final digit = alphabet.indexOf(c);
    if (digit < 0) throw const FormatException('Base58编码无效');
    value = value * BigInt.from(58) + BigInt.from(digit);
  }
  final bytes = <int>[];
  while (value > BigInt.zero) {
    bytes.add((value & BigInt.from(255)).toInt());
    value >>= 8;
  }
  return [
    ...List<int>.filled(text.split('').takeWhile((c) => c == '1').length, 0),
    ...bytes.reversed,
  ];
}

bool _base58Length(String v, int length) {
  try {
    return base58Bytes(v).length == length;
  } on FormatException {
    return false;
  }
}

String decimal(Object? value) {
  if (value is! String || !RegExp(r'^[1-9][0-9]{0,77}$').hasMatch(value))
    throw const FormatException('金额必须为正整数文本');
  return value;
}

String targetAccount(String value) {
  if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value))
    throw const FormatException('充值目标账户无效');
  return value;
}

String orderId(String value) {
  if (!RegExp(r'^top_[0-9a-f]{32}$').hasMatch(value))
    throw const FormatException('订单编号无效');
  return value;
}

bool allowedPair(String token, TopupNetwork n) => token == 'USDC'
    ? const [
        TopupNetwork.ethereum,
        TopupNetwork.base,
        TopupNetwork.solana,
      ].contains(n)
    : token == 'USDT' &&
          const [
            TopupNetwork.ethereum,
            TopupNetwork.tron,
            TopupNetwork.bnb,
          ].contains(n);

class TopupRail {
  const TopupRail({
    required this.token,
    required this.network,
    required this.asset,
    required this.decimals,
    required this.recvAddress,
  });
  final String token, asset, recvAddress;
  final TopupNetwork network;
  final int decimals;
  String get key => '${token}:${network.wire}';
  factory TopupRail.fromJson(Map<String, dynamic> j) {
    final n = TopupNetwork.parse(j['network']);
    final t = j['token'];
    final a = j['asset'];
    final r = j['recv_address'];
    if (t is! String ||
        !allowedPair(t, n) ||
        a is! String ||
        r is! String ||
        j['decimals'] != (n == TopupNetwork.bnb ? 18 : 6))
      throw const FormatException('币轨配置无效');
    if (n.address(a) != a || n.address(r) != r)
      throw const FormatException('币轨地址未规范化');
    return TopupRail(
      token: t,
      network: n,
      asset: a,
      decimals: j['decimals'] as int,
      recvAddress: r,
    );
  }
}

class TopupPackage {
  const TopupPackage({
    required this.packageId,
    required this.payDisplay,
    required this.coinDisplay,
    required this.coinFen,
    required this.payments,
  });
  final String packageId, payDisplay, coinDisplay, coinFen;
  final Map<String, String> payments;
  String amount(TopupRail rail) =>
      payments[rail.key] ?? (throw const FormatException('该套餐不支持当前币轨'));
  factory TopupPackage.fromJson(Map<String, dynamic> j) {
    final id = j['package_id'];
    if (id != 'pkg_15' && id != 'pkg_1400')
      throw const FormatException('不支持自定义套餐');
    final payment = j['payments'];
    if (payment is! List) throw const FormatException('缺少币轨报价');
    final amounts = <String, String>{};
    for (final raw in payment) {
      if (raw is! Map<String, dynamic>) throw const FormatException('币轨报价无效');
      final n = TopupNetwork.parse(raw['network']);
      final token = raw['token'];
      if (token is! String || !allowedPair(token, n))
        throw const FormatException('不支持的币轨');
      final key = '$token:${n.wire}';
      if (amounts.containsKey(key)) throw const FormatException('币轨报价重复');
      final a = decimal(raw['pay_amount']);
      final expected =
          BigInt.from(id == 'pkg_15' ? 15 : 1400) *
          BigInt.from(10).pow(n == TopupNetwork.bnb ? 18 : 6);
      if (BigInt.parse(a) != expected) throw const FormatException('套餐金额无效');
      amounts[key] = a;
    }
    if (amounts.length != 6 ||
        j['pay_display'] != (id == 'pkg_15' ? '15' : '1400') ||
        j['coin_fen'] != (id == 'pkg_15' ? '1000000' : '100000000') ||
        j['coin_display'] is! String)
      throw const FormatException('套餐配置无效');
    return TopupPackage(
      packageId: id as String,
      payDisplay: j['pay_display'] as String,
      coinDisplay: j['coin_display'] as String,
      coinFen: decimal(j['coin_fen']),
      payments: Map.unmodifiable(amounts),
    );
  }
}

class TopupConfig {
  const TopupConfig({required this.rails, required this.packages});
  final List<TopupRail> rails;
  final List<TopupPackage> packages;
  List<String> get tokens => const ['USDC', 'USDT'];
  TopupRail rail(String token, TopupNetwork n) => rails.firstWhere(
    (r) => r.token == token && r.network == n,
    orElse: () => throw const FormatException('当前币种不支持钱包所在网络'),
  );
  factory TopupConfig.fromJson(Map<String, dynamic> j) {
    if (j['ok'] != true || j['rails'] is! List || j['packages'] is! List)
      throw const FormatException('充值配置无效');
    final rails = (j['rails'] as List)
        .map((r) => TopupRail.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
    final packs = (j['packages'] as List)
        .map((r) => TopupPackage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
    if (rails.length != 6 ||
        rails.map((r) => r.key).toSet().length != 6 ||
        packs.length != 2 ||
        packs.map((p) => p.packageId).toSet().length != 2)
      throw const FormatException('充值配置缺项或重复');
    final evm = rails
        .where((r) => r.network.evmId != null)
        .map((r) => r.recvAddress)
        .toSet();
    if (evm.length != 1) throw const FormatException('EVM收款账户不一致');
    return TopupConfig(
      rails: List.unmodifiable(rails),
      packages: List.unmodifiable(packs),
    );
  }
}

class TopupContext {
  const TopupContext(this.network, this.payer);
  final TopupNetwork network;
  final String payer;
  factory TopupContext.fromJson(Map<String, dynamic> j) {
    final n = TopupNetwork.parse(j['network']);
    final p = j['payer'];
    if (j['chain'] != n.caip2 || p is! String)
      throw const FormatException('钱包上下文无效');
    return TopupContext(n, n.address(p));
  }
}

class TopupPaymentIntent {
  const TopupPaymentIntent({
    required this.order,
    required this.token,
    required this.intent,
    required this.authorizationMessage,
  });
  final String order, token, authorizationMessage;
  final Map<String, dynamic> intent;
  int get expiresAt => intent['expires_at'] as int;
  String get accountId => intent['account_id'] as String;
  String get payer => intent['payer_address'] as String;
  TopupNetwork get network => TopupNetwork.parse(intent['network']);
  String get coinFen => intent['coin_fen'] as String;
  Map<String, dynamic> toJson() => {
    'ok': true,
    'order_id': order,
    'payment_intent': token,
    'intent': intent,
    'wallet_authorization_message': authorizationMessage,
  };
  factory TopupPaymentIntent.fromJson(Map<String, dynamic> j) {
    if (j['ok'] != true ||
        j['order_id'] is! String ||
        j['payment_intent'] is! String ||
        j['wallet_authorization_message'] is! String ||
        j['intent'] is! Map<String, dynamic>)
      throw const FormatException('付款意图响应无效');
    final i = Map<String, dynamic>.unmodifiable(
      j['intent'] as Map<String, dynamic>,
    );
    const fields = {
      'intent_id',
      'cid_number',
      'account_id',
      'payer_address',
      'token',
      'network',
      'package_id',
      'asset',
      'recv_address',
      'pay_amount',
      'coin_fen',
      'issued_at',
      'expires_at',
    };
    if (i.length != fields.length ||
        !i.keys.every(fields.contains) ||
        i['intent_id'] is! String ||
        !RegExp(r'^tpi_[0-9a-f]{32}$').hasMatch(i['intent_id'] as String) ||
        i['issued_at'] is! int ||
        i['expires_at'] is! int ||
        (i['issued_at'] as int) <= 0 ||
        (i['expires_at'] as int) - (i['issued_at'] as int) != 600000)
      throw const FormatException('付款意图字段无效');
    final o = orderId(j['order_id'] as String);
    if (o != 'top_${(i['intent_id'] as String).substring(4)}')
      throw const FormatException('订单与意图不一致');
    targetAccount(i['account_id'] as String);
    final n = TopupNetwork.parse(i['network']);
    if (!allowedPair(i['token'] as String, n) ||
        n.address(i['payer_address'] as String) != i['payer_address'] ||
        n.address(i['asset'] as String) != i['asset'] ||
        n.address(i['recv_address'] as String) != i['recv_address'])
      throw const FormatException('付款意图币轨无效');
    decimal(i['pay_amount']);
    decimal(i['coin_fen']);
    final token = j['payment_intent'] as String;
    final parts = token.split('.');
    if (token.length > 8192 || parts.length != 2)
      throw const FormatException('付款凭证无效');
    final decoded = base64Url.decode(base64Url.normalize(parts[0]));
    final mac = base64Url.decode(base64Url.normalize(parts[1]));
    if (base64Url.encode(decoded).replaceAll('=', '') != parts[0] ||
        base64Url.encode(mac).replaceAll('=', '') != parts[1] ||
        mac.length != 32 ||
        jsonEncode(jsonDecode(utf8.decode(decoded))) != jsonEncode(i))
      throw const FormatException('付款凭证与意图不一致');
    return TopupPaymentIntent(
      order: o,
      token: token,
      intent: i,
      authorizationMessage: j['wallet_authorization_message'] as String,
    );
  }
  void validatePayment({
    required TopupRail rail,
    required TopupPackage package,
    required String accountId,
    required String payerAddress,
    required String chainGenesisHash,
    required String serviceOrigin,
    int? now,
  }) {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    if (intent['account_id'] != targetAccount(accountId) ||
        intent['payer_address'] != rail.network.address(payerAddress) ||
        intent['token'] != rail.token ||
        intent['network'] != rail.network.wire ||
        intent['asset'] != rail.asset ||
        intent['recv_address'] != rail.recvAddress ||
        intent['pay_amount'] != package.amount(rail) ||
        intent['coin_fen'] != package.coinFen ||
        intent['package_id'] != package.packageId ||
        time < (intent['issued_at'] as int) ||
        time >= expiresAt ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainGenesisHash) ||
        Uri.parse(serviceOrigin).origin != serviceOrigin)
      throw const FormatException('付款意图与本次充值不一致或过期');
    final expected =
        'CitizenServe Topup v1\nservice_origin=$serviceOrigin\nchain_genesis_hash=$chainGenesisHash\nintent_id=${intent['intent_id']}\nnetwork=${intent['network']}\npayer_address=${intent['payer_address']}\nasset=${intent['asset']}\nrecv_address=${intent['recv_address']}\npay_amount=${intent['pay_amount']}\ncoin_fen=${intent['coin_fen']}\naccount_id=${intent['account_id']}\npackage_id=${intent['package_id']}\nissued_at=${intent['issued_at']}\nexpires_at=${intent['expires_at']}\nintent_sha256=${sha256.convert(utf8.encode(token))}\n';
    if (authorizationMessage != expected)
      throw const FormatException('付款授权原文不一致');
  }
}

enum TopupOrderStatus { pending, paid, exception }

enum TopupPhase {
  awaiting,
  verifying,
  received,
  signed,
  broadcast,
  paid,
  exception,
}

class TopupOrder {
  const TopupOrder({
    required this.id,
    required this.status,
    required this.phase,
    required this.coinFen,
    this.paymentTxid,
    this.gmbTxHash,
    this.reason,
  });
  final String id, coinFen;
  final TopupOrderStatus status;
  final TopupPhase phase;
  final String? paymentTxid, gmbTxHash, reason;
  bool get terminal => status != TopupOrderStatus.pending;
  String get message => switch (phase) {
    TopupPhase.awaiting => '付款回执待核实，请勿重复付款',
    TopupPhase.verifying => '正在确认稳定币付款',
    TopupPhase.received =>
      reason == 'topup_disburse_insufficient_balance'
          ? '稳定币已收款，等待发币处理'
          : '稳定币已收款，等待发币',
    TopupPhase.signed || TopupPhase.broadcast => '稳定币已收款，公民币正在到账',
    TopupPhase.paid => '公民币已转入本账户',
    TopupPhase.exception => '订单需要核查，请保留原付款交易，勿重复付款',
  };
  Map<String, dynamic> toJson() => {
    'ok': true,
    'order_id': id,
    'status': status.name,
    'phase': phase.name,
    'coin_fen': coinFen,
    'payment_txid': paymentTxid,
    'gmb_tx_hash': gmbTxHash,
    'reason': reason,
  };
  factory TopupOrder.fromJson(Map<String, dynamic> j) {
    if (j['ok'] != true) throw const FormatException('订单响应无效');
    final status = TopupOrderStatus.values.firstWhere(
      (v) => v.name == j['status'],
      orElse: () => throw const FormatException('未知订单状态'),
    );
    final phase = TopupPhase.values.firstWhere(
      (v) => v.name == j['phase'],
      orElse: () => throw const FormatException('未知订单阶段'),
    );
    if ((status == TopupOrderStatus.paid) != (phase == TopupPhase.paid) ||
        (status == TopupOrderStatus.exception) !=
            (phase == TopupPhase.exception))
      throw const FormatException('订单状态不一致');
    if (status == TopupOrderStatus.paid &&
        (j['gmb_tx_hash'] is! String ||
            !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(j['gmb_tx_hash'] as String) ||
            j['payment_txid'] is! String))
      throw const FormatException('已到账回执缺少链上定位');
    return TopupOrder(
      id: orderId(j['order_id'] as String),
      status: status,
      phase: phase,
      coinFen: decimal(j['coin_fen']),
      paymentTxid: j['payment_txid'] as String?,
      gmbTxHash: j['gmb_tx_hash'] as String?,
      reason: j['reason'] as String?,
    );
  }
}

/// 客户端公开节点只用于构造和广播U交易，不是服务端验款或NRC秘密端点。
abstract final class TopupRpcConfig {
  static const tron = String.fromEnvironment('TOPUP_TRON_RPC_URL');
  static const solana = String.fromEnvironment('TOPUP_SOLANA_RPC_URL');
  static String url(String value) {
    final u = Uri.tryParse(value);
    if (u == null ||
        u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        u.hasQuery ||
        u.hasFragment)
      throw const FormatException('付款网络尚未配置');
    return u.toString();
  }
}

String topupOrigin(String base) =>
    Uri.parse(CitizenServeApiConfig.normalize(base)).origin;
