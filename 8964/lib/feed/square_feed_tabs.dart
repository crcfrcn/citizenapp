import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 广场分类栏：全部分类均支持长按拖动，松手后由页面持久保存顺序。
class SquareFeedTabs extends StatelessWidget {
  const SquareFeedTabs({
    super.key,
    required this.selected,
    required this.onChanged,
    this.followingUnread = 0,
    this.notificationsUnread = 0,
    this.order = SquareFeedKind.values,
    this.onReorder,
  });

  final SquareFeedKind selected;
  final ValueChanged<SquareFeedKind> onChanged;
  final List<SquareFeedKind> order;
  final void Function(int from, int to)? onReorder;

  /// 关注子 tab 红点数（我未静音关注在关注游标之后的新帖数）；0=不显示。
  final int followingUnread;
  final int notificationsUnread;

  static IconData iconFor(SquareFeedKind kind) => switch (kind) {
    SquareFeedKind.recommended => Icons.explore_outlined,
    SquareFeedKind.circle => Icons.diversity_3_outlined,
    SquareFeedKind.notifications => Icons.forum_outlined,
    SquareFeedKind.following => Icons.people_alt_outlined,
    SquareFeedKind.campaign => Icons.campaign_outlined,
    SquareFeedKind.article => Icons.article_outlined,
    SquareFeedKind.videos => Icons.videocam_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppLayout.scaled(context, 4)),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(13)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = TextPainter(
            text: TextSpan(
              text: '公民圈',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 12),
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = math.max(
            constraints.maxWidth / order.length,
            text.width + 8,
          );
          text.dispose();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < order.length; index++)
                  SizedBox(
                    key: ValueKey('square-tab-${order[index].name}'),
                    width: width,
                    child: DragTarget<SquareFeedKind>(
                      onWillAcceptWithDetails: (details) =>
                          onReorder != null && details.data != order[index],
                      onAcceptWithDetails: (details) =>
                          onReorder?.call(order.indexOf(details.data), index),
                      builder: (context, candidates, rejected) {
                        final kind = order[index];
                        final child = _SquareFeedTab(
                          kind: kind,
                          selected: kind == selected,
                          unread: kind == SquareFeedKind.following
                              ? followingUnread
                              : kind == SquareFeedKind.notifications
                              ? notificationsUnread
                              : 0,
                          onTap: () => onChanged(kind),
                        );
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: candidates.isEmpty
                                ? Colors.transparent
                                : AppTheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(
                              AppLayout.scaledValue(10),
                            ),
                          ),
                          child: LongPressDraggable<SquareFeedKind>(
                            data: kind,
                            axis: Axis.horizontal,
                            maxSimultaneousDrags: onReorder == null ? 0 : 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(width: width, child: child),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: child,
                            ),
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SquareFeedTab extends StatelessWidget {
  const _SquareFeedTab({
    required this.kind,
    required this.selected,
    required this.onTap,
    this.unread = 0,
  });

  final SquareFeedKind kind;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: AppLayout.scaled(context, 6)),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
          // 选中/未选都保留 1px 边框（未选透明），避免切换时因边框有无产生宽高抖动。
          border: Border.all(
            color: selected
                ? AppTheme.primary.withAlpha(40)
                : Colors.transparent,
          ),
        ),
        // 图标与文字竖排；大字体超出可用宽度时分类栏可横向滚动。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: unread > 0,
              label: Text(
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(fontSize: AppLayout.scaled(context, 9)),
              ),
              child: Icon(
                SquareFeedTabs.iconFor(kind),
                size: AppLayout.scaled(context, 17),
                color: color,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 3)),
            Text(
              kind.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 12),
                height: 1.0,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
