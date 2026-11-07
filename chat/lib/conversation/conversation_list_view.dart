import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChatHeaderAction<T> {
  const ChatHeaderAction({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final Widget icon;
}

/// Reusable title and anchored action menu for a chat overview.
class ChatSectionHeader<T> extends StatelessWidget {
  const ChatSectionHeader({
    super.key,
    required this.actions,
    required this.onAction,
    this.title = '聊天',
  });

  final String title;
  final List<ChatHeaderAction<T>> actions;
  final ValueChanged<T> onAction;

  Future<void> _open(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final selected = await showGeneralDialog<T>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: '关闭新建菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, _, _) => _ChatEntryMenu<T>(
        anchorCenterX: origin.dx + box.size.width / 2,
        top: origin.dy + box.size.height + 2,
        actions: actions,
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (selected != null) onAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 24),
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Builder(
            builder: (buttonContext) => Container(
              key: const ValueKey('chat-add-button'),
              width: AppLayout.scaled(context, 28),
              height: AppLayout.scaled(context, 28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.25),
              ),
              child: IconButton(
                tooltip: '新建',
                padding: EdgeInsets.zero,
                iconSize: AppLayout.scaled(context, 16),
                constraints: BoxConstraints.tightFor(
                  width: AppLayout.scaled(context, 28),
                  height: AppLayout.scaled(context, 28),
                ),
                icon: Icon(Icons.add_rounded, color: AppTheme.primary),
                onPressed: () => _open(buttonContext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatConversationListItem {
  const ChatConversationListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.unreadCount,
    required this.leading,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime updatedAt;
  final int unreadCount;
  final Widget leading;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onLongPress;
}

/// Reusable conversation list, search entry, status and unread UI.
class ChatConversationOverview extends StatelessWidget {
  const ChatConversationOverview({
    super.key,
    required this.header,
    required this.onRefresh,
    required this.onSearch,
    required this.items,
    this.loading = false,
    this.errorMessage,
    this.unavailable,
    this.loadingLabel = '正在读取本地会话',
    this.emptyLabel = '暂无会话',
  });

  final Widget header;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;
  final List<ChatConversationListItem> items;
  final bool loading;
  final String? errorMessage;
  final Widget? unavailable;
  final String loadingLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: AppTheme.scaffoldBg,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: header),
                  if (errorMessage != null)
                    SliverToBoxAdapter(
                      child: _ErrorBanner(message: errorMessage!),
                    ),
                  SliverToBoxAdapter(child: _SearchEntry(onTap: onSearch)),
                  if (loading && items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ChatConversationPlaceholder(message: loadingLabel),
                    )
                  else if (unavailable != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: unavailable!,
                    )
                  else if (items.isNotEmpty)
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ConversationTile(
                        item: items[index],
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                      ),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ChatConversationPlaceholder(message: emptyLabel),
                    ),
                ],
              ),
            ),
            if (loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    key: const ValueKey('chat-sync-progress'),
                    minHeight: AppLayout.scaled(context, 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatConversationPlaceholder extends StatelessWidget {
  const ChatConversationPlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppLayout.scaled(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final ChatConversationListItem item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst
          ? Radius.circular(AppLayout.scaled(context, 12))
          : Radius.zero,
      bottom: isLast
          ? Radius.circular(AppLayout.scaled(context, 12))
          : Radius.zero,
    );
    return Dismissible(
      key: ValueKey('chat-conversation-${item.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteDismissBackground(),
      confirmDismiss: (_) async {
        await item.onDelete();
        return false;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaled(context, 16),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: radius,
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              onTap: item.onTap,
              onLongPress: item.onLongPress,
              child: Padding(
                padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
                child: Row(
                  children: [
                    item.leading,
                    SizedBox(width: AppLayout.scaled(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppLayout.scaled(context, 4)),
                          Text(
                            item.subtitle.trim().isEmpty
                                ? '暂无消息'
                                : item.subtitle.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppLayout.scaled(context, 13),
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          chatConversationTime(item.updatedAt),
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 12),
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (item.unreadCount > 0) ...[
                          SizedBox(height: AppLayout.scaled(context, 6)),
                          CircleAvatar(
                            radius: AppLayout.scaled(context, 10),
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              '${item.unreadCount}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppLayout.scaled(context, 11),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppLayout.scaled(context, 10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayout.scaled(context, 10)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 16),
              vertical: AppLayout.scaled(context, 12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: AppLayout.scaled(context, 20),
                  color: AppTheme.textTertiary,
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  child: Text(
                    '搜索会话、联系人和聊天记录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: AppLayout.scaled(context, 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteDismissBackground extends StatelessWidget {
  const _DeleteDismissBackground();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.scaled(context, 16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(AppLayout.scaled(context, 8)),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: AppLayout.scaled(context, 20)),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.danger,
          fontSize: AppLayout.scaled(context, 12),
        ),
      ),
    );
  }
}

class _ChatEntryMenu<T> extends StatelessWidget {
  const _ChatEntryMenu({
    required this.anchorCenterX,
    required this.top,
    required this.actions,
  });

  final double anchorCenterX;
  final double top;
  final List<ChatHeaderAction<T>> actions;

  static const double _width = 116;
  static const double _caretWidth = 14;
  static const double _caretHeight = 7;
  static const double _edgeGap = 8;
  static const double _panelRadius = 12;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // 按实际字形、文字倍率和图标测量，保留原基准最小宽度及屏幕边界。
    final labelStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Colors.white,
      fontSize: AppLayout.scaled(context, 15),
    );
    final maximumWidth = math.max(0.0, screenWidth - _edgeGap * 2);
    final contentInset =
        38 + AppLayout.scaled(context, 20) + AppLayout.scaled(context, 12);
    var labelWidth = 0.0;
    var labelHeight = 0.0;
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: labelStyle),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        locale: Localizations.localeOf(context),
      );
      try {
        painter.layout(maxWidth: math.max(0.0, maximumWidth - contentInset));
        labelWidth = math.max(labelWidth, painter.width);
        labelHeight = math.max(labelHeight, painter.height);
      } finally {
        painter.dispose();
      }
    }
    final width = math.min(
      maximumWidth,
      math.max(_width, (contentInset + labelWidth).ceilToDouble()),
    );
    // 正常行高仍为40基准像素；大字只补足文字空间，不裁切菜单文案。
    final rowHeight = math.max(
      AppLayout.scaled(context, 40),
      labelHeight.ceilToDouble() + AppLayout.scaled(context, 8),
    );
    final rawLeft = anchorCenterX - width + 24;
    final left = rawLeft.clamp(_edgeGap, screenWidth - width - _edgeGap);
    final caretCenter = (anchorCenterX - left).clamp(
      _panelRadius + _caretWidth / 2,
      width - _panelRadius - _caretWidth / 2,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: caretCenter - _caretWidth / 2),
                child: CustomPaint(
                  size: const Size(_caretWidth, _caretHeight),
                  painter: _CaretPainter(const Color(0xFF66727D)),
                ),
              ),
              Material(
                color: const Color(0xFF66727D),
                borderRadius: BorderRadius.circular(
                  AppLayout.scaled(context, 12),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: AppLayout.scaled(context, 4)),
                      for (final action in actions)
                        InkWell(
                          onTap: () =>
                              Navigator.of(context).pop<T>(action.value),
                          child: SizedBox(
                            height: rowHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: AppLayout.scaled(context, 20),
                                    height: AppLayout.scaled(context, 20),
                                    child: Center(child: action.icon),
                                  ),
                                  SizedBox(
                                    width: AppLayout.scaled(context, 12),
                                  ),
                                  Flexible(
                                    child: Text(
                                      action.label,
                                      style: labelStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: AppLayout.scaled(context, 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tipInset = 2.2;
    final half = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(half - tipInset, tipInset)
      ..quadraticBezierTo(half, 0, half + tipInset, tipInset)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}

String chatConversationTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (difference == 1) return '昨天';
  if (difference > 1 && difference < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}
