import 'package:citizen_storage/app_isar.dart' as app_store show Region;

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
