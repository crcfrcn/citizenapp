import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat/mls/mls_boundary.dart';
import 'package:chat/transport/attachment_transfer.dart';
import 'package:chat/transport/chat_connection.dart';

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

void main() {
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
