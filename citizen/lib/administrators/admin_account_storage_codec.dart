// 分类管理员模块 `AdminAccounts` 的严格 SCALE 解码器。
//
// - PublicAdmins / PrivateAdmins: key=CID，value=institution_code + admins。
// - PersonalAdmins: key=personal_account，value=个人多签 AdminAccount 完整结构。
//
// 机构 CID 只存在 storage key，机构 value 不再保存 CID、kind、生命周期或创建资料。

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
  static const int kindPersonal = 2;

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

  static Uint8List personalAdminStorageKey(
    Uint8List accountId, {
    required CitizenRuntimeContext runtime,
  }) {
    if (accountId.length != 32) {
      throw ArgumentError('accountId 必须为 32 字节');
    }
    return runtime.storageKey('PersonalAdmins', 'AdminAccounts', [accountId]);
  }

  /// [kind] 必须由扫描到的 pallet 名确定，不能再从机构 value 猜测。
  static AdminAccountStorageDecoded? tryDecode(
    Uint8List bytes, {
    required int kind,
  }) {
    try {
      if (kind != kindPersonal) {
        final decoded = InstitutionRoleStorageCodec.decodeAdmins(bytes);
        if (decoded == null) return null;
        return AdminAccountStorageDecoded(
          orgCode: decoded.orgCode,
          kind: kind,
          admins: decoded.admins,
        );
      }

      var offset = 0;
      final (cidLen, cidLenBytes) = _decodeCompactU32(bytes, offset);
      offset += cidLenBytes + cidLen;
      if (offset + 5 > bytes.length) return null;
      final orgCode = InstitutionCodeLabel.codeToString(
        bytes.sublist(offset, offset + 4),
      );
      offset += 4;
      final storedKind = bytes[offset++];
      if (storedKind != kindPersonal) return null;

      final decodedAdmins = InstitutionRoleStorageCodec.decodeAdminVector(
        bytes,
        offset,
      );
      if (decodedAdmins == null) return null;
      final admins = decodedAdmins.$1;
      offset = decodedAdmins.$2;
      // 个人多签 value 后续仍有 creator/区块号/status；扫描只消费 admins。
      if (offset + 32 + 4 + 4 + 1 != bytes.length) return null;
      return AdminAccountStorageDecoded(
        orgCode: orgCode,
        kind: kindPersonal,
        admins: admins,
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

  /// PersonalAdmins 的 key 仍是 32B personal_account。
  static Uint8List? extractPersonalAccountFromKey(Uint8List storageKey) {
    const expectedLength = 32 + 16 + 32;
    if (storageKey.length != expectedLength) return null;
    return Uint8List.fromList(storageKey.sublist(storageKey.length - 32));
  }

  static (int, int) _decodeCompactU32(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('不支持的 Compact 编码');
    return result;
  }
}
