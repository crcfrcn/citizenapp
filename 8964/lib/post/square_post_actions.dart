import 'dart:async';

import 'package:provider/provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/notifications.dart';

import 'package:citizen_square/post/square_interaction_service.dart';

import 'package:flutter/material.dart';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
