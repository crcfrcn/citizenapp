import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('本轮独立动态库真实导出头文件中的全部聊天FFI接口', () {
    final file = Platform.environment['MLS_TEST_LIBRARY'];
    expect(file, isNotNull, reason: '必须由本产品测试入口交付本轮真实原生库');
    final library = DynamicLibrary.open(file!);
    final header = File('chat/mls/mls.h').readAsStringSync();
    final names = RegExp(r'\b(mls_[a-z_]+)\s*\(')
        .allMatches(header)
        .map((value) => value.group(1)!)
        .toSet();
    expect(names.length, 10);
    for (final name in names) {
      expect(
        library.lookup<NativeFunction<Void Function()>>(name).address,
        isNot(0),
        reason: name,
      );
    }
    for (final name in [
      'mls_rekey_state_json',
      'mls_two_party_smoke_json',
      'mls_device_identity_json',
      'mls_encrypt_json',
      'mls_decrypt_json',
    ]) {
      expect(
        () => library.lookup<NativeFunction<Void Function()>>(name),
        throwsArgumentError,
        reason: '禁止重新导出退役接口$name',
      );
    }
  });
}
