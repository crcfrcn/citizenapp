// 验证扫码预览、设备错误、关闭排空及SDK资源隔离。

import 'dart:async';

import 'package:citizen_scanner/scanner.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证迟到采集关闭、真实排空和更换SDK时的资源隔离。

// 使用真实SDK采集资源；只控制物理相机打开、排空及会话归属。
Widget _controllerView(
  CitizenSdk sdk, {
  ValueChanged<CitizenQrScanResult>? value,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScannerView(
    qr: sdk,
    purpose: CitizenQrScanPurpose.generalScan,
    onResult: value ?? (_) {},
  ),
);
Future<void> _controllerUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void _registerController() {
  final core = TestCitizenSdkHarness(physicalUi: true);
  testWidgets('打开尚未完成便退出，迟到摄像资源必须关闭且不展示', (tester) async {
    final opening = Completer<void>();
    core.fixture.cameraOpen = opening;
    final values = <CitizenQrScanResult>[];
    await tester.pumpWidget(_controllerView(core.sdk, value: values.add));
    await _controllerUntil(
      tester,
      () => core.fixture.calls.contains('openQrCapture'),
    );
    await tester.pumpWidget(const SizedBox());
    expect(core.fixture.nativeResources, isNotEmpty);
    opening.complete();
    await _controllerUntil(tester, () => core.fixture.nativeResources.isEmpty);
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
    await tester.pumpWidget(_controllerView(core.sdk));
    await _controllerUntil(
      tester,
      () => find.byType(Texture).evaluate().isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await _controllerUntil(
      tester,
      () => core.fixture.calls.contains('closeQrCapture'),
    );
    expect(core.fixture.nativeResources, isNotEmpty);
    drain.complete();
    await _controllerUntil(tester, () => core.fixture.nativeResources.isEmpty);
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
      await tester.pumpWidget(_controllerView(core.sdk));
      await _controllerUntil(
        tester,
        () => find.byType(Texture).evaluate().isNotEmpty,
      );
      core.fixture.cameraDrain = drain;
      await tester.pumpWidget(_controllerView(peer));
      await _controllerUntil(
        tester,
        () => core.fixture.calls.contains('closeQrCapture'),
      );
      expect(
        core.fixture.calls.where((m) => m == 'openQrCapture'),
        hasLength(1),
      );
      expect(core.fixture.nativeResources, contains('$oldHost:camera'));
      drain.complete();
      await _controllerUntil(
        tester,
        () => core.fixture.calls.where((m) => m == 'openQrCapture').length == 2,
      );
      expect(core.fixture.nativeResources, isNot(contains('$oldHost:camera')));
      expect(core.fixture.nativeResources, contains('$newHost:camera'));
      await tester.pumpWidget(const SizedBox());
      await _controllerUntil(
        tester,
        () => core.fixture.nativeResources.isEmpty,
      );
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

// 验证SDK纹理方向、结构化结果、错误及前后台和退出时序。

Widget _view(
  CitizenSdk sdk, {
  ValueChanged<CitizenQrScanResult>? result,
  ValueChanged<CitizenQrCapture?>? capture,
  ValueChanged<ScannerFailure>? failure,
  CitizenQrScanPurpose purpose = CitizenQrScanPurpose.generalScan,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScannerView(
    qr: sdk,
    purpose: purpose,
    onResult: result ?? (_) {},
    onCapture: capture,
    onFailure: failure,
  ),
);
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}

void _registerPreview() {
  final core = TestCitizenSdkHarness(physicalUi: true);
  testWidgets('预览只应用SDK剩余角度并保留纹理比例，方向事件更新同一资源', (tester) async {
    await tester.pumpWidget(_view(core.sdk));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    for (final rotation in [0, 270, 180, 90, 0]) {
      core.fixture.emit('qrCapturePreview', ['camera', 480, 640, rotation]);
      await _until(tester, () {
        final box = tester.widget<RotatedBox>(find.byType(RotatedBox));
        final size = box.child! as SizedBox;
        return box.quarterTurns == rotation ~/ 90 &&
            size.width == 480 &&
            size.height == 640;
      });
      final rotated = tester.widget<RotatedBox>(find.byType(RotatedBox));
      final size = rotated.child! as SizedBox;
      expect(size.width, 480);
      expect(size.height, 640);
      expect((size.child! as Texture).textureId, 4);
    }
    expect(core.fixture.calls.where((m) => m == 'openQrCapture'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
    expect(
      core.fixture.calls.where((m) => m == 'closeQrCapture'),
      hasLength(1),
    );
  });
  testWidgets('SDK纹理与结构化扫码结果原样转发', (tester) async {
    final values = <CitizenQrScanResult>[];
    CitizenQrCapture? capture;
    await tester.pumpWidget(
      _view(core.sdk, result: values.add, capture: (value) => capture = value),
    );
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 4);
    final wire = await core.sdk.encodeAccountId(testCitizenAccountId);
    final captured = capture!.results.first;
    core.fixture.scanText(wire, CitizenQrScanPurpose.generalScan);
    await _until(tester, () => values.isNotEmpty);
    expect(values.single, same(await captured));
    expect(values.single.accountId, testCitizenAccountId);
    expect(values.single.purpose, CitizenQrScanPurpose.generalScan);
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
  });
  testWidgets('SDK权限/设备错误按稳定类别投影，不读取异常字符串猜测', (tester) async {
    core.fixture.cameraError = CitizenSdkErrorCode.permissionDenied;
    final failures = <ScannerFailure>[];
    await tester.pumpWidget(_view(core.sdk, failure: failures.add));
    await _until(tester, () => failures.isNotEmpty);
    expect(failures.single.kind, ScannerFailureKind.permissionDenied);
    expect(find.byType(Texture), findsNothing);
    expect(core.fixture.nativeResources, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('前后台只转发SDK暂停恢复，退出等待真实资源close', (tester) async {
    await tester.pumpWidget(_view(core.sdk));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    final before = core.fixture.calls
        .where((m) => m == 'pauseQrCapture')
        .length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _until(
      tester,
      () =>
          core.fixture.calls.where((m) => m == 'pauseQrCapture').length >
          before,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _until(tester, () => core.fixture.calls.contains('resumeQrCapture'));
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
    expect(
      core.fixture.calls.where((m) => m == 'closeQrCapture'),
      hasLength(1),
    );
  });
  testWidgets('换轮排空旧资源时不投递旧错误，新轮真实错误仍投递', (tester) async {
    final failures = <ScannerFailure>[];
    await tester.pumpWidget(_view(core.sdk, failure: failures.add));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    final drain = Completer<void>();
    core.fixture.cameraDrain = drain;
    await tester.pumpWidget(
      _view(
        core.sdk,
        failure: failures.add,
        purpose: CitizenQrScanPurpose.coldAccountImport,
      ),
    );
    await tester.pump();
    core.fixture.emit('qrCaptureError', [
      'camera',
      CitizenSdkErrorCode.unavailable.index + 1,
      'synthetic stale frame',
      CitizenSdkFailureStage.admission.index + 1,
    ]);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(failures, isEmpty);
    core.fixture.cameraDrain = null;
    drain.complete();
    await _until(
      tester,
      () => core.fixture.calls.where((x) => x == 'openQrCapture').length == 2,
    );
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    core.fixture.emit('qrCaptureError', [
      'camera',
      CitizenSdkErrorCode.permissionDenied.index + 1,
      'synthetic current error',
      CitizenSdkFailureStage.admission.index + 1,
    ]);
    await _until(tester, () => failures.isNotEmpty);
    expect(failures.single.kind, ScannerFailureKind.permissionDenied);
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
  });
  testWidgets('离开预览后延迟采集错误不再进入已销毁页面', (tester) async {
    final failures = <ScannerFailure>[];
    await tester.pumpWidget(_view(core.sdk, failure: failures.add));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => core.fixture.nativeResources.isEmpty);
    core.fixture.emit('qrCaptureError', [
      'camera',
      CitizenSdkErrorCode.unavailable.index + 1,
      'synthetic closed frame',
      CitizenSdkFailureStage.admission.index + 1,
    ]);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(failures, isEmpty);
  });
}

void main() {
  group('采集关闭', _registerController);
  group('采集预览', _registerPreview);
}
