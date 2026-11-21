import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_user/square_api_client.dart';

import 'dart:async';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_user/profile/profile_action_icons.dart';

import 'package:flutter/foundation.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/profile/profile_header_card.dart';
import 'package:citizen_user/profile/collapsible_header.dart';
import 'package:citizen_user/profile/profile_category_tabs.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_system/theme/app_theme.dart';

import 'package:citizen_testing/fake_profile.dart';

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
  _RetryProfile(super.result, {this.denyRefresh = false});
  final bool denyRefresh;
  @override
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) async {
    calls++;
    if ((!denyRefresh && calls == 1) || (denyRefresh && calls > 1)) {
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

void main() {
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
        expect(find.text('仅互相关注的用户可见'), findsWidgets);
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
    expect(find.text('仅用户可见'), findsWidgets);
    expect(api.calls, 0);
  });

  testWidgets('统一主页入口拒绝时保留原路由，只弹窗', (tester) async {
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
    expect(find.text('仅用户可见'), findsOneWidget);
    expect(api.accessCalls, 1);
  });
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
