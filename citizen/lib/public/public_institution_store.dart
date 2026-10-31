import 'package:citizen_storage/user_isar.dart' as app_store show Entity;
// 公权机构快照缓存本地存储抽象(ADR-018 §九)。
//
// 抽象出存储接口,使同步/载入服务的逻辑可用内存 fake 单测,
// 不依赖 Isar 真库;生产实现见 isar_public_institution_store.dart。
// 全部为本地读写,UI 导航零链读零现查;数据内容来自 finalized 链快照。

import 'package:citizen_citizen/public/public_institution_dto.dart';

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
