import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/platform_input.dart';

void main() {
  test('App直接依赖公开SDK且保留唯一应用身份', () {
    final source = Platform.environment['CITIZENAPP_SOURCE_ROOT'] ?? Directory.current.path;
    final manifest = File('$source/pubspec.yaml').readAsStringSync();
    final lock = File('$source/pubspec.lock').readAsStringSync();
    expect(manifest, contains('https://github.com/tuyutata/tatachatsdk.git'));
    final record = RegExp(r'^  tatachat_sdk:\n(?:    .*\n|\n)+', multiLine: true).firstMatch(manifest)!.group(0)!;
    // 声明沿用main，锁只记录基线；本轮依赖由既有装配入口冻结。
    expect(record, contains('ref: main'));
    final locked = RegExp(r'^  tatachat_sdk:\n(?:    .*\n|\n)+', multiLine: true).firstMatch(lock)!.group(0)!;
    expect(locked, contains('ref: main'));
    expect(locked, contains('https://github.com/tuyutata/tatachatsdk.git'));
    expect(locked, matches(RegExp(r'resolved-ref: "?[a-f0-9]{40}"?')));
    expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('applicationId = "com.crcfrcn.citizenapp"'));
    expect(File('ios/source/Info.plist').readAsStringSync(), contains('CFBundleIdentifier'));
    expect(platformInput('ios/Podfile'), contains('flutter_install_all_ios_pods'));
    final plugins = jsonDecode(File('.flutter-plugins-dependencies').readAsStringSync()) as Map<String, dynamic>;
    for (final platform in ['ios', 'android']) {
      expect((plugins['plugins'][platform] as List<dynamic>).where((row) => row['name'] == 'tatachat_sdk'), hasLength(1));
    }
  });
  test('原生平台与FFI合同只消费SDK公开插件', () {
    final config = File('.dart_tool/package_config.json');
    final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
    final entry = packages.cast<Map<String, dynamic>>().singleWhere((row) => row['name'] == 'tatachat_sdk');
    final sdk = Directory.fromUri(
      config.absolute.uri.resolve(entry['rootUri'] as String),
    ).uri;
    expect(File.fromUri(sdk.resolve('android/src/main/java/chat/tata/sdk/TataChatSdkPlugin.java')).readAsStringSync(), contains('class TataChatSdkPlugin'));
    final pod = File.fromUri(sdk.resolve('ios/tatachat_sdk.podspec')).readAsStringSync();
    expect(pod, contains('spec.vendored_frameworks = framework_path'));
    expect(File.fromUri(sdk.resolve('lib/mls/mls_native.dart')).readAsStringSync(), isNot(contains('PRODUCT_WORK_LEASE')));
    expect(File.fromUri(sdk.resolve('lib/mls/mls_native.dart')).readAsStringSync(), isNot(contains('.active.json')));
  });
}
