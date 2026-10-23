import 'package:citizenapp/network/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:citizenapp/network/square_api_client.dart' show SquareApiConfig;

import 'topup_models.dart';

/// 稳定币充值 Worker 客户端(/topup/*)。
///
/// 充值 = 付款人自掏稳定币给某个公民链账户打公民币,收款方无需证明账户所有权(同转账),
/// 故全程不带广场会话：充值目标由 `account_id` 直接指定，任意钱包账户（含冷钱包、
/// 含他人账户）均可作目标。Worker 从 finalized 链双向绑定自行确定目标当时是否归属
/// 某个 `cid_number`，客户端不得自行声明身份归属；付款鉴权由 WalletConnect 完成。
/// confirm / status 凭 Worker 用 HMAC 签发的付款意图自证(不可伪造,内部钉死付款人、
/// 收款地址、金额、目标账户与签发时间)。
class TopupApiException implements Exception {
  const TopupApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}

class TopupApi {
  TopupApi({String? baseUrl, http.Client? httpClient})
    : baseUrl = SquareApiConfig.normalizeBaseUrl(
        baseUrl ?? SquareApiConfig.defaultBaseUrl,
      ),
      _http = HttpsOnlyClient(httpClient ?? http.Client());

  final String baseUrl;
  final http.Client _http;
  Future<TopupConfig> fetchConfig() async =>
      TopupConfig.fromJson(await _getJson('/topup/config'));
  Future<TopupPaymentIntent> createIntent({
    required String token,
    required String packageId,
    required String accountId,
    required TopupContext payer,
  }) async {
    targetAccount(accountId);
    return TopupPaymentIntent.fromJson(
      await _postJson('/topup/intent', {
        'account_id': accountId,
        'token': token,
        'package_id': packageId,
        'network': payer.network.wire,
        'payer_address': payer.payer,
      }),
    );
  }

  Future<TopupOrder> confirm({
    required TopupPaymentIntent intent,
    required String paymentTxid,
    required String payerSignature,
  }) async {
    intent.network.signature(payerSignature);
    if (!intent.network.transaction(paymentTxid))
      throw const FormatException('原付款交易定位无效');
    return _order(
      await _postJson('/topup/confirm', {
        'payment_intent': intent.token,
        'payment_txid': paymentTxid,
        'payer_signature': payerSignature,
      }),
      intent,
    );
  }

  Future<TopupOrder> status(TopupPaymentIntent intent) async => _order(
    await _postJson('/topup/status', {
      'order_id': intent.order,
      'payment_intent': intent.token,
    }),
    intent,
  );
  TopupOrder _order(Map<String, dynamic> data, TopupPaymentIntent intent) {
    final order = TopupOrder.fromJson(data);
    if (order.id != intent.order ||
        order.coinFen != intent.coinFen ||
        order.paymentTxid != null &&
            !intent.network.transaction(order.paymentTxid!))
      throw const FormatException('订单与充值目标不一致');
    return order;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {'content-type': 'application/json; charset=utf-8'},
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw TopupApiException(
        '充值服务响应不是 JSON：${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw TopupApiException(
        '充值服务响应结构不合法：${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TopupApiException(
        '充值服务请求失败，请稍后核实原订单',
        statusCode: response.statusCode,
        errorCode: decoded['error']?.toString(),
      );
    }
    return decoded;
  }

  void close() => _http.close();
}
