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
  static const contentPadding = EdgeInsets.fromLTRB(20, 18, 24, 12);

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
      padding: contentPadding,
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
    this.isPinned = false,
    this.onTogglePin,
    this.onVoice,
    this.onVideo,
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
  final bool isPinned;
  final Future<void> Function()? onTogglePin;
  final VoidCallback? onVoice;
  final VoidCallback? onVideo;
}

/// Reusable conversation list, search entry, status and unread UI.
class ChatConversationOverview extends StatelessWidget {
  const ChatConversationOverview({
    super.key,
    required this.header,
    required this.onRefresh,
    required this.onSearch,
    required this.items,
  });

  final Widget header;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;
  final List<ChatConversationListItem> items;

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
                  SliverToBoxAdapter(child: _SearchEntry(onTap: onSearch)),
                  if (items.isNotEmpty)
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ConversationTile(
                        key: ValueKey(items[index].id),
                        item: items[index],
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    super.key,
    required this.item,
    required this.isFirst,
    required this.isLast,
  });
  final ChatConversationListItem item;
  final bool isFirst;
  final bool isLast;
  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  double _offset = 0;
  bool _dragging = false;
  bool _busy = false;
  static const _duration = Duration(milliseconds: 180);
  ChatConversationListItem get item => widget.item;

  /// 先收起卡片再执行动作，取消删除后恢复原位，并防止重复触发。
  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _dragging = false;
      _offset = 0;
    });
    await Future<void>.delayed(_duration);
    if (!mounted) return;
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(
    String label,
    IconData icon,
    Color color,
    Future<void> Function() action,
    double width, {
    double leftOverlap = 0,
    double rightOverlap = 0,
  }) => SizedBox(
    width: width,
    // 底色延伸到卡片圆角下方，由前景卡片遮盖形成同半径的互补圆弧。
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -leftOverlap,
          right: -rightOverlap,
          child: ColoredBox(color: color),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _busy ? null : () => _runAction(action),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: widget.isFirst
          ? Radius.circular(AppLayout.scaled(context, 12))
          : Radius.zero,
      bottom: widget.isLast
          ? Radius.circular(AppLayout.scaled(context, 12))
          : Radius.zero,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final actionWidth = math.min(AppLayout.scaled(context, 80), width * .3);
        final panelWidth = actionWidth * 2;
        return GestureDetector(
          key: ValueKey('chat-conversation-${item.id}'),
          onHorizontalDragStart: _busy
              ? null
              : (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: _busy
              ? null
              : (details) => setState(() {
                  _offset = (_offset + details.delta.dx).clamp(-width, width);
                }),
          onHorizontalDragCancel: () => setState(() {
            _dragging = false;
            _offset = 0;
          }),
          onHorizontalDragEnd: _busy
              ? null
              : (_) {
                  if (_offset.abs() >= width * .78) {
                    if (_offset < 0) {
                      _runAction(item.onDelete);
                    } else {
                      _runAction(() async {
                        item.onVoice?.call();
                      });
                    }
                  } else {
                    setState(() {
                      _dragging = false;
                      _offset = _offset.abs() < actionWidth / 2
                          ? 0
                          : (_offset < 0 ? -panelWidth : panelWidth);
                    });
                  }
                },
          child: ClipRect(
            child: Stack(
              children: [
                if (_offset != 0)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.scaled(context, 16),
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Align(
                          alignment: _offset < 0
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _offset < 0
                                ? [
                                    _action(
                                      item.isPinned ? '取消置顶' : '置顶',
                                      Icons.push_pin_outlined,
                                      Colors.orange.shade700,
                                      () async {
                                        await item.onTogglePin?.call();
                                      },
                                      actionWidth,
                                      leftOverlap: math.max(
                                        radius.topRight.x,
                                        radius.bottomRight.x,
                                      ),
                                    ),
                                    _action(
                                      '删除',
                                      Icons.delete_outline_rounded,
                                      Colors.red.shade600,
                                      item.onDelete,
                                      actionWidth,
                                    ),
                                  ]
                                : [
                                    _action(
                                      '语音',
                                      Icons.call_outlined,
                                      Colors.green.shade600,
                                      () async {
                                        item.onVoice?.call();
                                      },
                                      actionWidth,
                                    ),
                                    _action(
                                      '视频',
                                      Icons.videocam_outlined,
                                      Colors.blue.shade600,
                                      () async {
                                        item.onVideo?.call();
                                      },
                                      actionWidth,
                                      rightOverlap: math.max(
                                        radius.topLeft.x,
                                        radius.bottomLeft.x,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: _dragging ? Duration.zero : _duration,
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(_offset, 0, 0),
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
                          onTap: _busy
                              ? null
                              : () {
                                  if (_offset == 0) {
                                    item.onTap();
                                  } else {
                                    setState(() => _offset = 0);
                                  }
                                },
                          onLongPress: _busy || _offset != 0
                              ? null
                              : item.onLongPress,
                          child: Padding(
                            padding: EdgeInsets.all(
                              AppLayout.scaled(context, 14),
                            ),
                            child: Row(
                              children: [
                                item.leading,
                                SizedBox(width: AppLayout.scaled(context, 12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (item.isPinned) ...[
                                            SizedBox(
                                              width: AppLayout.scaled(
                                                context,
                                                4,
                                              ),
                                            ),
                                            Tooltip(
                                              message: '已置顶',
                                              child: Icon(
                                                Icons.push_pin_rounded,
                                                key: ValueKey(
                                                  'chat-pinned-${item.id}',
                                                ),
                                                size: AppLayout.scaled(
                                                  context,
                                                  16,
                                                ),
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      SizedBox(
                                        height: AppLayout.scaled(context, 4),
                                      ),
                                      Text(
                                        item.subtitle.trim().isEmpty
                                            ? '暂无消息'
                                            : item.subtitle.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: AppLayout.scaled(
                                            context,
                                            13,
                                          ),
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
                                      SizedBox(
                                        height: AppLayout.scaled(context, 6),
                                      ),
                                      CircleAvatar(
                                        radius: AppLayout.scaled(context, 10),
                                        backgroundColor: AppTheme.primary,
                                        child: Text(
                                          '${item.unreadCount}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: AppLayout.scaled(
                                              context,
                                              11,
                                            ),
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
                ),
              ],
            ),
          ),
        );
      },
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

/// 仅聊天Tab头部在真实连接失败时挂载；离页或连接成功后销毁动画。
class ChatConnectionIndicator extends StatefulWidget {
  const ChatConnectionIndicator({super.key});
  @override
  State<ChatConnectionIndicator> createState() =>
      _ChatConnectionIndicatorState();
}

class _ChatConnectionIndicatorState extends State<ChatConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) {
      final count = (_animation.value * 5).floor() + 1;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 41),
          const Text('连接中', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Opacity(
                  key: ValueKey('chat-connection-dot-$i'),
                  opacity: i < count ? 1 : 0,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: 3,
                      height: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
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
