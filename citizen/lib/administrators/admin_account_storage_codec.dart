// 严格解码机构CID键对应的管理员存储布局。

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';

import 'package:citizen_sdk/citizen_sdk.dart';

class AdminAccountStorageDecoded {
  const AdminAccountStorageDecoded({
    required this.orgCode,
    required this.kind,
    required this.admins,
  });

  final String orgCode;
  final int kind;
  final List<AdminPerson> admins;
}

class AdminAccountStorageCodec {
  AdminAccountStorageCodec._();

  static const int kindPublicInstitution = 0;
  static const int kindPrivateInstitution = 1;

  static Uint8List institutionAdminStorageKey(
    String cidNumber, {
    required CitizenRuntimeContext runtime,
    required String orgCode,
    int? adminKind,
  }) {
    final cidBytes = utf8.encode(cidNumber);
    if (cidBytes.isEmpty || cidBytes.length > 32) {
      throw ArgumentError('机构 cid_number 必须为 1..32 字节');
    }
    final pallet = adminKind == null
        ? InstitutionCodeLabel.adminAccountsPalletName(orgCode)
        : InstitutionCodeLabel.adminAccountsPalletNameForKind(adminKind);
    return runtime.storageKey(pallet, 'AdminAccounts', [
      Uint8List.fromList(cidBytes),
    ]);
  }

  /// [kind] 必须由扫描到的 pallet 名确定，不能再从机构 value 猜测。
  static AdminAccountStorageDecoded? tryDecode(
    Uint8List bytes, {
    required int kind,
  }) {
    try {
      final decoded = InstitutionRoleStorageCodec.decodeAdmins(bytes);
      if (decoded == null) return null;
      return AdminAccountStorageDecoded(
        orgCode: decoded.orgCode,
        kind: kind,
        admins: decoded.admins,
      );
    } catch (_) {
      return null;
    }
  }

  /// 从机构 AdminAccounts 完整 key 提取 CID。key 尾部是
  /// `blake2_128(cid_scale) + Compact<len> + cid_bytes`。
  static String? extractCidNumberFromKey(Uint8List storageKey) {
    const valueOffset = 32 + 16;
    if (storageKey.length <= valueOffset) return null;
    try {
      final (length, compactSize) = _decodeCompactU32(storageKey, valueOffset);
      final start = valueOffset + compactSize;
      if (length <= 0 || start + length != storageKey.length) return null;
      return utf8.decode(storageKey.sublist(start), allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  static (int, int) _decodeCompactU32(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('不支持的 Compact 编码');
    return result;
  }
}
