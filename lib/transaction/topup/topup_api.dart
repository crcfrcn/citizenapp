import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citizenapp/app_log.dart';
import 'package:citizenapp/network/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'package:http/http.dart' as http;

import 'package:citizenapp/network/square_api_client.dart' show SquareApiConfig;

import 'topup_models.dart';

/// 稳定币充值 Worker 客户端(/topup/*)。
///
/// 充值 = 付款人自掏稳定币给某个公民链账户打公民币,收款方无需证明账户所有权(同转账),
/// 故全程不带广场会话：充值目标由 `account_id` 直接指定，任意钱包账户（含冷钱包、
/// 含他人账户）均可作目标。Worker 从 finalized 链双向绑定自行确定目标当时是否归属
/// 某个 `cid_number`，客户端不得自行声明身份归属；付款鉴权由 WalletConnect 完成。
/// confirm / status 由服务端对照已存原始意图和能力凭据，固定付款人、地址和金额；
/// App不持有签发秘密，不能只凭本地恢复记录决定向旧地址继续付款。
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

  /// 配置失败仅记录真实HTTP及闭集结构类别；诊断不创建意图或改变原单。
  Future<TopupConfig> fetchConfig() async {
    int? status;
    try {
      final response = await _http
          .get(
            Uri.parse('$baseUrl/topup/config'),
            headers: {'content-type': 'application/json; charset=utf-8'},
          )
          .timeout(const Duration(seconds: 20));
      status = response.statusCode;
      return TopupConfig.fromJson(_decode(response, '/topup/config'));
    } on Object catch (error) {
      AppLog.failure(
        stage: 'topup_config',
        statusCode: status,
        code: switch (error) {
          TopupApiException() => error.errorCode ?? 'response_invalid',
          SocketException() ||
          TimeoutException() ||
          http.ClientException() => 'network_unavailable',
          FormatException() => 'format',
          TypeError() => 'type',
          StateError() => 'state',
          _ => null,
        },
      );
      rethrow;
    }
  }

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

  /// 钱包确认账户后才取得新配置；原单必须先查证，随后才允许使用原地址。
  Future<({TopupRail rail, TopupPaymentIntent intent})> preparePayment({
    required TopupSelection selection,
    required String accountId,
    required TopupContext payer,
    required String chainGenesisHash,
    TopupPaymentIntent? original,
    bool Function()? isActive,
    int? now,
  }) async {
    void active() {
      if (isActive != null && !isActive()) {
        throw const TopupApiException('本次付款已取消');
      }
    }

    active();
    if (payer.network != selection.network) {
      throw const FormatException('钱包网络与所选网络不一致');
    }
    final config = await fetchConfig();
    active();
    if (!config.ready) throw const TopupApiException('充值暂未开放，未发起付款');
    selection.validate(config, payer);
    var rail = config.rail(selection.token, selection.network);
    final TopupPaymentIntent intent;
    if (original == null) {
      intent = await createIntent(
        token: selection.token,
        packageId: selection.package.packageId,
        accountId: accountId,
        payer: payer,
      );
    } else {
      if (original.accountId != accountId ||
          original.payer != payer.payer ||
          original.network != selection.network ||
          original.intent['token'] != selection.token ||
          original.intent['package_id'] != selection.package.packageId) {
        throw const FormatException('原订单与本次选择不一致');
      }
      final order = await status(original);
      active();
      if (order.phase != TopupPhase.awaiting ||
          order.terminal ||
          order.paymentTxid != null) {
        throw const TopupApiException('原订单已有付款进度，请返回查询原订单');
      }
      intent = original;
      rail = TopupRail(
        token: rail.token,
        network: rail.network,
        asset: rail.asset,
        decimals: rail.decimals,
        recvAddress: original.intent['recv_address'] as String,
      );
    }
    active();
    intent.validatePayment(
      rail: rail,
      package: selection.package,
      accountId: accountId,
      payerAddress: payer.payer,
      chainGenesisHash: chainGenesisHash,
      serviceOrigin: topupOrigin(baseUrl),
      now: now,
    );
    return (rail: rail, intent: intent);
  }

  /// 续播不重签；先确认服务端仍在等待同笔付款，再允许广播保护记录中的原字节。
  Future<void> authorizeReplay({
    required TopupPaymentIntent intent,
    required String txid,
    required TopupSelection selection,
    required String accountId,
    bool Function()? isActive,
    int? now,
  }) async {
    void active() {
      if (isActive != null && !isActive()) {
        throw const TopupApiException('本次付款已取消');
      }
    }

    active();
    if (intent.accountId != accountId ||
        intent.network != selection.network ||
        intent.intent['token'] != selection.token ||
        intent.intent['package_id'] != selection.package.packageId ||
        intent.network.evmId != null ||
        !intent.network.transaction(txid)) {
      throw const FormatException('原交易与本次选择不一致');
    }
    final config = await fetchConfig();
    active();
    if (!config.ready) throw const TopupApiException('充值暂未开放，未继续广播');
    selection.validate(config, TopupContext(intent.network, intent.payer));
    final order = await status(intent);
    active();
    if (order.terminal ||
        !const [
          TopupPhase.awaiting,
          TopupPhase.verifying,
        ].contains(order.phase) ||
        order.paymentTxid != null && order.paymentTxid != txid) {
      throw const TopupApiException('原订单已有付款进度，请返回查询原订单');
    }
    if ((now ?? DateTime.now().millisecondsSinceEpoch) >= intent.expiresAt) {
      throw const TopupApiException('原交易已过期，未继续广播');
    }
  }

  Future<TopupOrder> confirm({
    required TopupPaymentIntent intent,
    required String paymentTxid,
    required String payerSignature,
  }) async {
    intent.network.signature(payerSignature);
    if (!intent.network.transaction(paymentTxid)) {
      throw const FormatException('原付款交易定位无效');
    }
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
            !intent.network.transaction(order.paymentTxid!)) {
      throw const FormatException('订单与充值目标不一致');
    }
    return order;
  }

  /// Solana只经现有原生HTTP访问固定官方入口，避免本地WebView的跨域限制。
  /// 广播只接受调用方已保存的原字节和原交易号；不接收URL、Key或任意RPC。
  Future<Object?> solanaRpc({
    required TopupPaymentIntent intent,
    required String method,
    required List<Object?> params,
    String? wire,
    String? txid,
    int? now,
    bool Function()? isActive,
  }) async {
    void active() {
      if (isActive != null && !isActive()) {
        throw const TopupApiException('本次付款已取消');
      }
    }

    bool options(Object? value, Map<String, Object> expected) =>
        value is Map &&
        value.length == expected.length &&
        expected.entries.every((entry) => value[entry.key] == entry.value);
    active();
    if (intent.network != TopupNetwork.solana ||
        (now ?? DateTime.now().millisecondsSinceEpoch) >= intent.expiresAt) {
      throw const FormatException('原Solana付款上下文无效或已过期');
    }
    final valid = switch (method) {
      'getGenesisHash' => params.isEmpty,
      'getLatestBlockhash' =>
        params.length == 1 && options(params[0], {'commitment': 'finalized'}),
      'sendTransaction' =>
        params.length == 2 &&
            wire != null &&
            wire.isNotEmpty &&
            wire.length <= 1644 &&
            params[0] == wire &&
            txid != null &&
            TopupNetwork.solana.transaction(txid) &&
            options(params[1], {
              'encoding': 'base64',
              'skipPreflight': false,
              'preflightCommitment': 'confirmed',
              'maxRetries': 3,
            }),
      _ => false,
    };
    if (!valid) {
      throw const FormatException('未允许的Solana付款节点请求');
    }
    if (method == 'sendTransaction') {
      final bytes = base64Decode(wire!);
      if (bytes.length <= 64 || bytes.length > 1232) {
        throw const FormatException('原Solana交易长度无效');
      }
    }
    const failure = TopupApiException('Solana节点结果待核实，请返回原订单，勿重复付款');
    try {
      final response = await _http
          .post(
            Uri.parse(TopupRpcConfig.solana),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': method,
              'params': params,
            }),
          )
          .timeout(const Duration(seconds: 15));
      active();
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 1024 * 1024) {
        throw failure;
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> ||
          value['jsonrpc'] != '2.0' ||
          value['id'] != 1 ||
          value.containsKey('error') ||
          !value.containsKey('result') ||
          method == 'sendTransaction' && value['result'] != txid) {
        throw failure;
      }
      return value['result'];
    } on TopupApiException {
      rethrow;
    } on Object {
      throw failure;
    }
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
    return _decode(response, path);
  }

  Map<String, dynamic> _decode(http.Response response, String path) {
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
      final code = decoded['error']?.toString();
      final creating = path == '/topup/intent';
      throw TopupApiException(
        creating
            ? switch (code) {
                'topup_network_unconfigured' => '所选网络尚未开放，未发起付款',
                'topup_unconfigured' ||
                'topup_intent_unconfigured' => '充值暂未开放，未发起付款',
                'topup_intent_expired' => '付款报价已过期，请返回重新选择',
                _ => '充值服务请求失败，请稍后核实原订单',
              }
            : path == '/topup/config'
            ? '充值服务暂不可用，请稍后重试'
            : '暂时无法核实原订单，请稍后重试，勿重复付款',
        statusCode: response.statusCode,
        errorCode: code,
      );
    }
    return decoded;
  }

  void close() => _http.close();
}
