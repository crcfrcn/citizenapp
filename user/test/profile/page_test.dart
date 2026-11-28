// 验证主页、头像、菜单、用户码和刷新行为。

import 'package:citizen_user/profile/data.dart' show CitizenProfile, CitizenProfileApi, CitizenProfileCache, CitizenProfileLoadResult, CitizenProfileLoadStatus, CitizenProfileMediaCache, CitizenProfileMediaSnapshot, ProfileEntryRefreshResult, ProfilePresentation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_user/api.dart' show SquareApiClient, SquareApiException, SquareMembershipState, SquareSession;
import 'dart:async';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_user/profile/page.dart' show CollapsibleHeader, ProfileActionIcons, ProfileAvatar, ProfileCategoryTabs, ProfileHeaderCard, ProfileKebabMenu, ProfileTab, UserProfilePage, UserQrPage;
import 'package:flutter/foundation.dart';
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus, SquareSessionStatusText;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/membership/service.dart' show MembershipDisplayDecision, MembershipRevision, SubscriptionService;
import 'package:citizen_system/theme.dart';
import 'package:citizen_testing/profile.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:citizen_user/identity/badge.dart' show IdentityBadge;
import 'package:citizen_user/context.dart' show CurrentUserContext, IdentityBinding;
import 'package:citizen_square/post/store.dart';
import 'package:citizen_testing/chain.dart' as f;
import 'package:citizen_testing/chat/authentication.dart';
import '../fixtures.dart' show CreatorTestSecurity, CreatorTestUser;
import 'package:citizen_chain/service.dart';
import 'package:citizen_scanner/display.dart' show AppQrImage;
import 'package:citizen_square/post/card.dart';
import 'dart:convert';

void main() {
  group('profile_header_test', suite105);
  group('user_profile_page_test', suite109);
  group('profile_entry_refresh_test', suite104);
  group('profile_avatar_chain_test', suite102);
  group('profile_kebab_menu_test', suite106);
  group('user_qr_page_test', suite110);
  group('square_post_card_author_test', suite108);
  group('identity_cid_display_test', suite100);
}

// 验证统一主页权限检查、明确拒绝提示及身份变化和读取故障处理。

/// 身份账户缓存 fake：resolve/account_id 返回 null，让 _resolveOwnAccount 回退成
/// 「非本人」（行为与迁移前一致）；避免 instance 触发真链读/真 Isar。
class _NullMembershipSnapshotService implements SubscriptionService {
  @override
  Future<void> requireProfileAccess(
    SquareSession session,
    String targetCid,
  ) async {}
  @override
  Future<void> requireSquareAccess(SquareSession session) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap({required bool isSelf, CitizenProfile? localProfile}) =>
    MaterialApp(
      home: UserProfilePage(
        cidNumber: sampleProfile().cidNumber!,
        isSelf: isSelf,
        api: FakeProfileApi(localProfile ?? sampleProfile()),
        cache: FakeProfileCache(localProfile ?? sampleProfile()),
        sessionProvider: FakeSessionProvider(
          fakeSession(cidNumber: isSelf ? sampleProfile().cidNumber : null),
          citizenId: isSelf ? sampleProfile().cidNumber : null,
        ),
        subscriptionService: _NullMembershipSnapshotService(),
      ),
    );

class _SecurityRevision extends Fake implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
}

class _PendingRefreshSession extends FakeSessionProvider {
  _PendingRefreshSession()
    : super(fakeSession(), citizenId: sampleProfile().cidNumber);
  final completion = Completer<SquareSessionResolution>();
  int calls = 0;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) {
    if (!refresh) return super.resolveSession();
    calls++;
    return completion.future;
  }
}

class _UnavailableSession extends FakeSessionProvider {
  _UnavailableSession(this.status)
    : super(null, citizenId: fakeSession().cidNumber);
  final SquareSessionStatus status;
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async => SquareSessionResolution(status);
}

class _DeniedMembership extends _NullMembershipSnapshotService {
  int checks = 0;
  @override
  Future<void> requireProfileAccess(
    SquareSession session,
    String targetCid,
  ) async {
    checks++;
    throw const SquareApiException(
      '非会员禁止访问用户主页',
      statusCode: 403,
      errorCode: 'profile_membergate_required',
    );
  }
}

// 拒绝来自真实业务端口；普通页面不得先请求会员状态。
class _ServerDeniedProfile extends FakeProfileApi {
  _ServerDeniedProfile() : super(sampleProfile());
  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) async {
    calls++;
    throw const SquareApiException(
      '非会员禁止访问用户主页',
      statusCode: 403,
      errorCode: 'profile_membergate_required',
    );
  }
}

class _PendingProfile extends FakeProfileApi {
  _PendingProfile() : super(sampleProfile());
  final resultFuture = Completer<CitizenProfile>();
  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) {
    calls++;
    return resultFuture.future;
  }
}

class _RetryProfile extends FakeProfileApi {
  _RetryProfile(super.result, {this.denyRefresh = false, this.blockRefresh = false});
  final bool denyRefresh;
  final bool blockRefresh;
  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) async {
    calls++;
    if (blockRefresh && calls > 1) {
      throw const SquareApiException('blocked', statusCode: 404, errorCode: 'user_not_found');
    }
    if ((!denyRefresh && !blockRefresh && calls == 1) || (denyRefresh && calls > 1)) {
      throw SquareApiException(
        'fixture failure',
        statusCode: denyRefresh ? 403 : 503,
        errorCode: denyRefresh
            ? 'profile_membergate_required'
            : 'network_unavailable',
      );
    }
    return result;
  }
}

class _UnsavedProfile extends FakeProfileApi {
  _UnsavedProfile(super.result);
  @override
  Future<CitizenProfileLoadResult> loadProfile(
    String cidNumber, {
    required SquareSession session,
    CitizenProfileCache? cache,
    CitizenProfileMediaCache? mediaCache,
    bool Function()? isCurrent,
    bool refreshMedia = false,
  }) async {
    final profile = await fetchProfile(cidNumber, session: session);
    return CitizenProfileLoadResult(
      profile,
      CitizenProfileLoadStatus.saveFailed,
    );
  }
}

class _NonMemberProfileService extends _NullMembershipSnapshotService {
  @override
  Future<void> requireSquareAccess(SquareSession session) async {
    throw const SquareApiException(
      'fixture nonmember',
      errorCode: 'square_membergate_required',
    );
  }
}

CitizenProfile _missingProfile() => CitizenProfile.fromJson({
  ...sampleProfile().toJson(),
  'display_name': '',
  'profile_bio': '',
  'avatar_key': null,
  'banner_key': null,
  'profile_at': 0,
  'is_following': false,
  'is_followed_by': true,
  'is_notifying': false,
  'counts': {
    'following': 0,
    'followers': 0,
    'mutual_following': 0,
    'posts': 0,
    'campaigns': 0,
    'videos': 0,
    'articles': 0,
  },
});

class _UnfollowProfile extends FakeProfileApi {
  _UnfollowProfile({this.denyHome = false})
    : super(sampleProfile(following: true, followedBy: true));
  final bool denyHome;
  bool unfollowed = false;
  @override
  Future<void> unfollowUser({
    required SquareSession session,
    required String peerCid,
  }) async {
    unfollowCalls++;
    unfollowed = true;
  }

  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) async {
    if (unfollowed) throw const SquareApiException('network', statusCode: 503);
    return result;
  }

  @override
  Future<({List<SquarePost> posts, String? nextCursor})> fetchAuthorPosts(
    String cidNumber, {
    SquarePostCategory? category,
    SquarePostType? postType,
    int limit = 20,
    String? cursor,
    SquareSession? session,
  }) async {
    authorPostCalls++;
    if (unfollowed && denyHome) {
      throw const SquareApiException(
        'private',
        statusCode: 403,
        errorCode: 'profile_mutual_required',
      );
    }
    return (
      posts: unfollowed
          ? <SquarePost>[]
          : [
              SquarePost(
                postId: 'circle-unfollow',
                author: samplePost().author,
                postCategory: SquarePostCategory.normal,
                postType: SquarePostType.document,
                postVisibility: SquarePostVisibility.circle,
                text: '取关前的圈内正文',
                publishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
              ),
            ],
      nextCursor: null,
    );
  }
}

void suite109() {
  for (final denyHome in [false, true]) {
    testWidgets('取关成功资料503立即失效旧列表，主页拒绝=$denyHome', (tester) async {
      final api = _UnfollowProfile(denyHome: denyHome);
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: api.result.cidNumber!,
            isSelf: false,
            api: api,
            cache: FakeProfileCache(api.result),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NullMembershipSnapshotService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('取关前的圈内正文'), findsOneWidget);
      final before = api.authorPostCalls;
      final actions = tester.widget<ProfileActionIcons>(
        find.byType(ProfileActionIcons),
      );
      expect(actions.enabled, isTrue);
      expect(actions.isFollowing, isTrue);
      actions.onToggleFollow!();
      await tester.pumpAndSettle();
      expect(api.unfollowCalls, 1);
      expect(api.authorPostCalls, before + 1);
      expect(find.text('取关前的圈内正文'), findsNothing);
      if (denyHome) {
        expect(find.text('用户尚未开放主页访问，请稍后重试。'), findsWidgets);
        expect(find.byType(ProfileHeaderCard), findsNothing);
      } else {
        expect(find.byType(ProfileHeaderCard), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('统一主页入口只检查一次，重新进入重新检查', (tester) async {
    final api = FakeProfileApi(sampleProfile());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => UserProfilePage.open(
                context,
                UserProfilePage(
                  cidNumber: api.result.cidNumber!,
                  isSelf: false,
                  api: api,
                  cache: FakeProfileCache(api.result),
                  sessionProvider: FakeSessionProvider(fakeSession()),
                  subscriptionService: _NullMembershipSnapshotService(),
                ),
              ),
              child: const Text('打开主页'),
            ),
          ),
        ),
      ),
    );
    for (var count = 1; count <= 2; count++) {
      await tester.tap(find.text('打开主页'));
      await tester.pumpAndSettle();
      expect(api.accessCalls, count);
      expect(find.byType(ProfileHeaderCard), findsOneWidget);
      Navigator.of(tester.element(find.byType(UserProfilePage))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('他人主页权限未返回时不展示注入或磁盘缓存', (tester) async {
    final api = FakeProfileApi(sampleProfile())
      ..accessPending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: false,
          initialProfile: sampleProfile(displayName: '受保护的缓存'),
          api: api,
          cache: FakeProfileCache(sampleProfile(displayName: '受保护的缓存')),
          sessionProvider: FakeSessionProvider(fakeSession()),
          subscriptionService: _NullMembershipSnapshotService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.accessCalls, 1);
    expect(api.calls, 0);
    expect(find.text('受保护的缓存'), findsNothing);
    api.accessPending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileHeaderCard), findsOneWidget);
  });

  testWidgets('主页仅自己可见时不展示缓存且显示准确拒绝文案', (tester) async {
    final api = FakeProfileApi(sampleProfile())
      ..accessError = const SquareApiException(
        'private',
        statusCode: 403,
        errorCode: 'profile_private',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: false,
          initialProfile: sampleProfile(displayName: '不能泄露的缓存'),
          api: api,
          cache: FakeProfileCache(sampleProfile(displayName: '不能泄露的缓存')),
          sessionProvider: FakeSessionProvider(fakeSession()),
          subscriptionService: _NullMembershipSnapshotService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('不能泄露的缓存'), findsNothing);
    expect(find.text('用户尚未开放主页访问，请稍后重试。'), findsWidgets);
    expect(api.calls, 0);
  });

  testWidgets('统一主页入口明确拒绝时提示两秒自动消失且没有确认弹窗', (tester) async {
    final api = FakeProfileApi(sampleProfile())
      ..accessError = const SquareApiException(
        'private',
        statusCode: 403,
        errorCode: 'profile_private',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => UserProfilePage.open(
                context,
                UserProfilePage(
                  cidNumber: sampleProfile().cidNumber!,
                  isSelf: false,
                  api: api,
                  sessionProvider: FakeSessionProvider(fakeSession()),
                ),
              ),
              child: const Text('主页入口'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('主页入口'));
    await tester.pumpAndSettle();
    expect(find.byType(UserProfilePage), findsNothing);
    expect(find.text('用户尚未开放主页访问，请稍后重试。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('确定'), findsNothing);
    expect(api.accessCalls, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
  for (final code in ['profile_followers_required', 'profile_mutual_required']) {
    testWidgets('$code使用同一自动消失提示', (tester) async {
      final api = FakeProfileApi(sampleProfile())
        ..accessError = SquareApiException('fixture', statusCode: 403, errorCode: code);
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
        Scaffold(body: TextButton(onPressed: () => UserProfilePage.open(context,
          UserProfilePage(cidNumber: api.result.cidNumber!, isSelf: false,
            api: api, sessionProvider: FakeSessionProvider(fakeSession()))),
          child: const Text('主页入口'))))));
      await tester.tap(find.text('主页入口'));
      await tester.pumpAndSettle();
      expect(find.text('用户尚未开放主页访问，请稍后重试。'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  }
  for (final identityChanged in [true, false]) {
    testWidgets('旧主页权限拒绝不提示到新${identityChanged ? '身份' : '路由'}', (tester) async {
      final security = _SecurityRevision();
      addTearDown(security.revision.dispose);
      final api = FakeProfileApi(sampleProfile())..accessPending = Completer<void>();
      await tester.pumpWidget(Provider<AccountSecurityService?>.value(value: security,
        child: MaterialApp(home: Builder(builder: (context) => Scaffold(
          body: TextButton(onPressed: () => UserProfilePage.open(context,
            UserProfilePage(cidNumber: api.result.cidNumber!, isSelf: false,
              api: api, sessionProvider: FakeSessionProvider(fakeSession()))),
            child: const Text('主页入口')))))));
      await tester.tap(find.text('主页入口'));
      await tester.pump();
      if (identityChanged) {
        security.revision.value++;
      } else {
        Navigator.of(tester.element(find.text('主页入口'))).push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('其他页面'))));
        await tester.pumpAndSettle();
      }
      api.accessPending!.completeError(const SquareApiException('fixture',
        statusCode: 403, errorCode: 'profile_private'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(UserProfilePage), findsNothing);
    });
  }
  final entryFailures = <Object>[
    const SquareApiException('fixture', statusCode: 503),
    const SquareApiException('fixture', statusCode: 401, errorCode: 'invalid_session'),
    const SquareApiException('fixture', statusCode: 403, errorCode: 'unknown_forbidden'),
    const SquareApiException('fixture', statusCode: 404, errorCode: 'user_not_found'),
    const SquareApiException('fixture', statusCode: 503, errorCode: 'profile_private'),
    const FormatException('fixture'), TimeoutException('fixture'), StateError('fixture'),
  ];
  for (var index = 0; index < entryFailures.length; index++) {
    testWidgets('非明确权限拒绝$index不弹窗也不放行缓存', (tester) async {
      final api = FakeProfileApi(sampleProfile())..accessError = entryFailures[index];
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
        Scaffold(body: TextButton(onPressed: () => UserProfilePage.open(context,
          UserProfilePage(cidNumber: api.result.cidNumber!, isSelf: false,
            initialProfile: sampleProfile(displayName: '未获准的缓存'),
            api: api, sessionProvider: FakeSessionProvider(fakeSession()))),
          child: const Text('主页入口'))))));
      await tester.tap(find.text('主页入口'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(UserProfilePage), findsNothing);
      expect(find.text('未获准的缓存'), findsNothing);
      expect(api.accessCalls, 1);
    });
  }
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CitizenProfileApi.resetEntryRefreshMemory();
  });
  testWidgets('本人缓存的零计数完整显示且保留自关注入口', (tester) async {
    final old = sampleProfile();
    final profile = CitizenProfile.fromJson({
      ...old.toJson(),
      'counts': {
        ...(old.toJson()['counts'] as Map<String, dynamic>),
        'following': 0,
        'followers': 0,
        'mutual_following': 0,
      },
    });
    await tester.pumpWidget(_wrap(isSelf: true, localProfile: profile));
    await tester.pumpAndSettle();
    for (final label in ['0 关注', '0 关注者', '0 互关']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
  });

  testWidgets('他人主页先显示缓存，服务端拒绝后保留展示且不前置会员GET', (tester) async {
    final api = _ServerDeniedProfile();
    final denied = _DeniedMembership();
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: true,
          initialProfile: sampleProfile(displayName: '应保留的缓存'),
          api: api,
          cache: FakeProfileCache(sampleProfile(displayName: '应保留的缓存')),
          sessionProvider: FakeSessionProvider(fakeSession()),
          subscriptionService: denied,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('非会员禁止访问用户主页'), findsNothing);
    expect(find.text('应保留的缓存'), findsWidgets);
    expect(api.calls, 1);
    expect(denied.checks, 0);
  });
  testWidgets('他人业务请求挂起仍显示旧缓存，失败也不补会员GET', (tester) async {
    final api = _PendingProfile(), service = _DeniedMembership();
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: false,
          initialProfile: sampleProfile(displayName: '旧缓存直接显示'),
          api: api,
          cache: FakeProfileCache(sampleProfile(displayName: '旧缓存直接显示')),
          sessionProvider: FakeSessionProvider(fakeSession()),
          subscriptionService: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.calls, 1);
    expect(service.checks, 0);
    expect(find.text('旧缓存直接显示'), findsWidgets);
    api.resultFuture.completeError(
      const SquareApiException(
        'denied',
        statusCode: 403,
        errorCode: 'profile_membergate_required',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('非会员禁止访问用户主页'), findsNothing);
    expect(service.checks, 0);
  });

  testWidgets('非会员本人离线主页不调用会员门禁并保留本地资料', (tester) async {
    final denied = _DeniedMembership();
    final api = FakeProfileApi(sampleProfile());
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: true,
          api: api,
          cache: FakeProfileCache(sampleProfile(displayName: '本人离线资料')),
          sessionProvider: FakeSessionProvider(
            null,
            citizenId: sampleProfile().cidNumber,
          ),
          subscriptionService: denied,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本人离线资料'), findsWidgets);
    expect(denied.checks, 0);
    expect(api.calls, 0);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    void prepareView(WidgetTester tester) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('${platform.name}非空联系人遇远端版本0正常打开且关系取本次响应', (tester) async {
      prepareView(tester);
      final local = sampleProfile(
        displayName: 'Rhett本机资料',
        following: true,
        notifying: true,
      ).copyWith(profileAt: 1793472841955);
      final cache = FakeProfileCache(local);
      final api = FakeProfileApi(_missingProfile());
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: local.cidNumber!,
            isSelf: false,
            initialProfile: local,
            api: api,
            cache: cache,
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NonMemberProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rhett本机资料'), findsWidgets);
      expect(find.byType(ProfileCategoryTabs), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-error-refresh')), findsNothing);
      final header = tester.widget<ProfileHeaderCard>(
        find.byType(ProfileHeaderCard),
      );
      expect(header.profile!.isFollowing, isFalse);
      expect(header.profile!.isFollowedBy, isTrue);
      expect(header.profile!.isNotifying, isFalse);
      expect(cache.seed, same(local));
      expect(cache.wrote, isFalse);
      expect(api.calls, 1);
      expect(find.text('云端暂无资料，已保留本机资料'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}本人下拉遇云端缺失静默保留非空资料', (tester) async {
      prepareView(tester);
      final local = sampleProfile(
        displayName: '本人保存资料',
      ).copyWith(profileAt: 200);
      final cache = FakeProfileCache(local);
      final api = FakeProfileApi(_missingProfile());
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: local.cidNumber!,
            isSelf: true,
            api: api,
            cache: cache,
            sessionProvider: FakeSessionProvider(
              fakeSession(cidNumber: local.cidNumber),
            ),
            subscriptionService: _NonMemberProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      await tester.drag(find.text('暂无公文内容，请在广场发布'), const Offset(0, 380));
      await tester.pumpAndSettle();
      expect(api.calls, 2);
      expect(find.text('本人保存资料'), findsWidgets);
      expect(find.text('云端暂无资料，已保留本机资料'), findsNothing);
      expect(find.text('刷新完成'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(cache.seed, same(local));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}主页本地结构保留下拉重试原接口且不额外请求会员', (tester) async {
      prepareView(tester);
      final api = _RetryProfile(sampleProfile());
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: sampleProfile().cidNumber!,
            isSelf: false,
            api: api,
            cache: FakeProfileCache(),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NonMemberProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-error-refresh')), findsNothing);
      expect(api.calls, 1);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 380));
      await tester.pumpAndSettle();
      expect(api.calls, 2);
      expect(find.byType(ProfileCategoryTabs), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-error-refresh')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}刷新被服务端拒绝后仍保留已有资料', (tester) async {
      prepareView(tester);
      final api = _RetryProfile(
        sampleProfile(displayName: '此前已展示资料'),
        denyRefresh: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: api.result.cidNumber!,
            isSelf: false,
            api: api,
            cache: FakeProfileCache(),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NonMemberProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('此前已展示资料'), findsWidgets);
      await tester.drag(find.text('暂无公文内容，请在广场发布'), const Offset(0, 380));
      await tester.pumpAndSettle();
      expect(api.calls, 2);
      expect(find.text('此前已展示资料'), findsWidgets);
      expect(find.byKey(const ValueKey('profile-error-refresh')), findsNothing);
      expect(find.text('非会员禁止访问用户主页'), findsWidgets);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}拉黑拒绝会收起已经打开的主页', (tester) async {
      prepareView(tester);
      final api = _RetryProfile(sampleProfile(displayName: '旧主页资料'), blockRefresh: true);
      await tester.pumpWidget(MaterialApp(home: UserProfilePage(
        cidNumber: api.result.cidNumber!,
        isSelf: false,
        api: api,
        cache: FakeProfileCache(),
        sessionProvider: FakeSessionProvider(fakeSession()),
        subscriptionService: _NonMemberProfileService(),
      )));
      await tester.pumpAndSettle();
      expect(find.text('旧主页资料'), findsWidgets);
      await tester.drag(find.text('暂无公文内容，请在广场发布'), const Offset(0, 380));
      await tester.pumpAndSettle();
      expect(find.text('旧主页资料'), findsNothing);
      expect(find.text('用户主页暂不可用'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}本机保存失败仍展示已获准资料且不误报访问拒绝', (tester) async {
      prepareView(tester);
      final api = _UnsavedProfile(sampleProfile(displayName: '已获准远端资料'));
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: api.result.cidNumber!,
            isSelf: false,
            api: api,
            cache: FakeProfileCache(),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NonMemberProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已获准远端资料'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('profile-error-refresh')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('${platform.name}空内容下拉显示完整进度，服务失败仍重读本地', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeProfileApi(sampleProfile());
      final provider = _PendingRefreshSession();
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: sampleProfile().cidNumber!,
            isSelf: true,
            api: api,
            cache: FakeProfileCache(sampleProfile()),
            sessionProvider: provider,
            subscriptionService: _NullMembershipSnapshotService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = api.localPostCalls;
      await tester.drag(find.text('暂无公文内容，请在广场发布'), const Offset(0, 380));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(provider.calls, 1);
      expect(
        find.byKey(const ValueKey('profile-refresh-progress')),
        findsOneWidget,
      );
      expect(api.localPostCalls, greaterThan(before));
      provider.completion.complete(
        const SquareSessionResolution(SquareSessionStatus.networkUnavailable),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-refresh-progress')),
        findsNothing,
      );
      expect(find.text('内容加载失败，请下拉刷新'), findsAtLeastNWidgets(1));
      expect(find.text('需要钱包账户才能浏览关注列表'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final status in [
    SquareSessionStatus.noWallet,
    SquareSessionStatus.networkUnavailable,
    SquareSessionStatus.identityUnavailable,
    SquareSessionStatus.deviceUnavailable,
  ]) {
    testWidgets('关注列表保留真实会话状态：${status.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfilePage(
            cidNumber: fakeSession().cidNumber,
            isSelf: true,
            api: FakeProfileApi(sampleProfile()),
            cache: FakeProfileCache(sampleProfile()),
            sessionProvider: _UnavailableSession(status),
            subscriptionService: _NullMembershipSnapshotService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(' 关注').first);
      await tester.pumpAndSettle();
      if (status == SquareSessionStatus.noWallet) {
        expect(find.text('需要钱包账户才能浏览关注列表'), findsOneWidget);
      } else {
        expect(find.text(status.message), findsWidgets);
        expect(find.text('需要钱包账户才能浏览关注列表'), findsNothing);
      }
    });
  }

  testWidgets('renders 4 counted category tabs without a photo tab', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(isSelf: true));
    await tester.pumpAndSettle();

    for (final tab in ['posts', 'campaign', 'videos', 'articles']) {
      expect(find.byKey(ValueKey<String>('profile-tab-$tab')), findsOneWidget);
    }
    expect(find.textContaining('照片'), findsNothing);
    expect(find.text('公文{36}'), findsOneWidget);
    expect(find.text('帖子{36}'), findsNothing);
    expect(find.text('竞选{6}'), findsOneWidget);
    expect(find.text('视频{4}'), findsOneWidget);
    expect(find.text('文章{12}'), findsOneWidget);
    // 当前资料页统一使用细体左箭头返回，测试与已确认的正式 UI 保持一致。
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('暂无公文内容，请在广场发布'), findsOneWidget);
    expect(find.text('还没有帖子'), findsNothing);
    expect(ProfileCategoryTabs.height, 36);
    expect(ProfileCategoryTabs.labelTopPadding, 8);

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.backgroundColor, AppTheme.primaryDark);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.forceMaterialTransparency, isFalse);
    // 背景必须由折叠头部明确绘制，不能再把透明 Material 当作真实背景。
    expect(find.byType(FlexibleSpaceBar), findsNothing);
    final header = tester.widget<CollapsibleHeader>(
      find.byType(CollapsibleHeader),
    );
    expect(header.banner, isNotNull);
    expect(header.collapsedBanner, isNotNull);
    expect(header.bottomHeight, ProfileCategoryTabs.height);

    final collapsedBackground = find.byKey(
      const ValueKey('profile-collapsed-background-opacity'),
    );
    expect(
      tester.widget<Opacity>(collapsedBackground).opacity,
      closeTo(0, 0.001),
    );
    expect(
      find.descendant(of: collapsedBackground, matching: find.byType(Image)),
      findsOneWidget,
    );

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Opacity>(collapsedBackground).opacity,
      closeTo(1, 0.001),
    );
  });

  testWidgets('switching category shows the matching tab body', (tester) async {
    await tester.pumpWidget(_wrap(isSelf: true));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('profile-tab-campaign')),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无竞选内容，请在广场发布'), findsOneWidget);
  });

  testWidgets('builds another user profile without exceptions', (tester) async {
    await tester.pumpWidget(_wrap(isSelf: false));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfilePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('会员镜像确认后只刷新同一公民号的已挂载主页', (tester) async {
    final api = FakeProfileApi(sampleProfile());
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfilePage(
          cidNumber: sampleProfile().cidNumber!,
          isSelf: true,
          api: api,
          cache: FakeProfileCache(sampleProfile()),
          sessionProvider: FakeSessionProvider(
            fakeSession(),
            citizenId: sampleProfile().cidNumber,
          ),
          subscriptionService: _NullMembershipSnapshotService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, 0);

    MembershipRevision.instance.notifyChanged('OTHER-CID');
    await tester.pumpAndSettle();
    expect(api.calls, 0);

    MembershipRevision.instance.notifyChanged(sampleProfile().cidNumber!);
    await tester.pumpAndSettle();
    expect(api.calls, 0);
  });
}

// 验证主页资料、关系统计、徽章及大字体和窄屏布局。

late TestCitizenSdkHarness _sdkHarness;

const String _profileCidNumber = 'CN001-CTZN-000000001-2026';

/// 身份账户缓存 fake：resolve/account_id 返回 null，让 _resolveOwnAccount 回退成
/// 「非本人」（行为与迁移前一致）；避免 instance 触发真链读/真 Isar。
class _HeaderEmptyMembership implements SubscriptionService {
  @override
  Future<void> requireProfileAccess(
    SquareSession session,
    String targetCid,
  ) async {}
  @override
  Future<void> requireSquareAccess(SquareSession session) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _headerWrap({
  required bool isSelf,
  required CitizenProfileApi api,
  CitizenProfileCache? cache,
  SquareSessionProvider? sessionProvider,
  TargetPlatform platform = TargetPlatform.android,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  MembershipDisplayDecision initialMembershipDecision =
      MembershipDisplayDecision.inactiveConfirmed,
  SquareMembershipState? initialMembershipState,
  SubscriptionService? subscriptionService,
}) {
  return Provider<CitizenSdk>.value(
    value: _sdkHarness.sdk,
    child: MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: textScaler, padding: padding),
        child: child!,
      ),
      home: UserProfilePage(
        cidNumber: _profileCidNumber,
        isSelf: isSelf,
        initialProfile: cache is FakeProfileCache ? cache.seed : null,
        api: api,
        cache:
            cache ??
            FakeProfileCache(
              isSelf && api is FakeProfileApi ? api.result : null,
            ),
        sessionProvider:
            sessionProvider ??
            FakeSessionProvider(
              fakeSession(cidNumber: isSelf ? _profileCidNumber : null),
              citizenId: isSelf ? _profileCidNumber : null,
            ),
        initialMembershipDecision: initialMembershipDecision,
        initialMembershipState: initialMembershipState,
        subscriptionService:
            subscriptionService ?? _HeaderEmptyMembership(),
      ),
    ),
  );
}

class _DeferredProfileApi extends FakeProfileApi {
  _DeferredProfileApi(super.result, this.gate);
  final Future<void> gate;
  @override
  Future<CitizenProfile> fetchProfile(String cidNumber, {SquareSession? session}) async {
    await gate;
    return super.fetchProfile(cidNumber, session: session);
  }
}

// 通过App公开资料接口交付确认结果，不替代SDK状态或本机身份资源。
class _FollowApi extends FakeProfileApi {
  _FollowApi(
    super.result,
    this.confirmed, {
    this.cache,
    this.failRead = false,
    this.pending,
  });
  final CitizenProfile confirmed;
  final FakeProfileCache? cache;
  final bool failRead;
  final Future<CitizenProfile>? pending;
  int refreshes = 0;
  @override
  Future<CitizenProfileLoadResult> refreshProfile(
    String cidNumber, {
    required SquareSession session,
    required bool userInitiated,
    bool Function()? isCurrent,
    CitizenProfileCache? cache,
    CitizenProfileMediaCache? mediaCache,
  }) async {
    if (!userInitiated) {
      return super.refreshProfile(
        cidNumber,
        session: session,
        userInitiated: false,
        isCurrent: isCurrent,
        cache: cache,
        mediaCache: mediaCache,
      );
    }
    refreshes++;
    if (failRead) {
      throw const SquareApiException('fixture profile refresh failed');
    }
    final fresh = await (pending ?? Future.value(confirmed));
    if (!(isCurrent?.call() ?? true)) {
      throw StateError('fixture session changed');
    }
    final targetCache = cache ?? this.cache;
    return targetCache == null
        ? CitizenProfileLoadResult(fresh, CitizenProfileLoadStatus.updated)
        : targetCache.receiveRemote(
            fresh,
            expectedCid: cidNumber,
            assertCurrent: () {
              if (!(isCurrent?.call() ?? true)) {
                throw StateError('fixture session changed');
              }
            },
          );
  }
}

void suite105() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CitizenProfileApi.resetEntryRefreshMemory();
  });
  _sdkHarness = TestCitizenSdkHarness();
  testWidgets('公开昵称、公民号、三项关系和四类内容计数按身份语义展示', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _headerWrap(isSelf: false, api: FakeProfileApi(sampleProfile(displayName: ''))),
    );
    await tester.pumpAndSettle();

    final fallback = ProfilePresentation.forIdentityKey(
      _profileCidNumber,
    ).fallbackName;
    expect(find.text(fallback), findsWidgets);
    expect(find.text('身份CID号：$_profileCidNumber'), findsOneWidget);
    expect(find.textContaining('SS58：'), findsNothing);
    expect(find.text(kOwner), findsNothing);
    expect(find.textContaining('8 互关'), findsOneWidget);
    expect(find.textContaining('2 关注'), findsOneWidget);
    expect(find.textContaining('128 关注者'), findsOneWidget);
    expect(find.text('公文{36}'), findsOneWidget);
    expect(find.text('帖子{36}'), findsNothing);
    expect(find.text('竞选{6}'), findsOneWidget);
    expect(find.text('视频{4}'), findsOneWidget);
    expect(find.text('文章{12}'), findsOneWidget);
    final mutual = tester.getRect(find.textContaining('8 互关'));
    final following = tester.getRect(find.textContaining('2 关注'));
    final followers = tester.getRect(find.textContaining('128 关注者'));
    expect(following.left - mutual.right, closeTo(18, 0.5));
    expect(followers.left - following.right, closeTo(18, 0.5));
    final categoryBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(categoryBar.labelStyle?.fontSize, 16);
    expect(categoryBar.labelStyle?.fontWeight, FontWeight.w700);
    expect(categoryBar.unselectedLabelStyle?.fontSize, 16);
    expect(categoryBar.unselectedLabelStyle?.fontWeight, FontWeight.w700);
    expect(categoryBar.unselectedLabelColor, AppTheme.textPrimary);
    expect(categoryBar.isScrollable, isTrue);
    expect(categoryBar.tabAlignment, TabAlignment.start);
    expect(ProfileCategoryTabs.height, 36);
    expect(ProfileCategoryTabs.labelTopPadding, 8);
    final postsLabel = tester.widget<Text>(
      find.byKey(const ValueKey<String>('profile-tab-posts')),
    );
    final spans = (postsLabel.textSpan! as TextSpan).children!;
    expect((spans.first as TextSpan).style?.fontSize, 16);
    expect((spans.first as TextSpan).style?.fontWeight, FontWeight.w700);
    expect((spans.last as TextSpan).style?.fontSize, 11);
    expect((spans.last as TextSpan).style?.fontWeight, FontWeight.w400);
    expect((spans.last as TextSpan).style?.color, AppTheme.textTertiary);
    expect(find.byTooltip('复制 SS58 地址'), findsNothing);
    expect(find.byIcon(Icons.copy), findsNothing);
  });

  testWidgets('本人主页首帧优先使用已确认会员快照而非普通资料镜像', (tester) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: true,
        api: FakeProfileApi(
          sampleProfile(memberLevel: null, membergateActive: false),
        ),
        initialMembershipDecision: MembershipDisplayDecision.activeConfirmed,
        initialMembershipState: const SquareMembershipState(
          active: true,
          paidUntil: 9999999999999,
          memberLevel: 'democracy',
        ),
      ),
    );
    await tester.pump();

    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.checked, isTrue);
  });

  testWidgets('资料模型保留非法账户文本也不展示且窄屏不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile(accountId: 'invalid-account-id')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SS58：'), findsNothing);
    expect(find.text('身份CID号：$_profileCidNumber'), findsOneWidget);
    expect(find.byTooltip('复制 SS58 地址'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字体下三项关系统计保持一组且不反向缩小文字', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile()),
        platform: TargetPlatform.iOS,
        textScaler: const TextScaler.linear(53 / 17),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byType(ProfileHeaderCard);
    expect(
      find.descendant(of: header, matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('2 关注'), findsOneWidget);
    expect(find.textContaining('128 关注者'), findsOneWidget);
    expect(find.textContaining('8 互关'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('订阅入口固定在通知左侧且与三图标保持同一行', (tester) async {
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileActionIcons(
              isSelf: false,
              isFollowing: false,
              leading: SizedBox(
                key: ValueKey<String>('creator-subscribe-entry'),
                width: 56,
                height: 34,
              ),
            ),
          ),
        ),
      ),
    );

    final subscribe = find.byKey(
      const ValueKey<String>('creator-subscribe-entry'),
    );
    final notify = find.byIcon(Icons.notifications_outlined);
    expect(subscribe, findsOneWidget);
    expect(notify, findsOneWidget);
    expect(
      tester.getRect(subscribe).right,
      lessThan(tester.getRect(notify).left),
    );
    expect(
      tester.getCenter(subscribe).dy,
      closeTo(tester.getCenter(notify).dy, 0.1),
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 1.5]) {
      for (final entry in <String, String>{
        '长中文': '${'签' * 159}尾',
        '显式换行': '${'中文ABC\n' * 26}末尾四字',
        '表情混排': '${'😀' * 79}尾巴',
      }.entries) {
        testWidgets('${platform.name}窄屏字体$scale完整显示160长度签名${entry.key}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          expect(entry.value.length, 160);
          await tester.pumpWidget(
            _headerWrap(
              isSelf: true,
              api: FakeProfileApi(sampleProfile(profileBio: entry.value)),
              platform: platform,
              textScaler: TextScaler.linear(scale),
              padding: platform == TargetPlatform.iOS
                  ? const EdgeInsets.only(top: 44, bottom: 34)
                  : const EdgeInsets.only(top: 24),
            ),
          );
          await tester.pumpAndSettle();
          final bio = find.text(entry.value);
          final paragraph = tester.renderObject<RenderParagraph>(bio);
          expect(paragraph.didExceedMaxLines, isFalse);
          final tail = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: entry.value.length - 1,
              extentOffset: entry.value.length,
            ),
          );
          expect(tail, isNotEmpty, reason: '末尾字符必须实际排版，不能只保留Text.data');
          expect(
            tail.last.bottom,
            lessThanOrEqualTo(paragraph.size.height + 0.1),
          );
          final stats = find.textContaining('128 关注者');
          expect(
            tester.getRect(stats).top,
            greaterThanOrEqualTo(tester.getRect(bio).bottom),
          );
          // 原合同按分类文字顶部计间距，bottom容器自身含顶部留白且有Sliver叠层。
          final categoryLabel = find.descendant(
            of: find.byType(ProfileCategoryTabs),
            matching: find.byKey(const ValueKey<String>('profile-tab-posts')),
          );
          expect(
            tester.getRect(categoryLabel).top,
            greaterThanOrEqualTo(tester.getRect(stats).bottom),
            reason: '完整签名下方的分类文字不能覆盖统计',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name}小屏大字体能通过原页面滚动读到长签名末尾', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final padding = platform == TargetPlatform.iOS
          ? const EdgeInsets.only(top: 44, bottom: 34)
          : const EdgeInsets.only(top: 24);
      final text = '${'中文ABC\n' * 26}末尾四字';
      await tester.pumpWidget(
        _headerWrap(
          isSelf: true,
          api: FakeProfileApi(sampleProfile(profileBio: text)),
          platform: platform,
          padding: padding,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      final bio = find.text(text);
      final paragraph = tester.renderObject<RenderParagraph>(bio);
      var visible = false;
      for (var attempt = 0; attempt < 80; attempt++) {
        final tail = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: text.length - 1,
                extentOffset: text.length,
              ),
            )
            .last;
        final bottom = paragraph
            .localToGlobal(Offset(tail.left, tail.bottom))
            .dy;
        final top = paragraph.localToGlobal(Offset(tail.left, tail.top)).dy;
        if (top >= kToolbarHeight + padding.top &&
            bottom <= 700 - padding.bottom &&
            bottom <= tester.getRect(find.byType(CollapsibleHeader)).bottom) {
          visible = true;
          for (final opacity in tester.widgetList<Opacity>(
            find.ancestor(of: bio, matching: find.byType(Opacity)),
          )) {
            expect(opacity.opacity, greaterThan(0.99), reason: '超屏签名读完前不应已淡出');
          }
          break;
        }
        await tester.timedDrag(
          find.byType(NestedScrollView),
          const Offset(0, -40),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
      }
      expect(visible, isTrue, reason: '末尾必须能滚动进入手机可见区域且未被折叠容器裁切');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('仅个性签名改变资料高度且分类文字顶部不产生额外留白', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<({double labelTopPadding, double statsTop})> layoutOf(
      String profileBio, {
      required TargetPlatform platform,
      required EdgeInsets padding,
    }) async {
      // 先卸载旧 State，避免相同路由类型复用上一轮 late final API，确保三种签名独立装配。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _headerWrap(
          isSelf: true,
          api: FakeProfileApi(sampleProfile(profileBio: profileBio)),
          platform: platform,
          padding: padding,
        ),
      );
      await tester.pumpAndSettle();
      final stats = find.textContaining('128 关注者');
      final categoryPosts = find.descendant(
        of: find.byType(ProfileCategoryTabs),
        matching: find.byKey(const ValueKey<String>('profile-tab-posts')),
      );
      return (
        labelTopPadding:
            tester.getRect(categoryPosts).top -
            tester.getRect(find.byType(ProfileCategoryTabs)).top,
        statsTop: tester.getRect(stats).top,
      );
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final padding = platform == TargetPlatform.iOS
          ? const EdgeInsets.only(top: 44, bottom: 34)
          : const EdgeInsets.only(top: 24);
      final empty = await layoutOf('', platform: platform, padding: padding);
      final oneLine = await layoutOf(
        '一行个性签名',
        platform: platform,
        padding: padding,
      );
      final wrappedBio = await layoutOf(
        '一段需要自动换行的个性签名，用来验证签名实际高度会推动统计区',
        platform: platform,
        padding: padding,
      );

      for (final layout in [empty, oneLine, wrappedBio]) {
        expect(
          layout.labelTopPadding,
          closeTo(ProfileCategoryTabs.labelTopPadding, 0.5),
        );
      }
      expect(oneLine.statsTop, greaterThan(empty.statsTop));
      expect(wrappedBio.statsTop, greaterThan(oneLine.statsTop));
    }
    // WidgetTest 无法准确还原 SliverAppBar.bottom 与 flexibleSpace 的真机叠层
    // 坐标，因此在此锁定产品间距契约；真实视觉距离由双端页面验收覆盖。
    expect(ProfileHeaderCard.statsToCategoryVisualGap, 15);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [375.0, 390.0, 412.0]) {
      testWidgets('${platform.name} 分类栏在 ${width.toInt()}px 屏宽内五段文字空隙相等', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          Provider<CitizenSdk>.value(
            value: _sdkHarness.sdk,
            child: MaterialApp(
              theme: AppTheme.lightTheme.copyWith(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  // 真机 iPhone 当前为 Extra Large，Flutter 引擎映射为 19/17。
                  textScaler: platform == TargetPlatform.iOS
                      ? const TextScaler.linear(19 / 17)
                      : TextScaler.noScaling,
                ),
                child: child!,
              ),
              home: const DefaultTabController(
                length: 4,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: ProfileCategoryTabs.height,
                      child: ProfileCategoryTabs(
                        posts: 36,
                        campaigns: 6,
                        videos: 4,
                        articles: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bar = tester.getRect(find.byType(TabBar));
        final labels = [
          for (final tab in ProfileTab.values)
            tester.getRect(
              find.byKey(ValueKey<String>('profile-tab-${tab.name}')),
            ),
        ];
        final gaps = <double>[
          labels.first.left - bar.left,
          for (var index = 1; index < labels.length; index++)
            labels[index].left - labels[index - 1].right,
          bar.right - labels.last.right,
        ];
        expect(gaps.first, greaterThan(0));
        for (final gap in gaps.skip(1)) {
          expect(
            gap,
            closeTo(gaps.first, 0.75),
            reason: '${platform.name} ${width.toInt()}px 的五段视觉空隙必须相等',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name} 主页统计完整位于分类栏上方且不被裁切', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _headerWrap(
          isSelf: false,
          api: FakeProfileApi(
            sampleProfile(profileBio: '完整简介用于验证窄屏和不同平台字体度量下统计区仍完整可见'),
          ),
          platform: platform,
          textScaler: const TextScaler.linear(1.3),
          padding: platform == TargetPlatform.iOS
              ? const EdgeInsets.only(top: 44, bottom: 34)
              : const EdgeInsets.only(top: 24),
        ),
      );
      await tester.pumpAndSettle();

      final stats = [
        find.textContaining('8 互关'),
        find.textContaining('2 关注'),
        find.textContaining('128 关注者'),
      ];
      for (final stat in stats) {
        expect(stat, findsOneWidget);
      }
      // 这里只锁定窄屏大字体时三项文字完整且无 RenderFlex 溢出；统计到分类的
      // 15px 视觉间距由上面的精确几何测试分别覆盖 Android 与 iOS。
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'self profile exposes follow and retains edit menu without private messaging',
    (tester) async {
      await tester.pumpWidget(
        _headerWrap(isSelf: true, api: FakeProfileApi(sampleProfile())),
      );
      await tester.pumpAndSettle();

      // 本人可关注自己，通知和私信仍隐藏。
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
      expect(find.byIcon(Icons.how_to_reg), findsNothing);
      // 认证以头像角的公民徽章呈现；无会员显示身份档，会员显示对应会员档位。
      expect(find.byType(IdentityBadge), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('用户码'), findsOneWidget);
      expect(find.text('编辑资料'), findsOneWidget);
    },
  );

  testWidgets('other profile shows subscribe, chat and follow', (tester) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile(following: false)),
      ),
    );
    await tester.pumpAndSettle();

    // 看别人主页：通知(订阅)/聊天/关注 三个图标都在。
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('用户码'), findsOneWidget);
    expect(find.text('编辑资料'), findsNothing);
  });

  testWidgets('renders an avatar image when the profile has an avatar key', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => File('assets/logo/mark256.png').readAsBytes(),
    );
    final requests = <http.Request>[];
    final client = SquareApiClient(
      baseUrl: 'https://example.com/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          bytes!,
          200,
          headers: {'content-type': 'image/png'},
        );
      }),
    );
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(
            avatarKey:
                'i/$_profileCidNumber/avatar/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
          client: client,
        ),
      ),
    );
    // 先让真实缓存I/O完成并推进头像请求，再等待页面稳定；保留原30次有界等待。
    for (var n = 0; n < 30 && requests.isEmpty; n++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    expect(
      requests.single.url.path,
      '/api/user/profiles/$_profileCidNumber/assets/avatar',
    );
    expect(requests.single.headers['authorization'], 'Bearer tok');
    expect(requests.single.headers['x-mls-proof'], isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pure visitor shows an orange person badge (no membership)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(certified: false, cidNumber: _profileCidNumber),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.color, AppTheme.identityVisitor);
    expect(badge.style.checked, isFalse);
  });

  testWidgets('voting identity, no membership -> blue ring, unchecked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile(cidLevel: 'voting')),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.color, AppTheme.identityVoting);
    expect(badge.style.checked, isFalse);
  });

  testWidgets('voting identity + democracy membership -> blue, checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(cidLevel: 'voting', memberLevel: 'democracy'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.color, AppTheme.identityVoting);
    expect(badge.style.checked, isTrue);
  });

  testWidgets('candidate identity + spark membership -> red, checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(cidLevel: 'candidate', memberLevel: 'spark'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.color, AppTheme.identityCandidate);
    expect(badge.style.checked, isTrue);
  });

  testWidgets('candidate identity + freedom membership -> gold, checked', (
    tester,
  ) async {
    // 会员徽章按会员档位着色，不复用竞选身份的红色。
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(cidLevel: 'candidate', memberLevel: 'freedom'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.color, AppTheme.identityVisitor);
    expect(badge.style.checked, isTrue);
  });

  testWidgets('本人身份核实后先展示持久资料，后台刷新更新并保存', (tester) async {
    final gate = Completer<void>();
    final api = _DeferredProfileApi(sampleProfile(displayName: '刷新名'), gate.future);
    final cache = FakeProfileCache(sampleProfile(displayName: '本地名'));
    await tester.pumpWidget(_headerWrap(isSelf: true, api: api, cache: cache));
    expect(find.text('本地名'), findsNothing, reason: '本人提示不是访问许可，仍需核对当前CID');
    await tester.pumpAndSettle();
    expect(find.text('本地名'), findsWidgets);
    expect(find.text('刷新名'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(cache.wrote, isTrue);
    expect(find.text('刷新名'), findsWidgets);
  });

  testWidgets('following a user optimistically flips the icon', (tester) async {
    final before = sampleProfile(following: false, followedBy: true);
    final api = _FollowApi(
      before,
      before.copyWith(isFollowing: true, followers: 129, mutualFollowing: 9),
    );
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: api,
        sessionProvider: FakeSessionProvider(fakeSession()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.how_to_reg), findsOneWidget);
    expect(find.textContaining('129 关注者'), findsOneWidget);
    expect(find.textContaining('9 互关'), findsOneWidget);
    expect(api.followCalls, 1);
  });

  testWidgets(
    'unfollowing a mutual user decrements followers and mutual count',
    (tester) async {
      final before = sampleProfile(following: true, followedBy: true);
      final api = _FollowApi(
        before,
        before.copyWith(isFollowing: false, followers: 127, mutualFollowing: 7),
      );
      await tester.pumpWidget(
        _headerWrap(
          isSelf: false,
          api: api,
          sessionProvider: FakeSessionProvider(fakeSession()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.how_to_reg));
      await tester.pumpAndSettle();

      expect(find.textContaining('127 关注者'), findsOneWidget);
      expect(find.textContaining('7 互关'), findsOneWidget);
      expect(api.unfollowCalls, 1);
    },
  );

  testWidgets('a failed follow rolls the icon back', (tester) async {
    final api = FakeProfileApi(
      sampleProfile(following: false),
      throwOnFollow: true,
    );
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: api,
        sessionProvider: FakeSessionProvider(fakeSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
    expect(find.textContaining('128 关注者'), findsOneWidget);
    expect(find.textContaining('8 互关'), findsOneWidget);
    expect(api.followCalls, 1);
  });

  testWidgets('tapping mutual following opens the mutual list', (tester) async {
    final api = FakeProfileApi(sampleProfile());
    await tester.pumpWidget(
      _headerWrap(
        isSelf: false,
        api: api,
        sessionProvider: FakeSessionProvider(fakeSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('8 互关'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '互关'), findsOneWidget);
    expect(api.lastFollowsType, 'mutual_following');
  });

  testWidgets('message on another profile opens a direct chat with that user', (
    tester,
  ) async {
    String? peer;
    String? chatTitle;
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          home: UserProfilePage(
            cidNumber: _profileCidNumber,
            isSelf: false,
            api: FakeProfileApi(sampleProfile(displayName: '轻节点')),
            cache: FakeProfileCache(),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _HeaderEmptyMembership(),
            onOpenDirectChat: (context, {required peerUserId, required title}) {
              peer = peerUserId;
              chatTitle = title;
              return Future<void>.value();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(peer, _profileCidNumber);
    expect(chatTitle, '轻节点');
  });

  testWidgets('他人视角识别本人后只保留通用关注入口', (tester) async {
    String? peer;
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: _sdkHarness.sdk,
        child: MaterialApp(
          home: UserProfilePage(
            cidNumber: _profileCidNumber,
            isSelf: false,
            api: FakeProfileApi(sampleProfile(displayName: '轻节点')),
            cache: FakeProfileCache(sampleProfile()),
            sessionProvider: FakeSessionProvider(
              fakeSession(),
              citizenId: _profileCidNumber,
            ),
            subscriptionService: _HeaderEmptyMembership(),
            // 本机已确认公民号相同，隐藏私信等本人操作。
            onOpenDirectChat: (context, {required peerUserId, required title}) {
              peer = peerUserId;
              return Future<void>.value();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.person_add_alt), findsOneWidget);
    expect(peer, isNull);
  });

  testWidgets('other profile bell prompts to follow first when not following', (
    tester,
  ) async {
    final api = FakeProfileApi(sampleProfile(following: false));
    await tester.pumpWidget(_headerWrap(isSelf: false, api: api));
    await tester.pumpAndSettle();

    // 未关注时铃铛为空心；点它提示先关注（通知归属挂在关注关系上），不发通知请求。
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('请先关注'), findsOneWidget);
    expect(api.notifyCalls, 0);
  });

  testWidgets('other profile bell mutes notify when following and notifying', (
    tester,
  ) async {
    final api = FakeProfileApi(sampleProfile(following: true, notifying: true));
    await tester.pumpWidget(_headerWrap(isSelf: false, api: api));
    await tester.pumpAndSettle();

    // 已关注且开通知：铃铛为实心 active；点它静音（enabled=false）。
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_active));
    await tester.pumpAndSettle();

    expect(api.notifyCalls, 1);
    expect(api.lastNotifyEnabled, isFalse);
    // 乐观更新后铃铛转为空心。
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('用户码无法核验轻节点绑定时提示重试', (tester) async {
    await tester.pumpWidget(
      _headerWrap(isSelf: true, api: FakeProfileApi(sampleProfile())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用户码'));
    await tester.pumpAndSettle();

    expect(find.byType(UserQrPage), findsNothing);
    expect(find.text('轻节点绑定尚未核验，请刷新重试'), findsOneWidget);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform本人关注回读三项权威计数并重入缓存', (tester) async {
      final before = sampleProfile();
      final confirmed = CitizenProfile.fromJson({
        ...before.toJson(),
        'is_following': true, 'is_followed_by': true,
        // 故意不同于旧数值加一，验证不在客户端推算服务端计数。
        'counts': {
          ...(before.toJson()['counts'] as Map<String, dynamic>),
          'following': 13,
          'followers': 77,
          'mutual_following': 6,
        },
      });
      final cache = FakeProfileCache(before);
      final api = _FollowApi(before, confirmed, cache: cache);
      await tester.pumpWidget(
        _headerWrap(
          isSelf: true,
          api: api,
          cache: cache,
          platform: platform,
          sessionProvider: FakeSessionProvider(
            fakeSession(cidNumber: _profileCidNumber),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pumpAndSettle();
      expect(api.followCalls, 1);
      expect(api.refreshes, 1);
      expect(cache.wrote, isTrue);
      for (final label in ['13 关注', '77 关注者', '6 互关']) {
        expect(find.textContaining(label), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _headerWrap(isSelf: true, api: api, cache: cache, platform: platform),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('13 关注'), findsOneWidget);
      // 十分钟内不重读云端关系，未知操作保持禁用。
      expect(
        tester
            .widget<ProfileActionIcons>(find.byType(ProfileActionIcons))
            .enabled,
        isFalse,
      );
    });
  }
  testWidgets('关注成功后资料回读失败不撤销关系或编造计数', (tester) async {
    final before = sampleProfile();
    final api = _FollowApi(before, before, failRead: true);
    await tester.pumpWidget(_headerWrap(isSelf: false, api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.how_to_reg), findsOneWidget);
    expect(find.textContaining('128 关注者'), findsOneWidget);
    expect(find.text('关注已更新，资料刷新失败，请下拉刷新'), findsOneWidget);
    expect(api.followCalls, 1);
  });
  testWidgets('资料确认前重复点击不会重复关注或取关', (tester) async {
    final before = sampleProfile();
    final done = Completer<CitizenProfile>();
    final api = _FollowApi(
      before,
      before.copyWith(isFollowing: true),
      pending: done.future,
    );
    await tester.pumpWidget(_headerWrap(isSelf: false, api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.how_to_reg));
    await tester.pump();
    expect(api.followCalls, 1);
    expect(api.unfollowCalls, 0);
    done.complete(before.copyWith(isFollowing: true));
    await tester.pumpAndSettle();
  });
}

// 验证资料刷新持久限速、同身份并发合并和失败保留。

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
  Completer<void>? accessPending;
  int accessChecks = 0;
  @override
  Future<void> requireProfileAccess(
    String targetCid,
    SquareSession session,
  ) async {
    accessChecks++;
    if (accessPending != null) await accessPending!.future;
  }

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
    if (fail) {
      throw const SquareApiException('network failure', statusCode: 503);
    }
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

void suite104() {
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
  testWidgets('本人核对本机身份后显示缓存，后台挂起不显示整页转圈，返回后只更新一次', (tester) async {
    api.pending = Completer<CitizenProfile>();
    await tester.pumpWidget(page(initial: cache.seed));
    await tester.pump();
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
  testWidgets('他人每次进入独立校验权限，通过后资料刷新失败保留缓存', (tester) async {
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
    api.accessPending = Completer<void>();
    await tester.pumpWidget(page(self: false, initial: cache.seed));
    expect(find.text('本地资料'), findsNothing);
    await tester.pump();
    expect(api.accessChecks, 1);
    api.accessPending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('本地资料'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(api.gets, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page(self: false, initial: cache.seed));
    await tester.pumpAndSettle();
    expect(api.gets, 1);
    expect(sessions.calls, 3);
    expect(api.accessChecks, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
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

// 验证头像徽章仅消费最终链事实及CID年份边界。

void suite102() {
  testWidgets('轻节点尚无该公民数据时不把旧参数显示成身份或会员徽章', (tester) async {
    final reader = f.Reader();
    final reading = Completer<void>();
    reader.behavior = (account, block, citizens, creators) async {
      if (citizens.contains(f.cidB)) await reading.future;
      return f.snapshot(block, account, citizens: citizens, creators: creators);
    };
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => f.block(103),
      getGenesisHash: () async => f.hash(0),
      getAccount: () async => f.account(1),
    );
    addTearDown(source.close);
    await source.start();
    await tester.pumpWidget(
      ChangeNotifierProvider<ChainDataService>.value(
        value: source,
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              seed: f.cidB,
              size: 80,
              cidLevel: 'candidate',
              memberLevel: 'spark',
              membergateActive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IdentityBadge), findsNothing);
    reading.complete();
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.checked, isTrue);
    expect(badge.tooltip, '访客 · 自由会员');
    await tester.pumpWidget(const SizedBox());
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform头像随最终块会员变更，不接受旧展示参数覆盖', (tester) async {
      final reader = f.Reader();
      var head = f.block(103);
      reader.behavior = (a, b, c, d) async => f.snapshot(
        b,
        a,
        citizens: c,
        creators: d,
        hasMembership: b.number < BigInt.from(104),
      );
      final source = ChainDataService(
        reader: reader,
        getFinalizedHead: () async => head,
        getGenesisHash: () async => f.hash(0),
        getAccount: () async => f.account(1),
      );
      addTearDown(source.close);
      await source.start();
      await tester.pumpWidget(
        ChangeNotifierProvider<ChainDataService>.value(
          value: source,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(
              body: ProfileAvatar(
                seed: f.cidA,
                size: 80,
                cidLevel: 'candidate',
                membergateActive: true,
                memberLevel: 'spark',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).style.checked,
        isTrue,
      );
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).tooltip,
        '访客 · 自由会员',
      );
      head = f.block(104);
      await source.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).style.checked,
        isFalse,
      );
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).tooltip,
        '访客',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final year in ['0000', '2026', '9999', '10000', '4294967295', '4294967296', '02026']) {
    testWidgets('CID年份 $year 的头像身份订阅遵守u32边界', (tester) async {
      final cid = 'CN000-CTZN0-000000001-$year';
      final watched = <String>{};
      final reader = f.Reader();
      reader.behavior = (a, b, citizens, creators) async {
        watched.addAll(citizens);
        return f.snapshot(b, a, citizens: citizens, creators: creators);
      };
      final source = ChainDataService(
        reader: reader, getFinalizedHead: () async => f.block(103),
        getGenesisHash: () async => f.hash(0), getAccount: () async => f.account(1),
      );
      addTearDown(source.close);
      await source.start();
      await tester.pumpWidget(
        ChangeNotifierProvider<ChainDataService>.value(
          value: source, child: MaterialApp(home: Scaffold(body: ProfileAvatar(seed: cid, size: 80))),
        ),
      );
      await tester.pumpAndSettle();
      final accepted = !['4294967296', '02026'].contains(year);
      expect(watched.contains(cid), accepted);
      expect(find.byType(IdentityBadge), accepted ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

}

// 验证本人资料编辑注销及他人仅用户码菜单。

Future<void> _openMenu(WidgetTester tester, {required bool isSelf}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ProfileKebabMenu(
              isSelf: isSelf,
              onUserCode: () {},
              onEditProfile: () {},
              onDeleteAccount: () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void suite106() {
  testWidgets('本人主页显示注销用户和编辑资料', (tester) async {
    await _openMenu(tester, isSelf: true);
    expect(find.text('注销用户'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
  });

  testWidgets('他人主页只显示用户码', (tester) async {
    await _openMenu(tester, isSelf: false);
    expect(find.text('用户码'), findsOneWidget);
    expect(find.text('二维码'), findsNothing);
    expect(find.text('注销用户'), findsNothing);
    expect(find.text('编辑资料'), findsNothing);
  });
}

// 验证固定用户码的二维码、公开资料、复制及下载入口。

/// 用户码展示页（`k=3 user_contact`，固定码，多入口复用同一页）。
///
/// 验证点：
/// - 页面渲染公开昵称、完整 SS58 地址、复制图标和顶部下载图标
/// - 复制点击不抛异常（Clipboard 在 test 环境由 services binding 静默接管）
/// - 下载点击进入保存流程不抛异常（单测环境 SaverGallery 无 native 实现，
///   走 `_saveQr` 的 catch 兜底；不用 pumpAndSettle，保存中的进度圈永不 settle）
/// - 用户码输入只传CID和account_id，昵称和SS58不进SDK编码输入
/// - 本页只出用户码：不存在任何「该出哪种码」的运行时分流（账户维度走账户码页）
void suite110() {
  const accountId =
      '0x0000000000000000000000000000000000000000000000000000000000000000';
  const cidNumber = 'CN001-CTZN-000000001-2026';
  const displayName = '晨光寻路者';
  const qrData = '{"b":{"c":"$cidNumber","n":"$accountId"},"k":3,"p":"QR_V1"}';
  final accountAddress = citizenSs58FromAccountId(accountId);

  Future<void> openPage(WidgetTester tester, {bool isSelf = false}) async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await sdk.close();
    });
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          home: UserQrPage(
            qrData: qrData,
            cidNumber: cidNumber,
            displayName: displayName,
            accountId: accountId,
            isSelf: isSelf,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('用户码页面渲染完整二维码、昵称、地址、复制与顶部下载入口', (tester) async {
    await openPage(tester);

    expect(find.widgetWithText(AppBar, '用户码'), findsOneWidget);
    expect(find.text('二维码'), findsNothing);
    expect(find.text(displayName), findsWidgets);
    expect(find.text(accountAddress), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byType(AppQrImage), findsOneWidget);
  });

  testWidgets('底部文案如实覆盖加联系人与转账两种扫码场景', (tester) async {
    await openPage(tester);

    expect(find.text('扫描此二维码可加为联系人，或向其转账'), findsOneWidget);
  });

  testWidgets('本人入口标题显示我的用户码', (tester) async {
    await openPage(tester, isSelf: true);

    expect(find.widgetWithText(AppBar, '我的用户码'), findsOneWidget);
  });

  testWidgets('用户码是固定码，不出现任何时效文案', (tester) async {
    await openPage(tester);

    expect(find.textContaining('分钟内有效'), findsNothing);
  });

  testWidgets('点击复制地址不抛异常', (tester) async {
    await openPage(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(accountAddress), findsOneWidget);
  });

  testWidgets('点击下载进入保存流程不抛异常', (tester) async {
    await openPage(tester);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  test('用户码调用SDK编码，UI标签不进入协议输入', () async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    try {
      final document = await sdk.encodeDocument(
        CitizenQrContent.userContact(
          cidNumber: cidNumber,
          accountId: accountId,
        ),
      );
      expect(document.canonicalText, qrData);
      expect(document.kind, CitizenQrKind.userContact);
      expect(document.cidNumber, cidNumber);
      expect(document.accountId, accountId);
      expect(document.canonicalText, isNot(contains(displayName)));
      expect(document.canonicalText, isNot(contains(accountAddress)));
    } finally {
      await sdk.close();
    }
  });
}

// 验证作者点击回调及缺资料时稳定昵称和头像。

void suite108() {
  testWidgets('tapping the author region fires onAuthorTap', (tester) async {
    var authorTapped = false;
    var cardTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquarePostCard(
            post: samplePost(text: '正文', displayName: '张三'),
            onTap: () => cardTapped = true,
            onAuthorTap: () => authorTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();

    expect(authorTapped, isTrue);
    expect(cardTapped, isFalse);
  });

  testWidgets('missing author profile uses the stable local name and image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquarePostCard(post: samplePost(displayName: '')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认昵称稳定种子按身份主键 cid_number（samplePost 作者的 cid）。
    expect(
      find.text(
        ProfilePresentation.forIdentityKey('CN001-CTZN-000000001-2026')
            .fallbackName,
      ),
      findsOneWidget,
    );
    expect(find.byType(Image), findsWidgets);
  });
}

// 验证资料卡缩写显示CID，同时保留完整身份值和头像种子。

void suite100() {
  testWidgets(
    'profile renders a short identity CID without changing the identity or avatar seed',
    (tester) async {
      const full = 'CN001-CTZN4-123456789-2026';
      final image = MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderCard(
              cidNumber: full,
              profile: null,
              actions: const SizedBox.shrink(),
              avatarImage: image,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('身份CID号：CN001-CTZN4-123456789'), findsOneWidget);
      expect(find.textContaining(full), findsNothing);
      expect(
        tester
            .widget<ProfileHeaderCard>(find.byType(ProfileHeaderCard))
            .cidNumber,
        full,
      );
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).seed,
        full,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
