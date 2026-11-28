// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:convert';

import 'package:citizen_square/article/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证规范Delta、字号和登记字体的真实只读渲染。

void _registerArticleRichTextView() {
  testWidgets('字体真实登记名与消费者文本样式一致', (tester) async {
    final manifest = (jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List).cast<Map>();
    for (final entry in {
      'kaiti': 'LXGWWenKaiLite',
      'jinglei': 'FZJingLeiS',
    }.entries) {
      final family = 'packages/citizen_assets/${entry.value}';
      expect(manifest.where((row) => row['family'] == family), hasLength(1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArticleRichTextView(
              delta: [
                {
                  'insert': '字体正文',
                  'attributes': {'font': entry.key},
                },
                {'insert': '\n'},
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final families = <String?>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text?.contains('字体正文') == true) {
            families.add(span.style?.fontFamily);
          }
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }
      }

      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        collect(rich.text);
      }
      expect(families, [family]);
    }
  });
  testWidgets('只读文章富文本渲染规范 Delta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleRichTextView(
            delta: [
              {
                'insert': '静蕾体正文内容满足十字',
                'attributes': {'font': 'jinglei', 'color': 'primary'},
              },
              {'insert': '\n'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('五档规范字号按14至24像素真实渲染', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArticleRichTextView(
            delta: [
              {
                'insert': '小',
                'attributes': {'size': 'small'},
              },
              {
                'insert': '正文',
                'attributes': {'size': 'body'},
              },
              {
                'insert': '大',
                'attributes': {'size': 'large'},
              },
              {
                'insert': '副标题',
                'attributes': {'size': 'subtitle'},
              },
              {
                'insert': '标题',
                'attributes': {'size': 'title'},
              },
              {'insert': '\n'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final sizes = <String, double?>{};
    void collect(InlineSpan span) {
      if (span case TextSpan(:final text, :final style, :final children)) {
        if (text != null && text.isNotEmpty) sizes[text] = style?.fontSize;
        for (final child in children ?? const <InlineSpan>[]) {
          collect(child);
        }
      }
    }

    for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
      collect(richText.text);
    }
    expect(sizes['小'], 14);
    expect(sizes['正文'], 16);
    expect(sizes['大'], 18);
    expect(sizes['副标题'], 20);
    expect(sizes['标题'], 24);
  });
}

// 验证文章Delta样式白名单、规范换行及字号编辑。

void _registerArticleSectionEditor() {
  test('资源包字体仅在Quill消费侧限定包名，持久协议不变', () {
    for (final entry in {
      'kaiti': 'LXGWWenKaiLite',
      'jinglei': 'FZJingLeiS',
    }.entries) {
      final controller = articleQuillController([
        {
          'insert': '字体',
          'attributes': {'font': entry.key},
        },
        {'insert': '\n'},
      ]);
      addTearDown(controller.dispose);
      expect(
        controller.document.toDelta().toJson().first['attributes']['font'],
        'packages/citizen_assets/${entry.value}',
      );
      expect(articleControllerDelta(controller).first['attributes'], {
        'font': entry.key,
      });
    }
  });
  group('文章 Delta 规范化', () {
    test('保留开放样式并删除任意值、链接和媒体嵌入', () {
      final normalized = normalizeArticleDelta([
        {
          'insert': '规范文字',
          'attributes': {
            'bold': true,
            'font': 'jinglei',
            'size': 99,
            'color': '#123456',
            'link': 'https://invalid.test',
          },
        },
        {
          'insert': {'image': 'x'},
        },
        const {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);
      expect(normalized, [
        {
          'insert': '规范文字',
          'attributes': {'bold': true, 'font': 'jinglei'},
        },
        const {
          'insert': '\n',
          'attributes': {'align': 'center'},
        },
      ]);
    });

    test('块格式只留在换行符并始终补规范结尾', () {
      expect(
        normalizeArticleDelta([
          const {
            'insert': '正文',
            'attributes': {'list': 'bullet'},
          },
        ]),
        [
          const {'insert': '正文'},
          const {'insert': '\n'},
        ],
      );
    });

    test('纯文本按 Unicode 内容提取', () {
      expect(
        articleDeltaPlainText([
          const {'insert': '你好🙂'},
          const {'insert': '\n'},
        ]),
        '你好🙂',
      );
    });
  });

  testWidgets('字号菜单把选中文字写为规范标题字号', (tester) async {
    final controller = articleQuillController([
      const {'insert': '规范文字'},
      const {'insert': '\n'},
    ]);
    addTearDown(controller.dispose);
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArticleRichTextToolbar(controller: controller)),
      ),
    );

    await tester.tap(find.byIcon(Icons.format_size));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标题'));
    await tester.pumpAndSettle();

    expect(articleControllerDelta(controller), [
      const {
        'insert': '规范文字',
        'attributes': {'size': 'title'},
      },
      const {'insert': '\n'},
    ]);
  });
}

void main() {
  group("article_rich_text_view_test", _registerArticleRichTextView);
  group("compose/article_section_editor_test", _registerArticleSectionEditor);
}
