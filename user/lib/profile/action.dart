// 编解码资料账户动作授权并审阅、准备签名响应。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:citizen_scanner/sign.dart';

// 解码广场账户动作签名载荷，并生成独立审阅字段。

/// 广场账户动作签名 payload（两色内容核对用）。
///
/// 布局须与 Worker `user/action_challenge.buildActionScalePayload` 逐字节一致：
///   scaleString(action) ‖ scaleString(account_id) ‖ scaleString(challengeId)
///   [‖ scaleString(context/level)] ‖ u64_le(expires_at)
/// 其中 context 仅在 action == 'subscribe_membership' 时存在（= 会员等级）。
class SquareActionPayload {
  const SquareActionPayload({
    required this.action,
    required this.accountId,
    required this.challengeId,
    required this.expiresAt,
    this.context,
  });

  final String action;
  final String accountId;
  final String challengeId;
  final int expiresAt;

  /// 动作专属绑定字段（subscribe_membership = 会员等级）。
  final String? context;

  /// registry 镜像中文动作名。未命中返回 null,签名入口必须红色拒绝。
  String? get actionTypeLabel => _squareActionTypeLabels[action];

  /// 用户确认页展示字段。字段名缺中文时返回 null,调用方必须拒绝签名。
  List<SquareReviewField>? get reviewFields {
    final actionType = actionTypeLabel;
    if (actionType == null) return null;
    final fields = <SquareReviewField>[];
    if (!_appendField(fields, 'action_type', actionType)) return null;
    if (!_appendField(fields, 'account_id', accountId)) return null;
    if (!_appendField(fields, 'challenge_id', challengeId)) return null;
    if (context != null &&
        !_appendField(fields, 'membership_level', context!)) {
      return null;
    }
    if (!_appendField(fields, 'expires_at', _formatExpiresAt(expiresAt))) {
      return null;
    }
    return fields;
  }
}

/// 广场账户子动作中文名，镜像 qr-protocol registry 的 square_account_action decoder。
const Map<String, String> _squareActionTypeLabels = {
  'subscribe_membership': '订阅会员',
  'cancel_membership': '取消订阅',
  'delete_account': '注销用户',
};

class SquareReviewField {
  const SquareReviewField({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;
}

/// 解码 payloadHex。无法识别 / 布局不符 / 未知动作一律返回 null（调用方须禁止签名）。
SquareActionPayload? decodeSquareActionPayload(String payloadHex) {
  try {
    final bytes = _hexToBytes(payloadHex);
    var offset = 0;

    final (action, o1) = _readString(bytes, offset);
    offset = o1;
    if (!_squareActionTypeLabels.containsKey(action)) return null;

    final (accountId, o2) = _readString(bytes, offset);
    offset = o2;
    if (!isCitizenAccountId(accountId)) return null;
    final (challengeId, o3) = _readString(bytes, offset);
    offset = o3;

    String? context;
    if (action == 'subscribe_membership') {
      final (level, o4) = _readString(bytes, offset);
      context = level;
      offset = o4;
    }

    // 结尾必须正好剩 u64（8 字节）过期时间，多一分少一分都拒。
    if (bytes.length - offset != 8) return null;
    final expiresAt = _u64Le(bytes, offset);

    final decoded = SquareActionPayload(
      action: action,
      accountId: accountId,
      challengeId: challengeId,
      expiresAt: expiresAt,
      context: context,
    );
    if (decoded.reviewFields == null) return null;
    return decoded;
  } on Object {
    return null;
  }
}

bool _appendField(List<SquareReviewField> fields, String key, String value) {
  // 原确认页中文标签逐字保留；这是App展示资源，不属于SDK协议能力。
  final label = switch (key) {
    'action_type' => '操作类型',
    'account_id' => '账户',
    'challenge_id' => '挑战编号',
    'membership_level' => '会员等级',
    'expires_at' => '过期时间',
    _ => null,
  };
  if (label == null || label.isEmpty) return false;
  fields.add(SquareReviewField(key: key, label: label, value: value));
  return true;
}

String _formatExpiresAt(int value) {
  final millis = value > 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(millis).toLocal().toString();
}

(String, int) _readString(Uint8List bytes, int offset) {
  final (len, width) = CitizenScale.readCompact(bytes, offset);
  if (width > 4) throw const FormatException('SCALE compact big-integer 不支持');
  final next = offset + width;
  final end = next + len;
  final str = utf8.decode(bytes.sublist(next, end));
  return (str, end);
}

int _u64Le(Uint8List bytes, int offset) =>
    CitizenScale.readUnsigned(bytes, offset, 8).toSigned(64).toInt();

Uint8List _hexToBytes(String input) {
  final text = input.startsWith('0x') || input.startsWith('0X')
      ? input.substring(2)
      : input;
  if (text.length.isOdd) {
    throw const FormatException('hex 长度必须为偶数');
  }
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(text.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

// 解析并审阅账户动作请求，定位准确本机账户后生成签名响应。

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
