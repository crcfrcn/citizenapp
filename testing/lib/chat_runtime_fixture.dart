import 'package:chat/chat.dart';

/// 收发算法回归的合成额度；实际会员资格继续由 App 的会员回归单独验证。
class TestChatMediaLimits extends ChatMediaLimits {
  const TestChatMediaLimits({this.maximumBytes = 0x7fffffffffffffff});
  final int maximumBytes;
  @override
  int limitForKind(ChatMessageKind kind) => maximumBytes;
  @override
  int limitForMime(String contentType) => maximumBytes;
  @override
  bool exceedsForKind(ChatMessageKind kind, int byteSize) =>
      byteSize > maximumBytes;
}

/// 合成回归的依赖替身；生产运行时直接读取 App 服务，不使用此合同。
abstract interface class ChatRuntimeFixture {
  ChatPushService get push;
  ChatMediaLimits get mediaLimits;
  Future<bool> canSend(String userId);
  Future<ChatRuntimeAccount?> currentAccount({String? expectedAccountId});
  Future<ChatAccess> requestChatAccess({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
  });
  Future<void> invalidateAccount(String accountId);
}

abstract interface class ChatAttachmentAuthorizationFixture {
  Future<bool> prepareAttachment(
    ChatRuntimeAccount account, {
    required bool allowRefresh,
    String? expectedDeviceId,
  });
}

/// 只在测试中将合成业务事实交给同一真实运行时，收发、队列和围栏仍执行生产代码。
class TestChatRuntime extends ChatRuntime {
  TestChatRuntime({
    ChatRuntimeFixture? host,
    super.store,
    super.preferences,
    super.stateStoreFactory,
    super.cryptoFactory,
    super.documentsDirectoryProvider,
    super.transportFactory,
    super.receiveOnly,
    super.debugUseIndependentUserMutationGate,
  }) : fixture = host;

  final ChatRuntimeFixture? fixture;

  @override
  ChatPushService get push => fixture?.push ?? super.push;

  @override
  ChatMediaLimits get mediaLimits => fixture?.mediaLimits ?? super.mediaLimits;

  @override
  Future<bool> canSend(String userId) => fixture!.canSend(userId);

  @override
  Future<ChatRuntimeAccount?> currentAccount({String? expectedAccountId}) =>
      fixture!.currentAccount(expectedAccountId: expectedAccountId);

  @override
  Future<ChatAccess> requestChatAccess({
    required ChatRuntimeAccount account,
    required ChatDevice identity,
  }) => fixture!.requestChatAccess(account: account, identity: identity);

  @override
  Future<void> invalidateProductAccount(String accountId) =>
      fixture!.invalidateAccount(accountId);

  @override
  Future<bool> prepareAttachment(
    ChatRuntimeAccount account, {
    required bool allowRefresh,
    String? expectedDeviceId,
  }) {
    final source = fixture;
    if (source is ChatAttachmentAuthorizationFixture) {
      return (source as ChatAttachmentAuthorizationFixture).prepareAttachment(
        account,
        allowRefresh: allowRefresh,
        expectedDeviceId: expectedDeviceId,
      );
    }
    return Future.value(true);
  }
}
