// 公权机构数据包载入单测 —— 版本驱动增量 reconcile(fake AssetBundle + fake store)。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/public/admin_division_bundle_loader.dart';
import 'package:citizen_citizen/public/public_institution_bundle_loader.dart';
import 'package:citizen_citizen/public/public_institution_dto.dart';

import 'package:citizen_testing/institution/fake_admin_division_store.dart';
import 'package:citizen_testing/institution/fake_data_version_kv.dart';
import 'package:citizen_testing/institution/fake_public_institution_store.dart';

class _MapBundle extends AssetBundle {
  _MapBundle(this._files);
  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _files[key];
    if (value == null) throw FlutterError('asset not found: $key');
    return value;
  }
}

/// 构造一个不触碰全局 Isar 的机构 loader(字典 loader 也走 fake + fake 版本游标)。
PublicInstitutionBundleLoader buildLoader({
  required FakePublicInstitutionStore store,
  required AssetBundle bundle,
  FakeDataVersionKv? institutionKv,
  FakeDataVersionKv? divisionKv,
  FakeAdminDivisionStore? divisionStore,
}) {
  final divLoader = AdminDivisionBundleLoader(
    store: divisionStore ?? FakeAdminDivisionStore(),
    bundle: bundle,
    versionKv: divisionKv ?? FakeDataVersionKv(),
  );
  return PublicInstitutionBundleLoader(
    store: store,
    bundle: bundle,
    divisionLoader: divLoader,
    versionKv: institutionKv ?? FakeDataVersionKv(),
  );
}

/// 新格式机构 manifest:provinces:[{province_name,manifest_version,count}]。
String _instManifest({
  required String version,
  required List<Map<String, Object>> provinces,
}) => jsonEncode({'version': version, 'provinces': provinces});

void main() {
  for (final badShard in <String?>[
    null,
    'not json',
    '{}',
    jsonEncode({
      'province_name': '中枢省',
      'manifest_version': 'next',
      'institutions': [],
    }),
  ]) {
    test('机构分片缺失或损坏不删除现存数据、不推进游标，原版本可重试：$badShard', () async {
      final files = <String, String>{
        'packages/citizen_assets/institutions/manifest.json': _instManifest(
          version: 'next-global',
          provinces: [
            {'province_name': '中枢省', 'manifest_version': 'next', 'count': 1},
          ],
        ),
      };
      const shard = 'packages/citizen_assets/institutions/中枢省.json';
      if (badShard != null) files[shard] = badShard;
      final store = FakePublicInstitutionStore();
      await store.upsertInstitutions([
        PublicInstitutionDto.fromJson({
          'cid_number': 'old',
          'province_code': 'ZS',
          'institution_code': 'PRC',
          'account_count': 1,
        }),
      ]);
      await store.setProvinceVersion('中枢省', 'old');
      final kv = FakeDataVersionKv()
        ..globalVersion = 'old-global'
        ..provinceVersions = {'中枢省': 'old'};
      final loader = buildLoader(
        store: store,
        bundle: _MapBundle(files),
        institutionKv: kv,
      );
      await expectLater(loader.ensureSynced(), throwsFormatException);
      expect(store.byId.keys, ['old']);
      expect(store.deleteCalls, 0);
      expect(kv.globalVersion, 'old-global');
      expect(kv.provinceVersions, {'中枢省': 'old'});
      expect(await store.provinceVersion('中枢省'), 'old');
      files[shard] = jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'next',
        'institutions': [
          {
            'cid_number': 'new',
            'province_code': 'ZS',
            'institution_code': 'PRC',
            'account_count': 1,
          },
        ],
      });
      expect(await loader.ensureSynced(), isTrue);
      expect(store.byId.keys, ['new']);
      expect(kv.globalVersion, 'next-global');
      expect(kv.provinceVersions, {'中枢省': 'next'});
    });
  }
  test('旧版已误推进的机构游标靠省级成功记录在同版本恢复', () async {
    final store = FakePublicInstitutionStore();
    // 另一个省有数据，不能用全库非空判断失败省已完成。
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson({
        'cid_number': 'LN-kept',
        'province_code': 'LN',
        'institution_code': 'PRC',
        'account_count': 1,
      }),
    ]);
    await store.setProvinceVersion('岭南省', 'same');
    final kv = FakeDataVersionKv()
      ..globalVersion = 'same'
      ..provinceVersions = {'中枢省': 'same', '岭南省': 'same'};
    final files = <String, String>{
      'packages/citizen_assets/institutions/manifest.json': _instManifest(
        version: 'same',
        provinces: [
          {'province_name': '中枢省', 'manifest_version': 'same', 'count': 1},
          {'province_name': '岭南省', 'manifest_version': 'same', 'count': 1},
        ],
      ),
    };
    final loader = buildLoader(
      store: store,
      bundle: _MapBundle(files),
      institutionKv: kv,
    );
    await expectLater(loader.ensureSynced(), throwsFormatException);
    files['packages/citizen_assets/institutions/中枢省.json'] = jsonEncode({
      'province_name': '中枢省',
      'manifest_version': 'same',
      'institutions': [
        {
          'cid_number': 'ZS-restored',
          'province_code': 'ZS',
          'institution_code': 'PRC',
          'account_count': 1,
        },
      ],
    });
    files['packages/citizen_assets/institutions/岭南省.json'] = jsonEncode({
      'province_name': '岭南省',
      'manifest_version': 'same',
      'institutions': [
        {
          'cid_number': 'LN-kept',
          'province_code': 'LN',
          'institution_code': 'PRC',
          'account_count': 1,
        },
      ],
    });
    expect(await loader.ensureSynced(), isTrue);
    expect(store.byId.keys.toSet(), {'LN-kept', 'ZS-restored'});
  });
  test('机构合法空分片清理本省旧记录后才记成功', () async {
    final store = FakePublicInstitutionStore();
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson({
        'cid_number': 'stale',
        'province_code': 'ZS',
        'institution_code': 'PRC',
        'account_count': 1,
      }),
    ]);
    final kv = FakeDataVersionKv();
    final loader = buildLoader(
      store: store,
      institutionKv: kv,
      bundle: _MapBundle({
        'packages/citizen_assets/institutions/manifest.json': _instManifest(
          version: 'empty',
          provinces: [
            {'province_name': '中枢省', 'manifest_version': 'empty', 'count': 0},
          ],
        ),
        'packages/citizen_assets/institutions/中枢省.json': jsonEncode({
          'province_name': '中枢省',
          'manifest_version': 'empty',
          'institutions': [],
        }),
      }),
    );
    expect(await loader.ensureSynced(), isTrue);
    expect(store.byId, isEmpty);
    expect(kv.globalVersion, 'empty');
  });

  test('首装:载入 manifest(新格式)+ 省分片 → 写库 + 省顺序 + 版本戳', () async {
    final bundle = _MapBundle({
      'packages/citizen_assets/institutions/manifest.json': _instManifest(
        version: '1',
        provinces: const [
          {'province_name': '中枢省', 'manifest_version': 'cz-1', 'count': 1},
        ],
      ),
      'packages/citizen_assets/institutions/中枢省.json': jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'cz-1',
        'institutions': [
          {
            'cid_number': 'ZS001-ZF000-1-2026',
            'cid_full_name': '中枢省人民政府',
            'province_code': 'ZS',
            'city_code': '001',
            'institution_code': 'ZF',
            'account_count': 2,
          },
        ],
      }),
    });
    final store = FakePublicInstitutionStore();
    final kv = FakeDataVersionKv();
    final loader = buildLoader(store: store, bundle: bundle, institutionKv: kv);

    final changed = await loader.ensureSynced();

    expect(changed, isTrue);
    expect(store.byId.containsKey('ZS001-ZF000-1-2026'), isTrue);
    expect(store.byId['ZS001-ZF000-1-2026']!.provinceCode, 'ZS');
    expect(store.byId['ZS001-ZF000-1-2026']!.cityCode, '001');
    expect(await store.listProvinces(), ['中枢省']);
    expect(await store.provinceVersion('中枢省'), 'cz-1');
    expect(kv.globalVersion, '1');
    expect(kv.provinceVersions, {'中枢省': 'cz-1'});
  });

  test('全局 version 相等但省级 manifest_version 变化 → 仍 reconcile 机构分片', () async {
    final store = FakePublicInstitutionStore();
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'ZS001-ZF000-1-2026',
        'cid_full_name': '旧名机构',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 2,
      }),
    ]);
    final kv = FakeDataVersionKv()
      ..globalVersion = '1'
      ..provinceVersions = {'中枢省': 'cz-old'};
    final bundle = _MapBundle({
      'packages/citizen_assets/institutions/manifest.json': _instManifest(
        version: '1',
        provinces: const [
          {'province_name': '中枢省', 'manifest_version': 'cz-new', 'count': 1},
        ],
      ),
      'packages/citizen_assets/institutions/中枢省.json': jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'cz-new',
        'institutions': [
          {
            'cid_number': 'ZS001-ZF000-1-2026',
            'cid_full_name': '新名机构',
            'province_code': 'ZS',
            'city_code': '001',
            'institution_code': 'ZF',
            'account_count': 2,
          },
        ],
      }),
    });
    final loader = buildLoader(store: store, bundle: bundle, institutionKv: kv);

    final changed = await loader.ensureSynced();

    expect(changed, isTrue);
    expect(store.byId['ZS001-ZF000-1-2026']!.fullName, '新名机构');
    expect(kv.globalVersion, '1');
    expect(kv.provinceVersions, {'中枢省': 'cz-new'});
  });

  test('reconcile:改名 + 删除 + 新增,没变的省不动', () async {
    // 本地:中枢省[A 旧名, B 待删](manifest_version=cz-1)、岭南省[X](manifest_version=ln-1)。
    // manifest:中枢省 manifest_version 变(cz-1→cz-2),岭南省 manifest_version 不变。
    final store = FakePublicInstitutionStore();
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'A',
        'cid_full_name': '旧名机构',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 1,
      }),
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'B',
        'cid_full_name': '待删机构',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 1,
      }),
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'X',
        'cid_full_name': '岭南机构',
        'province_code': 'LN',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 1,
      }),
    ]);
    await store.setProvinceVersion('岭南省', 'ln-1');
    final kv = FakeDataVersionKv()
      ..globalVersion = 'before'
      ..provinceVersions = {'中枢省': 'cz-1', '岭南省': 'ln-1'};
    final bundle = _MapBundle({
      'packages/citizen_assets/institutions/manifest.json': _instManifest(
        version: 'after',
        provinces: const [
          {
            'province_name': '中枢省',
            'manifest_version': 'cz-2',
            'count': 2,
          }, // 变了
          {
            'province_name': '岭南省',
            'manifest_version': 'ln-1',
            'count': 1,
          }, // 不变
        ],
      ),
      'packages/citizen_assets/institutions/中枢省.json': jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'cz-2',
        'institutions': [
          // A 改名,B 不在(删),C 新增。
          {
            'cid_number': 'A',
            'cid_full_name': '新名机构',
            'province_code': 'ZS',
            'city_code': '001',
            'institution_code': 'ZF',
            'account_count': 1,
          },
          {
            'cid_number': 'C',
            'cid_full_name': '新增机构',
            'province_code': 'ZS',
            'city_code': '002',
            'institution_code': 'ZF',
            'account_count': 1,
          },
        ],
      }),
      // 岭南省分片故意不提供:若误读会 return(无分片),证明没读它。
    });
    final loader = buildLoader(store: store, bundle: bundle, institutionKv: kv);

    final changed = await loader.ensureSynced();

    expect(changed, isTrue);
    expect(store.byId['A']!.fullName, '新名机构'); // 改名
    expect(store.byId.containsKey('B'), isFalse); // 删除
    expect(store.byId['C']!.fullName, '新增机构'); // 新增
    expect(store.byId.containsKey('X'), isTrue); // 岭南省没动,X 仍在
    expect(store.lastUpsertCids, ['A', 'C']); // 只写改名/新增,不重写整省
    expect(kv.globalVersion, 'after');
    expect(kv.provinceVersions, {'中枢省': 'cz-2', '岭南省': 'ln-1'});
  });

  test('没变的省不读分片(deleteCalls/upsertCalls 不为该省增加)', () async {
    final store = FakePublicInstitutionStore();
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'X',
        'province_code': 'LN',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 1,
      }),
    ]);
    await store.setProvinceVersion('岭南省', 'ln-1');
    final kv = FakeDataVersionKv()
      ..globalVersion = 'before'
      ..provinceVersions = {'岭南省': 'ln-1'};
    // 全局 version 变了(强制进入逐省比对),但岭南省 manifest_version 没变 → 不 reconcile。
    final bundle = _MapBundle({
      'packages/citizen_assets/institutions/manifest.json': _instManifest(
        version: 'after',
        provinces: const [
          {'province_name': '岭南省', 'manifest_version': 'ln-1', 'count': 1},
        ],
      ),
    });
    final loader = buildLoader(store: store, bundle: bundle, institutionKv: kv);

    final upsertBefore = store.upsertCalls;
    final deleteBefore = store.deleteCalls;
    final changed = await loader.ensureSynced();

    expect(changed, isFalse);
    expect(store.upsertCalls, upsertBefore); // 没读分片、没 upsert
    expect(store.deleteCalls, deleteBefore);
    // 但全局 version 仍落到 after(完成标记)。
    expect(kv.globalVersion, 'after');
  });

  test('manifest 缺省级版本表 → 不写库、不删除本地数据', () async {
    final bundle = _MapBundle({
      'packages/citizen_assets/institutions/manifest.json': jsonEncode({
        'version': '1',
        'provinces': ['中枢省'],
      }),
      'packages/citizen_assets/institutions/中枢省.json': jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'cz-1',
        'institutions': [
          {
            'cid_number': 'ZS001',
            'cid_full_name': '新名机构',
            'province_code': 'ZS',
            'city_code': '001',
            'institution_code': 'ZF',
            'account_count': 2,
          },
        ],
      }),
    });
    final store = FakePublicInstitutionStore();
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'ZS001',
        'cid_full_name': '旧名机构',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 2,
      }),
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': 'STALE',
        'cid_full_name': '旧残留机构',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'ZF',
        'account_count': 2,
      }),
    ]);
    final loader = buildLoader(store: store, bundle: bundle);
    final upsertBefore = store.upsertCalls;
    final deleteBefore = store.deleteCalls;

    await expectLater(loader.ensureSynced(), throwsFormatException);
    expect(store.upsertCalls, upsertBefore);
    expect(store.deleteCalls, deleteBefore);
    expect(store.byId.containsKey('ZS001'), isTrue);
    expect(store.byId['ZS001']!.fullName, '旧名机构');
    expect(store.byId.containsKey('STALE'), isTrue);
    expect(store.provinceOrder, isEmpty);
    expect(await store.listProvinces(), ['ZS']);
  });

  test('无数据包 → loadFromBundle 返回 false 不崩', () async {
    final store = FakePublicInstitutionStore();
    final loader = buildLoader(store: store, bundle: _MapBundle(const {}));
    expect(await loader.loadFromBundle(), isFalse);
  });
}
