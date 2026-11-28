// 验证目录模型及省份数据。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'dart:convert';
import 'dart:io';
import 'package:citizen_citizen/public/data.dart' show provinceDisplayNameByCode, provinceFullNameByCode, publicProvinceNamesSet;

void main() {
  group('public_institution_dto_test', _registerDto);
  group('public_provinces_test', _registerProvinces);
}

// 验证机构快照字段、自然行政代码和代表人转换。

void _registerDto() {
  group('PublicInstitutionDto.fromJson', () {
    test('解析全字段(行政区只吃 code) + custom_account_names', () {
      final dto = PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'AH001-ZF000-123456789-2026',
        'cid_full_name': '安徽省人民政府',
        'cid_short_name': '皖府',
        'status': 'ACTIVE',
        'province_code': 'AH',
        'city_code': '001',
        'town_code': '',
        'institution_code': 'ZF',
        'account_count': 3,
        'legal_representative': {
          'family_name': '李',
          'given_name': '大民',
          'cid_number': 'CID-1',
          'account': '11',
        },
        'custom_account_names': ['业务专户A', '业务专户B'],
      });
      expect(dto.cidNumber, 'AH001-ZF000-123456789-2026');
      expect(dto.fullName, '安徽省人民政府');
      expect(dto.provinceCode, 'AH');
      expect(dto.cityCode, '001');
      expect(dto.townCode, '');
      expect(dto.accountCount, 3);
      expect(dto.familyName, '李');
      expect(dto.givenName, '大民');
      expect(dto.accountNames, ['业务专户A', '业务专户B']);
      // 行政区 code + 法定代表人随实体落库。
      final entity = dto.toEntity();
      expect(entity.provinceCode, 'AH');
      expect(entity.cityCode, '001');
      expect(entity.familyName, '李');
      expect(entity.givenName, '大民');
    });

    test('缺省行政区 code → 空串;缺省 custom/法定代表人 → 空/null(无名字 fallback)', () {
      final dto = PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'X',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 2,
      });
      expect(dto.provinceCode, 'ZS');
      expect(dto.cityCode, '001');
      expect(dto.townCode, ''); // 缺省镇 code → 空串
      expect(dto.accountNames, isEmpty);
      expect(dto.cidState, 'ACTIVE');
      expect(dto.familyName, isNull);
      expect(dto.givenName, isNull);
    });

    test('toEntity 保留真实目录事实和名称回退', () {
      final dto = PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'Y',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'LF',
        'account_count': 2,
      });
      final e = dto.toEntity();
      expect(e.cidNumber, 'Y');
      expect(e.fullName, 'Y'); // 无名回退 cid_number
      expect(e.orgCode, 'LF');
      expect(e.accountCount, 2);
    });
  });
}

// 验证链上和字典省名逐字一致及规范省代码映射。

void _registerProvinces() {
  test('链上省名集合 == 字典 provinces.json 省名集合(逐字对齐守卫)', () {
    final file = File('assets/divisions/provinces.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'packages/citizen_assets/divisions/provinces.json 必须存在(字典数据包)',
    );

    final dictNames = (jsonDecode(file.readAsStringSync()) as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['name'] as String)
        .toSet();
    final chainNames = publicProvinceNamesSet();

    // 集合相等:链上常量与字典一一对应,零漂移。
    expect(
      chainNames,
      equals(dictNames),
      reason:
          '链上省名与 china.sqlite 派生字典省名不一致——'
          '改名只改 china.sqlite,且需同步链上常量。',
    );
  });

  test('省 code → 全名/展示名映射来自链上常量(中枢省=ZS)', () {
    expect(provinceFullNameByCode('ZS'), '中枢省');
    expect(provinceDisplayNameByCode('ZS'), '中枢');
    // 未知 code 回退 code 本身(绝不崩)。
    expect(provinceFullNameByCode('ZZ'), 'ZZ');
  });
}
