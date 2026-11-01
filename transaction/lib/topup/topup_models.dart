import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart' show CitizenSdk;

import 'package:crypto/crypto.dart';
import 'package:citizen_network/citizen_serve_api_config.dart';

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
  String get label => switch (this) {
    ethereum => 'Ethereum/以太坊链',
    base => 'Base/贝斯链',
    bnb => 'BNB/币安链',
    tron => 'Tron/波场链',
    solana => 'Solana/索拉纳链',
  };
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
      if (List.generate(
        4,
        (i) => bytes[21 + i] == checksum[i],
      ).every((v) => v)) {
        return value;
      }
    }
    throw const FormatException('付款地址无效');
  }

  bool transaction(String value) => this == solana
      ? value.length <= 88 && _base58Length(value, 64)
      : RegExp(
          this == tron ? r'^[0-9a-f]{64}$' : r'^0x[0-9a-f]{64}$',
        ).hasMatch(value);
}

/// Base58是地址/签名编码，不承担任何签名或私钥功能。
List<int> base58Bytes(String text) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (text.isEmpty || text.length > 128) {
    throw const FormatException('Base58编码无效');
  }
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
  if (value is! String || !RegExp(r'^[1-9][0-9]{0,77}$').hasMatch(value)) {
    throw const FormatException('金额必须为正整数文本');
  }
  return value;
}

String targetAccount(String value) {
  if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('充值目标账户无效');
  }
  return value;
}

String validateOrderId(String value) {
  if (!RegExp(r'^top_[0-9a-f]{32}$').hasMatch(value)) {
    throw const FormatException('订单编号无效');
  }
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
  String get key => '$token:${network.wire}';
  factory TopupRail.fromJson(Map<String, dynamic> j) {
    final n = TopupNetwork.parse(j['network']);
    final t = j['token'];
    final a = j['asset'];
    final r = j['recv_address'];
    if (t is! String ||
        !allowedPair(t, n) ||
        a is! String ||
        r is! String ||
        j['decimals'] != (n == TopupNetwork.bnb ? 18 : 6)) {
      throw const FormatException('币轨配置无效');
    }
    if (n.address(a) != a || n.address(r) != r) {
      throw const FormatException('币轨地址未规范化');
    }
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
    if (id != 'pkg_10' && id != 'pkg_900') {
      throw const FormatException('不支持自定义套餐');
    }
    final payment = j['payments'];
    if (payment is! List) throw const FormatException('缺少币轨报价');
    final amounts = <String, String>{};
    for (final raw in payment) {
      if (raw is! Map<String, dynamic>) throw const FormatException('币轨报价无效');
      final n = TopupNetwork.parse(raw['network']);
      final token = raw['token'];
      if (token is! String || !allowedPair(token, n)) {
        throw const FormatException('不支持的币轨');
      }
      final key = '$token:${n.wire}';
      if (amounts.containsKey(key)) throw const FormatException('币轨报价重复');
      final a = decimal(raw['pay_amount']);
      final expected =
          BigInt.from(id == 'pkg_10' ? 10 : 900) *
          BigInt.from(10).pow(n == TopupNetwork.bnb ? 18 : 6);
      if (BigInt.parse(a) != expected) throw const FormatException('套餐金额无效');
      amounts[key] = a;
    }
    if (amounts.length != 6 ||
        j['pay_display'] != (id == 'pkg_10' ? '10' : '900') ||
        j['coin_fen'] != (id == 'pkg_10' ? '1000000' : '100000000') ||
        j['coin_display'] is! String) {
      throw const FormatException('套餐配置无效');
    }
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
  const TopupConfig({
    required this.ready,
    required this.rails,
    required this.packages,
  });
  final bool ready;
  final List<TopupRail> rails;
  final List<TopupPackage> packages;
  List<String> get tokens => const ['USDC', 'USDT'];
  TopupRail rail(String token, TopupNetwork n) => rails.firstWhere(
    (r) => r.token == token && r.network == n,
    orElse: () => throw const FormatException('当前币种不支持所选网络'),
  );
  TopupPackage packageById(String id) => packages.firstWhere(
    (p) => p.packageId == id,
    orElse: () => throw const FormatException('充值套餐不存在'),
  );
  static const origin = 'https://www.crcfrcn.com';
  static const genesis =
      '0x18847a5dfd263272f2e7727836fe6582f8c4463ff48609df7b96d5e4d9dd24dd';
  factory TopupConfig.local() {
    const evm = '0x5ce9b56b9d1812a7cf29841e21756f09ca7d223b';
    final rails = [
      const TopupRail(
        token: 'USDC',
        network: TopupNetwork.ethereum,
        asset: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        decimals: 6,
        recvAddress: evm,
      ),
      const TopupRail(
        token: 'USDC',
        network: TopupNetwork.base,
        asset: '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
        decimals: 6,
        recvAddress: evm,
      ),
      const TopupRail(
        token: 'USDC',
        network: TopupNetwork.solana,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        decimals: 6,
        recvAddress: 'ES4pPjXbsK8Q47PpeCSddNsomxFqDmR9tD7p6j1Crcyi',
      ),
      const TopupRail(
        token: 'USDT',
        network: TopupNetwork.ethereum,
        asset: '0xdac17f958d2ee523a2206206994597c13d831ec7',
        decimals: 6,
        recvAddress: evm,
      ),
      const TopupRail(
        token: 'USDT',
        network: TopupNetwork.tron,
        asset: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        decimals: 6,
        recvAddress: 'TB1JA2HBUmfAvRVm9TQvm7RbtkFRSmeuH3',
      ),
      const TopupRail(
        token: 'USDT',
        network: TopupNetwork.bnb,
        asset: '0x55d398326f99059ff775485246999027b3197955',
        decimals: 18,
        recvAddress: evm,
      ),
    ];
    return TopupConfig(
      ready: true,
      rails: List.unmodifiable(rails),
      packages: List.unmodifiable([
        for (final amount in [10, 900])
          TopupPackage(
            packageId: 'pkg_$amount',
            payDisplay: '$amount',
            coinDisplay: amount == 10 ? '10,000.00' : '1,000,000.00',
            coinFen: amount == 10 ? '1000000' : '100000000',
            payments: Map.unmodifiable({
              for (final rail in rails)
                rail.key:
                    (BigInt.from(amount) * BigInt.from(10).pow(rail.decimals))
                        .toString(),
            }),
          ),
      ]),
    );
  }

  /// 消费CitizenServe公开合同：固定21行UTF-8/LF，显示文字及JSON顺序不参与。
  String get fingerprint {
    final lines = [
      'CitizenServe Topup Config',
      'service_origin=$origin',
      'chain_genesis_hash=$genesis',
    ];
    for (final token in const ['USDC', 'USDT']) {
      for (final network in const [
        TopupNetwork.ethereum,
        TopupNetwork.base,
        TopupNetwork.solana,
        TopupNetwork.tron,
        TopupNetwork.bnb,
      ]) {
        if (!allowedPair(token, network)) continue;
        final value = rail(token, network);
        lines.add(
          'rail=${value.token}|${value.network.wire}|${value.asset}|${value.decimals}|${value.recvAddress}',
        );
        for (final id in const ['pkg_10', 'pkg_900']) {
          final pack = packageById(id);
          lines.add('package=$id|${pack.amount(value)}|${pack.coinFen}');
        }
      }
    }
    return '${lines.join('\n')}\n';
  }

  String get hash => sha256.convert(utf8.encode(fingerprint)).toString();

  factory TopupConfig.fromJson(Map<String, dynamic> j) {
    if (j['is_ok'] != true ||
        j['ready'] is! bool ||
        j['rails'] is! List ||
        j['packages'] is! List) {
      throw const FormatException('充值配置无效');
    }
    final rails = (j['rails'] as List)
        .map((r) => TopupRail.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
    final packs = (j['packages'] as List)
        .map((r) => TopupPackage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
    if (rails.length != 6 ||
        rails.map((r) => r.key).toSet().length != 6 ||
        packs.length != 2 ||
        packs.map((p) => p.packageId).toSet().length != 2) {
      throw const FormatException('充值配置缺项或重复');
    }
    final evm = rails
        .where((r) => r.network.evmId != null)
        .map((r) => r.recvAddress)
        .toSet();
    if (evm.length != 1) throw const FormatException('EVM收款账户不一致');
    packs.sort(
      (a, b) => a.packageId == b.packageId
          ? 0
          : a.packageId == 'pkg_10'
          ? -1
          : 1,
    );
    return TopupConfig(
      ready: j['ready'] as bool,
      rails: List.unmodifiable(rails),
      packages: List.unmodifiable(packs),
    );
  }
}

/// 一次点击固定币种、套餐和主网；本地订单冻结本次选择，不恢复或重付旧单。
class TopupSelection {
  factory TopupSelection({
    required String token,
    required TopupPackage package,
    required TopupNetwork network,
  }) {
    if (!allowedPair(token, network)) throw const FormatException('币种与网络不匹配');
    return TopupSelection._(token, package, network);
  }
  const TopupSelection._(this.token, this.package, this.network);
  final String token;
  final TopupPackage package;
  final TopupNetwork network;
  factory TopupSelection.fromPayment(
    TopupPayment payment,
    TopupConfig config,
  ) => TopupSelection(
    token: payment.token,
    package: config.packageById(payment.packageId),
    network: payment.network,
  );
  Map<String, String> toJson() => {
    'token': token,
    'package_id': package.packageId,
    'network': network.wire,
  };
  void validate(TopupConfig config, TopupContext payer) {
    if (payer.network != network) throw const FormatException('钱包网络与所选网络不一致');
    final rail = config.rail(token, network),
        current = config.packageById(package.packageId);
    if (package.coinFen != current.coinFen ||
        package.amount(rail) != current.amount(rail)) {
      throw const FormatException('充值报价已更新，请重新选择');
    }
  }
}

class TopupContext {
  const TopupContext(this.network, this.payer);
  final TopupNetwork network;
  final String payer;
  factory TopupContext.fromJson(Map<String, dynamic> j) {
    final n = TopupNetwork.parse(j['network']);
    final p = j['payer'];
    if (j['chain'] != n.caip2 || p is! String) {
      throw const FormatException('钱包上下文无效');
    }
    return TopupContext(n, n.address(p));
  }
}

/// 钱包点击创建的本地订单，付款前无服务端意图或链查询。
abstract final class TopupWallets {
  // 逐个接入钱包：本阶段只开放MetaMask，授权仍须严格匹配用户所选网络。
  static bool paymentReady(String walletId, TopupNetwork network) =>
      walletId == ids.first;
  static const ids = {
    'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96',
    'ef333840daf915aafdc4a004525502d6d49d77bd9c65e0642dbaefb3c2893bef',
    '4622a2b2d6af1c9844944291e5e7351a6aa24cd7b23099efac1b2fd875da31a0',
    '8a0ee50d1f22f6651afcae7eb4253e52a3310b90af5daef78a8c4929a9bb99d4',
    '971e689d0a5be527bac79629b4ee9b925e82208e5168b733496a09c0faed0709',
    'fd20dc426fb37566d803205b19bbc1d4096b248ac04548e3cfb6b3a38bd033aa',
  };
}

/// 签名前只持有内存报价和随机恢复凭据，不是数据库订单。
class TopupDraft {
  TopupDraft._(this.fields, this.recoveryToken);
  final Map<String, Object?> fields;
  final String recoveryToken;
  static const action = 18; // qr-protocol registry/actions.yaml 的 topup 公共动作码。
  factory TopupDraft.create(TopupSelection selection, String account) {
    final config = TopupConfig.local(),
        rail = config.rail(selection.token, selection.network),
        pack = config.packageById(selection.package.packageId);
    if (pack.coinFen != selection.package.coinFen ||
        pack.amount(rail) != selection.package.amount(rail)) {
      throw const FormatException('充值套餐与本地可信配置不一致');
    }
    return TopupDraft._(
      Map.unmodifiable({
        'account_id': targetAccount(account),
        'package_id': pack.packageId,
        'token': rail.token,
        'network': rail.network.wire,
        'asset': rail.asset,
        'recv_address': rail.recvAddress,
        'pay_amount': pack.amount(rail),
        'coin_fen': pack.coinFen,
        'config_hash': config.hash,
      }),
      randomTopupHex(32),
    );
  }
  String get signText => topupSignText(fields, recoveryToken);
}

String topupSignText(Map<String, Object?> fields, String recoveryToken) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(recoveryToken)) {
    throw const FormatException('恢复凭据格式无效');
  }
  return [
    'CitizenServe Topup',
    'service_origin=${TopupConfig.origin}',
    'chain_genesis_hash=${TopupConfig.genesis}',
    for (final key in const [
      'account_id',
      'package_id',
      'token',
      'network',
      'asset',
      'recv_address',
      'pay_amount',
      'coin_fen',
      'config_hash',
    ])
      '$key=${fields[key]}',
    'recovery_hash=${sha256.convert(utf8.encode(recoveryToken))}',
    '',
  ].join('\n');
}

Uint8List topupSignatureBytes(String signature) {
  if (!RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature)) {
    throw const FormatException('公民账户签名必须是原始64字节');
  }
  return Uint8List.fromList(
    List.generate(
      64,
      (i) => int.parse(signature.substring(2 + i * 2, 4 + i * 2), radix: 16),
    ),
  );
}

String topupBinding(String text, String signature) => sha256.convert([
  ...utf8.encode(text),
  ...topupSignatureBytes(signature),
]).toString();

class TopupPayment {
  const TopupPayment({
    required this.orderId,
    required this.accountId,
    required this.packageId,
    required this.token,
    required this.network,
    required this.asset,
    required this.recvAddress,
    required this.payAmount,
    required this.coinFen,
    required this.createdAt,
    required this.configHash,
  });
  final String orderId,
      accountId,
      packageId,
      token,
      asset,
      recvAddress,
      payAmount,
      coinFen,
      configHash;
  final TopupNetwork network;
  final int createdAt;
  factory TopupPayment.signed(TopupDraft draft, String signature, {int? now}) {
    final binding = topupBinding(draft.signText, signature);
    final payment = TopupPayment.fromJson({
      ...draft.fields,
      'order_id': 'top_${binding.substring(0, 32)}',
      'created_at': now ?? DateTime.now().millisecondsSinceEpoch,
    });
    payment.validateCatalog(TopupConfig.local());
    return payment;
  }
  Map<String, Object?> toJson() => {
    'order_id': orderId,
    'account_id': accountId,
    'package_id': packageId,
    'token': token,
    'network': network.wire,
    'asset': asset,
    'recv_address': recvAddress,
    'pay_amount': payAmount,
    'coin_fen': coinFen,
    'created_at': createdAt,
    'config_hash': configHash,
  };
  factory TopupPayment.fromJson(Map<String, dynamic> j) {
    exactTopupFields(j, const {
      'order_id',
      'account_id',
      'package_id',
      'token',
      'network',
      'asset',
      'recv_address',
      'pay_amount',
      'coin_fen',
      'created_at',
      'config_hash',
    });
    final n = TopupNetwork.parse(j['network']);
    final token = j['token'];
    if (token is! String ||
        !allowedPair(token, n) ||
        j['created_at'] is! int ||
        (j['created_at'] as int) <= 0 ||
        j['config_hash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(j['config_hash'] as String)) {
      throw const FormatException('本地充值订单字段无效');
    }
    final asset = j['asset'] as String, recv = j['recv_address'] as String;
    if (n.address(asset) != asset || n.address(recv) != recv) {
      throw const FormatException('付款地址未规范化');
    }
    return TopupPayment(
      orderId: validateOrderId(j['order_id'] as String),
      accountId: targetAccount(j['account_id'] as String),
      packageId: j['package_id'] as String,
      token: token,
      network: n,
      asset: asset,
      recvAddress: recv,
      payAmount: decimal(j['pay_amount']),
      coinFen: decimal(j['coin_fen']),
      createdAt: j['created_at'] as int,
      configHash: j['config_hash'] as String,
    );
  }
  void validateCatalog(TopupConfig catalog) {
    final rail = catalog.rail(token, network),
        package = catalog.packageById(packageId);
    if (catalog.hash != configHash ||
        rail.asset != asset ||
        rail.recvAddress != recvAddress ||
        package.amount(rail) != payAmount ||
        package.coinFen != coinFen) {
      throw const FormatException('订单与可信付款配置不一致');
    }
  }
}

/// 仅由原生付款网络核验返回；回跳、JS布尔值和交易哈希不能替代证据。
class TopupProof {
  const TopupProof._(
    this.network,
    this.txid,
    this.payer,
    this.asset,
    this.receiver,
    this.amount,
    this.blockHash,
    this.blockNumber,
    this.blockAt,
    this.transferIndex,
    this.checkedAt,
    this.binding,
  );
  final TopupNetwork network;
  final String txid, payer, asset, receiver, amount, blockHash, binding;
  final int blockNumber, blockAt, transferIndex, checkedAt;
  Map<String, Object?> toJson() => {
    'binding_hash': binding,
    'network': network.wire,
    'payment_txid': txid,
    'payer_address': payer,
    'asset': asset,
    'recv_address': receiver,
    'pay_amount': amount,
    'block_hash': blockHash,
    'block_number': blockNumber,
    'block_at': blockAt,
    'transfer_index': transferIndex,
    'checked_at': checkedAt,
    'finalized': true,
    'succeeded': true,
  };
  factory TopupProof.fromJson(Map<String, dynamic> j) {
    exactTopupFields(j, const {
      'binding_hash',
      'network',
      'payment_txid',
      'payer_address',
      'asset',
      'recv_address',
      'pay_amount',
      'block_hash',
      'block_number',
      'block_at',
      'transfer_index',
      'checked_at',
      'finalized',
      'succeeded',
    });
    final n = TopupNetwork.parse(j['network']);
    final tx = j['payment_txid'] as String, bh = j['block_hash'] as String;
    if (j['binding_hash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(j['binding_hash'] as String) ||
        !n.transaction(tx) ||
        j['finalized'] != true ||
        j['succeeded'] != true ||
        j['block_number'] is! int ||
        (j['block_number'] as int) < 0 ||
        j['block_at'] is! int ||
        (j['block_at'] as int) <= 0 ||
        j['checked_at'] is! int ||
        (j['checked_at'] as int) < (j['block_at'] as int) ||
        j['transfer_index'] is! int ||
        (j['transfer_index'] as int) < 0 ||
        (n == TopupNetwork.solana
            ? !_base58Length(bh, 32)
            : !RegExp(
                n == TopupNetwork.tron
                    ? r'^[0-9a-f]{64}$'
                    : r'^0x[0-9a-f]{64}$',
              ).hasMatch(bh))) {
      throw const FormatException('付款证据未最终成功或定位不完整');
    }
    return TopupProof._(
      n,
      tx,
      n.address(j['payer_address'] as String),
      n.address(j['asset'] as String),
      n.address(j['recv_address'] as String),
      decimal(j['pay_amount']),
      bh,
      j['block_number'] as int,
      j['block_at'] as int,
      j['transfer_index'] as int,
      j['checked_at'] as int,
      j['binding_hash'] as String,
    );
  }
  bool matches(TopupPayment payment, String payer, String tx) =>
      network == payment.network &&
      txid == tx &&
      this.payer == payer &&
      asset == payment.asset &&
      receiver == payment.recvAddress &&
      amount == payment.payAmount &&
      blockAt >= payment.createdAt ~/ 1000 * 1000;
}

String randomTopupHex(int length) => List.generate(
  length,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
void exactTopupFields(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException('充值字段不完整或包含未知字段');
  }
}

/// 客户端公开节点只用于构造和广播U交易，不是服务端验款或NRC秘密端点。
abstract final class TopupRpcConfig {
  // 与服务端相同的唯一公开入口；不读取环境变量、节点Key或自定义URL。
  static const ethereum = 'https://ethereum-rpc.publicnode.com';
  static const base = 'https://mainnet.base.org';
  static const bnb = 'https://bsc-dataseed.bnbchain.org';
  static const tron = 'https://tron-rpc.publicnode.com';
  static const solana = 'https://api.mainnet.solana.com';
  static String endpoint(TopupNetwork network) => switch (network) {
    TopupNetwork.ethereum => ethereum,
    TopupNetwork.base => base,
    TopupNetwork.bnb => bnb,
    TopupNetwork.tron => tron,
    TopupNetwork.solana => solana,
  };
  static String url(String value) {
    final u = Uri.tryParse(value);
    if (u == null ||
        u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        u.hasQuery ||
        u.hasFragment) {
      throw const FormatException('付款网络尚未配置');
    }
    return u.toString();
  }
}

String topupOrigin(String origin) =>
    Uri.parse(CitizenServeApiConfig.normalize('$origin/api')).origin;

/// 付款后的HTTPS受理快照；保存服务身份，不把未经签名验真的结果当到账。
class TopupReceipt {
  TopupReceipt._(this._data);
  final Map<String, dynamic> _data;
  String get orderId => _data['order_id'] as String;
  String get paymentTxid => _data['payment_txid'] as String;
  String get coinFen => _data['coin_fen'] as String;
  String get publicKey => _data['result_publickey'] as String;
  int get revision => _data['order_rev'] as int;
  String get state => _data['order_state'] as String;
  String? get reason => _data['exception_reason'] as String?;
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
  factory TopupReceipt.fromJson(Map<String, dynamic> value) {
    exactTopupFields(value, const {
      'is_ok',
      'order_id',
      'order_rev',
      'order_state',
      'payment_txid',
      'gmb_tx_hash',
      'coin_fen',
      'exception_reason',
      'is_reused',
      'auto_final',
      'chain_state',
      'result_ack',
      'result_publickey',
      'result',
      'result_signature',
    });
    const states = {
          'verifying',
          'received',
          'signed',
          'broadcast',
          'paid',
          'exception',
        },
        chainStates = {'unverified', 'finalized_success', 'finalized_failed'};
    final state = value['order_state'],
        result = value['result'],
        signature = value['result_signature'];
    if (value['is_ok'] != true ||
        !states.contains(state) ||
        !chainStates.contains(value['chain_state']) ||
        value['order_rev'] is! int ||
        (value['order_rev'] as int) < 0 ||
        value['is_reused'] is! bool ||
        value['result_ack'] is! bool ||
        value['auto_final'] != (state == 'paid' || state == 'exception') ||
        value['result_publickey'] is! String ||
        !RegExp(
          r'^0x[0-9a-f]{64}$',
        ).hasMatch(value['result_publickey'] as String) ||
        value['payment_txid'] is! String ||
        value['gmb_tx_hash'] != null &&
            (value['gmb_tx_hash'] is! String ||
                !RegExp(
                  r'^0x[0-9a-f]{64}$',
                ).hasMatch(value['gmb_tx_hash'] as String)) ||
        value['exception_reason'] != null &&
            value['exception_reason'] is! String ||
        (result == null) != (signature == null)) {
      throw const FormatException('发币受理快照无效');
    }
    validateOrderId(value['order_id'] as String);
    decimal(value['coin_fen']);
    if (result != null) {
      if (result is! Map<String, dynamic> ||
          signature is! String ||
          !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature)) {
        throw const FormatException('服务端结果封存结构无效');
      }
      exactTopupFields(result, const {
        'service_origin',
        'order_id',
        'result_rev',
        'account_id',
        'payment_txid',
        'gmb_tx_hash',
        'coin_fen',
        'order_state',
        'chain_state',
        'exception_reason',
        'finished_at',
      });
      if (result['service_origin'] != TopupConfig.origin ||
          result['order_id'] != value['order_id'] ||
          result['result_rev'] != value['order_rev'] ||
          result['payment_txid'] != value['payment_txid'] ||
          result['gmb_tx_hash'] != value['gmb_tx_hash'] ||
          result['coin_fen'] != value['coin_fen'] ||
          result['order_state'] != state ||
          result['chain_state'] != value['chain_state'] ||
          result['exception_reason'] != value['exception_reason'] ||
          result['finished_at'] is! int ||
          (result['finished_at'] as int) <= 0 ||
          !const {'paid', 'exception'}.contains(state)) {
        throw const FormatException('结果与原受理快照不一致');
      }
      targetAccount(result['account_id'] as String);
    }
    return TopupReceipt._(
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );
  }
  void matches(TopupPayment payment, String txid) {
    if (orderId != payment.orderId ||
        paymentTxid != txid ||
        coinFen != payment.coinFen ||
        _data['result'] != null &&
            (_data['result'] as Map)['account_id'] != payment.accountId) {
      throw const FormatException('服务端回执不属于原已支付订单');
    }
  }

  bool get sealed => _data['result'] != null;
  bool get acknowledged => _data['result_ack'] == true;
  String? get gmbTxHash => _data['gmb_tx_hash'] as String?;
  String? get resultSignature => _data['result_signature'] as String?;
  String get signedText {
    if (!sealed) throw StateError('结果尚未封存');
    final result = _data['result'] as Map;
    return [
      'CitizenServe Topup Result',
      for (final key in const [
        'service_origin',
        'order_id',
        'result_rev',
        'account_id',
        'payment_txid',
        'gmb_tx_hash',
        'coin_fen',
        'order_state',
        'chain_state',
        'exception_reason',
        'finished_at',
      ])
        '$key=${result[key] ?? ''}',
      '',
    ].join('\n');
  }

  bool sameResult(TopupReceipt other) =>
      sealed &&
      other.sealed &&
      signedText == other.signedText &&
      resultSignature == other.resultSignature;
  Future<VerifiedTopupReceipt> verify(TopupPayment payment, String txid) async {
    matches(payment, txid);
    if (!sealed ||
        state == 'paid' &&
            (_data['chain_state'] != 'finalized_success' ||
                gmbTxHash == null) ||
        state == 'exception' && _data['chain_state'] == 'finalized_success') {
      throw const FormatException('结果没有明确最终执行事实');
    }
    final signature = resultSignature!;
    final valid = await CitizenSdk.verify(
      accountId: publicKey,
      signature: Uint8List.fromList(
        List.generate(
          64,
          (i) =>
              int.parse(signature.substring(2 + i * 2, 4 + i * 2), radix: 16),
        ),
      ),
      payload: Uint8List.fromList(utf8.encode(signedText)),
    );
    if (!valid) throw const FormatException('服务端结果签名无效');
    return VerifiedTopupReceipt._(this);
  }

  factory TopupReceipt.notification(
    Map<String, dynamic> payload,
    TopupReceipt prior,
  ) {
    exactTopupFields(payload, const {'kind', 'result', 'result_signature'});
    if (payload['kind'] != 'topup_result' ||
        payload['result'] is! Map<String, dynamic>) {
      throw const FormatException('充值通知无效');
    }
    final result = payload['result'] as Map<String, dynamic>;
    return TopupReceipt.fromJson({
      ...prior.toJson(),
      'order_rev': result['result_rev'],
      'order_state': result['order_state'],
      'payment_txid': result['payment_txid'],
      'gmb_tx_hash': result['gmb_tx_hash'],
      'coin_fen': result['coin_fen'],
      'exception_reason': result['exception_reason'],
      'auto_final': true,
      'chain_state': result['chain_state'],
      'result_ack': prior.acknowledged,
      'result': result,
      'result_signature': payload['result_signature'],
    });
  }
  String get message => state == 'exception'
      ? '充值处理异常，请核实原订单'
      : state == 'paid'
      ? '服务端已发回完成结果'
      : '发币请求已受理，等待完成结果';
}

/// 只能由现有SDK纯验签生成，不能由推送布尔值或外部JSON构造。
class VerifiedTopupReceipt {
  const VerifiedTopupReceipt._(this.receipt);
  final TopupReceipt receipt;
}
