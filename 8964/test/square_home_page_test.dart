import 'package:tatachat_sdk/tatachat_sdk.dart' as chat_sdk;
import 'package:citizen_account/membership/subscription_service.dart';

import 'package:citizen_testing/mls_authentication_fixture.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:citizen_square/post/square_post_detail_page.dart';
import 'package:citizen_square/post/square_post_card.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/identity_badge_snapshot_store.dart';
import 'package:citizen_account/identity/citizen_identity_chain_reader.dart';
import 'package:citizen_square/compose/compose_page.dart';
import 'package:citizen_square/compose/document_compose_body.dart';
import 'package:citizen_square/draft/compose_draft.dart';
import 'package:citizen_square/draft/compose_draft_store.dart';
import 'package:citizen_square/compose/video_compose_body.dart';
import 'package:citizen_square/compose/compose_media_widgets.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/feed/square_home_page.dart';
import 'package:citizen_square/feed/square_tab_page.dart';
import 'package:citizen_square/feed/square_tab_order_store.dart';
import 'package:citizen_square/feed/square_feed_tabs.dart';
import 'package:citizen_account/profile/citizen_profile.dart';
import 'package:citizen_account/profile/citizen_profile_cache.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/profile/profile_avatar.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_identity_state.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/cid_business_gate.dart';
import 'package:citizen_account/membership/membership_revision.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_account/identity/identity_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_testing/fake_profile.dart';

/// 身份账户缓存 fake:resolve 返回 null,让 loadCurrent 回退 wallet.account_id
/// 使用测试默认账户快照，避免 instance 访问真实本地钱包/Isar。
class _NullIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => null;
  @override
  Future<String?> accountId() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

class _FakeWallet extends TestWalletReads {
  _FakeWallet(this.wallet);

  final CitizenWalletStateAccount? wallet;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: wallet == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: wallet == null ? const [] : [wallet!],
        ),
      );
}

class _StaticProfileMediaCache extends CitizenProfileMediaCache {
  @override
  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) async =>
      const CitizenProfileMediaSnapshot(avatarPath: '/tmp/synced-avatar.png');
}

final _registeredWallet = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  name: '测试钱包',
  ss58Address: 'citizen_test_account_id',
  accountId:
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  createdAtMillis: BigInt.one,
  isDefault: true,
);

SquareIdentityService _walletIdentityService({_LocalSnapshots? snapshots}) =>
    (() {
      final reads0 = _FakeWallet(_registeredWallet);
      return SquareIdentityService(
        getWalletState: reads0.getWalletState,
        currentUserContext: _NullIdentityCache(),
        badgeSnapshotStore: snapshots ?? _LocalSnapshots(),
        profileCache: FakeProfileCache(),
      );
    })();

SquareIdentityService _emptyIdentityService() => (() {
  final reads0 = _FakeWallet(null);
  return SquareIdentityService(
    getWalletState: reads0.getWalletState,
    currentUserContext: _NullIdentityCache(),
    badgeSnapshotStore: _LocalSnapshots(),
  );
})();

SquareIdentityService _unregisteredIdentityService() => (() {
  final reads0 = _FakeWallet(_registeredWallet);
  return SquareIdentityService(
    getWalletState: reads0.getWalletState,
    currentUserContext: _UnregisteredIdentityCache(),
    badgeSnapshotStore: _LocalSnapshots(),
  );
})();

/// 显示服务只依赖本地事实；测试记录本地读取，不提供链服务。
class _LocalSnapshots extends IdentityBadgeSnapshotStore {
  _LocalSnapshots({this.registered = false});
  final bool registered;
  int reads = 0;
  @override
  Future<IdentityBadgeSnapshot?> readForAccountId(String accountId) async {
    reads++;
    return IdentityBadgeSnapshot(
      cidNumber: registered ? testMlsCidNumber : '',
      cidLevel: 'visitor',
      updatedAt: 1,
      accountId: accountId,
      verified: true,
      // 正向发布夹具提供完整已注册事实；默认仍是明确未注册，不更改反向用例。
      identity: registered
          ? CitizenIdentityChainSnapshot(
              cidNumber: testMlsCidNumber,
              accountId: Uint8List.fromList(List<int>.filled(32, 0xaa)),
              bindRev: 1,
              votingIdentity: null,
            )
          : null,
    );
  }
}

class _StaticComposeIdentityService implements SquareIdentityService {
  const _StaticComposeIdentityService();

  @override
  Future<SquareIdentityState> loadCurrent() async {
    return const SquareIdentityState(
      accountId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      cidNumber: 'CN220-CTZN2-100000001-2026',
      displayName: '不应显示的用户昵称',
      signMode: CitizenWalletSignMode.hot,
      cidLevel: 'voting',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

class _DelayedComposeIdentityService implements SquareIdentityService {
  final Completer<SquareIdentityState> completer =
      Completer<SquareIdentityState>();

  @override
  Future<SquareIdentityState> loadCurrent() => completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// 每次身份revision生成独立请求，验证旧账户迟到不会覆盖最新展示。
class _QueuedHomeIdentityService implements SquareIdentityService {
  final requests = <Completer<SquareIdentityState>>[];

  @override
  Future<SquareIdentityState> loadCurrent() {
    final request = Completer<SquareIdentityState>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// 保留主页自行创建身份服务的生产接线，只控制公开当前用户解析的完成顺序。
class _QueuedHomeCurrentUser implements CurrentUserContext {
  final requests = <Completer<CurrentUser?>>[];

  @override
  Future<CurrentUser?> resolve() {
    final request = Completer<CurrentUser?>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('主页回归未配置当前用户操作');
}

/// 身份服务依次读取隔离库中的完整身份和公开资料；有界驱动真实I/O及测试微任务，
/// 两次队列屏障保证迟到身份已经读完，避免仅因异步结果尚未完成而得到阴性断言。
Future<void> _drainHomeIdentityReads(WidgetTester tester) async {
  for (var stage = 0; stage < 2; stage++) {
    await tester.pump();
    var reached = false;
    final barrier = UserIsar.instance.read<void>((_) async {
      reached = true;
    });
    for (var attempt = 0; attempt < 100 && !reached; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(reached, isTrue, reason: '隔离身份读取必须完成，不能跳过迟到结果校验');
    await barrier;
  }
  await tester.pumpAndSettle();
}

class _RecordingDraftRepository implements SquareComposeDraftRepository {
  final List<SquareComposeDraft> saved = <SquareComposeDraft>[];
  final List<String> deleted = <String>[];

  @override
  Future<void> save(SquareComposeDraft draft) async => saved.add(draft);

  @override
  Future<List<SquareComposeDraft>> list(String cidNumber) async =>
      List<SquareComposeDraft>.unmodifiable(saved);

  @override
  Future<void> delete(String cidNumber, String draftId) async {
    deleted.add('$cidNumber:$draftId');
  }

  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {}
}

class _FakeFeedSource implements SquareFeedSource {
  const _FakeFeedSource();

  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    return const <SquarePost>[];
  }
}

/// 模拟后台通知在创建会话时抛出非 Exception 错误，验证 unawaited 边界完整。
class _ThrowingSessionProvider implements SquareSessionProvider {
  @override
  Future<SquareSession?> ensureSession() async {
    throw StateError('session unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

class _DeviceMissingSessionProvider implements SquareSessionProvider {
  int registrationCalls = 0;

  @override
  Future<SquareSession?> ensureSession() async {
    if (registrationCalls == 0) {
      throw const SquareApiException(
        '设备未登记',
        errorCode: 'device_not_registered',
      );
    }
    return SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'registered',
      cidNumber: 'CN220-CTZN2-100000001-2026',
      bindRev: 1,
      accountId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  Future<SquareSession?> registerCurrentDevice() async {
    registrationCalls++;
    return ensureSession();
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// 保持生产路径类型判断成立，但不访问真实 Worker。
class _FakeSquareApiClient extends SquareApiClient {
  _FakeSquareApiClient({
    super.baseUrl,
    super.httpClient,
    this.posts = const <SquarePost>[],
  });
  final List<SquarePost> posts;
  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    return posts;
  }
}

/// 只给信息流的首次握手提供会话，避免本头像回归启动无关通知网络。
class _FeedOnlySessionProvider extends FakeSessionProvider {
  _FeedOnlySessionProvider(super.session);
  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async => ++calls == 1 ? session : null;
}

/// 未注册：当前默认账户的本地绑定为空，不回退其他账户。
class _UnregisteredIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 1,
      accountIndex: 0,
      accountId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      ss58Address: 'ss58-demo',
      name: '默认账户',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// Worker 真源判定:登录挑战对未绑定账户回 403 cid_not_bound。
class _CidNotBoundSessionProvider implements SquareSessionProvider {
  _CidNotBoundSessionProvider({this.errorCode = 'cid_not_bound'});
  final String errorCode;
  @override
  Future<SquareSession?> ensureSession() async {
    throw SquareApiException('当前身份不可用', statusCode: 403, errorCode: errorCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

/// 记录最近一次请求的分类，用于断言分类切换真的按 feedKind 重新拉流。
class _RecordingFeedSource implements SquareFeedSource {
  SquareFeedKind? lastFeedKind;
  int calls = 0;

  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    calls++;
    lastFeedKind = feedKind;
    return const <SquarePost>[];
  }
}

/// 控制 feed 完成时机，验证网络未返回时页面结构仍已显示。
class _PendingFeedSource implements SquareFeedSource {
  final Completer<List<SquarePost>> completer = Completer<List<SquarePost>>();
  int calls = 0;

  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) {
    calls += 1;
    return completer.future;
  }
}

/// 按分类返回不同夹具的假数据源；模拟 Worker 对每个 feed 端点各自过滤
/// （关注流走 `/api/8964/feed/following` 的 JOIN 结果）。
class _KindFeedSource implements SquareFeedSource {
  _KindFeedSource({this.following = const <SquarePost>[]});

  final List<SquarePost> following;

  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    if (feedKind == SquareFeedKind.following) return following;
    return const <SquarePost>[];
  }
}

SquareMediaItem _media(SquareMediaKind kind) =>
    SquareMediaItem(mediaKind: kind, url: '');

SquarePost _seedPost({
  required String id,
  required String text,
  String? title,
  SquarePostType postType = SquarePostType.document,
  List<SquareMediaItem> media = const [],
}) {
  return SquarePost(
    postId: id,
    author: const SquareAuthor(
      accountId:
          '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      displayName: '作者',
      cidLevel: 'voting',
    ),
    postCategory: SquarePostCategory.normal,
    postType: postType,
    text: text,
    title: title,
    publishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    mediaItems: media,
  );
}

class _ReadyBusinessGate implements CidBusinessGate {
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() async => const CidBusinessDecision(
    CidBusinessStatus.ready,
    cidNumber: testMlsCidNumber,
  );
}

Widget _wrap(Widget child) {
  return Provider<CidBusinessGate>.value(
    value: _ReadyBusinessGate(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

class _GateMlsSessions implements SquareSessionProvider {
  bool ready = false;
  int calls = 0;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    calls++;
    return ready
        ? SquareSessionResolution(
            SquareSessionStatus.ready,
            session: fakeSquareSession(testMlsAccountId),
          )
        : SquareSessionResolution.fromError(
            const chat_sdk.MlsNativeException(
              chat_sdk.MlsNativeErrorCode.directoryInvalid,
              'synthetic raw directory detail',
            ),
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}

void main() {
  _squareTabGateTests();
  _squareOrderPersistenceTests();
  testWidgets('真实广场门禁只显示固定MLS原因，下拉重试成功后挂载内容且不增加按钮', (tester) async {
    final sessions = _GateMlsSessions();
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipBusinessGate(
          sessionProvider: sessions,
          child: const Text('合成广场内容'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本机聊天存储路径校验失败'), findsOneWidget);
    expect(find.textContaining('synthetic raw'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('合成广场内容'), findsNothing);
    sessions.ready = true;
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('合成广场内容'), findsOneWidget);
    expect(sessions.calls, 2);
  });

  for (final type in [SquarePostType.document, SquarePostType.article]) {
    testWidgets('广场$type作者头像实际GET使用当前会话及新鲜MLS证明', (tester) async {
      final bytes = await tester.runAsync(
        () => File('assets/logo/mark256.png').readAsBytes(),
      );
      final requests = <http.Request>[];
      var signed = 0;
      final session = SquareSession(
        deviceId: testMlsDeviceId,
        sessionToken: 'synthetic-feed-token',
        cidNumber: testMlsCidNumber,
        bindRev: 1,
        accountId: testMlsAccountId,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
        authenticateRequest:
            ({
              required method,
              required uri,
              required body,
              required sessionToken,
            }) async {
              expect(method, 'GET');
              expect(
                uri.path,
                '/api/user/profiles/$testMlsCidNumber/assets/avatar',
              );
              expect(body, isEmpty);
              expect(sessionToken, 'synthetic-feed-token');
              return {'x-mls-proof': 'feed-${++signed}'};
            },
      );
      final source = _FakeSquareApiClient(
        baseUrl: 'https://example.com/api',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            bytes!,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
        posts: [
          SquarePost(
            postId: 'signed-feed-${type.name}',
            author: const SquareAuthor(
              accountId: testMlsAccountId,
              cidNumber: testMlsCidNumber,
              displayName: '合成作者',
              avatarKey: 'profile/$testMlsCidNumber/avatar',
            ),
            postCategory: SquarePostCategory.normal,
            postType: type,
            text: '合成正文',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          SquareHomePage(
            tabOrderStore: const _MemoryTabOrderStore(),
            identityService: const _StaticComposeIdentityService(),
            feedSource: source,
            sessionProvider: _FeedOnlySessionProvider(session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var n = 0; n < 30 && requests.isEmpty; n++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        requests.single.url.toString(),
        'https://example.com/api/user/profiles/$testMlsCidNumber/assets/avatar',
      );
      expect(
        requests.single.headers['authorization'],
        'Bearer synthetic-feed-token',
      );
      expect(requests.single.headers['x-mls-proof'], 'feed-1');
      expect(requests.single.followRedirects, isFalse);
      expect(signed, 1);
      expect(find.text('合成作者'), findsOneWidget);
      expect(find.text('合成正文'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      source.close();
    });
  }
  for (final replace in [false, true]) {
    testWidgets('详情返回${replace ? '替换' : '删除'}结果就地更新，不重查公共流', (tester) async {
      final source = _RecordingFeedSource();
      final session = FakeSessionProvider(null);
      await tester.pumpWidget(
        Provider<SquareSessionProvider>.value(
          value: session,
          child: _wrap(
            SquareHomePage(
              tabOrderStore: const _MemoryTabOrderStore(),
              identityService: const _StaticComposeIdentityService(),
              feedSource: source,
              sessionProvider: session,
              seedPosts: [samplePost(text: '操作前正文')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      tester.widget<SquarePostCard>(find.byType(SquarePostCard)).onTap!();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SquarePostDetailPage))).pop(
        replace
            ? SquarePostDetailResult(
                replacement: samplePost(id: 'replacement', text: '操作后正文'),
              )
            : const SquarePostDetailResult(deleted: true),
      );
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      expect(find.text('操作前正文'), findsNothing);
      expect(find.text('操作后正文'), replace ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('主页真实账户revision接线', () {
    useIsolatedIsar();
    late CitizenSdk sdk;
    late AccountSecurityService security;
    late _QueuedHomeCurrentUser current;
    late CurrentUser registered;
    late _RecordingFeedSource feed;
    late int badgeRevision;
    var walletReads = 0;
    var walletPresent = true;
    CitizenSdkOperation<CitizenWalletState> readWallet() {
      walletReads++;
      return testCitizenOperation(
        () => walletPresent
            ? testCitizenWalletState()
            : CitizenWalletState(
                revision: BigInt.two,
                hotProfile: null,
                accounts: [],
                initializationState: CitizenWalletInitializationState.empty,
                cleanupPending: false,
              ),
      );
    }

    setUp(() async {
      badgeRevision = IdentityBadgeSnapshotStore.revision.value;
      walletPresent = true;
      final core = await openTestSdk();
      sdk = core.sdk;
      final account = testCitizenWalletState().defaultAccount!;
      walletReads = 0;
      current = _QueuedHomeCurrentUser();
      feed = _RecordingFeedSource();
      security = AccountSecurityService(
        getWalletState: readWallet,
        signing: sdk,
        mlsDeviceRegistrar: ({
          required cidNumber,
          required bindRev,
          required accountId,
          required signBinding,
        }) async => throw StateError('主页回归禁止登记MLS设备'),
        coldMlsDeviceBindingSigner: ({
          required binding,
          required payload,
          required signingMessage,
          required publicKey,
          required issuedAtMillis,
        }) async => throw StateError('主页回归禁止钱包签名'),
      );
      registered = CurrentUser(
        account: account,
        binding: IdentityBinding(
          genesisHash: '0x${'11' * 32}',
          cidNumber: testMlsCidNumber,
          accountId: account.accountId,
          bindRev: 1,
        ),
      );
      // 页面挂载前写合成完整快照；只使用本组独占Isar，不读取设备钱包或金库。
      await IdentityBadgeSnapshotStore().writeVerified(
        accountId: account.accountId,
        identity: CitizenIdentityChainSnapshot(
          cidNumber: testMlsCidNumber,
          accountId: Uint8List.fromList(List<int>.filled(32, 1)),
          bindRev: 1,
          votingIdentity: null,
        ),
        isCurrent: () => true,
      );
    });

    tearDown(() async {
      security.dispose();
      await sdk.close();

      IdentityBadgeSnapshotStore.revision.value = badgeRevision;
    });

    Widget page() => MultiProvider(
      providers: [
        Provider<CitizenSdk>.value(value: sdk),
        Provider<AccountSecurityService>.value(value: security),
        Provider<CurrentUserContext>.value(value: current),
        Provider<SquareSessionProvider>.value(value: FakeSessionProvider(null)),
      ],
      // 不注入identityService，必须经过真实账户监听和SquareIdentityService创建分支。
      child: _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          walletStateReader: readWallet,
          feedSource: feed,
        ),
      ),
    );

    testWidgets('账户revision变化但新请求未启动时，旧身份不能提交且新结果可恢复', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(page());
      await tester.pump();
      expect(current.requests, hasLength(1));
      expect(walletReads, 1);
      expect(feed.calls, 1);
      expect(find.byTooltip('发布'), findsNothing);

      security.notifyDefaultAccountChanged();
      await tester.pump();
      expect(security.revision.value, 1);
      expect(current.requests, hasLength(2));
      // 钱包回调仍在等待解析，身份请求序号尚未推进，单独验证账户版本保护。
      current.requests[0].complete(registered);
      await _drainHomeIdentityReads(tester);
      expect(walletReads, 1);
      expect(feed.calls, 1);
      expect(find.byTooltip('发布'), findsNothing);
      expect(tester.takeException(), isNull);

      current.requests[1].complete(registered);
      await tester.pump();
      expect(current.requests, hasLength(3));
      expect(walletReads, 2);
      expect(feed.calls, 2);
      current.requests[2].complete(registered);
      await _drainHomeIdentityReads(tester);
      expect(find.byTooltip('发布'), findsOneWidget);
      expect(walletReads, 2);
      expect(feed.calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('钱包身份解析新结果先完成后，旧解析不能额外加载身份或feed', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(page());
      await tester.pump();
      current.requests.single.complete(registered);
      await _drainHomeIdentityReads(tester);
      expect(find.byTooltip('发布'), findsOneWidget);
      expect(walletReads, 1);
      expect(feed.calls, 1);

      security.notifyDefaultAccountChanged();
      security.notifyDefaultAccountChanged();
      await tester.pump();
      expect(security.revision.value, 2);
      expect(current.requests, hasLength(3));
      walletPresent = false;
      current.requests[2].complete(null);
      await tester.pumpAndSettle();
      expect(find.byTooltip('发布'), findsNothing);
      expect(walletReads, 2);
      expect(feed.calls, 2);

      current.requests[1].complete(registered);
      await tester.pumpAndSettle();
      expect(current.requests, hasLength(3));
      expect(walletReads, 2);
      expect(feed.calls, 2);
      expect(find.byTooltip('发布'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('身份延迟完成后通知父页面，feed未返回也显示原发布入口', (tester) async {
    final identity = _DelayedComposeIdentityService();
    final feed = _PendingFeedSource();
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: identity,
          feedSource: feed,
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('发布'), findsNothing);
    identity.completer.complete(
      await const _StaticComposeIdentityService().loadCurrent(),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('发布'), findsOneWidget);
    expect(find.byKey(const ValueKey('square-feed-progress')), findsOneWidget);
    expect(feed.calls, 1);
    feed.completer.complete(const <SquarePost>[]);
    await tester.pumpAndSettle();
  });

  for (final state in [
    const SquareIdentityState(accountId: ''),
    SquareIdentityState(
      accountId: _registeredWallet.accountId,
      signMode: CitizenWalletSignMode.hot,
    ),
  ]) {
    testWidgets('身份延迟返回${state.hasWallet ? '未注册' : '无钱包'}仍不显示发布入口', (
      tester,
    ) async {
      final identity = _DelayedComposeIdentityService();
      await tester.pumpWidget(
        _wrap(
          SquareHomePage(
            tabOrderStore: const _MemoryTabOrderStore(),
            identityService: identity,
            feedSource: const _FakeFeedSource(),
          ),
        ),
      );
      await tester.pump();
      identity.completer.complete(state);
      await tester.pumpAndSettle();
      expect(find.byTooltip('发布'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final registered in [false, true]) {
    testWidgets('较新账户${registered ? '已注册' : '无钱包'}结果不被旧身份迟到覆盖', (tester) async {
      final identity = _QueuedHomeIdentityService();
      final feed = _PendingFeedSource();
      await tester.pumpWidget(
        _wrap(
          SquareHomePage(
            tabOrderStore: const _MemoryTabOrderStore(),
            identityService: identity,
            feedSource: feed,
          ),
        ),
      );
      await tester.pump();
      expect(identity.requests, hasLength(1));
      IdentityBadgeSnapshotStore.revision.value++;
      await tester.pump();
      expect(identity.requests, hasLength(2));
      identity.requests[1].complete(
        registered
            ? const SquareIdentityState(
                accountId: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                cidNumber: 'CN220-CTZN2-100000002-2026',
                signMode: CitizenWalletSignMode.hot,
              )
            : const SquareIdentityState(accountId: ''),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('发布'), registered ? findsOneWidget : findsNothing);
      identity.requests[0].complete(
        registered
            ? SquareIdentityState(accountId: _registeredWallet.accountId)
            : await const _StaticComposeIdentityService().loadCurrent(),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('发布'), registered ? findsOneWidget : findsNothing);
      expect(feed.calls, 1);
      expect(tester.takeException(), isNull);
      feed.completer.complete(const <SquarePost>[]);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('页面卸载后身份完成不更新State', (tester) async {
    final identity = _DelayedComposeIdentityService();
    final feed = _PendingFeedSource();
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: identity,
          feedSource: feed,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    identity.completer.complete(
      await const _StaticComposeIdentityService().loadCurrent(),
    );
    feed.completer.complete(const <SquarePost>[]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed 未返回时直接显示广场页面且不使用整页转圈', (tester) async {
    final feedSource = _PendingFeedSource();

    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: const _StaticComposeIdentityService(),
          feedSource: feedSource,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(feedSource.calls, 1);
    expect(find.byTooltip('发布'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('square-person-tank-watermark')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('square-feed-progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('广场内容加载失败'), findsNothing);

    feedSource.completer.complete(const <SquarePost>[]);
    await tester.pumpAndSettle();

    expect(feedSource.calls, 1);
    expect(find.byKey(const ValueKey('square-feed-progress')), findsNothing);
    expect(find.text('广场内容加载失败'), findsNothing);
  });

  testWidgets('广场只替换人物坦克背景且保留分类、发布与切换行为', (tester) async {
    const identityService = _StaticComposeIdentityService();
    final feedSource = _RecordingFeedSource();

    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: identityService,
          feedSource: feedSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 顶部大小标题与空态图标/文字彻底删除。
    expect(find.text('广场'), findsNothing);
    expect(find.text('暂无推荐内容'), findsNothing);
    expect(find.text('暂无关注内容'), findsNothing);
    expect(find.text('暂无竞选内容'), findsNothing);

    // 中央背景只使用选定的人物坦克透明资源；旧单坦克水印不再存在。
    final watermarkFinder = find.byKey(
      const ValueKey<String>('square-person-tank-watermark'),
    );
    expect(watermarkFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('square-tank-watermark')),
      findsNothing,
    );
    final watermark = tester.widget<Image>(watermarkFinder);
    expect(
      (watermark.image as AssetImage).assetName,
      'packages/citizen_assets/icons/square-person-tank-watermark.png',
    );
    final watermarkContext = tester.element(watermarkFinder);
    expect(
      watermark.width,
      closeTo(AppLayout.scaled(watermarkContext, 280), 0.01),
    );
    expect(
      watermark.height,
      closeTo(AppLayout.scaled(watermarkContext, 141), 0.01),
    );
    final watermarkOpacity = tester.widget<Opacity>(
      find.byKey(
        const ValueKey<String>('square-person-tank-watermark-opacity'),
      ),
    );
    expect(watermarkOpacity.opacity, 0.08);
    // 顶部头像入口已删除；发布改为右下角悬浮 FAB。
    expect(find.byKey(const ValueKey('compose-user-avatar')), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('发布'), findsOneWidget);

    // 五分类可切换：照片不再单独占一档，图片公文继续归普通推荐内容。
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('照片'), findsNothing);
    expect(feedSource.lastFeedKind, SquareFeedKind.recommended);

    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(feedSource.lastFeedKind, SquareFeedKind.following);

    await tester.tap(find.text('竞选'));
    await tester.pumpAndSettle();
    expect(feedSource.lastFeedKind, SquareFeedKind.campaign);

    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();
    expect(feedSource.lastFeedKind, SquareFeedKind.article);

    await tester.tap(find.byIcon(Icons.videocam_outlined));
    await tester.pumpAndSettle();
    expect(feedSource.lastFeedKind, SquareFeedKind.videos);
  });

  testWidgets('会员镜像确认后已挂载广场就地刷新', (tester) async {
    final feedSource = _RecordingFeedSource();
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _emptyIdentityService(),
          feedSource: feedSource,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(feedSource.calls, 1);

    MembershipRevision.instance.notifyChanged('CID-1');
    await tester.pumpAndSettle();
    expect(feedSource.calls, 2);
  });

  testWidgets('广场图片公文留在推荐流，文章和视频继续按内容分类过滤', (tester) async {
    // 带媒体的卡片较高，默认 600 视口会让第二张之后懒加载不构建；用高视口保证三帖都渲染。
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seed = [
      _seedPost(id: 'a', text: '照片帖', media: [_media(SquareMediaKind.image)]),
      _seedPost(
        id: 'b',
        text: '视频帖',
        postType: SquarePostType.video,
        media: [_media(SquareMediaKind.video)],
      ),
      _seedPost(
        id: 'c',
        text: '文章正文C',
        title: '文章帖',
        postType: SquarePostType.article,
      ),
    ];
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _emptyIdentityService(),
          feedSource: _RecordingFeedSource(),
          seedPosts: seed,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 推荐：三帖全在。
    expect(find.text('照片帖'), findsOneWidget);
    expect(find.text('视频帖'), findsOneWidget);
    expect(find.text('文章帖'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();
    expect(find.text('文章帖'), findsOneWidget);
    expect(find.text('照片帖'), findsNothing);
    expect(find.text('视频帖'), findsNothing);

    await tester.tap(find.byIcon(Icons.videocam_outlined));
    await tester.pumpAndSettle();
    expect(find.text('视频帖'), findsOneWidget);
    expect(find.text('照片帖'), findsNothing);
    expect(find.text('文章帖'), findsNothing);
  });

  testWidgets('发布按钮展开公文、文章、视频，打开编辑页不读链', (tester) async {
    final snapshots = _LocalSnapshots(registered: true);
    final identityService = _walletIdentityService(snapshots: snapshots);

    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: identityService,
          feedSource: const _FakeFeedSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(snapshots.reads, greaterThan(0));

    await tester.tap(find.byTooltip('发布'));
    await tester.pumpAndSettle();
    expect(find.text('公文'), findsOneWidget);
    expect(find.text('文章'), findsWidgets);
    expect(find.text('视频'), findsWidgets);
    expect(snapshots.reads, greaterThan(0));

    final itemFinders = [
      find.byKey(const ValueKey('square-publish-document')),
      find.byKey(const ValueKey('square-publish-article')),
      find.byKey(const ValueKey('square-publish-video')),
    ];
    final centers = <Offset>[];
    for (final finder in itemFinders) {
      final size = tester.getSize(finder);
      expect(size.width, closeTo(size.height, 0.01));
      expect(tester.widget<Material>(finder).shape, isA<CircleBorder>());
      final center = tester.getCenter(finder);
      centers.add(center);
    }
    // 公文标签也是完整入口的一部分，因此圆弧虚拟圆心需上移标签高度。
    final arcCenter = Offset(centers[2].dx, centers[0].dy);
    final radii = [for (final center in centers) (center - arcCenter).distance];
    // 三个入口圆心位于同一短半径圆弧，且明显比旧菜单更靠近主按钮。
    expect(radii.reduce((a, b) => a > b ? a : b), lessThan(120));
    expect(
      radii.reduce((a, b) => a > b ? a : b) -
          radii.reduce((a, b) => a < b ? a : b),
      lessThan(0.5),
    );
    // 标准四分之一圆弧：0° / 45° / 90°，两段相邻弦长严格相等。
    expect(centers[0].dy, closeTo(arcCenter.dy, 0.5));
    expect(centers[2].dx, closeTo(arcCenter.dx, 0.5));
    expect(
      (centers[0] - centers[1]).distance,
      closeTo((centers[1] - centers[2]).distance, 0.5),
    );
    expect(
      arcCenter.dx - centers[1].dx,
      closeTo(arcCenter.dy - centers[1].dy, 0.5),
    );
    // 完整入口在设备安全区内比较等距；保留实际安全区和原有一像素容差。
    final pageSize = tester.getSize(find.byType(SquareHomePage));
    final documentBottom = tester.getBottomRight(find.text('公文')).dy;
    final videoRight = tester.getTopRight(itemFinders[2]).dx;
    expect(
      pageSize.height -
          documentBottom -
          MediaQuery.paddingOf(tester.element(find.byType(SquareHomePage)))
              .bottom,
      closeTo(pageSize.width - videoRight, 1),
    );

    await tester.tap(find.byKey(const ValueKey('square-publish-document')));
    await tester.pumpAndSettle();
    expect(find.text('发公文'), findsOneWidget);
    expect(snapshots.reads, greaterThan(0));
  });

  testWidgets('三类发布页标题真正居中、按钮紧凑且只显示同步头像', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const identityService = _StaticComposeIdentityService();

    for (final postType in SquarePostType.values) {
      await tester.pumpWidget(
        _wrap(
          SquareComposePage(
            postType: postType,
            identityService: identityService,
            profileCache: FakeProfileCache(
              sampleProfile(avatarKey: 'profile/avatar'),
            ),
            profileMediaCache: _StaticProfileMediaCache(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageWidth = tester.getSize(find.byType(SquareComposePage)).width;
      final titleCenter = tester.getCenter(
        find.byKey(const ValueKey('compose-centered-title')),
      );
      expect(titleCenter.dx, closeTo(pageWidth / 2, 0.5));
      expect(titleCenter.dy, lessThan(tester.getCenter(find.text('取消')).dy));
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('compose-centered-title')),
      );
      final cancel = tester.widget<Text>(find.text('取消'));
      expect(title.style!.fontSize!, greaterThan(cancel.style?.fontSize ?? 14));
      expect(find.text('发${postType.label}'), findsOneWidget);

      final publishSize = tester.getSize(
        find.byKey(const ValueKey('compose-publish-button')),
      );
      expect(publishSize.height, lessThanOrEqualTo(34));
      expect(publishSize.height, greaterThanOrEqualTo(30));

      final avatar = tester.widget<ProfileAvatar>(
        find.byKey(const ValueKey('compose-user-avatar')),
      );
      expect(avatar.imagePath, '/tmp/synced-avatar.png');
      expect(avatar.borderRadius, 17);
      expect(avatar.showBadge, isFalse);
      expect(find.byType(IdentityBadge), findsNothing);
      expect(find.text('不应显示的用户昵称'), findsNothing);
      expect(find.text(postType.label), findsNothing);
      expect(find.text('发布额度按会员套餐计'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);

      final publishButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('compose-publish-button')),
      );
      expect(publishButton.onPressed, isNull);
    }
  });

  testWidgets('公文内容合法后发布按钮启用，清空后立即恢复灰色禁用', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SquareComposePage(
          postType: SquarePostType.document,
          identityService: _StaticComposeIdentityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FilledButton publishButton() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('compose-publish-button')),
    );
    expect(publishButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '合法公文内容',
    );
    await tester.pump();
    await tester.pump();
    expect(publishButton().onPressed, isNotNull);

    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '',
    );
    await tester.pump();
    await tester.pump();
    expect(publishButton().onPressed, isNull);
  });

  testWidgets('文章首图位于标题右侧，添加图文框独占顶部靠右位置', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SquareComposePage(
          postType: SquarePostType.article,
          identityService: _StaticComposeIdentityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final coverFinder = find.byKey(const ValueKey('article-cover-picker'));
    final addSectionFinder = find.byKey(const ValueKey('article-add-section'));
    final inlineFinder = find.byKey(const ValueKey('article-insert-media-0'));
    expect(coverFinder, findsOneWidget);
    expect(addSectionFinder, findsOneWidget);
    expect(
      tester.widget<ComposeMediaAddButton>(coverFinder).icon,
      Icons.add_photo_alternate_outlined,
    );
    expect(
      tester.getCenter(coverFinder).dy,
      lessThan(tester.getCenter(inlineFinder).dy),
    );
    expect(
      tester.getCenter(addSectionFinder).dx,
      greaterThan(tester.getSize(find.byType(SquareComposePage)).width * 0.75),
    );
    expect(
      tester.getCenter(coverFinder).dy,
      greaterThan(tester.getCenter(addSectionFinder).dy),
    );
    expect(
      tester.getTopRight(coverFinder).dx,
      closeTo(tester.getTopRight(addSectionFinder).dx, 0.5),
    );
    expect(
      tester.getTopRight(inlineFinder).dx,
      closeTo(tester.getTopRight(addSectionFinder).dx, 1.1),
    );
    expect(
      tester.widget<ComposeMediaAddButton>(addSectionFinder).iconSize,
      greaterThan(tester.widget<ComposeMediaAddButton>(inlineFinder).iconSize!),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('compose-fixed-identity-bar')))
          .height,
      // 原布局固定基准50，按当前设备宽度缩放，不能固定为桌面夹具的45。
      closeTo(AppLayout.scaled(tester.element(addSectionFinder), 50), 0.5),
    );
    expect(
      tester.getCenter(inlineFinder).dx,
      greaterThan(tester.getSize(find.byType(SquareComposePage)).width * 0.75),
    );
  });

  testWidgets('取消前立即保存最新文字，身份稍后完成也不丢失草稿', (tester) async {
    final identityService = _DelayedComposeIdentityService();
    final drafts = _RecordingDraftRepository();
    await tester.pumpWidget(
      _wrap(
        SquareComposePage(
          postType: SquarePostType.document,
          identityService: identityService,
          draftStore: drafts,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '尚未到防抖时间也必须保存的文字',
    );
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(drafts.saved, isEmpty);

    identityService.completer.complete(
      const SquareIdentityState(
        accountId: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        signMode: CitizenWalletSignMode.hot,
      ),
    );
    await tester.pumpAndSettle();
    expect(drafts.saved, hasLength(1));
    expect(drafts.saved.single.text, '尚未到防抖时间也必须保存的文字');
  });

  testWidgets('公文9张后顶部图片入口禁用，视频选中后顶部显示首帧入口', (tester) async {
    const image = SquareLocalMediaDraft(
      mediaKind: SquareMediaKind.image,
      path: '/tmp/missing-document-image.jpg',
      fileName: 'image.jpg',
      contentType: 'image/jpeg',
      byteSize: 1,
    );
    const video = SquareLocalMediaDraft(
      mediaKind: SquareMediaKind.video,
      path: '/tmp/missing-video.mp4',
      fileName: 'video.mp4',
      contentType: 'video/mp4',
      byteSize: 1,
      videoSecs: 10,
    );

    await tester.pumpWidget(
      _wrap(
        const SquareComposePage(
          postType: SquarePostType.document,
          identityService: _StaticComposeIdentityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final documentState = tester.state<SquareDocumentComposeBodyState>(
      find.byType(SquareDocumentComposeBody),
    );
    documentState.restore(
      const SquareComposeDraft(
        draftId: 'document-draft',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        postType: SquarePostType.document,
        text: '',
        media: [image, image, image, image, image, image, image, image, image],
        updatedAt: 1,
      ),
    );
    await tester.pump();

    final imageAction = tester.widget<ComposeMediaAddButton>(
      find.byKey(const ValueKey('document-add-images')),
    );
    expect(imageAction.onPressed, isNull);
    expect(find.text('图片  9/9'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const SquareComposePage(
          postType: SquarePostType.video,
          identityService: _StaticComposeIdentityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final videoState = tester.state<SquareVideoComposeBodyState>(
      find.byType(SquareVideoComposeBody),
    );
    videoState.restore(
      const SquareComposeDraft(
        draftId: 'video-draft',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        postType: SquarePostType.video,
        text: '',
        media: [video],
        updatedAt: 1,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('video-picker-thumbnail')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('video-picker')), findsNothing);
    expect(find.byKey(const ValueKey('video-local-preview')), findsOneWidget);
  });

  group('关注流', () {
    testWidgets('渲染服务端关注帖(公文+文章)，本地种子不混入', (tester) async {
      final feedSource = _KindFeedSource(
        following: [
          _seedPost(id: 'f1', text: '关注公文AA'),
          _seedPost(
            id: 'f2',
            text: '文章摘要',
            title: '关注文章BB',
            postType: SquarePostType.article,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          SquareHomePage(
            tabOrderStore: const _MemoryTabOrderStore(),
            identityService: _emptyIdentityService(),
            feedSource: feedSource,
            seedPosts: [_seedPost(id: 's1', text: '种子SS')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 推荐流(默认)：种子帖在。
      expect(find.text('种子SS'), findsOneWidget);

      // 关注流：只服务端 following 结果(公文+文章)，种子不混入。
      await tester.tap(find.text('关注'));
      await tester.pumpAndSettle();
      expect(find.text('关注公文AA'), findsOneWidget);
      expect(find.text('关注文章BB'), findsOneWidget);
      expect(find.text('种子SS'), findsNothing);
    });
  });

  testWidgets('信息流与后台通知会话快速失败时不产生未捕获异步异常', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _emptyIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: _ThrowingSessionProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);

    // 会话失败属通用故障(非未注册),维持原故障文案,不得误入注册引导。
    expect(find.text('广场内容加载失败'), findsOneWidget);
    expect(find.text('尚未注册'), findsNothing);
  });

  testWidgets('广场设备失败不增加准备按钮或误显注册', (tester) async {
    final provider = _DeviceMissingSessionProvider();
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _emptyIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: provider,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.registrationCalls, 0);
    expect(find.byKey(const ValueKey('square-register-device')), findsNothing);
    expect(find.text('验证并登记本机设备'), findsNothing);
    expect(find.text('公民服务准备未完成，请重试'), findsOneWidget);
    expect(find.text('注册'), findsNothing);
  });

  testWidgets('已核实未注册显示统一注册引导', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _unregisteredIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: _CidNotBoundSessionProvider(
            errorCode: 'identity_unregistered',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 引导态呈现,假故障文案禁止出现。
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('广场内容加载失败'), findsNothing);
  });

  testWidgets('缓存缺失且Worker投影未绑定保持未知，不误显注册', (tester) async {
    // 缺少本机事实时，服务端投影缺失仍不能当作已核实未注册。
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _emptyIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: _CidNotBoundSessionProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('尚未注册'), findsNothing);
    expect(find.text('身份同步中，请稍后重试'), findsOneWidget);
    expect(find.text('注册'), findsNothing);
    expect(find.text('广场内容加载失败'), findsNothing);
  });
  testWidgets('已有身份但生产投影未绑定时不显示注册按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: const _StaticComposeIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: _CidNotBoundSessionProvider(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('身份同步中，请稍后重试'), findsOneWidget);
    expect(find.text('注册'), findsNothing);
  });
}

/// 控制公民圈响应时机，验证分类切换时不混入推荐或种子内容。
class _CirclePendingFeedSource implements SquareFeedSource {
  final pending = Completer<List<SquarePost>>();
  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    if (feedKind == SquareFeedKind.circle) return pending.future;
    return [_seedPost(id: 'stranger', text: '推荐陌生用户内容')];
  }
}

void _squareOrderPersistenceTests() {
  group('广场真实顺序持久化接线', () {
    useIsolatedIsar();
    setUp(() async => UserIsar.instance.db());
    testWidgets('松手落库、重新创建页面保留顺序并请求首项，重新进广场也选首项', (tester) async {
      final feed = _RecordingFeedSource();
      final selected = ValueNotifier<int>(0);
      addTearDown(selected.dispose);
      Widget page() => _wrap(
        SquareHomePage(
          identityService: _walletIdentityService(),
          feedSource: feed,
          selectedTab: selected,
        ),
      );
      await tester.pumpWidget(page());
      await _drainHomeIdentityReads(tester);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('square-tab-circle'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('square-tab-recommended'))),
      );
      await tester.pump();
      await gesture.up();
      await _drainHomeIdentityReads(tester);
      await tester.pumpAndSettle();
      var tabs = tester.widget<SquareFeedTabs>(find.byType(SquareFeedTabs));
      expect(tabs.order.first, SquareFeedKind.circle);
      expect(tabs.selected, SquareFeedKind.recommended);
      expect(
        (await tester.runAsync(() => const SquareTabOrderStore().read()))!
            .first,
        SquareFeedKind.circle,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final before = feed.calls;
      await tester.pumpWidget(page());
      await _drainHomeIdentityReads(tester);
      await tester.pumpAndSettle();
      tabs = tester.widget<SquareFeedTabs>(find.byType(SquareFeedTabs));
      expect(tabs.order.first, SquareFeedKind.circle);
      expect(tabs.selected, SquareFeedKind.circle);
      expect(feed.calls, before + 1);
      expect(feed.lastFeedKind, SquareFeedKind.circle);
      await tester.tap(find.text('视频'));
      await tester.pumpAndSettle();
      selected.value = 1;
      selected.value = 0;
      await tester.pumpAndSettle();
      expect(
        tester.widget<SquareFeedTabs>(find.byType(SquareFeedTabs)).selected,
        SquareFeedKind.circle,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _drainHomeIdentityReads(tester);
    });
  });

  testWidgets('公民圈等待返回期间不显示推荐流或种子中的陌生用户内容', (tester) async {
    final feed = _CirclePendingFeedSource();
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          tabOrderStore: const _MemoryTabOrderStore(),
          identityService: _walletIdentityService(),
          feedSource: feed,
          seedPosts: [_seedPost(id: 'seed', text: '种子陌生内容')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('推荐陌生用户内容'), findsOneWidget);
    await tester.tap(find.text('公民圈'));
    await tester.pump();
    expect(find.text('推荐陌生用户内容'), findsNothing);
    expect(find.text('种子陌生内容'), findsNothing);
    feed.pending.complete([_seedPost(id: 'mutual', text: '互关用户内容')]);
    await tester.pumpAndSettle();
    expect(find.text('互关用户内容'), findsOneWidget);
  });
}

class _MemoryTabOrderStore extends SquareTabOrderStore {
  const _MemoryTabOrderStore();
  @override
  Future<List<SquareFeedKind>> read() async => List.of(SquareFeedKind.values);
  @override
  Future<void> write(List<SquareFeedKind> order) async {}
}

// 真实SquareTab不注入页面替身；只在公开CID/SDK/会话边界提供合成事实。

class _TabGate implements CidBusinessGate {
  _TabGate(this.status);
  CidBusinessStatus status;
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() async => CidBusinessDecision(
    status,
    cidNumber: status == CidBusinessStatus.ready ? testMlsCidNumber : null,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unconfigured CID boundary');
}

class _UnavailableTabSessions implements SquareSessionProvider {
  int ensureCalls = 0, resolveCalls = 0, registrationCalls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    ensureCalls++;
    throw const SquareApiException(
      'synthetic unavailable',
      statusCode: 503,
      errorCode: 'synthetic_service_unavailable',
      stage: SquareApiStage.challenge,
    );
  }

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    resolveCalls++;
    return SquareSessionResolution.fromError(
      const SquareApiException(
        'synthetic unavailable',
        statusCode: 503,
        stage: SquareApiStage.challenge,
      ),
    );
  }

  @override
  Future<SquareSession?> registerCurrentDevice() async {
    registrationCalls++;
    throw StateError('CID入口不得触发设备登记');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unconfigured session boundary');
}

void _squareTabGateTests() {
  group('广场真实Tab事实门禁', () {
    useIsolatedIsar();
    late CitizenSdk sdk;
    late AccountSecurityService security;
    late _TabGate gate;
    late _UnavailableTabSessions sessions;
    late CurrentUserContext current;
    setUp(() async {
      // 与既有真实主页回归相同，在真实异步区打开库，避免原生回调绑定到测试虚拟时钟。
      await UserIsar.instance.db();
      final core = await openTestSdk(
        modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
      );
      sdk = core.sdk;
      await sdk.importColdAccount(accountId: testCitizenAccountId).result;
      security = AccountSecurityService(
        getWalletState: sdk.getWalletState,
        signing: sdk,
        mlsDeviceRegistrar: ({
          required cidNumber,
          required bindRev,
          required accountId,
          required signBinding,
        }) async => throw StateError('测试禁止登记设备'),
        coldMlsDeviceBindingSigner: ({
          required binding,
          required payload,
          required signingMessage,
          required publicKey,
          required issuedAtMillis,
        }) async => throw StateError('测试禁止钱包签名'),
      );
      gate = _TabGate(CidBusinessStatus.ready);
      sessions = _UnavailableTabSessions();
      current = CurrentUserContext(
        getWalletState: sdk.getWalletState,
        accountSecurity: security,
        bindingReader: (accountId) async => IdentityBinding(
          genesisHash: '0x${'11' * 32}',
          cidNumber: testMlsCidNumber,
          accountId: accountId,
          bindRev: 1,
        ),
        identityReader: (_) async => null,
      );
    });
    tearDown(() async {
      security.dispose();
      gate.revision.dispose();
      await sdk.close();
    });
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CitizenSdk>.value(value: sdk),
            Provider<AccountSecurityService>.value(value: security),
            Provider<CurrentUserContext>.value(value: current),
            Provider<SquareSessionProvider>.value(value: sessions),
            Provider<CidBusinessGate>.value(value: gate),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SquareTab(),
          ),
        ),
      );
      await _drainHomeIdentityReads(tester);
      if (gate.status == CidBusinessStatus.ready) {
        // 生产主页会顺序读取本地身份、徽章和资料；等待实际入口出现，不以空闲帧冒充完成。
        for (
          var attempt = 0;
          attempt < 100 && find.byTooltip('发布').evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
    }

    Future<void> check(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      try {
        await open(tester);
        await body();
      } finally {
        // 原生库关闭也必须在Widget测试仍可驱动微任务时完成，不能留到外层tearDown。
        await tester.pumpWidget(const SizedBox.shrink());
        // 编辑页身份完成后还会排队读取头像；逐段驱动原队列，不能在标题出现时立即关库。
        for (var stage = 0; stage < 4; stage++) {
          await _drainHomeIdentityReads(tester);
        }
        var closed = false;
        Object? closeError;
        unawaited(
          UserIsar.instance.resetForTest().then<void>(
            (_) {
              closed = true;
            },
            onError: (Object error) {
              closeError = error;
              closed = true;
            },
          ),
        );
        for (var attempt = 0; attempt < 200 && !closed; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(closed, isTrue, reason: '必须完成本用例隔离库关闭，不能污染下一用例');
        if (closeError != null) throw closeError!;
      }
    }

    testWidgets('已有CID且503仍显示原发布入口并进入文章编辑器，动态保持失败', (tester) async {
      await check(tester, () async {
        expect(find.byType(SquareHomePage), findsOneWidget);
        expect(find.text('公民服务暂时不可用，请稍后重试'), findsOneWidget);
        expect(find.byTooltip('发布'), findsOneWidget);
        expect(sessions.ensureCalls, greaterThan(0));
        expect(sessions.resolveCalls, 0);
        expect(sessions.registrationCalls, 0);
        await tester.tap(find.byTooltip('发布'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('square-publish-article')));
        await _drainHomeIdentityReads(tester);
        await tester.pumpAndSettle();
        expect(find.text('发文章'), findsOneWidget);
        expect(find.text('初始化本机聊天设备'), findsNothing);
        expect(find.text('尚未注册'), findsNothing);
        expect(sessions.registrationCalls, 0);
      });
    });
    for (final status in [
      CidBusinessStatus.unregistered,
      CidBusinessStatus.unavailable,
      CidBusinessStatus.noWallet,
    ]) {
      testWidgets('CID事实${status.name}不挂载广场或准备会话', (tester) async {
        gate.status = status;
        await check(tester, () async {
          expect(find.byType(SquareHomePage), findsNothing);
          expect(find.byTooltip('发布'), findsNothing);
          expect(sessions.ensureCalls, 0);
          expect(sessions.resolveCalls, 0);
          expect(sessions.registrationCalls, 0);
          expect(
            find.text('尚未注册'),
            status == CidBusinessStatus.unregistered
                ? findsOneWidget
                : findsNothing,
          );
          if (status == CidBusinessStatus.unavailable) {
            expect(find.text('暂时无法核实公民号身份，请重试'), findsOneWidget);
          }
        });
      });
    }
    testWidgets('CID事实改变后撤下旧广场，失败不冒充未注册', (tester) async {
      await check(tester, () async {
        expect(find.byType(SquareHomePage), findsOneWidget);
        gate.status = CidBusinessStatus.unavailable;
        gate.revision.value++;
        await tester.pumpAndSettle();
        expect(find.byType(SquareHomePage), findsNothing);
        expect(find.text('暂时无法核实公民号身份，请重试'), findsOneWidget);
        expect(find.text('尚未注册'), findsNothing);
        expect(find.byTooltip('发布'), findsNothing);
        expect(sessions.registrationCalls, 0);
      });
    });
  });
}
