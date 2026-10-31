import 'package:citizen_storage/user_isar.dart' as app_store show Version;
// 只读派生数据的版本游标存储(与 schemaVersion 解耦)。
//
// 行政区/公权机构是只读派生数据(无用户数据),数据新鲜度完全由本
// helper 独立管理，并按 data_kind 自然键保存到 sync 表：
//   - global_version = 全局包版本，相等即整体秒过
//   - province_data = per-province 版本 map 的 JSON
// 逐省 reconcile 后逐省落 prov_vers,中断可续;全部省过完才落 data_version。
//
// 抽象成接口以便载入逻辑用内存 fake 单测,不依赖 Isar 真库;生产实现见
// [IsarDataVersionKv]。

import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart';

/// 版本游标读写接口。
abstract interface class DataVersionKv {
  /// 默认走全局 [UserIsar] 的 Isar 实现；`isar` 可注入供集成测试。
  factory DataVersionKv({required String dataKind, Isar? isar}) =
      IsarDataVersionKv;

  /// 读全局包版本;从未写过返回 null(首装)。
  Future<String?> readGlobalVersion();

  /// 写全局包版本(全部省 reconcile 成功后才落,作完成标记)。
  Future<void> writeGlobalVersion(String version);

  /// 读 per-province ver map;无 / 解析失败返回空 map(走全量 reconcile)。
  Future<Map<String, String>> readProvinceVersions();

  /// 整表覆盖写 per-province ver map(逐省 reconcile 后每省落一次,中断可续)。
  Future<void> writeProvinceVersions(Map<String, String> versions);
}

/// UserIsar 的 typed entity 实现。
class IsarDataVersionKv implements DataVersionKv {
  IsarDataVersionKv({required this.dataKind, Isar? isar}) : _injected = isar;

  /// 键命名空间,如 `admin_division` / `public_institution`。
  final String dataKind;
  final Isar? _injected;

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
  Future<String?> readGlobalVersion() async {
    return _read((isar) async {
      final row = await isar
          .collection<app_store.Version>()
          .filter()
          .dataKindEqualTo(dataKind)
          .findFirst();
      return row?.globalVersion;
    });
  }

  @override
  Future<void> writeGlobalVersion(String version) async {
    await _write((isar) async {
      final entity =
          await isar
              .collection<app_store.Version>()
              .filter()
              .dataKindEqualTo(dataKind)
              .findFirst() ??
          (app_store.Version()..dataKind = dataKind);
      entity.globalVersion = version;
      await isar.collection<app_store.Version>().putByDataKind(entity);
    });
  }

  @override
  Future<Map<String, String>> readProvinceVersions() async {
    return _read((isar) async {
      final row = await isar
          .collection<app_store.Version>()
          .filter()
          .dataKindEqualTo(dataKind)
          .findFirst();
      return decodeProvinceVersions(row?.provinceData);
    });
  }

  @override
  Future<void> writeProvinceVersions(Map<String, String> versions) async {
    final encoded = jsonEncode(versions);
    await _write((isar) async {
      final entity =
          await isar
              .collection<app_store.Version>()
              .filter()
              .dataKindEqualTo(dataKind)
              .findFirst() ??
          (app_store.Version()..dataKind = dataKind);
      entity.provinceData = encoded;
      await isar.collection<app_store.Version>().putByDataKind(entity);
    });
  }

  /// 解析 per-province ver map 的 JSON 字符串(无 / 非法返回空 map)。
  static Map<String, String> decodeProvinceVersions(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, String>{};
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } on FormatException {
      return <String, String>{};
    }
  }
}
