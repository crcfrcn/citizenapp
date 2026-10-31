import 'dart:async';

import 'package:citizen_square/feed/square_home_page.dart';
import 'package:citizen_square/feed/square_feed_tabs.dart';
import 'package:citizen_square/feed/square_tab_order_store.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_account/identity/square_identity_state.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/notifications.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/social_isar.dart';
import 'package:citizen_square/feed/square_notifications_page.dart';
import 'package:citizen_square/post/square_post_actions.dart';
import 'package:citizen_square/like/square_likes_strip.dart';
import 'package:citizen_square/like/square_likes_page.dart';
import 'package:citizen_square/comment/comments.dart';
import 'package:citizen_square/comment/square_comment_thread_page.dart';

import 'package:citizen_testing/isar_test_env.dart';

const cid = 'CN220-CTZN2-100000077-2026';
const peerCid = 'CN220-CTZN2-100000078-2026';
const thirdCid = 'CN220-CTZN2-100000079-2026';

class User implements CurrentUserContext {
  String currentCid = cid;
  int bindRev = 1;
  String get fixtureAccountId => '0x${(currentCid == cid ? '11' : '44') * 32}';
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      accountId: fixtureAccountId,
      ss58Address: 'synthetic',
      name: '测试',
      walletIndex: 0,
      accountIndex: 0,
      isDefault: true,
      createdAtMillis: BigInt.one,
      signMode: CitizenWalletSignMode.hot,
    ),
    binding: IdentityBinding(
      genesisHash: '0x${'22' * 32}',
      cidNumber: currentCid,
      accountId: fixtureAccountId,
      bindRev: bindRev,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class Sessions implements SquareSessionProvider {
  Sessions(this.user);
  final User user;
  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: '33' * 32,
    sessionToken: 'test',
    cidNumber: user.currentCid,
    accountId: user.fixtureAccountId,
    bindRev: user.bindRev,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class Identity implements SquareIdentityService {
  @override
  Future<SquareIdentityState> loadCurrent() async =>
      const SquareIdentityState(accountId: 'synthetic', cidNumber: cid);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class Order extends SquareTabOrderStore {
  @override
  Future<List<SquareFeedKind>> read() async => List.of(SquareFeedKind.values);
  @override
  Future<void> write(List<SquareFeedKind> order) async {}
}

class Api extends SquareApiClient {
  Api(this.user);
  final User user;
  int sequence = 10;
  final notificationRequests = <String>[];
  final readOwners = <String>[];
  List<Map<String, dynamic>>? notificationItems;
  Future<Map<String, dynamic>> Function(SquareSession, int?, int?)?
  onNotifications;
  Completer<Map<String, dynamic>>? heldLikes;
  Completer<Map<String, dynamic>>? heldNotificationRead;
  Map<String, dynamic>? capturedNotificationRead;
  Completer<Map<String, dynamic>>? heldSquareRead;
  Map<String, dynamic>? capturedSquareRead;
  int feedCalls = 0;
  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    feedCalls++;
    return [];
  }

  int square = 3, tab = 3, post = 3, revision = 1, likes = 0;
  bool liked = false, offline = false;
  final reads = <Map<String, dynamic>>[];
  final requests = <String>[];
  Map<String, dynamic> get state => {
    'is_ok': true,
    'cid_number': user.currentCid,
    'bind_rev': user.bindRev,
    'notice_rev': revision,
    'square_unread': square,
    'notifications_unread': tab,
    'following_unread': 0,
    'interaction_unread': post,
    'through': sequence,
    'interaction_sequence': sequence,
    'member_rev': 0,
    'creator_rev': 0,
    'membergate': null,
    'creator': null,
  };
  Map<String, dynamic> interaction(String id) => {
    'post_id': id,
    'like_count': likes,
    'liked_by_me': liked,
    'comment_unread': post,
    'through': sequence,
  };
  @override
  Future<Map<String, dynamic>> fetchNotificationState({
    required SquareSession session,
  }) async => state;
  @override
  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    String? postId,
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) async {
    reads.add({'scope': scope, 'post_id': postId, 'through': through});
    readOwners.add(session.cidNumber);
    if (offline) throw StateError('offline');
    if (scope == 'square' && square > 0) {
      square = 0;
      revision++;
    }
    if (scope == 'notifications' && tab > 0) {
      tab = 0;
      revision++;
    }
    if (scope == 'post' && post > 0) {
      post = 0;
      revision++;
    }
    if (scope == 'notifications' && heldNotificationRead != null) {
      final held = heldNotificationRead!;
      heldNotificationRead = null;
      capturedNotificationRead = Map<String, dynamic>.of(state);
      return held.future;
    }
    if (scope == 'square' && heldSquareRead != null) {
      final held = heldSquareRead!;
      heldSquareRead = null;
      capturedSquareRead = Map<String, dynamic>.of(state);
      return held.future;
    }
    return state;
  }

  @override
  Future<Map<String, dynamic>> fetchNotifications({
    required SquareSession session,
    int? cursor,
    bool groupByPost = false,
    int? through,
  }) async {
    expectSync(groupByPost, isTrue);
    notificationRequests.add(session.cidNumber);
    if (onNotifications != null) {
      return onNotifications!(session, cursor, through);
    }
    return page();
  }

  Map<String, dynamic> page() => {
    'is_ok': true,
    'items':
        notificationItems ??
        [
          {
            'post_id': 'notification-post',
            'post_title': '有通知的内容',
            'post_excerpt': '正文',
            'notice_count': 3,
            'comment_unread': post,
          },
        ],
    'through': sequence,
    'next_cursor': null,
    'state': state,
  };

  @override
  Future<Map<String, dynamic>> fetchPostInteractions({
    required SquareSession session,
    required List<String> postIds,
  }) async => {
    'is_ok': true,
    'items': [for (final id in postIds) interaction(id)],
  };
  @override
  Future<Map<String, dynamic>> setLike({
    required SquareSession session,
    required String postId,
    required bool liked,
  }) async {
    this.liked = liked;
    likes = liked ? 1 : 0;
    return {'is_ok': true, 'state': interaction(postId)};
  }

  @override
  Future<Map<String, dynamic>> fetchLikes({
    required SquareSession session,
    required String postId,
    int? cursor,
    int limit = 20,
  }) async {
    final held = heldLikes;
    heldLikes = null;
    if (held != null) return held.future;
    return {
      'is_ok': true,
      'state': interaction(postId),
      'items': liked
          ? [
              {'cid_number': cid, 'display_name': '点赞公民', 'avatar_key': null},
            ]
          : [],
      'next_cursor': null,
    };
  }

  Map<String, dynamic> comment(
    String id,
    String text,
    int seq, {
    String? parent,
    String author = cid,
  }) => {
    'comment_id': id,
    'reply_seq': seq,
    'created_at': seq,
    'post_id': 'thread-post',
    'author_cid': author,
    'display_name': author == cid
        ? '本人'
        : author == peerCid
        ? '用户甲'
        : '用户乙',
    'reply_text': text,
    'reply_state': 'active',
    'reply_to': parent,
  };
  List<Map<String, dynamic>> get threadRows => [
    comment('root', '根评论', 1),
    comment('received', '收到的回复', 2, parent: 'root', author: peerCid),
    comment('third', '第三位参与者', 3, parent: 'received', author: thirdCid),
  ];
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
    requests.add('$mode:$thread');
    return {
      'is_ok': true,
      'comments': mode == 'thread' ? threadRows : [threadRows[1]],
      'next_cursor': null,
      'next_after': null,
    };
  }
}

Future<void> driveIo(WidgetTester tester, Future<dynamic> task) async {
  var done = false;
  Object? error;
  StackTrace? trace;
  task.then<void>(
    (_) {
      done = true;
    },
    onError: (Object e, StackTrace st) {
      error = e;
      trace = st;
      done = true;
    },
  );
  for (var attempt = 0; attempt < 100 && !done; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(done, isTrue, reason: '实际异步操作必须完成');
  if (error != null) Error.throwWithStackTrace(error!, trace!);
}

Future<void> pumpIo(WidgetTester tester) async {
  for (var round = 0; round < 8; round++) {
    await tester.pump();
    var reached = false;
    final barrier = UserIsar.instance.read<void>((_) async {
      reached = true;
    });
    for (var attempt = 0; attempt < 100 && !reached; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(reached, isTrue, reason: '实际数据库操作必须排空');
    await barrier;
  }
}

Future<void> drain(WidgetTester tester) async {
  await pumpIo(tester);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late Api api;
  late Sessions sessions;
  late User user;
  setUp(() async {
    await UserIsar.instance.db();
    await SocialIsar.instance.db();
    user = User();
    api = Api(user);
    sessions = Sessions(user);
    Notifications.instance.configure(api: api, sessions: sessions, user: user);
    await Notifications.instance.restore();
    await Notifications.instance.accept(api.state);
  });
  tearDown(() {
    Notifications.instance.stop();
    api.close();
  });
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      Provider<SquareApiClient>.value(value: api),
      Provider<SquareSessionProvider>.value(value: sessions),
      Provider<CurrentUserContext>.value(value: user),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
  test('三级清读请求范围独立，离线内容级意图持久化并按原范围重放', () async {
    final n = Notifications.instance;
    await n.read(owner: n.scope, scope: 'square', through: 10);
    expect([n.unread, n.notificationUnread], [0, 3]);
    await n.read(owner: n.scope, scope: 'notifications', through: 10);
    expect([n.unread, n.notificationUnread, api.post], [0, 0, 3]);
    api.offline = true;
    await n.read(owner: n.scope, scope: 'post', postId: 'p', through: 10);
    final saved = await UserIsar.instance.read(
      (db) => db.collection<Notice>().getByCidNumber(cid),
    );
    final intent = (jsonDecode(saved!.pendingData!) as List).single as Map;
    expect(intent['scope'], 'post');
    expect(intent['post_id'], 'p');
    n.invalidate();
    api.offline = false;
    await n.calibrate(force: true);
    expect(api.reads.last, {'scope': 'post', 'post_id': 'p', 'through': 10});
    expect(api.post, 0);
    expect(n.unread, 0);
  });
  for (final scopes in [
    ['square', 'notifications', 'post'],
    ['square', 'post', 'notifications'],
    ['notifications', 'square', 'post'],
    ['notifications', 'post', 'square'],
    ['post', 'square', 'notifications'],
    ['post', 'notifications', 'square'],
  ]) {
    test('三级独立清读顺序 ${scopes.join(' → ')}，只提交并清除对应范围', () async {
      final n = Notifications.instance;
      final expected = {'square': 3, 'notifications': 4, 'post': 5};
      api.tab = 4;
      api.post = 5;
      api.revision++;
      await n.accept(api.state);
      for (final scope in scopes) {
        expect(
          await n.read(
            owner: n.scope,
            scope: scope,
            postId: scope == 'post' ? 'notification-post' : null,
            through: 10,
          ),
          isTrue,
        );
        expected[scope] = 0;
        expect(
          [n.unread, n.notificationUnread, api.post],
          [expected['square'], expected['notifications'], expected['post']],
        );
        expect(api.reads.last, {
          'scope': scope,
          'post_id': scope == 'post' ? 'notification-post' : null,
          'through': 10,
        });
      }
      expect(api.reads, hasLength(3));
    });
  }
  testWidgets('通知页按内容显示，只清通知层，进入内容仍保留正确快照', (tester) async {
    String? opened;
    int? captured;
    await tester.pumpWidget(
      wrap(
        SquareNotificationsPage(
          api: api,
          sessions: sessions,
          onOpenPost: (id, through) async {
            opened = id;
            captured = through;
          },
        ),
      ),
    );
    await drain(tester);
    expect(find.text('有通知的内容'), findsOneWidget);
    expect(api.tab, 0);
    expect(api.square, 3);
    expect(api.post, 3);
    expect(api.reads.every((r) => r['scope'] == 'notifications'), isTrue);
    await tester.tap(find.text('有通知的内容'));
    await tester.pump();
    expect(opened, 'notification-post');
    expect(captured, 10);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('点赞、总数、头像和更多列表使用同一真实操作状态', (tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            const SquarePostActions(postId: 'like-post'),
            SquareLikesStrip(
              postId: 'like-post',
              api: api,
              sessions: sessions,
              showLikeButton: false,
            ),
          ],
        ),
      ),
    );
    await drain(tester);
    await tester.tap(find.byTooltip('点赞'));
    await drain(tester);
    expect(api.likes, 1);
    expect(find.byTooltip('取消点赞'), findsOneWidget);
    expect(find.text('点赞 1'), findsOneWidget);
    await tester.tap(find.text('更多'));
    await drain(tester);
    expect(find.byType(SquareLikesPage), findsOneWidget);
    expect(find.text('点赞公民'), findsOneWidget);
    await tester.pageBack();
    await drain(tester);
    await tester.tap(find.byTooltip('取消点赞'));
    await drain(tester);
    expect(api.likes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('点击评论打开该讨论串，包含多位参与者并按时间展示', (tester) async {
    await tester.pumpWidget(
      wrap(
        Comments(
          postId: 'thread-post',
          api: api,
          sessionProvider: sessions,
          ownerCid: cid,
        ),
      ),
    );
    await drain(tester);
    await tester.tap(find.text('收到的回复'));
    await drain(tester);
    expect(find.byType(SquareCommentThreadPage), findsOneWidget);
    expect(api.requests, contains('thread:received'));
    expect(find.text('根评论'), findsOneWidget);
    expect(find.text('第三位参与者'), findsOneWidget);
    expect(api.threadRows.map((r) => r['author_cid']).toSet(), {
      cid,
      peerCid,
      thirdCid,
    });
    for (final name in ['本人', '用户甲', '用户乙']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('收到的回复')).dy,
      lessThan(tester.getTopLeft(find.text('第三位参与者')).dy),
    );
    expect(
      tester.getTopLeft(find.text('根评论')).dy,
      lessThan(tester.getTopLeft(find.text('第三位参与者')).dy),
    );
    expect(
      api.reads.any(
        (r) => r['scope'] == 'square' || r['scope'] == 'notifications',
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
  testWidgets('广场仅在实际选中时清父层，重复点击当前子tab重新拉流', (tester) async {
    final selected = ValueNotifier<int>(1);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      wrap(
        SquareHomePage(
          identityService: Identity(),
          feedSource: api,
          sessionProvider: sessions,
          tabOrderStore: Order(),
          selectedTab: selected,
        ),
      ),
    );
    await drain(tester);
    expect(api.square, 3);
    expect(api.tab, 3);
    expect(api.post, 3);
    selected.value = 0;
    await drain(tester);
    expect(api.square, 0);
    expect(api.tab, 3);
    expect(api.post, 3);
    expect(
      tester
          .widget<SquareFeedTabs>(find.byType(SquareFeedTabs))
          .notificationsUnread,
      3,
    );
    final calls = api.feedCalls;
    await tester.tap(find.text('推荐'));
    await drain(tester);
    expect(api.feedCalls, calls + 1);
    await tester.tap(find.text('互动'));
    await drain(tester);
    expect(api.tab, 0);
    expect(api.post, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
  for (final hidden in [false, true]) {
    testWidgets('广场清读在途收到新事件，${hidden ? '隐藏期间保留角标，返回后' : '可见时'}补清新上界且不清另外两级', (
      tester,
    ) async {
      final selected = ValueNotifier<int>(0);
      addTearDown(selected.dispose);
      final held = Completer<Map<String, dynamic>>();
      api.heldSquareRead = held;
      await tester.pumpWidget(
        wrap(
          SquareHomePage(
            identityService: Identity(),
            feedSource: api,
            sessionProvider: sessions,
            tabOrderStore: Order(),
            selectedTab: selected,
          ),
        ),
      );
      await pumpIo(tester);
      expect(api.capturedSquareRead, isNotNull);
      if (hidden) selected.value = 1;
      api.revision++;
      api.sequence++;
      api.square = 1;
      api.tab = 4;
      api.post = 4;
      await driveIo(tester, Notifications.instance.accept(api.state));
      held.complete(api.capturedSquareRead!);
      await drain(tester);
      if (hidden) {
        expect(Notifications.instance.unread, 1);
        expect(api.reads, hasLength(1));
        selected.value = 0;
        await drain(tester);
      }
      expect(api.reads, [
        {'scope': 'square', 'post_id': null, 'through': 10},
        {'scope': 'square', 'post_id': null, 'through': 11},
      ]);
      expect(
        [
          Notifications.instance.unread,
          Notifications.instance.notificationUnread,
          api.post,
        ],
        [0, 4, 4],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester);
    });
  }
  for (final staleError in [false, true]) {
    testWidgets('广场清读切账号不等待旧请求，迟到${staleError ? '错误' : '回执'}不覆盖新账号', (
      tester,
    ) async {
      final held = Completer<Map<String, dynamic>>();
      api.heldSquareRead = held;
      await tester.pumpWidget(
        wrap(
          SquareHomePage(
            identityService: Identity(),
            feedSource: api,
            sessionProvider: sessions,
            tabOrderStore: Order(),
          ),
        ),
      );
      await pumpIo(tester);
      final old = api.capturedSquareRead!;
      user.currentCid = peerCid;
      api.revision = 1;
      api.square = 2;
      api.tab = 4;
      api.post = 5;
      Notifications.instance.invalidate();
      await driveIo(tester, Notifications.instance.accept(api.state));
      await drain(tester);
      expect(held.isCompleted, isFalse);
      expect(api.readOwners, [cid, peerCid]);
      expect(
        [
          Notifications.instance.unread,
          Notifications.instance.notificationUnread,
          api.post,
        ],
        [0, 4, 5],
      );
      if (staleError) {
        held.completeError(StateError('旧账号清读失败'));
      } else {
        held.complete(old);
      }
      await drain(tester);
      expect(api.readOwners, [cid, peerCid]);
      expect(Notifications.instance.cidNumber, peerCid);
      expect(
        [
          Notifications.instance.unread,
          Notifications.instance.notificationUnread,
          api.post,
        ],
        [0, 4, 5],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester);
    });
  }
  testWidgets('点赞期间迟到的头像列表不能覆盖新数量', (tester) async {
    final held = Completer<Map<String, dynamic>>();
    api.heldLikes = held;
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            const SquarePostActions(postId: 'race-like'),
            SquareLikesStrip(
              postId: 'race-like',
              api: api,
              sessions: sessions,
              showLikeButton: false,
            ),
          ],
        ),
      ),
    );
    await drain(tester);
    await tester.tap(find.byTooltip('点赞'));
    await drain(tester);
    expect(api.likes, 1);
    held.complete({
      'is_ok': true,
      'items': [],
      'next_cursor': null,
      'state': {'post_id': 'race-like', 'like_count': 0, 'liked_by_me': false},
    });
    await drain(tester);
    expect(find.text('点赞 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
  testWidgets('直接打开文章详情的已点赞状态可以正确取消', (tester) async {
    api.likes = 1;
    api.liked = true;
    await tester.pumpWidget(
      wrap(
        SquareLikesStrip(postId: 'article-only', api: api, sessions: sessions),
      ),
    );
    await drain(tester);
    expect(find.byTooltip('取消点赞'), findsOneWidget);
    await tester.tap(find.byTooltip('取消点赞'));
    await drain(tester);
    expect(api.likes, 0);
    expect(find.text('点赞 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
  testWidgets('持久化通知为首项后真实加载通知；隐藏期间不刷新或清读，返回后分别清两级', (tester) async {
    await tester.runAsync(
      () => const SquareTabOrderStore().write([
        SquareFeedKind.notifications,
        ...SquareFeedKind.values.where(
          (kind) => kind != SquareFeedKind.notifications,
        ),
      ]),
    );
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    final home = SquareHomePage(
      identityService: Identity(),
      feedSource: api,
      sessionProvider: sessions,
      selectedTab: selected,
    );
    await tester.pumpWidget(
      wrap(
        ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, _) => IndexedStack(
            index: index,
            children: [home, const Text('其他底部页面')],
          ),
        ),
      ),
    );
    await drain(tester);
    expect(
      tester.widget<SquareFeedTabs>(find.byType(SquareFeedTabs)).order.first,
      SquareFeedKind.notifications,
    );
    expect(find.text('有通知的内容'), findsOneWidget);
    expect(find.byTooltip('互动'), findsNothing);
    expect(api.feedCalls, 0);
    expect(api.notificationRequests, isNotEmpty);
    expect([api.square, api.tab, api.post], [0, 0, 3]);
    selected.value = 1;
    await drain(tester);
    final requests = api.notificationRequests.length;
    api.reads.clear();
    api.revision++;
    api.sequence++;
    api.square = 1;
    api.tab = 1;
    api.post = 4;
    await driveIo(tester, Notifications.instance.accept(api.state));
    await drain(tester);
    expect(find.text('其他底部页面'), findsOneWidget);
    expect(api.notificationRequests.length, requests);
    expect(api.reads, isEmpty);
    expect([api.square, api.tab, api.post], [1, 1, 4]);
    selected.value = 0;
    await drain(tester);
    expect(api.notificationRequests.length, greaterThan(requests));
    expect([api.square, api.tab, api.post], [0, 0, 4]);
    expect(api.feedCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });

  testWidgets('通知请求在途切换底部tab，迟到响应不清读，重新显示才清读', (tester) async {
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    final held = Completer<Map<String, dynamic>>();
    final response = api.page();
    api.onNotifications = (session, cursor, through) => held.future;
    await tester.pumpWidget(
      wrap(
        ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (context, index, _) => IndexedStack(
            index: index,
            children: [
              SquareNotificationsPage(
                api: api,
                sessions: sessions,
                selectedTab: selected,
                onOpenPost: (_, _) async {},
              ),
              const Text('隐藏通知页'),
            ],
          ),
        ),
      ),
    );
    await pumpIo(tester);
    expect(api.notificationRequests, hasLength(1));
    selected.value = 1;
    await pumpIo(tester);
    held.complete(response);
    await drain(tester);
    expect(api.tab, 3);
    expect(api.reads, isEmpty);
    expect(api.notificationRequests, hasLength(1));
    api.onNotifications = null;
    selected.value = 0;
    await drain(tester);
    expect(api.tab, 0);
    expect(api.square, 3);
    expect(api.post, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });

  testWidgets('通知页后台收到事件不请求不清读，回前台补刷', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      wrap(
        SquareNotificationsPage(
          api: api,
          sessions: sessions,
          onOpenPost: (_, _) async {},
        ),
      ),
    );
    await drain(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final requests = api.notificationRequests.length;
    api.reads.clear();
    api.tab = 1;
    api.revision++;
    api.sequence++;
    await driveIo(tester, Notifications.instance.accept(api.state));
    await pumpIo(tester);
    expect(api.notificationRequests.length, requests);
    expect(api.reads, isEmpty);
    expect(api.tab, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await drain(tester);
    expect(api.notificationRequests.length, greaterThan(requests));
    expect(api.tab, 0);
    expect(api.post, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });

  for (final deletion in [false, true]) {
    testWidgets('通知列表在途${deletion ? '撤销最后通知' : '收到新事件'}时丢弃旧快照并补刷', (
      tester,
    ) async {
      final key = GlobalKey<SquareNotificationsPageState>();
      await tester.pumpWidget(
        wrap(
          SquareNotificationsPage(
            key: key,
            api: api,
            sessions: sessions,
            onOpenPost: (_, _) async {},
          ),
        ),
      );
      await drain(tester);
      final old = api.page(), held = Completer<Map<String, dynamic>>();
      var intercepted = false;
      api.onNotifications = (session, cursor, through) {
        if (!intercepted) {
          intercepted = true;
          return held.future;
        }
        return Future.value(api.page());
      };
      unawaited(key.currentState!.refresh());
      await pumpIo(tester);
      api.reads.clear();
      api.revision++;
      if (deletion) {
        api.notificationItems = [];
      } else {
        api.sequence++;
        api.tab = 1;
        api.post = 4;
        api.notificationItems = [
          {
            'post_id': 'new-post',
            'post_title': '新到的通知内容',
            'post_excerpt': '新内容',
            'notice_count': 1,
            'comment_unread': 1,
          },
        ];
      }
      await driveIo(tester, Notifications.instance.accept(api.state));
      await pumpIo(tester);
      held.complete(old);
      await drain(tester);
      expect(find.text('有通知的内容'), findsNothing);
      expect(find.text(deletion ? '暂无评论互动' : '新到的通知内容'), findsOneWidget);
      expect(api.notificationRequests.length, greaterThan(2));
      if (!deletion) {
        expect(api.reads, isNotEmpty);
        expect(
          api.reads.every(
            (r) => r['scope'] == 'notifications' && r['through'] == 11,
          ),
          isTrue,
        );
      }
      expect(api.square, 3);
      expect(api.post, deletion ? 3 : 4);
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester);
    });
  }

  testWidgets('在途重复刷新即使版本相同也补取，不丢弃用户刷新', (tester) async {
    final key = GlobalKey<SquareNotificationsPageState>();
    await tester.pumpWidget(
      wrap(
        SquareNotificationsPage(
          key: key,
          api: api,
          sessions: sessions,
          onOpenPost: (_, _) async {},
        ),
      ),
    );
    await drain(tester);
    final old = api.page(), held = Completer<Map<String, dynamic>>();
    var intercepted = false;
    api.onNotifications = (session, cursor, through) {
      if (!intercepted) {
        intercepted = true;
        return held.future;
      }
      return Future.value(api.page());
    };
    final before = api.notificationRequests.length;
    unawaited(key.currentState!.refresh());
    await pumpIo(tester);
    unawaited(key.currentState!.refresh());
    held.complete(old);
    await drain(tester);
    expect(api.notificationRequests.length, before + 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });

  for (final staleError in [false, true]) {
    testWidgets('同版本切账号不等待旧HTTP，迟到${staleError ? '错误' : '结果'}不覆盖新账号', (
      tester,
    ) async {
      final key = GlobalKey<SquareNotificationsPageState>();
      await tester.pumpWidget(
        wrap(
          SquareNotificationsPage(
            key: key,
            api: api,
            sessions: sessions,
            onOpenPost: (_, _) async {},
          ),
        ),
      );
      await drain(tester);
      final old = api.page(), held = Completer<Map<String, dynamic>>();
      var intercepted = false;
      api.onNotifications = (session, cursor, through) {
        if (session.cidNumber == cid && !intercepted) {
          intercepted = true;
          return held.future;
        }
        return Future.value(api.page());
      };
      unawaited(key.currentState!.refresh());
      await pumpIo(tester);
      final sameRevision = api.revision;
      user.currentCid = 'CN220-CTZN2-100000078-2026';
      api.tab = 3;
      api.square = 3;
      api.post = 3;
      api.notificationItems = [
        {
          'post_id': 'new-account-post',
          'post_title': '新账号的通知',
          'post_excerpt': '正文',
          'notice_count': 3,
          'comment_unread': 3,
        },
      ];
      final cached = Map<String, dynamic>.of(api.state)..remove('cid_number');
      await driveIo(
        tester,
        UserIsar.instance.writeTxn((db) async {
          await db.collection<Notice>().put(
            Notice()
              ..cidNumber = user.currentCid
              ..stateData = jsonEncode(cached)
              ..pendingData = '[]',
          );
        }),
      );
      Notifications.instance.invalidate();
      await driveIo(tester, Notifications.instance.restore());
      expect(Notifications.instance.noticeRev, sameRevision);
      await drain(tester);
      expect(held.isCompleted, isFalse);
      expect(api.notificationRequests, contains(user.currentCid));
      expect(find.text('新账号的通知'), findsOneWidget);
      expect(find.text('有通知的内容'), findsNothing);
      if (staleError) {
        held.completeError(StateError('旧账号HTTP失败'));
      } else {
        held.complete(old);
      }
      await drain(tester);
      expect(find.text('新账号的通知'), findsOneWidget);
      expect(find.text('互动读取失败，请下拉重试'), findsNothing);
      expect(api.readOwners.last, user.currentCid);
      await tester.pumpWidget(const SizedBox.shrink());
      await drain(tester);
    });
  }

  testWidgets('通知读取失败不清任何层级，明确重试后成功加载', (tester) async {
    api.onNotifications = (_, _, _) async => throw StateError('读取失败');
    await tester.pumpWidget(
      wrap(
        SquareNotificationsPage(
          api: api,
          sessions: sessions,
          onOpenPost: (_, _) async {},
        ),
      ),
    );
    await drain(tester);
    expect(find.text('互动读取失败，请下拉重试'), findsOneWidget);
    expect(api.reads, isEmpty);
    api.onNotifications = null;
    await tester.tap(find.text('互动读取失败，请下拉重试'));
    await drain(tester);
    expect(find.text('有通知的内容'), findsOneWidget);
    expect(api.tab, 0);
    expect(api.square, 3);
    expect(api.post, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
  testWidgets('清读回执在途收到新事件，旧回执不覆盖新计数且列表继续补刷', (tester) async {
    final held = Completer<Map<String, dynamic>>();
    api.heldNotificationRead = held;
    await tester.pumpWidget(
      wrap(
        SquareNotificationsPage(
          api: api,
          sessions: sessions,
          onOpenPost: (_, _) async {},
        ),
      ),
    );
    await pumpIo(tester);
    expect(api.capturedNotificationRead, isNotNull);
    api.revision++;
    api.sequence++;
    api.tab = 1;
    api.post = 4;
    api.notificationItems = [
      {
        'post_id': 'after-read',
        'post_title': '清读期间的新通知',
        'post_excerpt': '正文',
        'notice_count': 1,
        'comment_unread': 1,
      },
    ];
    await driveIo(tester, Notifications.instance.accept(api.state));
    held.complete(api.capturedNotificationRead!);
    await drain(tester);
    expect(find.text('清读期间的新通知'), findsOneWidget);
    expect(find.text('有通知的内容'), findsNothing);
    expect(
      api.reads
          .where((row) => row['scope'] == 'notifications')
          .map((row) => row['through'])
          .toList(),
      [10, 11],
    );
    expect([api.square, api.tab, api.post], [3, 0, 4]);
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  });
}
