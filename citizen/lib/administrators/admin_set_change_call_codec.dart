import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';

import 'dart:typed_data';

import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';

class PersonalAdminsChangeCallCodec {
  PersonalAdminsChangeCallCodec._();

  static Future<Uint8List> build({
    required CitizenCallBuilder buildCall,
    required String orgCode,
    required int adminKind,
    required Uint8List accountId,
    required List<AdminPerson> admins,
    required int newThreshold,
  }) {
    if (accountId.length != 32) {
      throw ArgumentError('accountId 必须为 32 字节');
    }
    if (orgCode != 'PMUL' || adminKind != 2) {
      throw ArgumentError('机构管理员由 entity 任职结果管理；本调用只允许个人多签');
    }
    if (newThreshold <= 0) {
      throw ArgumentError('newThreshold 必须大于 0');
    }
    final encodedAdmins = <List<Object>>[];
    for (final admin in admins) {
      final bytes = citizenAccountIdBytes(admin.accountId);
      if (bytes.length != 32) {
        throw ArgumentError('管理员公钥必须为 32 字节');
      }
      encodedAdmins.add([
        bytes,
        Uint8List.fromList(utf8.encode(admin.cidNumber)),
        _nameBytes(admin.familyName, 'family_name'),
        _nameBytes(admin.givenName, 'given_name'),
      ]);
    }
    return buildCall('PersonalAdmins', 'propose_admin_set_change', [
      Uint8List.fromList(InstitutionCodeLabel.codeBytes(orgCode)),
      accountId,
      encodedAdmins,
      newThreshold,
    ]);
  }

  static Uint8List _nameBytes(String value, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > 128) {
      throw ArgumentError('$field 长度必须在 1..=128 字节');
    }
    return Uint8List.fromList(bytes);
  }
}
