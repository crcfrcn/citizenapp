import 'package:citizen_account/identity/registration_models.dart';
import 'package:citizen_account/identity/public_identity_store.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/mls_authentication.dart';
import 'package:citizen_account/identity/mls_device_binding.dart';

/// 对设备绑定证明消息（`signing_message` 的 32 字节摘要）做 sr25519 主钥签名，
/// 返回 `0x` hex 签名。
typedef DeviceBindingSigner = Future<String> Function({
  required Uint8List payload,
  required Uint8List signingMessage,
  required String publicKey,
  required int issuedAtMillis,
});
typedef RegistrationCapabilityProvider =
    Future<RegistrationCapabilities?> Function(
      MlsAuthenticationIdentity identity,
    );

/// 只在明确的设备未登记响应后编排登记，钱包证明先持久保存。
class MlsDeviceRegistrar {
  MlsDeviceRegistrar({
    required MlsAuthenticationSource authentication,
    SquareApiClient? apiClient,
    RegistrationCapabilityProvider? registrationCapabilities,
    PublicIdentityRecordStore? proofStore,
  }) : _authentication = authentication,
       _api = apiClient ?? SquareApiClient(),
       _registrationCapabilities = registrationCapabilities,
       _proofStore = proofStore ?? SystemPublicIdentityRecordStore();

  final MlsAuthenticationSource _authentication;
  final SquareApiClient _api;
  final RegistrationCapabilityProvider? _registrationCapabilities;
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
    // 只复用当前设备的回执；不同公钥重新走原钱包签署，绝不借用旧签名。
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

    // 真人结果已在原CID交易之前保存；这里没有再次弹窗或Turnstile原始token。
    final capabilities = await _registrationCapabilities?.call(identity);
    await _authentication.requireCurrent(identity);
    await _api.registerMlsDevice(
      identity: identity,
      authentication: _authentication,
      issuedAt: issuedAt,
      bindingSignatureHex: signature,
      regId: capabilities?.regId,
      recoveryToken: capabilities?.recoveryToken,
    );
    await _authentication.requireCurrent(identity);
  }
}
