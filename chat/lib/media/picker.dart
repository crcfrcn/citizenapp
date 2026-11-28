// 统一聊天文件与相册选择的原平台端口。

import 'dart:convert';

import 'package:chat/media/processor.dart';
import 'package:chat/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

// 通过统一原生通道选择单文件和探测视频缩略图，消费当前业务上限。

/// 系统文件选择返回的公民聊天临时普通文件；App业务仍在Dart层决定最终额度。
final class ChatPickedFile {
  const ChatPickedFile({
    required this.path,
    required this.fileName,
    required this.mime,
  });

  final String path;
  final String fileName;
  final String mime;
}

/// 公民聊天附件相关的唯一平台边界：单文件选择与视频小图探测共用同一通道。
final class ChatAttachmentPlatform {
  const ChatAttachmentPlatform();

  static const MethodChannel _channel = MethodChannel('citizenapp/chat/media');

  Future<ChatPickedFile?> pickFile({required int maxBytes}) async {
    if (maxBytes <= 0 || maxBytes > 0x7fffffffffffffff) {
      throw const FormatException('文件选择上限无效');
    }
    // 原生流式复制消费App当前上限，不另设SDK会员大小限制。
    final result = await _channel.invokeMapMethod<String, Object?>('pickFile', {
      'max_bytes': maxBytes,
    });
    if (result == null) return null;
    final path = result['path'];
    final fileName = result['file_name'];
    final mime = result['mime'];
    if (path is! String ||
        !p.isAbsolute(path) ||
        path.contains('\u0000') ||
        fileName is! String ||
        !_validFileName(fileName) ||
        mime is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$')
            .hasMatch(mime)) {
      throw const FormatException('系统文件选择结果无效');
    }
    return ChatPickedFile(path: path, fileName: fileName, mime: mime);
  }

  Future<
    ({int? width, int? height, int? durationMs, List<int>? thumbnailBytes})
  >
  probeVideo(String path) async {
    if (!p.isAbsolute(path) || path.contains('\u0000')) {
      throw const FormatException('视频路径必须是有效绝对路径');
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'probeVideo',
      <String, Object?>{'path': path},
    );
    if (result == null) throw const FormatException('视频探测结果缺失');

    int? positiveInt(String field) {
      final value = result[field];
      if (value == null) return null;
      if (value is! int || value <= 0 || value > 0xffffffff) {
        throw FormatException('视频探测字段无效：$field');
      }
      return value;
    }

    final rawThumbnail = result['thumbnail_bytes'];
    if (rawThumbnail != null && rawThumbnail is! Uint8List) {
      throw const FormatException('视频封面字节类型无效');
    }
    final thumbnail = rawThumbnail as Uint8List?;
    if (thumbnail != null && (thumbnail.isEmpty || thumbnail.length > 262144)) {
      throw const FormatException('视频封面字节超出限制');
    }
    return (
      width: positiveInt('width'),
      height: positiveInt('height'),
      durationMs: positiveInt('duration_ms'),
      thumbnailBytes: thumbnail,
    );
  }

  static bool _validFileName(String value) {
    if (value.isEmpty || utf8.encode(value).length > 255) return false;
    return !value.contains('/') &&
        !value.contains('\\') &&
        !value.runes.any((rune) => rune < 32 || rune == 127);
  }
}

// 选择一段视频或最多九张照片，并返回路径型媒体。

/// 采集到的媒体文件(路径型,不载入字节)。
class PickedMediaFile {
  const PickedMediaFile({
    required this.path,
    required this.fileName,
    required this.mime,
    required this.kind,
  });

  final String path;
  final String fileName;
  final String mime;
  final ChatMessageKind kind;
}

typedef ChatGalleryFilesPicker = Future<List<XFile>> Function(
  BuildContext context,
);

/// Chat 相册唯一边界：一次只允许一个视频，或一至九张照片。
class MediaPicker {
  MediaPicker({ChatGalleryFilesPicker? pickGallery})
    : _pickGallery = pickGallery ?? _defaultPickGallery;

  final ChatGalleryFilesPicker _pickGallery;

  Future<List<PickedMediaFile>> gallery(BuildContext context) async {
    final files = await _pickGallery(context);
    final picked = <PickedMediaFile>[];
    for (final file in files) {
      final fileName = file.name;
      final mime = file.mimeType ?? mimeFromFileName(fileName);
      final kind = mediaKindFromMime(mime);
      if (kind != ChatMessageKind.image && kind != ChatMessageKind.video) {
        throw const FormatException('相册只能选择照片或视频');
      }
      picked.add(
        PickedMediaFile(
          path: file.path,
          fileName: fileName,
          mime: mime,
          kind: kind,
        ),
      );
    }
    if (picked.isEmpty) return const <PickedMediaFile>[];
    final kind = picked.first.kind;
    if (picked.any((item) => item.kind != kind) ||
        (kind == ChatMessageKind.video && picked.length != 1) ||
        (kind == ChatMessageKind.image && picked.length > 9)) {
      throw const FormatException('一次只能选择1个视频，或1至9张照片');
    }
    return picked;
  }
}

Future<List<XFile>> _defaultPickGallery(BuildContext context) async {
  final assets = await AssetPicker.pickAssets(
    context,
    // wechatMoment 在选择阶段强制“单视频或多图”互斥，返回边界仍再次校验。
    // ignore: prefer_const_constructors
    pickerConfig: AssetPickerConfig(
      maxAssets: 9,
      requestType: RequestType.common,
      specialPickerType: SpecialPickerType.wechatMoment,
      themeColor: Theme.of(context).colorScheme.primary,
      textDelegate: const AssetPickerTextDelegate(),
    ),
  );
  if (assets == null || assets.isEmpty) return const <XFile>[];
  final files = <XFile>[];
  for (final asset in assets) {
    final file = await asset.file;
    if (file == null) continue;
    final title = await asset.titleAsync;
    files.add(
      XFile(
        file.path,
        name: title.isEmpty ? null : title,
        mimeType: await asset.mimeTypeAsync,
      ),
    );
  }
  return files;
}
