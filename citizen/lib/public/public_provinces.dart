// 从固定治理目录取得43省导航及代码和名称映射。

import 'package:citizen_citizen/institution/governance_registry.dart';

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
