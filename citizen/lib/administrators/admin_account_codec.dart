// 解码管理员记录及账户资料，区分名册与独立阈值。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:typed_data';

import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';

class AdminAccountCodec {
  AdminAccountCodec._();

  static AdminAccountState? decodeInstitution({
    required String cidNumber,
    required Uint8List data,
    required int institutionKind,
  }) {
    final decoded = InstitutionRoleStorageCodec.decodeAdmins(data);
    if (decoded == null) return null;
    return AdminAccountState(
      cidNumber: cidNumber,
      orgCode: decoded.orgCode,
      kind: institutionKind,
      admins: decoded.admins,
      threshold: 0,
    );
  }

  static (int, int) readCompactU32(Uint8List data, int offset) {
    final decoded = CitizenScale.readCompact(data, offset);
    if (decoded.$1 > 0xffffffff) {
      throw const FormatException('Compact 长度超出 u32');
    }
    return decoded;
  }
}
