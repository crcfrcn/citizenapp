// 以冻结字节验证三类管理员布局、数量和截断边界。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/administrators/admin_account_storage_codec.dart';

void main() {
  List<int> codeBytes(String code) {
    final out = List<int>.filled(4, 0);
    final raw = code.codeUnits;
    for (var i = 0; i < out.length && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
  }

  List<int> scaleBytes(String cid) {
    final raw = utf8.encode(cid);
    return [raw.length << 2, ...raw];
  }

  List<int> publicAdminBytes(
    String cidNumber,
    String familyName,
    String givenName,
    List<int> account,
  ) => [
    ...account,
    ...scaleBytes(cidNumber),
    ...scaleBytes(familyName),
    ...scaleBytes(givenName),
  ];

  group('tryDecode', () {
    test('成功解码 PublicInstitution(0 admins)', () {
      final bytes = Uint8List.fromList([...codeBytes('NRC'), 0]);
      final r = AdminAccountStorageCodec.tryDecode(
        bytes,
        kind: AdminAccountStorageCodec.kindPublicInstitution,
      )!;
      expect(r.orgCode, 'NRC');
      expect(r.kind, AdminAccountStorageCodec.kindPublicInstitution);
      expect(r.admins, isEmpty);
    });

    test('成功解码 PublicInstitution 含 2 个 admin', () {
      final a1 = List.filled(32, 0x44);
      final a2 = List.filled(32, 0x55);
      final bytes = Uint8List.fromList([
        ...codeBytes('CGOV'),
        0x08, // Compact(2)
        ...publicAdminBytes('CN220-CTZN2-198805200-2026', '', '', a1),
        ...publicAdminBytes('', '李', '四', a2),
      ]);
      final r = AdminAccountStorageCodec.tryDecode(
        bytes,
        kind: AdminAccountStorageCodec.kindPublicInstitution,
      )!;
      expect(r.orgCode, 'CGOV');
      expect(r.kind, AdminAccountStorageCodec.kindPublicInstitution);
      expect(r.admins.map((admin) => admin.accountId), [
        '0x${'44' * 32}',
        '0x${'55' * 32}',
      ]);
      expect(r.admins.first.cidNumber, 'CN220-CTZN2-198805200-2026');
      expect(r.admins.first.familyName, isEmpty);
      expect(r.admins.last.cidNumber, isEmpty);
    });

    test('admins 数量超过实际字节返回 null', () {
      final bytes = Uint8List.fromList([
        ...codeBytes('NRC'),
        0x08, // 声明 2 个 admin 但只给 1 个完整管理员的字节。
        ...publicAdminBytes('', '', '', List.filled(32, 0xCC)),
      ]);
      expect(
        AdminAccountStorageCodec.tryDecode(
          bytes,
          kind: AdminAccountStorageCodec.kindPublicInstitution,
        ),
        isNull,
      );
    });
  });

  group('storage key 主键提取', () {
    test('机构 storage key 提取 CID', () {
      const cid = 'GD001-CGOV0-123456789-2026';
      final key = Uint8List.fromList([
        ...List.filled(32, 0),
        ...List.filled(16, 1),
        ...scaleBytes(cid),
      ]);
      expect(AdminAccountStorageCodec.extractCidNumberFromKey(key), cid);
    });
  });
}
