import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_scanner/scanner.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

Widget _view(
  CitizenSdk sdk, {
  ValueChanged<String>? result,
  ValueChanged<ScannerFailure>? failure,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ScannerView(
    qr: sdk,
    purpose: CitizenQrScanPurpose.generalScan,
    onRawValue: result ?? (_) {},
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
  testWidgets('SDK纹理原样交给预览，结果只转发SDK规范文本', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(_view(core.sdk, result: values.add));
    await _until(tester, () => find.byType(Texture).evaluate().isNotEmpty);
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 4);
    final wire = await core.sdk.encodeAccountId(testCitizenAccountId);
    core.fixture.scanText(wire, CitizenQrScanPurpose.generalScan);
    await _until(tester, () => values.isNotEmpty);
    expect(values, [wire]);
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
}
