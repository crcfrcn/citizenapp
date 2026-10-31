import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/update/app_update_manifest.dart';

void main() {
  test('显示设备原生版本，不把构建号拼成另一版号', () {
    const value = AppVersionInfo(
      packageName: 'app',
      versionName: '1.2.3',
      versionCode: 99,
    );
    expect(value.label, 'v1.2.3');
  });
  test('商店版本按数值比较，Apple短版本等价于末尾零', () {
    expect(newerVersion('1.0.10', '1.0.9'), isTrue);
    expect(newerVersion('1.1', '1.0.99'), isTrue);
    expect(newerVersion('1.0', '1.0.0'), isFalse);
    expect(newerVersion('1.0.0', '1.0'), isFalse);
    expect(newerVersion('0.9.9', '1.0.0'), isFalse);
  });
  for (final value in [
    '',
    '01.0.0',
    'v1.0.0',
    '1.0.0-rc1',
    '1.0.0.1',
    '1.0/',
    ' 1.0',
  ]) {
    test(
      '拒绝无效商店版本$value',
      () => expect(() => versionParts(value), throwsFormatException),
    );
  }
}
