import 'package:citizen_testing/membergate_fixture.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Member;
import 'package:tatachat_sdk/tatachat_sdk.dart' as chat_sdk;

import 'package:citizen_testing/mls_authentication_fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_square/compose/square_chain_service.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/membership/membership_page.dart';
import 'package:citizen_account/membership/membership_revision.dart';
import 'package:citizen_account/membership/subscription_service.dart';
import 'package:citizen_account/identity/citizen_identity_chain_reader.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_account/identity/identity_badge.dart';

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

const String _owner = _identityAccountId;
const _identityAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
final _identityAccount = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  accountId: _identityAccountId,
  ss58Address: 'ss58-demo',
  name: '默认账户',
  createdAtMillis: BigInt.one,
  isDefault: true,
);

class _FakeSessionProvider implements SquareSessionProvider {
  late final SquareSession value = SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'tok',
    cidNumber: "CN220-CTZN2-198805200-2026",
    bindRev: 1,
    accountId: _owner,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 600000,
    authenticateRequest: fakeMlsRequestHeaders,
  );

  SquareSession _session() => value;

  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    return _session();
  }

  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async =>
      SquareSessionResolution(SquareSessionStatus.ready, session: _session());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreparingSessions extends _FakeSessionProvider {
  _PreparingSessions({this.missingCommitted = false});
  final bool missingCommitted;
  int preparations = 0;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    preparations++;
    return missingCommitted
        ? SquareSessionResolution.fromError(
            const chat_sdk.MlsNativeException(
              chat_sdk.MlsNativeErrorCode.stateMissing,
              'synthetic detail',
            ),
          )
        : super.resolveSession(refresh: refresh);
  }
}

class _CidNotBoundSessionProvider implements SquareSessionProvider {
  _CidNotBoundSessionProvider({
    this.status = SquareSessionStatus.identityUnbound,
  });

  final SquareSessionStatus status;
  int calls = 0;

  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    throw const SquareApiException(
      '该钱包账户未绑定 CID,无法登录',
      statusCode: 403,
      errorCode: 'cid_not_bound',
    );
  }

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    calls++;
    return SquareSessionResolution(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 会话建立即失败(如MLS身份不可用/网络故障):页面须给可见解释,不得留残缺骨架。
class _ThrowingSessionProvider implements SquareSessionProvider {
  @override
  Future<SquareSession?> ensureSession() async {
    throw const SquareApiException(
      'MLS设备认证校验失败',
      statusCode: 401,
      errorCode: 'invalid_signature',
    );
  }

  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async =>
      const SquareSessionResolution(SquareSessionStatus.deviceUnavailable);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingSessionProvider implements SquareSessionProvider {
  _PendingSessionProvider(this.pending);

  final Future<SquareSession?> pending;

  @override
  Future<SquareSession?> ensureSession() => pending;

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    final session = await pending;
    return session == null
        ? const SquareSessionResolution(SquareSessionStatus.noWallet)
        : SquareSessionResolution(SquareSessionStatus.ready, session: session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 平台档价格链上单源（`PlatformPrice[level]`，分）；测试直接注入 mock 价表。
class _FakeChainService extends SquareChainService {
  _FakeChainService(this._prices) : super();

  final Map<String, int> _prices;
  int fetchCount = 0;
  final List<bool> forceFreshCalls = [];

  @override
  Future<Map<String, int>> fetchAllPlatformPrices({
    bool forceFresh = false,
  }) async {
    fetchCount++;
    forceFreshCalls.add(forceFresh);
    return _prices;
  }
}

class _FailingChainService extends SquareChainService {
  _FailingChainService() : super();

  int fetchCount = 0;

  @override
  Future<Map<String, int>> fetchAllPlatformPrices({
    bool forceFresh = false,
  }) async {
    fetchCount++;
    throw StateError('chain unavailable');
  }
}

/// 记录订阅 / 取消动作的假编排：不触发真钱包与真上链。
class _RecordingSubscriptionService implements SubscriptionService {
  final List<String> subscribed = [];
  final List<String> changed = [];
  int cancelCount = 0;
  int authorizationCount = 0;
  final List<bool> forceAuthorizationCalls = <bool>[];
  int cacheReadCount = 0;
  int cacheWriteCount = 0;
  SquareMembershipState? mirror;
  MembershipDisplaySnapshot? cachedSnapshot;
  bool mirrorPending = false;
  Map<String, int> serverPrices = const {};

  @override
  bool get mirrorSyncPending => mirrorPending;

  @override
  Future<SquareMembershipState> authorizeMembership(
    SquareSession session, {
    bool forceRefresh = false,
  }) async {
    authorizationCount++;
    forceAuthorizationCalls.add(forceRefresh);
    final state = _priced(mirror!, serverPrices);
    final previous = cachedSnapshot;
    cachedSnapshot = MembershipDisplaySnapshot(
      state: state,
      prices: serverPrices.isNotEmpty
          ? serverPrices
          : previous?.prices ?? const <String, int>{},
      memberAt: DateTime.now().millisecondsSinceEpoch,
      priceAt: previous?.priceAt ?? 0,
    );
    return state;
  }

  @override
  Future<MembershipDisplaySnapshot?> readDisplaySnapshot(
    String accountId,
  ) async {
    cacheReadCount++;
    return cachedSnapshot;
  }

  @override
  Future<void> writeDisplaySnapshot(
    String accountId,
    MembershipDisplaySnapshot snapshot,
  ) async {
    cacheWriteCount++;
    cachedSnapshot = snapshot;
  }

  @override
  Future<void> subscribe(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
  }) async {
    subscribed.add('$level:$expectedPriceFen');
  }

  @override
  Future<void> cancel({BuildContext? context}) async {
    cancelCount++;
  }

  @override
  Future<void> changePlan(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
  }) async {
    changed.add('$level:$expectedPriceFen');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 会员与身份彻底解耦（ADR-037）：会员卡只描述订阅，不含任何身份字段。
/// 三档额度通过服务端合同夹具注入，不依赖产品内置套餐。
SquareMembershipState _state({
  bool active = false,
  String? memberLevel,
  String? subState,
  int chargeAt = 0,
}) {
  return SquareMembershipState(
    active: active,
    paidUntil: active ? DateTime.now().millisecondsSinceEpoch + 600000 : 0,
    memberLevel: memberLevel,
    subState: subState ?? (active ? 'active' : null),

    chargeAt: chargeAt,
    plans: membergatePlansFixture(),
  );
}

// 服务端价格夹具与静态名称分开，注册页面只能消费响应中的真实价格。
SquareMembershipState _priced(
  SquareMembershipState state,
  Map<String, int> prices,
) => SquareMembershipState(
  active: state.active,
  paidUntil: state.paidUntil,
  memberLevel: state.memberLevel,
  subState: state.subState,

  chargeAt: state.chargeAt,
  plans: SquareApiClient.decodeMembershipPlans([
    for (final plan in state.plans)
      {...plan.toJson(), 'price_fen': prices[plan.memberLevel]},
  ]),
  usageState: state.usageState,
);
// 会员合同的公开测试夹具，供既有广场测试复用；不进入产品运行代码。
SquareMembershipPlan _plan(String level, int? price) => membergatePlansFixture(
  price == null ? const {} : {level: price},
).firstWhere((p) => p.memberLevel == level);
final _membershipJson = jsonEncode({
  'is_ok': true,
  'membergate_active': true,
  'membergate': {
    'member_level': 'democracy',
    'paid_until': 9999999999999,
    'sub_state': 'active',
    'charge_at': 1000,
  },
  'plans': [for (final plan in membergatePlansFixture()) plan.toJson()],
  'usage': membergateUsageFixture(),
});

class _MemoryMembershipApi extends SquareApiClient {
  _MemoryMembershipApi(this.read);
  final Future<SquareMembershipState> Function() read;
  int calls = 0;
  @override
  Future<SquareMembershipState> fetchMembership(SquareSession session) {
    calls++;
    return read();
  }
}

SquareSession _cacheSession({
  String cid = 'CN220-CTZN2-198805200-2026',
  String account = _owner,
  int revision = 1,
  String device = testMlsDeviceId,
  String token = 'cache-session',
  int expires = 9999999999999,
}) => SquareSession(
  cidNumber: cid,
  accountId: account,
  bindRev: revision,
  deviceId: device,
  sessionToken: token,
  expiresAt: expires,
  authenticateRequest: fakeMlsRequestHeaders,
);
SquareMembershipState _cacheState(int until, {bool active = true}) =>
    SquareMembershipState(
      active: active,
      paidUntil: until,
      memberLevel: 'freedom',

      subState: 'active',
      plans: [_plan('freedom', 29900)],
    );

Future<void> _pump(
  WidgetTester tester,
  SquareMembershipState state, {
  Map<String, int> prices = const {},
  SubscriptionService? service,
  SquareSessionProvider? sessionProvider,
  SquareChainService? chainService,
  CurrentUserContext? currentUserContext,
}) async {
  final effectiveService = service ?? _RecordingSubscriptionService();
  if (effectiveService is _RecordingSubscriptionService) {
    effectiveService.mirror ??= effectiveService.cachedSnapshot?.state ?? state;
    effectiveService.serverPrices = prices;
  }
  // 页面与动作门禁从同一上下文取得同一已注册会话，避免构造器/Provider事实分离。
  final effectiveSession = sessionProvider ?? _FakeSessionProvider();
  await tester.pumpWidget(
    Provider<SquareSessionProvider>.value(
      value: effectiveSession,
      child: MaterialApp(
        home: MembershipPage(
          chainService: chainService ?? _FakeChainService(prices),
          sessionProvider: effectiveSession,
          subscriptionService: effectiveService,
          identityResolver: _RegisteredFinalizedIdentity(),
          currentUserContext: currentUserContext,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _frontCard(String text) => find.descendant(
  of: find.byKey(const ValueKey('membership-front-card')),
  matching: find.text(text),
);

Finder _frontButton(String label) => find.descendant(
  of: find.byKey(const ValueKey('membership-front-card')),
  matching: find.widgetWithText(FilledButton, label),
);

class _CachedCurrentUser implements CurrentUserContext {
  _CachedCurrentUser({this.unregistered = false});
  final bool unregistered;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: _identityAccount,
    verifiedUnregistered: unregistered,
    binding: unregistered
        ? null
        : const IdentityBinding(
            genesisHash:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            cidNumber: 'CN220-CTZN2-198805200-2026',
            accountId: _identityAccountId,
            bindRev: 1,
          ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableCurrentUser implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => throw StateError('测试当前账户不可用');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RegisteredFinalizedIdentity implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: _identityAccountId,
    accountAddress: 'ss58-demo',
    snapshot: CitizenIdentityChainSnapshot(
      // 与_FakeSessionProvider、_CachedCurrentUser使用相同CID/账户/版本。
      cidNumber: 'CN220-CTZN2-198805200-2026',
      accountId: Uint8List.fromList(List<int>.filled(32, 0x11)),
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
          accounts: [_identityAccount],
        ),
      );
}

SubscriptionService _subscriptionService({
  SquareApiClient? api,
  SquareSessionProvider? sessionProvider,
  bool resumePendingTransactions = true,
}) => (() {
  final reads0 = _FakeWallet();
  return SubscriptionService(
    getWalletState: reads0.getWalletState,
    identityResolver: _RegisteredFinalizedIdentity(),
    sessionProvider: sessionProvider ?? _FakeSessionProvider(),
    api: api,
    resumePendingTransactions: resumePendingTransactions,
  );
})();

void main() {
  _resourcePreflightTests();
  TestCitizenSdkHarness();
  useIsolatedIsar();

  setUp(() {
    SubscriptionService.invalidateCitizenAccount(_owner);
    // 清理本文件三种会话夹具的内存展示，避免相同事实抑制下一例的变化广播。
    for (final cid in [
      testMlsCidNumber,
      'CN220-CTZN2-198805200-2026',
      'CN220-CTZN2-198805299-2026',
    ]) {
      SubscriptionService.setChatAuthorizationForTesting(cid, null);
    }
    SubscriptionService.nowForTesting = null;
  });
  tearDown(() {
    SubscriptionService.invalidateCitizenAccount(_owner);
    SubscriptionService.nowForTesting = null;
  });

  test('交易证明单份保存，待同步种类和CID隔离，确认不清除历史', () async {
    const cid = testMlsCidNumber;
    final member = {'tx_hash': 'member', 'block_hash': 'member-block'};
    final creator = {'tx_hash': 'creator', 'block_hash': 'creator-block'};
    await wallet_store.Member.storeProof(cid, member, pendingKind: 'member');
    await wallet_store.Member.storeProof(cid, creator, pendingKind: 'creator');
    await wallet_store.Member.storeProof(
      'other',
      member,
      pendingKind: 'member',
    );
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'member'), [
      member,
    ]);
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'creator'), [
      creator,
    ]);
    await wallet_store.Member.finishProof(cid, 'member', 'creator');
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'member'), [
      member,
    ]);
    await wallet_store.Member.finishProof(cid, 'member', 'member');
    expect(
      await wallet_store.Member.readProofs(cid, pendingKind: 'member'),
      isEmpty,
    );
    expect(await wallet_store.Member.readProofs(cid), [member, creator]);
    expect(
      await wallet_store.Member.readProofs('other', pendingKind: 'member'),
      [member],
    );
    final row = await UserIsar.instance.read(
      (db) => db.collection<wallet_store.Member>().getByCidNumberStateKind(
        cid,
        'proof',
      ),
    );
    expect((jsonDecode(row!.bodyData) as List), hasLength(2));
  });

  test('历史限50仍保留所有待同步证明，替换计划不清除其它种类', () async {
    const cid = testMlsCidNumber;
    await wallet_store.Member.storeProof(cid, {
      'tx_hash': 'pending',
    }, pendingKind: 'member');
    await wallet_store.Member.storeProof(
      cid,
      {'tx_hash': 'old-plan'},
      pendingKind: 'plan',
      replacePending: true,
    );
    await wallet_store.Member.storeProof(
      cid,
      {'tx_hash': 'new-plan'},
      pendingKind: 'plan',
      replacePending: true,
    );
    for (var i = 0; i < 51; i++) {
      await wallet_store.Member.storeProof(cid, {'tx_hash': 'complete-$i'});
    }
    expect(await wallet_store.Member.readProofs(cid), hasLength(50));
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'member'), [
      {'tx_hash': 'pending'},
    ]);
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'plan'), [
      {'tx_hash': 'new-plan'},
    ]);
    await wallet_store.Member.finishProof(cid, 'old-plan', 'plan');
    expect(await wallet_store.Member.readProofs(cid, pendingKind: 'plan'), [
      {'tx_hash': 'new-plan'},
    ]);
    await wallet_store.Member.finishProof(cid, 'pending', 'member');
    expect(
      await wallet_store.Member.readProofs(cid, pendingKind: 'member'),
      isEmpty,
    );
    await expectLater(
      wallet_store.Member.storeProof(cid, {'block_hash': 'missing'}),
      throwsFormatException,
    );
    expect(await wallet_store.Member.readProofs(cid), hasLength(50));
  });

  test('强刷合并在途请求；广播前安装唯一缓存，附件重复准备不再GET', () async {
    final pending = Completer<SquareMembershipState>();
    final api = _MemoryMembershipApi(() => pending.future),
        session = _cacheSession();
    addTearDown(api.close);
    final service = _subscriptionService(api: api);
    Future<SquareMembershipState>? listenerResult;
    void changed() {
      listenerResult = service.authorizeMembership(session);
    }

    MembershipRevision.instance.listenable.addListener(changed);
    addTearDown(
      () => MembershipRevision.instance.listenable.removeListener(changed),
    );
    final first = service.authorizeMembership(session),
        second = service.authorizeMembership(session, forceRefresh: true);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 1);
    expect(SubscriptionService.chatFileMaxBytesFor(session.cidNumber), 0);
    pending.complete(
      _cacheState(DateTime.now().millisecondsSinceEpoch + 120000),
    );
    expect(identical(await first, await second), isTrue);
    if (listenerResult != null) await listenerResult;
    await SubscriptionService.prepareAttachment(session, service: service);
    await SubscriptionService.prepareAttachment(session, service: service);
    expect(api.calls, 1);
    expect(
      SubscriptionService.chatFileMaxBytesFor(session.cidNumber),
      10 * 1024 * 1024,
    );
  });
  test('60秒正向缓存与paidUntil边界，30秒无权益缓存到点失效', () async {
    var now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    var result = _cacheState(now + 180000);
    final api = _MemoryMembershipApi(() async => result),
        session = _cacheSession();
    addTearDown(api.close);
    final service = _subscriptionService(api: api);
    await service.authorizeMembership(session);
    now += 59999;
    await service.authorizeMembership(session);
    expect(api.calls, 1);
    now++;
    await service.authorizeMembership(session);
    expect(api.calls, 2);
    result = _cacheState(now + 1000);
    await service.authorizeMembership(session, forceRefresh: true);
    now += 1000;
    expect(SubscriptionService.chatFileMaxBytesFor(session.cidNumber), 0);
    result = _cacheState(0, active: false);
    await service.authorizeMembership(session);
    expect(api.calls, 4);
    now += 29999;
    await service.authorizeMembership(session);
    expect(api.calls, 4);
    now++;
    await service.authorizeMembership(session);
    expect(api.calls, 5);
    await expectLater(
      SubscriptionService.prepareAttachment(session, service: service),
      throwsA(isA<SquareApiException>()),
    );
    expect(api.calls, 5);
  });
  for (final error in [
    for (final status in [429, 500, 501, 502, 503, 504, 599])
      SquareApiException('unavailable', statusCode: status),
    StateError('network'),
  ]) {
    test('失败退避5秒，强刷不能绕过且失败不授予权限：$error', () async {
      var now = DateTime.now().millisecondsSinceEpoch;
      SubscriptionService.nowForTesting = () => now;
      var fail = true;
      final api = _MemoryMembershipApi(() async {
            if (fail) throw error;
            return _cacheState(now + 60000);
          }),
          session = _cacheSession();
      addTearDown(api.close);
      final service = _subscriptionService(api: api);
      await expectLater(
        service.authorizeMembership(session),
        throwsA(same(error)),
      );
      now += 4999;
      await expectLater(
        service.authorizeMembership(session, forceRefresh: true),
        throwsA(same(error)),
      );
      expect(api.calls, 1);
      expect(SubscriptionService.chatFileMaxBytesFor(session.cidNumber), 0);
      now++;
      fail = false;
      await service.authorizeMembership(session);
      expect(api.calls, 2);
    });
  }
  for (final field in [
    'cid',
    'account',
    'revision',
    'device',
    'token',
    'expiry',
    'invalidate',
  ]) {
    test('会话$field变化后旧Future不能写权限或展示', () async {
      final old = _cacheSession();
      final next = _cacheSession(
        cid: field == 'cid' ? 'CN220-CTZN2-198805299-2026' : old.cidNumber,
        account: field == 'account' ? 'different-account' : old.accountId,
        revision: field == 'revision' ? 2 : 1,
        device: field == 'device' ? 'other-device' : old.deviceId,
        token: field == 'token' ? 'new-token' : old.sessionToken,
        expires: field == 'expiry' ? old.expiresAt - 1 : old.expiresAt,
      );
      final pending = Completer<SquareMembershipState>();
      var reads = 0;
      final api = _MemoryMembershipApi(
        () => ++reads == 1
            ? pending.future
            : Future.value(_cacheState(0, active: false)),
      );
      addTearDown(api.close);
      final service = _subscriptionService(api: api);
      final stale = expectLater(
        service.authorizeMembership(old),
        throwsA(isA<SubscriptionException>()),
      );
      await Future<void>.delayed(Duration.zero);
      if (field == 'invalidate') {
        SubscriptionService.invalidateBusinessMembership(old.cidNumber);
      }
      await service.authorizeMembership(next);
      pending.complete(
        _cacheState(DateTime.now().millisecondsSinceEpoch + 120000),
      );
      await stale;
      expect(api.calls, 2);
      expect(SubscriptionService.chatFileMaxBytesFor(next.cidNumber), 0);
      expect(
        (await service.readDisplaySnapshot(next.cidNumber))!.state.active,
        isFalse,
      );
    });
  }
  test('会话期限先于60秒时立即裁剪，普通业务只验证会话并保持零GET', () async {
    var now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    final session = _cacheSession(expires: now + 1000),
        api = _MemoryMembershipApi(() async => _cacheState(now + 60000));
    addTearDown(api.close);
    final service = _subscriptionService(api: api);
    await service.requireSquareAccess(session);
    await service.requireProfileAccess(session, 'other');
    expect(api.calls, 0);
    await service.authorizeMembership(session);
    now += 1000;
    expect(SubscriptionService.chatFileMaxBytesFor(session.cidNumber), 0);
    await expectLater(
      service.authorizeMembership(session),
      throwsA(isA<SquareApiException>()),
    );
    expect(api.calls, 1);
  });

  test('自动附件仅派生当前唯一缓存，缺失/过期/设备不符均零新增GET', () async {
    var now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    final session = _cacheSession(),
        api = _MemoryMembershipApi(() async => _cacheState(now + 120000));
    addTearDown(api.close);
    Future<bool> cached({String? device, int? revision}) =>
        SubscriptionService.cachedAttachmentAuthorized(
          cidNumber: session.cidNumber,
          accountId: session.accountId,
          bindRev: revision ?? session.bindRev,
          expectedDeviceId: device ?? session.deviceId,
        );
    expect(await cached(), isFalse);
    expect(api.calls, 0);
    await _subscriptionService(api: api).authorizeMembership(session);
    expect(await cached(), isTrue);
    expect(api.calls, 1);
    expect(await cached(device: 'changed-device'), isFalse);
    expect(await cached(revision: 2), isFalse);
    expect(api.calls, 1);
    now += 60000;
    expect(await cached(), isFalse);
    expect(api.calls, 1);
  });
  test('缓存派生异步校验期间失效，迟到true不能授权附件', () async {
    Completer<void>? validation;
    final base = _cacheSession();
    final session = SquareSession(
      cidNumber: base.cidNumber,
      accountId: base.accountId,
      bindRev: base.bindRev,
      deviceId: base.deviceId,
      sessionToken: base.sessionToken,
      expiresAt: base.expiresAt,
      requireCurrent: () async {
        await validation?.future;
      },
    );
    final api = _MemoryMembershipApi(
      () async => _cacheState(DateTime.now().millisecondsSinceEpoch + 120000),
    );
    addTearDown(api.close);
    await _subscriptionService(api: api).authorizeMembership(session);
    validation = Completer<void>();
    final pending = SubscriptionService.cachedAttachmentAuthorized(
      cidNumber: session.cidNumber,
      accountId: session.accountId,
      bindRev: 1,
      expectedDeviceId: session.deviceId,
    );
    await Future<void>.delayed(Duration.zero);
    SubscriptionService.invalidateBusinessMembership(session.cidNumber);
    validation.complete();
    expect(await pending, isFalse);
    expect(api.calls, 1);
  });

  // 正例只用现行结构，旧结构保留为明确拒绝负例；两条读取入口共用校验。
  final malformedSnapshots = <String, Map<String, dynamic>>{
    '旧字段': {
      'is_ok': true,
      'membership_active': true,
      'membership': {'membership_level': 'democracy'},
      'plans': [],
      'usage': {},
    },
    for (final field in [
      'is_ok',
      'membergate_active',
      'membergate',
      'plans',
      'usage',
    ])
      '缺$field': (jsonDecode(_membershipJson) as Map<String, dynamic>)
        ..remove(field),
    for (final field in [
      'is_ok',
      'membergate_active',
      'membergate',
      'plans',
      'usage',
    ])
      '错类型$field': (jsonDecode(_membershipJson) as Map<String, dynamic>)
        ..[field] = 'invalid',
    '活跃但无会员': (jsonDecode(_membershipJson) as Map<String, dynamic>)
      ..['membergate'] = null,
    for (final field in [
      'member_level',
      'paid_until',
      'sub_state',
      'charge_at',
    ])
      '会员缺$field': (jsonDecode(_membershipJson) as Map<String, dynamic>)
        ..['membergate'].remove(field),
    for (final field in [
      'used_bytes',
      'reserved_bytes',
      'day_start',
      'published_count',
      'observed_at',
    ])
      '用量缺$field': (jsonDecode(_membershipJson) as Map<String, dynamic>)
        ..['usage'].remove(field),
    '用量错类型': (jsonDecode(_membershipJson) as Map<String, dynamic>)
      ..['usage']['used_bytes'] = '0',
    '用量负数': (jsonDecode(_membershipJson) as Map<String, dynamic>)
      ..['usage']['used_bytes'] = -1,
    '用量越界': (jsonDecode(_membershipJson) as Map<String, dynamic>)
      ..['usage']['used_bytes'] = 9007199254740992,
    '会员日期错类型': (jsonDecode(_membershipJson) as Map<String, dynamic>)
      ..['membergate']['paid_until'] = '9999999999999',
  };
  for (final entry in malformedSnapshots.entries) {
    test('GET和确认均拒绝损坏快照：${entry.key}', () async {
      var calls = 0;
      final tx = '0x${'a' * 64}', block = '0x${'b' * 64}';
      final api = SquareApiClient(
        baseUrl: 'https://membergate.test/api',
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? entry.value
                  : {
                      'is_ok': true,
                      'tx_hash': tx,
                      'block_hash': block,
                      'membergate_state': entry.value,
                    },
            ),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchMembership(_cacheSession()),
        throwsA(isA<SquareApiException>()),
      );
      await expectLater(
        api.confirmPlatformSubscription(
          session: _cacheSession(),
          txHash: tx,
          blockHash: block,
        ),
        throwsA(isA<SquareApiException>()),
      );
      expect(calls, 2, reason: '失败不能补GET或自动重复确认');
    });
  }

  test('明确未订阅可读取，原用量不得被置零', () async {
    final snapshot = jsonDecode(_membershipJson) as Map<String, dynamic>;
    snapshot['membergate_active'] = false;
    snapshot['membergate'] = null;
    snapshot['usage']['used_images'] = 7;
    snapshot['usage']['reserved_images'] = 2;
    snapshot['usage']['used_video_seconds'] = 31;
    snapshot['usage']['reserved_video_seconds'] = 4;
    snapshot['usage']['active_uploads'] = 3;
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient(
        (_) async => http.Response(jsonEncode(snapshot), 200),
      ),
    );
    addTearDown(api.close);
    final state = await api.fetchMembership(_cacheSession());
    expect(state.active, isFalse);
    expect(state.usageState!.toJson().containsKey('used_images'), isFalse);
    expect(
      state.usageState!.toJson().containsKey('used_video_seconds'),
      isFalse,
    );
    expect(state.usageState!.toJson().containsKey('active_uploads'), isFalse);
  });

  test('GET损坏只报读取失败，不覆盖已确认会员展示事实', () async {
    var damaged = false, calls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          damaged ? '{"is_ok":true,"plans":[],"usage":{}}' : _membershipJson,
          200,
        );
      }),
    );
    addTearDown(api.close);
    final session = _cacheSession();
    final service = _subscriptionService(
      api: api,
      resumePendingTransactions: false,
    );
    final original = await service.authorizeMembership(session);
    damaged = true;
    await expectLater(
      service.authorizeMembership(session, forceRefresh: true),
      throwsA(isA<SquareApiException>()),
    );
    final kept = (await service.readDisplaySnapshot(session.cidNumber))!.state;
    expect(kept.active, original.active);
    expect(kept.memberLevel, original.memberLevel);
    expect(kept.paidUntil, original.paidUntil);
    expect(kept.chargeAt, original.chargeAt);
    expect(calls, 2);
  });

  test('确认损坏保留原finalized证明，零成功广播及额外GET', () async {
    final provider = _FakeSessionProvider();
    final session = provider.value;
    final cidNumber = session.cidNumber;
    final tx = '0x${'a' * 64}', block = '0x${'b' * 64}';
    final proof = jsonEncode([
      {'tx_hash': tx, 'block_hash': block},
    ]);
    await wallet_store.Member.storeProof(
      cidNumber,
      (jsonDecode(proof) as List).single as Map<String, dynamic>,
      pendingKind: 'member',
    );
    var calls = 0, broadcasts = 0;
    void changed() => broadcasts++;
    MembershipRevision.instance.listenable.addListener(changed);
    addTearDown(
      () => MembershipRevision.instance.listenable.removeListener(changed),
    );
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'tx_hash': tx,
          'block_hash': block,
          'include_state': true,
        });
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'tx_hash': tx,
            'block_hash': block,
            'membergate_state': malformedSnapshots['旧字段'],
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final service = _subscriptionService(api: api, sessionProvider: provider);
    for (var i = 0; i < 100 && !service.mirrorSyncPending; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(service.mirrorSyncPending, isTrue);
    expect(
      jsonEncode(
        await wallet_store.Member.readProofs(cidNumber, pendingKind: 'member'),
      ),
      proof,
    );
    expect(calls, 1);
    expect(broadcasts, 0);
  });

  test('平台finalized确认使用MLS证明，核对回执后读取真实会员快照', () async {
    var deviceSignCount = 0;
    final sent = <http.Request>[];
    final txHash = '0x${'a' * 64}';
    final blockHash = '0x${'b' * 64}';
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((request) async {
        sent.add(request);
        expect(request.headers['authorization'], 'Bearer tok');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        if (request.method == 'POST') {
          expect(request.url.path, '/api/membergate/confirm');
          expect(jsonDecode(request.body), {
            'tx_hash': txHash,
            'block_hash': blockHash,
            'include_state': true,
          });
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'tx_hash': txHash,
              'block_hash': blockHash,
              'membergate_state': jsonDecode(_membershipJson),
            }),
            200,
          );
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/membergate');
        return http.Response(_membershipJson, 200);
      }),
    );
    addTearDown(api.close);
    final session = SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'tok',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId: _identityAccountId,
      expiresAt: 9999999999999,
      authenticateRequest:
          ({
            required method,
            required uri,
            required body,
            required sessionToken,
          }) async {
            deviceSignCount++;
            return fakeMlsRequestHeaders(
              method: method,
              uri: uri,
              body: body,
              sessionToken: sessionToken,
            );
          },
    );
    final confirmed = await api.confirmPlatformSubscription(
      session: session,
      txHash: txHash,
      blockHash: blockHash,
    );
    expect(sent.map((request) => request.method), ['POST']);
    expect(deviceSignCount, 1);
    expect(confirmed.active, isTrue);
    expect(confirmed.active, isTrue);
    expect(confirmed.memberLevel, 'democracy');
  });

  for (final damagedField in [
    'is_ok',
    'tx_hash',
    'block_hash',
    'extra',
    'membergate_state',
  ]) {
    test('会员确认拒绝损坏回执字段$damagedField，不能读取快照或冒认确认成功', () async {
      var calls = 0;
      final txHash = '0x${'a' * 64}', blockHash = '0x${'b' * 64}';
      final receipt = <String, Object>{
        'is_ok': true,
        'tx_hash': txHash,
        'block_hash': blockHash,
        'membergate_state': jsonDecode(_membershipJson),
      };
      receipt[damagedField] = damagedField == 'is_ok' ? false : '0x${'c' * 64}';
      final api = SquareApiClient(
        baseUrl: 'https://membergate.test/api',
        httpClient: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          return http.Response(jsonEncode(receipt), 200);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.confirmPlatformSubscription(
          session: _FakeSessionProvider()._session(),
          txHash: txHash,
          blockHash: blockHash,
        ),
        throwsA(isA<SquareApiException>()),
      );
      expect(calls, 1);
    });
  }

  test('确认快照暂不可用传播503并且不补GET，不将回执转成未激活会员', () async {
    var confirmations = 0, reads = 0;
    final txHash = '0x${'a' * 64}', blockHash = '0x${'b' * 64}';
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          confirmations++;
          return http.Response('{"error_code":"membership_unavailable"}', 503);
        }
        reads++;
        return http.Response('{"error_code":"membership_unavailable"}', 503);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.confirmPlatformSubscription(
        session: _FakeSessionProvider()._session(),
        txHash: txHash,
        blockHash: blockHash,
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(confirmations, 1);
    expect(reads, 0);
  });

  for (final broken in [
    {},
    {'is_ok': true},
    {
      'is_ok': true,
      'membergate_active': true,
      'membergate': null,
      'plans': [],
      'usage': {},
    },
  ]) {
    test('确认快照字段缺失不能被解释成明确无权益 $broken', () async {
      final tx = '0x${'a' * 64}', block = '0x${'b' * 64}';
      final api = SquareApiClient(
        baseUrl: 'https://membergate.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'is_ok': true,
              'tx_hash': tx,
              'block_hash': block,
              'membergate_state': broken,
            }),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.confirmPlatformSubscription(
          session: _cacheSession(),
          txHash: tx,
          blockHash: block,
        ),
        throwsA(isA<SquareApiException>()),
      );
    });
  }

  test('会员确认拒绝非规范交易和块，失败前不发请求', () async {
    var calls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);
    for (final value in ['', '0x1234', '0x${'A' * 64}']) {
      await expectLater(
        api.confirmPlatformSubscription(
          session: _FakeSessionProvider()._session(),
          txHash: value,
          blockHash: '0x${'b' * 64}',
        ),
        throwsA(isA<SquareApiException>()),
      );
      await expectLater(
        api.confirmPlatformSubscription(
          session: _FakeSessionProvider()._session(),
          txHash: '0x${'a' * 64}',
          blockHash: value,
        ),
        throwsA(isA<SquareApiException>()),
      );
    }
    expect(calls, 0);
  });

  test('聊天关闭构造期恢复时有真实待同步证明也零会话/确认/GET且保留证明', () async {
    final provider = _FakeSessionProvider(), session = _cacheSession();
    final cidNumber = provider.value.cidNumber;
    final proof = jsonEncode([
      {'tx_hash': '0x${'a' * 64}', 'block_hash': '0x${'b' * 64}'},
    ]);
    await wallet_store.Member.storeProof(
      cidNumber,
      (jsonDecode(proof) as List).single as Map<String, dynamic>,
      pendingKind: 'member',
    );
    var calls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((_) async {
        calls++;
        throw StateError('聊天构造期不得发请求');
      }),
    );
    addTearDown(api.close);
    final service = _subscriptionService(
      api: api,
      sessionProvider: provider,
      resumePendingTransactions: false,
    );
    await Future<void>.delayed(Duration.zero);
    // 只读展示、检查后台缓存均不能启动交易恢复。
    await service.readDisplaySnapshot(session.cidNumber);
    expect(provider.calls, 0);
    expect(calls, 0);
    expect(
      jsonEncode(
        await wallet_store.Member.readProofs(cidNumber, pendingKind: 'member'),
      ),
      proof,
    );
  });

  test('待同步证明确认先装唯一缓存再广播，后续消费者零GET且只清待同步状态', () async {
    final provider = _FakeSessionProvider(),
        session = await _FakeSessionProvider().ensureSession();
    final tx = '0x${'a' * 64}', block = '0x${'b' * 64}';
    final cidNumber = session!.cidNumber;
    await wallet_store.Member.storeProof(cidNumber, {
      'tx_hash': tx,
      'block_hash': block,
    }, pendingKind: 'member');
    final sent = <String>[], changed = Completer<void>();
    void listener() {
      if (!changed.isCompleted) changed.complete();
    }

    MembershipRevision.instance.listenable.addListener(listener);
    addTearDown(
      () => MembershipRevision.instance.listenable.removeListener(listener),
    );
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((request) async {
        sent.add(request.method);
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'tx_hash': tx,
            'block_hash': block,
            'membergate_state': jsonDecode(_membershipJson),
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final service = _subscriptionService(api: api, sessionProvider: provider);
    await changed.future.timeout(const Duration(seconds: 5));
    expect(
      (await service.authorizeMembership(
        (await provider.ensureSession())!,
      )).active,
      isTrue,
    );
    expect(sent, ['POST']);
    // 广播早于待同步状态清除，排空同一数据库队列后核对证明仍保留且恢复已完成。
    for (var i = 0; i < 10; i++) {
      final pending = await wallet_store.Member.readProofs(
        cidNumber,
        pendingKind: 'member',
      );
      if (pending.isEmpty) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      await wallet_store.Member.readProofs(cidNumber, pendingKind: 'member'),
      isEmpty,
    );
    expect(await wallet_store.Member.readProofs(cidNumber), [
      {'tx_hash': tx, 'block_hash': block},
    ]);
  });

  test('同一 CitizenServe 身份会话跨页面服务实例只读取一次会员', () async {
    var membershipCalls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://membergate.test/api',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/membergate');
        membershipCalls += 1;
        return http.Response(
          _membershipJson.replaceFirst('democracy', 'freedom'),
          200,
        );
      }),
    );
    final session = const SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'membership-session-once',
      cidNumber: 'CN220-CTZN2-198805299-2026',
      bindRev: 9,
      accountId:
          '0x9999999999999999999999999999999999999999999999999999999999999999',
      expiresAt: 9999999999999,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final first = _subscriptionService(api: api);
    final second = _subscriptionService(api: api);

    final states = await Future.wait([
      first.authorizeMembership(session),
      second.authorizeMembership(session),
    ]);

    expect(membershipCalls, 1);
    expect(states.every((state) => state.active), isTrue);
    expect(
      SubscriptionService.chatAuthorizationResolvedFor(session.cidNumber),
      isTrue,
    );
    expect(
      SubscriptionService.membershipResolvedFor(session.cidNumber),
      isTrue,
    );
  });

  testWidgets('已核实未注册直接显示引导，不建立普通会话', (tester) async {
    await _pump(
      tester,
      const SquareMembershipState(active: false, paidUntil: 0),
      currentUserContext: _CachedCurrentUser(unregistered: true),
    );
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.byKey(const ValueKey('membership-front-card')), findsOneWidget);
    expect(find.textContaining('恢复服务'), findsNothing);
  });

  testWidgets('会员普通进入自动准备，没有初始化弹窗或新增按钮', (tester) async {
    final sessions = _PreparingSessions();
    await _pump(
      tester,
      _state(active: false),
      sessionProvider: sessions,
      currentUserContext: _CachedCurrentUser(),
    );
    expect(sessions.preparations, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('初始化本机聊天设备'), findsNothing);
    expect(find.text('自由会员'), findsOneWidget);
  });
  testWidgets('会员已使用MLS状态缺失不得通过重试换钥', (tester) async {
    final sessions = _PreparingSessions(missingCommitted: true);
    await _pump(
      tester,
      _state(active: false),
      sessionProvider: sessions,
      currentUserContext: _CachedCurrentUser(),
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(sessions.preparations, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('本机聊天身份文件缺失，聊天暂时无法使用'), findsOneWidget);
  });

  testWidgets('renders the three subscription tier cards', (tester) async {
    await _pump(tester, _state());

    expect(find.text('自由会员'), findsOneWidget);
    expect(find.text('民主会员'), findsOneWidget);
    expect(find.text('薪火会员'), findsOneWidget);
    const mottos = <String, String>{
      'freedom': '生命诚可贵.爱情价更高.若为自由故.两者皆可抛',
      'democracy': '民主不是万能的.没有民主是万万不能的',
      'spark': '自由民主.薪火相传',
    };
    for (final entry in mottos.entries) {
      final level = entry.key;
      final expectedBadgeColor = switch (level) {
        'freedom' => AppTheme.identityVisitor,
        'democracy' => AppTheme.identityVoting,
        _ => AppTheme.identityCandidate,
      };
      final displayName = switch (level) {
        'freedom' => '自由会员',
        'democracy' => '民主会员',
        _ => '薪火会员',
      };
      final titleFinder = find.text(displayName);
      final badgeFinder = find.byKey(ValueKey('membership-tier-badge-$level'));
      final badge = tester.widget<IdentityBadge>(badgeFinder);
      final title = tester.widget<Text>(titleFinder);
      expect(badge.size, title.style?.fontSize);
      expect(badge.style.color, expectedBadgeColor);
      expect(badge.style.checked, isTrue);
      expect(
        tester.getCenter(badgeFinder).dx,
        lessThan(tester.getCenter(titleFinder).dx),
      );
      final motto = find.byKey(ValueKey('membership-motto-$level'));
      final content = find.byKey(ValueKey('membership-motto-content-$level'));
      expect(motto, findsOneWidget);
      expect(content, findsOneWidget);
      expect(
        tester.getCenter(content).dx,
        closeTo(tester.getCenter(motto).dx, 0.01),
      );

      final dotCount = '.'.allMatches(entry.value).length;
      for (var index = 0; index < dotCount; index++) {
        final slot = find.byKey(ValueKey('membership-motto-dot-$level-$index'));
        final dot = find.byKey(
          ValueKey('membership-motto-dot-shape-$level-$index'),
        );
        expect(slot, findsOneWidget);
        expect(dot, findsOneWidget);
        // 点在自己的固定盒中上下、左右精确居中；最长宣传语缩放后仍至少 4px，
        // 明显大于原字体基线句点。
        expect(
          tester.getCenter(dot).dx,
          closeTo(tester.getCenter(slot).dx, 0.01),
        );
        expect(
          tester.getCenter(dot).dy,
          closeTo(tester.getCenter(slot).dy, 0.01),
        );
        expect(tester.getSize(dot).width, greaterThanOrEqualTo(4));
        expect(tester.getSize(dot).height, greaterThanOrEqualTo(4));
      }

      final coloredHeader = tester.widget<Container>(
        find.byKey(ValueKey('membership-colored-header-$level')),
      );
      expect(coloredHeader.padding, const EdgeInsets.fromLTRB(16, 16, 16, 8));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽视口下三档徽章、名称和价格不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      _state(),
      prices: const {'freedom': 29900, 'democracy': 99900, 'spark': 199900},
    );

    for (final level in const ['freedom', 'democracy', 'spark']) {
      expect(
        find.byKey(ValueKey('membership-tier-badge-$level')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    SquareSessionStatus.networkUnavailable,
    SquareSessionStatus.serviceUnavailable,
    SquareSessionStatus.noWallet,
  ]) {
    testWidgets('无缓存$status三卡常显且未知权益详情不允许订阅', (tester) async {
      final actions = _RecordingSubscriptionService();
      await _pump(
        tester,
        const SquareMembershipState(active: false, paidUntil: 0),
        service: actions,
        sessionProvider: _CidNotBoundSessionProvider(status: status),
      );
      for (final level in ['freedom', 'democracy', 'spark']) {
        expect(
          find.byKey(ValueKey('membership-tier-card-$level')),
          findsOneWidget,
        );
      }
      expect(find.text('权益待获取'), findsWidgets);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('membership-front-card')),
          matching: find.text('查看详细权益'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('会员详情'), findsOneWidget);
      expect(find.text('权益待获取'), findsOneWidget);
      expect(actions.subscribed, isEmpty);
      expect(actions.authorizationCount, 0);
    });
  }

  testWidgets('部分展示快照保留三卡，缺档不复制已知额度', (tester) async {
    final partial = SquareMembershipState(
      active: false,
      paidUntil: 0,
      plans: membergatePlansFixture().take(1).toList(),
    );
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: partial,
        prices: const {},
        memberAt: 0,
        priceAt: 0,
      );
    // 模拟展示快照不完整；真正服务解码仍拒绝缺档，不能生成授权。
    await _pump(tester, partial, service: service);
    for (final level in ['freedom', 'democracy', 'spark']) {
      expect(
        find.byKey(ValueKey('membership-tier-card-$level')),
        findsOneWidget,
      );
    }
    expect(find.text('权益待获取'), findsNWidgets(2));
    expect(find.textContaining('聊天附件 每个'), findsOneWidget);
  });

  testWidgets('没有缓存且会话未完成时三卡常显，不制造会员额度', (tester) async {
    final pendingSession = Completer<SquareSession?>();
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPage(
          chainService: _FakeChainService(const {}),
          sessionProvider: _PendingSessionProvider(pendingSession.future),
          subscriptionService: _RecordingSubscriptionService(),
          identityResolver: _RegisteredFinalizedIdentity(),
        ),
      ),
    );
    await tester.pump();

    for (final level in ['freedom', 'democracy', 'spark']) {
      expect(
        find.byKey(ValueKey('membership-tier-card-$level')),
        findsOneWidget,
      );
    }
    expect(find.text('权益待获取'), findsWidgets);
    pendingSession.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('membership-load-failure-banner')),
        matching: find.text('请先添加钱包账户'),
      ),
      findsOneWidget,
    );
    expect(find.text('权益待获取'), findsWidgets);
  });

  testWidgets('已有本地会员时会话未绑定仍显示会员和同步说明，不授权订阅', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(active: true, memberLevel: 'democracy'),
        prices: const {'democracy': 99900},
        memberAt: now,
        priceAt: now,
      );
    await _pump(
      tester,
      _state(),
      service: service,
      sessionProvider: _CidNotBoundSessionProvider(),
      currentUserContext: _CachedCurrentUser(),
    );
    expect(find.text('当前会员'), findsOneWidget);
    expect(find.text('身份同步中，请稍后重试'), findsOneWidget);
    expect(service.authorizationCount, 0);
    expect(find.text('注册用户'), findsNothing);
  });

  testWidgets('当前账户无法读取时不把旧会员缓存当作当前账户展示', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(active: true, memberLevel: 'democracy'),
        prices: const {'democracy': 99900},
        memberAt: now,
        priceAt: now,
      );
    await _pump(
      tester,
      _state(),
      service: service,
      currentUserContext: _UnavailableCurrentUser(),
    );
    expect(find.text('当前会员'), findsNothing);
    expect(find.text('会员数据加载失败，请点右上刷新重试'), findsOneWidget);
    expect(service.authorizationCount, 0);
  });

  testWidgets('有效缓存直接展示且身份会话只鉴权一次并且不重复读取价格', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(active: true, memberLevel: 'democracy'),
        prices: const {'freedom': 29900, 'democracy': 99900, 'spark': 199900},
        memberAt: now,
        priceAt: now,
      );
    final chain = _FakeChainService(const {
      'freedom': 1,
      'democracy': 2,
      'spark': 3,
    });

    await _pump(tester, _state(), service: service, chainService: chain);

    expect(find.text('999.00 元'), findsOneWidget);
    expect(find.text('当前会员'), findsOneWidget);
    expect(service.authorizationCount, 1);
    expect(service.forceAuthorizationCalls, [isFalse]);
    expect(chain.fetchCount, 0);
  });

  testWidgets('手动刷新统一服务端快照，注册页面不再查链价格', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(),
        prices: const {'freedom': 29900},
        memberAt: now,
        priceAt: now,
      );
    final chain = _FakeChainService(const {'freedom': 39900});

    await _pump(tester, _state(), service: service, chainService: chain);
    service.serverPrices = const {'freedom': 39900};
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();

    expect(service.authorizationCount, 2);
    expect(service.forceAuthorizationCalls, [isFalse, isTrue]);
    expect(chain.fetchCount, 0);
    expect(chain.forceFreshCalls, isEmpty);
    expect(find.text('399.00 元'), findsOneWidget);
  });

  testWidgets('服务端未给新价格时保留上一次展示价格，不补查链', (tester) async {
    final stale = DateTime.now()
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(),
        prices: const {'freedom': 29900},
        memberAt: stale,
        priceAt: stale,
      );
    final chain = _FailingChainService();

    await _pump(tester, _state(), service: service, chainService: chain);

    expect(chain.fetchCount, 0);
    expect(find.text('自由会员'), findsOneWidget);
    expect(find.text('民主会员'), findsOneWidget);
    expect(find.text('薪火会员'), findsOneWidget);
    expect(find.text('299.00 元'), findsOneWidget);
  });

  testWidgets('会员页展示服务端套餐及真实价格', (tester) async {
    await _pump(tester, _state(), prices: const {'freedom': 29900});

    expect(find.text('自由会员'), findsOneWidget);
    expect(find.text('299.00 元'), findsOneWidget);
    expect(find.text('会员状态加载失败'), findsNothing);
  });

  testWidgets('defaults to the freedom card for a fresh account', (
    tester,
  ) async {
    await _pump(tester, _state());
    expect(_frontCard('自由会员'), findsOneWidget);
  });

  testWidgets('fronts the current membership tier card + 当前会员 marker', (
    tester,
  ) async {
    await _pump(tester, _state(active: true, memberLevel: 'spark'));

    expect(_frontCard('薪火会员'), findsOneWidget);
    expect(find.text('当前会员'), findsOneWidget);
    final currentCard = tester.widget<Container>(
      find.byKey(const ValueKey('membership-tier-card-spark')),
    );
    final border = (currentCard.decoration as BoxDecoration).border! as Border;
    expect(border.top.color, AppTheme.identityCandidate);
    expect(border.top.width, 2);
  });

  testWidgets('any identity can subscribe any tier — all cards show 订阅', (
    tester,
  ) async {
    await _pump(
      tester,
      _state(),
      prices: const {'freedom': 1, 'democracy': 2, 'spark': 3},
    );
    // 三档解耦、无身份门槛：三张卡都可订阅。
    expect(find.text('订阅'), findsNWidgets(3));
    expect(find.text('当前会员'), findsNothing);
  });

  testWidgets('shows 取消订阅 on the active tier + 更换为此档 on the others', (
    tester,
  ) async {
    await _pump(
      tester,
      _state(active: true, memberLevel: 'freedom'),
      prices: const {'freedom': 1, 'democracy': 2, 'spark': 3},
    );

    expect(find.text('取消订阅'), findsOneWidget);
    expect(find.text('更换为此档'), findsNWidgets(2));
  });

  testWidgets('公民币月价来自链读，逐档展示', (tester) async {
    await _pump(
      tester,
      _state(),
      prices: const {'freedom': 29900, 'democracy': 99900, 'spark': 199900},
    );

    expect(find.text('299.00 元'), findsOneWidget);
    expect(find.text('999.00 元'), findsOneWidget);
    expect(find.text('1,999.00 元'), findsOneWidget);
    for (final level in const ['freedom', 'democracy', 'spark']) {
      final image = tester.widget<Image>(
        find.byKey(ValueKey('membership-price-gmb-mark-$level')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'packages/citizen_assets/logo/mark256.png',
      );
      expect(image.width, 18);
      expect(image.height, 18);
      expect(image.colorBlendMode, BlendMode.srcIn);
    }
  });

  testWidgets('会员详情价格左侧显示公民币标志', (tester) async {
    await _pump(tester, _state(), prices: const {'freedom': 199900});

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('membership-front-card')),
        matching: find.text('查看详细权益'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会员详情'), findsOneWidget);
    expect(find.text('1,999.00 元'), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('membership-detail-price-gmb-mark-freedom')),
    );
    expect(
      (image.image as AssetImage).assetName,
      'packages/citizen_assets/logo/mark256.png',
    );
    expect(image.width, 18);
    expect(image.height, 18);
    expect(image.color, AppTheme.textPrimary);
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('会员卡片和详情展示最新自由会员用量标准', (tester) async {
    await _pump(tester, _state());

    expect(find.text('聊天 文字/表情/贴纸/图片'), findsNWidgets(3));
    expect(find.text('语音/视频消息 3 分钟 · 语音/视频通话'), findsNWidgets(3));
    expect(find.text('聊天附件 每个 10 MiB'), findsOneWidget);
    expect(find.text('视频 3 分钟 · 480p · 12 MiB'), findsOneWidget);
    expect(find.text('文章 3 万字 · 20 图 · 1 视频'), findsOneWidget);
    expect(find.textContaining('本周期 图'), findsNothing);
    expect(find.text('广场存储 256 GiB'), findsOneWidget);
    expect(find.text('视频 30 分钟 · 720p · 200 MiB'), findsOneWidget);
    expect(find.text('文章 3 万字 · 50 图 · 3 视频'), findsOneWidget);
    expect(find.textContaining('并发上传'), findsNothing);
    expect(find.text('广场存储 1 TiB'), findsOneWidget);
    expect(find.text('视频 3 小时 · 1080p · 1800 MiB'), findsOneWidget);
    expect(find.text('文章 3 万字 · 100 图 · 10 视频'), findsOneWidget);
    expect(find.textContaining('周期视频'), findsNothing);
    expect(find.text('广场存储 10 TiB'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('membership-front-card')),
        matching: find.text('查看详细权益'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('文字、表情、贴纸、图片'), findsOneWidget);
    expect(find.text('最长 3 分钟'), findsNWidgets(2));
    expect(find.text('支持'), findsNWidgets(2));
    expect(find.text('最大 10 MiB'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('最多 1 个'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('最多 1 个'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('用量额度'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('本周期图片'), findsNothing);
    expect(find.text('256 GiB'), findsOneWidget);
  });

  testWidgets('链上未设价 → 显示占位且禁止发起订阅', (tester) async {
    await _pump(tester, _state());
    expect(find.text('—'), findsNWidgets(3));
    final button = tester.widget<FilledButton>(_frontButton('链上价格未就绪'));
    expect(button.onPressed, isNull);
  });

  testWidgets('点击订阅按钮走 App 内订阅并传对应档', (tester) async {
    final service = _RecordingSubscriptionService();
    await _pump(
      tester,
      _state(),
      prices: const {'freedom': 29900},
      service: service,
    );

    final button = _frontButton('订阅');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    // 默认前置档=自由 → 订阅传 'freedom'。
    expect(service.subscribed, ['freedom:29900']);
    expect(service.cancelCount, 0);
    expect(service.changed, isEmpty);
  });

  testWidgets('finalized 后镜像未确认时明确提示权益仍在同步', (tester) async {
    final service = _RecordingSubscriptionService()..mirrorPending = true;
    await _pump(
      tester,
      _state(),
      prices: const {'freedom': 29900},
      service: service,
    );

    await tester.tap(_frontButton('订阅'));
    await tester.pumpAndSettle();

    expect(find.text('链上订阅已生效，会员权益正在同步'), findsOneWidget);
  });

  test('会员修订只为非空公民号发出失效通知', () {
    final events = <MembershipRevisionEvent>[];
    void listener() {
      final event = MembershipRevision.instance.listenable.value;
      if (event != null) events.add(event);
    }

    MembershipRevision.instance.listenable.addListener(listener);
    addTearDown(
      () => MembershipRevision.instance.listenable.removeListener(listener),
    );

    MembershipRevision.instance.notifyChanged('   ');
    MembershipRevision.instance.notifyChanged('CID-1');

    expect(events, hasLength(1));
    expect(events.single.cidNumber, 'CID-1');
    expect(events.single.revision, greaterThan(0));
  });

  testWidgets('点击另一档按钮走一次链上换档', (tester) async {
    final service = _RecordingSubscriptionService();
    await _pump(
      tester,
      _state(active: true, memberLevel: 'freedom', subState: 'active'),
      prices: const {'freedom': 1, 'democracy': 2, 'spark': 3},
      service: service,
    );

    // 在会员卡层叠手势区左滑，把民主档移到前层，再执行换档。
    await tester.drag(
      find.byKey(const ValueKey('membership-tier-stack-gesture')),
      const Offset(-360, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(_frontButton('更换为此档'));
    await tester.pumpAndSettle();

    expect(service.changed, ['democracy:2']);
    expect(service.subscribed, isEmpty);
  });

  testWidgets('点击取消订阅按钮走 App 内取消', (tester) async {
    final service = _RecordingSubscriptionService();
    await _pump(
      tester,
      _state(active: true, memberLevel: 'freedom'),
      service: service,
    );

    final button = _frontButton('取消订阅');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.cancelCount, 1);
    expect(service.subscribed, isEmpty);
    expect(service.changed, isEmpty);
  });

  testWidgets('订阅生效横幅显示订阅起止 + 链上自动续费口径', (tester) async {
    await _pump(
      tester,
      _state(
        active: true,
        memberLevel: 'freedom',
        subState: 'active',
        chargeAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    expect(find.textContaining('链上到期自动续费'), findsOneWidget);
    expect(find.textContaining('订阅 '), findsOneWidget);
  });

  testWidgets('会话建立失败且无快照时保留错误与重试，不显示假套餐', (tester) async {
    await _pump(
      tester,
      _state(active: false),
      sessionProvider: _ThrowingSessionProvider(),
    );

    // 没有真实套餐仍展示三档，但不生成额度。
    expect(
      find.byKey(const ValueKey('membership-load-failure-banner')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('membership-load-failure-banner')),
        matching: find.text('MLS设备认证暂时不可用，请稍后重试'),
      ),
      findsOneWidget,
    );
    expect(find.text('请先添加钱包账户'), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('membership-front-card')), findsOneWidget);
  });

  testWidgets('已取消订阅 → 横幅标签「到期终止」且不再续费', (tester) async {
    await _pump(
      tester,
      _state(
        active: true,
        memberLevel: 'freedom',
        subState: 'cancelled',
        chargeAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    expect(find.textContaining('已取消 · 到期终止'), findsOneWidget);
    expect(find.textContaining('链上到期自动续费'), findsNothing);
  });

  test('SquareMembershipState 订阅窗口 getter', () {
    const withWindow = SquareMembershipState(
      active: true,
      paidUntil: 2000,

      chargeAt: 1000,
    );
    expect(withWindow.hasSubscriptionWindow, isTrue);

    const noWindow = SquareMembershipState(active: true, paidUntil: 2000);
    // 缺 charge_at（=0）→ 无可展示窗口。
    expect(noWindow.hasSubscriptionWindow, isFalse);
  });

  test('真实套餐、媒体规格和用量按CID持久化；重启不补默认额度', () async {
    final service = _subscriptionService();
    const cidNumber = 'CN220-CTZN2-100000001-2026';
    final raw = jsonDecode(_membershipJson) as Map<String, dynamic>;
    raw['plans'][0]['limits']['storage_bytes'] = 777 * 1024 * 1024 * 1024;
    raw['plans'][0]['limits']['image_quality'] = 61;
    raw['plans'][0]['daily_limits']['media_requests'] = 4321;
    raw['usage']['used_bytes'] = 9000;
    raw['usage']['reserved_bytes'] = 700;
    raw['usage']['daily']['media_requests'] = 123;
    raw['usage']['published_count'] = 4;
    final snapshot = MembershipDisplaySnapshot(
      state: SquareApiClient.decodeMembership(raw),
      prices: const {'freedom': 29900, 'democracy': 99900, 'spark': 199900},
      memberAt: 3000,
      priceAt: 4000,
    );
    await service.writeDisplaySnapshot(cidNumber, snapshot);
    SubscriptionService.setChatAuthorizationForTesting(cidNumber, null);
    final restored = (await service.readDisplaySnapshot(cidNumber))!;
    expect(
      restored.state.planForLevel('freedom')!.usage.storageBytes,
      777 * 1024 * 1024 * 1024,
    );
    expect(restored.state.planForLevel('freedom')!.media['image_quality'], 61);
    expect(
      restored.state.planForLevel('freedom')!.dailyLimits['media_requests'],
      4321,
    );
    expect(restored.state.planForLevel('freedom')!.imageBytesLabel, '400 KiB');
    expect(restored.state.usageState!.usedBytes, 9000);
    expect(restored.state.usageState!.reservedBytes, 700);
    expect(restored.state.usageState!.daily['media_requests'], 123);
    expect(restored.state.usageState!.publishedCount, 4);
    expect(restored.prices['spark'], 199900);
    expect(restored.memberAt, 3000);
    expect(restored.priceAt, 4000);
  });

  testWidgets('同一档位服务端额度变化直接展示，不被本地定义覆盖', (tester) async {
    final raw = jsonDecode(_membershipJson) as Map<String, dynamic>;
    raw['plans'][0]['limits']['storage_bytes'] = 777 * 1024 * 1024 * 1024;
    raw['plans'][0]['plan']['video_max_bytes'] = 9 * 1024 * 1024;
    await _pump(tester, SquareApiClient.decodeMembership(raw));
    expect(find.text('广场存储 777 GiB'), findsOneWidget);
    expect(find.text('视频 3 分钟 · 480p · 9 MiB'), findsOneWidget);
    expect(find.text('本周期 图 300 · 视频 300 分钟'), findsNothing);
  });

  // 中文注释：同一状态在会员卡和详情页都必须保真，且按钮不得再与价格拼接。
  testWidgets('本机已有绑定但 Worker 未投影 → 显示身份同步故障而不是无钱包', (tester) async {
    final sessionProvider = _CidNotBoundSessionProvider(
      status: SquareSessionStatus.identityUnavailable,
    );
    final service = _RecordingSubscriptionService()
      ..cachedSnapshot = MembershipDisplaySnapshot(
        state: _state(),
        prices: const {'freedom': 299, 'democracy': 999, 'spark': 9999},
        memberAt: 1000,
        priceAt: 1000,
      );
    await _pump(
      tester,
      _state(active: false),
      service: service,
      currentUserContext: _CachedCurrentUser(),
      prices: const {'freedom': 299, 'democracy': 999, 'spark': 9999},
      sessionProvider: sessionProvider,
    );

    expect(find.text('身份同步中，请稍后重试'), findsWidgets);
    expect(find.text('请先添加钱包账户'), findsNothing);
    expect(find.text('注册用户'), findsNothing);
    expect(sessionProvider.calls, 1);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('membership-front-card')),
        matching: find.text('查看详细权益'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('会员详情'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('身份同步中，请稍后重试'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('身份同步中，请稍后重试'), findsWidgets);
    expect(find.text('请先添加钱包账户'), findsNothing);
  });

  testWidgets('本机无绑定 → Worker 判未注册后显示注册引导', (tester) async {
    final sessionProvider = _CidNotBoundSessionProvider();
    await _pump(
      tester,
      _state(active: false),
      prices: const {'freedom': 299, 'democracy': 999, 'spark': 9999},
      sessionProvider: sessionProvider,
    );

    // 没注册不是加载失败,重试也不会变——横幅必须完全消失。
    expect(
      find.byKey(const ValueKey('membership-load-failure-banner')),
      findsNothing,
    );
    expect(find.textContaining('会员数据加载失败'), findsNothing);
    expect(find.text('重试'), findsNothing);
    // 未注册引导与三档共存，动作仍不可订阅。
    expect(find.byKey(const ValueKey('membership-front-card')), findsOneWidget);
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('会员状态同步中'), findsNothing);
    expect(sessionProvider.calls, 1);
  });

  testWidgets('未注册 → 统一注册页面不展示会员卡价格', (tester) async {
    await _pump(
      tester,
      _state(active: false),
      prices: const {'freedom': 299, 'democracy': 999, 'spark': 9999},
      sessionProvider: _CidNotBoundSessionProvider(),
    );

    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.textContaining('2.99'), findsNothing);
  });
}

void _resourcePreflightTests() {
  group('本地资源预检', () {
    const origin = 'https://preflight.test';
    tearDown(
      () => SubscriptionService.invalidateCitizenAccount('test-account'),
    );
    SquareSession session() => SquareSession(
      sessionToken: 'synthetic',
      cidNumber: '1001',
      bindRev: 1,
      accountId: 'test-account',
      deviceId: 'test-device',
      expiresAt: DateTime.now().millisecondsSinceEpoch + 120000,
    );
    Future<SquareResourceLease> reserve(
      MembershipResourceGate gate,
      SquareSession s,
    ) => gate.reserve(
      origin: origin,
      session: s,
      operation: 'chat',
      actions: {'media_request': {}},
    );
    test('连接不再消费会员每日额度', () async {
      final gate = MembershipResourceGate(),
          s = session(),
          rules = preflightGateFixture(session(), limit: 0);
      (rules['resource_actions'] as Map)['chat_connect'] =
          <Map<String, String>>[];
      gate.observe(origin, s, {'gate': rules});
      (await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        actions: {'chat_connect': {}},
      )).cancel();
    });
    Map<String, dynamic> stockSnapshot(SquareSession s, {int period = 1000}) {
      final data = jsonDecode(_membershipJson) as Map<String, dynamic>;
      data['gate'] = preflightGateFixture(s, limit: 1);
      data['membergate']['charge_at'] = period;
      data['plans'][1]['limits']['storage_bytes'] = 1;
      data['plans'][1]['daily_limits']['media_requests'] = 1;
      data['usage']['attachment'] = {
        'status': 'available',
        'observed_at': 1000,
        'bytes': 0,
      };
      return data;
    }

    test('跨订阅周期的上传仍占同一真实空间，迟到完成不会释放占用', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, stockSnapshot(s));
      final old = await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 1},
      );
      old.sent();
      gate.observe(origin, s, stockSnapshot(s, period: 2000));
      await expectLater(
        gate.reserve(
          origin: origin,
          session: s,
          operation: 'chat',
          costs: {'storage_bytes': 1},
        ),
        throwsA(isA<SquarePreflightException>()),
      );
      old.finish();
      // 已结束的变更使存量失效，下一次由新采样或服务端裁定，不盲加旧快照。
      final next = stockSnapshot(s);
      next['usage']['used_bytes'] = 1;
      gate.observe(origin, s, next);
      await expectLater(
        gate.reserve(
          origin: origin,
          session: s,
          operation: 'chat',
          costs: {'storage_bytes': 1},
        ),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('无响应使存量变未知，不能永久卡住写入；已发送日扣量仍保留', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, stockSnapshot(s));
      final old = await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 1},
        actions: {'media_request': {}},
      );
      old
        ..sent()
        ..cancel();
      (await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 1},
      )).cancel();
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('旧快照不能替换较新会话，清除账户也清除图片可读的会话引用', () async {
      final gate = MembershipResourceGate(),
          s = session(),
          now = DateTime.now().millisecondsSinceEpoch;
      final next = SquareSession(
        sessionToken: 'new-synthetic',
        cidNumber: s.cidNumber,
        bindRev: s.bindRev,
        accountId: s.accountId,
        deviceId: s.deviceId,
        expiresAt: s.expiresAt,
      );
      gate.observe(origin, next, {
        'gate': preflightGateFixture(next, now: now + 1),
      });
      gate.observe(origin, s, {'gate': preflightGateFixture(s, now: now)});
      expect(SubscriptionService.currentSession, same(next));
      gate.invalidate(s.accountId);
      expect(SubscriptionService.currentSession, isNull);
    });
    test('并发预留消费服务端下发上限，未发送取消后准确释放', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, {'gate': preflightGateFixture(s, limit: 1)});
      final first = await reserve(gate, s);
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
      first.cancel();
      (await reserve(gate, s)).cancel();
    });
    test('发送后无回执保留不确定消耗，不能靠重试退款', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, {'gate': preflightGateFixture(s, limit: 1)});
      (await reserve(gate, s))
        ..sent()
        ..cancel();
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('回执使用真实used；跨设备伪造与损坏回执均不能释放预留', () async {
      final gate = MembershipResourceGate(),
          s = session(),
          now = DateTime.now().millisecondsSinceEpoch;
      gate.observe(origin, s, {
        'gate': preflightGateFixture(s, now: now, limit: 1),
      });
      final lease = (await reserve(gate, s))..sent();
      chat_sdk.ResourceUsage receipt(String device) =>
          chat_sdk.ResourceUsage()..mergeFromProto3Json({
            'user_id': s.cidNumber,
            'account_id': s.accountId,
            'binding_revision': s.bindRev,
            'device_id': device,
            'server_time_millis': now,
            'counters': [
              {
                'metric': 'media_requests',
                'window_start_millis': now ~/ 86400000 * 86400000,
                'charged': 1,
                'used': 1,
                'limit': 1,
              },
            ],
          });
      lease.finish(receipt: receipt('other-device'));
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
      lease.finish(receipt: receipt(s.deviceId));
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
      gate.observe(origin, s, {
        'gate': preflightGateFixture(s, now: now + 86400000, limit: 1),
      });
      (await reserve(gate, s)).cancel();
    });
    test('存量在途快照不能重复相加，完成后迟到旧采样失效', () async {
      final gate = MembershipResourceGate(), s = session();
      final before = stockSnapshot(s);
      before['plans'][1]['limits']['storage_bytes'] = 3;
      gate.observe(origin, s, before);
      final sample = gate.sample(origin, s);
      final first = await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 1},
      );
      first.sent();
      final during = stockSnapshot(s);
      during['plans'][1]['limits']['storage_bytes'] = 3;
      during['usage']['reserved_bytes'] = 1;
      gate.observe(origin, s, during);
      (await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 2},
      )).cancel();
      first.finish();
      gate.observe(origin, s, before, sample: sample);
      (await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'storage_bytes': 3},
      )).cancel();
    });
    test('缺回执未知失败保留日消耗；明确拒绝及幂等零扣量释放', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, {'gate': preflightGateFixture(s, limit: 1)});
      final denied = (await reserve(gate, s))..sent();
      denied.finish(headers: {}, accepted: false);
      final unchanged = (await reserve(gate, s))..sent();
      unchanged.finish(headers: {}, accepted: true);
      final unknown = (await reserve(gate, s))..sent();
      unknown.finish(headers: {}, accepted: false, uncertain: true);
      await expectLater(
        reserve(gate, s),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('同一附件未知许可重试复用预留，真实回执只结算一次', () async {
      final gate = MembershipResourceGate(), s = session();
      final rules = preflightGateFixture(s, limit: 1);
      rules['daily_limits'] = {'attachment_begins': 1};
      rules['resource_actions'] = {
        'chat_command': [
          {
            'metric': 'attachment_begins',
            'amount': 'one',
            'when': 'begin_attachment',
          },
        ],
      };
      gate.observe(origin, s, {'gate': rules});
      Future<SquareResourceLease> begin(String id) => gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        operationId: id,
        actions: {
          'chat_command': {'begin_attachment': 1},
        },
      );
      final first = (await begin('same'))..sent();
      first.cancel();
      await expectLater(
        begin('different'),
        throwsA(isA<SquarePreflightException>()),
      );
      final retry = (await begin('same'))..sent();
      final now = DateTime.now().millisecondsSinceEpoch;
      retry.finish(
        receipt: (chat_sdk.ResourceUsage()
          ..mergeFromProto3Json({
            'user_id': s.cidNumber,
            'device_id': s.deviceId,
            'account_id': s.accountId,
            'binding_revision': s.bindRev,
            'server_time_millis': now,
            'counters': [
              {
                'metric': 'attachment_begins',
                'window_start_millis': now ~/ 86400000 * 86400000,
                'charged': 0,
                'used': 1,
              },
            ],
          })),
      );
      (await begin('same')).cancel();
      await expectLater(
        begin('different'),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('同身份换会话后重试可以结算旧令牌的未知许可', () async {
      final gate = MembershipResourceGate(), old = session();
      final now = DateTime.now().millisecondsSinceEpoch;
      Map<String, dynamic> rules(SquareSession s, int time) {
        final r = preflightGateFixture(s, now: time, limit: 1);
        r['daily_limits'] = {'attachment_begins': 2};
        r['resource_actions'] = {
          'chat_command': [
            {
              'metric': 'attachment_begins',
              'amount': 'one',
              'when': 'begin_attachment',
            },
          ],
        };
        return r;
      }

      Future<SquareResourceLease> begin(SquareSession s, String id) =>
          gate.reserve(
            origin: origin,
            session: s,
            operation: 'chat',
            operationId: id,
            actions: {
              'chat_command': {'begin_attachment': 1},
            },
          );
      gate.observe(origin, old, {'gate': rules(old, now)});
      (await begin(old, 'same'))
        ..sent()
        ..cancel();
      final next = SquareSession(
        sessionToken: 'renewed',
        cidNumber: old.cidNumber,
        bindRev: old.bindRev,
        accountId: old.accountId,
        deviceId: old.deviceId,
        expiresAt: old.expiresAt,
      );
      gate.observe(origin, next, {'gate': rules(next, now + 1)});
      final retry = (await begin(next, 'same'))..sent();
      retry.finish(
        receipt: (chat_sdk.ResourceUsage()
          ..mergeFromProto3Json({
            'user_id': next.cidNumber,
            'device_id': next.deviceId,
            'account_id': next.accountId,
            'binding_revision': next.bindRev,
            'server_time_millis': now + 1,
            'counters': [
              {
                'metric': 'attachment_begins',
                'window_start_millis': now ~/ 86400000 * 86400000,
                'charged': 0,
                'used': 1,
              },
            ],
          })),
      );
      (await begin(next, 'new')).cancel();
    });
    test('未知失败的部分回执仅保留没有确认的成本', () async {
      final gate = MembershipResourceGate(), s = session();
      final now = DateTime.now().millisecondsSinceEpoch;
      final rules = preflightGateFixture(s, now: now, limit: 2);
      rules['daily_limits'] = {'media_requests': 2, 'delivery_bytes': 2};
      gate.observe(origin, s, {'gate': rules});
      final first = (await gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        costs: {'media_requests': 1, 'delivery_bytes': 1},
      ))..sent();
      first.finish(
        accepted: false,
        uncertain: true,
        receipt: (chat_sdk.ResourceUsage()
          ..mergeFromProto3Json({
            'user_id': s.cidNumber,
            'device_id': s.deviceId,
            'account_id': s.accountId,
            'binding_revision': s.bindRev,
            'server_time_millis': now,
            'counters': [
              {
                'metric': 'media_requests',
                'window_start_millis': now ~/ 86400000 * 86400000,
                'charged': 1,
                'used': 1,
              },
            ],
          })),
      );
      (await reserve(gate, s)).cancel();
      await expectLater(
        gate.reserve(
          origin: origin,
          session: s,
          operation: 'chat',
          costs: {'delivery_bytes': 2},
        ),
        throwsA(isA<SquarePreflightException>()),
      );
    });
    test('未发送许可取消后不能留下免费幂等入口', () async {
      final gate = MembershipResourceGate(), s = session();
      final rules = preflightGateFixture(s, limit: 1);
      rules['daily_limits'] = {'attachment_begins': 1};
      rules['resource_actions'] = {
        'chat_command': [
          {
            'metric': 'attachment_begins',
            'amount': 'one',
            'when': 'begin_attachment',
          },
        ],
      };
      gate.observe(origin, s, {'gate': rules});
      Future<SquareResourceLease> begin(String id) => gate.reserve(
        origin: origin,
        session: s,
        operation: 'chat',
        operationId: id,
        actions: {
          'chat_command': {'begin_attachment': 1},
        },
      );
      (await begin('same')).cancel();
      final first = await begin('other');
      await expectLater(
        begin('same'),
        throwsA(isA<SquarePreflightException>()),
      );
      first.cancel();
    });
    test('旧账户预留不能在失效后发送；未知规则不伪造HTTP拒绝', () async {
      final gate = MembershipResourceGate(), s = session();
      gate.observe(origin, s, {'gate': preflightGateFixture(s)});
      final lease = await reserve(gate, s);
      gate.invalidate(s.accountId);
      expect(lease.sent, throwsA(isA<SquarePreflightException>()));
      (await reserve(gate, s)).cancel();
    });
    test('实际网络请求本地拒绝发生在MLS证明和HTTP之前', () async {
      final gate = MembershipResourceGate(), s = session();
      final rules = preflightGateFixture(s);
      (rules['daily_limits'] as Map)['media_requests'] = 0;
      gate.observe(origin, s, {'gate': rules});
      SquareApiClient.resourceGate = gate;
      addTearDown(() => SquareApiClient.resourceGate = null);
      var network = 0;
      final api = SquareApiClient(
        baseUrl: '$origin/api',
        httpClient: MockClient((_) async {
          network++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.openCardMedia('$origin/api/user/cards/1002/avatar', session: s),
        throwsA(isA<SquarePreflightException>()),
      );
      expect(network, 0);
    });
  });
}
