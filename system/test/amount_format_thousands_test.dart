import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:citizen_system/amount_format.dart';

void main() {
  group('ThousandSeparatorFormatter', () {
    test('输入插入千分位后光标仍在末尾', () {
      final value = ThousandSeparatorFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1234.50',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(value.text, '1,234.50');
      expect(value.selection.baseOffset, 8);
    });
    test('中间插入数字后光标跟随有效字符', () {
      final value = ThousandSeparatorFormatter().formatEditUpdate(
        const TextEditingValue(
          text: '1,234.50',
          selection: TextSelection.collapsed(offset: 2),
        ),
        const TextEditingValue(
          text: '1,9234.50',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(value.text, '19,234.50');
      expect(value.selection.baseOffset, 2);
    });
    test('非法字符与超出小数位的输入保留原值', () {
      const old = TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 5),
      );
      final formatter = ThousandSeparatorFormatter();
      for (final text in ['12x', '12.345']) {
        expect(
          formatter.formatEditUpdate(old, TextEditingValue(text: text)),
          same(old),
        );
      }
      expect(
        formatter.formatEditUpdate(old, TextEditingValue.empty),
        same(TextEditingValue.empty),
      );
    });
  });
}
