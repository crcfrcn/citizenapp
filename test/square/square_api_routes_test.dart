import '../account/membership/membership_page_test.dart'
    show membergatePlanFixture, membergateUsageFixture;

import 'dart:async';
import 'dart:convert';

import 'package:citizenapp/app_log.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/mls_authentication.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/8964/feed/square_models.dart';

import 'mls_authentication_fixture.dart';

void main() {
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
  _proposalFailureDiagnosticsTests();
  _proposalReadDiagnosticsTests();
  _failureDiagnosticsTests();
  _serviceUnavailableTests();
  _chatAccessTests();
  _readCoalescingTests();
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
          bindingRevision: 1,
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

/// 合成异常的toString不得被日志读取，防止未来把动态正文混入固定事件。
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
    bindingRevision: 1,
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
          ? {'ok': true, 'posts': []}
          : {'ok': false, 'error': 'synthetic_denial'},
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
        return http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    await Future.wait([
      for (var i = 0; i < 2; i++)
        api.setNotify(
          session: owner,
          followedCidNumber: testMlsCidNumber,
          enabled: true,
        ),
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
      'registration_required',
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
              jsonEncode({'error': code, 'message': canary, 'proof': canary}),
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
        // 会话发送前已有一次证明；收到503后不再创建证明或追加请求。
        expect(source.proofCalls, boundary == 'challenge' ? 0 : 1);
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
              jsonEncode({'error': 'device_not_registered'}),
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
                'purpose',
                'method',
                'request_target',
                'body_sha256',
              ]),
            );
            expect(body['purpose'], 'session');
            expect(body['method'], 'POST');
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
      expect(session.bindingRevision, source.identity.bindingRevision);
      expect(await attempt(), same(session));
      expect(registrations, 0);
      expect(paths, [
        '/api/user/challenges',
        if (boundary == 'session') '/api/user/sessions',
        '/api/user/challenges',
        '/api/user/sessions',
      ]);
      expect(source.proofCalls, boundary == 'challenge' ? 1 : 2);
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
              jsonEncode({'error': 'device_not_registered'}),
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
    expect(source.proofCalls, 0);
    expect(registrations, 0);
    unavailable = false;
    expect((await attempt()).isUsable, isTrue);
    expect(challenges, 2);
    expect(sessions, 1);
    expect(source.proofCalls, 1);
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
                'error': 'registration_required',
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
                    enrollmentId: null,
                    recoveryToken: null,
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
                    .having((e) => e.errorCode, '原码', 'registration_required'),
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
        expect(source.proofCalls, boundary == 'challenge' ? 0 : 1);
        expect(lines, [
          '[CitizenFailure] stage=$boundary http=$status code=registration_required',
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
              _ => jsonEncode({'ok': true, 'session_token': canary}),
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
                    enrollmentId: null,
                    recoveryToken: null,
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
          jsonEncode({'error': '$canary\ncode=forged', 'message': canary}),
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
