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
