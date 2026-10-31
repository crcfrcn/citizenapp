import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:citizen_system/update/app_update_installer.dart';
import 'package:citizen_system/update/app_update_manifest.dart';

class AppUpdateService {
  AppUpdateService({
    AppUpdateInstaller? installer,
    http.Client? client,
    bool? isAndroid,
  }) : _installer = installer ?? AppUpdateInstaller(),
       _client = client ?? http.Client(),
       _isAndroid = isAndroid ?? Platform.isAndroid;
  final AppUpdateInstaller _installer;
  final http.Client _client;
  final bool _isAndroid;

  Future<AppVersionInfo> readCurrentVersion() => _installer.getPackageInfo();

  /// 是否可更新以当前设备商店为准，GitHub发布或商店草稿不代表已上架。
  Future<AppUpdateInfo?> checkUpdate(AppVersionInfo current) async {
    if (_isAndroid) {
      final value = await _installer.checkStoreUpdate().timeout(
        const Duration(seconds: 15),
      );
      if (value['available'] is! bool) {
        throw const FormatException('Google Play状态无效');
      }
      if (value['available'] == false) return null;
      final code = value['versionCode'];
      if (code is! int || code <= 0) {
        throw const FormatException('Google Play构建号无效');
      }
      return code > current.versionCode ? const AppUpdateInfo() : null;
    }
    final store = await _installer.getStoreInfo().timeout(
      const Duration(seconds: 15),
    );
    final id = store['appId'], country = store['country'];
    if (id is! String ||
        !RegExp(r'^[0-9]+$').hasMatch(id) ||
        country is! String ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw const FormatException('App Store商品或地区不可用');
    }
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'id': id,
      'country': country,
    });
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const HttpException('读取App Store版本失败');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('商店响应过大');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic> || value['results'] is! List) {
      throw const FormatException('App Store响应无效');
    }
    final rows = value['results'] as List;
    if (rows.isEmpty) return null; // 当前商店尚未上架或不可安装，不显示更新。
    if (rows.length != 1 || rows.first is! Map<String, dynamic>) {
      throw const FormatException('商店商品不唯一');
    }
    final app = rows.first as Map<String, dynamic>;
    if (app['trackId'].toString() != id ||
        app['bundleId'] != current.packageName ||
        app['version'] is! String) {
      throw const FormatException('App Store商品与当前应用不符');
    }
    final version = app['version'] as String;
    return newerVersion(version, current.versionName)
        ? AppUpdateInfo(version: version)
        : null;
  }

  Future<bool> openStore() => _installer.openStore();
}
