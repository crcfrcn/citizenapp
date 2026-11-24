// 验证可选择CID通过键盘和工具栏复制完整原值。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/identity_cid_selectable_text.dart';

void main() {
  testWidgets(
    'short visible CID copies the full original via keyboard and toolbar',
    (tester) async {
      const full = 'GZ018-CREGM-159197206-2026';
      const shown = 'GZ018-CREGM-159197206';
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: IdentityCidSelectableText(full)),
        ),
      );
      expect(find.text(shown), findsOneWidget);
      expect(find.text(full), findsNothing);
      await tester.tap(find.byType(SelectableText));
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      state.userUpdateTextEditingValue(
        state.textEditingValue.copyWith(
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: shown.length,
          ),
        ),
        SelectionChangedCause.keyboard,
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, full);
      copied = null;
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final toolbar =
          selectable.contextMenuBuilder!(
                tester.element(find.byType(SelectableText)),
                state,
              )
              as AdaptiveTextSelectionToolbar;
      toolbar.buttonItems!
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pump();
      expect(copied, full);
      expect(state.textEditingValue.text, shown);
    },
  );
}
