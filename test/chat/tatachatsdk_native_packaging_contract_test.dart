import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

// 宿主脚本是独占普通副本；按既定source-view映射回读正式原文，并验真副本字节。
String _originalSourceRoot(String sourceScript) {
  final script = File(sourceScript);
  final project = script.parent.parent.path;
  const marker = '/source-view/';
  final candidates = <String>[];
  for (var start = 0; ;) {
    final index = project.indexOf(marker, start);
    if (index < 0) break;
    start = index + marker.length;
    final candidate = project.substring(index + marker.length - 1);
    if (!project.startsWith('$candidate/target/')) continue;
    final original = File('$candidate/scripts/build.mjs');
    if (Directory(candidate).resolveSymbolicLinksSync() != candidate ||
        FileSystemEntity.typeSync(original.path, followLinks: false) !=
            FileSystemEntityType.file ||
        original.readAsStringSync() != script.readAsStringSync()) {
      throw StateError('消费脚本与正式来源不一致');
    }
    candidates.add(candidate);
  }
  if (candidates.length > 1) throw StateError('正式来源映射不唯一');
  return candidates.isEmpty ? project : candidates.single;
}

void main() {
  test(
    'CitizenApp consumes TataChatSDK product output without source staging',
    () {
      final buildSource = File('scripts/build.mjs').readAsStringSync();
      final match = RegExp(
        r'export const BUILD_SHELL_SOURCES=Object.freeze\((\{[^\n]+\})\);',
      ).firstMatch(buildSource);
      expect(match, isNotNull);
      final shellSources = jsonDecode(match!.group(1)!) as Map<String, dynamic>;
      final runner = shellSources['run'] as String;
      final testRunner = shellSources['test'] as String;
      final sourceScript = File('scripts/build.mjs').resolveSymbolicLinksSync();
      final sourceRoot = _originalSourceRoot(sourceScript);
      final pubspec = File('$sourceRoot/pubspec.yaml').readAsStringSync();
      final pubLock = File('$sourceRoot/pubspec.lock').readAsStringSync();
      final podfile = File('ios/Podfile').readAsStringSync();
      final lockfile = File('ios/Podfile.lock').readAsStringSync();

      expect(runner, contains('TATACHATSDK_NATIVE_IOS_DIR='));
      expect(runner, contains('ios/TataChatSDK.xcframework'));
      expect(runner, contains('project-framework'));
      expect(runner, isNot(contains('TATACHATSDK_APPLE_FRAMEWORK_DIR')));
      expect(runner, contains(r'verify-ios-package "$IOS_APP"'));
      expect(pubspec, contains('https://github.com/tuyutata/tatachatsdk.git'));
      expect(pubspec, contains('29b7e4377833802a0a9f833c44c3e92036bd8493'));
      // App取消独立密码学与包装存储插件，钱包上游传递依赖保持原锁。
      expect(
        RegExp(
          r'^  (?:cryptography|flutter_secure_storage):',
          multiLine: true,
        ).hasMatch(pubspec),
        isFalse,
      );
      expect(
        RegExp(
          r'^  flutter_secure_storage(?:_\w+)?:',
          multiLine: true,
        ).hasMatch(pubLock),
        isFalse,
      );
      expect(lockfile, isNot(contains('flutter_secure_storage')));
      expect(testRunner, contains('dependencies'));
      // 原始产品声明只读；所有环境从同一锁定Git SDK取得本轮视图，不增加override配置。
      expect(runner, isNot(contains('pubspec_overrides.yaml')));
      expect(runner, isNot(contains('cleanup_direct_source_state')));
      expect(runner, isNot(contains(r'rm -f "$TATACHATSDK_ROOT/ios/')));
      expect(runner, contains(r'flutter pub get "${PUB_GET_ARGS[@]}"'));
      expect(runner, contains('flutter build ios --no-pub --release'));
      expect(
        runner,
        contains(
          r'GRADLE_EXECUTABLE="${CITIZENAPP_GRADLE:-$CITIZENAPP_PROJECT_ROOT/android/gradlew}"',
        ),
      );
      expect(
        runner,
        contains(r'[[ "$GRADLE_EXECUTABLE" == /* && -f "$GRADLE_EXECUTABLE"'),
      );
      expect(
        runner,
        contains(
          r'"$GRADLE_EXECUTABLE" ${gradle_network_arg:+"$gradle_network_arg"}',
        ),
      );
      expect(runner, isNot(contains('GRADLE_NETWORK_ARGS')));
      expect(runner, contains('gradle.beforeSettings { settings ->'));
      expect(runner, contains('settings.pluginManagement.repositories'));
      expect(runner, isNot(contains('resolutionStrategy.force')));
      expect(runner, isNot(contains('\nflutter pub get\n')));
      expect(testRunner, isNot(contains('pubspec_overrides.yaml')));
      expect(testRunner, contains(r'pub get "${PUB_GET_ARGS[@]}"'));
      expect(podfile, contains('TataChatSDK 通过自身 Flutter FFI plugin'));
      expect(lockfile, contains('- tatachat_sdk (1.0.0)'));
    },
  );
  // 合成工程验证普通复制后的来源归属；改写消费副本必须失败且原文不变。
  test('source-view读取正式来源，脚本副本漂移拒绝', () {
    final area = Directory.systemTemp.createTempSync('native-contract-source-');
    try {
      final owner = Directory('${area.path}/owner')..createSync();
      final original = File('${owner.path}/scripts/build.mjs');
      original.parent.createSync();
      original.writeAsStringSync('locked product script');
      expect(_originalSourceRoot(original.path), owner.path);
      final view = Directory(
        '${owner.path}/target/ios/test/task/source-view${owner.path}',
      )..createSync(recursive: true);
      final copy = File('${view.path}/scripts/build.mjs');
      copy.parent.createSync();
      original.copySync(copy.path);
      expect(_originalSourceRoot(copy.path), owner.path);
      copy.writeAsStringSync('changed task copy');
      expect(() => _originalSourceRoot(copy.path), throwsStateError);
      expect(original.readAsStringSync(), 'locked product script');
    } finally {
      area.deleteSync(recursive: true);
    }
  });
}
