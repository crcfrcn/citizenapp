import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/post/square_models.dart';
import 'package:citizenapp/network/square_api_client.dart';

import 'mls_authentication_fixture.dart';

void main() {
  test('公民圈请求专用接口并使用当前身份会话', () async {
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/8964/feed/circle');
        expect(request.url.queryParameters, {'limit': '20'});
        expect(request.headers['authorization'], 'Bearer circle-session');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(
          '{"is_ok":true,"feed_kind":"circle","posts":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    final posts = await api.fetchFeed(
      feedKind: SquareFeedKind.circle,
      session: const SquareSession(
        deviceId: testMlsDeviceId,
        sessionToken: 'circle-session',
        cidNumber: testMlsCidNumber,
        bindRev: 1,
        accountId: '0x8888888888888888888888888888888888888888888888888888888888888888',
        expiresAt: 1800000000000,
        authenticateRequest: fakeMlsRequestHeaders,
      ),
    );
    expect(posts, isEmpty);
  });
  test('通知分层、讨论串与点赞接口保留当前会话证明及准确请求目标', () async {
    final requests = <http.Request>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer interaction-session');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(
          '{"is_ok":true,"items":[],"comments":[],"state":{"post_id":"p","like_count":0}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    const session = SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'interaction-session',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId:
          '0x8888888888888888888888888888888888888888888888888888888888888888',
      expiresAt: 1800000000000,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    await api.fetchNotifications(
      session: session,
      groupByPost: true,
      through: 10,
      cursor: 5,
    );
    expect(requests.last.url.queryParameters, {
      'limit': '20',
      'cursor': '5',
      'group': 'post',
      'through': '10',
    });
    await api.markNotifyRead(
      session: session,
      scope: 'post',
      postId: 'p',
      through: 10,
    );
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['scope'], 'post');
    expect(body['post_id'], 'p');
    expect(body['through'], 10);
    await api.fetchComments(
      session: session,
      postId: 'p',
      mode: 'thread',
      thread: 'root',
      after: '1:2',
    );
    expect(requests.last.url.path, '/api/8964/posts/p/comments');
    expect(requests.last.url.queryParameters['after'], '1:2');
    await api.fetchPostInteractions(session: session, postIds: ['p']);
    expect(jsonDecode(requests.last.body), {
      'post_ids': ['p'],
    });
    await api.fetchLikes(session: session, postId: 'p', cursor: 7);
    expect(requests.last.url.path, '/api/8964/posts/p/likes');
    await api.setLike(session: session, postId: 'p', liked: true);
    expect(requests.last.method, 'PUT');
    expect(jsonDecode(requests.last.body), {});
    await api.setLike(session: session, postId: 'p', liked: false);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, '/api/8964/posts/p/like');
    expect(requests, hasLength(7));
  });
}
