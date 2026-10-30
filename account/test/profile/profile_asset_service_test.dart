import 'package:citizen_testing/membergate_fixture.dart'
    show preflightGateFixture;

import 'package:citizen_account/membership/subscription_service.dart';

import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_account/profile/profile_asset_service.dart';
import 'package:citizen_account/square_api_client.dart';

// 受保护请求在本地预检后使用当前会话的设备请求签名器；
// 测试用固定假签名占位，MockClient 不校验签名头。
SquareSession _session() => SquareSession(
  deviceId: testMlsDeviceId,
  sessionToken: 'tok',
  cidNumber: "CN220-CTZN2-198805200-2026",
  bindRev: 1,
  accountId:
      '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  authenticateRequest: fakeMlsRequestHeaders,
);

void main() {
  test('资料先压WebP，远端哈希和本地回执使用同份成品字节', () async {
    final session = _session(),
        compressed = Uint8List.fromList(List.filled(100, 7));
    SubscriptionService.resourceGate.observe('https://example.com', session, {
      'gate': preflightGateFixture(session),
    });
    var compression = 0, requests = 0;
    final client = SquareApiClient(
      baseUrl: 'https://example.com/api',
      httpClient: MockClient((request) async {
        requests++;
        if (request.method == 'POST') {
          final value = jsonDecode(request.body) as Map;
          expect(
            value.keys,
            unorderedEquals([
              'upload_kind',
              'content_type',
              'byte_size',
              'content_hash',
            ]),
          );
          expect(value['upload_kind'], 'avatar');
          expect(value['content_type'], 'image/webp');
          expect(value['byte_size'], 100);
          expect(value['content_hash'], sha256.convert(compressed).toString());
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'object_key': 'profile/acct/avatar',
              'upload_id': 'spa_test',
              'expires_at': DateTime.now().millisecondsSinceEpoch + 60000,
              'http_method': 'PUT',
              'upload_url': '/api/user/profile/assets/spa_test',
            }),
            200,
          );
        }
        expect(request.bodyBytes, compressed);
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'content_hash': sha256.convert(compressed).toString(),
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final service = ProfileAssetService(
      client: client,
      compress: (bytes, w, h, q) async {
        compression++;
        expect(bytes.length, 1000);
        return compressed;
      },
    );
    final result = await service.upload(
      session: session,
      uploadKind: 'avatar',
      bytes: Uint8List(1000),
      contentType: 'image/jpeg',
    );
    expect(compression, 1);
    expect(requests, 2);
    expect(result.bytes, compressed);
    expect(result.contentHash, sha256.convert(compressed).toString());
  });

  TestCitizenSdkHarness();
  setUp(() {
    final session = _session();
    SubscriptionService.resourceGate.observe('https://example.com', session, {
      'gate': preflightGateFixture(session),
    });
  });
  test('uploads bytes and returns the object key and hash', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final sha = sha256.convert(bytes).toString();
    Map<String, dynamic>? prepareBody;
    String? putAuth;
    List<int>? putBody;

    final client = SquareApiClient(
      baseUrl: 'https://example.com/api',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/user/profile/assets') {
          prepareBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'object_key': 'profile/acct/avatar',
              'upload_id': 'spa_test',
              'expires_at': DateTime.now().millisecondsSinceEpoch + 60000,
              'http_method': 'PUT',
              'upload_url': '/api/user/profile/assets/spa_test',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        putAuth = request.headers['authorization'];
        putBody = request.bodyBytes;
        return http.Response(
          jsonEncode({'is_ok': true, 'content_hash': sha}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await ProfileAssetService(client: client).upload(
      session: _session(),
      uploadKind: 'avatar',
      bytes: bytes,
      contentType: 'image/webp',
    );

    expect(result.objectKey, 'profile/acct/avatar');
    expect(result.contentHash, sha);
    expect(prepareBody!['content_hash'], sha);
    expect(prepareBody!['content_type'], 'image/webp');
    expect(prepareBody!['byte_size'], 5);
    expect(putBody, bytes);
    expect(putAuth, 'Bearer tok');
  });

  test('throws when the upload PUT fails', () async {
    final client = SquareApiClient(
      baseUrl: 'https://example.com/api',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/user/profile/assets') {
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'object_key': 'profile/a/avatar',
              'upload_id': 'spa_failure',
              'expires_at': DateTime.now().millisecondsSinceEpoch + 60000,
              'http_method': 'PUT',
              'upload_url': '/api/user/profile/assets/spa_failure',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/user/profile/assets/spa_failure');
        return http.Response('nope', 500);
      }),
    );

    await expectLater(
      ProfileAssetService(client: client).upload(
        session: _session(),
        uploadKind: 'avatar',
        bytes: Uint8List.fromList([1]),
        contentType: 'image/webp',
      ),
      throwsA(isA<SquareApiException>()),
    );
  });
}
