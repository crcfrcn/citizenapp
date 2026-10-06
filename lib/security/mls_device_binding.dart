import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';

/// 已单独授权的登记载荷；SCALE与GMB摘要只使用CitizenSDK原语。
Future<Uint8List> encodeMlsDeviceBindingPayload({
  required String cidNumber,
  required int bindingRevision,
  required String accountId,
  required String publicKey,
  required int issuedAtMillis,
}) async {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(cidNumber) ||
      bindingRevision <= 0 ||
      bindingRevision > 9007199254740991 ||
      !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId) ||
      !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey) ||
      issuedAtMillis <= 0 ||
      issuedAtMillis > 9007199254740991) {
    throw const FormatException('MLS设备登记载荷无效');
  }
  return Uint8List.fromList([
    ...await CitizenSigning.encodePayload(
      CitizenSigningPayload.scaleString(cidNumber),
    ),
    ...await CitizenSigning.encodePayload(
      CitizenSigningPayload.u64Le(BigInt.from(bindingRevision)),
    ),
    ...await CitizenSigning.encodePayload(
      CitizenSigningPayload.scaleString(accountId),
    ),
    ...await CitizenSigning.encodePayload(
      CitizenSigningPayload.scaleString(publicKey),
    ),
    ...await CitizenSigning.encodePayload(
      CitizenSigningPayload.u64Le(BigInt.from(issuedAtMillis)),
    ),
  ]);
}

Future<Uint8List> buildMlsDeviceBindingSigningMessage(
  String cidNumber,
  int bindingRevision,
  String accountId,
  String publicKey,
  int issuedAt,
) async => CitizenSigning.encodePayload(
  CitizenSigningPayload.message(
    opTag: kOpSignMlsDeviceBind,
    scalePayload: await encodeMlsDeviceBindingPayload(
      cidNumber: cidNumber,
      bindingRevision: bindingRevision,
      accountId: accountId,
      publicKey: publicKey,
      issuedAtMillis: issuedAt,
    ),
  ),
);
