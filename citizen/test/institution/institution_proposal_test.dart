// 核对Runtime真实编码金标、四类详情及未知/损坏数据的拒绝边界。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_models.dart';
import 'package:citizen_citizen/institution/institution_proposal_codec.dart';

Uint8List raw(Map<String, dynamic> row) {
  final text = row['encoded_hex'] as String;
  return Uint8List.fromList([
    for (var i = 0; i < text.length; i += 2)
      int.parse(text.substring(i, i + 2), radix: 16),
  ]);
}

void main() {
  final source =
      jsonDecode(
            File(
              'citizen/test/institution/institution_proposals.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (source['cases'] as List).cast<Map<String, dynamic>>();
  test('八个公私权管理载荷完整解码，保留原始内容及缓存回读', () {
    expect(cases, hasLength(8));
    for (final row in cases) {
      final bytes = raw(row),
          info = InstitutionProposalCodec.decode(BigInt.one, raw(row));
      expect(bytes.length, row['byte_length']);
      expect(info, isNotNull, reason: row['name'] as String);
      expect(info!.actorCidNumber, row['cid_number']);
      expect(info.rows, isNotEmpty);
      final saved =
          jsonDecode(jsonEncode(info.toJson())) as Map<String, dynamic>;
      final restored = InstitutionProposalInfo.fromJson(BigInt.one, saved);
      expect(restored?.toJson(), info.toJson());
      final values = info.rows.map((r) => r.value).join('；');
      if (row['action'] == 3) {
        for (final value in [
          '财务岗',
          'R_CONFIG',
          '新名称',
          'R_DELETE',
          '日序100—200',
          'CN220-CTZN2-198805200-2026',
        ]) {
          expect(values, contains(value));
        }
      }
      if (row['action'] == 5) {
        expect(values, contains('multisig / 0 / 发起'));
        expect(values, contains('multisig / 0 / 表决'));
        expect(values, contains('原阈值批准'));
        expect(values, contains('09' * 32));
      }
      if (row['action'] == 2) expect(info, isA<CloseProposalInfo>());
    }
  });
  test('每一截断位置、尾随及错误命名空间都拒绝，不降级成关闭', () {
    for (final row in cases) {
      final bytes = raw(row);
      for (var length = 0; length < bytes.length; length++) {
        expect(
          InstitutionProposalCodec.decode(
            BigInt.one,
            Uint8List.sublistView(bytes, 0, length),
          ),
          isNull,
        );
      }
      expect(
        InstitutionProposalCodec.decode(
          BigInt.one,
          Uint8List.fromList([...bytes, 0]),
        ),
        isNull,
      );
      final bad = Uint8List.fromList(bytes),
          offset = CitizenScale.readCompact(bytes, 0).$2;
      bad[offset] = 0;
      expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
      bad.setAll(0, bytes);
      bad[offset + 8] = 255;
      expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    }
  });
  test('治理未知枚举和机构码错配拒绝；缓存未知类型不成为权限', () {
    final bytes = raw(cases.firstWhere((r) => r['action'] == 3));
    final offset = CitizenScale.readCompact(bytes, 0).$2;
    final bad = Uint8List.fromList(bytes);
    bad[offset + 9] = 0;
    expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    bad.setAll(0, bytes);
    var cursor = offset + 13;
    final (length, size) = CitizenScale.readCompact(bytes, cursor);
    cursor += length + size;
    cursor += CitizenScale.readCompact(bytes, cursor).$2;
    bad[cursor] = 4;
    expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    expect(
      InstitutionProposalInfo.fromJson(BigInt.one, {
        'kind': 'unknown',
        'actor_cid_number': 'somewhere',
      }),
      isNull,
    );
    expect(
      InstitutionProposalInfo.fromJson(BigInt.one, {
        'kind': 'institution_change',
        'action': 5,
        'actor_cid_number': 'somewhere',
        'rows': [
          {'label': '权限', 'value': 1, 'copyable': true},
        ],
      }),
      isNull,
    );
  });
}
