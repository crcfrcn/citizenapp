// 验证管理员四字段、机构CID键及个人多签变更布局。

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_citizen/administrators/admin_account_storage_codec.dart';
import 'package:citizen_citizen/administrators/admin_account_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';

void main() {
  List<int> bytes(String text) => [
    (utf8.encode(text).length << 2),
    ...utf8.encode(text),
  ];
  List<int> code(String value) => [
    ...value.codeUnits,
    ...List.filled(4 - value.length, 0),
  ];
  List<int> publicAdmin(
    String citizenCid,
    String familyName,
    String givenName,
    int accountByte,
  ) => [
    ...List.filled(32, accountByte),
    ...bytes(citizenCid),
    ...bytes(familyName),
    ...bytes(givenName),
  ];

  test('公权机构 AdminAccounts 严格解码管理员四字段', () {
    final value = Uint8List.fromList([
      ...code('CGOV'),
      8,
      ...publicAdmin('CN220-CTZN2-198805200-2026', '张', '三', 1),
      ...publicAdmin('', '', '', 2),
    ]);
    final decoded = AdminAccountCodec.decodeInstitution(
      cidNumber: 'CID-1',
      data: value,
      institutionKind: 0,
    )!;
    expect(decoded.admins.map((admin) => admin.accountId), [
      '0x${'01' * 32}',
      '0x${'02' * 32}',
    ]);
    expect(decoded.cidNumber, 'CID-1');
    expect(decoded.isActive, isTrue);
    expect(decoded.admins.first.cidNumber, 'CN220-CTZN2-198805200-2026');
    expect(decoded.admins.last.cidNumber, isEmpty);
    expect(decoded.admins.last.familyName, isEmpty);
  });

  test('机构管理员 storage key 以 CID 为唯一 key', () async {
    const cidNumber = 'GD001-CGOV0-123456789-2026';
    final runtime = await CitizenSdkTestFixture.runtimeContext(
      CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      ),
    );
    final key = AdminAccountStorageCodec.institutionAdminStorageKey(
      cidNumber,
      runtime: runtime,
      orgCode: 'CGOV',
    );
    expect(key.length, 32 + 16 + 1 + utf8.encode(cidNumber).length);
    expect(key.sublist(49), utf8.encode(cidNumber));
  });
}
