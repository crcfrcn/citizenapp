import 'package:citizen_testing/platform_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('平台夹具拒绝跨目录和非平台路径', () {
    for (final path in ['ios/../outside', 'android/./file', 'lib/main.dart', 'ios//file']) {
      expect(() => platformInput(path), throwsArgumentError, reason: path);
    }
  });
  test('缺失平台原件不能伪造为空文本', () {
    expect(() => platformInput('ios/no-such-platform-input'), throwsStateError);
  });
}
