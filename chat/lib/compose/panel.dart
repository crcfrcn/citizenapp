// 展示聊天动作、表情及贴纸选择面板。

import 'dart:math' as math;

import 'package:chat/compose/sticker.dart';
import 'package:citizen_system/theme.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

// 展示聊天功能面板及各动作图标和选择回调。

/// Default action set for a direct or group conversation.
enum ChatComposerAction {
  gallery,
  capture,
  videoCall,
  voiceCall,
  transfer,
  location,
  file,
}

/// Allows a host to replace one icon without owning the panel layout.
///
/// Return null to use 公民聊天's default Material icon.
typedef ChatComposerActionIconBuilder = Widget? Function(
  BuildContext context,
  ChatComposerAction action,
  Color color,
  double size,
);

/// Four-column action grid. Group conversations hide transfer and disable calls.
class ComposerActionPanel extends StatelessWidget {
  const ComposerActionPanel({
    super.key,
    required this.isGroup,
    required this.onAction,
    this.callsEnabled = false,
    this.iconBuilder,
  });

  final bool isGroup;
  final bool callsEnabled;
  final ValueChanged<ChatComposerAction> onAction;
  final ChatComposerActionIconBuilder? iconBuilder;

  static const _items = <_ActionItem>[
    _ActionItem(ChatComposerAction.gallery, Icons.photo_library_rounded, '相册'),
    _ActionItem(ChatComposerAction.capture, Icons.photo_camera_rounded, '拍摄'),
    _ActionItem(ChatComposerAction.videoCall, Icons.videocam_rounded, '视频通话'),
    _ActionItem(ChatComposerAction.voiceCall, Icons.call_rounded, '语音通话'),
    _ActionItem(
      ChatComposerAction.transfer,
      Icons.currency_exchange_rounded,
      '转账',
    ),
    _ActionItem(
      ChatComposerAction.location,
      Icons.location_on_rounded,
      '位置',
      unavailable: true,
    ),
    _ActionItem(ChatComposerAction.file, Icons.insert_drive_file_rounded, '文件'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in _items)
        if (!(isGroup && item.action == ChatComposerAction.transfer))
          item.copyWith(
            disabled:
                (!callsEnabled || isGroup) &&
                (item.action == ChatComposerAction.videoCall ||
                    item.action == ChatComposerAction.voiceCall),
          ),
    ];
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('chat-composer-action-panel'),
      color: colors.surface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 18),
          AppLayout.scaled(context, 22),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: AppLayout.scaled(context, 86),
          mainAxisSpacing: AppLayout.scaled(context, 12),
          crossAxisSpacing: AppLayout.scaled(context, 14),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _ActionButton(
          item: items[index],
          iconBuilder: iconBuilder,
          onTap: () => onAction(items[index].action),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.onTap,
    this.iconBuilder,
  });

  final _ActionItem item;
  final VoidCallback onTap;
  final ChatComposerActionIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = item.unavailable || item.disabled
        ? colors.onSurfaceVariant.withValues(alpha: 0.48)
        : colors.onSurface;
    final iconSize = AppLayout.scaled(context, 25);
    final customIcon = iconBuilder?.call(
      context,
      item.action,
      foreground,
      iconSize,
    );
    return Semantics(
      button: true,
      enabled: !item.disabled,
      label: item.disabled
          ? '${item.label}，暂不支持'
          : item.unavailable
          ? '${item.label}，功能完善中'
          : item.label,
      child: InkWell(
        key: ValueKey('chat-action-${item.action.name}'),
        borderRadius: BorderRadius.circular(AppLayout.scaled(context, 14)),
        onTap: item.disabled ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppLayout.scaled(context, 56),
              height: AppLayout.scaled(context, 56),
              decoration: BoxDecoration(
                color: item.unavailable
                    ? colors.surfaceContainerHigh.withValues(alpha: 0.6)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  AppLayout.scaled(context, 14),
                ),
              ),
              alignment: Alignment.center,
              child:
                  customIcon ??
                  Icon(item.icon, size: iconSize, color: foreground),
            ),
            SizedBox(height: AppLayout.scaled(context, 6)),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: AppLayout.scaled(context, 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(
    this.action,
    this.icon,
    this.label, {
    this.unavailable = false,
    this.disabled = false,
  });

  final ChatComposerAction action;
  final IconData icon;
  final String label;
  final bool unavailable;
  final bool disabled;

  _ActionItem copyWith({bool? disabled}) => _ActionItem(
    action,
    icon,
    label,
    unavailable: unavailable,
    disabled: disabled ?? this.disabled,
  );
}

// 展示并切换聊天表情与贴纸选择面板。

enum ChatComposerPanel { none, expression, actions }

enum ChatExpressionTab { emoji, sticker }

/// Reusable emoji/sticker panel. Product entitlement remains a host concern.
class ChatExpressionPanel extends StatelessWidget {
  const ChatExpressionPanel({
    super.key,
    required this.controller,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onStickerPick,
    required this.onSendText,
  });

  final TextEditingController controller;
  final ChatExpressionTab selectedTab;
  final ValueChanged<ChatExpressionTab> onTabChanged;
  final void Function(String packId, String stickerId) onStickerPick;
  final ValueChanged<String> onSendText;

  @override
  Widget build(BuildContext context) {
    final height = math.min(304.0, MediaQuery.sizeOf(context).height * 0.44);
    return SizedBox(
      key: const ValueKey('chat-expression-panel'),
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: AppLayout.scaled(context, 42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tabButton(context, ChatExpressionTab.emoji, '表情'),
                SizedBox(width: AppLayout.scaled(context, 18)),
                _tabButton(context, ChatExpressionTab.sticker, '贴纸'),
              ],
            ),
          ),
          Expanded(
            child: selectedTab == ChatExpressionTab.emoji
                ? Column(
                    children: [
                      Expanded(
                        child: EmojiPicker(
                          key: const ValueKey('chat-emoji-picker'),
                          textEditingController: controller,
                          config: Config(
                            height: height - AppLayout.scaled(context, 90),
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              columns: 8,
                              backgroundColor: AppTheme.surfaceCard,
                            ),
                            categoryViewConfig: CategoryViewConfig(
                              backgroundColor: AppTheme.surfaceCard,
                              indicatorColor: AppTheme.accent,
                              iconColorSelected: AppTheme.accent,
                              backspaceColor: AppTheme.accent,
                            ),
                            bottomActionBarConfig: const BottomActionBarConfig(
                              enabled: false,
                            ),
                          ),
                        ),
                      ),
                      _bottomActionBar(context),
                    ],
                  )
                : StickerPanel(
                    height: height - AppLayout.scaled(context, 42),
                    onPick: onStickerPick,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActionBar(BuildContext context) {
    return SizedBox(
      height: AppLayout.scaled(context, 48),
      child: ColoredBox(
        color: AppTheme.surfaceCard,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BackspaceButton(
              key: const ValueKey('chat-emoji-backspace'),
              const Config(),
              () => _deleteText(deleteWord: false),
              () => _deleteText(deleteWord: true),
              AppTheme.textSecondary,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) => IconButton(
                key: const ValueKey('chat-emoji-send'),
                tooltip: '发送',
                color: AppTheme.accent,
                disabledColor: AppTheme.textTertiary,
                onPressed: value.text.trim().isEmpty ? null : _sendDraft,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, ChatExpressionTab tab, String label) {
    final selected = selectedTab == tab;
    return TextButton(
      key: ValueKey('chat-expression-${tab.name}'),
      onPressed: () => onTabChanged(tab),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.accent : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  void _deleteText({required bool deleteWord}) {
    final value = controller.value;
    final text = value.text;
    if (text.isEmpty) return;
    final selection = value.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final start = hasSelection
        ? math.min(selection.start, selection.end)
        : (selection.isValid ? selection.extentOffset : text.length).clamp(
            0,
            text.length,
          );
    final end = hasSelection ? math.max(selection.start, selection.end) : start;
    if (hasSelection) {
      final next = text.replaceRange(start, end, '');
      controller.value = value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }
    if (start == 0) return;
    final before = text.substring(0, start);
    final retained = deleteWord
        ? before.replaceFirst(RegExp(r'(?:\s+|\S+\s*)$'), '')
        : before.characters.skipLast(1).toString();
    final next = '$retained${text.substring(start)}';
    controller.value = value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: retained.length),
      composing: TextRange.empty,
    );
  }

  void _sendDraft() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    onSendText(text);
  }
}
