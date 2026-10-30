import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/security/system_protected_storage.dart';

void main() {
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
