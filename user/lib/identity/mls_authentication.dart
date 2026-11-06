import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:citizen_network/mls_authentication.dart' as mls;

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
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId) ||
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

const mlsChallengeFields = {
  'is_ok',
  'cid_number',
  'device_id',
  'public_key',
  'account_id',
  'bind_rev',
  'service_origin',
  'nonce_id',
  'expires_at',
  'http_method',
  'request_target',
  'body_hash',
};

void validateMlsChallenge(
  MlsAuthenticationIdentity identity,
  mls.MlsAuthenticationRequest request,
  Map<String, dynamic> challenge,
) {
  identity.validate();
  request.validate();
  if (challenge.length != mlsChallengeFields.length ||
      !challenge.keys.every(mlsChallengeFields.contains) ||
      challenge['is_ok'] != true ||
      challenge['cid_number'] != identity.cidNumber ||
      challenge['device_id'] != identity.deviceId ||
      challenge['public_key'] != identity.publicKey ||
      challenge['account_id'] != identity.accountId ||
      challenge['bind_rev'] != identity.bindRev ||
      challenge['service_origin'] != request.serviceOrigin ||
      challenge['nonce_id'] != request.nonceId ||
      challenge['expires_at'] != request.expiresAt ||
      challenge['http_method'] != request.httpMethod ||
      challenge['request_target'] != request.requestTarget ||
      challenge['body_hash'] != '0x${sha256.convert(request.bodyBytes)}') {
    throw const MlsAuthenticationException('MLS挑战与实际请求或当前身份不一致');
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
