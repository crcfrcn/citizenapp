// 验证附件会员许可、到期及精确大小边界不影响基础聊天。

import 'package:chat/chat.dart';
import 'package:citizen_testing/membership.dart';
import 'package:citizen_user/api.dart'
    show SquareApiClient, SquareResourceAuthorization, SquareSession;
import 'package:citizen_user/identity/state.dart'
    show FinalizedIdentityResolver;
import 'package:citizen_user/membership/service.dart' show SubscriptionService;
import 'package:flutter_test/flutter_test.dart';

// 验证附件会员许可、到期及精确大小边界不影响基础聊天。

const _cidNumber = 'CN220-CTZN2-100000001-2026';
const _otherCidNumber = 'CN220-CTZN2-100000002-2026';

class _Membergate extends SquareApiClient {
  bool allowed = true;
  late int until;
  @override
  Future<SquareResourceAuthorization> fetchResourceAuthorization(
    SquareSession session,
  ) async => SquareApiClient.decodeResourceAuthorization(
    resourceAuthorizationFixture(
      allowed: allowed,
      level: 'democracy',
      validUntil: until,
    ),
  );
}

class _NoChain implements FinalizedIdentityResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('聊天附件不得查询链身份');
}

void main() {
  const mib = 1024 * 1024;
  const policy = ChatMediaLimits();

  late SquareSession session;
  late _Membergate gate;
  late SubscriptionService service;
  late int now;

  setUp(() async {
    now = DateTime.now().millisecondsSinceEpoch;
    SubscriptionService.nowForTesting = () => now;
    session = SquareSession(
      deviceId: 'synthetic-device',
      sessionToken: 'synthetic-session',
      cidNumber: _cidNumber,
      bindRev: 1,
      accountId: 'synthetic-account',
      expiresAt: now + 360000,
    );
    gate = _Membergate()..until = now + 60000;
    service = SubscriptionService(api: gate, identityResolver: _NoChain());
    await service.authorizeResources(session, forceRefresh: true);
  });
  tearDown(() {
    SubscriptionService.invalidateCitizenAccount(session.accountId);
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

  test('非会员保留有效公民基础聊天，附件额度为0仍禁止附件', () async {
    gate.allowed = false;
    await service.authorizeResources(session, forceRefresh: true);
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
    expect(SubscriptionService.chatFileMaxBytesFor(_cidNumber), 0);
    expect(policy.exceedsForKind(ChatMessageKind.file, 1), isTrue);
    expect(policy.exceedsForKind(ChatMessageKind.text, 1 << 40), isFalse);
  });
  test('会员门禁许可到期立即收回附件提示', () {
    now += 60000;
    expect(SubscriptionService.chatAuthorizedFor(_cidNumber), isTrue);
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
