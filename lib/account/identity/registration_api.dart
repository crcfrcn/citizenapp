import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:citizenapp/network/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'registration_models.dart';

/// 恢复秘密只出现在JSON正文；不记录原始服务器消息或带能力的URL。
class RegistrationApi {
  RegistrationApi({http.Client? client})
    : _http = HttpsOnlyClient(client ?? http.Client());
  final http.Client _http;
  Future<RegistrationResponse> prepare(RegistrationContext context) =>
      _post(context, '/user/registration', context.toJson(), initial: true);
  Future<RegistrationResponse> status(
    RegistrationContext context,
    RegistrationCapabilities cap, {
    String operation = 'read',
  }) {
    if (!{'read', 'refresh_verification', 'cancel'}.contains(operation)) {
      throw ArgumentError('登记操作无效');
    }
    return _post(context, '/user/registration/status', {
      ...cap.toJson(),
      'operation': operation,
    }, cap: cap);
  }

  Future<RegistrationResponse> verify(
    RegistrationContext context,
    RegistrationCapabilities cap, {
    required String checkId,
    required String token,
  }) => _post(context, '/user/registration/verify', {
    ...cap.toJson(),
    'check_id': checkId,
    'turnstile_token': token,
  }, cap: cap);
  Future<RegistrationResponse> _post(
    RegistrationContext context,
    String path,
    Map<String, Object?> body, {
    RegistrationCapabilities? cap,
    bool initial = false,
  }) async {
    final response = await _http
        .post(
          Uri.parse('${context.baseUrl}$path'),
          headers: {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != (initial ? 201 : 200)) {
      // 不展示可能含登记能力的服务端正文；按 HTTP 状态区分可操作原因。
      final reason = switch (response.statusCode) {
        400 => '注册信息无效，请核对所选钱包账户后重试',
        401 => '注册验证已失效，请重新进行真人验证',
        403 => '真人验证未通过或当前账户无权注册',
        404 => '注册验证服务入口不可用，请稍后重试',
        409 => '当前账户的注册状态冲突，请核对公民号状态',
        429 => '注册请求过于频繁，请稍后重试',
        >= 500 => '注册验证服务故障，请稍后重试',
        _ => '注册验证请求失败（HTTP ${response.statusCode}），请稍后重试',
      };
      throw RegistrationException(
        reason,
        code: 'registration_http_${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > 65536) {
      throw const FormatException('登记响应超限');
    }
    return RegistrationResponse.parse(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      context,
      capabilities: cap,
      initial: initial,
    );
  }

  void close() => _http.close();
}
