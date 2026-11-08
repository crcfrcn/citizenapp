import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_user/profile/square_action_payload.dart';

enum SquareActionSignError { invalidRequest, undecodable, accountNotLocal }

class SquareActionSignException implements Exception {
  const SquareActionSignException(this.error, this.message);

  final SquareActionSignError error;
  final String message;

  @override
  String toString() => message;
}

/// 扫到的广场账户动作签名请求，经校验/解码/定位钱包后的待签态。
class SquareActionSignPrep {
  const SquareActionSignPrep({
    required this.request,
    required this.actionLabel,
    required this.decoded,
    required this.account,
  });

  final CitizenQrDocument request;
  final String actionLabel;
  final SquareActionPayload decoded;
  final CitizenWalletStateAccount account;
}

/// 广场账户动作「签名响应方」（官网无私钥，CitizenApp 扫一扫代签）。
///
/// 流程：消费 SDK 签名请求 → 业务解码 → 按签名账户定位本机钱包
/// → 用户核对动作 → **account_id 主钥**对 signing_message(0x1D) 签名（生物识别）→ 出 signResponse。
class SquareActionSignService {
  SquareActionSignService({required CitizenSdk qr}) : _qr = qr;

  final CitizenSdk _qr;

  /// 从 SDK 已解析的请求读取业务字段并定位本机钱包。
  Future<SquareActionSignPrep> prepare(
    CitizenQrDocument request,
    CitizenSdk? wallet, {
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    CitizenWalletStateAccount? requiredAccount,
  }) async {
    final payload = request.reviewPayload;
    final signer = request.signerAccountId;
    if (request.kind != CitizenQrKind.signRequest ||
        request.action != CitizenQrActions.squareAccountAction ||
        payload == null ||
        signer == null) {
      throw const SquareActionSignException(
        SquareActionSignError.invalidRequest,
        '该动作不属于 CitizenApp 业务二维码',
      );
    }
    const actionLabel = '广场账户动作签名';
    final decoded = decodeSquareActionPayload(
      '0x${payload.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    );
    final reviewFields = decoded?.reviewFields;
    if (decoded == null || reviewFields == null) {
      throw const SquareActionSignException(
        SquareActionSignError.undecodable,
        '签名内容无法完整中文展示，已拒绝签名',
      );
    }
    final account =
        requiredAccount ??
        _findAccount(
          await (getWalletState ?? wallet!.getWalletState)().result,
          signer,
        );
    if (account == null || account.accountId != signer) {
      throw const SquareActionSignException(
        SquareActionSignError.accountNotLocal,
        '此签名请求的账户不在本机',
      );
    }
    return SquareActionSignPrep(
      request: request,
      actionLabel: actionLabel,
      decoded: decoded,
      account: account,
    );
  }

  /// 主钥签名（读硬件金库、弹生物识别）→ 构造 signResponse envelope JSON。
  Future<String> sign(
    SquareActionSignPrep prep,
    CitizenSdk? signing,
    BuildContext? context, {
    PayloadSigner? payloadSigner,
  }) async {
    final signBytes = await CitizenSdk.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignSquareAction,
        scalePayload: prep.request.reviewPayload!,
      ),
    );
    if (context != null && !context.mounted) {
      throw const SquareActionSignException(
        SquareActionSignError.invalidRequest,
        '当前签名页面已经关闭',
      );
    }
    final signature =
        await (payloadSigner ??
            ((id, payload, action, ctx) => signCitizenPayload(
              signing: signing!,
              context: ctx,
              accountId: id,
              payload: payload,
              action: action,
            )))(
          prep.account.accountId,
          signBytes,
          prep.request.action!,
          context,
        );
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
