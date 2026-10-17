import 'dart:convert';
import 'dart:io';

/// 回读平台唯一输入清单中的原字节，供静态契约测试使用。
String platformInput(String destination) {
  final platform = destination.split('/').first;
  if (platform != 'ios' && platform != 'android') {
    throw ArgumentError.value(destination, 'destination', '未知平台');
  }
  final source = File('$platform/platform.mjs').readAsStringSync();
  final marker = '  ${jsonEncode(destination)}: ';
  final entry = source.indexOf(marker);
  if (entry < 0) throw StateError('平台输入缺失：$destination');
  var valueStart = entry + marker.length;
  if (!source.startsWith('[\n', valueStart)) {
    // 同字节的多个平台消费文件共用一个声明，测试也回读这一唯一原件。
    final reference = RegExp(r'^[A-Za-z][A-Za-z0-9]*')
        .firstMatch(source.substring(valueStart));
    if (reference == null) throw StateError('平台输入引用无效：$destination');
    final declaration = 'const ${reference.group(0)} = [\n';
    final position = source.indexOf(declaration);
    if (position < 0) throw StateError('平台输入声明缺失：$destination');
    valueStart = position + declaration.length;
  } else {
    valueStart += 2;
  }
  const suffix = '\n  ].join("\\n")';
  var end = source.indexOf(suffix, valueStart);
  if (end < 0) end = source.indexOf('\n].join("\\n")', valueStart);
  if (end < 0) throw StateError('平台输入格式无效：$destination');
  final lines = jsonDecode('[${source.substring(valueStart, end)}]') as List;
  if (lines.any((line) => line is! String)) {
    throw StateError('平台输入内容无效：$destination');
  }
  return lines.cast<String>().join('\n');
}
