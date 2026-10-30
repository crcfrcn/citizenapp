import 'package:citizen_testing/fixture.dart';

import 'dart:convert';
import 'dart:io';

import 'package:citizen_system/update/app_update_controller.dart';
import 'package:citizen_system/update/app_update_installer.dart';
import 'package:citizen_system/update/app_update_manifest.dart';
import 'package:citizen_system/update/app_update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const current = AppVersionInfo(
  packageName: 'com.crcfrcn.citizenapp',
  versionName: '1.0.0',
  versionCode: 7,
);
const payload = 'citizenapp-update-fixture';
Map<String, dynamic> proof({int code = 9, String version = '1.2.3'}) {
  final value = jsonDecode(
    fixtureFile('citizen_system', 'update_fixture.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  value['version_code'] = code;
  value['version'] = version;
  for (final asset in value['assets'] as List) {
    asset['name'] = (asset['name'] as String).replaceAll('1.2.3', version);
  }
  return value;
}

Map<String, dynamic> release(Map<String, dynamic> value) {
  final title = '公民·Android·v${value['version']}';
  return {
    'name': title,
    'tag_name': title,
    'draft': false,
    'prerelease': false,
    'published_at': '2026-10-29T00:00:00Z',
    'assets': <Map<String, dynamic>>[
      for (final extension in ['json', 'apk'])
        <String, dynamic>{
          // GitHub文件名可以被规范化，只有原label参与合同匹配。
          'name': 'normalized.${value['version_code']}.$extension',
          'label': '$title.$extension',
          'state': 'uploaded', 'size': 25,
          'browser_download_url':
              'https://updates.example/${value['version_code']}.$extension',
        },
    ],
  };
}

http.StreamedResponse response(Object? value, {int status = 200}) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(value))), status);

class Client extends http.BaseClient {
  Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    expect(request.url.scheme, 'https');
    expect(request.followRedirects, isFalse);
    return handler(request);
  }
}

class Installer extends AppUpdateInstaller {
  final paths = <String>[];
  @override
  Future<AppVersionInfo> getPackageInfo() async => current;
  @override
  Future<bool> installApk(String path) async {
    paths.add(path);
    return true;
  }
}

AppUpdateInfo update() => AppUpdateInfo(
  manifest: AppUpdateManifest.fromJson(proof()),
  apkDownloadUrl: Uri.parse('https://updates.example/9.apk'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() {
    temp = Directory(Platform.environment['WORK']!)
        .createTempSync('update-case-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            expect(call.method, 'getTemporaryDirectory');
            return temp.path;
          },
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    temp.deleteSync(recursive: true);
  });
  test('完整分页、旧项在前、混合平台及乱序仍选择最高构建号', () async {
    final old = proof(code: 6, version: '1.0.0'),
        latest = proof(code: 12, version: '1.3.0');
    final calls = <Uri>[];
    final service = AppUpdateService(
      client: Client((request) async {
        calls.add(request.url);
        if (request.url.host == 'api.github.com') {
          expect(request.url.queryParameters['per_page'], '100');
          return response(
            request.url.queryParameters['page'] == '1'
                ? [
                    release(old),
                    ...List.generate(99, (_) => {'tag_name': '公民·iOS·v1.2.3'}),
                  ]
                : [
                    release(proof()),
                    release(latest),
                    {...release(proof()), 'draft': true},
                    {...release(proof()), 'prerelease': true},
                  ],
          );
        }
        return response(
          {
            '/6.json': old,
            '/9.json': proof(),
            '/12.json': latest,
          }[request.url.path],
        );
      }),
    );
    final result = await service.checkAndroidUpdate(current);
    expect(result!.manifest.versionCode, 12);
    expect(result.apkDownloadUrl.path, '/12.apk');
    expect(calls.where((url) => url.host == 'api.github.com').length, 2);
    expect(calls.every((url) => !url.path.contains('normalized')), isTrue);
  });
  test('同版、旧版、空列表及其它应用没有更新', () async {
    for (final code in [null, 6, 7, 9]) {
      final value = proof(code: code ?? 9);
      if (code == 9) value['package_name'] = 'other.app';
      final rows = code == null ? [] : [release(value)];
      final service = AppUpdateService(
        client: Client(
          (r) async => response(r.url.host == 'api.github.com' ? rows : value),
        ),
      );
      expect(await service.checkAndroidUpdate(current), isNull);
    }
  });
  for (final kind in [
    'name',
    'published',
    'duplicate proof',
    'duplicate apk',
    'missing proof',
    'missing apk',
    'name only',
    'uploading',
    'size',
    'version',
    'duplicate code',
    'duplicate tag',
    'http url',
    'proof json',
  ]) {
    test('正式候选$kind错误明确失败，不返回旧包', () async {
      final value = proof(), row = release(proof());
      final rows = [row];
      final assets = row['assets'] as List;
      switch (kind) {
        case 'name':
          row['name'] = 'other';
        case 'published':
          row['published_at'] = null;
        case 'duplicate proof':
          assets.add({...assets[0] as Map<String, dynamic>});
        case 'duplicate apk':
          assets.add({...assets[1] as Map<String, dynamic>});
        case 'missing proof':
          assets.removeAt(0);
        case 'missing apk':
          assets.removeAt(1);
        case 'name only':
          assets[0]['name'] = assets[0]['label'];
          assets[0]['label'] = null;
        case 'uploading':
          assets[1]['state'] = 'new';
        case 'size':
          assets[1]['size'] = 26;
        case 'version':
          value['version'] = '2.0.0';
        case 'duplicate code':
          final duplicate = release(proof(version: '1.3.0'));
          duplicate['assets'][0]['browser_download_url'] =
              'https://updates.example/duplicate.json';
          rows.add(duplicate);
        case 'duplicate tag':
          rows.add(row);
        case 'http url':
          assets[0]['browser_download_url'] = 'http://updates.example/9.json';
        case 'proof json':
          break;
      }
      final service = AppUpdateService(
        client: Client(
          (r) async => response(
            r.url.host == 'api.github.com'
                ? rows
                : kind == 'proof json'
                ? []
                : r.url.path == '/duplicate.json'
                ? proof(version: '1.3.0')
                : value,
          ),
        ),
      );
      await expectLater(
        service.checkAndroidUpdate(current),
        throwsFormatException,
      );
    });
  }
  for (final stage in ['list', 'proof', 'page2']) {
    test('$stage真实HTTP失败不能返回空或旧包', () async {
      final service = AppUpdateService(
        client: Client((r) async {
          if (stage == 'list' ||
              stage == 'proof' && r.url.host != 'api.github.com' ||
              stage == 'page2' && r.url.queryParameters['page'] == '2') {
            return response({}, status: 503);
          }
          return response(
            r.url.host == 'api.github.com'
                ? stage == 'page2'
                      ? List.generate(100, (_) => {'tag_name': 'other'})
                      : [release(proof())]
                : proof(),
          );
        }),
      );
      await expectLater(
        service.checkAndroidUpdate(current),
        throwsA(isA<HttpException>()),
      );
    });
  }
  test('列表与证明无效JSON明确失败', () async {
    for (final atProof in [false, true]) {
      final service = AppUpdateService(
        client: Client((r) async {
          if (atProof && r.url.host == 'api.github.com') {
            return response([release(proof())]);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode('invalid JSON')),
            200,
          );
        }),
      );
      await expectLater(
        service.checkAndroidUpdate(current),
        throwsFormatException,
      );
    }
  });
  test('只接受HTTPS重定向并限制循环', () async {
    for (final location in [
      'http://updates.example/9.apk',
      'https://updates.example/loop',
    ]) {
      var calls = 0;
      final service = AppUpdateService(
        client: Client((r) async {
          calls++;
          return http.StreamedResponse(
            const Stream.empty(),
            302,
            headers: {'location': location},
          );
        }),
      );
      await expectLater(
        service.downloadUpdate(update()),
        throwsA(isA<Exception>()),
      );
      expect(calls, location.startsWith('http:') ? 1 : 6);
      expect(temp.listSync(), isEmpty);
    }
  });
  test('HTTPS相对重定向后按证明大小报告进度，只返回已验证文件', () async {
    final progress = <List<int?>>[];
    final service = AppUpdateService(
      client: Client(
        (r) async => r.url.path == '/9.apk'
            ? http.StreamedResponse(
                const Stream.empty(),
                302,
                headers: {'location': '/verified'},
              )
            : http.StreamedResponse(
                Stream.fromIterable([
                  utf8.encode(payload.substring(0, 5)),
                  utf8.encode(payload.substring(5)),
                ]),
                200,
              ),
      ),
    );
    final file = await service.downloadUpdate(
      update(),
      onProgress: (received, total) => progress.add([received, total]),
    );
    expect(await file.readAsString(), payload);
    expect(progress, [
      [5, 25],
      [25, 25],
    ]);
    expect(temp.listSync().length, 1);
  });
  for (final failure in [
    'http',
    'header',
    'short',
    'long',
    'hash',
    'stream',
    'progress',
  ]) {
    test('下载$failure失败清理未验证文件且绝不调用安装', () async {
      final installer = Installer();
      final service = AppUpdateService(
        installer: installer,
        client: Client((r) async {
          if (r.url.host == 'api.github.com') {
            return response([release(proof())]);
          }
          if (r.url.path.endsWith('.json')) return response(proof());
          if (failure == 'http') return response({}, status: 404);
          final bytes = utf8.encode(
            failure == 'short'
                ? 'short'
                : failure == 'long'
                ? '$payload!'
                : failure == 'hash'
                ? 'x' * 25
                : payload,
          );
          final stream = failure == 'stream'
              ? (() async* {
                  yield bytes.sublist(0, 4);
                  throw const HttpException('合成中断');
                })()
              : Stream.value(bytes);
          return http.StreamedResponse(
            stream,
            200,
            contentLength: failure == 'header' ? 26 : null,
          );
        }),
      );
      if (failure == 'progress') {
        await expectLater(
          service.downloadUpdate(
            update(),
            onProgress: (_, _) => throw StateError('合成回调失败'),
          ),
          throwsStateError,
        );
      } else {
        final controller = AppUpdateController.forTesting(
          service: service,
          isAndroid: true,
        );
        addTearDown(controller.dispose);
        await controller.check();
        expect(controller.state.hasUpdate, isTrue);
        expect(await controller.downloadAndInstall(), isFalse);
        expect(controller.state.status, AppUpdateStatus.error);
        expect(controller.state.versionLabel, 'v1.0.0');
      }
      expect(temp.listSync(), isEmpty);
      expect(installer.paths, isEmpty);
    });
  }
  test('校验成功后控制器只向原安装接口交付同一文件', () async {
    final installer = Installer();
    final service = AppUpdateService(
      installer: installer,
      client: Client((r) async {
        if (r.url.host == 'api.github.com') return response([release(proof())]);
        if (r.url.path.endsWith('.json')) return response(proof());
        return http.StreamedResponse(
          Stream.value(utf8.encode(payload)),
          200,
          contentLength: 25,
        );
      }),
    );
    final controller = AppUpdateController.forTesting(
      service: service,
      isAndroid: true,
    );
    addTearDown(controller.dispose);
    await controller.check();
    expect(await controller.downloadAndInstall(), isTrue);
    expect(installer.paths, [controller.state.downloadedApk!.path]);
    expect(File(installer.paths.single).readAsStringSync(), payload);
    expect(controller.state.status, AppUpdateStatus.available);
  });
  test('临时签名地址不进入请求和流异常，失败文件仍清空', () async {
    for (final stage in [
      'request',
      'proof',
      'download',
      'redirect',
      'redirect stream',
      'header',
    ]) {
      final error = http.ClientException(
        '合成网络异常',
        Uri.parse('https://updates.example/?synthetic=private-marker'),
      );
      final service = AppUpdateService(
        client: Client((r) async {
          if (stage == 'request') {
            throw error;
          }
          if (stage == 'redirect stream') {
            return http.StreamedResponse(
              Stream.error(error),
              302,
              headers: {
                'location': 'https://updates.example/?synthetic=private-marker',
              },
            );
          }
          if (stage == 'header') {
            return http.StreamedResponse(
              Stream.error(error),
              200,
              contentLength: 26,
            );
          }
          if (stage == 'redirect') {
            return http.StreamedResponse(
              const Stream.empty(),
              302,
              headers: {
                'location': 'https://updates.example/?synthetic=private-marker',
              },
            );
          }
          if (stage == 'proof' && r.url.host == 'api.github.com') {
            return response([release(proof())]);
          }
          return http.StreamedResponse(Stream.error(error), 200);
        }),
      );
      await expectLater(
        stage == 'download' || stage.startsWith('redirect') || stage == 'header'
            ? service.downloadUpdate(update())
            : service.checkAndroidUpdate(current),
        throwsA(
          isA<HttpException>().having(
            (e) => e.toString().contains('private-marker'),
            '不输出签名参数',
            isFalse,
          ),
        ),
      );
      expect(temp.listSync(), isEmpty);
    }
  });
}
