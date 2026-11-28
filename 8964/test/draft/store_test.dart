// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:io';

import 'package:citizen_square/draft/media.dart';
import 'package:citizen_square/draft/store.dart';
import 'package:citizen_square/media/store.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_storage/social.dart'
    as social_store
    show Cleanup, Draft;
import 'package:citizen_storage/social.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

// 以真实Isar验证草稿媒体离线保存、CID隔离及失败不覆盖。

SquareComposeDraft _draft(
  String id,
  int updatedAt, {
  String cidNumber = 'CN001-CTZN-100000001-2026',
}) => SquareComposeDraft(
  draftId: id,
  cidNumber: cidNumber,
  postType: SquarePostType.document,
  text: '内容 $id',
  media: const <SquareLocalMediaDraft>[],
  updatedAt: updatedAt,
);

void _registerComposeDraftStore() {
  test('公民圈范围经真实Isar草稿保存恢复', () async {
    final store = SquareComposeDraftStore.instance;
    final draft = _draft(
      'scope',
      1,
    ).copyWith(postVisibility: SquarePostVisibility.circle);
    await store.save(draft);
    final restored = (await store.list(draft.cidNumber)).single;
    expect(restored.postVisibility, SquarePostVisibility.circle);
    expect(restored.toJson()['post_visibility'], 'circle');
  });
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = SquareComposeDraftStore.instance;
  late Directory documentsDirectory;

  setUpAll(() {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'citizenapp_square_drafts_',
    );
    ComposeDraftMedia.debugDocumentsDirectoryProvider = () async =>
        documentsDirectory;
  });
  setUp(() async {
    await ComposeDraftMedia.resetForTest(
      documentsDirectoryProvider: () async => documentsDirectory,
    );
  });
  tearDown(() async {
    await ComposeDraftMedia.resetForTest(
      documentsDirectoryProvider: () async => documentsDirectory,
    );
  });
  tearDownAll(() async {
    ComposeDraftMedia.debugDocumentsDirectoryProvider = null;
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
  });

  test('禁止联网时草稿增删改查和素材导入全部正常，CID数据互不影响', () async {
    var networkCalls = 0;
    await HttpOverrides.runZoned(
      () async {
        const cid = 'CN001-CTZN-100000001-2026',
            other = 'CN001-CTZN-100000002-2026';
        final input = File('${documentsDirectory.path}/offline.webp');
        await input.writeAsBytes([1, 3, 5, 7]);
        await store.save(
          _draft('offline', 1000).copyWith(
            media: [
              SquareLocalMediaDraft(
                mediaKind: SquareMediaKind.image,
                path: input.path,
                fileName: 'offline.webp',
                contentType: 'image/webp',
                byteSize: 4,
              ),
            ],
          ),
        );
        await store.save(_draft('offline', 1000, cidNumber: other));
        final saved = (await store.list(cid)).single;
        await store.save(
          SquareComposeDraft(
            cidNumber: cid,
            draftId: saved.draftId,
            postType: saved.postType,
            text: '离线修改',
            media: saved.media,
            updatedAt: 2000,
          ),
        );
        final opened = await store.restore((await store.list(cid)).single);
        expect(opened.text, '离线修改');
        expect(await File(opened.media.single.path).readAsBytes(), [
          1,
          3,
          5,
          7,
        ]);
        await store.delete(cid, 'offline');
        expect(await store.list(cid), isEmpty);
        expect(await store.list(other), hasLength(1));
      },
      createHttpClient: (_) {
        networkCalls++;
        throw StateError('草稿操作不得创建网络客户端');
      },
    );
    expect(networkCalls, 0);
  });
  test('多草稿按 updated_at 新→旧列出，仅本人可见', () async {
    await store.save(_draft('a', 1000));
    await store.save(_draft('b', 3000));
    await store.save(_draft('c', 2000));
    await store.save(_draft('x', 9999, cidNumber: 'CN001-CTZN-999999999-2026'));

    final drafts = await store.list('CN001-CTZN-100000001-2026');
    expect(drafts.map((d) => d.draftId).toList(), ['b', 'c', 'a']);
    expect(
      drafts.every((d) => d.cidNumber == 'CN001-CTZN-100000001-2026'),
      isTrue,
    );
  });

  test('草稿媒体实际字节入库，移除来源文件后仍能恢复，不持久保存路径', () async {
    const cid = 'CN001-CTZN-100000001-2026';
    final input = File('${documentsDirectory.path}/selected.webp');
    await input.writeAsBytes([1, 3, 5, 7]);
    await store.save(
      _draft('bytes', 1000).copyWith(
        media: [
          SquareLocalMediaDraft(
            mediaKind: SquareMediaKind.image,
            path: input.path,
            fileName: 'photo.webp',
            contentType: 'image/webp',
            byteSize: 4,
          ),
        ],
      ),
    );
    final saved = (await store.list(cid)).single;
    expect(saved.media.single.bodyHash, isNotNull);
    expect(saved.media.single.path, isEmpty);
    expect(saved.toJsonString(), isNot(contains(documentsDirectory.path)));
    await input.delete();
    final restored = await store.restore(saved);
    expect(await File(restored.media.single.path).readAsBytes(), [1, 3, 5, 7]);
    expect(
      (await const SquareMediaStore().get(
        cidNumber: cid,
        bodyHash: saved.media.single.bodyHash!,
      ))!.isComplete,
      isTrue,
    );
  });

  test('保存第101条草稿不删除已有草稿', () async {
    for (var i = 0; i < 101; i++) {
      await store.save(_draft('keep-$i', i + 1));
    }
    final drafts = await store.list('CN001-CTZN-100000001-2026');
    expect(drafts, hasLength(101));
    expect(drafts.any((draft) => draft.draftId == 'keep-0'), isTrue);
  });

  test('媒体导入失败或引用其他CID的媒体不能覆盖原草稿', () async {
    const cid = 'CN001-CTZN-100000001-2026';
    await store.save(_draft('retain', 1000));
    final file = File('${documentsDirectory.path}/incomplete.webp');
    await file.writeAsBytes([1, 2]);
    final incoming = SquareLocalMediaDraft(
      mediaKind: SquareMediaKind.image,
      path: file.path,
      fileName: 'incomplete.webp',
      contentType: 'image/webp',
      byteSize: 3,
    );
    await expectLater(
      store.save(_draft('retain', 2000).copyWith(media: [incoming])),
      throwsA(isA<SquareMediaStoreException>()),
    );
    final other = await const SquareMediaStore().saveFile(
      cidNumber: 'CN001-CTZN-999999999-2026',
      path: file.path,
      mediaKind: 'image',
      contentType: 'image/webp',
      byteSize: 2,
    );
    await expectLater(
      store.save(
        _draft('retain', 2000).copyWith(
          media: [
            SquareLocalMediaDraft(
              mediaKind: SquareMediaKind.image,
              path: '',
              bodyHash: other.bodyHash,
              fileName: 'other.webp',
              contentType: 'image/webp',
              byteSize: 2,
            ),
          ],
        ),
      ),
      throwsA(isA<SquareMediaStoreException>()),
    );
    expect((await store.list(cid)).single.updatedAt, 1000);
  });

  test('同 draftId 再存为覆盖，不新增', () async {
    await store.save(_draft('s', 1000, cidNumber: 'CN001-CTZN-200000001-2026'));
    await store.save(_draft('s', 5000, cidNumber: 'CN001-CTZN-200000001-2026'));
    final drafts = await store.list('CN001-CTZN-200000001-2026');
    expect(drafts.length, 1);
    expect(drafts.single.updatedAt, 5000);
  });

  test('损坏草稿读取 fail-closed，数据库行与媒体目录均原样保留', () async {
    const cidNumber = 'CN001-CTZN-300000001-2026';
    const draftId = 'broken';
    final entity = social_store.Draft()
      ..cidNumber = cidNumber
      ..draftId = draftId
      ..postType = 'document'
      ..text = '损坏行'
      ..mediaData = '{bad-json'
      ..updatedAt = 1000;
    await SocialIsar.instance.writeTxn((isar) async {
      await isar.collection<social_store.Draft>().putByCidNumberDraftId(entity);
    });
    final mediaDir = Directory(
      '${documentsDirectory.path}/square_drafts/'
      '${Uri.encodeComponent(cidNumber)}/${Uri.encodeComponent(draftId)}',
    );
    mediaDir.createSync(recursive: true);
    File('${mediaDir.path}/sentinel.bin').writeAsBytesSync(<int>[1, 2, 3]);

    await expectLater(
      store.list(cidNumber),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );

    final retained = await SocialIsar.instance.read(
      (isar) => isar.collection<social_store.Draft>().getByCidNumberDraftId(
        entity.cidNumber,
        entity.draftId,
      ),
    );
    expect(retained, isNotNull);
    expect(File('${mediaDir.path}/sentinel.bin').existsSync(), isTrue);
  });

  test('明确删除先提交事实与清理计划，文件失败保留计划并可重试', () async {
    const cidNumber = 'CN001-CTZN-400000001-2026';
    const draftId = 'delete-retry';
    await store.save(_draft(draftId, 1000, cidNumber: cidNumber));

    final invalidRoot = File('${documentsDirectory.path}/square_drafts');
    invalidRoot.writeAsStringSync('阻断目录删除');
    await expectLater(
      store.delete(cidNumber, draftId),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );

    expect(await store.list(cidNumber), isEmpty);
    final pending = await SocialIsar.instance.read(
      (isar) => isar.collection<social_store.Cleanup>().where().findAll(),
    );
    expect(pending, hasLength(1));
    expect(pending.single.tryCount, 1);

    invalidRoot.deleteSync();
    await store.retryPendingFileCleanup(cidNumber: cidNumber);
    final remaining = await SocialIsar.instance.read(
      (isar) => isar.collection<social_store.Cleanup>().where().count(),
    );
    expect(remaining, 0);
  });

  test('非法路径段和属主符号链接均 fail-closed，不扩大删除范围', () async {
    final root = Directory('${documentsDirectory.path}/square_drafts')
      ..createSync(recursive: true);
    final rootMarker = File('${root.path}/root-marker.bin')
      ..writeAsBytesSync(<int>[1]);

    await expectLater(
      store.delete('CN001-CTZN-500000001-2026', '..'),
      throwsA(isA<SquareComposeDraftStoreException>()),
    );
    expect(rootMarker.existsSync(), isTrue);

    const cidNumber = 'CN001-CTZN-500000002-2026';
    final outside = Directory('${documentsDirectory.path}/outside')
      ..createSync();
    final outsideMarker = File('${outside.path}/must-survive.bin')
      ..writeAsBytesSync(<int>[2]);
    Link('${root.path}/${Uri.encodeComponent(cidNumber)}')
        .createSync(outside.path);

    await expectLater(
      ComposeDraftMedia.deleteDir(cidNumber, 'draft-a'),
      throwsA(isA<StateError>()),
    );
    expect(outsideMarker.existsSync(), isTrue);
  });
}

// 验证草稿类型、范围、段落及媒体往返和损坏拒绝。

SquareLocalMediaDraft _media(SquareMediaKind kind, String name) =>
    SquareLocalMediaDraft(
      mediaKind: kind,
      path: '/temporary/$name',
      bodyHash: 'stored-$name',
      fileName: name,
      contentType: kind == SquareMediaKind.video ? 'video/mp4' : 'image/jpeg',
      byteSize: 100,
    );

void _registerComposeDraft() {
  test('三种发布范围完整往返，缺失或非法字段不回退公开', () {
    for (final visibility in SquarePostVisibility.values) {
      final draft = SquareComposeDraft(
        draftId: 'scope',
        cidNumber: 'CN123',
        postType: SquarePostType.document,
        postVisibility: visibility,
        text: '正文',
        media: const [],
        updatedAt: 1,
      );
      expect(
        SquareComposeDraft.fromJson(draft.toJson()).postVisibility,
        visibility,
      );
      final missing = draft.toJson()..remove('post_visibility');
      expect(() => SquareComposeDraft.fromJson(missing), throwsFormatException);
      expect(
        () => SquareComposeDraft.fromJson({
          ...draft.toJson(),
          'post_visibility': 'followers',
        }),
        throwsFormatException,
      );
    }
  });
  group('SquareComposeDraft JSON 往返', () {
    test('文章草稿含段落和媒体完整往返', () {
      final draft = SquareComposeDraft(
        draftId: 'draft1',
        cidNumber: 'CN001-CTZN-100000001-2026',
        postType: SquarePostType.article,
        title: '论社区自治',
        text: '正文',
        media: [
          _media(SquareMediaKind.image, 'cover.jpg'),
          _media(
            SquareMediaKind.image,
            'inline.jpg',
          ).copyWith(assetId: 'ios-or-android-photo-asset-id'),
        ],
        contentSections: const [
          {
            'text_delta': [
              {'insert': '第一段正文满足十字'},
              {'insert': '\n'},
            ],
            'gallery_media_indices': [1],
          },
        ],
        updatedAt: 1800000000000,
      );
      final restored = SquareComposeDraft.fromJsonString(draft.toJsonString())!;
      expect(restored.draftId, 'draft1');
      expect(restored.isArticle, isTrue);
      expect(restored.title, '论社区自治');
      expect(restored.media.length, 2);
      expect(restored.media[1].fileName, 'inline.jpg');
      expect(restored.media[1].bodyHash, 'stored-inline.jpg');
      expect(restored.media[1].path, isEmpty);
      expect(draft.toJsonString(), isNot(contains('/temporary/')));
      expect(restored.media[1].assetId, 'ios-or-android-photo-asset-id');
      expect(restored.contentSections!.length, 1);
      expect(restored.contentSections!.first['gallery_media_indices'], [1]);
      expect(restored.updatedAt, 1800000000000);
    });

    test('损坏字符串返回 null', () {
      expect(SquareComposeDraft.fromJsonString('不是json'), isNull);
      expect(SquareComposeDraft.fromJsonString(null), isNull);
    });
  });

  group('卡片派生', () {
    test('类型标签由固定 post_type 决定', () {
      SquareComposeDraft draft({
        required SquarePostType postType,
        List<SquareLocalMediaDraft> media = const [],
      }) => SquareComposeDraft(
        draftId: 'd',
        cidNumber: 'CN001-CTZN-100000001-2026',
        postType: postType,
        text: 't',
        media: media,
        updatedAt: 1,
      );

      expect(
        draft(
          postType: SquarePostType.document,
          media: [_media(SquareMediaKind.image, 'a.jpg')],
        ).typeLabel,
        '公文',
      );
      expect(
        draft(
          postType: SquarePostType.video,
          media: [_media(SquareMediaKind.video, 'v.mp4')],
        ).typeLabel,
        '视频',
      );
      expect(draft(postType: SquarePostType.article).typeLabel, '文章');
    });

    test('文章摘要优先标题；空内容 isEmpty', () {
      const article = SquareComposeDraft(
        draftId: 'd',
        cidNumber: 'CN001-CTZN-100000001-2026',
        postType: SquarePostType.article,
        title: '标题',
        text: '正文',
        media: [],
        updatedAt: 1,
      );
      expect(article.summary, '标题');

      const empty = SquareComposeDraft(
        draftId: 'd',
        cidNumber: 'CN001-CTZN-100000001-2026',
        postType: SquarePostType.document,
        text: '  ',
        media: [],
        updatedAt: 1,
      );
      expect(empty.isEmpty, isTrue);
    });
  });
}

void main() {
  group("compose/compose_draft_store_test", _registerComposeDraftStore);
  group("compose/compose_draft_test", _registerComposeDraft);
}
