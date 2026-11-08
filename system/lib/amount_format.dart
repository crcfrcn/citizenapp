import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/services.dart';

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
