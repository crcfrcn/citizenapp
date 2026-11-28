// 金额输入、CID格式及选择复制展示。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// 为金额输入插入千分位并校正光标，限制两位小数。

/// 金额输入框实时千分位格式化器。
///
/// 用户输入数字时自动插入千分位逗号，光标位置自动跟随。
/// 支持两位小数。
///
/// ```dart
/// TextField(
///   inputFormatters: [ThousandSeparatorFormatter()],
/// )
/// ```
class ThousandSeparatorFormatter extends TextInputFormatter {
  const ThousandSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final formatted = groupAmountInput(text);
    if (formatted == null) return oldValue;

    // 计算新光标位置：数光标左边有多少位数字/小数点，在新字符串中找到同样位置
    final oldCursor = newValue.selection.baseOffset.clamp(0, text.length);
    // 光标左侧在原文本中有多少"有效字符"（非逗号）
    int rawCount = 0;
    for (int i = 0; i < oldCursor && i < text.length; i++) {
      if (text[i] != ',') rawCount++;
    }
    // 在格式化后文本中找对应位置
    int newCursor = 0;
    int count = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (count >= rawCount) break;
      if (formatted[i] != ',') count++;
      newCursor = i + 1;
    }
    newCursor = newCursor.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}

// 缩写展示CID和系统标签，完整选区复制时恢复原始标识。

const identityCidLabel = '身份CID号';
final _identityCidPattern = RegExp(
  r'(?<![A-Za-z0-9-])([A-Z0-9]{5}-[A-Z0-9]{5}-[0-9]{9})-[0-9]{4,10}(?![A-Za-z0-9-])',
);

String formatIdentityCidText(String value) =>
    value.replaceAllMapped(_identityCidPattern, (match) => match.group(1)!);

/// 仅用于系统标签/提示；不用于昵称、聊天正文或用户文档。
String identityCidUiText(
  String value,
) => formatIdentityCidText(value).replaceAll(
  RegExp(
    r'机构身份CID号|身份\s*ID|(?:公民|居民|机构|身份)\s*CID(?:\s*(?:编号|号码|号))?|公民号|(?:身份\s*)?CID\s*(?:编号|号码|号)|\bCID(?![A-Za-z0-9_])',
  ),
  identityCidLabel,
);

/// 显示选区映射回原文；完整选中的短号仍复制完整 CID，其他选区原样保留。
String identityCidSelectionText(String original, int start, int end) {
  final display = formatIdentityCidText(original);
  if (start < 0 || end < start || end > display.length) return '';
  int originalOffset(int offset) {
    var hidden = 0;
    for (final match in _identityCidPattern.allMatches(original)) {
      final displayEnd = match.start - hidden + match.group(1)!.length;
      if (offset < displayEnd) break;
      hidden += match.group(0)!.length - match.group(1)!.length;
    }
    return offset + hidden;
  }

  return original.substring(originalOffset(start), originalOffset(end));
}

/// 按既有字段语义格式化确认页，用户备注、姓名和正文保持原文。
String identityCidFieldText(String key, String value) {
  const composite = {
    'admins',
    'governance_detail',
    'issuer',
    'target',
    'houses',
    'fee_payer_description',
    'execution_fee_payer_description',
    'operation_fee_payer_description',
    'contact_list',
  };
  return key == 'cid_number' ||
          key.endsWith('_cid_number') ||
          composite.contains(key)
      ? formatIdentityCidText(value)
      : value;
}

/// 已有中文审阅条目只在身份字段上隐藏年份，姓名和其他内容不改。
String identityCidReviewText(String label, String value) =>
    identityCidUiText(label).contains(identityCidLabel)
    ? formatIdentityCidText(value)
    : value;

// 以可选择文本显示CID，复制时保持完整原文。

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
