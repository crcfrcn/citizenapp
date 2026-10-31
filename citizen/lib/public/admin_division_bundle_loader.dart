// 行政区字典数据包载入 —— 版本驱动增量 reconcile(ADR-021 §A2/A3)。
//
// 已提交行政区数据由本产品资源维护；自动化编译只消费现有资源
// 生成静态数据包。客户端无服务端,数据靠 assets 包分发;包版本变了就增量刷新——
// 变的换、删的清、没变的不动,零旧数据残留(只读派生数据,无用户数据)。
// 数据包结构:
//   assets/divisions/manifest.json      = { version, province_count, city_count, town_count, provinces:[{code,ver}] }
//   assets/divisions/provinces.json      = [{code,name}]
//   assets/divisions/cities/<pcode>.json = [{code,name}]
//   assets/divisions/towns/<pcode>.json  = [{city_code,code,name}]
// provinces[].ver = 该省内容(市分片+镇分片)hash,改名/删码/重排一变即变。

import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:citizen_citizen/public/admin_division_dto.dart';
import 'package:citizen_citizen/public/admin_division_store.dart';
import 'package:citizen_citizen/public/data_version_kv.dart';

class AdminDivisionBundleLoader {
  AdminDivisionBundleLoader({
    required this.store,
    AssetBundle? bundle,
    DataVersionKv? versionKv,
  }) : bundle = bundle ?? rootBundle,
       versionKv = versionKv ?? DataVersionKv(dataKind: 'admin_division');

  final AdminDivisionStore store;
  final AssetBundle bundle;

  /// 版本游标存储(与 schemaVersion 解耦,独立管数据新鲜度)。
  final DataVersionKv versionKv;

  static const String _dir = 'packages/citizen_assets/divisions';
  static const String _manifestPath = '$_dir/manifest.json';
  static const String _provincesPath = '$_dir/provinces.json';

  /// 版本驱动增量 reconcile:包版本变了就增量刷新,变的换、删的清、没变的不动。
  ///
  /// 每次核对清单总数量；不完整时重新对账，完整时只处理版本变化或缺游标的省。
  /// 没变的省连分片都不读。全局 version 只作最终完成标记,不能短路省级检查。
  /// manifest 缺省级版本表时视为无效数据包,直接拒绝写库。
  /// 返回是否发生了写入。
  Future<bool> ensureSynced() => _sync();

  /// 强制按清单对账；没有提供数据包时保留本地数据。
  Future<bool> loadFromBundle() => _sync(force: true);

  Future<bool> _sync({bool force = false}) async {
    final manifest = await _readManifest();
    if (manifest == null) return false;
    final versions = _parseProvinceVersions(manifest['provinces']);
    if (versions.isEmpty) throw const FormatException('行政区清单缺少省级版本表');
    final expected =
        _count(manifest, 'province_count') +
        _count(manifest, 'city_count') +
        _count(manifest, 'town_count');
    if (_count(manifest, 'province_count') != versions.length) {
      throw const FormatException('行政区省份数量与清单不一致');
    }
    final raw = await _required(_provincesPath);
    final provinces = (jsonDecode(raw) as List)
        .map((e) => AdminDivisionDto.province(e as Map<String, dynamic>))
        .toList();
    final byCode = {for (final p in provinces) p.provinceCode: p};
    if (byCode.length != provinces.length ||
        !versions.keys.every(byCode.containsKey)) {
      throw const FormatException('行政区省级记录不完整');
    }
    final complete = await store.divisionCount() == expected;
    final stored = await versionKv.readProvinceVersions();
    final next = Map<String, String>.of(stored);
    var changed = false;
    for (final entry in versions.entries) {
      if (!force && complete && stored[entry.key] == entry.value) continue;
      final updated = await _reconcileProvince(byCode[entry.key]!);
      changed = changed || updated;
      next[entry.key] = entry.value;
      await versionKv.writeProvinceVersions(next);
    }
    if (await store.divisionCount() != expected) {
      throw const FormatException('行政区数量与清单不一致');
    }
    final version = manifest['version'] as String?;
    if (version != null) await versionKv.writeGlobalVersion(version);
    return changed;
  }

  static int _count(Map<String, dynamic> manifest, String key) {
    final n = manifest[key];
    if (n is! int || n < 0) throw const FormatException('行政区清单计数不合法');
    return n;
  }

  /// reconcile 单省:读该省分片 → 只 upsert 变化行 → 删包里已没有的废键。
  Future<bool> _reconcileProvince(AdminDivisionDto province) async {
    final provinceCode = province.provinceCode;
    // 所有必需分片都读取并解析后，才允许对该省做增量写入或删除。
    final shard = await _loadProvinceShards(provinceCode);
    final newDtos = [province, ...shard.cities, ...shard.towns];
    final newCodes = {
      for (final d in newDtos) (d.provinceCode, d.cityCode, d.townCode),
    };
    if (newCodes.length != newDtos.length) {
      throw const FormatException('行政区分片自然键重复');
    }
    final oldRows = await store.divisionsOfProvince(provinceCode);
    final oldByCode = {
      for (final e in oldRows) (e.provinceCode, e.cityCode, e.townCode): e,
    };
    final changedDtos = newDtos
        .where(
          (d) =>
              oldByCode[(d.provinceCode, d.cityCode, d.townCode)]?.regionName !=
              d.regionName,
        )
        .toList(growable: false);
    if (changedDtos.isNotEmpty) await store.upsertDivisions(changedDtos);
    final staleRows = oldRows
        .where(
          (e) => !newCodes.contains((e.provinceCode, e.cityCode, e.townCode)),
        )
        .map((e) => e.rowId)
        .toList(growable: false);
    if (staleRows.isNotEmpty) await store.deleteRows(staleRows);
    return changedDtos.isNotEmpty || staleRows.isNotEmpty;
  }

  Future<_ProvinceShards> _loadProvinceShards(String provinceCode) async {
    final citiesRaw = await _required('$_dir/cities/$provinceCode.json');
    final townsRaw = await _required('$_dir/towns/$provinceCode.json');
    final cities = (jsonDecode(citiesRaw) as List)
        .map(
          (e) => AdminDivisionDto.city(provinceCode, e as Map<String, dynamic>),
        )
        .toList();
    final towns = (jsonDecode(townsRaw) as List)
        .map(
          (e) => AdminDivisionDto.town(provinceCode, e as Map<String, dynamic>),
        )
        .toList();
    return _ProvinceShards(cities: cities, towns: towns);
  }

  Future<String> _required(String path) async {
    final raw = await _tryLoadString(path);
    if (raw == null) throw const FormatException('行政区必需分片不可读取');
    return raw;
  }

  Future<Map<String, dynamic>?> _readManifest() async {
    final manifestRaw = await _tryLoadString(_manifestPath);
    if (manifestRaw == null) return null;
    return jsonDecode(manifestRaw) as Map<String, dynamic>;
  }

  /// 解析当前 manifest `provinces:[{code,ver}]` → `{code: ver}`。
  static Map<String, String> _parseProvinceVersions(Object? raw) {
    if (raw is! List) throw const FormatException('行政区省级版本表不合法');
    final out = <String, String>{};
    for (final e in raw) {
      if (e is! Map) throw const FormatException('行政区省条目不合法');
      final code = e['code']?.toString();
      final ver = e['ver']?.toString();
      if (code == null ||
          code.isEmpty ||
          ver == null ||
          ver.isEmpty ||
          out.containsKey(code)) {
        throw const FormatException('行政区省级版本不合法');
      }
      out[code] = ver;
    }
    return out;
  }

  Future<String?> _tryLoadString(String path) async {
    try {
      return await bundle.loadString(path);
    } on FlutterError {
      // 缺失或读取失败由调用方区分可选清单与必需分片；必需分片必须拒绝同步。
      return null;
    } on Exception {
      return null;
    }
  }
}

/// 某省的市/镇分片解析结果(内部用)。
class _ProvinceShards {
  const _ProvinceShards({required this.cities, required this.towns});

  final List<AdminDivisionDto> cities;
  final List<AdminDivisionDto> towns;
}
