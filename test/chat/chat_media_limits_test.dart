import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/chat/chat_product_policy.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';

const _cidNumber = 'CN220-CTZN2-100000001-2026';
const _otherCidNumber = 'CN220-CTZN2-100000002-2026';

void main() {
  const mib = 1024 * 1024;
  const policy = CitizenChatMediaLimitPolicy();

  setUp(() {
    SubscriptionService.rememberCitizenSession(
      SquareSession(
        deviceId: "synthetic-device",
        sessionToken: "synthetic-session",
        cidNumber: _cidNumber,
        bindingRevision: 1,
        accountId: "synthetic-account",
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
    SubscriptionService.setChatAuthorizationForTesting(_cidNumber, 100 * mib);
  });
  tearDown(() {
    SubscriptionService.setChatAuthorizationForTesting(_cidNumber, null);
    SubscriptionService.nowForTesting = null;
  });

  test('会员模块唯一保存 CID 绑定的聊天附件权益', () {
    expect(SubscriptionService.membershipResolvedFor(_cidNumber), isTrue);
    expect(
      SubscriptionService.chatAuthorizationResolvedFor(_cidNumber),
      isTrue,
    );
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 100 * mib);
    expect(SubscriptionService.chatAuthorizedFor(_otherCidNumber), isFalse);
  });

  test('附件授权失败不关闭基础聊天，也不抹掉已确认会员展示事实', () {
    SubscriptionService.markAttachmentAuthorizationUnavailable(_cidNumber);

    expect(SubscriptionService.membershipResolvedFor(_cidNumber), isTrue);
    expect(
      SubscriptionService.chatAuthorizationResolvedFor(_cidNumber),
      isTrue,
    );
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
  });

  test('非会员保留有效公民基础聊天，附件额度为0仍禁止附件', () {
    SubscriptionService.setChatAuthorizationForTesting(_cidNumber, 0);
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
    expect(policy.exceedsForKind(ChatMessageKind.file, 1), isTrue);
    expect(policy.exceedsForKind(ChatMessageKind.text, 1 << 40), isFalse);
  });
  test('唯一缓存60秒到期立即收回附件，展示事实和基础会话不被会员查询替代', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    SubscriptionService.setChatAuthorizationForTesting(_cidNumber, 100 * mib);
    SubscriptionService.nowForTesting = () => now + 60000;
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
    expect(SubscriptionService.membershipResolvedFor(_cidNumber), isTrue);
    expect(policy.exceedsForKind(ChatMessageKind.file, 1), isTrue);
  });

  test('聊天模块的媒体策略无状态读取会员模块当前上限', () {
    expect(policy.limitForKind(ChatMessageKind.image), 100 * mib);
    expect(policy.limitForKind(ChatMessageKind.video), 100 * mib);
    expect(policy.limitForKind(ChatMessageKind.file), 100 * mib);
    expect(policy.limitForKind(ChatMessageKind.audio), 100 * mib);
    expect(policy.limitForKind(ChatMessageKind.text), 0);
    expect(policy.limitForKind(ChatMessageKind.sticker), 0);
    expect(policy.limitForMime('image/png'), 100 * mib);
  });

  test('媒体精确边界由无状态策略执行，文字和贴纸不携带媒体字节', () {
    expect(policy.exceedsForKind(ChatMessageKind.image, 100 * mib), isFalse);
    expect(policy.exceedsForKind(ChatMessageKind.image, 100 * mib + 1), isTrue);
    expect(policy.exceedsForKind(ChatMessageKind.text, 1 << 40), isFalse);
    expect(policy.exceedsForKind(ChatMessageKind.sticker, 1 << 40), isFalse);
  });
}
