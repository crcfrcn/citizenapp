import 'package:citizen_storage/app_isar.dart' as app_store show Region;

import 'package:citizen_citizen/public/admin_division_dto.dart';

/// 本地行政区唯一存储接口；查询使用自然代码，删除使用Isar原主键。
abstract interface class AdminDivisionStore {
  Future<void> upsertDivisions(List<AdminDivisionDto> items);
  Future<int> divisionCount();

  /// 未命中仍返回最末级代码，显示不依赖远端读取。
  Future<String> regionName({
    required String provinceCode,
    String cityCode = '',
    String townCode = '',
  });
  Future<List<app_store.Region>> cities(String provinceCode);
  Future<List<app_store.Region>> divisionsOfProvince(String provinceCode);
  Future<void> deleteRows(List<int> rowIds);
}
