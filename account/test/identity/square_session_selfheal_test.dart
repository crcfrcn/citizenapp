import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_sdk/citizen_sdk.dart'
    show
        CitizenSdkException,
        CitizenSdkErrorCode,
        CitizenWalletStateAccount,
        CitizenWalletSignMode;
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:citizen_account/identity/identity_binding.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_account/identity/mls_authentication.dart';

import 'package:citizen_testing/mls_authentication_fixture.dart';

/// 只有明确未登记才编排一次登记；签名失败绝不触发钱包或重建MLS身份。
void main() {
  _preparationDiagnosticsTests();
  _chatAccessSessionTests();
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
      sdk.MlsNativeErrorCode.directoryInvalid,
      sdk.MlsNativeErrorCode.directoryUnavailable,
      sdk.MlsNativeErrorCode.stateMissing,
      sdk.MlsNativeErrorCode.storageReadFailed,
    ]) {
      final error = sdk.MlsNativeException(code, 'synthetic-private-path');
      final result = SquareSessionResolution.fromError(error);
      expect(result.status, SquareSessionStatus.deviceUnavailable);
      expect(result.stage, SquareApiStage.identity);
      expect(result.errorCode, 'mls_${error.diagnosticCode}');
      expect(result.message, error.userMessage);
      expect(result.message, isNot(contains('synthetic-private-path')));
    }
    expect(
      SquareSessionResolution.fromError(StateError('synthetic internal error'))
          .status,
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
        expect(failure.stage, SquareApiStage.challenge);
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
        expect(resolution.stage, SquareApiStage.challenge);
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
    'mls_challenge_limit_reached': (
      429,
      SquareSessionStatus.serviceUnavailable,
    ),
    'request_rate_exceeded': (429, SquareSessionStatus.serviceUnavailable),
    'registration_required': (403, SquareSessionStatus.deviceUnavailable),
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
        expect(failure.stage, SquareApiStage.challenge);
        expect(failure.message, isNot(contains('合成服务正文')));
      }
    });
  }
  test('未准入保留登记阶段，不伪装为断网', () {
    final failure = SquareSessionResolution.fromError(
      const SquareApiException(
        '合成拒绝',
        errorCode: 'registration_required',
        stage: SquareApiStage.registration,
      ),
    );
    expect(failure.status, SquareSessionStatus.deviceUnavailable);
    expect(failure.statusCode, isNull);
    expect(failure.stage, SquareApiStage.registration);
    expect(failure.message, '公民服务准备未完成，请重试');
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
          if (request.url.path.endsWith('/challenges')) {
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
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
          if (request.url.path.endsWith('/challenges')) {
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
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
  Future<SquareSession?> ensureSession() async => session;
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
              'realtime_url': 'wss://worker.test/api/tatachat/realtime',
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

// 已有CID的合成上下文：所有未列明操作（含CID注册/Turnstile）均立即失败。
class _DiagnosticCurrent implements CurrentUserContext {
  Object? failure;
  final _binding = const IdentityBinding(
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
      binding: _binding,
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
  for (final code in ['registration_required', 'device_not_registered']) {
    test('已有CID的$code仅明确设备未登记恢复一次且不进入注册或真人验证', () async {
      final security = _DiagnosticSecurity(), current = _DiagnosticCurrent();
      final source = FakeMlsAuthentication(), lines = <String>[];
      var sessions = 0, challenges = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenges')) {
            challenges++;
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
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
          expect(result.status, SquareSessionStatus.deviceUnavailable);
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
      expect(challenges, attempts);
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
    const sdk.MlsNativeException(
      sdk.MlsNativeErrorCode.stateMissing,
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
        if (request.url.path.endsWith('/challenges')) {
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
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
