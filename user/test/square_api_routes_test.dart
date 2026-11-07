import 'package:crypto/crypto.dart' show sha256;
import 'package:citizen_testing/membergate_fixture.dart'
    show membergatePlanFixture, membergateUsageFixture;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_system/app_log.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/mls_authentication.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_square/post/square_models.dart';

import 'package:citizen_testing/mls_authentication_fixture.dart';

void main() {
  registrationReportTests();
  coldIdentityAuthenticationTests();
  test('真实429 RPC限额保留固定错误码且不自动重试', () async {
    var calls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{"error_code":"chain_rpc_budget_exceeded"}', 429);
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
            .having((e) => e.errorCode, 'code', 'chain_rpc_budget_exceeded')
            .having((e) => e.statusCode, 'status', 429),
      ),
    );
    expect(calls, 1);
  });
  test('通讯录逐条备份包含备注，删除证明覆盖空正文', () async {
    final signed = <List<int>>[];
    final sent = <http.Request>[];
    final session = SquareSession(
      sessionToken: 'ordinary',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
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
            signed.add(List.of(body));
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
      httpClient: MockClient((request) async {
        sent.add(request);
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(jsonEncode({'is_ok': true}), 200);
      }),
    );
    addTearDown(api.close);
    const cid = 'CN220-CTZN2-100000002-2026';
    await api.fetchUserContacts(session: session);
    await api.saveUserContact(
      session: session,
      cidNumber: cid,
      accountId: testMlsAccountId,
      contactRemark: '同事',
    );
    await api.deleteUserContact(session: session, cidNumber: cid);
    expect(sent.map((r) => r.method), ['GET', 'PUT', 'DELETE']);
    expect(sent.map((r) => r.url.path), [
      '/api/user/contacts',
      '/api/user/contacts/$cid',
      '/api/user/contacts/$cid',
    ]);
    expect(sent[0].body, '');
    expect(jsonDecode(sent[1].body), {
      'account_id': testMlsAccountId,
      'contact_remark': '同事',
    });
    expect(sent[2].body, '');
    expect(signed, sent.map((r) => r.bodyBytes).toList());
  });

  test('关注和评论真实HTTP正文直接使用peer_cid及op_id，认证覆盖同一字节', () async {
    final signed = <List<int>>[];
    final sent = <http.Request>[];
    final session = SquareSession(
      sessionToken: 'ordinary',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
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
            signed.add(List.of(body));
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
      httpClient: MockClient((request) async {
        sent.add(request);
        expect(request.method, 'POST');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(jsonEncode({'is_ok': true}), 200);
      }),
    );
    addTearDown(api.close);
    await api.followUser(
      session: session,
      peerCid: 'CN220-CTZN2-100000002-2026',
    );
    await api.createComment(
      session: session,
      postId: 'p',
      opId: '01' * 16,
      replyText: '评论',
      replyTo: 'parent',
    );
    expect(sent.map((request) => request.url.path), [
      '/api/8964/follows',
      '/api/8964/posts/p/comments',
    ]);
    expect(jsonDecode(sent[0].body), {
      'peer_cid': 'CN220-CTZN2-100000002-2026',
    });
    expect(jsonDecode(sent[1].body), {
      'op_id': '01' * 16,
      'reply_text': '评论',
      'reply_to': 'parent',
    });
    expect(signed, sent.map((request) => request.bodyBytes).toList());
  });

  test('HTTP计时标签及数字严格闭集，出口故障不影响调用', () async {
    const canary = 'synthetic-private-http-detail';
    final lines = <String>[];
    await runZoned(
      () async {
        AppLog.http(
          stage: canary,
          phase: canary,
          statusCode: 600,
          headersMicros: 4,
          elapsedMicros: -1,
        );
        AppLog.http(
          stage: 'challenge',
          phase: 'complete',
          statusCode: 200,
          headersMicros: 2,
          elapsedMicros: 3,
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines, [
      '[CitizenHttp] stage=other http=none headers_us=none total_us=none phase=other',
      '[CitizenHttp] stage=challenge http=200 headers_us=2 total_us=3 phase=complete',
    ]);
    expect(lines.join(), isNot(contains(canary)));
    await runZoned(
      () async {
        AppLog.http(stage: 'challenge', phase: 'error', elapsedMicros: 1);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError(canary),
      ),
    );
  });
  test('发布确认直接核对同一交易和正文，无额外详情查询', () async {
    final paths = <String>[];
    final hash = '11' * 32, block = '0x${'22' * 32}', tx = '0x${'33' * 32}';
    final session = SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 'synthetic',
      cidNumber: testMlsCidNumber,
      accountId: testMlsAccountId,
      bindRev: 1,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final index = <String, dynamic>{
      'post_id': 'post',
      'account_id': testMlsAccountId,
      'cid_number': testMlsCidNumber,
      'post_category': 'normal',
      'post_type': 'document',
      'post_title': null,
      'post_excerpt': '摘要',
      'content_hash': hash,
      'receipt_id': 'receipt',
      'chain_block': 1,
      'block_hash': block,
      'tx_hash': tx,
      'published_at': 1000,
      'post_state': 'published',
      'media_items': <Object>[],
    };
    final manifest = <String, dynamic>{
      'schema': 'citizenapp.square.post',
      'cid_number': testMlsCidNumber,
      'post_type': 'document',
      'text': '真实清单正文',
      'media_items': <Object>[],
    };
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({'is_ok': true, 'post': index, 'manifest': manifest}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final post = await api.confirmPublishedPost(
      session: session,
      postId: 'post',
      blockHash: block,
      txHash: tx,
    );
    expect(post.text, '真实清单正文');
    expect(post.contentHash, hash);
    expect(paths, ['POST /api/8964/posts/confirm']);
    for (final bad in ['block', 'tx', 'schema', 'author', 'type', 'http']) {
      final calls = <String>[];
      final invalidIndex = {...index};
      final invalidManifest = {...manifest};
      switch (bad) {
        case 'block':
          invalidIndex['block_hash'] = '0x${'44' * 32}';
        case 'tx':
          invalidIndex['tx_hash'] = '0x${'44' * 32}';
        case 'schema':
          invalidManifest['schema'] = 'unknown';
        case 'author':
          invalidManifest['cid_number'] = 'other';
        case 'type':
          invalidManifest['post_type'] = 'article';
      }
      final invalid = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'post': invalidIndex,
              'manifest': invalidManifest,
            }),
            bad == 'http' ? 503 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      try {
        await expectLater(
          invalid.confirmPublishedPost(
            session: session,
            postId: 'post',
            blockHash: block,
            txHash: tx,
          ),
          throwsA(isA<SquareApiException>()),
        );
        expect(calls, ['POST /api/8964/posts/confirm']);
      } finally {
        invalid.close();
      }
    }
    final old = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'is_ok': true,
            'post': {...index, 'text': '旧内联正文'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(old.close);
    await expectLater(
      old.fetchPostDetail(session: session, postId: 'post'),
      throwsA(isA<SquareApiException>()),
    );
  });
  _proposalFailureDiagnosticsTests();
  _proposalReadDiagnosticsTests();
  _failureDiagnosticsTests();
  _serviceUnavailableTests();
  _chatAccessTests();
  _readCoalescingTests();
  for (final status in [401, 403, 429, 503]) {
    for (final data in <Map<String, Object?>>[
      {'error_code': 'device_not_registered'},
      {},
      {'error_code': 1},
      {'error_code': null},
      {
        'error_code': {'code': 'device_not_registered'},
      },
      {'error': 'device_not_registered'},
    ]) {
      test('真实错误字段$status/$data仅接受error_code字符串且不重试', () async {
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
                  data['error_code'] is String ? data['error_code'] : null,
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
              'is_ok': true,
              'membergate_active': false,
              'membergate': null,
              'plans': [
                for (final level in const ['freedom', 'democracy', 'spark'])
                  membergatePlanFixture(level)..['price_fen'] = price,
              ],
              'usage': membergateUsageFixture(),
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
          bindRev: 1,
          expiresAt: 9999999999999,
          authenticateRequest: fakeMlsRequestHeaders,
        ),
      );
      if (price == null ||
          price is int && price >= 0 && price <= 9007199254740991) {
        expect((await state).planForLevel('freedom')!.priceFen, price);
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
      bindRev: 1,
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
            'is_ok': true,
            'items': [],
            'square_unread': 0,
            'notifications_unread': 0,
            'following_unread': 0,
            'interaction_unread': 0,
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
    await api.fetchUserContacts(session: session);
    await api.fetchFeed(feedKind: SquareFeedKind.recommended, session: session);
    await api.fetchAuthorPosts(
      cidNumber: testMlsCidNumber,
      cursor: '7',
      session: session,
    );
    await api.fetchFollows(
      cidNumber: testMlsCidNumber,
      type: 'following',
      cursor: '9',
      session: session,
    );
    await api.setNotify(
      session: session,
      peerCid: testMlsCidNumber,
      enabled: true,
    );
    await api.fetchNotificationState(session: session);
    await api.markNotifyRead(session: session, scope: 'square', through: 1);
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
  test('上传签名绑定帖子、交易哈希和原始正文，complete只签空正文', () async {
    final requests = <http.Request>[];
    final session = SquareSession(
      sessionToken: 'ordinary',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId: testMlsAccountId,
      deviceId: testMlsDeviceId,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.method == 'PUT'
                ? {'is_ok': true, 'uploads': []}
                : {'is_ok': true, 'state': 'complete'},
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final hash = '0x${'ab' * 32}';
    final raw = Uint8List.fromList(utf8.encode('{"text":"正文"}'));
    expect(
      await api.beginUpload(
        session: session,
        postId: 'post',
        txHash: hash,
        manifest: raw,
      ),
      isEmpty,
    );
    expect(requests.single.url.path, '/api/8964/uploads/post/manifest');
    expect(requests.single.url.queryParameters, {'tx_hash': hash});
    expect(requests.single.bodyBytes, raw);
    expect(await api.completeUpload(session: session, postId: 'post'), isTrue);
    expect(requests.last.url.path, '/api/8964/uploads/post/complete');
    expect(requests.last.bodyBytes, isEmpty);
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

/// 合成异常的function toString() { [native code] }不得被日志读取，防止未来把动态正文混入固定事件。
class _UnreadableProposalError {
  @override
  String toString() =>
      throw StateError('synthetic error text must not be read');
}

// 仅用合成输入核对回执闭集，不把任意字符串或秘密写进设备日志。
void _proposalReadDiagnosticsTests() {
  for (final state in ['waiting', 'started', 'empty', 'nonempty']) {
    test('提案读取回执$state仅输出固定状态', () {
      final lines = <String>[];
      runZoned(
        () => AppLog.proposalRead(state: state),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(lines, ['[CitizenRead] stage=proposal_first state=$state']);
    });
  }
  test('提案回执未知或恶意状态只输出other，出口失败不覆盖业务结果', () {
    final lines = <String>[];
    runZoned(
      () {
        AppLog.proposalRead(state: 'synthetic private identity');
        AppLog.proposalRead(state: 'empty\nstate=nonempty');
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(
      lines,
      List.filled(2, '[CitizenRead] stage=proposal_first state=other'),
    );
    final value = runZoned(
      () {
        AppLog.proposalRead(state: 'empty');
        return true;
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError('synthetic sink failure'),
      ),
    );
    expect(value, isTrue);
  });
}

void _proposalFailureDiagnosticsTests() {
  for (final code in CitizenSdkErrorCode.values) {
    test('提案SDK公开错误类别${code.name}仅输出固定枚举', () {
      final lines = <String>[];
      runZoned(
        () {
          AppLog.proposalFailure(
            stage: 'proposal_year',
            error: CitizenSdkException(
              code: code,
              message: 'synthetic private message',
              method: 'synthetic private method',
              sessionId: 'synthetic private session',
            ),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(lines, [
        '[CitizenFailure] stage=proposal_year http=none code=sdk_${code.name}',
      ]);
      expect(lines.join(), isNot(contains('synthetic private')));
    });
  }
  for (final stage in [
    'institutions',
    'feed',
    'year',
    'index',
    'details',
    'context',
    'votes',
    'display',
    'summary',
  ]) {
    test('提案固定阶段$stage沿同一安全出口', () {
      final lines = <String>[];
      runZoned(
        () => AppLog.proposalFailure(
          stage: 'proposal_$stage',
          error: StateError('synthetic private detail'),
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(lines, [
        '[CitizenFailure] stage=proposal_$stage http=none code=state',
      ]);
    });
  }
  for (final fixture in <(Object, String)>[
    (const FormatException('synthetic private detail'), 'format'),
    (TypeError(), 'type'),
    (StateError('synthetic private detail'), 'state'),
    (_UnreadableProposalError(), 'other'),
  ]) {
    test('提案非SDK异常仅分类${fixture.$2}且不读取原文', () {
      final lines = <String>[];
      runZoned(
        () => AppLog.proposalFailure(
          stage: 'proposal_summary',
          error: fixture.$1,
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(lines, [
        '[CitizenFailure] stage=proposal_summary http=none code=${fixture.$2}',
      ]);
    });
  }
  test('提案恶意阶段及伪造SDK错误名称均归other，出口故障不外抛', () {
    final lines = <String>[];
    runZoned(
      () {
        AppLog.proposalFailure(
          stage: 'proposal_index\nsynthetic private detail',
          error: _UnreadableProposalError(),
        );
        AppLog.failure(
          stage: 'proposal_index',
          code: 'sdk_network\nsynthetic private detail',
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines, [
      '[CitizenFailure] stage=other http=none code=other',
      '[CitizenFailure] stage=proposal_index http=none code=other',
    ]);
    runZoned(
      () => AppLog.proposalFailure(
        stage: 'proposal_index',
        error: _UnreadableProposalError(),
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError('synthetic sink failure'),
      ),
    );
  });
}

void _chatAccessTests() {
  const session = SquareSession(
    sessionToken: 'ordinary',
    cidNumber: testMlsCidNumber,
    bindRev: 1,
    accountId: testMlsAccountId,
    deviceId: testMlsDeviceId,
    expiresAt: 4102444800000,
    authenticateRequest: fakeMlsRequestHeaders,
  );
  Map<String, Object> receipt() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'is_ok': true,
      'realtime_url': 'wss://square.test/api/chat/realtime',
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
        expect(request.url.path, '/api/chat/access');
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
      'wss://square.test/api/chat/realtime',
    );
    expect(access.accessToken, 'opaque-token');
  });
  // 保留原正向与拒绝断言；补齐默认、显式及自定义安全端口的边界。
  for (final endpoints in const [
    ('https://square.test/api', 'wss://square.test:443/api/chat/realtime'),
    ('https://square.test:443/api', 'wss://square.test/api/chat/realtime'),
    (
      'https://square.test:8443/api',
      'wss://square.test:8443/api/chat/realtime',
    ),
    (
      'https://square.test:8443/api',
      'WSS://square.test:8443/api/chat/realtime',
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
    'wss://square.test/api/chat/realtime',
    'wss://square.test:443/api/chat/realtime',
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
    'realtime_url': 'wss://other.test/api/chat/realtime',
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
    'https://square.test/api/chat/realtime',
    'wss://square.test:8443/api/chat/realtime',
    'wss://square.test:0/api/chat/realtime',
    'wss://user@square.test/api/chat/realtime',
    'wss://square.test/api/chat/realtime?token=secret',
    'wss://square.test/api/chat/realtime#fragment',
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

// 同一实际请求只签一次，完成/失败后不保存可重复消费的证明或响应。
void _readCoalescingTests() {
  SquareSession session({
    String token = 'coalesced',
    Future<void> Function()? current,
    Future<Map<String, String>> Function()? sign,
  }) => SquareSession(
    sessionToken: token,
    cidNumber: testMlsCidNumber,
    accountId: testMlsAccountId,
    bindRev: 1,
    deviceId: testMlsDeviceId,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    requireCurrent: current,
    authenticateRequest:
        ({
          required method,
          required uri,
          required body,
          required sessionToken,
        }) =>
            sign?.call() ??
            fakeMlsRequestHeaders(
              method: method,
              uri: uri,
              body: body,
              sessionToken: sessionToken,
            ),
  );
  http.Response result([int status = 200]) => http.Response(
    jsonEncode(
      status == 200
          ? {'is_ok': true, 'items': []}
          : {'is_ok': false, 'error_code': 'synthetic_denial'},
    ),
    status,
  );
  test('跨客户端同会话十个并发GET只签发一次，完成后的读取重新签名', () async {
    var requests = 0, signed = 0;
    final entered = Completer<void>(), release = Completer<void>();
    final owner = session(
      sign: () async => {'x-mls-proof': 'read-${++signed}'},
    );
    http.Client client() => MockClient((_) async {
      requests++;
      if (!entered.isCompleted) {
        entered.complete();
      }
      await release.future;
      return result();
    });
    final a = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: client(),
    );
    final b = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: client(),
    );
    addTearDown(a.close);
    addTearDown(b.close);
    final reads = List.generate(
      10,
      (index) => (index.isEven ? a : b).fetchFeed(
        feedKind: SquareFeedKind.recommended,
        session: owner,
      ),
    );
    await entered.future;
    expect(requests, 1);
    expect(signed, 1);
    release.complete();
    expect((await Future.wait(reads)).every((value) => value.isEmpty), isTrue);
    await b.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner);
    expect(requests, 2);
    expect(signed, 2);
  });
  test('不同会话和完整URL不能共用在途GET', () async {
    var requests = 0;
    final entered = Completer<void>(), release = Completer<void>();
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        if (++requests == 3) {
          entered.complete();
        }
        await release.future;
        return result();
      }),
    );
    addTearDown(api.close);
    final a = session(), b = session(token: 'other');
    final reads = [
      api.fetchFeed(feedKind: SquareFeedKind.recommended, session: a),
      api.fetchFeed(feedKind: SquareFeedKind.recommended, session: b),
      api.fetchFeed(feedKind: SquareFeedKind.following, session: a),
    ];
    await entered.future;
    expect(requests, 3);
    release.complete();
    await Future.wait(reads);
  });
  for (final status in [401, 403, 429, 503]) {
    test('合并GET的$status原样拒绝且不重试，下一次读取可重新签名', () async {
      var requests = 0, signed = 0;
      final entered = Completer<void>(), release = Completer<void>();
      final owner = session(
        sign: () async => {'x-mls-proof': 'error-${++signed}'},
      );
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((_) async {
          requests++;
          if (!entered.isCompleted) {
            entered.complete();
          }
          await release.future;
          return result(requests == 1 ? status : 200);
        }),
      );
      addTearDown(api.close);
      final first = api.fetchFeed(
        feedKind: SquareFeedKind.recommended,
        session: owner,
      );
      final second = api.fetchFeed(
        feedKind: SquareFeedKind.recommended,
        session: owner,
      );
      final failure = isA<SquareApiException>().having(
        (e) => e.statusCode,
        'status',
        status,
      );
      final checked = [
        expectLater(first, throwsA(failure)),
        expectLater(second, throwsA(failure)),
      ];
      await entered.future;
      expect(requests, 1);
      release.complete();
      await Future.wait(checked);
      expect(requests, 1);
      expect(signed, 1);
      await api.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner);
      expect(requests, 2);
      expect(signed, 2);
    });
  }
  test('共享GET等待期间身份失效，两名等待者都拒绝迟到结果', () async {
    var current = true, requests = 0;
    final entered = Completer<void>(), release = Completer<void>();
    final owner = session(
      current: () async {
        if (!current) {
          throw StateError('synthetic identity changed');
        }
      },
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        requests++;
        entered.complete();
        await release.future;
        return result();
      }),
    );
    addTearDown(api.close);
    final checked = [
      for (var i = 0; i < 2; i++)
        expectLater(
          api.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner),
          throwsStateError,
        ),
    ];
    await entered.future;
    current = false;
    release.complete();
    await Future.wait(checked);
    expect(requests, 1);
  });
  test('签名失败清除在途GET，显式重试不复用失败证明', () async {
    var signed = 0, requests = 0;
    final owner = session(
      sign: () async {
        if (++signed == 1) {
          throw StateError('synthetic signer failure');
        }
        return {'x-mls-proof': 'fresh'};
      },
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        requests++;
        return result();
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner),
      throwsStateError,
    );
    expect(requests, 0);
    await api.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner);
    expect(requests, 1);
    expect(signed, 2);
  });
  test('关闭的客户端不能借另一客户端在途GET交付数据', () async {
    final entered = Completer<void>(), release = Completer<void>();
    var requests = 0;
    final owner = session();
    final a = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        requests++;
        entered.complete();
        await release.future;
        return result();
      }),
    );
    final b = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient(
        (_) async => throw StateError('closed client must not send'),
      ),
    );
    addTearDown(a.close);
    b.close();
    final read = a.fetchFeed(
      feedKind: SquareFeedKind.recommended,
      session: owner,
    );
    await entered.future;
    await expectLater(
      b.fetchFeed(feedKind: SquareFeedKind.recommended, session: owner),
      throwsA(isA<http.ClientException>()),
    );
    release.complete();
    await read;
    expect(requests, 1);
  });
  test('相同写操作仍分别签名和发送，不进入只读GET合并', () async {
    var requests = 0, signed = 0;
    final owner = session(
      sign: () async => {'x-mls-proof': 'write-${++signed}'},
    );
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((r) async {
        expect(r.method, 'PUT');
        requests++;
        return http.Response('{"is_ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    await Future.wait([
      for (var i = 0; i < 2; i++)
        api.setNotify(session: owner, peerCid: testMlsCidNumber, enabled: true),
    ]);
    expect(requests, 2);
    expect(signed, 2);
  });
}

// 503不能授权设备登记；夹具只模拟HTTP回执，不代表真实服务或真人验证通过。
void _serviceUnavailableTests() {
  const canary = 'synthetic-private-503';
  for (final boundary in ['challenge', 'session']) {
    for (final code in [
      'device_not_registered',
      'identity_not_reported',
      'synthetic_unknown',
    ]) {
      test('$boundary的503/$code保留原错误且不进入设备登记', () async {
        final paths = <String>[], lines = <String>[];
        final source = FakeMlsAuthentication();
        var registrations = 0;
        final api = SquareApiClient(
          baseUrl: 'https://square.test/api',
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (boundary == 'session' &&
                request.url.path.endsWith('/challenges')) {
              return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
            }
            return http.Response(
              jsonEncode({
                'error_code': code,
                'message': canary,
                'proof': canary,
              }),
              503,
            );
          }),
        );
        addTearDown(api.close);
        await runZoned(
          () => expectLater(
            api.ensureSession(
              accountId: testMlsAccountId,
              authentication: source,
              onDeviceNotRegistered: (_) async {
                registrations++;
              },
            ),
            throwsA(
              isA<SquareApiException>()
                  .having((e) => e.statusCode, '原HTTP', 503)
                  .having((e) => e.stage?.name, '原阶段', boundary)
                  .having((e) => e.errorCode, '原错误码', code)
                  .having((e) => e.message, '原消息', canary),
            ),
          ),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lines.add(line),
          ),
        );
        expect(registrations, 0);
        expect(paths, [
          '/api/user/challenges',
          if (boundary == 'session') '/api/user/sessions',
        ]);
        // 挑战申请先证明持钥；会话再签一次业务证明，503不追加操作。
        expect(source.proofCalls, boundary == 'challenge' ? 1 : 2);
        final loggedCode = code == 'synthetic_unknown' ? 'other' : code;
        expect(lines, [
          '[CitizenFailure] stage=$boundary http=503 code=$loggedCode',
        ]);
        for (final value in [
          canary,
          testMlsAccountId,
          testMlsCidNumber,
          testMlsDeviceId,
        ]) {
          expect(lines.join(), isNot(contains(value)));
        }
      });
    }

    test('$boundary的503结束后主动重试恢复会话并复用有效缓存', () async {
      final source = FakeMlsAuthentication();
      final paths = <String>[];
      var unavailable = true, registrations = 0;
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.method, 'POST');
          final challenge = request.url.path.endsWith('/challenges');
          if (unavailable && challenge == (boundary == 'challenge')) {
            return http.Response(
              jsonEncode({'error_code': 'device_not_registered'}),
              503,
            );
          }
          if (challenge) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              body.keys,
              unorderedEquals([
                'account_id',
                'public_key',
                'token_purpose',
                'http_method',
                'request_target',
                'body_hash',
              ]),
            );
            expect(body['token_purpose'], 'session');
            expect(body['http_method'], 'POST');
            expect(body['request_target'], '/api/user/sessions');
            return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
          }
          expect(request.url.path, '/api/user/sessions');
          expect(jsonDecode(request.body), {'account_id': testMlsAccountId});
          return http.Response(jsonEncode(fakeMlsSession()), 200);
        }),
      );
      addTearDown(api.close);
      Future<SquareSession> attempt() => api.ensureSession(
        accountId: testMlsAccountId,
        authentication: source,
        onDeviceNotRegistered: (_) async {
          registrations++;
        },
      );
      await expectLater(
        attempt(),
        throwsA(
          isA<SquareApiException>().having((e) => e.statusCode, '真实失败', 503),
        ),
      );
      unavailable = false;
      final session = await attempt();
      expect(session.isUsable, isTrue);
      expect(session.accountId, testMlsAccountId);
      expect(session.cidNumber, testMlsCidNumber);
      expect(session.deviceId, testMlsDeviceId);
      expect(session.bindRev, source.identity.bindRev);
      expect(await attempt(), same(session));
      expect(registrations, 0);
      expect(paths, [
        '/api/user/challenges',
        if (boundary == 'session') '/api/user/sessions',
        '/api/user/challenges',
        '/api/user/sessions',
      ]);
      expect(source.proofCalls, boundary == 'challenge' ? 3 : 4);
    });
  }

  test('并发503共用原失败且结束后可主动重试', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final source = FakeMlsAuthentication();
    var unavailable = true, challenges = 0, sessions = 0, registrations = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/challenges')) {
          challenges++;
          if (unavailable) {
            entered.complete();
            await release.future;
            return http.Response(
              jsonEncode({'error_code': 'device_not_registered'}),
              503,
            );
          }
          return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
        }
        sessions++;
        return http.Response(jsonEncode(fakeMlsSession()), 200);
      }),
    );
    addTearDown(api.close);
    Future<SquareSession> attempt() => api.ensureSession(
      accountId: testMlsAccountId,
      authentication: source,
      onDeviceNotRegistered: (_) async {
        registrations++;
      },
    );
    // 先安装每个错误观察器，再释放同一挑战，避免制造未处理异步异常。
    final pending = List.generate(
      3,
      (_) => attempt().then<Object>(
        (session) => session,
        onError: (Object error) => error,
      ),
    );
    await entered.future;
    release.complete();
    final errors = await Future.wait(pending);
    expect(
      errors.first,
      isA<SquareApiException>().having((e) => e.statusCode, '真实HTTP', 503),
    );
    expect(errors[1], same(errors.first));
    expect(errors[2], same(errors.first));
    expect(challenges, 1);
    expect(sessions, 0);
    expect(source.proofCalls, 1);
    expect(registrations, 0);
    unavailable = false;
    expect((await attempt()).isUsable, isTrue);
    expect(challenges, 2);
    expect(sessions, 1);
    expect(source.proofCalls, 3);
    expect(registrations, 0);
  });
}

// 所有标记均为合成金丝雀；真实账户、URL、挑战及回执不得进入诊断。
void _failureDiagnosticsTests() {
  const canary = 'synthetic-private-canary';
  for (final boundary in ['challenge', 'session', 'registration']) {
    for (final status in [401, 403, 404, 429, 503]) {
      test('$boundary真实HTTP$status保留阶段且不追加请求或泄漏正文', () async {
        final lines = <String>[], paths = <String>[];
        final source = FakeMlsAuthentication();
        final api = SquareApiClient(
          baseUrl: 'https://square.test/api',
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (boundary != 'challenge' &&
                request.url.path.endsWith('/challenges')) {
              return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
            }
            return http.Response(
              jsonEncode({
                'error_code': 'identity_not_reported',
                'message': canary,
                'session_token': canary,
                'challenge': canary,
                'proof': canary,
              }),
              status,
            );
          }),
        );
        addTearDown(api.close);
        await runZoned(
          () async {
            final request = boundary == 'registration'
                ? api.registerMlsDevice(
                    identity: source.identity,
                    authentication: source,
                    issuedAt: 1,
                    bindingSignatureHex: '0x${'ab' * 64}',
                  )
                : api.ensureSession(
                    accountId: testMlsAccountId,
                    authentication: source,
                    onDeviceNotRegistered: (_) async => fail('未准入不得触发登记'),
                  );
            await expectLater(
              request,
              throwsA(
                isA<SquareApiException>()
                    .having((e) => e.statusCode, 'HTTP', status)
                    .having((e) => e.stage?.name, '阶段', boundary)
                    .having((e) => e.errorCode, '原码', 'identity_not_reported'),
              ),
            );
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lines.add(line),
          ),
        );
        expect(
          paths,
          boundary == 'challenge'
              ? ['/api/user/challenges']
              : [
                  '/api/user/challenges',
                  boundary == 'registration'
                      ? '/api/user/devices'
                      : '/api/user/sessions',
                ],
        );
        expect(source.proofCalls, boundary == 'challenge' ? 1 : 2);
        expect(lines, [
          '[CitizenFailure] stage=$boundary http=$status code=identity_not_reported',
        ]);
        expect(lines.join(), isNot(contains(canary)));
        for (final secret in [
          testMlsAccountId,
          testMlsCidNumber,
          testMlsDeviceId,
        ]) {
          expect(lines.join(), isNot(contains(secret)));
        }
      });
    }
    for (final shape in ['json', 'shape', 'receipt']) {
      test('$boundary损坏$shape失败关闭并安全分类', () async {
        final lines = <String>[];
        var calls = 0;
        final source = FakeMlsAuthentication();
        final api = SquareApiClient(
          baseUrl: 'https://square.test/api',
          httpClient: MockClient((request) async {
            calls++;
            if (boundary != 'challenge' &&
                request.url.path.endsWith('/challenges')) {
              return http.Response(jsonEncode(fakeMlsChallenge(request)), 200);
            }
            return http.Response(switch (shape) {
              'json' => '{$canary',
              'shape' => jsonEncode([canary]),
              _ => jsonEncode({'is_ok': true, 'session_token': canary}),
            }, 200);
          }),
        );
        addTearDown(api.close);
        await runZoned(
          () async {
            final request = boundary == 'registration'
                ? api.registerMlsDevice(
                    identity: source.identity,
                    authentication: source,
                    issuedAt: 1,
                    bindingSignatureHex: '0x${'ab' * 64}',
                  )
                : api.ensureSession(
                    accountId: testMlsAccountId,
                    authentication: source,
                    onDeviceNotRegistered: (_) async => fail('损坏回执不得登记'),
                  );
            await expectLater(
              request,
              throwsA(
                shape == 'receipt'
                    ? isA<MlsAuthenticationException>()
                    : isA<SquareApiException>(),
              ),
            );
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lines.add(line),
          ),
        );
        expect(calls, boundary == 'challenge' ? 1 : 2);
        final code = shape == 'receipt'
            ? boundary == 'challenge'
                  ? 'invalid_mls_proof'
                  : 'response_invalid'
            : shape;
        expect(lines, [
          '[CitizenFailure] stage=$boundary http=${shape == 'receipt' ? 'none' : '200'} code=$code',
        ]);
        expect(lines.join(), isNot(contains(canary)));
      });
    }
  }
  test('未知错误码和恶意输入只输出other；日志出口故障不覆盖原异常', () async {
    final lines = <String>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'error_code': '$canary\ncode=forged', 'message': canary}),
          403,
        ),
      ),
    );
    addTearDown(api.close);
    await runZoned(
      () async {
        AppLog.failure(stage: canary, statusCode: 600, code: canary);
        await expectLater(
          api.ensureSession(
            accountId: testMlsAccountId,
            authentication: FakeMlsAuthentication(),
          ),
          throwsA(
            isA<SquareApiException>().having((e) => e.statusCode, 'HTTP', 403),
          ),
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines, [
      '[CitizenFailure] stage=other http=none code=other',
      '[CitizenFailure] stage=challenge http=403 code=other',
    ]);
    await runZoned(
      () async {
        await expectLater(
          api.ensureSession(
            accountId: testMlsAccountId,
            authentication: FakeMlsAuthentication(),
          ),
          throwsA(
            isA<SquareApiException>().having((e) => e.statusCode, '原异常', 403),
          ),
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError('synthetic sink failure'),
      ),
    );
  });
}

void registrationReportTests() {
  const cid = 'CN220-CTZN2-100000001-2026';
  final account = '0x${'11' * 32}';
  test('注册结果报告仅两字段，暂时失败间隔60/120秒共最多三次', () async {
    final requests = <http.Request>[], delays = <Duration>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      reportDelay: (d) async {
        delays.add(d);
      },
      httpClient: MockClient((r) async {
        requests.add(r);
        return requests.length < 3
            ? http.Response(
                '{"is_ok":false,"error_code":"identity_storage_unavailable"}',
                503,
              )
            : http.Response('{"is_ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    await api.reportIdentity(
      cidNumber: cid,
      accountId: account,
      requireCurrent: () async {},
    );
    expect(requests, hasLength(3));
    expect(delays, [const Duration(seconds: 60), const Duration(seconds: 120)]);
    for (final r in requests) {
      expect(r.url.path, '/api/user/identity');
      expect(jsonDecode(r.body), {'cid_number': cid, 'account_id': account});
      expect(r.headers.containsKey('authorization'), false);
      expect(r.headers.containsKey('x-mls-proof'), false);
    }
  });
  test('报告三次失败即停止，没有外层无限重试', () async {
    var calls = 0;
    final waits = <Duration>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      reportDelay: (d) async {
        waits.add(d);
      },
      httpClient: MockClient((_) async {
        calls++;
        return http.Response(
          '{"is_ok":false,"error_code":"identity_storage_unavailable"}',
          503,
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.reportIdentity(
        cidNumber: cid,
        accountId: account,
        requireCurrent: () async {},
      ),
      throwsA(isA<SquareApiException>()),
    );
    expect(calls, 3);
    expect(waits, hasLength(2));
  });
  test('永久拒绝及错误成功正文不能重试或伪造已同步', () async {
    for (final status in [400, 403, 409, 200]) {
      var calls = 0, waits = 0;
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        reportDelay: (_) async {
          waits++;
        },
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
            status == 200
                ? '{"is_ok":true,"credential":"forbidden"}'
                : '{"is_ok":false,"error_code":"identity_binding_conflict"}',
            status,
          );
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.reportIdentity(
          cidNumber: cid,
          accountId: account,
          requireCurrent: () async {},
        ),
        throwsA(isA<SquareApiException>()),
      );
      expect(calls, 1);
      expect(waits, 0);
    }
  });
  test('同一绑定报告在途合并，账户切换后不发下一次请求', () async {
    final gate = Completer<void>();
    var calls = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((_) async {
        calls++;
        await gate.future;
        return http.Response('{"is_ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    final first = api.reportIdentity(
          cidNumber: cid,
          accountId: account,
          requireCurrent: () async {},
        ),
        second = api.reportIdentity(
          cidNumber: cid,
          accountId: account,
          requireCurrent: () async {},
        );
    expect(identical(first, second), true);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
    var active = true;
    final retry = SquareApiClient(
      baseUrl: 'https://square.test/api',
      reportDelay: (_) async {
        active = false;
      },
      httpClient: MockClient(
        (_) async => http.Response(
          '{"is_ok":false,"error_code":"identity_storage_unavailable"}',
          503,
        ),
      ),
    );
    addTearDown(retry.close);
    await expectLater(
      retry.reportIdentity(
        cidNumber: cid,
        accountId: account,
        requireCurrent: () async {
          if (!active) throw StateError('account changed');
        },
      ),
      throwsStateError,
    );
  });
}

void coldIdentityAuthenticationTests() {
  test('已有链身份缺服务端事实只补报，再恢复同一设备申请', () async {
    final source = FakeMlsAuthentication(), paths = <String>[];
    var challenges = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      reportDelay: (_) async => fail('不应退避'),
      httpClient: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/challenges')) {
          challenges++;
          expect(r.headers['x-mls-proof'], isNotEmpty);
          final header = jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(r.headers['x-mls-proof']!)),
            ),
          ) as Map<String, dynamic>;
          expect(header['request_target'], '/api/user/challenges');
          expect(header['body_hash'], '0x${sha256.convert(r.bodyBytes)}');
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {
            'account_id',
            'public_key',
            'token_purpose',
            'http_method',
            'request_target',
            'body_hash',
            'issued_at',
            'binding_signature',
          });
          expect(body['token_purpose'], 'device');
          return challenges == 1
              ? http.Response(
                  '{"is_ok":false,"error_code":"identity_not_reported"}',
                  409,
                )
              : http.Response(jsonEncode(fakeMlsChallenge(r)), 200);
        }
        if (r.url.path.endsWith('/identity')) {
          expect(jsonDecode(r.body), {
            'cid_number': source.identity.cidNumber,
            'account_id': source.identity.accountId,
          });
          return http.Response('{"is_ok":true}', 200);
        }
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'cid_number': source.identity.cidNumber,
            'bind_rev': 1,
            'device_id': source.identity.deviceId,
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await api.registerMlsDevice(
      identity: source.identity,
      authentication: source,
      issuedAt: DateTime.now().millisecondsSinceEpoch,
      bindingSignatureHex: '0x${'11' * 64}',
    );
    expect(paths, [
      '/api/user/challenges',
      '/api/user/identity',
      '/api/user/challenges',
      '/api/user/devices',
    ]);
    expect(source.proofCalls, 3);
  });
  test('首次会话挑战明确缺上下文仅恢复一次，不能将会话提交失败当设备缺失', () async {
    for (final boundary in ['challenge', 'session']) {
      final source = FakeMlsAuthentication();
      var challenges = 0, restores = 0;
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/challenges')) {
            challenges++;
            if (boundary == 'challenge' && challenges == 1) {
              return http.Response(
                '{"is_ok":false,"error_code":"invalid_session"}',
                401,
              );
            }
            return http.Response(jsonEncode(fakeMlsChallenge(r)), 200);
          }
          return boundary == 'session'
              ? http.Response(
                  '{"is_ok":false,"error_code":"invalid_session"}',
                  401,
                )
              : http.Response(jsonEncode(fakeMlsSession()), 200);
        }),
      );
      addTearDown(api.close);
      final task = api.ensureSession(
        accountId: source.identity.accountId,
        authentication: source,
        onDeviceNotRegistered: (_) async {
          restores++;
        },
      );
      if (boundary == 'challenge') {
        await task;
        expect(restores, 1);
        expect(challenges, 2);
      } else {
        await expectLater(task, throwsA(isA<SquareApiException>()));
        expect(restores, 0);
        expect(challenges, 1);
      }
    }
  });
}
