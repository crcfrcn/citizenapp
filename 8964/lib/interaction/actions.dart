// 提交原帖子互动动作并展示对应操作组件。

import 'dart:async';

import 'package:citizen_system/theme.dart';
import 'package:citizen_user/api.dart' show SquareApiClient, SquareSession;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/notifications.dart'
    show NotificationScope, Notifications;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 按浏览者CID读写点赞、收藏等互动状态。

/// 互动状态按浏览者CID归属，不写入帖子manifest或改变信息流顺序。
class SquareInteractionService extends ChangeNotifier {
  static final instance = SquareInteractionService();
  final _states = <String, Map<String, dynamic>>{};
  final _busy = <String>{};
  final _versions = <String, int>{};
  final _pending = <String, Completer<void>>{};
  final _reading = <String, Future<void>>{};
  SquareApiClient? _api;
  SquareSessionProvider? _sessions;
  Map<String, dynamic>? state(String post) =>
      _states['${Notifications.instance.scope?.cidNumber}:$post'];
  bool busy(String post) =>
      _busy.contains('${Notifications.instance.scope?.cidNumber}:$post');
  Future<void> load(
    String post,
    SquareApiClient api,
    SquareSessionProvider sessions,
  ) {
    final existing = _pending[post];
    if (existing != null) return existing.future;
    _api = api;
    _sessions = sessions;
    final c = Completer<void>();
    _pending[post] = c;
    if (_pending.length == 1) scheduleMicrotask(_flush);
    return c.future;
  }

  Future<void> _flush() async {
    final work = Map<String, Completer<void>>.of(_pending);
    _pending.clear();
    final api = _api, sessions = _sessions;
    try {
      if (api == null ||
          sessions == null ||
          !await Notifications.instance.restore()) {
        return;
      }
      final session = await sessions.ensureSession();
      if (session == null) return;
      final owner = Notifications.instance.scope;
      if (owner == null ||
          owner.cidNumber != session.cidNumber ||
          owner.bindRev != session.bindRev) {
        return;
      }
      final ids = work.keys.toList();
      const batchSize = 8;
      for (var at = 0; at < ids.length; at += batchSize) {
        final versions = {
          for (final id in ids.skip(at).take(batchSize))
            '${session.cidNumber}:$id':
                _versions['${session.cidNumber}:$id'] ?? 0,
        };
        final result = await api.fetchPostInteractions(
          session: session,
          postIds: ids.skip(at).take(batchSize).toList(),
        );
        await session.validateCurrent();
        if (!Notifications.instance.isCurrent(owner)) return;
        for (final item in (result['items'] as List).whereType<Map>()) {
          final row = item.cast<String, dynamic>();
          final key = '${session.cidNumber}:${row['post_id']}';
          if (!_busy.contains(key) && (_versions[key] ?? 0) == versions[key]) {
            _states[key] = row;
          }
        }
      }
      notifyListeners();
    } on Object {
      /* 互动失败不阻断正文；用户可通过原下拉刷新重试。 */
    } finally {
      for (final c in work.values) {
        if (!c.isCompleted) c.complete();
      }
    }
  }

  void install(SquareSession session, Map<String, dynamic> row) {
    final owner = Notifications.instance.scope;
    if (owner == null ||
        owner.cidNumber != session.cidNumber ||
        owner.bindRev != session.bindRev) {
      return;
    }
    final post = row['post_id'];
    if (post is! String) return;
    final key = '${session.cidNumber}:$post';
    if (_busy.contains(key)) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    _states[key] = Map.unmodifiable({...?_states[key], ...row});
    notifyListeners();
  }

  Future<void> toggle(
    String post,
    SquareApiClient api,
    SquareSessionProvider sessions,
  ) async {
    if (!await Notifications.instance.restore()) throw StateError('当前身份不可用');
    final owner = Notifications.instance.scope!;
    final key = '${owner.cidNumber}:$post';
    if (!_busy.add(key)) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    notifyListeners();
    try {
      final session = await sessions.ensureSession();
      if (session == null ||
          session.cidNumber != owner.cidNumber ||
          session.bindRev != owner.bindRev) {
        throw StateError('身份已变化');
      }
      final result = await api.setLike(
        session: session,
        postId: post,
        liked:
            !(_states[key]?['liked_by_me'] == true ||
                _states[key]?['liked_by_me'] == 1),
      );
      await session.validateCurrent();
      if (Notifications.instance.isCurrent(owner)) {
        _states[key] = {
          ...?_states[key],
          ...(result['state'] as Map).cast<String, dynamic>(),
        };
      }
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  Future<void> viewed(String post, {int? through}) {
    final owner = Notifications.instance.scope;
    if (owner == null) return Future.value();
    final bound = through ?? Notifications.instance.through;
    final key = '$owner:$post:$bound';
    return _reading[key] ??= _viewed(
      post,
      owner,
      bound,
    ).whenComplete(() => _reading.remove(key));
  }

  Future<void> _viewed(
    String post,
    NotificationScope owner,
    int through,
  ) async {
    if (through <= 0) return;
    final key = '${owner.cidNumber}:$post';
    _versions[key] = (_versions[key] ?? 0) + 1;
    final queued = await Notifications.instance.read(
      owner: owner,
      scope: 'post',
      postId: post,
      through: through,
    );
    if (queued && Notifications.instance.isCurrent(owner)) {
      final key = '${owner.cidNumber}:$post';
      final previous = _states[key];
      if (previous != null && ((previous['through'] as int?) ?? 0) <= through) {
        _states[key] = {...previous, 'comment_unread': 0};
      }
      notifyListeners();
    }
  }
}

// 呈现帖子点赞、评论和收藏的共用互动栏。

/// 广场卡片底部互动栏（点赞 / 评论 / 收藏），图片/视频/文章卡共用同一版式。
class SquarePostActions extends StatefulWidget {
  const SquarePostActions({super.key, this.onComment, this.postId});
  final String? postId;
  final VoidCallback? onComment;

  @override
  State<SquarePostActions> createState() => _SquarePostActionsState();
}

class _SquarePostActionsState extends State<SquarePostActions> {
  final service = SquareInteractionService.instance;
  SquareApiClient? api;
  SquareSessionProvider? sessions;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      api = context.read<SquareApiClient>();
      sessions = context.read<SquareSessionProvider>();
    } on Object {
      /* 测试/离线展示允许没有业务提供器。 */
    }
    if (widget.postId != null && api != null && sessions != null) {
      unawaited(service.load(widget.postId!, api!, sessions!));
    }
  }

  @override
  void didUpdateWidget(covariant SquarePostActions old) {
    super.didUpdateWidget(old);
    if (old.postId != widget.postId &&
        widget.postId != null &&
        api != null &&
        sessions != null) {
      unawaited(service.load(widget.postId!, api!, sessions!));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([service, Notifications.instance]),
    builder: (context, _) {
      final state = widget.postId == null
          ? null
          : service.state(widget.postId!);
      final liked = state?['liked_by_me'] == true || state?['liked_by_me'] == 1;
      final unread = (state?['comment_unread'] as int?) ?? 0;
      final count = (state?['like_count'] as int?) ?? 0;

      return Row(
        children: [
          Tooltip(
            message: liked ? '取消点赞' : '点赞',
            child: InkResponse(
              onTap:
                  widget.postId == null ||
                      api == null ||
                      sessions == null ||
                      service.busy(widget.postId!)
                  ? null
                  : () async {
                      try {
                        await service.toggle(widget.postId!, api!, sessions!);
                      } on Object {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('点赞操作失败，请重试')),
                          );
                        }
                      }
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                    size: AppLayout.scaled(context, 18),
                    color: liked ? AppTheme.primary : AppTheme.textTertiary,
                  ),
                  if (count > 0) Text(' $count'),
                ],
              ),
            ),
          ),
          SizedBox(width: AppLayout.scaled(context, 18)),
          Tooltip(
            message: '评论',
            child: InkResponse(
              onTap: widget.onComment,
              radius: AppLayout.scaled(context, 24),
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: Icon(
                  Icons.mode_comment_outlined,
                  size: AppLayout.scaled(context, 18),
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ),
          SizedBox(width: AppLayout.scaled(context, 18)),
          Icon(
            Icons.bookmark_border_rounded,
            size: AppLayout.scaled(context, 18),
            color: AppTheme.textTertiary,
          ),
        ],
      );
    },
  );
}
