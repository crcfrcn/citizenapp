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

  static AdminAccountState? decodePersonal(
    Uint8List personalAccount,
    Uint8List data,
  ) {
    if (data.length < 5) return null;
    var offset = 0;
    // 链端 AdminAccount 前导字段 cid_number: BoundedVec<u8>(个人多签为空);仅消费字节。
    final (cidLen, cidLenSize) = readCompactU32(data, offset);
    offset += cidLenSize + cidLen;
    if (offset + 5 > data.length) return null;
    final orgCode = String.fromCharCodes(
      data.sublist(offset, offset + 4).where((b) => b != 0),
    );
    offset += 4;
    final kind = data[offset++];
    final decodedAdmins = InstitutionRoleStorageCodec.decodeAdminVector(
      data,
      offset,
    );
    if (decodedAdmins == null) return null;
    final admins = decodedAdmins.$1;
    offset = decodedAdmins.$2;
    if (offset + 32 + 4 + 4 + 1 != data.length) return null;
    final creatorAccount = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;
    final createdAt = _readU32(data, offset);
    offset += 4;
    final updatedAt = _readU32(data, offset);
    offset += 4;
    final status = data[offset];
    if (status > 2) return null;
    return AdminAccountState(
      accountId: citizenAccountIdFromBytes(personalAccount),
      orgCode: orgCode,
      kind: kind,
      admins: admins,
      // runtime 的各管理员 `AdminAccounts` 不保存阈值；
      // 个人多签阈值仍从 internal-vote 的个人阈值 storage 补齐。
      threshold: 0,
      personalCreatorAccountId: creatorAccount,
      personalCreatedAt: createdAt,
      personalUpdatedAt: updatedAt,
      personalStatus: status,
    );
  }

  static (int, int) readCompactU32(Uint8List data, int offset) {
    final decoded = CitizenScale.readCompact(data, offset);
    if (decoded.$1 > 0xffffffff) {
      throw const FormatException('Compact 长度超出 u32');
    }
    return decoded;
  }

  static int _readU32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();
}
