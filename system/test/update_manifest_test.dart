import 'package:citizen_testing/fixture.dart';

import 'dart:convert';

import 'package:citizen_system/update/app_update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture() => jsonDecode(
  fixtureFile('citizen_system', 'update_fixture.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('唯一发布证明解析APK名称、大小、摘要和应用标识', () {
    final manifest = AppUpdateManifest.fromJson(fixture());
    expect(manifest.version, '1.2.3');
    expect(manifest.versionCode, 9);
    expect(manifest.apkAsset, '公民·Android·v1.2.3.apk');
    expect(manifest.apkSize, 25);
    expect(manifest.apkSha256, fixture()['assets'][1]['sha256']);
    expect(manifest.matchesAndroidPackage('com.crcfrcn.citizenapp'), isTrue);
    expect(manifest.matchesAndroidPackage('other.app'), isFalse);
  });
  for (final entry in <String, List<Object?>>{
    'schema': [null, 2, '1'],
    'product_id': [null, 'other'],
    'platform': ['ios', null],
    'package_name': ['', null, 123, ' app '],
    'version': ['', 'v1.2.3', '01.2.3', '1.2', '1.2.3-beta', 123],
    'version_code': [null, '9', 9.5, 0, -1],
    'assets': [null, {}, []],
  }.entries) {
    for (var i = 0; i < entry.value.length; i++) {
      test('证明拒绝${entry.key}无效输入$i', () {
        final json = fixture()..[entry.key] = entry.value[i];
        expect(() => AppUpdateManifest.fromJson(json), throwsFormatException);
      });
    }
  }
  for (final field in ['name', 'size', 'sha256']) {
    for (final value
        in field == 'size' ? [0, -1, '24', 24.5] : ['', null, 42, 'invalid']) {
      test('附件拒绝$field=$value', () {
        final json = fixture();
        json['assets'][1][field] = value;
        expect(() => AppUpdateManifest.fromJson(json), throwsFormatException);
      });
    }
  }
  test('重复附件、第二APK和错版本APK均拒绝', () {
    final duplicate = fixture();
    duplicate['assets'].add(duplicate['assets'][1]);
    expect(() => AppUpdateManifest.fromJson(duplicate), throwsFormatException);
    final extra = fixture();
    extra['assets'].add({...extra['assets'][1] as Map, 'name': 'other.apk'});
    expect(() => AppUpdateManifest.fromJson(extra), throwsFormatException);
    final wrong = fixture();
    wrong['assets'][1]['name'] = '公民·Android·v2.0.0.apk';
    expect(() => AppUpdateManifest.fromJson(wrong), throwsFormatException);
  });
  test('不接受被替代的固定更新清单结构', () {
    expect(
      () => AppUpdateManifest.fromJson({
        'app': 'citizenapp',
        'platform': 'android',
        'package_name': 'com.crcfrcn.citizenapp',
        'version_name': '1.2.3',
        'version_code': 9,
        'apk_asset': 'update.apk',
        'apk_sha256': 'a' * 64,
      }),
      throwsFormatException,
    );
  });
}
