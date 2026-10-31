import 'dart:async';

import 'package:citizen_account/creator/creator_page.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

import 'package:citizen_account/creator/creator_service.dart';
import 'package:citizen_account/creator/creator_overview.dart';
import 'package:citizen_account/creator/creator_plan.dart';
import 'package:citizen_account/identity/cid_business_gate.dart';
import 'package:citizen_account/membership/subscription_service.dart';
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
  final Completer<CreatorPageData> completer = Completer<CreatorPageData>();
  int loadCalls = 0;
  String? lastSnapshotCid;

  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) {
    loadCalls++;
    return completer.future;
  }

  @override
  Future<CreatorDisplaySnapshot?> readDisplaySnapshot(String cidNumber) async {
    lastSnapshotCid = cidNumber;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// 主动刷新失败不能清掉已显示的本地数据。
class _FailingCreatorService implements CreatorService {
  int loadCalls = 0;

  @override
  Future<CreatorDisplaySnapshot?> readDisplaySnapshot(String cidNumber) async =>
      null;

  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    loadCalls++;
    throw Exception('MLS设备认证校验失败');
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

class _SnapshotCreatorService extends _PendingCreatorService {
  _SnapshotCreatorService(this.snapshot);

  final CreatorDisplaySnapshot snapshot;

  @override
  Future<CreatorDisplaySnapshot?> readDisplaySnapshot(String cidNumber) async =>
      snapshot;
}

void main() {
  useIsolatedIsar();
  const cidNumber = 'CN220-CTZN2-100000001-2026';

  testWidgets('入口旧 CID 在门禁未完成时不显示创作者业务，确认未注册后显示统一引导', (tester) async {
    final decision = Completer<CidBusinessDecision>();
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        gate: _BusinessGate(decision.future),
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    expect(find.text('已开通'), findsNothing);
    expect(service.lastSnapshotCid, isNull);
    decision.complete(
      const CidBusinessDecision(CidBusinessStatus.unregistered),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('已开通'), findsNothing);
    expect(service.lastSnapshotCid, isNull);
  });

  testWidgets('入口 CID 与当前绑定不同，仅按已核实 CID 读取展示快照', (tester) async {
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
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.lastSnapshotCid, currentCid);
    expect(find.text('已开通'), findsNothing);
  });

  testWidgets('身份核对故障时旧 CID 与刷新动作都不能读取创作者业务', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        gate: _BusinessGate(
          Future.value(
            const CidBusinessDecision(CidBusinessStatus.unavailable),
          ),
        ),
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法核实公民号身份'), findsOneWidget);
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
    await sdk.importColdAccount(accountId: testCitizenAccountId).result;
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
    expect(find.textContaining('暂时无法核实公民号身份'), findsOneWidget);
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
    expect(find.textContaining('暂时无法核实公民号身份'), findsNothing);
    // 新CID没有会员快照时保持未确认展示，不借旧入口状态伪造无会员结论。
    expect(find.byTooltip('刷新'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('已开通'), findsNothing);
    expect(resolver.calls, initialReads);
    expect(sessions.calls, initialSessions);
    expect(core.fixture.calls, isNot(contains('beginSigning')));
  });

  testWidgets('无会员缺失快照直接显示门禁且不自动联网', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision:
              MembershipDisplayDecision.inactiveConfirmed,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('创作者'), findsOneWidget);
    expect(find.text('去订阅平台会员'), findsOneWidget);
    expect(find.textContaining('同步'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.loadCalls, 0);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pump();
    expect(service.loadCalls, 1);

    service.completer.complete(CreatorPageData.gated());
  });

  testWidgets('有会员缺失快照直接显示创作者页且不自动联网', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('我的创作者会员'), findsOneWidget);
    expect(find.text('已开通'), findsOneWidget);
    expect(service.loadCalls, 0);
    expect(find.textContaining('同步'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    service.completer.complete(
      CreatorPageData.active(
        plan: CreatorPlan.empty(),
        overview: CreatorOverview.zero,
      ),
    );
  });

  testWidgets('无会员时只显示明确订阅门禁，不显示同步第三态', (tester) async {
    final service = _PendingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision:
              MembershipDisplayDecision.inactiveConfirmed,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('去订阅平台会员'), findsOneWidget);
    expect(find.textContaining('同步'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    service.completer.complete(
      CreatorPageData.active(
        plan: CreatorPlan.empty(),
        overview: CreatorOverview.zero,
      ),
    );
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

  test('展示快照的新鲜度分别约束会员与创作者数据', () {
    const nowMs = 1000000;
    final gated = CreatorDisplaySnapshot(
      cidNumber: cidNumber,
      data: CreatorPageData.gated(),
      memberAt: nowMs - 1000,
      creatorAt: 0,
    );
    expect(gated.isFresh(nowMs), isTrue, reason: '门禁态不需要创作者档位时间戳');

    final active = CreatorDisplaySnapshot(
      cidNumber: cidNumber,
      data: CreatorPageData.active(
        plan: CreatorPlan.empty(),
        overview: CreatorOverview.zero,
      ),
      memberAt: nowMs - 1000,
      creatorAt: 0,
    );
    expect(active.isFresh(nowMs), isFalse);
  });

  testWidgets('缺失快照不自动联网，主动刷新失败保留本地展示', (tester) async {
    final service = _FailingCreatorService();
    await tester.pumpWidget(
      _creatorApp(
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.loadCalls, 0);
    expect(find.text('重试'), findsNothing);
    expect(find.text('已开通'), findsOneWidget);
    expect(find.textContaining('同步'), findsNothing);
    expect(find.textContaining('MLS设备认证校验失败'), findsNothing);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(service.loadCalls, 1);
    expect(find.text('已开通'), findsOneWidget);
    expect(find.textContaining('MLS设备认证校验失败'), findsOneWidget);
  });

  testWidgets('过期本地快照仍显示真实档位且不自动联网', (tester) async {
    const nowMs = 1;
    final service = _SnapshotCreatorService(
      CreatorDisplaySnapshot(
        cidNumber: cidNumber,
        data: CreatorPageData.active(
          plan: const CreatorPlan(
            tiers: [
              CreatorTier(
                tierId: 'local',
                tierName: '本地会员档',
                monthFen: 990,
                quarterFen: null,
                yearFen: null,
              ),
            ],
          ),
          overview: const CreatorOverview(
            subscriberCount: 7,
            monthlyIncomeFen: 1234,
            tierCount: 1,
          ),
        ),
        memberAt: nowMs,
        creatorAt: nowMs,
      ),
    );
    await tester.pumpWidget(
      _creatorApp(
        home: CreatorPage(
          service: service,
          initialCidNumber: cidNumber,
          initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('本地会员档'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('同步'), findsNothing);
    expect(service.loadCalls, 0);
  });
}
