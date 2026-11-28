// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'package:chat/compose/panel.dart';
import 'package:chat/compose/sticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证私聊功能动作及群聊转账和通话限制。

void _registerComposerActionPanel() {
  testWidgets('direct chat exposes seven actions', (tester) async {
    final actions = <ChatComposerAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComposerActionPanel(isGroup: false, onAction: actions.add),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNWidgets(7));
    await tester.tap(find.byKey(const ValueKey('chat-action-gallery')));
    expect(actions, [ChatComposerAction.gallery]);
  });

  testWidgets('group chat hides transfer and disables calls', (tester) async {
    final actions = <ChatComposerAction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComposerActionPanel(isGroup: true, onAction: actions.add),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('chat-action-transfer')), findsNothing);
    final callButton = tester.widget<InkWell>(
      find.byKey(const ValueKey('chat-action-videoCall')),
    );
    expect(callButton.onTap, isNull);
    expect(actions, isEmpty);
  });
}

// 验证贴纸分类呈现及包和贴纸标识回调。

void _registerStickerPanel() {
  testWidgets('点选贴纸回调 (packId, stickerId)', (tester) async {
    String? pickedPack;
    String? pickedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StickerPanel(
            onPick: (packId, stickerId) {
              pickedPack = packId;
              pickedId = stickerId;
            },
          ),
        ),
      ),
    );
    await tester.pump(); // 不 settle:Image.asset 异步解码不阻塞交互

    // 首个分类(表情)默认展示,点第一个贴纸 grinning_face。
    await tester.tap(find.byKey(const ValueKey('sticker-grinning_face')));
    await tester.pump();

    expect(pickedPack, StickerPack.packId);
    expect(pickedId, 'grinning_face');
  });

  testWidgets('渲染四个分类 Tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StickerPanel(onPick: (_, _) {})),
      ),
    );
    await tester.pump();

    expect(find.text('表情'), findsOneWidget);
    expect(find.text('手势'), findsOneWidget);
    expect(find.text('爱心'), findsOneWidget);
    expect(find.text('庆祝'), findsOneWidget);
  });
}

void main() {
  group(
    "conversation/composer_action_panel_test",
    _registerComposerActionPanel,
  );
  group("conversation/sticker_panel_test", _registerStickerPanel);
}
