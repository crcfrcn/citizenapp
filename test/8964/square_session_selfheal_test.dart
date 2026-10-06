import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';

import 'mls_authentication_fixture.dart';

/// 只有明确未登记才编排一次登记；签名失败绝不触发钱包或重建MLS身份。
void main() {
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
