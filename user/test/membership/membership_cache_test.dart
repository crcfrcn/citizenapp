// 验证会员页面缓存、当前身份核对及价格按需刷新。

import 'dart:async';
import 'dart:convert';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_testing/membergate_fixture.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/membership/membership_page.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import '../creator/creator_test_support.dart';

SquareSession sessionFor(CreatorTestUser user) => SquareSession(
  deviceId: testMlsDeviceId,
  sessionToken: 'membership-${user.cidNumber}',
  cidNumber: user.cidNumber,
  accountId: user.ownerAccountId,
  bindRev: user.bindRev,
  expiresAt: 9999999999999,
  authenticateRequest: fakeMlsRequestHeaders,
);

class _Sessions extends Fake implements SquareSessionProvider {
  _Sessions(this.user);
  final CreatorTestUser user;
  int calls = 0;
  Future<SquareSessionResolution> Function()? resolve;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    calls++;
    return resolve != null
        ? await resolve!()
        : SquareSessionResolution(
            SquareSessionStatus.ready,
            session: sessionFor(user),
          );
  }
}

class _Resources extends Fake implements SubscriptionService {
  int calls = 0, subscribes = 0, cancels = 0, changes = 0;
  int? price;
  IdentityBinding? expected;
  Future<SquareResourceAuthorization> Function(SquareSession)? response;
  Future<void> Function()? action;
  @override
  Future<SquareResourceAuthorization> authorizeResources(
    SquareSession session, {
    bool forceRefresh = false,
  }) async {
    calls++;
    return response == null
        ? SquareApiClient.decodeResourceAuthorization(
            resourceAuthorizationFixture(allowed: false),
          )
        : await response!(session);
  }

  @override
  Future<void> subscribe(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
    IdentityBinding? expectedBinding,
  }) async {
    subscribes++;
    price = expectedPriceFen;
    expected = expectedBinding;
    await action?.call();
  }

  @override
  Future<void> cancel({
    BuildContext? context,
    IdentityBinding? expectedBinding,
  }) async {
    cancels++;
    expected = expectedBinding;
    await action?.call();
  }

  @override
  Future<void> changePlan(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
    IdentityBinding? expectedBinding,
  }) async {
    changes++;
    price = expectedPriceFen;
    expected = expectedBinding;
    await action?.call();
  }
}

class _Identity extends Fake implements FinalizedIdentityResolver {}

class _ChangedIdentity extends Fake implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: f.account(1),
    accountAddress: citizenSs58FromAccountId(f.account(1)),
    snapshot: CitizenIdentityChainSnapshot(
      cidNumber: f.cidB,
      accountId: citizenAccountIdBytes(f.account(1)),
      bindRev: 2,
      votingIdentity: null,
    ),
  );
}

void main() {
  late f.Reader reader;
  late ChainDataService source;
  late CreatorTestUser user;
  late CreatorTestSecurity security;
  late _Sessions sessions;
  late _Resources resources;
  late CitizenBlockRef head;
  late int heads, now;
  late bool member;
  late int price;
  late int runtime;
  setUp(() {
    reader = f.Reader();
    user = CreatorTestUser();
    security = CreatorTestSecurity();
    sessions = _Sessions(user);
    resources = _Resources();
    head = f.block(103);
    heads = 0;
    now = 1000000;
    member = true;
    price = 100;
    runtime = 1;
    reader.ownBehavior = (a, b, c, d, own) async => f.snapshot(
      b,
      a,
      cidNumber: user.cidNumber,
      bindRev: user.bindRev,
      genesisHash: user.genesisHash,
      hasMembership: member,
      ownCreator: own,
      runtimeSpecVersion: runtime,
      priceValues: {'freedom': price, 'democracy': 200, 'spark': 300},
    );
    source = ChainDataService(
      reader: reader,
      now: () => DateTime.fromMillisecondsSinceEpoch(now),
      priceCacheDuration: const Duration(minutes: 5),
      getAccount: () async => user.ownerAccountId,
      getGenesisHash: () async => user.genesisHash,
      getFinalizedHead: () async {
        heads++;
        return head;
      },
    );
  });
  tearDown(() async {
    await source.close();
    security.revision.dispose();
    SubscriptionService.invalidateCitizenAccount(user.ownerAccountId);
    SubscriptionService.nowForTesting = null;
  });
  Future<void> warm() async {
    await source.start();
    await source.ensureMembership(
      genesisHash: user.genesisHash,
      accountId: user.ownerAccountId,
      cidNumber: user.cidNumber,
      bindRev: user.bindRev,
    );
  }

  Widget app({bool route = false, SubscriptionService? service}) =>
      MultiProvider(
        providers: [
          Provider<CurrentUserContext>.value(value: user),
          Provider<AccountSecurityService>.value(value: security),
        ],
        child: MaterialApp(
          home: route
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MembershipPage(
                          chainData: source,
                          sessionProvider: sessions,
                          subscriptionService: service ?? resources,
                        ),
                      ),
                    ),
                    child: const Text('打开会员'),
                  ),
                )
              : MembershipPage(
                  chainData: source,
                  sessionProvider: sessions,
                  subscriptionService: service ?? resources,
                ),
        ),
      );
  Finder frontButton() => find.descendant(
    of: find.byKey(const ValueKey('membership-front-card')),
    matching: find.byType(FilledButton),
  );
  Future<void> dispose(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  test('订阅、取消、换档都拒绝与页面不符的身份，不请求钱包签名', () async {
    final service = SubscriptionService(
      identityResolver: _ChangedIdentity(),
      getWalletState: () => throw StateError('身份不符不能读签名账户'),
    );
    final expected = (await user.resolve())!.binding!;
    for (final action in <Future<void> Function()>[
      () => service.subscribe('freedom', 100, expectedBinding: expected),
      () => service.cancel(expectedBinding: expected),
      () => service.changePlan('spark', 300, expectedBinding: expected),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<SubscriptionException>().having(
            (e) => e.message,
            'message',
            contains('身份已变化'),
          ),
        ),
      );
    }
  });

  testWidgets('有效会员和价格首帧恢复，云端挂起不阻塞显示和操作', (tester) async {
    await warm();
    final pending = Completer<SquareResourceAuthorization>();
    resources.response = (_) => pending.future;
    final before = (heads, reader.priceCalls.length);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('当前会员'), findsOneWidget);
    expect(find.text('取消订阅'), findsWidgets);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNotNull);
    expect((heads, reader.priceCalls.length), before);
    pending.complete(
      SquareApiClient.decodeResourceAuthorization(
        resourceAuthorizationFixture(),
      ),
    );
    await tester.pumpAndSettle();
    await dispose(tester);
  });

  testWidgets('会员缺失时保持套餐结构，真实无会员结果可复用', (tester) async {
    member = false;
    await warm();
    final before = (heads, reader.priceCalls.length);
    await tester.pumpWidget(app(route: true));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('打开会员'));
      await tester.pumpAndSettle();
      expect(find.text('当前会员'), findsNothing);
      expect(tester.widget<FilledButton>(frontButton()).onPressed, isNotNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect((heads, reader.priceCalls.length), before);
    await dispose(tester);
  });

  testWidgets('离开期间背景区块推进，再进入不重读价格或最终块', (tester) async {
    await warm();
    await tester.pumpWidget(app(route: true));
    await tester.tap(find.text('打开会员'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    head = f.block(104);
    await source.refresh();
    expect(source.snapshot!.pricesLoaded, isFalse);
    final before = (heads, reader.priceCalls.length);
    await tester.tap(find.text('打开会员'));
    await tester.pumpAndSettle();
    expect(find.text('当前会员'), findsOneWidget);
    expect((heads, reader.priceCalls.length), before);
    await dispose(tester);
  });

  testWidgets('无缓存时先显示禁用套餐，链读完成后才开放操作', (tester) async {
    final pending = Completer<ChainDataSnapshot>();
    reader.ownBehavior = (_, _, _, _, _) => pending.future;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('会员｜订阅'), findsOneWidget);
    expect(find.text('当前会员'), findsNothing);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNull);
    pending.complete(f.snapshot(head, user.ownerAccountId));
    await tester.pumpAndSettle();
    expect(find.text('当前会员'), findsOneWidget);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNotNull);
    await dispose(tester);
  });

  testWidgets('运行时变化只补取一次价格，普通区块不触发价格读取', (tester) async {
    await warm();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final before = reader.priceCalls.length;
    runtime = 2;
    head = f.block(104);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(reader.priceCalls.length, before + 1);
    expect(source.priceSnapshot!.runtimeSpecVersion, 2);
    head = f.block(105);
    await source.refresh();
    await tester.pumpAndSettle();
    expect(reader.priceCalls.length, before + 1);
    await dispose(tester);
  });

  testWidgets('价格到期时补取一次，失败保留显示并禁用依赖价格的动作', (tester) async {
    member = false;
    await warm();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final before = reader.priceCalls.length;
    reader.ownBehavior = (_, _, _, _, _) => Future.error(StateError('offline'));
    now += const Duration(minutes: 5).inMilliseconds;
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(reader.priceCalls.length, before + 1);
    expect(source.priceSnapshot!.prices['freedom'], 100);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNull);
    expect(find.text('轻节点会员读取失败，请刷新重试'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('切CID立即撤下旧会员，不等待旧云端请求结束', (tester) async {
    await warm();
    final old = Completer<SquareResourceAuthorization>();
    resources.response = (s) => s.cidNumber == f.cidA
        ? old.future
        : Future.value(
            SquareApiClient.decodeResourceAuthorization(
              resourceAuthorizationFixture(allowed: false),
            ),
          );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('当前会员'), findsOneWidget);
    user.cidNumber = f.cidB;
    user.bindRev = 2;
    member = false;
    head = f.block(104);
    final newChain = Completer<ChainDataSnapshot>();
    reader.ownBehavior = (_, _, _, _, _) => newChain.future;
    security.revision.value++;
    await tester.pump();
    expect(find.text('当前会员'), findsNothing);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNull);
    newChain.complete(
      f.snapshot(
        head,
        user.ownerAccountId,
        cidNumber: f.cidB,
        bindRev: 2,
        hasMembership: false,
      ),
    );
    await tester.pumpAndSettle();
    old.complete(
      SquareApiClient.decodeResourceAuthorization(
        resourceAuthorizationFixture(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前会员'), findsNothing);
    expect(tester.widget<FilledButton>(frontButton()).onPressed, isNotNull);
    expect(resources.calls, 2);
    await dispose(tester);
  });

  testWidgets('交易前强制核价，价格改变先更新页面，不提交旧价格', (tester) async {
    member = false;
    await warm();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final before = reader.priceCalls.length;
    price = 900;
    await tester.tap(frontButton());
    await tester.pumpAndSettle();
    expect(reader.priceCalls.length, before + 1);
    expect(resources.subscribes, 0);
    expect(find.text('会员价格已更新，请确认后重试'), findsOneWidget);
    await tester.tap(frontButton());
    await tester.pumpAndSettle();
    expect(resources.subscribes, 1);
    expect(resources.price, 900);
    expect(resources.expected!.cidNumber, user.cidNumber);
    await dispose(tester);
  });

  testWidgets('取消当前会员也先核对链状态，完成后主动更新会员和用量', (tester) async {
    await warm();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final before = reader.priceCalls.length;
    resources.action = () async {
      member = false;
      head = f.block(104);
    };
    await tester.tap(frontButton());
    await tester.pumpAndSettle();
    expect(resources.cancels, 1);
    expect(reader.priceCalls.length, before + 2);
    expect(find.text('当前会员'), findsNothing);
    expect(resources.calls, 2);
    await dispose(tester);
  });

  testWidgets('主动刷新重新核价，云端失败不显示提示且保留会员和价格', (tester) async {
    await warm();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    resources.response = (_) async => throw StateError('cloud offline');
    final before = reader.priceCalls.length;
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(reader.priceCalls.length, before + 1);
    expect(find.text('当前会员'), findsOneWidget);
    expect(source.pricesReady, isTrue);
    expect(find.text('1.00 元'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('membership-load-failure-banner')),
      findsNothing,
    );
    expect(find.text('重试'), findsNothing);
    await dispose(tester);
  });

  for (final failure in ['会话缺失', '会话身份不符', '会话异常', '云端请求异常']) {
    testWidgets('$failure时首次进入和重新进入均不显示提示，保留会员和价格', (tester) async {
      await warm();
      if (failure == '会话缺失') {
        sessions.resolve = () async => const SquareSessionResolution(
          SquareSessionStatus.serviceUnavailable,
        );
      } else if (failure == '会话身份不符') {
        final other = CreatorTestUser()..cidNumber = f.cidB;
        sessions.resolve = () async => SquareSessionResolution(
          SquareSessionStatus.ready,
          session: sessionFor(other),
        );
      } else if (failure == '会话异常') {
        sessions.resolve = () async => throw StateError('session offline');
      } else {
        resources.response = (_) async =>
            throw const SquareApiException('cloud offline', statusCode: 503);
      }
      await tester.pumpWidget(app(route: true));
      for (var visit = 0; visit < 2; visit++) {
        await tester.tap(find.text('打开会员'));
        await tester.pumpAndSettle();
        expect(find.text('当前会员'), findsOneWidget);
        expect(find.text('1.00 元'), findsOneWidget);
        expect(source.pricesReady, isTrue);
        expect(tester.widget<FilledButton>(frontButton()).onPressed, isNotNull);
        expect(
          find.byKey(const ValueKey('membership-load-failure-banner')),
          findsNothing,
        );
        expect(find.text('重试'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(resources.calls, failure == '云端请求异常' ? 2 : 0);
      await dispose(tester);
    });
  }

  testWidgets('命中有效规则用量缓存时重复进入不建会话、不查链、不请求云端', (tester) async {
    await warm();
    var gets = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membership.test/api',
      httpClient: MockClient((r) async {
        gets++;
        return http.Response(jsonEncode(resourceAuthorizationFixture()), 200);
      }),
    );
    final service = SubscriptionService(
      identityResolver: _Identity(),
      api: api,
      getWalletState: () => throw StateError('展示不读钱包'),
    );
    addTearDown(api.close);
    await service.authorizeResources(sessionFor(user));
    final before = (heads, gets);
    await tester.pumpWidget(app(route: true, service: service));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('打开会员'));
      await tester.pumpAndSettle();
      expect(find.text('当前会员'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect((heads, gets), before);
    expect(sessions.calls, 0);
    await dispose(tester);
  });
  testWidgets('规则用量缓存到期只更新云端，不触发链和价格重读', (tester) async {
    await warm();
    var cloudNow = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => cloudNow;
    var gets = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membership.test/api',
      httpClient: MockClient((r) async {
        gets++;
        return http.Response(jsonEncode(resourceAuthorizationFixture()), 200);
      }),
    );
    final service = SubscriptionService(
      identityResolver: _Identity(),
      api: api,
      getWalletState: () => throw StateError('展示不读钱包'),
    );
    addTearDown(api.close);
    await service.authorizeResources(sessionFor(user));
    cloudNow += 60000;
    final before = (heads, reader.priceCalls.length);
    await tester.pumpWidget(app(service: service));
    await tester.pumpAndSettle();
    expect(gets, 2);
    expect(sessions.calls, 1);
    expect((heads, reader.priceCalls.length), before);
    expect(find.text('当前会员'), findsOneWidget);
    await dispose(tester);
  });
}
