import 'message/chat_message.dart';
import 'package:citizen_user/membership/subscription_service.dart';

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
