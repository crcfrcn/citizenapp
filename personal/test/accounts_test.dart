import 'package:citizen_personal/storage.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store;
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'chain_test.dart' show PersonalLifecycleFixture;
import 'proposals_test.dart' show PersonalproposalhistoryserviceOfflineChain;
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_citizen/proposal/proposal_registry.dart'
    show ProposalKind;
import 'package:citizen_sdk/citizen_sdk.dart';
// 个人多签accounts功能回归，保留迁入用例和断言。

import 'package:citizen_personal/accounts.dart';
import 'package:citizen_personal/members.dart';
import 'package:citizen_personal/proposals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 原用例所属：personal/test/personal_account_entry_test.dart
// 验证多签入口标题、箭头及整卡点击范围。

/// 交易页顶部唯一入口卡片。扫一扫已收进收款地址框,这里不得再出现扫码入口。
void _registerPersonalaccountentry() {
  testWidgets('渲染多签账户标题与右向 chevron', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PersonalAccountEntryCard())),
    );

    expect(find.text('多签账户'), findsOneWidget);
    expect(find.text('扫一扫'), findsNothing);

    final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    // 与链上交易状态行右侧同一颗:线性 chevron,22,不设颜色。
    expect(chevron.size, 22);
    expect(chevron.color, isNull);
  });

  testWidgets('整张卡片是点击区', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalAccountEntryCard(onTap: () => taps += 1)),
      ),
    );

    // 点标题与点箭头都应命中同一个点击区(箭头只作指示,不单独包 InkWell)。
    await tester.tap(find.text('多签账户'));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(taps, 2);
  });
}

void main() {
  group('撤销创建交互', _registerRevokeInterface);
  group('personal_account_entry_test', _registerPersonalaccountentry);
  test('个人多签真实名称完整进入上下文，未取得名称不伪造简称', () {
    final bytes = List.filled(32, 0x12);
    final named = personalAccountFromBytes(bytes, accountName: '家庭基金账户甲乙')!;
    expect(named.shortName, '家庭基金账户甲乙');
    expect(named.fullName, '家庭基金账户甲乙');
    final unnamed = personalAccountFromBytes(bytes)!;
    expect(unnamed.shortName, isEmpty);
    expect(unnamed.accountId, named.accountId);
  });

  test('个人账户只接受规范账户ID，机构CID不参与个人身份', () {
    final id = '0x${'aa' * 32}';
    expect(
      PersonalMemberIdentity.personalAccount(
        accountId: id,
        accountLabel: '个人',
      ).accountId,
      id,
    );
    expect(
      () => PersonalMemberIdentity.personalAccount(
        accountId: id.toUpperCase(),
        accountLabel: '个人',
      ),
      throwsFormatException,
    );
    expect(personalAccountFromBytes(citizenAccountIdBytes(id))!.accountId, id);
  });
  test('个人提案能力保留转账和成员变更，不依赖机构CID或岗位', () {
    final account = PersonalAccountInfo(
      fullName: '个人',
      shortName: '个人',
      accountId: '0x${'77' * 32}',
    );
    expect(PersonalProposalCapabilities.forAccount(account), {
      ProposalKind.transfer,
      ProposalKind.adminsChange,
    });
  });
}

void _registerRevokeInterface() {
  useIsolatedIsar();
  final harness = TestCitizenSdkHarness();
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<bool> localExists(String account) => UserIsar.instance.read(
    (isar) async =>
        await isar
            .collection<wallet_store.Account>()
            .filter()
            .accountIdEqualTo(account)
            .findFirst() !=
        null,
  );
  for (final mode in [
    'success',
    'pending-cleanup',
    'read-failure',
    'cold-cancel',
    'already-voted',
  ]) {
    testWidgets('撤销创建界面：$mode，冻结票据筛选与本机记录一致', (tester) async {
      final fixture = PersonalLifecycleFixture();
      late CitizenWalletState wallets;
      await tester.runAsync(() async {
        await fixture.initialize();
        fixture.clearRecords = mode != 'pending-cleanup';
        fixture.failCleanupRead = mode == 'read-failure';
        final walletIds = mode == 'already-voted'
            ? [fixture.creator]
            : [fixture.creator, fixture.peer];
        wallets = CitizenWalletState(
          revision: BigInt.one,
          activeWalletIndex: 0,
          hotProfile: null,
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          accounts: [
            for (var index = 0; index < walletIds.length; index++)
              CitizenWalletStateAccount(
                signMode: mode == 'cold-cancel' && index == 1
                    ? CitizenWalletSignMode.cold
                    : CitizenWalletSignMode.hot,
                walletIndex: index,
                accountIndex: 0,
                accountId: walletIds[index],
                ss58Address: citizenSs58FromAccountId(walletIds[index]),
                name: '成员$index',
                createdAtMillis: BigInt.one,
                isDefault: index == 0,
              ),
          ],
        );
        await UserIsar.instance.writeTxn((isar) async {
          await isar.collection<wallet_store.Account>().put(
            wallet_store.Account()
              ..accountId = fixture.account
              ..accountName = '待建账户'
              ..creatorAccount = fixture.creator
              ..addedAt = 1,
          );
          await PersonalMultisigLocalState.putStatusInTxn(
            isar,
            fixture.account,
            PersonalMultisigLocalState.statusPending,
          );
          await PersonalMultisigLocalState.putDetailInTxn(
            isar,
            fixture.account,
            MultisigLocalDetailSnapshot(
              groupState: 'pending',
              syncedAt: DateTime.now().millisecondsSinceEpoch,
              admins: [
                for (final id in [fixture.creator, fixture.peer])
                  PersonalMember(
                    accountId: id,
                    familyName: '备注',
                    givenName: '成员',
                  ),
              ],
              threshold: 1,
            ),
          );
        });
        await PersonalProposalHistoryService().recordOrUpdate(
          accountId: fixture.account,
          proposalId: fixture.pid,
          actionKind: PersonalProposalAction.create,
          status: PersonalProposalStatus.voting,
          yesCount: 1,
          noCount: 0,
          snapshot: {'amount_fen': '111'},
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await settleIo(tester);
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Provider<CitizenSdk>.value(
            value: harness.sdk,
            child: MaterialApp(
              home: PersonalManageAccountInfoPage(
                account: PersonalAccountInfo(
                  fullName: '待建账户',
                  shortName: '待建账户',
                  accountId: fixture.account,
                ),
                manageService: fixture.service(),
                historyService: PersonalProposalHistoryService(
                  getSyncStatus: PersonalproposalhistoryserviceOfflineChain()
                      .getSyncStatus,
                  getFinalizedHead: fixture.getFinalizedHead,
                  getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
                  getStorage: fixture.getStorage,
                  getStorageBatch: fixture.getStorageBatch,
                  getSystemEvents: fixture.getSystemEvents,
                ),
                walletStateLoader: () async => wallets,
                initialLocalStatus: 'pending',
                initialAdminAccountIds: [fixture.creator, fixture.peer],
              ),
            ),
          ),
        );
      });
      await settleIo(tester);
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      await tester.runAsync(() async {
        menu.onSelected!('revoke_create');
        menu.onSelected!('revoke_create');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settleIo(tester);
      if (mode == 'already-voted') {
        expect(find.byType(SimpleDialog), findsNothing);
        expect(fixture.tx.prepareCount, 0);
      } else {
        expect(
          find.byType(SimpleDialog),
          findsOneWidget,
          reason: find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .join(' | '),
        );
        final dialog = find.byType(SimpleDialog);
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining(fixture.creator.substring(0, 10)),
          ),
          findsNothing,
        );
        final candidate = find.descendant(
          of: dialog,
          matching: find.textContaining(fixture.peer.substring(0, 10)),
        );
        expect(candidate, findsOneWidget);
        if (mode == 'cold-cancel') {
          expect(
            find.descendant(of: dialog, matching: find.textContaining('冷钱包')),
            findsOneWidget,
          );
        }
        await tester.runAsync(() async {
          await tester.tap(candidate);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text(mode == 'cold-cancel' ? '取消' : '提交反对票'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await settleIo(tester);
        expect(
          fixture.tx.prepareCount,
          mode == 'cold-cancel' ? 0 : 1,
          reason: find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .join(' | '),
        );
      }
      expect(
        await tester.runAsync(() => localExists(fixture.account)),
        mode != 'success',
      );
      if (mode == 'pending-cleanup') {
        expect(find.textContaining('待同步到链上否决'), findsOneWidget);
      }
      if (mode == 'read-failure') {
        expect(find.textContaining('撤销未完成'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(seconds: 45)));
  }
}
