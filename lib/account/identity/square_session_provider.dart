import 'package:citizenapp/app_log.dart';
import 'package:citizen_sdk/citizen_sdk.dart'
    show CitizenSdkException, CitizenSdkErrorCode;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';

import 'cid_business_gate.dart';

import 'package:citizenapp/account/identity/account_security_service.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/mls_authentication.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;

/// 页面建立 CitizenServe 会话后的互斥结果。
///
/// `noWallet` 只来自本地默认账户不存在；远端投影、网络和设备认证故障必须保留自己的
/// 状态，禁止再用 nullable session 把它们伪装成“没有钱包”。
enum SquareSessionStatus {
  ready,
  noWallet,
  identityUnavailable,
  identityUnbound,
  serviceUnavailable,
  networkUnavailable,
  deviceUnavailable,
  identityChanged,
}

extension SquareSessionStatusText on SquareSessionStatus {
  String get message => switch (this) {
    SquareSessionStatus.ready => '',
    SquareSessionStatus.noWallet => '请先添加钱包账户',
    SquareSessionStatus.identityUnavailable => '身份同步中，请稍后重试',
    SquareSessionStatus.identityUnbound => '当前默认钱包账户尚未绑定 CID',
    SquareSessionStatus.serviceUnavailable => '公民服务暂时不可用，请稍后重试',
    SquareSessionStatus.networkUnavailable => '网络连接失败，请检查网络后重试',
    SquareSessionStatus.deviceUnavailable => 'MLS设备认证暂时不可用，请稍后重试',
    SquareSessionStatus.identityChanged => '当前用户已变化，请重试',
  };
}

class SquareSessionResolution {
  const SquareSessionResolution(
    this.status, {
    this.session,
    this.errorCode,
    this.statusCode,
    this.stage,
  });

  final SquareSessionStatus status;
  final SquareSession? session;

  /// 仅保留已知闭集错误码和固定阶段；原始服务消息不进入页面或持久诊断。
  final String? errorCode;
  final int? statusCode;
  final SquareApiStage? stage;

  static sdk.MlsNativeException? _mlsError(String? value) {
    for (final code in sdk.MlsNativeErrorCode.values) {
      final error = sdk.MlsNativeException(code, '');
      if (value == 'mls_${error.diagnosticCode}') return error;
    }
    return null;
  }

  String get message =>
      _mlsError(errorCode)?.userMessage ??
      switch (errorCode) {
        'identity_local_missing' => '身份信息暂不可用，请在身份页刷新后重试',
        'device_not_registered' => '公民服务准备未完成，请重试',
        'registration_required' => '公民服务准备未完成，请重试',
        'mls_challenge_limit_reached' ||
        'request_rate_exceeded' => '请求过于频繁，请稍后重试',
        'authenticationRequired' => '首次设备登记授权尚未完成',
        'authenticationCancelled' => '设备授权已取消，可再次主动发起',
        _ => status.message,
      };

  /// 页面和通讯录复用同一错误分类；无记录不等于离线，未知HTTP错误不等于设备故障。
  static SquareSessionResolution fromError(Object error) {
    if (error is sdk.MlsNativeException) {
      return SquareSessionResolution(
        error.code == sdk.MlsNativeErrorCode.stateOwnerMismatch
            ? SquareSessionStatus.identityChanged
            : SquareSessionStatus.deviceUnavailable,
        errorCode: 'mls_${error.diagnosticCode}',
        stage: SquareApiStage.identity,
      );
    }
    if (error is CitizenSdkException &&
        (error.code == CitizenSdkErrorCode.authenticationCancelled ||
            error.code == CitizenSdkErrorCode.cancelled)) {
      return const SquareSessionResolution(
        SquareSessionStatus.deviceUnavailable,
        errorCode: 'authenticationCancelled',
        stage: SquareApiStage.registration,
      );
    }
    if (error is SquareApiException) {
      final status = switch (error.errorCode) {
        'identity_unregistered' => SquareSessionStatus.identityUnbound,
        'identity_local_missing' ||
        'cid_not_bound' ||
        'identity_projection_pending' =>
          SquareSessionStatus.identityUnavailable,
        'cid_binding_changed' => SquareSessionStatus.identityChanged,
        'network_unavailable' => SquareSessionStatus.networkUnavailable,
        'registration_required' ||
        'device_not_registered' ||
        'invalid_mls_signature' ||
        'invalid_mls_proof' ||
        'invalid_binding_signature' ||
        'invalid_device_binding' ||
        'stale_device_binding' ||
        'device_proof_invalid' ||
        'device_proof_storage' => SquareSessionStatus.deviceUnavailable,
        _ => SquareSessionStatus.serviceUnavailable,
      };
      const knownCodes = {
        'identity_unregistered',
        'identity_local_missing',
        'cid_not_bound',
        'identity_projection_pending',
        'identity_projection_unavailable',
        'cid_binding_changed',
        'network_unavailable',
        'registration_required',
        'device_not_registered',
        'invalid_mls_signature',
        'invalid_mls_proof',
        'invalid_binding_signature',
        'invalid_device_binding',
        'stale_device_binding',
        'device_proof_invalid',
        'device_proof_storage',
        'mls_challenge_limit_reached',
        'request_rate_exceeded',
      };
      return SquareSessionResolution(
        status,
        errorCode: knownCodes.contains(error.errorCode)
            ? error.errorCode
            : null,
        statusCode: error.statusCode,
        // 本机设备证明存储失败没有HTTP响应，也仍须指出登记阶段。
        stage:
            error.stage ??
            switch (error.errorCode) {
              'device_proof_invalid' ||
              'device_proof_storage' => SquareApiStage.registration,
              _ => null,
            },
      );
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return const SquareSessionResolution(
        SquareSessionStatus.networkUnavailable,
        errorCode: 'network_unavailable',
        stage: SquareApiStage.request,
      );
    }
    if (error is MlsAuthenticationException) {
      final status = switch (error.code) {
        'identityChanged' => SquareSessionStatus.identityChanged,
        'identityUnavailable' => SquareSessionStatus.identityUnavailable,
        _ => SquareSessionStatus.deviceUnavailable,
      };
      return SquareSessionResolution(
        status,
        errorCode:
            const {
              'identityChanged',
              'identityUnavailable',
              'invalid_mls_proof',
            }.contains(error.code)
            ? error.code
            : null,
        stage: status == SquareSessionStatus.deviceUnavailable
            ? SquareApiStage.proof
            : SquareApiStage.identity,
      );
    }
    if (error is AccountSecurityException) {
      return SquareSessionResolution(
        error.code == 'identityChanged'
            ? SquareSessionStatus.identityChanged
            : SquareSessionStatus.deviceUnavailable,
        errorCode:
            const {
              'identityChanged',
              'authenticationRequired',
              'authenticationCancelled',
              'integrity',
            }.contains(error.code)
            ? error.code
            : null,
        stage: SquareApiStage.registration,
      );
    }
    if (error is PlatformException && error.code == 'mls_storage_unavailable') {
      return const SquareSessionResolution(
        SquareSessionStatus.deviceUnavailable,
        errorCode: 'mls_storage_unavailable',
        stage: SquareApiStage.identity,
      );
    }
    return const SquareSessionResolution(
      SquareSessionStatus.serviceUnavailable,
    );
  }
}

/// 广场与聊天共用的MLS准备和会话协调；普通认证不启动聊天权益或消息网络。
class SquareSessionProvider {
  SquareSessionProvider({
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    SquareApiClient? client,
    MlsAuthenticationSource? authentication,
    CidBusinessGate? cidBusinessGate,
  }) : _client = client ?? SquareApiClient(),
       _accountSecurity = accountSecurity,
       _currentUserContext = currentUserContext,
       _cidBusinessGate = cidBusinessGate {
    _authentication =
        authentication ??
        MlsAuthentication(
          runtime: () =>
              (_runtimeFactory ??
              (throw const MlsAuthenticationException('MLS运行实例未接入')))(),
          currentBinding: _currentMlsBinding,
        );
  }

  final SquareApiClient _client;
  final AccountSecurityService _accountSecurity;
  final CurrentUserContext _currentUserContext;
  late final MlsAuthenticationSource _authentication;
  sdk.ChatSdk Function()? _runtimeFactory;
  final CidBusinessGate? _cidBusinessGate;
  final Map<(String, int), Future<SquareSession?>> _flights = {};
  final Set<(String, String, int)> _blockedAuthorization = {};
  MlsAuthenticationSource get authentication => _authentication;
  sdk.ChatSdk get mlsRuntime =>
      (_runtimeFactory ??
      (throw const MlsAuthenticationException('MLS运行实例未接入')))();
  CurrentUserContext get _currentUser => _currentUserContext;

  /// 仅注入前台唯一实例工厂，安装本身不启动SDK或网络。
  void installRuntimeFactory(sdk.ChatSdk Function() factory) {
    if (_runtimeFactory != null) throw StateError('MLS运行实例已接入');
    _runtimeFactory = factory;
  }

  void closeAuthentication() {
    final source = _authentication;
    if (source is MlsAuthentication) source.close();
  }

  Future<MlsAccountBinding> _currentMlsBinding() async {
    final current = await _currentUser.resolve();
    final binding = current?.binding;
    if (current == null ||
        binding == null ||
        binding.accountId != current.accountId) {
      throw const MlsAuthenticationException(
        '当前身份尚未验证',
        code: 'identityUnavailable',
      );
    }
    return (
      cidNumber: binding.cidNumber,
      accountId: binding.accountId,
      bindingRevision: binding.bindingRevision,
    );
  }

  /// 身份主键是CID；所有普通请求使用同一MLS设备身份。
  Future<void> projectFinalizedIdentity(String blockHash) =>
      _client.projectFinalizedIdentity(blockHash);

  Future<String?> currentCitizenId() async {
    final current = await _currentUser.resolve();
    return current?.binding?.cidNumber;
  }

  Future<SquareSession?> ensureSession() => _ensureSession();

  /// 主动重试只恢复内部准备，不进入公民号注册或真人验证。
  Future<SquareSession?> registerCurrentDevice() =>
      _ensureSession(userInitiated: true);

  /// 所有消费者共用当前账户的唯一准备任务；先确认CID事实，再离线准备MLS和服务会话。
  Future<SquareSession?> _ensureSession({
    bool userInitiated = false,
    String? expectedAccountId,
  }) async {
    try {
      final decision = await _cidBusinessGate?.resolve();
      if (decision != null && decision.status != CidBusinessStatus.ready) {
        if (decision.status == CidBusinessStatus.noWallet) return null;
        throw SquareApiException(
          decision.status == CidBusinessStatus.unregistered
              ? '当前账户尚未注册公民号'
              : '身份读取失败，请重试',
          errorCode: decision.status == CidBusinessStatus.unregistered
              ? 'identity_unregistered'
              : 'identity_projection_unavailable',
          stage: SquareApiStage.identity,
        );
      }
      final current = await _currentUser.resolve();
      if (current == null) return null;
      if (expectedAccountId != null && current.accountId != expectedAccountId) {
        throw const AccountSecurityException(
          '当前用户已变化',
          code: 'identityChanged',
        );
      }
      final key = (current.accountId, _accountSecurity.revision.value);
      final existing = _flights[key];
      if (existing != null) return await existing;
      late final Future<SquareSession?> task;
      task =
          _prepareSession(
            userInitiated: userInitiated,
            expectedAccountId: current.accountId,
          ).whenComplete(() {
            if (identical(_flights[key], task)) _flights.remove(key);
          });
      _flights[key] = task;
      return await task;
    } on Object catch (error) {
      // 网络边界已有真实阶段；本地准备只输出既有闭集分类，不读异常正文。
      if (error is! SquareApiException ||
          error.stage == null ||
          error.stage == SquareApiStage.identity) {
        final failure = SquareSessionResolution.fromError(error);
        AppLog.failure(
          stage: failure.stage?.name ?? 'prepare',
          statusCode: failure.statusCode,
          code:
              failure.errorCode ??
              switch (error) {
                FormatException() => 'format',
                TypeError() => 'type',
                StateError() => 'state',
                PlatformException() => 'platform',
                _ => null,
              },
        );
      }
      rethrow;
    }
  }

  Future<SquareSession?> _prepareSession({
    required bool userInitiated,
    required String expectedAccountId,
  }) async {
    final revision = _accountSecurity.revision.value;
    final current = await _currentUser.resolve();
    if (current == null) return null;
    if (current.accountId.isEmpty || current.accountId != expectedAccountId) {
      throw const AccountSecurityException(
        '当前用户已变化，请重试',
        code: 'identityChanged',
      );
    }
    final binding = current.binding;
    if (binding == null || binding.accountId != current.accountId) {
      throw SquareApiException(
        current.isUnregistered ? '当前账户尚未注册公民号' : '身份信息暂不可用，请在身份页刷新后重试',
        errorCode: current.isUnregistered
            ? 'identity_unregistered'
            : 'identity_local_missing',
        stage: SquareApiStage.identity,
      );
    }
    Future<void> requireCurrent() async {
      final latest = await _currentUser.resolve();
      if (_accountSecurity.revision.value != revision ||
          latest?.accountId != binding.accountId ||
          latest?.binding?.cidNumber != binding.cidNumber ||
          latest?.binding?.bindingRevision != binding.bindingRevision ||
          latest?.binding?.genesisHash != binding.genesisHash) {
        throw const AccountSecurityException(
          '当前用户已变化，请重试',
          code: 'identityChanged',
        );
      }
    }

    await requireCurrent();
    final session = await _client.ensureSession(
      accountId: current.accountId,
      authentication: _authentication,
      onDeviceNotRegistered: (context) async {
        await requireCurrent();
        if (context.accountId != binding.accountId ||
            context.cidNumber != binding.cidNumber ||
            context.bindingRevision != binding.bindingRevision) {
          throw const MlsAuthenticationException(
            '当前用户已变化',
            code: 'identityChanged',
          );
        }
        final owner = (
          binding.cidNumber,
          binding.accountId,
          binding.bindingRevision,
        );
        if (userInitiated) _blockedAuthorization.remove(owner);
        if (_blockedAuthorization.contains(owner)) {
          throw const AccountSecurityException(
            '钱包授权尚未完成',
            code: 'authenticationRequired',
          );
        }
        try {
          await _registerMissingMlsDevice(binding);
        } on Object catch (error) {
          // 明确取消后只接受下一次主动重试；渲染、前台恢复和推送不得反复请求授权。
          if (error is AccountSecurityException ||
              error is CitizenSdkException) {
            _blockedAuthorization.add(owner);
          }
          rethrow;
        }
        await requireCurrent();
      },
    );
    await requireCurrent();
    await session.validateCurrent();
    await requireCurrent();
    if (session.accountId != binding.accountId ||
        session.cidNumber != binding.cidNumber ||
        session.bindingRevision != binding.bindingRevision ||
        !session.isUsable) {
      throw const MlsAuthenticationException(
        '目标会话期间身份已变化',
        code: 'identityChanged',
      );
    }
    return session;
  }

  /// 聊天模块只提交设备标识和预期身份；会话建立、请求签名与 HTTP 均留在服务模块。
  Future<CitizenServeChatAccess> requestChatAccess({
    required String deviceId,
    required String expectedCidNumber,
    required int expectedBindingRevision,
    required String expectedAccountId,
  }) async {
    final session = await ensureSession();
    final identity = await _authentication.readIdentity();
    if (identity.cidNumber != expectedCidNumber ||
        identity.bindingRevision != expectedBindingRevision ||
        identity.accountId != expectedAccountId ||
        identity.deviceId != deviceId) {
      throw const MlsAuthenticationException(
        '聊天许可身份已变化',
        code: 'identityChanged',
      );
    }
    if (session == null ||
        session.cidNumber != expectedCidNumber ||
        session.bindingRevision != expectedBindingRevision ||
        session.accountId != expectedAccountId ||
        session.deviceId != deviceId) {
      throw const SquareApiException('聊天会话与当前用户绑定不一致');
    }
    await _authentication.requireCurrent(identity);
    final access = await _client.fetchChatAccess(
      session: session,
      deviceId: deviceId,
    );
    await _authentication.requireCurrent(identity);
    await session.validateCurrent();
    if ((await _currentUser.resolve())?.accountId != expectedAccountId ||
        !session.isUsable) {
      throw const MlsAuthenticationException(
        '聊天许可返回时会话已变化',
        code: 'identityChanged',
      );
    }
    return access;
  }

  /// 为页面保留失败原因；动作服务仍可使用 [ensureSession] 让异常失败关闭。
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    try {
      final session = await (refresh ? refreshSession() : ensureSession());
      if (session == null) {
        return const SquareSessionResolution(SquareSessionStatus.noWallet);
      }
      return SquareSessionResolution(
        SquareSessionStatus.ready,
        session: session,
      );
    } on SquareApiException catch (error) {
      if (error.errorCode == 'cid_not_bound' ||
          error.errorCode == 'identity_projection_pending') {
        // 本机已有 finalized 绑定时，Worker 的 cid_not_bound 只能视为投影未同步。
        return SquareSessionResolution(
          SquareSessionStatus.identityUnavailable,
          errorCode: error.errorCode,
          statusCode: error.statusCode,
          stage: error.stage,
        );
      }
      return SquareSessionResolution.fromError(error);
    } on Object catch (error) {
      // 未知Error同样失败关闭，不能穿透到会员页面或输出原始异常。
      return SquareSessionResolution.fromError(error);
    }
  }

  /// Worker 明确返回 401 后清除当前身份账户的本地缓存并重新握手一次。
  ///
  /// 仅供已经收到未授权响应的前台请求调用；普通首次加载仍走 [ensureSession] 的缓存与
  /// in-flight 去重，避免把每次页面进入都放大成新的登录挑战。
  Future<SquareSession?> refreshSession() async {
    final current = await _currentUser.resolve();
    if (current == null) return null;
    if (current.accountId.isEmpty) {
      throw const AccountSecurityException(
        '默认账户信息不可用',
        code: 'identityChanged',
      );
    }
    _client.clearSession(current.accountId);
    return ensureSession();
  }

  /// 账户换绑时只由会话所有者清理准确账户的 CitizenServe 登录态。
  void invalidateAccount(String accountId) => _client.clearSession(accountId);

  /// 目标账户仍须是当前默认账户；与普通入口共用同一自动准备和缓存。
  Future<SquareSession?> ensureSessionForAccountId(String accountId) =>
      _ensureSession(expectedAccountId: accountId);

  /// Worker 是设备登记状态真源；只有它明确报告未登记时才进入一次钱包鉴权。
  Future<void> _registerMissingMlsDevice(IdentityBinding binding) async {
    await _accountSecurity.registerMlsDeviceForBinding(binding);
  }
}
