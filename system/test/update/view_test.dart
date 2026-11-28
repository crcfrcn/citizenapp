// 验证更新徽标。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/update/view.dart';

// 验证更新红点及检查失败保留已读取设备版本。

class _FakeAppUpdateService extends AppUpdateService {
  _FakeAppUpdateService({this.failStoreCheck = false});

  final bool failStoreCheck;
  int storeCheckCount = 0;

  @override
  Future<AppVersionInfo> readCurrentVersion() async => const AppVersionInfo(
    packageName: 'com.crcfrcn.citizenapp',
    versionName: '1.0.0',
    versionCode: 7,
  );

  @override
  Future<AppUpdateInfo?> checkUpdate(AppVersionInfo currentVersion) async {
    storeCheckCount += 1;
    if (failStoreCheck) throw StateError('offline');
    return null;
  }
}

void main() {
  testWidgets('有更新时显示红点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateDotBadge(
            show: true,
            dotKey: Key('update-dot'),
            child: Icon(Icons.settings),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('update-dot')), findsOneWidget);
  });

  testWidgets('没有更新时不显示红点', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateDotBadge(
            show: false,
            dotKey: Key('update-dot'),
            child: Icon(Icons.settings),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('update-dot')), findsNothing);
  });

  test('读取本机版本后检查商店，不改变版本显示', () async {
    final service = _FakeAppUpdateService();
    final controller = AppUpdateController.forTesting(service: service);

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.idle);
    expect(controller.state.versionLabel, 'v1.0.0');
    expect(controller.state.hasUpdate, isFalse);
    expect(service.storeCheckCount, 1);
  });

  test('Android 联网检查失败仍保留已读取的本机版本', () async {
    final service = _FakeAppUpdateService(failStoreCheck: true);
    final controller = AppUpdateController.forTesting(service: service);

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.versionLabel, 'v1.0.0');
    expect(service.storeCheckCount, 1);
  });
}
