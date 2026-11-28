// 目录仓库、版本及Isar实现。

import 'package:citizen_storage/user.dart' as app_store show Region;
import 'package:citizen_citizen/public/data.dart' show AdminDivisionDto;

import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_storage/user.dart' as app_store show Version;
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user.dart';
import 'package:citizen_storage/user.dart' as app_store show Catalog, Entity, Province;
import 'package:citizen_storage/user.dart' as user_store show Follow;

// 定义本地行政区查询和按原始主键增量删除接口。

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

// 定义公权目录及分片同步的本地存储接口。

// 公权机构快照缓存本地存储抽象(ADR-018 §九)。
//
// 抽象出存储接口,使同步/载入服务的逻辑可用内存 fake 单测,
// 不依赖 Isar 真库;生产实现见 isar_public_institution_store.dart。
// 全部为本地读写,UI 导航零链读零现查;数据内容来自 finalized 链快照。

abstract interface class PublicInstitutionStore {
  /// 幂等 upsert 一批机构(按 cid_number 唯一)。
  Future<void> upsertInstitutions(List<PublicInstitutionDto> items);

  /// 设置省份规范顺序(中枢 + 43 省 code,来自数据包 manifest)。
  Future<void> setProvinceOrder(List<String> provinceCodes);

  /// 省份规范顺序(省 code);无 manifest 时回退已落库机构的去重省 code。
  Future<List<String>> listProvinces();

  /// 某省全部市 code(按 city_code 去重,顺序稳定)。
  ///
  /// (ADR-021):镇 code 全国不唯一,但市 code 在省内唯一;按 code 去重,
  /// 名字由调用方查字典 join。
  Future<List<String>> listCities(String provinceCode);

  /// 某省某市全部公权机构(按 province_code + city_code)。
  Future<List<app_store.Entity>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  );

  /// 按 cid_number 取单个机构。
  Future<app_store.Entity?> getByCid(String cidNumber);

  /// 按机构码集合取全部机构(跨省扁平;org_code 索引 anyOf 查,非全表扫)。
  ///
  /// (ADR-028 P2):五子 tab 的治理/立法等机构视图按 institution_code
  /// 过滤统一目录的入口。
  Future<List<app_store.Entity>> listByInstitutionCodes(
    Set<String> institutionCodes,
  );

  /// 某省内按机构码集合取机构(province_code 索引 + org_code anyOf)。
  ///
  /// (ADR-028 P3):立法 tab 省导航选某省后,取该省 省立法院/省议会 +
  /// 全部市的市立法会。
  Future<List<app_store.Entity>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  );

  /// 某省(省 code)全部机构实体(按 province_code 索引查)。
  ///
  /// (增量 reconcile 用):供 loader 逐条比对同 cid 内容,只 upsert 真正
  /// 改名/新增的行,再删除包里已没有的废 cid,零旧数据残留。
  Future<List<app_store.Entity>> institutionsOfProvince(String provinceCode);

  /// 某省(省 code)全部机构 cid_number。
  Future<List<String>> cidsOfProvince(String provinceCode);

  /// 按 cid_number 批量删(分块,事务内)。
  Future<void> deleteByCids(List<String> cids);

  /// 已落库机构总数(判断是否需要首次载入数据包)。
  Future<int> institutionCount();

  /// 取某省(省 code)已同步版本戳。
  Future<String?> provinceVersion(String provinceCode);

  /// 写某省(省 code)已同步版本戳。
  Future<void> setProvinceVersion(String provinceCode, String version);

  // ── 订阅("关注")——按订阅者永久 CID 隔离 ──

  Future<void> subscribe(String cidNumber, String peerCid);

  Future<void> unsubscribe(String cidNumber, String peerCid);

  Future<bool> isSubscribed(String cidNumber, String peerCid);

  /// 我订阅的机构(关注分组),跨省扁平。
  Future<List<app_store.Entity>> listSubscribed(String cidNumber);
}

// 持久保存行政区及机构派生数据的独立版本游标。

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

// 以自然索引和有界事务读写Isar行政区分片。

// 行政区自然三元索引由原Isar维护；按省分片与有界事务增量更新。

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

// 在统一用户库读写公权目录、省份顺序及关注和同步状态。

// 公权机构目录本地存储 —— Isar 实现(ADR-018 §九)。
//
// 省份顺序、目录、同步状态与关注关系共用UserIsar；一次读取在同一回调中完成。

class IsarPublicInstitutionStore implements PublicInstitutionStore {
  IsarPublicInstitutionStore({Isar? isar}) : _injected = isar;

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
    return _read((isar) async {
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
    });
  }

  @override
  Future<List<String>> listCities(String provinceCode) async {
    return _read((isar) async {
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
    });
  }

  @override
  Future<List<app_store.Entity>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  ) async {
    return _read((isar) async {
      return isar
          .collection<app_store.Entity>()
          .filter()
          .provinceCodeEqualTo(provinceCode)
          .and()
          .cityCodeEqualTo(cityCode)
          .findAll();
    });
  }

  @override
  Future<app_store.Entity?> getByCid(String cidNumber) async {
    return _read((isar) async {
      return isar
          .collection<app_store.Entity>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findFirst();
    });
  }

  @override
  Future<List<app_store.Entity>> listByInstitutionCodes(
    Set<String> institutionCodes,
  ) async {
    if (institutionCodes.isEmpty) return const [];
    return _read((isar) async {
      // org_code 已建索引(ADR-028 P2);anyOf 走索引匹配,非全表扫。
      return isar
          .collection<app_store.Entity>()
          .filter()
          .anyOf(institutionCodes, (q, code) => q.orgCodeEqualTo(code))
          .findAll();
    });
  }

  @override
  Future<List<app_store.Entity>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  ) async {
    if (institutionCodes.isEmpty) return const [];
    return _read((isar) async {
      // province_code + org_code 均有索引;省内按码 anyOf,高效(ADR-028 P3)。
      return isar
          .collection<app_store.Entity>()
          .filter()
          .provinceCodeEqualTo(provinceCode)
          .and()
          .anyOf(institutionCodes, (q, code) => q.orgCodeEqualTo(code))
          .findAll();
    });
  }

  @override
  Future<List<app_store.Entity>> institutionsOfProvince(
    String provinceCode,
  ) async {
    return _read((isar) async {
      return isar
          .collection<app_store.Entity>()
          .filter()
          .provinceCodeEqualTo(provinceCode)
          .findAll();
    });
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
    return _read((isar) async {
      return isar.collection<app_store.Entity>().count();
    });
  }

  @override
  Future<String?> provinceVersion(String province) async {
    return _read((isar) async {
      final meta = await isar
          .collection<app_store.Province>()
          .filter()
          .provinceCodeEqualTo(province)
          .findFirst();
      return meta?.dataVersion;
    });
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
    await _write((isar) async {
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
    await _write((isar) async {
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
    return _read((isar) async {
      final hit = await isar
          .collection<user_store.Follow>()
          .getByCidNumberPeerCid(cidNumber, peerCid);
      return hit != null;
    });
  }

  @override
  Future<List<app_store.Entity>> listSubscribed(String cidNumber) {
    return _read((isar) async {
      final subs = await isar
          .collection<user_store.Follow>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findAll();
      final out = <app_store.Entity>[];
      for (final sub in subs) {
        final inst = await isar.collection<app_store.Entity>().getByCidNumber(
          sub.peerCid,
        );
        if (inst != null) out.add(inst);
      }
      return out;
    });
  }
}
