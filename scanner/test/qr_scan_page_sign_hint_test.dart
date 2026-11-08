import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_scanner/qr_scan_page.dart';

/// 扫码填地址时扫到签名请求:必须给明确去向,不得用「无法识别」含糊过去。
///
/// 签名请求(广场动作 / 公民身份 / 注册局占号换绑)统一在「聊天 → 扫一扫」处理;
/// 交易页与多签各页的地址框扫码都走 [QrScanMode.transfer],共用这一条提示。
late TestCitizenSdkHarness _core;

void main() {
  _core = TestCitizenSdkHarness(physicalUi: true);
  late String signRequestCode;
  late String accountCode;
  setUp(() async {
    accountCode = await _core.sdk.encodeAccountId(testCitizenAccountId);
    signRequestCode = (await _core.sdk.encodeDocument(
      CitizenQrContent.signRequest(
        requestId: 'hint-request-00001',
        expiresAt: BigInt.from(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120,
        ),
        signerAccountId: testCitizenAccountId,
        action: CitizenQrActions.squareAccountAction,
        reviewPayload: Uint8List.fromList([1]),
      ),
    )).canonicalText;
  });

  testWidgets('transfer 模式扫到签名请求:指路聊天扫一扫,不回传结果', (tester) async {
    QrScanTransferResult? popped;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    unawaitedPush(navigatorKey, signRequestCode).then((value) {
      popped = value;
    });
    await tester.pumpAndSettle();

    expect(find.text('这是签名请求'), findsOneWidget);
    expect(find.text('此处只扫收款地址。请到「聊天 → 扫一扫」。'), findsOneWidget);
    // 未识别文案不得同时出现:两条提示并存等于没给去向。
    expect(find.text('无法识别二维码'), findsNothing);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 扫码页停留在原地继续扫,不带结果返回调用方。
    expect(find.byType(QrScanPage), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets('通讯录和用户码入口扫到签名请求保持各自原错误弹窗', (tester) async {
    for (final mode in [QrScanMode.contact, QrScanMode.userContactValue]) {
      final navigatorKey = await pumpScannerHost(tester);
      unawaitedPushMode(navigatorKey, signRequestCode, mode);
      await tester.pumpAndSettle();
      expect(
        find.text(mode == QrScanMode.contact ? '无法识别二维码' : '这不是用户码'),
        findsOneWidget,
      );
      expect(find.text('请扫描当前入口支持的二维码'), findsNothing);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(QrScanPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('账户目标入口拒绝签名请求码', (tester) async {
    final navigatorKey = await pumpScannerHost(tester);
    unawaitedPushMode(navigatorKey, signRequestCode, QrScanMode.accountTarget);
    await tester.pumpAndSettle();
    expect(find.text('二维码类型不符'), findsOneWidget);
    expect(find.text('请扫描用户码或账户码'), findsOneWidget);
  });

  testWidgets('签名入口拒绝账户码', (tester) async {
    final navigatorKey = await pumpScannerHost(tester);
    unawaitedPushMode(navigatorKey, accountCode, QrScanMode.signRequest);
    await tester.pumpAndSettle();
    expect(find.text('二维码类型不符'), findsOneWidget);
    expect(find.text('请扫描签名请求二维码'), findsOneWidget);
  });

  testWidgets('用户资料入口拒绝账户码并提示扫描用户码', (tester) async {
    final navigatorKey = await pumpScannerHost(tester);
    unawaitedPushMode(navigatorKey, accountCode, QrScanMode.userContactValue);
    await tester.pumpAndSettle();
    expect(find.text('这不是用户码'), findsOneWidget);
    expect(find.textContaining('只有「用户主页」出示的用户码'), findsOneWidget);
  });

  testWidgets('扫一扫把签名请求作为 SDK 文档交给调用方', (tester) async {
    final navigatorKey = await pumpScannerHost(tester);
    final route = unawaitedPushMode(
      navigatorKey,
      signRequestCode,
      QrScanMode.dispatch,
    );
    await tester.pumpAndSettle();
    final result = await route as CitizenQrScanResult;
    expect(result.document.kind, CitizenQrKind.signRequest);
    expect(result.document.action, CitizenQrActions.squareAccountAction);
    expect(result.document.signerAccountId, testCitizenAccountId);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform冷钱包账户码返回后不残留排队错误且不清调用页成功提示', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final messenger = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          scaffoldMessengerKey: messenger,
          theme: ThemeData(platform: platform),
          home: const Scaffold(body: Text('钱包调用页')),
        ),
      );
      Object? result;
      var returns = 0;
      unawaited(
        nav.currentState!
            .push<Object?>(
              MaterialPageRoute(
                builder: (_) => QrScanPage(
                  mode: QrScanMode.coldAccountImport,
                  qr: _core.sdk,
                ),
              ),
            )
            .then((value) {
              result = value;
              returns++;
              messenger.currentState!.showSnackBar(
                const SnackBar(content: Text('调用页成功提示')),
              );
            }),
      );
      await tester.pumpAndSettle();
      await scannerUntil(
        tester,
        () => find.byType(Texture).evaluate().isNotEmpty,
      );
      for (var i = 0; i < 4; i++) {
        _core.fixture.emit('qrCaptureError', [
          'camera',
          CitizenSdkErrorCode.unavailable.index + 1,
          'synthetic camera failure',
          CitizenSdkFailureStage.admission.index + 1,
        ]);
      }
      await scannerUntil(tester, () => find.text('扫码失败').evaluate().isNotEmpty);
      expect(find.text('扫码失败'), findsOneWidget);
      _core.fixture.scanText(
        accountCode,
        CitizenQrScanPurpose.coldAccountImport,
      );
      _core.fixture.scanText(
        accountCode,
        CitizenQrScanPurpose.coldAccountImport,
      );
      await scannerUntil(tester, () => returns == 1);
      await tester.pumpAndSettle();
      final scanned = result as CitizenQrScanResult;
      expect(scanned.purpose, CitizenQrScanPurpose.coldAccountImport);
      expect(scanned.document.kind, CitizenQrKind.accountId);
      expect(scanned.accountId, testCitizenAccountId);
      expect(returns, 1);
      expect(find.text('调用页成功提示'), findsOneWidget);
      expect(find.text('扫码失败'), findsNothing);
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(find.text('扫码失败'), findsNothing);
      await scannerUntil(tester, () => _core.fixture.nativeResources.isEmpty);
    });
  }
  testWidgets('取消扫码只销毁本页错误提示，保留外层已有提示', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        scaffoldMessengerKey: messenger,
        home: const Scaffold(body: Text('调用页')),
      ),
    );
    messenger.currentState!.showSnackBar(
      const SnackBar(content: Text('外层已有提示'), duration: Duration(minutes: 1)),
    );
    await tester.pumpAndSettle();
    unawaited(
      nav.currentState!.push<Object?>(
        MaterialPageRoute(
          builder: (_) =>
              QrScanPage(mode: QrScanMode.coldAccountImport, qr: _core.sdk),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scannerUntil(
      tester,
      () => find.byType(Texture).evaluate().isNotEmpty,
    );
    _core.fixture.emit('qrCaptureError', [
      'camera',
      CitizenSdkErrorCode.permissionDenied.index + 1,
      'synthetic permission failure',
      CitizenSdkFailureStage.admission.index + 1,
    ]);
    await scannerUntil(tester, () => find.text('扫码失败').evaluate().isNotEmpty);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('外层已有提示'), findsOneWidget);
    expect(find.text('扫码失败'), findsNothing);
    await scannerUntil(tester, () => _core.fixture.nativeResources.isEmpty);
    messenger.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
  });
}

Future<GlobalKey<NavigatorState>> pumpScannerHost(WidgetTester tester) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
  );
  return navigatorKey;
}

Future<Object?> unawaitedPushMode(
  GlobalKey<NavigatorState> navigatorKey,
  String initialCode,
  QrScanMode mode,
) {
  return navigatorKey.currentState!.push<Object?>(
    MaterialPageRoute(
      builder: (_) => QrScanPage(
        mode: mode,
        initialCode: initialCode,
        qr: _qrFor(initialCode),
      ),
    ),
  );
}

Future<QrScanTransferResult?> unawaitedPush(
  GlobalKey<NavigatorState> navigatorKey,
  String initialCode,
) {
  return navigatorKey.currentState!.push<QrScanTransferResult>(
    MaterialPageRoute(
      builder: (_) => QrScanPage(
        mode: QrScanMode.transfer,
        initialCode: initialCode,
        qr: _qrFor(initialCode),
      ),
    ),
  );
}

// 页面提示只读取真实Core的文档类别，不在App另写解析器。
CitizenSdk _qrFor(String code) => _core.sdk;

Future<void> scannerUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}
