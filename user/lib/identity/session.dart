// 协调MLS设备登记、请求认证和用户会话。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:citizen_network/auth.dart' as mls;
import 'dart:typed_data';
import 'package:citizen_user/security.dart' show AccountSecurityService, PublicIdentityRecordStore, SystemPublicIdentityRecordStore, decodeDeviceRegistrationProof, deviceRegistrationProofKey;
import 'package:citizen_user/api.dart' show CitizenServeChatAccess, SquareApiClient, SquareApiException, SquareApiStage, SquareSession;
import 'package:citizen_system/security/access.dart';
import 'package:citizen_system/log.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:citizen_user/context.dart' show CurrentUserContext, IdentityBinding;
import 'package:citizen_user/identity/state.dart' show CidBusinessGate, CidBusinessStatus;

// 复用唯一聊天运行时生成绑定公开CID和设备的受限请求证明。

typedef MlsAccountBinding = ({String cidNumber, String accountId, int bindRev});

class MlsAuthenticationException implements Exception {
  const MlsAuthenticationException(
    this.message, {
    this.code = 'invalid_mls_proof',
  });
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// 公开身份快照，仅含CID、当前绑定与同一MLS公钥。
class MlsAuthenticationIdentity {
  const MlsAuthenticationIdentity({
    required this.cidNumber,
    required this.accountId,
    required this.bindRev,
    required this.deviceId,
    required this.publicKey,
  });
  final String cidNumber;
  final String accountId;
  final int bindRev;
  final String deviceId;
  final String publicKey;

  String get cacheKey => jsonEncode([cidNumber, accountId, bindRev, deviceId]);
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(cidNumber) ||
        !isCitizenAccountId(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey) ||
        deviceId != publicKey.substring(2) ||
        bindRev <= 0 ||
        bindRev > mls.MlsAuthenticationRequest.maxJsonInteger) {
      throw const MlsAuthenticationException('MLS公开身份与当前绑定无效');
    }
  }
}

/// 测试只替换这个受限边界；生产没有任意字节签名回调。
abstract interface class MlsAuthenticationSource {
  Future<MlsAuthenticationIdentity> readIdentity();
  Future<void> requireCurrent(MlsAuthenticationIdentity identity);
  Future<mls.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required mls.MlsAuthenticationRequest request,
  });
}

/// 前台会话与聊天复用唯一运行实例；认证不访问权益、网络或钱包。
class MlsAuthentication implements MlsAuthenticationSource {
  MlsAuthentication({
    required Future<mls.ChatDevice> Function() readLocalIdentity,
    required Future<mls.MlsAuthenticationProof> Function(
      mls.MlsAuthenticationRequest request,
    )
    createProof,
    required Future<MlsAccountBinding> Function() currentBinding,
  }) : _readLocalIdentity = readLocalIdentity,
       _createProof = createProof,
       _currentBinding = currentBinding;
  final Future<mls.ChatDevice> Function() _readLocalIdentity;
  final Future<mls.MlsAuthenticationProof> Function(
    mls.MlsAuthenticationRequest request,
  )
  _createProof;
  final Future<MlsAccountBinding> Function() _currentBinding;
  bool _closed = false;

  /// SDK关闭与业务释放之前同步封住新认证和晚返回。
  void close() {
    _closed = true;
  }

  @override
  Future<MlsAuthenticationIdentity> readIdentity() async {
    if (_closed) {
      throw const MlsAuthenticationException(
        'MLS认证已关闭',
        code: 'identityChanged',
      );
    }
    final binding = await _currentBinding();
    // SDK在同一受保护锁内自动准备合法空存储或复用原身份；这里只读取公开结果。
    final local = await _readLocalIdentity();
    final publicKey = local.publicKey;
    if (publicKey == null) throw const MlsAuthenticationException('MLS公开身份缺失');
    final identity = MlsAuthenticationIdentity(
      cidNumber: binding.cidNumber,
      accountId: binding.accountId,
      bindRev: binding.bindRev,
      deviceId: local.deviceId,
      publicKey: publicKey,
    );
    identity.validate();
    if (local.userId != identity.cidNumber) {
      throw const MlsAuthenticationException('MLS身份所有者不一致');
    }
    await requireCurrent(identity);
    return identity;
  }

  @override
  Future<void> requireCurrent(MlsAuthenticationIdentity identity) async {
    identity.validate();
    final binding = await _currentBinding();
    if (_closed ||
        binding.cidNumber != identity.cidNumber ||
        binding.accountId != identity.accountId ||
        binding.bindRev != identity.bindRev) {
      throw const MlsAuthenticationException(
        'MLS认证期间当前用户已变化',
        code: 'identityChanged',
      );
    }
  }

  @override
  Future<mls.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required mls.MlsAuthenticationRequest request,
  }) async {
    identity.validate();
    request.validate();
    await requireCurrent(identity);
    final proof = await _createProof(request);
    await requireCurrent(identity);
    validateMlsProofMatches(identity, request, proof);
    return proof;
  }
}

void validateMlsProofMatches(
  MlsAuthenticationIdentity identity,
  mls.MlsAuthenticationRequest request,
  mls.MlsAuthenticationProof proof,
) {
  identity.validate();
  request.validate();
  // 直接验证SDK原生字段集；宿主不再构造第二份证明或翻译字段名。
  final fields = proof.toJson();
  final expected = <String, Object>{
    'user_id': identity.cidNumber,
    'device_id': identity.deviceId,
    'public_key': identity.publicKey,
    'account_id': identity.accountId,
    'bind_rev': identity.bindRev,
    'service_origin': request.serviceOrigin,
    'token_purpose': request.tokenPurpose,
    if (request.sessionHash != null) 'session_hash': request.sessionHash!,
    'nonce_id': request.nonceId,
    'expires_at': request.expiresAt,
    'http_method': request.httpMethod,
    'request_target': request.requestTarget,
    'body_hash': '0x${sha256.convert(request.bodyBytes)}',
  };
  final signature = fields['signature'];
  if (fields.length != expected.length + 1 ||
      signature is! String ||
      !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature) ||
      !expected.entries.every((entry) => fields[entry.key] == entry.value)) {
    throw const MlsAuthenticationException('MLS证明与准确请求不一致');
  }
}

// 使用SDK原语构造已获授权的MLS设备登记载荷和摘要。

/// 已单独授权的登记载荷；SCALE与GMB摘要只使用CitizenSDK原语。
Future<Uint8List> encodeMlsDeviceBindingPayload({
  required String cidNumber,
  required int bindRev,
  required String accountId,
  required String publicKey,
  required int issuedAtMillis,
}) async {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(cidNumber) ||
      bindRev <= 0 ||
      bindRev > 9007199254740991 ||
      !isCitizenAccountId(accountId) ||
      !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey) ||
      issuedAtMillis <= 0 ||
      issuedAtMillis > 9007199254740991) {
    throw const FormatException('MLS设备登记载荷无效');
  }
  return Uint8List.fromList([
    ...await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(cidNumber),
    ),
    ...await CitizenSdk.encodePayload(
      CitizenSigningPayload.u64Le(BigInt.from(bindRev)),
    ),
    ...await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(accountId),
    ),
    ...await CitizenSdk.encodePayload(
      CitizenSigningPayload.scaleString(publicKey),
    ),
    ...await CitizenSdk.encodePayload(
      CitizenSigningPayload.u64Le(BigInt.from(issuedAtMillis)),
    ),
  ]);
}

Future<Uint8List> buildMlsDeviceBindingSigningMessage(
  String cidNumber,
  int bindRev,
  String accountId,
  String publicKey,
  int issuedAt,
) async => CitizenSdk.encodePayload(
  CitizenSigningPayload.message(
    opTag: kOpSignMlsDeviceBind,
    scalePayload: await encodeMlsDeviceBindingPayload(
      cidNumber: cidNumber,
      bindRev: bindRev,
      accountId: accountId,
      publicKey: publicKey,
      issuedAtMillis: issuedAt,
    ),
  ),
);

// 复用持久钱包证明，同步已确认换绑或明确未登记的MLS设备绑定。

/// 对设备绑定证明消息（`signing_message` 的 32 字节摘要）做 sr25519 主钥签名，
/// 返回 `0x` hex 签名。
typedef DeviceBindingSigner =
    Future<String> Function({
      required Uint8List payload,
      required Uint8List signingMessage,
      required String publicKey,
      required int issuedAtMillis,
    });

/// 已确认换绑或明确未登记时更新同一设备绑定，钱包证明先持久保存。
class MlsDeviceRegistrar {
  MlsDeviceRegistrar({
    required MlsAuthenticationSource authentication,
    SquareApiClient? apiClient,
    PublicIdentityRecordStore? proofStore,
  }) : _authentication = authentication,
       _api = apiClient ?? SquareApiClient(),
       _proofStore = proofStore ?? SystemPublicIdentityRecordStore();

  final MlsAuthenticationSource _authentication;
  final SquareApiClient _api;
  final PublicIdentityRecordStore _proofStore;
  final Map<String, Future<void>> _flights = {};

  Future<void> register({
    required String cidNumber,
    required int bindRev,
    required String accountId,
    required DeviceBindingSigner signBinding,
    int? issuedAtMillis,
  }) {
    final key = deviceRegistrationProofKey(cidNumber, bindRev, accountId);
    return _flights.putIfAbsent(
      key,
      () =>
          _register(
            cidNumber: cidNumber,
            bindRev: bindRev,
            accountId: accountId,
            signBinding: signBinding,
            issuedAtMillis: issuedAtMillis,
          ).whenComplete(() {
            _flights.remove(key);
          }),
    );
  }

  Future<void> _register({
    required String cidNumber,
    required int bindRev,
    required String accountId,
    required DeviceBindingSigner signBinding,
    int? issuedAtMillis,
  }) async {
    final identity = await _authentication.readIdentity();
    if (identity.cidNumber != cidNumber ||
        identity.bindRev != bindRev ||
        identity.accountId != accountId) {
      throw const MlsAuthenticationException(
        '登记归属与当前MLS身份不一致',
        code: 'identityChanged',
      );
    }
    final proofKey = deviceRegistrationProofKey(cidNumber, bindRev, accountId);
    final rawProof = await _proofStore.read(proofKey);
    await _authentication.requireCurrent(identity);
    late final int issuedAt;
    late final String signature;
    var reusable = false;
    if (rawProof != null) {
      try {
        final proof = decodeDeviceRegistrationProof(
          rawProof,
          cidNumber: cidNumber,
          bindRev: bindRev,
          accountId: accountId,
        );
        reusable = proof['public_key'] == identity.publicKey;
        if (reusable) {
          issuedAt = proof['issued_at'] as int;
          signature = proof['signature'] as String;
        }
      } on FormatException {
        throw const SquareApiException(
          '本机MLS登记授权不可用',
          errorCode: 'device_proof_invalid',
        );
      }
    }
    // 只复用当前设备的钱包授权；不同公钥重新走原钱包签署，绝不借用旧签名。
    if (!reusable) {
      issuedAt = issuedAtMillis ?? DateTime.now().millisecondsSinceEpoch;
      final payload = await encodeMlsDeviceBindingPayload(
        cidNumber: cidNumber,
        bindRev: bindRev,
        accountId: accountId,
        publicKey: identity.publicKey,
        issuedAtMillis: issuedAt,
      );
      final message = await buildMlsDeviceBindingSigningMessage(
        cidNumber,
        bindRev,
        accountId,
        identity.publicKey,
        issuedAt,
      );
      await _authentication.requireCurrent(identity);
      signature = await signBinding(
        payload: payload,
        signingMessage: message,
        publicKey: identity.publicKey,
        issuedAtMillis: issuedAt,
      );
      await _authentication.requireCurrent(identity);
      if (!RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature)) {
        throw const SquareApiException(
          'MLS登记钱包签名无效',
          errorCode: 'device_proof_invalid',
        );
      }
      final proof = jsonEncode({
        'cid_number': cidNumber,
        'bind_rev': bindRev,
        'account_id': accountId,
        'public_key': identity.publicKey,
        'issued_at': issuedAt,
        'signature': signature,
      });
      if (!await _proofStore.compareAndSet(
            proofKey,
            expected: rawProof,
            next: proof,
          ) ||
          await _proofStore.read(proofKey) != proof) {
        throw const SquareApiException(
          'MLS登记授权保存失败',
          errorCode: 'device_proof_storage',
        );
      }
      await _authentication.requireCurrent(identity);
    }

    // 钱包授权材料独立于人验，设备提交只携带当前四字段和持钥证明。
    await _api.registerMlsDevice(
      identity: identity,
      authentication: _authentication,
      issuedAt: issuedAt,
      bindingSignatureHex: signature,
    );
    await _authentication.requireCurrent(identity);
  }
}

// 解析建立公民服务会话后的明确状态，保留设备和网络失败类别。

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

  static mls.MlsException? _mlsError(String? value) {
    for (final code in mls.MlsErrorCode.values) {
      final error = mls.MlsException(code, '');
      if (value == 'mls_${error.diagnosticCode}') return error;
    }
    return null;
  }

  String get message =>
      _mlsError(errorCode)?.userMessage ??
      switch (errorCode) {
        'identity_local_missing' => '身份信息暂不可用，请在身份页刷新后重试',
        'device_not_registered' => '公民服务准备未完成，请重试',
        'chain_rpc_budget_exceeded' => '公共链查询次数已达服务端限额，请稍后重试',
        'request_rate_exceeded' => '请求过于频繁，请稍后重试',
        'authenticationRequired' => '首次设备登记授权尚未完成',
        'authenticationCancelled' => '设备授权已取消，可再次主动发起',
        _ => status.message,
      };

  /// 页面和通讯录复用同一错误分类；无记录不等于离线，未知HTTP错误不等于设备故障。
  static SquareSessionResolution fromError(Object error) {
    if (error is mls.MlsException) {
      return SquareSessionResolution(
        error.code == mls.MlsErrorCode.stateOwnerMismatch
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
        'cid_not_bound' => SquareSessionStatus.identityUnavailable,
        'cid_binding_changed' => SquareSessionStatus.identityChanged,
        'network_unavailable' => SquareSessionStatus.networkUnavailable,
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
        'identity_projection_unavailable',
        'cid_binding_changed',
        'network_unavailable',
        'device_not_registered',
        'invalid_mls_signature',
        'invalid_mls_proof',
        'invalid_binding_signature',
        'invalid_device_binding',
        'stale_device_binding',
        'device_proof_invalid',
        'device_proof_storage',
        'request_rate_exceeded',
        'chain_rpc_budget_exceeded',
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
    _sessionAuthentication =
        authentication ??
        MlsAuthentication(
          readLocalIdentity: () =>
              (_sessionLocalIdentity ??
              (throw const MlsAuthenticationException('MLS身份读取未接入')))(),
          createProof: (request) =>
              (_createMlsProof ??
              (throw const MlsAuthenticationException('MLS认证未接入')))(request),
          currentBinding: _currentMlsBinding,
        );
  }

  final SquareApiClient _client;
  final AccountSecurityService _accountSecurity;
  final CurrentUserContext _currentUserContext;
  late final MlsAuthenticationSource _sessionAuthentication;
  Future<mls.ChatDevice> Function()? _sessionLocalIdentity;
  Future<mls.MlsAuthenticationProof> Function(mls.MlsAuthenticationRequest)?
  _createMlsProof;
  final CidBusinessGate? _cidBusinessGate;
  final Map<(String, int, bool), Future<SquareSession?>> _sessionFlights = {};
  final Set<(String, String, int)> _blockedAuthorization = {};
  MlsAuthenticationSource get authentication => _sessionAuthentication;
  CurrentUserContext get _currentUser => _currentUserContext;

  /// 注入唯一 MLS 身份的受限操作，安装本身不创建身份或连接网络。
  void installMlsAuthentication({
    required Future<mls.ChatDevice> Function() readLocalIdentity,
    required Future<mls.MlsAuthenticationProof> Function(
      mls.MlsAuthenticationRequest,
    )
    createProof,
  }) {
    if (_sessionLocalIdentity != null || _createMlsProof != null) {
      throw StateError('MLS认证已接入');
    }
    _sessionLocalIdentity = readLocalIdentity;
    _createMlsProof = createProof;
  }

  void closeAuthentication() {
    final source = _sessionAuthentication;
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
      bindRev: binding.bindRev,
    );
  }

  Future<String?> currentCitizenId() async {
    final current = await _currentUser.resolve();
    return current?.binding?.cidNumber;
  }

  Future<SquareSession?> ensureSession() => _ensureSession();

  Future<SquareSession?> ensureContactSession() =>
      _ensureSession(allowWalletAuthorization: false);

  /// 聊天消费本机已经核验的绑定，缺失时由身份页负责恢复。
  Future<SquareSession?> ensureChatSession() =>
      _ensureSession(recoverBinding: false);

  /// 主动重试只恢复内部准备，不进入公民号注册或真人验证。
  Future<SquareSession?> registerCurrentDevice() =>
      _ensureSession(userInitiated: true);

  /// 所有消费者共用当前账户的 MLS 与服务会话准备任务。
  Future<SquareSession?> _ensureSession({
    bool userInitiated = false,
    bool allowWalletAuthorization = true,
    bool recoverBinding = true,
    String? expectedAccountId,
  }) async {
    try {
      if (recoverBinding) {
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
      }
      final current = await _currentUser.resolve();
      if (current == null) return null;
      if (current.accountId.isEmpty ||
          (expectedAccountId != null &&
              current.accountId != expectedAccountId)) {
        throw const AccountSecurityException(
          '当前用户已变化',
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
      final revision = _accountSecurity.revision.value;
      final key = (binding.accountId, revision, allowWalletAuthorization);
      final existing = _sessionFlights[key];
      if (existing != null) return await existing;
      late final Future<SquareSession?> task;
      task =
          _prepareSession(
            userInitiated: userInitiated,
            allowWalletAuthorization: allowWalletAuthorization,
            binding: binding,
            revision: revision,
          ).whenComplete(() {
            if (identical(_sessionFlights[key], task)) _sessionFlights.remove(key);
          });
      _sessionFlights[key] = task;
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

  Future<SquareSession> _prepareSession({
    required bool userInitiated,
    required bool allowWalletAuthorization,
    required IdentityBinding binding,
    required int revision,
  }) async {
    Future<void> requireCurrent() async {
      final latest = await _currentUser.resolve();
      if (_accountSecurity.revision.value != revision ||
          latest?.accountId != binding.accountId ||
          latest?.binding?.cidNumber != binding.cidNumber ||
          latest?.binding?.bindRev != binding.bindRev ||
          latest?.binding?.genesisHash != binding.genesisHash) {
        throw const AccountSecurityException(
          '当前用户已变化，请重试',
          code: 'identityChanged',
        );
      }
    }

    await requireCurrent();
    final session = await _client.ensureSession(
      accountId: binding.accountId,
      authentication: _sessionAuthentication,
      onDeviceNotRegistered: (context) async {
        await requireCurrent();
        if (context.accountId != binding.accountId ||
            context.cidNumber != binding.cidNumber ||
            context.bindRev != binding.bindRev) {
          throw const MlsAuthenticationException(
            '当前用户已变化',
            code: 'identityChanged',
          );
        }
        if (!allowWalletAuthorization) {
          throw const AccountSecurityException(
            '钱包授权尚未完成',
            code: 'authenticationRequired',
          );
        }
        final owner = (binding.cidNumber, binding.accountId, binding.bindRev);
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
        session.bindRev != binding.bindRev ||
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
    final session = await ensureChatSession();
    final identity = await _sessionAuthentication.readIdentity();
    if (identity.cidNumber != expectedCidNumber ||
        identity.bindRev != expectedBindingRevision ||
        identity.accountId != expectedAccountId ||
        identity.deviceId != deviceId) {
      throw const MlsAuthenticationException(
        '聊天许可身份已变化',
        code: 'identityChanged',
      );
    }
    if (session == null ||
        session.cidNumber != expectedCidNumber ||
        session.bindRev != expectedBindingRevision ||
        session.accountId != expectedAccountId ||
        session.deviceId != deviceId) {
      throw const SquareApiException('聊天会话与当前用户绑定不一致');
    }
    await _sessionAuthentication.requireCurrent(identity);
    final access = await _client.fetchChatAccess(
      session: session,
      deviceId: deviceId,
    );
    await _sessionAuthentication.requireCurrent(identity);
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
    } on Object catch (error) {
      // 未知Error同样失败关闭，不能穿透到会员页面或输出原始异常。
      return SquareSessionResolution.fromError(error);
    }
  }

  /// Worker 明确返回 401 后清除当前身份账户的本地缓存并重新握手一次。
  ///
  /// 仅供已经收到未授权响应的前台请求调用；普通首次加载仍走 [ensureSession] 的缓存与
  /// in-flight 去重，避免把每次页面进入都放大成新的会话请求。
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
