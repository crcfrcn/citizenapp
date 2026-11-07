import 'package:chat/message/chat_message.dart';

/// App应用 conversation-list presentation snapshot.
class ChatConversationPreview {
  const ChatConversationPreview({
    required this.conversationId,
    required this.title,
    required this.peerUserId,
    required this.lastMessage,
    required this.lastUpdatedAt,
    required this.unreadCount,
    required this.deliveryState,
    this.conversationKind = 'dm',
  });

  /// 公民聊天 conversation identifier.
  final String conversationId;

  /// App应用-visible title.
  final String title;

  /// App应用 maps this user ID to 公民聊天's opaque peer user ID.
  final String peerUserId;

  /// Decrypted local summary. Plaintext never comes from the service.
  final String lastMessage;

  final DateTime lastUpdatedAt;
  final int unreadCount;
  final ChatMessageDeliveryState deliveryState;

  /// dm for direct chat, group for a private group.
  final String conversationKind;

  bool get isGroup => conversationKind == 'group';
}

/// App应用 chat-tab overview.
class ChatInboxOverview {
  const ChatInboxOverview({
    required this.userId,
    required this.pendingOutgoing,
    required this.unreadCount,
  });

  final String? userId;
  final int pendingOutgoing;
  final int unreadCount;

  static const empty = ChatInboxOverview(
    userId: null,
    pendingOutgoing: 0,
    unreadCount: 0,
  );
}

/// A decoded local-message batch plus the number of rows rejected by local
/// integrity verification.
class ChatMessageDisplayBatch {
  const ChatMessageDisplayBatch({
    required this.messages,
    required this.integrityFailureCount,
  });

  final List<ChatStoredMessage> messages;
  final int integrityFailureCount;
}

/// Deployment-neutral local chat message exposed by a storage adapter.
class ChatStoredMessage {
  const ChatStoredMessage({
    required this.messageId,
    required this.conversationId,
    required this.direction,
    required this.senderUserId,
    required this.recipientUserId,
    required this.messageKind,
    required this.deliveryState,
    required this.createdAtMillis,
    this.plaintext,
  });

  final String messageId;
  final String conversationId;
  final String direction;
  final String senderUserId;
  final String recipientUserId;
  final ChatMessageKind messageKind;
  final ChatMessageDeliveryState deliveryState;
  final int createdAtMillis;
  final String? plaintext;
}

/// One encrypted message retained by the sender until delivery succeeds.
class ChatQueuedMessage {
  const ChatQueuedMessage({
    required this.messageId,
    required this.recipientUserId,
    required this.messageBytes,
  });

  final String messageId;
  final String recipientUserId;
  final List<int> messageBytes;
}

/// A local outgoing message waiting for its encrypted message.
class ChatPendingOutgoingMessage {
  const ChatPendingOutgoingMessage({
    required this.localMessageId,
    required this.conversationId,
    required this.recipientUserId,
    required this.messageKind,
    required this.createdAtMillis,
    required this.payload,
  });

  final String localMessageId;
  final String conversationId;
  final String recipientUserId;
  final ChatMessageKind messageKind;
  final int createdAtMillis;
  final String payload;
}

/// Attachment delivery metadata retained per recipient.
class ChatPendingMedia {
  const ChatPendingMedia({
    required this.attachmentId,
    required this.recipientUserId,
    required this.conversationId,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
  });

  final String attachmentId;
  final String recipientUserId;
  final String conversationId;
  final String fileName;
  final String contentType;
  final int byteSize;
}
