// 展示帖子卡片和作者标题，保留原操作与资料入口。

import 'package:citizen_square/interaction/actions.dart';
import 'package:citizen_square/media/view.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_user/profile/data.dart' show CitizenProfile;
import 'package:citizen_user/profile/data.dart'
    show
        CitizenProfileCache,
        CitizenProfileMediaCache,
        CitizenProfileMediaSnapshot;
import 'package:citizen_user/profile/page.dart' show ProfileAvatar;
import 'package:flutter/material.dart';

// 按信息流或详情模式展示公文和视频及其竞选变体。

/// 动态流与详情页的显示模式。
enum SquarePostCardDisplayMode { feed, detail }

/// 广场公文/视频卡（含竞选变体）。
///
/// 公文固定“正文 → 照片”，视频固定“封面 → 配文”。Feed 中公文正文最多 3 行、
/// 视频配文最多 2 行，真实溢出才显示展开入口；详情页显示完整文字。
class SquarePostCard extends StatelessWidget {
  const SquarePostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.avatarUrl,

    this.avatarImage,

    this.displayMode = SquarePostCardDisplayMode.feed,
  });

  final SquarePost post;
  final VoidCallback? onTap;

  /// 点击作者头像/名进入其用户主页。
  final VoidCallback? onAuthorTap;

  /// 作者头像地址；实际请求由当前会话的受保护读取器拥有。
  final String? avatarUrl;

  /// 完整资料媒体的签名读取器；不携带可复用的一次性证明头。
  final ImageProvider? avatarImage;

  final SquarePostCardDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
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
              _buildBody(context),
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

  Widget _buildBody(BuildContext context) {
    final media = post.mediaItems;
    final caption = post.text.trim();
    final isVideo = post.postType == SquarePostType.video;

    if (media.isEmpty) {
      if (caption.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: AppLayout.scaledValue(12)),
        child: _caption(context, caption, isVideo: isVideo),
      );
    }

    final mediaWidget = SquareMediaGrid(
      mediaItems: media,

      enableVideoPlayback: displayMode == SquarePostCardDisplayMode.detail,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVideo) ...[
          SizedBox(height: AppLayout.scaledValue(12)),
          mediaWidget,
          if (caption.isNotEmpty) ...[
            SizedBox(height: AppLayout.scaledValue(12)),
            _caption(context, caption, isVideo: true),
          ],
        ] else ...[
          if (caption.isNotEmpty) ...[
            SizedBox(height: AppLayout.scaledValue(12)),
            _caption(context, caption, isVideo: false),
          ],
          SizedBox(height: AppLayout.scaledValue(12)),
          mediaWidget,
        ],
      ],
    );
  }

  Widget _caption(BuildContext context, String text, {required bool isVideo}) {
    final style = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: AppLayout.scaledValue(15),
      height: 1.45,
    );
    if (displayMode == SquarePostCardDisplayMode.detail) {
      return Text(text, style: style);
    }
    return _ExpandableFeedText(
      key: ValueKey('${post.postType.workerValue}-feed-text'),
      text: text,
      style: style,
      maxLines: isVideo ? 2 : 3,
      expandLabel: isVideo ? '展开' : '展开全文',
      onExpand: onTap,
    );
  }
}

/// 按当前真实宽度、系统字体倍率和字体样式判断文字是否溢出，禁止用字符数猜测。
class _ExpandableFeedText extends StatelessWidget {
  const _ExpandableFeedText({
    super.key,
    required this.text,
    required this.style,
    required this.maxLines,
    required this.expandLabel,
    this.onExpand,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final String expandLabel;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflowed = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              key: ValueKey('$expandLabel-text'),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            if (overflowed)
              Semantics(
                button: true,
                label: expandLabel,
                child: InkWell(
                  key: ValueKey('$expandLabel-action'),
                  onTap: onExpand,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: AppLayout.scaledValue(4),
                      right: AppLayout.scaledValue(8),
                      bottom: AppLayout.scaledValue(4),
                    ),
                    child: Text(
                      expandLabel,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: AppLayout.scaledValue(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// 统一展示作者头像、身份徽章、竞选信息和更多操作。

/// 广场卡片统一作者头部：方形圆角头像 + 右下角扇贝身份勋章、昵称、
/// 竞选药丸（仅竞选公民）、竞选岗位/时间、右上角更多按钮。
///
/// 图片/视频/文章及其竞选变体共用同一头部，保证身份表达一致。
class SquarePostHeader extends StatefulWidget {
  const SquarePostHeader({
    super.key,
    required this.post,
    this.onAuthorTap,
    this.onMore,
    this.avatarUrl,

    this.avatarImage,
  });

  final SquarePost post;

  /// 点击头像/昵称区进入作者主页。
  final VoidCallback? onAuthorTap;

  /// 右上角更多菜单；为 null 时按钮仍展示但不响应。
  final VoidCallback? onMore;

  /// 作者头像已解析的可读地址（由页面据 avatar_key + session 生成）；
  /// 用户已设置但缺失时保留占位，只有从未设置才显示稳定默认照片。
  final String? avatarUrl;

  /// 完整资料媒体的签名读取器；不携带可复用的一次性证明头。
  final ImageProvider? avatarImage;

  @override
  State<SquarePostHeader> createState() => _SquarePostHeaderState();
}

class _SquarePostHeaderState extends State<SquarePostHeader> {
  CitizenProfile? _profile;
  CitizenProfileMediaSnapshot _media = const CitizenProfileMediaSnapshot();
  int _generation = 0;
  SquarePost get post => widget.post;
  bool get _isCampaign => post.postCategory == SquarePostCategory.campaign;

  @override
  void initState() {
    super.initState();
    CitizenProfileCache.revision.addListener(_changed);
    _readLocal();
  }

  void _changed() {
    if (CitizenProfileCache.revision.value?.cidNumber ==
        post.author.cidNumber) {
      _readLocal();
    }
  }

  @override
  void didUpdateWidget(covariant SquarePostHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLocal != post.isLocal ||
        oldWidget.post.author.cidNumber != post.author.cidNumber) {
      _profile = null;
      _media = const CitizenProfileMediaSnapshot();
      _readLocal();
    }
  }

  /// 本人帖子作者资料复用UserIsar入口；头部更新不获取会话或远端图片。
  Future<void> _readLocal() async {
    final generation = ++_generation;
    final cid = post.author.cidNumber;
    if (!post.isLocal || cid == null) return;
    try {
      final profile = await const CitizenProfileCache().read(cid);
      if (profile?.cidNumber != cid) return;
      final media = await CitizenProfileMediaCache().read(profile!);
      if (mounted && generation == _generation) {
        setState(() {
          _profile = profile;
          _media = media;
        });
      }
    } catch (_) {
      /* 保留既有显示，不下载或写入第二套资料。 */
    }
  }

  @override
  void dispose() {
    _generation++;
    CitizenProfileCache.revision.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Row(
      // start 对齐让更多按钮贴近卡片上边缘。
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onAuthorTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                ProfileAvatar(
                  // 头像稳定种子按身份主键 cid_number（与资料页一致，换绑不变）；
                  // cid 缺失（本地草稿等）回落当前账户。
                  seed: author.cidNumber ?? author.accountId,
                  size: AppLayout.scaled(context, 40),
                  imagePath: _media.avatarPath,
                  imageUrl: post.isLocal ? null : widget.avatarUrl,

                  imageProvider: post.isLocal ? null : widget.avatarImage,
                  userImageSet:
                      (_profile?.avatarKey ?? author.avatarKey)?.isNotEmpty ==
                      true,
                  cidLevel: _profile?.cidLevel ?? author.cidLevel,
                  memberLevel: _profile?.memberLevel ?? author.memberLevel,
                  membergateActive:
                      _profile?.membergateActive ?? author.membergateActive,
                  borderRadius: 12,
                ),
                SizedBox(width: AppLayout.scaled(context, 11)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _profile?.displayName.trim().isNotEmpty == true
                                  ? _profile!.displayName
                                  : author.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: AppLayout.scaled(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // 药丸只有竞选公民显示；投票/访客靠头像勋章表达。
                          if (_isCampaign) ...[
                            SizedBox(width: AppLayout.scaled(context, 6)),
                            const _CampaignPill(),
                          ],
                        ],
                      ),
                      SizedBox(height: AppLayout.scaled(context, 2)),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: AppLayout.scaled(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onMore,
          icon: Icon(
            Icons.more_horiz,
            size: AppLayout.scaled(context, 20),
            color: AppTheme.textTertiary,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: AppLayout.scaled(context, 28),
            minHeight: AppLayout.scaled(context, 20),
          ),
          visualDensity: VisualDensity.compact,
          tooltip: '更多',
        ),
      ],
    );
  }

  /// 竞选岗位只有竞选公民且有值时展示，否则只显示时间。
  String _subtitle() {
    final time = _formatCreatedAt(post.publishedAt);
    final position = post.campaignPosition?.trim();
    if (_isCampaign && position != null && position.isNotEmpty) {
      return '$position · $time';
    }
    return time;
  }

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}

class _CampaignPill extends StatelessWidget {
  const _CampaignPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 7),
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: AppTheme.danger.withAlpha(0x1F),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(20)),
      ),
      child: Text(
        '竞选',
        style: TextStyle(
          color: AppTheme.danger,
          fontSize: AppLayout.scaled(context, 11),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
