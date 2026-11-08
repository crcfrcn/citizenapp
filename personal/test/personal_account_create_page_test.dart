import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_scanner/qr_scan_page.dart';
import 'package:citizen_personal/personal_account_create_page.dart';
import 'package:citizen_personal/personal_manage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_testing/isar_test_env.dart';

late TestCitizenSdkHarness _sdkHarness;

void main() {
  _sdkHarness = TestCitizenSdkHarness(physicalUi: true);
  useIsolatedIsar();

  Future<void> pumpPage(
    WidgetTester tester, {
    PersonalAccountCreatePage? page,
  }) async {
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          home: page ?? PersonalAccountCreatePage(
            walletStateLoader: () async => CitizenWalletState(
              initializationState: CitizenWalletInitializationState.empty,
              cleanupPending: false,
              revision: BigInt.zero,
              hotProfile: null,
              accounts: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('扫码入口位于管理员列表标题行右侧且独立文字按钮已删除', (tester) async {
    await pumpPage(tester);

    final title = find.text('管理员列表（0/64）');
    final scanButton = find.byKey(const ValueKey('personal-admin-scan-button'));
    expect(title, findsOneWidget);
    expect(scanButton, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '扫码添加管理员'), findsNothing);

    final titleRect = tester.getRect(title);
    final buttonRect = tester.getRect(scanButton);
    expect(buttonRect.left, greaterThanOrEqualTo(titleRect.right));
    expect(buttonRect.center.dy, closeTo(titleRect.center.dy, 1));

    final icon = tester.widget<SvgPicture>(
      find.descendant(of: scanButton, matching: find.byType(SvgPicture)),
    );
    expect(icon.bytesLoader, isA<SvgAssetLoader>());
    expect(
      (icon.bytesLoader as SvgAssetLoader).assetName,
      'packages/citizen_assets/icons/scan-line.svg',
    );
  });

  testWidgets('管理员扫码消费 SDK 用户码并进入姓名确认', (tester) async {
    await pumpPage(tester);
    final wire = (await _sdkHarness.sdk.encodeDocument(
      CitizenQrContent.userContact(
        cidNumber: 'CN001-CTZN-000000001-2026',
        accountId: testCitizenAccountId,
      ),
    )).canonicalText;

    await tester.tap(find.byKey(const ValueKey('personal-admin-scan-button')));
    await tester.pumpAndSettle();

    final page = tester.widget<QrScanPage>(find.byType(QrScanPage));
    expect(page.mode, QrScanMode.userContactValue);
    expect(page.customTitle, '扫码添加管理员');
    for (
      var i = 0;
      i < 100 && _sdkHarness.fixture.nativeResources.isEmpty;
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(_sdkHarness.fixture.nativeResources, isNotEmpty);
    _sdkHarness.fixture.scanText(wire, CitizenQrScanPurpose.generalScan);
    final namesDialog = find.text('管理员姓名');
    for (var i = 0; i < 100 && namesDialog.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(namesDialog, findsOneWidget);
    expect(find.byType(QrScanPage), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('管理员列表（0/64）'), findsOneWidget);
  });

  for (final (amount, readFails, notice, balanceReads) in [
    ('1.99', false, '初始资金不能低于 2.00 元', 0),
    ('2.00', false, '当前余额 4.79 元，至少需要 4.80 元', 1),
    ('2.00', true, '提交失败：Bad state: 最低入金读取失败', 0),
  ]) {
    testWidgets('个人多签入金 $amount：$notice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final block = CitizenBlockRef(
        hash: '0x${'12' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.best,
      );
      var minimumReads = 0;
      var walletReads = 0;
      await pumpPage(
        tester,
        page: PersonalAccountCreatePage(
          walletStateLoader: () async => testCitizenWalletState(),
          manageService: PersonalManageService(),
          amountReads: (
            quote: (fen) async {
              expect(fen, parseFen(amount));
              return CitizenFeeSnapshot(
                bestBlock: block,
                feeRateParts: 1000000,
                minimumFeeFen: BigInt.from(10),
                existentialDepositFen: BigInt.from(250),
                voteFeeFen: BigInt.zero,
                feeFen: BigInt.from(20),
                minimumSelfPayFen: BigInt.from(260),
              );
            },
            minimum: (requested) async {
              expect(requested, same(block));
              minimumReads++;
              if (readFails) throw StateError('最低入金读取失败');
              return BigInt.from(200);
            },
            balance: (accountId) async {
              expect(accountId, testCitizenAccountId);
              walletReads++;
              return CitizenAccountBalance(
                accountId: accountId,
                block: CitizenBlockRef(
                  hash: '0x${'34' * 32}',
                  number: BigInt.one,
                  finality: CitizenBlockFinality.finalized,
                ),
                freeFen: BigInt.from(479),
                reservedFen: BigInt.zero,
                totalFen: BigInt.from(479),
              );
            },
          ),
        ),
      );

      final sdk = _sdkHarness.sdk;
      final admin = (await sdk.encodeDocument(CitizenQrContent.userContact(
        cidNumber: 'CN001-CTZN-000000001-2026',
        accountId: citizenAccountIdFromBytes(List<int>.filled(32, 42)),
      ))).canonicalText;
      final scanned = await sdk.parseForPurpose(admin, CitizenQrScanPurpose.generalScan);
      await tester.tap(find.byKey(const ValueKey('personal-admin-scan-button')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(QrScanPage))).pop(scanned);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      expect(find.text('管理员列表（2/64）'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '输入名称（如：家庭基金）'), '家庭基金');
      final amountField = find.widgetWithText(TextField, '输入初始资金');
      await tester.ensureVisible(amountField);
      await tester.pumpAndSettle();
      await tester.enterText(amountField, amount);
      expect(parseFen(tester.widget<TextField>(amountField).controller!.text), parseFen(amount));
      final submit = find.widgetWithText(ElevatedButton, '发起创建提案');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.textContaining(notice), findsOneWidget);
      expect(minimumReads, 1);
      expect(walletReads, balanceReads);
    });
  }
}
