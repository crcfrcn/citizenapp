import 'package:citizen_system/notifications/app_push_token.dart';

import 'dart:io';

import 'package:citizen_system/notifications/app_push_service.dart';

import 'package:flutter_test/flutter_test.dart';
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
    final source = File(
      'system/lib/notifications/app_push_service.dart',
    ).readAsStringSync();
    final appIds = RegExp(
      r"'(1:124593150477:(?:android|ios):[0-9a-f]+)'",
    ).allMatches(source).map((match) => match.group(1)!).toSet();

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
    final source = File(
      'system/lib/notifications/app_push_service.dart',
    ).readAsStringSync();
    final keys = RegExp(
      r"const _firebase(?:Android|Ios)ApiKey = '(AIza[^']+)'",
    ).allMatches(source).map((match) => match.group(1)!).toList();

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

  test('普通应用推送由CitizenServe会话登记', () {
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
}
