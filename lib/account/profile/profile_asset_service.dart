import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';

import 'package:citizenapp/network/square_api_client.dart';

class ProfileAssetResult {
  const ProfileAssetResult({
    required this.objectKey,
    required this.contentHash,
    required this.bytes,
  });

  final String objectKey;
  final String contentHash;
  final Uint8List bytes;
}

/// 头像/背景资产上传编排：算 sha256 → 申请授权 → PUT 字节 → 返回 object_key + hash。
/// 内容只进 R2，不上链。
class ProfileAssetService {
  ProfileAssetService({
    SquareApiClient? client,
    Future<Uint8List> Function(Uint8List, int, int, int)? compress,
  }) : _client = client ?? SquareApiClient(),
       _compress = compress ?? _compressWebp;
  final Future<Uint8List> Function(Uint8List, int, int, int) _compress;
  static Future<Uint8List> _compressWebp(
    Uint8List bytes,
    int width,
    int height,
    int quality,
  ) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: width,
    minHeight: height,
    quality: quality,
    format: CompressFormat.webp,
    keepExif: false,
  );

  final SquareApiClient _client;

  Future<ProfileAssetResult> upload({
    required SquareSession session,
    required String kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!const {'avatar', 'banner'}.contains(kind)) {
      throw const SquarePreflightException('资料图片类型无效', 'invalid_profile_kind');
    }
    final rules = SubscriptionService.resourceGate.profileMedia(
      _client.baseUri.origin,
      session,
    );
    final maxBytes = rules?['${kind}_bytes'];
    if (maxBytes is! int ||
        maxBytes <= 0 ||
        rules?['content_type'] != 'image/webp') {
      throw const SquarePreflightException(
        '资料媒体规格暂不可用，请稍后重试',
        'profile_media_unavailable',
      );
    }
    if (bytes.isEmpty) {
      throw const SquarePreflightException('资料图片不能为空', 'invalid_profile_media');
    }
    if (contentType != 'image/webp' || bytes.length > maxBytes) {
      final source = bytes;
      Uint8List? compressed;
      for (final quality in [75, 60, 45, 30]) {
        final candidate = await _compress(
          source,
          kind == 'avatar' ? 1024 : 1920,
          kind == 'avatar' ? 1024 : 720,
          quality,
        );
        if (candidate.isNotEmpty && candidate.length <= maxBytes) {
          compressed = candidate;
          break;
        }
      }
      if (compressed == null) {
        throw const SquarePreflightException(
          '资料图片压缩后仍超出上限',
          'profile_media_limit',
        );
      }
      bytes = compressed;
      contentType = 'image/webp';
    }
    await session.validateCurrent();
    final sha = sha256.convert(bytes).toString();
    final prepared = await _client.prepareProfileAsset(
      session: session,
      kind: kind,
      contentType: contentType,
      byteSize: bytes.length,
      sha256Hex: sha,
    );
    await _client.uploadBytesTo(
      prepared.uploadUrl,
      bytes,
      contentType,
      session: session,
    );
    return ProfileAssetResult(
      objectKey: prepared.objectKey,
      contentHash: prepared.contentHash,
      bytes: bytes,
    );
  }
}
