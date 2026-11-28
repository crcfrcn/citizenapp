// 严格编解码聊天基础内容与MLS媒体描述。

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_network/content.dart' as protocol;
import 'package:citizen_network/content.dart' as wire;
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';

// 严格编解码私聊和群聊共用的基础文本、表情及贴纸内容。

/// 第一类消息的闭集，媒体、通话和扩展消息不得进入该结构。
enum BasicContentKind { text, emoji, sticker }

/// 私聊和群聊共用的第一类消息内容模型。
final class BasicContent {
  const BasicContent._({
    required this.kind,
    this.value,
    this.packId,
    this.stickerId,
  });

  factory BasicContent.text(String value) =>
      BasicContent._(kind: BasicContentKind.text, value: value);

  factory BasicContent.emoji(String value) =>
      BasicContent._(kind: BasicContentKind.emoji, value: value);

  /// 输入框中的纯 emoji 自动进入 emoji 分支，其余内容进入文本分支。
  factory BasicContent.textInput(String value) =>
      isEmojiOnly(value) ? BasicContent.emoji(value) : BasicContent.text(value);

  factory BasicContent.sticker({
    required String packId,
    required String stickerId,
  }) => BasicContent._(
    kind: BasicContentKind.sticker,
    packId: packId,
    stickerId: stickerId,
  );

  final BasicContentKind kind;
  final String? value;
  final String? packId;
  final String? stickerId;

  static bool isEmojiOnly(String value) {
    if (value.isEmpty) return false;
    final runes = value.runes.toList(growable: false);
    final hasKeycap = runes.contains(0x20e3);
    var hasEmoji = false;
    for (final rune in runes) {
      if (rune == 0x200d ||
          rune == 0xfe0f ||
          rune == 0x20e3 ||
          (rune >= 0x1f3fb && rune <= 0x1f3ff)) {
        continue;
      }
      if (hasKeycap &&
          (rune == 0x23 || rune == 0x2a || (rune >= 0x30 && rune <= 0x39))) {
        hasEmoji = true;
        continue;
      }
      final emoji =
          (rune >= 0x1f000 && rune <= 0x1faff) ||
          (rune >= 0x2600 && rune <= 0x27ff) ||
          (rune >= 0x2300 && rune <= 0x23ff) ||
          rune == 0x00a9 ||
          rune == 0x00ae ||
          rune == 0x2122 ||
          rune == 0x3030 ||
          rune == 0x303d ||
          rune == 0x3297 ||
          rune == 0x3299;
      if (!emoji) return false;
      hasEmoji = true;
    }
    return hasEmoji;
  }
}

/// 第一类消息唯一 protobuf 编解码器，所有非法结构均失败关闭。
final class BasicContentCodec {
  BasicContentCodec._();

  static const int maxTextBytes = 16 * 1024;
  static const int maxEmojiBytes = 256;
  static const int maxPayloadBytes = 64 * 1024;
  static final RegExp _stickerId = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  static Uint8List encode(BasicContent content) {
    _validate(content);
    final payload = switch (content.kind) {
      BasicContentKind.text => wire.BasicPayload(
        text: wire.TextContent(value: content.value),
      ),
      BasicContentKind.emoji => wire.BasicPayload(
        emoji: wire.EmojiContent(value: content.value),
      ),
      BasicContentKind.sticker => wire.BasicPayload(
        sticker: wire.StickerContent(
          packId: content.packId,
          stickerId: content.stickerId,
        ),
      ),
    };
    final encoded = Uint8List.fromList(payload.writeToBuffer());
    if (encoded.length > maxPayloadBytes) {
      throw const FormatException('第一类消息超过最大载荷');
    }
    return encoded;
  }

  static BasicContent decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxPayloadBytes) {
      throw const FormatException('第一类消息载荷大小不合法');
    }
    late final wire.BasicPayload payload;
    try {
      payload = wire.BasicPayload.fromBuffer(bytes);
    } on Object {
      throw const FormatException('第一类消息不是合法 protobuf');
    }
    if (payload.unknownFields.isNotEmpty) {
      throw const FormatException('第一类消息包含未知字段');
    }
    final content = switch (payload.whichContent()) {
      wire.BasicPayload_Content.text => _decodeText(payload.text),
      wire.BasicPayload_Content.emoji => _decodeEmoji(payload.emoji),
      wire.BasicPayload_Content.sticker => _decodeSticker(payload.sticker),
      wire.BasicPayload_Content.notSet => throw const FormatException(
        '第一类消息内容类型缺失',
      ),
    };
    _validate(content);
    return content;
  }

  static BasicContent _decodeText(wire.TextContent value) {
    _rejectUnknown(value);
    return BasicContent.text(value.value);
  }

  static BasicContent _decodeEmoji(wire.EmojiContent value) {
    _rejectUnknown(value);
    return BasicContent.emoji(value.value);
  }

  static BasicContent _decodeSticker(wire.StickerContent value) {
    _rejectUnknown(value);
    return BasicContent.sticker(
      packId: value.packId,
      stickerId: value.stickerId,
    );
  }

  static void _rejectUnknown(GeneratedMessage message) {
    if (message.unknownFields.isNotEmpty) {
      throw const FormatException('第一类消息子结构包含未知字段');
    }
  }

  static void _validate(BasicContent content) {
    switch (content.kind) {
      case BasicContentKind.text:
        final value = content.value ?? '';
        final length = utf8.encode(value).length;
        if (length == 0 || length > maxTextBytes) {
          throw const FormatException('文本消息大小不合法');
        }
      case BasicContentKind.emoji:
        final value = content.value ?? '';
        final length = utf8.encode(value).length;
        if (length == 0 ||
            length > maxEmojiBytes ||
            !BasicContent.isEmojiOnly(value)) {
          throw const FormatException('emoji 消息内容不合法');
        }
      case BasicContentKind.sticker:
        if (!_stickerId.hasMatch(content.packId ?? '') ||
            !_stickerId.hasMatch(content.stickerId ?? '')) {
          throw const FormatException('贴纸标识不合法');
        }
    }
  }
}

/// 已完成端到端解密与严格协议校验的私聊第一类消息。
final class DirectMessageInbound {
  const DirectMessageInbound({
    required this.conversationId,
    required this.content,
  });

  final String conversationId;
  final BasicContent content;
}

// 严格编解码MLS媒体附件描述并校验文件组和实际收件设备。

enum MediaContentKind { image, video, file, audio }

/// 普通MLS消息内的唯一附件描述；文件组与实际设备叶子均须严格核验。
/// App保留选择、压缩和展示策略，聊天包拥有 MLS 线格式及体积界限。
final class MediaContent {
  factory MediaContent({
    required MediaContentKind kind,
    required String attachmentId,
    required String fileName,
    required String mime,
    required int byteSize,
    required int attachmentChatEpoch,
    required String attachmentGroupId,
    required List<int> attachmentWelcome,
    required List<String> attachmentMemberIdentities,
    required String senderIdentity,
    required int attachmentChunkCount,
    required List<int> plainSha256,
    required int cipherByteSize,
    required List<int> cipherSha256,
    int? width,
    int? height,
    int? durationMs,
    String? blurhash,
  }) => MediaContent._(
    kind: kind,
    attachmentId: attachmentId,
    fileName: fileName,
    mime: mime,
    byteSize: byteSize,
    attachmentChatEpoch: attachmentChatEpoch,
    attachmentGroupId: attachmentGroupId,
    attachmentWelcome: List<int>.unmodifiable(attachmentWelcome),
    attachmentMemberIdentities: List<String>.unmodifiable(
      attachmentMemberIdentities,
    ),
    senderIdentity: senderIdentity,
    attachmentChunkCount: attachmentChunkCount,
    plainSha256: List<int>.unmodifiable(plainSha256),
    cipherByteSize: cipherByteSize,
    cipherSha256: List<int>.unmodifiable(cipherSha256),
    width: width,
    height: height,
    durationMs: durationMs,
    blurhash: blurhash,
  );

  const MediaContent._({
    required this.kind,
    required this.attachmentId,
    required this.fileName,
    required this.mime,
    required this.byteSize,
    required this.attachmentChatEpoch,
    required this.attachmentGroupId,
    required this.attachmentWelcome,
    required this.attachmentMemberIdentities,
    required this.senderIdentity,
    required this.attachmentChunkCount,
    required this.plainSha256,
    required this.cipherByteSize,
    required this.cipherSha256,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.blurhash,
  });

  final MediaContentKind kind;
  final String attachmentId;
  final String fileName;
  final String mime;
  final int byteSize;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurhash;
  final int attachmentChatEpoch;
  final String attachmentGroupId;
  final List<int> attachmentWelcome;
  final List<String> attachmentMemberIdentities;
  final String senderIdentity;
  final int attachmentChunkCount;
  final List<int> plainSha256;
  final int cipherByteSize;
  final List<int> cipherSha256;
}

final class MediaContentCodec {
  const MediaContentCodec._();

  static const int maxWireBytes = 64 * 1024;
  static const int _maxUint32 = 0xffffffff;
  static final RegExp _attachmentId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _mime = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$',
  );

  static List<int> encode(MediaContent content) {
    _validate(content);
    final descriptor = protocol.MediaDescriptor()
      ..attachmentId = content.attachmentId
      ..fileName = content.fileName
      ..mime = content.mime
      ..byteSize = Int64(content.byteSize)
      ..attachmentChatEpoch = Int64(content.attachmentChatEpoch)
      ..attachmentGroupId = content.attachmentGroupId
      ..attachmentWelcome = content.attachmentWelcome
      ..attachmentMemberIdentities.addAll(content.attachmentMemberIdentities)
      ..senderIdentity = content.senderIdentity
      ..attachmentChunkCount = content.attachmentChunkCount
      ..plainSha256 = content.plainSha256
      ..cipherByteSize = Int64(content.cipherByteSize)
      ..cipherSha256 = content.cipherSha256;
    if (content.width case final value?) descriptor.width = value;
    if (content.height case final value?) descriptor.height = value;
    if (content.durationMs case final value?) descriptor.durationMs = value;
    if (content.blurhash case final value?) descriptor.blurhash = value;

    final payload = protocol.MediaPayload();
    switch (content.kind) {
      case MediaContentKind.image:
        payload.image = descriptor;
      case MediaContentKind.video:
        payload.video = descriptor;
      case MediaContentKind.file:
        payload.file = descriptor;
      case MediaContentKind.audio:
        payload.audio = descriptor;
    }
    final bytes = payload.writeToBuffer();
    if (bytes.length > maxWireBytes) {
      throw const FormatException('media payload exceeds the wire limit');
    }
    return bytes;
  }

  static MediaContent decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxWireBytes) {
      throw const FormatException('invalid media payload size');
    }
    late final protocol.MediaPayload payload;
    try {
      payload = protocol.MediaPayload.fromBuffer(bytes);
    } on Object {
      throw const FormatException('invalid media payload');
    }
    if (payload.unknownFields.isNotEmpty ||
        !_sameBytes(bytes, payload.writeToBuffer())) {
      throw const FormatException('non-canonical media payload');
    }

    late final MediaContentKind kind;
    late final protocol.MediaDescriptor descriptor;
    switch (payload.whichContent()) {
      case protocol.MediaPayload_Content.image:
        kind = MediaContentKind.image;
        descriptor = payload.image;
      case protocol.MediaPayload_Content.video:
        kind = MediaContentKind.video;
        descriptor = payload.video;
      case protocol.MediaPayload_Content.file:
        kind = MediaContentKind.file;
        descriptor = payload.file;
      case protocol.MediaPayload_Content.audio:
        kind = MediaContentKind.audio;
        descriptor = payload.audio;
      case protocol.MediaPayload_Content.notSet:
        throw const FormatException('media payload has no content');
    }
    if (descriptor.unknownFields.isNotEmpty) {
      throw const FormatException('media descriptor has unknown fields');
    }
    final content = MediaContent(
      kind: kind,
      attachmentId: descriptor.attachmentId,
      fileName: descriptor.fileName,
      mime: descriptor.mime,
      byteSize: descriptor.byteSize.toInt(),
      width: descriptor.width == 0 ? null : descriptor.width,
      height: descriptor.height == 0 ? null : descriptor.height,
      durationMs: descriptor.durationMs == 0 ? null : descriptor.durationMs,
      blurhash: descriptor.blurhash.isEmpty ? null : descriptor.blurhash,
      attachmentChatEpoch: descriptor.attachmentChatEpoch.toInt(),
      attachmentGroupId: descriptor.attachmentGroupId,
      attachmentWelcome: descriptor.attachmentWelcome,
      attachmentMemberIdentities: descriptor.attachmentMemberIdentities,
      senderIdentity: descriptor.senderIdentity,
      attachmentChunkCount: descriptor.attachmentChunkCount,
      plainSha256: descriptor.plainSha256,
      cipherByteSize: descriptor.cipherByteSize.toInt(),
      cipherSha256: descriptor.cipherSha256,
    );
    _validate(content);
    return content;
  }

  static void _validate(MediaContent content) {
    if (!_attachmentId.hasMatch(content.attachmentId)) {
      throw const FormatException('invalid attachment id');
    }
    final fileNameBytes = utf8.encode(content.fileName);
    if (fileNameBytes.isEmpty ||
        fileNameBytes.length > 255 ||
        content.fileName.contains('/') ||
        content.fileName.contains('\\') ||
        content.fileName.contains('\u0000')) {
      throw const FormatException('invalid attachment file name');
    }
    if (!_mime.hasMatch(content.mime)) {
      throw const FormatException('invalid attachment MIME type');
    }
    if (content.byteSize <= 0 || content.cipherByteSize <= content.byteSize) {
      throw const FormatException('invalid attachment byte size');
    }
    final members = content.attachmentMemberIdentities;
    final sorted = [...members]..sort();
    if (content.attachmentChatEpoch < 0 ||
        content.attachmentChatEpoch > 9007199254740991 ||
        content.byteSize > 9007199254740991 ||
        content.attachmentChunkCount > _maxUint32 ||
        utf8.encode(content.attachmentGroupId).length > 320 ||
        [
          content.attachmentWelcome,
          content.plainSha256,
          content.cipherSha256,
        ].any((bytes) => bytes.any((b) => b < 0 || b > 255)) ||
        content.attachmentChunkCount !=
            (content.byteSize + 1024 * 1024 - 1) ~/ (1024 * 1024) ||
        content.cipherByteSize >
            content.byteSize + content.attachmentChunkCount * 4096 ||
        content.plainSha256.length != 32 ||
        content.cipherSha256.length != 32 ||
        content.attachmentGroupId !=
            'attachment:${content.senderIdentity}:${content.attachmentId}' ||
        content.attachmentWelcome.isEmpty ||
        content.attachmentWelcome.length > 48 * 1024 ||
        members.length < 2 ||
        members.length > 1989 ||
        members.toSet().length != members.length ||
        !members.contains(content.senderIdentity) ||
        !_sameStrings(members, sorted) ||
        members.any(
          (m) => !RegExp(r'^[^:\x00-\x20]{1,256}:[0-9a-f]{64}$').hasMatch(m),
        )) {
      throw const FormatException('附件MLS合同无效');
    }
    if ((content.width == null) != (content.height == null) ||
        (content.width != null &&
            (content.width! <= 0 || content.width! > _maxUint32)) ||
        (content.height != null &&
            (content.height! <= 0 || content.height! > _maxUint32)) ||
        (content.durationMs != null &&
            (content.durationMs! <= 0 || content.durationMs! > _maxUint32)) ||
        (content.blurhash != null &&
            (content.blurhash!.isEmpty ||
                utf8.encode(content.blurhash!).length > 512))) {
      throw const FormatException('invalid attachment presentation metadata');
    }
    switch (content.kind) {
      case MediaContentKind.image:
        if (!content.mime.startsWith('image/') || content.durationMs != null) {
          throw const FormatException('invalid image descriptor');
        }
      case MediaContentKind.video:
        if (!content.mime.startsWith('video/')) {
          throw const FormatException('invalid video descriptor');
        }
      case MediaContentKind.audio:
        if (!content.mime.startsWith('audio/') ||
            content.width != null ||
            content.blurhash != null) {
          throw const FormatException('invalid audio descriptor');
        }
      case MediaContentKind.file:
        if (content.width != null ||
            content.durationMs != null ||
            content.blurhash != null) {
          throw const FormatException('invalid file descriptor');
        }
    }
  }

  static bool _sameStrings(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// 已完成端到端解密与严格协议校验的私聊第二类媒体消息。
final class DirectAttachmentInbound {
  const DirectAttachmentInbound({
    required this.conversationId,
    required this.content,
  });

  final String conversationId;
  final MediaContent content;
}
