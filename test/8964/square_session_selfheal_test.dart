import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';

import 'mls_authentication_fixture.dart';

/// 只有明确未登记才编排一次登记；签名失败绝不触发钱包或重建MLS身份。
void main() {
  // 真实HTTP解码与会话分类联测：未知状态及损坏响应不能伪装成MLS设备故障。
  for (final status in [200, 404, 429, 503]) {
    test('挑战非JSON响应$status保留阶段，分类为服务失败', () async {
      final client = SquareApiClient(
        baseUrl: 'https://worker.test',
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
        baseUrl: 'https://worker.test',
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
    'turnstile_not_configured': (503, SquareSessionStatus.serviceUnavailable),
    'turnstile_failed': (403, SquareSessionStatus.deviceUnavailable),
    'invalid_binding_signature': (401, SquareSessionStatus.deviceUnavailable),
  }.entries) {
    test('真实HTTP错误码${entry.key}保留类别、状态与阶段', () async {
      final client = SquareApiClient(
        baseUrl: 'https://worker.test',
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
  test('本地真人验证取消保留登记阶段，不伪装为断网', () {
    final failure = SquareSessionResolution.fromError(
      const SquareApiException('合成取消', errorCode: 'turnstile_cancelled'),
    );
    expect(failure.status, SquareSessionStatus.deviceUnavailable);
    expect(failure.statusCode, isNull);
    expect(failure.stage, SquareApiStage.registration);
    expect(failure.message, '设备安全验证已取消，请重试');
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
        baseUrl: 'https://worker.test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenge')) {
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
        baseUrl: 'https://worker.test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenge')) {
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
