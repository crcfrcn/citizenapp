import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/account/identity/public_identity_store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';

import 'dart:convert';
import 'dart:async';

import 'package:citizen_sdk/account_codec.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/mls_authentication.dart';
import 'package:citizenapp/account/identity/mls_device_registrar.dart';
import 'package:citizenapp/network/square_api_client.dart';

import '../support/fake_citizen_sdk.dart';
import 'mls_authentication_fixture.dart';

const _accountId = testMlsAccountId;
const _binding = IdentityBinding(
  genesisHash:
      "0xabababababababababababababababababababababababababababababababab",
  cidNumber: testMlsCidNumber,
  bindingRevision: 1,
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

class _SessionWalletManager implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
  int registrationCalls = 0;
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
    required int bindingRevision,
    required String accountId,
  }) async {}

  @override
  Future<void> registerMlsDeviceForBinding(IdentityBinding binding) async {
    registrationCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionIdentityCache implements CurrentUserContext {
  _SessionIdentityCache({this.localBinding = _binding});
  final IdentityBinding? localBinding;
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
  'ok': true,
  'cid_number': testMlsCidNumber,
  'binding_revision': 1,
  'device_id': testMlsDeviceId,
};

Future<void> _register(
  MlsDeviceRegistrar registrar, {
  DeviceBindingSigner? signer,
}) => registrar.register(
  cidNumber: testMlsCidNumber,
  bindingRevision: 1,
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
class _AttemptWallet implements CitizenSdkWallet, CitizenSigning {
  _AttemptWallet({
    this.cold = false,
    this.failure = CitizenSdkErrorCode.authenticationCancelled,
  });
  final bool cold;
  final CitizenSdkErrorCode failure;
  int signs = 0;
  Completer<void>? barrier;
  @override
  CitizenSdkOperation<CitizenWalletState> getState() => testCitizenOperation(
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
  @override
  CitizenSdkOperation<CitizenSigningOutcome> begin(
    CitizenSigningIntent intent,
  ) => testCitizenOperation(() async {
    signs++;
    await barrier?.future;
    throw CitizenSdkException(code: failure, message: '合成签名终态');
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('不应调用此钱包能力');
}

void main() {
  Future<AccountSecurityService> attemptSecurity(
    _AttemptWallet wallet,
    _ProofStore records, {
    void Function()? onCold,
  }) async {
    final service = AccountSecurityService(
      wallet: wallet,
      signing: wallet,
      blobStore: records,
      mlsDeviceRegistrar:
          ({
            required cidNumber,
            required bindingRevision,
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
      bindingRevision: 1,
      accountId: _accountId,
    );
    return service;
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

  test("普通会话未登记直接拒绝，仅显式入口协调一次登记", () async {
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
    for (final ordinary in [
      missing.ensureSession,
      missing.refreshSession,
      () => missing.ensureSessionForAccountId(_accountId),
    ]) {
      await expectLater(
        ordinary(),
        throwsA(
          isA<SquareApiException>().having(
            (e) => e.errorCode,
            '错误码',
            'device_not_registered',
          ),
        ),
      );
      expect(missingWallet.registrationCalls, 0);
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
    var wallets = 0, capabilityReads = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(store.entries, hasLength(1));
        if (request.url.path.endsWith('/challenges')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['purpose'], 'registration');
          expect(body['public_key'], source.identity.publicKey);
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
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
      registrationCapabilities: (_) async {
        capabilityReads++;
        expect(store.entries, hasLength(1));
        return const RegistrationCapabilities('enrollment', 'recovery');
      },
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
    expect(capabilityReads, 1);
    expect(requests, hasLength(1));
    expect(requests.single.keys.toSet(), {
      'account_id',
      'public_key',
      'issued_at',
      'binding_signature',
      'enrollment_id',
      'recovery_token',
    });
    expect(requests.single['public_key'], source.identity.publicKey);
    expect(requests.single['binding_signature'], '0x${'bb' * 64}');
  });

  for (final rowExists in [true, false]) {
    test('回执丢失后复用钱包授权和登记能力：$rowExists', () async {
      final store = _ProofStore(), source = FakeMlsAuthentication();
      var failNetwork = true, wallets = 0, capabilityReads = 0;
      final bodies = <Map<String, dynamic>>[];
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenges')) {
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
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
        registrationCapabilities: (_) async {
          capabilityReads++;
          return const RegistrationCapabilities('enrollment', 'recovery');
        },
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
      expect(capabilityReads, 2);
      expect(bodies[1]['enrollment_id'], 'enrollment');
      expect(bodies[1].containsKey('turnstile_token'), false);
      expect(
        bodies.last['binding_signature'],
        bodies.first['binding_signature'],
      );
      expect(bodies.last['issued_at'], bodies.first['issued_at']);
      expect(source.proofCalls, 2);
    });
  }

  test('授权保存失败，不读取登记能力或网络', () async {
    final store = _ProofStore()..rejectWrite = true;
    var capabilityReads = 0, requests = 0;
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
      registrationCapabilities: (_) async {
        capabilityReads++;
        return const RegistrationCapabilities('enrollment', 'recovery');
      },
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
    expect(capabilityReads, 0);
    expect(requests, 0);
  });

  test('保存授权对应另一个MLS设备时拒绝，禁止重新钱包签名', () async {
    final store = _ProofStore();
    store.entries[deviceRegistrationProofKey(
      testMlsCidNumber,
      1,
      testMlsAccountId,
    )] = jsonEncode({
      'cid_number': testMlsCidNumber,
      'binding_revision': 1,
      'account_id': testMlsAccountId,
      'public_key': '0x${'bc' * 32}',
      'issued_at': 1700000000000,
      'signature': '0x${'bb' * 64}',
    });
    var wallets = 0;
    final registrar = MlsDeviceRegistrar(
      authentication: FakeMlsAuthentication(),
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
              wallets++;
              return '0x${'bb' * 64}';
            },
      ),
      throwsA(
        isA<SquareApiException>().having(
          (e) => e.errorCode,
          '错误码',
          'device_proof_invalid',
        ),
      ),
    );
    expect(wallets, 0);
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
        if (request.url.path.endsWith('/challenges')) {
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
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
    expect(body!.containsKey('enrollment_id'), true);
    expect(body!['enrollment_id'], isNull);
    expect(body!.containsKey('recovery_token'), true);
    expect(body!['recovery_token'], isNull);
    expect(body!.containsKey('turnstile_token'), false);
  });
}
