import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_scanner/scanner.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

// 使用真实SDK采集资源；只控制物理相机打开、排空及会话归属。
Widget _view(CitizenSdk sdk, {ValueChanged<String>? value}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScannerView(
    qr: sdk,
    purpose: CitizenQrScanPurpose.generalScan,
    onRawValue: value ?? (_) {},
  ),
);
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void main() {
  final core = TestCitizenSdkHarness(physicalUi: true);
  testWidgets('打开尚未完成便退出，迟到摄像资源必须关闭且不展示', (tester) async {
    final opening = Completer<void>();
    core.fixture.cameraOpen = opening;
    final values = <String>[];
    await tester.pumpWidget(_view(core.sdk, value: values.add));
    await _until(tester, () => core.fixture.calls.contains('openQrCapture'));
    await tester.pumpWidget(const SizedBox());
    expect(core.fixture.nativeResources, isNotEmpty);
    opening.complete();
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
    expect(
      core.fixture.calls.where((m) => m == 'closeQrCapture'),
      hasLength(1),
    );
    expect(values, isEmpty);
    expect(find.byType(Texture), findsNothing);
  });
  testWidgets('dispose不伪造SDK排空，close未完成时资源仍是未关闭', (tester) async {
    final drain = Completer<void>();
    core.fixture.cameraDrain = drain;
    await tester.pumpWidget(_view(core.sdk));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.calls.contains('closeQrCapture'));
    expect(core.fixture.nativeResources, isNotEmpty);
    drain.complete();
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
    expect(
      core.fixture.calls.where((m) => m == 'closeQrCapture'),
      hasLength(1),
    );
  });
  testWidgets('更换SDK前先关闭前一个预览，不向新页面交付旧流', (tester) async {
    final peer = await CitizenSdk.open(modules: CitizenSdkModules.qr);
    final oldHost = core.fixture.handles.keys.first,
        newHost = core.fixture.handles.keys.last;
    final drain = Completer<void>();
    try {
      await tester.pumpWidget(_view(core.sdk));
      await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
      core.fixture.cameraDrain = drain;
      await tester.pumpWidget(_view(peer));
      await _until(tester, () => core.fixture.calls.contains('closeQrCapture'));
      expect(
        core.fixture.calls.where((m) => m == 'openQrCapture'),
        hasLength(1),
      );
      expect(core.fixture.nativeResources, contains('$oldHost:camera'));
      drain.complete();
      await _until(
        tester,
        () => core.fixture.calls.where((m) => m == 'openQrCapture').length == 2,
      );
      expect(core.fixture.nativeResources, isNot(contains('$oldHost:camera')));
      expect(core.fixture.nativeResources, contains('$newHost:camera'));
      await tester.pumpWidget(const SizedBox());
      await _until(tester, () => core.fixture.nativeResources.isEmpty);
      expect(
        core.fixture.calls.where((m) => m == 'closeQrCapture'),
        hasLength(2),
      );
    } finally {
      if (!drain.isCompleted) drain.complete();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await peer.close();
    }
  });
}
