// 验证创作者身份门禁、档位价格及未知状态不越权。

import 'dart:async';

import 'package:citizen_user/creator/creator_page.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/register_identity_sheet.dart';
import 'package:citizen_user/identity/identity_badge_snapshot_store.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/creator/creator_plan.dart';
import 'package:citizen_user/identity/cid_business_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _BusinessGate implements CidBusinessGate {
  _BusinessGate(this.result);
  Future<CidBusinessDecision> result;
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() => result;
}

class _CreatorSecurity extends Fake implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
}

class _RegistrationSecurity extends _CreatorSecurity {
  VoidCallback? onNotify;
  int notifications = 0;

  @override
  void notifyIdentityBindingChanged() {
    notifications++;
    onNotify?.call();
    revision.value++;
  }
}

class _UnregisteredCurrentUser extends Fake implements CurrentUserContext {
  _UnregisteredCurrentUser(this.account);
  final CitizenWalletStateAccount account;

  @override
  Future<CurrentUser?> resolve() async =>
      CurrentUser(account: account, binding: null, verifiedUnregistered: true);

  @override
  void invalidate() {}
}

class _UnregisteredResolver extends Fake implements FinalizedIdentityResolver {
  _UnregisteredResolver(this.account);
  final CitizenWalletStateAccount account;

  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: account.accountId,
    accountAddress: account.ss58Address,
    snapshot: null,
  );

  @override
  Future<void> assertCurrent(FinalizedIdentity identity) async {}
}

class _RegistrationSessions extends _CreatorSessions {
  @override
  void invalidateAccount(String accountId) {}
}

class _CreatorResolver extends Fake implements FinalizedIdentityResolver {
  int calls = 0;
  @override
  Future<FinalizedIdentity?> resolve() async {
    calls++;
    throw StateError('展示不能查链');
  }
}

class _CreatorSessions extends Fake implements SquareSessionProvider {
  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    throw StateError('展示不能建立会话');
  }
}

Widget _creatorApp({required Widget home, CidBusinessGate? gate}) =>
    Provider<CidBusinessGate>.value(
      value:
          gate ??
          _BusinessGate(
            Future.value(
              const CidBusinessDecision(
                CidBusinessStatus.ready,
                cidNumber: 'CN220-CTZN2-100000001-2026',
              ),
            ),
          ),
      child: MaterialApp(home: home),
    );

class _PendingCreatorService implements CreatorService {
  @override
  Future<CreatorOverview?> cachedOverview(String cid) async => null;
  final Completer<CreatorPageData> completer = Completer<CreatorPageData>();
  int loadCalls = 0;
  String? lastSnapshotCid;

  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) {
    loadCalls++;
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  useIsolatedIsar();
  const cidNumber = 'CN220-CTZN2-100000001-2026';

  for (final knownUnregistered in [false, true]) {
    testWidgets('创作者单次注册不闪现管理模板（已有未注册快照：$knownUnregistered）', (tester) async {
      final core = await openTestSdk(
        modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
      );
      final sdk = core.sdk;
      await tester.runAsync(
        () => sdk.importColdAccount(testCitizenAccountId).result,
      );
      final wallet = await tester.runAsync(() => sdk.getWalletState().result);
      final account = wallet!.defaultAccount!;
      if (knownUnregistered) {
        await tester.runAsync(
          () => IdentityBadgeSnapshotStore().writeVerified(
            accountId: account.accountId,
            identity: null,
            isCurrent: () => true,
          ),
        );
      }
      final gate = _BusinessGate(
        Future.value(const CidBusinessDecision(CidBusinessStatus.unregistered)),
      );
      final security = _RegistrationSecurity();
      final recheck = Completer<CidBusinessDecision>();
      security.onNotify = () => gate.result = recheck.future;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(sdk.close);
        security.revision.dispose();
        gate.revision.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CitizenSdk>.value(value: sdk),
            Provider<AccountSecurityService>.value(value: security),
            Provider<CurrentUserContext>.value(
              value: _UnregisteredCurrentUser(account),
            ),
            Provider<FinalizedIdentityResolver>.value(
              value: _UnregisteredResolver(account),
            ),
            Provider<SquareSessionProvider>.value(
              value: _RegistrationSessions(),
            ),
            Provider<CidBusinessGate>.value(value: gate),
          ],
          child: MaterialApp(
            home: CreatorPage(service: _PendingCreatorService()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('注册'));
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(RegisterIdentitySheet).evaluate().isNotEmpty) break;
      }
      expect(security.notifications, knownUnregistered ? 0 : 1);
      expect(find.byType(RegisterIdentitySheet), findsOneWidget);
      expect(find.text('我的创作者会员', skipOffstage: false), findsNothing);
      expect(find.text('创建和管理你的会员档。', skipOffstage: false), findsNothing);
      if (knownUnregistered) {
        expect(find.text('尚未注册', skipOffstage: false), findsOneWidget);
      }
      recheck.complete(
        const CidBusinessDecision(CidBusinessStatus.unregistered),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RegisterIdentitySheet), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterIdentitySheet), findsNothing);
      expect(find.text('尚未注册'), findsOneWidget);
    });
  }

  testWidgets('身份核对未完成时禁用创作者业务，确认未注册后显示统一引导', (tester) async {
    final decision = Completer<CidBusinessDecision>();
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        gate: _BusinessGate(decision.future),
        home: CreatorPage(service: service),
      ),
    );
    expect(find.text('已开通'), findsNothing);
    expect(find.text('我的创作者会员'), findsNothing);
    expect(service.lastSnapshotCid, isNull);
    decision.complete(
      const CidBusinessDecision(CidBusinessStatus.unregistered),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('已开通'), findsNothing);
    expect(service.lastSnapshotCid, isNull);
  });

  testWidgets('当前 CID 已核实但链快照缺失时不伪造会员状态', (tester) async {
    final service = _PendingCreatorService();
    const currentCid = 'CN220-CTZN2-100000002-2026';
    await tester.pumpWidget(
      _creatorApp(
        gate: _BusinessGate(
          Future.value(
            const CidBusinessDecision(
              CidBusinessStatus.ready,
              cidNumber: currentCid,
            ),
          ),
        ),
        home: CreatorPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.lastSnapshotCid, isNull);
    expect(find.text('已开通'), findsNothing);
  });

  testWidgets('身份核对故障与重试均不能越过身份检查读取创作者业务', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        gate: _BusinessGate(
          Future.value(
            const CidBusinessDecision(CidBusinessStatus.unavailable),
          ),
        ),
        home: CreatorPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法核实身份CID号'), findsOneWidget);
    expect(find.text('我的创作者会员'), findsNothing);
    expect(find.text('已开通'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(service.lastSnapshotCid, isNull);
    expect(service.loadCalls, 0);
  });

  testWidgets('生产监听路径在身份同步广播后原地退出未知，不增加链或会话请求', (tester) async {
    final gate = _BusinessGate(
      Future.value(const CidBusinessDecision(CidBusinessStatus.unavailable)),
    );
    final security = _CreatorSecurity(),
        resolver = _CreatorResolver(),
        sessions = _CreatorSessions();
    final core = await openTestSdk(
      modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
    );
    final sdk = core.sdk;
    await tester.runAsync(
      () => sdk.importColdAccount(testCitizenAccountId).result,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await sdk.close();
      });
      security.revision.dispose();
      gate.revision.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CitizenSdk>.value(value: sdk),
          Provider<AccountSecurityService>.value(value: security),
          Provider<FinalizedIdentityResolver>.value(value: resolver),
          Provider<SquareSessionProvider>.value(value: sessions),
          Provider<CidBusinessGate>.value(value: gate),
        ],
        child: const MaterialApp(home: CreatorPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法核实身份CID号'), findsOneWidget);
    // 构造时原会员恢复可能核对一次身份，本次广播不得追加链或会话请求。
    final initialReads = resolver.calls, initialSessions = sessions.calls;
    gate.result = Future.value(
      const CidBusinessDecision(CidBusinessStatus.ready, cidNumber: cidNumber),
    );
    security.revision.value++;
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(find.textContaining('暂时无法核实身份CID号'), findsNothing);
    // 新CID没有会员快照时保持未确认展示，不借旧入口状态伪造无会员结论。
    expect(find.byTooltip('刷新'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('creator-subscribe')))
          .onPressed,
      isNull,
    );
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('已开通'), findsNothing);
    expect(resolver.calls, initialReads);
    expect(sessions.calls, initialSessions);
    expect(core.fixture.calls, isNot(contains('beginSigning')));
  });

  testWidgets('缺失快照保持管理页和禁用订阅，不自动建立会话', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(_creatorApp(home: CreatorPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('我的创作者会员'), findsOneWidget);
    expect(find.text('去订阅平台会员'), findsNothing);
    expect(find.text('已开通'), findsNothing);
    expect(find.text('还没有会员档'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('creator-subscribe')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建会员档'))
          .onPressed,
      isNull,
    );
    expect(service.loadCalls, 0);
  });

  group('CreatorTier JSON', () {
    test('Rust tiers实际价格列；缺失/坏列表拒绝而非免费', () {
      final tier = CreatorTier.fromJson({
        'tier_id': 'a',
        'tier_name': '支持者',
        'month_fen': 500,
        'quarter_fen': null,
        'year_fen': 5000,
      });
      expect(tier.priceFenOf(BillingPeriod.monthly), 500);
      expect(tier.priceFenOf(BillingPeriod.yearly), 5000);
      expect(
        () => CreatorTier.fromJson({'tier_id': 'a', 'tier_name': '支持者'}),
        throwsFormatException,
      );
      expect(
        () => CreatorPlan.fromJson({
          'tiers': [false],
        }),
        throwsFormatException,
      );
    });
    test('toJson/fromJson 往返（分口径）', () {
      const tier = CreatorTier(
        tierId: 't1',
        tierName: '铁杆粉丝',
        monthFen: 990,
        quarterFen: null,
        yearFen: 9900,
      );
      final json = tier.toJson();
      expect(json, {
        'tier_id': 't1',
        'tier_name': '铁杆粉丝',
        'month_fen': 990,
        'quarter_fen': null,
        'year_fen': 9900,
      });

      final back = CreatorTier.fromJson(json);
      expect(back.tierId, 't1');
      expect(back.tierName, '铁杆粉丝');
      expect(back.priceFenOf(BillingPeriod.monthly), 990);
      expect(back.priceFenOf(BillingPeriod.yearly), 9900);
      expect(back.hasPeriod(BillingPeriod.quarterly), isFalse);
    });

    test('fromJson拒绝非正、越界和旧价格结构', () {
      for (final value in [0, -5, 9007199254740992, '100', 1.5]) {
        expect(
          () => CreatorTier.fromJson({
            'tier_id': 't2',
            'tier_name': 'x',
            'month_fen': value,
            'quarter_fen': null,
            'year_fen': 100,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => CreatorTier.fromJson({
          'tier_id': 't2',
          'tier_name': 'x',
          'prices_fen': {'monthly': 100},
        }),
        throwsFormatException,
      );
    });
  });

  group('CreatorPlan', () {
    test('fromJson 解析档位列表', () {
      final plan = CreatorPlan.fromJson({
        'tiers': [
          {
            'tier_id': 'a',
            'tier_name': '基础',
            'month_fen': 500,
            'quarter_fen': null,
            'year_fen': null,
          },
        ],
      });
      expect(plan.toJson().keys, ['tiers']);
      expect(plan.tiers, hasLength(1));
      expect(plan.tiers.first.priceFenOf(BillingPeriod.monthly), 500);
    });

    test('empty 构造无档位', () {
      final plan = CreatorPlan.empty();
      expect(plan.isEmpty, isTrue);
      expect(CreatorPlan.maxTiers, 10);
    });
  });
}
