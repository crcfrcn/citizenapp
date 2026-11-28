// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:chat/mls/protocol.dart';
import 'package:chat/transport/attachment.dart';
import 'package:chat/transport/connection.dart';
import 'package:citizen_network/frame.dart';
import 'package:citizen_network/message.dart';
import 'package:citizen_testing/chat/runtime.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证WSS帧、附件重试和停止后迟到许可及命令超时关闭。

final class _Socket implements ChatSocket {
  final controller = StreamController<Object?>();
  final sent = <ChatFrame>[];
  void Function(ChatFrame)? respond;
  int closes = 0;
  bool failClose = false;
  @override
  String? get protocol => 'chat';
  @override
  Stream<Object?> get events => controller.stream;
  @override
  void add(List<int> bytes) {
    final frame = ChatFrame.fromBuffer(bytes);
    sent.add(frame);
    respond?.call(frame);
  }

  void receive(ChatFrame frame) => controller.add(frame.writeToBuffer());
  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw StateError('synthetic close failure');
    if (!controller.isClosed) unawaited(controller.close());
  }
}

final class _Http implements ChatHttpAdapter {
  final response = Completer<ChatHttpResponse>();
  final enteredGet = Completer<void>();
  int closes = 0;
  int puts = 0;
  int successfulPuts = 0;
  int putFailures = 0;
  bool pendingPut = false;
  @override
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    puts++;
    if (putFailures > 0) {
      putFailures--;
      throw const ChatConnectionException('attachment_network_failed');
    }
    if (pendingPut) return response.future;
    successfulPuts++;
    return ChatHttpResponse(statusCode: 204, headers: {}, body: Uint8List(0));
  }

  @override
  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) {
    if (!enteredGet.isCompleted) enteredGet.complete();
    return response.future;
  }

  @override
  Future<void> dispose() async {
    closes++;
  }
}

ChatAccess _lifecycleAccess({int lifetime = 300000}) => ChatAccess(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
  accessToken: 'opaque-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + lifetime,
);

ChatConnection _connection({
  ChatAccessProvider? access,
  required ChatSocketConnector connector,
  _Http? http,
}) => ChatConnection(
  identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
  accessProvider: access ?? () async => _lifecycleAccess(),
  socketConnector: connector,
  httpAdapterFactory: http == null ? null : () => http,
);

Future<ChatSocket> _ready(_Socket socket) async {
  scheduleMicrotask(
    () =>
        socket.receive(ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE)),
  );
  return socket;
}

void _registerChatConnectionLifecycle() {
  test('超出2MiB的入站帧在解析前关闭，方向错误的Ping也不能回Pong', () async {
    for (final oversized in [true, false]) {
      final socket = _Socket(), http = _Http();
      final transport = _connection(
        connector: (_, _) => _ready(socket),
        http: http,
      );
      await transport.connect();
      if (oversized) {
        socket.controller.add(Uint8List(2 * 1024 * 1024 + 1));
      } else {
        socket.receive(ChatFrame()..ping = Ping(sentAtMillis: Int64.ONE));
      }
      await Future<void>.delayed(Duration.zero);
      expect(socket.closes, 1);
      expect(http.closes, 1);
      expect(socket.sent, isEmpty);
      await transport.dispose();
    }
  });
  test('分块中断后以同 ID 同创建时间和原摘要重试 begin，不盲目 abort', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chat-chunk-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cipher');
    await file.writeAsBytes([1, 2, 3]);
    final http = _Http()..putFailures = 1, socket = _Socket();
    final metadata = <List<int>>[];
    socket.respond = (frame) {
      if (frame.whichBody() == ChatFrame_Body.beginAttachment) {
        metadata.add(frame.beginAttachment.attachment.writeToBuffer());
        socket.receive(
          ChatFrame()
            ..success = Success(
              kind: 'attachment.begun',
              ids: ['attachment-a'],
            ),
        );
      } else if (frame.whichBody() == ChatFrame_Body.completeAttachment) {
        socket.receive(
          http.successfulPuts == 0
              ? (ChatFrame()..failure = Failure(code: 'storage_unavailable'))
              : (ChatFrame()
                  ..attachmentReady = AttachmentReady(
                    attachmentId: 'attachment-a',
                  )),
        );
      } else {
        fail('unexpected command');
      }
    };
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    Future<void> upload() => transport.uploadEncryptedAttachment(
      attachmentId: 'attachment-a',
      recipientUserIds: ['user-b'],
      cipherFile: file,
      cipherByteSize: 3,
      cipherSha256: crypto.sha256.convert([1, 2, 3]).toString(),
      createdAtMillis: 567,
    );
    await expectLater(upload(), throwsA(isA<ChatConnectionException>()));
    await upload();
    expect(metadata, hasLength(2));
    expect(metadata.first, metadata.last);
    expect(http.puts, 2);
    expect(
      socket.sent.where(
        (frame) => frame.whichBody() == ChatFrame_Body.abortAttachment,
      ),
      isEmpty,
    );
    await transport.dispose();
  });

  test('停止期间迟到许可不能创建 socket，原 provider 故障保留', () async {
    final access = Completer<ChatAccess>();
    var opens = 0;
    final transport = _connection(
      access: () => access.future,
      connector: (_, _) async {
        opens++;
        return _Socket();
      },
    );
    final rejected = expectLater(
      transport.connect(),
      throwsA(isA<ChatConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await transport.dispose();
    access.complete(_lifecycleAccess());
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(opens, 0);

    final error = StateError('synthetic host error');
    final failed = _connection(
      access: () async => throw error,
      connector: (_, _) async => _Socket(),
    );
    await expectLater(failed.connect(), throwsA(same(error)));
    await failed.dispose();
  });

  test('迟到 socket 必须关闭，不能恢复已停止的连接', () async {
    final entered = Completer<void>(), opening = Completer<ChatSocket>();
    final transport = _connection(
      connector: (_, _) {
        entered.complete();
        return opening.future;
      },
    );
    final rejected = expectLater(
      transport.connect(),
      throwsA(isA<ChatConnectionException>()),
    );
    await entered.future;
    await transport.dispose();
    final lateSocket = _Socket();
    opening.complete(lateSocket);
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(lateSocket.closes, 1);
  });

  test('失败 Ready 不能当作就绪，下次连接重新取许可', () async {
    final sockets = [_Socket(), _Socket()];
    var reads = 0, opens = 0;
    final transport = _connection(
      access: () async {
        reads++;
        return _lifecycleAccess();
      },
      connector: (_, _) async {
        final socket = sockets[opens++];
        scheduleMicrotask(
          () => socket.receive(
            opens == 1
                ? (ChatFrame()..success = Success(kind: 'unexpected'))
                : (ChatFrame()..ready = Ready()),
          ),
        );
        return socket;
      },
    );
    await expectLater(
      transport.connect(),
      throwsA(isA<ChatConnectionException>()),
    );
    await transport.connect();
    expect(reads, 2);
    expect(sockets.first.closes, 1);
    await transport.dispose();
  });

  test('命令超时关闭整条连接，后续排队命令不能匹配迟到回执', () async {
    final socket = _Socket(), http = _Http();
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    final first = expectLater(
      transport.resolveKeyPackages('user-b'),
      throwsA(isA<ChatConnectionException>()),
    );
    final second = expectLater(
      transport.resolveKeyPackages('user-c'),
      throwsA(isA<ChatConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, hasLength(1));
    // 传输层使用真实异步资源；跨过现行12秒期限后核验关闭与排队拒绝。
    await Future<void>.delayed(const Duration(seconds: 13));
    await Future.wait([first, second]);
    expect(socket.sent, hasLength(1));
    expect(socket.closes, 1);
    expect(http.closes, 1);
    await transport.dispose();
  });

  test('许可截止同时关闭 WSS 和在途 HTTPS，晚响应不能变成成功', () async {
    final socket = _Socket(), http = _Http();
    final transport = _connection(
      access: () async => _lifecycleAccess(lifetime: 61000),
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    final directory = await Directory.systemTemp.createTemp('chat-expiry-');
    addTearDown(() => directory.delete(recursive: true));
    final pending = expectLater(
      transport.downloadEncryptedAttachment(
        ownerCid: 'owner-a',
        attachmentId: 'attachment-a',
        target: File('${directory.path}/cipher'),
        expectedByteSize: 1,
        expectedSha256: crypto.sha256.convert([1]).toString(),
      ),
      throwsA(isA<ChatConnectionException>()),
    );
    await http.enteredGet.future;
    await pending;
    http.response.complete(
      ChatHttpResponse(
        statusCode: 200,
        headers: {
          'content-length': '1',
          'x-chat-cipher-sha256': crypto.sha256.convert([1]).toString(),
        },
        body: Uint8List.fromList([1]),
      ),
    );
    expect(socket.closes, 1);
    expect(http.closes, 1);
    await transport.dispose();
  });

  test('关闭失败保留资源并可重试，已关闭 HTTP 不重复回收', () async {
    final socket = _Socket()..failClose = true, http = _Http();
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    await transport.connect();
    await expectLater(
      transport.dispose(),
      throwsA(isA<ChatConnectionException>()),
    );
    expect(http.closes, 1);
    socket.failClose = false;
    await transport.dispose();
    expect(socket.closes, 2);
    expect(http.closes, 1);
  });

  test('同 ID 附件重试固定元数据，丢失完成响应不 abort，Ready 才成功', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chat-attachment-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cipher');
    await file.writeAsBytes([1, 2, 3]);
    final hash = crypto.sha256.convert([1, 2, 3]).toString();
    final http = _Http(), socket = _Socket();
    final metadata = <List<int>>[];
    var completed = false, loseReply = true;
    socket.respond = (frame) {
      switch (frame.whichBody()) {
        case ChatFrame_Body.beginAttachment:
          metadata.add(frame.beginAttachment.attachment.writeToBuffer());
          socket.receive(
            ChatFrame()
              ..success = Success(
                kind: 'attachment.begun',
                ids: ['attachment-a'],
              ),
          );
        case ChatFrame_Body.completeAttachment:
          if (!completed && http.puts == 0) {
            socket.receive(ChatFrame()..failure = Failure(code: 'not_found'));
          } else if (loseReply) {
            completed = true;
            socket.receive(
              ChatFrame()..failure = Failure(code: 'storage_unavailable'),
            );
          } else {
            socket.receive(
              ChatFrame()
                ..attachmentReady = AttachmentReady(
                  attachmentId: 'attachment-a',
                ),
            );
          }
        default:
          fail('unexpected command');
      }
    };
    final transport = _connection(
      connector: (_, _) => _ready(socket),
      http: http,
    );
    Future<void> upload() => transport.uploadEncryptedAttachment(
      attachmentId: 'attachment-a',
      recipientUserIds: ['user-b'],
      cipherFile: file,
      cipherByteSize: 3,
      cipherSha256: hash,
      createdAtMillis: 123,
    );
    await expectLater(upload(), throwsA(isA<ChatConnectionException>()));
    expect(
      socket.sent.where((f) => f.whichBody() == ChatFrame_Body.abortAttachment),
      isEmpty,
    );
    expect(metadata.single, isNotEmpty);
    expect(
      AttachmentMetadata.fromBuffer(metadata.single).createdAtMillis.toInt(),
      123,
    );
    loseReply = false;
    await upload();
    expect(metadata, hasLength(1));
    expect(http.puts, 1);
    await transport.dispose();
  });
}

// 验证真实WebSocket握手、资源预检、命令关联及传输失败收口。

final class _FakeSocket implements ChatSocket {
  @override
  String? get protocol => 'chat';
  final StreamController<Object?> _events = StreamController<Object?>();
  final List<ChatFrame> sent = <ChatFrame>[];
  bool closed = false;
  bool refuseSend = false;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  void add(List<int> bytes) {
    if (refuseSend) {
      throw StateError('synthetic-private-socket-detail');
    }
    sent.add(ChatFrame.fromBuffer(bytes));
  }

  void receive(ChatFrame frame) => _events.add(frame.writeToBuffer());

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await _events.close();
  }
}

ChatAccess _access() => ChatAccessFixture(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
  accessToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void _registerChatServerConnection() {
  for (final status in [401, 403, 429, 503]) {
    test('系统WebSocket握手保留HTTP$status且不额外探测', () async {
      final client = _HandshakeHttpClient(status);
      await HttpOverrides.runZoned(() async {
        final transport = ChatConnection(
          identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
          accessProvider: () async => _access(),
        );
        await expectLater(
          transport.connect(),
          throwsA(
            isA<ChatConnectionException>().having(
              (e) => e.code,
              'HTTP类别',
              'realtime_http_$status',
            ),
          ),
        );
        await transport.dispose();
      }, createHttpClient: (_) => client);
      expect(client.requests, 1);
      expect(client.request.followRedirects, isFalse);
      expect(client.request.response.socket.destroyed, isTrue);
    });
  }

  test('不匹配的响应不能结清当前命令预留，关闭连接保留不确定消耗', () async {
    final socket = _FakeSocket(), gate = _ResourceGate();
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccessFixture(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await transport.connect();
    final mailbox = transport.fetchMailbox();
    final assertion = expectLater(
      mailbox,
      throwsA(
        isA<ChatConnectionException>().having(
          (e) => e.code,
          '相关性',
          'realtime_response_mismatch',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    socket.receive(ChatFrame()..success = (Success()..kind = 'unmatched'));
    await assertion;
    await transport.dispose();
    expect(gate.finished, 1); // 只结清Ready，不能以旧/错误响应退款当前命令。
    expect(gate.cancelled, greaterThan(0));
  });

  test('真实发送失败仍关闭连接并返回固定错误码，不泄漏原异常', () async {
    final socket = _FakeSocket()..refuseSend = true;
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await expectLater(
      transport.fetchMailbox(),
      throwsA(
        isA<ChatConnectionException>().having(
          (e) => e.code,
          '固定发送失败',
          'realtime_send_failed',
        ),
      ),
    );
    await transport.dispose();
    expect(socket.closed, isTrue);
    expect(socket.sent, isEmpty);
  });

  test('连接预检等待期间关闭，迟到预留释放且不打开socket', () async {
    final gate = _ResourceGate()..connectWait = Completer<void>();
    var openings = 0;
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccessFixture(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        openings++;
        return _FakeSocket();
      },
    );
    final opening = transport.connect();
    final assertion = expectLater(
      opening,
      throwsA(isA<ChatConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await transport.dispose();
    gate.connectWait!.complete();
    await assertion;
    await Future<void>.delayed(Duration.zero);
    expect(openings, 0);
    expect(gate.cancelled, 1);
  });

  test('宿主拒绝连接时零socket；异步命令预检取消后零发送', () async {
    final gate = _ResourceGate();
    var connections = 0;
    final socket = _FakeSocket();
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => ChatAccessFixture(
        realtimeUrl: _access().realtimeUrl,
        accessToken: 'signed-token',
        expiresAtMillis: _access().expiresAtMillis,
        resources: gate,
      ),
      socketConnector: (_, _) async {
        connections++;
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    gate.reject = true;
    await expectLater(transport.connect(), throwsA(isA<StateError>()));
    expect(connections, 0);
    gate.reject = false;
    await transport.connect();
    expect(gate.actions, ['chat_connect', 'chat_connect']);
    gate.wait = Completer<void>();
    final command = transport.fetchMailbox();
    final assertion = expectLater(
      command,
      throwsA(isA<ChatConnectionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, isEmpty);
    await transport.dispose();
    gate.wait!.complete();
    await assertion;
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent, isEmpty);
    expect(gate.cancelled, greaterThan(0));
  });

  test('空闲26秒不发送业务Ping，连接仍可执行原邮箱命令', () async {
    final clock = FakeAsync();
    late _FakeSocket socket;
    var closed = false;
    clock.run((clock) {
      socket = _FakeSocket();
      final transport = ChatConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (_, _) async {
          scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
          return socket;
        },
      );
      var connected = false;
      transport.connect().then((_) {
        connected = true;
      });
      clock.flushMicrotasks();
      expect(connected, isTrue);
      // FakeSocket没有网络时钟；仍验证原26秒边界，不挤占30秒总期限。
      clock.elapse(const Duration(seconds: 26));
      expect(socket.sent, isEmpty);
      expect(socket.closed, isFalse);
      ({List<ChatMailboxMessage> messages, String? nextCursor})? mailbox;
      transport.fetchMailbox().then((value) {
        mailbox = value;
      });
      clock.flushMicrotasks();
      expect(socket.sent.single.whichBody(), ChatFrame_Body.syncMessages);
      socket.receive(ChatFrame()..messageBatch = MessageBatch());
      clock.flushMicrotasks();
      expect(mailbox?.messages, isEmpty);
      transport.dispose().then((_) {
        closed = true;
      });
      clock.flushMicrotasks();
    });
    // StreamController取消的系统Future在真实zone完成；只排空收尾，不推进协议时间。
    for (var turn = 0; turn < 5 && !closed; turn++) {
      await Future<void>.delayed(Duration.zero);
      clock.flushMicrotasks();
    }
    expect(closed, isTrue);
    expect(socket.closed, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('未请求的应用层Pong继续关闭连接', () async {
    final socket = _FakeSocket();
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await transport.connect();
    socket.receive(ChatFrame()..pong = Pong(sentAtMillis: Int64.ONE));
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
    expect(transport.lastRealtimeDiagnosticCode, 'realtime_pong_unmatched');
    await transport.dispose();
  });

  test('邮箱保留完整Protobuf外层，ACK按100条分批且精确匹配回执', () async {
    final socket = _FakeSocket();
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (_, _) async {
        scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
        return socket;
      },
    );
    await transport.connect();
    final pending = transport.fetchMailbox();
    await Future<void>.delayed(Duration.zero);
    expect(socket.sent.last.syncMessages.limit, 100);
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-b',
      senderDeviceId: 'device-b',
      createdAtMillis: Int64.ONE,
      deliveries: [
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-a', deviceId: 'device-a'),
          openmlsCiphertext: [1, 2, 3],
        ),
      ],
    );
    socket.receive(
      ChatFrame()..messageBatch = MessageBatch(messages: [message]),
    );
    final mailbox = await pending;
    expect(
      EncryptedMessage.fromBuffer(mailbox.messages.single.messageBytes)
          .writeToBuffer(),
      message.writeToBuffer(),
    );
    final ack = transport.acknowledgeMailbox(
      List.generate(205, (i) => 'message-$i'),
    );
    for (final count in [100, 100, 5]) {
      await Future<void>.delayed(Duration.zero);
      final ids = socket.sent.last.acknowledgeMessages.messageIds;
      expect(ids, hasLength(count));
      socket.receive(
        ChatFrame()..success = Success(kind: 'messages.acknowledged', ids: ids),
      );
    }
    await ack;
    await transport.dispose();
  });
  test('WSS negotiates chat and sends binary protobuf only', () async {
    final socket = _FakeSocket();
    late Uri connectedUri;
    late String connectedToken;
    final transport = ChatConnection(
      identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
      accessProvider: () async => _access(),
      socketConnector: (uri, token) async {
        connectedUri = uri;
        connectedToken = token;
        scheduleMicrotask(
          () => socket.receive(
            ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
          ),
        );
        return socket;
      },
    );

    await transport.connect();
    expect(
      connectedUri.toString(),
      'wss://chat.example.test/api/chat/realtime',
    );
    expect(connectedToken, 'signed-token');
    expect(socket.sent, isEmpty);
    await transport.dispose();
  });

  test(
    'protocol without request id keeps exactly one command in flight',
    () async {
      final socket = _FakeSocket();
      final transport = ChatConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (uri, token) async {
          scheduleMicrotask(
            () => socket.receive(
              ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
            ),
          );
          return socket;
        },
      );
      await transport.connect();

      final first = transport.resolveKeyPackages('user-b');
      final second = transport.resolveKeyPackages('user-c');
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, hasLength(1));
      expect(socket.sent.single.resolveKeyPackages.userId, 'user-b');

      socket.receive(ChatFrame()..keyPackageBatch = KeyPackageBatch());
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, hasLength(2));
      expect(socket.sent.last.resolveKeyPackages.userId, 'user-c');

      socket.receive(ChatFrame()..keyPackageBatch = KeyPackageBatch());
      await second;
      await transport.dispose();
    },
  );

  test(
    'message available bypasses command queue and only emits wake event',
    () async {
      final socket = _FakeSocket();
      final events = <ChatServiceEvent>[];
      final transport = ChatConnection(
        identity: const ChatDevice(userId: 'user-a', deviceId: 'device-a'),
        accessProvider: () async => _access(),
        socketConnector: (uri, token) async {
          scheduleMicrotask(
            () => socket.receive(
              ChatFrame()..ready = Ready(serverTimeMillis: Int64.ONE),
            ),
          );
          return socket;
        },
      );
      final stop = await transport.connectRealtime(
        onEvent: (event) async => events.add(event),
      );
      socket.receive(
        ChatFrame()
          ..messageAvailable = MessageAvailable(
            expiresAtMillis: Int64(2),
            message: EncryptedMessage(
              messageId: 'message-a',
              conversationId: 'conversation-a',
              senderUserId: 'peer',
              senderDeviceId: 'peer-device',
              createdAtMillis: Int64.ONE,
              deliveries: [
                EncryptedDelivery(
                  recipient: Recipient(userId: 'user-a', deviceId: 'device-a'),
                  openmlsCiphertext: [1, 2, 3],
                ),
              ],
            ),
          ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single, isA<ChatMessageAvailableEvent>());
      final message = (events.single as ChatMessageAvailableEvent).message;
      expect(message.messageId, 'message-a');
      expect(
        EncryptedMessage.fromBuffer(message.messageBytes).openmlsCiphertext,
        [1, 2, 3],
      );
      expect(socket.sent.where((sent) => sent.hasSyncMessages()), isEmpty);
      await stop();
      await transport.dispose();
    },
  );

  for (final wrongDevice in [false, true]) {
    test('邮箱实际拒绝错误${wrongDevice ? '设备' : '用户'}且不交付密文', () async {
      final socket = _FakeSocket();
      final transport = ChatConnection(
        identity: const ChatDevice(userId: 'local', deviceId: 'device'),
        accessProvider: () async => _access(),
        socketConnector: (_, _) async {
          scheduleMicrotask(() => socket.receive(ChatFrame()..ready = Ready()));
          return socket;
        },
      );
      final pending = transport.fetchMailbox();
      final assertion = expectLater(
        pending,
        throwsA(
          isA<ChatConnectionException>().having(
            (error) => error.code,
            'code',
            'mailbox_identity_invalid',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      socket.receive(
        ChatFrame()
          ..messageBatch = MessageBatch(
            messages: [
              EncryptedMessage(
                messageId: 'message',
                conversationId: 'conversation',
                senderUserId: 'peer',
                senderDeviceId: 'peer-device',
                createdAtMillis: Int64.ONE,
                deliveries: [
                  EncryptedDelivery(
                    recipient: Recipient(
                      userId: wrongDevice ? 'local' : 'other',
                      deviceId: wrongDevice ? 'other' : 'device',
                    ),
                    openmlsCiphertext: [1, 2, 3],
                  ),
                ],
              ),
            ],
          ),
      );
      await assertion;
      await transport.dispose();
    });
  }
}

// 只替代HTTP边界；异常由Dart系统WebSocket真实握手检查产生。
final class _HandshakeHttpClient implements HttpClient {
  _HandshakeHttpClient(int status) : request = _HandshakeRequest(status);
  final _HandshakeRequest request;
  int requests = 0;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    expect(method, 'GET');
    expect(url.scheme, 'https');
    requests++;
    return request;
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _HandshakeRequest implements HttpClientRequest {
  _HandshakeRequest(int status) : response = _HandshakeResponse(status);
  final _HandshakeResponse response;
  @override
  bool followRedirects = true;
  @override
  final HttpHeaders headers = _HandshakeHeaders();
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _HandshakeResponse implements HttpClientResponse {
  _HandshakeResponse(this.statusCode);
  @override
  final int statusCode;
  final socket = _RejectedSocket();
  @override
  final HttpHeaders headers = _HandshakeHeaders();
  @override
  Future<Socket> detachSocket() async => socket;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _HandshakeHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RejectedSocket implements Socket {
  bool destroyed = false;
  @override
  void destroy() {
    destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ResourceGate implements ChatResourceFixture {
  bool reject = false;
  Completer<void>? wait;
  Completer<void>? connectWait;
  final actions = <String>[];
  int cancelled = 0;
  int finished = 0;
  @override
  Future<SquareResourceLease> reserve(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  }) async {
    actions.add(action);
    if (action == 'chat_connect') {
      await connectWait?.future;
    }
    if (reject) {
      throw StateError('synthetic-local-limit');
    }
    if (action == 'chat_command') {
      expect(frame, isNotEmpty);
      await wait?.future;
    }
    return _ResourceLease(() => cancelled++, () => finished++);
  }
}

final class _ResourceLease implements SquareResourceLease {
  _ResourceLease(this.onCancel, this.onFinish);
  final void Function() onCancel;
  final void Function() onFinish;
  @override
  void sent() {}
  @override
  void finish({
    ResourceUsage? receipt,
    Map<String, String>? headers,
    bool accepted = true,
    bool uncertain = false,
  }) {
    onFinish();
  }

  @override
  void cancel() => onCancel();
}

void main() {
  group(
    "transport/chat_connection_lifecycle_test",
    _registerChatConnectionLifecycle,
  );
  group("transport/chat_server_connection_test", _registerChatServerConnection);
}
