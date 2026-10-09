import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/services/square_request_signer.dart';
import 'package:citizenapp/notifications/app_push_token.dart';

import 'mls_authentication_fixture.dart';

Map<String, dynamic> _proof(Map<String, String> headers) => jsonDecode(
  utf8.decode(base64Url.decode(base64Url.normalize(headers['x-mls-proof']!))),
) as Map<String, dynamic>;

void main() {
  test('正文冻结并保留完整/api路径、查询和DELETE正文', () async {
    final input = Uint8List.fromList(utf8.encode('{"说明":"公民"}'));
    final snapshot = input.toList();
    final entered = Completer<void>(), release = Completer<void>();
    List<int>? captured;
    final pending = squareRequestHeadersForBytes(
      method: 'DELETE',
      uri: Uri.parse('https://worker.test/api/8964/search?cursor=a%2Fb'),
      body: input,
      sessionToken: 'tok',
      authenticate:
          ({
            required method,
            required uri,
            required body,
            required sessionToken,
          }) async {
            captured = body;
            entered.complete();
            await release.future;
            return fakeMlsRequestHeaders(
              method: method,
              uri: uri,
              body: body,
              sessionToken: sessionToken,
            );
          },
    );
    await entered.future;
    input.fillRange(0, input.length, 0);
    release.complete();
    final headers = await pending;
    expect(headers.keys, ['x-mls-proof']);
    expect(headers.values.single.contains('='), false);
    expect(captured, snapshot);
    expect(() => captured![0] = 0, throwsUnsupportedError);
    final proof = _proof(headers);
    expect(proof['method'], 'DELETE');
    expect(proof['request_target'], '/api/8964/search?cursor=a%2Fb');
    expect(proof['body_sha256'], '0x${sha256.convert(snapshot)}');
  });
  test('会话与推送请求绑定实际正文和同一MLS设备，挑战带会话Bearer', () async {
    final source = FakeMlsAuthentication();
    var requests = 0;
    Map<String, dynamic>? pushBody;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        requests++;
        if (request.url.path == '/api/user/challenges') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {
            'account_id',
            'public_key',
            'purpose',
            'method',
            'request_target',
            'body_sha256',
          });
          if (body['purpose'] == 'request') {
            expect(request.headers['authorization'], 'Bearer tok');
          }
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
        final proof = _proof(request.headers);
        expect(proof['device_id'], source.identity.deviceId);
        expect(proof['public_key'], source.identity.publicKey);
        expect(proof['request_target'], request.url.path);
        expect(proof['body_sha256'], '0x${sha256.convert(request.bodyBytes)}');
        if (request.url.path == '/api/user/sessions') {
          expect(jsonDecode(request.body), {'account_id': testMlsAccountId});
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }
        expect(request.url.path, '/api/notifications/endpoint');
        expect(request.method, 'PUT');
        expect(request.headers['authorization'], 'Bearer tok');
        pushBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': true, 'expires_at': pushBody!['expires_at']}),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final session = await client.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
    );
    await client.registerPushEndpoint(
      session: session,
      endpoint: const AppPushToken(
        provider: 'fcm',
        token: 'fcm-token-1234567890',
        apnsEnvironment: null,
      ),
    );
    expect(pushBody!.keys.toSet(), {
      'push_provider',
      'push_token',
      'apns_environment',
      'expires_at',
    });
    expect(pushBody!['push_token'], 'fcm-token-1234567890');
    expect(requests, 4);
    expect(source.proofCalls, 2);
    expect(
      identical(
        await client.ensureSession(
          accountId: testMlsAccountId,
          authentication: source,
        ),
        session,
      ),
      true,
    );
    expect(requests, 4);
  });
  for (final field in [
    'user_id',
    'device_id',
    'public_key',
    'account_id',
    'binding_revision',
    'service_origin',
    'method',
    'request_target',
    'body_sha256',
    'extra',
  ]) {
    test('挑战$field被改动时不进入签名和会话提交', () async {
      final source = FakeMlsAuthentication();
      var submits = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenges')) {
            final challenge = fakeMlsChallenge(request)
              ..[field] = field == 'binding_revision' ? 2 : 'tampered';
            return http.Response(jsonEncode(challenge), 200);
          }
          submits++;
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.ensureSession(
          accountId: testMlsAccountId,
          authentication: source,
        ),
        throwsA(isA<MlsAuthenticationException>()),
      );
      expect(source.proofCalls, 0);
      expect(submits, 0);
    });
  }
  test('签名期间关闭认证，拒绝提交会话', () async {
    final source = FakeMlsAuthentication();
    source.beforeProof = () async {
      source.closed = true;
    };
    var submits = 0;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/challenges')) {
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
        submits++;
        return http.Response(jsonEncode(fakeMlsSession()), 200);
      }),
    );
    addTearDown(client.close);
    await expectLater(
      client.ensureSession(accountId: testMlsAccountId, authentication: source),
      throwsA(isA<MlsAuthenticationException>()),
    );
    expect(submits, 0);
  });
  test('并发共享握手，失效后迟到响应不得缓存', () async {
    final entered = Completer<void>(), response = Completer<http.Response>();
    var calls = 0;
    final source = FakeMlsAuthentication();
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/challenges')) {
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
        calls++;
        if (calls == 1) {
          entered.complete();
          return response.future;
        }
        return http.Response(jsonEncode(fakeMlsSession()), 200);
      }),
    );
    addTearDown(client.close);
    final first = client.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
    );
    final second = client.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
    );
    final rejectedFirst = expectLater(
      first,
      throwsA(isA<MlsAuthenticationException>()),
    );
    final rejectedSecond = expectLater(
      second,
      throwsA(isA<MlsAuthenticationException>()),
    );
    await entered.future;
    expect(calls, 1);
    client.clearSession(testMlsAccountId);
    response.complete(http.Response(jsonEncode(fakeMlsSession()), 200));
    await Future.wait([rejectedFirst, rejectedSecond]);
    await client.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
    );
    expect(calls, 2);
  });
  test('业务HTTP晚返回时认证已关闭，拒绝消费结果', () async {
    final source = FakeMlsAuthentication();
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/challenges')) {
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }
        source.closed = true;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final session = await client.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
    );
    await expectLater(
      client.registerPushEndpoint(
        session: session,
        endpoint: const AppPushToken(
          provider: 'fcm',
          token: 'fcm-token-1234567890',
          apnsEnvironment: null,
        ),
      ),
      throwsA(isA<MlsAuthenticationException>()),
    );
  });
  test('过期挑战不能进入SDK签名或会话提交', () async {
    final source = FakeMlsAuthentication();
    var submits = 0;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/challenges')) {
          final value = fakeMlsChallenge(request)
            ..['expires_at_millis'] = DateTime.now().millisecondsSinceEpoch - 1;
          return http.Response(jsonEncode(value), 200);
        }
        submits++;
        return http.Response(jsonEncode(fakeMlsSession()), 200);
      }),
    );
    addTearDown(client.close);
    await expectLater(
      client.ensureSession(accountId: testMlsAccountId, authentication: source),
      throwsArgumentError,
    );
    expect(source.proofCalls, 0);
    expect(submits, 0);
  });

  for (final field in [
    'device_id',
    'extra',
    'account_id',
    'binding_revision',
  ]) {
    test('会话响应$field与当前公开身份不符或多字段时拒绝缓存', () async {
      final source = FakeMlsAuthentication();
      var calls = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/challenges')) {
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
          calls++;
          final response = fakeMlsSession()
            ..[field] = field == 'binding_revision' ? 2 : 'tampered';
          return http.Response(jsonEncode(response), 200);
        }),
      );
      addTearDown(client.close);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          client.ensureSession(
            accountId: testMlsAccountId,
            authentication: source,
          ),
          throwsA(isA<MlsAuthenticationException>()),
        );
      }
      expect(calls, 2);
    });
  }
}
