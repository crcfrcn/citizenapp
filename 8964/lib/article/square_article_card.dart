import 'package:citizen_square/media/square_media_grid.dart';
import 'package:flutter/material.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/post/square_post_actions.dart';
import 'package:citizen_square/post/square_post_header.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
