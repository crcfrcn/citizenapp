// 验证账户派生及金标。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/data.dart' show deriveAccountId, deriveInstitutionAccountIdByName, deriveInstitutionClearingAccountId, deriveInstitutionCustomAccountId, deriveInstitutionFeeAccountId, deriveInstitutionMainAccountId, kOpHe, kOpSafetyFund, kOpStake;
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:citizen_citizen/data.dart' show isForbiddenAccountName, kReservedAccountNames, kReservedNameFcsf, kReservedNameFee, kReservedNameHe, kReservedNameMain, kReservedNameSafetyFund;

void main() {
  group('account_derivation_golden_test', _registerGolden);
  group('account_derivation_test', _registerAccounts);
}

// 以链端黄金向量逐字节核对App统一账户派生。

const _fixturePath = 'citizen/test/account.json';

void _registerGolden() {
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

// 验证各类制度账户名称路由、前缀和派生边界。

void _registerAccounts() {
  // 国家储委会 LN001-NRC0G-944805165-2026（T3/T4 新机构码 + GMB 域，单源 china_cb.rs）
  const nrcCid = 'LN001-NRC0G-944805165-2026';
  const nrcMain =
      '0x7c0c099ee4df10c5bd3f618ddf132b6d15390fa27d2c1369f70aeb6b5f3907e5';
  const nrcFee =
      '0xfabe3c11d600221ab4156ebaae3c00c8efae939442f4cd1a764cfdf62461a387';
  const nrcSafety =
      '0x4ac779852c175087c445c35efecfef3ce6e0232702152ea2283f0b5ec3952e53';
  const nrcHe =
      '0xda5544a52e806f6e5daeba3e2f0be134b218a9c348f2804b7e933deb9ed84e86';
  // 中枢省 ZS001-PRC0E-016974075-2026（T3/T4 新机构码 + GMB 域，单源 china_cb.rs）
  const prcCid = 'ZS001-PRC0E-016974075-2026';
  const prcMain =
      '0x54bad80b12cedbf7a1569fb96d18d90c4793949a356eb16c6304841af81001dd';
  const prcFee =
      '0x1f88202bf56fad5c7acfb08bc95322bb0149f8561cdb1f10a9331d46067b353a';
  // 联邦安全局与正式创世 FCSF 账户（链上 finalized 余额账户）。
  const fscCid = 'ZS001-FSC0W-434172688-2026';
  const fcsfAccountId =
      '0xc0e4ce3c11401ad661ae139081bbc797db51d0efe71df3ffb107f3dcb0064802';

  group('机构账户派生 golden 向量(链上注册表交叉验证)', () {
    test('国家储委会主账户 OP_MAIN', () {
      expect(
        citizenAccountIdFromBytes(deriveInstitutionMainAccountId(nrcCid)),
        nrcMain,
      );
    });

    test('国家储委会费用账户 OP_FEE', () {
      expect(
        citizenAccountIdFromBytes(deriveInstitutionFeeAccountId(nrcCid)),
        nrcFee,
      );
    });

    test('中枢省主账户 / 费用账户', () {
      expect(
        citizenAccountIdFromBytes(deriveInstitutionMainAccountId(prcCid)),
        prcMain,
      );
      expect(
        citizenAccountIdFromBytes(deriveInstitutionFeeAccountId(prcCid)),
        prcFee,
      );
    });

    test('名字路由:主账户/费用账户与显式派生一致', () {
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionAccountIdByName(nrcCid, kReservedNameMain),
        ),
        nrcMain,
      );
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionAccountIdByName(nrcCid, kReservedNameFee),
        ),
        nrcFee,
      );
    });

    test('名字路由:安全基金 OP_SAFETY / 两和基金 OP_HE', () {
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionAccountIdByName(nrcCid, kReservedNameSafetyFund),
        ),
        nrcSafety,
      );
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionAccountIdByName(nrcCid, kReservedNameHe),
        ),
        nrcHe,
      );
    });

    test('名字路由:联邦公民安全基金 OP_FCSF', () {
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionAccountIdByName(fscCid, kReservedNameFcsf),
        ),
        fcsfAccountId,
      );
      expect(kReservedAccountNames, contains(kReservedNameFcsf));
      expect(isForbiddenAccountName(kReservedNameFcsf), isTrue);
    });
  });

  group('自定义账户 OP_NAME(0x00)', () {
    test('payload 追加 account_name,与手工构造一致', () {
      const name = '业务专户A';
      final expected = Hasher.blake2b256.hash(
        Uint8List.fromList(<int>[
          ...utf8.encode('GMB'),
          0x00,
          2027 & 0xFF,
          (2027 >> 8) & 0xFF,
          ...utf8.encode(nrcCid),
          ...utf8.encode(name),
        ]),
      );
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionCustomAccountId(nrcCid, name),
        ),
        citizenAccountIdFromBytes(expected),
      );
    });

    test('自定义账户不同于主账户', () {
      expect(
        citizenAccountIdFromBytes(
          deriveInstitutionCustomAccountId(nrcCid, '专户'),
        ),
        isNot(
          citizenAccountIdFromBytes(deriveInstitutionMainAccountId(nrcCid)),
        ),
      );
    });

    test('空账户名抛错(对齐链端 EmptyAccountName)', () {
      expect(
        () => deriveInstitutionCustomAccountId(nrcCid, ''),
        throwsArgumentError,
      );
    });

    test('自定义名命中受限保留名抛错', () {
      expect(
        () => deriveInstitutionCustomAccountId(nrcCid, kReservedNameMain),
        throwsArgumentError,
      );
      expect(
        () => deriveInstitutionCustomAccountId(fscCid, kReservedNameFcsf),
        throwsArgumentError,
      );
    });
  });
}
