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

/// 消费Android塔塔自动化的唯一发布证明，不另设更新清单格式。
class AppUpdateManifest {
  const AppUpdateManifest._({
    required this.packageName,
    required this.version,
    required this.versionCode,
    required this.apkAsset,
    required this.apkSize,
    required this.apkSha256,
  });

  final String packageName;
  final String version;
  final int versionCode;
  final String apkAsset;
  final int apkSize;
  final String apkSha256;

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final packageName = json['package_name'];
    final versionCode = json['version_code'];
    final assets = json['assets'];
    if (json['schema'] is! int ||
        json['schema'] != 1 ||
        json['product_id'] != 'citizenapp' ||
        json['platform'] != 'android' ||
        version is! String ||
        !RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')
            .hasMatch(version) ||
        packageName is! String ||
        packageName.isEmpty ||
        packageName.trim() != packageName ||
        versionCode is! int ||
        versionCode <= 0 ||
        assets is! List) {
      throw const FormatException('Android发布证明格式无效');
    }
    final name = '公民·Android·v$version.apk';
    final names = <String>{};
    Map<String, dynamic>? apk;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic> ||
          asset['name'] is! String ||
          !names.add(asset['name'] as String) ||
          asset['size'] is! int ||
          (asset['size'] as int) <= 0 ||
          asset['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(asset['sha256'] as String)) {
        throw const FormatException('发布附件名称、大小或摘要无效');
      }
      if ((asset['name'] as String).endsWith('.apk')) {
        if (asset['name'] != name || apk != null) {
          throw const FormatException('发布证明含不匹配的APK');
        }
        apk = asset;
      }
    }
    if (apk == null) throw const FormatException('发布证明缺少APK');
    return AppUpdateManifest._(
      packageName: packageName,
      version: version,
      versionCode: versionCode,
      apkAsset: name,
      apkSize: apk['size'] as int,
      apkSha256: apk['sha256'] as String,
    );
  }

  bool matchesAndroidPackage(String expectedPackageName) =>
      packageName == expectedPackageName;
}

class AppUpdateInfo {
  const AppUpdateInfo({required this.manifest, required this.apkDownloadUrl});

  final AppUpdateManifest manifest;
  final Uri apkDownloadUrl;
}
