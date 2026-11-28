// 保存和读取原草稿模型、媒体标识及持久状态。

import 'dart:convert';

import 'package:citizen_square/draft/media.dart';
import 'package:citizen_square/media/store.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_storage/social.dart'
    as social_store
    show Cleanup, Draft, Media, Publish;
import 'package:citizen_storage/social.dart';
import 'package:isar_community/isar.dart';

// 定义固定发布类型和可见范围的本地草稿及完整内容往返。

/// 广场草稿箱的一条草稿；发布类型在创建时固定为公文、文章或视频。
///
/// 与发布 manifest 同构，便于恢复到发布页并直接发布：
/// media 顺序 = [首图, ...正文媒体]（文章）/ 图集（公文）/ 单视频（视频）；
/// contentSections 仅文章使用：每段保存 text_delta 与一个可选媒体引用。
class SquareComposeDraft {
  const SquareComposeDraft({
    required this.draftId,
    required this.cidNumber,
    required this.postType,
    this.postVisibility = SquarePostVisibility.public,
    this.title,
    required this.text,
    required this.media,
    this.contentSections,
    required this.updatedAt,
  });

  final String draftId;

  /// 草稿永久属于 CID；发布时再读取该 CID 当前绑定账户完成签名与付款。
  final String cidNumber;
  final SquarePostType postType;
  final SquarePostVisibility postVisibility;
  final String? title;
  final String text;
  final List<SquareLocalMediaDraft> media;
  final List<Map<String, Object?>>? contentSections;
  final int updatedAt;

  bool get isArticle => postType == SquarePostType.article;

  bool get isEmpty =>
      text.trim().isEmpty && media.isEmpty && (title?.trim().isEmpty ?? true);

  String get typeLabel => postType.label;

  /// 卡片摘要：文章优先标题，否则正文。
  String get summary {
    final trimmedTitle = title?.trim();
    if (isArticle && trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    return text.trim();
  }

  SquareComposeDraft copyWith({
    List<SquareLocalMediaDraft>? media,
    List<Map<String, Object?>>? contentSections,
    int? updatedAt,
    SquarePostVisibility? postVisibility,
  }) {
    return SquareComposeDraft(
      draftId: draftId,
      cidNumber: cidNumber,
      postType: postType,
      postVisibility: postVisibility ?? this.postVisibility,
      title: title,
      text: text,
      media: media ?? this.media,
      contentSections: contentSections ?? this.contentSections,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'draft_id': draftId,
    'cid_number': cidNumber,
    'post_type': postType.workerValue,
    'post_visibility': postVisibility.name,
    if (title != null) 'title': title,
    'text': text,
    'media': media.map(_mediaToJson).toList(),
    if (contentSections != null) 'content_sections': contentSections,
    'updated_at': updatedAt,
  };

  String toJsonString() => jsonEncode(toJson());

  static SquareComposeDraft? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SquareComposeDraft.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  factory SquareComposeDraft.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    final rawSections = json['content_sections'];
    final draftId = json['draft_id']?.toString() ?? '';
    final cidNumber = json['cid_number']?.toString() ?? '';
    final updatedAt = json['updated_at'] is int
        ? json['updated_at'] as int
        : int.tryParse(json['updated_at']?.toString() ?? '') ?? 0;
    if (draftId.isEmpty ||
        cidNumber.isEmpty ||
        updatedAt <= 0 ||
        rawMedia is! List ||
        (rawSections != null && rawSections is! List)) {
      throw const FormatException('草稿主键或时间不合法');
    }
    return SquareComposeDraft(
      draftId: draftId,
      cidNumber: cidNumber,
      postType: _postTypeFromJson(json['post_type']),
      postVisibility: SquarePostVisibility.parse(json['post_visibility']),
      title: json['title']?.toString(),
      text: json['text']?.toString() ?? '',
      media: rawMedia.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('草稿媒体条目损坏');
        }
        return _mediaFromJson(item);
      }).toList(),
      contentSections: rawSections is List
          ? rawSections.map((e) {
              if (e is! Map) throw const FormatException('草稿文章条目损坏');
              return e.map((k, v) => MapEntry(k.toString(), v));
            }).toList()
          : null,
      updatedAt: updatedAt,
    );
  }

  static SquarePostType _postTypeFromJson(Object? value) {
    for (final postType in SquarePostType.values) {
      if (postType.workerValue == value) return postType;
    }
    throw const FormatException('草稿 post_type 不合法');
  }

  static Map<String, Object?> _mediaToJson(SquareLocalMediaDraft draft) => {
    'media_kind': draft.mediaKind.workerValue,
    'body_hash': draft.bodyHash ?? (throw const FormatException('草稿媒体尚未入库')),
    'file_name': draft.fileName,
    'content_type': draft.contentType,
    'byte_size': draft.byteSize,
    if (draft.pixelWidth != null) 'pixel_width': draft.pixelWidth,
    if (draft.pixelHeight != null) 'pixel_height': draft.pixelHeight,
    if (draft.assetId != null) 'asset_id': draft.assetId,
    if (draft.videoSecs != null) 'video_secs': draft.videoSecs,
  };

  static SquareLocalMediaDraft _mediaFromJson(Map<String, dynamic> json) {
    final mediaKind = switch (json['media_kind']) {
      'image' => SquareMediaKind.image,
      'video' => SquareMediaKind.video,
      _ => throw const FormatException('草稿 media_kind 不合法'),
    };
    return SquareLocalMediaDraft(
      mediaKind: mediaKind,
      // 持久草稿只引用已入库内容；路径仅在本次预览时再生。
      path: '',
      bodyHash: json['body_hash'] as String?,
      pixelWidth: json['pixel_width'] as int?,
      pixelHeight: json['pixel_height'] as int?,
      fileName: json['file_name']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      byteSize: json['byte_size'] is int
          ? json['byte_size'] as int
          : int.tryParse(json['byte_size']?.toString() ?? '') ?? 0,
      videoSecs: json['video_secs'] is int
          ? json['video_secs'] as int
          : int.tryParse(json['video_secs']?.toString() ?? ''),
      assetId: json['asset_id']?.toString().trim().isEmpty == false
          ? json['asset_id']?.toString()
          : null,
    );
  }
}

// 按CID保存和恢复广场草稿，协调媒体引用及待重试清理。

/// 广场草稿箱存储契约（便于测试注入）。
abstract class SquareComposeDraftRepository {
  Future<void> save(SquareComposeDraft draft);
  Future<List<SquareComposeDraft>> list(String cidNumber);
  Future<void> delete(String cidNumber, String draftId);

  /// 真实本地仓库处理待重试文件事实；测试仓库可使用空实现。
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {}
}

class SquareComposeDraftStoreException implements Exception {
  const SquareComposeDraftStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 广场草稿的 SocialIsar 类型化仓库。
///
/// [list] 是严格纯读取：损坏行会 fail-closed 并原样保留，绝不在读取中修复、迁移、
/// 删除数据库行或媒体。未发布草稿不按数量淘汰；用户明确删除时才写入文件清理事实，
/// 再于事务外尝试删除媒体目录。
class SquareComposeDraftStore implements SquareComposeDraftRepository {
  SquareComposeDraftStore._();

  static final SquareComposeDraftStore instance = SquareComposeDraftStore._();

  static const String _draftDirectoryCleanup = 'draft_directory';

  /// 与发布成功收尾共用的文件清理事实；调用方已处于 Social 写事务。
  static Future<void> planCleanupInTransaction(
    Isar db,
    String cid,
    String draftId,
  ) async {
    await db.collection<social_store.Cleanup>().putByCidNumberDraftId(
      _newCleanup(
        cidNumber: cid,
        draftId: draftId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> save(SquareComposeDraft draft) async {
    _validateIdentity(cidNumber: draft.cidNumber, draftId: draft.draftId);
    if (draft.updatedAt <= 0) {
      throw const SquareComposeDraftStoreException('草稿时间不合法');
    }
    final normalizedMedia = <SquareLocalMediaDraft>[];
    final importingFiles = draft.media.any((item) => item.bodyHash == null);
    for (final item in draft.media) {
      normalizedMedia.add(
        item.bodyHash == null
            ? await ComposeDraftMedia.persist(
                draft.cidNumber,
                draft.draftId,
                item,
              )
            : item,
      );
    }
    final normalized = draft.copyWith(media: normalizedMedia);
    final prepared = _toEntity(normalized);
    final cleanupIds = <Id>[];
    await SocialIsar.instance.writeTxn((isar) async {
      final publishing = await isar
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(draft.cidNumber, draft.draftId);
      if (publishing != null) {
        throw const SquareComposeDraftStoreException('该草稿正在恢复发布结果，不能覆盖内容');
      }
      for (final item in normalizedMedia) {
        final stored = await isar
            .collection<social_store.Media>()
            .getByCidNumberBodyHash(draft.cidNumber, item.bodyHash!);
        if (stored == null ||
            stored.byteSize != item.byteSize ||
            stored.mediaKind != item.mediaKind.workerValue ||
            stored.contentType != item.contentType) {
          throw const SquareMediaStoreException('草稿媒体声明与数据库不一致');
        }
      }
      await SquareMediaStore.replaceReferencesInTransaction(
        isar,
        cidNumber: draft.cidNumber,
        contentKind: 'draft',
        contentId: draft.draftId,
        references: [
          for (var i = 0; i < normalizedMedia.length; i++)
            SquareMediaReference(
              cidNumber: draft.cidNumber,
              bodyHash: normalizedMedia[i].bodyHash!,
              contentKind: 'draft',
              contentId: draft.draftId,
              mediaIndex: i,
              mediaRole: 'main',
            ),
        ],
      );
      final existing = await isar
          .collection<social_store.Draft>()
          .getByCidNumberDraftId(prepared.cidNumber, prepared.draftId);
      if (existing != null) prepared.rowId = existing.rowId;
      await isar.collection<social_store.Draft>().putByCidNumberDraftId(
        prepared,
      );

      // 重新保存同一 draft_id 即声明它仍是有效草稿，撤销尚未执行的旧清理事实。
      final staleCleanup = await isar
          .collection<social_store.Cleanup>()
          .getByCidNumberDraftId(draft.cidNumber, draft.draftId);
      if (staleCleanup != null) {
        await isar.collection<social_store.Cleanup>().delete(
          staleCleanup.rowId,
        );
      }

      if (importingFiles) {
        final cleanup = _newCleanup(
          cidNumber: draft.cidNumber,
          draftId: draft.draftId,
          createdAt: draft.updatedAt,
        );
        cleanupIds.add(
          await isar.collection<social_store.Cleanup>().putByCidNumberDraftId(
            cleanup,
          ),
        );
      }
    });
    await _runCleanupIds(cleanupIds);
  }

  /// 当前草稿只从本地内容库生成临时处理文件，读取不回填或改写草稿记录。
  Future<SquareComposeDraft> restore(SquareComposeDraft draft) async {
    _validateIdentity(cidNumber: draft.cidNumber, draftId: draft.draftId);
    if (draft.media.any((item) => item.bodyHash == null)) {
      throw const FormatException('草稿媒体缺少本地内容索引');
    }
    final media = <SquareLocalMediaDraft>[];
    for (final item in draft.media) {
      media.add(
        await ComposeDraftMedia.persist(draft.cidNumber, draft.draftId, item),
      );
    }
    return draft.copyWith(media: media);
  }

  @override
  Future<List<SquareComposeDraft>> list(String cidNumber) async {
    _validateIdentity(cidNumber: cidNumber);
    final entities = await SocialIsar.instance.read((isar) async {
      final rows = await isar
          .collection<social_store.Draft>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findAll();
      return rows.map(_copyEntity).toList(growable: false);
    });

    final drafts = entities.map(_fromEntity).toList(growable: false);
    drafts.sort((left, right) {
      final byTime = right.updatedAt.compareTo(left.updatedAt);
      if (byTime != 0) return byTime;
      return right.draftId.compareTo(left.draftId);
    });
    return drafts;
  }

  @override
  Future<void> delete(String cidNumber, String draftId) async {
    _validateIdentity(cidNumber: cidNumber, draftId: draftId);
    late Id cleanupId;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    await SocialIsar.instance.writeTxn((isar) async {
      final publishing = await isar
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(cidNumber, draftId);
      if (publishing != null) throw StateError('请先恢复该草稿的发布结果');
      await SquareMediaStore.removeContentInTransaction(
        isar,
        cidNumber: cidNumber,
        contentKind: 'draft',
        contentId: draftId,
      );
      final entity = await isar
          .collection<social_store.Draft>()
          .getByCidNumberDraftId(cidNumber, draftId);
      if (entity != null) {
        await isar.collection<social_store.Draft>().delete(entity.rowId);
      }
      cleanupId = await isar
          .collection<social_store.Cleanup>()
          .putByCidNumberDraftId(
            _newCleanup(
              cidNumber: cidNumber,
              draftId: draftId,
              createdAt: createdAt,
            ),
          );
    });
    await _runCleanupIds([cleanupId]);
  }

  /// 重试此前由明确删除动作留下的文件清理事实。
  ///
  /// 本方法不会由 [list] 或普通启动隐式调用；调用方应在用户明确重试或同一删除流程中
  /// 调用。全部计划都会尝试，最后聚合报告失败项。
  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {
    if (cidNumber != null) _validateIdentity(cidNumber: cidNumber);
    final rowIds = await SocialIsar.instance.read((isar) async {
      final rows = cidNumber == null
          ? await isar.collection<social_store.Cleanup>().where().findAll()
          : await isar
                .collection<social_store.Cleanup>()
                .filter()
                .cidNumberEqualTo(cidNumber)
                .findAll();
      return rows.map((row) => row.rowId).toList(growable: false);
    });
    await _runCleanupIds(rowIds);
  }

  Future<void> _runCleanupIds(List<Id> rowIds) async {
    final failures = <String>[];
    for (final rowId in rowIds) {
      final plan = await SocialIsar.instance.read((isar) async {
        final row = await isar.collection<social_store.Cleanup>().get(rowId);
        return row == null ? null : _copyCleanup(row);
      });
      if (plan == null) continue;
      if (plan.cleanupKind != _draftDirectoryCleanup) {
        failures.add('$rowId：未知清理类型 ${plan.cleanupKind}');
        continue;
      }

      try {
        await ComposeDraftMedia.deleteDir(plan.cidNumber, plan.draftId);
        await SocialIsar.instance.writeTxn((isar) async {
          final current = await isar.collection<social_store.Cleanup>().get(
            rowId,
          );
          if (current != null && current.rowId == plan.rowId) {
            await isar.collection<social_store.Cleanup>().delete(current.rowId);
          }
        });
      } catch (error) {
        failures.add('$rowId：$error');
        await SocialIsar.instance.writeTxn((isar) async {
          final current = await isar.collection<social_store.Cleanup>().get(
            rowId,
          );
          if (current == null || current.rowId != plan.rowId) return;
          current
            ..tryCount += 1
            ..lastError = error.toString();
          await isar.collection<social_store.Cleanup>().putByCidNumberDraftId(
            current,
          );
        });
      }
    }
    if (failures.isNotEmpty) {
      throw SquareComposeDraftStoreException(
        '草稿事实已更新，但媒体清理尚未全部完成：${failures.join('；')}',
      );
    }
  }

  static social_store.Draft _toEntity(SquareComposeDraft draft) {
    _validateIdentity(cidNumber: draft.cidNumber, draftId: draft.draftId);
    if (draft.updatedAt <= 0) {
      throw const SquareComposeDraftStoreException('草稿时间不合法');
    }
    final json = draft.toJson();
    return social_store.Draft()
      ..cidNumber = draft.cidNumber
      ..draftId = draft.draftId
      ..postType = draft.postType.workerValue
      ..postVisibility = draft.postVisibility.name
      ..title = draft.title
      ..text = draft.text
      ..mediaData = jsonEncode(json['media'])
      ..sectionData = json['content_sections'] == null
          ? null
          : jsonEncode(json['content_sections'])
      ..updatedAt = draft.updatedAt;
  }

  static void _validateIdentity({required String cidNumber, String? draftId}) {
    final invalidCid =
        cidNumber.trim().isEmpty ||
        cidNumber.trim() != cidNumber ||
        utf8.encode(cidNumber).length > 32 ||
        cidNumber == '.' ||
        cidNumber == '..';
    final invalidDraft =
        draftId != null &&
        (draftId.trim().isEmpty ||
            draftId.trim() != draftId ||
            draftId == '.' ||
            draftId == '..');
    if (invalidCid || invalidDraft) {
      throw const SquareComposeDraftStoreException('草稿主键不合法');
    }
  }

  static SquareComposeDraft _fromEntity(social_store.Draft entity) {
    try {
      final media = jsonDecode(entity.mediaData);
      final sections = entity.sectionData == null
          ? null
          : jsonDecode(entity.sectionData!);
      if (media is! List || (sections != null && sections is! List)) {
        throw const FormatException('草稿嵌套字段不是目标结构');
      }
      return SquareComposeDraft.fromJson(<String, dynamic>{
        'draft_id': entity.draftId,
        'cid_number': entity.cidNumber,
        'post_type': entity.postType,
        'post_visibility': entity.postVisibility,
        if (entity.title != null) 'title': entity.title,
        'text': entity.text,
        'media': media,
        'content_sections': ?sections,
        'updated_at': entity.updatedAt,
      });
    } on Object catch (error) {
      throw SquareComposeDraftStoreException(
        '草稿 ${entity.draftId} 数据损坏，已原样保留：$error',
      );
    }
  }

  static social_store.Draft _copyEntity(social_store.Draft source) =>
      social_store.Draft()
        ..rowId = source.rowId
        ..cidNumber = source.cidNumber
        ..draftId = source.draftId
        ..postType = source.postType
        ..postVisibility = source.postVisibility
        ..title = source.title
        ..text = source.text
        ..mediaData = source.mediaData
        ..sectionData = source.sectionData
        ..updatedAt = source.updatedAt;

  static social_store.Cleanup _newCleanup({
    required String cidNumber,
    required String draftId,
    required int createdAt,
  }) => social_store.Cleanup()
    ..cidNumber = cidNumber
    ..draftId = draftId
    ..cleanupKind = _draftDirectoryCleanup
    ..createdAt = createdAt
    ..tryCount = 0;

  static social_store.Cleanup _copyCleanup(social_store.Cleanup source) =>
      social_store.Cleanup()
        ..rowId = source.rowId
        ..cidNumber = source.cidNumber
        ..draftId = source.draftId
        ..cleanupKind = source.cleanupKind
        ..createdAt = source.createdAt
        ..tryCount = source.tryCount
        ..lastError = source.lastError;
}
