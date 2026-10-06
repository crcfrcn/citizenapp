import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/security/system_protected_storage.dart';

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

  test('多实例并发CAS只有一个胜者，重建读取已提交值', () async {
    final a = store(), b = store();
    final result = await Future.wait([
      a.compareAndSet('record', expected: null, next: 'a'),
      b.compareAndSet('record', expected: null, next: 'b'),
    ]);
    expect(result.where((value) => value), hasLength(1));
    expect(await store().read('record'), result.first ? 'a' : 'b');
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
