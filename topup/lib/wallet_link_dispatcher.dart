import 'dart:convert';

/// 每次唤起独立返回固定原因，不保存共享错误，也不携带链接或会话资料。
enum WalletLinkResult {
  opened,
  sessionMissing,
  urlInvalid,
  channelMismatch,
  protocolInvalid,
  parameterInvalid,
  metadataInvalid,
  rpcInvalid,
  systemRejected,
  systemError,
}

/// 仅唤起已在保护区保存的官方SDK会话；原生宿主独立核对冻结付款参数。
class WalletLinkDispatcher {
  WalletLinkDispatcher({required Future<bool> Function(Uri) launcher})
    : _launcher = launcher;
  final Future<bool> Function(Uri) _launcher;
  String? _channel;

  // 双端只核对SDK保存的频道；会话恢复、有效期和续期由SDK决定。
  // 不把缓存账户地址当授权，不读取或复制会话私钥，也不重算缓存期限。
  void restore(String? value) {
    _channel = null;
    if (value == null) return;
    try {
      final data = jsonDecode(value);
      if (data is Map &&
          data['channelId'] is String &&
          RegExp(
            r'^[A-Za-z0-9-]{16,128}$',
          ).hasMatch(data['channelId'] as String)) {
        _channel = data['channelId'] as String;
      }
    } on Object {
      /* 损坏配置不能取得会话唤起资格。 */
    }
  }

  Uri _parse(String rawUrl) {
    if (_channel == null) throw WalletLinkResult.sessionMissing;
    if (rawUrl.length > 32768) throw WalletLinkResult.urlInvalid;
    final uri = Uri.parse(rawUrl);
    if (uri.scheme != 'metamask' ||
        uri.host != 'connect' ||
        !(uri.path.isEmpty || uri.path == '/') ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw WalletLinkResult.urlInvalid;
    }
    final query = uri.queryParametersAll;
    if (query.values.any((values) => values.length != 1)) {
      throw WalletLinkResult.parameterInvalid;
    }
    if (query['channelId']?.single != _channel) {
      throw WalletLinkResult.channelMismatch;
    }
    if (query['v']?.single != '2' || query['comm']?.single != 'socket') {
      throw WalletLinkResult.protocolInvalid;
    }
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
        'redirect',
      ].contains(key),
    )) {
      throw WalletLinkResult.parameterInvalid;
    }
    // SDK暂停唤醒链接只使用redirect=true；它不是任意网页返回地址。
    if (query.containsKey('redirect') && query['redirect']?.single != 'true') {
      throw WalletLinkResult.parameterInvalid;
    }
    if (query.containsKey('scheme') &&
        !const ['true', 'false'].contains(query['scheme']?.single)) {
      throw WalletLinkResult.parameterInvalid;
    }
    if (query.containsKey('originatorInfo')) {
      try {
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
            info['scheme'] != 'citizenapp://topup') {
          throw WalletLinkResult.metadataInvalid;
        }
      } on Object {
        throw WalletLinkResult.metadataInvalid;
      }
    }
    final fields = uri.query
        .split('&')
        .where((item) => item.startsWith('rpc='))
        .toList();
    if (fields.isNotEmpty) {
      try {
        // 复用会话的官方RPC为双层base64密文，不能假装它仍是首次连接的明文JSON。
        final encoded = utf8.decode(
          base64Decode(Uri.decodeComponent(fields.single.substring(4))),
        );
        final cipher = base64Decode(encoded);
        if (cipher.length < 97 || !const [2, 3, 4].contains(cipher.first)) {
          throw WalletLinkResult.rpcInvalid;
        }
      } on Object {
        throw WalletLinkResult.rpcInvalid;
      }
    }
    return uri;
  }

  Future<WalletLinkResult> open(String rawUrl) async {
    final Uri uri;
    try {
      uri = _parse(rawUrl);
    } on WalletLinkResult catch (result) {
      return result;
    } on Object {
      return WalletLinkResult.urlInvalid;
    }
    try {
      return await _launcher(uri)
          ? WalletLinkResult.opened
          : WalletLinkResult.systemRejected;
    } on Object {
      return WalletLinkResult.systemError;
    }
  }
}
