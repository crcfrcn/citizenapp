import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:citizen_system/update/app_update_installer.dart';
import 'package:citizen_system/update/app_update_manifest.dart';

typedef AppUpdateDownloadProgress = void Function(
  int receivedBytes,
  int? totalBytes,
);

class AppUpdateService {
  AppUpdateService({AppUpdateInstaller? installer, http.Client? client})
    : _installer = installer ?? AppUpdateInstaller(),
      _client = client ?? http.Client();

  static final Uri _releasesUri = Uri.parse(
    'https://api.github.com/repos/crcfrcn/citizenapp/releases',
  );
  final AppUpdateInstaller _installer;
  final http.Client _client;

  /// 本机安装包版本读取与联网更新检查分离，关于页不因远端失败丢失本机版本。
  Future<AppVersionInfo> readCurrentVersion() => _installer.getPackageInfo();

  /// 调用方先完成平台门禁，iOS不得进入Android检查。
  Future<AppUpdateInfo?> checkAndroidUpdate(
    AppVersionInfo currentVersion,
  ) async {
    AppUpdateInfo? latest;
    final versions = <int>{};
    final tags = <String>{};
    // Release顺序不是版本顺序；完整分页后才决定最高可升级构建号。
    for (var page = 1; ; page++) {
      final uri = _releasesUri.replace(
        queryParameters: {'per_page': '100', 'page': '$page'},
      );
      final rows = await _readJson(uri);
      if (rows is! List) throw const FormatException('GitHub Release列表格式无效');
      for (final release in rows) {
        if (release is! Map<String, dynamic> ||
            release['draft'] == true ||
            release['prerelease'] == true) {
          continue;
        }
        final tag = release['tag_name'];
        if (tag is! String ||
            !RegExp(
              r'^公民·Android·v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
            ).hasMatch(tag)) {
          continue;
        }
        if (release['name'] != tag ||
            release['published_at'] is! String ||
            DateTime.tryParse(release['published_at'] as String) == null ||
            !tags.add(tag)) {
          throw const FormatException('Android Release名称、发布时间或唯一性无效');
        }
        final assets = release['assets'];
        final proof = _asset(assets, '$tag.json');
        final manifest = AppUpdateManifest.fromJson(
          _object(await _readJson(_https(proof['browser_download_url']))),
        );
        if ('公民·Android·v${manifest.version}' != tag) {
          throw const FormatException('发布证明与Release版本不一致');
        }
        if (!manifest.matchesAndroidPackage(currentVersion.packageName)) {
          continue;
        }
        if (!versions.add(manifest.versionCode)) {
          throw const FormatException('Android发布构建号重复');
        }
        final apk = _asset(assets, manifest.apkAsset);
        if (apk['size'] != manifest.apkSize) {
          throw const FormatException('Release APK大小与发布证明不一致');
        }
        final url = _https(apk['browser_download_url']);
        if (manifest.versionCode > currentVersion.versionCode &&
            (latest == null ||
                manifest.versionCode > latest.manifest.versionCode)) {
          latest = AppUpdateInfo(manifest: manifest, apkDownloadUrl: url);
        }
      }
      if (rows.length < 100) break;
    }
    return latest;
  }

  Future<File> downloadUpdate(
    AppUpdateInfo update, {
    AppUpdateDownloadProgress? onProgress,
  }) async {
    final response = await _send(update.apkDownloadUrl);
    final expected = update.manifest.apkSize;
    if (response.contentLength != null && response.contentLength != expected) {
      await _discard(response);
      throw StateError('APK下载长度与发布证明不一致');
    }
    final tempDir = await getTemporaryDirectory();
    // 每次下载独占文件，失败只清理本次现场，不触碰其它在途下载。
    final directory = await tempDir.createTemp('citizenapp-update-');
    final apkFile = File('${directory.path}/update.apk');
    try {
      final output = await apkFile.open(mode: FileMode.write);
      final digestSink = _DigestSink();
      final hashInput = sha256.startChunkedConversion(digestSink);
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (received > expected) throw StateError('APK超过发布证明大小');
          await output.writeFrom(chunk);
          hashInput.add(chunk);
          onProgress?.call(received, expected);
        }
        await output.flush();
      } finally {
        hashInput.close();
        await output.close();
      }
      if (received != expected ||
          digestSink.digest.toString() != update.manifest.apkSha256) {
        throw StateError('APK大小或SHA-256校验失败，已拒绝安装');
      }
      return apkFile;
    } catch (error) {
      await directory.delete(recursive: true);
      if (error is http.ClientException || error is IOException) {
        throw const HttpException('更新网络传输失败');
      }
      rethrow;
    }
  }

  Future<bool> installApk(File apkFile) => _installer.installApk(apkFile.path);

  Future<Object?> _readJson(Uri uri) async {
    final response = await _send(uri);
    try {
      return jsonDecode(await response.stream.bytesToString());
    } on http.ClientException {
      throw const HttpException('更新网络传输失败');
    } on IOException {
      throw const HttpException('更新网络传输失败');
    }
  }

  Future<void> _discard(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } on http.ClientException {
      throw const HttpException('更新网络传输失败');
    } on IOException {
      throw const HttpException('更新网络传输失败');
    }
  }

  /// 手动跟随HTTPS重定向，禁止客户端默认跟随到明文地址。
  Future<http.StreamedResponse> _send(Uri uri) async {
    var current = _https(uri.toString());
    for (var redirects = 0; ; redirects++) {
      final request = http.Request('GET', current)..followRedirects = false;
      request.headers.addAll(const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'citizenapp-android-updater',
      });
      // GitHub重定向地址可能含临时签名，网络错误不向日志交付原URL。
      final http.StreamedResponse response;
      try {
        response = await _client.send(request);
      } on http.ClientException {
        throw const HttpException('更新网络请求失败');
      } on IOException {
        throw const HttpException('更新网络请求失败');
      }
      if (response.statusCode == HttpStatus.ok) return response;
      await _discard(response);
      if ([301, 302, 303, 307, 308].contains(response.statusCode) &&
          redirects < 5) {
        final location = response.headers['location'];
        if (location == null) throw const FormatException('更新重定向缺少地址');
        try {
          current = _https(current.resolve(location).toString());
        } on FormatException {
          throw const FormatException('更新重定向地址无效');
        }
        continue;
      }
      throw HttpException('读取更新失败：HTTP ${response.statusCode}');
    }
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('发布证明JSON格式无效');
  }
  return value;
}

Map<String, dynamic> _asset(Object? assets, String label) {
  if (assets is! List) throw const FormatException('Release缺少附件列表');
  final matches = assets
      .whereType<Map<String, dynamic>>()
      .where((asset) => asset['label'] == label)
      .toList();
  if (matches.length != 1 || matches.single['state'] != 'uploaded') {
    throw FormatException('Release附件缺失、重复或上传未完成：$label');
  }
  return matches.single;
}

Uri _https(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('更新地址必须为有效HTTPS地址');
  }
  return uri;
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}
