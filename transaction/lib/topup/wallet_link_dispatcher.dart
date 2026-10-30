/// 本地充值页只请求打开已选钱包；保留来源和危险协议检查，失败立即停止。
enum WalletLinkSource {
  /// Reown 通过受控 JS bridge 明确请求打开钱包，包括自定义 scheme 与 Universal Link。
  walletOpenBridge,

  /// WebView 主框架直接导航；HTTPS 仍留在 WebView，只有钱包自定义 scheme 才外部打开。
  webViewNavigation,
}

enum WalletLinkDisposition { stayInWebView, openExternalWallet, blocked }

class WalletLinkDecision {
  const WalletLinkDecision(this.disposition, {this.uri});

  final WalletLinkDisposition disposition;
  final Uri? uri;
}

/// 系统外部打开注入点。测试以假实现验证失败和异常分支，生产由 `url_launcher` 提供。
typedef WalletUriLauncher = Future<bool> Function(Uri uri);

enum WalletLinkOpenResult { opened, invalid, blocked, failed }

/// WalletConnect 钱包链接分类与系统打开单源。
class WalletLinkDispatcher {
  WalletLinkDispatcher({required WalletUriLauncher launcher})
    : _launcher = launcher;

  final WalletUriLauncher _launcher;

  /// 这些协议不属于钱包打开能力；即使页面脚本请求，也不得交给系统。
  static const Set<String> _blockedSchemes = {
    'http',
    'ws',
    'javascript',
    'data',
    'file',
    'blob',
    'about',
    'tel',
    'sms',
    'mailto',
    'geo',
  };

  static WalletLinkDecision classify(
    String rawUrl, {
    required WalletLinkSource source,
  }) {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(value);
    if (value.isEmpty || uri == null || uri.scheme.isEmpty) {
      return const WalletLinkDecision(WalletLinkDisposition.blocked);
    }

    final scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) {
      // about/file/blob 是 WebView 自己的内部资源类型；其余危险协议同样不得外部打开。
      if (scheme == 'about' || scheme == 'file' || scheme == 'blob') {
        return WalletLinkDecision(
          WalletLinkDisposition.stayInWebView,
          uri: uri,
        );
      }
      return const WalletLinkDecision(WalletLinkDisposition.blocked);
    }

    if (scheme == 'https') {
      // 普通网络资源继续由 WebView 加载；只有 Reown 明确发出的钱包打开事件，才把
      // Universal Link 交给系统，沿原受控桥接打开已选钱包。
      return WalletLinkDecision(
        source == WalletLinkSource.walletOpenBridge
            ? WalletLinkDisposition.openExternalWallet
            : WalletLinkDisposition.blocked,
        uri: uri,
      );
    }

    // 品牌选择与启用校验归随包页面；此处保留协议与来源检查。
    return WalletLinkDecision(
      WalletLinkDisposition.openExternalWallet,
      uri: uri,
    );
  }

  Future<WalletLinkOpenResult> open(
    String rawUrl, {
    required WalletLinkSource source,
  }) async {
    final decision = classify(rawUrl, source: source);
    if (decision.disposition == WalletLinkDisposition.blocked) {
      return WalletLinkOpenResult.blocked;
    }
    if (decision.disposition != WalletLinkDisposition.openExternalWallet ||
        decision.uri == null) {
      return WalletLinkOpenResult.invalid;
    }
    try {
      if (await _launcher(decision.uri!)) {
        return WalletLinkOpenResult.opened;
      }
    } catch (_) {
      // 失败不提取通用wc URI，避免系统改投其他钱包；不泄漏配对内容或平台异常。
    }
    return WalletLinkOpenResult.failed;
  }
}
