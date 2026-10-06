import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:citizenapp/8964/profile/services/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/chat/chat_product_configuration.dart';
import 'package:citizenapp/chat/chat_product_policy.dart';
import 'package:citizenapp/my/membership/subscription_service.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/notifications/app_push_service.dart';
import 'package:citizenapp/security/account_security_service.dart';

/// Maps CitizenServe's product error contract without leaking it into TataChatSDK.
String chatUserErrorMessage(
  Object error, {
  String fallback = '聊天暂时无法使用，请稍后重试',
}) {
  if (error is SquareApiException) {
    return switch (error.errorCode) {
      'cid_not_bound' => '当前默认账户尚未注册公民号，无法使用聊天',
      'device_not_registered' ||
      'chat_device_not_registered' ||
      'invalid_mls_signature' ||
      'invalid_mls_proof' => '聊天设备身份尚未就绪，请重试',
      'cid_binding_changed' => '当前登录用户已切换，请重新进入聊天',
      'missing_session' ||
      'invalid_session' ||
      'session_expired' => '聊天会话已失效，请重试',
      'chat_membership_required' ||
      'membership_required' ||
      'chat_disabled' => '当前账户尚未开通聊天会员权益',
      'chat_server_not_configured' => '聊天服务尚未配置',
      _ =>
        error.statusCode == null || error.statusCode! >= 500
            ? '聊天服务暂时无法连接，请稍后重试'
            : fallback,
    };
  }
  return sdk.chatSdkUserErrorMessage(error, fallback: fallback);
}

/// 公民群页面只把 TataChatSDK 的中性 userId 显示为 CID；不改写协议或存储字段。
extension CitizenGroupMemberFields on sdk.GroupMember {
  String get cidNumber => userId;
}

extension CitizenChatGroupFields on sdk.ChatGroup {
  String get creatorCidNumber => creatorUserId;
  List<String> get memberCidNumbers => memberUserIds;
}

typedef ChatPushTokenProvider = Future<sdk.ChatPushToken> Function();

/// 公民聊天模块消费现有用户、会员、安全、会话与推送接口的协议适配。
///
/// CID、当前账户、会员和 CitizenServe 会话仍由各自业务模块拥有；
/// 本类型不保存或复制这些事实，只在 TataChatSDK 调用时读取并映射。
final class CitizenChatRuntimeHost implements sdk.ChatRuntimeHost {
  CitizenChatRuntimeHost({
    required this.accountSecurity,
    required this.currentUserContext,
    required this.squareSessionProvider,
    required this.pushService,
  });

  final AccountSecurityService accountSecurity;
  final CurrentUserContext currentUserContext;
  final SquareSessionProvider squareSessionProvider;
  final ChatPushService pushService;

  @override
  sdk.ChatPushBridge get push => pushService;

  @override
  sdk.ChatMediaLimitPolicy get mediaLimits =>
      const CitizenChatMediaLimitPolicy();

  @override
  Future<bool> canSend(String userId) async =>
      SubscriptionService.chatAuthorizedFor(userId);

  @override
  Future<sdk.ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async {
    final current = await currentUserContext.resolve();
    if (current == null) return null;
    final defaultAccount = current.account;
    if (expectedAccountId != null &&
        defaultAccount.accountId != expectedAccountId) {
      throw StateError('身份账户已切换，请重新进入聊天');
    }
    final binding = current.binding;
    if (binding == null) return null;
    if (binding.accountId != defaultAccount.accountId) {
      throw StateError('当前用户绑定与默认账户不一致');
    }
    return sdk.ChatRuntimeAccount(
      hostIndex: defaultAccount.walletIndex,
      bindingScope: binding.genesisHash,
      userId: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
      displayName: defaultAccount.name,
    );
  }

  @override
  Future<sdk.TataChatServerAccess> requestTataChatServerAccess({
    required sdk.ChatRuntimeAccount account,
    required sdk.ChatDevice identity,
  }) async {
    final response = await squareSessionProvider.requestChatServerAccess(
      deviceId: identity.deviceId,
      expectedCidNumber: account.userId,
      expectedBindingRevision: account.bindingRevision,
      expectedAccountId: account.accountId,
    );
    final access = sdk.TataChatServerAccess(
      tataChatServerUrl: response.chatServerUrl,
      tataChatServerToken: response.chatServerToken,
      expiresAtMillis: response.expiresAtMillis,
    );
    access.validate(DateTime.now().millisecondsSinceEpoch);
    return access;
  }

  @override
  Future<void> invalidateAccount(String accountId) async {
    squareSessionProvider.invalidateAccount(accountId);
  }
}

/// 关闭唯一实例时同步封住普通认证，随后由SDK收口其内部生命周期。
final class _CitizenChatRuntime extends sdk.ChatSdk {
  _CitizenChatRuntime({
    required super.host,
    super.store,
    super.preferences,
    super.stateStoreFactory,
    super.cryptoFactory,
    super.documentsDirectoryProvider,
    super.transportFactory,
    super.receiveOnly,
    this.onClosing,
  });
  final void Function()? onClosing;
  @override
  Future<void> stop() {
    onClosing?.call();
    return super.stop();
  }
}

/// 使用CitizenApp依赖创建同一MLS运行实例，不启动聊天同步或权益请求。
sdk.ChatSdk createCitizenChatRuntime({
  required AccountSecurityService accountSecurity,
  required CurrentUserContext currentUserContext,
  required SquareSessionProvider squareSessionProvider,
  sdk.ChatStore? store,
  SharedPreferences? preferences,
  sdk.MlsStateStoreFactory? stateStoreFactory,
  sdk.MlsGroupCrypto Function(
    sdk.ChatDevice identity,
    sdk.MlsStateStore stateStore,
  )?
  cryptoFactory,
  sdk.ChatServiceTransportFactory? transportFactory,
  ChatPushService? pushService,
  AppPushService? appPushService,
  ChatPushTokenProvider? pushTokenProvider,
  Future<Directory> Function()? documentsDirectoryProvider,
  bool receiveOnly = false,
  void Function()? onClosing,
}) => _CitizenChatRuntime(
  host: createCitizenChatRuntimeHost(
    accountSecurity: accountSecurity,
    squareSessionProvider: squareSessionProvider,
    pushService: pushService,
    appPushService: appPushService,
    pushTokenProvider: pushTokenProvider,
    currentUserContext: currentUserContext,
  ),
  store: store,
  preferences: preferences,
  stateStoreFactory: stateStoreFactory,
  cryptoFactory: cryptoFactory,
  documentsDirectoryProvider: documentsDirectoryProvider,
  transportFactory: transportFactory,
  receiveOnly: receiveOnly,
  onClosing: onClosing,
);

/// 构造 SDK 需要的 CitizenApp 产品宿主，仅供组合与测试注入。
sdk.ChatRuntimeHost createCitizenChatRuntimeHost({
  required AccountSecurityService accountSecurity,
  required CurrentUserContext currentUserContext,
  required SquareSessionProvider squareSessionProvider,
  ChatPushService? pushService,
  AppPushService? appPushService,
  ChatPushTokenProvider? pushTokenProvider,
}) {
  final push =
      pushService ??
      ChatPushService(
        appPushService: appPushService,
        tokenProvider: pushTokenProvider,
      );
  final host = CitizenChatRuntimeHost(
    accountSecurity: accountSecurity,
    currentUserContext: currentUserContext,
    squareSessionProvider: squareSessionProvider,
    pushService: push,
  );
  return host;
}
