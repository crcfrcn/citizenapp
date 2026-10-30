import 'package:citizen_storage/social_isar.dart' as social_store show Reply;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_account/notifications.dart';

import 'dart:async';
import 'dart:convert';

import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_square/comment/comments.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_storage/social_isar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_testing/isar_test_env.dart';

const _cid = 'CN220-CTZN2-100000007-2026';
Map<String, dynamic> _comment({
  String replyText = '评论',
  String post = 'post',
  String state = 'active',
  String id = 'comment',
  int sequence = 1,
  String author = _cid,
}) => {
  'reply_seq': sequence,
  'created_at': 1000000,
  'comment_id': id,
  'post_id': post,
  'author_cid': author,
  'reply_text': replyText,
  'reply_state': state,
  'display_name': '公民',
  'reply_to': null,
};

class _Sessions implements SquareSessionProvider {
  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: '33' * 32,
    sessionToken: 'synthetic',
    cidNumber: _cid,
    accountId: '0x${'11' * 32}',
    bindRev: 1,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused session boundary');
}

class _User implements CurrentUserContext {
  String cid = _cid;
  bool fail = false;
  @override
  Future<CurrentUser?> resolve() async {
    if (fail) throw StateError('synthetic identity read failure');
    return CurrentUser(
      account: CitizenWalletStateAccount(
        accountId: '0x${'11' * 32}',
        ss58Address: 'synthetic',
        name: '评论测试',
        walletIndex: 0,
        accountIndex: 0,
        isDefault: true,
        createdAtMillis: BigInt.one,
        signMode: CitizenWalletSignMode.hot,
      ),
      binding: IdentityBinding(
        genesisHash: '0x${'22' * 32}',
        cidNumber: cid,
        accountId: '0x${'11' * 32}',
        bindRev: 1,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _notice(int revision) => {
  'is_ok': true,
  'cid_number': _cid,
  'bind_rev': 1,
  'notice_rev': revision,
  'square_unread': 0,
  'notifications_unread': 0,
  'following_unread': 0,
  'interaction_unread': 0,
  'interaction_sequence': 0,
  'through': revision,
  'member_rev': 0,
  'creator_rev': 0,
  'membergate': null,
  'creator': null,
};

class _Api extends SquareApiClient {
  _Api() : super(baseUrl: 'https://comments.test/api');
  int reads = 0;
  Future<Map<String, dynamic>> Function(int)? onRead;
  bool failSend = false;
  final operations = <String>[];
  final replies = <String?>[], deleted = <String>[], targets = <String?>[];
  final cursors = <int?>[];
  Map<String, dynamic>? firstPage, nextPage;
  @override
  Future<Map<String, dynamic>> fetchComments({
    required SquareSession session,
    required String postId,
    int? cursor,
    String? target,

    String? mode,
    String? thread,
    int? through,
    String? after,
  }) async {
    reads++;
    if (onRead != null) return onRead!(reads);
    cursors.add(cursor);
    targets.add(target);
    return (cursor == null ? firstPage : nextPage) ??
        {'is_ok': true, 'comments': <Object>[], 'next_cursor': null};
  }

  @override
  Future<Map<String, dynamic>> createComment({
    required SquareSession session,
    required String postId,
    required String opId,
    required String replyText,
    String? replyTo,
  }) async {
    operations.add(opId);
    replies.add(replyTo);
    if (failSend) throw StateError('synthetic offline');
    return {
      'is_ok': true,
      'comment': _comment(replyText: replyText, post: postId),
    };
  }

  @override
  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],

    String? postId,
  }) async => _notice(5);
  @override
  Future<void> deleteComment({
    required SquareSession session,
    required String postId,
    required String commentId,
  }) async {
    deleted.add(commentId);
  }
}

Future<void> _drain(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
}

// 真实Isar任务与Widget微任务在同一区域驱动，避免runAsync等待另一虚拟区域的队列。
Future<void> _complete(
  WidgetTester tester,
  Future<dynamic> Function() action,
) async {
  var done = false;
  Object? failure;
  unawaited(
    action().then<void>(
      (_) {
        done = true;
      },
      onError: (Object error) {
        failure = error;
        done = true;
      },
    ),
  );
  await _drain(tester, () => done);
  if (failure != null) throw failure!;
}

// Widget用例在仍可驱动原生异步任务时关库，失败用例也不污染下一用例。
Future<void> _check(WidgetTester tester, Future<void> Function() body) async {
  final notices = _Api();
  Notifications.instance.configure(
    api: notices,
    sessions: _Sessions(),
    user: _User(),
  );
  try {
    await body();
  } finally {
    Notifications.instance.stop();
    notices.close();
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    var closed = false;
    Object? error;
    unawaited(
      SocialIsar.instance.resetForTest().then<void>(
        (_) {
          closed = true;
        },
        onError: (Object value) {
          error = value;
          closed = true;
        },
      ),
    );
    await _drain(tester, () => closed);
    if (error != null) throw error!;
    await tester.runAsync(() => UserIsar.instance.resetForTest());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  test('模型拒绝坏分页行和已删除正文，不用空列表掩盖错误', () {
    expect(SquareComment.fromJson(_comment()).replyText, '评论');
    for (final value in [
      {..._comment(), 'reply_seq': 0},
      _comment(state: 'unknown'),
      _comment(state: 'deleted'),
      _comment(replyText: '字' * 2001),
    ]) {
      expect(() => SquareComment.fromJson(value), throwsFormatException);
    }
    expect(
      SquareComment.fromJson(_comment(replyText: '', state: 'deleted'))
          .replyState,
      'deleted',
    );
  });
  testWidgets('发送失败保留相同操作ID，重试不创建第二个操作', (tester) async {
    await _check(tester, () async {
      await tester.runAsync(() => SocialIsar.instance.read((_) async => null));
      final api = _Api()..failSend = true;
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .readOnly,
        isTrue,
        reason: '身份和本机缓存恢复期间不能提前编辑或发送',
      );
      await _drain(tester, () => find.text('暂无评论').evaluate().isNotEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '原评论',
      );
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(tester, () => find.text('重试发送').evaluate().isNotEmpty);
      api.failSend = false;
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(
        tester,
        () =>
            find.text('原评论').evaluate().isNotEmpty &&
            find.text('发送').evaluate().isNotEmpty,
      );
      expect(api.operations.length, 2);
      expect(api.operations.toSet().length, 1);
      expect(api.reads, 1);
    });
  });
  for (final mode in ['page', 'pending', 'mixed']) {
    testWidgets('评论旧缓存$mode拒绝操作且原样保留，刷新读取并发新快照', (tester) async {
      await _check(tester, () async {
        final row = _comment(replyText: '旧评论');
        if (mode == 'page') {
          for (final entry in {
            'reply_seq': 'sequence',
            'reply_text': 'body',
            'reply_state': 'state',
          }.entries) {
            row[entry.value] = row.remove(entry.key);
          }
        }
        final page = jsonEncode({
          'comments': [row],
          'next_cursor': null,
        });
        final pending = jsonEncode({
          'op_id': '11' * 16,
          if (mode == 'page' || mode == 'mixed') 'reply_text': '旧待发',
          if (mode != 'page') 'body': '旧待发',
          'reply_to': null,
        });
        await tester.runAsync(
          () => SocialIsar.instance.writeTxn((db) async {
            await db.collection<social_store.Reply>().put(
              social_store.Reply()
                ..cidNumber = _cid
                ..postId = 'post'
                ..pageData = page
                ..pendingData = pending,
            );
          }),
        );
        final api = _Api();
        addTearDown(api.close);
        var writes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Comments(
                  postId: 'post',
                  ownerCid: _cid,
                  api: api,
                  sessionProvider: _Sessions(),
                  cacheWriter:
                      (
                        cid,
                        post,
                        nextPage,
                        nextPending, {
                        required isCurrent,
                      }) async {
                        writes++;
                        throw StateError('普通恢复不得写入');
                      },
                ),
              ),
            ),
          ),
        );
        await _drain(
          tester,
          () => find.text('评论暂时不可用，请刷新重试').evaluate().isNotEmpty,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('comment-send')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('comment-input')))
              .readOnly,
          true,
        );
        expect(find.text('放弃本机待发'), findsNothing);
        expect(api.operations, isEmpty);
        expect(api.reads, 0);
        expect(writes, 0);
        final newPending = jsonEncode({
          'op_id': '22' * 16,
          'reply_text': '新待发',
          'reply_to': null,
        });
        await tester.runAsync(
          () => SocialIsar.instance.writeTxn((db) async {
            final saved = (await db
                .collection<social_store.Reply>()
                .getByCidNumberPostId(_cid, 'post'))!;
            expect(saved.pageData, page);
            expect(saved.pendingData, pending);
            saved
              ..pageData = jsonEncode({
                'comments': [_comment(replyText: '新评论')],
                'next_cursor': null,
              })
              ..pendingData = newPending;
            await db.collection<social_store.Reply>().put(saved);
          }),
        );
        await tester.tap(find.byTooltip('刷新评论'));
        await _drain(
          tester,
          () =>
              find.text('新待发').evaluate().isNotEmpty &&
              tester
                      .widget<FilledButton>(
                        find.byKey(const ValueKey('comment-send')),
                      )
                      .onPressed !=
                  null,
        );
        expect(find.text('新评论'), findsOneWidget);
        expect(api.operations, isEmpty);
        expect(api.reads, 0);
        expect(writes, 0);
        await tester.runAsync(() async {
          final saved = (await SocialIsar.instance.read(
            (db) => db.collection<social_store.Reply>().getByCidNumberPostId(
              _cid,
              'post',
            ),
          ))!;
          expect(saved.pendingData, newPending);
        });
      });
    });
  }
  testWidgets('已有评论缓存先展示，进入不重新请求全部评论', (tester) async {
    await _check(tester, () async {
      await tester.runAsync(() async {
        await SocialIsar.instance.writeTxn((db) async {
          await db.collection<social_store.Reply>().put(
            social_store.Reply()
              ..cidNumber = _cid
              ..postId = 'post'
              ..pageData = jsonEncode({
                'comments': [_comment()],
                'next_cursor': null,
              }),
          );
        });
      });
      final api = _Api();
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => find.text('评论').evaluate().length > 1);
      expect(api.reads, 0);
    });
  });
  testWidgets('游标补页、回复关联和本人删除都走当前实现，不重拉整页', (tester) async {
    await _check(tester, () async {
      final api = _Api()
        ..firstPage = {
          'is_ok': true,
          'comments': [_comment(id: 'parent', sequence: 2, replyText: '待回复')],
          'next_cursor': 2,
        }
        ..nextPage = {
          'is_ok': true,
          'comments': [
            _comment(
              id: 'older',
              sequence: 1,
              replyText: '较早评论',
              author: 'other',
            ),
          ],
          'next_cursor': null,
        };
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(
        tester,
        () =>
            find.text('待回复').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.tap(find.text('更早评论'));
      await _drain(
        tester,
        () =>
            find.text('较早评论').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(api.cursors, [null, 2]);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('回复'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '新回复',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.byKey(const ValueKey('comment-send')));
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(
        tester,
        () =>
            api.replies.isNotEmpty &&
            find
                .ancestor(of: find.text('新回复'), matching: find.byType(ListTile))
                .evaluate()
                .isNotEmpty &&
            find.text('发送').evaluate().isNotEmpty,
      );
      expect(api.replies, ['parent']);
      final own = find.ancestor(
        of: find.text('新回复'),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(own);
      await tester.tap(
        find.descendant(
          of: own,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await _drain(tester, () => find.text('评论已删除').evaluate().isNotEmpty);
      expect(api.deleted, ['comment']);
      expect(api.reads, 2);
    });
  });
  testWidgets('通知目标只请求一次准确评论页', (tester) async {
    await _check(tester, () async {
      final api = _Api()
        ..firstPage = {
          'is_ok': true,
          'comments': [_comment(id: 'far', replyText: '目标回复')],
          'next_cursor': null,
        };
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                initialCommentId: 'far',
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => find.text('目标回复').evaluate().isNotEmpty);
      expect(api.reads, 1);
      expect(api.targets, ['far']);
    });
  });
  testWidgets('评论加载期间的新事件在旧请求结束后合并补取，同版本计数不吞事件', (tester) async {
    await _check(tester, () async {
      final first = Completer<Map<String, dynamic>>(), api = _Api();
      addTearDown(api.close);
      api.onRead = (n) async => n == 1
          ? await first.future
          : {
              'is_ok': true,
              'comments': [_comment(replyText: '新通知评论')],
              'next_cursor': null,
            };
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: _User(),
      );
      await _complete(tester, () => Notifications.instance.accept(_notice(5)));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => api.reads == 1);
      final event = {
        'state': {..._notice(5), 'through': 8, 'interaction_sequence': 8},
        'post_id': 'another-post',
        'comment_id': 'comment',
      };
      await _complete(tester, () => Notifications.instance.receive(event));
      await _complete(
        tester,
        () => Notifications.instance.receive({
          ...event,
          'state': {..._notice(5), 'through': 9, 'interaction_sequence': 9},
        }),
      );
      first.complete({
        'is_ok': true,
        'comments': <Object>[],
        'next_cursor': null,
      });
      await _drain(
        tester,
        () =>
            api.reads == 2 &&
            find.text('新通知评论').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(api.reads, 2);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await _complete(
        tester,
        () => Notifications.instance.receive({
          ...event,
          'state': {..._notice(5), 'through': 10, 'interaction_sequence': 10},
        }),
      );
      await tester.pump();
      expect(api.reads, 2);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await _drain(
        tester,
        () =>
            api.reads == 3 &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      final navigator = Navigator.of(tester.element(find.byType(Comments)));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('遮挡页面'))),
        ),
      );
      await tester.pumpAndSettle();
      await _complete(
        tester,
        () => Notifications.instance.receive({
          ...event,
          'state': {..._notice(5), 'through': 11, 'interaction_sequence': 11},
        }),
      );
      await tester.pump();
      expect(api.reads, 3);
      navigator.pop();
      // 返回时会立即补取；先完成路由动画，再驱动真实Isar异步回调。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _drain(
        tester,
        () =>
            api.reads == 4 &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
    });
  });
  testWidgets('永久失败可放弃本机待发，不自动更换操作ID重发', (tester) async {
    await _check(tester, () async {
      final api = _Api()..failSend = true;
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => find.text('暂无评论').evaluate().isNotEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '保留原文',
      );
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(
        tester,
        () =>
            find.text('放弃本机待发').evaluate().isNotEmpty &&
            find.text('重试发送').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('放弃本机待发'));
      await _drain(
        tester,
        () =>
            find.text('放弃本机待发').evaluate().isEmpty &&
            find.text('发送').evaluate().isNotEmpty &&
            find.text('保存中').evaluate().isEmpty,
      );
      expect(api.operations.length, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .readOnly,
        false,
      );
    });
  });
  testWidgets('旧详情切换身份后隐藏原草稿并停止发送，不将其归给新CID', (tester) async {
    await _check(tester, () async {
      final api = _Api()..failSend = true;
      final user = _User();
      addTearDown(api.close);
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: user,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => find.text('暂无评论').evaluate().isNotEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '原账号私有待发',
      );
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(tester, () => find.text('重试发送').evaluate().isNotEmpty);
      user.cid = 'CN220-CTZN2-100000098-2026';
      Notifications.instance.invalidate();
      await _drain(
        tester,
        () => find.text('评论身份已变化，请重新打开详情').evaluate().isNotEmpty,
      );
      expect(find.text('原账号私有待发'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .readOnly,
        isTrue,
      );
      expect(api.operations.length, 1);
      final saved = await tester.runAsync(
        () => SocialIsar.instance.read(
          (db) => db.collection<social_store.Reply>().getByCidNumberPostId(
            _cid,
            'post',
          ),
        ),
      );
      expect(saved?.pendingData, contains('原账号私有待发'));
      final foreign = await tester.runAsync(
        () => SocialIsar.instance.read(
          (db) => db.collection<social_store.Reply>().getByCidNumberPostId(
            user.cid,
            'post',
          ),
        ),
      );
      expect(foreign, isNull);
    });
  });
  testWidgets('本机缓存恢复在途切换身份也终止旧详情，不停留在加载态', (tester) async {
    await _check(tester, () async {
      final user = _User(), api = _Api(), release = Completer<void>();
      addTearDown(api.close);
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: user,
      );
      var restored = false, held = false, released = false;
      unawaited(Notifications.instance.restore().then((_) => restored = true));
      await _drain(tester, () => restored);
      await tester.runAsync(() => SocialIsar.instance.read((_) async => null));
      unawaited(
        SocialIsar.instance
            .read<void>((_) async {
              held = true;
              await release.future;
            })
            .then((_) => released = true),
      );
      await _drain(tester, () => held);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Comments(
                  postId: 'post',
                  ownerCid: _cid,
                  api: api,
                  sessionProvider: _Sessions(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        user.cid = 'CN220-CTZN2-100000098-2026';
        Notifications.instance.invalidate();
        await _drain(
          tester,
          () => find.text('评论身份已变化，请重新打开详情').evaluate().isNotEmpty,
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(api.reads, 0);
      } finally {
        release.complete();
        await _drain(tester, () => released);
      }
    });
  });
  for (final remove in [false, true]) {
    testWidgets('旧刷新不能覆盖已完成${remove ? '删除' : '发送'}，只补取一次', (tester) async {
      await _check(tester, () async {
        final api = _Api(), stale = Completer<Map<String, dynamic>>();
        addTearDown(api.close);
        Map<String, dynamic> page(bool changed) => {
          'is_ok': true,
          'comments': remove
              ? [
                  _comment(
                    replyText: changed ? '' : '旧正文',
                    state: changed ? 'deleted' : 'active',
                  ),
                ]
              : changed
              ? [_comment(replyText: '新发送')]
              : <Object>[],
          'next_cursor': null,
        };
        api.onRead = (n) async => n == 2 ? await stale.future : page(n > 2);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Comments(
                  postId: 'post',
                  ownerCid: _cid,
                  api: api,
                  sessionProvider: _Sessions(),
                ),
              ),
            ),
          ),
        );
        await _drain(
          tester,
          () =>
              api.reads == 1 &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.tap(find.byTooltip('刷新评论'));
        await _drain(tester, () => api.reads == 2);
        if (remove) {
          await tester.tap(find.byType(PopupMenuButton<String>).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('删除'));
          await _drain(tester, () => find.text('评论已删除').evaluate().isNotEmpty);
        } else {
          await tester.enterText(
            find.byKey(const ValueKey('comment-input')),
            '新发送',
          );
          await tester.tap(find.byKey(const ValueKey('comment-send')));
          await _drain(
            tester,
            () =>
                find.text('发送').evaluate().isNotEmpty &&
                api.operations.length == 1,
          );
        }
        stale.complete(page(false));
        await _drain(
          tester,
          () =>
              api.reads == 3 &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text(remove ? '评论已删除' : '新发送'), findsOneWidget);
        expect(find.text('旧正文'), findsNothing);
        expect(api.reads, 3);
      });
    });
  }
  testWidgets('服务端已提交但本机完成保存失败仍保留原操作ID和正文', (tester) async {
    await _check(tester, () async {
      final api = _Api();
      addTearDown(api.close);
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
                cacheWriter:
                    (cid, post, page, pending, {required isCurrent}) async {
                      if (fail &&
                          pending == null &&
                          api.operations.isNotEmpty) {
                        throw StateError('synthetic completion write failure');
                      }
                      await SocialIsar.instance.writeTxn((db) async {
                        if (!isCurrent()) return;
                        final row =
                            await db
                                .collection<social_store.Reply>()
                                .getByCidNumberPostId(cid, post) ??
                            social_store.Reply();
                        row
                          ..cidNumber = cid
                          ..postId = post
                          ..pageData = page
                          ..pendingData = pending;
                        await db.collection<social_store.Reply>().put(row);
                      });
                    },
              ),
            ),
          ),
        ),
      );
      await _drain(tester, () => find.text('暂无评论').evaluate().isNotEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '原操作正文',
      );
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(tester, () => find.text('重试发送').evaluate().isNotEmpty);
      expect(api.operations.length, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .controller!
            .text,
        '原操作正文',
      );
      final saved = await tester.runAsync(
        () => SocialIsar.instance.read(
          (db) => db.collection<social_store.Reply>().getByCidNumberPostId(
            _cid,
            'post',
          ),
        ),
      );
      expect(saved?.pendingData, contains(api.operations.single));
      fail = false;
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await _drain(tester, () => find.text('发送').evaluate().isNotEmpty);
      expect(api.operations.length, 2);
      expect(api.operations.toSet().length, 1);
      final completed = await tester.runAsync(
        () => SocialIsar.instance.read(
          (db) => db.collection<social_store.Reply>().getByCidNumberPostId(
            _cid,
            'post',
          ),
        ),
      );
      expect(completed?.pendingData, isNull);
    });
  });
  testWidgets('首次身份恢复暂时失败后刷新会重新恢复并启用原评论入口', (tester) async {
    await _check(tester, () async {
      final user = _User()..fail = true, api = _Api();
      addTearDown(api.close);
      Notifications.instance.configure(
        api: api,
        sessions: _Sessions(),
        user: user,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Comments(
                postId: 'post',
                ownerCid: _cid,
                api: api,
                sessionProvider: _Sessions(),
              ),
            ),
          ),
        ),
      );
      await _drain(
        tester,
        () => find.text('评论暂时不可用，请刷新重试').evaluate().isNotEmpty,
      );
      expect(api.reads, 0);
      user.fail = false;
      await tester.tap(find.byTooltip('刷新评论'));
      await _drain(tester, () => find.text('暂无评论').evaluate().isNotEmpty);
      expect(api.reads, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .readOnly,
        isFalse,
      );
    });
  });
}
