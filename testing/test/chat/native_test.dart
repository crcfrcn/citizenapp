// 验证加载本轮原生库及成功检查结果复用。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/chat/native.dart';

void main() {
  test('原生检查真实加载本轮库，重复检查复用成功结果', () {
    requireMlsTestLibrary();
    requireMlsTestLibrary();
  });
}
