// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:convert';

import 'package:chat/message/codec.dart';
import 'package:chat/message/content.dart';
import 'package:chat/mls/store.dart';
import 'package:chat/models.dart';
import 'package:citizen_network/content.dart' as protocol;
import 'package:flutter_test/flutter_test.dart';

// 验证媒体描述的精确大小、设备成员和规范线格式边界。

void _registerMediaContent() {
  final sender = 'CID-A:${'11' * 32}';
  final receiver = 'CID-B:${'22' * 32}';

  // 所有协议边界使用合成公开描述；不生成应用钥或读取设备秘密。
  MediaContent content({
    MediaContentKind kind = MediaContentKind.file,
    int byteSize = 1024,
    int? cipherByteSize,
    String attachmentId = 'attachment-1',
    String? groupId,
    List<int> welcome = const [1, 2, 3],
    List<String>? members,
    String? senderIdentity,
    int? chunkCount,
    int epoch = 1,
    List<int>? plainHash,
    List<int>? cipherHash,
  }) => MediaContent(
    kind: kind,
    attachmentId: attachmentId,
    fileName: kind == MediaContentKind.video ? 'clip.mp4' : 'document.bin',
    mime: kind == MediaContentKind.video
        ? 'video/mp4'
        : 'application/octet-stream',
    byteSize: byteSize,
    durationMs: kind == MediaContentKind.video ? 3000 : null,
    attachmentChatEpoch: epoch,
    attachmentGroupId:
        groupId ?? 'attachment:${senderIdentity ?? sender}:$attachmentId',
    attachmentWelcome: welcome,
    attachmentMemberIdentities: members ?? [sender, receiver],
    senderIdentity: senderIdentity ?? sender,
    attachmentChunkCount:
        chunkCount ?? (byteSize + 1024 * 1024 - 1) ~/ (1024 * 1024),
    plainSha256: plainHash ?? List<int>.filled(32, 7),
    cipherByteSize: cipherByteSize ?? byteSize + 36,
    cipherSha256: cipherHash ?? List<int>.filled(32, 9),
  );

  test('唯一公开入口保留媒体入站类型和原内容合同', () {
    final incoming = DirectAttachmentInbound(
      conversationId: 'conversation-a',
      content: content(),
    );
    final decoded = MediaContentCodec.decode(
      MediaContentCodec.encode(incoming.content),
    );
    expect(incoming.conversationId, 'conversation-a');
    expect(decoded.attachmentId, incoming.content.attachmentId);
    expect(
      decoded.attachmentMemberIdentities,
      incoming.content.attachmentMemberIdentities,
    );
  });

  test('媒体合同保留超过四GiB的准确大小及MLS公开描述', () {
    const clearSize = 5 * 1024 * 1024 * 1024;
    final decoded = MediaContentCodec.decode(
      MediaContentCodec.encode(
        content(byteSize: clearSize, cipherByteSize: clearSize + 81920),
      ),
    );
    expect(decoded.byteSize, clearSize);
    expect(decoded.cipherByteSize, clearSize + 81920);
    expect(decoded.attachmentWelcome, [1, 2, 3]);
    expect(decoded.attachmentMemberIdentities, [sender, receiver]);
    expect(decoded.senderIdentity, sender);
    expect(decoded.plainSha256, List<int>.filled(32, 7));
  });

  test('未知外层字段、已禁用数字tag及非规范编码全部拒绝', () {
    final valid = MediaContentCodec.encode(content());
    expect(
      () => MediaContentCodec.decode([...valid, 0xa0, 0x01, 0x01]),
      throwsFormatException,
    );
    final unknown = protocol.MediaPayload.fromBuffer(valid);
    unknown.file.mergeFromBuffer([0x4a, 0x01, 0x00]);
    expect(
      () => MediaContentCodec.decode(unknown.writeToBuffer()),
      throwsFormatException,
    );
    // 外层file字段号18的冗长varint编码具有相同语义，仍不允许第二种线格式。
    expect(
      () => MediaContentCodec.decode([0x92, 0x81, 0x00, ...valid.sublist(2)]),
      throwsFormatException,
    );
  });

  test('Welcome、块数、epoch和开销上下界', () {
    final atLimit = content(
      welcome: List<int>.filled(48 * 1024, 1),
      epoch: 9007199254740991,
      cipherByteSize: 1024 + 4096,
    );
    expect(
      MediaContentCodec.decode(MediaContentCodec.encode(atLimit))
          .attachmentWelcome
          .length,
      48 * 1024,
    );
    for (final invalid in [
      content(welcome: []),
      content(welcome: List<int>.filled(48 * 1024 + 1, 1)),
      content(welcome: [256]),
      content(plainHash: List<int>.filled(31, 1)),
      content(cipherHash: List<int>.filled(32, -1)),
      content(byteSize: 0),
      content(cipherByteSize: 1024),
      content(cipherByteSize: 1024 + 4097),
      content(chunkCount: 0),
      content(chunkCount: 2),
      content(byteSize: 0x100000000 * 1024 * 1024, chunkCount: 0x100000000),
      content(epoch: -1),
      content(epoch: 9007199254740992),
    ]) {
      expect(() => MediaContentCodec.encode(invalid), throwsFormatException);
    }
  });

  test('组、实际发送设备和闭集成员不能伪造或使用另一种排序', () {
    for (final invalid in [
      content(attachmentId: ''),
      content(attachmentId: 'x' * 129),
      content(groupId: 'ordinary-chat'),
      content(members: [sender]),
      content(members: [sender, sender]),
      content(members: [receiver, sender]),
      content(members: [sender, 'CID-B:${'AA' * 32}']),
      content(senderIdentity: 'CID-C:${'33' * 32}'),
      content(
        senderIdentity: '${'x' * 256}:${'11' * 32}',
        members: ['${'x' * 256}:${'11' * 32}', 'y:${'22' * 32}'],
      ),
    ]) {
      expect(() => MediaContentCodec.encode(invalid), throwsFormatException);
    }
    final large = [
      sender,
      receiver,
      for (var i = 0; i < 1987; i++)
        'CID-C:${i.toRadixString(16).padLeft(64, '0')}',
    ]..sort();
    expect(
      () => MediaContentCodec.encode(content(members: large)),
      throwsFormatException,
    );
    large.add('CID-D:${'44' * 32}');
    large.sort();
    expect(
      () => MediaContentCodec.encode(content(members: large)),
      throwsFormatException,
    );
  });

  test('媒体展示类型约束保留', () {
    expect(
      () => MediaContentCodec.encode(content(kind: MediaContentKind.audio)),
      throwsFormatException,
    );
    expect(
      MediaContentCodec.decode(
        MediaContentCodec.encode(content(kind: MediaContentKind.video)),
      ).durationMs,
      3000,
    );
  });
}

// 验证基础内容Protobuf严格往返和同会话密码学串行执行。

void _registerMessageContentContract() {
  group('第一类消息协议', () {
    test('文字、emoji、贴纸均通过唯一 protobuf 往返', () {
      final contents = <BasicContent>[
        BasicContent.text('hello'),
        BasicContent.textInput('😀'),
        BasicContent.sticker(packId: 'fluent3d', stickerId: 'hello_1'),
      ];
      final decoded = contents
          .map(
            (content) =>
                BasicContentCodec.decode(BasicContentCodec.encode(content)),
          )
          .toList(growable: false);
      expect(decoded.map((item) => item.kind), <BasicContentKind>[
        BasicContentKind.text,
        BasicContentKind.emoji,
        BasicContentKind.sticker,
      ]);
    });

    test('未知字段、空内容和超限内容全部失败关闭', () {
      final valid = BasicContentCodec.encode(BasicContent.text('x'));
      expect(
        () => BasicContentCodec.decode(<int>[...valid, 0x20, 0x01]),
        throwsFormatException,
      );
      expect(
        () => BasicContentCodec.encode(BasicContent.text('')),
        throwsFormatException,
      );
      expect(
        () => BasicContentCodec.encode(
          BasicContent.text('x' * (BasicContentCodec.maxTextBytes + 1)),
        ),
        throwsFormatException,
      );
    });
  });

  test('同一会话严格串行，不同任务不会越过前序密码学操作', () async {
    final serial = SerialExecutor();
    final gate = Completer<void>();
    final order = <int>[];
    final first = serial.run('conversation', () async {
      order.add(1);
      await gate.future;
      order.add(2);
    });
    final second = serial.run('conversation', () async => order.add(3));
    await Future<void>.delayed(Duration.zero);
    expect(order, <int>[1]);
    gate.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(order, <int>[1, 2, 3]);
  });
}

// 验证文本、表情、贴纸及媒体载荷分派和非法描述拒绝。

void _registerPayload() {
  test('text content round-trips through the 公民聊天 codec', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.text('你好'));
    final wire = BasicContentCodec.decode(_decodeWireBytes(encoded));
    expect(wire.kind, BasicContentKind.text);
    expect(wire.value, '你好');
    final decoded = ChatPayloadCodec.decode(encoded);
    expect(decoded.kind, ChatMessageKind.text);
    expect(decoded.text, '你好');
    expect(decoded.summary, '你好');
  });

  test('pure emoji uses the dedicated 公民聊天 emoji branch', () {
    final encoded = ChatPayloadCodec.encode(ChatContent.text('😀'));
    final wire = BasicContentCodec.decode(_decodeWireBytes(encoded));
    expect(wire.kind, BasicContentKind.emoji);
    expect(ChatPayloadCodec.decode(encoded).text, '😀');
  });

  test('all four media kinds use the 公民聊天 protobuf descriptor', () {
    final cases =
        <ChatMessageKind, ({String name, String mime, int? duration})>{
          ChatMessageKind.image: (
            name: 'IMG.jpg',
            mime: 'image/jpeg',
            duration: null,
          ),
          ChatMessageKind.video: (
            name: 'clip.mp4',
            mime: 'video/mp4',
            duration: 4200,
          ),
          ChatMessageKind.file: (
            name: 'doc.pdf',
            mime: 'application/pdf',
            duration: null,
          ),
          ChatMessageKind.audio: (
            name: 'voice.m4a',
            mime: 'audio/mp4',
            duration: 12500,
          ),
        };
    for (final entry in cases.entries) {
      final visual =
          entry.key == ChatMessageKind.image ||
          entry.key == ChatMessageKind.video;
      final encoded = ChatPayloadCodec.encode(
        ChatContent.media(
          kind: entry.key,
          attachmentId: 'att-1',
          fileName: entry.value.name,
          mime: entry.value.mime,
          byteSize: 2048,
          width: visual ? 1080 : null,
          height: visual ? 1920 : null,
          durationMs: entry.value.duration,
          blurhash: visual ? 'L6Pj0' : null,

          attachmentChatEpoch: 1,
          attachmentGroupId: 'attachment:CID-A:${'11' * 32}:att-1',
          attachmentWelcome: 'AQID',
          attachmentMemberIdentities: [
            'CID-A:${'11' * 32}',
            'CID-B:${'22' * 32}',
          ],
          senderIdentity: 'CID-A:${'11' * 32}',
          attachmentChunkCount: ((2048) + 1024 * 1024 - 1) ~/ (1024 * 1024),
          plainSha256: '00' * 32,
          cipherByteSize: 2084,
          cipherSha256: '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
      final wire = MediaContentCodec.decode(_decodeWireBytes(encoded));
      expect(wire.attachmentId, 'att-1');
      final decoded = ChatPayloadCodec.decode(encoded);
      expect(decoded.kind, entry.key);
      expect(decoded.isMedia, isTrue);
      expect(decoded.fileName, entry.value.name);
      expect(decoded.mime, entry.value.mime);
      expect(decoded.byteSize, 2048);
      expect(decoded.durationMs, entry.value.duration);
      expect(decoded.cipherByteSize, 2084);
    }
  });

  test('媒体非法描述与非协议JSON拒绝', () {
    expect(
      () => ChatPayloadCodec.encode(
        ChatContent.media(
          kind: ChatMessageKind.audio,
          attachmentId: 'voice-1',
          fileName: 'voice.m4a',
          mime: 'video/mp4',
          byteSize: 1,
          durationMs: 1000,

          attachmentChatEpoch: 1,
          attachmentGroupId: 'attachment:CID-A:${'11' * 32}:voice-1',
          attachmentWelcome: 'AQID',
          attachmentMemberIdentities: [
            'CID-A:${'11' * 32}',
            'CID-B:${'22' * 32}',
          ],
          senderIdentity: 'CID-A:${'11' * 32}',
          attachmentChunkCount: ((1) + 1024 * 1024 - 1) ~/ (1024 * 1024),
          plainSha256: '00' * 32,
          cipherByteSize: 21,
          cipherSha256: '1111111111111111111111111111111111111111111111111111111111111111',
        ),
      ),
      throwsFormatException,
    );
    for (final raw in const <String>[
      '',
      'not json {{{',
      '{"kind":"text","text":"x"}',
      '{"kind":"image","attachment_id":"a"}',
    ]) {
      expect(() => ChatPayloadCodec.decode(raw), throwsFormatException);
    }
  });

  test('sticker carries only ids and JSON-looking text remains text', () {
    final sticker = ChatPayloadCodec.decode(
      ChatPayloadCodec.encode(
        ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face'),
      ),
    );
    expect(sticker.kind, ChatMessageKind.sticker);
    expect(sticker.packId, 'fluent3d');
    expect(sticker.stickerId, 'grinning_face');
    expect(sticker.summary, '[贴纸]');
    expect(sticker.isMedia, isFalse);

    const jsonyText = '{"type":"unknown_chat_attachment","file_name":"x"}';
    final text = ChatPayloadCodec.decode(
      ChatPayloadCodec.encode(ChatContent.text(jsonyText)),
    );
    expect(text.kind, ChatMessageKind.text);
    expect(text.text, jsonyText);
  });

  test('media summaries are typed placeholders', () {
    String summaryOf(ChatContent content) =>
        ChatPayloadCodec.decode(ChatPayloadCodec.encode(content)).summary;
    ChatContent media(
      ChatMessageKind kind,
      String name,
      String mime, {
      int? durationMs,
    }) => ChatContent.media(
      kind: kind,
      attachmentId: 'a',
      fileName: name,
      mime: mime,
      byteSize: 1,
      durationMs: durationMs,

      attachmentChatEpoch: 1,
      attachmentGroupId: 'attachment:CID-A:${'11' * 32}:a',
      attachmentWelcome: 'AQID',
      attachmentMemberIdentities: ['CID-A:${'11' * 32}', 'CID-B:${'22' * 32}'],
      senderIdentity: 'CID-A:${'11' * 32}',
      attachmentChunkCount: ((1) + 1024 * 1024 - 1) ~/ (1024 * 1024),
      plainSha256: '00' * 32,
      cipherByteSize: 21,
      cipherSha256:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    expect(
      summaryOf(media(ChatMessageKind.image, 'p.png', 'image/png')),
      '[图片]',
    );
    expect(
      summaryOf(
        media(ChatMessageKind.video, 'v.mp4', 'video/mp4', durationMs: 1000),
      ),
      '[视频]',
    );
    expect(
      summaryOf(media(ChatMessageKind.file, 'doc.pdf', 'application/pdf')),
      '[文件] doc.pdf',
    );
    expect(
      summaryOf(
        media(ChatMessageKind.audio, 'v.m4a', 'audio/mp4', durationMs: 1000),
      ),
      '[语音]',
    );
  });
}

List<int> _decodeWireBytes(String encoded) {
  final padding = '=' * ((4 - encoded.length % 4) % 4);
  return base64Url.decode('$encoded$padding');
}

void main() {
  group("message/media_content_test", _registerMediaContent);
  group(
    "message/message_content_contract_test",
    _registerMessageContentContract,
  );
  group("message/payload_test", _registerPayload);
}
