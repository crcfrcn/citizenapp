import 'mls_authentication_fixture.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:citizenapp/8964/feed/square_post_detail_page.dart';
import 'package:citizenapp/8964/feed/square_post_card.dart';

import '../support/fake_citizen_sdk.dart';
import '../support/isar_test_env.dart';

import 'package:citizenapp/account/identity/account_security_service.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/identity_badge_snapshot_store.dart';
import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/8964/compose/compose_page.dart';
import 'package:citizenapp/8964/compose/document_compose_body.dart';
import 'package:citizenapp/8964/compose/compose_draft.dart';
import 'package:citizenapp/8964/compose/compose_draft_store.dart';
import 'package:citizenapp/8964/compose/video_compose_body.dart';
import 'package:citizenapp/8964/compose/compose_media_widgets.dart';
import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/8964/feed/square_home_page.dart';
import 'package:citizenapp/account/profile/citizen_profile.dart';
import 'package:citizenapp/account/profile/citizen_profile_cache.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/account/profile/profile_avatar.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/square_identity_state.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/cid_business_gate.dart';
import 'package:citizenapp/account/membership/membership_revision.dart';
import 'package:citizenapp/system/theme/app_layout.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/account/identity/identity_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizenapp/storage/user_isar.dart';

import 'profile/fake_profile.dart';

/// 身份账户缓存 fake:resolve 返回 null,让 loadCurrent 回退 wallet.accountId
/// 使用测试默认账户快照，避免 instance 访问真实本地钱包/Isar。
class _NullIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => null;
  @override
  Future<String?> accountId() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWallet implements CitizenSdkWallet {
  _FakeWallet(this.wallet);

  final CitizenWalletStateAccount? wallet;

  @override
  CitizenSdkOperation<CitizenWalletState> getState() => testCitizenOperation(
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    SquareIdentityService(
      wallet: _FakeWallet(_registeredWallet),
      currentUserContext: _NullIdentityCache(),
      badgeSnapshotStore: snapshots ?? _LocalSnapshots(),
      profileCache: FakeProfileCache(),
    );

SquareIdentityService _emptyIdentityService() => SquareIdentityService(
  wallet: _FakeWallet(null),
  currentUserContext: _NullIdentityCache(),
  badgeSnapshotStore: _LocalSnapshots(),
);

SquareIdentityService _unregisteredIdentityService() => SquareIdentityService(
  wallet: _FakeWallet(_registeredWallet),
  currentUserContext: _UnregisteredIdentityCache(),
  badgeSnapshotStore: _LocalSnapshots(),
);

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
      identityLevel: 'visitor',
      updatedAtMillis: 1,
      accountId: accountId,
      verified: true,
      // 正向发布夹具提供完整已注册事实；默认仍是明确未注册，不更改反向用例。
      identity: registered
          ? CitizenIdentityChainSnapshot(
              cidNumber: testMlsCidNumber,
              accountId: Uint8List.fromList(List<int>.filled(32, 0xaa)),
              bindingRevision: 1,
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
      identityLevel: 'voting',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedComposeIdentityService implements SquareIdentityService {
  final Completer<SquareIdentityState> completer =
      Completer<SquareIdentityState>();

  @override
  Future<SquareIdentityState> loadCurrent() => completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      bindingRevision: 1,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Worker 真源判定:登录挑战对未绑定账户回 403 cid_not_bound。
class _CidNotBoundSessionProvider implements SquareSessionProvider {
  _CidNotBoundSessionProvider({this.errorCode = 'cid_not_bound'});
  final String errorCode;
  @override
  Future<SquareSession?> ensureSession() async {
    throw SquareApiException(
      '当前身份不可用',
      statusCode: 403,
      errorCode: errorCode,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      identityLevel: 'voting',
    ),
    postCategory: SquarePostCategory.normal,
    postType: postType,
    text: text,
    title: title,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

void main() {
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
        bindingRevision: 1,
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
              avatarObjectKey: 'profile/$testMlsCidNumber/avatar',
            ),
            postCategory: SquarePostCategory.normal,
            postType: type,
            text: '合成正文',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          SquareHomePage(
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
    late TestCitizenSdkTransport transport;
    late CitizenSdk sdk;
    late AccountSecurityService security;
    late _QueuedHomeCurrentUser current;
    late CurrentUser registered;
    late _RecordingFeedSource feed;
    late int badgeRevision;
    var walletReads = 0;
    var walletPresent = true;

    setUp(() async {
      badgeRevision = IdentityBadgeSnapshotStore.revision.value;
      walletPresent = true;
      transport = TestCitizenSdkTransport({
        'getWalletState': (_) {
          walletReads++;
          return [
            walletPresent
                ? testCitizenWalletState()
                : <Object?>[
                    '2',
                    null,
                    <Object?>[],
                    0,
                    false,
                    null,
                    <Object?>[],
                  ],
          ];
        },
      });
      sdk = await transport.open();
      final account = (await sdk.wallet.getState().result).defaultAccount!;
      walletReads = 0;
      current = _QueuedHomeCurrentUser();
      feed = _RecordingFeedSource();
      security = AccountSecurityService(
        wallet: sdk.wallet,
        signing: sdk.signing,
        mlsDeviceRegistrar: ({
          required cidNumber,
          required bindingRevision,
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
          bindingRevision: 1,
        ),
      );
      // 页面挂载前写合成完整快照；只使用本组独占Isar，不读取设备钱包或金库。
      await IdentityBadgeSnapshotStore().writeVerified(
        accountId: account.accountId,
        identity: CitizenIdentityChainSnapshot(
          cidNumber: testMlsCidNumber,
          accountId: Uint8List.fromList(List<int>.filled(32, 1)),
          bindingRevision: 1,
          votingIdentity: null,
        ),
        isCurrent: () => true,
      );
    });

    tearDown(() async {
      security.dispose();
      await sdk.close();
      await transport.dispose();
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
      child: _wrap(SquareHomePage(feedSource: feed)),
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
      _wrap(SquareHomePage(identityService: identity, feedSource: feed)),
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
        _wrap(SquareHomePage(identityService: identity, feedSource: feed)),
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
      _wrap(SquareHomePage(identityService: identity, feedSource: feed)),
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
      'assets/icons/square-person-tank-watermark.png',
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
      durationSeconds: 10,
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
        updatedAtMillis: 1,
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
        updatedAtMillis: 1,
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
    expect(find.text('本机设备授权尚未完成，请稍后重试'), findsOneWidget);
    expect(find.text('注册'), findsNothing);
  });

  testWidgets('已核实未注册显示统一注册引导', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SquareHomePage(
          identityService: _unregisteredIdentityService(),
          feedSource: _FakeSquareApiClient(),
          sessionProvider: _CidNotBoundSessionProvider(errorCode: 'identity_unregistered'),
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
