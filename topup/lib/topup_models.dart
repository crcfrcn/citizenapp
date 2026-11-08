import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart'
    show CitizenSdk, isCitizenAccountId, scaleTokenUnits;

import 'package:crypto/crypto.dart';
import 'package:citizen_network/citizen_serve_api_config.dart';

/// 精确主网标识；会话批准的链列表不等于钱包的本次付款网络。
enum TopupNetwork {
  ethereum('ethereum', 'eip155:1', 1),
  base('base', 'eip155:8453', 8453),
  bnb('bnb', 'eip155:56', 56);

  const TopupNetwork(this.wire, this.caip2, this.evmId);
  final String wire, caip2;
  final int evmId;
  String get label => switch (this) {
    ethereum => 'Ethereum/以太坊链',
    base => 'Base/贝斯链',
    bnb => 'BNB/币安链',
  };
  static TopupNetwork parse(Object? value) => values.firstWhere(
    (n) => n.wire == value,
    orElse: () => throw const FormatException('不支持的付款网络'),
  );
  String address(String value) {
    final v = value.toLowerCase();
    if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(v) || v == '0x${'0' * 40}') {
      throw const FormatException('EVM地址无效');
    }
    return v;
  }

  bool transaction(String value) => RegExp(r'^0x[0-9a-f]{64}$').hasMatch(value);
}

String decimal(Object? value) {
  if (value is! String || !RegExp(r'^[1-9][0-9]{0,77}$').hasMatch(value)) {
    throw const FormatException('金额必须为正整数文本');
  }
  return value;
}

String targetAccount(String value) {
  if (!isCitizenAccountId(value)) {
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

bool allowedPair(String token, TopupNetwork network) =>
    const ['USDC', 'USDT'].contains(token);

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
    if (id != 'pkg_10' && id != 'pkg_1000') {
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
      final expected = scaleTokenUnits(
        BigInt.from(id == 'pkg_10' ? 10 : 1000),
        n == TopupNetwork.bnb ? 18 : 6,
      );
      if (a != expected.toString()) throw const FormatException('套餐金额无效');
      amounts[key] = a;
    }
    if (amounts.length != 6 ||
        j['pay_display'] != (id == 'pkg_10' ? '10' : '1000') ||
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
        network: TopupNetwork.bnb,
        asset: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
        decimals: 18,
        recvAddress: evm,
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
        network: TopupNetwork.base,
        asset: '0xfde4c96c8593536e31f229ea8f37b2ada2699bb2',
        decimals: 6,
        recvAddress: evm,
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
        for (final amount in [10, 1000])
          TopupPackage(
            packageId: 'pkg_$amount',
            payDisplay: '$amount',
            coinDisplay: amount == 10 ? '10,000.00' : '1,000,000.00',
            coinFen: amount == 10 ? '1000000' : '100000000',
            payments: Map.unmodifiable({
              for (final rail in rails)
                rail.key: scaleTokenUnits(
                  BigInt.from(amount),
                  rail.decimals,
                ).toString(),
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
        TopupNetwork.bnb,
      ]) {
        if (!allowedPair(token, network)) continue;
        final value = rail(token, network);
        lines.add(
          'rail=${value.token}|${value.network.wire}|${value.asset}|${value.decimals}|${value.recvAddress}',
        );
        for (final id in const ['pkg_10', 'pkg_1000']) {
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
    final evm = rails.map((r) => r.recvAddress).toSet();
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
}

/// 充值固定使用MetaMask；标识只用于本地订单，图标不承担付款选择。
abstract final class TopupWallet {
  static const id = 'metamask';
  // MetaMask官方扩展app/images/logo/metamask-fox.svg，随包绘制，不请求远程图片。
  static const logo = r'''<svg width="35" height="34" viewBox="0 0 35 34" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M32.7077 32.7522L25.1688 30.5174L19.4833 33.9008L15.5167 33.8991L9.82793 30.5174L2.29225 32.7522L0 25.0489L2.29225 16.4993L0 9.27094L2.29225 0.312256L14.0674 7.31554H20.9326L32.7077 0.312256L35 9.27094L32.7077 16.4993L35 25.0489L32.7077 32.7522Z" fill="#FF5C16"/>
<path d="M2.29395 0.312256L14.0691 7.32047L13.6008 12.1301L2.29395 0.312256Z" fill="#FF5C16"/>
<path d="M9.82959 25.0522L15.0106 28.9811L9.82959 30.5175V25.0522Z" fill="#FF5C16"/>
<path d="M14.5966 18.5565L13.6009 12.1333L7.22692 16.5009L7.22363 16.4993V16.5025L7.24335 20.9983L9.82809 18.5565H9.82974H14.5966Z" fill="#FF5C16"/>
<path d="M32.7077 0.312256L20.9326 7.32047L21.3993 12.1301L32.7077 0.312256Z" fill="#FF5C16"/>
<path d="M25.1722 25.0522L19.9912 28.9811L25.1722 30.5175V25.0522Z" fill="#FF5C16"/>
<path d="M27.7766 16.5025H27.7783H27.7766V16.4993L27.775 16.5009L21.401 12.1333L20.4053 18.5565H25.1722L27.7586 20.9983L27.7766 16.5025Z" fill="#FF5C16"/>
<path d="M9.82793 30.5175L2.29225 32.7522L0 25.0522H9.82793V30.5175Z" fill="#E34807"/>
<path d="M14.5947 18.5549L16.0341 27.8406L14.0393 22.6777L7.23975 20.9984L9.82613 18.5549H14.593H14.5947Z" fill="#E34807"/>
<path d="M25.1721 30.5175L32.7078 32.7522L35.0001 25.0522H25.1721V30.5175Z" fill="#E34807"/>
<path d="M20.4053 18.5549L18.9658 27.8406L20.9607 22.6777L27.7602 20.9984L25.1722 18.5549H20.4053Z" fill="#E34807"/>
<path d="M0 25.0488L2.29225 16.4993H7.22183L7.23991 20.9967L14.0394 22.676L16.0343 27.8389L15.0089 28.976L9.82793 25.0472H0V25.0488Z" fill="#FF8D5D"/>
<path d="M35.0001 25.0488L32.7078 16.4993H27.7783L27.7602 20.9967L20.9607 22.676L18.9658 27.8389L19.9912 28.976L25.1722 25.0472H35.0001V25.0488Z" fill="#FF8D5D"/>
<path d="M20.9325 7.31543H17.4999H14.0673L13.6006 12.1251L16.0342 27.834H18.9656L21.4008 12.1251L20.9325 7.31543Z" fill="#FF8D5D"/>
<path d="M2.29225 0.312256L0 9.27094L2.29225 16.4993H7.22183L13.5991 12.1301L2.29225 0.312256Z" fill="#661800"/>
<path d="M13.17 20.4199H10.9369L9.72095 21.6062L14.0409 22.6727L13.17 20.4182V20.4199Z" fill="#661800"/>
<path d="M32.7077 0.312256L34.9999 9.27094L32.7077 16.4993H27.7781L21.4009 12.1301L32.7077 0.312256Z" fill="#661800"/>
<path d="M21.833 20.4199H24.0694L25.2853 21.6079L20.9604 22.676L21.833 20.4182V20.4199Z" fill="#661800"/>
<path d="M19.4817 30.8362L19.9911 28.9794L18.9658 27.8423H16.0327L15.0073 28.9794L15.5167 30.8362" fill="#661800"/>
<path d="M19.4816 30.8359V33.9021H15.5166V30.8359H19.4816Z" fill="#C0C4CD"/>
<path d="M9.82959 30.5142L15.52 33.9008V30.8346L15.0106 28.9778L9.82959 30.5142Z" fill="#E7EBF6"/>
<path d="M25.1721 30.5142L19.4817 33.9008V30.8346L19.9911 28.9778L25.1721 30.5142Z" fill="#E7EBF6"/>
</svg>''';
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
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(bh)) {
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
  static String endpoint(TopupNetwork network) => switch (network) {
    TopupNetwork.ethereum => ethereum,
    TopupNetwork.base => base,
    TopupNetwork.bnb => bnb,
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
        !RegExp(r'^0x[0-9a-f]{64}$')
            .hasMatch(value['result_publickey'] as String) ||
        value['payment_txid'] is! String ||
        value['gmb_tx_hash'] != null &&
            (value['gmb_tx_hash'] is! String ||
                !RegExp(r'^0x[0-9a-f]{64}$')
                    .hasMatch(value['gmb_tx_hash'] as String)) ||
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
