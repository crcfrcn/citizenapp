import 'package:flutter/services.dart';
import 'package:citizen_system/update/app_update_manifest.dart';

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
