/// CitizenServe的唯一API根；能力URL只能在相同origin、准确路径上使用。
class CitizenServeApiConfig {
  static const production = 'https://www.crcfrcn.com/api';
  static const registrationScope = 'citizenserve:production';
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
}
