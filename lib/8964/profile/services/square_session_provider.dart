import 'dart:async';
import 'dart:io';

import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/my/myid/current_user_context.dart';
import 'package:citizenapp/security/chain_bootstrap_api.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:citizenapp/security/mls_authentication.dart';
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
  const SquareSessionResolution(this.status, {this.session});

  final SquareSessionStatus status;
  final SquareSession? session;

  String get message => status.message;
}

/// 广场与聊天共用的MLS会话协调；普通认证不访问钱包或聊天权益。
class SquareSessionProvider {
  SquareSessionProvider({
    required AccountSecurityService accountSecurity,
    required CurrentUserContext currentUserContext,
    SquareApiClient? client,
    MlsAuthenticationSource? authentication,
    ChainBootstrapApi? bootstrapApi,
  }) : _client = client ?? SquareApiClient(),
       _accountSecurity = accountSecurity,
       _currentUserContext = currentUserContext,
       _bootstrapApi = bootstrapApi ?? ChainBootstrapApi() {
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
  final ChainBootstrapApi _bootstrapApi;
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
  Future<SquareSession?> ensureSession() => _ensureSession();

  /// 页面明确请求本机登记时仍由Worker判定登记资格，并复用唯一会话协调。
  Future<SquareSession?> registerCurrentDevice() => _ensureSession();

  Future<SquareSession?> _ensureSession() async {
    final current = await _currentUser.resolve();
    if (current == null) return null;
    if (current.accountId.isEmpty) {
      throw const AccountSecurityException(
        '默认账户信息不可用',
        code: 'identityChanged',
      );
    }
    final session = await _client.ensureSession(
      accountId: current.accountId,
      authentication: _authentication,
      onDeviceNotRegistered: (context) async {
        if (context.accountId != current.accountId) {
          throw const MlsAuthenticationException(
            '当前用户已变化',
            code: 'identityChanged',
          );
        }
        final binding = await _bindingForContext(context);
        await _registerMissingMlsDevice(binding);
      },
    );
    if ((await _currentUser.resolve())?.accountId != current.accountId) {
      throw const AccountSecurityException(
        '当前用户已变化，请重试',
        code: 'identityChanged',
      );
    }
    await _activateSessionBinding(session);
    return session;
  }

  /// 聊天模块只提交设备标识和预期身份；会话建立、请求签名与 HTTP 均留在服务模块。
  Future<CitizenServeChatAccess> requestChatServerAccess({
    required String deviceId,
    required String expectedCidNumber,
    required int expectedBindingRevision,
    required String expectedAccountId,
  }) async {
    final session = await ensureSession();
    if (session == null ||
        session.cidNumber != expectedCidNumber ||
        session.bindingRevision != expectedBindingRevision ||
        session.accountId != expectedAccountId ||
        session.deviceId != deviceId) {
      throw const SquareApiException('聊天会话与当前用户绑定不一致');
    }
    return _client.fetchChatServerAccess(session: session, deviceId: deviceId);
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
        if (error.errorCode == 'cid_not_bound') {
          final current = await _currentUser.resolve();
          if (current?.binding == null) {
            return const SquareSessionResolution(
              SquareSessionStatus.identityUnbound,
            );
          }
        }
        // 本机已有 finalized 绑定时，Worker 的 cid_not_bound 只能视为投影未同步。
        return const SquareSessionResolution(
          SquareSessionStatus.identityUnavailable,
        );
      }
      if (error.errorCode == 'identity_projection_unavailable' ||
          (error.statusCode ?? 0) >= 500) {
        return const SquareSessionResolution(
          SquareSessionStatus.serviceUnavailable,
        );
      }
      return const SquareSessionResolution(
        SquareSessionStatus.deviceUnavailable,
      );
    } on SocketException {
      return const SquareSessionResolution(
        SquareSessionStatus.networkUnavailable,
      );
    } on TimeoutException {
      return const SquareSessionResolution(
        SquareSessionStatus.networkUnavailable,
      );
    } on MlsAuthenticationException catch (error) {
      return SquareSessionResolution(
        error.code == 'identityChanged'
            ? SquareSessionStatus.identityChanged
            : error.code == 'identityUnavailable'
            ? SquareSessionStatus.identityUnavailable
            : SquareSessionStatus.deviceUnavailable,
      );
    } on AccountSecurityException catch (error) {
      return SquareSessionResolution(
        error.code == 'identityChanged'
            ? SquareSessionStatus.identityChanged
            : SquareSessionStatus.deviceUnavailable,
      );
    } on Exception {
      return const SquareSessionResolution(
        SquareSessionStatus.serviceUnavailable,
      );
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

  /// 已由精确 finalized 交易结果确认换绑后，为目标账户建立新会话。
  ///
  /// 本入口不再自行解析身份或读链；Worker 登录挑战仍会按链上当前绑定 fail-closed。
  /// 用于已确认当前账户的普通受保护请求。
  Future<SquareSession?> ensureSessionForAccountId(String accountId) async {
    final binding = await _accountSecurity.identityBindingForAccountId(
      accountId,
    );
    final identity = await _authentication.readIdentity();
    if (identity.accountId != accountId ||
        identity.cidNumber != binding.cidNumber ||
        identity.bindingRevision != binding.bindingRevision) {
      throw const MlsAuthenticationException(
        "目标会话与当前已验证绑定不一致",
        code: "identityChanged",
      );
    }
    final session = await _client.ensureSession(
      accountId: accountId,
      authentication: _authentication,
      onDeviceNotRegistered: (_) => _registerMissingMlsDevice(binding),
    );
    await _authentication.requireCurrent(identity);
    if (session.accountId != identity.accountId ||
        session.cidNumber != identity.cidNumber ||
        session.bindingRevision != identity.bindingRevision ||
        session.deviceId != identity.deviceId) {
      throw const MlsAuthenticationException(
        "目标会话期间身份已变化",
        code: "identityChanged",
      );
    }
    return session;
  }

  /// Worker 是设备登记状态真源；只有它明确报告未登记时才进入一次钱包鉴权。
  Future<void> _registerMissingMlsDevice(IdentityBinding binding) async {
    await _accountSecurity.registerMlsDeviceForBinding(binding);
  }

  Future<IdentityBinding> _bindingForContext(
    MlsAuthenticationIdentity context,
  ) async {
    final existing = await _accountSecurity.readIdentityBindingForAccountId(
      context.accountId,
    );
    if (existing != null &&
        existing.cidNumber == context.cidNumber &&
        existing.bindingRevision == context.bindingRevision) {
      return existing;
    }
    final manifest = await _bootstrapApi.fetchManifest();
    final binding = IdentityBinding(
      genesisHash: manifest.chain.genesisHash,
      cidNumber: context.cidNumber,
      bindingRevision: context.bindingRevision,
      accountId: context.accountId,
    );
    await _accountSecurity.activateIdentityBinding(
      genesisHash: binding.genesisHash,
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
    return binding;
  }

  Future<void> _activateSessionBinding(SquareSession session) async {
    final binding = await _bindingForContext(
      MlsAuthenticationIdentity(
        cidNumber: session.cidNumber,
        bindingRevision: session.bindingRevision,
        accountId: session.accountId,
        deviceId: session.deviceId,
        publicKey: '0x${session.deviceId}',
      ),
    );
    await _accountSecurity.activateIdentityBinding(
      genesisHash: binding.genesisHash,
      cidNumber: binding.cidNumber,
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
    );
    // 真正绑定变化已由 revision 使缓存失效；同绑定登录不得取消其它页面的在途读取。
  }
}
