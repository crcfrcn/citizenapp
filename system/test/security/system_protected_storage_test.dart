import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/security/system_protected_storage.dart';

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
  Future<Directory> fixtureRoot() async {
    final temporary = await Directory.systemTemp.createTemp('citizen_channel_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    return root;
  }

  test('生产提交不持Dart外层文件锁，等待回执期间仍能调度其他任务', () async {
    final root = await fixtureRoot();
    final entered = Completer<void>();
    final reply = Completer<bool>();
    messenger.setMockMethodCallHandler(SystemProtectedStorage.channel, (
      call,
    ) async {
      if (call.method == 'prepareRecords') return root.path;
      expect(call.method, 'compareRecords');
      final args = call.arguments as Map;
      expect(args['name'], 'identity.json');
      expect(args['expected'], isNull);
      expect(jsonDecode(args['next'] as String), {'record': 'synthetic'});
      // 原生是唯一锁所有者，Dart不能先创建并持有同名锁后再等平台回执。
      expect(await File('${root.path}/identity.json.lock').exists(), isFalse);
      entered.complete();
      return reply.future;
    });
    final writing = SystemProtectedRecordStore('identity.json')
        .write('record', 'synthetic');
    await entered.future.timeout(const Duration(seconds: 2));
    var scheduled = false;
    await Future<void>(() => scheduled = true);
    expect(scheduled, isTrue);
    reply.complete(true);
    await writing;
  });

  test('原生CAS拒绝、无回执或抛错都不能确认提交，失败后可主动重试', () async {
    final root = await fixtureRoot();
    var attempt = 0;
    messenger.setMockMethodCallHandler(SystemProtectedStorage.channel, (
      call,
    ) async {
      if (call.method == 'prepareRecords') return root.path;
      expect(call.method, 'compareRecords');
      return switch (attempt++) {
        0 => false,
        1 => null,
        2 => throw PlatformException(code: 'system_protection_unavailable'),
        _ => true,
      };
    });
    final records = SystemProtectedRecordStore('identity.json');
    await expectLater(records.write('record', 'synthetic'), throwsStateError);
    await expectLater(records.write('record', 'synthetic'), throwsStateError);
    await expectLater(
      records.write('record', 'synthetic'),
      throwsA(isA<PlatformException>()),
    );
    await records.write('record', 'synthetic');
    expect(attempt, 4);
  });

  test('原生完整快照冲突保留他人提交，CAS返回false，普通写入明确失败', () async {
    final root = await fixtureRoot();
    final file = File('${root.path}/identity.json');
    await file.writeAsString('{"record":"before"}');
    var calls = 0;
    messenger.setMockMethodCallHandler(SystemProtectedStorage.channel, (
      call,
    ) async {
      if (call.method == 'prepareRecords') return root.path;
      final args = call.arguments as Map;
      // 在Dart读取之后模拟另一个isolate已经提交；原生不得覆盖它。
      await file.writeAsString('{"record":"other"}');
      calls++;
      return args['expected'] == await file.readAsString();
    });
    final records = SystemProtectedRecordStore('identity.json');
    expect(
      await records.compareAndSet('record', expected: 'before', next: 'mine'),
      isFalse,
    );
    await file.writeAsString('{"record":"before"}');
    await expectLater(records.write('record', 'mine'), throwsStateError);
    expect(await records.read('record'), 'other');
    expect(calls, 2);
  });

  test('关闭后迟到的原生回执不得确认写入或重新开放队列', () async {
    final root = await fixtureRoot();
    final entered = Completer<void>();
    final reply = Completer<bool>();
    messenger.setMockMethodCallHandler(SystemProtectedStorage.channel, (
      call,
    ) async {
      if (call.method == 'prepareRecords') return root.path;
      entered.complete();
      return reply.future;
    });
    final records = SystemProtectedRecordStore('identity.json');
    final writing = records.write('record', 'synthetic');
    final rejected = expectLater(writing, throwsStateError);
    await entered.future;
    records.close();
    reply.complete(true);
    await rejected;
    await expectLater(records.read('record'), throwsStateError);
  });
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
  test('topup准确主记录名可用，但任意路径和辅助文件不能充当主记录',() async {
    var calls=0;messenger.setMockMethodCallHandler(SystemProtectedStorage.channel,(_) async {calls++;throw PlatformException(code:'fixture');});
    await expectLater(SystemProtectedRecordStore('topup.json').read('order'),throwsA(isA<PlatformException>()));expect(calls,1);
    for(final name in ['../topup.json','topup.json.part','topup.json.lock']){await expectLater(SystemProtectedRecordStore(name).read('order'),throwsArgumentError);}
    expect(calls,1);
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
