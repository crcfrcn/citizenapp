import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/8964/media/square_media_processor.dart';
import 'package:citizenapp/8964/media/square_media_store.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';

class SquareUploadedContent {
  const SquareUploadedContent({
    required this.session,
    required this.postId,
    required this.contentHash,
    required this.receiptId,
  });

  final SquareSession session;
  final String postId;
  final String contentHash;
  final String receiptId;
}

class SquarePreparedContent {
  SquarePreparedContent({
    required this.session,
    required this.preparedUpload,
    required this.postId,
    required this.contentHash,
    required this.receiptId,
    required this.manifestBytes,
    required List<SquareLocalMediaDraft> mediaDrafts,
    this.processedMedia,
    this.mediaReferences = const [],
  }) : mediaDrafts = List.unmodifiable(mediaDrafts);

  final SquareSession session;
  final SquarePreparedUpload preparedUpload;
  final String postId;
  final String contentHash;
  final String receiptId;
  final Uint8List manifestBytes;
  final List<SquareLocalMediaDraft> mediaDrafts;
  final SquareProcessedMediaBatch? processedMedia;
  final List<SquareMediaReference> mediaReferences;

  Future<void> deleteTemporaryMedia() async {
    await processedMedia?.deleteTemporaryFiles();
  }
}

/// 普通会话由唯一MLS会话服务提供，发布器不持有签名能力。
typedef SquareSessionResolver = Future<SquareSession> Function(
  String accountId,
);

abstract class SquareContentUploader {
  Future<SquareSession> resumeSession(
    String accountId,
    SquareSessionResolver sessionForAccount,
  );
  Future<SquarePreparedContent> preparePostContent({
    required String accountId,
    required SquarePostType postType,
    required String text,
    required List<SquareLocalMediaDraft> mediaDrafts,
    required SquareSessionResolver sessionForAccount,
    String? title,
    List<Map<String, Object?>>? contentSections,
    void Function(SquarePublishStage stage)? onStage,
  });

  Future<SquareUploadedContent> uploadPreparedContent(
    SquarePreparedContent prepared, {
    void Function(SquarePublishStage stage)? onStage,
  });
}

/// 只有真实手机端上传器实现本地媒体取消；测试替身不需要伪造原生通道。
abstract interface class SquareMediaProcessingController {
  Future<void> cancelMediaProcessing();
}

class SquareUploadService
    implements SquareContentUploader, SquareMediaProcessingController {
  SquareUploadService({
    required SubscriptionService subscriptionService,
    SquareApiClient? apiClient,
    SquareMediaProcessor? mediaProcessor,
  }) : _api = apiClient ?? SquareApiClient(),
       _mediaProcessor = mediaProcessor ?? SquareMediaProcessor(),
       _subscriptionService = subscriptionService;

  final SquareApiClient _api;
  final SquareMediaProcessor _mediaProcessor;
  final SubscriptionService _subscriptionService;

  @override
  Future<SquareSession> resumeSession(
    String accountId,
    SquareSessionResolver sessionForAccount,
  ) => sessionForAccount(accountId);

  @override
  Future<void> cancelMediaProcessing() => _mediaProcessor.cancel();

  @override
  Future<SquarePreparedContent> preparePostContent({
    required String accountId,
    required SquarePostType postType,
    required String text,
    required List<SquareLocalMediaDraft> mediaDrafts,
    required SquareSessionResolver sessionForAccount,
    String? title,
    List<Map<String, Object?>>? contentSections,
    void Function(SquarePublishStage stage)? onStage,
  }) async {
    onStage?.call(SquarePublishStage.signingIn);
    final session = await sessionForAccount(accountId);
    // 发布只读取 CitizenServe 已同步的会员状态，禁止在发布路径读取链或触发状态修复。
    // 与会员页/附件共用同一请求和结果；缺失或到期才读取，不每次强刷。
    final membership = await _subscriptionService.authorizeMembership(session);
    final plan = membership.activePlan;
    final usageState = membership.usageState;
    if (plan == null || usageState == null) {
      throw const SquareApiException('需要有效会员才能发布广场内容');
    }
    final earlyError = validateSquarePostContent(
      postType: postType,
      title: title,
      text: text,
      mediaDrafts: mediaDrafts,
      contentSections: contentSections,
      plan: plan,
      usageState: usageState,
      processed: false,
    );
    if (earlyError != null) {
      throw SquarePreflightException(earlyError, 'upload_limit');
    }
    final earlyReservation = await SubscriptionService.resourceGate.reserve(
      origin: _api.baseUri.origin,
      session: session,
      operation: 'square',
      costs: const {},
    );
    SquareProcessedMediaBatch? processedMedia;
    try {
      onStage?.call(SquarePublishStage.processingMedia);
      processedMedia = await _mediaProcessor.process(
        mediaDrafts: mediaDrafts,
        membershipPlan: plan,
      );
      final finalMediaDrafts = processedMedia.mediaDrafts;
      final derivatives = processedMedia.derivatives;
      if (derivatives.length != finalMediaDrafts.length) {
        throw const SquareApiException('本地媒体衍生图数量不一致');
      }
      final validationError = validateSquarePostContent(
        postType: postType,
        title: title,
        text: text,
        mediaDrafts: finalMediaDrafts,
        contentSections: contentSections,
        plan: plan,
        usageState: usageState,
      );
      if (validationError != null) throw SquareApiException(validationError);

      final mediaManifests = <Map<String, Object?>>[];
      final mediaHashes = <String>[];
      final derivativeHashes = <String>[];
      for (final draft in finalMediaDrafts) {
        // 成品完整入库后才申请上传；数据库容量不足时不会发出媒体上传。
        final stored = await const SquareMediaStore().saveFile(
          cidNumber: session.cidNumber,
          path: draft.path,
          mediaKind: draft.mediaKind.workerValue,
          contentType: draft.contentType,
          byteSize: draft.byteSize,
        );
        final digest = stored.bodyHash;
        mediaHashes.add(digest);
        mediaManifests.add({
          'media_kind': draft.mediaKind.workerValue,
          'file_name': draft.fileName,
          'byte_size': draft.byteSize,
          'body_hash': digest,
          if (draft.videoSecs != null) 'video_secs': draft.videoSecs,
          if (draft.pixelWidth != null) 'pixel_width': draft.pixelWidth,
          if (draft.pixelHeight != null) 'pixel_height': draft.pixelHeight,
        });
      }
      for (final derivative in derivatives) {
        final stored = await const SquareMediaStore().saveFile(
          cidNumber: session.cidNumber,
          path: derivative.path,
          mediaKind: 'image',
          contentType: derivative.contentType,
          byteSize: derivative.byteSize,
        );
        derivativeHashes.add(stored.bodyHash);
      }

      final trimmedTitle = title?.trim() ?? '';
      final manifestBytes = _canonicalJsonBytes({
        'schema': 'citizenapp.square.post',
        'cid_number': session.cidNumber,
        'post_type': postType.workerValue,
        if (trimmedTitle.isNotEmpty) 'post_title': trimmedTitle,
        'text': text,
        // 每个文章段落先保存 text_delta，再保存一个可选媒体引用。
        if (contentSections != null && contentSections.isNotEmpty)
          'content_sections': contentSections,
        'media_items': mediaManifests,
      });
      final contentHash = sha256.convert(manifestBytes).toString();

      onStage?.call(SquarePublishStage.preparingStorage);
      // prepare 只请求 Worker 的 D1 会员投影和额度早期反馈；编辑、哈希与上传均不读链。
      earlyReservation.cancel(); // 实际prepare以精确成品/衍生图/manifest总量原子重占。
      final prepared = await _api.prepareUpload(
        session: session,
        postType: postType,
        titleLength: postType == SquarePostType.article
            ? trimmedTitle.runes.length
            : 0,
        textLength: text.trim().runes.length,
        contentHash: contentHash,
        manifestBytes: manifestBytes.length,
        mediaItems: finalMediaDrafts
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final draft = entry.value;
              final derivative = derivatives[index];
              if (derivative.mediaIndex != index) {
                throw const SquareApiException('本地媒体衍生图顺序不一致');
              }
              final width = draft.pixelWidth;
              final height = draft.pixelHeight;
              if (width == null || height == null) {
                throw const SquareApiException('本地媒体尺寸缺失');
              }
              return SquareUploadMediaRequest(
                mediaKind: draft.mediaKind,
                byteSize: draft.byteSize,
                bodyHash: mediaHashes[index],
                pixelWidth: width,
                pixelHeight: height,
                previewBytes: derivative.byteSize,
                previewHash: derivativeHashes[index],
                videoSecs: draft.videoSecs,
              );
            })
            .toList(growable: false),
      );
      if (prepared.mediaUploads.length != finalMediaDrafts.length * 2) {
        throw const SquareApiException('上传授权数量与本地媒体数量不一致');
      }

      return SquarePreparedContent(
        session: session,
        preparedUpload: prepared,
        postId: prepared.postId,
        contentHash: contentHash,
        receiptId: prepared.receiptId,
        manifestBytes: manifestBytes,
        mediaDrafts: finalMediaDrafts,
        processedMedia: processedMedia,
        mediaReferences: [
          for (var i = 0; i < finalMediaDrafts.length; i++) ...[
            SquareMediaReference(
              cidNumber: session.cidNumber,
              bodyHash: mediaHashes[i],
              contentKind: 'publication',
              contentId: prepared.postId,
              mediaIndex: i,
              mediaRole: 'main',
            ),
            SquareMediaReference(
              cidNumber: session.cidNumber,
              bodyHash: derivativeHashes[i],
              contentKind: 'publication',
              contentId: prepared.postId,
              mediaIndex: i,
              mediaRole: derivatives[i].derivativeKind.name,
            ),
          ],
        ],
      );
    } catch (_) {
      earlyReservation.cancel();
      await processedMedia?.deleteTemporaryFiles();
      rethrow;
    }
  }

  @override
  Future<SquareUploadedContent> uploadPreparedContent(
    SquarePreparedContent prepared, {
    void Function(SquarePublishStage stage)? onStage,
  }) async {
    final mediaDrafts = prepared.mediaDrafts;
    final preparedUpload = prepared.preparedUpload;
    if (preparedUpload.mediaUploads.length != mediaDrafts.length * 2) {
      throw const SquareApiException('上传授权数量与本地媒体数量不一致');
    }

    try {
      // 媒体与 manifest 必须在最终链签名前完成；链失败时由服务端查 finalized 真源后清理。
      onStage?.call(SquarePublishStage.uploadingMedia);
      await _api.uploadObject(
        uploadUrl: preparedUpload.manifestUploadUrl,
        contentType: 'application/json; charset=utf-8',
        body: prepared.manifestBytes,
        session: prepared.session,
      );
      for (final upload in preparedUpload.mediaUploads) {
        final i = upload.mediaIndex;
        if (i < 0 || i >= mediaDrafts.length) {
          throw const SquareApiException('上传目标媒体序号无效');
        }
        final draft = mediaDrafts[i];
        final source = upload.objectRole == 'source';
        final derivative = prepared.processedMedia?.derivatives[i];
        if (!source &&
            (derivative == null ||
                derivative.mediaIndex != i ||
                derivative.derivativeKind.name != upload.objectRole)) {
          throw const SquareApiException('衍生图上传授权与本地文件不一致');
        }
        await _api.uploadMedia(
          session: prepared.session,
          upload: upload,
          filePath: source ? draft.path : derivative!.path,
          byteSize: source ? draft.byteSize : derivative!.byteSize,
        );
      }

      onStage?.call(SquarePublishStage.completingStorage);
      final completed = await _api.completeUpload(
        session: prepared.session,
        uploadId: preparedUpload.uploadId,
        contentHash: prepared.contentHash,
      );
      if (completed.postId != prepared.postId ||
          completed.receiptId != prepared.receiptId) {
        throw const SquareApiException('存储完成响应与链上发布索引不一致');
      }

      return SquareUploadedContent(
        session: prepared.session,
        postId: completed.postId,
        contentHash: completed.contentHash,
        receiptId: completed.receiptId,
      );
    } finally {
      // 成品字节已入库并由发布恢复行持有引用；这里只删除可再生的处理文件。
      await prepared.deleteTemporaryMedia();
    }
  }

  Uint8List _canonicalJsonBytes(Map<String, Object?> value) {
    return Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }
}

/// CitizenApp 发布前强校验；Cloudflare 仍在 prepare 和 complete 独立复核。
/// 本函数只读 Worker 返回的当前套餐与用量快照，绝不代替服务端原子预留。
String? validateSquarePostContent({
  required SquarePostType postType,
  required String? title,
  required String text,
  required List<SquareLocalMediaDraft> mediaDrafts,
  required List<Map<String, Object?>>? contentSections,
  required SquareMembershipPlan plan,
  required SquareMembershipUsageState usageState,
  bool processed = true,
}) {
  final titleLength = (title ?? '').trim().runes.length;
  final textLength = text.trim().runes.length;
  final images = mediaDrafts
      .where((item) => item.mediaKind == SquareMediaKind.image)
      .toList(growable: false);
  final videos = mediaDrafts
      .where((item) => item.mediaKind == SquareMediaKind.video)
      .toList(growable: false);

  String? videoError() {
    for (final video in videos) {
      if (processed && video.byteSize > plan.video.videoMaxBytes) {
        return '单个视频体积超出当前会员档位上限';
      }
      final duration = video.videoSecs ?? 0;
      if (duration <= 0 || duration > plan.video.videoMaxSeconds) {
        return '单个视频时长超出当前会员档位上限';
      }
    }
    return null;
  }

  switch (postType) {
    case SquarePostType.document:
      if (titleLength != 0) return '公文不允许标题';
      if (textLength > plan.document.textMaxChars) {
        return '公文文字不能超过 ${plan.document.textMaxChars} 字';
      }
      if (videos.isNotEmpty) return '公文只允许图片';
      if (images.length > plan.document.maxImages) {
        return '公文图片不能超过 ${plan.document.maxImages} 张';
      }
      if (textLength == 0 && images.isEmpty) return '公文内容不能为空';
      break;
    case SquarePostType.video:
      if (titleLength != 0) return '视频不允许标题';
      if (textLength > plan.video.textMaxChars) {
        return '视频配文不能超过 ${plan.video.textMaxChars} 字';
      }
      if (mediaDrafts.length != 1 || videos.length != 1) {
        return '视频发布必须且只能包含 1 个视频';
      }
      final error = videoError();
      if (error != null) return error;
      break;
    case SquarePostType.article:
      if (titleLength < plan.article.titleMinChars ||
          titleLength > plan.article.titleMaxChars) {
        return '文章标题必须是 ${plan.article.titleMinChars}-${plan.article.titleMaxChars} 字';
      }
      if (textLength == 0) return '文章正文不能为空';
      if (textLength > plan.article.bodyMaxChars) {
        return '文章正文不能超过 ${plan.article.bodyMaxChars} 字';
      }
      if (mediaDrafts.isEmpty ||
          mediaDrafts.first.mediaKind != SquareMediaKind.image) {
        return '文章必须上传 1 张首图';
      }
      if (images.length > plan.article.maxImages) {
        return '文章图片总数不能超过 ${plan.article.maxImages} 张';
      }
      if (videos.length > plan.article.maxVideos) {
        return '当前会员每篇文章最多插入 ${plan.article.maxVideos} 个视频';
      }
      final error = videoError();
      if (error != null) return error;
      final sectionError = _validateArticleContentSections(
        contentSections,
        mediaDrafts,
      );
      if (sectionError != null) return sectionError;
      break;
  }

  return null;
}

String? _validateArticleContentSections(
  List<Map<String, Object?>>? sections,
  List<SquareLocalMediaDraft> media,
) {
  if (sections == null || sections.isEmpty) return '文章必须包含规范正文段落';
  final referenced = <int>{};
  for (final section in sections) {
    if (section.keys.any(
      (key) => !const {
        'text_delta',
        'gallery_media_indices',
        'video_media_index',
      }.contains(key),
    )) {
      return '文章段落包含未知字段';
    }
    final delta = section['text_delta'];
    final deltaError = validateArticleTextDelta(delta);
    if (deltaError != null) return deltaError;
    final galleryIndices = section['gallery_media_indices'];
    final videoIndex = section['video_media_index'];
    if (galleryIndices != null && videoIndex != null) {
      return '文章一个段落只能包含一种媒体';
    }
    if (galleryIndices != null) {
      final rawIndices = galleryIndices;
      if (rawIndices is! List || rawIndices.isEmpty || rawIndices.length > 9) {
        return '文章每个图集必须包含 1-9 张图片';
      }
      for (final rawIndex in rawIndices) {
        if (rawIndex is! int ||
            rawIndex <= 0 ||
            rawIndex >= media.length ||
            media[rawIndex].mediaKind != SquareMediaKind.image ||
            !referenced.add(rawIndex)) {
          return '文章图集与媒体顺序不一致';
        }
      }
    } else if (videoIndex != null) {
      final rawIndex = videoIndex;
      if (rawIndex is! int ||
          rawIndex <= 0 ||
          rawIndex >= media.length ||
          media[rawIndex].mediaKind != SquareMediaKind.video ||
          !referenced.add(rawIndex)) {
        return '文章视频块与媒体顺序不一致';
      }
    }
  }
  for (var index = 1; index < media.length; index++) {
    if (!referenced.contains(index)) return '文章存在未引用的正文媒体';
  }
  return null;
}

/// 客户端 Delta 白名单校验；拒绝未知属性、媒体嵌入和任意样式值。
String? validateArticleTextDelta(Object? raw) {
  if (raw is! List || raw.isEmpty) return '文章段落富文本不合法';
  final text = StringBuffer();
  for (final rawOperation in raw) {
    if (rawOperation is! Map) return '文章段落富文本操作不合法';
    if (rawOperation.keys.any(
      (key) => key != 'insert' && key != 'attributes',
    )) {
      return '文章段落富文本操作包含未知字段';
    }
    final insert = rawOperation['insert'];
    if (insert is! String || insert.isEmpty) return '文章只允许文字富文本';
    text.write(insert);
    final attributes = rawOperation['attributes'];
    if (attributes == null) continue;
    if (attributes is! Map) return '文章富文本属性不合法';
    for (final entry in attributes.entries) {
      final key = entry.key;
      final value = entry.value;
      final valid = switch (key) {
        'bold' || 'italic' || 'underline' || 'strike' => value == true,
        'font' => const {
          'heiti',
          'songti',
          'kaiti',
          'monospace',
          'jinglei',
        }.contains(value),
        'size' => const {
          'small',
          'body',
          'large',
          'subtitle',
          'title',
        }.contains(value),
        'color' => const {
          'default',
          'secondary',
          'primary',
          'info',
          'success',
          'warning',
          'danger',
        }.contains(value),
        'background' => const {
          'neutral_soft',
          'primary_soft',
          'info_soft',
          'success_soft',
          'warning_soft',
          'danger_soft',
        }.contains(value),
        'align' => insert == '\n' && const {'center', 'right'}.contains(value),
        'list' => insert == '\n' && const {'ordered', 'bullet'}.contains(value),
        _ => false,
      };
      if (!valid) return '文章富文本包含未开放的格式';
    }
  }
  if (!text.toString().endsWith('\n')) return '文章段落富文本必须规范结束';
  if (text.toString().trim().runes.length < 10) {
    return '文章每个段落不少于 10 个字';
  }
  return null;
}
