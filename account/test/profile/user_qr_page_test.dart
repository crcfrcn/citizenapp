import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:citizen_scanner/qr_display_scaffold.dart' show AppQrImage;

import 'package:citizen_account/profile/user_qr_page.dart';
import 'package:citizen_citizen/account_derivation.dart';

/// 用户码展示页（`k=3 user_contact`，固定码，多入口复用同一页）。
///
/// 验证点：
/// - 页面渲染公开昵称、完整 SS58 地址、复制图标和顶部下载图标
/// - 复制点击不抛异常（Clipboard 在 test 环境由 services binding 静默接管）
/// - 下载点击进入保存流程不抛异常（单测环境 SaverGallery 无 native 实现，
///   走 `_saveQr` 的 catch 兜底；不用 pumpAndSettle，保存中的进度圈永不 settle）
/// - 用户码输入只传CID和account_id，昵称和SS58不进SDK编码输入
/// - 本页只出用户码：不存在任何「该出哪种码」的运行时分流（账户维度走账户码页）
void main() {
  const accountId =
      '0x0000000000000000000000000000000000000000000000000000000000000000';
  const cidNumber = 'CN001-CTZN-000000001-2026';
  const displayName = '晨光寻路者';
  const qrData = '{"b":{"c":"$cidNumber","n":"$accountId"},"k":3,"p":"QR_V1"}';
  final accountAddress = ss58FromAccountIdText(accountId);

  Future<void> openPage(WidgetTester tester, {bool isSelf = false}) async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await sdk.close();
    });
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          home: UserQrPage(
            qrData: qrData,
            cidNumber: cidNumber,
            displayName: displayName,
            accountId: accountId,
            isSelf: isSelf,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('用户码页面渲染完整二维码、昵称、地址、复制与顶部下载入口', (tester) async {
    await openPage(tester);

    expect(find.widgetWithText(AppBar, '用户码'), findsOneWidget);
    expect(find.text('二维码'), findsNothing);
    expect(find.text(displayName), findsWidgets);
    expect(find.text(accountAddress), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byType(AppQrImage), findsOneWidget);
  });

  testWidgets('底部文案如实覆盖加联系人与转账两种扫码场景', (tester) async {
    await openPage(tester);

    expect(find.text('扫描此二维码可加为联系人，或向其转账'), findsOneWidget);
  });

  testWidgets('本人入口标题显示我的用户码', (tester) async {
    await openPage(tester, isSelf: true);

    expect(find.widgetWithText(AppBar, '我的用户码'), findsOneWidget);
  });

  testWidgets('用户码是固定码，不出现任何时效文案', (tester) async {
    await openPage(tester);

    expect(find.textContaining('分钟内有效'), findsNothing);
  });

  testWidgets('点击复制地址不抛异常', (tester) async {
    await openPage(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(accountAddress), findsOneWidget);
  });

  testWidgets('点击下载进入保存流程不抛异常', (tester) async {
    await openPage(tester);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  test('用户码调用SDK编码，UI标签不进入协议输入', () async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    try {
      final document = await sdk.encodeDocument(
        CitizenQrContent.userContact(
          cidNumber: cidNumber,
          accountId: accountId,
        ),
      );
      expect(document.canonicalText, qrData);
      expect(document.kind, CitizenQrKind.userContact);
      expect(document.cidNumber, cidNumber);
      expect(document.accountId, accountId);
      expect(document.canonicalText, isNot(contains(displayName)));
      expect(document.canonicalText, isNot(contains(accountAddress)));
    } finally {
      await sdk.close();
    }
  });
}
