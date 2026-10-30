import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证包限定资源真正进入Flutter bundle；不复制业务目录解析实现。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('资源包的行政区与机构JSON均可从实际bundle完整读取', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final catalogs = manifest.listAssets().where((key) =>
        key.startsWith('packages/citizen_assets/divisions/') ||
        key.startsWith('packages/citizen_assets/institutions/')).toList();
    expect(catalogs, isNotEmpty);
    expect(catalogs, contains('packages/citizen_assets/divisions/provinces.json'));
    expect(catalogs, contains('packages/citizen_assets/institutions/manifest.json'));
    for (final key in catalogs) {
      final value = jsonDecode(await rootBundle.loadString(key));
      expect(value, anyOf(isA<Map>(), isA<List>()), reason: key);
    }
  });
}
