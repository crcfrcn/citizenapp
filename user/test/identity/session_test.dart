// 验证设备登记、会话恢复及设备绑定金标。

import 'package:flutter/widgets.dart';
import 'package:citizen_system/security/access.dart';
import 'package:chat/chat.dart' as chat_sdk;
import 'package:citizen_user/security.dart' show AccountSecurityService, PublicIdentityRecordStore, deviceRegistrationProofKey;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext, IdentityBinding;
import 'package:citizen_user/identity/session.dart' show DeviceBindingSigner, MlsAuthenticationException, MlsAuthenticationIdentity, MlsAuthenticationSource, MlsDeviceRegistrar, SquareSessionProvider, SquareSessionResolution, SquareSessionStatus, SquareSessionStatusText, buildMlsDeviceBindingSigningMessage, encodeMlsDeviceBindingPayload;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_user/identity/state.dart' show CidBusinessDecision, CidBusinessGate, CidBusinessStatus, FinalizedIdentityResolver;
import 'package:citizen_user/api.dart' show SquareApiClient, SquareApiException, SquareApiStage, SquareSession;
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:chat/chat.dart' as chat;
import 'dart:io';
import 'package:citizen_network/auth.dart';

void main() {
  group('mls_device_registrar_test', suite83);
  group('square_session_selfheal_test', suite93);
  group('device_binding_golden_test', suite114);
}

// 验证换绑同步与未登记设备的一次钱包授权、持久证明和失败恢复。

const _accountId = testMlsAccountId;
const _binding = IdentityBinding(
  genesisHash:
      "0xabababababababababababababababababababababababababababababababab",
  cidNumber: testMlsCidNumber,
  bindRev: 1,
  accountId: _accountId,
);

class _SessionApi extends SquareApiClient {
  _SessionApi({required this.deviceMissing, this.beforeReturn});
  final Future<void> Function()? beforeReturn;
  final bool deviceMissing;
  bool registered = false;
  @override
  Future<SquareSession> ensureSession({
    required String accountId,
    required MlsAuthenticationSource authentication,
    Future<void> Function(MlsAuthenticationIdentity)? onDeviceNotRegistered,
  }) async {
    final identity = await authentication.readIdentity();
    if (deviceMissing && !registered) {
      if (onDeviceNotRegistered == null) {
        throw const SquareApiException(
          "未登记",
          errorCode: "device_not_registered",
        );
      }
      await onDeviceNotRegistered(identity);
      registered = true;
    }
    await authentication.requireCurrent(identity);
    await beforeReturn?.call();
    return fakeSquareSession(accountId);
  }
}

class _StorageAuthentication extends FakeMlsAuthentication {
  @override
  Future<MlsAuthenticationIdentity> readIdentity() async =>
      throw const chat_sdk.MlsException(
        chat_sdk.MlsErrorCode.stateMissing,
        'synthetic private detail',
      );
}

class _SessionWalletManager implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
  int registrationCalls = 0;
  Object? registrationFailure;
  @override
  Future<IdentityBinding> identityBindingForAccountId(String accountId) async =>
      _binding;

  @override
  Future<IdentityBinding?> readIdentityBindingForAccountId(
    String accountId,
  ) async => _binding;

  @override
  Future<void> activateIdentityBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindRev,
    required String accountId,
    bool notify = true,
  }) async {}

  @override
  Future<void> registerMlsDeviceForBinding(IdentityBinding binding) async {
    registrationCalls++;
    if (registrationFailure != null) throw registrationFailure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionIdentityCache implements CurrentUserContext {
  _SessionIdentityCache({this.localBinding = _binding});
  IdentityBinding? localBinding;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 7,
      accountIndex: 0,
      accountId: _accountId,
      ss58Address: 'ss58',
      name: '测试账户',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: localBinding,
  );

  @override
  void invalidate() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FactGate implements CidBusinessGate {
  _FactGate(this.decision, {this.prepare});
  final CidBusinessDecision decision;
  final void Function()? prepare;
  @override
  Future<CidBusinessDecision> resolve() async {
    prepare?.call();
    return decision;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected gate operation');
}

class _ProofStore implements PublicIdentityRecordStore {
  final entries = <String, String>{};
  bool rejectWrite = false;
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
    if (rejectWrite || entries[key] != expected) return false;
    if (next == null) {
      entries.remove(key);
    } else {
      entries[key] = next;
    }
    return true;
  }
}

Map<String, Object> _receipt() => {
  'is_ok': true,
  'cid_number': testMlsCidNumber,
  'bind_rev': 1,
  'device_id': testMlsDeviceId,
};

Future<void> _register(
  MlsDeviceRegistrar registrar, {
  DeviceBindingSigner? signer,
}) => registrar.register(
  cidNumber: testMlsCidNumber,
  bindRev: 1,
  accountId: testMlsAccountId,
  issuedAtMillis: 1700000000000,
  signBinding:
      signer ??
      ({
        required payload,
        required signingMessage,
        required publicKey,
        required issuedAtMillis,
      }) async => '0x${'bb' * 64}',
);

/// 只控制明确的签名取消/失败；不伪造成功签名，也不访问设备钱包或金库。
class _AttemptWallet extends TestWalletReads {
  _AttemptWallet({
    this.cold = false,
    this.failure = CitizenSdkErrorCode.authenticationCancelled,
  });
  final bool cold;
  final CitizenSdkErrorCode failure;
  int signs = 0;
  Completer<void>? barrier;
  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: [
            CitizenWalletStateAccount(
              signMode: cold
                  ? CitizenWalletSignMode.cold
                  : CitizenWalletSignMode.hot,
              walletIndex: 0,
              accountIndex: cold ? null : 0,
              accountId: _accountId,
              ss58Address: citizenSs58FromAccountId(_accountId),
              name: '合成账户',
              createdAtMillis: BigInt.zero,
              isDefault: true,
            ),
          ],
        ),
      );
  Future<Uint8List> sign(
    String accountId,
    Uint8List payload,
    int action,
    BuildContext? context,
  ) async {
    signs++;
    await barrier?.future;
    throw CitizenSdkException(code: failure, message: '合成签名终态');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('不应调用此钱包能力');
}

void suite83() {
  test('换绑同步失败后跨实例复用证明，确认后不重复请求', () async {
    final binding = IdentityBinding(
      genesisHash: _binding.genesisHash,
      cidNumber: testMlsCidNumber,
      bindRev: 2,
      accountId: _accountId,
    );
    final records = _ProofStore(), wallet = _AttemptWallet();
    final source = FakeMlsAuthentication(bindRev: 2);
    records.entries[deviceRegistrationProofKey(testMlsCidNumber, 2, _accountId)] =
        jsonEncode({
          'cid_number': testMlsCidNumber,
          'bind_rev': 2,
          'account_id': _accountId,
          'public_key': source.identity.publicKey,
          'issued_at': 1700000000000,
          'signature': '0x${'bb' * 64}',
        });
    var fail = true;
    final bodies = <Map<String, dynamic>>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/user/devices');
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (fail) return http.Response('{"error_code":"temporary"}', 503);
        return http.Response(jsonEncode({..._receipt(), 'bind_rev': 2}), 200);
      }),
    );
    addTearDown(api.close);
    Future<AccountSecurityService> factory() async {
      final registrar = MlsDeviceRegistrar(
        authentication: source, apiClient: api, proofStore: records,
      );
      final security = AccountSecurityService(
        getWalletState: wallet.getWalletState,
        payloadSigner: wallet.sign,
        blobStore: records,
        mlsDeviceRegistrar: registrar.register,
        coldMlsDeviceBindingSigner: ({required binding, required payload,
          required signingMessage, required publicKey, required issuedAtMillis})
          async => throw StateError('不应要求冷签'),
      );
      addTearDown(security.dispose);
      await security.activateIdentityBinding(
        genesisHash: binding.genesisHash, cidNumber: binding.cidNumber,
        bindRev: binding.bindRev, accountId: binding.accountId,
      );
      return security;
    }
    expect(await (await factory()).synchronizeMlsBinding(binding), false);
    fail = false;
    final recovered = await factory();
    expect(await recovered.synchronizeMlsBinding(binding), true);
    expect(await (await factory()).synchronizeMlsBinding(binding), true);
    expect(bodies, hasLength(2));
    expect(bodies.first, bodies.last);
    expect(wallet.signs, 0);
    expect(source.identity.deviceId, testMlsDeviceId);
    expect(await recovered.synchronizeMlsBinding(_binding), false);
    expect(bodies, hasLength(2), reason: '旧代次不得同步或请求签署');
  });

  test('已提交MLS身份缺失拒绝换钥，不登记或请求钱包授权', () async {
    final security = _SessionWalletManager();
    final provider = SquareSessionProvider(
      client: _SessionApi(deviceMissing: true),
      accountSecurity: security,
      currentUserContext: _SessionIdentityCache(),
      authentication: _StorageAuthentication(),
    );
    final result = await provider.resolveSession();
    expect(result.errorCode, 'mls_state_missing');
    expect(security.registrationCalls, 0);
    expect(result.message, isNot(contains('synthetic private')));
  });

  test('已有CID先恢复公开绑定，再共享自动准备；并发只登记一次', () async {
    final current = _SessionIdentityCache(localBinding: null);
    final security = _SessionWalletManager(), source = FakeMlsAuthentication();
    final provider = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
      authentication: source,
      client: _SessionApi(deviceMissing: true),
      cidBusinessGate: _FactGate(
        const CidBusinessDecision(CidBusinessStatus.ready),
        prepare: () => current.localBinding = _binding,
      ),
    );
    final result = await Future.wait([
      provider.ensureSession(),
      provider.ensureSession(),
    ]);
    expect(result.every((s) => s?.cidNumber == testMlsCidNumber), true);
    expect(security.registrationCalls, 1);
  });
  for (final fact in [
    CidBusinessStatus.unregistered,
    CidBusinessStatus.unavailable,
  ]) {
    test('CID事实$fact在MLS前结束；读取失败不当作没有CID', () async {
      final security = _SessionWalletManager(),
          source = FakeMlsAuthentication();
      final provider = SquareSessionProvider(
        accountSecurity: security,
        currentUserContext: _SessionIdentityCache(localBinding: null),
        authentication: source,
        cidBusinessGate: _FactGate(CidBusinessDecision(fact)),
        client: _SessionApi(deviceMissing: true),
      );
      final resolution = await provider.resolveSession();
      expect(
        resolution.errorCode,
        fact == CidBusinessStatus.unregistered
            ? 'identity_unregistered'
            : 'identity_projection_unavailable',
      );
      expect(source.identityCalls, 0);
      expect(security.registrationCalls, 0);
    });
  }
  test('自动准备取消后渲染和前台重试不重复授权，主动重试沿原入口恢复', () async {
    final security = _SessionWalletManager()
      ..registrationFailure = const AccountSecurityException(
        'synthetic cancellation',
        code: 'authenticationCancelled',
      );
    final provider = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: _SessionIdentityCache(),
      authentication: FakeMlsAuthentication(),
      client: _SessionApi(deviceMissing: true),
    );
    expect(
      (await provider.resolveSession()).errorCode,
      'authenticationCancelled',
    );
    for (var i = 0; i < 3; i++) {
      expect(
        (await provider.resolveSession()).errorCode,
        'authenticationRequired',
      );
    }
    expect(security.registrationCalls, 1);
    security.registrationFailure = null;
    expect(await provider.registerCurrentDevice(), isNotNull);
    expect(security.registrationCalls, 2);
    expect(await provider.ensureSession(), isNotNull);
    expect(security.registrationCalls, 2);
  });

  Future<AccountSecurityService> attemptSecurity(
    _AttemptWallet wallet,
    _ProofStore records, {
    void Function()? onCold,
  }) async {
    final service = AccountSecurityService(
      getWalletState: wallet.getWalletState,
      payloadSigner: wallet.sign,
      blobStore: records,
      mlsDeviceRegistrar:
          ({
            required cidNumber,
            required bindRev,
            required accountId,
            required signBinding,
          }) async {
            await signBinding(
              payload: Uint8List.fromList([1]),
              signingMessage: Uint8List.fromList([2]),
              publicKey: '0x${'ab' * 32}',
              issuedAtMillis: 1,
            );
          },
      coldMlsDeviceBindingSigner:
          ({
            required binding,
            required payload,
            required signingMessage,
            required publicKey,
            required issuedAtMillis,
          }) async {
            onCold?.call();
            throw const AccountSecurityException(
              '合成冷签取消',
              code: 'authenticationCancelled',
            );
          },
    );
    addTearDown(service.dispose);
    await service.activateIdentityBinding(
      genesisHash: _binding.genesisHash,
      cidNumber: _binding.cidNumber,
      bindRev: 1,
      accountId: _accountId,
    );
    return service;
  }

  for (final receiptKey in <String?>[null, 'ab', 'bc']) {
    test('既有尝试标记仅凭真实另一设备回执解除：$receiptKey', () async {
      final records = _ProofStore(),
          wallet = _AttemptWallet(failure: CitizenSdkErrorCode.network);
      final service = await attemptSecurity(wallet, records);
      final attempt =
          'mls.registration.attempt:${jsonEncode(_binding.toJson())}';
      records.entries[attempt] = 'attempted';
      if (receiptKey != null) {
        records.entries[deviceRegistrationProofKey(
          testMlsCidNumber,
          1,
          testMlsAccountId,
        )] = jsonEncode({
          'cid_number': testMlsCidNumber,
          'bind_rev': 1,
          'account_id': testMlsAccountId,
          'public_key': '0x${receiptKey * 32}',
          'issued_at': 1,
          'signature': '0x${'bb' * 64}',
        });
      }
      await expectLater(
        service.registerMlsDeviceForBinding(_binding),
        receiptKey == 'bc'
            ? throwsA(isA<CitizenSdkException>())
            : throwsA(
                isA<AccountSecurityException>().having(
                  (e) => e.code,
                  'code',
                  'authenticationRequired',
                ),
              ),
      );
      expect(wallet.signs, receiptKey == 'bc' ? 1 : 0);
      expect(
        records.entries[attempt],
        receiptKey == 'bc' ? '0x${'ab' * 32}' : 'attempted',
      );
    });
  }

  for (final failure in [
    CitizenSdkErrorCode.authenticationCancelled,
    CitizenSdkErrorCode.cancelled,
    CitizenSdkErrorCode.network,
    CitizenSdkErrorCode.integrity,
  ]) {
    test('首次设备授权$failure：只有明确取消才能再次主动授权', () async {
      final records = _ProofStore(), wallet = _AttemptWallet(failure: failure);
      final service = await attemptSecurity(wallet, records);
      final cancelled =
          failure == CitizenSdkErrorCode.authenticationCancelled ||
          failure == CitizenSdkErrorCode.cancelled;
      await expectLater(
        service.registerMlsDeviceForBinding(_binding),
        throwsA(isA<CitizenSdkException>()),
      );
      final attempts = records.entries.keys.where(
        (key) => key.startsWith('mls.registration.attempt:'),
      );
      expect(attempts.length, cancelled ? 0 : 1);
      await expectLater(
        service.registerMlsDeviceForBinding(_binding),
        cancelled
            ? throwsA(isA<CitizenSdkException>())
            : throwsA(
                isA<AccountSecurityException>().having(
                  (e) => e.code,
                  'code',
                  'authenticationRequired',
                ),
              ),
      );
      expect(wallet.signs, cancelled ? 2 : 1);
      expect(records.entries.containsKey('identity.bindings'), isTrue);
    });
  }

  test('冷签明确取消可再次主动授权，不触发热签或删除公开绑定', () async {
    final records = _ProofStore(), wallet = _AttemptWallet(cold: true);
    var calls = 0;
    final service = await attemptSecurity(
      wallet,
      records,
      onCold: () => calls++,
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        service.registerMlsDeviceForBinding(_binding),
        throwsA(
          isA<AccountSecurityException>().having(
            (e) => e.code,
            'code',
            'authenticationCancelled',
          ),
        ),
      );
    }
    expect(calls, 2);
    expect(wallet.signs, 0);
    expect(
      records.entries.keys.where(
        (key) => key.startsWith('mls.registration.attempt:'),
      ),
      isEmpty,
    );
    expect(records.entries.containsKey('identity.bindings'), isTrue);
  });

  test('同绑定并发授权共用一次，取消结束后才允许下一次用户动作', () async {
    final records = _ProofStore(),
        wallet = _AttemptWallet()..barrier = Completer<void>();
    final service = await attemptSecurity(wallet, records);
    final first = service.registerMlsDeviceForBinding(_binding);
    final second = service.registerMlsDeviceForBinding(_binding);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(wallet.signs, 1);
    final checks = Future.wait([
      expectLater(first, throwsA(isA<CitizenSdkException>())),
      expectLater(second, throwsA(isA<CitizenSdkException>())),
    ]);
    wallet.barrier!.complete();
    await checks;
    wallet.barrier = null;
    await expectLater(
      service.registerMlsDeviceForBinding(_binding),
      throwsA(isA<CitizenSdkException>()),
    );
    expect(wallet.signs, 2);
  });

  TestCitizenSdkHarness();
  test('本机绑定缺失为未知，不读MLS或代办链恢复/登记', () async {
    final source = FakeMlsAuthentication();
    final wallet = _SessionWalletManager();
    final provider = SquareSessionProvider(
      client: _SessionApi(deviceMissing: true),
      accountSecurity: wallet,
      authentication: source,
      currentUserContext: _SessionIdentityCache(localBinding: null),
    );
    await expectLater(
      provider.ensureSession(),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'identity_local_missing',
        ),
      ),
    );
    expect(source.identityCalls, 0);
    expect(source.proofCalls, 0);
    expect(wallet.registrationCalls, 0);
  });

  test("普通会话未登记自动准备，已登记会话不再钱包授权", () async {
    final existingWallet = _SessionWalletManager();
    final existing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: false),
      accountSecurity: existingWallet,
      authentication: FakeMlsAuthentication(),
      currentUserContext: _SessionIdentityCache(),
    );
    expect(await existing.ensureSession(), isNotNull);
    expect(await existing.registerCurrentDevice(), isNotNull);
    expect(existingWallet.registrationCalls, 0);
    final missingWallet = _SessionWalletManager();
    final missing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: true),
      accountSecurity: missingWallet,
      authentication: FakeMlsAuthentication(),
      currentUserContext: _SessionIdentityCache(),
    );
    // 普通页面、刷新及精确账户入口共用自动准备；只登记一次。
    for (final ordinary in [
      missing.ensureSession,
      missing.refreshSession,
      () => missing.ensureSessionForAccountId(_accountId),
    ]) {
      expect(await ordinary(), isNotNull);
      expect(missingWallet.registrationCalls, 1);
    }
    expect(await missing.registerCurrentDevice(), isNotNull);
    expect(await missing.ensureSession(), isNotNull);
    expect(missingWallet.registrationCalls, 1);
  });

  test('普通握手期间本机代次改变拒绝迟到会话，目标账户不符不读MLS', () async {
    final wallet = _SessionWalletManager(), source = FakeMlsAuthentication();
    final api = _SessionApi(
      deviceMissing: false,
      beforeReturn: () async {
        wallet.revision.value++;
      },
    );
    final provider = SquareSessionProvider(
      client: api,
      accountSecurity: wallet,
      authentication: source,
      currentUserContext: _SessionIdentityCache(),
    );
    await expectLater(
      provider.ensureSessionForAccountId('0x${'ef' * 32}'),
      throwsA(isA<AccountSecurityException>()),
    );
    expect(source.identityCalls, 0);
    await expectLater(
      provider.ensureSession(),
      throwsA(
        isA<AccountSecurityException>().having(
          (e) => e.code,
          '代次',
          'identityChanged',
        ),
      ),
    );
    expect(wallet.registrationCalls, 0);
  });

  test('钱包授权先落盘；登记只提交MLS公开身份与新鲜MLS证明', () async {
    final store = _ProofStore(), source = FakeMlsAuthentication();
    final requests = <Map<String, dynamic>>[];
    var wallets = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(store.entries, hasLength(1));
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(jsonEncode(_receipt()), 200);
      }),
    );
    addTearDown(api.close);
    final registrar = MlsDeviceRegistrar(
      authentication: source,
      proofStore: store,
      apiClient: api,
    );
    Future<String> signer({
      required payload,
      required signingMessage,
      required publicKey,
      required issuedAtMillis,
    }) async {
      wallets++;
      expect(publicKey, source.identity.publicKey);
      expect(signingMessage, hasLength(32));
      return '0x${'bb' * 64}';
    }

    await Future.wait([
      _register(registrar, signer: signer),
      _register(registrar, signer: signer),
    ]);
    expect(wallets, 1);
    expect(requests, hasLength(1));
    expect(requests.single.keys.toSet(), {
      'account_id',
      'public_key',
      'issued_at',
      'binding_signature',
    });
    expect(requests.single['public_key'], source.identity.publicKey);
    expect(requests.single['binding_signature'], '0x${'bb' * 64}');
  });

  test('回执丢失后只复用已有钱包授权', () async {
    final store = _ProofStore(), source = FakeMlsAuthentication();
    var failNetwork = true, wallets = 0;
    final bodies = <Map<String, dynamic>>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        if (failNetwork) throw StateError('合成回执丢失');
        return http.Response(jsonEncode(_receipt()), 200);
      }),
    );
    addTearDown(api.close);
    MlsDeviceRegistrar factory() => MlsDeviceRegistrar(
      authentication: source,
      proofStore: store,
      apiClient: api,
    );
    Future<String> signer({
      required payload,
      required signingMessage,
      required publicKey,
      required issuedAtMillis,
    }) async {
      wallets++;
      return '0x${'bb' * 64}';
    }

    await expectLater(_register(factory(), signer: signer), throwsStateError);
    failNetwork = false;
    await _register(factory(), signer: signer);
    expect(wallets, 1);
    expect(bodies[1].keys.toSet(), {
      'account_id',
      'public_key',
      'issued_at',
      'binding_signature',
    });
    expect(bodies[1].containsKey('turnstile_token'), false);
    expect(bodies.last['binding_signature'], bodies.first['binding_signature']);
    expect(bodies.last['issued_at'], bodies.first['issued_at']);
    expect(source.proofCalls, 2);
  });

  test('授权保存失败，不发网络请求', () async {
    final store = _ProofStore()..rejectWrite = true;
    var requests = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);
    final registrar = MlsDeviceRegistrar(
      authentication: FakeMlsAuthentication(),
      proofStore: store,
      apiClient: api,
    );
    await expectLater(
      _register(registrar),
      throwsA(
        isA<SquareApiException>().having(
          (e) => e.errorCode,
          '错误码',
          'device_proof_storage',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('新公钥不能借旧设备签名，原子保存自身回执且随后重试复用', () async {
    final store = _ProofStore(), source = FakeMlsAuthentication();
    final key = deviceRegistrationProofKey(
      testMlsCidNumber,
      1,
      testMlsAccountId,
    );
    store.entries[key] = jsonEncode({
      'cid_number': testMlsCidNumber,
      'bind_rev': 1,
      'account_id': testMlsAccountId,
      'public_key': '0x${'bc' * 32}',
      'issued_at': 1700000000000,
      'signature': '0x${'cc' * 64}',
    });
    var wallets = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['public_key'], source.identity.publicKey);
        expect(body['binding_signature'], '0x${'bb' * 64}');
        expect(
          jsonDecode(store.entries[key]!)['public_key'],
          source.identity.publicKey,
        );
        return http.Response(jsonEncode(_receipt()), 200);
      }),
    );
    addTearDown(api.close);
    final registrar = MlsDeviceRegistrar(
      authentication: source,
      proofStore: store,
      apiClient: api,
    );
    Future<String> signer({
      required payload,
      required signingMessage,
      required publicKey,
      required issuedAtMillis,
    }) async {
      wallets++;
      return '0x${'bb' * 64}';
    }

    await _register(registrar, signer: signer);
    await _register(registrar, signer: signer);
    expect(wallets, 1);
  });

  test('钱包授权期间账户变化，禁止保存或提交', () async {
    final store = _ProofStore(), source = FakeMlsAuthentication();
    final registrar = MlsDeviceRegistrar(
      authentication: source,
      proofStore: store,
    );
    await expectLater(
      _register(
        registrar,
        signer:
            ({
              required payload,
              required signingMessage,
              required publicKey,
              required issuedAtMillis,
            }) async {
              source.closed = true;
              return '0x${'bb' * 64}';
            },
      ),
      throwsA(isA<MlsAuthenticationException>()),
    );
    expect(store.entries, isEmpty);
  });

  test('已准入设备明确提交两个null，不产生验证页面', () async {
    final source = FakeMlsAuthentication(), store = _ProofStore();
    Map<String, dynamic>? body;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_receipt()), 200);
      }),
    );
    addTearDown(api.close);
    await _register(
      MlsDeviceRegistrar(
        authentication: source,
        proofStore: store,
        apiClient: api,
      ),
    );
    expect(body!.keys.toSet(), {
      'account_id',
      'public_key',
      'issued_at',
      'binding_signature',
    });
    expect(body!.containsKey('turnstile_token'), false);
  });
}

// 验证会话错误准确分类、首次设备登记和取消不触发重复授权。

/// 只有明确未登记才编排一次登记；签名失败绝不触发钱包或重建MLS身份。
void suite93() {
  test('通讯录自动补传遇未登记不再请求钱包签名', () async {
    final security = _DiagnosticSecurity();
    final source = FakeMlsAuthentication();
    var requests = 0;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({'error_code': 'device_not_registered'}),
          403,
        );
      }),
    );
    addTearDown(client.close);
    addTearDown(security.revision.dispose);
    final provider = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: _DiagnosticCurrent(),
      client: client,
      authentication: source,
    );
    await expectLater(
      provider.ensureContactSession(),
      throwsA(
        isA<AccountSecurityException>().having(
          (e) => e.code,
          'code',
          'authenticationRequired',
        ),
      ),
    );
    expect(security.deviceRegistrations, 0);
    expect(security.unexpected, isEmpty);
    expect(requests, 1);
  });

  test('服务端公共RPC限额是固定可重试分类，不显示原始正文', () {
    final result = SquareSessionResolution.fromError(
      const SquareApiException(
        '合成私有服务正文',
        statusCode: 429,
        errorCode: 'chain_rpc_budget_exceeded',
        stage: SquareApiStage.registration,
      ),
    );
    expect(result.status, SquareSessionStatus.serviceUnavailable);
    expect(result.errorCode, 'chain_rpc_budget_exceeded');
    expect(result.message, '公共链查询次数已达服务端限额，请稍后重试');
  });
  _preparationDiagnosticsTests();
  _chatAccessSessionTests();
  test('本机绑定缺失时聊天不触发身份恢复，普通会话仍由原门禁恢复', () async {
    final current = _DiagnosticCurrent()..hasBinding = false;
    final security = _DiagnosticSecurity();
    addTearDown(security.revision.dispose);
    var recoveryReads = 0;
    final gate = CidBusinessGate(
      currentUserContext: current,
      identityResolver: FinalizedIdentityResolver(
        getWalletState: () {
          recoveryReads++;
          throw StateError('合成身份恢复失败');
        },
      ),
      synchronizeIdentity: (_) async => fail('身份恢复无可提交的绑定'),
      revision: security.revision,
    );
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((_) async => fail('本机无绑定时不请求服务')),
    );
    final provider = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
      cidBusinessGate: gate,
      client: client,
    );
    final missing = isA<SquareApiException>().having(
      (error) => error.errorCode,
      'errorCode',
      'identity_local_missing',
    );
    await expectLater(provider.ensureChatSession(), throwsA(missing));
    await expectLater(
      provider.requestChatAccess(
        deviceId: testMlsDeviceId,
        expectedCidNumber: testMlsCidNumber,
        expectedBindingRevision: 1,
        expectedAccountId: testMlsAccountId,
      ),
      throwsA(missing),
    );
    expect(recoveryReads, 0);
    await expectLater(
      provider.ensureSession(),
      throwsA(isA<SquareApiException>()),
    );
    expect(recoveryReads, 1);
    expect(security.deviceRegistrations, 0);
  });
  test('明确取消保留取消分类，不变成服务故障或再次注册', () {
    for (final error in <Object>[
      const CitizenSdkException(
        code: CitizenSdkErrorCode.authenticationCancelled,
        message: 'synthetic detail',
      ),
      const AccountSecurityException(
        'synthetic detail',
        code: 'authenticationCancelled',
      ),
    ]) {
      final result = SquareSessionResolution.fromError(error);
      expect(result.errorCode, 'authenticationCancelled');
      expect(result.message, '设备授权已取消，可再次主动发起');
    }
  });
  test('MLS本地错误保留固定阶段及中文，不冒充网络或泄露技术文本', () {
    for (final code in [
      chat.MlsErrorCode.directoryInvalid,
      chat.MlsErrorCode.directoryUnavailable,
      chat.MlsErrorCode.stateMissing,
      chat.MlsErrorCode.storageReadFailed,
    ]) {
      final error = chat.MlsException(code, 'synthetic-private-path');
      final result = SquareSessionResolution.fromError(error);
      expect(result.status, SquareSessionStatus.deviceUnavailable);
      expect(result.stage, SquareApiStage.identity);
      expect(result.errorCode, 'mls_${error.diagnosticCode}');
      expect(result.message, error.userMessage);
      expect(result.message, isNot(contains('synthetic-private-path')));
    }
    expect(
      SquareSessionResolution.fromError(
        StateError('synthetic internal error'),
      ).status,
      SquareSessionStatus.serviceUnavailable,
    );
  });
  test('未知、已核实未注册和设备未登记保持不同状态及固定提示', () {
    const cases = {
      'identity_local_missing': SquareSessionStatus.identityUnavailable,
      'identity_unregistered': SquareSessionStatus.identityUnbound,
      'device_not_registered': SquareSessionStatus.deviceUnavailable,
    };
    for (final entry in cases.entries) {
      final result = SquareSessionResolution.fromError(
        SquareApiException(
          '不应进入提示的原始正文',
          errorCode: entry.key,
          stage: SquareApiStage.identity,
        ),
      );
      expect(result.status, entry.value);
      expect(result.message, isNot(contains('恢复服务')));
      expect(result.message, isNot(contains('原始正文')));
    }
  });
  // 真实HTTP解码与会话分类联测：未知状态及损坏响应不能伪装成MLS设备故障。
  for (final status in [200, 404, 429, 503]) {
    test('挑战非JSON响应$status保留阶段，分类为服务失败', () async {
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((_) async => http.Response('not-json', status)),
      );
      addTearDown(client.close);
      try {
        await client.ensureSession(
          accountId: testMlsAccountId,
          authentication: FakeMlsAuthentication(),
        );
        fail('损坏响应必须失败');
      } on SquareApiException catch (error) {
        final failure = SquareSessionResolution.fromError(error);
        expect(failure.status, SquareSessionStatus.serviceUnavailable);
        expect(failure.statusCode, status);
        expect(failure.stage, SquareApiStage.session);
        expect(failure.errorCode, isNull);
      }
    });
  }
  for (final error in [
    const SocketException('合成网络故障'),
    TimeoutException('合成超时'),
    http.ClientException('合成传输失败'),
  ]) {
    test('挑战传输${error.runtimeType}保留网络分类与阶段', () async {
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((_) async => throw error),
      );
      addTearDown(client.close);
      try {
        await client.ensureSession(
          accountId: testMlsAccountId,
          authentication: FakeMlsAuthentication(),
        );
        fail('传输失败必须拒绝');
      } on SquareApiException catch (failure) {
        final resolution = SquareSessionResolution.fromError(failure);
        expect(resolution.status, SquareSessionStatus.networkUnavailable);
        expect(resolution.stage, SquareApiStage.session);
        expect(resolution.errorCode, 'network_unavailable');
      }
    });
  }
  test('绑定改变、未登记和未知错误不混用，未知消息不进入诊断', () {
    expect(
      SquareSessionResolution.fromError(
        const SquareApiException(
          '合成',
          errorCode: 'cid_binding_changed',
          statusCode: 401,
        ),
      ).status,
      SquareSessionStatus.identityChanged,
    );
    expect(
      SquareSessionResolution.fromError(
        const SquareApiException(
          '合成',
          errorCode: 'device_not_registered',
          statusCode: 401,
        ),
      ).status,
      SquareSessionStatus.deviceUnavailable,
    );
    final failure = SquareSessionResolution.fromError(
      const SquareApiException(
        '不应持久保存的合成正文',
        errorCode: 'unrecognized_fixture',
        statusCode: 400,
      ),
    );
    expect(failure.status, SquareSessionStatus.serviceUnavailable);
    expect(failure.errorCode, isNull);
    expect(failure.message, isNot(contains('合成正文')));
  });
  // 与CitizenServe现行错误码联测：限流与配置故障属于服务，真人验证拒绝属于认证。
  for (final entry in {
    'request_rate_exceeded': (429, SquareSessionStatus.serviceUnavailable),
    'cid_not_bound': (409, SquareSessionStatus.identityUnavailable),
    'invalid_binding_signature': (401, SquareSessionStatus.deviceUnavailable),
  }.entries) {
    test('真实HTTP错误码${entry.key}保留类别、状态与阶段', () async {
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error_code': entry.key, 'message': '不应进入诊断的合成服务正文'}),
            entry.value.$1,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.close);
      try {
        await client.ensureSession(
          accountId: testMlsAccountId,
          authentication: FakeMlsAuthentication(),
        );
        fail('错误响应必须拒绝');
      } on SquareApiException catch (error) {
        final failure = SquareSessionResolution.fromError(error);
        expect(failure.status, entry.value.$2);
        expect(failure.statusCode, entry.value.$1);
        expect(failure.errorCode, entry.key);
        expect(failure.stage, SquareApiStage.session);
        expect(failure.message, isNot(contains('合成服务正文')));
      }
    });
  }
  test('缺绑定事实保持身份同步失败，不伪装为断网', () {
    final failure = SquareSessionResolution.fromError(
      const SquareApiException(
        '合成拒绝',
        errorCode: 'cid_not_bound',
        stage: SquareApiStage.registration,
      ),
    );
    expect(failure.status, SquareSessionStatus.identityUnavailable);
    expect(failure.statusCode, isNull);
    expect(failure.stage, SquareApiStage.registration);
    expect(failure.message, SquareSessionStatus.identityUnavailable.message);
  });
  for (final error in [
    'invalid_mls_signature',
    'invalid_mls_proof',
    'cid_not_bound',
  ]) {
    test('$error原样拒绝，不登记或重试', () async {
      var registerCalls = 0;
      var sessionCalls = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          sessionCalls++;
          return http.Response(
            jsonEncode({'error_code': error, 'message': '拒绝'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.ensureSession(
          accountId: testMlsAccountId,
          authentication: FakeMlsAuthentication(),
          onDeviceNotRegistered: (_) async {
            registerCalls++;
          },
        ),
        throwsA(
          isA<SquareApiException>().having((e) => e.errorCode, '错误码', error),
        ),
      );
      expect(registerCalls, 0);
      expect(sessionCalls, 1);
    });
  }
  for (final success in [true, false]) {
    test('未登记只登记一次；重试${success ? "成功" : "仍失败"}', () async {
      var registerCalls = 0;
      var sessionCalls = 0;
      final source = FakeMlsAuthentication();
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          sessionCalls++;
          if (sessionCalls == 1 || !success) {
            return http.Response(
              jsonEncode({
                'error_code': 'device_not_registered',
                'message': '未登记',
              }),
              401,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }),
      );
      addTearDown(client.close);
      final pending = client.ensureSession(
        accountId: testMlsAccountId,
        authentication: source,
        onDeviceNotRegistered: (identity) async {
          expect(identity.cidNumber, testMlsCidNumber);
          expect(identity.deviceId, testMlsDeviceId);
          registerCalls++;
        },
      );
      if (success) {
        expect((await pending).deviceId, testMlsDeviceId);
      } else {
        await expectLater(
          pending,
          throwsA(
            isA<SquareApiException>().having(
              (e) => e.errorCode,
              '错误码',
              'device_not_registered',
            ),
          ),
        );
      }
      expect(registerCalls, 1);
      expect(sessionCalls, 2);
      expect(source.proofCalls, 2);
    });
  }
}

class _UnusedChatSecurity implements AccountSecurityService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected security operation');
}

class _UnusedChatCurrent implements CurrentUserContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('late result must be rejected first');
}

class _ChatSessionFixture extends SquareSessionProvider {
  _ChatSessionFixture(
    SquareApiClient client,
    FakeMlsAuthentication source,
    this.session,
  ) : super(
        accountSecurity: _UnusedChatSecurity(),
        currentUserContext: _UnusedChatCurrent(),
        // 与本用例冻结的已注册会话一致，仍由原断言验证迟到许可被拒绝。
        client: client,
        authentication: source,
      );
  final SquareSession session;
  @override
  Future<SquareSession?> ensureChatSession() async => session;
}

void _chatAccessSessionTests() {
  for (final change in ['binding', 'revocation']) {
    test('聊天许可返回前$change发生，冻结会话拒绝迟到结果', () async {
      final source = FakeMlsAuthentication();
      var revoked = false;
      final session = SquareSession(
        sessionToken: 'ordinary',
        cidNumber: testMlsCidNumber,
        bindRev: 1,
        accountId: testMlsAccountId,
        deviceId: testMlsDeviceId,
        expiresAt: 4102444800000,
        authenticateRequest: fakeMlsRequestHeaders,
        requireCurrent: () async {
          if (revoked) {
            throw const MlsAuthenticationException(
              'synthetic revoked session',
              code: 'identityChanged',
            );
          }
        },
      );
      final api = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((_) async {
          if (change == 'binding') {
            source.identity = const MlsAuthenticationIdentity(
              cidNumber: testMlsCidNumber,
              accountId: testMlsAccountId,
              bindRev: 2,
              deviceId: testMlsDeviceId,
              publicKey: '0x$testMlsDeviceId',
            );
          } else {
            revoked = true;
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'realtime_url': 'wss://worker.test/api/chat/realtime',
              'access_token': 'opaque',
              'expires_at': now + 300000,
              'recheck_at': now + 120000,
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final provider = _ChatSessionFixture(api, source, session);
      await expectLater(
        provider.requestChatAccess(
          deviceId: testMlsDeviceId,
          expectedCidNumber: testMlsCidNumber,
          expectedBindingRevision: 1,
          expectedAccountId: testMlsAccountId,
        ),
        throwsA(
          isA<MlsAuthenticationException>().having(
            (e) => e.code,
            'code',
            'identityChanged',
          ),
        ),
      );
    });
  }
}

// 只模拟本机公民号绑定；任何额外身份操作都立即失败。
class _DiagnosticCurrent implements CurrentUserContext {
  Object? failure;
  bool hasBinding = true;
  final _sessionBinding = const IdentityBinding(
    genesisHash:
        '0xabababababababababababababababababababababababababababababababab',
    cidNumber: testMlsCidNumber,
    bindRev: 1,
    accountId: testMlsAccountId,
  );
  @override
  Future<CurrentUser?> resolve() async {
    if (failure != null) throw failure!;
    return CurrentUser(
      account: CitizenWalletStateAccount(
        signMode: CitizenWalletSignMode.hot,
        walletIndex: 7,
        accountIndex: 0,
        accountId: testMlsAccountId,
        ss58Address: 'synthetic-public-address',
        name: '合成账户',
        createdAtMillis: BigInt.one,
        isDefault: true,
      ),
      binding: hasBinding ? _sessionBinding : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected identity operation');
}

class _DiagnosticSecurity implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
  int deviceRegistrations = 0;
  final unexpected = <Symbol>[];
  @override
  Future<void> registerMlsDeviceForBinding(IdentityBinding binding) async {
    deviceRegistrations++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpected.add(invocation.memberName);
    throw StateError('unexpected security operation');
  }
}

void _preparationDiagnosticsTests() {
  for (final code in ['cid_not_bound', 'device_not_registered']) {
    test('已有CID的$code仅明确设备未登记恢复一次且不进入注册或真人验证', () async {
      final security = _DiagnosticSecurity(), current = _DiagnosticCurrent();
      final source = FakeMlsAuthentication(), lines = <String>[];
      var sessions = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/user/sessions');
          sessions++;
          return http.Response(
            jsonEncode({
              'error_code': code,
              'message': 'synthetic-private-preparation',
            }),
            403,
          );
        }),
      );
      addTearDown(client.close);
      addTearDown(security.revision.dispose);
      final provider = SquareSessionProvider(
        accountSecurity: security,
        currentUserContext: current,
        client: client,
        authentication: source,
      );
      await runZoned(
        () async {
          final result = await provider.resolveSession();
          expect(
            result.status,
            code == 'cid_not_bound'
                ? SquareSessionStatus.identityUnavailable
                : SquareSessionStatus.deviceUnavailable,
          );
          expect(result.errorCode, code);
          expect(result.stage, SquareApiStage.session);
          expect(result.statusCode, 403);
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      final attempts = code == 'device_not_registered' ? 2 : 1;
      expect(security.deviceRegistrations, attempts - 1);
      expect(security.unexpected, isEmpty); // 零CID注册、零Turnstile、零其它钱包操作。
      expect(sessions, attempts);
      expect(source.proofCalls, attempts);
      expect(
        lines,
        List.filled(
          attempts,
          '[CitizenFailure] stage=session http=403 code=$code',
        ),
      );
    });
  }
  for (final error in <Object>[
    const FormatException('synthetic-private-preparation'),
    StateError('synthetic-private-preparation'),
    const SocketException('synthetic-private-preparation'),
    const chat.MlsException(
      chat.MlsErrorCode.stateMissing,
      'synthetic-private-preparation',
    ),
  ]) {
    test('本地准备${error.runtimeType}保留原异常及安全分类且零网络', () async {
      final current = _DiagnosticCurrent()..failure = error;
      final lines = <String>[];
      var requests = 0;
      final client = SquareApiClient(
        httpClient: MockClient((_) async {
          requests++;
          throw StateError('must not request');
        }),
      );
      addTearDown(client.close);
      final provider = SquareSessionProvider(
        accountSecurity: _UnusedChatSecurity(),
        currentUserContext: current,
        client: client,
        authentication: FakeMlsAuthentication(),
      );
      await runZoned(
        () async {
          await expectLater(provider.ensureSession(), throwsA(same(error)));
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      final (stage, code) = switch (error) {
        FormatException() => ('prepare', 'format'),
        StateError() => ('prepare', 'state'),
        SocketException() => ('request', 'network_unavailable'),
        _ => ('identity', 'mls_state_missing'),
      };
      expect(requests, 0);
      expect(lines, ['[CitizenFailure] stage=$stage http=none code=$code']);
      expect(lines.join(), isNot(contains('synthetic-private-preparation')));
    });
  }
  test('已有CID在会话返回前切换代次，拒绝迟到结果且不登记或再次认证', () async {
    final security = _DiagnosticSecurity(), current = _DiagnosticCurrent();
    final reached = Completer<void>(), response = Completer<http.Response>();
    var sessions = 0;
    final source = FakeMlsAuthentication();
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        sessions++;
        reached.complete();
        return response.future;
      }),
    );
    addTearDown(client.close);
    addTearDown(security.revision.dispose);
    final provider = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
      client: client,
      authentication: source,
    );
    final pending = provider.resolveSession();
    await reached.future;
    security.revision.value++;
    response.complete(http.Response(jsonEncode(fakeMlsSession()), 200));
    expect((await pending).status, SquareSessionStatus.identityChanged);
    expect(security.deviceRegistrations, 0);
    expect(security.unexpected, isEmpty);
    expect(sessions, 1);
    expect(source.proofCalls, 1);
  });
}

// 以跨语言向量核对MLS设备登记SCALE和GMB操作域。

const _bindingAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _cidNumber = 'CN220-CTZN2-198805200-2026';
const _bindingRevision = 1;
final String _publicKey = '0x${'ab' * 32}';
const int _issuedAt = 1700000000000;
const _goldenHex =
    'ddf7ca6d82b5f2e364a710a72eb54159d401901cbea52b8cff3e1d8754ce605b';

void suite114() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();
  test(
    'buildMlsDeviceBindingSigningMessage matches Worker golden (0x1C)',
    () async {
      final message = await buildMlsDeviceBindingSigningMessage(
        _cidNumber,
        _bindingRevision,
        _bindingAccountId,
        _publicKey,
        _issuedAt,
      );
      expect(message.length, 32);
      expect(bytesToHex(message), _goldenHex);
    },
  );

  test('CitizenSDK Blake2Domain 输入与设备绑定逐字节共用 0x1C', () async {
    final payload = await encodeMlsDeviceBindingPayload(
      cidNumber: _cidNumber,
      bindRev: _bindingRevision,
      accountId: _bindingAccountId,
      publicKey: _publicKey,
      issuedAtMillis: _issuedAt,
    );
    final coldSigningMessage = (await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignMlsDeviceBind,
        scalePayload: payload,
      ),
    ));
    expect(bytesToHex(coldSigningMessage), _goldenHex);
  });
}
