// 以可选择文本显示CID，复制时保持完整原文。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'identity_cid_display.dart';

/// 与原 SelectableText 相同的显示/选择交互，复制仍取完整原文。
class IdentityCidSelectableText extends StatefulWidget {
  const IdentityCidSelectableText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  State<IdentityCidSelectableText> createState() =>
      _IdentityCidSelectableTextState();
}

class _IdentityCidSelectableTextState extends State<IdentityCidSelectableText> {
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  void _copy() {
    if (_selection.isCollapsed) return;
    Clipboard.setData(
      ClipboardData(
        text: identityCidSelectionText(
          widget.data,
          _selection.start,
          _selection.end,
        ),
      ),
    );
    ContextMenuController.removeAny();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyC, control: true): _copy,
      const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _copy,
    },
    child: SelectableText(
      formatIdentityCidText(widget.data),
      style: widget.style,
      textAlign: widget.textAlign,
      onSelectionChanged: (selection, _) => _selection = selection,
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: [
              for (final item in state.contextMenuButtonItems)
                if (item.type == ContextMenuButtonType.copy)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: _copy,
                  )
                else
                  item,
            ],
          ),
    ),
  );
}
