import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/contacts/contact_sort.dart';

void main() {
  test('备注仅允许汉字及英文字母，可留空', () {
    for (final value in ['', '张三', 'Alice', '张Alice', '重庆']) {
      expect(validateContactRemark(value), value);
    }
    for (final value in ['张三1', 'John Doe', '备注。', ' A', '朋友🙂', 'a\nb']) {
      expect(() => validateContactRemark(value), throwsFormatException);
    }
    expect(() => validateContactRemark('中' * 41), throwsFormatException);
  });
  test('数字首位在前，汉字按拼音首字母，英文忽略大小写', () {
    final values = [
      ('张三', '9'),
      ('alice', '3'),
      ('', '20'),
      ('Bob', '4'),
      ('重庆', '5'),
      ('', '10'),
    ];
    values.sort((a, b) => compareContactKeys(a.$1, a.$2, b.$1, b.$2));
    expect(values.map((v) => v.$1), ['', '', 'alice', 'Bob', '重庆', '张三']);
    expect(values.take(2).map((v) => v.$2), ['10', '20']);
    expect(compareContactKeys('alice', '2', 'Alice', '3'), lessThan(0));
  });
}
