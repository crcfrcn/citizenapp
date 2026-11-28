// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_square/media/store.dart';
import 'package:citizen_square/post/store.dart';
import 'package:citizen_square/post/sync.dart';
import 'package:citizen_storage/social.dart';
import 'package:citizen_testing/chat/authentication.dart';
import 'package:citizen_testing/database.dart';
import 'package:citizen_user/api.dart' show SquareApiClient, SquareSession;
import 'package:citizen_user/api.dart'
    show SquareApiException, SquarePostDeletionService, SquareSession;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// 验证远端删除、准确不存在回执及本地清理恢复和CID边界。

const _cidNumber = 'CN001-CTZN-000000001-2026';
const _otherCidNumber = 'CN002-CTZN-000000002-2026';
const _accountId =
    '0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';

SquareSession _session() => const SquareSession(
  deviceId: testMlsDeviceId,
  sessionToken: 'session',
  cidNumber: _cidNumber,
  bindRev: 1,
  accountId: _accountId,
  expiresAt: 4102444800000,
);

class _FakeRemoteDeletion implements SquarePostDeletionService {
  _FakeRemoteDeletion({this.error});

  final SquareApiException? error;
  int calls = 0;

  @override
  Future<void> deletePost({
    required SquareSession session,
    required String postId,
  }) async {
    calls += 1;
    if (error != null) throw error!;
  }
}

class _FakeLocalStore implements SquareLocalPostDeletionStore {
  bool fail = false;
  int deleteCalls = 0;
  String? deletedCidNumber;
  String? deletedPostId;

  @override
  Future<bool> delete({
    required String cidNumber,
    required String postId,
  }) async {
    deleteCalls += 1;
    if (fail) throw StateError('本地事务失败');
    deletedCidNumber = cidNumber;
    deletedPostId = postId;
    return true;
  }
}

void _registerSquarePostDeletionCoordinator() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  test('远端成功本地失败，重启后只重试本地删除', () async {
    final remote = _FakeRemoteDeletion();
    final local = _FakeLocalStore()..fail = true;
    await expectLater(
      SquarePostDeletionCoordinator(
        remoteDeletion: remote,
        localStore: local,
      ).delete(
        session: _session(),
        cidNumber: _cidNumber,
        postId: 'pending-delete',
      ),
      throwsStateError,
    );
    expect(
      (await const SquarePostStore().readDeletion(
        _cidNumber,
        'pending-delete',
      ))!.jobState,
      'confirmed',
    );
    await (await SocialIsar.instance.db()).close();
    local.fail = false;
    await SquarePostDeletionCoordinator(
      remoteDeletion: remote,
      localStore: local,
    ).delete(
      session: _session(),
      cidNumber: _cidNumber,
      postId: 'pending-delete',
    );
    expect(remote.calls, 1);
    expect(local.deleteCalls, 2);
  });
  test('Worker 删除成功后删除同 CID 本地副本', () async {
    final remote = _FakeRemoteDeletion();
    final local = _FakeLocalStore();
    final coordinator = SquarePostDeletionCoordinator(
      remoteDeletion: remote,
      localStore: local,
    );

    await coordinator.delete(
      session: _session(),
      cidNumber: _cidNumber,
      postId: 'post-1',
    );

    expect(remote.calls, 1);
    expect(local.deleteCalls, 1);
    expect(local.deletedCidNumber, _cidNumber);
    expect(local.deletedPostId, 'post-1');
  });

  test('Worker 精确返回 404/post_not_found 时允许清理本人本地残留', () async {
    final remote = _FakeRemoteDeletion(
      error: const SquareApiException(
        '帖子不存在',
        statusCode: 404,
        errorCode: 'post_not_found',
      ),
    );
    final local = _FakeLocalStore();
    final coordinator = SquarePostDeletionCoordinator(
      remoteDeletion: remote,
      localStore: local,
    );

    await coordinator.delete(
      session: _session(),
      cidNumber: _cidNumber,
      postId: 'post-2',
    );

    expect(local.deleteCalls, 1);
  });

  test('权限、会话或网络错误必须保留本地副本', () async {
    final remote = _FakeRemoteDeletion(
      error: const SquareApiException(
        '无权删除',
        statusCode: 403,
        errorCode: 'post_owner_mismatch',
      ),
    );
    final local = _FakeLocalStore();
    final coordinator = SquarePostDeletionCoordinator(
      remoteDeletion: remote,
      localStore: local,
    );

    await expectLater(
      coordinator.delete(
        session: _session(),
        cidNumber: _cidNumber,
        postId: 'post-3',
      ),
      throwsA(isA<SquareApiException>()),
    );

    expect(local.deleteCalls, 0);
  });

  test('请求 CID 与会话 CID 不同则在访问 Worker 前拒绝', () async {
    final remote = _FakeRemoteDeletion();
    final local = _FakeLocalStore();
    final coordinator = SquarePostDeletionCoordinator(
      remoteDeletion: remote,
      localStore: local,
    );

    await expectLater(
      coordinator.delete(
        session: _session(),
        cidNumber: _otherCidNumber,
        postId: 'post-4',
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'post_owner_mismatch',
        ),
      ),
    );

    expect(remote.calls, 0);
    expect(local.deleteCalls, 0);
  });
}

// 验证三类帖子增量回灌、媒体哈希、逐页原子提交和检查点。

const _cid = 'R5-K3P1C1-N9-D4';
const _account =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _syncSession = SquareSession(
  deviceId: testMlsDeviceId,
  sessionToken: 'sqs_sync',
  cidNumber: _cid,
  bindRev: 1,
  accountId: _account,
  expiresAt: 1900000000000,
);

SquareLocalPost _post(
  String postId,
  int createdAt, {
  String cid = _cid,
  String postVisibility = 'public',
  List<Map<String, Object>> media = const [],
}) {
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'schema': SquarePostStore.manifestSchema,
        'cid_number': cid,
        'post_type': 'document',
        'text': '正文 $postId',
        'media_items': media,
      }),
    ),
  );
  return SquareLocalPost(
    postId: postId,
    cidNumber: cid,
    accountId: _account,
    postCategory: 'normal',
    postType: 'document',
    postVisibility: postVisibility,
    manifestBytes: bytes,
    contentHash: sha256.convert(bytes).toString(),
    receiptId: 'sqr_$postId',
    chainBlock: createdAt,
    publishedAt: createdAt,
    postState: SquarePostStore.publishedState,
  );
}

class _MediaApi extends SquareApiClient {
  _MediaApi(this.post, this.main, this.preview);
  final SquareLocalPost post;
  final Uint8List main;
  final Uint8List preview;
  bool corrupt = false;
  int downloads = 0;
  @override
  Future<List<Map<String, dynamic>>> fetchPostMedia({
    required SquareSession session,
    required SquareLocalPost post,
  }) async {
    final manifest = jsonDecode(utf8.decode(post.manifestBytes)) as Map;
    return (manifest['media_items'] as List)
        .map(
          (item) => <String, dynamic>{
            ...Map<String, dynamic>.from(item as Map),
            'url': 'https://example.com/main',
            'preview_url': 'https://example.com/preview',
          },
        )
        .toList();
  }

  @override
  Future<http.StreamedResponse> openPostMedia(
    String url, {
    required SquareSession session,
    String? range,
    int? expectedBytes,
  }) async {
    downloads++;
    final bytes = url.endsWith('/main')
        ? (corrupt ? Uint8List.fromList(List.filled(main.length, 9)) : main)
        : preview;
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      contentLength: bytes.length,
      headers: {'content-type': 'image/png'},
    );
  }
}

void _registerSquarePostSyncService() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();

  test('本人回灌三类动态不漏范围，重开数据库保持原值', () async {
    final posts = [
      _post('scope-open', 3, postVisibility: 'public'),
      _post('scope-circle', 2, postVisibility: 'circle'),
      _post('scope-home', 1, postVisibility: 'profile'),
    ];
    final sync = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) async =>
          SquareLocalPostPage(items: posts, nextCursor: null),
    );
    await sync.sync(_syncSession, userInitiated: true);
    await (await SocialIsar.instance.db()).close();
    final saved = await const SquarePostStore().listByCid(_cid);
    expect(saved.map((p) => p.postVisibility).toSet(), {
      'public',
      'circle',
      'profile',
    });
  });

  test('普通加载拒绝联网，用户刷新跨实例复用同CID任务', () async {
    final gate = Completer<SquareLocalPostPage>();
    var calls = 0;
    Future<SquareLocalPostPage> load({
      required SquareSession session,
      String? cursor,
      required int limit,
    }) {
      calls++;
      return gate.future;
    }

    final a = SquarePostSyncService(pageLoader: load),
        b = SquarePostSyncService(pageLoader: load);
    expect(() => a.sync(_syncSession, userInitiated: false), throwsStateError);
    expect(calls, 0);
    final first = a.sync(_syncSession, userInitiated: true);
    final second = b.sync(_syncSession, userInitiated: true);
    expect(identical(first, second), isTrue);
    gate.complete(const SquareLocalPostPage(items: [], nextCursor: null));
    await first;
    expect(calls, 1);
  });

  for (final kind in ['image', 'video']) {
    test('$kind实际字节入库并跨重启保留，哈希错误不得提交正文或推进检查点', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final preview = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==',
      );
      final hash = sha256.convert(bytes).toString();
      final post = _post(
        'media-post',
        2000,
        media: [
          {
            'media_kind': kind,
            'file_name': kind == 'image' ? 'photo.png' : 'video.mp4',
            'byte_size': bytes.length,
            'body_hash': hash,
          },
        ],
      );
      final api = _MediaApi(post, bytes, preview)..corrupt = true;
      final sync = SquarePostSyncService(
        api: api,
        pageLoader: ({required session, cursor, required limit}) async =>
            SquareLocalPostPage(items: [post], nextCursor: null),
      );
      await expectLater(
        sync.sync(_syncSession, userInitiated: true),
        throwsA(isA<Exception>()),
      );
      const store = SquarePostStore();
      expect(await store.listByCid(_cid), isEmpty);
      expect(await store.readSyncCheckpoint(_cid), isNull);
      api.corrupt = false;
      await sync.sync(_syncSession, userInitiated: true);
      await (await SocialIsar.instance.db()).close();
      const media = SquareMediaStore();
      expect(
        await media.readRange(
          cidNumber: _cid,
          bodyHash: hash,
          offset: 0,
          length: bytes.length,
        ),
        bytes,
      );
      expect(
        (await media.referencesForContent(
          cidNumber: _cid,
          contentKind: 'post',
          contentId: post.postId,
        )).length,
        2,
      );
      final downloads = api.downloads;
      await sync.sync(_syncSession, userInitiated: true);
      expect(api.downloads, downloads);
    });
  }

  test('首次回灌完整分页，后续只扫描到旧检查点且保留本地历史', () async {
    final firstCursors = <String?>[];
    final firstSync = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) async {
        expect(session.cidNumber, _cid);
        expect(limit, 5);
        firstCursors.add(cursor);
        if (cursor == null) {
          return SquareLocalPostPage(
            items: [_post('sqp_3', 3000), _post('sqp_2', 2000)],
            nextCursor: 'cursor_2',
          );
        }
        expect(cursor, 'cursor_2');
        return SquareLocalPostPage(
          items: [_post('sqp_1', 1000)],
          nextCursor: null,
        );
      },
    );

    await firstSync.sync(_syncSession, userInitiated: true);
    expect(firstCursors, [null, 'cursor_2']);
    expect(
      (await const SquarePostStore().listByCid(_cid))
          .map((post) => post.postId),
      ['sqp_3', 'sqp_2', 'sqp_1'],
    );
    final firstCheckpoint = await const SquarePostStore().readSyncCheckpoint(
      _cid,
    );
    expect(firstCheckpoint?.postId, 'sqp_3');
    expect(firstCheckpoint?.publishedAt, 3000);

    var secondPageCalls = 0;
    final incrementalSync = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) async {
        secondPageCalls += 1;
        expect(cursor, isNull);
        return SquareLocalPostPage(
          items: [_post('sqp_4', 4000), _post('sqp_3', 3000)],
          nextCursor: 'must_not_be_requested',
        );
      },
    );
    await incrementalSync.sync(_syncSession, userInitiated: true);

    expect(secondPageCalls, 1);
    expect(
      (await const SquarePostStore().listByCid(_cid))
          .map((post) => post.postId),
      ['sqp_4', 'sqp_3', 'sqp_2', 'sqp_1'],
    );
    final nextCheckpoint = await const SquarePostStore().readSyncCheckpoint(
      _cid,
    );
    expect(nextCheckpoint?.postId, 'sqp_4');
    expect(nextCheckpoint?.publishedAt, 4000);
  });

  test('一页任一条归属错误时整页不落盘且不推进检查点', () async {
    final service = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) async =>
          SquareLocalPostPage(
            items: [
              _post('sqp_good', 2000),
              _post('sqp_wrong_owner', 1000, cid: 'R5-K3P1C1-N8-D5'),
            ],
            nextCursor: null,
          ),
    );

    await expectLater(
      service.sync(_syncSession, userInitiated: true),
      throwsA(isA<SquarePostStoreException>()),
    );
    expect(await const SquarePostStore().listByCid(_cid), isEmpty);
    expect(await const SquarePostStore().readSyncCheckpoint(_cid), isNull);
  });

  test('远端为空只更新空检查点，不删除会员到期前已落盘的本地副本', () async {
    const store = SquarePostStore();
    await store.save(_post('sqp_local', 1000));
    final service = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) async =>
          const SquareLocalPostPage(items: [], nextCursor: null),
    );

    await service.sync(_syncSession, userInitiated: true);

    expect((await store.listByCid(_cid)).single.postId, 'sqp_local');
    final checkpoint = await store.readSyncCheckpoint(_cid);
    expect(checkpoint?.postId, isNull);
    expect(checkpoint?.publishedAt, 0);
  });

  test('注销清理同时删除本人副本和同步检查点', () async {
    const store = SquarePostStore();
    await store.save(_post('sqp_local', 1000));
    await store.writeSyncCheckpoint(
      cidNumber: _cid,
      checkpoint: const SquarePostSyncCheckpoint(
        postId: 'sqp_local',
        publishedAt: 1000,
      ),
    );

    expect(await store.deleteAllByCid(_cid), 1);
    expect(await store.listByCid(_cid), isEmpty);
    expect(await store.readSyncCheckpoint(_cid), isNull);
  });

  test('同一 CID 并发启动复用同一个回灌任务', () async {
    final pageCompleter = Completer<SquareLocalPostPage>();
    var calls = 0;
    final service = SquarePostSyncService(
      pageLoader: ({required session, cursor, required limit}) {
        calls += 1;
        return pageCompleter.future;
      },
    );

    final first = service.sync(_syncSession, userInitiated: true);
    final second = service.sync(_syncSession, userInitiated: true);
    expect(identical(first, second), isTrue);
    pageCompleter.complete(
      const SquareLocalPostPage(items: [], nextCursor: null),
    );
    await Future.wait([first, second]);

    expect(calls, 1);
  });
}

void main() {
  group(
    "square_post_deletion_coordinator_test",
    _registerSquarePostDeletionCoordinator,
  );
  group("square_post_sync_service_test", _registerSquarePostSyncService);
}
