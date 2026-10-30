import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_account/square_api_client.dart';

// 受保护请求统一在本地预检后使用当前会话的设备请求签名器，
// 缺失即抛「设备请求签名器缺失」。测试用固定假签名占位；MockClient 不校验签名头。
SquareSession _session() => const SquareSession(
  deviceId: testMlsDeviceId,
  sessionToken: 'sqs_test',
  cidNumber: "CN220-CTZN2-198805200-2026",
  bindRev: 1,
  accountId:
      '0x8888888888888888888888888888888888888888888888888888888888888888',
  expiresAt: 1800000000000,
  authenticateRequest: fakeMlsRequestHeaders,
);

void main() {
  TestCitizenSdkHarness();
  test('SquareApiClient 解析 Worker feed 内容和媒体元数据', () async {
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/8964/feed/recommended');
        expect(request.url.queryParameters['limit'], '20');
        expect(request.headers['authorization'], 'Bearer sqs_test');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(
          '''
          {
            "is_ok": true,
            "feed_kind": "recommended",
            "posts": [
              {
                "post_id": "sqp_001",
                "account_id": "0x0101010101010101010101010101010101010101010101010101010101010101",
                "cid_number": "CN001-CTZN-000000001-2026",
                "display_name": "林正华",
                "avatar_key": "profile/1111111111111111111111111111111111111111111111111111111111111111/avatar",
                "post_category": "campaign",
                "post_type": "document",
                "post_excerpt": "竞选公文摘要",
                "content_hash": "0x1111",
                "receipt_id": "sqr_001",
                "chain_block": 88,
                "published_at": 1800000000000,
                "post_state": "published",
                "media_items": [
                  {
                    "media_kind": "image",
                    "url": "https://media.crcfrcn.com/square/cid/posts/sqp_001/media/0/source.webp",
                    "preview_url": "https://media.crcfrcn.com/square/cid/posts/sqp_001/media/0/thumbnail.webp",
                    "byte_size": 1024,
                    "pixel_width": 1080,
                    "pixel_height": 1920
                  }
                ]
              }
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final posts = await client.fetchFeed(
      feedKind: SquareFeedKind.recommended,
      session: _session(),
    );

    expect(posts, hasLength(1));
    expect(posts.first.postCategory, SquarePostCategory.campaign);
    expect(posts.first.text, '竞选公文摘要');
    expect(posts.first.author.cidNumber, 'CN001-CTZN-000000001-2026');
    // 真数据：作者展示名与头像键随 feed 回传并解析。
    expect(posts.first.author.displayName, '林正华');
    expect(
      posts.first.author.avatarKey,
      'profile/1111111111111111111111111111111111111111111111111111111111111111/avatar',
    );
    expect(posts.first.chainBlock, 88);
    expect(posts.first.mediaItems.single.mediaKind, SquareMediaKind.image);
    expect(
      posts.first.mediaItems.single.url,
      'https://media.crcfrcn.com/square/cid/posts/sqp_001/media/0/source.webp',
    );
    expect(
      posts.first.mediaItems.single.previewUrl,
      'https://media.crcfrcn.com/square/cid/posts/sqp_001/media/0/thumbnail.webp',
    );
    expect(posts.first.mediaItems.single.byteSize, 1024);
    // 横竖屏所需宽高解析：高>宽 → 竖屏。
    expect(posts.first.mediaItems.single.isPortrait, isTrue);
  });

  test('SquareApiClient 详情接口读取全文并保留 Feed 作者资料', () async {
    final summary = SquarePost(
      postId: 'sqp_detail',
      author: const SquareAuthor(
        accountId: '0x0101010101010101010101010101010101010101010101010101010101010101',
        cidNumber: 'CN001-CTZN-000000001-2026',
        displayName: '林正华',
      ),
      postCategory: SquarePostCategory.normal,
      postType: SquarePostType.article,
      title: '文章标题标题标题',
      text: '列表摘要',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(1800000000000),
    );
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/8964/posts/sqp_detail');
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'post': {
              'post_id': 'sqp_detail',
              'account_id': summary.author.accountId,
              'cid_number': summary.author.cidNumber,
              'post_category': 'normal',
              'post_type': 'article',
              'content_hash': List<String>.filled(64, '1').join(),
              'receipt_id': 'sqr_detail',
              'chain_block': 88,
              'published_at': 1800000000000,
              'post_state': 'published',
              'media_items': [
                {
                  'media_kind': 'image',
                  'url': 'https://media.test/cover.jpg',
                  'pixel_width': 1920,
                  'pixel_height': 1080,
                },
              ],
            },
            'manifest': {
              'schema': 'citizenapp.square.post',
              'cid_number': summary.author.cidNumber,
              'post_type': 'article',
              'media_items': <Object>[],
              'post_title': '文章标题标题标题',
              'text': 'R2 规范全文',
              'content_sections': [
                {
                  'text_delta': [
                    {'insert': 'R2 规范全文满足十个字'},
                    {'insert': '\n'},
                  ],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final detail = await client.fetchPostDetail(
      session: _session(),
      summary: summary,
    );

    expect(detail.text, 'R2 规范全文');
    expect(detail.contentSections, hasLength(1));
    expect(detail.author.displayName, '林正华');
  });

  test('SquareApiClient 拒绝缺少必填首图的文章 Feed', () async {
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'is_ok': true,
            'feed_kind': 'recommended',
            'posts': [
              {
                'post_id': 'article_without_cover',
                'account_id': '0x0101010101010101010101010101010101010101010101010101010101010101',
                'post_category': 'normal',
                'post_type': 'article',
                'post_title': '缺少首图的非法文章',
                'excerpt': '这条数据不得作为正常文章进入动态流',
                'published_at': 1800000000000,
                'media_items': <Object>[],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.fetchFeed(
        feedKind: SquareFeedKind.recommended,
        session: _session(),
      ),
      throwsA(
        isA<SquareApiException>().having(
          (error) => error.message,
          'message',
          '文章首图缺失',
        ),
      ),
    );
  });

  test('SquareApiConfig 只允许HTTPS /api根，包括本机', () {
    expect(
      SquareApiConfig.normalizeBaseUrl('https://square.example/api/'),
      'https://square.example/api',
    );
    expect(
      SquareApiConfig.normalizeBaseUrl('https://127.0.0.1:8787/api/'),
      'https://127.0.0.1:8787/api',
    );
    for (final root in [
      'http://square.example/api',
      'http://localhost:8787/api',
      'ws://localhost:8787/api',
      'https://square.example',
      'https://square.example/square',
      'https://square.example/api?other=1',
      'https://square.example/api#other',
      'https://account@square.example/api',
    ]) {
      expect(
        () => SquareApiConfig.normalizeBaseUrl(root),
        throwsFormatException,
      );
    }
  });

  test('SquareApiClient prepareUpload 发送内容形态和额度声明', () async {
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/8964/uploads');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        expect(request.headers['authorization'], 'Bearer sqs_test');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('post_category'), isFalse);
        expect(body['post_type'], 'article');
        expect(body['title_length'], 12);
        expect(body['text_length'], 30000);
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'upload_id': 'squ_test',
            'post_id': 'sqp_test',
            'receipt_id': 'sqr_test',
            'expires_at': 1800000000000,
            'byte_size': 1024,
            'manifest': {
              'object_key': 'square/cid/posts/sqp_test/manifest.json',
              'upload_url':
                  'https://square.test/api/8964/uploads/squ_test/manifest',
            },
            'media_uploads': [
              for (final role in ['source', 'thumbnail'])
                {
                  'media_index': 0,
                  'object_role': role,
                  'object_key': 'square/cid/posts/sqp_test/media/0/$role.webp',
                  'upload': {
                    'http_method': 'PUT',
                    'url': 'https://upload.test/$role',
                    'expires_at': 1800000000000,
                    'headers': {
                      'content-type': 'image/webp',
                      'content-length': role == 'source' ? '1024' : '256',
                    },
                  },
                },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final prepared = await client.prepareUpload(
      session: _session(),
      postType: SquarePostType.article,
      titleLength: 12,
      textLength: 30000,
      contentHash: '11' * 32,
      manifestBytes: 512,
      mediaItems: const [
        SquareUploadMediaRequest(
          mediaKind: SquareMediaKind.image,
          byteSize: 1024,
          bodyHash: '1111111111111111111111111111111111111111111111111111111111111111',
          pixelWidth: 320,
          pixelHeight: 240,
          previewBytes: 256,
          previewHash: '2222222222222222222222222222222222222222222222222222222222222222',
        ),
      ],
    );

    expect(prepared.postId, 'sqp_test');
    expect(
      prepared.manifestUploadUrl,
      'https://square.test/api/8964/uploads/squ_test/manifest',
    );
    expect(prepared.mediaUploads.map((e) => (e.mediaIndex, e.objectRole)), [
      (0, 'source'),
      (0, 'thumbnail'),
    ]);
  });

  test('prepareUpload拒绝错源、错上传身份和带查询的manifest能力', () async {
    for (final capability in [
      'https://other.test/api/8964/uploads/squ_test/manifest',
      'https://square.test/api/8964/uploads/other/manifest',
      'https://square.test/api/8964/uploads/squ_test/manifest?token=other',
      'http://square.test/api/8964/uploads/squ_test/manifest',
    ]) {
      var calls = 0;
      final client = SquareApiClient(
        baseUrl: 'https://square.test/api',
        httpClient: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/8964/uploads');
          return http.Response(
            jsonEncode({
              'is_ok': true,
              'upload_id': 'squ_test',
              'post_id': 'sqp_test',
              'receipt_id': 'sqr_test',
              'expires_at': 1800000000000,
              'byte_size': 512,
              'manifest': {
                'object_key': 'square/cid/posts/sqp_test/manifest.json',
                'upload_url': capability,
              },
              'media_uploads': <Object>[],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.prepareUpload(
          session: _session(),
          postType: SquarePostType.document,
          titleLength: 0,
          textLength: 10,
          contentHash: '11' * 32,
          manifestBytes: 512,
          mediaItems: const [],
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    }
  });

  test('SquareApiClient 对 R2 临时 5xx 只重试当前文件上传', () async {
    final root = await Directory.systemTemp.createTemp('square_r2_retry_');
    final file = File('${root.path}/source.webp');
    await file.writeAsBytes(const [1, 2, 3, 4]);
    var attempts = 0;
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        attempts += 1;
        expect(request.method, 'PUT');
        expect(request.bodyBytes, const [1, 2, 3, 4]);
        return http.Response('', attempts == 1 ? 503 : 200);
      }),
    );
    try {
      await client.uploadMedia(
        session: _session(),
        upload: const SquarePreparedMediaUpload(
          mediaIndex: 0,
          objectRole: 'source',
          objectKey: 'square/cid/posts/sqp_test/media/0/source.webp',
          httpMethod: 'PUT',
          url: 'https://upload.test/source.webp',
          expiresAt: 1800000000000,
          headers: {'content-type': 'image/webp', 'content-length': '4'},
        ),
        byteSize: 4,
        filePath: file.path,
      );
      expect(attempts, 2);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('SquareApiClient deletePost 使用登录态删除指定内容', () async {
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/8964/posts/sqp_old');
        expect(request.headers['authorization'], 'Bearer sqs_test');
        return http.Response(
          jsonEncode({'is_ok': true, 'post_id': 'sqp_old'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await client.deletePost(session: _session(), postId: 'sqp_old');
  });

  test('SquareApiClient 严格解析本人副本原始字节并携带设备请求证明', () async {
    final manifestBytes = utf8.encode(
      jsonEncode({
        'schema': 'citizenapp.square.post',
        'cid_number': _session().cidNumber,
        'post_type': 'document',
        'text': '本人原始正文',
        'media_items': const <Object>[],
      }),
    );
    final contentHash = sha256.convert(manifestBytes).toString();
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/8964/posts/self');
        expect(request.url.queryParameters['limit'], '5');
        expect(request.headers['authorization'], 'Bearer sqs_test');
        expect(request.headers['x-mls-proof'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'posts': [
              {
                'post': {
                  'post_id': 'sqp_self',
                  'cid_number': _session().cidNumber,
                  'account_id': _session().accountId,
                  'post_category': 'normal',
                  'post_type': 'document',
                  'content_hash': contentHash,
                  'receipt_id': 'sqr_self',
                  'chain_block': 88,
                  'published_at': 1800000000000,
                  'post_state': 'published',
                },
                'content_hash': contentHash,
                'manifest_bytes_base64url': base64Url
                    .encode(manifestBytes)
                    .replaceAll('=', ''),
              },
            ],
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final page = await client.fetchSelfPublishedPostCopies(session: _session());

    expect(page.items.single.manifestBytes, orderedEquals(manifestBytes));
    expect(page.items.single.contentHash, contentHash);
    expect(page.items.single.publishedAt, 1800000000000);
    expect(page.nextCursor, isNull);
  });

  test('SquareApiClient 本人副本任一条字段漂移时拒绝整页', () async {
    final client = SquareApiClient(
      baseUrl: 'https://square.test/api',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'is_ok': true,
            'posts': [
              {
                'post': {
                  'post_id': 'sqp_wrong',
                  'cid_number': 'OTHER-CID',
                  'account_id': _session().accountId,
                  'post_category': 'normal',
                  'post_type': 'document',
                  'content_hash': '11' * 32,
                  'receipt_id': 'sqr_wrong',
                  'chain_block': 88,
                  'published_at': 1800000000000,
                  'post_state': 'published',
                },
                'content_hash': '11' * 32,
                'manifest_bytes_base64url': 'e30',
              },
            ],
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.fetchSelfPublishedPostCopies(session: _session()),
      throwsA(isA<SquareApiException>()),
    );
  });
}
