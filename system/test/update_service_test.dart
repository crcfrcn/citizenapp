import 'dart:convert';
import 'package:citizen_testing/fixture.dart';
import 'package:citizen_system/update/app_update_controller.dart';
import 'package:citizen_system/update/app_update_installer.dart';
import 'package:citizen_system/update/app_update_manifest.dart';
import 'package:citizen_system/update/app_update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const android = AppVersionInfo(
  packageName: 'com.crcfrcn.citizenapp',
  versionName: '1.0.0',
  versionCode: 7,
);
const ios = AppVersionInfo(
  packageName: 'ios.citizenapp',
  versionName: '1.0.0',
  versionCode: 7,
);

class Installer extends AppUpdateInstaller {
  Map<String, Object?> update = {'available': true, 'versionCode': 9};
  Map<String, Object?> store = {'appId': '6800953222', 'country': 'US'};
  int opened = 0, checks = 0;
  bool opens = true;
  bool checkFails = false;
  @override
  Future<AppVersionInfo> getPackageInfo() async => android;
  @override
  Future<Map<String, Object?>> checkStoreUpdate() async {
    checks++;
    if (checkFails) throw StateError('offline');
    return update;
  }

  @override
  Future<Map<String, Object?>> getStoreInfo() async => store;
  @override
  Future<bool> openStore() async {
    opened++;
    return opens;
  }
}

Future<Map<String, dynamic>> fixture() async =>
    jsonDecode(
          fixtureFile(
            'citizen_system',
            'update_fixture.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android只读取Google Play可用性，不请求GitHub或下载APK', () async {
    final native = Installer();
    final service = AppUpdateService(
      installer: native,
      isAndroid: true,
      client: MockClient((_) async => throw StateError('Android不得发起HTTP更新请求')),
    );
    expect(await service.readCurrentVersion(), android);
    expect(await service.checkUpdate(android), isNotNull);
    expect(native.checks, 1);
    expect(await service.openStore(), isTrue);
    expect(native.opened, 1);
    native.update = {'available': false, 'versionCode': 99};
    expect(await service.checkUpdate(android), isNull);
    native.update = {'available': true, 'versionCode': 7};
    expect(await service.checkUpdate(android), isNull);
  });
  test('iOS读取登记商品及真实商店地区的已上架版本', () async {
    final service = AppUpdateService(
      installer: Installer(),
      isAndroid: false,
      client: MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'itunes.apple.com');
        expect(request.url.queryParameters, {
          'id': '6800953222',
          'country': 'US',
        });
        expect(request.followRedirects, isFalse);
        return http.Response(jsonEncode(await fixture()), 200);
      }),
    );
    final info = await service.checkUpdate(ios);
    expect(info?.version, '1.2.3');
  });
  test('商店未上架不显示更新，同版本不显示更新', () async {
    final data = await fixture();
    final service = AppUpdateService(
      installer: Installer(),
      isAndroid: false,
      client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
    );
    data['results'] = [];
    expect(await service.checkUpdate(ios), isNull);
    data['results'] = [
      {'trackId': 6800953222, 'bundleId': 'ios.citizenapp', 'version': '1.0'},
    ];
    expect(await service.checkUpdate(ios), isNull);
  });
  for (final field in ['trackId', 'bundleId', 'version']) {
    test('错误商店商品字段$field不得提示更新', () async {
      final data = await fixture();
      (data['results'] as List).first[field] = 'wrong';
      final service = AppUpdateService(
        installer: Installer(),
        isAndroid: false,
        client: MockClient((_) async => http.Response(jsonEncode(data), 200)),
      );
      expect(service.checkUpdate(ios), throwsFormatException);
    });
  }
  test('商店请求失败和地区缺失保留真实失败，不伪装已有更新', () async {
    final native = Installer();
    final service = AppUpdateService(
      installer: native,
      isAndroid: false,
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(service.checkUpdate(ios), throwsA(isA<Exception>()));
    native.store = {'appId': '6800953222', 'country': ''};
    await expectLater(service.checkUpdate(ios), throwsFormatException);
  });
  test('原生通道只提供读版本、检查商店和打开商店', () async {
    final calls = <String>[];
    const channel = MethodChannel('citizenapp/update');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'getPackageInfo' => {
              'packageName': 'ios.citizenapp',
              'versionName': '1.2.3',
              'versionCode': 9,
            },
            'checkStoreUpdate' => {'available': true, 'versionCode': 10},
            'getStoreInfo' => {'appId': '6800953222', 'country': 'US'},
            'openStore' => true,
            _ => throw StateError('未知操作'),
          };
        });
    final native = AppUpdateInstaller();
    expect((await native.getPackageInfo()).label, 'v1.2.3');
    await native.checkStoreUpdate();
    await native.getStoreInfo();
    expect(await native.openStore(), isTrue);
    expect(calls, [
      'getPackageInfo',
      'checkStoreUpdate',
      'getStoreInfo',
      'openStore',
    ]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('点击更新只打开商店，失败可重试且设备版本不变', () async {
    final native = Installer()..opens = false;
    final controller = AppUpdateController.forTesting(
      service: AppUpdateService(installer: native, isAndroid: true),
    );
    await controller.check();
    expect(controller.state.versionLabel, 'v1.0.0');
    expect(await controller.openStore(), isFalse);
    expect(controller.state.hasUpdate, isTrue);
    native.opens = true;
    expect(await controller.openStore(), isTrue);
    expect(native.opened, 2);
    expect(controller.state.versionLabel, 'v1.0.0');
    controller.dispose();
  });
  test('设备未换版本时，商店暂时离线保留已知更新入口', () async {
    final native = Installer();
    final controller = AppUpdateController.forTesting(
      service: AppUpdateService(installer: native, isAndroid: true),
    );
    await controller.check();
    expect(controller.state.hasUpdate, isTrue);
    native.checkFails = true;
    await controller.check(force: true);
    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.hasUpdate, isTrue);
    expect(controller.state.versionLabel, 'v1.0.0');
    expect(await controller.openStore(), isTrue);
    controller.dispose();
  });
}
