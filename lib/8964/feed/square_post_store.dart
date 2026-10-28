import 'package:citizenapp/storage/social_isar.dart'
    as social_store
    show PostCursor, Erase, Draft, MediaLink, Media, Post, Publish;
import 'package:flutter/foundation.dart' show ValueNotifier;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';

import 'package:citizenapp/storage/social_isar.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizenapp/8964/media/square_media_store.dart';
import 'package:citizenapp/8964/compose/compose_draft_store.dart';

/// 本人已发布广场内容的只读值对象。
///
/// 正文、标题、文章块和媒体声明的唯一内容真源是 [manifestBytes]；调用方若需展示，
/// 必须从这份已经通过哈希校验的原始 manifest 解析，不能另存一套本地正文字段。
class SquareLocalPost {
  SquareLocalPost({
    required this.postId,
    required this.cidNumber,
    required this.accountId,
    required this.postCategory,
    required this.postType,
    required Uint8List manifestBytes,
    required this.contentHash,
    required this.receiptId,
    required this.chainBlock,
    required this.publishedAt,
    required this.postState,
  }) : manifestBytes = Uint8List.fromList(manifestBytes);

  final String postId;
  final String cidNumber;
  final String accountId;
  final String postCategory;
  final String postType;
  final Uint8List manifestBytes;
  final String contentHash;
  final String receiptId;
  final int? chainBlock;
  final int publishedAt;
  final String postState;
}

/// Worker 本人副本接口的一页结果。
///
/// [nextCursor] 是 Worker 签发的稳定分页游标，客户端只原样回传，不解析或自行构造。
class SquareLocalPostPage {
  const SquareLocalPostPage({required this.items, required this.nextCursor});

  final List<SquareLocalPost> items;
  final String? nextCursor;
}

/// 已完成一次完整回灌时记录的远端最新发布事实。
///
/// 它只用于缩短后续增量扫描，不是本地内容真源，也不含设备时间。远端为空时
/// [postId] 为 null、[publishedAt] 为 0。
class SquarePostSyncCheckpoint {
  const SquarePostSyncCheckpoint({
    required this.postId,
    required this.publishedAt,
  });

  final String? postId;
  final int publishedAt;
}

/// 发布链路写入本人副本所需的最小边界，便于隔离测试失败与重试语义。
abstract class SquareLocalPostWriter {
  Future<void> save(SquareLocalPost post, {String? draftId});
}

/// 单帖删除所需的最小本地边界。
abstract class SquareLocalPostDeletionStore {
  Future<bool> delete({required String cidNumber, required String postId});
}

/// 注销时按永久 CID 删除全部本人副本和同步检查点的最小边界。
abstract class SquareLocalPostBulkDeletionStore {
  Future<int> deleteAllByCid(String cidNumber);
}

class SquarePostStoreException implements Exception {
  const SquarePostStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 本人广场内容的本地持久化边界。
///
/// 这里同时承担写入前完整性闸门：只有 Worker 已确认的 `published` 内容可以入库，
/// 且原始 manifest 的 SHA-256、CID 和发布类型必须与外层已确认字段一致。
/// 任何不一致都在进入 Isar 写事务前失败，绝不覆盖已有正确副本。
class SquarePostStore
    implements
        SquareLocalPostWriter,
        SquareLocalPostDeletionStore,
        SquareLocalPostBulkDeletionStore {
  const SquarePostStore();

  /// 事务提交后按CID通知页面重读；不由通知触发远端同步。
  static final revision = ValueNotifier<({String cidNumber, int revision})?>(
    null,
  );
  static int _revision = 0;
  static void _notify(String cid) =>
      revision.value = (cidNumber: cid, revision: ++_revision);

  static const String publishedState = 'published';
  static const String manifestSchema = 'citizenapp.square.post';

  /// 保存或幂等覆盖一条本人已发布内容。
  ///
  /// [created_at] 必须来自 Worker `square_posts.created_at`，本方法不读取设备时间。
  @override
  Future<void> save(SquareLocalPost post, {String? draftId}) async {
    if (draftId == null) {
      await saveAll(<SquareLocalPost>[post]);
      return;
    }
    final normalized = validate(post);
    await SocialIsar.instance.writeTxn((db) async {
      final pending = await db
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(post.cidNumber, draftId);
      if (pending == null ||
          pending.jobState != 'confirmed' ||
          pending.postId != post.postId ||
          pending.accountId != post.accountId ||
          pending.contentHash != post.contentHash ||
          pending.receiptId != post.receiptId ||
          pending.postCategory != post.postCategory ||
          pending.publishedAt != post.publishedAt ||
          pending.chainBlock != post.chainBlock) {
        throw const SquarePostStoreException('发布恢复事实与帖子不一致');
      }
      final refs = await db
          .collection<social_store.MediaLink>()
          .where()
          .contentIdCidNumberContentKindEqualTo(
            post.postId,
            post.cidNumber,
            'publication',
          )
          .findAll();
      await _validateMediaReferences(
        db,
        normalized.manifestBytes,
        post.cidNumber,
        refs,
      );
      await _putPost(db, normalized);
      // 修改产生新帖；本地收尾与旧帖删除意图同事务，退出后仍能显式恢复。
      final replaced = pending.replaceId;
      if (replaced != null &&
          replaced.isNotEmpty &&
          replaced != post.postId &&
          await db.collection<social_store.Erase>().getByCidNumberPostId(
                post.cidNumber,
                replaced,
              ) ==
              null) {
        await db.collection<social_store.Erase>().put(
          social_store.Erase()
            ..cidNumber = post.cidNumber
            ..postId = replaced
            ..jobState = 'pending',
        );
      }
      await SquareMediaStore.replaceReferencesInTransaction(
        db,
        cidNumber: post.cidNumber,
        contentKind: 'post',
        contentId: post.postId,
        references: refs
            .map(
              (r) => SquareMediaReference(
                cidNumber: r.cidNumber,
                bodyHash: r.bodyHash,
                contentKind: 'post',
                contentId: post.postId,
                mediaIndex: r.mediaIndex,
                mediaRole: r.mediaRole,
              ),
            )
            .toList(),
      );
      await SquareMediaStore.removeContentInTransaction(
        db,
        cidNumber: post.cidNumber,
        contentKind: 'publication',
        contentId: post.postId,
      );
      await SquareMediaStore.removeContentInTransaction(
        db,
        cidNumber: post.cidNumber,
        contentKind: 'draft',
        contentId: draftId,
      );
      await db.collection<social_store.Draft>().deleteByCidNumberDraftId(
        post.cidNumber,
        draftId,
      );
      await SquareComposeDraftStore.planCleanupInTransaction(
        db,
        post.cidNumber,
        draftId,
      );
      await db.collection<social_store.Publish>().delete(pending.rowId);
    });
    _notify(post.cidNumber);
  }

  Future<social_store.Publish?> readPublication(String cid, String draftId) {
    _validateCidNumber(cid);
    _requireNonEmpty(draftId, 'draft_id');
    return SocialIsar.instance.read((db) async {
      final row = await db
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(cid, draftId);
      if (row != null) _validatePublication(row);
      return row;
    });
  }

  /// 先提交发布意图与媒体引用，再允许上传/交易；阶段只前进、不推断交易失败。
  Future<void> savePublication(
    social_store.Publish row, {
    List<SquareMediaReference>? references,
  }) async {
    _validatePublication(row);
    const states = ['prepared', 'submitting', 'finalized', 'confirmed'];
    final next = states.indexOf(row.jobState);
    await SocialIsar.instance.writeTxn((db) async {
      final current = await db
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(row.cidNumber, row.draftId);
      if (current != null) {
        final old = states.indexOf(current.jobState);
        if (old < 0 ||
            current.postId != row.postId ||
            current.accountId != row.accountId ||
            current.contentHash != row.contentHash ||
            current.receiptId != row.receiptId ||
            current.uploadId != row.uploadId ||
            current.replaceId != row.replaceId ||
            (old >= 2 &&
                (current.txHash != row.txHash ||
                    current.chainHash != row.chainHash)) ||
            (old >= 3 &&
                (current.publishedAt != row.publishedAt ||
                    current.postCategory != row.postCategory ||
                    current.chainBlock != row.chainBlock)) ||
            next < old ||
            next > old + 1) {
          throw const SquarePostStoreException('发布恢复记录禁止覆盖或倒退');
        }
        row.rowId = current.rowId;
      } else if (next != 0 || references == null) {
        throw const SquarePostStoreException('发布恢复记录缺少准备阶段');
      } else {
        // 调用方传来的数据库行号不能覆盖其它 CID 的记录。
        row.rowId = Isar.autoIncrement;
      }
      if (references != null) {
        if (next != 0) throw const SquarePostStoreException('提交后不能替换发布媒体');
        await SquareMediaStore.replaceReferencesInTransaction(
          db,
          cidNumber: row.cidNumber,
          contentKind: 'publication',
          contentId: row.postId,
          references: references,
        );
        final refs = await db
            .collection<social_store.MediaLink>()
            .where()
            .contentIdCidNumberContentKindEqualTo(
              row.postId,
              row.cidNumber,
              'publication',
            )
            .findAll();
        await _validateMediaReferences(
          db,
          Uint8List.fromList(row.manifestBytes),
          row.cidNumber,
          refs,
        );
      }
      await db.collection<social_store.Publish>().put(row);
    });
  }

  static void _validatePublication(social_store.Publish row) {
    _validateCidNumber(row.cidNumber);
    _requireNonEmpty(row.draftId, 'draft_id');
    _requireNonEmpty(row.postId, 'post_id');
    if (!isAccountIdText(row.accountId) ||
        sha256.convert(row.manifestBytes).toString() != row.contentHash) {
      throw const SquarePostStoreException('发布恢复记录完整性不合法');
    }
    final manifest = _decodeManifest(Uint8List.fromList(row.manifestBytes));
    if (manifest['schema'] != manifestSchema ||
        manifest['cid_number'] != row.cidNumber ||
        manifest['post_type'] != row.postType) {
      throw const SquarePostStoreException('发布恢复记录归属不一致');
    }
    const states = ['prepared', 'submitting', 'finalized', 'confirmed'];
    final next = states.indexOf(row.jobState);
    if (next < 0 ||
        (next >= 2 && (row.txHash == null || row.chainHash == null)) ||
        (next == 3 && (row.publishedAt == null || row.postCategory == null))) {
      throw const SquarePostStoreException('发布恢复阶段缺少确认事实');
    }
  }

  /// 只在尚未提交或服务端/SDK已明确确认失败的当前动作中释放准备记录。
  Future<void> discardPublication(
    String cid,
    String draftId,
    String postId, {
    bool definitiveFailure = false,
  }) async {
    _validateCidNumber(cid);
    await SocialIsar.instance.writeTxn((db) async {
      final row = await db
          .collection<social_store.Publish>()
          .getByCidNumberDraftId(cid, draftId);
      if (row == null) return;
      if (row.postId != postId ||
          (row.jobState != 'prepared' &&
              !(definitiveFailure && row.jobState == 'submitting'))) {
        throw const SquarePostStoreException('交易未明确失败，不能丢弃发布记录');
      }
      await SquareMediaStore.removeContentInTransaction(
        db,
        cidNumber: cid,
        contentKind: 'publication',
        contentId: row.postId,
      );
      await db.collection<social_store.Publish>().delete(row.rowId);
    });
  }

  static SquareLocalPost confirmedPublication(social_store.Publish row) {
    if (row.jobState != 'confirmed') {
      throw const SquarePostStoreException('远端发布尚未确认');
    }
    return validate(
      SquareLocalPost(
        postId: row.postId,
        cidNumber: row.cidNumber,
        accountId: row.accountId,
        postCategory: row.postCategory!,
        postType: row.postType,
        manifestBytes: Uint8List.fromList(row.manifestBytes),
        contentHash: row.contentHash,
        receiptId: row.receiptId,
        chainBlock: row.chainBlock,
        publishedAt: row.publishedAt!,
        postState: publishedState,
      ),
    );
  }

  static Future<void> _validateMediaReferences(
    Isar db,
    Uint8List bytes,
    String cid,
    List<social_store.MediaLink> refs,
  ) async {
    final manifest = _decodeManifest(bytes);
    final items = manifest['media_items'];
    if (items is! List) throw const SquarePostStoreException('媒体声明缺失');
    if (refs.length != items.length * 2) {
      throw const SquarePostStoreException('发布媒体或衍生图未完整入库');
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) throw const SquarePostStoreException('媒体声明损坏');
      final main = refs
          .where((r) => r.mediaIndex == i && r.mediaRole == 'main')
          .single;
      final derivativeRole = item['media_kind'] == 'video'
          ? 'cover'
          : 'thumbnail';
      final derivative = refs
          .where((r) => r.mediaIndex == i && r.mediaRole == derivativeRole)
          .single;
      final media = await db
          .collection<social_store.Media>()
          .getByCidNumberBodyHash(cid, main.bodyHash);
      final preview = await db
          .collection<social_store.Media>()
          .getByCidNumberBodyHash(cid, derivative.bodyHash);
      if (media == null ||
          !media.isComplete ||
          media.bodyHash != item['body_hash'] ||
          media.byteSize != item['byte_size'] ||
          media.mediaKind != item['media_kind'] ||
          preview == null ||
          !preview.isComplete ||
          preview.mediaKind != 'image') {
        throw const SquarePostStoreException('发布媒体与正文声明不一致');
      }
    }
  }

  static Future<void> _putPost(Isar db, SquareLocalPost post) async {
    // 用户已发起删除的内容不得被较早发出的同步请求重新写回。
    if (await db.collection<social_store.Erase>().getByCidNumberPostId(
          post.cidNumber,
          post.postId,
        ) !=
        null) {
      return;
    }
    final existing = await db.collection<social_store.Post>().getByPostId(
      post.postId,
    );
    if (existing != null) _assertSamePublishedFact(existing, post);
    final entity = existing ?? social_store.Post();
    entity
      ..postId = post.postId
      ..cidNumber = post.cidNumber
      ..accountId = post.accountId
      ..postCategory = post.postCategory
      ..postType = post.postType
      ..manifestBytes = post.manifestBytes
      ..contentHash = post.contentHash
      ..receiptId = post.receiptId
      ..chainBlock = post.chainBlock
      ..publishedAt = post.publishedAt
      ..postState = post.postState;
    await db.collection<social_store.Post>().put(entity);
  }

  /// 原子保存一整页 Worker 回灌结果。
  ///
  /// 所有条目会先在事务外完成完整性校验；任一条不合法或同页 post_id 重复时整页拒绝，
  /// 保证同步中断后最多留下完整页，不会留下半页空洞。
  Future<void> saveAll(List<SquareLocalPost> posts) async {
    if (posts.isEmpty) return;
    final normalizedPosts = posts.map(validate).toList(growable: false);
    final postIds = <String>{};
    for (final post in normalizedPosts) {
      if (!postIds.add(post.postId)) {
        throw const SquarePostStoreException('同一回灌页包含重复 post_id');
      }
    }

    await SocialIsar.instance.writeTxn((isar) async {
      for (final normalized in normalizedPosts) {
        await _putPost(isar, normalized);
      }
    });
    for (final cid in posts.map((post) => post.cidNumber).toSet()) {
      _notify(cid);
    }
  }

  /// 同步页的正文与已验证媒体关联一起提交；下载和SHA校验在事务外完成。
  Future<void> saveSyncedPage(
    List<SquareLocalPost> posts,
    Map<String, List<SquareMediaReference>> references,
  ) async {
    final normalized = posts.map(validate).toList();
    if (normalized.map((p) => p.postId).toSet().length != normalized.length) {
      throw const SquarePostStoreException('同步页包含重复帖子');
    }
    await SocialIsar.instance.writeTxn((db) async {
      for (final post in normalized) {
        if (await db.collection<social_store.Erase>().getByCidNumberPostId(
              post.cidNumber,
              post.postId,
            ) !=
            null) {
          continue;
        }
        final refs = references[post.postId];
        if (refs == null) throw const SquarePostStoreException('同步页缺少媒体完成事实');
        await SquareMediaStore.replaceReferencesInTransaction(
          db,
          cidNumber: post.cidNumber,
          contentKind: 'post',
          contentId: post.postId,
          references: refs,
        );
        final rows = await db
            .collection<social_store.MediaLink>()
            .where()
            .contentIdCidNumberContentKindEqualTo(
              post.postId,
              post.cidNumber,
              'post',
            )
            .findAll();
        await _validateMediaReferences(
          db,
          post.manifestBytes,
          post.cidNumber,
          rows,
        );
        await _putPost(db, post);
      }
    });
    for (final cid in posts.map((post) => post.cidNumber).toSet()) {
      _notify(cid);
    }
  }

  Future<social_store.Erase?> readDeletion(String cid, String postId) {
    _validateCidNumber(cid);
    _requireNonEmpty(postId, 'post_id');
    return SocialIsar.instance.read(
      (db) =>
          db.collection<social_store.Erase>().getByCidNumberPostId(cid, postId),
    );
  }

  /// 删除意图先落盘；confirmed永久保留，既用于本地失败重试，也阻止旧同步复活。
  Future<void> recordDeletion(
    String cid,
    String postId, {
    bool confirmed = false,
  }) async {
    _validateCidNumber(cid);
    _requireNonEmpty(postId, 'post_id');
    await SocialIsar.instance.writeTxn((db) async {
      final current = await db
          .collection<social_store.Erase>()
          .getByCidNumberPostId(cid, postId);
      final row =
          current ??
          (social_store.Erase()
            ..cidNumber = cid
            ..postId = postId);
      if (current != null &&
          !{'pending', 'confirmed'}.contains(current.jobState)) {
        throw const SquarePostStoreException('删除恢复状态损坏');
      }
      row.jobState = confirmed || current?.jobState == 'confirmed'
          ? 'confirmed'
          : 'pending';
      await db.collection<social_store.Erase>().put(row);
    });
  }

  Future<List<social_store.Erase>> deletionsToRecover(String cid) {
    _validateCidNumber(cid);
    return SocialIsar.instance.read((db) async {
      final rows = await db
          .collection<social_store.Erase>()
          .filter()
          .cidNumberEqualTo(cid)
          .findAll();
      final result = <social_store.Erase>[];
      for (final row in rows) {
        if (!{'pending', 'confirmed'}.contains(row.jobState)) {
          throw const SquarePostStoreException('删除恢复状态损坏');
        }
        if (row.jobState == 'pending' ||
            await db.collection<social_store.Post>().getByPostId(row.postId) !=
                null) {
          result.add(row);
        }
      }
      return result;
    });
  }

  /// 读取已完成回灌检查点；损坏值 fail-closed，禁止把错误标记当作同步完成。
  Future<SquarePostSyncCheckpoint?> readSyncCheckpoint(String cidNumber) async {
    _validateCidNumber(cidNumber);
    return SocialIsar.instance.read((isar) async {
      final entity = await isar
          .collection<social_store.PostCursor>()
          .getByCidNumber(cidNumber);
      if (entity == null) return null;
      final postId = entity.postId;
      final createdAt = entity.publishedAt;
      final validEmpty = postId == null && createdAt == 0;
      final validPost =
          postId != null && postId.trim().isNotEmpty && createdAt > 0;
      if (!validEmpty && !validPost) {
        throw const SquarePostStoreException('本人副本同步检查点损坏');
      }
      return SquarePostSyncCheckpoint(postId: postId, publishedAt: createdAt);
    });
  }

  /// 仅在所有目标页成功落盘后更新检查点，不写设备时间。
  Future<void> writeSyncCheckpoint({
    required String cidNumber,
    required SquarePostSyncCheckpoint checkpoint,
  }) async {
    _validateCidNumber(cidNumber);
    final postId = checkpoint.postId;
    final validEmpty = postId == null && checkpoint.publishedAt == 0;
    final validPost =
        postId != null &&
        postId.trim().isNotEmpty &&
        checkpoint.publishedAt > 0;
    if (!validEmpty && !validPost) {
      throw const SquarePostStoreException('本人副本同步检查点不合法');
    }
    await SocialIsar.instance.writeTxn((isar) async {
      final entity =
          await isar.collection<social_store.PostCursor>().getByCidNumber(
            cidNumber,
          ) ??
          social_store.PostCursor();
      entity
        ..cidNumber = cidNumber
        ..postId = postId
        ..publishedAt = checkpoint.publishedAt;
      await isar.collection<social_store.PostCursor>().putByCidNumber(entity);
    });
  }

  Future<SquareLocalPost?> read({
    required String cidNumber,
    required String postId,
  }) async {
    _validateCidNumber(cidNumber);
    _requireNonEmpty(postId, 'post_id');
    return SocialIsar.instance.read((isar) async {
      final entity = await isar.collection<social_store.Post>().getByPostId(
        postId,
      );
      if (entity == null || entity.cidNumber != cidNumber) {
        return null;
      }
      return _fromEntity(entity);
    });
  }

  /// 按 Worker 时间倒序、post_id 倒序返回指定 CID 的全部本人副本。
  ///
  /// 排序不用设备时间；post_id 是同毫秒发布时的稳定次级排序键。
  Future<List<SquareLocalPost>> listByCid(String cidNumber) async {
    _validateCidNumber(cidNumber);
    return SocialIsar.instance.read((isar) async {
      final entities = await isar
          .collection<social_store.Post>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findAll();
      entities.sort((left, right) {
        final byCreatedAt = right.publishedAt.compareTo(left.publishedAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return right.postId.compareTo(left.postId);
      });
      return entities.map(_fromEntity).toList(growable: false);
    });
  }

  /// 仅在帖子确属指定 CID 时删除，禁止只凭全局 post_id 越过归属边界。
  @override
  Future<bool> delete({
    required String cidNumber,
    required String postId,
  }) async {
    _validateCidNumber(cidNumber);
    _requireNonEmpty(postId, 'post_id');
    final removed = await SocialIsar.instance.writeTxn((isar) async {
      final entity = await isar.collection<social_store.Post>().getByPostId(
        postId,
      );
      if (entity != null && entity.cidNumber != cidNumber) {
        return false;
      }
      await SquareMediaStore.removeContentInTransaction(
        isar,
        cidNumber: cidNumber,
        contentKind: 'post',
        contentId: postId,
      );
      return entity == null
          ? false
          : await isar.collection<social_store.Post>().delete(entity.rowId);
    });
    _notify(cidNumber);
    return removed;
  }

  /// 用户注销的本地清理入口；服务端硬删除成功后按永久 CID 一次删净。
  @override
  Future<int> deleteAllByCid(String cidNumber) async {
    _validateCidNumber(cidNumber);
    final deleted = await SocialIsar.instance.writeTxn((isar) async {
      final entities = await isar
          .collection<social_store.Post>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .findAll();
      for (final entity in entities) {
        await SquareMediaStore.removeContentInTransaction(
          isar,
          cidNumber: cidNumber,
          contentKind: 'post',
          contentId: entity.postId,
        );
      }
      await isar
          .collection<social_store.Erase>()
          .filter()
          .cidNumberEqualTo(cidNumber)
          .deleteAll();
      final deleted = entities.isEmpty
          ? 0
          : await isar.collection<social_store.Post>().deleteAll(
              entities.map((entity) => entity.rowId).toList(),
            );
      final checkpoint = await isar
          .collection<social_store.PostCursor>()
          .getByCidNumber(cidNumber);
      if (checkpoint != null) {
        await isar.collection<social_store.PostCursor>().delete(
          checkpoint.rowId,
        );
      }
      return deleted;
    });
    _notify(cidNumber);
    return deleted;
  }

  static SquareLocalPost validate(SquareLocalPost post) {
    _requireNonEmpty(post.postId, 'post_id');
    _validateCidNumber(post.cidNumber);
    if (!isAccountIdText(post.accountId)) {
      throw const SquarePostStoreException('account_id 格式不合法');
    }
    if (post.postCategory != 'normal' && post.postCategory != 'campaign') {
      throw const SquarePostStoreException('post_category 不合法');
    }
    if (post.postType != 'document' &&
        post.postType != 'article' &&
        post.postType != 'video') {
      throw const SquarePostStoreException('post_type 不合法');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(post.contentHash)) {
      throw const SquarePostStoreException('content_hash 格式不合法');
    }
    _requireNonEmpty(post.receiptId, 'receipt_id');
    if (post.chainBlock != null && post.chainBlock! < 0) {
      throw const SquarePostStoreException('chain_block 不合法');
    }
    if (post.publishedAt <= 0) {
      throw const SquarePostStoreException('published_at 不合法');
    }
    if (post.postState != publishedState) {
      throw const SquarePostStoreException('post_state 只允许 published');
    }

    final bytes = Uint8List.fromList(post.manifestBytes);
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != post.contentHash) {
      throw const SquarePostStoreException('manifest 与 content_hash 不一致');
    }

    final manifest = _decodeManifest(bytes);
    if (manifest['schema'] != manifestSchema) {
      throw const SquarePostStoreException('manifest schema 不合法');
    }
    if (manifest['cid_number'] != post.cidNumber) {
      throw const SquarePostStoreException('manifest cid_number 不一致');
    }
    if (manifest['post_type'] != post.postType) {
      throw const SquarePostStoreException('manifest post_type 不一致');
    }
    if (manifest['text'] is! String || manifest['media_items'] is! List) {
      throw const SquarePostStoreException('manifest 正文或媒体声明不完整');
    }

    return SquareLocalPost(
      postId: post.postId,
      cidNumber: post.cidNumber,
      accountId: post.accountId,
      postCategory: post.postCategory,
      postType: post.postType,
      manifestBytes: bytes,
      contentHash: post.contentHash,
      receiptId: post.receiptId,
      chainBlock: post.chainBlock,
      publishedAt: post.publishedAt,
      postState: post.postState,
    );
  }

  static Map<String, dynamic> _decodeManifest(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, dynamic>) {
        throw const SquarePostStoreException('manifest 必须是 JSON 对象');
      }
      return decoded;
    } on SquarePostStoreException {
      rethrow;
    } on Object {
      throw const SquarePostStoreException('manifest 不是合法 UTF-8 JSON');
    }
  }

  static SquareLocalPost _fromEntity(social_store.Post entity) {
    final post = SquareLocalPost(
      postId: entity.postId,
      cidNumber: entity.cidNumber,
      accountId: entity.accountId,
      postCategory: entity.postCategory,
      postType: entity.postType,
      manifestBytes: Uint8List.fromList(entity.manifestBytes),
      contentHash: entity.contentHash,
      receiptId: entity.receiptId,
      chainBlock: entity.chainBlock,
      publishedAt: entity.publishedAt,
      postState: entity.postState,
    );
    // 磁盘行也必须重新过完整性闸门；损坏数据不得以空白正文等方式静默降级。
    return validate(post);
  }

  /// `post_id` 对应链上不可变发布事实；重复同步只允许逐字段完全相同。
  ///
  /// 这既阻止另一 CID 复用同一编号覆盖本人内容，也禁止把“编辑”误实现为原地改正文；
  /// 广场编辑必须发布新 post_id，再按已确认删除流程清理旧帖。
  static void _assertSamePublishedFact(
    social_store.Post existing,
    SquareLocalPost incoming,
  ) {
    if (existing.cidNumber != incoming.cidNumber ||
        existing.accountId != incoming.accountId ||
        existing.postCategory != incoming.postCategory ||
        existing.postType != incoming.postType ||
        !_bytesEqual(existing.manifestBytes, incoming.manifestBytes) ||
        existing.contentHash != incoming.contentHash ||
        existing.receiptId != incoming.receiptId ||
        existing.chainBlock != incoming.chainBlock ||
        existing.publishedAt != incoming.publishedAt ||
        existing.postState != incoming.postState) {
      throw const SquarePostStoreException('post_id 已绑定另一条不可变发布事实');
    }
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static void _validateCidNumber(String cidNumber) {
    final bytes = utf8.encode(cidNumber);
    // CID 号码格式真源在 OnChina/链上；App 这里只复用跨端载荷的 1..32 UTF-8
    // 字节边界，不维护第二份号码正则。
    if (cidNumber.trim() != cidNumber || bytes.isEmpty || bytes.length > 32) {
      throw const SquarePostStoreException('cid_number 格式不合法');
    }
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty || value.trim() != value) {
      throw SquarePostStoreException('$field 不能为空');
    }
  }
}
