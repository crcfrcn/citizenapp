import 'package:citizenapp/8964/feed/square_notifications_page.dart';
import 'package:citizenapp/8964/post/square_interaction_service.dart';
import 'package:citizenapp/system/notifications/notifications.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/identity_badge_snapshot_store.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:citizenapp/app_log.dart';

import 'package:citizenapp/8964/post/square_models.dart';
import 'package:citizenapp/8964/article/square_article_detail_page.dart';
import 'package:citizenapp/8964/compose/compose_page.dart';
import 'package:citizenapp/8964/post/square_post_detail_page.dart';
import 'package:citizenapp/account/profile/user_profile_page.dart';
import 'package:citizenapp/account/profile/citizen_profile_api.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/square_identity_state.dart';
import 'package:citizenapp/8964/post/square_post_sync_service.dart';
import 'package:citizenapp/8964/feed/square_feed_tabs.dart';
import 'package:citizenapp/8964/feed/square_tab_order_store.dart';
import 'package:citizenapp/8964/article/square_article_card.dart';
import 'package:citizenapp/8964/post/square_post_card.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/membership/membership_revision.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/account/identity/identity_register_guide.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

class SquareHomePage extends StatefulWidget {
  const SquareHomePage({
    super.key,
    this.identityService,
    this.feedSource,
    this.initialFeed,
    this.tabOrderStore,
    this.seedPosts = const <SquarePost>[],
    this.sessionProvider,
    this.onSquareUnreadChanged,
    this.selectedTab,
    this.tabIndex = 0,
  });

  final SquareIdentityService? identityService;
  final SquareFeedSource? feedSource;
  final SquareFeedKind? initialFeed;
  final SquareTabOrderStore? tabOrderStore;
  final List<SquarePost> seedPosts;
  final SquareSessionProvider? sessionProvider;

  /// 广场底部 tab 红点计数回调（上抛给 AppShell 挂 Badge）。
  final ValueChanged<int>? onSquareUnreadChanged;

  /// 底部导航当前活动 tab 广播；值 == [tabIndex] 时显示保存顺序中的第一项。
  final ValueNotifier<int>? selectedTab;
  final int tabIndex;

  @override
  State<SquareHomePage> createState() => _SquareHomePageState();
}

class _SquareHomePageState extends State<SquareHomePage> {
  late SquareFeedKind _selectedFeed =
      widget.initialFeed ?? SquareFeedKind.recommended;
  late final SquareTabOrderStore _tabOrderStore =
      widget.tabOrderStore ?? const SquareTabOrderStore();
  List<SquareFeedKind> _tabOrder = List.of(SquareFeedKind.values);
  Future<void>? _orderLoad;
  bool _tabOrderReady = false;
  late Future<SquareIdentityState> _identityFuture;
  int _identityLoadGeneration = 0;
  late final SquareIdentityService _identityService;
  late final SquareFeedSource _feedSource;
  late Future<List<SquarePost>> _feedFuture;
  int _feedLoadGeneration = 0;
  final List<SquarePost> _localPosts = [];
  final Set<String> _removedPostIds = {};

  /// 最近一次身份加载结果的身份账户与永久 CID，供身份 revision 广播后成对比对。
  String? _identityAddress;
  String? _identityCidNumber;

  final SquareApiClient _squareApi = SquareApiClient();
  late final CitizenProfileApi _profileApi;
  final SquarePostSyncService _postSyncService = SquarePostSyncService();

  /// 当前分类响应所属会话；媒体和头像均由当前会话的受保护读取器获取。
  SquareSession? _feedSession;
  SquareSessionProvider? _sessionProvider;
  AccountSecurityService? _accountSecurity;
  bool _dependenciesReady = false;

  /// 关注子 tab 红点数（服务端 following_unread）。广场底部 tab 数经回调上抛。
  int _followingUnread = 0;

  /// 三级阅读分别提交；只有当前实际显示的广场页面消费广场层角标。
  bool _publishMenuOpen = false;
  bool _squareReadFlight = false;
  bool _squareReadPending = false, _squareReadScheduled = false;
  int _squareReadGeneration = 0;
  NotificationScope? _squareReadOwner;
  final _notificationsKey = GlobalKey<SquareNotificationsPageState>();
  final Set<String> _interactionPosts = {};

  @override
  void initState() {
    super.initState();
    widget.selectedTab?.addListener(_onSquareSelected);
    _feedSource = widget.feedSource ?? SquareApiClient();
    _profileApi = CitizenProfileApi(
      client: _feedSource is SquareApiClient ? _feedSource : _squareApi,
    );
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    IdentityBadgeSnapshotStore.revision.addListener(_onIdentitySnapshotChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) {
      _scheduleSquareRead();
      return;
    }
    _sessionProvider = widget.sessionProvider;
    final injectedIdentity = widget.identityService;
    if (injectedIdentity != null) {
      _identityService = injectedIdentity;
    } else {
      final sdk = context.read<CitizenSdk>();
      final accountSecurity = context.read<AccountSecurityService>();
      _sessionProvider ??= context.read<SquareSessionProvider>();
      _identityService = SquareIdentityService(
        wallet: sdk.wallet,
        currentUserContext: context.read<CurrentUserContext>(),
      );
      _accountSecurity = accountSecurity;
      accountSecurity.revision.addListener(_onWalletsChanged);
    }
    _identityFuture = _loadIdentity();
    // 浏览态首帧挂载页面并并行请求 feed；会话入口先核对当前账户 CID，
    // 本机绑定缺失时等 finalized 链事实返回，再决定引导或业务内容。
    _feedFuture = _beginFeedLoad();
    // 本页常驻 IndexedStack；切换身份账户（CID 换绑 / 切钱包）后经
    // 账户／身份 revision 广播重载身份，保证身份图标与作者点击的 isSelf
    // 判定始终基于当前身份账户。
    Notifications.instance.addListener(_onNotificationChanged);
    _followingUnread = Notifications.instance.followingUnread;
    _dependenciesReady = true;
    _scheduleSquareRead();
  }

  @override
  void dispose() {
    _identityLoadGeneration++;
    widget.selectedTab?.removeListener(_onSquareSelected);
    _accountSecurity?.revision.removeListener(_onWalletsChanged);
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    IdentityBadgeSnapshotStore.revision.removeListener(
      _onIdentitySnapshotChanged,
    );
    Notifications.instance.removeListener(_onNotificationChanged);
    super.dispose();
  }

  /// 身份验真成功只刷新本地身份展示，不因此重复加载动态或网络会话。
  void _onIdentitySnapshotChanged() {
    if (_dependenciesReady && mounted) {
      setState(() {
        _identityFuture = _loadIdentity();
      });
    }
  }

  /// 会员确认事件只负责让当前 feed 重新读取 Worker 作者信号；事件本身不携带权益。
  void _onMembershipChanged() {
    if (!mounted || MembershipRevision.instance.listenable.value == null) {
      return;
    }
    unawaited(_refreshFeedAfterMembershipChanged());
  }

  Future<void> _refreshFeedAfterMembershipChanged() async {
    try {
      await _refreshFeed();
    } on Object catch (error) {
      AppLog.d('square feed membership refresh failed: $error');
    }
  }

  void _onNotificationChanged() {
    if (!mounted) return;
    widget.onSquareUnreadChanged?.call(Notifications.instance.unread);
    setState(() => _followingUnread = Notifications.instance.followingUnread);
    _scheduleSquareRead();
    if (_squareVisible && _sessionProvider != null) {
      for (final id in _interactionPosts) {
        unawaited(
          SquareInteractionService.instance.load(
            id,
            _squareApi,
            _sessionProvider!,
          ),
        );
      }
    }
  }

  bool get _squareVisible =>
      mounted &&
      ModalRoute.isCurrentOf(context) != false &&
      (widget.selectedTab == null ||
          widget.selectedTab!.value == widget.tabIndex) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  void _scheduleSquareRead() {
    _squareReadPending = true;
    if (_squareReadScheduled) return;
    _squareReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _squareReadScheduled = false;
      unawaited(_readSquare());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _readSquare() async {
    if (!_squareVisible ||
        !_squareReadPending ||
        (_squareReadFlight &&
            _squareReadOwner == Notifications.instance.scope)) {
      return;
    }
    final generation = ++_squareReadGeneration;
    _squareReadFlight = true;
    _squareReadOwner = Notifications.instance.scope;
    _squareReadPending = false;
    try {
      if (!await Notifications.instance.restore() ||
          !_squareVisible ||
          generation != _squareReadGeneration) {
        return;
      }
      final owner = Notifications.instance.scope!;
      _squareReadOwner = owner;
      final through = Notifications.instance.through;
      if (through > 0 && Notifications.instance.unread > 0) {
        await Notifications.instance.read(
          owner: owner,
          scope: 'square',
          through: through,
        );
      }
    } on Object catch (error) {
      AppLog.d('square notification read failed: $error');
    } finally {
      if (generation == _squareReadGeneration) {
        _squareReadFlight = false;
        _squareReadOwner = null;
        // 同身份的新事件保留补清意图；切身份后旧请求不能结束新身份的任务。
        if (_squareReadPending && _squareVisible) _scheduleSquareRead();
      }
    }
  }

  @override
  void didUpdateWidget(covariant SquareHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      oldWidget.selectedTab?.removeListener(_onSquareSelected);
      widget.selectedTab?.addListener(_onSquareSelected);
    }
  }

  void _onSquareSelected() {
    _scheduleSquareRead();
    if (!mounted ||
        !_tabOrderReady ||
        widget.selectedTab?.value != widget.tabIndex ||
        _selectedFeed == _tabOrder.first) {
      return;
    }
    setState(() {
      _selectedFeed = _tabOrder.first;
      _feedFuture = _beginFeedLoad();
    });
  }

  Future<void> _ensureTabOrder() async {
    if (_tabOrderReady) return;
    final pending = _orderLoad;
    if (pending != null) return pending;
    final future = _restoreTabOrder();
    _orderLoad = future;
    try {
      await future;
    } finally {
      _orderLoad = null;
    }
  }

  Future<void> _restoreTabOrder() async {
    final order = await _tabOrderStore.read();
    if (!mounted) return;
    setState(() {
      _tabOrder = order;
      _selectedFeed = widget.initialFeed ?? order.first;
      _tabOrderReady = true;
    });
  }

  Future<void> _reorderTabs(int from, int to) async {
    if (!_tabOrderReady || from == to) return;
    final next = List<SquareFeedKind>.of(_tabOrder);
    next.insert(to, next.removeAt(from));
    setState(() => _tabOrder = next);
    try {
      await _tabOrderStore.write(next);
    } on Object catch (error) {
      AppLog.d('square tab order save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('子 tab 顺序保存失败，请重新拖动保存')));
      }
    }
  }

  Future<SquareIdentityState> _loadIdentity() async {
    final generation = ++_identityLoadGeneration;
    final accountRevision = _accountSecurity?.revision.value;
    final identity = await _identityService.loadCurrent();
    // 完成通知必须重建父Scaffold；卸载、账户版本变化及迟到旧请求均不能写回。
    if (!mounted ||
        generation != _identityLoadGeneration ||
        accountRevision != _accountSecurity?.revision.value) {
      return identity;
    }
    setState(() {
      _identityAddress = identity.accountId;
      _identityCidNumber = identity.cidNumber;
    });
    return identity;
  }

  Future<void> _onWalletsChanged() async {
    // CID 占号可在 account_id 不变时把 cid_number 从空推进为有效值；收到显式身份
    // revision 后必须读取完整身份，不能沿用只比较账户的旧优化。
    final accountRevision = _accountSecurity?.revision.value;
    final identity = await context.read<CurrentUserContext>().resolve();
    final identityAccountId = identity?.accountId ?? '';
    final identityCidNumber = identity?.cidNumber ?? '';
    if (!mounted || accountRevision != _accountSecurity?.revision.value) return;
    if (identityAccountId == (_identityAddress ?? '') &&
        identityCidNumber == (_identityCidNumber ?? '')) {
      return;
    }
    setState(() {
      _identityAddress = identityAccountId;
      _identityCidNumber = identityCidNumber;
      _identityFuture = _loadIdentity();
      _feedFuture = _beginFeedLoad();
    });
  }

  Future<void> _openCompose(SquarePostType postType) async {
    // 菜单和编辑页只使用本地当前用户；finalized 身份、会员和余额统一留到最终签名阶段。
    if (_publishMenuOpen) setState(() => _publishMenuOpen = false);
    final post = await Navigator.of(context).push<SquarePost>(
      MaterialPageRoute<SquarePost>(
        builder: (_) => CitizenServiceGate(
          title: '发布内容',
          description: '注册后即可在广场发布内容。',
          child: SquareComposePage(
            postType: postType,
            identityService: _identityService,
          ),
        ),
      ),
    );
    if (post == null || !mounted) return;
    setState(() => _localPosts.insert(0, post));
  }

  Future<void> _openAuthor(String cidNumber) async {
    if (cidNumber.isEmpty) return;
    final identity = await _identityFuture;
    if (!mounted) return;
    // 身份主键 = cid_number：作者主键与本人身份都按 cid 比对判定 isSelf。
    final selfCid = identity.cidNumber?.trim() ?? '';
    final isSelf = selfCid.isNotEmpty && selfCid == cidNumber;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CitizenServiceGate(
          title: '用户主页',
          description: '注册后即可查看用户主页。',
          child: UserProfilePage(cidNumber: cidNumber, isSelf: isSelf),
        ),
      ),
    );
  }

  Future<void> _openDetail(SquarePost post) async {
    final result = await Navigator.of(context).push<SquarePostDetailResult>(
      MaterialPageRoute<SquarePostDetailResult>(
        builder: (_) => CitizenServiceGate(
          title: '内容详情',
          description: '注册后即可查看广场内容。',
          child: post.postType == SquarePostType.article
              ? SquareArticleDetailPage(post: post)
              : SquarePostDetailPage(post: post),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _removedPostIds.add(post.postId);
      _localPosts.removeWhere((item) => item.postId == post.postId);
      final replacement = result.replacement;
      if (replacement != null) {
        _localPosts.removeWhere((item) => item.postId == replacement.postId);
        _localPosts.insert(0, replacement);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _identityCidNumber?.isNotEmpty == true
          ? _SquarePublishMenu(
              expanded: _publishMenuOpen,
              onToggle: () =>
                  setState(() => _publishMenuOpen = !_publishMenuOpen),
              onSelected: _openCompose,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 头像入口已删（进自己主页只走「我的-背景图」），分类栏上移到顶部省空间。
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SquareFeedTabs(
                      selected: _selectedFeed,
                      order: _tabOrder,
                      followingUnread: _followingUnread,
                      notificationsUnread:
                          Notifications.instance.notificationUnread,
                      onReorder: _tabOrderReady
                          ? (from, to) => unawaited(_reorderTabs(from, to))
                          : null,
                      onChanged: (feed) {
                        if (!_tabOrderReady) return;
                        if (feed == SquareFeedKind.notifications &&
                            _selectedFeed == feed) {
                          unawaited(_notificationsKey.currentState?.refresh());
                          return;
                        }
                        setState(() {
                          _selectedFeed = feed;
                          _feedFuture = _beginFeedLoad();
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Opacity(
                              key: const ValueKey<String>(
                                'square-person-tank-watermark-opacity',
                              ),
                              // 8% 只增强背景可见度；原图 alpha 保持完整，避免资产被二次淡化。
                              opacity: 0.08,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: 2.2,
                                  sigmaY: 2.2,
                                ),
                                // 只替换 feed 底层水印；顶栏、内容、FAB 和底部导航
                                // 不读取该图片，也不得随水印设计一起改动。
                                child: Image.asset(
                                  'assets/icons/square-person-tank-watermark.png',
                                  key: const ValueKey<String>(
                                    'square-person-tank-watermark',
                                  ),
                                  width: AppLayout.scaled(context, 280),
                                  height: AppLayout.scaled(context, 141),
                                  fit: BoxFit.contain,
                                  color: AppTheme.primary,
                                  colorBlendMode: BlendMode.srcIn,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedFeed == SquareFeedKind.notifications)
                        SquareNotificationsPage(
                          key: _notificationsKey,
                          selectedTab: widget.selectedTab,
                          tabIndex: widget.tabIndex,
                          api: _feedSource is SquareApiClient
                              ? _feedSource
                              : _squareApi,
                          sessions: _sessionProvider,
                          onOpenPost: (post, through) => openSquareNotification(
                            context,
                            postId: post,
                            notificationThrough: through,
                          ),
                        )
                      else
                        FutureBuilder<List<SquarePost>>(
                          key: ValueKey(
                            _selectedFeed == SquareFeedKind.circle
                                ? _feedLoadGeneration
                                : -1,
                          ),
                          future: _feedFuture,
                          builder: (context, snapshot) {
                            final error = snapshot.error;
                            if (error is SquareApiException &&
                                error.errorCode == 'identity_unregistered') {
                              // 当前本地身份已存在时，服务端缺项只能显示同步状态。
                              if (_identityCidNumber?.isNotEmpty == true) {
                                return const Center(child: Text('身份同步中，请稍后重试'));
                              }
                              return IdentityRegisterGuide(
                                description: '注册后即可浏览广场、发布内容。',
                                onRegistered: _onRegisteredFromGuide,
                              );
                            }
                            if (error is SquareApiException &&
                                (error.errorCode == 'device_not_registered' ||
                                    error.errorCode == 'invalid_signature')) {
                              return const Center(child: Text('公民服务准备未完成，请重试'));
                            }
                            final posts = _composeFeed(
                              snapshot.data ?? const <SquarePost>[],
                            );
                            final errorMessage = error is SquareApiException
                                ? SquareSessionResolution.fromError(error)
                                      .message
                                : snapshot.hasError
                                ? '广场内容加载失败'
                                : null;
                            return Stack(
                              children: [
                                RefreshIndicator(
                                  onRefresh: _refreshFeed,
                                  child: _FeedBody(
                                    posts: posts,
                                    errorMessage: errorMessage,
                                    onOpenPost: _openDetail,
                                    onOpenAuthor: _openAuthor,
                                    avatarImageOf: (key) => _feedSession == null
                                        ? null
                                        : _profileApi.mediaImage(
                                            key,
                                            session: _feedSession!,
                                          ),
                                  ),
                                ),
                                if (snapshot.connectionState !=
                                    ConnectionState.done)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: LinearProgressIndicator(
                                      key: const ValueKey(
                                        'square-feed-progress',
                                      ),
                                      minHeight: AppLayout.scaled(context, 2),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_publishMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('square-publish-menu-scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _publishMenuOpen = false),
                child: const ColoredBox(color: Color(0x14000000)),
              ),
            ),
        ],
      ),
    );
  }

  Future<List<SquarePost>> _loadFeed(
    SquareFeedKind feedKind,
    int generation, {
    bool syncSelf = false,
  }) async {
    if (feedKind == SquareFeedKind.notifications) return const [];
    SquareSession? session;
    SquareSessionProvider? sessionProvider;
    if (_feedSource is SquareApiClient) {
      sessionProvider =
          _sessionProvider ?? context.read<SquareSessionProvider>();
      session = await sessionProvider.ensureSession();
      if (session == null) {
        throw const SquareApiException('需要钱包账户才能浏览广场');
      }
    }
    List<SquarePost> posts;
    try {
      posts = await _feedSource.fetchFeed(feedKind: feedKind, session: session);
    } on SquareApiException catch (error) {
      // 只在 Worker 明确拒绝旧 Session 时重新握手一次；第二次失败原样交给前台，禁止
      // 无限重试。测试/离线数据源不参与生产会话刷新。
      if (error.statusCode != 401 ||
          _feedSource is! SquareApiClient ||
          generation != _feedLoadGeneration) {
        rethrow;
      }
      final refreshed = await sessionProvider!.refreshSession();
      if (refreshed == null) rethrow;
      session = refreshed;
      posts = await _feedSource.fetchFeed(
        feedKind: feedKind,
        session: refreshed,
      );
    }
    // 保存完整会话供头像逐次现签；卸载或迟到旧分类请求不能覆盖当前媒体身份。
    if (mounted && generation == _feedLoadGeneration) {
      _feedSession = session;
      _interactionPosts
        ..clear()
        ..addAll(posts.map((p) => p.postId));
      if (sessionProvider != null && _squareVisible) {
        for (final id in _interactionPosts) {
          unawaited(
            SquareInteractionService.instance.load(
              id,
              _feedSource is SquareApiClient ? _feedSource : _squareApi,
              sessionProvider,
            ),
          );
        }
      }
      _scheduleSquareRead();
    }
    if (syncSelf && session != null) {
      await _postSyncService.sync(
        session,
        userInitiated: true,
        isCurrent: () => mounted && generation == _feedLoadGeneration,
      );
    }
    return posts;
  }

  Future<List<SquarePost>> _beginFeedLoad({bool syncSelf = false}) {
    final generation = ++_feedLoadGeneration;
    final future = () async {
      await _ensureTabOrder();
      if (!mounted || generation != _feedLoadGeneration) return <SquarePost>[];
      final feedKind = _selectedFeed;
      return _loadFeed(feedKind, generation, syncSelf: syncSelf);
    }();
    // initState 和分类切换会先创建 Future、随后才由下一帧 FutureBuilder 挂监听。
    // Worker 快速失败时必须立刻观察错误，消除这段未处理时间窗；原 Future
    // 不做转换，页面仍能通过 snapshot.hasError 展示真实前台失败态。
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          AppLog.d('[SquareHomePage] feed load failed: $error');
        },
      ),
    );
    return future;
  }

  Future<void> _refreshFeed() async {
    final next = _beginFeedLoad(syncSelf: true);
    // Future 赋值表达式本身会返回 Future，必须使用语句块确保 setState 回调
    // 同步返回 void；会员确认后的就地刷新也复用这条安全路径。
    setState(() {
      _feedFuture = next;
    });
    await next;
  }

  /// 引导内占号成功后的就地回刷。服务层已经先失效身份缓存再广播全局 revision；
  /// 当前回调只保证本页在注册流程返回的同一帧重载身份与 feed。
  void _onRegisteredFromGuide() {
    if (!mounted) return;
    setState(() {
      _identityFuture = _loadIdentity();
      _feedFuture = _beginFeedLoad();
    });
  }

  /// 关注和公民圈由服务端按当前 CID 筛选；公民圈只合并本人的即时发布结果。
  List<SquarePost> _composeFeed(List<SquarePost> serverPosts) {
    // 写操作已有确定结果，直接更新当前展示，返回页面不再次请求远端。
    final visibleServer = serverPosts
        .where((post) => !_removedPostIds.contains(post.postId))
        .toList();
    final byId = <String, SquarePost>{};
    for (final post in [
      ..._localPosts,
      ...visibleServer,
      ...widget.seedPosts,
    ]) {
      if (!_removedPostIds.contains(post.postId)) {
        byId.putIfAbsent(post.postId, () => post);
      }
    }
    final merged = byId.values.toList();
    switch (_selectedFeed) {
      case SquareFeedKind.recommended:
        return merged;
      case SquareFeedKind.circle:
        final selfCid = _identityCidNumber;
        final circle = <String, SquarePost>{
          for (final post in visibleServer) post.postId: post,
        };
        if (selfCid != null && selfCid.isNotEmpty) {
          for (final post in _localPosts) {
            if (post.author.cidNumber == selfCid &&
                !_removedPostIds.contains(post.postId)) {
              circle[post.postId] = post;
            }
          }
        }
        return circle.values.toList()..sort((a, b) {
          final byTime = b.publishedAt.compareTo(a.publishedAt);
          return byTime != 0 ? byTime : b.postId.compareTo(a.postId);
        });
      case SquareFeedKind.notifications:
        return const [];
      case SquareFeedKind.following:
        return visibleServer;
      case SquareFeedKind.campaign:
        return merged
            .where((post) => post.postCategory == SquarePostCategory.campaign)
            .toList(growable: false);
      case SquareFeedKind.article:
        return merged
            .where((post) => post.postType == SquarePostType.article)
            .toList(growable: false);
      case SquareFeedKind.videos:
        return merged
            .where((post) => post.postType == SquarePostType.video)
            .toList(growable: false);
    }
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.posts,
    required this.errorMessage,
    required this.onOpenPost,
    required this.onOpenAuthor,
    required this.avatarImageOf,
  });

  final List<SquarePost> posts;
  final String? errorMessage;
  final ValueChanged<SquarePost> onOpenPost;
  final ValueChanged<String> onOpenAuthor;

  /// 完整资料头像只从逐请求签名的图片源读取，不保存一次性证明头。
  final ImageProvider? Function(String objectKey) avatarImageOf;

  ImageProvider? _avatarImage(SquareAuthor author) {
    final key = author.avatarKey;
    return key == null ? null : avatarImageOf(key);
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      // 空态不再展示图标+文字，仅保留可下拉刷新的空滚动区，让底层人物坦克水印透出；
      // 有错误时顶部仍显示错误横幅。
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [if (errorMessage != null) _errorBanner(errorMessage!)],
      );
    }

    return ListView.separated(
      // 底部留白给右下角发布 FAB，避免盖住末条内容的互动区。
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemBuilder: (context, index) {
        if (index == 0 && errorMessage != null) {
          return _errorBanner(errorMessage!);
        }
        final postIndex = errorMessage == null ? index : index - 1;
        final post = posts[postIndex];
        final avatarImage = post.isLocal ? null : _avatarImage(post.author);
        // 文章走标题/正文在上、强制横屏首图在下的文章卡；其余走图文卡。
        if (post.postType == SquarePostType.article) {
          return SquareArticleCard(
            post: post,
            onTap: () => onOpenPost(post),
            onAuthorTap: () => onOpenAuthor(post.author.cidNumber ?? ''),
            avatarImage: avatarImage,
          );
        }
        return SquarePostCard(
          post: post,
          onTap: () => onOpenPost(post),
          onAuthorTap: () => onOpenAuthor(post.author.cidNumber ?? ''),
          avatarImage: avatarImage,
        );
      },
      separatorBuilder: (_, _) =>
          SizedBox(height: AppLayout.scaled(context, 10)),
      itemCount: posts.length + (errorMessage == null ? 0 : 1),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(12)),
      decoration: AppTheme.bannerDecoration(AppTheme.warning),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: AppLayout.scaledValue(13),
          height: 1.35,
        ),
      ),
    );
  }
}

/// 右下角发布按钮的三项等半径圆弧菜单；只管理本地动画和类型导航，
/// 不触发任何网络或链读取。
class _SquarePublishMenu extends StatefulWidget {
  const _SquarePublishMenu({
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<SquarePostType> onSelected;

  static const _duration = Duration(milliseconds: 220);

  @override
  State<_SquarePublishMenu> createState() => _SquarePublishMenuState();
}

class _SquarePublishMenuState extends State<_SquarePublishMenu> {
  bool _itemsVisible = false;

  @override
  void initState() {
    super.initState();
    _itemsVisible = widget.expanded;
  }

  @override
  void didUpdateWidget(covariant _SquarePublishMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded) {
      // 本轮 build 会立即把入口挂回主按钮位置，再沿圆弧展开。
      _itemsVisible = true;
      return;
    }
    if (oldWidget.expanded) {
      // 先播放归位/淡出动画，结束后再移出命中测试与语义树。
      Future<void>.delayed(_SquarePublishMenu._duration, () {
        if (!mounted || widget.expanded) return;
        setState(() => _itemsVisible = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.scaled(context, 190);
    final mainSize = AppLayout.scaled(context, 56);
    final itemSize = AppLayout.scaled(context, 46);
    final radius = AppLayout.scaled(context, 100);
    final origin = size - mainSize / 2;
    final labelGap = AppLayout.scaled(context, 2);
    final labelSize = AppLayout.scaled(context, 12);
    // 公文入口的完整下缘包含文字；圆弧整体上移同等高度后，其完整下边距才与
    // 视频圆形入口的右边距一致。三个圆心仍使用同一虚拟圆心和标准等分角度。
    final arcOriginY = origin - labelGap - labelSize;
    const entries = <({SquarePostType postType, IconData icon})>[
      (postType: SquarePostType.document, icon: Icons.description_outlined),
      (postType: SquarePostType.article, icon: Icons.article_outlined),
      (postType: SquarePostType.video, icon: Icons.videocam_outlined),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        // 水平端点的标签允许使用主按钮下方既有安全空白，圆心无需为避让文字偏离圆弧。
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < entries.length; index++)
            _item(
              context,
              postType: entries[index].postType,
              icon: entries[index].icon,
              // 标准四分之一圆弧按 0° / 45° / 90° 等分，两个相邻弦长必然相同。
              angleDegrees: 90 * index / (entries.length - 1),
              originX: origin,
              originY: arcOriginY,
              collapsedOrigin: origin,
              radius: radius,
              size: itemSize,
              labelGap: labelGap,
              labelSize: labelSize,
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: mainSize,
              height: mainSize,
              child: FloatingActionButton(
                key: const ValueKey('square-publish-main-button'),
                heroTag: 'square-publish-main',
                shape: const CircleBorder(),
                onPressed: widget.onToggle,
                tooltip: widget.expanded ? '收起发布菜单' : '发布',
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                child: AnimatedRotation(
                  turns: widget.expanded ? 0.125 : 0,
                  duration: _SquarePublishMenu._duration,
                  child: Icon(
                    widget.expanded ? Icons.close : Icons.edit_rounded,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required SquarePostType postType,
    required IconData icon,
    required double angleDegrees,
    required double originX,
    required double originY,
    required double collapsedOrigin,
    required double radius,
    required double size,
    required double labelGap,
    required double labelSize,
  }) {
    // 角度从主按钮正左方向向上递增；三个圆心到主按钮圆心的距离完全相同。
    final radians = angleDegrees * math.pi / 180;
    final left = originX - radius * math.cos(radians) - size / 2;
    final top = originY - radius * math.sin(radians) - size / 2;
    final collapsed = collapsedOrigin - size / 2;
    return AnimatedPositioned(
      duration: _SquarePublishMenu._duration,
      curve: Curves.easeOutCubic,
      left: widget.expanded ? left : collapsed,
      top: widget.expanded ? top : collapsed,
      child: Offstage(
        offstage: !_itemsVisible,
        child: ExcludeSemantics(
          excluding: !widget.expanded,
          child: IgnorePointer(
            ignoring: !widget.expanded,
            child: AnimatedScale(
              duration: _SquarePublishMenu._duration,
              scale: widget.expanded ? 1 : 0.72,
              child: AnimatedOpacity(
                duration: _SquarePublishMenu._duration,
                opacity: widget.expanded ? 1 : 0,
                child: Semantics(
                  button: true,
                  label: '发布${postType.label}',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        key: ValueKey('square-publish-${postType.workerValue}'),
                        color: AppTheme.surfaceCard,
                        elevation: 3,
                        shadowColor: Colors.black26,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => widget.onSelected(postType),
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Icon(
                              icon,
                              size: AppLayout.scaled(context, 22),
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: labelGap),
                      Text(
                        postType.label,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: labelSize,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 推送与通知列表共用一个详情读取；目标评论由共用评论区定位。
Future<void> openSquareNotification(
  BuildContext context, {
  required String postId,
  String? commentId,
  int? notificationThrough,
}) async {
  try {
    final api = context.read<SquareApiClient>();
    final session = await context.read<SquareSessionProvider>().ensureSession();
    if (session == null || !context.mounted) return;
    final post = await api.fetchPostDetail(session: session, postId: postId);
    await session.validateCurrent();
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => post.postType == SquarePostType.article
            ? SquareArticleDetailPage(
                post: post,
                initialDetailLoaded: true,
                initialCommentId: commentId,
                notificationThrough: notificationThrough,
              )
            : SquarePostDetailPage(
                post: post,
                initialDetailLoaded: true,
                initialCommentId: commentId,
                notificationThrough: notificationThrough,
              ),
      ),
    );
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('通知内容暂时不可用或已删除')));
    }
  }
}
