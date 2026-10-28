import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/mls_authentication.dart';
import 'package:citizenapp/system/security/system_protected_storage.dart';
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
        response.regId,
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
      orgCode: 'NATP',
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
      orgCode: 'CTZN',
      chainScope: '0x${'22' * 32}',
    );
    final old = record(c);
    final value = old.next(
      response: RegistrationResponse.parse(
        registrationResponse(c, jobState: 'human_verified'),
        c,
      ),
      phase: RegistrationPhase.finalized,
      finalized: FinalizedRegistration(
        binding: IdentityBinding(
          genesisHash: c.chainScope,
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindRev: 1,
          accountId: c.accountId,
        ),
        blockHash: '0x${'44' * 32}',
      ),
    );
    await store().save(null, value);
    final identity = MlsAuthenticationIdentity(
      cidNumber: value.finalized!.binding.cidNumber,
      accountId: c.accountId,
      bindRev: 1,
      deviceId: '33' * 32,
      publicKey: '0x${'33' * 32}',
    );
    expect(
      await store().forDevice(identity, chainScope: '0x${'55' * 32}'),
      isNull,
    );
    expect(
      (await store().forDevice(identity, chainScope: c.chainScope))?.regId,
      value.capabilities.regId,
    );
    expect(await store().hasPendingAccount(c.accountId, c.chainScope), true);
    final ready = value.next(phase: RegistrationPhase.ready);
    await store().save(value, ready);
    expect(
      await store().forDevice(identity, chainScope: c.chainScope),
      isNull,
      reason: '已完成公民号使用普通设备准备，不再消费真人登记能力',
    );
    await store().save(ready, value);
    await expectLater(
      store().save(value, value.next(checkpoint: {'private_key': 'secret'})),
      throwsFormatException,
    );
    expect((await store().read(c))?.checkpoint, isNull);
  });
  test('过期真人登记能力不交付；已有公民号改用普通准备，不重复验证', () async {
    final c = registrationContext();
    final json = registrationResponse(c, jobState: 'human_verified');
    json['created_at'] = 1;
    json['human_at'] = 2;
    json['expires_at'] = 3;
    final value = record(c).next(
      response: RegistrationResponse.parse(json, c),
      phase: RegistrationPhase.finalized,
      finalized: FinalizedRegistration(
        binding: IdentityBinding(
          genesisHash: c.chainScope,
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindRev: 1,
          accountId: c.accountId,
        ),
        blockHash: '0x${'44' * 32}',
      ),
    );
    await store().save(null, value);
    expect(
      await store().forDevice(
        MlsAuthenticationIdentity(
          cidNumber: value.finalized!.binding.cidNumber,
          accountId: c.accountId,
          bindRev: 1,
          deviceId: '33' * 32,
          publicKey: '0x${'33' * 32}',
        ),
        chainScope: c.chainScope,
      ),
      isNull,
    );
    expect(
      (await store().read(c))!.response.jobState,
      RegistrationState.humanVerified,
      reason: '不能把过期或故障改写为假的真人通过或没有CID',
    );
  });
  test('公开序列化白名单不保存Turnstile token或私钥', () {
    final value = record();
    final text = value.encode();
    final raw = jsonDecode(text) as Map<String, dynamic>;
    expect(raw.containsKey('capabilities'), false);
    expect(raw.containsKey('record_version'), false);
    expect(raw['recovery_token'], value.capabilities.recoveryToken);
    expect((raw['response'] as Map)['reg_id'], value.capabilities.regId);
    final wrong = RegistrationRecord(
      context: value.context,
      capabilities: RegistrationCapabilities(
        'other',
        value.capabilities.recoveryToken,
      ),
      response: value.response,
    );
    expect(wrong.encode, throwsFormatException);
    expect(text, isNot(contains('turnstile_token')));
    expect(text, isNot(contains('private_key')));
    expect(RegistrationRecord.decode(text).encode(), text);
  });
  test('旧注册快照与混合字段都拒绝，读取原样保留恢复能力及检查点', () async {
    final value = record();
    Map<String, dynamic> legacy() {
      final data = jsonDecode(value.encode()) as Map<String, dynamic>;
      data.remove('record_version');
      final response = data['response'] as Map<String, dynamic>;
      response['context_hash'] = value.context.contextHash;
      for (final entry in {
        'job_state': 'state',
        'is_ok': 'ok',
        'created_at': 'created_at_millis',
        'expires_at': 'expires_at_millis',
        'human_at': 'human_at_millis',
      }.entries) {
        response[entry.value] = response.remove(entry.key);
      }
      final verification = response['verification'];
      if (verification is Map<String, dynamic>) {
        verification['page_expires_at_millis'] = verification.remove(
          'page_expires_at',
        );
      }
      return data;
    }

    final records = SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    );
    final raw = jsonEncode(legacy());
    expect(
      await records.compareAndSet(
        value.context.contextHash,
        expected: null,
        next: raw,
      ),
      true,
    );
    await expectLater(store().read(value.context), throwsFormatException);
    expect(await records.read(value.context.contextHash), raw);
    final invalid = legacy();
    (invalid['response'] as Map)['is_ok'] = true;
    final mixed = jsonEncode(invalid);
    expect(
      await records.compareAndSet(
        value.context.contextHash,
        expected: raw,
        next: mixed,
      ),
      true,
    );
    await expectLater(store().read(value.context), throwsFormatException);
    expect(await records.read(value.context.contextHash), mixed);
  });
  test('旧版本标记和旧状态拒绝读取，混合字段不被改写', () async {
    final value = record();
    final data = jsonDecode(value.encode()) as Map<String, dynamic>;
    data['record_version'] = 2;
    final response = data['response'] as Map<String, dynamic>;
    response['state'] = response.remove('job_state');
    final raw = jsonEncode(data);
    final records = SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    );
    expect(
      await records.compareAndSet(
        value.context.contextHash,
        expected: null,
        next: raw,
      ),
      true,
    );
    await expectLater(store().read(value.context), throwsFormatException);
    expect(await records.read(value.context.contextHash), raw);
    response['job_state'] = response['state'];
    final mixed = jsonEncode(data);
    expect(
      await records.compareAndSet(
        value.context.contextHash,
        expected: raw,
        next: mixed,
      ),
      true,
    );
    await expectLater(store().read(value.context), throwsFormatException);
    expect(await records.read(value.context.contextHash), mixed);
  });
}
