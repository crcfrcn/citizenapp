import 'dart:async';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/creator/creator_page.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/creator/creator_tier_card.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/identity_badge.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/membership/membership_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'creator_test_support.dart';

class _Sessions extends Fake implements SquareSessionProvider {
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async =>
      const SquareSessionResolution(SquareSessionStatus.deviceUnavailable);
}

class _Resolver extends Fake implements FinalizedIdentityResolver {}

void main() {
  late f.Reader reader;
  late ChainDataService source;
  late CreatorTestUser user;
  late CreatorTestService service;
  late CitizenBlockRef head;
  late StreamController<CitizenSdkEvent> events;
  setUp(() {
    reader = f.Reader();
    user = CreatorTestUser();
    service = CreatorTestService();
    head = f.block(103);
    events = StreamController.broadcast(sync: true);
    source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => head,
      getGenesisHash: () async => user.genesisHash,
      getAccount: () async => user.ownerAccountId,
      events: events.stream,
    );
  });
  tearDown(() async {
    await source.close();
    await events.close();
  });
  Finder getSubscribe() => find.byKey(const ValueKey('creator-subscribe'));
  Finder getCreate() => find.widgetWithText(FilledButton, '创建会员档');
  Widget app({CreatorTestSecurity? security, Widget? home}) => creatorTestApp(
    source: source,
    user: user,
    service: service,
    security: security,
    home: home,
  );
  ChainCreatorTier tier(String name) => ChainCreatorTier(
    tierId: 'tier1',
    tierName: name,
    pricesFen: {'monthly': BigInt.from(990)},
  );
  Future<void> pull(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('订阅延迟期间逐帧显示禁用管理页，不出现旧引导或假空档', (tester) async {
    final pending = Completer<ChainDataSnapshot>();
    var first = true;
    reader.ownBehavior = (a, b, c, d, ownCreator) {
      if (first) {
        first = false;
        return pending.future;
      }
      return Future.value(
        f.snapshot(b, a, ownCreator: ownCreator, hasMembership: false),
      );
    };
    await tester.pumpWidget(app());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('我的创作者会员'), findsOneWidget);
      expect(find.text('去订阅平台会员'), findsNothing);
      expect(find.text('还没有会员档'), findsNothing);
      expect(find.text('已开通'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(tester.widget<TextButton>(getSubscribe()).onPressed, isNull);
      expect(tester.widget<FilledButton>(getCreate()).onPressed, isNull);
    }
    pending.complete(
      f.snapshot(head, user.ownerAccountId, hasMembership: false),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(getSubscribe());
    expect(button.onPressed, isNotNull);
    expect(button.style!.foregroundColor!.resolve({}), AppTheme.success);
    expect(tester.widget<FilledButton>(getCreate()).onPressed, isNull);
    expect(service.loadCalls, 0);
  });

  testWidgets('会员先就绪即显示徽章，档位与统计尚未就绪不允许编辑', (tester) async {
    await source.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.ownBehavior = (a, b, c, d, ownCreator) => pending.future;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('creator-membership-badge')),
      findsOneWidget,
    );
    expect(find.text('已开通'), findsOneWidget);
    expect(find.text('还没有会员档'), findsNothing);
    expect(tester.widget<FilledButton>(getCreate()).onPressed, isNull);
    pending.complete(
      f.snapshot(
        head,
        user.ownerAccountId,
        ownCreator: true,
        creatorTiers: [tier('链上铁杆')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('链上铁杆'), findsOneWidget);
    expect(
      tester.widget<CreatorTierCard>(find.byType(CreatorTierCard)).onEdit,
      isNotNull,
    );
    expect(find.text('--'), findsWidgets);
    expect(service.loadCalls, 0);
  });

  for (final level in ['freedom', 'democracy', 'spark']) {
    testWidgets('$level 对应有效会员徽章，统计加载不改变会员判断', (tester) async {
      final pending = Completer<CreatorOverview?>();
      service.readOverview = (_) => pending.future;
      reader.ownBehavior = (a, b, c, d, ownCreator) async =>
          f.snapshot(b, a, ownCreator: ownCreator, memberLevel: level);
      await source.start();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final badge = tester.widget<IdentityBadge>(
        find.byKey(const ValueKey('creator-membership-badge')),
      );
      expect(badge.style.checked, isTrue);
      expect(
        badge.style.color,
        identityBadgeStyle(
          cidLevel: null,
          memberLevel: level,
          membergateActive: true,
        )!.color,
      );
      expect(tester.widget<FilledButton>(getCreate()).onPressed, isNotNull);
      pending.complete(CreatorOverview.zero);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('creator-membership-badge')),
        findsOneWidget,
      );
    });
  }

  testWidgets('未订阅也显示已有档位但禁用编辑，缓存统计不能冒充会员有效', (tester) async {
    reader.ownBehavior = (a, b, c, d, ownCreator) async => f.snapshot(
      b,
      a,
      ownCreator: ownCreator,
      hasMembership: false,
      creatorTiers: [tier('旧档位')],
    );
    service.readOverview = (_) async => CreatorOverview.zero;
    await source.start();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('旧档位'), findsOneWidget);
    expect(
      tester.widget<CreatorTierCard>(find.byType(CreatorTierCard)).onEdit,
      isNull,
    );
    expect(find.text('已开通'), findsNothing);
    expect(getSubscribe(), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('订阅按钮跳转真实会员页，浏览返回不重置或重读创作者', (tester) async {
    final sdk = await openTestSdk();
    reader.ownBehavior = (a, b, c, d, ownCreator) async =>
        f.snapshot(b, a, ownCreator: ownCreator, hasMembership: false);
    await source.start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CitizenSdk>.value(value: sdk.sdk),
          Provider<FinalizedIdentityResolver>.value(value: _Resolver()),
          Provider<SquareSessionProvider>.value(value: _Sessions()),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(getSubscribe());
    await tester.pumpAndSettle();
    expect(find.byType(MembershipPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '会员｜订阅'), findsOneWidget);
    final before = reader.calls.length;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(getSubscribe(), findsOneWidget);
    expect(reader.calls.length, before);
    expect(service.loadCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('连续进出及中间最终块更新不额外补取创作者数据', (tester) async {
    await source.start();
    final home = Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => CreatorPage(service: service)),
        ),
        child: const Text('进入'),
      ),
    );
    await tester.pumpWidget(app(home: home));
    await tester.tap(find.text('进入'));
    await tester.pumpAndSettle();
    final before = reader.calls.length;
    await tester.pageBack();
    await tester.pumpAndSettle();
    head = f.block(104);
    await source.refresh();
    final afterBlock = reader.calls.length;
    expect(afterBlock, before + 1);
    await tester.tap(find.text('进入'));
    await tester.pumpAndSettle();
    expect(reader.calls.length, afterBlock);
    expect(find.text('已开通'), findsOneWidget);
    expect(service.loadCalls, 0);
  });

  testWidgets('链读取失败保留档位但撤销操作与徽章，重试恢复', (tester) async {
    reader.ownBehavior = (a, b, c, d, ownCreator) async =>
        f.snapshot(b, a, ownCreator: ownCreator, creatorTiers: [tier('保留档位')]);
    await source.start();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    reader.ownBehavior = (_, _, _, _, _) => Future.error(StateError('offline'));
    head = f.block(104);
    await expectLater(source.refresh(), throwsStateError);
    await tester.pumpAndSettle();
    expect(find.text('保留档位'), findsOneWidget);
    expect(
      tester.widget<CreatorTierCard>(find.byType(CreatorTierCard)).onEdit,
      isNull,
    );
    expect(tester.widget<TextButton>(getSubscribe()).onPressed, isNull);
    expect(
      find.byKey(const ValueKey('creator-membership-badge')),
      findsNothing,
    );
    reader.ownBehavior = (a, b, c, d, ownCreator) async =>
        f.snapshot(b, a, ownCreator: ownCreator, creatorTiers: [tier('保留档位')]);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CreatorTierCard>(find.byType(CreatorTierCard)).onEdit,
      isNotNull,
    );
    expect(find.text('会员状态暂不可用，请重试'), findsNothing);
  });

  testWidgets('云端统计故障保留档位和徽章，未知统计不显示为零', (tester) async {
    reader.ownBehavior = (a, b, c, d, ownCreator) async =>
        f.snapshot(b, a, ownCreator: ownCreator, creatorTiers: [tier('链上铁杆')]);
    service.refresh = () async => throw const CreatorException('云端统计不可用');
    await source.start();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await pull(tester);
    await tester.pumpAndSettle();
    expect(service.loadCalls, 1);
    expect(find.text('链上铁杆'), findsOneWidget);
    expect(find.text('统计暂不可用，请重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creator-membership-badge')),
      findsOneWidget,
    );
    expect(find.text('--'), findsWidgets);
  });

  testWidgets('进入时迟到的统计缓存不能覆盖用户刚刷新的统计', (tester) async {
    final cached = Completer<CreatorOverview?>();
    service.readOverview = (_) => cached.future;
    service.refresh = () async => CreatorPageData(
      overview: CreatorOverview(
        subscriberCount: 42,
        monthlyIncomeFen: BigInt.one,
        blockNumber: 103,
        blockHash: f.hash(103),
      ),
    );
    await source.start();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await pull(tester);
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    cached.complete(
      CreatorOverview(
        subscriberCount: 7,
        monthlyIncomeFen: BigInt.one,
        blockNumber: 86,
        blockHash: f.hash(86),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('同账户切换CID与绑定版本，旧统计迟到不能覆盖新页面', (tester) async {
    final security = CreatorTestSecurity();
    final oldOverview = Completer<CreatorOverview?>();
    final newSnapshot = Completer<ChainDataSnapshot>();
    service.readOverview = (cid) =>
        cid == f.cidA ? oldOverview.future : Future.value(null);
    reader.ownBehavior = (a, b, c, d, ownCreator) => user.cidNumber != f.cidA
        ? newSnapshot.future
        : Future.value(
            f.snapshot(
              b,
              a,
              ownCreator: ownCreator,
              creatorTiers: [tier('旧CID档')],
            ),
          );
    await source.start();
    await tester.pumpWidget(app(security: security));
    await tester.pumpAndSettle();
    expect(find.text('旧CID档'), findsOneWidget);
    user.cidNumber = f.cidB;
    user.bindRev = 2;
    head = f.block(104);
    security.revision.value++;
    await tester.pump();
    expect(find.text('旧CID档'), findsNothing);
    expect(tester.widget<TextButton>(getSubscribe()).onPressed, isNull);
    newSnapshot.complete(
      f.snapshot(
        head,
        user.ownerAccountId,
        cidNumber: f.cidB,
        bindRev: 2,
        ownCreator: true,
        hasMembership: false,
        creatorTiers: [tier('新CID档')],
      ),
    );
    await source.refresh();
    await tester.pumpAndSettle();
    oldOverview.complete(
      CreatorOverview(
        subscriberCount: 777,
        monthlyIncomeFen: BigInt.one,
        blockNumber: 103,
        blockHash: f.hash(103),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新CID档'), findsOneWidget);
    expect(find.text('777'), findsNothing);
    expect(find.text('已开通'), findsNothing);
    expect(tester.widget<TextButton>(getSubscribe()).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    security.revision.dispose();
  });

  testWidgets('取消续费但已付周期仍有效时保留徽章，到期后显示订阅按钮', (tester) async {
    reader.ownBehavior = (a, b, c, d, ownCreator) async => f.snapshot(
      b,
      a,
      ownCreator: ownCreator,
      subState: 'cancelled',
      paidUntil: 1104,
    );
    await source.start();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('creator-membership-badge')),
      findsOneWidget,
    );
    head = f.block(104);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(getSubscribe(), findsOneWidget);
    expect(tester.widget<FilledButton>(getCreate()).onPressed, isNull);
  });
}
