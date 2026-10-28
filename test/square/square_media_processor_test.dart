import '../account/membership/membership_page_test.dart'
    show membergatePlansFixture, membergatePlanFixture;

import 'package:citizenapp/network/square_api_client.dart';

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/8964/media/square_media_policy.dart';
import 'package:citizenapp/8964/media/square_media_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('受保护播放文件原生通道', () {
    late Directory root;
    final calls = <MethodCall>[];
    var mode = '';
    setUp(() async {
      root = await Directory.systemTemp.createTemp('square_bridge_test_');
      calls.clear();
      mode = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('citizenapp/square_media'),
            (call) async {
              calls.add(call);
              if (mode == 'missing') throw MissingPluginException();
              if (call.method == 'prepare_playback_file') {
                if (mode == 'invalid') return 'relative.mp4';
                final file = await File('${root.path}/protected.mp4')
                    .create(exclusive: true);
                return file.resolveSymbolicLinks();
              }
              final args = call.arguments as Map;
              final file = File(args['output_path'] as String);
              if (call.method == 'verify_playback_file') {
                expect(await file.length(), args['byte_size']);
              } else if (call.method == 'delete_playback_file') {
                if (mode != 'delete_without_effect') await file.delete();
              }
              return null;
            },
          );
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('citizenapp/square_media'),
            null,
          );
      await root.delete(recursive: true);
    });
    test('准备、校验和删除使用同一原生归属路径与精确字段', () async {
      const bridge = MethodChannelSquareVideoBridge();
      final file = await bridge.preparePlaybackFile(3);
      await file.writeAsBytes([1, 2, 3]);
      await bridge.verifyPlaybackFile(file, 3);
      await bridge.deletePlaybackFile(file);
      expect(calls.map((c) => c.method), [
        'prepare_playback_file',
        'verify_playback_file',
        'delete_playback_file',
      ]);
      expect(calls[0].arguments, {'byte_size': 3});
      expect(calls[1].arguments, {'output_path': file.path, 'byte_size': 3});
      expect(calls[2].arguments, {'output_path': file.path});
      expect(await file.exists(), isFalse);
    });
    test('无原生保护实现、相对路径和越界尺寸全部失败', () async {
      const bridge = MethodChannelSquareVideoBridge();
      for (final size in [0, -1, 3 * 1024 * 1024 * 1024 + 1]) {
        await expectLater(
          bridge.preparePlaybackFile(size),
          throwsFormatException,
        );
      }
      expect(calls, isEmpty);
      mode = 'invalid';
      await expectLater(bridge.preparePlaybackFile(3), throwsFormatException);
      mode = 'missing';
      await expectLater(
        bridge.preparePlaybackFile(3),
        throwsA(isA<MissingPluginException>()),
      );
      expect(await root.list().toList(), isEmpty);
    });
    test('原生删除声称成功但文件仍在时必须拒绝确认', () async {
      const bridge = MethodChannelSquareVideoBridge();
      final file = await bridge.preparePlaybackFile(3);
      mode = 'delete_without_effect';
      await expectLater(bridge.deletePlaybackFile(file), throwsStateError);
      expect(await file.exists(), isTrue);
      mode = '';
      await bridge.deletePlaybackFile(file);
    });
  });

  group('SquareMediaPolicy', () {
    test('三个会员档位使用唯一确定的图片与视频规则', () {
      expect(SquareMediaPolicy.localImageBytes, 4 * 1024 * 1024);
      expect(SquareMediaPolicy.playbackBytes, 3 * 1024 * 1024 * 1024);
      expect(
        (
          SquareMediaPolicy.forPlan(_plan('freedom')).imageDimension,
          SquareMediaPolicy.forPlan(_plan('freedom')).imageQuality,
          SquareMediaPolicy.forPlan(_plan('freedom')).imageBytes,
          SquareMediaPolicy.forPlan(_plan('freedom')).videoHeight,
          SquareMediaPolicy.forPlan(_plan('freedom')).videoTotalBitrate,
          SquareMediaPolicy.forPlan(_plan('freedom')).videoMaxSeconds,
          SquareMediaPolicy.forPlan(_plan('freedom')).videoMaxBytes,
        ),
        (1280, 65, 400 * 1024, 480, 450000, 180, 12 * 1024 * 1024),
      );
      expect(
        (
          SquareMediaPolicy.forPlan(_plan('democracy')).imageDimension,
          SquareMediaPolicy.forPlan(_plan('democracy')).imageQuality,
          SquareMediaPolicy.forPlan(_plan('democracy')).imageBytes,
          SquareMediaPolicy.forPlan(_plan('democracy')).videoHeight,
          SquareMediaPolicy.forPlan(_plan('democracy')).videoTotalBitrate,
          SquareMediaPolicy.forPlan(_plan('democracy')).videoMaxSeconds,
          SquareMediaPolicy.forPlan(_plan('democracy')).videoMaxBytes,
        ),
        (1600, 72, 800 * 1024, 720, 800000, 1800, 200 * 1024 * 1024),
      );
      expect(
        (
          SquareMediaPolicy.forPlan(_plan('spark')).imageDimension,
          SquareMediaPolicy.forPlan(_plan('spark')).imageQuality,
          SquareMediaPolicy.forPlan(_plan('spark')).imageBytes,
          SquareMediaPolicy.forPlan(_plan('spark')).videoHeight,
          SquareMediaPolicy.forPlan(_plan('spark')).videoTotalBitrate,
          SquareMediaPolicy.forPlan(_plan('spark')).videoMaxSeconds,
          SquareMediaPolicy.forPlan(_plan('spark')).videoMaxBytes,
        ),
        (1920, 78, 1200 * 1024, 1080, 1200000, 10800, 1800 * 1024 * 1024),
      );
      expect(
        SquareMediaPolicy.forPlan(_plan('freedom')).thumbnailDimension,
        360,
      );
      expect(
        SquareMediaPolicy.forPlan(_plan('freedom')).coverBytes,
        120 * 1024,
      );
      expect(
        () => SquareMediaPolicy.forPlan(_plan('unknown')),
        throwsFormatException,
      );
    });
  });

  test('同档位编码参数只消费响应，缺失或坏规格不按名称补值', () {
    final rows = [
      for (final level in const ['freedom', 'democracy', 'spark'])
        membergatePlanFixture(level),
    ];
    (rows.first['limits'] as Map)['image_quality'] = 61;
    (rows.first['limits'] as Map)['video_total_bitrate'] = 400000;
    final plan = SquareApiClient.decodeMembershipPlans(rows).first;
    expect(SquareMediaPolicy.forPlan(plan).imageQuality, 61);
    expect(SquareMediaPolicy.forPlan(plan).videoTotalBitrate, 400000);
    (rows.first['limits'] as Map).remove('audio_bitrate');
    expect(
      () => SquareApiClient.decodeMembershipPlans(rows),
      throwsA(isA<SquareApiException>()),
    );
  });

  group('SquareMediaProcessor', () {
    late Directory root;
    late Directory batchDirectory;
    late File sourceImage;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('square_media_test_');
      batchDirectory = Directory('${root.path}/batch');
      sourceImage = File('${root.path}/source.png');
      await sourceImage.writeAsBytes(
        img.encodePng(img.Image(width: 2000, height: 1000)),
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('图片按会员规则生成 WebP 主文件与缩略图元数据', () async {
      final calls = <({int width, int height, int quality})>[];
      final processor = SquareMediaProcessor(
        videoBridge: _FakeVideoBridge(),
        temporaryDirectoryFactory: () async => batchDirectory,
        imageCompressOperation:
            ({
              required inputPath,
              required outputPath,
              required width,
              required height,
              required quality,
            }) async {
              calls.add((width: width, height: height, quality: quality));
              final output = File(outputPath);
              await output.writeAsBytes(
                img.encodePng(img.Image(width: width, height: height)),
              );
              return XFile(output.path);
            },
      );

      final batch = await processor.process(
        membershipPlan: _plan('freedom'),
        mediaDrafts: [
          SquareLocalMediaDraft(
            mediaKind: SquareMediaKind.image,
            path: sourceImage.path,
            fileName: 'source.jpg',
            contentType: 'image/jpeg',
            byteSize: await sourceImage.length(),
          ),
        ],
      );

      expect(calls, [
        (width: 1280, height: 640, quality: 65),
        (width: 360, height: 180, quality: 65),
      ]);
      expect(batch.mediaDrafts.single.contentType, 'image/webp');
      expect(batch.mediaDrafts.single.fileName, 'source.webp');
      expect(batch.mediaDrafts.single.pixelWidth, 1280);
      expect(batch.mediaDrafts.single.pixelHeight, 640);
      expect(
        batch.derivatives.single.derivativeKind,
        SquareMediaDerivativeKind.thumbnail,
      );
      expect(await File(batch.derivatives.single.path).exists(), isTrue);

      await batch.deleteTemporaryFiles();
      expect(await batchDirectory.exists(), isFalse);
    });

    test('视频使用单份 HEVC 成品并把原生封面转成 WebP', () async {
      final bridge = _FakeVideoBridge();
      final processor = SquareMediaProcessor(
        videoBridge: bridge,
        temporaryDirectoryFactory: () async => batchDirectory,
        imageCompressOperation:
            ({
              required inputPath,
              required outputPath,
              required width,
              required height,
              required quality,
            }) async {
              final output = File(outputPath);
              await output.writeAsBytes(
                img.encodePng(img.Image(width: width, height: height)),
              );
              return XFile(output.path);
            },
      );
      final sourceVideo = File('${root.path}/source.mov')
        ..writeAsBytesSync([1]);

      final batch = await processor.process(
        membershipPlan: _plan('freedom'),
        mediaDrafts: [
          SquareLocalMediaDraft(
            mediaKind: SquareMediaKind.video,
            path: sourceVideo.path,
            fileName: 'source.mov',
            contentType: 'video/quicktime',
            byteSize: 1,
            videoSecs: 120,
          ),
        ],
      );

      expect(bridge.lastRequest?.policy.memberLevel, 'freedom');
      expect(
        bridge.lastRequest?.policy.videoMaxBytes,
        SquareMediaPolicy.forPlan(_plan('freedom')).videoMaxBytes,
      );
      expect(batch.mediaDrafts.single.contentType, 'video/mp4');
      expect(batch.mediaDrafts.single.fileName, 'source.mp4');
      expect(batch.mediaDrafts.single.byteSize, 4);
      expect(
        batch.derivatives.single.derivativeKind,
        SquareMediaDerivativeKind.cover,
      );
      expect(batch.derivatives.single.contentType, 'image/webp');
      expect(
        await File('${batchDirectory.path}/0_cover_source.png').exists(),
        isFalse,
      );
    });

    test('设备不支持硬件 HEVC 编码或解码时失败关闭并清理整个批次', () async {
      final sourceVideo = File('${root.path}/source.mov')
        ..writeAsBytesSync([1]);
      for (final bridge in [
        _FakeVideoBridge(canEncodeHevc: false),
        _FakeVideoBridge(canDecodeHevc: false),
      ]) {
        final processor = SquareMediaProcessor(
          videoBridge: bridge,
          temporaryDirectoryFactory: () async => batchDirectory,
        );
        await expectLater(
          processor.process(
            membershipPlan: _plan('freedom'),
            mediaDrafts: [
              SquareLocalMediaDraft(
                mediaKind: SquareMediaKind.video,
                path: sourceVideo.path,
                fileName: 'source.mov',
                contentType: 'video/quicktime',
                byteSize: 1,
                videoSecs: 30,
              ),
            ],
          ),
          throwsFormatException,
        );
        expect(await batchDirectory.exists(), isFalse);
      }
    });
  });
}

final class _FakeVideoBridge implements SquareVideoBridge {
  _FakeVideoBridge({this.canEncodeHevc = true, this.canDecodeHevc = true});

  final bool canEncodeHevc;
  final bool canDecodeHevc;
  SquareVideoTranscodeRequest? lastRequest;

  @override
  Future<SquareVideoCapability> capabilities() async => SquareVideoCapability(
    canEncodeHevc: canEncodeHevc,
    canDecodeHevc: canDecodeHevc,
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<SquareVideoTranscodeResult> transcode(
    SquareVideoTranscodeRequest request,
  ) async {
    lastRequest = request;
    await File(request.outputPath).writeAsBytes([1, 2, 3, 4]);
    final cover = img.encodePng(img.Image(width: 1280, height: 720));
    await File(request.coverPath).writeAsBytes(cover);
    return SquareVideoTranscodeResult(
      videoSecs: 120,
      pixelWidth: 854,
      pixelHeight: 480,
      videoFrameRate: 30,
      videoAverageBitrate: request.policy.videoTotalBitrate - 20000,
      videoPeakBitrate: request.policy.videoPeakBitrate - 50000,
      byteSize: 4,
      coverByteSize: cover.length,
      videoCodec: 'hevc',
      sampleEntry: 'hvc1',
      fastStart: true,
      isSdr: true,
    );
  }
}

// 当前服务端合同夹具；压缩处理不按档位补入任何参数。
SquareMembershipPlan _plan(String level) {
  final plans = membergatePlansFixture();
  if (level != 'unknown') {
    return plans.firstWhere((p) => p.memberLevel == level);
  }
  final p = plans.first;
  return SquareMembershipPlan(
    memberLevel: level,
    displayName: p.displayName,
    fileLimit: p.fileLimit,
    chat: p.chat,
    document: p.document,
    video: p.video,
    article: p.article,
    usage: p.usage,
    imageBytes: p.imageBytes,
    imageDimension: p.imageDimension,
    media: p.media,
    resources: p.resources,
    dailyLimits: p.dailyLimits,
  );
}
