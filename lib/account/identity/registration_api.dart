import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:citizenapp/security/chain_bootstrap_api.dart'
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
    required String verificationId,
    required String token,
  }) => _post(context, '/user/registration/verify', {
    ...cap.toJson(),
    'verification_id': verificationId,
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
    if (response.statusCode != 200) {
      throw const RegistrationException('注册验证服务未完成请求，请重试');
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
