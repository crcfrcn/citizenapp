import 'package:flutter/material.dart';

import 'package:citizenapp/system/theme/app_theme.dart';
import 'package:citizenapp/system/theme/app_layout.dart';

/// 广场卡片底部互动栏（点赞 / 评论 / 收藏），图片/视频/文章卡共用同一版式。
class SquarePostActions extends StatelessWidget {
  const SquarePostActions({super.key, this.onComment});
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.thumb_up_alt_outlined,
          size: AppLayout.scaled(context, 18),
          color: AppTheme.textTertiary,
        ),
        SizedBox(width: AppLayout.scaled(context, 18)),
        Tooltip(
          message: '评论',
          child: InkResponse(
            onTap: onComment,
            radius: AppLayout.scaled(context, 24),
            child: Icon(
              Icons.mode_comment_outlined,
              size: AppLayout.scaled(context, 18),
              color: AppTheme.textTertiary,
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
  }
}
