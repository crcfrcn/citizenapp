import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/chat/chat_product_configuration.dart';
import 'package:citizenapp/chat/chat_product_policy.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/system/notifications/app_push_service.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';

/// Maps CitizenServe's product error contract without leaking it into TataChatSDK.
String chatUserErrorMessage(
  Object error, {
  String fallback = '聊天暂时无法使用，请稍后重试',
}) {
  if (error is SquarePreflightException) {
    return error.message;
  }
  if (error is SquareApiException) {
    return switch (error.errorCode) {
      'cid_not_bound' => '公民身份同步失败，请重试',
      'identity_unregistered' => '当前默认账户尚未注册公民号，无法使用聊天',
      'registration_required' => '公民服务准备未完成，请重试',
      'device_not_registered' ||
      'chat_device_not_registered' ||
      'invalid_mls_signature' ||
      'invalid_mls_proof' => '聊天设备身份尚未就绪，请重试',
      'cid_binding_changed' => '当前登录用户已切换，请重新进入聊天',
      'missing_session' ||
      'invalid_session' ||
      'session_expired' => '聊天会话已失效，请重试',
      'attachment_membergate_required' => '非会员禁止使用聊天附件',
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
final class CitizenChatRuntimeHost
    implements sdk.ChatRuntimeHost, sdk.ChatAttachmentAuthorizationHost {
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
  Future<bool> canSend(String userId) async {
    final session = await squareSessionProvider.ensureSession();
    if (session == null || session.cidNumber != userId) return false;
    SubscriptionService.rememberCitizenSession(session);
    return SubscriptionService.chatAuthorizedFor(userId);
  }

  @override
  Future<bool> prepareAttachment(
    sdk.ChatRuntimeAccount account, {
    required bool allowRefresh,
    String? expectedDeviceId,
  }) async {
    if (!allowRefresh) {
      return SubscriptionService.cachedAttachmentAuthorized(
        cidNumber: account.userId,
        accountId: account.accountId,
        bindRev: account.bindingRevision,
        expectedDeviceId: expectedDeviceId,
      );
    }
    final session = await squareSessionProvider.ensureSession();
    if (session == null ||
        session.cidNumber != account.userId ||
        session.accountId != account.accountId ||
        session.bindRev != account.bindingRevision ||
        (expectedDeviceId != null && session.deviceId != expectedDeviceId)) {
      throw const SquareApiException(
        '附件会话与当前账户或设备不一致',
        statusCode: 401,
        errorCode: 'invalid_session',
      );
    }
    await session.validateCurrent();
    await SubscriptionService.prepareAttachment(session);
    await session.validateCurrent();
    return true;
  }

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
      bindingRevision: binding.bindRev,
      accountId: binding.accountId,
      displayName: defaultAccount.name,
    );
  }

  @override
  Future<sdk.ChatAccess> requestChatAccess({
    required sdk.ChatRuntimeAccount account,
    required sdk.ChatDevice identity,
  }) async {
    if (identity.userId != account.userId) {
      throw StateError('聊天设备与当前用户不一致');
    }
    final response = await squareSessionProvider.requestChatAccess(
      deviceId: identity.deviceId,
      expectedCidNumber: account.userId,
      expectedBindingRevision: account.bindingRevision,
      expectedAccountId: account.accountId,
    );
    final access = sdk.ChatAccess(
      realtimeUrl: response.realtimeUrl,
      accessToken: response.accessToken,
      expiresAtMillis: response.expiresAt,
      resources: _CitizenChatResources(
        squareSessionProvider,
        account,
        identity.deviceId,
        response.realtimeUrl,
      ),
    );
    access.validate(DateTime.now().millisecondsSinceEpoch);
    return access;
  }

  @override
  Future<void> invalidateAccount(String accountId) async {
    SubscriptionService.invalidateCitizenAccount(accountId);
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

/// 同一App预检的中性SDK适配；不在聊天产品层复制会员额度或另存用量。
final class _CitizenChatResources implements sdk.ChatResourceGate {
  _CitizenChatResources(this.sessions, this.account, this.device, this.url);
  final SquareSessionProvider sessions;
  final sdk.ChatRuntimeAccount account;
  final String device;
  final Uri url;
  final _knownAttachments = <String, bool>{};
  @override
  Future<sdk.ChatResourceLease> reserve(
    String action, {
    List<int> frame = const [],
    int bytes = 0,
  }) async {
    final session = await sessions.ensureSession();
    if (session == null ||
        session.accountId != account.accountId ||
        session.cidNumber != account.userId ||
        session.bindRev != account.bindingRevision ||
        session.deviceId != device) {
      throw const SquarePreflightException('聊天用户已变化', 'identity_changed');
    }
    await session.validateCurrent();
    final input = <String, int>{
      'bytes': bytes,
      'frame_bytes': frame.length,
      'begin_attachment': 0,
    };
    final costs = <String, int>{};
    var operation = 'chat';
    final control = frame.isEmpty ? null : sdk.ChatFrame.fromBuffer(frame);
    if (control != null) {
      final value = control;
      // 明文单文件限制已由SDK注入的mediaLimits在加密前检查，不能用明文上限再拒绝合法MLS密文。
      input['begin_attachment'] = value.hasBeginAttachment() ? 1 : 0;
      costs.addAll({'device_frames': 1, 'device_frame_bytes': frame.length});
      if (value.hasBeginAttachment() || value.hasCompleteAttachment()) {
        operation = 'attachment';
      }
      if (value.hasBeginAttachment() &&
          _knownAttachments[value.beginAttachment.attachment.attachmentId] ==
              false) {
        final meta = value.beginAttachment.attachment;
        costs.addAll({'attachment_bytes': meta.cipherByteSize.toInt()});
      }
    }
    if (action.startsWith('attachment_')) {
      operation = 'attachment';
    }
    final lease = await SubscriptionService.resourceGate.reserve(
      origin: url.replace(scheme: 'https').origin,
      session: session,
      operation: operation,
      operationId: control?.hasBeginAttachment() == true
          ? crypto.sha256
                .convert(control!.beginAttachment.attachment.writeToBuffer())
                .toString()
          : null,
      costs: costs,
      actions: {action: input},
    );
    final stockChanged =
        control != null &&
        (control.hasCompleteAttachment() ||
            control.hasAcknowledgeAttachment() ||
            control.hasAbortAttachment());
    return _CitizenChatResourceLease(
      lease,
      onResult: (accepted, errorCode) {
        if (control?.hasCompleteAttachment() == true) {
          if (accepted) {
            _knownAttachments[control!.completeAttachment.attachmentId] = true;
          } else if (errorCode == 'not_found') {
            _knownAttachments[control!.completeAttachment.attachmentId] = false;
          } // 未完成或未知不抹掉已确认存在的附件；只有not_found证明不存在。
        }
        if (control?.hasBeginAttachment() == true && accepted) {
          _knownAttachments[control!.beginAttachment.attachment.attachmentId] =
              true;
        }
        if (accepted && stockChanged) {
          SubscriptionService.invalidateBusinessMembership(session.cidNumber);
        }
      },
    );
  }
}

final class _CitizenChatResourceLease implements sdk.ChatResourceLease {
  _CitizenChatResourceLease(this.lease, {this.onResult});
  final SquareResourceLease lease;
  final void Function(bool, String?)? onResult;
  @override
  void sent() => lease.sent();
  @override
  void cancel() => lease.cancel();
  @override
  void finish({
    sdk.ResourceUsage? receipt,
    Map<String, String>? headers,
    bool accepted = true,
    String? errorCode,
  }) {
    onResult?.call(accepted, errorCode);
    lease.finish(
      headers: headers,
      accepted: accepted,
      uncertain:
          !accepted &&
          (errorCode == 'storage_unavailable' || errorCode == 'server_failure'),
      receipt: receipt,
    );
  }
}
