// 隔离真实Isar测试目录，保留业务库与聊天库各自的初始化和清理入口。

import 'dart:io';

import 'package:citizen_storage/chat.dart';
import 'package:citizen_storage/core.dart';
import 'package:citizen_storage/social.dart';
import 'package:citizen_storage/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// 为每个聊天测试创建独占数据库，并加载本轮锁定Isar库。

/// 每个测试文件独占物理数据库，只接受由原锁定位的本轮Isar动态库。
void useIsolatedChatIsar() {
  Directory? directory;
  setUpAll(() async {
    final work = Platform.environment['CITIZENAPP_TEST_WORK_DIR'];
    final library = Platform.environment['ISAR_CORE_LIB_PATH'];
    if (work == null ||
        library == null ||
        !path.isAbsolute(work) ||
        !path.isAbsolute(library) ||
        Directory(work).resolveSymbolicLinksSync() != work ||
        FileSystemEntity.typeSync(library, followLinks: false) !=
            FileSystemEntityType.file ||
        File(library).resolveSymbolicLinksSync() != library ||
        !path.isWithin(work, library)) {
      throw StateError('Isar测试必须使用本轮Pub原锁交付的动态库');
    }
    final owned = await Directory.systemTemp.createTemp('chat_test_');
    directory = owned;
    IsarCoreBootstrap.debugTestDirectoryOverride = owned.path;
    await IsarCoreBootstrap.ensureTestCoreInitialized();
  });
  setUp(() => ChatIsar.instance.resetForTest());
  tearDown(() => ChatIsar.instance.resetForTest());
  tearDownAll(() async {
    try {
      await ChatIsar.instance.resetForTest();
    } finally {
      IsarCoreBootstrap.debugTestDirectoryOverride = null;
      final owned = directory;
      if (owned != null && owned.existsSync()) {
        await owned.delete(recursive: true);
      }
    }
  });
}

// 按测试文件隔离真实Isar目录，并管理各业务数据库的打开和清理。

/// 每个测试文件拥有真实隔离数据库，测试环境不注入应用数据密钥。
void useIsolatedIsar() {
  late Directory dir;
  IOOverrides? previous;
  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('citizenapp_test_');
    previous = IOOverrides.current;
    // SDK自己的测试库沿用Directory.systemTemp；用Dart公开IO接口隔离当前测试isolate。
    IOOverrides.global = _TestDirectory(dir);
    IsarCoreBootstrap.debugTestDirectoryOverride = dir.path;
    await IsarCoreBootstrap.ensureTestCoreInitialized();
  });
  setUp(() async {
    await _resetAllIsar();
  });
  tearDown(() async {
    await _resetAllIsar();
  });
  tearDownAll(() async {
    await _resetAllIsar();
    IsarCoreBootstrap.debugTestDirectoryOverride = null;
    IOOverrides.global = previous;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
}

final class _TestDirectory extends IOOverrides {
  _TestDirectory(this.directory);
  final Directory directory;
  @override
  Directory getSystemTempDirectory() => directory;
}

Future<void> _resetAllIsar() async {
  await UserIsar.instance.resetForTest();
  await ChatIsar.instance.resetForTest();
  await SocialIsar.instance.resetForTest();
}
