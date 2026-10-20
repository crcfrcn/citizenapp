import 'dart:io';

/// 测试直接回读本轮普通工程中的真实平台文件，不解析构建脚本或模块。
String platformInput(String destination) {
  final parts = destination.split('/');
  if (!['ios', 'android'].contains(parts.first) ||
      parts.any((part) => part.isEmpty || part == '..' || part == '.')) {
    throw ArgumentError.value(destination, 'destination', '平台输入路径无效');
  }
  // 保留现有调用方的资源名称，读取Android实际的标准限定目录。
  final path = destination.replaceFirst('/res/values-en_', '/res/values-en/')
      .replaceFirst('/res/values-night_', '/res/values-night/');
  final file = File(path);
  if (!file.existsSync()) throw StateError('本轮平台输入缺失：$path');
  return file.readAsStringSync();
}
