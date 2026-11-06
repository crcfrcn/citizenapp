import 'dart:async';
import 'dart:io';

import 'package:citizen_system/app_log.dart';
import 'package:citizen_system/notifications/app_push_service.dart';
import 'package:citizen_system/notifications/app_push_token.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_runtime.dart';
import 'transport/chat_connection.dart';

const _wakePendingKey = 'chat.push.wake_pending';

/// 只把CitizenApp通用平台推送映射为公民聊天聊天唤醒桥；不拥有Firebase配置或非聊天通知。
class ChatPushService {
  ChatPushService({
    AppPushService? appPushService,
    MethodChannel? notificationsChannel,
    Future<AppPushToken> Function()? tokenProvider,
  }) : _appPushService = appPushService ?? AppPushService(),
       _tokenProvider = tokenProvider,
       _notificationsChannel =
           notificationsChannel ??
           const MethodChannel('citizenapp/chat_notifications');

  final AppPushService _appPushService;
  final Future<AppPushToken> Function()? _tokenProvider;
  final MethodChannel _notificationsChannel;
  final StreamController<ChatPushWake> _wakeController =
      StreamController<ChatPushWake>.broadcast();
  final StreamController<AppPushToken> _tokenController =
      StreamController<AppPushToken>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<AppPushToken>? _tokenSubscription;

  Stream<ChatPushWake> get wakes => _wakeController.stream;

  Stream<AppPushToken> get tokenChanges => _tokenController.stream;

  Future<AppPushToken> initialize() async {
    final custom = _tokenProvider;
    if (custom != null) return custom();
    final token = await _appPushService.initialize();
    _messageSubscription ??= _appPushService.foregroundMessages.listen(
      _handleMessage,
    );
    _tokenSubscription ??= _appPushService.tokenChanges.listen(
      (next) => _tokenController.add(next),
    );
    return token;
  }

  static bool isWakeData(Map<String, dynamic> data) =>
      data.length == 1 && data['event'] == 'chat_wake';

  static Future<void> storeWake() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wakePendingKey, true);
  }

  Future<bool> takePendingWake() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_wakePendingKey) ?? false;
    await prefs.remove(_wakePendingKey);
    return pending;
  }

  void _handleMessage(Map<String, dynamic> data) {
    if (!isWakeData(data)) return;
    _wakeController.add(const ChatPushWake());
  }

  /// 页面已读提交成功后只清理当前会话通知；Android与iOS共用原生通道。
  Future<void> clearConversationNotifications(String conversationId) async {
    if ((!Platform.isAndroid && !Platform.isIOS) || conversationId.isEmpty) {
      return;
    }
    await _notificationsChannel.invokeMethod<void>(
      'clearConversationNotifications',
      <String, String>{'conversationId': conversationId},
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _wakeController.close();
    await _tokenController.close();
  }
}

/// Firebase后台isolate只持久记录无内容唤醒，前台唯一ChatRuntime恢复后再补拉端到端密文。
@pragma('vm:entry-point')
Future<void> chatRuntimeBackgroundHandler(RemoteMessage message) async {
  if (!ChatPushService.isWakeData(message.data)) return;
  try {
    await ChatRuntime.runStartupPreflight<void>(
      operation: () async {
        await ensureAppFirebaseReady();
        await ChatPushService.storeWake();
      },
    );
  } catch (error) {
    AppLog.d('chat background mailbox wake deferred: $error');
  }
}
