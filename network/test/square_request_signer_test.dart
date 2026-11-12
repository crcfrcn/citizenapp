import 'package:citizen_network/citizen_serve_api_config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_user/identity/mls_authentication.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_network/square_request_signer.dart';
import 'package:citizen_system/notifications/app_push_token.dart';

import 'package:citizen_testing/mls_authentication_fixture.dart';

Map<String, dynamic> _proof(Map<String, String> headers) =>
    jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(headers['x-mls-proof']!)),
          ),
        )
        as Map<String, dynamic>;

void main() {
  _httpTimingTests();
  test('共用 HTTPS Client 在发送前拒绝明文并禁止重定向', () async {
    var sent = 0;
    final client = HttpsOnlyClient(
      MockClient((request) async {
        sent++;
        expect(request.followRedirects, isFalse);
        return http.Response('{}', 200);
      }),
    );
    try {
      await client.get(Uri.parse('https://example.invalid'));
      expect(sent, 1);
      for (final scheme in ['http', 'ws']) {
        await expectLater(
          () => client.get(Uri.parse('$scheme://localhost')),
          throwsUnsupportedError,
        );
      }
      expect(sent, 1);
    } finally {
      client.close();
    }
  });

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
    expect(proof['http_method'], 'DELETE');
    expect(proof['request_target'], '/api/8964/search?cursor=a%2Fb');
    expect(proof['body_hash'], '0x${sha256.convert(snapshot)}');
  });
  test('会话与推送请求绑定实际正文和同一MLS设备，挑战带会话Bearer', () async {
    final source = FakeMlsAuthentication();
    var requests = 0;
    Map<String, dynamic>? pushBody;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
        requests++;

        final proof = _proof(request.headers);
        expect(proof['device_id'], source.identity.deviceId);
        expect(proof['public_key'], source.identity.publicKey);
        expect(proof['request_target'], request.url.path);
        expect(proof['body_hash'], '0x${sha256.convert(request.bodyBytes)}');
        if (request.url.path == '/api/user/sessions') {
          expect(jsonDecode(request.body), {'account_id': testMlsAccountId});
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }
        expect(request.url.path, '/api/notifications/endpoint');
        expect(request.method, 'PUT');
        expect(request.headers['authorization'], 'Bearer tok');
        pushBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'is_ok': true, 'expires_at': pushBody!['expires_at']}),
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
      'apns_env',
      'expires_at',
    });
    expect(pushBody!['push_token'], 'fcm-token-1234567890');
    expect(requests, 2);
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
    expect(requests, 2);
  });
  test('签名期间关闭认证，拒绝提交会话', () async {
    final source = FakeMlsAuthentication();
    source.beforeProof = () async {
      source.closed = true;
    };
    var submits = 0;
    final client = SquareApiClient(
      baseUrl: 'https://worker.test/api',
      httpClient: MockClient((request) async {
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
  for (final field in ['device_id', 'extra', 'account_id', 'bind_rev']) {
    test('会话响应$field与当前公开身份不符或多字段时拒绝缓存', () async {
      final source = FakeMlsAuthentication();
      var calls = 0;
      final client = SquareApiClient(
        baseUrl: 'https://worker.test/api',
        httpClient: MockClient((request) async {
          calls++;
          final response = fakeMlsSession()
            ..[field] = field == 'bind_rev' ? 2 : 'tampered';
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

// 内存端口验证消费时机及取消、背压、异常，不把测试等待当成生产延迟。
class _TimingClient extends http.BaseClient {
  _TimingClient(this.reply);
  final Future<http.StreamedResponse> Function(http.BaseRequest) reply;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      reply(request);
  @override
  void close() => closed = true;
}

void _httpTimingTests() {
  const canary = 'synthetic-private-http-detail';
  test('实际业务路径只输出固定功能类别，不输出动态路径或查询', () async {
    const paths = {
      '/api/user/sessions': 'session',
      '/api/user/contacts': 'contacts',
      '/api/membergate/creator/tiers': 'creator',
      '/api/membergate': 'membergate',
      '/api/user/profiles/synthetic': 'profile',
      '/api/user/cards/synthetic': 'card',
      '/api/8964/follows': 'follows',
      '/api/8964/feed': 'feed',
      '/api/8964/posts/synthetic/comments': 'comments',
      '/api/notifications': 'notifications',
      '/api/topup/confirm': 'topup_confirm',
      '/api/topup/status': 'topup_status',
      '/api/chat/access': 'chat_access',
    };
    for (final entry in paths.entries) {
      final lines = <String>[];
      final client = HttpsOnlyClient(
        _TimingClient(
          (_) async => http.StreamedResponse(Stream.value([1]), 200),
        ),
      );
      await runZoned(
        () async {
          await client.get(
            Uri.parse('https://www.crcfrcn.com${entry.key}?q=$canary'),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      client.close();
      expect(lines, hasLength(2));
      expect(lines.last, contains('stage=${entry.value} http=200'));
      expect(lines.last, endsWith('phase=complete'));
      expect(lines.join(), isNot(contains(canary)));
      expect(lines.join(), isNot(contains(entry.key)));
    }
  });
  final uri = Uri.parse('https://www.crcfrcn.com/api/user/sessions?q=$canary');
  Future<List<String>> capture(Future<void> Function() action) async {
    final lines = <String>[];
    await runZoned(
      action,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.join(), isNot(contains(canary)));
    return lines;
  }

  test('HTTP计时不预读，保留元数据、背压、正文和关闭', () async {
    final source = StreamController<List<int>>();
    final request = http.Request('POST', uri)
      ..headers['authorization'] = canary
      ..body = canary;
    final inner = _TimingClient((sent) async {
      expect(sent, same(request));
      expect(sent.followRedirects, isFalse);
      return http.StreamedResponse(
        source.stream,
        206,
        request: sent,
        contentLength: 3,
        headers: {'x-test': 'kept'},
        reasonPhrase: 'Partial Content',
        persistentConnection: false,
      );
    });
    final client = HttpsOnlyClient(inner);
    final lines = await capture(() async {
      final response = await client.send(request);
      expect(source.hasListener, isFalse);
      expect(response.request, same(request));
      expect(response.contentLength, 3);
      expect(response.headers['x-test'], 'kept');
      expect(response.reasonPhrase, 'Partial Content');
      expect(response.persistentConnection, isFalse);
      final bytes = <int>[];
      final done = Completer<void>();
      final subscription = response.stream.listen(
        bytes.addAll,
        onDone: done.complete,
      );
      await Future<void>.delayed(Duration.zero);
      expect(source.hasListener, isTrue);
      subscription.pause();
      await Future<void>.delayed(Duration.zero);
      expect(source.isPaused, isTrue);
      subscription.resume();
      source.add([1, 2, 3]);
      await source.close();
      await done.future;
      expect(bytes, [1, 2, 3]);
      client.close();
      expect(inner.closed, isTrue);
    });
    expect(lines.length, 2);
    expect(lines.first, contains('stage=session http=206'));
    expect(lines.first, endsWith('phase=headers'));
    expect(lines.last, endsWith('phase=complete'));
    final timing = RegExp(
      r'headers_us=(\d+) total_us=(\d+)',
    ).firstMatch(lines.last)!;
    expect(int.parse(timing[2]!), greaterThanOrEqualTo(int.parse(timing[1]!)));
  });
  test('HTTP取消透传且不宣告正文完成', () async {
    var cancelled = 0;
    final source = StreamController<List<int>>(
      onCancel: () {
        cancelled++;
      },
    );
    final client = HttpsOnlyClient(
      _TimingClient((_) async => http.StreamedResponse(source.stream, 200)),
    );
    final lines = await capture(() async {
      final response = await client.send(http.Request('GET', uri));
      final subscription = response.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      client.close();
    });
    expect(cancelled, 1);
    expect(lines.length, 2);
    expect(lines.last, endsWith('phase=cancelled'));
  });
  for (final body in [false, true]) {
    test('HTTP错误$body保留原异常且只结束一次', () async {
      final failure = StateError(canary);
      final client = HttpsOnlyClient(
        _TimingClient((_) async {
          if (!body) throw failure;
          return http.StreamedResponse(Stream<List<int>>.error(failure), 200);
        }),
      );
      final lines = await capture(() async {
        await expectLater(client.get(uri), throwsA(same(failure)));
        client.close();
      });
      expect(lines.where((line) => line.endsWith('phase=error')).length, 1);
      expect(lines.join(), isNot(contains('phase=complete')));
    });
  }
  test('非所属源保持原响应对象且不输出正式服务计时', () async {
    final original = http.StreamedResponse(Stream.value([1]), 200);
    final client = HttpsOnlyClient(_TimingClient((_) async => original));
    final lines = await capture(() async {
      final response = await client.send(
        http.Request(
          'GET',
          Uri.parse('https://other.invalid/api/user/sessions'),
        ),
      );
      expect(response, same(original));
      await response.stream.drain<void>();
      client.close();
    });
    expect(lines, isEmpty);
  });
}
