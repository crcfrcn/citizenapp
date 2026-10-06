import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;

typedef MlsAccountBinding = ({
  String cidNumber,
  String accountId,
  int bindingRevision,
});

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
    required this.bindingRevision,
    required this.deviceId,
    required this.publicKey,
  });
  final String cidNumber;
  final String accountId;
  final int bindingRevision;
  final String deviceId;
  final String publicKey;

  String get cacheKey =>
      jsonEncode([cidNumber, accountId, bindingRevision, deviceId]);
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(cidNumber) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey) ||
        deviceId != publicKey.substring(2) ||
        bindingRevision <= 0 ||
        bindingRevision > sdk.MlsAuthenticationRequest.maxJsonInteger) {
      throw const MlsAuthenticationException('MLS公开身份与当前绑定无效');
    }
  }
}

/// 测试只替换这个受限边界；生产没有任意字节签名回调。
abstract interface class MlsAuthenticationSource {
  Future<MlsAuthenticationIdentity> readIdentity();
  Future<void> requireCurrent(MlsAuthenticationIdentity identity);
  Future<sdk.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required sdk.MlsAuthenticationRequest request,
    required Map<String, dynamic> challenge,
  });
}

/// 前台会话与聊天复用唯一运行实例；认证不访问权益、网络或钱包。
class MlsAuthentication implements MlsAuthenticationSource {
  MlsAuthentication({
    required sdk.ChatSdk Function() runtime,
    required Future<MlsAccountBinding> Function() currentBinding,
  }) : _runtime = runtime,
       _currentBinding = currentBinding;
  final sdk.ChatSdk Function() _runtime;
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
    final local = await _runtime().readLocalMlsIdentity();
    final publicKey = local.publicKey;
    if (publicKey == null) throw const MlsAuthenticationException('MLS公开身份缺失');
    final identity = MlsAuthenticationIdentity(
      cidNumber: binding.cidNumber,
      accountId: binding.accountId,
      bindingRevision: binding.bindingRevision,
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
        binding.bindingRevision != identity.bindingRevision) {
      throw const MlsAuthenticationException(
        'MLS认证期间当前用户已变化',
        code: 'identityChanged',
      );
    }
  }

  @override
  Future<sdk.MlsAuthenticationProof> createProof({
    required MlsAuthenticationIdentity identity,
    required sdk.MlsAuthenticationRequest request,
    required Map<String, dynamic> challenge,
  }) async {
    validateMlsChallenge(identity, request, challenge);
    await requireCurrent(identity);
    final proof = await _runtime().createMlsAuthenticationProof(request);
    await requireCurrent(identity);
    validateMlsProofMatches(identity, request, challenge, proof);
    return proof;
  }
}

const mlsChallengeFields = {
  'ok',
  'user_id',
  'device_id',
  'public_key',
  'account_id',
  'binding_revision',
  'service_origin',
  'challenge',
  'expires_at_millis',
  'method',
  'request_target',
  'body_sha256',
};

void validateMlsChallenge(
  MlsAuthenticationIdentity identity,
  sdk.MlsAuthenticationRequest request,
  Map<String, dynamic> challenge,
) {
  identity.validate();
  request.validate();
  if (challenge.length != mlsChallengeFields.length ||
      !challenge.keys.every(mlsChallengeFields.contains) ||
      challenge['ok'] != true ||
      challenge['user_id'] != identity.cidNumber ||
      challenge['device_id'] != identity.deviceId ||
      challenge['public_key'] != identity.publicKey ||
      challenge['account_id'] != identity.accountId ||
      challenge['binding_revision'] != identity.bindingRevision ||
      challenge['service_origin'] != request.serviceOrigin ||
      challenge['challenge'] != request.challenge ||
      challenge['expires_at_millis'] != request.expiresAtMillis ||
      challenge['method'] != request.method ||
      challenge['request_target'] != request.requestTarget ||
      challenge['body_sha256'] != '0x${sha256.convert(request.bodyBytes)}') {
    throw const MlsAuthenticationException('MLS挑战与实际请求或当前身份不一致');
  }
}

void validateMlsProofMatches(
  MlsAuthenticationIdentity identity,
  sdk.MlsAuthenticationRequest request,
  Map<String, dynamic> challenge,
  sdk.MlsAuthenticationProof proof,
) {
  validateMlsChallenge(identity, request, challenge);
  final fields = proof.toJson();
  if (fields.length != 12 ||
      !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(proof.signature) ||
      !fields.entries.every(
        (entry) =>
            entry.key == 'signature' || challenge[entry.key] == entry.value,
      )) {
    throw const MlsAuthenticationException('MLS证明与固定挑战不一致');
  }
}
