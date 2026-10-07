import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CitizenApp consumes TataChatSDK product output without source staging',
    () {
      final runner = File('scripts/citizenapp-run.sh').readAsStringSync();
      final testRunner = File('scripts/citizenapp-test.sh').readAsStringSync();
      final sourceScript = File(
        'scripts/citizenapp-test.sh',
      ).resolveSymbolicLinksSync();
      final sourceRoot = File(sourceScript).parent.parent.path;
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
        RegExp(r'^  (?:cryptography|flutter_secure_storage):', multiLine: true)
            .hasMatch(pubspec),
        isFalse,
      );
      expect(
        RegExp(r'^  flutter_secure_storage(?:_\w+)?:', multiLine: true)
            .hasMatch(pubLock),
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
}
