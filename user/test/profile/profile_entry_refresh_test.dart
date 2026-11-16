import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/profile_header_card.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_testing/fake_profile.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../creator/creator_test_support.dart';

class _Sessions extends Fake implements SquareSessionProvider {
  _Sessions(this.binding);
  final IdentityBinding binding;
  int calls = 0;
  bool unavailable = false;
  @override
  Future<String?> currentCitizenId() async => binding.cidNumber;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    calls++;
    return SquareSessionResolution(
      unavailable
          ? SquareSessionStatus.networkUnavailable
          : SquareSessionStatus.ready,
      session: unavailable
          ? null
          : SquareSession(
              deviceId: testMlsDeviceId,
              sessionToken: 'profile-entry',
              cidNumber: binding.cidNumber,
              accountId: binding.accountId,
              bindRev: binding.bindRev,
              expiresAt: 9999999999999,
              authenticateRequest: fakeMlsRequestHeaders,
            ),
    );
  }
}

class _Api extends CitizenProfileApi {
  _Api(this.result, DateTime Function() now) : super(now: now);
  CitizenProfile result;
  int gets = 0;
  bool fail = false;
  Completer<CitizenProfile>? pending;
  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) async {
    gets++;
    if (fail)
      throw const SquareApiException('network failure', statusCode: 503);
    return pending == null ? result : await pending!.future;
  }

  @override
  Future<List<SquareLocalPost>> fetchLocalPublishedPosts(
    String cidNumber,
  ) async => [];
  @override
  Future<({List<SquarePost> posts, String? nextCursor})> fetchAuthorPosts(
    String cidNumber, {
    SquarePostCategory? category,
    SquarePostType? postType,
    int limit = 20,
    String? cursor,
    SquareSession? session,
  }) async => (posts: <SquarePost>[], nextCursor: null);
}

class _DelayedMedia extends CitizenProfileMediaCache {
  final first = Completer<CitizenProfileMediaSnapshot>();
  int reads = 0;
  @override
  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) =>
      ++reads == 1
      ? first.future
      : Future.value(
          const CitizenProfileMediaSnapshot(avatarPath: '/tmp/new-profile.png'),
        );
  @override
  Future<CitizenProfileMediaSnapshot> refresh({
    required CitizenProfile profile,
    required String? avatarUrl,
    required String? bannerUrl,
    required http.Client client,
  }) async => const CitizenProfileMediaSnapshot();
}

void main() {
  late int now;
  late IdentityBinding binding;
  late _Sessions sessions;
  late FakeProfileCache cache;
  late _Api api;
  late CreatorTestUser user;
  late CreatorTestSecurity security;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(now);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CitizenProfileApi.resetEntryRefreshMemory();
    now = 1000000;
    user = CreatorTestUser();
    security = CreatorTestSecurity();
    binding = IdentityBinding(
      genesisHash: f.hash(0),
      cidNumber: f.cidA,
      accountId: f.account(1),
      bindRev: 1,
    );
    sessions = _Sessions(binding);
    cache = FakeProfileCache(
      sampleProfile(
        cidNumber: f.cidA,
        displayName: '本地资料',
      ).copyWith(profileAt: 10),
    );
    api = _Api(
      sampleProfile(
        cidNumber: f.cidA,
        displayName: '云端资料',
      ).copyWith(profileAt: 11),
      clock,
    );
  });
  tearDown(() => security.revision.dispose());
  Future<ProfileEntryRefreshResult?> enter({
    _Api? client,
    IdentityBinding? owner,
    _Sessions? provider,
    bool Function()? current,
  }) => (client ?? api).refreshOnEntry(
    f.cidA,
    binding: owner ?? binding,
    sessions: provider ?? sessions,
    cache: cache,
    isCurrentIdentity: current,
  );
  Widget page({
    bool self = true,
    String? target,
    CitizenProfile? initial,
    CitizenProfileMediaCache? media,
  }) => MultiProvider(
    providers: [
      Provider<CurrentUserContext>.value(value: user),
      Provider<AccountSecurityService>.value(value: security),
    ],
    child: MaterialApp(
      home: UserProfilePage(
        key: UniqueKey(),
        cidNumber: target ?? f.cidA,
        isSelf: self,
        initialProfile: initial,
        mediaCache: media,
        api: api,
        cache: cache,
        sessionProvider: sessions,
      ),
    ),
  );

  test('10分钟内跨API实例只刷新一次，恰好到期才再次刷新', () async {
    await enter();
    final second = _Api(api.result, clock);
    now += 599999;
    expect(await enter(client: second), isNull);
    expect(sessions.calls, 1);
    expect(second.gets, 0);
    now++;
    await enter(client: second);
    expect(sessions.calls, 2);
    expect(second.gets, 1);
    expect(cache.seed!.displayName, '云端资料');
  });
  test('限速时间持久化，清除进程内任务后仍不重复刷新', () async {
    await enter();
    now += 300000;
    CitizenProfileApi.resetEntryRefreshMemory();
    final another = _Api(api.result, clock);
    expect(await enter(client: another), isNull);
    expect(another.gets, 0);
    expect(sessions.calls, 1);
    expect(
      (await SharedPreferences.getInstance()).getKeys().where(
        (v) => v.startsWith('profile.entry.'),
      ),
      hasLength(1),
    );
  });
  test('失败也占用十分钟窗口，不删除缓存，到期可恢复', () async {
    api.fail = true;
    await expectLater(enter(), throwsA(isA<SquareApiException>()));
    expect(cache.seed!.displayName, '本地资料');
    api.fail = false;
    now += 599999;
    expect(await enter(), isNull);
    expect(api.gets, 1);
    now++;
    await enter();
    expect(api.gets, 2);
    expect(cache.seed!.displayName, '云端资料');
  });
  test('会话失败前已记录窗口，反复进入不重新准备云端会话', () async {
    sessions.unavailable = true;
    await expectLater(enter(), throwsStateError);
    now += 1000;
    expect(await enter(), isNull);
    expect(sessions.calls, 1);
    expect(api.gets, 0);
  });
  test('相同主页相同身份并发进入共享一个任务', () async {
    api.pending = Completer<CitizenProfile>();
    final first = enter();
    final second = enter();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    api.pending!.complete(api.result);
    await Future.wait([first, second]);
    expect(api.gets, 1);
    expect(sessions.calls, 1);
  });
  test('云端无新版本或版本零保留本地，不重复写库', () async {
    api.result = cache.seed!;
    final same = await enter();
    expect(same!.profile.status, CitizenProfileLoadStatus.unchanged);
    expect(cache.wrote, isFalse);
    now += 600000;
    api.result = api.result.copyWith(profileAt: 0, displayName: '');
    final missing = await enter();
    expect(missing!.profile.status, CitizenProfileLoadStatus.remoteMissing);
    expect(missing.profile.profile.displayName, '本地资料');
    expect(cache.wrote, isFalse);
  });
  test('浏览者绑定不同独立刷新，旧身份迟到不回写', () async {
    api.pending = Completer<CitizenProfile>();
    var oldCurrent = true;
    final first = enter(current: () => oldCurrent);
    final rejected = expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    oldCurrent = false;
    final owner = IdentityBinding(
      genesisHash: f.hash(0),
      cidNumber: f.cidB,
      accountId: f.account(2),
      bindRev: 2,
    );
    final fresh = _Api(
      api.result.copyWith(displayName: '新身份结果', profileAt: 12),
      clock,
    );
    await enter(client: fresh, owner: owner, provider: _Sessions(owner));
    api.pending!.complete(api.result);
    await rejected;
    expect(cache.seed!.displayName, '新身份结果');
    expect(fresh.gets, 1);
  });
  testWidgets('本人首帧显示缓存，后台挂起不显示整页转圈，返回后只更新一次', (tester) async {
    api.pending = Completer<CitizenProfile>();
    await tester.pumpWidget(page(initial: cache.seed));
    expect(find.text('本地资料'), findsWidgets);
    expect(find.byType(ProfileHeaderCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    api.pending!.complete(api.result);
    await tester.pumpAndSettle();
    expect(find.text('云端资料'), findsWidgets);
    expect(cache.seed!.displayName, '云端资料');
    expect(api.gets, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('他人主页与本人一样先显示本地，请求失败保留资料', (tester) async {
    user.cidNumber = f.cidB;
    user.ownerAccountId = f.account(2);
    sessions = _Sessions(
      IdentityBinding(
        genesisHash: f.hash(0),
        cidNumber: f.cidB,
        accountId: f.account(2),
        bindRev: 1,
      ),
    );
    api.fail = true;
    await tester.pumpWidget(page(self: false, initial: cache.seed));
    expect(find.text('本地资料'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('本地资料'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(api.gets, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page(self: false, initial: cache.seed));
    await tester.pumpAndSettle();
    expect(api.gets, 1);
    expect(sessions.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('重新进入不足十分钟不准备会话，也不重复读取云端资料', (tester) async {
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    now += 599999;
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pumpAndSettle();
    expect(api.gets, 1);
    expect(sessions.calls, 1);
    expect(find.text('云端资料'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    now++;
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pumpAndSettle();
    expect(api.gets, 2);
    expect(sessions.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('首个页面退出不取消同身份另一个页面的共享刷新', (tester) async {
    api.pending = Completer<CitizenProfile>();
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pumpAndSettle();
    api.pending!.complete(api.result);
    await tester.pumpAndSettle();
    expect(api.gets, 1);
    expect(find.text('云端资料'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('旧图片缓存读取迟到不能覆盖本次已更新图片', (tester) async {
    cache.seed = cache.seed!.copyWith(
      avatarKey: 'i/${f.cidA}/avatar/${'a' * 64}',
    );
    api.result = cache.seed!;
    final media = _DelayedMedia();
    await tester.pumpWidget(page(initial: cache.seed, media: media));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProfileHeaderCard>(find.byType(ProfileHeaderCard))
          .avatarPath,
      '/tmp/new-profile.png',
    );
    media.first.complete(
      const CitizenProfileMediaSnapshot(avatarPath: '/tmp/old-profile.png'),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProfileHeaderCard>(find.byType(ProfileHeaderCard))
          .avatarPath,
      '/tmp/new-profile.png',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
