import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:citizen_system/amount_format.dart';

/// AmountFormat.formatThousands 边界覆盖。
void main() {
  group('AmountFormat.formatThousands', () {
    test('零', () {
      expect(AmountFormat.formatThousands(0.0), '0.00');
    });

    test('正整数', () {
      expect(AmountFormat.formatThousands(1234567.89), '1,234,567.89');
    });

    test('负数', () {
      expect(AmountFormat.formatThousands(-1000.5), '-1,000.50');
    });

    test('小于千的正小数不带逗号', () {
      expect(AmountFormat.formatThousands(99.5), '99.50');
    });

    test('null 返回 --', () {
      expect(AmountFormat.formatThousands(null), '--');
    });

    test('NaN 返回 --', () {
      expect(AmountFormat.formatThousands(double.nan), '--');
    });

    test('Infinity 返回 --', () {
      expect(AmountFormat.formatThousands(double.infinity), '--');
    });

    test('负 Infinity 返回 --', () {
      expect(AmountFormat.formatThousands(double.negativeInfinity), '--');
    });

    test('自定义小数位 decimals=0 不带小数点', () {
      expect(AmountFormat.formatThousands(1234567.0, decimals: 0), '1,234,567');
    });

    test('亿级大数', () {
      expect(
        AmountFormat.formatThousands(123456789012.34),
        '123,456,789,012.34',
      );
    });
  });
  group('公共金额显示与输入', () {
    test('已有单位和超大整数均按原始字符串保留', () {
      expect(
        AmountFormat.formatString(
          '3402823669209384634633746074317682114.55 公民币',
        ),
        '3,402,823,669,209,384,634,633,746,074,317,682,114.55 公民币',
      );
      expect(AmountFormat.format(100), '100.00 元');
      expect(AmountFormat.format(100, symbol: ''), '100.00');
    });
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
