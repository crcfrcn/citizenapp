import 'package:citizen_testing/membergate_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:chat/chat.dart';

const _cidNumber = 'CN220-CTZN2-100000001-2026';
const _otherCidNumber = 'CN220-CTZN2-100000002-2026';

void main() {
  const mib = 1024 * 1024;
  const policy = ChatMediaLimits();

  setUp(() {
    SubscriptionService.rememberCitizenSession(
      SquareSession(
        deviceId: "synthetic-device",
        sessionToken: "synthetic-session",
        cidNumber: _cidNumber,
        bindRev: 1,
        accountId: "synthetic-account",
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
    setChatLightData(_cidNumber, 100 * mib);
  });
  tearDown(() {
    setChatLightData(_cidNumber, null);
    SubscriptionService.nowForTesting = null;
  });

  test('会员模块唯一保存 CID 绑定的聊天附件权益', () {
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

    expect(
      SubscriptionService.chatAuthorizationResolvedFor(_cidNumber),
      isTrue,
    );
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
  });

  test('非会员保留有效公民基础聊天，附件额度为0仍禁止附件', () {
    setChatLightData(_cidNumber, 0);
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
    expect(policy.exceedsForKind(ChatMessageKind.file, 1), isTrue);
    expect(policy.exceedsForKind(ChatMessageKind.text, 1 << 40), isFalse);
  });
  test('轻节点快照失效立即收回附件提示，不创建会员HTTP请求', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    setChatLightData(_cidNumber, 100 * mib);
    setChatLightData(_cidNumber, null);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
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
