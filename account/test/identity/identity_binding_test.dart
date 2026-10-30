import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/public_identity_store.dart';

class _Records implements PublicIdentityRecordStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) async {
    if (values[key] != expected) return false;
    if (next == null) {
      values.remove(key);
    } else {
      values[key] = next;
    }
    return true;
  }
}

IdentityBinding binding(String cid, int revision, String account) =>
    IdentityBinding(
      genesisHash: '0x${'11' * 32}',
      cidNumber: cid,
      bindRev: revision,
      accountId: account,
    );

void main() {
  test('公开绑定严格拒绝多余字段、无效CID和非规范账户', () {
    final current = binding('CID-A', 1, '0x${'22' * 32}');
    expect(
      IdentityBinding.fromJson(jsonEncode(current.toJson()))!.cidNumber,
      'CID-A',
    );
    expect(
      IdentityBinding.fromJson(
        jsonEncode({...current.toJson(), 'extra': true}),
      ),
      isNull,
    );
    expect(
      () => binding('CID:A', 1, current.accountId).validate(),
      throwsFormatException,
    );
    expect(
      () => binding('CID-A', 0, current.accountId).validate(),
      throwsFormatException,
    );
  });
  test('多实例CAS保留两个CID，版本不得回退或同版换账户', () async {
    final records = _Records();
    final a = PublicIdentityStore(records), b = PublicIdentityStore(records);
    await Future.wait([
      a.activate(binding('CID-A', 1, '0x${'22' * 32}')),
      b.activate(binding('CID-B', 1, '0x${'33' * 32}')),
    ]);
    expect(
      (await a.readAll()).map((item) => item.cidNumber),
      unorderedEquals(['CID-A', 'CID-B']),
    );
    final saved = jsonDecode(records.values['identity.bindings']!) as List;
    expect(
      saved.map((item) => (item as Map)['cid_number']),
      unorderedEquals(['CID-A', 'CID-B']),
    );
    await a.activate(binding('CID-A', 2, '0x${'44' * 32}'));
    await expectLater(
      b.activate(binding('CID-A', 1, '0x${'22' * 32}')),
      throwsStateError,
    );
    await expectLater(
      b.activate(binding('CID-A', 2, '0x${'55' * 32}')),
      throwsStateError,
    );
    await a.clearForCid('CID-A');
    expect(await b.readForCid('CID-A'), isNull);
    expect((await b.readForCid('CID-B'))!.accountId, '0x${'33' * 32}');
  });
  test('重复CID和旧对象索引拒绝且原值保持', () async {
    final records = _Records();
    final value = binding('CID-A', 1, '0x${'22' * 32}').toJson();
    final store = PublicIdentityStore(records);
    for (final raw in [
      jsonEncode([value, value]),
      jsonEncode({'CID-A': value}),
    ]) {
      records.values['identity.bindings'] = raw;
      await expectLater(store.readAll(), throwsFormatException);
      expect(records.values['identity.bindings'], raw);
    }
  });
}
