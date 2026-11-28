// 个人多签lifecycle功能回归，保留迁入用例和断言。

import 'package:citizen_personal/chain.dart';
import 'package:citizen_personal/lifecycle.dart';
import 'package:citizen_personal/proposals.dart';
import 'package:citizen_personal/storage.dart';
import 'package:citizen_scanner/scan.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_wallet/account/card.dart' show buildWalletAccountQrData;
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// 原用例所属：personal/test/personal_account_create_page_test.dart
// 验证管理员扫码姓名确认及个人多签入金交互。

late TestCitizenSdkHarness _personalaccountcreatepagesdkHarness;

void _registerPersonalaccountcreatepage() {
  _personalaccountcreatepagesdkHarness = TestCitizenSdkHarness(
    physicalUi: true,
  );
  useIsolatedIsar();

  Future<void> pumpPage(
    WidgetTester tester, {
    PersonalAccountCreatePage? page,
  }) async {
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _personalaccountcreatepagesdkHarness.sdk,
        child: MaterialApp(
          home:
              page ??
              PersonalAccountCreatePage(
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

  testWidgets('管理员扫码消费无CID钱包码并进入姓名确认', (tester) async {
    await pumpPage(tester);
    final wire = await buildWalletAccountQrData(
      _personalaccountcreatepagesdkHarness.sdk,
      testCitizenAccountId,
    );

    await tester.tap(find.byKey(const ValueKey('personal-admin-scan-button')));
    await tester.pumpAndSettle();

    final page = tester.widget<QrScanPage>(find.byType(QrScanPage));
    expect(page.mode, QrScanMode.wallet);
    expect(page.customTitle, '扫码添加管理员');
    for (
      var i = 0;
      i < 100 &&
          _personalaccountcreatepagesdkHarness.fixture.nativeResources.isEmpty;
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      _personalaccountcreatepagesdkHarness.fixture.nativeResources,
      isNotEmpty,
    );
    _personalaccountcreatepagesdkHarness.fixture.scanText(
      wire,
      CitizenQrScanPurpose.generalScan,
    );
    final namesDialog = find.text('管理员姓名');
    for (var i = 0; i < 100 && namesDialog.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(namesDialog, findsOneWidget);
    expect(find.byType(QrScanPage), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('管理员列表（1/64）'), findsOneWidget);
    // 同一钱包再次扫描仍只能保留一名成员，姓名不改变钱包身份。
    await tester.tap(find.byKey(const ValueKey('personal-admin-scan-button')));
    await tester.pumpAndSettle();
    final duplicate = await _personalaccountcreatepagesdkHarness.sdk
        .parseForPurpose(wire, CitizenQrScanPurpose.generalScan);
    Navigator.of(tester.element(find.byType(QrScanPage))).pop(duplicate);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('该管理员已在列表中'), findsOneWidget);
    expect(find.text('管理员列表（1/64）'), findsOneWidget);
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
                FLAT_FEE: BigInt.zero,
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

      final sdk = _personalaccountcreatepagesdkHarness.sdk;
      final admin = await buildWalletAccountQrData(
        sdk,
        citizenAccountIdFromBytes(List<int>.filled(32, 42)),
      );
      final scanned = await sdk.parseForPurpose(
        admin,
        CitizenQrScanPurpose.generalScan,
      );
      await tester.tap(
        find.byKey(const ValueKey('personal-admin-scan-button')),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(QrScanPage))).pop(scanned);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      expect(find.text('管理员列表（2/64）'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '输入名称（如：家庭基金）'),
        '家庭基金',
      );
      final amountField = find.widgetWithText(TextField, '输入初始资金');
      await tester.ensureVisible(amountField);
      await tester.pumpAndSettle();
      await tester.enterText(amountField, amount);
      expect(
        parseFen(tester.widget<TextField>(amountField).controller!.text),
        parseFen(amount),
      );
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

// 原用例所属：personal/test/personal_pending_create_lookup_test.dart
// 验证待激活提案按账户、创建动作和投票状态精确匹配。

void _registerPersonalpendingcreatelookup() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  const personalAccount =
      '0x11223344556677889900aabbccddeeff'
      'ffeeddccbbaa00998877665544332211';

  test('无 entity → 返回 null', () async {
    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('仅有 executed/rejected entity → 不命中,返回 null', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(5),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.executed,
      yesCount: 3,
      noCount: 0,
    );
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(6),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.rejected,
      yesCount: 0,
      noCount: 3,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('voting 状态的 create entity 命中,返回 proposalId', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(99),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 1,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), BigInt.from(99));
  });

  test('voting 但 action != create(如 transfer)不命中', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(200),
      actionKind: PersonalProposalAction.transfer,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('其他多签账户的 entity 不命中(filter 按地址过滤)', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    const otherAccountId =
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
    await service.recordOrUpdate(
      accountId: otherAccountId,
      proposalId: BigInt.from(77),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
    expect(await lookup.findActiveCreate(otherAccountId), BigInt.from(77));
  });
}

void main() {
  group(
    'personal_account_create_page_test',
    _registerPersonalaccountcreatepage,
  );
  group(
    'personal_pending_create_lookup_test',
    _registerPersonalpendingcreatelookup,
  );
}
