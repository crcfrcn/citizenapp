import 'dart:convert';

/// 仅唤起已在保护区保存的官方SDK会话；原生宿主独立核对冻结付款参数。
class WalletLinkDispatcher {
  WalletLinkDispatcher({required Future<bool> Function(Uri) launcher})
    : _launcher = launcher;
  final Future<bool> Function(Uri) _launcher;
  String? _channel;
  int _validUntil = 0;

  // 只从系统保护区回读官方SDK配置；不把缓存账户地址当授权，不读取或复制会话私钥。
  void restore(String? value) {
    _channel = null;
    _validUntil = 0;
    if (value == null) return;
    try {
      final data = jsonDecode(value);
      if (data is Map &&
          data['channelId'] is String &&
          data['validUntil'] is int &&
          RegExp(
            r'^[A-Za-z0-9-]{16,128}$',
          ).hasMatch(data['channelId'] as String)) {
        _channel = data['channelId'] as String;
        _validUntil = data['validUntil'] as int;
      }
    } on Object {
      /* 损坏配置不能取得会话唤起资格。 */
    }
  }

  Uri? parse(String rawUrl) {
    if (_channel == null ||
        DateTime.now().millisecondsSinceEpoch >= _validUntil ||
        rawUrl.length > 32768)
      return null;
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.scheme != 'metamask' ||
          uri.host != 'connect' ||
          !(uri.path.isEmpty || uri.path == '/') ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty)
        return null;
      final query = uri.queryParametersAll;
      if (query.values.any((values) => values.length != 1) ||
          query['channelId']?.single != _channel ||
          query['v']?.single != '2' ||
          query['comm']?.single != 'socket')
        return null;
      if (query.keys.any(
        (key) => !const [
          'channelId',
          'pubkey',
          'comm',
          't',
          'v',
          'hr',
          'scheme',
          'rpc',
          'originatorInfo',
        ].contains(key),
      ))
        return null;
      if (query.containsKey('scheme') &&
          !const ['true', 'false'].contains(query['scheme']?.single))
        return null;
      if (query.containsKey('originatorInfo')) {
        final raw = uri.query
            .split('&')
            .singleWhere((item) => item.startsWith('originatorInfo='));
        final info = jsonDecode(
          utf8.decode(
            base64Decode(
              Uri.decodeComponent(raw.substring('originatorInfo='.length)),
            ),
          ),
        );
        if (info is! Map ||
            info['url'] != 'https://www.crcfrcn.com' ||
            info['title'] != 'CitizenApp' ||
            info['scheme'] != 'citizenapp://topup')
          return null;
      }
      final fields = uri.query
          .split('&')
          .where((item) => item.startsWith('rpc='))
          .toList();
      if (fields.isNotEmpty) {
        // 复用会话的官方RPC为双层base64密文，不能假装它仍是首次连接的明文JSON。
        final encoded = utf8.decode(
          base64Decode(Uri.decodeComponent(fields.single.substring(4))),
        );
        final cipher = base64Decode(encoded);
        if (cipher.length < 97 || !const [2, 3, 4].contains(cipher.first))
          return null;
      }
      return uri;
    } on Object {
      return null;
    }
  }

  Future<bool> open(String rawUrl) async {
    final uri = parse(rawUrl);
    if (uri == null) return false;
    try {
      return await _launcher(uri);
    } on Object {
      return false;
    }
  }
}
