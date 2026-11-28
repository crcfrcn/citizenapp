// 验证受保护存储及失败处理。

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/security/storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  group('system_protected_record_store_test', recordTests);
  group('system_protected_storage_test', storageTests);
}

// 验证受保护记录CAS、跨实例并发、损坏和链接拒绝及全量擦除。

void recordTests() {
  late Directory root;
  setUp(() async {
    final created = await Directory.systemTemp.createTemp('citizen_records_');
    root = Directory(await created.resolveSymbolicLinks());
  });
  tearDown(() => root.delete(recursive: true));
  SystemProtectedRecordStore store() => SystemProtectedRecordStore(
    'identity.json',
    directory: () async => root.path,
  );

  test('registration独立记录CAS和全量擦除读回', () async {
    final registration = SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    );
    final identity = store();
    await identity.write('public', 'binding');
    await registration.write('capability', 'protected');
    expect(await identity.read('capability'), isNull);
    await registration.deleteAll();
    expect(await registration.readAll(), isEmpty);
    expect(await identity.read('public'), 'binding');
  });
  test('多实例并发CAS只有一个胜者，重建读取已提交值', () async {
    final a = store(), b = store();
    final result = await Future.wait([
      a.compareAndSet('record', expected: null, next: 'a'),
      b.compareAndSet('record', expected: null, next: 'b'),
    ]);
    expect(result.where((value) => value), hasLength(1));
    expect(await store().read('record'), result.first ? 'a' : 'b');
  });
  test('损坏和超限写入失败后队列释放，修复合成记录后可重试', () async {
    final records = store();
    final file = File('${root.path}/identity.json');
    await file.writeAsString('{');
    await expectLater(records.write('record', 'failed'), throwsFormatException);
    // 只修复本测试的合成夹具；生产代码不得以清空记录绕过损坏。
    await file.writeAsString('{}');
    await expectLater(
      records.write('record', 'x' * 262144),
      throwsFormatException,
    );
    expect(await file.readAsString(), '{}');
    await records.write('record', 'retry');
    expect(await records.read('record'), 'retry');
    expect(await File('${root.path}/identity.json.part').exists(), isFalse);
    expect(await File('${root.path}/identity.json.lock').exists(), isFalse);
  });
  test('删除、清空和CAS未命中保持完整记录语义', () async {
    final records = store();
    await records.write('a', 'one');
    await records.write('b', 'two');
    expect(
      await records.compareAndSet('a', expected: 'wrong', next: 'lost'),
      isFalse,
    );
    expect(await records.readAll(), {'a': 'one', 'b': 'two'});
    expect(await records.compareAndSet('a', expected: 'one'), isTrue);
    await records.delete('missing');
    expect(await records.readAll(), {'b': 'two'});
    await records.deleteAll();
    expect(await records.readAll(), isEmpty);
  });
  test('未提交残片不能覆盖完整记录；损坏主文件失败关闭', () async {
    final records = store();
    await records.write('record', 'committed');
    await File('${root.path}/identity.json.part').writeAsString('incomplete');
    expect(await records.read('record'), 'committed');
    await File('${root.path}/identity.json').writeAsString('{');
    await expectLater(records.read('record'), throwsFormatException);
  });
  test('链接文件拒绝，关闭期间晚到目录结果不得写入', () async {
    final outside = File('${root.path}/outside');
    await outside.writeAsString('owned fixture');
    await Link('${root.path}/identity.json').create(outside.path);
    await expectLater(store().read('record'), throwsStateError);
    await Link('${root.path}/identity.json').delete();
    final gate = Completer<String>();
    final records = SystemProtectedRecordStore(
      'identity.json',
      directory: () => gate.future,
    );
    final writing = records.write('record', 'late');
    records.close();
    gate.complete(root.path);
    await expectLater(writing, throwsStateError);
    expect(await File('${root.path}/identity.json').exists(), false);
  });
}

// 验证原生唯一锁、提交回执、冲突和关闭后的迟到写入隔离。

void storageTests() {
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
    final writing = SystemProtectedRecordStore(
      'identity.json',
    ).write('record', 'synthetic');
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
