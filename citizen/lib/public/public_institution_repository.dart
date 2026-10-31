import 'package:citizen_storage/user_isar.dart' as app_store show Entity;
// 公权机构 finalized 链快照缓存 repo 门面。
//
// card B/C 的统一入口。**读全部走本地 store(零链读零网络、秒开)**;
// finalized 链快照包由 [ensureSynced] 在首启后台导入/对账。目录缓存随 App 发布的
// 链快照更新；涉及身份、绑定、付款或权限的操作必须再读取 finalized 链状态，不能把
// 本地目录当作授权真源。

import 'package:citizen_citizen/public/admin_division_store.dart';
import 'package:citizen_citizen/public/area_path_formatter.dart';
import 'package:citizen_citizen/public/isar_admin_division_store.dart';
import 'package:citizen_citizen/public/isar_public_institution_store.dart';
import 'package:citizen_citizen/public/public_institution_bundle_loader.dart';
import 'package:citizen_citizen/public/public_institution_store.dart';
import 'package:citizen_citizen/public/public_provinces.dart';

class PublicInstitutionRepository {
  PublicInstitutionRepository({
    PublicInstitutionStore? store,
    AdminDivisionStore? divisionStore,
    PublicInstitutionBundleLoader? loader,
    Duration? syncTtl,
  }) : store = store ?? IsarPublicInstitutionStore(),
       divisionStore = divisionStore ?? IsarAdminDivisionStore(),
       _syncTtl = syncTtl ?? const Duration(minutes: 2) {
    this.loader =
        loader ??
        (store == null && divisionStore == null
            ? _defaultLoader
            : PublicInstitutionBundleLoader(
                store: this.store,
                divisionStore: this.divisionStore,
              ));
  }

  // 默认仓库都访问同一 UserIsar；切换页面时共享正在进行的目录导入。
  static final PublicInstitutionBundleLoader _defaultLoader =
      PublicInstitutionBundleLoader(
        store: IsarPublicInstitutionStore(),
        divisionStore: IsarAdminDivisionStore(),
      );

  final PublicInstitutionStore store;

  /// 行政区字典(ADR-021 行政区唯一真源):机构显示名按 code join 此字典。
  final AdminDivisionStore divisionStore;
  late final PublicInstitutionBundleLoader loader;

  final Duration _syncTtl;
  final Map<String, int> _lastSyncMs = {};

  // ── 读(本地,零网络,秒开)──
  Future<List<String>> listProvinces() => store.listProvinces();
  Future<List<String>> listCities(String provinceCode) =>
      store.listCities(provinceCode);
  Future<List<app_store.Entity>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  ) => store.listInstitutionsByCity(provinceCode, cityCode);
  Future<app_store.Entity?> getByCid(String cidNumber) =>
      store.getByCid(cidNumber);

  /// 按机构码集合取全部机构(治理/立法 tab 过滤入口,ADR-028 P2)。
  Future<List<app_store.Entity>> listByInstitutionCodes(
    Set<String> institutionCodes,
  ) => store.listByInstitutionCodes(institutionCodes);

  /// 某省内按机构码集合取机构(立法 tab 省导航,ADR-028 P3)。
  Future<List<app_store.Entity>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  ) => store.listByProvinceAndCodes(provinceCode, institutionCodes);

  // ── 行政区字典 join(ADR-021;UI 显示名唯一来自字典/链上常量省名)──

  /// 某市 code → 市名(查字典;未命中回退 code 本身,绝不崩)。
  Future<String> cityName(String provinceCode, String cityCode) {
    return divisionStore.regionName(
      provinceCode: provinceCode,
      cityCode: cityCode,
    );
  }

  /// 某省所有市的 `code → 市名` 映射(**一次查询**,供市列表批量 join)。
  ///
  /// (ADR-018 R2 禁 N+1):市列表渲染必须用本方法一次取全省市名,
  /// **禁止**对每个市逐个调 [cityName](那是 N+1,省份市多时会转圈)。
  Future<Map<String, String>> cityNameMap(String provinceCode) async {
    final divisions = await divisionStore.cities(provinceCode);
    return {for (final d in divisions) d.cityCode: d.regionName};
  }

  /// (province_code, city_code, town_code) → 「省名·市名[·镇名]」显示路径。
  ///
  /// 省名走链上常量(认可的省名源);空 town 只显到市;字典缺失回退 code。
  /// **不在 widget build 里调**:在 repository / state 层预 join 成 view-model。
  Future<String> areaPath({
    required String provinceCode,
    required String cityCode,
    String townCode = '',
  }) {
    return formatAreaPath(
      divisionStore,
      provinceName: provinceDisplayNameByCode(provinceCode),
      provinceCode: provinceCode,
      cityCode: cityCode,
      townCode: townCode,
    );
  }

  /// 机构所属地显示路径(详情页 所属地行用;省名带"省"全名)。
  Future<String> institutionAreaPath(app_store.Entity inst) {
    return formatAreaPath(
      divisionStore,
      provinceName: provinceFullNameByCode(inst.provinceCode),
      provinceCode: inst.provinceCode,
      cityCode: inst.cityCode,
      townCode: inst.townCode,
    );
  }

  // ── 订阅("关注")──
  Future<void> subscribe(String cidNumber, String peerCid) =>
      store.subscribe(cidNumber, peerCid);
  Future<void> unsubscribe(String cidNumber, String peerCid) =>
      store.unsubscribe(cidNumber, peerCid);
  Future<bool> isSubscribed(String cidNumber, String peerCid) =>
      store.isSubscribed(cidNumber, peerCid);
  Future<List<app_store.Entity>> listSubscribed(String cidNumber) =>
      store.listSubscribed(cidNumber);

  /// 后台导入/对账内置创世快照包。返回机构部分是否发生写入。
  /// 非阻塞调用方:UI 先读本地缓存再调本方法。
  Future<bool> ensureSynced() => loader.ensureSynced();

  /// 后台重新对账当前安装包携带的 finalized 链快照。
  ///
  /// TTL 只用于避免页面切换时重复读取 asset；链上关键状态由对应业务服务在操作前
  /// 精确读取。
  Future<void> refreshProvince(String province) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSyncMs[province];
    if (last != null && now - last < _syncTtl.inMilliseconds) return;
    _lastSyncMs[province] = now;
    await ensureSynced();
  }
}
