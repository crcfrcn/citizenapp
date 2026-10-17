/// CitizenServe的唯一API根；能力URL只能在相同origin、准确路径上使用。
class CitizenServeApiConfig {
  static const production = 'https://www.crcfrcn.com/api';
  static const registrationScope = 'citizenserve:production';
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
    if (uri == null || uri.scheme != 'https' || uri.origin != mediaOrigin ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        !uri.path.startsWith('/square/') ||
        Uri.parse(baseUrl).origin != Uri.parse(production).origin) {
      return const {};
    }
    for (final entry in headers?.entries ?? const <MapEntry<String, String>>[]) {
      if (entry.key.toLowerCase() == 'authorization' &&
          RegExp(r'^Bearer sqs_[0-9a-f]{32}$').hasMatch(entry.value)) {
        return {'authorization': entry.value};
      }
    }
    return const {};
  }
}
