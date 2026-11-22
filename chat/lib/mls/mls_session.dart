// 表示MLS线消息和发送语义，接收类型交由OpenMLS判断。

import 'package:fixnum/fixnum.dart';
import 'package:citizen_network/protocol/message.dart';

/// 发送端已知的 MLS wire 语义；接收端由 OpenMLS 解析真实类型。
enum MlsMessageKind { welcome, commit, application, unknown }

/// 一条标准 MLS wire message。
class MlsWireMessage {
  const MlsWireMessage({
    required this.wireBytes,
    required this.conversationId,
    this.groupIdBytes = const [],
    this.senderMemberIdentity,
    this.messageKind = MlsMessageKind.unknown,
  });

  final List<int> wireBytes;
  final String conversationId;
  final List<int> groupIdBytes;
  final String? senderMemberIdentity;

  String get groupId =>
      groupIdBytes.isEmpty ? conversationId : mlsGroupId(groupIdBytes);
  final MlsMessageKind messageKind;

  String get wireHex =>
      wireBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  EncryptedMessage toEncryptedMessage({
    required String messageId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required String recipientDeviceId,
    required int createdAtMillis,
  }) {
    return EncryptedMessage(
      messageId: messageId,
      conversationId: conversationId,
      groupId: groupIdBytes,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(
            userId: recipientUserId,
            deviceId: recipientDeviceId,
          ),
          openmlsCiphertext: wireBytes,
        ),
      ],
      createdAtMillis: Int64(createdAtMillis),
    );
  }
}

String mlsGroupId(List<int> bytes) =>
    'mls:${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

List<int> mlsGroupIdBytes(String id) {
  if (!RegExp(r'^mls:[0-9a-f]{32}$').hasMatch(id)) {
    throw const FormatException('MLS组标识无效');
  }
  return [
    for (var i = 4; i < id.length; i += 2)
      int.parse(id.substring(i, i + 2), radix: 16),
  ];
}

/// 从服务端不透明消息恢复 wire bytes；消息类型必须交给 OpenMLS 判断。
MlsWireMessage mlsWireMessageFromEncryptedMessage(EncryptedMessage message) {
  return MlsWireMessage(
    wireBytes: List<int>.from(message.openmlsCiphertext),
    conversationId: message.conversationId,
    groupIdBytes: List<int>.unmodifiable(message.groupId),
    senderMemberIdentity: message.groupId.isEmpty
        ? null
        : '${message.senderUserId}:${message.senderDeviceId}',
  );
}

/// 私聊和群聊信封形状的唯一App校验；必须在进入native或业务写入前调用。
void validateChatEnvelope(EncryptedMessage message) {
  final parts = message.conversationId.split(':');
  bool cid(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(value);
  if (parts.length != 3 ||
      message.conversationId.length > 256 ||
      !cid(parts[1])) {
    throw const FormatException('聊天会话标识无效');
  }
  if (!cid(message.senderUserId) ||
      message.deliveries.isEmpty ||
      message.deliveries.any(
        (delivery) =>
            !delivery.hasRecipient() || !cid(delivery.recipient.userId),
      )) {
    throw const FormatException('聊天信封身份无效');
  }
  if (parts[0] == 'dm') {
    if (!cid(parts[2]) ||
        parts[1].compareTo(parts[2]) >= 0 ||
        message.groupId.length != 16 ||
        !parts.skip(1).contains(message.senderUserId) ||
        message.deliveries.any(
          (delivery) =>
              !delivery.hasRecipient() ||
              !parts.skip(1).contains(delivery.recipient.userId),
        )) {
      throw const FormatException('私聊信封与双方或MLS组不一致');
    }
  } else if (parts[0] == 'grp') {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(parts[2]) ||
        message.groupId.isNotEmpty) {
      throw const FormatException('群聊信封不得携带私聊MLS组');
    }
  } else {
    throw const FormatException('聊天会话类型无效');
  }
}
