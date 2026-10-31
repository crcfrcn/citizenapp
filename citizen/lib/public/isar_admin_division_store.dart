import 'package:citizen_storage/user_isar.dart' as app_store show Region;
// 行政区自然三元索引由原Isar维护；按省分片与有界事务增量更新。

import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_citizen/public/admin_division_dto.dart';
import 'package:citizen_citizen/public/admin_division_store.dart';

class IsarAdminDivisionStore implements AdminDivisionStore {
  IsarAdminDivisionStore({Isar? isar}) : _injected = isar;

  final Isar? _injected;

  /// 单事务批量上限:5 万条镇级数据分块写,避免巨型事务卡主线程 / 占内存。
  static const int _upsertChunk = 2000;

  Future<T> _read<T>(Future<T> Function(Isar isar) action) {
    final injected = _injected;
    if (injected != null) return action(injected);
    return UserIsar.instance.read(action);
  }

  Future<T> _write<T>(Future<T> Function(Isar isar) action) async {
    final injected = _injected;
    if (injected != null) {
      return injected.writeTxn(() => action(injected));
    }
    return UserIsar.instance.writeTxn(action);
  }

  @override
  Future<void> upsertDivisions(List<AdminDivisionDto> items) async {
    if (items.isEmpty) return;
    for (var start = 0; start < items.length; start += _upsertChunk) {
      final end = (start + _upsertChunk).clamp(0, items.length);
      final entities = items
          .sublist(start, end)
          .map((dto) => dto.toEntity())
          .toList(growable: false);
      await _write((isar) async {
        await isar
            .collection<app_store.Region>()
            .putAllByProvinceCodeCityCodeTownCode(entities);
      });
    }
  }

  @override
  Future<int> divisionCount() async {
    return _read((isar) async {
      return isar.collection<app_store.Region>().count();
    });
  }

  @override
  Future<String> regionName({
    required String provinceCode,
    String cityCode = '',
    String townCode = '',
  }) async {
    final code = townCode.isNotEmpty
        ? townCode
        : cityCode.isNotEmpty
        ? cityCode
        : provinceCode;
    if (code.isEmpty) return code;
    return _read((isar) async {
      final row = await isar
          .collection<app_store.Region>()
          .getByProvinceCodeCityCodeTownCode(provinceCode, cityCode, townCode);
      return row?.regionName ?? code;
    });
  }

  @override
  Future<List<app_store.Region>> cities(String provinceCode) async {
    return _read((isar) async {
      return isar
          .collection<app_store.Region>()
          .filter()
          .provinceCodeEqualTo(provinceCode)
          .cityCodeIsNotEmpty()
          .townCodeEqualTo('')
          .findAll();
    });
  }

  @override
  Future<List<app_store.Region>> divisionsOfProvince(
    String provinceCode,
  ) async {
    return _read((isar) async {
      return isar
          .collection<app_store.Region>()
          .filter()
          .provinceCodeEqualTo(provinceCode)
          .findAll();
    });
  }

  @override
  Future<void> deleteRows(List<int> rowIds) async {
    for (var start = 0; start < rowIds.length; start += _upsertChunk) {
      final end = (start + _upsertChunk).clamp(0, rowIds.length);
      final chunk = rowIds.sublist(start, end);
      await _write(
        (isar) => isar.collection<app_store.Region>().deleteAll(chunk),
      );
    }
  }
}
