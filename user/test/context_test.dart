// 验证当前用户、公开绑定及按CID持久归属。

import 'package:citizen_system/security/access.dart';
import 'package:citizen_user/security.dart' show AccountSecurityService, PublicIdentityRecordStore, PublicIdentityStore;
import 'package:citizen_testing/sdk.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/context.dart' show CurrentUserContext, IdentityBinding;
import 'package:citizen_user/identity/state.dart' show IdentityBadgeSnapshot;
import 'dart:convert';
import 'package:citizen_storage/user.dart';
import 'package:citizen_storage/user.dart' as app_store show Entity;
import 'package:citizen_citizen/public/store.dart' show IsarPublicInstitutionStore;
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_testing/database.dart';

void main() {
  group('current_user_context_test', suite78);
  group('identity_binding_test', suite82);
  group('user_service_test', suite123);
}

// 验证默认账户精确绑定、并发读取合并及失效后的迟到拒绝。

const _hotId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _coldId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void suite78() {
  final core = TestCitizenSdkHarness();
  late AccountSecurityService security;

  setUp(() {
    security = AccountSecurityService(
      getWalletState: _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot))
          .getWalletState,
      signing: core.sdk,
      blobStore: _MemoryStore(),
      mlsDeviceRegistrar: _registerNothing,
      coldMlsDeviceBindingSigner: _rejectColdBinding,
    );
  });
  tearDown(() => security.dispose());

  test('只读取 SDK 顺序第一账户的精确绑定', () async {
    final requested = <String>[];
    final context = (() {
      final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (accountId) async {
          requested.add(accountId);
          return null;
        },
      );
    })();
    expect((await context.resolve())!.accountId, _hotId);
    expect(requested, [_hotId]);
  });

  test('缺绑定是未知，只有已核实空身份才是未注册', () async {
    for (final verified in [false, true]) {
      final context = (() {
        final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
        return CurrentUserContext(
          getWalletState: reads0.getWalletState,
          accountSecurity: security,
          bindingReader: (_) async => null,
          identityReader: (_) async => verified
              ? const IdentityBadgeSnapshot(
                  cidNumber: '',
                  cidLevel: 'visitor',
                  updatedAt: 1,
                  verified: true,
                )
              : null,
        );
      })();
      final current = (await context.resolve())!;
      expect(current.isRegistered, isFalse);
      expect(current.isUnregistered, verified);
    }
  });

  test('已核实未注册不会继续使用旧公开绑定', () async {
    final context = (() {
      final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) async => _binding(_hotId, 'CID-OLD'),
        identityReader: (_) async => const IdentityBadgeSnapshot(
          cidNumber: '',
          cidLevel: 'visitor',
          updatedAt: 1,
          verified: true,
        ),
      );
    })();
    final current = (await context.resolve())!;
    expect(current.binding, isNull);
    expect(current.isUnregistered, isTrue);
  });

  test('冷账户可以成为当前默认用户', () async {
    final context = (() {
      final reads0 = _FakeWallet(_account(_coldId, CitizenWalletSignMode.cold));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) async => _binding(_coldId, 'CID-COLD'),
      );
    })();
    final current = await context.resolve();
    expect(current!.account.signMode, CitizenWalletSignMode.cold);
    expect(current.cidNumber, 'CID-COLD');
  });

  test('并发读取合并，显式失效后重新精确读取', () async {
    var calls = 0;
    final completer = Completer<IdentityBinding?>();
    final context = (() {
      final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) {
          calls += 1;
          return calls == 1
              ? completer.future
              : Future.value(_binding(_hotId, 'CID-HOT'));
        },
      );
    })();
    final reads = [context.resolve(), context.resolve(), context.resolve()];
    completer.complete(_binding(_hotId, 'CID-HOT'));
    await Future.wait(reads);
    await context.resolve();
    expect(calls, 1);
    context.invalidate();
    expect((await context.resolve())!.cidNumber, 'CID-HOT');
    expect(calls, 2);
  });

  test('账户上下文失效后拒绝迟到绑定，不返回旧账户数据', () async {
    final completion = Completer<IdentityBinding?>();
    final context = (() {
      final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) => completion.future,
      );
    })();
    final pending = context.resolve();
    await Future<void>.delayed(Duration.zero);
    context.invalidate();
    completion.complete(_binding(_hotId, 'CID-HOT'));
    await expectLater(pending, throwsA(isA<AccountSecurityException>()));
  });

  test('重复激活同一会话绑定不广播身份变化且保留正在读取的快照', () async {
    final binding = _binding(_hotId, 'CID-HOT');
    Future<void> activate() => security.activateIdentityBinding(
      genesisHash: binding.genesisHash,
      cidNumber: binding.cidNumber,
      bindRev: binding.bindRev,
      accountId: binding.accountId,
    );
    await activate();
    final revision = security.revision.value;
    final completion = Completer<IdentityBinding?>();
    final context = (() {
      final reads0 = _FakeWallet(_account(_hotId, CitizenWalletSignMode.hot));
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) => completion.future,
      );
    })();
    final pending = context.resolve();
    await Future<void>.delayed(Duration.zero);
    await activate();
    expect(security.revision.value, revision);
    completion.complete(binding);
    expect((await pending)!.cidNumber, binding.cidNumber);
    await activate();
    expect(security.revision.value, revision);
  });

  test('SDK 账户目录为空时返回 null', () async {
    final context = (() {
      final reads0 = _FakeWallet(null);
      return CurrentUserContext(
        getWalletState: reads0.getWalletState,
        accountSecurity: security,
        bindingReader: (_) async => throw StateError('不应读取绑定'),
      );
    })();
    expect(await context.resolve(), isNull);
  });
}

CitizenWalletStateAccount _account(
  String accountId,
  CitizenWalletSignMode mode,
) => CitizenWalletStateAccount(
  signMode: mode,
  walletIndex: 0,
  accountIndex: mode == CitizenWalletSignMode.hot ? 0 : null,
  accountId: accountId,
  ss58Address: '${mode.name}-ss58',
  name: mode.name,
  createdAtMillis: BigInt.zero,
  isDefault: true,
);

IdentityBinding _binding(String accountId, String cid) => IdentityBinding(
  genesisHash: '0x${'11' * 32}',
  cidNumber: cid,
  bindRev: 1,
  accountId: accountId,
);

final class _FakeWallet extends TestWalletReads {
  _FakeWallet(this.account);
  final CitizenWalletStateAccount? account;

  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: account == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: account == null ? const [] : [account!],
        ),
      );
}

Future<void> _registerNothing({
  required String cidNumber,
  required int bindRev,
  required String accountId,
  required Future<String> Function({
    required Uint8List payload,
    required Uint8List signingMessage,
    required String publicKey,
    required int issuedAtMillis,
  })
  signBinding,
}) async {}

Future<String> _rejectColdBinding({
  required IdentityBinding binding,
  required Uint8List payload,
  required Uint8List signingMessage,
  required String publicKey,
  required int issuedAtMillis,
}) => throw UnimplementedError();

class _MemoryStore implements PublicIdentityRecordStore {
  final entries = <String, String>{};
  @override
  Future<String?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, String value) async {
    entries[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    entries.remove(key);
  }

  @override
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) async {
    if (entries[key] != expected) return false;
    if (next == null) {
      entries.remove(key);
    } else {
      entries[key] = next;
    }
    return true;
  }
}

// 验证公开绑定严格字段、跨实例CAS及修订不回退。

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

void suite82() {
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

// 验证机构关注按永久CID持久化，换绑后保持同一分区。

const _ownerCidNumber = 'CN220-CTZN2-198805200-2026';
void suite123() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  test('公权机构关注按订阅者 CID 持久化，钱包换绑不产生新分区', () async {
    const peerCid = 'GD001-CGOV0-000000001-2026';
    final isar = await UserIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.collection<app_store.Entity>().clear();
    });
    final store = IsarPublicInstitutionStore(isar: isar);
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': peerCid,
        'cid_full_name': '广东省人民政府',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'CGOV',
        'account_count': 2,
      }),
    ]);

    await store.subscribe(_ownerCidNumber, peerCid);

    expect(
      (await store.listSubscribed(_ownerCidNumber)).map((row) => row.cidNumber),
      [peerCid],
      reason: '关注归属永久 CID，不接收或存储当前钱包账户作为分区键',
    );
    expect(await store.listSubscribed('CN220-CTZN2-OTHER-2026'), isEmpty);
  });
}
