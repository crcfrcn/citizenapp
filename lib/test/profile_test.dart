// 验证资料惰性读取和CID关注归属。

import 'package:citizen_citizen/public/store.dart' show IsarPublicInstitutionStore;
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_testing/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/profile/data.dart' show CitizenProfileApi;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:async';
import 'package:citizen_testing/membership.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:citizen_user/identity/state.dart' show FinalizedIdentity, FinalizedIdentityResolver;
import 'package:citizen_user/membership/page.dart' show MembershipPage;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:citizen_testing/sdk.dart';
import 'dart:io';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext;
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus;
import 'package:citizen_chain/service.dart';
import 'package:citizen_testing/chain.dart' as light;
import 'package:citizen_user/creator/page.dart' show CreatorPage;
import 'package:citizen_user/creator/service.dart' show CreatorPageData, CreatorService;
import 'package:citizen_user/creator/service.dart' show CreatorOverview;
import 'package:citizen_user/identity/state.dart' show IdentityBadgeSnapshot, IdentityBadgeSnapshotStore;
import 'package:citizen_user/membership/service.dart' show MembershipRevision;
import 'package:citizen_user/membership/service.dart' show SubscriptionService;
import 'package:citizenapp/user.dart';
import 'package:citizen_user/profile/page.dart' show UserQrPage;
import 'package:citizen_user/profile/page.dart' show UserProfilePage;
import 'package:citizen_user/identity/session.dart' show SquareSessionResolution;
import 'package:citizen_user/profile/data.dart' show CitizenProfile;
import 'package:citizen_user/profile/data.dart' show CitizenProfileMediaCache, CitizenProfileMediaSnapshot;
import 'package:citizen_user/profile/page.dart' show ProfileAvatar;
import 'package:citizen_user/api.dart' show SquareApiClient, SquareResourceAuthorization, SquareSession;
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_system/theme.dart';
import 'package:citizen_user/identity/badge.dart' show IdentityBadge;
import 'package:citizen_user/identity/state.dart' show MyIdService;
import 'package:citizen_user/identity/registration.dart' show RegisterIdentitySheet;
import 'package:flutter/material.dart';
import 'package:citizen_testing/profile.dart' hide sampleProfile;
import 'package:citizen_testing/profile.dart' as fixtures;

void main() {
  group('institution_follow_storage_test', _registerFollow);
  group('profile_page_lazy_chain_test', _registerProfile);
}

// 验证机构关注按CID隔离及合库后的无重入关联读取。

void _registerFollow() {
  useIsolatedIsar();
  test('机构关注只按两个自然CID隔离，重复关注不重写且取消不串用户', () async {
    final store = IsarPublicInstitutionStore();
    const owner = 'R5-K3P1C1-N9-D4';
    const other = 'R5-K3P1C1-N8-D5';
    const target = 'R5-K3P1C1-N7-D6';
    await store.subscribe(owner, target);
    await store.subscribe(owner, target);
    await store.subscribe(other, target);
    expect(await store.isSubscribed(owner, target), isTrue);
    expect(await store.isSubscribed(other, target), isTrue);
    expect(await store.isSubscribed(target, owner), isFalse);
    await store.unsubscribe(owner, target);
    expect(await store.isSubscribed(owner, target), isFalse);
    expect(await store.isSubscribed(other, target), isTrue);
  });

  test('合库后机构与关注在同一读取回调中完成关联，不发生重入', () async {
    final store = IsarPublicInstitutionStore();
    await store.upsertInstitutions([
      const PublicInstitutionDto(
        cidNumber: 'synthetic-institution',
        fullName: '合成机构',
        cidState: 'ACTIVE',
        provinceCode: 'ZS',
        cityCode: '001',
        orgCode: 'NRC',
        accountCount: 2,
      ),
    ]);
    await store.subscribe('synthetic-owner', 'synthetic-institution');
    final rows = await store.listSubscribed('synthetic-owner');
    expect(rows.map((row) => row.cidNumber), ['synthetic-institution']);
    expect(await store.listSubscribed('synthetic-other'), isEmpty);
  });
}

// 验证本人资料、徽章及会员页面按需读取和共享缓存。

class _ReadyBusinessGate implements CidBusinessGate {
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() async =>
      const CidBusinessDecision(CidBusinessStatus.ready, cidNumber: _cidNumber);
}

CitizenProfile sampleProfile({
  String displayName = '轻节点',
  String? avatarKey,
  String? bannerKey,
}) => CitizenProfile.fromJson(
  fixtures
      .sampleProfile(
        displayName: displayName,
        avatarKey: avatarKey,
        bannerKey: bannerKey,
      )
      .toJson()
    ..['cid_number'] = _cidNumber,
);

late TestCitizenSdkHarness _sdkHarness;

const _cidNumber = 'CN220-CTZN2-198805200-2026';

final _testWallet = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  ss58Address: 'wallet_profile_test',
  accountId:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  name: '测试钱包',
  createdAtMillis: BigInt.one,
  isDefault: true,
);

/// 身份账户缓存 fake：直接返回已缓存 CID 快照，验证离线读取不会启动轻节点。
class _CachedIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 1,
      accountIndex: 0,
      accountId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ss58Address: 'wallet_profile_test',
      name: '默认账户',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: IdentityBinding(
      genesisHash: '0x${'11' * 32}',
      cidNumber: _cidNumber,
      accountId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      bindRev: 1,
    ),
  );
  @override
  Future<String?> accountId() async =>
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWallet extends TestWalletReads {
  _FakeWallet(this.wallet);

  final CitizenWalletStateAccount wallet;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: [wallet],
        ),
      );
}

class _TrackedIdentityCache extends _CachedIdentityCache {
  _TrackedIdentityCache(this.reads);

  final List<String> reads;

  @override
  Future<CurrentUser?> resolve() {
    reads.add('identity');
    return super.resolve();
  }
}

class _UnboundLocalUser extends _CachedIdentityCache {
  @override
  Future<CurrentUser?> resolve() async =>
      CurrentUser(account: _testWallet, binding: null);
}

class _UnregisteredLocalUser extends _CachedIdentityCache {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: _testWallet,
    binding: null,
    verifiedUnregistered: true,
  );
}

class _UnregisteredBadgeStore extends _FakeIdentityBadgeSnapshotStore {
  @override
  Future<IdentityBadgeSnapshot?> readForAccountId(String accountId) async =>
      IdentityBadgeSnapshot(
        cidNumber: '',
        cidLevel: 'visitor',
        updatedAt: 1,
        accountId: accountId,
        verified: true,
      );
}

class _BackgroundRegistrationResolver extends Fake
    implements FinalizedIdentityResolver {
  final pending = Completer<FinalizedIdentity?>();
  int calls = 0;
  @override
  Future<FinalizedIdentity?> resolve() {
    calls++;
    return pending.future;
  }
}

class _BackgroundRegistrationService extends Fake implements MyIdService {
  int synchronizations = 0;
  int accountReads = 0;
  @override
  Future<void> synchronizeIdentity(FinalizedIdentity identity) async {
    synchronizations++;
  }

  @override
  Future<List<CitizenWalletStateAccount>> listBindableAccounts() async {
    accountReads++;
    return [_testWallet];
  }
}

class _VerifiedLocalBadgeStore extends _FakeIdentityBadgeSnapshotStore {
  @override
  Future<IdentityBadgeSnapshot?> readForAccountId(String accountId) async =>
      IdentityBadgeSnapshot(
        cidNumber: _cidNumber,
        cidLevel: 'visitor',
        updatedAt: 1,
        accountId: accountId,
        verified: true,
        identity: CitizenIdentityChainSnapshot(
          cidNumber: _cidNumber,
          accountId: Uint8List.fromList(List.filled(32, 0xaa)),
          bindRev: 1,
          votingIdentity: null,
        ),
      );
}

class _ForbiddenSessionProvider extends FakeSessionProvider {
  _ForbiddenSessionProvider() : super(null, citizenId: _cidNumber);
  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    throw StateError('普通进入不得建立远端会话');
  }

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    calls++;
    throw StateError('普通进入不得验证远端身份');
  }
}

class _FakeIdentityBadgeSnapshotStore extends IdentityBadgeSnapshotStore {
  int readCalls = 0;

  @override
  Future<IdentityBadgeSnapshot?> readForAccountId(String accountId) async =>
      null;

  @override
  Future<IdentityBadgeSnapshot?> read(String cidNumber) async {
    readCalls += 1;
    return IdentityBadgeSnapshot(
      cidNumber: cidNumber,
      cidLevel: 'candidate',
      updatedAt: 1,
    );
  }
}

class _FakeSquareApi extends SquareApiClient {
  int membershipCalls = 0;

  @override
  Future<SquareResourceAuthorization> fetchResourceAuthorization(
    SquareSession session,
  ) async {
    membershipCalls += 1;
    return const SquareResourceAuthorization(
      allowed: false,
      validUntil: 9999999999999,
    );
  }
}

class _ActiveMembershipSquareApi extends SquareApiClient {
  @override
  Future<SquareResourceAuthorization> fetchResourceAuthorization(
    SquareSession session,
  ) async {
    return const SquareResourceAuthorization(
      allowed: false,
      validUntil: 9999999999999,
    );
  }
}

class _StaticProfileMediaCache extends CitizenProfileMediaCache {
  _StaticProfileMediaCache({
    required this.avatarPath,
    required this.bannerPath,
  });

  final String avatarPath;
  final String bannerPath;

  @override
  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) async =>
      CitizenProfileMediaSnapshot(
        avatarPath: avatarPath,
        bannerPath: bannerPath,
      );

  @override
  Future<CitizenProfileMediaSnapshot> refresh({
    required CitizenProfile profile,
    required String? avatarUrl,
    required String? bannerUrl,
    required http.Client client,
  }) => read(profile);
}

class _ConfirmedMembershipSnapshotService implements SubscriptionService {
  int authorizeCalls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MembershipResolver extends Fake implements FinalizedIdentityResolver {}

class _LocalCreatorService extends Fake implements CreatorService {
  int loadCalls = 0;
  @override
  Future<CreatorOverview?> cachedOverview(String cid) async => null;
  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    loadCalls++;
    throw StateError('普通进入不读取远端统计');
  }
}

void _registerProfile() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CitizenProfileApi.resetEntryRefreshMemory();
  });
  _sdkHarness = TestCitizenSdkHarness();
  testWidgets('未注册点击背景直接打开注册弹窗，连续点击不重复打开且取消不进资料页', (tester) async {
    final resolver = _BackgroundRegistrationResolver();
    final registration = _BackgroundRegistrationService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CitizenSdk>.value(value: _sdkHarness.sdk),
          Provider<MyIdService>.value(value: registration),
          Provider<FinalizedIdentityResolver>.value(value: resolver),
        ],
        child: MaterialApp(
          home: MyTab(
            walletStateReader: _FakeWallet(_testWallet).getWalletState,
            currentUserContext: _UnregisteredLocalUser(),
            badgeSnapshotStore: _UnregisteredBadgeStore(),
            profileCache: FakeProfileCache(sampleProfile()),
            profileApi: FakeProfileApi(sampleProfile()),
            sessionProvider: _ForbiddenSessionProvider(),
            subscriptionService: _ConfirmedMembershipSnapshotService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final background = find.byKey(const ValueKey('my-profile-background'));
    final point = tester.getTopLeft(background) + const Offset(20, 100);
    await tester.tapAt(point);
    await tester.pump();
    await tester.tapAt(point);
    await tester.pump();
    expect(resolver.calls, 1);
    expect(find.text('本地尚未保存身份CID号，请主动刷新身份'), findsNothing);
    resolver.pending.complete(
      FinalizedIdentity(
        accountId: _testWallet.accountId,
        accountAddress: _testWallet.ss58Address,
        snapshot: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.byType(UserProfilePage), findsNothing);
    expect(registration.synchronizations, 1);
    expect(registration.accountReads, 1);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsNothing);
    expect(find.byType(UserProfilePage), findsNothing);
    expect(find.text('本地尚未保存身份CID号，请主动刷新身份'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('本地展示CID绑定尚未恢复仍显示本人资料，分类不抢跑会话', (tester) async {
    final session = _ForbiddenSessionProvider();
    final api = FakeProfileApi(
      sampleProfile(),
      throwOnProfile: true,
      throwOnAuthorPosts: true,
    );
    await tester.pumpWidget(
      Provider<CidBusinessGate>.value(
        value: _ReadyBusinessGate(),
        child: Provider<CitizenSdk>.value(
          value: _sdkHarness.sdk,
          child: MaterialApp(
            home: MyTab(
              walletStateReader: _FakeWallet(_testWallet).getWalletState,
              currentUserContext: _UnboundLocalUser(),
              badgeSnapshotStore: _VerifiedLocalBadgeStore(),
              profileCache: FakeProfileCache(sampleProfile()),
              profileApi: api,
              sessionProvider: session,
              subscriptionService: _ConfirmedMembershipSnapshotService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final background = find.byKey(const ValueKey('my-profile-background'));
    await tester.tapAt(tester.getTopLeft(background) + const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(find.byType(UserProfilePage), findsOneWidget);
    for (final tab in ['campaign', 'videos', 'articles', 'posts']) {
      await tester.tap(find.byKey(ValueKey('profile-tab-$tab')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    expect(find.byType(UserProfilePage), findsNothing);
    expect(session.calls, 0);
    expect(api.calls, 0);
    expect(api.authorPostCalls, 0);
    expect(api.localPostCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('我的创作者真实入口反复进入命中共享缓存，无额外链读或会话请求', (tester) async {
    final reader = light.Reader();
    var head = light.block(103);
    reader.ownBehavior =
        (account, block, citizens, creators, ownCreator) async =>
            light.snapshot(
              block,
              account,
              cidNumber: _cidNumber,
              genesisHash: '0x${'11' * 32}',
              ownCreator: ownCreator,
              memberLevel: 'democracy',
            );
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => head,
      getGenesisHash: () async => '0x${'11' * 32}',
      getAccount: () async => _testWallet.accountId,
    );
    final session = _ForbiddenSessionProvider();
    final creator = _LocalCreatorService();
    addTearDown(source.close);
    await source.start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChainDataService>.value(value: source),
          Provider<CidBusinessGate>.value(value: _ReadyBusinessGate()),
          Provider<CitizenSdk>.value(value: _sdkHarness.sdk),
        ],
        child: MaterialApp(
          home: MyTab(
            walletStateReader: _FakeWallet(_testWallet).getWalletState,
            currentUserContext: _CachedIdentityCache(),
            badgeSnapshotStore: _FakeIdentityBadgeSnapshotStore(),
            profileCache: FakeProfileCache(sampleProfile()),
            profileApi: FakeProfileApi(sampleProfile(), throwOnProfile: true),
            sessionProvider: session,
            subscriptionService: _ConfirmedMembershipSnapshotService(),
            creatorService: creator,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('my-service-entry-创作者'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(CreatorPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creator-membership-badge')),
      findsOneWidget,
    );
    expect(find.text('去订阅平台会员'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    head = light.block(104);
    await source.refresh();
    final before = reader.calls.length;
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(CreatorPage), findsOneWidget);
    expect(reader.calls.length, before);
    expect(creator.loadCalls, 0);
    expect(session.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('我的会员订阅真实入口反复进入命中会员价格用量缓存', (tester) async {
    final reader = light.Reader();
    reader.ownBehavior = (a, b, c, d, own) async => light.snapshot(
      b,
      a,
      cidNumber: _cidNumber,
      genesisHash: '0x${'11' * 32}',
      memberLevel: 'democracy',
    );
    var headReads = 0, gets = 0;
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async {
        headReads++;
        return light.block(103);
      },
      getGenesisHash: () async => '0x${'11' * 32}',
      getAccount: () async => _testWallet.accountId,
    );
    final session = SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'my-membership',
      cidNumber: _cidNumber,
      accountId: _testWallet.accountId,
      bindRev: 1,
      expiresAt: 9999999999999,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final api = SquareApiClient(
      baseUrl: 'https://membership.test/api',
      httpClient: MockClient((r) async {
        gets++;
        return http.Response(jsonEncode(resourceAuthorizationFixture()), 200);
      }),
    );
    final service = SubscriptionService(
      chainData: source,
      identityResolver: _MembershipResolver(),
      api: api,
      getWalletState: () => throw StateError('展示不读签名账户'),
    );
    final sessions = _ForbiddenSessionProvider();
    addTearDown(() async {
      api.close();
      await source.close();
      SubscriptionService.invalidateCitizenAccount(_testWallet.accountId);
    });
    await source.start();
    await source.ensureMembership(
      genesisHash: '0x${'11' * 32}',
      accountId: _testWallet.accountId,
      cidNumber: _cidNumber,
      bindRev: 1,
    );
    await service.authorizeResources(session);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChainDataService>.value(value: source),
          Provider<CitizenSdk>.value(value: _sdkHarness.sdk),
        ],
        child: MaterialApp(
          home: MyTab(
            walletStateReader: _FakeWallet(_testWallet).getWalletState,
            currentUserContext: _CachedIdentityCache(),
            badgeSnapshotStore: _FakeIdentityBadgeSnapshotStore(),
            profileCache: FakeProfileCache(sampleProfile()),
            sessionProvider: sessions,
            subscriptionService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = (headReads, gets, reader.priceCalls.length);
    final entry = find.byKey(const ValueKey('my-service-entry-会员｜订阅'));
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(MembershipPage), findsOneWidget);
      expect(find.text('当前会员'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect((headReads, gets, reader.priceCalls.length), before);
    expect(sessions.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('我的页面只读徽章快照且不启动轻节点', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshotStore = _FakeIdentityBadgeSnapshotStore();
    final wallet = _testWallet;
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MyTab(
            walletStateReader: _FakeWallet(wallet).getWalletState,
            currentUserContext: _CachedIdentityCache(),
            badgeSnapshotStore: snapshotStore,
            profileCache: FakeProfileCache(sampleProfile()),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _ConfirmedMembershipSnapshotService(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IdentityBadge), findsOneWidget);
    expect(snapshotStore.readCalls, 1);
    expect(find.text('钱包'), findsOneWidget);
    expect(find.text('管理账户'), findsOneWidget);
    expect(find.text('身份'), findsOneWidget);
    expect(find.text('注册与查看'), findsOneWidget);
    expect(find.text('个人服务'), findsOneWidget);
    expect(find.text('会员｜订阅'), findsOneWidget);
    expect(find.text('创作者'), findsOneWidget);
    expect(find.text('通讯录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my-header-status-bar-scrim')),
      findsOneWidget,
    );
    final creatorTop = tester.getTopLeft(find.text('创作者')).dy;
    final contactsTop = tester.getTopLeft(find.text('通讯录')).dy;
    final membershipTop = tester.getTopLeft(find.text('会员｜订阅')).dy;
    expect(creatorTop, lessThan(contactsTop));
    expect(contactsTop, lessThan(membershipTop));
    expect(
      tester.getSize(find.byKey(const ValueKey('my-primary-entry-钱包'))).height,
      AppLayout.primaryEntryHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('my-primary-entry-身份'))).height,
      AppLayout.primaryEntryHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('my-service-entry-创作者'))).height,
      AppLayout.serviceRowHeight,
    );

    final userCodeButton = find.byKey(
      const ValueKey('my-header-user-code-button'),
    );
    final profileChevron = find.byKey(const ValueKey('my-profile-chevron'));
    expect(userCodeButton, findsOneWidget);
    expect(profileChevron, findsOneWidget);
    expect(
      (tester.getCenter(userCodeButton).dx -
              tester.getCenter(profileChevron).dx)
          .abs(),
      lessThan(0.01),
    );
    final userCodeIconRect = tester.getRect(
      find.byIcon(Icons.qr_code_2_rounded),
    );
    final myTitleRect = tester.getRect(find.text('我的'));
    // 验收比较可见图标顶部与文字底部，而不是再次用两个顶部位置糊弄。
    expect(userCodeIconRect.top, greaterThanOrEqualTo(myTitleRect.bottom));
    expect(
      userCodeIconRect.top - myTitleRect.bottom,
      closeTo(AppLayout.scaledValue(1), 0.5),
    );

    await tester.tap(userCodeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UserQrPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '我的用户码'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('我的页面展示公开昵称且钱包改名广播不重复刷新资料', (tester) async {
    final wallet = _testWallet;
    final reads = <String>[];
    final profileApi = FakeProfileApi(sampleProfile(displayName: '公开昵称'));
    final profileCache = FakeProfileCache(sampleProfile(displayName: '缓存昵称'));
    final squareApi = _FakeSquareApi();
    final membershipService = _ConfirmedMembershipSnapshotService();
    final snapshotStore = _FakeIdentityBadgeSnapshotStore();
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          home: MyTab(
            walletStateReader: () {
              reads.add('wallet');
              return _FakeWallet(wallet).getWalletState();
            },
            currentUserContext: _TrackedIdentityCache(reads),
            badgeSnapshotStore: snapshotStore,
            profileApi: profileApi,
            profileCache: profileCache,
            sessionProvider: FakeSessionProvider(fakeSession()),
            squareApi: squareApi,
            subscriptionService: membershipService,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(reads.take(2), ['wallet', 'identity']);
    expect(find.text('缓存昵称'), findsOneWidget);
    expect(find.text('不得公开的钱包名'), findsNothing);
    expect(profileApi.calls, 0);
    expect(membershipService.authorizeCalls, 0);
    expect(squareApi.membershipCalls, 0);

    MembershipRevision.instance.notifyChanged(_cidNumber);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(membershipService.authorizeCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('我的首页展示公开头像背景并等待轻节点会员数据', (tester) async {
    late Directory root;
    late File avatar;
    late File banner;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('my-profile-media-');
      final sourceImage = File('assets/logo/mark256.png');
      avatar = sourceImage.copySync('${root.path}/avatar.png');
      banner = sourceImage.copySync('${root.path}/banner.png');
    });
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final wallet = _testWallet;
    final profile = sampleProfile(
      displayName: '统一公开资料',
      avatarKey: 'profile/avatar',
      bannerKey: 'profile/banner',
    );
    final remoteMembership = _ActiveMembershipSquareApi();
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          home: MyTab(
            walletStateReader: _FakeWallet(wallet).getWalletState,
            currentUserContext: _CachedIdentityCache(),
            badgeSnapshotStore: _FakeIdentityBadgeSnapshotStore(),
            profileApi: FakeProfileApi(profile),
            profileCache: FakeProfileCache(profile),
            profileMediaCache: _StaticProfileMediaCache(
              avatarPath: avatar.path,
              bannerPath: banner.path,
            ),
            sessionProvider: FakeSessionProvider(fakeSession()),
            squareApi: remoteMembership,
            subscriptionService: _ConfirmedMembershipSnapshotService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final profileAvatar = tester.widget<ProfileAvatar>(
      find.byType(ProfileAvatar),
    );
    expect(profileAvatar.imagePath, avatar.path);
    expect(profileAvatar.userImageSet, isTrue);
    expect(profileAvatar.size, 80);
    expect(profileAvatar.badgeOverflow, 6);
    final fileImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<FileImage>()
        .map((provider) => provider.file.path)
        .toSet();
    expect(fileImages, containsAll(<String>{avatar.path, banner.path}));
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.checked, isFalse);
    final avatarRect = tester.getRect(find.byType(ProfileAvatar));
    final badgeRect = tester.getRect(find.byType(IdentityBadge));
    expect(badgeRect.right, greaterThan(avatarRect.right));
    expect(badgeRect.bottom, greaterThan(avatarRect.bottom));
    expect(find.text('竞选身份 · 民主会员'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
