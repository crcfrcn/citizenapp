import 'package:citizenapp/8964/feed/comments.dart';
import 'package:citizenapp/system/notifications/notifications.dart';
import 'package:citizenapp/8964/feed/square_post_store.dart';
import 'package:citizenapp/8964/feed/square_local_post_presenter.dart';
import 'package:citizenapp/8964/feed/square_post_sync_service.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';
import 'package:provider/provider.dart';

import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/8964/compose/compose_page.dart';
import 'package:citizenapp/account/identity/identity_register_guide.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/8964/feed/square_post_deletion_coordinator.dart';
import 'package:citizenapp/8964/feed/square_post_card.dart';
import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

/// 本页面编排广场帖子详情加载、链上索引展示以及编辑和删除入口；
/// 正文与媒体操作仍经 Square API 协调，钱包会话和区块链底层不在页面内实现。
class SquarePostDetailResult {
  const SquarePostDetailResult({this.deleted = false, this.replacement});

  final bool deleted;
  final SquarePost? replacement;
}

enum _PostDetailAction { edit, delete }

class SquarePostDetailPage extends StatefulWidget {
  const SquarePostDetailPage({
    super.key,
    required this.post,
    this.api,
    this.sessionProvider,
    this.deletionCoordinator,
    this.initialDetailLoaded = false,
    this.initialCommentId,
  });

  final SquarePost post;
  final bool initialDetailLoaded;
  final String? initialCommentId;
  final SquareApiClient? api;
  final SquareSessionProvider? sessionProvider;
  final SquarePostDeleteCoordinator? deletionCoordinator;

  @override
  State<SquarePostDetailPage> createState() => _SquarePostDetailPageState();
}

class _SquarePostDetailPageState extends State<SquarePostDetailPage> {
  late final SquareApiClient _api;
  late final SquareSessionProvider _sessionProvider;
  late final SquarePostDeleteCoordinator _deletionCoordinator;
  late SquarePost _post;
  bool _loading = true;
  Object? _loadError;
  bool _deleting = false;
  bool _dependenciesReady = false;

  SquarePost get post => _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _api = widget.api ?? SquareApiClient();
    _deletionCoordinator =
        widget.deletionCoordinator ??
        SquarePostDeletionCoordinator(remoteDeletion: _api);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    _dependenciesReady = true;
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      if (_post.isLocal) {
        final cid = _post.author.cidNumber!;
        if (refresh) {
          final session = await _sessionProvider.ensureSession();
          if (session == null || session.cidNumber != cid) {
            throw StateError('当前用户已变化');
          }
          await SquarePostSyncService().sync(
            session,
            userInitiated: true,
            isCurrent: () => mounted,
          );
        }
        final local = await const SquarePostStore().read(
          cidNumber: cid,
          postId: _post.postId,
        );
        if (local == null) throw StateError('本地尚未保存内容');
        final presentation = const SquareLocalPostPresenter().present(local);
        if (mounted) {
          setState(() {
            _post = presentation.post;
            _loading = false;
          });
        }
        return;
      }
      final session = await _sessionProvider.ensureSession();
      if (session == null) throw const SquareApiException('请先选择默认钱包账户');
      await SubscriptionService.requireSquareSession(session, client: _api);
      await Notifications.instance.restore();
      final notificationOwner = Notifications.instance.scope;
      await session.validateCurrent();
      if (notificationOwner != null &&
          (notificationOwner.cidNumber != session.cidNumber ||
              notificationOwner.bindRev != session.bindRev ||
              notificationOwner.accountId != session.accountId)) {
        throw StateError('内容详情身份已变化');
      }
      final detail = widget.initialDetailLoaded && !refresh
          ? _post
          : await _api.fetchPostDetail(session: session, summary: _post);
      if (!mounted ||
          (notificationOwner != null &&
              !Notifications.instance.isCurrent(notificationOwner))) {
        return;
      }
      setState(() {
        _post = detail;

        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          unawaited(
            Notifications.instance.read(
              owner: notificationOwner,
              postIds: [post.postId],
            ),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (refresh) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('刷新失败，已保留本地内容')));
      }
      setState(() {
        _loadError = refresh ? null : error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MembershipBusinessGate(
      localContent: post.isLocal,
      sessionProvider: _sessionProvider,
      client: _api,
      child: Scaffold(
        appBar: AppBar(
          title: Text(post.postType.label),
          actions: [
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : () => _loadDetail(refresh: true),
            ),
            PopupMenuButton<_PostDetailAction>(
              enabled: !_deleting,
              onSelected: _handleAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _PostDetailAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('修改'),
                  ),
                ),
                PopupMenuItem(
                  value: _PostDetailAction.delete,
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
            ? _PostDetailLoadError(
                error: _loadError!,
                onRetry: () => _loadDetail(refresh: true),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  SquarePostCard(
                    post: post,

                    displayMode: SquarePostCardDisplayMode.detail,
                  ),
                  if (!post.isLocal || post.chainBlock != null)
                    Comments(
                      postId: post.postId,
                      api: _api,
                      sessionProvider: _sessionProvider,
                      initialCommentId: widget.initialCommentId,
                    ),
                  SizedBox(height: AppLayout.scaled(context, 12)),
                  Container(
                    padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '链上索引',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: AppLayout.scaled(context, 15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: AppLayout.scaled(context, 10)),
                        _DetailRow(label: 'post_id', value: post.postId),
                        _DetailRow(
                          label: 'content_hash',
                          value: post.contentHash ?? '',
                        ),
                        _DetailRow(
                          label: 'storage_receipt_id',
                          value: post.receiptId ?? '',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleAction(_PostDetailAction action) async {
    switch (action) {
      case _PostDetailAction.edit:
        await _editPost();
        break;
      case _PostDetailAction.delete:
        await _deletePost();
        break;
    }
  }

  Future<void> _editPost() async {
    final replacement = await Navigator.of(context).push<SquarePost>(
      MaterialPageRoute<SquarePost>(
        builder: (_) => CitizenServiceGate(
          title: '编辑内容',
          description: '注册后即可编辑广场内容。',
          child: SquareComposePage(
            postType: post.postType,
            initialTitle: post.title,
            initialText: post.text,
            replaceId: post.postId,
          ),
        ),
      ),
    );
    if (replacement == null || !mounted) return;
    Navigator.of(context).pop(SquarePostDetailResult(replacement: replacement));
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除内容'),
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
        throw const SquareApiException('只能删除本人内容');
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppLayout.scaled(context, 120),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppLayout.scaled(context, 12),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppLayout.scaled(context, 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDetailLoadError extends StatelessWidget {
  const _PostDetailLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('内容加载失败：$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
