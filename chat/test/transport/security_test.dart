// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';

import 'package:chat/mls/protocol.dart';
import 'package:chat/transport/attachment.dart';
import 'package:chat/transport/connection.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证聊天许可安全地址及必需WebSocket子协议。

final class _WrongProtocolSocket implements ChatSocket {
  final StreamController<Object?> _events = StreamController<Object?>();

  @override
  String? get protocol => null;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  void add(List<int> bytes) {}

  @override
  Future<void> close() async {
    unawaited(_events.close());
  }
}

void _registerChatTransportContract() {
  test('access contract rejects paths, credentials in URL and cleartext', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final value in <String>[
      'http'
          '://chat.example.test',
      'https://user@chat.example.test',
      'https://chat.example.test/'
          'v1',
    ]) {
      expect(
        () => ChatAccess(
          realtimeUrl: Uri.parse(value),
          accessToken: 'token',
          expiresAtMillis: now + 300000,
        ).validate(now),
        throwsStateError,
      );
    }
  });

  test('missing chat subprotocol fails closed', () async {
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccess(
        realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
        accessToken: 'token',
        expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
      ),
      socketConnector: (uri, token) async => _WrongProtocolSocket(),
    );
    await expectLater(
      transport.connect(),
      throwsA(isA<ChatConnectionException>()),
    );
    await transport.dispose();
  });
}

// 验证服务根、令牌和唯一WSS及同源HTTPS附件合同。

ChatAccess access(
  Uri url, {
  String token = 'test-token',
  int expires = 200000,
}) =>
    ChatAccess(realtimeUrl: url, accessToken: token, expiresAtMillis: expires);

void _registerSecurity() {
  test('唯一服务入口拒绝明文、WSS 根和相对地址', () {
    for (final url in [
      Uri.parse(
        'http'
        '://chat.example.com',
      ),
      Uri.parse(
        'ws'
        '://chat.example.com',
      ),
      Uri.parse('wss://chat.example.com'),
      Uri.parse('/chat'),
      Uri.parse('https:///chat'),
    ]) {
      expect(() => access(url).validate(1000), throwsStateError);
    }
  });

  test('服务根拒绝账户信息、业务路径、查询和片段', () {
    for (final url in [
      Uri.parse('https://user:password@chat.example.com'),
      Uri.parse('https://chat.example.com/chat'),
      Uri.parse('https://chat.example.com?token=value'),
      Uri.parse('https://chat.example.com/#fragment'),
      Uri.parse('wss://user@chat.example.com/api/chat/realtime'),
      Uri.parse('wss://chat.example.com/api/chat/realtime?token=value'),
      Uri.parse('wss://chat.example.com/api/chat/realtime#fragment'),
      Uri.parse('wss://chat.example.com/api/chat/other'),
    ]) {
      expect(() => access(url).validate(1000), throwsStateError);
    }
  });

  test('空令牌、带空白令牌和即将过期凭据均拒绝', () {
    final url = Uri.parse('wss://chat.example.com/api/chat/realtime');
    for (final token in [
      '',
      'invalid token',
      'invalid\ntoken',
      '令牌',
      'a' * (16384 + 1),
    ]) {
      expect(() => access(url, token: token).validate(1000), throwsStateError);
    }
    expect(() => access(url, expires: 61000).validate(1000), throwsStateError);
    expect(() => access(url, expires: 61001).validate(1000), returnsNormally);
  });

  test('网络端点拒绝非加密协议', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse(
          'http'
          '://example.com',
        ),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      (ChatAccess(
        realtimeUrl: Uri.parse('wss://example.com/api/chat/realtime'),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).realtimeUrl.scheme,
      'wss',
    );
    expect(
      (ChatAccess(
        realtimeUrl: Uri.parse('wss://example.com/api/chat/realtime'),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).attachmentChunkUrl('owner-a', 'attachment-a', 0).scheme,
      'https',
    );
  });

  test('完整WSS控制入口与同origin HTTPS分块是唯一公开地址合同', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final access = ChatAccess(
      realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
      accessToken: 'opaque-token',
      expiresAtMillis: now + 120000,
    );
    access.validate(now);
    expect(
      access.attachmentChunkUrl('owner-a', 'attachment-a', 3).toString(),
      'https://chat.example.test/api/chat/attachments/owner-a/attachment-a/chunks/3',
    );
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse('wss://chat.example.test/realtime'),
        accessToken: 'opaque-token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
  });

  test('network endpoints fail closed unless encrypted', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse(
          'ws'
          '://chat.example.test',
        ),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse(
          'http'
          '://chat.example.test',
        ),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
  });

  test('附件传输地址只允许HTTPS', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(
      (ChatAccess(
        realtimeUrl: Uri.parse('wss://objects.example.com/api/chat/realtime'),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      )..validate(now)).attachmentChunkUrl('owner-a', 'attachment-a', 0).scheme,
      'https',
    );
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse(
          'http'
          '://objects.example.com',
        ),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
    expect(
      () => ChatAccess(
        realtimeUrl: Uri.parse('https://user@example.com'),
        accessToken: 'token',
        expiresAtMillis: now + 120000,
      ).validate(now),
      throwsStateError,
    );
  });
}

void main() {
  group(
    "transport/chat_transport_contract_test",
    _registerChatTransportContract,
  );
  group("transport/security_test", _registerSecurity);
}
