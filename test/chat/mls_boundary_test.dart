import '../square/mls_authentication_fixture.dart';
import '../support/fake_citizen_sdk.dart';

import 'package:citizenapp/chat/tatachat_sdk_adapter.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/profile/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';

import '../support/isar_test_env.dart';

class _UnusedSecurity implements AccountSecurityService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCurrentUserContext implements CurrentUserContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatAccessProvider extends SquareSessionProvider {
  _ChatAccessProvider()
    : super(
        accountSecurity: _UnusedSecurity(),
        currentUserContext: _UnusedCurrentUserContext(),
      );
  int requests = 0;
  @override
  Future<CitizenServeChatAccess> requestChatAccess({
    required String deviceId,
    required String expectedCidNumber,
    required int expectedBindingRevision,
    required String expectedAccountId,
  }) async {
    requests++;
    expect(deviceId, 'device-a');
    expect(expectedCidNumber, 'user-a');
    expect(expectedBindingRevision, 1);
    expect(expectedAccountId, 'account-a');
    return CitizenServeChatAccess(
      realtimeUrl: Uri.parse('wss://service.test/api/tatachat/realtime'),
      accessToken: 'opaque',
      expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
    );
  }
}

void main() {
  TestCitizenSdkHarness();
  useIsolatedIsar();
  test('宿主直接映射完整WSS许可，跨用户设备在请求前拒绝', () async {
    final sessions = _ChatAccessProvider();
    final host = createCitizenChatRuntimeHost(
      accountSecurity: _UnusedSecurity(),
      currentUserContext: _UnusedCurrentUserContext(),
      squareSessionProvider: sessions,
    );
    const account = ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope: 'synthetic',
      userId: 'user-a',
      bindingRevision: 1,
      accountId: 'account-a',
      displayName: 'A',
    );
    final access = await host.requestChatAccess(
      account: account,
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
    );
    expect(
      access.realtimeUrl.toString(),
      'wss://service.test/api/tatachat/realtime',
    );
    expect(access.accessToken, 'opaque');
    await expectLater(
      host.requestChatAccess(
        account: account,
        identity: const ChatDevice(userId: 'user-b', deviceId: 'device-a'),
      ),
      throwsStateError,
    );
    expect(sessions.requests, 1);
    await host.push.dispose();
  });

  group('ChatDevice', () {
    test('accepts CID as chat identity without wallet private key', () {
      const identity = ChatDevice(
        userId: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice-phone',
      );

      expect(identity.validate(), isNull);
      expect(identity.userId, 'CN220-CTZN2-100000001-2026');
      expect(identity.deviceId, 'alice-phone');
    });

    test('rejects an ambiguous device identity', () {
      const identity = ChatDevice(
        userId: 'CN220-CTZN2-100000001-2026',
        deviceId: 'alice:phone',
      );

      expect(identity.validate(), contains('冒号'));
    });
  });

  test('SDK用户标识就是永久CID，绑定只保存公开事实', () {
    const binding = ChatBinding(
      bindingScope:
          '0x'
          '1111111111111111111111111111111111111111111111111111111111111111',
      userId: 'CN220-CTZN2-100000001-2026',
      bindingRevision: 1,
      accountId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    binding.validate();
    expect(binding.userId, 'CN220-CTZN2-100000001-2026');
  });

  group('Chat 用户错误文案', () {
    test('未知 StateError 不泄漏 Bad state 或底层乱码', () {
      final message = chatUserErrorMessage(
        StateError('native /tmp/libtatachat_sdk \uFFFD\u0000 debug'),
      );

      expect(message, '聊天暂时无法使用，请稍后重试');
      expect(message.toLowerCase(), isNot(contains('bad state')));
      expect(message, isNot(contains('libsmoldot')));
    });

    test('MLS 状态所有权错误映射固定中文且不透传技术码', () {
      const error = MlsNativeException(
        MlsNativeErrorCode.stateOwnerMismatch,
        'CHAT_MLS_STATE_OWNER_MISMATCH:debug',
      );

      final message = chatUserErrorMessage(error);
      expect(message, contains('其他用户'));
      expect(message, isNot(contains('CHAT_MLS')));
    });

    test('Cloudflare 未绑定 CID 与MLS设备认证失败分层提示', () {
      const unregistered = SquareApiException(
        '该钱包账户未绑定 CID',
        statusCode: 403,
        errorCode: 'cid_not_bound',
      );
      const deviceMissing = SquareApiException(
        'MLS设备未登记',
        statusCode: 401,
        errorCode: 'device_not_registered',
      );

      expect(chatUserErrorMessage(unregistered), contains('当前默认账户'));
      expect(chatUserErrorMessage(deviceMissing), contains('聊天设备身份'));
    });

    test('Cloudflare 服务端异常不误报为 OpenMLS 加载失败', () {
      const error = SquareApiException(
        'internal trace',
        statusCode: 503,
        errorCode: 'internal_error',
      );

      final message = chatUserErrorMessage(error);
      expect(message, '聊天服务暂时无法连接，请稍后重试');
      expect(message, isNot(contains('OpenMLS')));
      expect(message, isNot(contains('安全组件')));
    });

    test('聊天服务模块 会员拒绝使用统一错误码并映射为权益提示', () {
      const error = SquareApiException(
        'chat membership required',
        statusCode: 403,
        errorCode: 'chat_membership_required',
      );

      expect(chatUserErrorMessage(error), '当前账户尚未开通聊天会员权益');
    });
  });

  test('聊天许可设备与会话不一致时在HTTP前拒绝', () async {
    var requests = 0;
    final client = SquareApiClient(
      baseUrl: 'https://www.example.test/api',
      httpClient: MockClient((request) async {
        requests += 1;
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      client.fetchChatAccess(
        session: const SquareSession(
          deviceId: testMlsDeviceId,
          sessionToken: 'session-a',
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindingRevision: 1,
          accountId: '0x1111111111111111111111111111111111111111111111111111111111111111',
          expiresAt: 4102444800000,
          authenticateRequest: fakeMlsRequestHeaders,
        ),
        deviceId: 'device-1',
      ),
      throwsA(isA<SquareApiException>()),
    );
    expect(requests, 0);
  });

  test('停止共用实例前同步关闭普通MLS认证，不构造第二实例', () async {
    var closing = false;
    final security = _UnusedSecurity();
    final current = _UnusedCurrentUserContext();
    final sessions = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
    );
    final runtime = createCitizenChatRuntime(
      accountSecurity: security,
      currentUserContext: current,
      squareSessionProvider: sessions,
      onClosing: () {
        closing = true;
      },
    );
    final stopping = runtime.stop();
    expect(closing, true);
    await stopping;
    await runtime.close();
  });
}
