import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/security/public_identity_store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/8964/profile/square_session_provider.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/8964/services/mls_device_registrar.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';

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
  _SessionApi({required this.deviceMissing});
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
    return fakeSquareSession(accountId);
  }
}

class _SessionWalletManager implements AccountSecurityService {
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
    binding: _binding,
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

void main() {
  TestCitizenSdkHarness();
  test("普通会话只使用 MLS，未登记只协调一次授权登记", () async {
    final existingWallet = _SessionWalletManager();
    final existing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: false),
      accountSecurity: existingWallet,
      authentication: FakeMlsAuthentication(),
      currentUserContext: _SessionIdentityCache(),
    );
    expect(await existing.ensureSession(), isNotNull);
    expect(existingWallet.registrationCalls, 0);
    final missingWallet = _SessionWalletManager();
    final missing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: true),
      accountSecurity: missingWallet,
      authentication: FakeMlsAuthentication(),
      currentUserContext: _SessionIdentityCache(),
    );
    expect(await missing.ensureSession(), isNotNull);
    expect(await missing.ensureSession(), isNotNull);
    expect(missingWallet.registrationCalls, 1);
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
