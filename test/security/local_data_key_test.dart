import '../support/fake_citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/security/account_data_key_provision.dart';
import 'package:citizenapp/security/local_cipher.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/security/device_data_key_vault.dart';

class _MemoryStore implements LocalKeyBlobStore {
  final Map<String, String> entries = <String, String>{};
  bool corruptNextDeviceWrite = false;
  int deviceWrites = 0;
  int? failDeviceWriteAt;
  bool retainRecoveryMarker = false;

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async {
    if (key.startsWith('citizenapp_device_data_key_')) {
      deviceWrites++;
      if (deviceWrites == failDeviceWriteAt) throw StateError('测试存储失败');
      if (corruptNextDeviceWrite) {
        corruptNextDeviceWrite = false;
        value = 'corrupted-fixture';
      }
    }
    entries[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (retainRecoveryMarker &&
        key.startsWith('device_data_key_recovery_pending_'))
      return;
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

final class _DerivingWallet implements CitizenSdkWallet, CitizenSdkWalletBatch {
  _DerivingWallet(Uint8List secret) : _secret = Uint8List.fromList(secret);

  final Uint8List _secret;
  int batchCalls = 0;
  Future<void> Function()? duringBatch;
  Object? batchError;
  CitizenWalletState? state;

  @override
  CitizenSdkOperation<CitizenWalletState> getState() => testCitizenOperation(
    () async => state ?? (throw StateError('wallet state missing')),
  );

  @override
  CitizenSdkOperation<Uint8List> deriveApplicationKey({
    required String accountId,
    required Uint8List salt,
    required Uint8List info,
  }) => testCitizenOperation(
    () async => Uint8List.fromList(
      sha256.convert(<int>[..._secret, ...salt, ...info]).bytes,
    ),
  );

  @override
  CitizenSdkOperation<List<Uint8List>> deriveApplicationKeys({
    required String accountId,
    required Uint8List salt,
    required List<Uint8List> infos,
  }) => testCitizenOperation(() async {
    batchCalls++;
    await duringBatch?.call();
    if (batchError != null) throw batchError!;
    return infos
        .map(
          (info) => Uint8List.fromList(
            sha256.convert(<int>[..._secret, ...salt, ...info]).bytes,
          ),
        )
        .toList(growable: false);
  });

  @override
  CitizenSdkOperation<CitizenApplicationKeyPreparation> prepareApplicationKeys({
    required String accountId,
    required Uint8List salt,
    required List<Uint8List> infos,
    Uint8List? signingMessage,
  }) => testCitizenOperation(
    () async => CitizenApplicationKeyPreparation(
      keys: await deriveApplicationKeys(
        accountId: accountId,
        salt: salt,
        infos: infos,
      ).result,
      signature: signingMessage == null ? null : Uint8List(64),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemoryDeviceVault extends DeviceDataKeyVault {
  int sealCalls = 0;
  bool available = true;
  int? failSealAt;
  Object? openError;
  final Map<String, Uint8List> values = {};
  @override
  Future<bool> contains(int walletIndex) async => available;
  @override
  Future<Uint8List> open({
    required int walletIndex,
    required String blob,
    required Uint8List aad,
  }) async {
    if (openError != null) throw openError!;
    if (!available) {
      throw const DeviceDataKeyVaultException(
        '测试硬件钥失效',
        code: 'keyPermanentlyInvalidated',
      );
    }
    return Uint8List.fromList(values[blob]!);
  }

  @override
  Future<String> seal({
    required int walletIndex,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    expect(plaintext, hasLength(32));
    expect(aad, isNotEmpty);
    sealCalls++;
    if (sealCalls == failSealAt) {
      throw const DeviceDataKeyVaultException('测试封装失败');
    }
    available = true;
    final blob = 'test-sealed-$sealCalls';
    values[blob] = Uint8List.fromList(plaintext);
    return blob;
  }
}

class _CleanupWallet extends TestCitizenSdkWallet {
  CitizenWalletState state = CitizenWalletState(
    revision: BigInt.one,
    hotProfile: null,
    accounts: const [],
    initializationState: CitizenWalletInitializationState.recovering,
    cleanupPending: true,
  );
  Object? error;
  @override
  CitizenSdkOperation<CitizenWalletState> getState() =>
      testCitizenOperation(() {
        if (error != null) throw error!;
        return state;
      });
}

class _CleanupSigning implements CitizenSigning {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('清理不应签名');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestCitizenSdkTransport encodingTransport;
  late CitizenSdk encodingSdk;
  setUp(() async {
    encodingTransport = TestCitizenSdkTransport({}, useCore: true);
    encodingSdk = await encodingTransport.open();
  });
  tearDown(() async {
    await encodingSdk.close();
    await encodingTransport.dispose();
  });

  test('精确清理意图接SDK账户列表，诊断仍在或安全清理未完时不删除意图和设备材料', () async {
    final store = _MemoryStore(), wallet = _CleanupWallet();
    final service = AccountSecurityService(
      wallet: wallet,
      signing: _CleanupSigning(),
      blobStore: store,
      subkeyRegistrar: ({
        required cidNumber,
        required bindingRevision,
        required accountId,
        required signBinding,
      }) async => throw StateError('不应注册子钥'),
      coldDeviceBindingSigner: ({
        required binding,
        required payload,
        required signingMessage,
        required devicePublicKey,
        required issuedAtMillis,
      }) async => throw StateError('不应冷签'),
      coldAccountDataKeyProvider: ({
        required binding,
        required requests,
      }) async => throw StateError('不应派生'),
    );
    final ids = ['0x${'01' * 32}', '0x${'02' * 32}'];
    try {
      expect(await service.hasPendingAccountCleanup, isFalse);
      await service.prepareAccountCleanup(
        accountIds: ids,
        walletIndexes: {0},
        deleteWalletWideKey: true,
      );
      final before = Map<String, String>.of(store.entries);
      final pending = jsonDecode(before.values.single) as Map<String, dynamic>;
      expect(pending['account_ids'], ids);
      expect(pending['wallet_indices'], [0]);
      expect(pending['delete_wallet_wide_key'], isTrue);
      expect(await service.hasPendingAccountCleanup, isTrue);
      await expectLater(
        service.reconcileAccountCleanup(),
        throwsA(isA<AccountSecurityException>()),
      );
      expect(store.entries, before);
      wallet.state = CitizenWalletState(
        revision: BigInt.two,
        hotProfile: null,
        accounts: const [],
        initializationState: CitizenWalletInitializationState.ready,
        cleanupPending: false,
        diagnostics: [
          CitizenWalletDiagnostic(
            walletIndex: 0,
            walletName: '异常',
            accountId: ids.first,
            ss58Address: null,
            diagnosticReason: CitizenWalletDiagnosticReason.invalidStructure,
            signMode: null,
            cleanupTargets: null,
          ),
        ],
      );
      await expectLater(
        service.reconcileAccountCleanup(),
        throwsA(isA<AccountSecurityException>()),
      );
      expect(store.entries, before);
      wallet.error = const CitizenSdkException(
        code: CitizenSdkErrorCode.storage,
        message: '合成读取失败',
      );
      await expectLater(
        service.reconcileAccountCleanup(),
        throwsA(isA<CitizenSdkException>()),
      );
      expect(store.entries, before);
      await service.cancelAccountCleanup();
      expect(await service.hasPendingAccountCleanup, isFalse);
    } finally {
      service.dispose();
    }
  });

  const genesisHash =
      '0x1111111111111111111111111111111111111111111111111111111111111111';
  const cidNumber = 'GD-CTZN1-8F3A2B';
  const firstAccountId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const secondAccountId =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final firstSecret = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final secondSecret = Uint8List.fromList(
    List<int>.generate(32, (i) => 100 + i),
  );
  const firstBinding = AccountDataBinding(
    genesisHash: genesisHash,
    cidNumber: cidNumber,
    bindingRevision: 1,
    accountId: firstAccountId,
  );
  const secondBinding = AccountDataBinding(
    genesisHash: genesisHash,
    cidNumber: cidNumber,
    bindingRevision: 2,
    accountId: secondAccountId,
  );

  group('当前钱包绑定元数据', () {
    late _MemoryStore store;
    late AccountDataBindingStore bindingStore;

    setUp(() {
      store = _MemoryStore();
      bindingStore = AccountDataBindingStore(store);
    });

    test('只保存公开绑定字段，不保存任何派生密钥', () async {
      await bindingStore.activate(firstBinding);
      final active = await bindingStore.readForCid(cidNumber);
      expect(active?.genesisHash, genesisHash);
      expect(active?.cidNumber, cidNumber);
      expect(active?.bindingRevision, 1);
      expect(active?.accountId, firstAccountId);
      expect(store.entries.length, 2);
      expect(
        store.entries.values,
        everyElement(isNot(contains(firstSecret.join(',')))),
      );
    });

    test('绑定版本禁止回退，同版本字段冲突失败关闭', () async {
      await bindingStore.activate(secondBinding);
      await expectLater(
        bindingStore.activate(firstBinding),
        throwsA(isA<AccountDataKeyException>()),
      );
      await expectLater(
        bindingStore.activate(
          const AccountDataBinding(
            genesisHash: genesisHash,
            cidNumber: cidNumber,
            bindingRevision: 2,
            accountId: firstAccountId,
          ),
        ),
        throwsA(isA<AccountDataKeyException>()),
      );
    });

    test('多 CID 绑定互不覆盖，不触碰无关持久值', () async {
      store.entries['unrelated_sentinel'] = 'keep';
      const secondCidBinding = AccountDataBinding(
        genesisHash: genesisHash,
        cidNumber: 'CN220-CTZN2-198805201-2026',
        bindingRevision: 1,
        accountId: '0x3333333333333333333333333333333333333333333333333333333333333333',
      );

      await bindingStore.activate(firstBinding);
      await bindingStore.activate(secondCidBinding);
      expect(
        (await bindingStore.readForCid(cidNumber))?.accountId,
        firstAccountId,
      );
      expect(
        (await bindingStore.readForCid(secondCidBinding.cidNumber))?.accountId,
        secondCidBinding.accountId,
      );
      expect(store.entries['unrelated_sentinel'], 'keep');

      await bindingStore.clearForCid(cidNumber);
      expect(await bindingStore.readForCid(cidNumber), isNull);
      expect(
        await bindingStore.readForCid(secondCidBinding.cidNumber),
        isNotNull,
      );
    });

    test('直接构造的无效链上绑定字段也失败关闭', () async {
      const invalidBindings = <AccountDataBinding>[
        AccountDataBinding(
          genesisHash: '0x01',
          cidNumber: cidNumber,
          bindingRevision: 1,
          accountId: firstAccountId,
        ),
        AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: '123456789012345678901234567890123',
          bindingRevision: 1,
          accountId: firstAccountId,
        ),
        AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: cidNumber,
          bindingRevision: 0,
          accountId: firstAccountId,
        ),
        AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: cidNumber,
          bindingRevision: 1,
          accountId: '0x01',
        ),
      ];
      for (final binding in invalidBindings) {
        await expectLater(
          bindingStore.activate(binding),
          throwsA(isA<AccountDataKeyException>()),
        );
        await expectLater(
          AccountDataKeyDeriver.derive(
            wallet: _DerivingWallet(firstSecret),
            binding: binding,
            purpose: LocalKeyPurpose.chat,
          ),
          throwsA(isA<AccountDataKeyException>()),
        );
      }
      expect(store.entries, isEmpty);
    });

    test('换绑交接日志只保存相邻版本的公开绑定上下文并可清除', () async {
      await bindingStore.writePendingHandover(
        source: firstBinding,
        target: secondBinding,
      );
      final pending = await bindingStore.readPendingHandover();
      expect(pending?.source.accountId, firstAccountId);
      expect(pending?.target.accountId, secondAccountId);
      expect(pending?.target.bindingRevision, 2);
      expect(pending?.state, AccountDataHandoverState.preparing);
      expect(store.entries.keys, <String>[
        AccountDataBindingStore.pendingHandoverKey,
      ]);
      expect(
        store.entries.values.single,
        isNot(contains(firstSecret.join(','))),
      );
      expect(
        store.entries.values.single,
        isNot(contains(secondSecret.join(','))),
      );

      await bindingStore.markPendingHandoverReady(
        source: firstBinding,
        target: secondBinding,
      );
      expect(
        (await bindingStore.readPendingHandover())?.state,
        AccountDataHandoverState.ready,
      );

      await bindingStore.clearPendingHandover(
        source: firstBinding,
        target: secondBinding,
      );
      expect(await bindingStore.readPendingHandover(), isNull);
      expect(store.entries, isEmpty);
    });

    test('换绑交接拒绝跨 CID、跨创世、跳版本和同账户目标', () async {
      final invalidTargets = <AccountDataBinding>[
        const AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: 'GD-CTZN1-OTHER',
          bindingRevision: 2,
          accountId: secondAccountId,
        ),
        const AccountDataBinding(
          genesisHash: '0x2222222222222222222222222222222222222222222222222222222222222222',
          cidNumber: cidNumber,
          bindingRevision: 2,
          accountId: secondAccountId,
        ),
        const AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: cidNumber,
          bindingRevision: 3,
          accountId: secondAccountId,
        ),
        const AccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: cidNumber,
          bindingRevision: 2,
          accountId: firstAccountId,
        ),
      ];
      for (final target in invalidTargets) {
        await expectLater(
          bindingStore.writePendingHandover(
            source: firstBinding,
            target: target,
          ),
          throwsA(isA<AccountDataKeyException>()),
        );
      }
      expect(store.entries, isEmpty);
    });

    test('已落盘交接记录被篡改成跳版本时读取也失败关闭', () async {
      await bindingStore.writePendingHandover(
        source: firstBinding,
        target: secondBinding,
      );
      final decoded = jsonDecode(
        store.entries[AccountDataBindingStore.pendingHandoverKey]!,
      ) as Map<String, dynamic>;
      (decoded['target'] as Map<String, dynamic>)['binding_revision'] = 3;
      store.entries[AccountDataBindingStore.pendingHandoverKey] = jsonEncode(
        decoded,
      );

      await expectLater(
        bindingStore.readPendingHandover(),
        throwsA(isA<AccountDataKeyException>()),
      );
    });
  });

  group('当前钱包账户用途子钥', () {
    late _DerivingWallet wallet;
    late _MemoryStore store;
    late _MemoryDeviceVault vault;
    late AccountSecurityService service;
    AccountSecurityService makeService({bool registrationFails = false}) =>
        AccountSecurityService(
          wallet: wallet,
          signing: _CleanupSigning(),
          blobStore: store,
          deviceDataKeyVault: vault,
          subkeyRegistrar:
              ({
                required cidNumber,
                required bindingRevision,
                required accountId,
                required signBinding,
              }) async {
                final signature = await signBinding(
                  payload: Uint8List(32),
                  signingMessage: Uint8List(32),
                  devicePublicKey: 'synthetic',
                  issuedAtMillis: 1,
                );
                expect(signature, hasLength(130));
                if (registrationFails) throw StateError('测试网络失败');
              },
          coldDeviceBindingSigner: ({
            required binding,
            required payload,
            required signingMessage,
            required devicePublicKey,
            required issuedAtMillis,
          }) async => throw StateError('不应冷签'),
          coldAccountDataKeyProvider: ({
            required binding,
            required requests,
          }) async => throw StateError('不应冷派生'),
        );
    const chatRequest = <DataKeyRequest>[
      (purpose: LocalKeyPurpose.chat, context: null),
    ];
    setUp(() async {
      wallet = _DerivingWallet(firstSecret);
      wallet.state = CitizenWalletState(
        revision: BigInt.one,
        hotProfile: null,
        accounts: [
          CitizenWalletStateAccount(
            signMode: CitizenWalletSignMode.hot,
            walletIndex: 0,
            accountIndex: 0,
            accountId: firstAccountId,
            ss58Address: '',
            name: '',
            createdAtMillis: BigInt.zero,
            isDefault: true,
          ),
        ],
        initializationState: CitizenWalletInitializationState.ready,
        cleanupPending: false,
      );
      store = _MemoryStore();
      vault = _MemoryDeviceVault();
      service = makeService();
      await service.activateAccountDataBinding(
        genesisHash: genesisHash,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: firstAccountId,
      );
    });
    tearDown(() => service.dispose());
    test('普通读取不授权，首次并发准备一次，重启七用途静默可读', () async {
      await expectLater(
        service.readDataKeysForBinding(firstBinding, chatRequest),
        throwsA(isA<DeviceDataKeyVaultException>()),
      );
      expect(wallet.batchCalls, 0);
      await Future.wait(
        List.generate(
          3,
          (_) => service.prepareFirstDeviceForBinding(firstBinding),
        ),
      );
      expect(wallet.batchCalls, 1);
      expect(vault.sealCalls, 7);
      final restarted = makeService();
      try {
        for (final purpose in LocalKeyPurpose.values) {
          final keys = await restarted.readDataKeysForBinding(firstBinding, [
            (
              purpose: purpose,
              context: purpose == LocalKeyPurpose.contactsCloud
                  ? 'encryption'
                  : null,
            ),
          ]);
          expect(keys.single, hasLength(32));
          keys.single.fillRange(0, 32, 0);
        }
        final index = await restarted.readDataKeysForBinding(firstBinding, [
          (purpose: LocalKeyPurpose.contactsCloud, context: 'index'),
        ]);
        index.single.fillRange(0, 32, 0);
        await restarted.prepareFirstDeviceForBinding(firstBinding);
        expect(wallet.batchCalls, 1);
      } finally {
        restarted.dispose();
      }
    });
    test('登记与七用途派生一次授权，网络失败保留本地钥，重启不重新派生', () async {
      final registering = makeService(registrationFails: true);
      try {
        await expectLater(
          registering.prepareFirstDeviceForBinding(
            firstBinding,
            registerDevice: true,
          ),
          throwsA(isA<StateError>()),
        );
        expect(wallet.batchCalls, 1);
        expect(vault.sealCalls, 7);
        final keys = await registering.readDataKeysForBinding(
          firstBinding,
          chatRequest,
        );
        keys.single.fillRange(0, 32, 0);
        final restarted = makeService();
        try {
          await expectLater(
            restarted.prepareFirstDeviceForBinding(
              firstBinding,
              registerDevice: true,
            ),
            throwsA(
              isA<AccountSecurityException>().having(
                (e) => e.code,
                'code',
                'authenticationRequired',
              ),
            ),
          );
          expect(wallet.batchCalls, 1);
        } finally {
          restarted.dispose();
        }
      } finally {
        registering.dispose();
      }
    });
    test('取消后的普通读取和新实例不重复授权，保留认证码及阶段', () async {
      wallet.batchError = const CitizenSdkException(
        code: CitizenSdkErrorCode.authenticationCancelled,
        message: '测试取消',
      );
      await expectLater(
        service.prepareFirstDeviceForBinding(firstBinding),
        throwsA(
          isA<AccountSecurityException>()
              .having((e) => e.code, 'code', 'authenticationCancelled')
              .having((e) => e.stage, 'stage', 'authentication'),
        ),
      );
      final restarted = makeService();
      try {
        await expectLater(
          restarted.readDataKeysForBinding(firstBinding, chatRequest),
          throwsA(isA<DeviceDataKeyVaultException>()),
        );
        await expectLater(
          restarted.prepareFirstDeviceForBinding(firstBinding),
          throwsA(isA<AccountSecurityException>()),
        );
        expect(wallet.batchCalls, 1);
      } finally {
        restarted.dispose();
      }
    });
    for (final stage in ['seal', 'write', 'readback', 'unseal']) {
      test('准备失败回滚持久值并保留未完成，不自动再认证：' + stage, () async {
        if (stage == 'seal') vault.failSealAt = 2;
        if (stage == 'write') store.failDeviceWriteAt = 2;
        if (stage == 'readback') store.corruptNextDeviceWrite = true;
        if (stage == 'unseal')
          wallet.duringBatch = () async {
            vault.openError = const DeviceDataKeyVaultException(
              '测试完整性',
              code: 'integrity',
            );
          };
        await expectLater(
          service.prepareFirstDeviceForBinding(firstBinding),
          throwsA(
            isA<AccountSecurityException>().having(
              (e) => e.stage,
              'stage',
              stage,
            ),
          ),
        );
        expect(
          store.entries.keys.where(
            (key) => key.startsWith('device_data_key_recovery_pending_'),
          ),
          hasLength(1),
        );
        expect(
          store.entries.keys.where(
            (key) => key.startsWith('citizenapp_device_data_key_'),
          ),
          isEmpty,
        );
        final restarted = makeService();
        try {
          await expectLater(
            restarted.prepareFirstDeviceForBinding(firstBinding),
            throwsA(isA<Exception>()),
          );
          expect(wallet.batchCalls, 1);
        } finally {
          restarted.dispose();
        }
      });
    }
    test('同绑定激活幂等，准备期间真实身份变化失败关闭', () async {
      wallet.duringBatch = () async {
        await service.activateAccountDataBinding(
          genesisHash: genesisHash,
          cidNumber: cidNumber,
          bindingRevision: 1,
          accountId: firstAccountId,
        );
      };
      final revision = service.revision.value;
      await service.prepareFirstDeviceForBinding(firstBinding);
      expect(service.revision.value, revision);
      vault.available = false;
      final explicit = makeService();
      wallet.duringBatch = () async => explicit.notifyDefaultAccountChanged();
      try {
        await expectLater(
          explicit.ensureDeviceDataKeysForBinding(
            firstBinding,
            rebuildAll: true,
          ),
          throwsA(isA<AccountSecurityException>()),
        );
      } finally {
        explicit.dispose();
      }
    });
    test('完整中断材料静默提交，锁定与完整性错误不触发重建', () async {
      await service.prepareFirstDeviceForBinding(firstBinding);
      final marker =
          'device_data_key_recovery_pending_' +
          Uri.encodeComponent(genesisHash) +
          '_' +
          Uri.encodeComponent(cidNumber) +
          '_1_' +
          firstAccountId;
      store.entries[marker] = 'true';
      final restarted = makeService();
      try {
        final keys = await restarted.readDataKeysForBinding(
          firstBinding,
          chatRequest,
        );
        keys.single.fillRange(0, 32, 0);
        expect(store.entries[marker], isNull);
        store.entries[marker] = 'true';
        store.retainRecoveryMarker = true;
        await expectLater(
          restarted.readDataKeysForBinding(firstBinding, chatRequest),
          throwsA(
            isA<AccountSecurityException>()
                .having((e) => e.code, 'code', 'storage')
                .having((e) => e.stage, 'stage', 'commit'),
          ),
        );
        expect(store.entries[marker], 'true');
        expect(wallet.batchCalls, 1);
        store.retainRecoveryMarker = false;
        for (final code in [
          'integrity',
          'deviceLocked',
          'keyPermanentlyInvalidated',
        ]) {
          vault.openError = DeviceDataKeyVaultException('固定测试失败', code: code);
          await expectLater(
            restarted.readDataKeysForBinding(firstBinding, chatRequest),
            throwsA(
              isA<DeviceDataKeyVaultException>().having(
                (e) => e.code,
                'code',
                code,
              ),
            ),
          );
          expect(wallet.batchCalls, 1);
        }
      } finally {
        restarted.dispose();
      }
    });
    test('一次批量请求返回逐项相同的用途钥', () async {
      final wallet = _DerivingWallet(firstSecret);
      final requests = <DataKeyRequest>[
        (purpose: LocalKeyPurpose.chat, context: null),
        (purpose: LocalKeyPurpose.contactsCloud, context: 'index'),
      ];
      final batch = await AccountDataKeyDeriver.deriveBatch(
        wallet: wallet,
        binding: firstBinding,
        requests: requests,
      );
      expect(wallet.batchCalls, 1);
      for (var index = 0; index < requests.length; index++) {
        final request = requests[index];
        final single = await AccountDataKeyDeriver.derive(
          wallet: wallet,
          binding: firstBinding,
          purpose: request.purpose,
          context: request.context,
        );
        expect(batch[index], single);
      }
    });
    test('同一账户同一绑定跨设备派生结果一致', () async {
      final first = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(firstSecret),
        binding: firstBinding,
        purpose: LocalKeyPurpose.chat,
      );
      final anotherDevice = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(Uint8List.fromList(firstSecret)),
        binding: firstBinding,
        purpose: LocalKeyPurpose.chat,
      );
      expect(anotherDevice, first);
    });

    test('全部用途域互相隔离', () async {
      final values = <String>{};
      for (final purpose in LocalKeyPurpose.values) {
        final key = await AccountDataKeyDeriver.derive(
          wallet: _DerivingWallet(firstSecret),
          binding: firstBinding,
          purpose: purpose,
        );
        expect(key, hasLength(32));
        values.add(key.join(','));
      }
      expect(values.length, LocalKeyPurpose.values.length);
    });

    test('同一用途的 encryption 与 index 上下文互相隔离', () async {
      final encryptionKey = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(firstSecret),
        binding: firstBinding,
        purpose: LocalKeyPurpose.contactsCloud,
        context: 'encryption',
      );
      final indexKey = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(firstSecret),
        binding: firstBinding,
        purpose: LocalKeyPurpose.contactsCloud,
        context: 'index',
      );
      expect(indexKey, isNot(encryptionKey));
    });

    test('没有当前账户签名交接时，新钱包不能直接解密此前钱包历史私有密文', () async {
      final currentKey = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(firstSecret),
        binding: firstBinding,
        purpose: LocalKeyPurpose.chat,
      );
      final oldCiphertext = await LocalCipher.encryptString(
        key: currentKey,
        plaintext: '此前钱包历史私有数据',
        aad: '${LocalKeyPurpose.chat.domain}|message-before-rebind',
      );
      final newKey = await AccountDataKeyDeriver.derive(
        wallet: _DerivingWallet(secondSecret),
        binding: secondBinding,
        purpose: LocalKeyPurpose.chat,
      );
      expect(newKey, isNot(currentKey));
      await expectLater(
        LocalCipher.decryptString(
          key: newKey,
          blob: oldCiphertext,
          aad: '${LocalKeyPurpose.chat.domain}|message-before-rebind',
        ),
        throwsA(isA<LocalCipherException>()),
      );
    });
  });

  group('冷钱包用途钥加密交付', () {
    test('真实编码完成0x22授权，显式验签替身隔离加密解封测试', () async {
      final child = Uint8List.fromList(
        List<int>.generate(32, (index) => index + 1),
      );
      const accountId =
          '0x1111111111111111111111111111111111111111111111111111111111111111';
      // 本用例隔离验证加密交付；签名仅为合成数据，不声称真实签名通过验签。
      final verifiedMessages = <Uint8List>[];
      encodingTransport.handlers['verifySignature'] = (fields) {
        expect(fields[0], accountId);
        expect(fields[1], Uint8List(64));
        verifiedMessages.add(Uint8List.fromList(fields[2]! as Uint8List));
        return <Object?>[true];
      };
      const binding = AccountDataBinding(
        genesisHash: genesisHash,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: accountId,
      );
      final requests = <DataKeyRequest>[
        (purpose: LocalKeyPurpose.chat, context: null),
        (purpose: LocalKeyPurpose.contactsCloud, context: 'encryption'),
      ];
      final recipientSecret = Uint8List.fromList(List<int>.filled(32, 0x31));
      final session = await AccountDataKeyProvisionSession.create(
        binding: binding,
        requests: requests,
        expiresAt: 1900000000,
        recipientSecret: recipientSecret,
        requestNonce: List<int>.filled(16, 0x41),
      );
      final keys = <Uint8List>[];
      try {
        for (final request in requests) {
          keys.add(
            await AccountDataKeyDeriver.derive(
              wallet: _DerivingWallet(child),
              binding: binding,
              purpose: request.purpose,
              context: request.context,
            ),
          );
        }
        final plaintext = Uint8List.fromList(<int>[
          requests.length << 2,
          LocalKeyPurpose.chat.provisionCode,
          0,
          ...keys[0],
          LocalKeyPurpose.contactsCloud.provisionCode,
          1,
          ...keys[1],
        ]);
        final senderSecret = Uint8List.fromList(List<int>.filled(32, 0x51));
        final nonce = Uint8List.fromList(List<int>.filled(12, 0x61));
        final sealed = await _sealAccountDataBundle(
          recipientSecret: recipientSecret,
          senderSecret: senderSecret,
          nonce: nonce,
          plaintext: plaintext,
          aad: session.payload,
        );
        final senderPublicKey = sealed.senderPublicKey;
        final ciphertext = sealed.ciphertext;
        final authorization = accountDataKeyProvisionAuthorization(
          requestPayload: session.payload,
          senderPublicKey: senderPublicKey,
          nonce: nonce,
          ciphertext: ciphertext,
        );
        final message = (await CitizenSigning.encodePayload(
          CitizenSigningPayload.message(
            opTag: kOpSignAccountDataKeyProvision,
            scalePayload: authorization,
          ),
        ));
        final signature = Uint8List(64);
        final body = CitizenQrDocument(
          kind: CitizenQrKind.accountDataKeyResponse,
          canonicalText: 'synthetic-response',
          scanPurposeMask: 32,
          signerAccountId: '0x${'11' * 32}',
          signature: signature,
          keyExchangePublicKey: senderPublicKey,
          encryptionNonce: nonce,
          ciphertext: ciphertext,
        );

        final opened = await session.open(body);
        expect(verifiedMessages.single, message);
        expect(opened, hasLength(2));
        expect(opened[0], keys[0]);
        expect(opened[1], keys[1]);
        for (final key in opened) {
          key.fillRange(0, key.length, 0);
        }

        final tampered = Uint8List.fromList(ciphertext)..[0] ^= 1;
        expect(
          session.open(
            CitizenQrDocument(
              kind: CitizenQrKind.accountDataKeyResponse,
              canonicalText: 'synthetic-tampered-response',
              scanPurposeMask: 32,
              signerAccountId: '0x${'11' * 32}',
              signature: signature,
              keyExchangePublicKey: senderPublicKey,
              encryptionNonce: nonce,
              ciphertext: tampered,
            ),
          ),
          throwsA(isA<AccountDataKeyException>()),
        );
        plaintext.fillRange(0, plaintext.length, 0);
        senderSecret.fillRange(0, senderSecret.length, 0);
      } finally {
        for (final key in keys) {
          key.fillRange(0, key.length, 0);
        }
        child.fillRange(0, child.length, 0);
        recipientSecret.fillRange(0, recipientSecret.length, 0);
        session.dispose();
      }
    });

    test('请求用 UTF-8 字节长度编码 CID，重复用途失败关闭', () async {
      const binding = AccountDataBinding(
        genesisHash: genesisHash,
        cidNumber: '公民-A',
        bindingRevision: 1,
        accountId: firstAccountId,
      );
      final payload = await encodeAccountDataKeyProvisionRequest(
        binding: binding,
        recipientPublicKey: List<int>.filled(32, 1),
        requests: <DataKeyRequest>[
          (purpose: LocalKeyPurpose.chat, context: null),
        ],
        expiresAt: 1900000000,
        requestNonce: List<int>.filled(16, 2),
      );
      expect(payload[32], utf8.encode('公民-A').length << 2);
      await expectLater(
        encodeAccountDataKeyProvisionRequest(
          binding: binding,
          recipientPublicKey: List<int>.filled(32, 1),
          requests: <DataKeyRequest>[
            (purpose: LocalKeyPurpose.chat, context: null),
            (purpose: LocalKeyPurpose.chat, context: null),
          ],
          expiresAt: 1900000000,
          requestNonce: List<int>.filled(16, 2),
        ),
        throwsA(isA<AccountDataKeyException>()),
      );
    });
  });
}

Future<({Uint8List senderPublicKey, Uint8List ciphertext})>
_sealAccountDataBundle({
  required Uint8List recipientSecret,
  required Uint8List senderSecret,
  required Uint8List nonce,
  required Uint8List plaintext,
  required Uint8List aad,
}) async {
  final x25519 = X25519();
  final sender = await x25519.newKeyPairFromSeed(senderSecret);
  final recipient = await x25519.newKeyPairFromSeed(recipientSecret);
  final senderPublicKey = await sender.extractPublicKey();
  final recipientPublicKey = await recipient.extractPublicKey();
  final shared = await x25519.sharedSecretKey(
    keyPair: sender,
    remotePublicKey: recipientPublicKey,
  );
  final salt = await Sha256().hash(aad);
  final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: salt.bytes,
    info: utf8.encode('citizenapp.account-data/provision'),
  );
  final box = await AesGcm.with256bits().encrypt(
    plaintext,
    secretKey: key,
    nonce: nonce,
    aad: aad,
  );
  return (
    senderPublicKey: Uint8List.fromList(senderPublicKey.bytes),
    ciphertext: Uint8List.fromList(<int>[...box.cipherText, ...box.mac.bytes]),
  );
}
