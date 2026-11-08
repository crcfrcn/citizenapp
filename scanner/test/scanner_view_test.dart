import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_scanner/scanner.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

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

void main() {
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
