import 'package:citizen_testing/chat_access_fixture.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_network/protocol/chat_frame.pb.dart';
import 'package:chat/transport/attachment_transfer.dart';
import 'package:chat/transport/chat_connection.dart';

final class _FakeHttpAdapter implements ChatHttpAdapter {
  Uri? putUri;
  String? putToken;
  Uint8List? putBody;
  String? putHash;
  ChatHttpResponse? getResponse;
  bool disposed = false;
  int putStatus = 204;

  @override
  Future<ChatHttpResponse> putChunk({
    required Uri uri,
    required String bearerToken,
    required Uint8List body,
    required String cipherSha256,
  }) async {
    putUri = uri;
    putToken = bearerToken;
    putBody = body;
    putHash = cipherSha256;
    return ChatHttpResponse(
      statusCode: putStatus,
      headers: <String, String>{},
      body: Uint8List(0),
    );
  }

  @override
  Future<ChatHttpResponse> getChunk({
    required Uri uri,
    required String bearerToken,
    required int maximumBytes,
  }) async => getResponse!;

  @override
  Future<void> dispose() async => disposed = true;
}

ChatAccess _access() => ChatAccessFixture(
  realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
  accessToken: 'signed-token',
  expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
);

void main() {
  test('密文块在宿主预检完成前零网络，按真实密文长度计量', () async {
    final gate = _ChunkGate(), adapter = _FakeHttpAdapter();
    final access = ChatAccessFixture(
      realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
      accessToken: 'synthetic',
      expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
      resources: gate,
    );
    final transport = ChatAttachmentTransport(access: access, adapter: adapter);
    final bytes = Uint8List.fromList([1, 2, 3]);
    final work = transport.putChunk(
      attachmentId: 'attachment-a',
      chunkIndex: 0,
      bytes: bytes,
      cipherSha256: crypto.sha256.convert(bytes).toString(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(adapter.putBody, isNull);
    expect(gate.bytes, 3);
    gate.wait.complete();
    await work;
    expect(adapter.putBody, bytes);
    expect(gate.finished, 1);
    await transport.dispose();
  });

  test('附件HTTP未知失败交付宿主，明确拒绝不冒充未知扣量', () async {
    for (final status in [503, 429]) {
      final gate = _ChunkGate()..wait.complete();
      final adapter = _FakeHttpAdapter()..putStatus = status;
      final access = ChatAccessFixture(
        realtimeUrl: Uri.parse('wss://chat.example.test/api/chat/realtime'),
        accessToken: 'synthetic',
        expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
        resources: gate,
      );
      final transport = ChatAttachmentTransport(
        access: access,
        adapter: adapter,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        transport.putChunk(
          attachmentId: 'attachment-a',
          chunkIndex: 0,
          bytes: bytes,
          cipherSha256: crypto.sha256.convert(bytes).toString(),
        ),
        throwsA(isA<ChatConnectionException>()),
      );
      expect(gate.accepted, false);
      expect(gate.uncertain, status == 503);
      expect(gate.finished, 1);
      await transport.dispose();
    }
  });

  test('附件编号拒绝点、路径穿越和越界块号，同端口派生HTTPS', () async {
    final access = ChatAccessFixture(
      realtimeUrl: Uri.parse(
        'wss://chat.example.test:8443/api/chat/realtime',
      ),
      accessToken: 'signed-token',
      expiresAtMillis: DateTime.now().millisecondsSinceEpoch + 300000,
    );
    expect(
      access.attachmentChunkUrl('attachment-a', 0).toString(),
      'https://chat.example.test:8443/api/chat/attachments/attachment-a/chunks/0',
    );
    for (final id in ['..', 'attachment.a', 'a/b', 'a?token']) {
      expect(() => access.attachmentChunkUrl(id, 0), throwsArgumentError);
    }
    expect(
      () => access.attachmentChunkUrl('attachment-a', -1),
      throwsArgumentError,
    );
    expect(
      () => access.attachmentChunkUrl('attachment-a', 0x100000000),
      throwsArgumentError,
    );
  });
  test('upload verifies ciphertext before exact HTTPS chunk request', () async {
    final adapter = _FakeHttpAdapter();
    final transport = ChatAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final digest = crypto.sha256.convert(bytes).toString();

    await transport.putChunk(
      attachmentId: 'attachment-a',
      chunkIndex: 2,
      bytes: bytes,
      cipherSha256: digest,
    );
    expect(
      adapter.putUri.toString(),
      'https://chat.example.test/api/chat/attachments/attachment-a/chunks/2',
    );
    expect(adapter.putToken, 'signed-token');
    expect(adapter.putBody, bytes);
    expect(adapter.putHash, digest);
    await transport.dispose();
    expect(adapter.disposed, isTrue);
  });

  test('download verifies length, response digest and actual bytes', () async {
    final bytes = Uint8List.fromList(<int>[4, 5, 6]);
    final digest = crypto.sha256.convert(bytes).toString();
    final adapter = _FakeHttpAdapter()
      ..getResponse = ChatHttpResponse(
        statusCode: 200,
        headers: <String, String>{
          'content-length': '${bytes.length}',
          'x-chat-cipher-sha256': digest,
        },
        body: bytes,
      );
    final transport = ChatAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    expect(
      await transport.getChunk(
        attachmentId: 'attachment-a',
        chunkIndex: 0,
        expectedBytes: bytes.length,
      ),
      bytes,
    );
    await transport.dispose();
  });

  test('invalid upload digest fails before any network I/O', () async {
    final adapter = _FakeHttpAdapter();
    final transport = ChatAttachmentTransport(
      access: _access(),
      adapter: adapter,
    );
    await expectLater(
      transport.putChunk(
        attachmentId: 'attachment-a',
        chunkIndex: 0,
        bytes: Uint8List.fromList(<int>[1]),
        cipherSha256: 'invalid',
      ),
      throwsA(isA<ChatConnectionException>()),
    );
    expect(adapter.putUri, isNull);
    await transport.dispose();
  });
}

final class _ChunkGate implements ChatResourceFixture, SquareResourceLease {
  final wait = Completer<void>();
  int bytes = 0, finished = 0;
  bool? accepted;
  bool uncertain = false;
  @override
  Future<SquareResourceLease> reserve(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  }) async {
    expect(action, 'attachment_upload');
    this.bytes = bytes;
    await wait.future;
    return this;
  }

  @override
  void sent() {}
  @override
  void finish({
    ResourceUsage? receipt,
    Map<String, String>? headers,
    bool accepted = true,
    bool uncertain = false,
  }) {
    finished++;
    this.accepted = accepted;
    this.uncertain = uncertain;
  }

  @override
  void cancel() {}
}
