import '../support/fake_citizen_sdk.dart';

import 'package:citizenapp/chat/tatachat_sdk_adapter.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';

import '../support/isar_test_env.dart';

class _TestBinding extends AccountDataBinding implements ChatDataBinding {
  const _TestBinding({
    required super.genesisHash,
    required super.cidNumber,
    required super.bindingRevision,
    required super.accountId,
  });

  @override
  String get keyDomain => genesisHash;

  @override
  String get userId => cidNumber;

  @override
  String get id => '$keyDomain|$userId|$bindingRevision|$accountId';
}

class _TargetHandoverKeyFailureWalletManager implements AccountSecurityService {
  final List<Uint8List> sourceKeys = <Uint8List>[
    Uint8List.fromList(List<int>.filled(32, 17)),
  ];

  @override
  Future<List<Uint8List>> deriveDataKeysForBindingHandover(
    AccountDataBinding binding,
    List<({String? context, LocalKeyPurpose purpose})> requests,
  ) async {
    if (binding.bindingRevision == 1) return sourceKeys;
    throw StateError('target-key-derivation-failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCurrentUserContext implements CurrentUserContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestCitizenSdkHarness();
  useIsolatedIsar();

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

  test('SDK用户标识始终映射公民CID，MLS不在宿主供钥用途中', () {
    const binding = AccountDataBinding(
      genesisHash:
          '0x'
          '1111111111111111111111111111111111111111111111111111111111111111',
      cidNumber: 'CN220-CTZN2-100000001-2026',
      bindingRevision: 1,
      accountId:
          '0x'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(
      CitizenChatStorageKeyProvider.toChatBinding(binding).userId,
      binding.cidNumber,
    );
    expect(ChatStorageKeyPurpose.values.map((e) => e.name), [
      'chat',
      'chatIndex',
      'attachment',
    ]);
  });

  group('Chat换绑只处理剩余非MLS用途', () {
    test('目标用途钥取得失败时立即清零已经取得的来源用途钥', () async {
      const source = _TestBinding(
        genesisHash:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindingRevision: 1,
        accountId:
            '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      const target = _TestBinding(
        genesisHash:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindingRevision: 2,
        accountId:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final walletManager = _TargetHandoverKeyFailureWalletManager();
      final store = ChatStore(
        crypto: ChatCrypto(CitizenChatStorageKeyProvider(walletManager)),
      );
      await store.activateBindingFence(source);
      // 文件域仅使用本用例临时目录，失败验收不能读写真实设备数据。
      final deviceDirectory = await Directory.systemTemp.createTemp(
        'citizenapp_mls_boundary_',
      );
      addTearDown(() => deviceDirectory.delete(recursive: true));
      final currentUserContext = _UnusedCurrentUserContext();
      final runtime = createCitizenChatRuntime(
        store: store,
        accountSecurity: walletManager,
        currentUserContext: currentUserContext,
        squareSessionProvider: SquareSessionProvider(
          accountSecurity: walletManager,
          currentUserContext: currentUserContext,
        ),
        documentsDirectoryProvider: () async => deviceDirectory,
      );

      await expectLater(
        runtime.stageAccountHandover(source: source, target: target),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'target-key-derivation-failed',
          ),
        ),
      );
      for (final key in walletManager.sourceKeys) {
        expect(key, everyElement(0));
      }
    });
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

    test('Cloudflare 未绑定 CID 与设备子钥失败分层提示', () {
      const unregistered = SquareApiException(
        '该钱包账户未绑定 CID',
        statusCode: 403,
        errorCode: 'cid_not_bound',
      );
      const deviceMissing = SquareApiException(
        '设备子钥未注册',
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

    test('TataChatServer 会员拒绝使用统一错误码并映射为权益提示', () {
      const error = SquareApiException(
        'chat membership required',
        statusCode: 403,
        errorCode: 'chat_membership_required',
      );

      expect(chatUserErrorMessage(error), '当前账户尚未开通聊天会员权益');
    });
  });

  test('CitizenServe 聊天授权 HTTP 与响应解析只属于 SquareApiClient', () async {
    final client = SquareApiClient(
      baseUrl: 'https://www.example.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/chatserver/access');
        expect(jsonDecode(request.body), <String, Object?>{
          'device_id': 'device-a',
        });
        expect(request.headers['authorization'], 'Bearer session-a');
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'chat_server_url': 'https://chat.example.test',
            'chat_server_token': 'header.payload.signature',
            'expires_at_millis': 4102444800000,
          }),
          200,
        );
      }),
    );
    final access = await client.fetchChatServerAccess(
      session: SquareSession(
        sessionToken: 'session-a',
        cidNumber: 'CN220-CTZN2-100000001-2026',
        bindingRevision: 1,
        accountId:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        expiresAt: 4102444800000,
        signRequest: (_) async => 'request-signature',
      ),
      deviceId: 'device-a',
    );

    expect(access.chatServerUrl, Uri.parse('https://chat.example.test'));
    expect(access.chatServerToken, 'header.payload.signature');
    expect(access.expiresAtMillis, 4102444800000);
  });

  test('SquareApiClient 拒绝非 HTTPS 聊天服务地址', () async {
    final client = SquareApiClient(
      baseUrl: 'https://www.example.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'chat_server_url': 'http://chat.example.test',
            'chat_server_token': 'header.payload.signature',
            'expires_at_millis': 4102444800000,
          }),
          200,
        ),
      ),
    );

    await expectLater(
      client.fetchChatServerAccess(
        session: SquareSession(
          sessionToken: 'session-a',
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindingRevision: 1,
          accountId:
              '0x1111111111111111111111111111111111111111111111111111111111111111',
          expiresAt: 4102444800000,
          signRequest: (_) async => 'request-signature',
        ),
        deviceId: 'device-a',
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.message,
          'message',
          '聊天服务访问授权响应不合法',
        ),
      ),
    );
  });

  test('SquareApiClient 在发网前拒绝空聊天设备标识', () async {
    var requestCount = 0;
    final client = SquareApiClient(
      baseUrl: 'https://www.example.test/api',
      httpClient: MockClient((_) async {
        requestCount += 1;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.fetchChatServerAccess(
        session: SquareSession(
          sessionToken: 'session-a',
          cidNumber: 'CN220-CTZN2-100000001-2026',
          bindingRevision: 1,
          accountId:
              '0x1111111111111111111111111111111111111111111111111111111111111111',
          expiresAt: 4102444800000,
          signRequest: (_) async => 'request-signature',
        ),
        deviceId: '   ',
      ),
      throwsA(isA<SquareApiException>()),
    );
    expect(requestCount, 0);
  });
}
