// 定义会话、消息及队列模型，并保留会员媒体限额适配。

library;

import 'package:citizen_user/membership/service.dart' show SubscriptionService;

// 定义本机会话、消息、队列和待处理媒体等公开运行模型。

/// App应用 conversation-list presentation snapshot.
class ChatConversationPreview {
  const ChatConversationPreview({
    required this.conversationId,
    required this.title,
    required this.peerUserId,
    required this.lastMessage,
    required this.lastUpdatedAt,
    required this.unreadCount,
    this.conversationKind = 'dm',
    this.isPinned = false,
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

  /// 当前永久身份的本机置顶状态。
  final bool isPinned;

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

// 定义共享消息种类、投递状态及媒体超限错误。

enum ChatMessageKind {
  /// Plain text or an inline emoji.
  text,

  /// An end-to-end encrypted image attachment.
  image,

  /// An end-to-end encrypted video attachment.
  video,

  /// An end-to-end encrypted generic file attachment.
  file,

  /// An end-to-end encrypted voice message.
  audio,

  /// A bundled sticker identified by pack and sticker IDs.
  sticker,
}

/// Local delivery state. It is not a read receipt.
enum ChatMessageDeliveryState {
  /// Persisted in the local outgoing queue.
  queued,

  /// Being submitted to the configured encrypted transport.
  sending,

  /// Accepted by the transport.
  sent,

  /// Confirmed by a recipient device.
  receivedByDevice,

  /// Delivery ended in failure.
  failed,
}

/// Maximum duration for one voice or video message.
const Duration chatMessageMaximumDuration = Duration(minutes: 3);

/// An attachment exceeds the byte limit supplied by the host application.
class ChatMediaTooLargeException implements Exception {
  const ChatMediaTooLargeException({
    required this.byteSize,
    required this.limitBytes,
    this.kind,
  });

  final int byteSize;
  final int limitBytes;
  final ChatMessageKind? kind;

  @override
  String toString() =>
      'attachment size $byteSize exceeds limit $limitBytes bytes';
}

/// A voice or video message exceeds [chatMessageMaximumDuration].
class ChatMediaTooLongException implements Exception {
  const ChatMediaTooLongException({
    required this.kind,
    required this.durationMs,
  });

  final ChatMessageKind kind;
  final int durationMs;

  @override
  String toString() => 'voice and video messages are limited to three minutes';
}

const Duration chatMessageRetention = Duration(days: 7);

// 将会员模块提供的真实规格适配为聊天附件限额。

/// 公民聊天模块的无状态会员适配；会员事实与附件额度唯一来自会员模块。
class ChatMediaLimits {
  const ChatMediaLimits();

  int get _limit => SubscriptionService.currentChatFileMaxBytes;

  int limitForKind(ChatMessageKind kind) => switch (kind) {
    ChatMessageKind.image ||
    ChatMessageKind.video ||
    ChatMessageKind.file ||
    ChatMessageKind.audio => _limit,
    ChatMessageKind.text || ChatMessageKind.sticker => 0,
  };

  int limitForMime(String contentType) => _limit;

  bool exceedsForKind(ChatMessageKind kind, int byteSize) {
    if (kind == ChatMessageKind.text || kind == ChatMessageKind.sticker) {
      return false;
    }
    return byteSize > _limit;
  }
}
