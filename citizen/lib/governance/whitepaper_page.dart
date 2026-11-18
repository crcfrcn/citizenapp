import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';

/// 构建时从CitizenChainWhitepaper.md及原始SVG生成，随App内置，不访问官网。
const String citizenWhitepaperAsset =
    'packages/citizen_assets/documents/whitepaper.md';

Future<String>? _document;

// 一次进程复用成功正文；加载失败不缓存，页面重试仍读同一包内资源。
Future<String> _readWhitepaper() async {
  final pending = _document ??= rootBundle
      .loadString(citizenWhitepaperAsset)
      .then(citizenWhitepaperHtml);
  try {
    return await pending;
  } catch (_) {
    if (identical(_document, pending)) _document = null;
    rethrow;
  }
}

// 目录直达链接和正文标题使用相同锚点规则，保持离线跳转一致。
String _headingId(String text) => text
    .split(RegExp(r'<br\s*/?>', caseSensitive: false))
    .first
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'[^a-zA-Z0-9\u3400-\u9fff_-]'), '')
    .toLowerCase();

// 保留原文中英标题；中文锚点与原文目录一致。
class _WhitepaperHeading extends md.HeaderSyntax {
  const _WhitepaperHeading();

  @override
  md.Node parse(md.BlockParser parser) {
    final heading = super.parse(parser) as md.Element;
    heading.generatedId = _headingId(heading.textContent);
    return heading;
  }
}

// 原文为对齐而围栏包裹的标准Markdown表格仍按表格展示，真正代码保持原样。
class _WhitepaperCodeBlock extends md.FencedCodeBlockSyntax {
  const _WhitepaperCodeBlock();

  @override
  md.Node parse(md.BlockParser parser) {
    final original = super.parse(parser);
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ).parseLines(original.textContent.split('\n'));
    if (nodes.length == 1) {
      final table = nodes.single;
      if (table is md.Element && table.tag == 'table') return table;
    }
    return original;
  }
}

@visibleForTesting
String citizenWhitepaperHtml(String markdown) {
  if (markdown.trim().isEmpty) throw const FormatException('白皮书正文为空');
  // 原文没有下级链接的折叠项改为正文锚点，不改动同源白皮书。
  final document = markdown.replaceAllMapped(
    RegExp(r'<details>\s*<summary>([^<]+)</summary>\s*</details>'),
    (match) {
      final title = match[1]!;
      final anchor = Uri.encodeComponent(_headingId(title));
      return '<a class="whitepaper-toc-leaf" href="#$anchor">$title</a>';
    },
  );
  final body = md.markdownToHtml(
    document,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: const [_WhitepaperHeading(), _WhitepaperCodeBlock()],
  );
  return '''<!doctype html><html lang="zh-CN"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
<style>
html{scroll-behavior:smooth}
body{margin:0;background:#f6f8f7;color:#183e36;font-family:system-ui,sans-serif;font-size:16px;line-height:1.8;overflow-wrap:anywhere}
article{max-width:1100px;margin:auto;padding:16px 20px 48px}h1{font-size:26px}h2{font-size:22px}h3,h4{font-size:18px}
h1,h2,h3,h4,h5,h6{line-height:1.5;scroll-margin-top:16px}a{color:#18704a}img{max-width:100%;height:auto}
table,pre{display:block;max-width:100%;overflow-x:auto}table{border-collapse:collapse;font-size:14px}th,td{border:1px solid #ccd8d2;padding:8px;min-width:72px}
pre{padding:12px;background:#eaf0ec;font-size:13px;white-space:pre;overflow-wrap:normal}code{font-family:monospace}
li:has(details),li:has(.whitepaper-toc-leaf){list-style:none}
.whitepaper-toc-leaf{font-weight:600;text-decoration:none}
.whitepaper-to-top{display:grid;place-items:center;padding:0;line-height:1;position:fixed;right:30px;bottom:30px;border:0;border-radius:999px;width:42px;height:42px;font-size:18px;background:#0f766e;color:#fff;box-shadow:0 8px 18px rgba(15,118,110,.25);z-index:50;text-decoration:none}
details{margin:8px 0}summary{cursor:pointer;font-weight:600}details a{display:block}
.whitepaper-title-en,.whitepaper-heading-en,.whitepaper-en{color:#60756b;font-size:.85em;font-weight:400}
</style></head><body><article id="whitepaper-top">$body</article><a class="whitepaper-to-top" href="#whitepaper-top" aria-label="回到顶部" title="回到顶部">↑</a></body></html>''';
}

/// 只允许离线文档及其页内锚点导航，正文链接不打开在线页面。
@visibleForTesting
bool isCitizenWhitepaperNavigationAllowed(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return false;
  return uri.scheme == 'about' && uri.path == 'blank' ||
      uri.scheme.isEmpty && uri.path.isEmpty && uri.fragment.isNotEmpty;
}

class CitizenWhitepaperPage extends StatefulWidget {
  const CitizenWhitepaperPage({super.key});

  @override
  State<CitizenWhitepaperPage> createState() => _CitizenWhitepaperPageState();
}

class _CitizenWhitepaperPageState extends State<CitizenWhitepaperPage> {
  late final WebViewController _controller;
  var _loadingProgress = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(AppTheme.scaffoldBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loadError = null;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loadingProgress = 100);
          },
          onWebResourceError: (error) {
            // iframe/图片等子资源错误不得覆盖已成功显示的主文档。
            if (error.isForMainFrame != true || !mounted) return;
            setState(() => _loadError = '白皮书加载失败，请重试');
          },
          onNavigationRequest: (request) =>
              isCitizenWhitepaperNavigationAllowed(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _loadingProgress = 0;
    });
    try {
      final html = await _readWhitepaper();
      if (!mounted) return;
      await _controller.loadHtmlString(html, baseUrl: 'about:blank');
    } catch (_) {
      if (mounted) setState(() => _loadError = '白皮书加载失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    return Scaffold(
      appBar: AppBar(title: const Text('公民链白皮书'), centerTitle: true),
      body: Stack(
        children: [
          if (error == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppTheme.textTertiary,
                      size: 40,
                    ),
                    SizedBox(height: AppLayout.scaled(context, 12)),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: AppLayout.scaled(context, 12)),
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          if (error == null && _loadingProgress < 100)
            LinearProgressIndicator(
              key: const ValueKey('citizen-whitepaper-load-progress'),
              minHeight: AppLayout.scaled(context, 2),
              value: _loadingProgress == 0 ? null : _loadingProgress / 100,
            ),
        ],
      ),
    );
  }
}
