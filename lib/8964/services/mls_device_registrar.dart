import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/security/public_identity_store.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/security/mls_device_binding.dart';

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
    required int bindingRevision,
    required String accountId,
    required DeviceBindingSigner signBinding,
    int? issuedAtMillis,
  }) {
    final key = deviceRegistrationProofKey(
      cidNumber,
      bindingRevision,
      accountId,
    );
    return _flights.putIfAbsent(
      key,
      () =>
          _register(
            cidNumber: cidNumber,
            bindingRevision: bindingRevision,
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
    required int bindingRevision,
    required String accountId,
    required DeviceBindingSigner signBinding,
    int? issuedAtMillis,
  }) async {
    final identity = await _authentication.readIdentity();
    if (identity.cidNumber != cidNumber ||
        identity.bindingRevision != bindingRevision ||
        identity.accountId != accountId) {
      throw const MlsAuthenticationException(
        '登记归属与当前MLS身份不一致',
        code: 'identityChanged',
      );
    }
    final proofKey = deviceRegistrationProofKey(
      cidNumber,
      bindingRevision,
      accountId,
    );
    final rawProof = await _proofStore.read(proofKey);
    await _authentication.requireCurrent(identity);
    late final int issuedAt;
    late final String signature;
    if (rawProof != null) {
      try {
        final proof = jsonDecode(rawProof);
        const fields = {
          'cid_number',
          'binding_revision',
          'account_id',
          'public_key',
          'issued_at',
          'signature',
        };
        if (proof is! Map<String, dynamic> ||
            proof.length != fields.length ||
            !proof.keys.every(fields.contains) ||
            proof['cid_number'] != cidNumber ||
            proof['binding_revision'] != bindingRevision ||
            proof['account_id'] != accountId ||
            proof['public_key'] != identity.publicKey ||
            proof['issued_at'] is! int ||
            proof['issued_at'] <= 0 ||
            proof['issued_at'] > 9007199254740991 ||
            proof['signature'] is! String ||
            !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(proof['signature'])) {
          throw const FormatException();
        }
        issuedAt = proof['issued_at'] as int;
        signature = proof['signature'] as String;
      } on FormatException {
        throw const SquareApiException(
          '本机MLS登记授权不可用',
          errorCode: 'device_proof_invalid',
        );
      }
    } else {
      issuedAt = issuedAtMillis ?? DateTime.now().millisecondsSinceEpoch;
      final payload = await encodeMlsDeviceBindingPayload(
        cidNumber: cidNumber,
        bindingRevision: bindingRevision,
        accountId: accountId,
        publicKey: identity.publicKey,
        issuedAtMillis: issuedAt,
      );
      final message = await buildMlsDeviceBindingSigningMessage(
        cidNumber,
        bindingRevision,
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
        'binding_revision': bindingRevision,
        'account_id': accountId,
        'public_key': identity.publicKey,
        'issued_at': issuedAt,
        'signature': signature,
      });
      if (!await _proofStore.compareAndSet(
            proofKey,
            expected: null,
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
      enrollmentId: capabilities?.enrollmentId,
      recoveryToken: capabilities?.recoveryToken,
    );
    await _authentication.requireCurrent(identity);
  }
}
