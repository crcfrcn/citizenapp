// 测试隔离:每个测试文件(独立 isolate)用唯一临时目录开各业务 Isar,从物理上根除
// 系统临时目录下同名数据库导致的并发锁竞争(30 秒超时)与磁盘残留污染。
//
// 打开真库的测试文件在 main() 顶部调一次 `useIsolatedIsar();` 即可,不再各自手写
// setUpAll(ensureTestCoreInitialized) / setUp / tearDown(resetForTest) 样板。

import 'dart:io';

import 'package:citizenapp/isar/social_isar.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:citizenapp/isar/app_isar.dart';
import 'package:citizenapp/isar/isar_core_bootstrap.dart';
import 'package:citizenapp/isar/user_isar.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每个测试文件拥有真实隔离数据库，测试环境不注入应用数据密钥。
void useIsolatedIsar() {
  late Directory dir;
  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('citizenapp_test_');
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
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
}

Future<void> _resetAllIsar() async {
  // libmdbx 的进程级实例注册表不保证多个不同 schema 同时 cold-open/delete；
  // 测试复位按域顺序执行，业务运行时的数据库和操作队列仍完全独立。
  await WalletIsar.instance.resetForTest();
  await ChatIsar.instance.resetForTest();
  await SocialIsar.instance.resetForTest();
  await UserIsar.instance.resetForTest();
  await AppIsar.instance.resetForTest();
}
