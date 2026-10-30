import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

/// CitizenApp 各业务 Isar 实例共用的底层启动能力。
///
/// 本类只负责定位数据库目录和 Flutter 测试期加载 Isar Core，不保存任何业务状态，
/// 也不提供跨业务数据库的统一操作队列。每个业务数据库必须拥有独立的打开、读写和
/// 关闭生命周期，禁止借本类重新形成全 App 活性依赖。
class IsarCoreBootstrap {
  IsarCoreBootstrap._();

  /// 仅测试使用：让同一测试文件内的多个业务数据库落入同一个隔离临时目录。
  static String? debugTestDirectoryOverride;

  static Future<void>? _testCoreInitialization;

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Flutter 测试没有移动端插件自动加载 Isar Core，所有业务库共用一次初始化。
  static Future<void> ensureTestCoreInitialized() async {
    if (!isFlutterTest) return;
    final inflight = _testCoreInitialization;
    if (inflight != null) return inflight;

    final task = _initializeTestCore();
    _testCoreInitialization = task;
    try {
      await task;
    } catch (_) {
      if (identical(_testCoreInitialization, task)) {
        _testCoreInitialization = null;
      }
      rethrow;
    }
  }

  static Future<String> resolveDirectory() async {
    if (kIsWeb) return '.';
    if (isFlutterTest) {
      return debugTestDirectoryOverride ?? Directory.systemTemp.path;
    }
    return (await getApplicationSupportDirectory()).path;
  }

  static Future<void> _initializeTestCore() async {
    final localPath = _resolveLocalIsarCorePath();
    if (localPath == null) {
      throw StateError(
        'Flutter测试缺少本轮锁定的Isar Core动态库，请通过产品入口准备。',
      );
    }
    await Isar.initializeIsarCore(
      libraries: <Abi, String>{Abi.current(): localPath},
    );
  }

  /// 仅消费本轮产品入口按Pub锁解析的显式库，不扫描用户缓存或猜测版本。
  static String? _resolveLocalIsarCorePath() {
    final path = Platform.environment['ISAR_CORE_LIB_PATH'];
    final work = Platform.environment['CITIZENAPP_TEST_WORK_DIR'];
    if (path == null || work == null || !File(path).isAbsolute || !Directory(work).isAbsolute) return null;
    final file = File(path);
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.file ||
        file.resolveSymbolicLinksSync() != path || Directory(work).resolveSymbolicLinksSync() != work ||
        !path.startsWith('$work${Platform.pathSeparator}')) {
      return null;
    }
    return path;
  }
}
