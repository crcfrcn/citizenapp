/// 单次唤起只返回固定分类，链接及配对资料不进入日志。
enum WalletLinkResult {
  opened,
  urlInvalid,
  parameterInvalid,
  systemRejected,
  systemError,
}

/// 仅接受官方 MWP 配对或已有会话的链接。
class WalletLinkDispatcher {
  WalletLinkDispatcher({required Future<bool> Function(Uri) launcher})
    : _launcher = launcher;

  final Future<bool> Function(Uri) _launcher;

  Uri _parse(String rawUrl) {
    if (rawUrl.length > 16384) throw WalletLinkResult.urlInvalid;
    final uri = Uri.parse(rawUrl);
    if (uri.scheme != 'metamask' ||
        uri.authority != 'connect' ||
        uri.path != '/mwp' ||
        uri.hasFragment) {
      throw WalletLinkResult.urlInvalid;
    }
    final query = uri.queryParametersAll;
    if (query.values.any((values) => values.length != 1)) {
      throw WalletLinkResult.parameterInvalid;
    }
    final id = query['id']?.single;
    final payload = query['p']?.single;
    final wake =
        query.length == 1 &&
        id != null &&
        RegExp(
          r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(id);
    final pairing =
        query.length == 2 &&
        query['c']?.single == '1' &&
        payload != null &&
        RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(payload);
    if (!wake && !pairing) throw WalletLinkResult.parameterInvalid;
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
