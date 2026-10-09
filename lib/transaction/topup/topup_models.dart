import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:citizenapp/security/citizen_serve_api_config.dart';

// 稳定币充值购买公民币 · 数据模型(与 Worker /topup/* 对齐)。

/// 一条「币 + 链」入金轨(由 Worker config 下发,App 不写死合约)。
class TopupRail {
  const TopupRail({
    required this.token,
    required this.chainId,
    required this.tokenContract,
    required this.tokenDecimals,
    required this.label,
  });

  final String token; // 'USDC' | 'USDT'
  final int chainId;
  final String tokenContract;
  final int tokenDecimals;
  final String label;

  factory TopupRail.fromJson(Map<String, dynamic> json) {
    return TopupRail(
      token: json['token']?.toString() ?? '',
      chainId: _asInt(json['chain_id']),
      tokenContract: json['token_contract']?.toString() ?? '',
      tokenDecimals: _asInt(json['token_decimals']),
      label: json['label']?.toString() ?? '',
    );
  }

  /// WalletConnect 链标识(eip155:{chainId})。
  String get caip2 => 'eip155:$chainId';
}

/// 充值套餐:pay_amount=应付稳定币最小单位(字符串,防溢出);coin_fen=应发公民币分额。
class TopupPackage {
  const TopupPackage({
    required this.packageId,
    required this.payDisplay,
    required this.payAmount,
    required this.coinDisplay,
    required this.coinFen,
  });

  final String packageId;
  final String payDisplay;
  final String payAmount;
  final String coinDisplay;
  final String coinFen;

  BigInt get payAmountValue => BigInt.tryParse(payAmount) ?? BigInt.zero;

  factory TopupPackage.fromJson(Map<String, dynamic> json) {
    return TopupPackage(
      packageId: json['package_id']?.toString() ?? '',
      payDisplay: json['pay_display']?.toString() ?? '',
      payAmount: json['pay_amount']?.toString() ?? '0',
      coinDisplay: json['coin_display']?.toString() ?? '',
      coinFen: json['coin_fen']?.toString() ?? '0',
    );
  }
}

/// GET /topup/config 响应。
class TopupConfig {
  const TopupConfig({
    required this.network,
    required this.recvAddress,
    required this.rails,
    required this.packages,
  });

  final String network;
  final String recvAddress;
  final List<TopupRail> rails;
  final List<TopupPackage> packages;

  factory TopupConfig.fromJson(Map<String, dynamic> json) {
    final rails = json['rails'];
    final packages = json['packages'];
    return TopupConfig(
      network: json['network']?.toString() ?? '',
      recvAddress: json['recv_address']?.toString() ?? '',
      rails: rails is List
          ? rails
                .whereType<Map<String, dynamic>>()
                .map(TopupRail.fromJson)
                .toList(growable: false)
          : const <TopupRail>[],
      packages: packages is List
          ? packages
                .whereType<Map<String, dynamic>>()
                .map(TopupPackage.fromJson)
                .toList(growable: false)
          : const <TopupPackage>[],
    );
  }
}

/// 订单状态:pending=待支付 / paid=已支付 / exception=异常;
/// confirming/notFound 是轮询过渡响应,不是台账业务态。
enum TopupOrderStatus {
  confirming,
  pending,
  paid,
  exception,
  notFound,
  unknown,
}

TopupOrderStatus topupOrderStatusFrom(String? raw) {
  switch (raw) {
    case 'confirming':
      return TopupOrderStatus.confirming;
    case 'pending':
      return TopupOrderStatus.pending;
    case 'paid':
      return TopupOrderStatus.paid;
    case 'exception':
      return TopupOrderStatus.exception;
    case 'not_found':
      return TopupOrderStatus.notFound;
    default:
      return TopupOrderStatus.unknown;
  }
}

/// POST /topup/intent 结果。令牌把登录账户、付款地址和报价绑定到同一个短期意图。
class TopupPaymentIntent {
  const TopupPaymentIntent({
    required this.token,
    required this.expiresAt,
    this.intent = const {},
    this.authorizationMessage = '',
  });

  final String token;
  final int expiresAt;
  final Map<String, dynamic> intent;
  final String authorizationMessage;

  factory TopupPaymentIntent.fromJson(Map<String, dynamic> json) {
    if (json['intent'] is! Map<String, dynamic> ||
        json['payment_intent'] is! String ||
        json['wallet_authorization_message'] is! String) {
      throw const FormatException('付款意图响应无效');
    }
    final intent = json['intent'] as Map<String, dynamic>;
    return TopupPaymentIntent(
      token: json['payment_intent'] as String,
      expiresAt: _asInt(intent['expires_at']),
      intent: Map.unmodifiable(intent),
      authorizationMessage: json['wallet_authorization_message'] as String,
    );
  }

  void validatePayment({
    required TopupRail rail,
    required TopupPackage package,
    required String accountId,
    required String payerAddress,
    required String recvAddress,
    required String chainGenesisHash,
    String? serviceOrigin,
    int? now,
  }) {
    const fields = {
      'intent_id',
      'cid_number',
      'account_id',
      'payer_address',
      'token',
      'package_id',
      'chain_id',
      'token_contract',
      'recv_address',
      'pay_amount',
      'coin_fen',
      'issued_at',
      'expires_at',
    };
    final issued = intent['issued_at'];
    if (token.length > 8192 ||
        intent.length != fields.length ||
        !intent.keys.every(fields.contains) ||
        intent['account_id'] != accountId ||
        intent['payer_address'] != payerAddress.toLowerCase() ||
        intent['token'] != rail.token ||
        intent['package_id'] != package.packageId ||
        intent['chain_id'] != rail.chainId ||
        intent['token_contract'] != rail.tokenContract.toLowerCase() ||
        intent['recv_address'] != recvAddress.toLowerCase() ||
        intent['pay_amount'] != package.payAmount ||
        intent['coin_fen'] != package.coinFen ||
        issued is! int ||
        issued > (now ?? DateTime.now().millisecondsSinceEpoch) ||
        expiresAt - issued != 600000 ||
        expiresAt <= (now ?? DateTime.now().millisecondsSinceEpoch) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainGenesisHash)) {
      throw const FormatException('付款意图与本次充值不一致或过期');
    }
    final parts = token.split('.');
    if (parts.length != 2 ||
        jsonEncode(
              jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
              ),
            ) !=
            jsonEncode(intent)) {
      throw const FormatException('付款意图原文不一致');
    }
    final origin =
        serviceOrigin ?? Uri.parse(CitizenServeApiConfig.baseUrl).origin;
    final expected =
        'CitizenServe Topup v1\nservice_origin=$origin\nchain_genesis_hash=$chainGenesisHash\n'
        'intent_id=${intent['intent_id']}\nchain_id=${intent['chain_id']}\npayer_address=${intent['payer_address']}\n'
        'token_contract=${intent['token_contract']}\nrecv_address=${intent['recv_address']}\npay_amount=${intent['pay_amount']}\n'
        'coin_fen=${intent['coin_fen']}\naccount_id=${intent['account_id']}\npackage_id=${intent['package_id']}\n'
        'issued_at=${intent['issued_at']}\nexpires_at=${intent['expires_at']}\nintent_sha256=${sha256.convert(utf8.encode(token))}\n';
    if (authorizationMessage != expected) {
      throw const FormatException('付款授权文本与固定意图不一致');
    }
  }
}

/// POST /topup/confirm 结果。
class TopupConfirmResult {
  const TopupConfirmResult({required this.status, this.orderId});

  final TopupOrderStatus status;
  final String? orderId;

  factory TopupConfirmResult.fromJson(Map<String, dynamic> json) {
    return TopupConfirmResult(
      status: topupOrderStatusFrom(json['status']?.toString()),
      orderId: json['order_id']?.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
