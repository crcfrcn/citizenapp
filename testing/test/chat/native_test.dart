import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/openmls_test_env.dart';

void main() {
  test('原生检查真实加载本轮库，重复检查复用成功结果', () {
    requireOpenMlsTestLibrary();
    requireOpenMlsTestLibrary();
  });
}
