// 验证创作者接口、链事实和档位方案。

import 'package:citizen_testing/chat/authentication.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/api.dart' show SquareSession;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_user/creator/service.dart' show BillingPeriod, CreatorApiException, CreatorApiHttp, CreatorException, CreatorOverview, CreatorPageData, CreatorPlan, CreatorService, CreatorTier, FakeCreatorApi;
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus, FinalizedIdentity, FinalizedIdentityResolver, IdentityBadgeSnapshotStore;
import 'package:citizen_chain/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_testing/database.dart';
import 'package:citizen_testing/sdk.dart';
import 'dart:async';
import 'package:citizen_testing/chain.dart' as f;
import 'package:citizen_user/creator/page.dart' show CreatorPage, CreatorTierCard;
import 'package:citizen_user/identity/badge.dart' show IdentityBadge, identityBadgeStyle;
import 'package:citizen_user/membership/page.dart' show MembershipPage;
import 'package:citizen_system/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../fixtures.dart' show CreatorTestSecurity, CreatorTestService, CreatorTestUser, creatorTestApp;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext;
import 'package:citizen_user/identity/registration.dart' show RegisterIdentitySheet;

void main() {
  group('creator_api_test', suite70);
  group('creator_light_data_test', suite71);
  group('creator_plan_test', suite73);
}

// 验证创作者关系登记最小请求、严格列表及仅改名调用。

void suite70() {
  useIsolatedIsar();
  const tier = CreatorTier(
    tierId: 't1',
    tierName: '铁杆粉丝',
    monthFen: 990,
    quarterFen: null,
    yearFen: null,
  );

  test('关系登记只发送最低最终高度，不发送交易或会员镜像', () async {
    final sent = <http.Request>[];
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test/api',
      httpClient: MockClient((r) async {
        sent.add(r);
        return http.Response(
          jsonEncode(
            r.method == 'GET'
                ? {
                    'is_ok': true,
                    'cid_numbers': [_creatorCid],
                    'next_cursor': null,
                  }
                : {'is_ok': true},
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final owner = fakeSquareSession(_accountId, cidNumber: _creatorCid);
    await api.registerSubscription(
      session: owner,
      creatorCid: 'CID2',
      finalBlock: 103,
    );
    expect(jsonDecode(sent.single.body), {'final_block': 103});
    expect(sent.single.method, 'PUT');
    expect(sent.single.url.path, '/api/membergate/creators/CID2/subscription');
    final page = await api.fetchSubscribers(owner);
    expect(page.cidNumbers, [_creatorCid]);
    expect(sent.last.url.path, '/api/membergate/creator/subscribers');
    expect(sent.last.headers['x-mls-proof'], isNotEmpty);
  });
  test('登记列表拒绝畸形数据和服务端失败', () async {
    for (final response in [
      http.Response('{"is_ok":true,"cid_numbers":[42]}', 200),
      http.Response('{"is_ok":false}', 503),
    ]) {
      final api = CreatorApiHttp(
        baseUrl: 'https://creator.test/api',
        httpClient: MockClient((_) async => response),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchSubscribers(
          fakeSquareSession(_accountId, cidNumber: _creatorCid),
        ),
        throwsA(isA<CreatorApiException>()),
      );
    }
  });
  test('仅改档位名只提交 call_index 6，不重写价格计划', () async {
    final rpc = _FakeSubscriptionChain();
    final api = FakeCreatorApi();
    final service = (() {
      final reads0 = _FakeWallet();
      return CreatorService(
        api: api,
        subscriptionChain: rpc,
        getWalletState: reads0.getWalletState,
        identityResolver: _FakeIdentityCache(),
        sessionProvider: _FakeSessionProvider(),
      );
    })();

    final plan = await service.updateTierName(
      currentTiers: const [tier],
      tierId: 't1',
      tierName: '核心支持者',
    );

    expect(plan.tiers.single.tierName, '核心支持者');
    expect(rpc.renameCount, 1);
    expect(rpc.setPlansCount, 0);
    expect(rpc.signCount, 1);
    expect(api.registered, isEmpty);
  });
}

const _signerSs58Address = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
const _accountId =
    '0x0000000000000000000000000000000000000000000000000000000000000000';
const _creatorCid = 'CN220-CTZN2-198805200-2026';

class _FakeSessionProvider implements SquareSessionProvider {
  String accountId = _accountId;

  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'creator-session',
    cidNumber: _creatorCid,
    bindRev: 1,
    accountId: accountId,
    expiresAt: 9999999999999,
  );

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    final session = await ensureSession();
    return SquareSessionResolution(SquareSessionStatus.ready, session: session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 身份账户单源 fake：身份=账户0（与钱包/会话同账户），offline、不链读。
class _FakeIdentityCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: _accountId,
    accountAddress: _signerSs58Address,
    snapshot: CitizenIdentityChainSnapshot(
      cidNumber: _creatorCid,
      accountId: Uint8List(32),
      bindRev: 1,
      votingIdentity: null,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWallet extends TestWalletReads {
  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: [
            CitizenWalletStateAccount(
              signMode: CitizenWalletSignMode.hot,
              walletIndex: 1,
              accountIndex: 0,
              name: 'creator',
              ss58Address: _signerSs58Address,
              accountId: _accountId,
              createdAtMillis: BigInt.zero,
              isDefault: true,
            ),
          ],
        ),
      );
}

class _FakeSubscriptionChain extends SubscriptionChain {
  _FakeSubscriptionChain() : super();

  int setPlansCount = 0;
  int renameCount = 0;
  int signCount = 0;
  String currentTierName = '铁杆粉丝';
  String? lastPlansBlockHash;

  @override
  Future<FinalizedSubscriptionSnapshot> fetchSubscriptionSnapshot({
    required String cidNumber,
    String? creatorCid,
    CitizenBlockRef? at,
  }) async => FinalizedSubscriptionSnapshot(
    state: ChainSubscriptionState(
      plan: const ChainSubscriptionPlan.platform('freedom'),
      startedAt: 1000,
      chargeAt: 1000,
      chargeFen: BigInt.one,
      paidUntil: 3000,
      subState: 'active',
      priceFen: BigInt.one,
      suspendReason: null,
    ),
    chainNowMs: 2000,
    block: CitizenBlockRef(
      hash: '0x${List.filled(64, '0').join()}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    ),
  );

  @override
  Future<FinalizedSubscriptionTransaction> setCreatorPlans({
    required Uint8List signerPublicKey,
    required List<CreatorTierInput> tiers,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    setPlansCount++;
    signCount++;
    return (
      txHash: '0x${List.filled(64, 'c').join()}',
      blockNumber: 103,
      usedNonce: 1,
      blockHash: '0x${List.filled(64, 'd').join()}',
    );
  }

  @override
  Future<FinalizedSubscriptionTransaction> updateCreatorTierName({
    required Uint8List signerPublicKey,
    required String tierId,
    required String tierName,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    renameCount++;
    signCount++;
    currentTierName = tierName;
    return (
      txHash: '0x${List.filled(64, 'e').join()}',
      blockNumber: 103,
      usedNonce: 2,
      blockHash: '0x${List.filled(64, 'f').join()}',
    );
  }

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlans(
    String creatorCid, {
    CitizenBlockRef? at,
  }) async => [
    ChainCreatorTier(
      tierId: 't1',
      tierName: currentTierName,
      pricesFen: {'monthly': BigInt.from(990)},
    ),
  ];

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlansAtBlock(
    String creatorCid,
    CitizenBlockRef block,
  ) {
    lastPlansBlockHash = block.hash;
    return fetchCreatorPlans(creatorCid);
  }
}

// 验证会员、档位及统计分别就绪和页面进出复用链缓存。

class _Sessions extends Fake implements SquareSessionProvider {
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async =>
      const SquareSessionResolution(SquareSessionStatus.deviceUnavailable);
}

class _Resolver extends Fake implements FinalizedIdentityResolver {}

void suite71() {
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

// 验证创作者身份门禁、档位价格及未知状态不越权。

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

void suite73() {
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
