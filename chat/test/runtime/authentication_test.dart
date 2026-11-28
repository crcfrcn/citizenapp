// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chat/chat.dart' as chat;
import 'package:chat/chat.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:citizen_testing/database.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_user/api.dart'
    show
        CitizenServeChatAccess,
        SquareApiClient,
        SquareApiException,
        SquareSession;
import 'package:citizen_user/context.dart' show CurrentUser, CurrentUserContext;
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 验证宿主WSS许可、永久CID及设备身份绑定和迟到结果隔离。

class _UnusedSecurity implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
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
        // 本夹具只映射已注册用户的聊天许可，不调用真实钱包或链门禁。
      );
  int requests = 0;
  Completer<CitizenServeChatAccess>? held;
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
    if (held != null) return await held!.future;
    return CitizenServeChatAccess(
      realtimeUrl: Uri.parse('wss://service.test/api/chat/realtime'),
      accessToken: 'opaque',
      expiresAt: DateTime.now().millisecondsSinceEpoch + 300000,
    );
  }
}

void _registerMlsBoundary() {
  TestCitizenSdkHarness();
  useIsolatedIsar();
  test('宿主直接映射完整WSS许可，跨用户设备在请求前拒绝', () async {
    final sessions = _ChatAccessProvider();
    final host = ChatRuntime(
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
      'wss://service.test/api/chat/realtime',
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

  test('本地身份读取期间修订变化，旧读取结果不能成为当前聊天账户', () async {
    final security = _UnusedSecurity(), context = _DelayedCurrent();
    final host = ChatRuntime(
      accountSecurity: security,
      currentUserContext: context,
      squareSessionProvider: _ChatAccessProvider(),
    );
    addTearDown(host.push.dispose);
    addTearDown(security.revision.dispose);
    final reading = host.currentAccount();
    security.revision.value++;
    context.held.complete(null);
    await expectLater(reading, throwsStateError);
  });
  test('聊天许可在途切换身份，迟到授权回执不能交给聊天运行时', () async {
    final security = _UnusedSecurity(),
        sessions = _ChatAccessProvider()
          ..held = Completer<CitizenServeChatAccess>();
    final host = ChatRuntime(
      accountSecurity: security,
      currentUserContext: _UnusedCurrentUserContext(),
      squareSessionProvider: sessions,
    );
    addTearDown(host.push.dispose);
    addTearDown(security.revision.dispose);
    const account = ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope: 'synthetic',
      userId: 'user-a',
      bindingRevision: 1,
      accountId: 'account-a',
      displayName: 'A',
    );
    final request = host.requestChatAccess(
      account: account,
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
    );
    security.revision.value++;
    sessions.held!.complete(
      CitizenServeChatAccess(
        realtimeUrl: Uri.parse('wss://service.test/api/chat/realtime'),
        accessToken: 'opaque',
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
    await expectLater(request, throwsStateError);
    expect(sessions.requests, 1);
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

  test('聊天用户标识就是永久CID，绑定只保存公开事实', () {
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
        StateError('native /tmp/libmls \uFFFD\u0000 debug'),
      );

      expect(message, '聊天暂时无法使用，请稍后重试');
      expect(message.toLowerCase(), isNot(contains('bad state')));
      expect(message, isNot(contains('libsmoldot')));
    });

    test('MLS 状态所有权错误映射固定中文且不透传技术码', () {
      const error = MlsException(
        MlsErrorCode.stateOwnerMismatch,
        'CHAT_MLS_STATE_OWNER_MISMATCH:debug',
      );

      final message = chatUserErrorMessage(error);
      expect(message, contains('其他用户'));
      expect(message, isNot(contains('CHAT_MLS')));
    });

    test('身份同步失败、明确未注册与MLS设备认证失败分层提示', () {
      const unsynchronized = SquareApiException(
        '该钱包账户未绑定 CID',
        statusCode: 403,
        errorCode: 'cid_not_bound',
      );
      const unregistered = SquareApiException(
        '当前账户明确未注册',
        statusCode: 403,
        errorCode: 'identity_unregistered',
      );
      const deviceMissing = SquareApiException(
        'MLS设备未登记',
        statusCode: 401,
        errorCode: 'device_not_registered',
      );

      expect(chatUserErrorMessage(unsynchronized), '公民身份同步失败，请重试');
      expect(chatUserErrorMessage(unsynchronized), isNot(contains('注册')));
      expect(chatUserErrorMessage(unregistered), '当前默认账户尚未注册身份CID号，无法使用聊天');
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

    test('聊天附件会员拒绝使用统一错误码并映射为权益提示', () {
      const error = SquareApiException(
        'attachment membership required',
        statusCode: 403,
        errorCode: 'attachment_membergate_required',
      );

      expect(chatUserErrorMessage(error), '非会员禁止使用聊天附件');
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
          bindRev: 1,
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
    final runtime = ChatRuntime(
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

class _DelayedCurrent implements CurrentUserContext {
  final held = Completer<CurrentUser?>();
  @override
  Future<CurrentUser?> resolve() => held.future;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected current user operation');
}

// 验证实际聊天运行时串联MLS身份、挑战签名和许可认证。

class _Security implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected wallet operation');
}

class _Current implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: testMlsAccountId,
      ss58Address: 'synthetic-public-address',
      name: 'A',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: const IdentityBinding(
      genesisHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId: testMlsAccountId,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected current user operation');
}

class _Transport implements chat.ChatServiceTransport {
  _Transport(this.accessProvider);
  final chat.ChatAccessProvider accessProvider;
  chat.ChatAccess? access;
  final published = <chat.MlsKeyPackage>[];
  @override
  String? lastRealtimeDiagnosticCode;
  @override
  Future<void> connect() async {
    access = await accessProvider();
  }

  @override
  Future<void> registerPushEndpoint({
    required String pushProvider,
    required String pushToken,
    required String? apnsEnvironment,
    required int expiresAtMillis,
  }) async {}
  @override
  Future<void> publishKeyPackage(chat.MlsKeyPackage keyPackage) async {
    published.add(keyPackage);
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected chat transport operation');
}

void _registerMlsRuntimeAuthentication() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('公民宿主聊天初始化完整经过同一聊天运行时的MLS身份、挑战签名及许可认证', () async {
    SharedPreferences.setMockInitialValues({});
    final temporary = await Directory.systemTemp.createTemp(
      'citizen-chat-auth-',
    );
    final root = Directory(await temporary.resolveSymbolicLinks());
    final state = await Directory('${root.path}/mls').create();
    final security = _Security();
    final current = _Current();
    final paths = <String>[];
    final devices = <String>{};
    final client = SquareApiClient(
      baseUrl: 'https://service.test/api',
      httpClient: MockClient((request) async {
        final proof = (jsonDecode(
          utf8.decode(
            base64Url.decode(
              base64Url.normalize(request.headers['x-mls-proof']!),
            ),
          ),
        ) as Map).cast<String, dynamic>();
        expect(proof['user_id'], testMlsCidNumber);
        expect(proof['account_id'], testMlsAccountId);
        expect(proof['request_target'], request.url.path);
        expect(proof['body_hash'], '0x${sha256.convert(request.bodyBytes)}');
        expect(proof['public_key'], '0x${proof['device_id']}');
        devices.add(proof['device_id'] as String);
        paths.add(request.url.path);
        final now = DateTime.now().millisecondsSinceEpoch;
        final response = switch (request.url.path) {
          '/api/user/sessions' => fakeMlsSession(
            deviceId: proof['device_id'] as String,
          ),
          '/api/chat/access' => <String, Object>{
            'is_ok': true,
            'realtime_url': 'wss://service.test/api/chat/realtime',
            'access_token': 'synthetic-chat-token',
            'expires_at': now + 300000,
            'recheck_at': now + 120000,
          },
          _ => throw StateError('unexpected HTTP request'),
        };
        return http.Response(jsonEncode(response), 200);
      }),
    );
    final sessions = SquareSessionProvider(
      accountSecurity: security,
      currentUserContext: current,
      client: client,
    );
    late _Transport transport;
    var transportCreates = 0;
    final runtime = ChatRuntime(
      accountSecurity: security,
      currentUserContext: current,
      squareSessionProvider: sessions,
      documentsDirectoryProvider: () async => root,
      stateStoreFactory: (user) async =>
          chat.MlsStateStore(state, ownerUserId: user),
      pushTokenProvider: () async => const AppPushToken(
        provider: 'fcm',
        token: 'synthetic-push-token',
        apnsEnvironment: null,
      ),
      transportFactory: ({required identity, required accessProvider}) {
        transportCreates++;
        return transport = _Transport(accessProvider);
      },
      onClosing: sessions.closeAuthentication,
    );
    sessions.installMlsAuthentication(
      readLocalIdentity: () => (() => runtime)().readLocalMlsIdentity(),
      createProof: (request) =>
          (() => runtime)().createMlsAuthenticationProof(request),
    );
    addTearDown(() async {
      await runtime.stop();
      client.close();
      security.revision.dispose();
      await root.delete(recursive: true);
    });
    await Future.wait([
      runtime.ensureReady(testMlsAccountId),
      runtime.ensureReady(testMlsAccountId),
    ]);
    expect(transportCreates, 1);
    final identity = await runtime.readLocalMlsIdentity();
    expect(devices, {identity.deviceId});
    expect(transport.published.single.deviceId, identity.deviceId);
    expect(transport.access!.accessToken, 'synthetic-chat-token');
    expect(paths, ['/api/user/sessions', '/api/chat/access']);
    expect(
      await chat.MlsStateStore(
        state,
        ownerUserId: testMlsCidNumber,
      ).pendingResults(null),
      isEmpty,
    );
  });
}

void main() {
  group("mls_boundary_test", _registerMlsBoundary);
  group("mls_runtime_authentication_test", _registerMlsRuntimeAuthentication);
}
