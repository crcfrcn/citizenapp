import 'package:citizen_system/notifications/app_push_token.dart';

import 'dart:io';
import 'dart:convert';

import 'package:citizen_system/notifications/app_push_service.dart';

import 'package:chat/chat_push.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_testing/platform_input.dart';

void main() {
  test('充值通知在CID通知前独立处理，前台恢复仅调用订单模块', () {
    final source = File('lib/app.dart').readAsStringSync();
    final shell = source.indexOf('class AppShell');
    expect(source.indexOf('final _topupUpdates'), lessThan(shell));
    expect(source, contains('widget.appPushService.foregroundMessages'));
    expect(source, contains('widget.appPushService.openedMessages'));
    expect(source, contains('initialMessage(consume: false)'));
    expect(source, contains('_topupUpdates.resume()'));
    expect(source, contains('_topupUpdates.close()'));
    expect(
      source.indexOf("if (payload['kind'] == 'topup_result') return;"),
      lessThan(source.indexOf('await Notifications.instance.receive(data);')),
    );
    final topup = File('topup/lib/topup_api.dart').readAsStringSync();
    final recovery = topup.substring(
      topup.indexOf('Future<TopupReceipt> recover('),
      topup.indexOf('Future<TopupReceipt> _sendReceipt('),
    );
    expect(recovery, isNot(contains('Timer(')));
    expect(recovery, isNot(contains('verifyPayment(')));
    expect(recovery, isNot(contains('requestIssuance(')));
    expect(topup, isNot(contains('getGenesisHash().result')));
  });
  test('初始推送查看不消耗导航事件且并发仅消费一次', () async {
    var calls = 0;
    final value = <String, dynamic>{
      'kind': 'square_post',
      'post_id': 'synthetic',
    };
    final push = AppPushService(
      initialMessageLoader: () async {
        calls++;
        return value;
      },
    );
    expect(await push.initialMessage(consume: false), value);
    final results = await Future.wait([
      push.initialMessage(),
      push.initialMessage(),
    ]);
    expect(results.where((r) => r != null).length, 1);
    expect(calls, 1);
    expect(await push.initialMessage(), isNull);
    expect(await push.initialMessage(consume: false), value);
  });
  test('初始推送失败不粘住缓存或消耗导航事件', () async {
    var calls = 0;
    final push = AppPushService(
      initialMessageLoader: () async {
        calls++;
        if (calls == 1) throw StateError('synthetic');
        return {'kind': 'topup_result'};
      },
    );
    await expectLater(push.initialMessage(consume: false), throwsStateError);
    expect(await push.initialMessage(), {'kind': 'topup_result'});
    expect(calls, 2);
    expect(await push.initialMessage(), isNull);
  });
  test('新应用标识使用各自登记的唯一 Firebase App ID', () {
    final source = File('system/lib/notifications/app_push_service.dart')
        .readAsStringSync();
    final appIds = RegExp(r"'(1:124593150477:(?:android|ios):[0-9a-f]+)'")
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toSet();

    expect(
      source,
      contains("iosBundleId: Platform.isIOS ? 'ios.citizenapp' : null"),
    );
    expect(appIds, {
      '1:124593150477:android:436c372ca4779924ba1344',
      '1:124593150477:ios:dcff6e612fb28795ba1344',
    });
    expect(source, isNot(contains('String.fromEnvironment')));
  });

  test('Firebase 客户端 Key 按平台隔离且禁止共享回退', () {
    final source = File('system/lib/notifications/app_push_service.dart')
        .readAsStringSync();
    final keys = RegExp(r"const _firebase(?:Android|Ios)ApiKey = '(AIza[^']+)'")
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toList();

    expect(keys, hasLength(2));
    expect(keys.toSet(), hasLength(2));
    expect(
      source,
      matches(
        RegExp(
          r'final\s+apiKey\s*=\s*Platform\.isIOS\s*\?\s*'
          r'_firebaseIosApiKey\s*:\s*_firebaseAndroidApiKey;',
        ),
      ),
    );
    expect(source, contains('if (apiKey.isEmpty ||'));
    expect(source, contains('apiKey: apiKey'));
  });

  test('只接受无内容聊天唤醒载荷', () {
    expect(ChatPushService.isWakeData(const {'event': 'chat_wake'}), isTrue);
    expect(
      ChatPushService.isWakeData(const {
        'event': 'chat_wake',
        'sender_cid_number': 'forbidden',
      }),
      isFalse,
    );
    expect(
      ChatPushService.isWakeData(const {
        'event': 'chat_wake',
        'conversation_id': 'forbidden',
      }),
      isFalse,
    );
    expect(
      ChatPushService.isWakeData(const {
        'event': 'chat_wake',
        'message': '不得进入推送',
      }),
      isFalse,
    );
    expect(
      ChatPushService.isWakeData(const {'event': 'chat_message'}),
      isFalse,
    );
  });

  test('CitizenApp 双端只展示并清理固定聊天通知', () {
    final android = File('android/app/MainActivity.kt').readAsStringSync();
    final appPush = File('system/lib/notifications/app_push_service.dart')
        .readAsStringSync();

    expect(android, contains('CHAT_NOTIFICATION_CHANNEL_ID = "chat_messages"'));
    expect(android, contains('.setContentText("你有一条新消息")'));
    expect(appPush, contains('setForegroundNotificationPresentationOptions'));
    expect(android, contains('clearChatNotifications(conversationId)'));
    expect(
      File('ios/source/AppDelegate.swift').readAsStringSync(),
      contains('clearDeliveredChatNotifications'),
    );
  });

  test('聊天桥不拥有Firebase配置或非聊天通知', () {
    final source = File('chat/lib/chat_push.dart').readAsStringSync();
    expect(source, isNot(contains('FirebaseOptions')));
    expect(source, isNot(contains('_firebaseAndroidApiKey')));
    expect(source, isNot(contains('square_post')));
    expect(source, contains('AppPushService'));
  });

  test('普通应用推送由CitizenServe会话登记且不使用聊天数据面', () {
    final client = File('user/lib/square_api_client.dart').readAsStringSync();
    final main = File('lib/app.dart').readAsStringSync();
    expect(client, contains("_putJson('/notifications/endpoint'"));
    expect(main, contains('registerPushEndpoint'));
    expect(main, contains("payload['kind'] == 'storage_cleanup'"));
  });

  test('iOS APNs 环境以 provisioning profile 和 App Store 收据为真源', () {
    final entitlements = platformInput('ios/Runner/Runner.entitlements');
    final infoPlist = File('ios/source/Info.plist').readAsStringSync();
    final appDelegate = File('ios/source/AppDelegate.swift').readAsStringSync();

    expect(entitlements, contains('<string>\$(APS_ENVIRONMENT)</string>'));
    expect(infoPlist, isNot(contains('\$(APS_ENVIRONMENT)')));
    expect(appDelegate, contains('embedded'));
    expect(appDelegate, contains('mobileprovision'));
    expect(appDelegate, contains('profile["Entitlements"]'));
    expect(appDelegate, contains('entitlements["aps-environment"]'));
    expect(appDelegate, contains('bundle.appStoreReceiptURL'));
  });

  test('iOS 正式包固定声明当前出口合规豁免结论', () {
    final infoPlist = File('ios/source/Info.plist').readAsStringSync();

    // 当前销售范围排除法国，App Store Connect 已判定标准加密无须上传文稿。
    expect(infoPlist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
    expect(
      infoPlist,
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
    );
    expect(infoPlist, isNot(contains('ITSEncryptionExportComplianceCode')));
  });

  test('聊天原生保护由App注册，包图不再登记独立聊天插件', () {
    final packages = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final names = (packages['packages'] as List)
        .map((value) => (value as Map)['name'])
        .toSet();
    expect(names, contains('chat'));
    final storage = File('ios/chat/ChatStorageChannel.swift')
        .readAsStringSync();
    final app = File('ios/source/AppDelegate.swift').readAsStringSync();
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:allowBackup="false"'),
    );
    expect(
      storage,
      contains('FileProtectionType.completeUntilFirstUserAuthentication'),
    );
    expect(storage, contains('isExcludedFromBackup == true'));
    expect(storage, contains('try protectOwnedData(root)'));
    expect(
      app,
      contains(
        'chatStorageChannel = ChatStorageChannel(binaryMessenger: binaryMessenger)',
      ),
    );
  });

  test('推送端点缓存同时绑定服务类型、APNs 环境和 Token', () {
    const sandbox = AppPushToken(
      provider: 'apns',
      token: 'same-token',
      apnsEnvironment: 'sandbox',
    );
    const production = AppPushToken(
      provider: 'apns',
      token: 'same-token',
      apnsEnvironment: 'production',
    );
    const fcm = AppPushToken(
      provider: 'fcm',
      token: 'same-token',
      apnsEnvironment: null,
    );
    expect(
      sandbox.registrationCacheValue,
      isNot(production.registrationCacheValue),
    );
    expect(fcm.registrationCacheValue, isNot(sandbox.registrationCacheValue));
  });

  test('后台连续唤醒只持久化一个待补拉标志', () async {
    SharedPreferences.setMockInitialValues({});
    await ChatPushService.storeWake();
    await ChatPushService.storeWake();

    final service = ChatPushService();
    expect(await service.takePendingWake(), isTrue);
    expect(await service.takePendingWake(), isFalse);
    await service.dispose();
  });
}
