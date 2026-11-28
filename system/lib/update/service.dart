// 版本模型、原生通道及商店查询。

library ;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// 定义设备及商店版本模型，解析并按数值比较版本。

class AppVersionInfo {
  const AppVersionInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
  });
  final String packageName;
  final String versionName;
  final int versionCode;
  String get label => 'v$versionName';
}

/// 商店已向当前设备提供更新；Android商店不返回软件版本名称。
class AppUpdateInfo {
  const AppUpdateInfo({this.version});
  final String? version;
}

// Apple商店允许简短版本表示；仅比较时按缺省零分量处理，不改写展示值。
List<BigInt> versionParts(String value) {
  if (!RegExp(r'^(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*)){0,2}$').hasMatch(value)) {
    throw const FormatException('商店或安装包版本无效');
  }
  final result = value.split('.').map(BigInt.parse).toList();
  while (result.length < 3) {
    result.add(BigInt.zero);
  }
  return result;
}

bool newerVersion(String candidate, String current) {
  final left = versionParts(candidate), right = versionParts(current);
  for (var i = 0; i < 3; i++) {
    final comparison = left[i].compareTo(right[i]);
    if (comparison != 0) return comparison > 0;
  }
  return false;
}

// 通过原生通道读取设备版本、检查更新并打开对应商店。

/// 原生更新通道只读取设备/商店状态和打开商店，不下载或安装应用包。
class AppUpdateInstaller {
  static const MethodChannel _channel = MethodChannel('citizenapp/update');

  Future<AppVersionInfo> getPackageInfo() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getPackageInfo',
    );
    if (value == null ||
        value['packageName'] is! String ||
        value['versionName'] is! String ||
        value['versionCode'] is! int ||
        (value['versionCode'] as int) <= 0) {
      throw const FormatException('无法读取当前应用版本');
    }
    final name = value['versionName'] as String;
    versionParts(name);
    return AppVersionInfo(
      packageName: value['packageName'] as String,
      versionName: name,
      versionCode: value['versionCode'] as int,
    );
  }

  Future<Map<String, Object?>> checkStoreUpdate() async {
    return await _channel.invokeMapMethod<String, Object?>(
          'checkStoreUpdate',
        ) ??
        (throw const FormatException('无法读取Google Play更新状态'));
  }

  Future<Map<String, Object?>> getStoreInfo() async {
    return await _channel.invokeMapMethod<String, Object?>('getStoreInfo') ??
        (throw const FormatException('无法读取App Store登记'));
  }

  Future<bool> openStore() async =>
      await _channel.invokeMethod<bool>('openStore') ?? false;
}

// 依据当前设备商店的真实上架状态判断可用更新。

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
