import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:citizen_network/chain_bootstrap_api.dart' show HttpsOnlyClient;
import 'package:citizen_network/citizen_serve_api_config.dart';
import 'package:citizen_account/identity/registration_models.dart';

/// 默认Cloudflare核验；只确认当次通过，不创建任务、签发凭据或持久化令牌。
class RegistrationApi {
  RegistrationApi({http.Client? client})
    : _http = HttpsOnlyClient(client ?? http.Client());
  final http.Client _http;
  Future<void> verify(
    RegistrationContext context,
    RegistrationVerification verification,
  ) async {
    try {
      final response = await _http
          .post(
            Uri.parse('${context.baseUrl}/user/registration/verify'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(verification.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw RegistrationException(
          response.statusCode == 403 ? '真人验证未通过，请重试' : '真人验证服务暂不可用，请重试',
          code: 'registration_http_${response.statusCode}',
        );
      }
      if (response.bodyBytes.length > 4096) {
        throw const FormatException('真人验证响应超限');
      }
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map<String, dynamic> ||
          value.length != 1 ||
          value['is_ok'] != true) {
        throw const RegistrationException(
          '真人验证未通过',
          code: 'verification_failed',
        );
      }
    } on SocketException {
      throw const RegistrationException(
        '真人验证网络连接失败',
        code: 'network_unavailable',
      );
    } on TimeoutException {
      throw const RegistrationException(
        '真人验证请求超时',
        code: 'network_unavailable',
      );
    } on http.ClientException {
      throw const RegistrationException(
        '真人验证网络请求失败',
        code: 'network_unavailable',
      );
    }
  }

  static Uri pageUri() =>
      Uri.parse('${CitizenServeApiConfig.baseUrl}/user/registration/page');
  void close() => _http.close();
}
