import 'package:lpinyin/lpinyin.dart';

/// 备注仅限汉字和英文字母；排序键不含时间或公开昵称。
String validateContactRemark(String value) {
  if (value.runes.length > 40 ||
      !RegExp(r'^[A-Za-z\p{Script=Han}]*$', unicode: true).hasMatch(value)) {
    throw const FormatException('备注只能输入中英文，最多40字，可留空');
  }
  return value;
}

String _phonetic(String value) => PinyinHelper.getPinyinE(
  value,
  separator: '',
  defPinyin: '#',
  format: PinyinFormat.WITHOUT_TONE,
).toUpperCase();

int compareContactKeys(
  String remarkA,
  String cidA,
  String remarkB,
  String cidB,
) {
  String key(String remark, String cid) {
    if (remark.isEmpty) {
      final first = RegExp(r'[0-9]').firstMatch(cid)?.group(0);
      return first == null ? '2$cid' : '0$first';
    }
    final pinyin = _phonetic(remark);
    return '1${pinyin.isEmpty ? '#' : pinyin.substring(0, 1)}';
  }

  var result = key(remarkA, cidA).compareTo(key(remarkB, cidB));
  if (result != 0) return result;
  result = _phonetic(remarkA).compareTo(_phonetic(remarkB));
  if (result != 0) return result;
  final nA = BigInt.tryParse(cidA), nB = BigInt.tryParse(cidB);
  return nA != null && nB != null ? nA.compareTo(nB) : cidA.compareTo(cidB);
}
