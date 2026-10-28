import 'package:citizenapp/storage/app_isar.dart'
    as app_store
    show Catalog, Entity, Province;
import 'package:citizenapp/storage/user_isar.dart' as user_store show Follow;
// 公权机构目录本地存储 —— Isar 实现(ADR-018 §九)。
//
// 省份规范顺序、版本戳与机构目录属于通用业务库；按用户 CID 归属的关注关系只存
// UserIsar。两个数据库的事务绝不互相嵌套。

import 'package:isar_community/isar.dart';
import 'package:citizenapp/storage/app_isar.dart';
import 'package:citizenapp/storage/user_isar.dart';

import 'public_institution_dto.dart';
import 'public_institution_store.dart';

class IsarPublicInstitutionStore implements PublicInstitutionStore {
  IsarPublicInstitutionStore({Isar? isar, Isar? userIsar})
    : _injected = isar,
      _injectedUser = userIsar;

  final Isar? _injected;
  final Isar? _injectedUser;

  Future<Isar> _db() async => _injected ?? await AppIsar.instance.db();

  Future<T> _write<T>(Future<T> Function(Isar isar) action) async {
    final injected = _injected;
    if (injected != null) {
      return injected.writeTxn(() => action(injected));
    }
    return AppIsar.instance.writeTxn(action);
  }

  Future<T> _userRead<T>(Future<T> Function(Isar isar) action) async {
    final injected = _injectedUser;
    if (injected != null) return action(injected);
    return UserIsar.instance.read(action);
  }

  Future<T> _userWrite<T>(Future<T> Function(Isar isar) action) async {
    final injected = _injectedUser;
    if (injected != null) {
      return injected.writeTxn(() => action(injected));
    }
    return UserIsar.instance.writeTxn(action);
  }

  /// 单事务批量上限:创世快照和后续增量都分块写,避免巨型事务卡 UI / 占内存。
  static const int _upsertChunk = 2000;

  @override
  Future<void> upsertInstitutions(List<PublicInstitutionDto> items) async {
    if (items.isEmpty) return;
    // 走唯一索引批量 upsert(putAllByCidNumber),无需逐条 findFirst;
    // 分块成多个小事务,首次灌大包不卡 UI、不撑内存。
    for (var start = 0; start < items.length; start += _upsertChunk) {
      final end = (start + _upsertChunk).clamp(0, items.length);
      final entities = items
          .sublist(start, end)
          .map((dto) => dto.toEntity())
          .toList(growable: false);
      await _write((isar) async {
        await isar.collection<app_store.Entity>().putAllByCidNumber(entities);
      });
    }
  }

  @override
  Future<void> setProvinceOrder(List<String> provinces) async {
    await _write((isar) async {
      await isar.collection<app_store.Catalog>().put(
        app_store.Catalog()
          ..rowId = 0
          ..provinceCodes = List<String>.unmodifiable(provinces),
      );
    });
  }

  @override
  Future<List<String>> listProvinces() async {
    final isar = await _db();
    final meta = await isar.collection<app_store.Catalog>().get(0);
    if (meta != null && meta.provinceCodes.isNotEmpty) {
      return List<String>.unmodifiable(meta.provinceCodes);
    }
    // 回退:无 manifest 时用已落库机构去重省 code(顺序不保证规范)。
    final all = await isar.collection<app_store.Entity>().where().findAll();
    final seen = <String>{};
    final out = <String>[];
    for (final e in all) {
      if (seen.add(e.provinceCode)) out.add(e.provinceCode);
    }
    return out;
  }

  @override
  Future<List<String>> listCities(String provinceCode) async {
    final isar = await _db();
    final rows = await isar
        .collection<app_store.Entity>()
        .filter()
        .provinceCodeEqualTo(provinceCode)
        .findAll();
    // 按 city_code 去重(市 code 省内唯一);名字由调用方查字典 join。
    final seen = <String>{};
    final out = <String>[];
    for (final e in rows) {
      if (e.cityCode.isNotEmpty && seen.add(e.cityCode)) out.add(e.cityCode);
    }
    return out;
  }

  @override
  Future<List<app_store.Entity>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  ) async {
    final isar = await _db();
    return isar
        .collection<app_store.Entity>()
        .filter()
        .provinceCodeEqualTo(provinceCode)
        .and()
        .cityCodeEqualTo(cityCode)
        .findAll();
  }

  @override
  Future<app_store.Entity?> getByCid(String cidNumber) async {
    final isar = await _db();
    return isar
        .collection<app_store.Entity>()
        .filter()
        .cidNumberEqualTo(cidNumber)
        .findFirst();
  }

  @override
  Future<List<app_store.Entity>> listByInstitutionCodes(
    Set<String> institutionCodes,
  ) async {
    if (institutionCodes.isEmpty) return const [];
    final isar = await _db();
    // org_code 已建索引(ADR-028 P2);anyOf 走索引匹配,非全表扫。
    return isar
        .collection<app_store.Entity>()
        .filter()
        .anyOf(institutionCodes, (q, code) => q.orgCodeEqualTo(code))
        .findAll();
  }

  @override
  Future<List<app_store.Entity>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  ) async {
    if (institutionCodes.isEmpty) return const [];
    final isar = await _db();
    // province_code + org_code 均有索引;省内按码 anyOf,高效(ADR-028 P3)。
    return isar
        .collection<app_store.Entity>()
        .filter()
        .provinceCodeEqualTo(provinceCode)
        .and()
        .anyOf(institutionCodes, (q, code) => q.orgCodeEqualTo(code))
        .findAll();
  }

  @override
  Future<List<app_store.Entity>> institutionsOfProvince(
    String provinceCode,
  ) async {
    final isar = await _db();
    return isar
        .collection<app_store.Entity>()
        .filter()
        .provinceCodeEqualTo(provinceCode)
        .findAll();
  }

  @override
  Future<List<String>> cidsOfProvince(String provinceCode) async {
    final rows = await institutionsOfProvince(provinceCode);
    return rows.map((e) => e.cidNumber).toList(growable: false);
  }

  @override
  Future<void> deleteByCids(List<String> cids) async {
    if (cids.isEmpty) return;
    for (var start = 0; start < cids.length; start += _upsertChunk) {
      final end = (start + _upsertChunk).clamp(0, cids.length);
      final chunk = cids.sublist(start, end);
      await _write((isar) async {
        await isar.collection<app_store.Entity>().deleteAllByCidNumber(chunk);
      });
    }
  }

  @override
  Future<int> institutionCount() async {
    final isar = await _db();
    return isar.collection<app_store.Entity>().count();
  }

  @override
  Future<String?> provinceVersion(String province) async {
    final isar = await _db();
    final meta = await isar
        .collection<app_store.Province>()
        .filter()
        .provinceCodeEqualTo(province)
        .findFirst();
    return meta?.dataVersion;
  }

  @override
  Future<void> setProvinceVersion(String province, String version) async {
    await _write((isar) async {
      final entity =
          await isar
              .collection<app_store.Province>()
              .filter()
              .provinceCodeEqualTo(province)
              .findFirst() ??
          (app_store.Province()..provinceCode = province);
      entity.dataVersion = version;
      await isar.collection<app_store.Province>().putByProvinceCode(entity);
    });
  }

  @override
  Future<void> subscribe(String cidNumber, String peerCid) async {
    await _userWrite((isar) async {
      final existing = await isar
          .collection<user_store.Follow>()
          .getByCidNumberPeerCid(cidNumber, peerCid);
      if (existing != null) return;
      final entity = user_store.Follow()
        ..cidNumber = cidNumber
        ..peerCid = peerCid;
      await isar.collection<user_store.Follow>().put(entity);
    });
  }

  @override
  Future<void> unsubscribe(String cidNumber, String peerCid) async {
    await _userWrite((isar) async {
      final existing = await isar
          .collection<user_store.Follow>()
          .getByCidNumberPeerCid(cidNumber, peerCid);
      if (existing != null) {
        await isar.collection<user_store.Follow>().delete(existing.rowId);
      }
    });
  }

  @override
  Future<bool> isSubscribed(String cidNumber, String peerCid) async {
    return _userRead((isar) async {
      final hit = await isar
          .collection<user_store.Follow>()
          .getByCidNumberPeerCid(cidNumber, peerCid);
      return hit != null;
    });
  }

  @override
  Future<List<app_store.Entity>> listSubscribed(String cidNumber) async {
    final subs = await _userRead(
      (isar) async => isar
          .collection<user_store.Follow>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findAll(),
    );
    final isar = await _db();
    final out = <app_store.Entity>[];
    for (final sub in subs) {
      final inst = await isar
          .collection<app_store.Entity>()
          .filter()
          .cidNumberEqualTo(sub.peerCid)
          .findFirst();
      if (inst != null) out.add(inst);
    }
    return out;
  }
}
