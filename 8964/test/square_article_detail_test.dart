// 验证文章帖子详情的权限、身份撤销、刷新和本人离线读取。

import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/social_isar.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_square/post/square_local_post_presenter.dart';
import 'package:citizen_square/post/square_post_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/article/square_article_detail_page.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_square/media/square_media_carousel.dart';
import 'package:citizen_square/article/article_rich_text_view.dart';

import 'package:citizen_testing/fake_profile.dart';

// 标题/正文实际出现才算加载完成；同时推进HTTP/SDK回包，不能用无限动画的settle判成功。
Future<void> _pumpArticle(WidgetTester tester) async {
  for (
    var attempt = 0;
    find.byType(ArticleRichTextView).evaluate().isEmpty && attempt < 50;
    attempt++
  ) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(find.byType(ArticleRichTextView), findsWidgets);
}

class _DetailSecurity extends Fake implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);
}

class _DetailSessions extends FakeSessionProvider {
  _DetailSessions() : super(fakeSession());
  SquareSession active = fakeSession();
  @override
  Future<String?> currentCitizenId() async => active.cidNumber;
  @override
  Future<SquareSession?> ensureSession() async => active;
}

class _DetailApi extends SquareApiClient {
  _DetailApi()
    : super(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"is_ok":true,"items":[]}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
  int calls = 0;
  Object error = const SquareApiException('denied', statusCode: 403);
  Completer<SquarePost>? pending;
  @override
  Future<SquarePost> fetchPostDetail({
    required SquareSession session,
    SquarePost? summary,
    String? postId,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    throw error;
  }
}

void main() {
  testWidgets('详情由服务端会员门禁拒绝，会员GET为0且不显示初始正文', (tester) async {
    var membershipRequests = 0;
    var detailRequests = 0;
    final api = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/membergate')) {
          membershipRequests++;
          fail('详情不应前置会员GET');
        }
        expect(request.url.path, '/api/8964/posts/p1');
        detailRequests++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'is_ok': false,
              'error_code': 'square_membergate_required',
              'message': '非会员禁止使用广场功能',
            }),
          ),
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SquareArticleDetailPage(
          post: samplePost(
            postType: SquarePostType.article,
            title: '不可显示的初始标题',
            text: '不可显示的初始正文',
          ),
          api: api,
          sessionProvider: FakeSessionProvider(fakeSession()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('文章加载失败：非会员禁止使用广场功能'), findsOneWidget);
    expect(find.text('不可显示的初始标题'), findsNothing);
    expect(find.textContaining('不可显示的初始正文'), findsNothing);
    expect(membershipRequests, 0);
    expect(detailRequests, 1);
  });

  for (final article in [false, true]) {
    Widget detail(
      SquarePost post,
      _DetailApi api,
      _DetailSessions sessions, {
      SquareDetailRead? initialRead,
    }) => article
        ? SquareArticleDetailPage(
            post: post,
            api: api,
            sessionProvider: sessions,
            initialRead: initialRead,
          )
        : SquarePostDetailPage(
            post: post,
            api: api,
            sessionProvider: sessions,
            initialRead: initialRead,
          );
    SquarePost content() => SquarePost(
      postId: 'p1',
      author: samplePost().author,
      postCategory: SquarePostCategory.normal,
      postType: article ? SquarePostType.article : SquarePostType.document,
      text: '已经获准读取的受保护正文',
      title: article ? '受保护标题' : null,
      publishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      contentSections: article
          ? [
              ArticleContentSection(
                textDelta: [
                  {'insert': '已经获准读取的受保护正文\n'},
                ],
              ),
            ]
          : [],
    );
    for (final status in [401, 403, 404, 503]) {
      testWidgets('${article ? "文章" : "动态"}刷新$status按拒绝或故障处理旧正文', (
        tester,
      ) async {
        final api = _DetailApi()
          ..error = SquareApiException('fixture', statusCode: status);
        final sessions = _DetailSessions();
        await tester.pumpWidget(
          MaterialApp(
            home: detail(
              content(),
              api,
              sessions,
              initialRead: SquareDetailRead(
                session: sessions.active,
                postId: 'p1',
                revision: null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.calls, 0); // 通知预读绑定相同，不重复GET。
        expect(
          find.textContaining('已经获准读取的受保护正文', findRichText: true),
          findsWidgets,
        );
        await tester.tap(find.byTooltip('刷新'));
        await tester.pumpAndSettle();
        expect(api.calls, 1);
        expect(
          find.textContaining('已经获准读取的受保护正文', findRichText: true),
          status == 503 ? findsWidgets : findsNothing,
        );
        final menu = tester.widget<PopupMenuButton>(
          find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
        );
        expect(menu.enabled, status == 503);
        if (status != 503) {
          api.error = const SquareApiException('offline', statusCode: 503);
          await tester.tap(find.text('重试'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('已经获准读取的受保护正文', findRichText: true),
            findsNothing,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('${article ? "文章" : "动态"}身份修订立即隐藏正文且丢弃迟到读取', (tester) async {
      final api = _DetailApi()..pending = Completer<SquarePost>();
      final sessions = _DetailSessions();
      final security = _DetailSecurity();
      await tester.pumpWidget(
        Provider<AccountSecurityService>.value(
          value: security,
          child: MaterialApp(
            home: detail(
              content(),
              api,
              sessions,
              initialRead: SquareDetailRead(
                session: sessions.active,
                postId: 'p1',
                revision: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, 0);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();
      sessions.active = fakeSession(cidNumber: 'CN002');
      security.revision.value++;
      await tester.pump();
      api.pending!.complete(content());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('已经获准读取的受保护正文', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('当前身份已变化'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      security.revision.dispose();
    });
    testWidgets('${article ? "文章" : "动态"}回前台先隐藏旧正文并复核拉黑', (tester) async {
      final api = _DetailApi()..pending = Completer<SquarePost>();
      final sessions = _DetailSessions()..active = fakeSession(cidNumber: 'CN002');
      await tester.pumpWidget(
        MaterialApp(
          home: detail(
            content(), api, sessions,
            initialRead: SquareDetailRead(
              session: sessions.active, postId: 'p1', revision: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final body = find.textContaining('已经获准读取的受保护正文', findRichText: true);
      expect(body, findsWidgets);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.calls, 1);
      expect(body, findsNothing);
      api.pending!.completeError(const SquareApiException('blocked', statusCode: 404));
      await tester.pumpAndSettle();
      expect(body, findsNothing);
    });
    testWidgets('${article ? "文章" : "动态"}通知预读不能跨身份复用', (tester) async {
      final api = _DetailApi(), sessions = _DetailSessions();
      await tester.pumpWidget(
        MaterialApp(
          home: detail(
            content(),
            api,
            sessions,
            initialRead: SquareDetailRead(
              session: fakeSession(cidNumber: 'CN002'),
              postId: 'p1',
              revision: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(
        find.textContaining('已经获准读取的受保护正文', findRichText: true),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  TestCitizenSdkHarness();
  useIsolatedIsar();
  // Isar使用真实异步IO；在Widget虚拟时钟启动前打开数据库，避免把未完成的打开任务带入tearDown。
  setUp(() async {
    await UserIsar.instance.db();
    await SocialIsar.instance.db();
  });
  for (final type in ['document', 'article']) {
    testWidgets('本人$type详情离线读取数据库，刷新失败保留正文', (tester) async {
      var requests = 0;
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schema': SquarePostStore.manifestSchema,
            'cid_number': fakeSession().cidNumber,
            'post_type': type,
            'text': '本地已保存的详情正文',
            if (type == 'article') 'post_title': '本地文章标题',
            if (type == 'article')
              'content_sections': [
                {
                  'text_delta': [
                    {'insert': '本地已保存的详情正文\n'},
                  ],
                },
              ],
            'media_items': type == 'article'
                ? [
                    {
                      'media_kind': 'image',
                      'file_name': 'cover.png',
                      'content_type': 'image/png',
                      'byte_size': 1,
                      'body_hash': 'a' * 64,
                    },
                  ]
                : [],
          }),
        ),
      );
      final local = SquareLocalPost(
        postId: 'local-detail',
        cidNumber: fakeSession().cidNumber,
        accountId: kOwner,
        postCategory: 'normal',
        postType: type,
        manifestBytes: bytes,
        contentHash: sha256.convert(bytes).toString(),
        receiptId: 'receipt-local',
        chainBlock: 1,
        publishedAt: 1000,
        postState: SquarePostStore.publishedState,
      );
      await tester.runAsync(() => const SquarePostStore().save(local));
      final post = const SquareLocalPostPresenter().present(local).post;
      final api = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((_) async {
          requests++;
          throw StateError('不应请求远端');
        }),
      );
      final wrongSession = FakeSessionProvider(null, citizenId: 'CN002');
      await tester.pumpWidget(
        MaterialApp(
          home: type == 'article'
              ? SquareArticleDetailPage(
                  post: post,
                  api: api,
                  sessionProvider: wrongSession,
                )
              : SquarePostDetailPage(
                  post: post,
                  api: api,
                  sessionProvider: wrongSession,
                ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('本地已保存的详情正文', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('只能读取当前用户的本地内容'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      // 无会话：普通阅读仍能完成；主动刷新失败应保留原正文。
      final session = FakeSessionProvider(
        null,
        citizenId: post.author.cidNumber,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: type == 'article'
              ? SquareArticleDetailPage(
                  post: post,
                  api: api,
                  sessionProvider: session,
                )
              : SquarePostDetailPage(
                  post: post,
                  api: api,
                  sessionProvider: session,
                ),
        ),
      );
      for (
        var i = 0;
        i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('本地已保存的详情正文', findRichText: true),
        findsWidgets,
      );
      expect(requests, 0);
      if (type == 'article') {
        // 正文先到达，封面读库仍可能在进行；等到缺图终态再刷新和销毁页面。
        for (
          var attempt = 0;
          attempt < 100 && find.text('本地尚未保存媒体').evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.text('本地尚未保存媒体'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(find.text('刷新失败，已保留本地内容'), findsOneWidget);
      expect(
        find.textContaining('本地已保存的详情正文', findRichText: true),
        findsWidgets,
      );
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('renders the article title and body', (tester) async {
    var detailRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SquareArticleDetailPage(
          post: samplePost(
            postType: SquarePostType.article,
            title: '标题X',
            text: '正文内容正文内容正文',
          ),
          api: SquareApiClient(
            baseUrl: 'https://square.test/api',
            httpClient: MockClient((request) async {
              expect(request.url.path.endsWith('/membergate'), isFalse);
              expect(request.url.path, '/api/8964/posts/p1');
              detailRequests++;
              return http.Response(
                '''{"is_ok":true,"post":{"post_id":"p1","account_id":"$kOwner","cid_number":"CN001-CTZN-000000001-2026","post_category":"normal","post_type":"article","post_title":"标题X","content_hash":"${List<String>.filled(64, '1').join()}","receipt_id":"sqr_1","chain_block":1,"published_at":1000,"post_state":"published",
                "post_visibility": "public","media_items":[{"media_kind":"image","url":"https://media.test/cover.jpg"}]},"manifest":{"schema":"citizenapp.square.post","cid_number":"CN001-CTZN-000000001-2026","post_type":"article","text":"正文内容正文内容正文","media_items":[],"post_title":"标题X","content_sections":[{"text_delta":[{"insert":"正文内容正文内容正文"},{"insert":"\\n"}]}]}}''',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
          sessionProvider: FakeSessionProvider(fakeSession()),
        ),
      ),
    );
    await _pumpArticle(tester);
    expect(detailRequests, 1);

    expect(find.text('标题X'), findsOneWidget);
    expect(find.byType(ArticleRichTextView), findsOneWidget);
  });

  testWidgets('公开文章按块保留多图轮播关系和多个视频', (tester) async {
    var detailRequests = 0;
    final hash = List<String>.filled(64, '2').join();
    await tester.pumpWidget(
      MaterialApp(
        home: SquareArticleDetailPage(
          post: samplePost(
            postType: SquarePostType.article,
            title: '图集文章',
            text: '这是满足十个字的正文内容',
          ),
          api: SquareApiClient(
            baseUrl: 'https://square.test/api',
            httpClient: MockClient((request) async {
              expect(request.url.path.endsWith('/membergate'), isFalse);
              expect(request.url.path, '/api/8964/posts/p1');
              detailRequests++;
              return http.Response(
                '''{"is_ok":true,"post":{"post_id":"p1","account_id":"$kOwner","cid_number":"CN001-CTZN-000000001-2026","post_category":"normal","post_type":"article","post_title":"图集文章","content_hash":"$hash","receipt_id":"sqr_2","chain_block":2,"published_at":1000,"post_state":"published",
                "post_visibility": "public","media_items":[{"media_kind":"image","url":"https://media.test/cover.jpg"},{"media_kind":"image","url":"https://media.test/1.jpg"},{"media_kind":"image","url":"https://media.test/2.jpg"},{"media_kind":"image","url":"https://media.test/3.jpg"},{"media_kind":"video","url":"https://media.test/1.m3u8","preview_url":"https://media.test/1.jpg"},{"media_kind":"video","url":"https://media.test/2.m3u8","preview_url":"https://media.test/2.jpg"}]},"manifest":{"schema":"citizenapp.square.post","cid_number":"CN001-CTZN-000000001-2026","post_type":"article","text":"这是满足十个字的正文内容","media_items":[],"post_title":"图集文章","content_sections":[{"text_delta":[{"insert":"图集前面的正文内容满足十字"},{"insert":"\\n"}],"gallery_media_indices":[1,2,3]},{"text_delta":[{"insert":"第一个视频正文内容满足十字"},{"insert":"\\n"}],"video_media_index":4},{"text_delta":[{"insert":"第二个视频正文内容满足十字"},{"insert":"\\n"}],"video_media_index":5}]}}''',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
          sessionProvider: FakeSessionProvider(fakeSession()),
        ),
      ),
    );
    await _pumpArticle(tester);
    expect(detailRequests, 1);

    expect(find.byType(SquareMediaCarousel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('square-media-carousel-dot-2')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNWidgets(2));
  });
}
