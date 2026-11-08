import 'package:http/http.dart' as http;
import 'package:citizen_system/app_log.dart';

/// CitizenServe的唯一API根；能力URL只能在相同origin、准确路径上使用。
class CitizenServeApiConfig {
  static const production = 'https://www.crcfrcn.com/api';
  static const mediaOrigin = 'https://media.crcfrcn.com';
  static const _configured = String.fromEnvironment('SQUARE_API_URL');
  static String get baseUrl =>
      normalize(_configured.isEmpty ? production : _configured);
  static String normalize(String value) {
    final text = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api') {
      throw const FormatException('公民服务必须使用HTTPS /api根');
    }
    return text;
  }

  static Uri capability(
    String base,
    String value,
    String path, {
    bool query = false,
  }) {
    final root = Uri.parse(normalize(base));
    final uri = root.resolve(value);
    if (uri.scheme != 'https' ||
        uri.origin != root.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.path != '/api$path' ||
        (!query && uri.hasQuery)) {
      throw const FormatException('服务能力地址与本次请求不一致');
    }
    return uri;
  }

  /// 业务媒体只向所属正式媒体域交付会话头；外域、非HTTPS和带能力查询的地址不带凭据。
  static Map<String, String> mediaHeaders(
    String value,
    Map<String, String>? headers,
  ) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.origin != mediaOrigin ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith('/square/') ||
        Uri.parse(baseUrl).origin != Uri.parse(production).origin) {
      return const {};
    }
    for (final entry
        in headers?.entries ?? const <MapEntry<String, String>>[]) {
      if (entry.key.toLowerCase() == 'authorization' &&
          RegExp(r'^Bearer sqs_[0-9a-f]{32}$').hasMatch(entry.value)) {
        return {'authorization': entry.value};
      }
    }
    return const {};
  }
}

// 中文注释：共用真实 Client 边界只发送 HTTPS；关闭重定向以阻断服务端降级。
class HttpsOnlyClient extends http.BaseClient {
  HttpsOnlyClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw UnsupportedError('网络请求必须使用完整 HTTPS 地址');
    }
    request.followRedirects = false;
    final stage = _httpStage(uri);
    if (stage == null) return _inner.send(request);
    final clock = Stopwatch()..start();
    int? status, headersMicros;
    var finished = false;
    void report(String phase) => AppLog.http(
      stage: stage,
      statusCode: status,
      headersMicros: headersMicros,
      elapsedMicros: clock.elapsedMicroseconds,
      phase: phase,
    );
    void finish(String phase) {
      if (finished) return;
      finished = true;
      report(phase);
      clock.stop();
    }

    try {
      final response = await _inner.send(request);
      status = response.statusCode;
      headersMicros = clock.elapsedMicroseconds;
      report('headers');
      // yield*随原消费者读取，透传背压、取消和异常，不预读或检查正文。
      Stream<List<int>> body() async* {
        try {
          // yield*会直接转发流错误，不会抛回生成器；须在原错误转发处记失败。
          yield* response.stream.handleError((Object error, StackTrace stack) {
            finish('error');
            Error.throwWithStackTrace(error, stack);
          });
          finish('complete');
        } on Object {
          finish('error');
          rethrow;
        } finally {
          finish('cancelled');
        }
      }

      return http.StreamedResponse(
        body(),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on Object {
      finish('error');
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

/// 仅在内存匹配正式服务；动态路径、查询、头和正文不交给日志接口。
String? _httpStage(Uri uri) {
  if (uri.origin == CitizenServeApiConfig.mediaOrigin &&
      uri.path.startsWith('/square/')) {
    return 'media';
  }
  if (uri.origin != Uri.parse(CitizenServeApiConfig.production).origin ||
      !uri.path.startsWith('/api/')) {
    return null;
  }
  final path = uri.path.substring(4);
  return switch (path) {
    '/user/challenges' => 'challenge',
    '/user/sessions' => 'session',
    '/user/devices' => 'registration',
    '/user/contacts' => 'contacts',
    _ when path.startsWith('/user/contacts/') => 'contacts',
    '/topup/confirm' => 'topup_confirm',
    '/topup/status' => 'topup_status',
    _ when path.startsWith('/user/registration') => 'registration',
    _ when path.startsWith('/membergate/creator') => 'creator',
    _ when path.startsWith('/membergate') => 'membergate',
    _ when path.startsWith('/user/cards/') => 'card',
    _ when path.startsWith('/user/profile') => 'profile',
    _ when path.startsWith('/notifications') => 'notifications',
    _ when path.startsWith('/8964/follows') => 'follows',
    _ when path.startsWith('/8964/') && path.endsWith('/comments') =>
      'comments',
    _ when path.startsWith('/8964/') => 'feed',
    _ when path.startsWith('/chat/') => 'chat_access',
    _ => 'other',
  };
}
