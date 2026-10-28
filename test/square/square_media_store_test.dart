import 'package:citizenapp/storage/social_isar.dart'
    as social_store
    show Chunk, CleanupSchema, PostCursorSchema, Draft, DraftSchema, PostSchema;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:citizenapp/8964/media/square_media_store.dart';
import 'package:citizenapp/storage/isar_core_bootstrap.dart';
import 'package:citizenapp/storage/social_isar.dart';

import '../support/isar_test_env.dart';

const _cidA = 'R5-K3P1C1-N9-D4';
const _cidB = 'R5-K3P1C1-N8-D5';
const _store = SquareMediaStore();
const _chunkSize = SquareMediaStore.chunkSize;
final _storeError = isA<SquareMediaStoreException>();

// 全部使用合成字节与虚构 CID，不读取设备媒体或用户数据。
Uint8List _bytes(int size) => Uint8List.fromList(
  List<int>.generate(size, (index) => (index * 17 + 3) % 251),
);

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

SquareStoredMedia _media(
  Uint8List bytes, {
  String cid = _cidA,
  String? digest,
}) => SquareStoredMedia(
  cidNumber: cid,
  mediaKind: 'image',
  contentType: 'image/webp',
  byteSize: bytes.length,
  bodyHash: digest ?? _hash(bytes),
);

SquareMediaReference _reference({
  required String bodyHash,
  String cid = _cidA,
  String contentKind = 'post',
  String contentId = 'post-a',
  int index = 0,
  String role = 'main',
}) => SquareMediaReference(
  cidNumber: cid,
  bodyHash: bodyHash,
  contentKind: contentKind,
  contentId: contentId,
  mediaIndex: index,
  mediaRole: role,
);

Future<void> _save(Uint8List bytes, {String cid = _cidA}) async {
  final bodyHash = _hash(bytes);
  await _store.begin(_media(bytes, cid: cid));
  for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
    await _store.writeChunk(
      cidNumber: cid,
      bodyHash: bodyHash,
      partIndex: offset ~/ _chunkSize,
      bytes: Uint8List.sublistView(
        bytes,
        offset,
        math.min(offset + _chunkSize, bytes.length),
      ),
    );
  }
  await _store.finish(cidNumber: cid, bodyHash: bodyHash);
}

Future<void> _changeChunk(
  String bodyHash,
  Future<void> Function(Isar, social_store.Chunk) change,
) {
  return SocialIsar.instance.writeTxn((db) async {
    final chunk = await db
        .collection<social_store.Chunk>()
        .getByCidNumberBodyHashPartIndex(_cidA, bodyHash, 0);
    await change(db, chunk!);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('媒体关联组合进业务事务时，后续失败回滚引用替换和字节回收', () async {
    final bodyHash = _hash(_bytes(3));
    final bodyHashB = _hash(_bytes(4));
    await _save(_bytes(3));
    await _save(_bytes(4));
    await _store.attach(_reference(bodyHash: bodyHash, contentKind: 'draft'));
    await expectLater(
      SocialIsar.instance.writeTxn((db) async {
        await SquareMediaStore.replaceReferencesInTransaction(
          db,
          cidNumber: _cidA,
          contentKind: 'draft',
          contentId: 'post-a',
          references: [_reference(bodyHash: bodyHashB, contentKind: 'draft')],
        );
        throw StateError('模拟同一事务后续业务保存失败');
      }),
      throwsStateError,
    );
    final refs = await _store.referencesForContent(
      cidNumber: _cidA,
      contentKind: 'draft',
      contentId: 'post-a',
    );
    expect(refs.single.bodyHash, bodyHash);
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 3,
      ),
      _bytes(3),
    );
  });

  test('媒体流按固定块入库，输入分片不必与数据库块对齐', () async {
    final bodyHash = _hash(_bytes(_chunkSize + 11));
    final bytes = _bytes(_chunkSize + 11);
    await _store.saveStream(
      _media(bytes),
      Stream.fromIterable([
        bytes.sublist(0, 3),
        bytes.sublist(3, 900),
        bytes.sublist(900),
      ]),
    );
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: _chunkSize - 2,
        length: 13,
      ),
      bytes.sublist(_chunkSize - 2),
    );
  });

  test('短流或超长流不能标记完成，已有媒体字节保持不变', () async {
    final bodyHash = _hash(_bytes(5));
    for (final size in [4, 6]) {
      final descriptor = _media(_bytes(5));
      await expectLater(
        _store.saveStream(descriptor, Stream.value(_bytes(size))),
        throwsA(_storeError),
      );
      expect(
        (await _store.get(
          cidNumber: _cidA,
          bodyHash: descriptor.bodyHash,
        ))!.isComplete,
        isFalse,
      );
    }
    await _save(_bytes(5));
    await expectLater(
      _store.saveStream(_media(_bytes(5)), Stream.value(Uint8List(5))),
      throwsA(_storeError),
    );
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 5,
      ),
      _bytes(5),
    );
  });

  test('同名Social库补充媒体集合后保留已有草稿事实', () async {
    final old = await Isar.open(
      [
        social_store.PostSchema,
        social_store.DraftSchema,
        social_store.PostCursorSchema,
        social_store.CleanupSchema,
      ],
      name: 'citizenapp_social',
      directory: await IsarCoreBootstrap.resolveDirectory(),
    );
    await old.writeTxn(() async {
      await old.collection<social_store.Draft>().put(
        social_store.Draft()
          ..cidNumber = _cidA
          ..draftId = 'draft-old'
          ..postType = 'document'
          ..text = '未发布草稿必须保留'
          ..mediaData = '[]'
          ..updatedAt = 123,
      );
    });
    await old.close();
    await _save(_bytes(5));
    final draft = await SocialIsar.instance.read(
      (db) => db.collection<social_store.Draft>().getByCidNumberDraftId(
        _cidA,
        'draft-old',
      ),
    );
    expect(draft!.text, '未发布草稿必须保留');
    expect(draft.cidNumber, _cidA);
    expect(draft.updatedAt, 123);
  });

  test('描述、实际字节和关联分别持久化；跨块、尾块及EOF读取准确', () async {
    final bodyHash = _hash(_bytes(_chunkSize + 37));
    final bytes = _bytes(_chunkSize + 37);
    await _save(bytes);
    final reference = _reference(bodyHash: bodyHash);
    await _store.attach(reference);

    // 关闭但不删除数据库，再以新的入口实例读取，排除仅存在于内存的实现。
    await (await SocialIsar.instance.db()).close();
    const reopened = SquareMediaStore();
    final media = await reopened.get(cidNumber: _cidA, bodyHash: bodyHash);
    expect(media!.isComplete, isTrue);
    expect(media.byteSize, bytes.length);
    expect(media.bodyHash, sha256.convert(bytes).toString());
    expect(
      await reopened.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: _chunkSize,
      ),
      bytes.sublist(0, _chunkSize),
    );
    expect(
      await reopened.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: _chunkSize - 5,
        length: 42,
      ),
      bytes.sublist(_chunkSize - 5),
    );
    expect(
      await reopened.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: bytes.length,
        length: 0,
      ),
      isEmpty,
    );
    expect(
      (await reopened.referencesForContent(
        cidNumber: _cidA,
        contentKind: 'post',
        contentId: 'post-a',
      )).single.bodyHash,
      reference.bodyHash,
    );
    expect((await reopened.listByCid(_cidA)).single.bodyHash, bodyHash);
  });

  test('整块整数长度不要求空尾块，单字节媒体同样校验', () async {
    for (final size in [1, _chunkSize, _chunkSize * 2]) {
      await _save(_bytes(size));
      expect(
        (await _store.get(
          cidNumber: _cidA,
          bodyHash: _hash(_bytes(size)),
        ))!.isComplete,
        isTrue,
      );
    }
  });

  test('写入中断后不可读不可关联，重开数据库后能显式续写', () async {
    final bodyHash = _hash(_bytes(_chunkSize + 7));
    final bytes = _bytes(_chunkSize + 7);
    await _store.begin(_media(bytes));
    await _store.writeChunk(
      cidNumber: _cidA,
      bodyHash: bodyHash,
      partIndex: 0,
      bytes: Uint8List.sublistView(bytes, 0, _chunkSize),
    );
    await (await SocialIsar.instance.db()).close();
    await expectLater(
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    await expectLater(
      _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 1,
      ),
      throwsA(_storeError),
    );
    await expectLater(
      _store.attach(_reference(bodyHash: bodyHash)),
      throwsA(_storeError),
    );
    expect((await _store.listByCid(_cidA)).single.isComplete, isFalse);
    await _save(bytes);
    expect(
      (await _store.get(cidNumber: _cidA, bodyHash: bodyHash))!.isComplete,
      isTrue,
    );
  });

  test('重复块、描述和完成幂等，不允许覆盖不同内容', () async {
    final bodyHash = _hash(_bytes(23));
    final bytes = _bytes(23);
    await _save(bytes);
    await _save(bytes);
    await expectLater(
      _store.begin(_media(_bytes(24), digest: bodyHash)),
      throwsA(_storeError),
    );
    await expectLater(
      _store.writeChunk(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        partIndex: 0,
        bytes: Uint8List(23),
      ),
      throwsA(_storeError),
    );
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 23,
      ),
      bytes,
    );
  });

  test('乱序分块最终按序校验，排队前复制调用方缓冲区', () async {
    final bodyHash = _hash(_bytes(_chunkSize + 2));
    final bytes = _bytes(_chunkSize + 2);
    await _store.begin(_media(bytes));
    final input = Uint8List.fromList(bytes.sublist(_chunkSize));
    final writing = _store.writeChunk(
      cidNumber: _cidA,
      bodyHash: bodyHash,
      partIndex: 1,
      bytes: input,
    );
    input.fillRange(0, input.length, 0);
    await writing;
    await _store.writeChunk(
      cidNumber: _cidA,
      bodyHash: bodyHash,
      partIndex: 0,
      bytes: Uint8List.sublistView(bytes, 0, _chunkSize),
    );
    await _store.finish(cidNumber: _cidA, bodyHash: bodyHash);
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: _chunkSize,
        length: 2,
      ),
      bytes.sublist(_chunkSize),
    );
  });

  test('完整长度但整体哈希错误仍不可标记完成，失败后队列可继续', () async {
    final bodyHash = _hash([0]);
    final bytes = _bytes(19);
    await _store.begin(_media(bytes, digest: sha256.convert([0]).toString()));
    await _store.writeChunk(
      cidNumber: _cidA,
      bodyHash: bodyHash,
      partIndex: 0,
      bytes: bytes,
    );
    await expectLater(
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    expect(
      (await _store.get(cidNumber: _cidA, bodyHash: bodyHash))!.isComplete,
      isFalse,
    );
    expect(
      await _store.deleteUnused(cidNumber: _cidA, bodyHash: bodyHash),
      isTrue,
    );
    await _save(bytes);
  });

  test('缺失、额外、损坏分块均拒绝完成', () async {
    final bodyHash = _hash(_bytes(11));
    final bytes = _bytes(11);
    await _store.begin(_media(bytes));
    await expectLater(
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    await _store.writeChunk(
      cidNumber: _cidA,
      bodyHash: bodyHash,
      partIndex: 0,
      bytes: bytes,
    );
    await _changeChunk(bodyHash, (db, chunk) async {
      chunk.partBytes = [0, ...chunk.partBytes.skip(1)];
      await db.collection<social_store.Chunk>().put(chunk);
    });
    await expectLater(
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    await _changeChunk(bodyHash, (db, chunk) async {
      chunk.partBytes = bytes;
      await db.collection<social_store.Chunk>().put(chunk);
      await db.collection<social_store.Chunk>().put(
        social_store.Chunk()
          ..cidNumber = _cidA
          ..bodyHash = bodyHash
          ..partIndex = 1
          ..partBytes = [1]
          ..partHash = sha256.convert([1]).toString(),
      );
    });
    await expectLater(
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    expect(
      (await _store.get(cidNumber: _cidA, bodyHash: bodyHash))!.isComplete,
      isFalse,
    );
  });

  test('完成后磁盘分块损坏或缺失，范围读取明确失败', () async {
    final bodyHash = _hash(_bytes(13));
    await _save(_bytes(13));
    await _changeChunk(bodyHash, (db, chunk) async {
      chunk.partBytes = List<int>.filled(13, 0);
      await db.collection<social_store.Chunk>().put(chunk);
    });
    await expectLater(
      _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 1,
      ),
      throwsA(_storeError),
    );
    await _changeChunk(bodyHash, (db, chunk) async {
      await db.collection<social_store.Chunk>().delete(chunk.rowId);
    });
    await expectLater(
      _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 1,
      ),
      throwsA(_storeError),
    );
  });

  test('分块序号、零块、超长块及不准确尾块全部拒绝', () async {
    final bodyHash = _hash(_bytes(_chunkSize + 7));
    await _store.begin(_media(_bytes(_chunkSize + 7)));
    for (final input in [
      (-1, _bytes(1)),
      (2, _bytes(1)),
      (0, Uint8List(0)),
      (0, _bytes(_chunkSize + 1)),
      (0, _bytes(7)),
      (1, _bytes(6)),
      (1, _bytes(8)),
    ]) {
      await expectLater(
        _store.writeChunk(
          cidNumber: _cidA,
          bodyHash: bodyHash,
          partIndex: input.$1,
          bytes: input.$2,
        ),
        throwsA(_storeError),
      );
    }
  });

  test('范围不能负数、越界或一次加载超过1MiB', () async {
    final bodyHash = _hash(_bytes(9));
    await _save(_bytes(9));
    for (final range in [
      (-1, 1),
      (0, -1),
      (8, 2),
      (10, 0),
      (0, _chunkSize + 1),
    ]) {
      await expectLater(
        _store.readRange(
          cidNumber: _cidA,
          bodyHash: bodyHash,
          offset: range.$1,
          length: range.$2,
        ),
        throwsA(_storeError),
      );
    }
  });

  test('同摘要媒体按CID完全隔离，跨用户不能读写、关联或删除', () async {
    final bodyHash = _hash(_bytes(9));
    final bytesA = _bytes(9);
    final bytesB = _bytes(9);
    await _save(bytesA);
    expect(await _store.get(cidNumber: _cidB, bodyHash: bodyHash), isNull);
    expect(await _store.listByCid(_cidB), isEmpty);
    await expectLater(
      _store.readRange(
        cidNumber: _cidB,
        bodyHash: bodyHash,
        offset: 0,
        length: 1,
      ),
      throwsA(_storeError),
    );
    await expectLater(
      _store.writeChunk(
        cidNumber: _cidB,
        bodyHash: bodyHash,
        partIndex: 0,
        bytes: bytesA,
      ),
      throwsA(_storeError),
    );
    await expectLater(
      _store.attach(_reference(bodyHash: bodyHash, cid: _cidB)),
      throwsA(_storeError),
    );
    expect(
      await _store.deleteUnused(cidNumber: _cidB, bodyHash: bodyHash),
      isFalse,
    );
    expect(
      await _store.detach(_reference(bodyHash: bodyHash, cid: _cidB)),
      isFalse,
    );
    await _save(bytesB, cid: _cidB);
    await _store.attach(_reference(bodyHash: bodyHash));
    await _store.attach(_reference(bodyHash: bodyHash, cid: _cidB));
    expect(
      await _store.detach(_reference(bodyHash: bodyHash, cid: _cidB)),
      isTrue,
    );
    expect(
      await _store.deleteUnused(cidNumber: _cidB, bodyHash: bodyHash),
      isTrue,
    );
    expect(
      await _store.readRange(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        offset: 0,
        length: 9,
      ),
      bytesA,
    );
    expect(
      await _store.referencesForContent(
        cidNumber: _cidA,
        contentKind: 'post',
        contentId: 'post-a',
      ),
      hasLength(1),
    );
  });

  test('关联分类型、顺序和用途；移除一个引用不删除共享媒体', () async {
    final bodyHash = _hash(_bytes(17));
    await _save(_bytes(17));
    final refs = [
      _reference(bodyHash: bodyHash, contentKind: 'draft'),
      _reference(bodyHash: bodyHash, index: 2),
      _reference(bodyHash: bodyHash, index: 1, role: 'cover'),
      _reference(bodyHash: bodyHash, index: 1),
    ];
    for (final reference in refs) {
      await _store.attach(reference);
      await _store.attach(reference);
    }
    final post = await _store.referencesForContent(
      cidNumber: _cidA,
      contentKind: 'post',
      contentId: 'post-a',
    );
    expect(post.map((r) => r.mediaIndex), [1, 1, 2]);
    expect(post.take(2).map((r) => r.mediaRole), ['cover', 'main']);
    expect(await _store.detach(refs.first), isTrue);
    expect(await _store.detach(refs.first), isFalse);
    await expectLater(
      _store.deleteUnused(cidNumber: _cidA, bodyHash: bodyHash),
      throwsA(_storeError),
    );
    for (final reference in refs.skip(1)) {
      await _store.detach(reference);
    }
    expect(
      await _store.deleteUnused(cidNumber: _cidA, bodyHash: bodyHash),
      isTrue,
    );
    expect(await _store.get(cidNumber: _cidA, bodyHash: bodyHash), isNull);
    expect(
      await SocialIsar.instance.read(
        (db) => db.collection<social_store.Chunk>().count(),
      ),
      0,
    );
  });

  test('槽位冲突和迟到的解绑不能覆盖或移除新内容', () async {
    final bodyHash = _hash(_bytes(17));
    final bodyHashB = _hash(_bytes(18));
    await _save(_bytes(17));
    await _save(_bytes(18));
    await _store.attach(_reference(bodyHash: bodyHash));
    await expectLater(
      _store.attach(_reference(bodyHash: bodyHashB)),
      throwsA(_storeError),
    );
    await _store.detach(_reference(bodyHash: bodyHash));
    await _store.attach(_reference(bodyHash: bodyHashB));
    expect(await _store.detach(_reference(bodyHash: bodyHash)), isFalse);
    expect(
      (await _store.referencesForContent(
        cidNumber: _cidA,
        contentKind: 'post',
        contentId: 'post-a',
      )).single.bodyHash,
      bodyHashB,
    );
  });

  test('多个入口并发重试不会重复建行，绑定先于删除时删除必须失败', () async {
    final bodyHash = _hash(_bytes(23));
    final bytes = _bytes(23);
    const other = SquareMediaStore();
    await Future.wait([
      _store.begin(_media(bytes)),
      other.begin(_media(bytes)),
    ]);
    await Future.wait([
      _store.writeChunk(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        partIndex: 0,
        bytes: bytes,
      ),
      other.writeChunk(
        cidNumber: _cidA,
        bodyHash: bodyHash,
        partIndex: 0,
        bytes: bytes,
      ),
    ]);
    await Future.wait([
      _store.finish(cidNumber: _cidA, bodyHash: bodyHash),
      other.finish(cidNumber: _cidA, bodyHash: bodyHash),
    ]);
    final binding = _store.attach(_reference(bodyHash: bodyHash));
    final deleting = other.deleteUnused(cidNumber: _cidA, bodyHash: bodyHash);
    await expectLater(deleting, throwsA(_storeError));
    await binding;
    expect(await _store.listByCid(_cidA), hasLength(1));
    expect(
      await SocialIsar.instance.read(
        (db) => db.collection<social_store.Chunk>().count(),
      ),
      1,
    );
  });

  test('非法CID、空媒体及未知关联值拒绝，不能伪造完成标记', () async {
    final bodyHash = _hash(_bytes(1));
    await expectLater(_store.begin(_media(Uint8List(0))), throwsA(_storeError));
    await expectLater(
      _store.begin(_media(_bytes(1), digest: 'bad')),
      throwsA(_storeError),
    );
    for (final cid in ['', ' $_cidA', List.filled(33, 'a').join()]) {
      await expectLater(
        _store.begin(_media(_bytes(1), cid: cid)),
        throwsA(_storeError),
      );
      await expectLater(_store.listByCid(cid), throwsA(_storeError));
    }
    final media = _media(_bytes(1));
    await expectLater(
      _store.begin(
        SquareStoredMedia(
          cidNumber: media.cidNumber,

          mediaKind: media.mediaKind,
          contentType: media.contentType,
          byteSize: media.byteSize,
          bodyHash: media.bodyHash,
          isComplete: true,
        ),
      ),
      throwsA(_storeError),
    );
    for (final reference in [
      _reference(bodyHash: bodyHash, index: -1),
      _reference(bodyHash: bodyHash, role: 'unknown'),
      _reference(bodyHash: bodyHash, contentKind: 'unknown'),
      _reference(bodyHash: bodyHash, contentId: ''),
    ]) {
      await expectLater(_store.attach(reference), throwsA(_storeError));
    }
  });
}
