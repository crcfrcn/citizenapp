import 'dart:convert';
import 'package:citizen_user/identity/registration_api.dart';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:citizen_user/identity/registration_models.dart';

/// 默认Cloudflare页面只交付本次瞬时令牌，服务端Siteverify通过前不允许注册。
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  static RegistrationVerification? verificationFromMessage(String message) {
    if (message.length > 4096) return null;
    try {
      final raw = jsonDecode(message);
      if (raw is! Map<String, dynamic> ||
          raw.length != 2 ||
          !raw.keys.every({'check_id', 'token'}.contains) ||
          raw['check_id'] is! String ||
          raw['token'] is! String) {
        return null;
      }
      return RegistrationVerification(
        checkId: raw['check_id'] as String,
        token: raw['token'] as String,
      );
    } on Object {
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
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Turnstile',
        onMessageReceived: (message) {
          final token = RegistrationPage.verificationFromMessage(
            message.message,
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
                  request.url == RegistrationApi.pageUri().toString()
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
        controller.loadRequest(RegistrationApi.pageUri()).catchError((
          Object _,
        ) {
          if (mounted && !returned) setState(() => error = '验证页面加载失败，请返回后重试');
        });
      }
    });
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
