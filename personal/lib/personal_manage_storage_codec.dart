import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';

/// 个人多签账户生命周期快照。
///
/// `PersonalManage::PersonalAccounts` 只保存个人账户生命周期元数据；
/// 管理员真源在 `PersonalAdmins::AdminAccounts`，动态阈值真源在 `InternalVote`。
class PersonalManageAccountSnapshot {
  const PersonalManageAccountSnapshot({
    required this.creatorAccount,
    required this.accountName,
    required this.createdAt,
    required this.statusByte,
  });

  final String creatorAccount;
  final Uint8List accountName;
  final int createdAt;
  final int statusByte;
}

/// 管理员与阈值快照。
class PersonalManageAdminSnapshot {
  const PersonalManageAdminSnapshot({
    required this.orgCode,
    required this.adminsLen,
    required this.admins,
  });

  final String orgCode;
  final int adminsLen;
  final List<AdminPerson> admins;
}

/// PersonalManage 专属 storage codec。
class PersonalManageStorageCodec {
  PersonalManageStorageCodec._();

  static Uint8List personalAccountsKey(CitizenRuntimeContext runtime, String accountId) =>
      runtime.storageKey('PersonalManage', 'PersonalAccounts', [citizenAccountIdBytes(accountId)]);

  static Uint8List adminAccountKey(CitizenRuntimeContext runtime, Uint8List accountId) =>
      runtime.storageKey('PersonalAdmins', 'AdminAccounts', [accountId]);

  static Uint8List activePersonalThresholdKey(
    CitizenRuntimeContext runtime,
    Uint8List personalAccount,
  ) => runtime.storageKey('InternalVote', 'ActivePersonalThresholds', [personalAccount]);

  static PersonalManageAccountSnapshot? decodePersonalAccount(Uint8List data) {
    if (data.length < 32 + 1 + 4 + 1) return null;
    var offset = 0;
    final creatorAccount = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;
    final accountName = readBoundedBytes(data, offset);
    if (accountName == null) return null;
    offset = accountName.nextOffset;
    if (offset + 4 + 1 > data.length) return null;
    final createdAt = readU32Le(data, offset);
    offset += 4;
    final statusByte = data[offset];
    return PersonalManageAccountSnapshot(
      creatorAccount: creatorAccount,
      accountName: accountName.value,
      createdAt: createdAt,
      statusByte: statusByte,
    );
  }

  static PersonalManageAdminSnapshot? decodeAdminAccount(Uint8List data) {
    // 链端 AdminAccount 前导 cid_number: BoundedVec<u8>(个人多签为空)+ institution_code[u8;4]
    // + kind: u8 = 至少 5 字节后才是 admins。
    if (data.length <= 5) return null;
    var offset = 0;
    // cid_number: BoundedVec<u8>(个人多签为空);仅消费字节。
    final (cidLen, cidLenSize) = readCompactU32(data, offset);
    offset += cidLenSize + cidLen;
    if (offset + 5 > data.length) return null;
    final orgCode = InstitutionCodeLabel.codeToString(
      data.sublist(offset, offset + 4),
    );
    offset += 4;
    offset++; // AdminAccountKind
    final decodedAdmins = InstitutionRoleStorageCodec.decodeAdminVector(
      data,
      offset,
    );
    if (decodedAdmins == null) return null;
    final admins = decodedAdmins.$1;
    offset = decodedAdmins.$2;
    // PersonalAdmins::AdminAccounts 不保存 threshold；
    // 后续字段是 creator/created_at/updated_at/status，阈值必须另查 InternalVote。
    if (offset + 32 + 4 + 4 + 1 != data.length) return null;
    return PersonalManageAdminSnapshot(
      orgCode: orgCode,
      adminsLen: admins.length,
      admins: admins,
    );
  }

  static int? decodeDynamicThreshold(Uint8List? data) {
    if (data == null || data.length < 4) return null;
    return readU32Le(data, 0);
  }

  static ({Uint8List value, int nextOffset})? readBoundedBytes(
    Uint8List data,
    int offset,
  ) {
    if (offset >= data.length) return null;
    final (len, lenSize) = readCompactU32(data, offset);
    offset += lenSize;
    if (offset + len > data.length) return null;
    return (
      value: Uint8List.fromList(data.sublist(offset, offset + len)),
      nextOffset: offset + len,
    );
  }

  static (int, int) readCompactU32(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('Compact<u32>长度超出范围');
    return result;
  }

  static int readU32Le(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();

  static String accountNameText(Uint8List bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
