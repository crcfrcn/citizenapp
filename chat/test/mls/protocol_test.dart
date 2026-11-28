// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:io';

import 'package:chat/error.dart';
import 'package:chat/mls/protocol.dart';
import 'package:chat/mls/store.dart';
import 'package:chat/transport/attachment.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chat/native.dart';
import 'package:citizen_user/api.dart' show SquareApiException;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证MLS错误脱敏及认证请求的身份、期限和HTTPS边界。

// 合同测试锁定 公民聊天 的中性身份、状态清理边界和脱敏错误码。
void _registerBoundary() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('原生存储错误只有固定分类，不授权自动清理', () {
    final storage = MlsException.fromTechnicalMessage(
      'CHAT_MLS_STORAGE_READ_FAILED:detail',
    );
    final invalid = MlsException.fromTechnicalMessage(
      'CHAT_MLS_STATE_INVALID:detail',
    );
    expect(storage.code, MlsErrorCode.storageReadFailed);
    expect(storage.diagnosticCode, 'storage_read_failed');
    expect(invalid.code, MlsErrorCode.stateInvalid);
    expect(chatDiagnosticCode(StateError('hidden')), 'operation_failed');
    final conflict = MlsException.fromTechnicalMessage(
      'CHAT_MLS_WELCOME_CONFLICT',
      operation: MlsOperation.groupProcess,
    );
    expect(conflict.code, MlsErrorCode.welcomeConflict);
    expect(chatDiagnosticCode(conflict), 'welcome_conflict');
    expect(conflict.diagnosticOperation, 'group_process');
    expect(
      MlsException.fromTechnicalMessage('synthetic-private-detail').code,
      MlsErrorCode.operationFailed,
    );
  });

  test('已知握手原因保留，服务响应动态字段不进入诊断', () {
    expect(
      chatDiagnosticCode(
        const CitizenSdkException(
          code: CitizenSdkErrorCode.notReady,
          message: 'synthetic-private-detail',
        ),
      ),
      'sdk_admission_notReady',
    );
    expect(
      chatDiagnosticCode(const ChatConnectionException('realtime_http_503')),
      'realtime_http_503',
    );
    expect(
      chatDiagnosticCode(
        const SquareApiException(
          'synthetic-private-body',
          statusCode: 503,
          errorCode: 'synthetic-private-code',
        ),
      ),
      'service_unavailable',
    );
    expect(
      chatDiagnosticCode(
        const SquareApiException('synthetic', statusCode: 429),
      ),
      'resource_limit',
    );
  });

  test('结构化认证请求固定字段且复制正文，禁止签名域和身份注入', () {
    final bytes = [1, 2, 3];
    final request = createAuthenticationRequest(body: bytes);
    bytes[0] = 9;
    expect(request.bodyBytes, [1, 2, 3]);
    expect(() => request.bodyBytes[0] = 9, throwsUnsupportedError);
    expect(
      request.toJson().keys,
      unorderedEquals([
        'token_purpose',
        'service_origin',
        'nonce_id',
        'expires_at',
        'http_method',
        'request_target',
        'body_hex',
      ]),
    );
    expect(request.toJson()['body_hex'], '010203');
    request.validate();
  });

  test('认证拒绝非HTTPS源、地址别名、过期挑战和非法请求', () {
    for (final request in [
      createAuthenticationRequest(
        origin: Uri(scheme: 'http', host: 'api.example.test').toString(),
      ),
      createAuthenticationRequest(
        origin: Uri(scheme: 'ws', host: 'api.example.test').toString(),
      ),
      createAuthenticationRequest(origin: 'wss://api.example.test'),
      createAuthenticationRequest(origin: 'https://user@api.example.test'),
      createAuthenticationRequest(origin: 'https://api.example.test/path'),
      createAuthenticationRequest(origin: 'https://api.example.test?query'),
      createAuthenticationRequest(origin: 'https://api.example.test#fragment'),
      createAuthenticationRequest(target: '//other.example.test/path'),
      createAuthenticationRequest(target: '/path#fragment'),
      createAuthenticationRequest(target: '/path%xx'),
      createAuthenticationRequest(target: '/path\nheader'),
      createAuthenticationRequest(method: 'post'),
      createAuthenticationRequest(challenge: '22'),
      createAuthenticationRequest(expiry: 0),
      createAuthenticationRequest(
        expiry: DateTime.now().millisecondsSinceEpoch + 600000,
      ),
      createAuthenticationRequest(body: [-1]),
      createAuthenticationRequest(body: [256]),
      createAuthenticationRequest(
        body: List.filled(MlsAuthenticationRequest.maxBodyBytes + 1, 0),
      ),
    ]) {
      expect(request.validate, throwsArgumentError);
    }
  });
}

// 验证早到密文持久去重及MLS状态目录保护和链接边界。

void _registerSession() {
  TestWidgetsFlutterBinding.ensureInitialized();
  requireMlsTestLibrary();
  test('早到MLS密文在同一原生状态保存、去重及校验所有者', () async {
    final root = await Directory.systemTemp.createTemp('chat_pending_');
    addTearDown(() => root.delete(recursive: true));
    final store = MlsStateStore(
      Directory(await root.resolveSymbolicLinks()),
      ownerUserId: 'user',
    );
    final identity = await store.prepareIdentity();
    const wire = MlsWireMessage(wireBytes: [1, 2], conversationId: 'group');
    await store.queuePendingInbound(wire);
    await store.queuePendingInbound(wire);
    expect((await store.readPendingInbound()).single.wireHex, wire.wireHex);
    store.dispose();
    expect((await store.readIdentity()).deviceId, identity.deviceId);
    await expectLater(
      MlsStateStore(store.directory, ownerUserId: 'other').readPendingInbound(),
      throwsA(isA<MlsException>()),
    );
    await store.clearPendingInbound();
    expect(await store.readPendingInbound(), isEmpty);
    await File('${store.path}/state.bin').writeAsString('broken', flush: true);
    await expectLater(store.readIdentity(), throwsA(isA<MlsException>()));
    expect(await File('${store.path}/state.bin').readAsString(), 'broken');
  });
  test('平台验证后的系统目录别名被规范化，末级符号链接仍拒绝', () async {
    final root = await Directory.systemTemp.createTemp('chat_platform_path_');
    addTearDown(() => root.delete(recursive: true));
    const channel = MethodChannel('citizenapp/chat/storage');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var path = root.path;
    messenger.setMockMethodCallHandler(channel, (call) async => {'path': path});
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final store = await MlsStateStore.prepare('synthetic-user');
    expect(store.path, await root.resolveSymbolicLinks());
    final identity = await store.prepareIdentity();
    // 平台再次打开既有目录不需要创建标记，仍复用原身份。
    final reopened = await MlsStateStore.prepare('synthetic-user');
    expect((await reopened.prepareIdentity()).deviceId, identity.deviceId);
    final link = await Link('${root.path}/link').create(root.path);
    path = link.path;
    await expectLater(
      MlsStateStore.prepare('synthetic-user'),
      throwsA(
        isA<MlsException>().having(
          (error) => error.code,
          'code',
          MlsErrorCode.directoryInvalid,
        ),
      ),
    );
  });
  test('未准备或符号链接存储目录不得用于MLS', () async {
    final root = await Directory.systemTemp.createTemp(
      'chat_storage_boundary_',
    );
    addTearDown(() => root.delete(recursive: true));
    final missing = MlsStateStore(
      Directory('${root.path}/missing'),
      ownerUserId: 'user',
    );
    await expectLater(
      missing.ensureReady(),
      throwsA(
        isA<MlsException>().having(
          (e) => e.code,
          'code',
          MlsErrorCode.directoryUnavailable,
        ),
      ),
    );
    final link = await Link('${root.path}/link').create(root.path);
    await expectLater(
      MlsStateStore(Directory(link.path), ownerUserId: 'user').ensureReady(),
      throwsA(
        isA<MlsException>().having(
          (e) => e.code,
          'code',
          MlsErrorCode.directoryInvalid,
        ),
      ),
    );
  });
}

void main() {
  group("mls/boundary_test", _registerBoundary);
  group("mls/session_test", _registerSession);
}
