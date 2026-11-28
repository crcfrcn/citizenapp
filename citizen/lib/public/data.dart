// 行政区、机构目录及地区展示模型。

import 'package:citizen_storage/user.dart' as app_store show Region;
import 'package:citizen_storage/user.dart' as app_store show Entity;
import 'package:citizen_citizen/institution/data.dart' show kPrcs;
import 'package:citizen_citizen/public/store.dart' show AdminDivisionStore;

// 解析行政区自然代码和名称，保留镇代码的完整父级。

/// 行政区只保存省、市、镇自然代码与名称，不持久化派生层级和拼接键。
/// 资源包原始code/name结构由各工厂解析，镇代码必须保留完整父级。
class AdminDivisionDto {
  const AdminDivisionDto({
    required this.provinceCode,
    required this.regionName,
    this.cityCode = '',
    this.townCode = '',
  });

  final String provinceCode;
  final String cityCode;
  final String townCode;
  final String regionName;

  static AdminDivisionDto province(Map<String, dynamic> json) =>
      AdminDivisionDto(
        provinceCode: json['code'] as String? ?? '',
        regionName: json['name'] as String? ?? '',
      );

  static AdminDivisionDto city(
    String provinceCode,
    Map<String, dynamic> json,
  ) => AdminDivisionDto(
    provinceCode: provinceCode,
    cityCode: json['code'] as String? ?? '',
    regionName: json['name'] as String? ?? '',
  );

  static AdminDivisionDto town(
    String provinceCode,
    Map<String, dynamic> json,
  ) => AdminDivisionDto(
    provinceCode: provinceCode,
    cityCode: json['city_code'] as String? ?? '',
    townCode: json['code'] as String? ?? '',
    regionName: json['name'] as String? ?? '',
  );

  app_store.Region toEntity() => app_store.Region()
    ..provinceCode = provinceCode
    ..cityCode = cityCode
    ..townCode = townCode
    ..regionName = regionName;
}

// 解析发布期最终链目录中的机构、自然行政代码及代表人资料。

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

// 从固定治理目录取得43省导航及代码和名称映射。

const String _kCouncilSuffix = '公民储备委员会';

/// 省导航条目:code(查询/落库键)+ 全名(含"省")+ 展示名(去"省")。
class PublicProvinceItem {
  const PublicProvinceItem({
    required this.code,
    required this.provinceFullName,
    required this.provinceDisplayName,
  });

  /// 省 code(= 省储委会 cid_number 前 2 字符),与字典 provinces.json code 对齐。
  final String code;

  /// 规范全名(含"省"),与 china.sqlite 省名逐字对齐。
  final String provinceFullName;

  /// 展示名:去掉末尾"省"字。
  final String provinceDisplayName;
}

String _provinceFullNameOf(String councilName) =>
    councilName.endsWith(_kCouncilSuffix)
    ? councilName.substring(0, councilName.length - _kCouncilSuffix.length)
    : councilName;

String _codeOf(String cidNumber) {
  // 省储委会 cid_number 形如 `ZS001-GCB0R-...`,前 2 字符为省 code。
  return cidNumber.length >= 2 ? cidNumber.substring(0, 2) : cidNumber;
}

String _displayOf(String provinceFullName) => provinceFullName.endsWith('省')
    ? provinceFullName.substring(0, provinceFullName.length - 1)
    : provinceFullName;

/// 公权机构左栏的 43 个省份导航条目(code + 全名 + 展示名,来自链上省储委会常量)。
List<PublicProvinceItem> publicProvinceItems() {
  return kPrcs
      .map((c) {
        final provinceFullName = _provinceFullNameOf(c.fullName);
        return PublicProvinceItem(
          code: _codeOf(c.cidNumber),
          provinceFullName: provinceFullName,
          provinceDisplayName: _displayOf(provinceFullName),
        );
      })
      .toList(growable: false);
}

/// 公权机构左栏的 43 个省份规范**全名**(含"省")。
List<String> publicProvinceNames() => publicProvinceItems()
    .map((p) => p.provinceFullName)
    .toList(growable: false);

/// 链上省名集合(去"省"前的全名);单测用作「链上==字典」守卫断言。
Set<String> publicProvinceNamesSet() =>
    publicProvinceItems().map((p) => p.provinceFullName).toSet();

/// 省 code → 全名(含"省");未知 code 回退 code 本身(绝不崩)。
String provinceFullNameByCode(String code) {
  for (final p in publicProvinceItems()) {
    if (p.code == code) return p.provinceFullName;
  }
  return code;
}

/// 省 code → 展示名(去"省");未知 code 回退 code 本身。
String provinceDisplayNameByCode(String code) {
  for (final p in publicProvinceItems()) {
    if (p.code == code) return p.provinceDisplayName;
  }
  return code;
}

/// 省份**展示名**:去掉末尾"省"字。
///
/// 展示一律不带"省"(中枢/岭南/广东);但匹配/查询仍用 code。
/// 名字与 code 职责分离,不可混用。
String provinceDisplayName(String fullProvince) => fullProvince.endsWith('省')
    ? fullProvince.substring(0, fullProvince.length - 1)
    : fullProvince;

// 从省市镇自然代码查字典并组合显示路径，缺失时保留代码。

/// 把 (province_code, city_code, town_code) 拼成「省名·市名·镇名」显示路径。
///
/// 规则(ADR-021):
/// - 有 town:显「省名·市名·镇名」。
/// - 空 town:只显「省名·市名」,**不拼空段、不显 null**。
/// - 字典缺失:回退显 code 本身(绝不崩、绝不空)。
///
/// [provinceName] 省名由调用方传入(链上常量源,认可的省名源);市/镇名查 [store]。
/// 用 ` · ` 连接,与现有 UI 统一。
Future<String> formatAreaPath(
  AdminDivisionStore store, {
  required String provinceName,
  required String provinceCode,
  required String cityCode,
  String townCode = '',
}) async {
  final segments = <String>[];
  if (provinceName.isNotEmpty) segments.add(provinceName);

  if (cityCode.isNotEmpty) {
    segments.add(
      await store.regionName(provinceCode: provinceCode, cityCode: cityCode),
    );
  }

  // 空 town 只显到市,不拼空段。
  if (townCode.isNotEmpty) {
    segments.add(
      await store.regionName(
        provinceCode: provinceCode,
        cityCode: cityCode,
        townCode: townCode,
      ),
    );
  }

  return segments.join(' · ');
}
