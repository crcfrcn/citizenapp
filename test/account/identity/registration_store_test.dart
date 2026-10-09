import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/security/system_protected_storage.dart';
import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/account/identity/registration_store.dart';

import 'registration_api_test.dart'
    show registrationContext, registrationResponse;

void main() {
  late Directory root;
  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('registration_records_');
    root = Directory(await temp.resolveSymbolicLinks());
  });
  tearDown(() => root.delete(recursive: true));
  RegistrationStore store() => RegistrationStore(
    records: SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    ),
  );
  RegistrationRecord record([RegistrationContext? context]) {
    final c = context ?? registrationContext();
    final response = RegistrationResponse.parse(
      registrationResponse(c, initial: true),
      c,
      initial: true,
    );
    return RegistrationRecord(
      context: c,
      capabilities: RegistrationCapabilities(
        response.enrollmentId,
        response.json['recovery_token'] as String,
      ),
      response: response,
    );
  }

  test('两实例CAS只有一个胜者；重启读回能力且identity文件不存在', () async {
    final value = record(), a = store(), b = store();
    final writes = await Future.wait([
      a.save(null, value).then((_) => true, onError: (_) => false),
      b.save(null, value).then((_) => true, onError: (_) => false),
    ]);
    expect(writes.where((v) => v), hasLength(1));
    expect(
      (await store().read(value.context))?.capabilities.recoveryToken,
      value.capabilities.recoveryToken,
    );
    expect(await File('${root.path}/identity.json').exists(), false);
    expect(await File('${root.path}/registration.json.part').exists(), false);
  });
  test('恢复上下文按账户/机构/genesis隔离；损坏或链接拒绝', () async {
    final value = record();
    await store().save(null, value);
    final other = RegistrationContext(
      accountId: value.context.accountId,
      institution: 'NATP',
      chainScope: value.context.chainScope,
    );
    expect(await store().read(other), isNull);
    await File('${root.path}/registration.json').writeAsString('{');
    await expectLater(store().read(value.context), throwsFormatException);
    await File('${root.path}/registration.json').delete();
    await Link('${root.path}/registration.json').create('${root.path}/outside');
    await expectLater(store().read(value.context), throwsStateError);
  });
  test('设备恢复能力只属于同链实际finalized账户；写入前拒绝秘密字段', () async {
    final c = RegistrationContext(
      accountId: '0x${'11' * 32}',
      institution: 'CTZN',
      chainScope: '0x${'22' * 32}',
    );
    final old = record(c);
    final value = old.next(
      response: RegistrationResponse.parse(
        registrationResponse(c, state: 'human_verified'),
        c,
      ),
      phase: RegistrationPhase.finalized,
      finalized: FinalizedRegistration(
        binding: IdentityBinding(
          genesisHash: c.chainScope,
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindingRevision: 1,
          accountId: c.accountId,
        ),
        blockHash: '0x${'44' * 32}',
      ),
    );
    await store().save(null, value);
    final identity = MlsAuthenticationIdentity(
      cidNumber: value.finalized!.binding.cidNumber,
      accountId: c.accountId,
      bindingRevision: 1,
      deviceId: '33' * 32,
      publicKey: '0x${'33' * 32}',
    );
    expect(
      await store().forDevice(identity, chainScope: '0x${'55' * 32}'),
      isNull,
    );
    expect(
      (await store().forDevice(
        identity,
        chainScope: c.chainScope,
      ))?.enrollmentId,
      value.capabilities.enrollmentId,
    );
    expect(await store().hasPendingAccount(c.accountId, c.chainScope), true);
    await expectLater(
      store().save(value, value.next(checkpoint: {'private_key': 'secret'})),
      throwsFormatException,
    );
    expect((await store().read(c))?.checkpoint, isNull);
  });
  test('公开序列化白名单不保存Turnstile token或私钥', () {
    final text = record().encode();
    expect(text, isNot(contains('turnstile_token')));
    expect(text, isNot(contains('private_key')));
    expect(RegistrationRecord.decode(text).encode(), text);
  });
}
