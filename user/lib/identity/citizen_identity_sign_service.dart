import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:citizen_user/identity/voting_identity_payload.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';

class CitizenIdentitySignException implements Exception {
  const CitizenIdentitySignException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 公民身份签名的已校验待签态；三个扫码入口共用，避免页面各自实现协议。
class CitizenIdentitySignPrep {
  const CitizenIdentitySignPrep({
    required this.request,
    required this.actionLabel,
    required this.decoded,
    required this.account,
  });

  final CitizenQrDocument request;
  final String actionLabel;
  final VotingIdentityConsentPayload decoded;
  final CitizenWalletStateAccount account;
}

/// 公民签名统一服务：完整解码、请求/载荷/本机钱包三方公钥一致后才允许签名。
class CitizenIdentitySignService {
  CitizenIdentitySignService({required CitizenSdk qr}) : _qr = qr;
  final CitizenSdk _qr;

  Future<CitizenIdentitySignPrep> prepare(
    CitizenQrDocument request,
    CitizenSdk? wallet, {
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    CitizenWalletStateAccount? requiredAccount,
  }) async {
    final payload = request.reviewPayload;
    final signer = request.signerAccountId;
    if (request.kind != CitizenQrKind.signRequest ||
        request.action != CitizenQrActions.citizenIdentity ||
        payload == null ||
        signer == null) {
      throw const CitizenIdentitySignException('该二维码不是公民签名确认请求');
    }
    // 原确认页文案归App所有；协议与期限只由SDK验证。
    const actionLabel = '公民签名确认';
    final decoded = VotingIdentityConsentPayload.decode(payload);
    if (decoded == null) {
      throw const CitizenIdentitySignException('签名内容无法完整中文展示，已拒绝签名');
    }
    if (decoded.accountId != signer) {
      throw const CitizenIdentitySignException('身份载荷钱包与签名请求不一致');
    }
    final account =
        requiredAccount ??
        _findAccount(
          await (getWalletState ?? wallet!.getWalletState)().result,
          signer,
        );
    if (account == null || account.accountId != signer) {
      throw const CitizenIdentitySignException('此签名请求的账户不在本机');
    }
    return CitizenIdentitySignPrep(
      request: request,
      actionLabel: actionLabel,
      decoded: decoded,
      account: account,
    );
  }

  Future<String> sign(
    CitizenIdentitySignPrep prep,
    CitizenSdk? signing,
    BuildContext? context, {
    PayloadSigner? payloadSigner,
  }) async {
    final bytes = await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignCitizenIdentity,
        scalePayload: prep.request.reviewPayload!,
      ),
    );
    if (context != null && !context.mounted) {
      throw const CitizenIdentitySignException('当前签名页面已经关闭');
    }
    final signature =
        await (payloadSigner ??
            ((id, payload, action, ctx) => signCitizenPayload(
              signing: signing!,
              context: ctx,
              accountId: id,
              payload: payload,
              action: action,
            )))(prep.account.accountId, bytes, prep.request.action!, context);
    return (await _qr.encodeDocument(
      CitizenQrContent.signResponse(
        requestId: prep.request.requestId!,
        expiresAt: BigInt.from(prep.request.expiresAt!),
        signerAccountId: prep.account.accountId,
        signature: signature,
      ),
    )).canonicalText;
  }

  static CitizenWalletStateAccount? _findAccount(
    CitizenWalletState state,
    String accountId,
  ) {
    for (final account in state.accounts) {
      if (account.accountId == accountId) {
        return account;
      }
    }
    return null;
  }
}
