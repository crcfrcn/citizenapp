// 验证三档身份卡、当前身份排序及刷新换绑的真实状态交付。

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/identity_cid_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_user/identity/registration_coordinator.dart';
import 'package:citizen_user/identity/registration_models.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';

import 'registration_api_test.dart' show registrationContext;
import 'registration_coordinator_test.dart'
    show Api, MemoryStore, VerifiedCoordinator;

import 'package:citizen_user/identity/myid_page.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_badge_snapshot_store.dart';
import 'package:citizen_user/identity/register_identity_sheet.dart';
import 'package:citizen_user/identity/myid_service.dart';
import 'package:citizen_system/theme/app_layout.dart';

const MyIdState _votingState = MyIdState(
  tier: MyIdTier.voting,
  status: MyIdStatus.normal,
  votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
  cidNumber: 'CID-2026-0715',
  residenceDistrict: '中枢省 · 固市 · 和平镇',
  passportValidFrom: '2026-07-15',
  passportValidUntil: '2036-07-14',
);

const MyIdState _candidateState = MyIdState(
  tier: MyIdTier.candidate,
  status: MyIdStatus.normal,
  votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
  cidNumber: 'CID-2026-0715',
  residenceDistrict: '中枢省 · 固市 · 和平镇',
  passportValidFrom: '2026-07-15',
  passportValidUntil: '2036-07-14',
  familyName: '张',
  givenName: '三',
  citizenSexLabel: '男',
  birthDistrict: '中枢省 · 固市 · 和平镇',
  citizenBirthDate: '1992-05-18',
);

void main() {
  testWidgets('身份核实加载和未知失败状态均无横幅弹窗提示', (tester) async {
    for (final status in [MyIdStatus.unknown, MyIdStatus.queryFailed]) {
      final state = MyIdState(
        tier: MyIdTier.visitor,
        status: status,
        errorMessage: 'fixture-internal-identity-error',
      );
      final service = _FakeMyIdService(state);
      final pending = Completer<MyIdState>();
      service.pending = pending.future;
      await tester.pumpWidget(
        MaterialApp(home: MyIdPage(myIdService: service)),
      );
      await tester.pump();
      expect(find.textContaining('正在同步'), findsNothing);
      expect(find.textContaining('核实后自动更新'), findsNothing);
      expect(find.text('fixture-internal-identity-error'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      pending.complete(state);
      await tester.pumpAndSettle();
      expect(find.text('fixture-internal-identity-error'), findsNothing);
      expect(find.text('身份验证失败，请重试'), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  Finder card(MyIdTier tier) =>
      find.byKey(ValueKey<String>('passport-card-${tier.name}'));

  double cardTop(WidgetTester tester, MyIdTier tier) =>
      tester.getTopLeft(card(tier)).dy;

  Future<void> pumpPage(
    WidgetTester tester,
    MyIdState state, {
    Size? surfaceSize,
  }) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(home: MyIdPage(myIdService: _FakeMyIdService(state))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('身份页没有独立恢复入口，打开与下拉复用公开同步', (tester) async {
    final service = _FakeMyIdService(_votingState);
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    expect(find.text('恢复服务'), findsNothing);
    expect(service.refreshes, 1);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(service.refreshes, 2);
    expect(find.text(_votingState.cidNumber!), findsOneWidget);
  });

  testWidgets('刷新期间切换账户丢弃旧结果并读取当前展示', (tester) async {
    final service = _FakeMyIdService(_votingState);
    final current = _PageCurrentUser();
    await tester.pumpWidget(
      Provider<CurrentUserContext>.value(
        value: current,
        child: MaterialApp(home: MyIdPage(myIdService: service)),
      ),
    );
    await tester.pumpAndSettle();
    final pending = Completer<MyIdState>();
    service.pending = pending.future;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    current.selectedAccountId = '0x${'22' * 32}';
    service.state = const MyIdState(
      tier: MyIdTier.visitor,
      cidNumber: 'CID-NEW',
    );
    IdentityBadgeSnapshotStore.revision.value++;
    pending.complete(_votingState);
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('CID-NEW'), findsOneWidget);
    expect(find.text(_votingState.cidNumber!), findsNothing);
    expect(find.text('身份验证失败，请重试'), findsNothing);
  });

  testWidgets('换绑只执行原流程，完成并回读新身份后才提示成功，重新进入仍显示CID', (tester) async {
    const initial = MyIdState(
      tier: MyIdTier.visitor,
      status: MyIdStatus.normal,
      cidNumber: 'CN583-CTZN2-763721825-2026',
    );
    final service = _RebindPageService(initial);
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '更换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('目标冷账户'));
    await tester.pump();
    expect(service.calls, 1);
    expect(find.text(identityCidUiText('身份 CID 已换绑到所选账户')), findsNothing);
    service.publish(const MyIdState(tier: MyIdTier.visitor));
    await tester.pump();
    expect(
      find.text(formatIdentityCidText(initial.cidNumber!)),
      findsOneWidget,
      reason: '提交期间迟到广播不能清空原CID',
    );
    service.state = initial;
    service.finished.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(formatIdentityCidText(initial.cidNumber!)),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '更换'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '注册'), findsNothing);
    expect(find.text(identityCidUiText('身份 CID 已换绑到所选账户')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    expect(
      find.text(formatIdentityCidText(initial.cidNumber!)),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '更换'), findsOneWidget);
    expect(service.calls, 1);
    expect(
      service.state.cidNumber,
      initial.cidNumber,
      reason: '显示格式不改变完整业务CID',
    );
  });

  testWidgets('三张身份卡始终存在且旧访客文案彻底删除', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));

    expect(find.text('身份 · 访客'), findsOneWidget);
    expect(find.text('公民身份 · 投票'), findsOneWidget);
    expect(find.text('公民身份 · 竞选'), findsOneWidget);
    // 旧文案零残留
    expect(find.text('匿名访客'), findsNothing);
    expect(find.text('注册身份·访客'), findsNothing);
    expect(find.text('公民 · 投票身份'), findsNothing);
    expect(find.text('公民 · 竞选身份'), findsNothing);
    expect(find.text('没有公民身份信息'), findsNothing);
    // 访客卡改用“匿名”小标签替代整段空态
    expect(
      find.byKey(const ValueKey<String>('passport-anonymous-tag')),
      findsOneWidget,
    );
    expect(find.text('匿名'), findsOneWidget);
  });

  testWidgets('访客当前卡排第一且公民卡只显示字段名称', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));

    expect(
      cardTop(tester, MyIdTier.visitor),
      lessThan(cardTop(tester, MyIdTier.voting)),
    );
    expect(
      cardTop(tester, MyIdTier.voting),
      lessThan(cardTop(tester, MyIdTier.candidate)),
    );
    // 纯访客(无 CID)当前卡置顶但不挂「当前身份」徽章。
    expect(find.text('当前身份'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('current-identity-visitor')),
      findsNothing,
    );
    expect(find.text('绑定账户'), findsNWidgets(2));
    expect(find.text('公民姓名'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('投票身份卡置顶并且只有该卡显示真实值', (tester) async {
    await pumpPage(tester, _votingState);

    expect(
      cardTop(tester, MyIdTier.voting),
      lessThan(cardTop(tester, MyIdTier.visitor)),
    );
    expect(
      cardTop(tester, MyIdTier.visitor),
      lessThan(cardTop(tester, MyIdTier.candidate)),
    );
    expect(
      find.byKey(const ValueKey<String>('current-identity-voting')),
      findsOneWidget,
    );
    expect(find.text('当前身份'), findsOneWidget);
    expect(find.text('w5BekTim......weR8vMgf7o8E'), findsOneWidget);
    expect(find.text('CID-2026-0715'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: card(MyIdTier.voting),
              matching: find.text('身份CID号'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: card(MyIdTier.voting),
                matching: find.text('绑定账户'),
              ),
            )
            .dy,
      ),
    );
    expect(find.text('中枢省 · 固市 · 和平镇'), findsOneWidget);
    expect(find.text('正常'), findsOneWidget);
    expect(find.text('2026年07月15日 至 2036年07月14日'), findsOneWidget);

    final candidateCard = card(MyIdTier.candidate);
    expect(
      find.descendant(of: candidateCard, matching: find.text('公民姓名')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: candidateCard, matching: find.text('CID-2026-0715')),
      findsNothing,
    );
  });

  testWidgets('竞选身份卡置顶并显示九项真实字段，投票卡不重复数据', (tester) async {
    await pumpPage(tester, _candidateState);

    expect(
      cardTop(tester, MyIdTier.candidate),
      lessThan(cardTop(tester, MyIdTier.visitor)),
    );
    expect(
      cardTop(tester, MyIdTier.visitor),
      lessThan(cardTop(tester, MyIdTier.voting)),
    );
    expect(
      find.byKey(const ValueKey<String>('current-identity-candidate')),
      findsOneWidget,
    );
    expect(find.text('当前身份'), findsOneWidget);
    expect(find.text('w5BekTim......weR8vMgf7o8E'), findsOneWidget);
    expect(find.text('CID-2026-0715'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('男'), findsOneWidget);
    expect(find.text('1992年05月18日'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: card(MyIdTier.candidate),
              matching: find.text('身份CID号'),
            ),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(
                of: card(MyIdTier.candidate),
                matching: find.text('绑定账户'),
              ),
            )
            .dy,
      ),
    );

    final votingCard = card(MyIdTier.voting);
    expect(
      find.descendant(of: votingCard, matching: find.text('绑定账户')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: votingCard, matching: find.text('CID-2026-0715')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: votingCard,
        matching: find.text('w5BekTim......weR8vMgf7o8E'),
      ),
      findsNothing,
    );
  });

  testWidgets('链读失败不降级访客，三卡都没有当前身份和真实值', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.queryFailed,
        errorMessage: '链上身份读取失败',
      ),
    );

    expect(find.text('身份验证失败，请重试'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.text('当前身份'), findsNothing);
    expect(find.text('身份 · 访客'), findsNothing);
    expect(
      find.descendant(of: card(MyIdTier.visitor), matching: find.text('身份')),
      findsOneWidget,
    );
    expect(find.text('注册身份·访客'), findsNothing);
    expect(find.text('公民身份 · 投票'), findsOneWidget);
    expect(find.text('公民身份 · 竞选'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('没有默认热钱包的纯访客不挂徽章且无提示横幅', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(tier: MyIdTier.visitor, errorMessage: '请先创建钱包'),
    );

    expect(find.text('请先创建钱包'), findsNothing);
    // 纯访客(无 CID)不挂「当前身份」徽章。
    expect(
      find.byKey(const ValueKey<String>('current-identity-visitor')),
      findsNothing,
    );
    expect(find.text('当前身份'), findsNothing);
    // 空态文案已删，访客卡改以“匿名”小标签呈现
    expect(find.text('没有公民身份信息'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('passport-anonymous-tag')),
      findsOneWidget,
    );
  });

  testWidgets('过期和吊销只改变当前卡状态，不改变身份排序', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.voting,
        status: MyIdStatus.expired,
        votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
        cidNumber: 'CID-2026-0715',
        residenceDistrict: '中枢省 · 固市 · 和平镇',
        passportValidFrom: '2020-01-01',
        passportValidUntil: '2025-01-01',
      ),
    );

    expect(
      cardTop(tester, MyIdTier.voting),
      lessThan(cardTop(tester, MyIdTier.visitor)),
    );
    expect(find.text('已过期'), findsOneWidget);
  });

  testWidgets('窄屏和长字段不会产生布局溢出', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.candidate,
        status: MyIdStatus.normal,
        votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
        cidNumber: 'CID-VERY-LONG-2026-0715-EXAMPLE',
        residenceDistrict: '中枢省 · 很长的城市名称 · 很长的乡镇名称',
        passportValidFrom: '2026-07-15',
        passportValidUntil: '2036-07-14',
        familyName: '这是一个用于验证窄屏自动换行的较长公民',
        givenName: '姓名',
        citizenSexLabel: '男',
        birthDistrict: '中枢省 · 很长的出生城市名称 · 很长的出生乡镇名称',
        citizenBirthDate: '1992-05-18',
      ),
      surfaceSize: const Size(320, 1600),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('公民身份 · 竞选'), findsOneWidget);
  });

  // 余额用例通过合成人验结果与Siteverify边界进入真实编排，不保存人验状态。
  Future<void> pumpRegistration(
    WidgetTester tester,
    _RegisterFlowService service, {
    void Function(String)? onTopup,
  }) async {
    final api = Api([]);
    final store = MemoryStore([]);
    service.api = api;
    addTearDown(api.close);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RegistrationCoordinator>.value(
            value: VerifiedCoordinator(api: api, store: store),
          ),
          Provider<FinalizedIdentityResolver>.value(
            value: _UnregisteredIdentity(),
          ),
        ],
        child: MaterialApp(
          home: MyIdPage(
            myIdService: service,
            openRegistrationTopup: (_, accountId) async =>
                onTopup?.call(accountId),
          ),
        ),
      ),
    );
  }

  testWidgets('余额不足 → 不提交注册，先引导去链上充值', (tester) async {
    // 占号是自签自付的链上交易，余额不够连入池预检都过不了；先充值再注册。
    final service = _RegisterFlowService(balanceFen: 0);
    String? topupAccount;
    await pumpRegistration(tester, service, onTopup: (id) => topupAccount = id);
    await tester.pumpAndSettle();

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 0);
    expect(topupAccount, isNull);
    await tester.tap(find.text('充值/USDT'));
    await tester.pumpAndSettle();
    expect(topupAccount, registrationContext().accountId);
    expect(find.textContaining('注册失败：钱包余额不足'), findsOneWidget);
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
  });

  testWidgets('余额读取失败 → 既不提交也不跳充值，只提示重试(fail-closed)', (tester) async {
    final service = _RegisterFlowService(affordabilityThrows: true);
    await pumpRegistration(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 0);
    expect(find.textContaining('余额读取失败'), findsOneWidget);
    expect(find.textContaining('钱包余额不足'), findsNothing);
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.text('链上充值'), findsNothing);
  });

  testWidgets('余额达标 → 正常提交注册', (tester) async {
    final service = _RegisterFlowService(balanceFen: 121);
    await pumpRegistration(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 1);
  });

  testWidgets('不出现已下线的登记、换钱包和扫码入口', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));
    expect(find.text('护照号'), findsNothing);
    expect(find.text('选择钱包'), findsNothing);
    expect(find.text('更换钱包'), findsNothing);
    expect(find.text('扫码签名'), findsNothing);
  });

  testWidgets('页面改名为「身份」,不再叫电子护照', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));
    expect(find.widgetWithText(AppBar, '身份'), findsOneWidget);
    expect(find.text('电子护照'), findsNothing);
  });

  testWidgets('纯访客右上是「注册」按钮,访客卡无 CID 行', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));
    expect(find.widgetWithText(TextButton, '注册'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '更换'), findsNothing);
    // 访客卡内不含 CID 行(其余卡的字段名不算)。
    expect(
      find.descendant(
        of: card(MyIdTier.visitor),
        matching: find.text('身份CID号'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: card(MyIdTier.visitor), matching: find.text('绑定账户')),
      findsNothing,
    );
  });

  testWidgets('匿名已注册:右上「更换」+ 访客卡显公民号,匿名标签仍在', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.visitor,
        votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
        cidNumber: 'CN000-CTZN1-000000001-2026',
      ),
    );
    expect(find.widgetWithText(TextButton, '更换'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '注册'), findsNothing);
    // 匿名已注册(有 CID)访客卡挂「当前身份」徽章。
    expect(find.text('当前身份'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('current-identity-visitor')),
      findsOneWidget,
    );
    final visitorCard = card(MyIdTier.visitor);
    expect(
      find.descendant(of: visitorCard, matching: find.text('身份 · 公民')),
      findsOneWidget,
    );
    expect(find.text('身份 · 访客'), findsNothing);
    expect(
      find.descendant(
        of: visitorCard,
        matching: find.text('w5BekTim......weR8vMgf7o8E'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(of: visitorCard, matching: find.text('身份CID号')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(of: visitorCard, matching: find.text('绑定账户')),
            )
            .dy,
      ),
    );
    expect(
      find.descendant(of: visitorCard, matching: find.text('身份CID号')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: visitorCard,
        matching: find.text('CN000-CTZN1-000000001'),
      ),
      findsOneWidget,
    );
    // 已注册公民显示公民标题，匿名标签与卡片颜色沿用。
    expect(
      find.byKey(const ValueKey<String>('passport-anonymous-tag')),
      findsOneWidget,
    );
  });

  testWidgets('投票公民右上是「更换」按钮', (tester) async {
    await pumpPage(tester, _votingState);
    expect(find.widgetWithText(TextButton, '更换'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '注册'), findsNothing);
  });

  testWidgets('居民CID显示居民标题，账户缺失不展示其他账户', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.visitor,
        cidNumber: 'CN000-NATP1-000000001-2026',
      ),
      surfaceSize: const Size(390, 844),
    );
    final visitorCard = card(MyIdTier.visitor);
    expect(
      find.descendant(of: visitorCard, matching: find.text('身份 · 居民')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: visitorCard, matching: find.text('绑定账户')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: visitorCard, matching: find.text('—')),
      findsOneWidget,
    );
    expect(find.text('身份 · 访客'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换CID同时更新标题及绑定地址，未知状态不冒充访客', (tester) async {
    final service = _FakeMyIdService(
      const MyIdState(
        tier: MyIdTier.visitor,
        cidNumber: 'CN000-CTZN1-000000001-2026',
        votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
      ),
    );
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    expect(find.text('身份 · 公民'), findsOneWidget);
    service.state = const MyIdState(
      tier: MyIdTier.visitor,
      cidNumber: 'CN000-NATP1-000000002-2026',
      votingAccountId: '12345678ABCDEFGHIJKLabcdefghijkl',
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('身份 · 居民'), findsOneWidget);
    expect(find.text('12345678......abcdefghijkl'), findsOneWidget);
    expect(find.text('w5BekTim......weR8vMgf7o8E'), findsNothing);
    service.state = const MyIdState(
      tier: MyIdTier.visitor,
      status: MyIdStatus.unknown,
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('身份 · 访客'), findsNothing);
    expect(find.text('身份 · 居民'), findsNothing);
  });

  testWidgets('链读失败态右上不显示注册/更换按钮', (tester) async {
    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.queryFailed,
        errorMessage: '链上身份读取失败',
      ),
    );
    expect(find.widgetWithText(TextButton, '注册'), findsNothing);
    expect(find.widgetWithText(TextButton, '更换'), findsNothing);
  });

  testWidgets('身份卡CID字段使用统一标签且值保持单行', (tester) async {
    await pumpPage(tester, _votingState);
    final votingCard = card(MyIdTier.voting);
    final label = find.descendant(
      of: votingCard,
      matching: find.text('身份CID号'),
    );
    final value = find.descendant(
      of: votingCard,
      matching: find.text('CID-2026-0715'),
    );
    expect(label, findsOneWidget);
    final valueText = tester.widget<Text>(value);
    expect(valueText.maxLines, 1);
    expect(valueText.softWrap, isFalse);
    expect(
      tester.getTopLeft(value).dy,
      closeTo(tester.getTopLeft(label).dy, 1),
    );
    expect(
      tester.getTopLeft(value).dx - tester.getTopRight(label).dx,
      lessThanOrEqualTo(8),
      reason: '公民号键值间距应保持紧凑',
    );
    expect(find.text('公民号'), findsNothing);
  });

  testWidgets('三类身份卡字段值紧随名称并保持左对齐', (tester) async {
    void expectCompactField(Finder identityCard, String label, String value) {
      final labelFinder = find.descendant(
        of: identityCard,
        matching: find.text(label),
      );
      final valueFinder = find.descendant(
        of: identityCard,
        matching: find.text(value),
      );
      expect(tester.widget<Text>(valueFinder).textAlign, TextAlign.left);
      final actualGap =
          tester.getTopLeft(valueFinder).dx -
          tester.getTopRight(labelFinder).dx;
      final expectedGap = AppLayout.scaled(tester.element(identityCard), 6);
      expect(actualGap, closeTo(expectedGap, 0.1));
    }

    await pumpPage(
      tester,
      const MyIdState(
        tier: MyIdTier.visitor,
        votingAccountId: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
        cidNumber: 'CN000-CTZN1-000000001-2026',
      ),
    );
    expectCompactField(
      card(MyIdTier.visitor),
      '身份CID号',
      'CN000-CTZN1-000000001',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpPage(tester, _votingState);
    expectCompactField(card(MyIdTier.voting), '身份CID号', 'CID-2026-0715');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpPage(tester, _candidateState);
    expectCompactField(card(MyIdTier.candidate), '公民姓名', '张三');
  });

  testWidgets('打开先读本地并同步，主动刷新失败保留已显示公民号', (tester) async {
    final service = _FakeMyIdService(_votingState);
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    expect(service.localReads, 1);
    expect(service.refreshes, 1);
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(service.refreshes, 2);
    expect(find.text('CID-2026-0715'), findsOneWidget);
    service.refreshFails = true;
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(service.refreshes, 3);
    expect(find.text('CID-2026-0715'), findsOneWidget);
    expect(find.text('身份验证失败，请重试'), findsNothing);
  });

  testWidgets('失败与缓存广播均不显示提示，后台完整同步仍交付身份', (tester) async {
    final service = _FakeMyIdService(_votingState)..refreshFails = true;
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    IdentityBadgeSnapshotStore.revision.value++;
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    service.publish(_votingState);
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    expect(service.refreshes, 1);
    expect(find.text(_votingState.cidNumber!), findsOneWidget);
  });

  testWidgets('刷新期间后台成功不被旧失败覆盖，失效结果不交付', (tester) async {
    final service = _FakeMyIdService(_votingState);
    final pending = Completer<MyIdState>();
    service.pending = pending.future;
    await tester.pumpWidget(MaterialApp(home: MyIdPage(myIdService: service)));
    await tester.pump();
    service.publish(_candidateState);
    pending.complete(
      const MyIdState(tier: MyIdTier.visitor, status: MyIdStatus.queryFailed),
    );
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    service.refreshFails = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    service.syncCurrent = false;
    service.publish(_votingState);
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
  });

  testWidgets('空闲时切账户保持静默且不触发额外链查询', (tester) async {
    final service = _FakeMyIdService(_votingState)..refreshFails = true;
    final current = _PageCurrentUser();
    await tester.pumpWidget(
      Provider<CurrentUserContext>.value(
        value: current,
        child: MaterialApp(home: MyIdPage(myIdService: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    current.selectedAccountId = '0x${'22' * 32}';
    service.state = const MyIdState(
      tier: MyIdTier.visitor,
      cidNumber: 'CID-NEW',
    );
    IdentityBadgeSnapshotStore.revision.value++;
    await tester.pumpAndSettle();
    expect(find.text('身份验证失败，请重试'), findsNothing);
    expect(find.text('CID-NEW'), findsOneWidget);
    expect(find.text(_votingState.cidNumber!), findsNothing);
    expect(service.refreshes, 1);
  });

  testWidgets('身份页支持下拉刷新', (tester) async {
    await pumpPage(tester, const MyIdState(tier: MyIdTier.visitor));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}

/// 三个余额用例的链上前置事实明确为未注册，不绕过入口的身份核实。
class _UnregisteredIdentity implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: registrationContext().accountId,
    accountAddress: 'ss58-demo',
    snapshot: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 驱动注册前余额闸三分支的假 service：可配门槛、余额与链读失败。
class _RegisterFlowService extends _FakeMyIdService {
  _RegisterFlowService({this.balanceFen = 0, this.affordabilityThrows = false})
    : super(const MyIdState(tier: MyIdTier.visitor));

  /// 门槛固定 121 分(链上最低费 10 + ED 111);本用例只驱动余额侧三分支。
  static const int requiredFen = 121;

  final int balanceFen;
  final bool affordabilityThrows;
  int registerCalls = 0;
  late Api api;

  @override
  Future<void> synchronizeIdentity(FinalizedIdentity identity) async {
    expect(identity.accountId, registrationContext().accountId);
    expect(identity.isRegistered, isFalse);
    // 同步链身份不依赖保存过的人验状态。
  }

  @override
  Future<MyIdState> getState() async => const MyIdState(tier: MyIdTier.visitor);

  @override
  Future<List<CitizenWalletStateAccount>> listBindableAccounts() async =>
      <CitizenWalletStateAccount>[
        CitizenWalletStateAccount(
          signMode: CitizenWalletSignMode.hot,
          walletIndex: 0,
          accountIndex: 0,
          accountId: registrationContext().accountId,
          ss58Address: 'ss58-demo',
          name: '账户0',
          createdAtMillis: BigInt.zero,
          isDefault: true,
        ),
      ];

  @override
  Future<({BigInt balanceFen, BigInt requiredFen})>
  fetchRegistrationAffordability(String bindAccountId) async {
    if (affordabilityThrows) throw StateError('CitizenSDK 链状态未就绪');
    return (
      requiredFen: BigInt.from(requiredFen),
      balanceFen: BigInt.from(balanceFen),
    );
  }

  @override
  Future<String> registerAnonymousCid({
    required BuildContext? context,
    required String institution,
    String? bindAccountId,
  }) async {
    registerCalls++;
    return 'CN220-CTZN2-100000001-2026';
  }

  @override
  Future<String> registrationChainScope() async =>
      registrationContext().chainScope;
  @override
  Future<Future<void> Function()> registrationGuard(String accountId) async =>
      () async {
        expect(accountId, registrationContext().accountId);
      };
  @override
  Future<FinalizedRegistration?> readRegistrationIdentity(
    String accountId,
  ) async => null;
  @override
  Future<FinalizedRegistration> registerCid({
    required BuildContext? context,
    required String institution,
    required String accountId,
    required Future<void> Function(Map<String, dynamic>) onCheckpoint,
  }) async {
    final cid = await registerAnonymousCid(
      context: context,
      institution: institution,
      bindAccountId: accountId,
    );
    return FinalizedRegistration(
      binding: IdentityBinding(
        genesisHash: registrationContext().chainScope,
        cidNumber: cid,
        bindRev: 1,
        accountId: accountId,
      ),
      blockHash: '0x${'aa' * 32}',
    );
  }

  @override
  Future<bool> canRetryRegistration(Map<String, dynamic>? checkpoint) async =>
      false;
}

class _FakeMyIdService implements MyIdService {
  _FakeMyIdService(this.state);

  @override
  final ValueNotifier<MyIdSync?> sync = ValueNotifier<MyIdSync?>(null);

  bool syncCurrent = true;
  @override
  Future<bool> isCurrentSync(MyIdSync result) async =>
      syncCurrent && identical(sync.value, result);

  void publish(MyIdState next) {
    state = next;
    sync.value = MyIdSync(
      accountId: '0x${'11' * 32}',
      walletRevision: BigInt.one,
      identityRevision: 1,
      state: next,
    );
  }

  MyIdState state;

  @override
  Future<MyIdState> getState() async {
    localReads++;
    return state;
  }

  int localReads = 0;
  int refreshes = 0;
  bool refreshFails = false;
  Future<MyIdState>? pending;

  @override
  Future<MyIdState> refreshState() async {
    refreshes++;
    if (refreshFails) throw StateError('测试断网');
    if (pending != null) return pending!;
    return state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 页面只核对本机账户，快照广播不能吞掉同账户失败，也不能触发链解析。
class _PageCurrentUser implements CurrentUserContext {
  String selectedAccountId = '0x${'11' * 32}';
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: selectedAccountId,
      ss58Address: 'synthetic',
      name: '测试账户',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    ),
    binding: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 原两次签名已由服务/SDK回归覆盖；页面只驱动同一次换绑和收尾。
class _RebindPageService extends _FakeMyIdService {
  _RebindPageService(super.state);
  final finished = Completer<void>();
  int calls = 0;
  @override
  Future<List<CitizenWalletStateAccount>> listRebindTargets() async => [
    CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.cold,
      walletIndex: 2,
      accountIndex: 0,
      accountId: '0x${'22' * 32}',
      ss58Address: 'target-ss58',
      name: '目标冷账户',
      createdAtMillis: BigInt.zero,
      isDefault: false,
    ),
  ];
  @override
  Future<void> rebindCidTo({
    required BuildContext? buildContext,
    required String cidNumber,
    required String newAccountId,
  }) async {
    calls++;
    expect(newAccountId, '0x${'22' * 32}');
    await finished.future;
  }
}
