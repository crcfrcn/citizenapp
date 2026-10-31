import 'package:citizen_storage/user_isar.dart' as app_store show Entity;
// 内存 fake store —— 测同步/载入/订阅逻辑,不依赖 Isar 真库。

import 'package:citizen_citizen/public/public_institution_dto.dart';
import 'package:citizen_citizen/public/public_institution_store.dart';

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
