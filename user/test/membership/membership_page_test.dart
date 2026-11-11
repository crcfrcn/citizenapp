import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as light;
import 'dart:convert';
import 'dart:async';

import 'package:citizen_testing/membergate_fixture.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/membership/membership_page.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Sessions extends Fake implements SquareSessionProvider {
  final session = SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'resource-token',
    cidNumber: testMlsCidNumber,
    accountId: testMlsAccountId,
    bindRev: 1,
    expiresAt: 9999999999999,
    authenticateRequest: fakeMlsRequestHeaders,
  );
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async =>
      SquareSessionResolution(SquareSessionStatus.ready, session: session);
}

class _Identity extends Fake implements FinalizedIdentityResolver {}

class _Resources extends Fake implements SubscriptionService {
  int calls = 0;
  @override
  Future<SquareResourceAuthorization> authorizeResources(
    SquareSession session, {
    bool forceRefresh = false,
  }) async {
    calls++;
    return SquareApiClient.decodeResourceAuthorization(
      resourceAuthorizationFixture(allowed: false),
    );
  }
}

void main() {
  test('资源授权只解析服务端规则和用量', () {
    final value = SquareApiClient.decodeResourceAuthorization(
      resourceAuthorizationFixture(),
    );
    expect(value.allowed, isTrue);
    expect(value.plan!.memberLevel, 'freedom');
    expect(value.plan!.priceFen, isNull);
    expect(value.plans.length, 3);
    expect(value.usageState, isNotNull);
  });
  test('明确拒绝授权不构造会员展示状态', () {
    final value = SquareApiClient.decodeResourceAuthorization(
      resourceAuthorizationFixture(allowed: false),
    );
    expect(value.allowed, isFalse);
    expect(value.plan, isNull);
    expect(value.plans.length, 3);
  });
  test('旧会员响应与混合响应均拒绝', () {
    for (final extra in [
      {'membergate': null},
      {'membergate_active': true},
      {'final_hash': '0x00'},
    ]) {
      expect(
        () => SquareApiClient.decodeResourceAuthorization({
          ...resourceAuthorizationFixture(),
          ...extra,
        }),
        throwsA(isA<SquareApiException>()),
      );
    }
  });
  test('不完整许可和不一致档位拒绝', () {
    for (final authorization in [
      {'allowed': true, 'plan': null},
      {'allowed': false, 'plan': resourceAuthorizationFixture()['plans'][0]},
      {'allowed': 'yes', 'plan': null},
    ]) {
      expect(
        () => SquareApiClient.decodeResourceAuthorization({
          ...resourceAuthorizationFixture(),
          'authorization': authorization,
        }),
        throwsA(isA<SquareApiException>()),
      );
    }
  });
  test('授权 GET 保持原会话证明且无展示字段', () async {
    final sessions = _Sessions();
    final requests = <http.Request>[];
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(resourceAuthorizationFixture()), 200);
      }),
    );
    addTearDown(api.close);
    final result = await api.fetchResourceAuthorization(sessions.session);
    expect(result.allowed, isTrue);
    expect(requests.single.url.path, '/api/membergate');
    expect(requests.single.headers['authorization'], 'Bearer resource-token');
    expect(requests.single.headers['x-mls-proof'], isNotEmpty);
  });
  test('确认会员交易只发送原交易锚并要求三字段回执', () async {
    final sessions = _Sessions();
    final tx = '0x${'11' * 32}', block = '0x${'22' * 32}';
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(jsonDecode(request.body), {'tx_hash': tx, 'block_hash': block});
        return http.Response(
          jsonEncode({'is_ok': true, 'tx_hash': tx, 'block_hash': block}),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await api.confirmPlatformSubscription(
      session: sessions.session,
      txHash: tx,
      blockHash: block,
    );
  });
  test('同一会话合并并行资源请求并复用有效许可', () async {
    final sessions = _Sessions();
    final response = Completer<http.Response>();
    var gets = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) {
        gets++;
        return response.future;
      }),
    );
    final service = SubscriptionService(
      identityResolver: _Identity(),
      sessionProvider: sessions,
      getWalletState: () => throw StateError('资源预检不读钱包'),
      api: api,
      resumePendingTransactions: false,
    );
    addTearDown(api.close);
    final one = service.authorizeResources(sessions.session);
    final two = service.authorizeResources(sessions.session);
    await Future<void>.delayed(Duration.zero);
    expect(gets, 1);
    response.complete(
      http.Response(jsonEncode(resourceAuthorizationFixture()), 200),
    );
    final values = await Future.wait([one, two]);
    expect(identical(values[0], values[1]), isTrue);
    expect(
      (await service.authorizeResources(sessions.session)).allowed,
      isTrue,
    );
    expect(gets, 1);
    SubscriptionService.invalidateCitizenAccount(sessions.session.accountId);
  });
  test('临时故障退避期间复用失败，五秒后允许重试', () async {
    final sessions = _Sessions();
    var now = 2000000, gets = 0;
    SubscriptionService.nowForTesting = () => now;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        gets++;
        return gets == 1
            ? http.Response('{"is_ok":false,"error_code":"unavailable"}', 503)
            : http.Response(jsonEncode(resourceAuthorizationFixture()), 200);
      }),
    );
    final service = SubscriptionService(
      identityResolver: _Identity(),
      sessionProvider: sessions,
      getWalletState: () => throw StateError('资源预检不读钱包'),
      api: api,
      resumePendingTransactions: false,
    );
    addTearDown(() {
      api.close();
      SubscriptionService.invalidateCitizenAccount(sessions.session.accountId);
      SubscriptionService.nowForTesting = null;
    });
    await expectLater(
      service.authorizeResources(sessions.session),
      throwsA(isA<SquareApiException>()),
    );
    await expectLater(
      service.authorizeResources(sessions.session, forceRefresh: true),
      throwsA(isA<SquareApiException>()),
    );
    expect(gets, 1);
    now += 5000;
    expect(
      (await service.authorizeResources(sessions.session)).allowed,
      isTrue,
    );
    expect(gets, 2);
  });
  test('身份失效后的迟到资源响应不能恢复旧权限', () async {
    final sessions = _Sessions();
    final response = Completer<http.Response>();
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) => response.future),
    );
    final service = SubscriptionService(
      identityResolver: _Identity(),
      sessionProvider: sessions,
      getWalletState: () => throw StateError('资源预检不读钱包'),
      api: api,
      resumePendingTransactions: false,
    );
    addTearDown(api.close);
    final pending = service.authorizeResources(sessions.session);
    final rejected = expectLater(
      pending,
      throwsA(isA<SubscriptionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    SubscriptionService.invalidateCitizenAccount(sessions.session.accountId);
    response.complete(
      http.Response(jsonEncode(resourceAuthorizationFixture()), 200),
    );
    await rejected;
    expect(
      SubscriptionService.chatAuthorizedFor(sessions.session.cidNumber),
      isFalse,
    );
  });
  testWidgets('会员页使用轻节点会员，服务端仅交付规则和用量', (tester) async {
    final resources = _Resources(), sessions = _Sessions();
    final reader = light.Reader();
    reader.behavior = (a, b, c, d) async => light.snapshot(
      b,
      a,
      cidNumber: sessions.session.cidNumber,
      citizens: c,
      creators: d,
    );
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => light.block(103),
      getGenesisHash: () async => light.hash(0),
      getAccount: () async => sessions.session.accountId,
    );
    addTearDown(source.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPage(
          sessionProvider: _Sessions(),
          subscriptionService: resources,
          chainData: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resources.calls, 1);
    expect(find.text('会员｜订阅'), findsOneWidget);
    expect(find.textContaining('待接入'), findsNothing);
    expect(source.snapshot!.block.number, BigInt.from(103));
    expect(source.snapshot!.memberActive(sessions.session.cidNumber), isTrue);
    expect(find.text('当前会员'), findsOneWidget);
    expect(find.text('取消订阅'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
