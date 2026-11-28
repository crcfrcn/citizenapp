// 以内存实现行政区、机构及版本游标测试仓库。

import 'package:citizen_citizen/public/data.dart' show AdminDivisionDto;
import 'package:citizen_citizen/public/store.dart' show AdminDivisionStore;
import 'package:citizen_citizen/public/store.dart' show DataVersionKv;
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_citizen/public/store.dart' show PublicInstitutionStore;
import 'package:citizen_storage/user.dart'
    as app_store
    show Entity, Region;

// 以内存自然三元组实现行政区测试仓库。

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

// 内存 fake 版本游标 store —— 测 reconcile 增量逻辑,不依赖 Isar 真库。

class FakeDataVersionKv implements DataVersionKv {
  String? globalVersion;
  Map<String, String> provinceVersions = {};

  int writeGlobalCalls = 0;
  int writeProvinceCalls = 0;

  @override
  Future<String?> readGlobalVersion() async => globalVersion;

  @override
  Future<void> writeGlobalVersion(String version) async {
    writeGlobalCalls++;
    globalVersion = version;
  }

  @override
  Future<Map<String, String>> readProvinceVersions() async =>
      Map<String, String>.of(provinceVersions);

  @override
  Future<void> writeProvinceVersions(Map<String, String> versions) async {
    writeProvinceCalls++;
    provinceVersions = Map<String, String>.of(versions);
  }
}

// 以内存实现机构快照、同步和关注测试仓库。

// 内存 fake store —— 测同步/载入/订阅逻辑,不依赖 Isar 真库。

class FakePublicInstitutionStore implements PublicInstitutionStore {
  final Map<String, PublicInstitutionDto> byId = {};
  final Map<String, String> provinceVersions = {};
  final Set<(String, String)> subs = {};
  List<String> provinceOrder = [];
  int upsertCalls = 0;
  int upsertItemCount = 0;
  int deleteCalls = 0;
  List<String> lastUpsertCids = const [];

  app_store.Entity _entity(PublicInstitutionDto d) => d.toEntity();

  @override
  Future<void> upsertInstitutions(List<PublicInstitutionDto> items) async {
    upsertCalls++;
    upsertItemCount += items.length;
    lastUpsertCids = items.map((d) => d.cidNumber).toList(growable: false);
    for (final d in items) {
      byId[d.cidNumber] = d;
    }
  }

  @override
  Future<void> setProvinceOrder(List<String> provinces) async {
    provinceOrder = List.of(provinces);
  }

  @override
  Future<List<String>> listProvinces() async => provinceOrder.isNotEmpty
      ? List.of(provinceOrder)
      : byId.values.map((e) => e.provinceCode).toSet().toList();

  @override
  Future<List<String>> listCities(String provinceCode) async => byId.values
      .where((e) => e.provinceCode == provinceCode)
      .map((e) => e.cityCode)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();

  @override
  Future<List<app_store.Entity>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  ) async => byId.values
      .where((e) => e.provinceCode == provinceCode && e.cityCode == cityCode)
      .map(_entity)
      .toList();

  @override
  Future<app_store.Entity?> getByCid(String cidNumber) async {
    final d = byId[cidNumber];
    return d == null ? null : _entity(d);
  }

  @override
  Future<List<app_store.Entity>> listByInstitutionCodes(
    Set<String> institutionCodes,
  ) async => byId.values
      .where((e) => institutionCodes.contains(e.orgCode))
      .map(_entity)
      .toList(growable: false);

  @override
  Future<List<app_store.Entity>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  ) async => byId.values
      .where(
        (e) =>
            e.provinceCode == provinceCode &&
            institutionCodes.contains(e.orgCode),
      )
      .map(_entity)
      .toList(growable: false);

  @override
  Future<List<app_store.Entity>> institutionsOfProvince(
    String provinceCode,
  ) async => byId.values
      .where((e) => e.provinceCode == provinceCode)
      .map(_entity)
      .toList(growable: false);

  @override
  Future<List<String>> cidsOfProvince(String provinceCode) async => byId.values
      .where((e) => e.provinceCode == provinceCode)
      .map((e) => e.cidNumber)
      .toList(growable: false);

  @override
  Future<void> deleteByCids(List<String> cids) async {
    deleteCalls++;
    for (final cid in cids) {
      byId.remove(cid);
    }
  }

  @override
  Future<int> institutionCount() async => byId.length;

  @override
  Future<String?> provinceVersion(String province) async =>
      provinceVersions[province];

  @override
  Future<void> setProvinceVersion(String province, String version) async {
    provinceVersions[province] = version;
  }

  @override
  Future<void> subscribe(String cidNumber, String peerCid) async {
    subs.add((cidNumber, peerCid));
  }

  @override
  Future<void> unsubscribe(String cidNumber, String peerCid) async {
    subs.remove((cidNumber, peerCid));
  }

  @override
  Future<bool> isSubscribed(String cidNumber, String peerCid) async =>
      subs.contains((cidNumber, peerCid));

  @override
  Future<List<app_store.Entity>> listSubscribed(String cidNumber) async {
    final out = <app_store.Entity>[];
    for (final key in subs) {
      if (key.$1 != cidNumber) continue;
      final cid = key.$2;
      final d = byId[cid];
      if (d != null) out.add(_entity(d));
    }
    return out;
  }
}
