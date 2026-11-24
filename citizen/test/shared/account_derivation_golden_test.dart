// 以链端黄金向量逐字节核对App统一账户派生。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/account_derivation.dart';

const _fixturePath = 'citizen/test/shared/account_derive_vectors.json';

void main() {
  final file = File(_fixturePath);
  if (!file.existsSync()) throw StateError('账户派生金标缺失：$_fixturePath');

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final int ss58 = root['ss58_format'] as int;
  final vectors = (root['vectors'] as List).cast<Map<String, dynamic>>();

  group('账户派生金标向量(链端 ↔ Dart 逐字节对齐)', () {
    test('fixture 域常量与本端 _domain 一致', () {
      // 域已改名 GMB(ADR-024 Tier 3),fixture 与 _domain 同步为 GMB。
      expect(root['domain'], 'GMB');
      expect(ss58, citizenSs58Prefix);
    });

    for (final v in vectors) {
      final kind = v['kind'] as String;
      final expectedHex = v['account_id'] as String;
      final label = v['account_name'] != null
          ? '$kind / ${v['account_name']}'
          : kind;

      test('$label → $expectedHex', () {
        final actual = _deriveForVector(v);
        expect(citizenAccountIdFromBytes(actual), expectedHex);
      });
    }
  });
}

Uint8List _deriveForVector(Map<String, dynamic> v) {
  final kind = v['kind'] as String;
  switch (kind) {
    case 'InstitutionMain':
      return deriveInstitutionMainAccountId(v['cid_number'] as String);
    case 'InstitutionFee':
      return deriveInstitutionFeeAccountId(v['cid_number'] as String);
    case 'InstitutionStake':
      return deriveAccountId(
        opTag: kOpStake,
        payload: utf8.encode(v['cid_number'] as String),
      );
    case 'InstitutionSafetyFund':
      return deriveAccountId(
        opTag: kOpSafetyFund,
        payload: utf8.encode(v['cid_number'] as String),
      );
    case 'InstitutionHe':
      return deriveAccountId(
        opTag: kOpHe,
        payload: utf8.encode(v['cid_number'] as String),
      );
    case 'InstitutionClearing':
      return deriveInstitutionClearingAccountId(v['cid_number'] as String);
    case 'InstitutionNamed':
      return deriveInstitutionCustomAccountId(
        v['cid_number'] as String,
        v['account_name'] as String,
      );
    default:
      fail('未知金标向量 kind: $kind');
  }
}
