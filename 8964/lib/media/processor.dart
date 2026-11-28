// 消费原媒体规格，构造草稿并处理图片及视频衍生物。

import 'dart:async';
import 'dart:io';

import 'package:citizen_square/post/models.dart';
import 'package:citizen_user/api.dart' show SquareMembershipPlan;
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// 按授权规格生成图片和视频衍生物，管理原生文件保护及临时清理。

enum SquareMediaDerivativeKind { thumbnail, cover }

final class SquareMediaDerivative {
  const SquareMediaDerivative({
    required this.mediaIndex,
    required this.derivativeKind,
    required this.path,
    required this.contentType,
    required this.byteSize,
  });

  final int mediaIndex;
  final SquareMediaDerivativeKind derivativeKind;
  final String path;
  final String contentType;
  final int byteSize;
}

/// 一次发布所生成的全部临时媒体；主文件和衍生图必须同生共灭。
final class SquareProcessedMediaBatch {
  SquareProcessedMediaBatch({
    required List<SquareLocalMediaDraft> mediaDrafts,
    required List<SquareMediaDerivative> derivatives,
    required this.temporaryDirectory,
  }) : mediaDrafts = List.unmodifiable(mediaDrafts),
       derivatives = List.unmodifiable(derivatives);

  final List<SquareLocalMediaDraft> mediaDrafts;
  final List<SquareMediaDerivative> derivatives;
  final Directory temporaryDirectory;

  Future<void> deleteTemporaryFiles() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

final class SquareVideoCapability {
  const SquareVideoCapability({
    required this.canEncodeHevc,
    required this.canDecodeHevc,
  });

  final bool canEncodeHevc;
  final bool canDecodeHevc;
}

final class SquareVideoTranscodeRequest {
  const SquareVideoTranscodeRequest({
    required this.inputPath,
    required this.outputPath,
    required this.coverPath,
    required this.policy,
  });

  final String inputPath;
  final String outputPath;
  final String coverPath;
  final SquareMediaPolicy policy;

  Map<String, Object?> toChannelArguments() => <String, Object?>{
    'input_path': inputPath,
    'output_path': outputPath,
    'cover_path': coverPath,
    'video_width': policy.videoWidth,
    'video_height': policy.videoHeight,
    'video_bitrate': policy.videoBitrate,
    'video_peak_bitrate': policy.videoPeakBitrate,
    'audio_bitrate': policy.audioBitrate,
    'audio_sample_rate': policy.audioSampleRate,
    'video_frame_rate': policy.videoFrameRate,
    'keyframe_secs': policy.keyframeSecs,
    'video_max_seconds': policy.videoMaxSeconds,
    'video_max_bytes': policy.videoMaxBytes,
    'cover_dimension': policy.coverDimension,
    'cover_quality': policy.coverQuality,
    'cover_bytes': policy.coverBytes,
  };
}

final class SquareVideoTranscodeResult {
  const SquareVideoTranscodeResult({
    required this.videoSecs,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.videoFrameRate,
    required this.videoAverageBitrate,
    required this.videoPeakBitrate,
    required this.byteSize,
    required this.coverByteSize,
    required this.videoCodec,
    required this.sampleEntry,
    required this.fastStart,
    required this.isSdr,
  });

  final int videoSecs;
  final int pixelWidth;
  final int pixelHeight;
  final double videoFrameRate;
  final int videoAverageBitrate;
  final int videoPeakBitrate;
  final int byteSize;
  final int coverByteSize;
  final String videoCodec;
  final String sampleEntry;
  final bool fastStart;
  final bool isSdr;

  factory SquareVideoTranscodeResult.fromChannel(Object? value) {
    if (value is! Map) throw const FormatException('视频转码响应不合法');
    int intValue(String key) {
      final raw = value[key];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? -1;
    }

    double doubleValue(String key) {
      final raw = value[key];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? -1;
    }

    return SquareVideoTranscodeResult(
      videoSecs: intValue('video_secs'),
      pixelWidth: intValue('pixel_width'),
      pixelHeight: intValue('pixel_height'),
      videoFrameRate: doubleValue('video_frame_rate'),
      videoAverageBitrate: intValue('video_average_bitrate'),
      videoPeakBitrate: intValue('video_peak_bitrate'),
      byteSize: intValue('byte_size'),
      coverByteSize: intValue('cover_byte_size'),
      videoCodec: value['video_codec']?.toString() ?? '',
      sampleEntry: value['sample_entry']?.toString() ?? '',
      fastStart: value['fast_start'] == true,
      isSdr: value['is_sdr'] == true,
    );
  }
}

abstract interface class SquareVideoBridge {
  Future<SquareVideoCapability> capabilities();
  Future<SquareVideoTranscodeResult> transcode(
    SquareVideoTranscodeRequest request,
  );
  Future<void> cancel();
}

final class MethodChannelSquareVideoBridge implements SquareVideoBridge {
  const MethodChannelSquareVideoBridge();

  static const _channel = MethodChannel('citizenapp/square_media');

  /// 原生先建立文件保护，再允许写入媒体；没有平台实现时直接失败。
  Future<File> preparePlaybackFile(int byteSize) async {
    if (byteSize <= 0 || byteSize > SquareMediaPolicy.playbackBytes) {
      throw const FormatException('本地视频大小无效');
    }
    final path = await _channel.invokeMethod<String>('prepare_playback_file', {
      'byte_size': byteSize,
    });
    if (path == null || !path.startsWith('/')) {
      throw const FormatException('本地播放文件响应无效');
    }
    final file = File(path);
    try {
      if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.resolveSymbolicLinks() != path) {
        throw const FormatException('本地播放文件响应无效');
      }
      return file;
    } on Object {
      await deletePlaybackFile(file);
      rethrow;
    }
  }

  Future<void> verifyPlaybackFile(File file, int byteSize) =>
      _channel.invokeMethod<void>('verify_playback_file', {
        'output_path': file.path,
        'byte_size': byteSize,
      });

  /// 删除只由原生校验归属后执行，Dart再次回读，失败不得伪装成功。
  Future<void> deletePlaybackFile(File file) async {
    await _channel.invokeMethod<void>('delete_playback_file', {
      'output_path': file.path,
    });
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('本地播放文件清理失败');
    }
  }

  @override
  Future<SquareVideoCapability> capabilities() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('capabilities');
    if (raw == null) throw const FormatException('设备媒体能力响应为空');
    return SquareVideoCapability(
      canEncodeHevc: raw['can_encode_hevc'] == true,
      canDecodeHevc: raw['can_decode_hevc'] == true,
    );
  }

  @override
  Future<SquareVideoTranscodeResult> transcode(
    SquareVideoTranscodeRequest request,
  ) async {
    final raw = await _channel.invokeMethod<Object?>(
      'transcode_video',
      request.toChannelArguments(),
    );
    return SquareVideoTranscodeResult.fromChannel(raw);
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel_video');
}

typedef SquareTemporaryDirectoryFactory = Future<Directory> Function();
typedef SquareImageCompressOperation = Future<XFile?> Function({
  required String inputPath,
  required String outputPath,
  required int width,
  required int height,
  required int quality,
});

/// 广场唯一手机端媒体处理入口；原始草稿永不原地覆盖。
final class SquareMediaProcessor {
  SquareMediaProcessor({
    SquareVideoBridge? videoBridge,
    SquareTemporaryDirectoryFactory? temporaryDirectoryFactory,
    SquareImageCompressOperation? imageCompressOperation,
  }) : _videoBridge = videoBridge ?? const MethodChannelSquareVideoBridge(),
       _temporaryDirectoryFactory =
           temporaryDirectoryFactory ?? _defaultTemporaryDirectory,
       _imageCompressOperation =
           imageCompressOperation ?? _defaultImageCompress;

  final SquareVideoBridge _videoBridge;
  final SquareTemporaryDirectoryFactory _temporaryDirectoryFactory;
  final SquareImageCompressOperation _imageCompressOperation;

  Future<SquareProcessedMediaBatch> process({
    required List<SquareLocalMediaDraft> mediaDrafts,
    required SquareMembershipPlan membershipPlan,
  }) async {
    final policy = SquareMediaPolicy.forPlan(membershipPlan);
    final temporaryDirectory = await _temporaryDirectoryFactory();
    await temporaryDirectory.create(recursive: true);
    final processed = <SquareLocalMediaDraft>[];
    final derivatives = <SquareMediaDerivative>[];
    try {
      for (var index = 0; index < mediaDrafts.length; index++) {
        final draft = mediaDrafts[index];
        if (draft.mediaKind == SquareMediaKind.image) {
          final item = await _processImage(
            draft: draft,
            mediaIndex: index,
            policy: policy,
            temporaryDirectory: temporaryDirectory,
          );
          processed.add(item.$1);
          derivatives.add(item.$2);
        } else {
          final item = await _processVideo(
            draft: draft,
            mediaIndex: index,
            policy: policy,
            temporaryDirectory: temporaryDirectory,
          );
          processed.add(item.$1);
          derivatives.add(item.$2);
        }
      }
      return SquareProcessedMediaBatch(
        mediaDrafts: processed,
        derivatives: derivatives,
        temporaryDirectory: temporaryDirectory,
      );
    } catch (_) {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> cancel() => _videoBridge.cancel();

  Future<(SquareLocalMediaDraft, SquareMediaDerivative)> _processImage({
    required SquareLocalMediaDraft draft,
    required int mediaIndex,
    required SquareMediaPolicy policy,
    required Directory temporaryDirectory,
  }) async {
    final sourceSize = _readImageSize(draft.path);
    final primarySize = _fitLongestEdge(
      sourceSize.width,
      sourceSize.height,
      policy.imageDimension,
    );
    final primaryPath = path.join(temporaryDirectory.path, '$mediaIndex.webp');
    final primary = await _compressImageWithinLimit(
      inputPath: draft.path,
      outputPath: primaryPath,
      width: primarySize.width,
      height: primarySize.height,
      quality: policy.imageQuality,
      maxBytes: policy.imageBytes,
    );
    final primaryOutputSize = _readImageSize(primary.path);

    final thumbnailSize = _fitLongestEdge(
      primaryOutputSize.width,
      primaryOutputSize.height,
      policy.thumbnailDimension,
    );
    final thumbnailPath = path.join(
      temporaryDirectory.path,
      '${mediaIndex}_thumbnail.webp',
    );
    final thumbnail = await _compressImageWithinLimit(
      inputPath: primary.path,
      outputPath: thumbnailPath,
      width: thumbnailSize.width,
      height: thumbnailSize.height,
      quality: policy.thumbnailQuality,
      maxBytes: policy.thumbnailBytes,
    );
    return (
      SquareLocalMediaDraft(
        mediaKind: SquareMediaKind.image,
        path: primary.path,
        fileName: '${path.basenameWithoutExtension(draft.fileName)}.webp',
        contentType: 'image/webp',
        byteSize: primary.byteSize,
        pixelWidth: primaryOutputSize.width,
        pixelHeight: primaryOutputSize.height,
        assetId: draft.assetId,
      ),
      SquareMediaDerivative(
        mediaIndex: mediaIndex,
        derivativeKind: SquareMediaDerivativeKind.thumbnail,
        path: thumbnail.path,
        contentType: 'image/webp',
        byteSize: thumbnail.byteSize,
      ),
    );
  }

  Future<(SquareLocalMediaDraft, SquareMediaDerivative)> _processVideo({
    required SquareLocalMediaDraft draft,
    required int mediaIndex,
    required SquareMediaPolicy policy,
    required Directory temporaryDirectory,
  }) async {
    final duration = draft.videoSecs ?? 0;
    if (duration <= 0 || duration > policy.videoMaxSeconds) {
      throw const FormatException('视频时长超出当前会员档位上限');
    }
    final capability = await _videoBridge.capabilities();
    if (!capability.canEncodeHevc) {
      throw const FormatException('当前设备没有可用的硬件 HEVC 编码器，不能发布视频');
    }
    if (!capability.canDecodeHevc) {
      throw const FormatException('当前设备不能可靠解码 HEVC，不能发布视频');
    }
    final outputPath = path.join(temporaryDirectory.path, '$mediaIndex.mp4');
    final coverSourcePath = path.join(
      temporaryDirectory.path,
      '${mediaIndex}_cover_source.png',
    );
    final result = await _videoBridge.transcode(
      SquareVideoTranscodeRequest(
        inputPath: draft.path,
        outputPath: outputPath,
        coverPath: coverSourcePath,
        policy: policy,
      ),
    );
    _validateVideoResult(result, policy);
    if (!await File(outputPath).exists() ||
        !await File(coverSourcePath).exists()) {
      throw const FormatException('视频转码没有生成完整成品');
    }
    final actualBytes = await File(outputPath).length();
    final actualCoverSourceBytes = await File(coverSourcePath).length();
    if (actualBytes != result.byteSize ||
        actualCoverSourceBytes != result.coverByteSize) {
      throw const FormatException('视频转码文件大小与原生校验结果不一致');
    }
    final coverSourceSize = _readImageSize(coverSourcePath);
    final coverSize = _fitLongestEdge(
      coverSourceSize.width,
      coverSourceSize.height,
      policy.coverDimension,
    );
    final coverPath = path.join(
      temporaryDirectory.path,
      '${mediaIndex}_cover.webp',
    );
    final cover = await _compressImageWithinLimit(
      inputPath: coverSourcePath,
      outputPath: coverPath,
      width: coverSize.width,
      height: coverSize.height,
      quality: policy.coverQuality,
      maxBytes: policy.coverBytes,
    );
    await File(coverSourcePath).delete();
    return (
      SquareLocalMediaDraft(
        mediaKind: SquareMediaKind.video,
        path: outputPath,
        fileName: '${path.basenameWithoutExtension(draft.fileName)}.mp4',
        contentType: 'video/mp4',
        byteSize: actualBytes,
        videoSecs: result.videoSecs,
        pixelWidth: result.pixelWidth,
        pixelHeight: result.pixelHeight,
        assetId: draft.assetId,
      ),
      SquareMediaDerivative(
        mediaIndex: mediaIndex,
        derivativeKind: SquareMediaDerivativeKind.cover,
        path: cover.path,
        contentType: 'image/webp',
        byteSize: cover.byteSize,
      ),
    );
  }

  void _validateVideoResult(
    SquareVideoTranscodeResult result,
    SquareMediaPolicy policy,
  ) {
    if (result.videoCodec != 'hevc' || result.sampleEntry != 'hvc1') {
      throw const FormatException('视频成品不是唯一允许的 HEVC/hvc1');
    }
    if (!result.fastStart || !result.isSdr) {
      throw const FormatException('视频成品不满足 SDR 或快速起播要求');
    }
    if (result.videoSecs <= 0 ||
        result.videoSecs > policy.videoMaxSeconds ||
        result.pixelWidth <= 0 ||
        result.pixelHeight <= 0 ||
        result.pixelWidth > policy.videoWidth ||
        result.pixelHeight > policy.videoWidth ||
        result.pixelWidth > policy.videoHeight &&
            result.pixelHeight > policy.videoHeight ||
        result.videoFrameRate <= 0 ||
        result.videoFrameRate > policy.videoFrameRate + 0.01 ||
        result.videoAverageBitrate > policy.videoTotalBitrate * 1.08 ||
        result.videoPeakBitrate > policy.videoPeakBitrate ||
        result.byteSize <= 0 ||
        result.byteSize > policy.videoMaxBytes ||
        result.coverByteSize <= 0) {
      throw const FormatException('视频成品参数超出当前会员档位');
    }
  }

  Future<({String path, int byteSize})> _compressImageWithinLimit({
    required String inputPath,
    required String outputPath,
    required int width,
    required int height,
    required int quality,
    required int maxBytes,
  }) async {
    var attemptWidth = width;
    var attemptHeight = height;
    var attemptQuality = quality;
    for (var attempt = 0; attempt < 12; attempt++) {
      final attemptPath = '${path.withoutExtension(outputPath)}_$attempt.webp';
      final result = await _imageCompressOperation(
        inputPath: inputPath,
        outputPath: attemptPath,
        width: attemptWidth,
        height: attemptHeight,
        quality: attemptQuality,
      );
      if (result == null) throw const FormatException('图片压缩失败');
      final byteSize = await result.length();
      if (byteSize > 0 && byteSize <= maxBytes) {
        final finalFile = await File(result.path).rename(outputPath);
        return (path: finalFile.path, byteSize: byteSize);
      }
      try {
        await File(result.path).delete();
      } on FileSystemException {
        // 失败尝试仍位于本批次临时目录，批次结束时递归清理。
      }
      if (attemptQuality > 45) {
        attemptQuality -= 5;
      } else {
        attemptWidth = (attemptWidth * 0.85).round().clamp(2, width);
        attemptHeight = (attemptHeight * 0.85).round().clamp(2, height);
      }
    }
    throw const FormatException('图片无法压缩到当前会员档位上限');
  }

  ({int width, int height}) _readImageSize(String filePath) {
    final result = ImageSizeGetter.getSizeResult(FileInput(File(filePath)));
    final size = result.size;
    final width = size.needRotate ? size.height : size.width;
    final height = size.needRotate ? size.width : size.height;
    if (width <= 0 || height <= 0) throw const FormatException('图片尺寸不合法');
    return (width: width, height: height);
  }

  ({int width, int height}) _fitLongestEdge(
    int width,
    int height,
    int maxEdge,
  ) {
    final longest = width > height ? width : height;
    if (longest <= maxEdge) return (width: width, height: height);
    final scale = maxEdge / longest;
    return (
      width: _even((width * scale).round()),
      height: _even((height * scale).round()),
    );
  }

  int _even(int value) {
    final bounded = value < 2 ? 2 : value;
    return bounded.isEven ? bounded : bounded - 1;
  }

  static Future<Directory> _defaultTemporaryDirectory() async {
    final root = await getTemporaryDirectory();
    return Directory(
      path.join(
        root.path,
        'square_media',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
  }

  static Future<XFile?> _defaultImageCompress({
    required String inputPath,
    required String outputPath,
    required int width,
    required int height,
    required int quality,
  }) {
    return FlutterImageCompress.compressAndGetFile(
      inputPath,
      outputPath,
      minWidth: width,
      minHeight: height,
      quality: quality,
      format: CompressFormat.webp,
      autoCorrectionAngle: true,
      keepExif: false,
    );
  }
}

// 校验并消费服务端下发媒体规格，提供历史媒体安全读取上限。

/// 手机只执行服务端下发的成品规格；本文件不定义三档额度或编码参数副本。
final class SquareMediaPolicy {
  const SquareMediaPolicy._(this._plan);
  final SquareMembershipPlan _plan;

  // 历史已保存媒体的1024进制安全读取顶，与新上传额度无关，降档或调小上传规格不损坏旧内容。
  static const int localImageBytes = 4 * 1024 * 1024;
  static const int playbackBytes = 3 * 1024 * 1024 * 1024;

  String get memberLevel => _plan.memberLevel;
  int get imageDimension => _plan.imageDimension;
  int get imageBytes => _plan.imageBytes;
  int get imageQuality => _value('image_quality');
  int get thumbnailDimension => _value('thumbnail_dimension');
  int get thumbnailQuality => _value('thumbnail_quality');
  int get thumbnailBytes => _value('thumbnail_bytes');
  int get coverDimension => _value('cover_dimension');
  int get coverQuality => _value('cover_quality');
  int get coverBytes => _value('cover_bytes');
  int get videoFrameRate => _value('video_frame_rate');
  int get keyframeSecs => _value('keyframe_secs');
  int get audioSampleRate => _value('audio_sample_rate');
  int get videoHeight => _value('video_height');
  int get videoWidth => _value('video_width');
  int get videoTotalBitrate => _value('video_total_bitrate');
  int get videoPeakBitrate => _value('video_peak_bitrate');
  int get audioBitrate => _value('audio_bitrate');
  int get videoBitrate => videoTotalBitrate - audioBitrate;
  int get videoMaxSeconds => _plan.video.videoMaxSeconds;
  int get videoMaxBytes => _plan.video.videoMaxBytes;

  int _value(String key) {
    final value = _plan.media[key];
    if (value == null || value <= 0) throw FormatException('媒体成品参数缺失：$key');
    return value;
  }

  static SquareMediaPolicy forPlan(SquareMembershipPlan plan) {
    if (!const ['freedom', 'democracy', 'spark'].contains(plan.memberLevel) ||
        plan.imageBytes <= 0 ||
        plan.imageDimension <= 0 ||
        plan.video.videoMaxBytes <= 0 ||
        plan.video.videoMaxSeconds <= 0) {
      throw const FormatException('会员媒体参数缺失');
    }
    final policy = SquareMediaPolicy._(plan);
    for (final key in const [
      'image_quality',
      'thumbnail_dimension',
      'thumbnail_quality',
      'thumbnail_bytes',
      'cover_dimension',
      'cover_quality',
      'cover_bytes',
      'video_frame_rate',
      'keyframe_secs',
      'audio_sample_rate',
      'video_height',
      'video_width',
      'video_total_bitrate',
      'video_peak_bitrate',
      'audio_bitrate',
    ]) {
      policy._value(key);
    }
    if (policy.imageQuality > 100 ||
        policy.thumbnailQuality > 100 ||
        policy.coverQuality > 100 ||
        policy.audioBitrate >= policy.videoTotalBitrate ||
        policy.videoPeakBitrate < policy.videoTotalBitrate) {
      throw const FormatException('媒体成品规格无效');
    }
    return policy;
  }
}

// 从相册文件构造公文、文章或视频使用的媒体草稿。

/// 媒体草稿构造器类型；发布编辑器可在测试中注入稳定实现，生产环境统一使用下方实现。
typedef SquareMediaDraftBuilder = Future<SquareLocalMediaDraft> Function(
  XFile file,
  SquareMediaKind mediaKind,
);

/// 从相册 [XFile] 构造公文、文章或视频发布共用的本地媒体草稿。
Future<SquareLocalMediaDraft> buildSquareMediaDraft(
  XFile file,
  SquareMediaKind mediaKind,
) async {
  final name = file.name.isNotEmpty ? file.name : path.basename(file.path);
  final contentType = file.mimeType ?? _inferContentType(name, mediaKind);
  int? durationSeconds;
  if (mediaKind == SquareMediaKind.video) {
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      durationSeconds = controller.value.duration.inMilliseconds <= 0
          ? null
          : (controller.value.duration.inMilliseconds / 1000).ceil();
    } finally {
      await controller.dispose();
    }
    if (durationSeconds == null) {
      throw const FormatException('无法读取视频时长');
    }
  }
  return SquareLocalMediaDraft(
    mediaKind: mediaKind,
    path: file.path,
    fileName: name,
    contentType: contentType,
    byteSize: await file.length(),
    videoSecs: durationSeconds,
  );
}

String _inferContentType(String fileName, SquareMediaKind mediaKind) {
  final ext = path.extension(fileName).toLowerCase();
  if (mediaKind == SquareMediaKind.video) {
    return ext == '.webm' ? 'video/webm' : 'video/mp4';
  }
  return switch (ext) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
