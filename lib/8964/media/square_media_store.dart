import 'package:citizenapp/storage/social_isar.dart'
    as social_store
    show Chunk, MediaLink, Media;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';

import 'package:citizenapp/storage/social_isar.dart';

/// 媒体描述不含字节；列表读取不会把视频载入内存。
class SquareStoredMedia {
  const SquareStoredMedia({
    required this.cidNumber,
    required this.mediaKind,
    required this.contentType,
    required this.byteSize,
    required this.bodyHash,
    this.isComplete = false,
  });

  final String cidNumber;
  final String mediaKind;
  final String contentType;
  final int byteSize;
  final String bodyHash;
  final bool isComplete;

  factory SquareStoredMedia._fromEntity(social_store.Media entity) {
    return SquareStoredMedia(
      cidNumber: entity.cidNumber,

      mediaKind: entity.mediaKind,
      contentType: entity.contentType,
      byteSize: entity.byteSize,
      bodyHash: entity.bodyHash,
      isComplete: entity.isComplete,
    );
  }
}

/// 一条内容的媒体槽位，CID 是关联归属，不从当前全局用户隐式推断。
class SquareMediaReference {
  const SquareMediaReference({
    required this.cidNumber,
    required this.bodyHash,
    required this.contentKind,
    required this.contentId,
    required this.mediaIndex,
    required this.mediaRole,
  });

  final String cidNumber;
  final String bodyHash;
  final String contentKind;
  final String contentId;
  final int mediaIndex;
  final String mediaRole;

  factory SquareMediaReference._fromEntity(social_store.MediaLink entity) {
    return SquareMediaReference(
      cidNumber: entity.cidNumber,
      bodyHash: entity.bodyHash,
      contentKind: entity.contentKind,
      contentId: entity.contentId,
      mediaIndex: entity.mediaIndex,
      mediaRole: entity.mediaRole,
    );
  }
}

class SquareMediaStoreException implements Exception {
  const SquareMediaStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 广场媒体字节的唯一数据库入口，不访问网络或平台播放器。
/// 文件来源以流导入，文件读取和哈希计算均在数据库事务之外。
///
/// 描述、分块、关联均属于 SocialIsar。每块单独提交，完整校验逐块读取；
/// 中断后仍保持未完成，只有 finish 成功后才允许读取和建立关联。
/// 同一 CID 的操作跨实例串行，避免校验期间删除重建、写入或关联造成竞态；
/// 哈希计算在数据库队列之外，不长期占用其它 Social 业务的事务。
class SquareMediaStore {
  const SquareMediaStore();

  static const int chunkSize = 1024 * 1024;
  static final Map<String, Future<void>> _tails = {};

  Future<SquareStoredMedia> saveFile({
    required String cidNumber,
    required String path,
    required String mediaKind,
    required String contentType,
    required int byteSize,
  }) async {
    final file = File(path);
    if (await file.length() != byteSize) _fail('媒体来源长度不匹配');
    final digest = (await sha256.bind(file.openRead()).first).toString();
    final media = SquareStoredMedia(
      cidNumber: cidNumber,

      mediaKind: mediaKind,
      contentType: contentType,
      byteSize: byteSize,
      bodyHash: digest,
    );
    await saveStream(media, file.openRead());
    return (await get(cidNumber: cidNumber, bodyHash: digest))!;
  }

  /// 将任意输入流归整为固定数据库块；不把整个视频载入内存。
  /// 来源必须可提供已核实的长度与哈希，短流、长流和变更中的来源都无法完成。
  Future<void> saveStream(
    SquareStoredMedia media,
    Stream<List<int>> stream,
  ) async {
    await begin(media);
    var block = Uint8List(chunkSize);
    var used = 0;
    var index = 0;
    var total = 0;
    await for (final bytes in stream) {
      total += bytes.length;
      if (total > media.byteSize) _fail('媒体来源长度发生变化');
      var offset = 0;
      while (offset < bytes.length) {
        final take = math.min(chunkSize - used, bytes.length - offset);
        block.setRange(used, used + take, bytes, offset);
        used += take;
        offset += take;
        if (used == chunkSize) {
          await writeChunk(
            cidNumber: media.cidNumber,
            bodyHash: media.bodyHash,
            partIndex: index++,
            bytes: block,
          );
          block = Uint8List(chunkSize);
          used = 0;
        }
      }
    }
    if (total != media.byteSize) _fail('媒体来源长度发生变化');
    if (used > 0) {
      await writeChunk(
        cidNumber: media.cidNumber,
        bodyHash: media.bodyHash,
        partIndex: index,
        bytes: Uint8List.sublistView(block, 0, used),
      );
    }
    await finish(cidNumber: media.cidNumber, bodyHash: media.bodyHash);
  }

  /// 帖子/草稿事务的同域组成操作：调用方必须已处于 SocialIsar 写事务。
  /// 先验证全部新引用再替换，失败由外层事务整体回滚，不允许先删草稿再补引用。
  static Future<void> replaceReferencesInTransaction(
    Isar db, {
    required String cidNumber,
    required String contentKind,
    required String contentId,
    required List<SquareMediaReference> references,
  }) async {
    _validateContent(contentKind, contentId);
    final slots = <(int, String)>{};
    for (final ref in references) {
      _validateReference(ref);
      if (ref.cidNumber != cidNumber ||
          ref.contentKind != contentKind ||
          ref.contentId != contentId ||
          !slots.add((ref.mediaIndex, ref.mediaRole))) {
        _fail('媒体关联归属或槽位重复');
      }
      final media = await _requireMedia(db, cidNumber, ref.bodyHash);
      if (!media.isComplete) _fail('未完成媒体不能关联内容');
    }
    final previous = await db
        .collection<social_store.MediaLink>()
        .where()
        .contentIdCidNumberContentKindEqualTo(contentId, cidNumber, contentKind)
        .findAll();
    await db
        .collection<social_store.MediaLink>()
        .where()
        .contentIdCidNumberContentKindEqualTo(contentId, cidNumber, contentKind)
        .deleteAll();
    for (final ref in references) {
      await db.collection<social_store.MediaLink>().put(
        social_store.MediaLink()
          ..cidNumber = cidNumber
          ..bodyHash = ref.bodyHash
          ..contentKind = contentKind
          ..contentId = contentId
          ..mediaIndex = ref.mediaIndex
          ..mediaRole = ref.mediaRole,
      );
    }
    final retained = references.map((r) => r.bodyHash).toSet();
    for (final id
        in previous.map((r) => r.bodyHash).toSet().difference(retained)) {
      await _deleteIfUnreferenced(db, cidNumber, id);
    }
  }

  /// 同一内容删除/成功发布收尾使用；引用已转给帖子时其字节不会被误删。
  static Future<void> removeContentInTransaction(
    Isar db, {
    required String cidNumber,
    required String contentKind,
    required String contentId,
  }) async {
    _validateContent(contentKind, contentId);
    final refs = await db
        .collection<social_store.MediaLink>()
        .where()
        .contentIdCidNumberContentKindEqualTo(contentId, cidNumber, contentKind)
        .findAll();
    await db.collection<social_store.MediaLink>().deleteAll(
      refs.map((r) => r.rowId).toList(),
    );
    for (final id in refs.map((r) => r.bodyHash).toSet()) {
      await _deleteIfUnreferenced(db, cidNumber, id);
    }
  }

  static Future<void> _deleteIfUnreferenced(
    Isar db,
    String cidNumber,
    String id,
  ) async {
    final count = await db
        .collection<social_store.MediaLink>()
        .where()
        .bodyHashCidNumberEqualTo(id, cidNumber)
        .count();
    if (count != 0) return;
    await db
        .collection<social_store.Chunk>()
        .where()
        .cidNumberBodyHashEqualToAnyPartIndex(cidNumber, id)
        .deleteAll();
    await db.collection<social_store.Media>().deleteByCidNumberBodyHash(
      cidNumber,
      id,
    );
  }

  /// 建立不可变描述；重试只接受完全相同的描述，不能由调用方标记完成。
  Future<void> begin(SquareStoredMedia media) async {
    _validateMedia(media);
    if (media.isComplete) _fail('不能跳过媒体完整性校验');
    return _serial(
      media.cidNumber,
      () => SocialIsar.instance.writeTxn((db) async {
        final existing = await db
            .collection<social_store.Media>()
            .getByCidNumberBodyHash(media.cidNumber, media.bodyHash);
        if (existing != null) {
          if (existing.mediaKind != media.mediaKind ||
              existing.contentType != media.contentType ||
              existing.byteSize != media.byteSize) {
            _fail('媒体标识已对应不同内容');
          }
          return;
        }
        await db.collection<social_store.Media>().put(
          social_store.Media()
            ..cidNumber = media.cidNumber
            ..mediaKind = media.mediaKind
            ..contentType = media.contentType
            ..byteSize = media.byteSize
            ..bodyHash = media.bodyHash,
        );
      }),
    );
  }

  /// 写入一块；输入先复制，调用方之后修改缓冲区不能改变待保存内容。
  /// 完全相同的块可安全重试，已存在但不同的字节必须拒绝。
  Future<void> writeChunk({
    required String cidNumber,
    required String bodyHash,
    required int partIndex,
    required Uint8List bytes,
  }) async {
    _validateId(bodyHash);
    if (partIndex < 0 || bytes.isEmpty || bytes.length > chunkSize) {
      _fail('媒体分块范围不合法');
    }
    final owned = Uint8List.fromList(bytes);
    final digest = sha256.convert(owned).toString();
    return _serial(
      cidNumber,
      () => SocialIsar.instance.writeTxn((db) async {
        final media = await _requireMedia(db, cidNumber, bodyHash);
        if (owned.length != _chunkLength(media.byteSize, partIndex)) {
          _fail('媒体分块长度不匹配');
        }
        final existing = await db
            .collection<social_store.Chunk>()
            .getByCidNumberBodyHashPartIndex(cidNumber, bodyHash, partIndex);
        if (existing != null) {
          if (existing.partHash != digest ||
              !_sameBytes(existing.partBytes, owned)) {
            _fail('媒体分块重试内容不一致');
          }
          return;
        }
        if (media.isComplete) _fail('已完成媒体禁止补写分块');
        await db.collection<social_store.Chunk>().put(
          social_store.Chunk()
            ..cidNumber = cidNumber
            ..bodyHash = bodyHash
            ..partIndex = partIndex
            ..partBytes = owned
            ..partHash = digest,
        );
      }),
    );
  }

  /// 不拼接整个视频；逐块核验连续序号、每块长度、块哈希和整体 SHA-256。
  /// 任一步失败都不推进完成状态。重复完成仍重新校验，不信任旧标记。
  Future<void> finish({required String cidNumber, required String bodyHash}) {
    return _serial(cidNumber, () async {
      final media = await SocialIsar.instance.read(
        (db) => _requireMedia(db, cidNumber, bodyHash),
      );
      final count = _chunkCount(media.byteSize);
      final storedCount = await SocialIsar.instance.read(
        (db) => db
            .collection<social_store.Chunk>()
            .where()
            .cidNumberBodyHashEqualToAnyPartIndex(cidNumber, bodyHash)
            .count(),
      );
      if (storedCount != count) _fail('媒体分块不完整');
      final result = _DigestSink();
      final sink = sha256.startChunkedConversion(result);
      try {
        for (var index = 0; index < count; index++) {
          sink.add(await _readChunk(media, index));
        }
      } finally {
        sink.close();
      }
      if (result.digest?.toString() != media.bodyHash) {
        _fail('媒体整体哈希不匹配');
      }
      await SocialIsar.instance.writeTxn((db) async {
        final current = await _requireMedia(db, cidNumber, bodyHash);
        if (current.rowId != media.rowId ||
            current.bodyHash != media.bodyHash) {
          _fail('媒体在校验期间发生变化');
        }
        current.isComplete = true;
        await db.collection<social_store.Media>().put(current);
      });
    });
  }

  Future<SquareStoredMedia?> get({
    required String cidNumber,
    required String bodyHash,
  }) {
    _validateId(bodyHash);
    return _serial(
      cidNumber,
      () => SocialIsar.instance.read((db) async {
        final media = await db
            .collection<social_store.Media>()
            .getByCidNumberBodyHash(cidNumber, bodyHash);
        return media == null ? null : SquareStoredMedia._fromEntity(media);
      }),
    );
  }

  /// 仅列出指定用户的描述，包含未完成状态供显式恢复；不读取分块集合。
  Future<List<SquareStoredMedia>> listByCid(String cidNumber) {
    return _serial(
      cidNumber,
      () => SocialIsar.instance.read((db) async {
        final rows = await db
            .collection<social_store.Media>()
            .where()
            .cidNumberEqualToAnyBodyHash(cidNumber)
            .findAll();
        return rows.map(SquareStoredMedia._fromEntity).toList(growable: false);
      }),
    );
  }

  /// 精确范围读取，单次最多 1 MiB，可跨块；播放器按需继续请求下一段。
  /// 不截短越界请求；EOF 仅允许零长度读取。缺块或块损坏必须报错。
  Future<Uint8List> readRange({
    required String cidNumber,
    required String bodyHash,
    required int offset,
    required int length,
  }) {
    return _serial(cidNumber, () async {
      if (offset < 0 || length < 0 || length > chunkSize) {
        _fail('媒体读取范围不合法');
      }
      final media = await SocialIsar.instance.read(
        (db) => _requireMedia(db, cidNumber, bodyHash),
      );
      if (!media.isComplete) _fail('媒体尚未完整保存');
      if (offset > media.byteSize || length > media.byteSize - offset) {
        _fail('媒体读取范围超出长度');
      }
      final bytes = Uint8List(length);
      var copied = 0;
      while (copied < length) {
        final position = offset + copied;
        final chunk = await _readChunk(media, position ~/ chunkSize);
        final start = position % chunkSize;
        final take = math.min(length - copied, chunk.length - start);
        bytes.setRange(copied, copied + take, chunk, start);
        copied += take;
      }
      return bytes;
    });
  }

  /// 原引擎复合索引最多三列；五个自然字段在同一写事务内精确核对。
  static Future<social_store.MediaLink?> _slot(
    Isar db,
    SquareMediaReference reference,
  ) async {
    final rows = await db
        .collection<social_store.MediaLink>()
        .where()
        .contentIdCidNumberContentKindEqualTo(
          reference.contentId,
          reference.cidNumber,
          reference.contentKind,
        )
        .filter()
        .mediaIndexEqualTo(reference.mediaIndex)
        .mediaRoleEqualTo(reference.mediaRole)
        .limit(2)
        .findAll();
    if (rows.length > 1) _fail('媒体槽位自然字段重复');
    return rows.singleOrNull;
  }

  /// 一个槽位只能关联一份已完成媒体；更换媒体需先显式移除旧关联。
  Future<void> attach(SquareMediaReference reference) async {
    _validateReference(reference);
    return _serial(
      reference.cidNumber,
      () => SocialIsar.instance.writeTxn((db) async {
        final media = await _requireMedia(
          db,
          reference.cidNumber,
          reference.bodyHash,
        );
        if (!media.isComplete) _fail('未完成媒体不能关联内容');
        final existing = await _slot(db, reference);
        if (existing != null) {
          if (existing.bodyHash != reference.bodyHash) {
            _fail('媒体槽位已有不同关联');
          }
          return;
        }
        await db.collection<social_store.MediaLink>().put(
          social_store.MediaLink()
            ..cidNumber = reference.cidNumber
            ..bodyHash = reference.bodyHash
            ..contentKind = reference.contentKind
            ..contentId = reference.contentId
            ..mediaIndex = reference.mediaIndex
            ..mediaRole = reference.mediaRole,
        );
      }),
    );
  }

  Future<List<SquareMediaReference>> referencesForContent({
    required String cidNumber,
    required String contentKind,
    required String contentId,
  }) {
    _validateContent(contentKind, contentId);
    return _serial(
      cidNumber,
      () => SocialIsar.instance.read((db) async {
        final rows = await db
            .collection<social_store.MediaLink>()
            .where()
            .contentIdCidNumberContentKindEqualTo(
              contentId,
              cidNumber,
              contentKind,
            )
            .sortByMediaIndex()
            .thenByMediaRole()
            .findAll();
        return rows
            .map(SquareMediaReference._fromEntity)
            .toList(growable: false);
      }),
    );
  }

  /// 删除前匹配媒体标识，避免迟到的删除请求移除另一个媒体的新关联。
  Future<bool> detach(SquareMediaReference reference) async {
    _validateReference(reference);
    return _serial(
      reference.cidNumber,
      () => SocialIsar.instance.writeTxn((db) async {
        final existing = await _slot(db, reference);
        if (existing == null || existing.bodyHash != reference.bodyHash) {
          return false;
        }
        return db.collection<social_store.MediaLink>().delete(existing.rowId);
      }),
    );
  }

  /// 显式删除无引用媒体（包含未完成媒体）。引用检查与删除在同一事务；
  /// 删引用本身不会触发此操作，不因打开页面、数量上限或时间自动淘汰。
  Future<bool> deleteUnused({
    required String cidNumber,
    required String bodyHash,
  }) {
    _validateId(bodyHash);
    return _serial(
      cidNumber,
      () => SocialIsar.instance.writeTxn((db) async {
        final media = await db
            .collection<social_store.Media>()
            .getByCidNumberBodyHash(cidNumber, bodyHash);
        if (media == null) return false;
        final references = await db
            .collection<social_store.MediaLink>()
            .where()
            .bodyHashCidNumberEqualTo(bodyHash, cidNumber)
            .count();
        if (references != 0) _fail('媒体仍被内容引用');
        await db
            .collection<social_store.Chunk>()
            .where()
            .cidNumberBodyHashEqualToAnyPartIndex(cidNumber, bodyHash)
            .deleteAll();
        return db.collection<social_store.Media>().delete(media.rowId);
      }),
    );
  }

  static Future<social_store.Media> _requireMedia(
    Isar db,
    String cidNumber,
    String bodyHash,
  ) async {
    _validateId(bodyHash);
    final media = await db
        .collection<social_store.Media>()
        .getByCidNumberBodyHash(cidNumber, bodyHash);
    if (media == null) _fail('当前用户没有此媒体');
    return media;
  }

  static Future<List<int>> _readChunk(
    social_store.Media media,
    int index,
  ) async {
    final chunk = await SocialIsar.instance.read(
      (db) =>
          db.collection<social_store.Chunk>().getByCidNumberBodyHashPartIndex(
            media.cidNumber,
            media.bodyHash,
            index,
          ),
    );
    if (chunk == null ||
        chunk.partBytes.length != _chunkLength(media.byteSize, index) ||
        sha256.convert(chunk.partBytes).toString() != chunk.partHash) {
      _fail('媒体分块缺失或损坏');
    }
    return chunk.partBytes;
  }

  static int _chunkCount(int size) => (size - 1) ~/ chunkSize + 1;

  static int _chunkLength(int size, int index) {
    if (index < 0 || index >= _chunkCount(size)) _fail('媒体分块序号越界');
    return math.min(chunkSize, size - index * chunkSize);
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static void _validateMedia(SquareStoredMedia media) {
    _validateId(media.bodyHash);
    if (!{'image', 'video'}.contains(media.mediaKind) ||
        !media.contentType.startsWith('${media.mediaKind}/') ||
        media.contentType.trim() != media.contentType ||
        media.contentType.length > 255 ||
        media.contentType.length <= media.mediaKind.length + 1 ||
        media.byteSize <= 0 ||
        media.byteSize > 0x1fffffffffffff ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(media.bodyHash)) {
      _fail('媒体描述不合法');
    }
  }

  static void _validateContent(String kind, String id) {
    _validateId(id);
    if (!{'draft', 'post', 'publication'}.contains(kind)) _fail('媒体关联内容类型不合法');
  }

  static void _validateReference(SquareMediaReference reference) {
    _validateId(reference.bodyHash);
    _validateContent(reference.contentKind, reference.contentId);
    if (reference.mediaIndex < 0 ||
        reference.mediaIndex > 0x1fffffffffffff ||
        !{'main', 'thumbnail', 'cover'}.contains(reference.mediaRole)) {
      _fail('媒体槽位不合法');
    }
  }

  static void _validateId(String value) {
    if (value.trim().isEmpty ||
        value.trim() != value ||
        utf8.encode(value).length > 512) {
      _fail('媒体或内容标识不合法');
    }
  }

  static Future<T> _serial<T>(String cid, Future<T> Function() action) async {
    // 复用现有 CID 载荷的字节边界，不在 App 另建号码格式或链上授权规则。
    if (cid.trim() != cid || cid.isEmpty || utf8.encode(cid).length > 32) {
      _fail('cid_number 格式不合法');
    }
    final previous = _tails[cid] ?? Future<void>.value();
    final result = previous.then((_) => action());
    // 失败只返回给本次调用者，不阻塞同一用户后续的显式恢复。
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[cid] = tail;
    try {
      return await result;
    } finally {
      if (identical(_tails[cid], tail)) _tails.remove(cid);
    }
  }

  static Never _fail(String message) =>
      throw SquareMediaStoreException(message);
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest value) => digest = value;

  @override
  void close() {}
}
