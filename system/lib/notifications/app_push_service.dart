import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import 'package:citizen_system/notifications/app_push_token.dart';

// Firebase客户端标识属于公开应用配置，不是服务端授权凭据。Android与iOS使用各自正式应用标识。
const _firebaseAndroidApiKey = 'AIzaSyBfXLIwqGoOX_h75MxZYcorJncT3uSZrm4';
const _firebaseIosApiKey = 'AIzaSyBIVrjuAzf_TguwS88lf50PTeYXYlxTocU';
const _firebaseProjectId = 'citizenapp-23542';
const _firebaseSenderId = '124593150477';
const _firebaseAndroidAppId = '1:124593150477:android:436c372ca4779924ba1344';
const _firebaseIosAppId = '1:124593150477:ios:dcff6e612fb28795ba1344';

FirebaseOptions _firebaseOptions() {
  final apiKey = Platform.isIOS ? _firebaseIosApiKey : _firebaseAndroidApiKey;
  final appId = Platform.isIOS ? _firebaseIosAppId : _firebaseAndroidAppId;
  if (apiKey.isEmpty ||
      _firebaseProjectId.isEmpty ||
      _firebaseSenderId.isEmpty ||
      appId.isEmpty) {
    throw StateError('应用推送缺少Firebase构建参数');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: _firebaseSenderId,
    projectId: _firebaseProjectId,
    iosBundleId: Platform.isIOS ? 'ios.citizenapp' : null,
  );
}

Future<void> ensureAppFirebaseReady() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: _firebaseOptions());
  }
}

void registerAppPushBackgroundHandler(
  Future<void> Function(RemoteMessage message) handler,
) {
  FirebaseMessaging.onBackgroundMessage(handler);
}

/// CitizenApp唯一Firebase所有者；业务模块只消费中性Token和通知数据流。
final class AppPushService {
  AppPushService({
    MethodChannel? permissionsChannel,
    EventChannel? networkChannel,
    Future<Map<String, dynamic>?> Function()? initialMessageLoader,
  }) : _initialLoader = initialMessageLoader,
       _networkChannel = networkChannel,
       _permissionsChannel =
           permissionsChannel ?? const MethodChannel('citizenapp/permissions');

  final EventChannel? _networkChannel;
  final Future<Map<String, dynamic>?> Function()? _initialLoader;
  final MethodChannel _permissionsChannel;
  Future<AppPushToken>? _initialization;
  Future<Map<String, dynamic>?>? _initialMessage;
  bool _initialConsumed = false;

  /// 唯一原生网络事件通道；只报告可用性变化，业务决定是否在前台校准。
  late final Stream<bool> networkAvailability =
      (_networkChannel ?? const EventChannel('citizenapp/network'))
          .receiveBroadcastStream()
          .where((event) => event is bool)
          .cast<bool>()
          .distinct()
          .handleError((Object _) {});

  Stream<Map<String, dynamic>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map((message) => message.data);

  Stream<Map<String, dynamic>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  Stream<AppPushToken> get tokenChanges => FirebaseMessaging
      .instance
      .onTokenRefresh
      .asyncMap((_) => readToken(requestPermission: false))
      // 平台回调可能早于APNs Token就绪；忽略本次读取，等待下一次刷新或前台初始化重试。
      .handleError((Object _) {});

  Future<AppPushToken> initialize() {
    final current = _initialization;
    if (current != null) return current;
    final created = _initialize();
    _initialization = created;
    return created.catchError((Object error, StackTrace stackTrace) {
      if (identical(_initialization, created)) _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<AppPushToken> _initialize() async {
    final token = await readToken(requestPermission: true);
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: false,
            sound: true,
          );
    }
    return token;
  }

  Future<AppPushToken> readToken({required bool requestPermission}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('应用推送只支持Android和iOS');
    }
    await ensureAppFirebaseReady();
    final messaging = FirebaseMessaging.instance;
    if (requestPermission) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    if (Platform.isIOS) {
      final token = await messaging.getAPNSToken();
      if (token == null || token.isEmpty) {
        throw StateError('APNs Token尚未生成');
      }
      final environment = await _permissionsChannel.invokeMethod<String>(
        'getApnsEnvironment',
      );
      if (environment != 'sandbox' && environment != 'production') {
        throw StateError('iOS应用签名缺少有效APNs环境');
      }
      return AppPushToken(
        provider: 'apns',
        token: token,
        apnsEnvironment: environment,
      );
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('FCM Token尚未生成');
    }
    return AppPushToken(provider: 'fcm', token: token, apnsEnvironment: null);
  }

  /// 根级业务可查看同一初始事件；默认导航仍只消费一次，不能丢失其他业务推送。
  Future<Map<String, dynamic>?> initialMessage({bool consume = true}) async {
    if (consume && _initialConsumed) return null;
    final pending = _initialMessage ??= () async {
      if (_initialLoader != null) return _initialLoader();
      await ensureAppFirebaseReady();
      return (await FirebaseMessaging.instance.getInitialMessage())?.data;
    }();
    final Map<String, dynamic>? data;
    try {
      data = await pending;
    } on Object {
      if (identical(_initialMessage, pending)) _initialMessage = null;
      rethrow;
    }
    if (consume) {
      if (_initialConsumed) return null;
      _initialConsumed = true;
    }
    return data;
  }
}
