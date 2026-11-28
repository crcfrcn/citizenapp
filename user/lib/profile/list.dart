// 分页展示用户动态、关注、关注者及互关列表。

import 'package:citizen_square/post/store.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_user/profile/data.dart' show CitizenProfile, CitizenProfileApi, ProfilePresentation, SquareFollowEntry;
import 'package:citizen_user/api.dart' show SquareApiException, SquareSession;

import 'package:citizen_square/article/page.dart';
import 'package:citizen_square/post/card.dart';
import 'package:citizen_square/media/view.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_system/format.dart';
import 'package:citizen_user/profile/page.dart' show ProfileAvatar, UserProfilePage;
import 'package:citizen_user/membership/service.dart' show MembershipRevision;

// 按作者和内容分类分页读取帖子并触底续页。

/// 单个分类 Tab 的内容：按作者分页拉帖，游标触底加载。
///
/// [mediaKind] 为空 → 帖子卡列表；视频页按 [postType] 在 Worker
/// 分页前过滤，避免客户端分页后筛选造成漏项和错误空态。
class ProfilePostsTab extends StatefulWidget {
  const ProfilePostsTab({
    super.key,
    required this.cidNumber,
    required this.api,
    required this.emptyLabel,
    required this.session,
    required this.sessionReady,
    required this.isSelf,
    this.onSessionExpired,
    this.onAccessDenied,
    this.category,
    this.postType,
    this.mediaKind,
    this.onOpenPost,
    this.refreshFailed = false,
  });

  /// 作者身份主键 cid_number（按 cid 分页拉该身份的帖子）。
  final String cidNumber;
  final CitizenProfileApi api;
  final String emptyLabel;

  /// 可选浏览会话：只用于远端请求和受保护媒体，不是本人本地副本的读取凭证。
  ///
  /// 本人身份已经由上层以永久 `cid_number` 判定；断网或 Worker 不可用时会话可能为空，
  /// 此时仍必须允许本人读取本机已校验的发布副本。
  final SquareSession? session;

  /// 上层是否已经完成首次会话解析。false 表示仍在握手，禁止拿 null 抢跑远端请求；
  /// true + null 表示本次确实没有可用钱包会话。
  final bool sessionReady;

  /// Worker 明确返回 401 时由上层清理缓存并重新握手；每个请求最多调用一次。
  final Future<SquareSession?> Function()? onSessionExpired;

  /// 作者列表明确拒绝主页权限时，让父页关闭整页及资料媒体。
  final void Function(SquareApiException)? onAccessDenied;
  final bool isSelf;

  /// 页面远端刷新失败不伪装成正常空列表。
  final bool refreshFailed;
  final SquarePostCategory? category;
  final SquarePostType? postType;
  final SquareMediaKind? mediaKind;
  final void Function(SquarePost post)? onOpenPost;

  @override
  State<ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends State<ProfilePostsTab> {
  static const int _pageSize = 20;
  static const SquareLocalPostPresenter _localPresenter =
      SquareLocalPostPresenter();

  final List<SquarePost> _posts = [];
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  bool _failedFirst = false;
  bool _sessionUnavailable = false;
  int _loadGeneration = 0;
  SquareSession? _requestSession;

  @override
  void initState() {
    super.initState();
    SquarePostStore.revision.addListener(_onLocalPostsChanged);
    _requestSession = widget.session;
    unawaited(_loadFirst());
  }

  void _onLocalPostsChanged() {
    if (mounted &&
        widget.isSelf &&
        SquarePostStore.revision.value?.cidNumber == widget.cidNumber) {
      unawaited(_loadFirst());
    }
  }

  @override
  void dispose() {
    SquarePostStore.revision.removeListener(_onLocalPostsChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfilePostsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contractChanged =
        oldWidget.cidNumber != widget.cidNumber ||
        oldWidget.api != widget.api ||
        oldWidget.category != widget.category ||
        oldWidget.postType != widget.postType ||
        oldWidget.mediaKind != widget.mediaKind ||
        oldWidget.isSelf != widget.isSelf;
    final incomingSessionChanged =
        _sessionKey(widget.session) != _sessionKey(_requestSession) ||
        oldWidget.sessionReady != widget.sessionReady;
    if (!contractChanged && !incomingSessionChanged) return;
    _requestSession = widget.session;
    // 身份或分类变化不能沿用旧列表；会话变化不影响本人的本地内容。
    if (contractChanged) _posts.clear();
    if (!widget.isSelf || contractChanged) {
      unawaited(_loadFirst(reloadLocal: contractChanged));
    }
  }

  Future<void> _loadFirst({bool reloadLocal = true}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _failedFirst = false;
      _sessionUnavailable = false;
      _cursor = null;
      _done = false;
      if (reloadLocal && !widget.isSelf) {
        _posts.clear();
      }
    });
    var localHasContent = _posts.isNotEmpty;
    if (widget.isSelf && reloadLocal) {
      try {
        final localCopies = await widget.api.fetchLocalPublishedPosts(
          widget.cidNumber,
        );
        final presentations = localCopies
            .where((item) => item.cidNumber == widget.cidNumber)
            .map(_localPresenter.present)
            .where(_matchesLocalFilters)
            .toList(growable: false);
        localHasContent = presentations.isNotEmpty;
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _posts
            ..clear()
            ..addAll(presentations.map((item) => item.post));
        });
      } catch (_) {
        if (mounted && generation == _loadGeneration) {
          setState(() => _failedFirst = true);
          if (_posts.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('内容加载失败，请下拉刷新')));
          }
        }
      }
    }

    if (widget.isSelf) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _done = true;
        });
      }
      return;
    }
    final session = _requestSession;
    if (!widget.sessionReady || session == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        // 本人已有本地副本时直接展示；其余情况在握手完成前保持加载态。
        _loading = !widget.sessionReady && _posts.isEmpty;
        _sessionUnavailable = widget.sessionReady && session == null;
      });
      return;
    }

    try {
      final page = await _fetchRemotePage(
        generation: generation,
        session: session,
      );
      if (page == null || !mounted || generation != _loadGeneration) return;
      setState(() {
        _mergeRemotePosts(page.posts);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      if (error is SquareApiException &&
          const [
            'profile_private',
            'profile_followers_required',
            'profile_mutual_required',
          ].contains(error.errorCode)) {
        widget.onAccessDenied?.call(error);
      }
      setState(() {
        _loading = false;
        _failedFirst = _posts.isEmpty && !localHasContent;
      });
    }
  }

  Future<void> _loadMore() async {
    final session = _requestSession;
    if (widget.isSelf ||
        _loading ||
        _done ||
        _cursor == null ||
        session == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loading = true);
    try {
      final page = await _fetchRemotePage(
        generation: generation,
        session: session,
        cursor: _cursor,
      );
      if (page == null || !mounted || generation != _loadGeneration) return;
      setState(() {
        _mergeRemotePosts(page.posts);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      if (error is SquareApiException &&
          const [
            'profile_private',
            'profile_followers_required',
            'profile_mutual_required',
          ].contains(error.errorCode)) {
        widget.onAccessDenied?.call(error);
      }
      setState(() => _loading = false);
    }
  }

  /// 按当前 Tab 契约拉一页；401 只委托上层刷新一次 Session，第二次失败直接上抛。
  Future<({List<SquarePost> posts, String? nextCursor})?> _fetchRemotePage({
    required int generation,
    required SquareSession session,
    String? cursor,
  }) async {
    Future<({List<SquarePost> posts, String? nextCursor})> request(
      SquareSession activeSession,
    ) {
      return widget.api.fetchAuthorPosts(
        widget.cidNumber,
        category: widget.category,
        postType: widget.postType,
        limit: _pageSize,
        cursor: cursor,
        session: activeSession,
      );
    }

    try {
      return await request(session);
    } on SquareApiException catch (error) {
      if (!mounted || generation != _loadGeneration) return null;
      final refresh = widget.onSessionExpired;
      if (error.statusCode != 401 || refresh == null) rethrow;
      final refreshed = await refresh();
      if (!mounted || generation != _loadGeneration) return null;
      if (refreshed == null) rethrow;
      _requestSession = refreshed;
      return request(refreshed);
    }
  }

  String? _sessionKey(SquareSession? session) => session == null
      ? null
      : '${session.accountId}:${session.cidNumber}:${session.bindRev}:${session.sessionToken}';

  bool _matchesLocalFilters(SquareLocalPostPresentation presentation) {
    final post = presentation.post;
    if (widget.category != null && post.postCategory != widget.category) {
      return false;
    }
    if (widget.postType != null && post.postType != widget.postType) {
      return false;
    }
    final mediaKind = widget.mediaKind;
    return mediaKind == null ||
        post.mediaItems.any((item) => item.mediaKind == mediaKind);
  }

  /// 他人主页分页合并；本人列表只读取本地持久副本。
  void _mergeRemotePosts(List<SquarePost> remotePosts) {
    final byPostId = <String, SquarePost>{
      for (final post in _posts) post.postId: post,
    };
    for (final remote in remotePosts) {
      byPostId[remote.postId] = remote;
    }
    final merged = byPostId.values.toList()
      ..sort((left, right) {
        final byCreatedAt = right.publishedAt.compareTo(left.publishedAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return right.postId.compareTo(left.postId);
      });
    _posts
      ..clear()
      ..addAll(merged);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 400) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        key: PageStorageKey<String>(
          '${widget.category?.name ?? 'all'}:'
          '${widget.postType?.name ?? 'all'}:'
          '${widget.mediaKind?.name ?? 'posts'}',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          if (_loading)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                key: const ValueKey('profile-posts-load-progress'),
                minHeight: AppLayout.scaled(context, 2),
              ),
            ),
          ..._contentSlivers(),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers() {
    if (_loading && _posts.isEmpty) {
      return [_message('正在读取内容')];
    }
    if ((_failedFirst || widget.refreshFailed) && _posts.isEmpty) {
      return [_message('内容加载失败，请下拉刷新')];
    }
    if (_sessionUnavailable && _posts.isEmpty) {
      return [_message('内容暂未加载，请下拉刷新')];
    }
    if (widget.mediaKind != null) {
      return _mediaSlivers();
    }
    if (_posts.isEmpty) {
      return [_message(widget.emptyLabel)];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        sliver: SliverList.separated(
          itemCount: _posts.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: AppLayout.scaledValue(10)),
          itemBuilder: (context, index) {
            final post = _posts[index];
            final avatarKey = post.author.avatarKey;
            final session = widget.session;
            final avatarImage =
                post.isLocal || avatarKey == null || session == null
                ? null
                : widget.api.mediaImage(avatarKey, session: session);
            // 媒体和头像均交给所属受保护读取器，不在UI保存鉴权头。

            if (widget.postType == SquarePostType.article) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SquareArticleCard(
                    post: post,
                    onTap: () => widget.onOpenPost?.call(post),
                    onAuthorTap: () => widget.onOpenPost?.call(post),

                    avatarImage: avatarImage,
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SquarePostCard(
                  post: post,
                  onTap: () => widget.onOpenPost?.call(post),
                  onAuthorTap: () => widget.onOpenPost?.call(post),

                  avatarImage: avatarImage,
                ),
              ],
            );
          },
        ),
      ),
      _footer(),
    ];
  }

  List<Widget> _mediaSlivers() {
    final entries = <({SquarePost post, SquareMediaItem media})>[];
    for (final post in _posts) {
      for (final media in post.mediaItems) {
        if (media.mediaKind == widget.mediaKind) {
          entries.add((post: post, media: media));
        }
      }
    }
    if (entries.isEmpty) {
      // 本人列表只读本地副本，缺少视频不能推断远端没有视频。
      return [_message(widget.emptyLabel)];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppLayout.scaledValue(6),
            mainAxisSpacing: AppLayout.scaledValue(6),
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final entry = entries[index];
            return _MediaTile(
              media: entry.media,
              onTap: () => widget.onOpenPost?.call(entry.post),
            );
          }, childCount: entries.length),
        ),
      ),
      _footer(),
    ];
  }

  Widget _footer() {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _message(String text) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Text(text, style: const TextStyle(color: AppTheme.textTertiary)),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.media, this.onTap});

  final SquareMediaItem media;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SquareMediaTile(
        item: media,
        radius: BorderRadius.circular(AppTheme.radiusSm),
      ),
    );
  }
}

// 分页展示关注、关注者或互关，连接统一用户主页入口。

enum FollowsType {
  following('关注', 'following'),
  followers('关注者', 'followers'),
  mutualFollowing('互关', 'mutual_following');

  const FollowsType(this.label, this.workerValue);

  final String label;
  final String workerValue;
}

/// 关注、关注者和互关列表页。列表项为身份主键 cid_number；缺少公开资料时仍使用与主页
/// 一致的稳定默认昵称和头像，身份号显示在副标题，点击进入唯一用户主页。
class FollowsListPage extends StatefulWidget {
  const FollowsListPage({
    super.key,
    required this.cidNumber,
    required this.type,
    required this.session,
    this.api,
  });

  /// 被查看列表的所有者身份主键 cid_number（三类关系均按 cid 拉取）。
  final String cidNumber;
  final FollowsType type;
  final SquareSession session;
  final CitizenProfileApi? api;

  @override
  State<FollowsListPage> createState() => _FollowsListPageState();
}

class _FollowsListPageState extends State<FollowsListPage> {
  late final CitizenProfileApi _api;
  final List<SquareFollowEntry> _entries = [];
  final Map<String, CitizenProfile> _profiles = <String, CitizenProfile>{};
  String? _followsCursor;
  bool _followsLoading = false;
  bool _followsDone = false;
  bool _followsFailedFirst = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? CitizenProfileApi();
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    _followsLoadFirst();
  }

  @override
  void dispose() {
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    super.dispose();
  }

  /// 当前列表可见 CID 的会员镜像变化时只重取该行公开资料。
  void _onMembershipChanged() {
    final event = MembershipRevision.instance.listenable.value;
    if (!mounted || event == null) return;
    final matching = _entries
        .where((entry) => entry.peerCid == event.cidNumber)
        .toList(growable: false);
    if (matching.isEmpty) return;
    _profiles.remove(event.cidNumber);
    unawaited(_loadProfiles(matching));
  }

  Future<void> _followsLoadFirst() async {
    setState(() {
      _followsLoading = true;
      _followsFailedFirst = false;
    });
    try {
      final page = await _api.fetchFollows(
        widget.cidNumber,
        type: widget.type.workerValue,
        limit: 20,
        session: widget.session,
      );
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.entries);
        _followsCursor = page.nextCursor;
        _followsDone = page.nextCursor == null;
        _followsLoading = false;
      });
      unawaited(_loadProfiles(page.entries));
    } on Exception {
      if (!mounted) return;
      setState(() {
        _followsLoading = false;
        _followsFailedFirst = _entries.isEmpty;
      });
    }
  }

  Future<void> _followsLoadMore() async {
    if (_followsLoading || _followsDone || _followsCursor == null) return;
    setState(() => _followsLoading = true);
    try {
      final page = await _api.fetchFollows(
        widget.cidNumber,
        type: widget.type.workerValue,
        limit: 20,
        cursor: _followsCursor,
        session: widget.session,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _followsCursor = page.nextCursor;
        _followsDone = page.nextCursor == null;
        _followsLoading = false;
      });
      unawaited(_loadProfiles(page.entries));
    } on Exception {
      if (!mounted) return;
      setState(() => _followsLoading = false);
    }
  }

  bool _followsOnScroll(ScrollNotification notification) {
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 300) {
      _followsLoadMore();
    }
    return false;
  }

  /// 关注关系接口只返回目标身份主键 peer_cid；公开资料按当前分页并行补齐（按 cid 拉、
  /// 按 cid 去重）。单个资料失败时保留稳定本地默认展示，不阻塞列表及其他用户。
  Future<void> _loadProfiles(List<SquareFollowEntry> entries) async {
    await Future.wait(
      entries.map((entry) async {
        if (_profiles.containsKey(entry.peerCid)) return;
        try {
          final profile = await _api.fetchCard(
            entry.peerCid,
            session: widget.session,
          );
          _profiles[entry.peerCid] = profile;
        } on Exception {
          // 公开资料不可用时由 ProfilePresentation 稳定兜底。
        }
      }),
    );
    if (mounted) setState(() {});
  }

  void _openProfile(String cidNumber) {
    unawaited(
      UserProfilePage.open(
        context,
        UserProfilePage(
          cidNumber: cidNumber,
          isSelf: false,
          initialProfile: _profiles[cidNumber],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.type.label), centerTitle: true),
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
          if (_followsLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                key: const ValueKey('follows-load-progress'),
                minHeight: AppLayout.scaled(context, 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_followsLoading && _entries.isEmpty) {
      return const Center(
        child: Text('正在读取关注关系', style: TextStyle(color: AppTheme.textTertiary)),
      );
    }
    if (_followsFailedFirst) {
      return const Center(
        child: Text(
          '加载失败，请返回重试',
          style: TextStyle(color: AppTheme.textTertiary),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(switch (widget.type) {
          FollowsType.following => '还没有关注任何人',
          FollowsType.followers => '还没有关注者',
          FollowsType.mutualFollowing => '还没有互关用户',
        }, style: const TextStyle(color: AppTheme.textTertiary)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _followsOnScroll,
      child: ListView.separated(
        itemCount: _entries.length + (_followsLoading ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _entries.length) {
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppLayout.scaled(context, 12),
              ),
              child: LinearProgressIndicator(
                key: const ValueKey('follows-more-progress'),
                minHeight: AppLayout.scaled(context, 2),
              ),
            );
          }
          final entry = _entries[index];
          final profile = _profiles[entry.peerCid];
          final presentation = ProfilePresentation.forIdentityKey(
            entry.peerCid,
          );
          final avatarKey = profile?.avatarKey;
          return ListTile(
            leading: ProfileAvatar(
              seed: entry.peerCid,
              size: AppLayout.scaled(context, 42),
              imageUrl: avatarKey == null ? null : _api.cardMediaUrl(avatarKey),

              cidLevel: profile?.cidLevel,
              memberLevel: profile?.memberLevel,
              membergateActive: profile?.membergateActive ?? false,
            ),
            title: Text(
              presentation.resolveDisplayName(publicName: profile?.displayName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              formatIdentityCidText(entry.peerCid),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: AppLayout.scaled(context, 20),
            ),
            onTap: () => _openProfile(entry.peerCid),
          );
        },
      ),
    );
  }
}
