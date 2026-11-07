part of '../chat.dart';

UserContactService _contactServiceFromContext(BuildContext context) =>
    _contactServiceFromContextOrNull(context) ?? (throw StateError('通讯录依赖不可用'));

UserContactService? _contactServiceFromContextOrNull(BuildContext context) {
  final accountSecurity = context.read<AccountSecurityService?>();
  final currentUserContext = context.read<CurrentUserContext?>();
  final sessionProvider = context.read<SquareSessionProvider?>();
  final runtime = context.read<CitizenSdk?>();
  if (accountSecurity == null ||
      currentUserContext == null ||
      sessionProvider == null ||
      runtime == null) {
    return null;
  }
  return context.read<UserContactService?>() ??
      UserContactService(
        accountSecurity: accountSecurity,
        currentUserContext: currentUserContext,
        sessionProvider: sessionProvider,
      );
}

/// 聊天消费门禁核实后的有/无CID事实；缓存读取失败是操作错误，不增加身份状态。
Future<({String cidNumber, String accountId})> _resolveChatIdentity(
  CurrentUserContext currentUser,
) async {
  final identity = await currentUser.resolve();
  if (identity == null) return (cidNumber: '', accountId: '');
  if (identity.isRegistered) {
    return (cidNumber: identity.cidNumber, accountId: identity.accountId);
  }
  if (identity.isUnregistered) {
    return (cidNumber: '', accountId: identity.accountId);
  }
  throw const SquareApiException(
    '身份信息暂不可用，请在身份页刷新后重试',
    errorCode: 'identity_local_missing',
    stage: SquareApiStage.identity,
  );
}

Future<({String cidNumber, String accountId})?> _readChatEntryIdentity(
  BuildContext context,
) async {
  try {
    return await _resolveChatIdentity(context.read<CurrentUserContext>());
  } on Exception catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SquareApiException &&
                    error.errorCode == 'identity_local_missing'
                ? SquareSessionResolution.fromError(error).message
                : error is AccountSecurityException
                ? error.message
                : chatUserErrorMessage(error),
          ),
        ),
      );
    }
    return null;
  }
}

/// 打开群聊详情；产品身份解析留在 CitizenApp，完整页面链路由 聊天路由组装。
Future<void> openGroupChat(
  BuildContext context, {
  required String groupId,
  required String title,
  ChatDeleteConversationCallback? onDeleteConversation,
}) async {
  final identity = await _readChatEntryIdentity(context);
  if (identity == null) return;
  final accountId = identity.accountId;
  final currentUserId = identity.cidNumber;
  if (!context.mounted) return;
  if (accountId.isEmpty || currentUserId.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accountId.isEmpty ? '请先在「我的 → 我的钱包」添加钱包账户' : '当前默认账户尚未注册 CID',
          ),
        ),
      );
    }
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChatConversationPage(
        runtime: context.read<ChatRuntime>(),
        sessionProvider: context.read<SquareSessionProvider?>(),

        currentUserId: currentUserId,
        accountId: accountId,
        conversationId: groupId,
        peerUserId: groupId,
        isGroup: true,
        title: title,
        onDeleteConversation: onDeleteConversation,
      ),
    ),
  );
}

/// 打开私聊详情；产品身份与自聊门禁留在 CitizenApp，消息链路由 聊天路由组装。
Future<void> openDirectChat(
  BuildContext context, {
  required String peerUserId,
  required String title,
}) async {
  final identity = await _readChatEntryIdentity(context);
  if (identity == null) return;
  final accountId = identity.accountId;
  final currentUserId = identity.cidNumber;
  if (!context.mounted) return;
  if (accountId.isEmpty || currentUserId.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accountId.isEmpty ? '请先添加钱包账户' : '当前默认账户尚未注册 CID'),
        ),
      );
    }
    return;
  }
  if (peerUserId.trim() == currentUserId) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能和自己发起聊天')));
    }
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChatConversationPage(
        conversationId: ChatRuntime.directConversationId(
          currentUserId,
          peerUserId,
        ),
        runtime: context.read<ChatRuntime>(),
        sessionProvider: context.read<SquareSessionProvider?>(),

        currentUserId: currentUserId,
        accountId: accountId,
        peerUserId: peerUserId,
        title: title,
      ),
    ),
  );
}
