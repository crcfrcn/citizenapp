import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/security/system_protected_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      SystemProtectedStorage.channel,
      null,
    ),
  );
  test('未知记录名仍拒绝，不向原生提交', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(SystemProtectedStorage.channel, (
      _,
    ) async {
      calls++;
      return '/invalid';
    });
    await expectLater(
      SystemProtectedRecordStore('unknown.json').read('cap'),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
  test('原生保护失败向上抛出，不能获得可用目录', () async {
    messenger.setMockMethodCallHandler(
      SystemProtectedStorage.channel,
      (_) async =>
          throw PlatformException(code: 'system_protection_unavailable'),
    );
    await expectLater(
      SystemProtectedStorage.recordsDirectory(),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      SystemProtectedStorage.protectUserDatabase('/unowned'),
      throwsA(isA<PlatformException>()),
    );
  });
  test('拒绝相对路径和符号链接目录', () async {
    messenger.setMockMethodCallHandler(
      SystemProtectedStorage.channel,
      (_) async => 'relative',
    );
    await expectLater(
      SystemProtectedStorage.recordsDirectory(),
      throwsStateError,
    );
    final temp = await Directory.systemTemp.createTemp('citizen_policy_');
    final root = Directory(await temp.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final target = await Directory('${root.path}/target').create();
    final link = Link('${root.path}/link');
    await link.create(target.path);
    messenger.setMockMethodCallHandler(
      SystemProtectedStorage.channel,
      (_) async => link.path,
    );
    await expectLater(
      SystemProtectedStorage.recordsDirectory(),
      throwsStateError,
    );
  });
}
