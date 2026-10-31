/// 当前设备安装包的原生版本，独立于远端商店状态。
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
