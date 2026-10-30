import 'package:citizen_storage/app_isar.dart' as app_store show Entity;

// 公权机构 finalized 链快照 DTO。

/// 公权机构目录行；只解析发布期从 finalized 链状态生成的数据包。
class PublicInstitutionDto {
  const PublicInstitutionDto({
    required this.cidNumber,
    required this.cidState,
    required this.provinceCode,
    required this.cityCode,
    required this.orgCode,
    required this.accountCount,
    this.fullName,
    this.shortName,
    this.townCode = '',
    this.parentCid,
    this.isLegal,
    this.familyName,
    this.givenName,
    this.legalCid,
    this.legalAccount,
    this.accountNames = const [],
  });

  final String cidNumber;
  final String? fullName;
  final String? shortName;
  final String cidState;

  /// 所属省 code(行政区唯一真源键;名字由字典 join,见 ADR-021)。
  final String provinceCode;

  /// 所属市 code(名字走字典 join)。
  final String cityCode;

  /// 所属镇 code(空串=只定位到市级)。
  final String townCode;
  final String orgCode;
  final String? parentCid;
  final bool? isLegal;

  /// 法定代表人的姓、名；当前链快照没有任免信息时为 null。
  final String? familyName;
  final String? givenName;
  final String? legalCid;
  final String? legalAccount;
  final int accountCount;
  final List<String> accountNames;

  static PublicInstitutionDto fromJson(Map<String, dynamic> json) {
    final legalRepresentative =
        json['legal_representative'] as Map<String, dynamic>?;
    return PublicInstitutionDto(
      cidNumber: json['cid_number'] as String,
      fullName: json['cid_full_name'] as String?,
      shortName: json['cid_short_name'] as String?,
      cidState: json['status'] as String? ?? 'ACTIVE',
      // 行政区只吃 code(province_code/city_code/town_code);无名字 fallback
      // (ADR-021 死规则:名字唯一来自字典,不留旧方案)。
      provinceCode: json['province_code'] as String? ?? '',
      cityCode: json['city_code'] as String? ?? '',
      townCode: json['town_code'] as String? ?? '',
      orgCode: json['institution_code'] as String? ?? '',
      parentCid: json['parent_cid_number'] as String?,
      isLegal: json['has_legal_personality'] as bool?,
      familyName: legalRepresentative?['family_name'] as String?,
      givenName: legalRepresentative?['given_name'] as String?,
      legalCid: legalRepresentative?['cid_number'] as String?,
      legalAccount: legalRepresentative?['account'] as String?,
      accountCount: (json['account_count'] as num?)?.toInt() ?? 0,
      accountNames: (json['custom_account_names'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
    );
  }

  /// 目录只保存实际展示事实；省级版本由province集合拥有。
  app_store.Entity toEntity() {
    return app_store.Entity()
      ..cidNumber = cidNumber
      ..fullName = fullName ?? cidNumber
      ..shortName = shortName
      ..cidState = cidState
      ..provinceCode = provinceCode
      ..cityCode = cityCode
      ..townCode = townCode
      ..orgCode = orgCode
      ..parentCid = parentCid
      ..isLegal = isLegal
      ..familyName = familyName
      ..givenName = givenName
      ..legalCid = legalCid
      ..legalAccount = legalAccount
      ..accountCount = accountCount
      ..accountNames = accountNames;
  }
}
