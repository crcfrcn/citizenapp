import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'registration_models.dart';

/// 主页面只能停留在本次服务器能力URL；子资源由服务器的CSP限定。
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.verification});
  final RegistrationVerification verification;
  static String? tokenFromMessage(
    String message,
    RegistrationVerification verification, {
    int? now,
  }) {
    if ((now ?? DateTime.now().millisecondsSinceEpoch) >=
            verification.expiresAt ||
        message.length > 4096) {
      return null;
    }
    try {
      final raw = jsonDecode(message);
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          !raw.keys.every({'verification_id', 'token'}.contains) ||
          raw['verification_id'] != verification.id ||
          raw['token'] is! String) {
        return null;
      }
      final token = raw['token'] as String;
      return token.isNotEmpty && token.length <= 2048 && token.trim() == token
          ? token
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  late final WebViewController controller;
  bool returned = false;
  String? error;
  Timer? expiry;
  @override
  void initState() {
    super.initState();
    final remaining =
        widget.verification.expiresAt - DateTime.now().millisecondsSinceEpoch;
    expiry = Timer(Duration(milliseconds: remaining > 0 ? remaining : 0), () {
      if (mounted && !returned) setState(() => error = '验证页面已过期，请返回后重试');
    });
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Turnstile',
        onMessageReceived: (message) {
          final token = RegistrationPage.tokenFromMessage(
            message.message,
            widget.verification,
          );
          if (token != null && mounted && !returned) {
            returned = true;
            Navigator.of(context).pop(token);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              !request.isMainFrame ||
                  request.url == widget.verification.page.toString()
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (event) {
            if (event.isForMainFrame == true && mounted) {
              setState(() => error = '验证页面加载失败，请返回后重试');
            }
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.loadRequest(widget.verification.page).catchError((Object _) {
          if (mounted && !returned) setState(() => error = '验证页面加载失败，请返回后重试');
        });
      }
    });
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('注册安全验证')),
    body: SafeArea(
      child: error == null
          ? WebViewWidget(controller: controller)
          : Center(child: Text(error!)),
    ),
  );
}
