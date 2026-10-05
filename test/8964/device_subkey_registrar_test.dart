import '../support/fake_citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizenapp/8964/services/device_subkey_registrar.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/security/device_subkey.dart';
import 'package:citizenapp/security/account_security_service.dart';

/// 只覆写 publicKeyHex（返回**裸**公钥），其余走原生桥（本测试不触发）。
class _FakeDeviceSubkey extends DeviceSubkey {
  _FakeDeviceSubkey(this._pub);
  final String _pub;
  @override
  Future<String> publicKeyHex(String cidNumber) async => _pub;

  @override
  Future<String> signRawHex(String cidNumber, Uint8List payload) async =>
      'aa' * 64;
}

const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _binding = AccountDataBinding(
  genesisHash:
      '0xabababababababababababababababababababababababababababababababab',
  cidNumber: 'CN220-CTZN2-198805200-2026',
  bindingRevision: 1,
  accountId: _accountId,
);

class _SessionApi extends SquareApiClient {
  _SessionApi({required this.deviceMissing});

  final bool deviceMissing;

  @override
  Future<SquareSession> ensureSession({
    required String accountId,
    required SquareLoginSigner signLoginPayload,
    SquareMissingDeviceHandler? onDeviceNotRegistered,
  }) async {
    final context = SquareLoginContext(
      cidNumber: _binding.cidNumber,
      bindingRevision: _binding.bindingRevision,
      accountId: accountId,
    );
    await signLoginPayload(context, Uint8List(32));
    if (deviceMissing) {
      if (onDeviceNotRegistered == null) {
        throw const SquareApiException(
          '设备尚未登记',
          errorCode: 'device_not_registered',
        );
      }
      await onDeviceNotRegistered(context);
    }
    return SquareSession(
      sessionToken: 'session',
      cidNumber: _binding.cidNumber,
      bindingRevision: _binding.bindingRevision,
      accountId: accountId,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      signRequest: (message) => signLoginPayload(context, message),
    );
  }
}

class _SessionWalletManager implements AccountSecurityService {
  int registrationCalls = 0;
  bool rejectPrivatePreparation = false;
  bool prepared = false;
  @override
  Future<void> prepareFirstDeviceForBinding(
    AccountDataBinding binding, {
    bool registerDevice = false,
  }) async {
    if (!registerDevice && rejectPrivatePreparation) {
      throw const AccountSecurityException('private keys unavailable');
    }
    if (!prepared && registerDevice) registrationCalls++;
    prepared = true;
  }

  @override
  Future<AccountDataBinding> accountDataBindingForAccountId(
    String accountId,
  ) async => _binding;

  @override
  Future<AccountDataBinding?> readAccountDataBindingForAccountId(
    String accountId,
  ) async => _binding;

  @override
  Future<void> activateAccountDataBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) async {}

  @override
  Future<void> registerDeviceSubkeyForBinding(
    AccountDataBinding binding,
  ) async {
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

class _ProofStore implements LocalKeyBlobStore {
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

void main() {
  TestCitizenSdkHarness();
  test('注册 wire 的 p256_public_key 带 0x 前缀（ADR-041），公钥本身裸', () async {
    // 65 字节未压缩点裸 hex（04 || 128 hex）。
    final barePub = '04${'a' * 128}';
    const accountId =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    Map<String, dynamic>? registerBody;

    final api = SquareApiClient(
      baseUrl: 'https://square.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/square/auth/device/register') {
          registerBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final registrar = DeviceSubkeyRegistrar(
      proofStore: _ProofStore(),
      deviceSubkey: _FakeDeviceSubkey(barePub),
      apiClient: api,
      turnstileToken: () async => 'turnstile-device-bind-token',
    );

    await registrar.register(
      cidNumber: 'CN220-CTZN2-198805200-2026',
      bindingRevision: 1,
      accountId: accountId,
      signBinding: ({
        required payload,
        required signingMessage,
        required devicePublicKey,
        required issuedAtMillis,
      }) async => '0x${'bb' * 64}',
      issuedAtMillis: 1700000000000,
    );

    // wire 文本统一带 0x（拒裸）；公钥值本体保持裸，仅前缀。
    expect(registerBody, isNotNull);
    expect(registerBody!['p256_public_key'], '0x$barePub');
    expect(registerBody!['account_id'], accountId);
    expect(registerBody!['binding_signature'], '0x${'bb' * 64}');
    expect(registerBody!['turnstile_token'], 'turnstile-device-bind-token');
  });

  test('网络失败后新实例复用首次签名，并用硬件挑战恢复而不重复验证', () async {
    final store = _ProofStore();
    var failNetwork = true;
    var signatures = 0;
    var verifications = 0;
    final bodies = <Map<String, dynamic>>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path == '/square/auth/challenge') {
          expect(body['device_registration'], true);
          return http.Response(
            jsonEncode({
              'challenge_id': 'sqdr_recovery',
              'account_id': _accountId,
              'cid_number': _binding.cidNumber,
              'binding_revision': 1,
              'signing_payload_hex': '0x00',
            }),
            200,
          );
        }
        bodies.add(body);
        if (failNetwork) throw StateError('network');
        return http.Response('{"ok":true}', 200);
      }),
    );
    DeviceSubkeyRegistrar registrar({String? publicKey}) =>
        DeviceSubkeyRegistrar(
          proofStore: store,
          deviceSubkey: _FakeDeviceSubkey(publicKey ?? '04${'aa' * 64}'),
          apiClient: api,
          turnstileToken: () async {
            verifications++;
            return 'turnstile-device-bind-token';
          },
        );
    Future<void> register(DeviceSubkeyRegistrar value) => value.register(
      cidNumber: _binding.cidNumber,
      bindingRevision: 1,
      accountId: _accountId,
      issuedAtMillis: 1700000000000,
      signBinding:
          ({
            required payload,
            required signingMessage,
            required devicePublicKey,
            required issuedAtMillis,
          }) async {
            signatures++;
            return '0x${'bb' * 64}';
          },
    );
    await expectLater(register(registrar()), throwsStateError);
    failNetwork = false;
    await register(registrar());
    expect(signatures, 1);
    expect(verifications, 1);
    expect(bodies.last['issued_at'], bodies.first['issued_at']);
    expect(bodies.last['binding_signature'], bodies.first['binding_signature']);
    expect(bodies.last['recovery_challenge_id'], 'sqdr_recovery');
    expect(bodies.last['recovery_signature'], '0x${'aa' * 64}');
    expect(bodies.last.containsKey('turnstile_token'), false);
    await expectLater(
      register(registrar(publicKey: '04${'cc' * 64}')),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.errorCode,
          'code',
          'device_proof_invalid',
        ),
      ),
    );
    expect(signatures, 1);
    store.entries[deviceRegistrationProofKey(
          _binding.cidNumber,
          1,
          _accountId,
        )] =
        '[]';
    await expectLater(
      register(registrar()),
      throwsA(isA<SquareApiException>()),
    );
    expect(signatures, 1);
  });

  test('冷启动等待根导航器就绪后只展示一次设备验证', () async {
    var readyChecks = 0;
    var presentCalls = 0;
    final token = await acquireDeviceBindingTurnstileToken(
      isUiReady: () => ++readyChecks >= 3,
      present: () async {
        presentCalls++;
        return 'turnstile-device-bind-token';
      },
      delay: (_) async {},
    );

    expect(token, 'turnstile-device-bind-token');
    expect(presentCalls, 1);
  });

  test('根导航器超时不提交空 token', () async {
    await expectLater(
      acquireDeviceBindingTurnstileToken(
        isUiReady: () => false,
        present: () async => 'turnstile-device-bind-token',
        readyTimeout: Duration.zero,
        delay: (_) async {},
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'turnstile_ui_unavailable',
        ),
      ),
    );
  });

  test('用户取消设备验证时失败关闭且不产生空 token', () async {
    await expectLater(
      acquireDeviceBindingTurnstileToken(
        isUiReady: () => true,
        present: () async => null,
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'turnstile_cancelled',
        ),
      ),
    );
  });

  test('广场既有会话静默，缺设备协调一次首次准备', () async {
    final existingWallet = _SessionWalletManager()
      ..rejectPrivatePreparation = true;
    final existing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: false),
      accountSecurity: existingWallet,
      deviceSubkey: _FakeDeviceSubkey('04${'a' * 128}'),
      currentUserContext: _SessionIdentityCache(),
    );
    expect(await existing.ensureSession(), isNotNull);
    expect(existingWallet.registrationCalls, 0);

    final missingWallet = _SessionWalletManager();
    final missing = SquareSessionProvider(
      client: _SessionApi(deviceMissing: true),
      accountSecurity: missingWallet,
      deviceSubkey: _FakeDeviceSubkey('04${'b' * 128}'),
      currentUserContext: _SessionIdentityCache(),
    );
    expect(await missing.ensureSession(), isNotNull);
    expect(missingWallet.registrationCalls, 1);
    expect(await missing.ensureSession(), isNotNull);
    expect(missingWallet.registrationCalls, 1);
  });
}
