import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_user/identity/registration_models.dart';
import 'package:citizen_user/identity/registration_store.dart';
import 'registration_api_test.dart' show registrationContext;
import 'registration_coordinator_test.dart' show chainResult;

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('registration_chain_');
    root = Directory(await root.resolveSymbolicLinks());
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  RegistrationStore store() => RegistrationStore(
    records: SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    ),
  );
  RegistrationRecord record() => RegistrationRecord(
    context: registrationContext(),
    checkpoint: {
      'preparation_id': 'p',
      'account_id': registrationContext().accountId,
      'call_data_hash': '0x${'cc' * 32}',
      'state': 'executing',
    },
    finalized: chainResult(),
  );
  test('原生保护记录CAS并发只有一个胜者，重启保留真实交易事实', () async {
    final value = record();
    final wins = await Future.wait([
      store().save(null, value).then((_) => true, onError: (_) => false),
      store().save(null, value).then((_) => true, onError: (_) => false),
    ]);
    expect(wins.where((v) => v), hasLength(1));
    expect(
      (await store().read(value.context))!.finalized!.txHash,
      value.finalized!.txHash,
    );
    expect(await File('${root.path}/registration.json.part').exists(), false);
  });
  test('链账户自然键不因切机构绕过交易；跨链隔离，损坏和链接拒绝', () async {
    await store().save(null, record());
    final c = registrationContext();
    final other = RegistrationContext(
      accountId: c.accountId,
      orgCode: 'NATP',
      chainScope: c.chainScope,
    );
    expect((await store().read(other))!.checkpoint, isNotNull);
    final otherChain = RegistrationContext(
      accountId: c.accountId,
      orgCode: c.orgCode,
      chainScope: '0x${'33' * 32}',
    );
    expect(await store().read(otherChain), isNull);
    await File('${root.path}/registration.json').writeAsString('{');
    await expectLater(store().read(c), throwsFormatException);
    await File('${root.path}/registration.json').delete();
    await Link('${root.path}/registration.json').create('${root.path}/outside');
    await expectLater(store().read(c), throwsStateError);
  });
  test('仅当前链记录闭集，不保存人验、登记凭据或接受附加字段', () async {
    final value = record(),
        raw = jsonDecode(record().encode()) as Map<String, dynamic>;
    for (final key in [
      'reg_id',
      'recovery_token',
      'turnstile_token',
      'response',
      'job_state',
    ]) {
      expect(
        () => RegistrationRecord.decode(jsonEncode({...raw, key: 'forbidden'})),
        throwsFormatException,
      );
    }
    final bad = RegistrationRecord(
      context: value.context,
      checkpoint: {...value.checkpoint!, 'signature': 'forbidden'},
    );
    await expectLater(store().save(null, bad), throwsFormatException);
    expect(await store().read(value.context), isNull);
  });
}
