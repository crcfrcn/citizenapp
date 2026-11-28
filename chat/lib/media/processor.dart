// 统一聊天媒体MIME推断、探测及压缩。

import 'dart:io';
import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:chat/media/picker.dart';
import 'package:chat/models.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path_provider/path_provider.dart';

// 探测文件大小并将图片压缩到当前允许上限。

/// 取文件字节大小(默认走 File.length,可注入测试)。
typedef FileSizeReader = Future<int> Function(String path);

/// 把图片压到目标上限内,返回压缩后文件路径;无法压缩返回 null(默认走
/// flutter_image_compress,可注入测试)。
typedef ImageCompressStep = Future<String?> Function(String path, int limit);

typedef AttachmentLimitResolver = int Function(ChatMessageKind kind);

/// 媒体大小门控(采集侧,门①的上游)。
///
/// 定稿策略：图片仅超过App附件上限才压缩；正常图原样直通，超限只压一次，
/// 压后仍超则拒。视频/文件**不转码**，超限直接拒。全程按文件大小(stat)判定，
/// 不把文件整体解码进内存。
class MediaCompressor {
  MediaCompressor({
    required AttachmentLimitResolver limitForKind,
    FileSizeReader? sizeOf,
    ImageCompressStep? compressImage,
  }) : _limitForKind = limitForKind,
       _sizeOf = sizeOf ?? _defaultSizeOf,
       _compressImage = compressImage ?? _defaultCompressImage;

  final AttachmentLimitResolver _limitForKind;
  final FileSizeReader _sizeOf;
  final ImageCompressStep _compressImage;

  /// 返回最终待发送文件路径(可能是压缩后的临时文件)。超限且无法压到限内时抛
  /// [ChatMediaTooLargeException]。上限由 [kind] 决定。
  Future<String> ensureWithinLimit({
    required String path,
    required ChatMessageKind kind,
  }) async {
    final limit = _limitForKind(kind);
    final size = await _sizeOf(path);
    if (size <= limit) {
      return path; // 正常直通,不改动源文件
    }
    if (kind != ChatMessageKind.image) {
      // 视频/文件不转码,超限直接拒。
      throw ChatMediaTooLargeException(
        byteSize: size,
        limitBytes: limit,
        kind: kind,
      );
    }
    // 图片超限:压一次。
    final compressed = await _compressImage(path, limit);
    if (compressed == null) {
      throw ChatMediaTooLargeException(
        byteSize: size,
        limitBytes: limit,
        kind: kind,
      );
    }
    final newSize = await _sizeOf(compressed);
    if (newSize > limit) {
      throw ChatMediaTooLargeException(
        byteSize: newSize,
        limitBytes: limit,
        kind: kind,
      );
    }
    return compressed;
  }
}

Future<int> _defaultSizeOf(String path) => File(path).length();

Future<String?> _defaultCompressImage(String path, int limit) async {
  // 原生降质压缩(不在 Dart 侧整解码);目标限内即可,尽量保尺寸。
  final dir = await getTemporaryDirectory();
  final target =
      '${dir.path}/chat_compress_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final result = await FlutterImageCompress.compressAndGetFile(
    path,
    target,
    quality: 85,
  );
  return result?.path;
}

// 统一根据文件名推断聊天媒体MIME类型。

/// 由文件名推断 MIME 类型。聊天媒体的 MIME 单源,发送端与采集端共用。
String mimeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  // 图片
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  // 视频
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.3gp')) return 'video/3gpp';
  if (lower.endsWith('.avi')) return 'video/x-msvideo';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.webm')) return 'video/webm';
  // 音频
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  // 文件
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

/// 由外部文件 MIME 判定聊天消息类型:image / video / 其余为 file。
/// `audio` 只允许由按住说话录音入口显式创建，设备音频文件仍作为通用文件发送。
ChatMessageKind mediaKindFromMime(String mime) {
  if (mime.startsWith('image/')) return ChatMessageKind.image;
  if (mime.startsWith('video/')) return ChatMessageKind.video;
  return ChatMessageKind.file;
}

// 有界探测媒体宽高、时长及缩略图blurhash。

/// 媒体探测结果:宽高、时长、blurhash 占位。任一探测失败对应字段留空,不阻断发送。
class MediaProbeResult {
  const MediaProbeResult({
    this.width,
    this.height,
    this.durationMs,
    this.blurhash,
  });

  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurhash;
}

typedef ImageSizeReader = ({int width, int height})? Function(String path);
typedef MediaBytesReader = Future<List<int>?> Function(String path);
typedef VideoProbeReader =
    Future<
      ({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})
    >
    Function(String path);
typedef BlurhashEncoder = String? Function(List<int> smallImageBytes);

/// 采集媒体的宽高 / 时长 / blurhash 探测。
///
/// **内存安全**:blurhash 一律由**原生降采样出的小缩略图**(图走
/// flutter_image_compress、视频走 公民聊天 平台通道抽帧)编码,绝不在 Dart 侧整解码
/// 100MB 原图;图片宽高走 image_size_getter 读文件头,不解码。native 读取全部经
/// 可注入的 seam,编排与 blurhash 编码为纯 Dart,可单测。
class MediaProbe {
  MediaProbe({
    ImageSizeReader? imageSize,
    MediaBytesReader? imageThumbBytes,
    VideoProbeReader? videoProbe,
    BlurhashEncoder? blurhashOf,
  }) : _imageSize = imageSize ?? _defaultImageSize,
       _imageThumbBytes = imageThumbBytes ?? _defaultImageThumbBytes,
       _videoProbe = videoProbe ?? _defaultVideoProbe,
       _blurhashOf = blurhashOf ?? encodeBlurhash;

  final ImageSizeReader _imageSize;
  final MediaBytesReader _imageThumbBytes;
  final VideoProbeReader _videoProbe;
  final BlurhashEncoder _blurhashOf;

  Future<MediaProbeResult> probe({
    required String path,
    required ChatMessageKind kind,
  }) async {
    try {
      switch (kind) {
        case ChatMessageKind.image:
          final size = _imageSize(path);
          final thumb = await _imageThumbBytes(path);
          return MediaProbeResult(
            width: size?.width,
            height: size?.height,
            blurhash: thumb == null ? null : _blurhashOf(thumb),
          );
        case ChatMessageKind.video:
          final video = await _videoProbe(path);
          return MediaProbeResult(
            width: video.width,
            height: video.height,
            durationMs: video.durationMs,
            blurhash: video.thumbnailBytes == null
                ? null
                : _blurhashOf(video.thumbnailBytes!),
          );
        case ChatMessageKind.text ||
            ChatMessageKind.file ||
            ChatMessageKind.audio ||
            ChatMessageKind.sticker:
          return const MediaProbeResult();
      }
    } catch (_) {
      // 探测失败(文件损坏/native 异常)不阻断发送,占位退化为灰底。
      return const MediaProbeResult();
    }
  }

  /// 由**小缩略图字节**编码 blurhash(纯 Dart,可直接单测)。输入应已是缩略图;
  /// 保险起见**仅缩小**(不放大)到较大边 ≤64px 后编码——把主导的那一边降到 64,
  /// 另一边按比例随之 ≤64。
  static String? encodeBlurhash(List<int> smallImageBytes) {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(smallImageBytes));
      if (decoded == null) return null;
      final img.Image tiny;
      if (decoded.width <= 64 && decoded.height <= 64) {
        tiny = decoded; // 已足够小,不放大
      } else if (decoded.width >= decoded.height) {
        tiny = img.copyResize(decoded, width: 64); // 宽为主导 → 高按比例 ≤64
      } else {
        tiny = img.copyResize(decoded, height: 64); // 高为主导 → 宽按比例 ≤64
      }
      return BlurHash.encode(tiny, numCompX: 4, numCompY: 3).hash;
    } catch (_) {
      return null;
    }
  }
}

({int width, int height})? _defaultImageSize(String path) {
  try {
    final result = ImageSizeGetter.getSizeResult(FileInput(File(path)));
    final size = result.size;
    // needRotate=true 时宽高需互换。
    return size.needRotate
        ? (width: size.height, height: size.width)
        : (width: size.width, height: size.height);
  } catch (_) {
    return null;
  }
}

Future<List<int>?> _defaultImageThumbBytes(String path) async {
  // 原生降采样出小缩略图,不在 Dart 侧整解码。
  final bytes = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: 64,
    minHeight: 64,
    quality: 60,
  );
  return bytes;
}

Future<({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})>
_defaultVideoProbe(String path) =>
    const ChatAttachmentPlatform().probeVideo(path);
