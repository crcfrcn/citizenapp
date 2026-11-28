// 原目录资源加载流程。

import 'dart:convert';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:citizen_citizen/public/data.dart' show AdminDivisionDto;
import 'package:citizen_citizen/public/store.dart' show AdminDivisionStore;
import 'package:citizen_citizen/public/store.dart' show DataVersionKv;
import 'package:citizen_storage/user.dart' as app_store show Entity;
import 'package:flutter/foundation.dart';
import 'package:citizen_citizen/public/store.dart' show IsarAdminDivisionStore;
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_citizen/public/store.dart' show PublicInstitutionStore;
import 'package:citizen_citizen/public/data.dart' show publicProvinceItems;

// 按版本和省级分片增量导入随包行政区字典。

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

// 按最终链快照版本增量导入机构分片，成功后更新同步游标。

// 公权机构创世快照包载入 —— 链上快照驱动 reconcile(ADR-018 §九 混合模式 ①)。
//
// 发布期从链上创世状态导出的全量快照打进 assets;客户端把它当本地缓存,
// 公权机构唯一真源仍是链上状态。快照根或省级版本变了就增量刷新——
// 变的换、删的清、没变的不动,零旧数据残留(只读派生数据,无用户数据)。
// 数据包结构:
//   assets/institutions/manifest.json =
//     { chain_id, genesis_hash, snapshot_block_hash, state_root,
//       public_institution_root, provinces:[{province_name,manifest_version,count,shard_hash}] }
//   assets/institutions/<省名>.json    = { province_name, manifest_version, institutions:[...] }
// provinces[].manifest_version = 该省机构目录版本,内容一变即变。

class PublicInstitutionBundleLoader {
  PublicInstitutionBundleLoader({
    required this.store,
    AssetBundle? bundle,
    AdminDivisionStore? divisionStore,
    AdminDivisionBundleLoader? divisionLoader,
    DataVersionKv? versionKv,
  }) : bundle = bundle ?? rootBundle,
       divisionLoader =
           divisionLoader ??
           AdminDivisionBundleLoader(
             store: divisionStore ?? IsarAdminDivisionStore(),
             bundle: bundle ?? rootBundle,
           ),
       versionKv = versionKv ?? DataVersionKv(dataKind: 'public_institution');

  final PublicInstitutionStore store;
  final AssetBundle bundle;

  /// 行政区字典载入器(ADR-021):机构名字唯一真源,机构 reconcile 前先同步。
  final AdminDivisionBundleLoader divisionLoader;

  /// 版本游标存储(与 schemaVersion 解耦,独立管数据新鲜度)。
  final DataVersionKv versionKv;

  Future<bool>? _syncing;

  static const String _dir = 'packages/citizen_assets/institutions';
  static const String _manifestPath = '$_dir/manifest.json';

  /// 版本驱动增量 reconcile:包版本变了就增量刷新,变的换、删的清、没变的不动。
  ///
  /// 先 reconcile 行政区字典(机构 join 字典名),再 reconcile 机构。
  /// 省级游标、成功记录及清单数量共同判断完成；全局版本不能短路省级检查。
  /// 变了的省读取 `<省名>.json` 分片后做行级 diff:只 upsert 变化行、只删 absent cid。
  /// manifest 缺省级版本表时视为无效数据包,直接拒绝写库。
  /// 返回机构部分是否发生写入。
  Future<bool> ensureSynced() {
    final syncing = _syncing;
    if (syncing != null) return syncing;
    late final Future<bool> task;
    task = _ensureSynced().whenComplete(() {
      if (identical(_syncing, task)) _syncing = null;
    });
    _syncing = task;
    return task;
  }

  Future<bool> _ensureSynced() => _sync();

  /// 强制对账当前数据包；没有提供数据包时不改变本地数据。
  Future<bool> loadFromBundle() => _sync(force: true);

  Future<bool> _sync({bool force = false}) async {
    await divisionLoader.ensureSynced();
    final manifest = await _readManifest();
    if (manifest == null) return false;
    final provinces = _parseProvinceVersions(manifest['provinces']);
    if (provinces.isEmpty) {
      throw const FormatException('机构清单缺少省级版本表');
    }
    final globalVersion = _snapshotVersion(manifest);
    final count = await store.institutionCount();
    final expected = provinces.fold<int>(0, (n, p) => n + p.count);
    final complete = count == expected;
    final stored = await versionKv.readProvinceVersions();
    final next = Map<String, String>.of(stored);
    final previousGlobal = await versionKv.readGlobalVersion();
    if (previousGlobal != globalVersion || !complete) {
      await store.setProvinceOrder(
        provinces.map((p) => p.provinceName).toList(),
      );
    }
    var changed = false;
    for (final p in provinces) {
      // 旧实现可能只推进了KV游标；真实省级成功记录与计数也必须一致。
      final completed = await store.provinceVersion(p.provinceName);
      if (!force &&
          complete &&
          stored[p.provinceName] == p.manifestVersion &&
          completed == p.manifestVersion) {
        continue;
      }
      final updated = await _reconcileProvince(p);
      changed = changed || updated;
      next[p.provinceName] = p.manifestVersion;
      await versionKv.writeProvinceVersions(next);
    }
    if (await store.institutionCount() != expected) {
      throw const FormatException('机构目录数量与清单不一致');
    }
    await versionKv.writeGlobalVersion(globalVersion);
    return changed;
  }

  /// reconcile 单省:读 `<省名>.json` 分片 → 只 upsert 变化行 → 删包里已没有的废 cid。
  Future<bool> _reconcileProvince(_ProvinceVer province) async {
    final provinceName = province.provinceName;
    final raw = await _tryLoadString('$_dir/$provinceName.json');
    if (raw == null) throw const FormatException('机构必需分片不可读取');
    final shard = jsonDecode(raw) as Map<String, dynamic>;
    if (shard['province_name'] != provinceName ||
        shard['manifest_version'] != province.manifestVersion ||
        shard['institutions'] is! List) {
      throw const FormatException('机构分片结构或所属清单不一致');
    }
    final items = (shard['institutions'] as List)
        .map((e) => PublicInstitutionDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    if (items.length != province.count ||
        items.map((e) => e.cidNumber).toSet().length != items.length) {
      throw const FormatException('机构分片数量或自然键不合法');
    }
    String? provinceCode;
    for (final p in publicProvinceItems()) {
      if (p.provinceFullName == provinceName) provinceCode = p.code;
    }
    if (provinceCode == null ||
        items.any((e) => e.provinceCode != provinceCode)) {
      throw const FormatException('机构分片行政区不一致');
    }
    var changed = false;
    final oldRows = await store.institutionsOfProvince(provinceCode);
    final oldByCid = {for (final e in oldRows) e.cidNumber: e};
    final changedItems = items
        .where((d) => !_sameInstitution(oldByCid[d.cidNumber], d))
        .toList(growable: false);
    if (changedItems.isNotEmpty) {
      await store.upsertInstitutions(changedItems);
      changed = true;
    }

    final newCids = items.map((d) => d.cidNumber).toSet();
    final oldCids = oldByCid.keys;
    final staleCids = oldCids
        .where((s) => !newCids.contains(s))
        .toList(growable: false);
    if (staleCids.isNotEmpty) {
      await store.deleteByCids(staleCids);
      changed = true;
    }

    await store.setProvinceVersion(provinceName, province.manifestVersion);
    return changed;
  }

  Future<Map<String, dynamic>?> _readManifest() async {
    final manifestRaw = await _tryLoadString(_manifestPath);
    if (manifestRaw == null) return null;
    return jsonDecode(manifestRaw) as Map<String, dynamic>;
  }

  /// 全局快照版本优先由链身份锚点 + 公权机构根哈希组成。
  /// 这样 App 可以区分“同名 version 但实际链快照不同”的发布错误。
  static String _snapshotVersion(Map<String, dynamic> manifest) {
    final genesisHash = manifest['genesis_hash']?.toString() ?? '';
    final snapshotBlockHash = manifest['snapshot_block_hash']?.toString() ?? '';
    final publicInstitutionRoot =
        manifest['public_institution_root']?.toString() ?? '';
    if (genesisHash.isNotEmpty &&
        snapshotBlockHash.isNotEmpty &&
        publicInstitutionRoot.isNotEmpty) {
      return '$genesisHash:$snapshotBlockHash:$publicInstitutionRoot';
    }
    return manifest['version'] as String? ?? '0';
  }

  /// 解析当前 manifest `provinces:[{province_name,manifest_version}]` → 有序列表。
  static List<_ProvinceVer> _parseProvinceVersions(Object? raw) {
    if (raw is! List) throw const FormatException('机构清单省级版本表不合法');
    final out = <_ProvinceVer>[];
    for (final e in raw) {
      if (e is! Map) throw const FormatException('机构清单省条目不合法');
      final provinceName = e['province_name']?.toString();
      final manifestVersion = e['manifest_version']?.toString();
      final count = e['count'];
      if (count is! int || count < 0) throw const FormatException('机构清单计数不合法');
      if (provinceName == null ||
          provinceName.isEmpty ||
          manifestVersion == null ||
          manifestVersion.isEmpty ||
          out.any((p) => p.provinceName == provinceName)) {
        throw const FormatException('机构清单省级版本不合法');
      }
      {
        out.add(
          _ProvinceVer(
            provinceName: provinceName,
            manifestVersion: manifestVersion,
            count: count,
          ),
        );
      }
    }
    return out;
  }

  Future<String?> _tryLoadString(String path) async {
    try {
      return await bundle.loadString(path);
    } on FlutterError {
      // 资源不存在(数据包尚未生成)——返回 null 走空,不崩。
      return null;
    } on Exception {
      return null;
    }
  }

  static bool _sameInstitution(
    app_store.Entity? old,
    PublicInstitutionDto dto,
  ) {
    if (old == null) return false;
    return old.cidNumber == dto.cidNumber &&
        old.fullName == (dto.fullName ?? dto.cidNumber) &&
        old.shortName == dto.shortName &&
        old.cidState == dto.cidState &&
        old.provinceCode == dto.provinceCode &&
        old.cityCode == dto.cityCode &&
        old.townCode == dto.townCode &&
        old.orgCode == dto.orgCode &&
        old.parentCid == dto.parentCid &&
        old.isLegal == dto.isLegal &&
        old.familyName == dto.familyName &&
        old.givenName == dto.givenName &&
        old.legalCid == dto.legalCid &&
        old.legalAccount == dto.legalAccount &&
        old.accountCount == dto.accountCount &&
        _sameStringList(old.accountNames, dto.accountNames);
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// manifest 省级版本条目(内部用):省名 + 内容 manifestVersion。
class _ProvinceVer {
  const _ProvinceVer({
    required this.provinceName,
    required this.manifestVersion,
    required this.count,
  });

  final String provinceName;
  final String manifestVersion;
  final int count;
}
