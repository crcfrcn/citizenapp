// 验证创作者通知刷新及订阅按钮交互。

import 'dart:async';
import 'package:citizen_chain/service.dart';
import 'package:citizen_testing/chain.dart' as f;
import 'package:citizen_testing/database.dart';
import 'package:citizen_user/creator/service.dart' show CreatorApiException, CreatorOverview, CreatorPageData, CreatorPlan, CreatorSubscriptionState, CreatorView;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/membership/service.dart' show MembershipRevision;
import 'package:citizen_user/notifications.dart' show Notifications;
import 'package:citizen_user/api.dart' show SquareApiClient, SquareSession;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fixtures.dart' show CreatorTestService, CreatorTestUser, creatorTestApp;
import 'package:citizen_user/creator/button.dart' show CreatorSubscribeButton;
import 'package:citizen_user/creator/subscription.dart' show CreatorSubscribeService;
import 'package:citizen_testing/profile.dart';

void main() {
  group('creator_notification_refresh_test', suite72);
  group('creator_subscribe_button_test', suite98);
}

// 验证通知状态不阻断概览刷新或引入额外链读取。

class _Sessions extends Fake implements SquareSessionProvider {}

void suite72() {
  useIsolatedIsar();
  for (final notificationReady in [false, true]) {
    testWidgets('通知就绪=$notificationReady，会员广播不取消概览刷新也不新增链读', (tester) async {
      final user = CreatorTestUser();
      final notificationUser = CreatorTestUser()
        ..cidNumber = notificationReady ? f.cidA : '';
      final api = SquareApiClient(baseUrl: 'https://review.test/api');
      Notifications.instance.invalidate();
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: notificationUser,
      );
      await tester.runAsync(() => Notifications.instance.restore());
      final reader = f.Reader();
      final source = ChainDataService(
        reader: reader,
        getFinalizedHead: () async => f.block(103),
        getGenesisHash: () async => f.hash(0),
        getAccount: () async => user.ownerAccountId,
      );
      final result = Completer<CreatorPageData>();
      final service = CreatorTestService()..refresh = () => result.future;
      addTearDown(() async {
        Notifications.instance.invalidate();
        api.close();
        await source.close();
      });
      await source.start();
      await tester.pumpWidget(
        creatorTestApp(source: source, user: user, service: service),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(service.loadCalls, 1);
      final before = reader.calls.length;
      MembershipRevision.instance.notifyChanged(f.cidA);
      MembershipRevision.instance.notifyChanged(f.cidB);
      await tester.pump();
      result.complete(
        CreatorPageData(
          overview: CreatorOverview(
            subscriberCount: 42,
            monthlyIncomeFen: BigInt.from(1234),
            blockNumber: 103,
            blockHash: f.hash(103),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      expect(reader.calls.length, before);
      expect(find.text('已开通'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

// 验证创作者有效档位控制订阅入口及二级操作。

/// 只覆盖订阅按钮的 CitizenServe 投影门禁：服务端返回有效档位才显示，其余隐藏。
class _FakeSubscribeService implements CreatorSubscribeService {
  _FakeSubscribeService({required this.view, this.throwView = false});

  final CreatorView view;
  final bool throwView;

  @override
  Future<CreatorView> fetchView(
    SquareSession session,
    String creatorCid,
  ) async {
    if (throwView) throw const CreatorApiException('service unavailable');
    return view;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _plan = CreatorPlan.fromJson({
  'tiers': [
    {
      'tier_id': 't1',
      'tier_name': '支持者',
      'month_fen': 299,
      'quarter_fen': null,
      'year_fen': null,
    },
  ],
});

CreatorSubscriptionState _activeCreatorSubscription() =>
    const CreatorSubscriptionState(
      tierId: 't1',
      billingPeriod: 'monthly',
      subState: 'active',
      paidUntil: 9999999999999,
    );

void suite98() {
  Future<void> pump(
    WidgetTester tester, {
    required bool creatorActive,
    bool hasTiers = true,
    CreatorSubscriptionState? subscriberState,
    bool throwCreator = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreatorSubscribeButton(
            creatorCid: 'CN001-CTZN-000000001-2026',
            service: _FakeSubscribeService(
              view: CreatorView(
                plan: creatorActive && hasTiers ? _plan : null,
                subscription: subscriberState,
              ),
              throwView: throwCreator,
            ),
            sessionProvider: FakeSessionProvider(fakeSession()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('有档 且 创作者平台会员 active → 显示订阅按钮', (tester) async {
    await pump(tester, creatorActive: true);
    expect(find.text('订阅'), findsOneWidget);
  });

  testWidgets('已订阅时页头仍只显示单一入口，二级操作收入底部面板', (tester) async {
    await pump(
      tester,
      creatorActive: true,
      subscriberState: _activeCreatorSubscription(),
    );

    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('更换会员档'), findsNothing);
    expect(find.text('取消订阅'), findsNothing);

    await tester.tap(find.text('订阅'));
    await tester.pumpAndSettle();

    expect(find.text('更换会员档'), findsOneWidget);
    expect(find.text('取消订阅'), findsOneWidget);
  });

  testWidgets('CitizenServe 不返回创作者有效档位时隐藏', (tester) async {
    await pump(tester, creatorActive: false);
    expect(find.text('订阅'), findsNothing);
  });

  testWidgets('CitizenServe 创作者投影读取失败时隐藏（fail-closed）', (tester) async {
    await pump(tester, creatorActive: true, throwCreator: true);
    expect(find.text('订阅'), findsNothing);
  });

  testWidgets('无档 → 隐藏（既有行为不回归）', (tester) async {
    await pump(tester, creatorActive: true, hasTiers: false);
    expect(find.text('订阅'), findsNothing);
  });
}
