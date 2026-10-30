import 'package:citizen_storage/app_isar.dart' as app_store show Region;
import 'package:citizen_citizen/public/admin_division_dto.dart';
import 'package:citizen_citizen/public/admin_division_store.dart';

/// 内存库只用自然三元组，不复制生产拼接键算法。
class FakeAdminDivisionStore implements AdminDivisionStore {
  final Map<(String, String, String), app_store.Region> byCode = {};
  int _nextId = 0;
  int upsertCalls = 0;
  int upsertItemCount = 0;
  int deleteCalls = 0;
  List<(String, String, String)> lastUpsertCodes = const [];

  @override
  Future<void> upsertDivisions(List<AdminDivisionDto> items) async {
    upsertCalls++;
    upsertItemCount += items.length;
    lastUpsertCodes = items
        .map((d) => (d.provinceCode, d.cityCode, d.townCode))
        .toList(growable: false);
    for (final d in items) {
      seed(d);
    }
  }

  @override
  Future<int> divisionCount() async => byCode.length;

  @override
  Future<String> regionName({
    required String provinceCode,
    String cityCode = '',
    String townCode = '',
  }) async =>
      byCode[(provinceCode, cityCode, townCode)]?.regionName ??
      (townCode.isNotEmpty
          ? townCode
          : cityCode.isNotEmpty
          ? cityCode
          : provinceCode);

  @override
  Future<List<app_store.Region>> cities(String provinceCode) async => byCode
      .values
      .where(
        (e) =>
            e.provinceCode == provinceCode &&
            e.cityCode.isNotEmpty &&
            e.townCode.isEmpty,
      )
      .toList(growable: false);

  @override
  Future<List<app_store.Region>> divisionsOfProvince(
    String provinceCode,
  ) async => byCode.values
      .where((e) => e.provinceCode == provinceCode)
      .toList(growable: false);

  @override
  Future<void> deleteRows(List<int> rowIds) async {
    deleteCalls++;
    final ids = rowIds.toSet();
    byCode.removeWhere((_, row) => ids.contains(row.rowId));
  }

  void seed(AdminDivisionDto dto) {
    final code = (dto.provinceCode, dto.cityCode, dto.townCode);
    byCode[code] = dto.toEntity()..rowId = byCode[code]?.rowId ?? ++_nextId;
  }
}
