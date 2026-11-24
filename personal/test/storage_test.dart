// 个人持久化快照边界回归，不以缓存代替链上授权。
import 'dart:convert';
import 'package:citizen_personal/members.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_personal/storage.dart';

void main() {
  test('详情快照保留成员账户、备注姓名、同步时间和未知阈值', () {
    final value = MultisigLocalDetailSnapshot(
      groupState: 'active',
      syncedAt: 123,
      admins: [
        PersonalMember(
          accountId: '0x${'11' * 32}',
          familyName: '甲',
          givenName: '乙',
        ),
      ],
    );
    final encoded = value.toJson();
    expect(encoded['threshold'], isNull);
    final restored = MultisigLocalDetailSnapshot.fromJsonString(
      jsonEncode(encoded),
    )!;
    expect(restored.groupState, 'active');
    expect(restored.syncedAt, 123);
    expect(restored.threshold, isNull);
    expect(restored.admins.single.accountId, '0x${'11' * 32}');
    expect((encoded['admins'] as List).single.keys.toSet(), {
      'account_id',
      'family_name',
      'given_name',
    });
    expect(restored.admins.single.familyName, '甲');
    expect(restored.admins.single.givenName, '乙');
  });
  test('旧CID字段不进入个人快照', () {
    final raw = jsonEncode({
      'group_state': 'active',
      'admins': [
        {
          'account_id': '0x${'11' * 32}',
          'cid_number': '',
          'family_name': '甲',
          'given_name': '乙',
        },
      ],
    });
    expect(MultisigLocalDetailSnapshot.fromJsonString(raw), isNull);
  });
  test('缺失或损坏的快照不生成默认成员权限', () {
    for (final raw in <String?>[
      null,
      '',
      '{',
      '[]',
      '{"admins":null}',
      '{"admins":[1]}',
    ]) {
      expect(MultisigLocalDetailSnapshot.fromJsonString(raw), isNull);
    }
  });
}
