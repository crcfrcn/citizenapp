import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/8964/feed/square_models.dart';

import 'mls_authentication_fixture.dart';

void main() {
  _chatAccessTests();
  for (final status in [401, 403, 429, 503]) {
    for (final data in <Map<String, Object?>>[
      {'error': 'device_not_registered'},
      {},
      {'error': 1},
      {'error': null},
      {
        'error': {'code': 'device_not_registered'},
      },
      {'error_code': 'device_not_registered'},
    ]) {
      test('真实错误字段$status/$data仅接受error字符串且不重试', () async {
        var calls = 0;
        final api = SquareApiClient(
          baseUrl: 'https://square.test/api',
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(jsonEncode(data), status);
          }),
        );
        addTearDown(api.close);
        await expectLater(
          api.ensureSession(
            accountId: testMlsAccountId,
            authentication: FakeMlsAuthentication(),
          ),
          throwsA(
            isA<SquareApiException>()
                .having((e) => e.statusCode, 'HTTP状态', status)
                .having((e) => e.stage, '阶段', SquareApiStage.challenge)
                .having(
                  (e) => e.errorCode,
                  '错误码',
                  data['error'] is String ? data['error'] : null,
                ),
          ),
        );
        expect(calls, 1);
      });
    }
  }

  for (final price in [null, 0, 29900, -1, 1.5, true, 9007199254740992]) {
    test('会员真实价格解析不伪造未知值并拒绝非法数值 $price', () async {
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'ok': true,
              'membership_active': false,
              'membership': null,
              'plans': [
                {
                  'membership_level': 'freedom',
                  'price_fen': price,
                  'plan': {
                    'membership_level': 'freedom',
                    'chat_file_max_bytes': 104857600,
                    'video_max_seconds': 180,
                    'video_max_bytes': 104857600,
                    'article_max_images': 9,
                    'article_max_videos': 1,
                    'monthly_images': 100,
                    'monthly_video_seconds': 1800,
                    'active_uploads': 5,
                  },
                  'limits': {
                    'image_dimension': 1920,
                    'image_bytes': 10485760,
                    'storage_bytes': 1073741824,
                  },
                },
              ],
              'usage': {
                'used_images': 0,
                'reserved_images': 0,
                'used_video_seconds': 0,
                'reserved_video_seconds': 0,
                'active_uploads': 0,
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      final state = api.fetchMembership(
        const SquareSession(
          deviceId: testMlsDeviceId,
          sessionToken: 'price',
          cidNumber: testMlsCidNumber,
          accountId: testMlsAccountId,
          bindingRevision: 1,
          expiresAt: 9999999999999,
          authenticateRequest: fakeMlsRequestHeaders,
        ),
      );
      if (price == null ||
          price is int && price >= 0 && price <= 9007199254740991) {
        expect((await state).plans.single.priceFen, price);
      } else {
        await expectLater(state, throwsA(isA<SquareApiException>()));
      }
    });
  }
  test('功能API使用实际/api路径；方法、查询及正文与证明完全相同', () async {
    final signed = <({String method, Uri uri, List<int> body})>[],
        sent = <http.Request>[];
    final session = SquareSession(
      sessionToken: 'ordinary',
      cidNumber: testMlsCidNumber,
      bindingRevision: 1,
      accountId: testMlsAccountId,
      deviceId: testMlsDeviceId,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      authenticateRequest:
          ({
            required method,
            required uri,
            required body,
            required sessionToken,
          }) async {
            signed.add((method: method, uri: uri, body: List.of(body)));
            return fakeMlsRequestHeaders(
              method: method,
              uri: uri,
              body: body,
              sessionToken: sessionToken,
            );
          },
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((r) async {
        sent.add(r);
        return http.Response(
          jsonEncode({
            'ok': true,
            'posts': [],
            'entries': [],
            'square_unread': 0,
            'following_unread': 0,
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchFeed(feedKind: SquareFeedKind.recommended),
      throwsA(isA<SquareApiException>()),
    );
    expect(sent, isEmpty, reason: '无公民号会话不得发出受保护的广场请求');
    await api.exchangeContactMls(
      session: session,
      request: {'operation': 'read'},
    );
    await api.fetchFeed(feedKind: SquareFeedKind.recommended, session: session);
    await api.fetchAuthorPosts(
      cidNumber: testMlsCidNumber,
      cursor: 7,
      session: session,
    );
    await api.fetchFollows(
      cidNumber: testMlsCidNumber,
      type: 'following',
      cursor: 9,
      session: session,
    );
    await api.setNotify(
      session: session,
      followedCidNumber: testMlsCidNumber,
      enabled: true,
    );
    await api.fetchNotifyUnread(session: session);
    await api.markNotifyRead(session: session, scope: 'square');
    expect(sent.map((r) => r.url.path), [
      '/api/user/contacts',
      '/api/8964/feed/recommended',
      '/api/8964/posts',
      '/api/8964/follows',
      '/api/8964/follows/$testMlsCidNumber/notifications',
      '/api/notifications/unread',
      '/api/notifications/read',
    ]);
    for (var i = 0; i < sent.length; i++) {
      expect(signed[i].method, sent[i].method);
      expect(signed[i].uri.toString(), sent[i].url.toString());
      expect(signed[i].body, sent[i].bodyBytes);
      expect(sent[i].headers['authorization'], 'Bearer ordinary');
    }
    expect(sent[2].url.queryParameters['cid_number'], testMlsCidNumber);
    expect(sent[3].url.queryParameters['cursor'], '9');
  });
  test('prepare解析真实manifest对象及media_uploads；complete属主ID只在路径', () async {
    final requests = <http.Request>[];
    final session = SquareSession(
      sessionToken: 'ordinary',
      cidNumber: testMlsCidNumber,
      bindingRevision: 1,
      accountId: testMlsAccountId,
      deviceId: testMlsDeviceId,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode(
            r.url.path == '/api/8964/uploads'
                ? {
                    'ok': true,
                    'upload_id': 'upload',
                    'post_id': 'post',
                    'storage_receipt_id': 'receipt',
                    'expires_at': 9999999999999,
                    'estimated_bytes': 1,
                    'manifest': {
                      'object_key': 'manifest',
                      'upload_url': '/api/8964/uploads/upload/manifest',
                    },
                    'media_uploads': [],
                  }
                : {
                    'ok': true,
                    'upload_id': 'upload',
                    'post_id': 'post',
                    'content_hash': 'ab' * 32,
                    'storage_receipt_id': 'receipt',
                    'storage_state': 'ready',
                  },
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final prepared = await api.prepareUpload(
      session: session,
      postType: SquarePostType.document,
      titleLength: 0,
      textLength: 1,
      manifestHash: 'ab' * 32,
      manifestByteSize: 1,
      mediaItems: [],
    );
    expect(
      prepared.manifestUploadUrl,
      'https://square.test/api/8964/uploads/upload/manifest',
    );
    await api.completeUpload(
      session: session,
      uploadId: 'upload',
      manifestHash: 'ab' * 32,
      contentHash: 'ab' * 32,
    );
    expect(requests.last.url.path, '/api/8964/uploads/upload/complete');
    expect(jsonDecode(requests.last.body), {
      'manifest_hash': 'ab' * 32,
      'content_hash': 'ab' * 32,
    });
  });
  test('资料资源按CID和类型寻址，无旧更新时间查询； arbitrary键拒绝', () {
    final api = SquareApiClient(baseUrl: 'https://square.test/api');
    addTearDown(api.close);
    expect(
      api.mediaUrl('profile/$testMlsCidNumber/avatar', updatedAt: 5),
      'https://square.test/api/user/profiles/$testMlsCidNumber/assets/avatar',
    );
    expect(
      () => api.mediaUrl('profile/$testMlsCidNumber/../../outside'),
      throwsA(isA<SquareApiException>()),
    );
  });
}

void _chatAccessTests() {
  const session = SquareSession(
    sessionToken: 'ordinary',
    cidNumber: testMlsCidNumber,
    bindingRevision: 1,
    accountId: testMlsAccountId,
    deviceId: testMlsDeviceId,
    expiresAt: 4102444800000,
    authenticateRequest: fakeMlsRequestHeaders,
  );
  Map<String, Object> receipt() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'ok': true,
      'realtime_url': 'wss://square.test/api/tatachat/realtime',
      'access_token': 'opaque-token',
      'expires_at': now + 300000,
      'recheck_at': now + 120000,
    };
  }

  test('聊天许可精确签POST空正文，完整WSS同origin且实际请求禁止重定向', () async {
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/tatachat/access');
        expect(request.body, '{}');
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], 'Bearer ordinary');
        expect(
          request.headers.keys.any((name) => name.startsWith('x-mls-')),
          isTrue,
        );
        return http.Response(jsonEncode(receipt()), 200);
      }),
    );
    addTearDown(api.close);
    final access = await api.fetchChatAccess(
      session: session,
      deviceId: testMlsDeviceId,
    );
    expect(
      access.realtimeUrl.toString(),
      'wss://square.test/api/tatachat/realtime',
    );
    expect(access.accessToken, 'opaque-token');
  });
  // 保留原正向与拒绝断言；补齐默认、显式及自定义安全端口的边界。
  for (final endpoints in const [
    ('https://square.test/api', 'wss://square.test:443/api/tatachat/realtime'),
    ('https://square.test:443/api', 'wss://square.test/api/tatachat/realtime'),
    (
      'https://square.test:8443/api',
      'wss://square.test:8443/api/tatachat/realtime',
    ),
    (
      'https://square.test:8443/api',
      'WSS://square.test:8443/api/tatachat/realtime',
    ),
  ]) {
    test('聊天许可有效安全端口一致 ${endpoints.$1} ${endpoints.$2}', () async {
      final api = SquareApiClient(
        baseUrl: endpoints.$1,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({...receipt(), 'realtime_url': endpoints.$2}),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      final access = await api.fetchChatAccess(
        session: session,
        deviceId: testMlsDeviceId,
      );
      expect(access.realtimeUrl, Uri.parse(endpoints.$2));
      expect(access.accessToken, 'opaque-token');
    });
  }
  for (final realtime in [
    'wss://square.test/api/tatachat/realtime',
    'wss://square.test:443/api/tatachat/realtime',
  ]) {
    test('自定义HTTPS端口拒绝默认WSS端口 $realtime', () async {
      final api = SquareApiClient(
        baseUrl: 'https://square.test:8443/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({...receipt(), 'realtime_url': realtime}),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchChatAccess(session: session, deviceId: testMlsDeviceId),
        throwsA(isA<SquareApiException>()),
      );
    });
  }
  for (final mutation in <String, Object>{
    'realtime_url': 'wss://other.test/api/tatachat/realtime',
    'access_token': 'invalid token',
    'expires_at': 1,
    'recheck_at': 1,
    'unexpected': 'extra',
  }.entries) {
    test('聊天许可拒绝损坏字段${mutation.key}', () async {
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({...receipt(), mutation.key: mutation.value}),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchChatAccess(session: session, deviceId: testMlsDeviceId),
        throwsA(isA<SquareApiException>()),
      );
    });
  }
  for (final url in [
    'https://square.test/api/tatachat/realtime',
    'wss://square.test:8443/api/tatachat/realtime',
    'wss://square.test:0/api/tatachat/realtime',
    'wss://user@square.test/api/tatachat/realtime',
    'wss://square.test/api/tatachat/realtime?token=secret',
    'wss://square.test/api/tatachat/realtime#fragment',
    'wss://square.test/realtime',
  ]) {
    test('聊天许可拒绝不规范地址$url', () async {
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({...receipt(), 'realtime_url': url}),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchChatAccess(session: session, deviceId: testMlsDeviceId),
        throwsA(isA<SquareApiException>()),
      );
    });
  }
  test('重定向响应拒绝，不能把Location变为第二服务入口', () async {
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((r) async {
        expect(r.followRedirects, isFalse);
        return http.Response(
          '',
          303,
          headers: {'location': 'https://other.test/access'},
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchChatAccess(session: session, deviceId: testMlsDeviceId),
      throwsA(isA<SquareApiException>()),
    );
  });
}
