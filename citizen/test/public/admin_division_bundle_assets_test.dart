// 从真实资源包导入行政区字典并核对省市自然代码关联。

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_citizen/public/admin_division_bundle_loader.dart';

import 'package:citizen_testing/institution/fake_admin_division_store.dart';
import 'package:citizen_testing/institution/fake_data_version_kv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实 assets 数据包灌入后 cityNameMap(JL)[001]==南关市', () async {
    final store = FakeAdminDivisionStore();
    final loader = AdminDivisionBundleLoader(
      store: store,
      bundle: rootBundle,
      versionKv: FakeDataVersionKv(),
    );

    final changed = await loader.ensureSynced();
    expect(changed, isTrue, reason: '首装应从 assets 全量灌入字典');
    expect(
      await store.divisionCount(),
      greaterThan(40000),
      reason: '全国省/市/镇字典应≈4.2 万条',
    );

    final jl = await store.cities('JL');
    final nameMap = {for (final d in jl) d.cityCode: d.regionName};
    expect(nameMap['001'], '南关市', reason: '市名须 join 到字典,不回退 code');
    expect(nameMap['002'], '春阳市');
  });
}
