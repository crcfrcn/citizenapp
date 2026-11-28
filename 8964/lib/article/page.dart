// 展示文章卡片和详情，保留原权限复核及生命周期。

import 'dart:async';

import 'package:citizen_square/article/editor.dart';
import 'package:citizen_square/compose/page.dart';
import 'package:citizen_square/interaction/actions.dart';
import 'package:citizen_square/interaction/comments.dart';
import 'package:citizen_square/interaction/likes.dart';
import 'package:citizen_square/media/view.dart';
import 'package:citizen_square/post/card.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_square/post/page.dart';
import 'package:citizen_square/post/store.dart';
import 'package:citizen_square/post/sync.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_user/api.dart' show SquareApiClient, SquareApiException;
import 'package:citizen_user/context.dart' show CurrentUserContext;
import 'package:citizen_user/identity/badge.dart' show CitizenServiceGate;
import 'package:citizen_user/identity/session.dart'
    show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_user/membership/service.dart'
    show MembershipBusinessGate, SubscriptionService;
import 'package:citizen_user/notifications.dart' show Notifications;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 展示文章及竞选文章卡片的标题、摘要、横屏首图和互动。

/// 文章卡（含竞选变体）。
///
/// 版式：作者头部 → 标题（2 行截断）+ 正文摘要（2 行截断）→ 首图（强制横屏 16:9）→ 互动栏。
/// 首图取 `media_items[0]`，方向强制横屏，不随媒体原始朝向变化。
class SquareArticleCard extends StatelessWidget {
  const SquareArticleCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.avatarUrl,

    this.avatarImage,
  });

  final SquarePost post;
  final VoidCallback? onTap;

  /// 点击作者头像/名进入其用户主页。
  final VoidCallback? onAuthorTap;

  /// 作者头像地址；实际获取交给当前会话的受保护读取器。
  final String? avatarUrl;

  /// 完整资料媒体的签名读取器；不携带可复用的一次性证明头。
  final ImageProvider? avatarImage;

  @override
  Widget build(BuildContext context) {
    final cover = post.mediaItems.isNotEmpty ? post.mediaItems.first : null;
    final title = post.title?.trim();
    final body = post.text.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquarePostHeader(
                post: post,
                onAuthorTap: onAuthorTap,
                avatarUrl: avatarUrl,

                avatarImage: avatarImage,
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: AppLayout.scaled(context, 16),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              if (body.isNotEmpty) ...[
                SizedBox(height: AppLayout.scaled(context, 6)),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: AppLayout.scaled(context, 14),
                    height: 1.45,
                  ),
                ),
              ],
              if (cover != null && (cover.isLocal || cover.url.isNotEmpty)) ...[
                SizedBox(height: AppLayout.scaled(context, 12)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: SquareMediaImage(item: cover, preview: true),
                  ),
                ),
              ],
              SizedBox(height: AppLayout.scaled(context, 12)),
              SquarePostActions(
                postId: post.chainBlock != null || !post.isLocal
                    ? post.postId
                    : null,
                onComment: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 读取文章详情和完整段落媒体，随身份及权限变化撤下旧正文。

/// 文章详情：首图、标题、作者及保持图集/视频块关系的完整正文。
class SquareArticleDetailPage extends StatefulWidget {
  const SquareArticleDetailPage({
    super.key,
    required this.post,
    this.api,
    this.sessionProvider,
    this.deletionCoordinator,
    this.initialRead,
    this.initialCommentId,
    this.notificationThrough,
  });

  final SquarePost post;
  final SquareDetailRead? initialRead;
  final String? initialCommentId;
  final int? notificationThrough;
  final SquareApiClient? api;
  final SquareSessionProvider? sessionProvider;
  final SquarePostDeleteCoordinator? deletionCoordinator;

  @override
  State<SquareArticleDetailPage> createState() =>
      _SquareArticleDetailPageState();
}

enum _ArticleDetailAction { edit, delete }

class _SquareArticleDetailPageState extends State<SquareArticleDetailPage>
    with WidgetsBindingObserver {
  late final SquareApiClient _api;
  late final SquareSessionProvider _sessionProvider;
  late final SquarePostDeleteCoordinator _deletionCoordinator;
  late SquarePost _post;
  bool _loading = true;
  Object? _loadError;
  bool _deleting = false;
  bool _dependenciesReady = false;
  AccountSecurityService? _security;
  CurrentUserContext? _currentUser;
  int _loadGeneration = 0;
  String? _viewerCid;
  String? _viewerAccount;
  int? _viewerBindRev;
  bool _verifiedLocal = false;
  bool _hasContent = false;
  bool _wasCurrent = false;

  SquarePost get post => _post;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _post = widget.post;
    _api = widget.api ?? SquareApiClient();
    _deletionCoordinator =
        widget.deletionCoordinator ??
        SquarePostDeletionCoordinator(remoteDeletion: _api);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) != false;
    final returned = current && !_wasCurrent;
    _wasCurrent = current;
    if (_dependenciesReady) {
      if (returned) _recheckDetail();
      return;
    }
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    _dependenciesReady = true;
    _security = context.read<AccountSecurityService?>();
    _currentUser = context.read<CurrentUserContext?>();
    _security?.revision.addListener(_onIdentityChanged);
    unawaited(_loadDetail());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadGeneration++;
    _security?.revision.removeListener(_onIdentityChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasCurrent) _recheckDetail();
  }

  void _recheckDetail() {
    if (!_hasContent || _verifiedLocal || _post.author.cidNumber == _viewerCid) return;
    // 回到他人详情先隐藏旧正文，沿同一个读取入口校验当前权限。
    _hasContent = false;
    unawaited(_loadDetail(refresh: true));
  }

  void _onIdentityChanged() {
    // 立即卸载旧正文与媒体，不等待新会话或云端响应。
    _loadGeneration++;
    if (!mounted) return;
    setState(() {
      _verifiedLocal = false;
      _hasContent = false;
      _loading = false;
      _loadError = StateError('当前身份已变化，请重新打开内容');
    });
  }

  Future<void> _loadDetail({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    final revision = _security?.revision.value;
    bool current() =>
        mounted &&
        generation == _loadGeneration &&
        revision == _security?.revision.value;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      // 本人离线副本先核对本机身份，不以isLocal标志或作者CID代替当前用户。
      final localUser = await _currentUser?.resolve();
      final cidNumber =
          localUser?.cidNumber ?? await _sessionProvider.currentCitizenId();
      if (!current()) return;
      if (cidNumber == null ||
          cidNumber.isEmpty ||
          _viewerCid != null && _viewerCid != cidNumber ||
          localUser != null &&
              _viewerAccount != null &&
              (_viewerAccount != localUser.accountId ||
                  _viewerBindRev != localUser.bindRev)) {
        _hasContent = false;
        _verifiedLocal = false;
        throw StateError('当前身份已变化，请重新打开内容');
      }
      _viewerCid = cidNumber;
      if (localUser != null) {
        _viewerAccount = localUser.accountId;
        _viewerBindRev = localUser.bindRev;
      }
      if (_post.isLocal) {
        final cid = _post.author.cidNumber!;
        if (cidNumber != cid) {
          _hasContent = false;
          _verifiedLocal = false;
          throw StateError('只能读取当前用户的本地内容');
        }
        if (refresh) {
          final session = await _sessionProvider.ensureSession();
          if (!current()) return;
          if (session == null) throw StateError('当前无法建立服务会话');
          if (session.cidNumber != cid ||
              _viewerAccount != null &&
                  (session.accountId != _viewerAccount ||
                      session.bindRev != _viewerBindRev)) {
            _hasContent = false;
            _verifiedLocal = false;
            throw StateError('当前用户已变化');
          }
          await SquarePostSyncService().sync(
            session,
            userInitiated: true,
            isCurrent: current,
          );
        }
        final local = await const SquarePostStore().read(
          cidNumber: cid,
          postId: _post.postId,
        );
        if (local == null) throw StateError('本地尚未保存内容');
        final presentation = const SquareLocalPostPresenter().present(local);
        if (current()) {
          setState(() {
            _verifiedLocal = true;
            _hasContent = true;
            _post = presentation.post;
            _loading = false;
          });
        }
        return;
      }
      final session = await _sessionProvider.ensureSession();
      if (!current()) return;
      if (session == null) throw const SquareApiException('请先选择默认钱包账户');
      if (session.cidNumber != cidNumber ||
          _viewerAccount != null &&
              (session.accountId != _viewerAccount ||
                  session.bindRev != _viewerBindRev)) {
        _hasContent = false;
        _verifiedLocal = false;
        throw StateError('当前身份已变化，请重新打开内容');
      }
      _viewerAccount = session.accountId;
      _viewerBindRev = session.bindRev;
      await SubscriptionService.requireSquareSession(session, client: _api);
      await Notifications.instance.restore();
      final notificationOwner = Notifications.instance.scope;
      await session.validateCurrent();
      if (notificationOwner != null &&
          (notificationOwner.cidNumber != session.cidNumber ||
              notificationOwner.bindRev != session.bindRev ||
              notificationOwner.accountId != session.accountId)) {
        _hasContent = false;
        _verifiedLocal = false;
        throw StateError('内容详情身份已变化');
      }
      final readThrough = Notifications.instance.through;
      final detail =
          !refresh &&
              widget.initialRead?.matches(session, revision, _post.postId) ==
                  true
          ? _post
          : await _api.fetchPostDetail(session: session, summary: _post);
      await session.validateCurrent();
      if (!current() ||
          (notificationOwner != null &&
              !Notifications.instance.isCurrent(notificationOwner))) {
        return;
      }
      setState(() {
        _post = detail;
        _hasContent = true;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current() && ModalRoute.of(context)?.isCurrent == true) {
          unawaited(
            SquareInteractionService.instance.viewed(
              post.postId,
              through: readThrough,
            ),
          );
          unawaited(
            Notifications.instance.read(
              owner: notificationOwner,
              postIds: [post.postId],
            ),
          );
        }
      });
    } catch (error) {
      if (!mounted || !current()) return;
      // 明确拒绝远端内容时关闭旧正文；本人已核对的离线副本不因云端故障丢失。
      if (SquareSessionResolution.fromError(error).status ==
          SquareSessionStatus.identityChanged) {
        _hasContent = false;
        _verifiedLocal = false;
      }
      final denied =
          !_verifiedLocal &&
          error is SquareApiException &&
          const [401, 403, 404].contains(error.statusCode);
      if (denied) _hasContent = false;
      final keepContent = refresh && _hasContent && !denied;
      if (keepContent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('刷新失败，已保留本地内容')));
      }
      setState(() {
        _loadError = keepContent ? null : error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = post.mediaItems;
    final cover = media.isNotEmpty ? media.first : null;
    final title = post.title?.trim();

    final content = Scaffold(
      appBar: AppBar(
        title: const Text('文章'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _loadDetail(refresh: true),
          ),
          PopupMenuButton<_ArticleDetailAction>(
            enabled: !_deleting && !_loading && _loadError == null,
            onSelected: _handleAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ArticleDetailAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('修改'),
                ),
              ),
              PopupMenuItem(
                value: _ArticleDetailAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _DetailLoadError(
              error: _loadError!,
              onRetry: () => _loadDetail(refresh: true),
            )
          : ListView(
              children: [
                if (cover != null && (cover.isLocal || cover.url.isNotEmpty))
                  SquareMediaImage(item: cover),
                Padding(
                  padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: AppLayout.scaled(context, 22),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      SizedBox(height: AppLayout.scaled(context, 8)),
                      Text(
                        post.author.title,
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: AppLayout.scaled(context, 13),
                        ),
                      ),
                      SizedBox(height: AppLayout.scaled(context, 16)),
                      ..._buildBody(media),
                      if (!post.isLocal || post.chainBlock != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SquareLikesStrip(
                              postId: post.postId,
                              api: _api,
                              sessions: _sessionProvider,
                            ),
                            Comments(
                              postId: post.postId,
                              api: _api,
                              sessionProvider: _sessionProvider,
                              initialCommentId: widget.initialCommentId,
                              notificationThrough: widget.notificationThrough,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
    if (_loading || _loadError != null) return content;
    return MembershipBusinessGate(
      localContent: _verifiedLocal,
      sessionProvider: _sessionProvider,
      client: _api,
      child: content,
    );
  }

  /// 每个规范段落先渲染富文本，再渲染该段落的可选媒体。
  List<Widget> _buildBody(List<SquareMediaItem> media) {
    final sections = post.contentSections;
    if (sections.isEmpty) return const <Widget>[];
    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(ArticleRichTextView(delta: section.textDelta));
      final mediaIndices = section.galleryMediaIndices;
      if (mediaIndices != null) {
        final gallery = <SquareMediaItem>[];
        for (final mediaIndex in mediaIndices) {
          if (mediaIndex >= 0 && mediaIndex < media.length) {
            final item = media[mediaIndex];
            if (item.mediaKind == SquareMediaKind.image &&
                (item.isLocal || item.url.isNotEmpty)) {
              gallery.add(item);
            }
          }
        }
        if (gallery.isNotEmpty) widgets.add(_bodyGallery(gallery));
      } else if (section.videoMediaIndex case final mediaIndex?) {
        if (mediaIndex >= 0 && mediaIndex < media.length) {
          widgets.add(_bodyVideo(media[mediaIndex]));
        }
      }
    }
    return widgets;
  }

  Widget _bodyGallery(List<SquareMediaItem> items) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(8)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SquareMediaCarousel(
        children: [for (final item in items) SquareMediaImage(item: item)],
      ),
    ),
  );

  Widget _bodyVideo(SquareMediaItem item) => Padding(
    padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(8)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SquareVideo(
          url: item.url,

          thumbnailUrl: item.previewUrl,
          item: item,
        ),
      ),
    ),
  );

  Future<void> _handleAction(_ArticleDetailAction action) async {
    if (_loading || _loadError != null) return;
    switch (action) {
      case _ArticleDetailAction.edit:
        await _editArticle();
        break;
      case _ArticleDetailAction.delete:
        await _deleteArticle();
        break;
    }
  }

  Future<void> _editArticle() async {
    final replacement = await Navigator.of(context).push<SquarePost>(
      MaterialPageRoute<SquarePost>(
        builder: (_) => CitizenServiceGate(
          title: '编辑内容',
          description: '注册后即可编辑广场内容。',
          child: SquareComposePage(
            postType: SquarePostType.article,
            initialTitle: post.title,
            initialText: post.text,
            replaceId: post.postId,
            initialVisibility: post.postVisibility,
          ),
        ),
      ),
    );
    if (replacement == null || !mounted) return;
    Navigator.of(context).pop(SquarePostDetailResult(replacement: replacement));
  }

  Future<void> _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除文章'),
        content: const Text('删除后将清理本地及远端的正文和媒体。链上发布记录保持不变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final session = await _sessionProvider.ensureSession();
      if (session == null) {
        throw const SquareApiException('请先选择默认热钱包');
      }
      final authorCidNumber = post.author.cidNumber;
      if (authorCidNumber == null || authorCidNumber.isEmpty) {
        throw const SquareApiException('只能删除本人文章');
      }
      await _deletionCoordinator.delete(
        session: session,
        cidNumber: authorCidNumber,
        postId: post.postId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已删除'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      Navigator.of(context).pop(const SquarePostDetailResult(deleted: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _DetailLoadError extends StatelessWidget {
  const _DetailLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('文章加载失败：$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
