import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/user_qr_page.dart';
import 'package:citizen_user/profile/profile_action_icons.dart';
import 'package:citizen_user/profile/profile_category_tabs.dart';
import 'package:citizen_user/profile/profile_header_card.dart';
import 'package:citizen_user/profile/collapsible_header.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_user/identity/identity_badge.dart';

import 'package:citizen_testing/fake_profile.dart';

late TestCitizenSdkHarness _sdkHarness;

const String _profileCidNumber = 'CN001-CTZN-000000001-2026';

/// 身份账户缓存 fake：resolve/account_id 返回 null，让 _resolveOwnAccount 回退成
/// 「非本人」（行为与迁移前一致）；避免 instance 触发真链读/真 Isar。
class _NullMembershipSnapshotService implements SubscriptionService {
  @override
  Future<MembershipDisplaySnapshot?> readDisplaySnapshot(
    String cidNumber,
  ) async => null;

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

Widget _wrap({
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
        api: api,
        cache:
            cache ??
            FakeProfileCache(
              isSelf && api is FakeProfileApi ? api.result : null,
            ),
        sessionProvider:
            sessionProvider ??
            FakeSessionProvider(
              fakeSession(),
              citizenId: isSelf ? _profileCidNumber : null,
            ),
        initialMembershipDecision: initialMembershipDecision,
        initialMembershipState: initialMembershipState,
        subscriptionService:
            subscriptionService ?? _NullMembershipSnapshotService(),
        viewerAccountLoader: () async => null,
      ),
    ),
  );
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
  Future<CitizenProfile> refreshProfile(
    String cidNumber, {
    required SquareSession session,
    required bool userInitiated,
    bool Function()? isCurrent,
  }) async {
    refreshes++;
    expect(userInitiated, isTrue);
    if (failRead) {
      throw const SquareApiException('fixture profile refresh failed');
    }
    final fresh = await (pending ?? Future.value(confirmed));
    if (!(isCurrent?.call() ?? true)) {
      throw StateError('fixture session changed');
    }
    await cache?.write(fresh);
    return fresh;
  }
}

void main() {
  _sdkHarness = TestCitizenSdkHarness();
  testWidgets('公开昵称、公民号、三项关系和四类内容计数按身份语义展示', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(isSelf: false, api: FakeProfileApi(sampleProfile(displayName: ''))),
    );
    await tester.pumpAndSettle();

    final fallback = ProfilePresentation.forIdentityKey(
      _profileCidNumber,
    ).fallbackName;
    expect(find.text(fallback), findsWidgets);
    expect(find.text('公民号：$_profileCidNumber'), findsOneWidget);
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
      _wrap(
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
      _wrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile(accountId: 'invalid-account-id')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SS58：'), findsNothing);
    expect(find.text('公民号：$_profileCidNumber'), findsOneWidget);
    expect(find.byTooltip('复制 SS58 地址'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字体下三项关系统计保持一组且不反向缩小文字', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
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
            _wrap(
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
        _wrap(
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
        _wrap(
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
        _wrap(
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
        _wrap(isSelf: true, api: FakeProfileApi(sampleProfile())),
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
      _wrap(
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
      _wrap(
        isSelf: false,
        api: FakeProfileApi(
          sampleProfile(avatarKey: 'profile/$_profileCidNumber/avatar'),
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
      _wrap(
        isSelf: false,
        api: FakeProfileApi(sampleProfile(certified: false)),
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
      _wrap(
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
      _wrap(
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
      _wrap(
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
      _wrap(
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

  testWidgets('本人首屏只读持久资料，不拉取或重写远端结果', (tester) async {
    final api = FakeProfileApi(sampleProfile(displayName: '刷新名'));
    final cache = FakeProfileCache(sampleProfile(displayName: '本地名'));
    await tester.pumpWidget(_wrap(isSelf: true, api: api, cache: cache));
    await tester.pumpAndSettle();

    expect(api.calls, 0);
    expect(cache.wrote, isFalse);
    expect(find.text('本地名'), findsWidgets);
    expect(find.text('刷新名'), findsNothing);
  });

  testWidgets('following a user optimistically flips the icon', (tester) async {
    final before = sampleProfile(following: false, followedBy: true);
    final api = _FollowApi(
      before,
      before.copyWith(isFollowing: true, followers: 129, mutualFollowing: 9),
    );
    await tester.pumpWidget(
      _wrap(
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
        _wrap(
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
      _wrap(
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
      _wrap(
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
            subscriptionService: _NullMembershipSnapshotService(),
            viewerAccountLoader: () async => null,
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
            cache: FakeProfileCache(),
            sessionProvider: FakeSessionProvider(fakeSession()),
            subscriptionService: _NullMembershipSnapshotService(),
            // 浏览者账户相同，依然允许关注，隐藏私信等本人操作。
            viewerAccountLoader: () async => kOwner,
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
    await tester.pumpWidget(_wrap(isSelf: false, api: api));
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
    await tester.pumpWidget(_wrap(isSelf: false, api: api));
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

  testWidgets('三点菜单的用户码入口打开用户码页面', (tester) async {
    await tester.pumpWidget(
      _wrap(isSelf: true, api: FakeProfileApi(sampleProfile())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用户码'));
    await tester.pumpAndSettle();

    expect(find.byType(UserQrPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '我的用户码'), findsOneWidget);
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
        _wrap(
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
        _wrap(isSelf: true, api: api, cache: cache, platform: platform),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('13 关注'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_reg), findsOneWidget);
    });
  }
  testWidgets('关注成功后资料回读失败不撤销关系或编造计数', (tester) async {
    final before = sampleProfile();
    final api = _FollowApi(before, before, failRead: true);
    await tester.pumpWidget(_wrap(isSelf: false, api: api));
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
    await tester.pumpWidget(_wrap(isSelf: false, api: api));
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
