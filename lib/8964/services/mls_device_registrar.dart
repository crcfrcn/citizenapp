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
typedef TurnstileTokenProvider = Future<String?> Function();

const _turnstileTokenMinLength = 20;
const _turnstileTokenMaxLength = 2048;

/// 等待根导航器进入可展示状态后，只展示一次设备绑定验证页。
///
/// 冷启动时会话握手可能早于 `MaterialApp` 首帧；此前直接返回空 token 会让正式
/// Worker 必然以 `turnstile_required` 拒绝 iOS 新设备登记。这里仅等待前台 UI，
/// 不重试验证、不在后台伪造 token，也不把取消当成功。
Future<String> acquireDeviceBindingTurnstileToken({
  required bool Function() isUiReady,
  required TurnstileTokenProvider present,
  Duration readyTimeout = const Duration(seconds: 15),
  Duration pollInterval = const Duration(milliseconds: 50),
  Future<void> Function(Duration duration)? delay,
}) async {
  final wait = delay ?? Future<void>.delayed;
  final deadline = DateTime.now().add(readyTimeout);
  while (!isUiReady()) {
    if (!DateTime.now().isBefore(deadline)) {
      throw const SquareApiException(
        '设备安全验证界面尚未就绪，请稍后重试',
        errorCode: 'turnstile_ui_unavailable',
      );
    }
    await wait(pollInterval);
  }

  final token = await present();
  if (token == null || token.isEmpty) {
    throw const SquareApiException(
      '设备安全验证已取消',
      errorCode: 'turnstile_cancelled',
    );
  }
  if (token.length < _turnstileTokenMinLength ||
      token.length > _turnstileTokenMaxLength) {
    throw const SquareApiException(
      '设备安全验证结果不合法',
      errorCode: 'turnstile_token_invalid',
    );
  }
  return token;
}

/// 只在明确的设备未登记响应后编排登记，钱包证明先持久保存。
class MlsDeviceRegistrar {
  MlsDeviceRegistrar({
    required MlsAuthenticationSource authentication,
    SquareApiClient? apiClient,
    TurnstileTokenProvider? turnstileToken,
    PublicIdentityRecordStore? proofStore,
  }) : _authentication = authentication,
       _api = apiClient ?? SquareApiClient(),
       _turnstileToken = turnstileToken,
       _proofStore = proofStore ?? SystemPublicIdentityRecordStore();

  final MlsAuthenticationSource _authentication;
  final SquareApiClient _api;
  final TurnstileTokenProvider? _turnstileToken;
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

    Future<String> token() async {
      final provider = _turnstileToken;
      if (provider == null) {
        throw const SquareApiException(
          '设备安全验证未配置',
          errorCode: 'turnstile_ui_unavailable',
        );
      }
      final value = await provider();
      await _authentication.requireCurrent(identity);
      if (value == null ||
          value.length < _turnstileTokenMinLength ||
          value.length > _turnstileTokenMaxLength) {
        throw const SquareApiException(
          '设备安全验证未完成',
          errorCode: 'turnstile_token_invalid',
        );
      }
      return value;
    }

    Future<void> submit(String? turnstile) => _api.registerMlsDevice(
      identity: identity,
      authentication: _authentication,
      issuedAt: issuedAt,
      bindingSignatureHex: signature,
      turnstileToken: turnstile,
    );

    if (rawProof == null) {
      await submit(await token());
    } else {
      // 相同已登记回执无需重复真人验证；未落库或更新必须按服务端结果取得新token。
      try {
        await submit(null);
      } on SquareApiException catch (error) {
        if (error.errorCode != 'turnstile_required') rethrow;
        await submit(await token());
      }
    }
    await _authentication.requireCurrent(identity);
  }
}
