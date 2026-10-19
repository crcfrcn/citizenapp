import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
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

  String get message => switch (errorCode) {
    'identity_local_missing' => '请在身份页恢复或完成注册后重试',
    'registration_required' => '请在身份页完成注册安全验证和设备激活',
    'mls_challenge_limit_reached' || 'request_rate_exceeded' => '请求过于频繁，请稍后重试',
    'authenticationRequired' => '首次设备登记授权尚未完成',
    _ => status.message,
  };

  /// 页面和通讯录复用同一错误分类；无记录不等于离线，未知HTTP错误不等于设备故障。
  static SquareSessionResolution fromError(Object error) {
    if (error is SquareApiException) {
      final status = switch (error.errorCode) {
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

/// 广场与聊天共用的MLS会话协调；普通认证不访问钱包或聊天权益。
class SquareSessionProvider {
  SquareSessionProvider({
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    SquareApiClient? client,
    MlsAuthenticationSource? authentication,
  }) : _client = client ?? SquareApiClient(),
       _accountSecurity = accountSecurity,
       _currentUserContext = currentUserContext {
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

  /// 仅用户主动恢复/注册调用；Worker明确未登记后才允许一次钱包登记。
  Future<SquareSession?> registerCurrentDevice() =>
      _ensureSession(allowRegistration: true);

  /// 普通入口仅消费本机绑定；不查询链、不恢复绑定，也不隐式登记设备。
  Future<SquareSession?> _ensureSession({
    bool allowRegistration = false,
    String? expectedAccountId,
  }) async {
    final revision = _accountSecurity.revision.value;
    final current = await _currentUser.resolve();
    if (current == null) return null;
    if (current.accountId.isEmpty ||
        (expectedAccountId != null && current.accountId != expectedAccountId)) {
      throw const AccountSecurityException(
        '当前用户已变化，请重试',
        code: 'identityChanged',
      );
    }
    final binding = current.binding;
    if (binding == null || binding.accountId != current.accountId) {
      throw const SquareApiException(
        '请在身份页恢复或完成注册后重试',
        errorCode: 'identity_local_missing',
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
      onDeviceNotRegistered: allowRegistration
          ? (context) async {
              await requireCurrent();
              if (context.accountId != binding.accountId ||
                  context.cidNumber != binding.cidNumber ||
                  context.bindingRevision != binding.bindingRevision) {
                throw const MlsAuthenticationException(
                  '当前用户已变化',
                  code: 'identityChanged',
                );
              }
              await _registerMissingMlsDevice(binding);
              await requireCurrent();
            }
          : null,
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
    final session = await ensureSession();
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
    } on Exception catch (error) {
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

  /// 目标账户仍须是当前默认账户；与普通入口共用同一协调和缓存，不代办登记。
  Future<SquareSession?> ensureSessionForAccountId(String accountId) =>
      _ensureSession(expectedAccountId: accountId);

  /// Worker 是设备登记状态真源；只有它明确报告未登记时才进入一次钱包鉴权。
  Future<void> _registerMissingMlsDevice(IdentityBinding binding) async {
    await _accountSecurity.registerMlsDeviceForBinding(binding);
  }
}
