// 验证金额和CID输入展示。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:citizen_system/format.dart';
import 'package:flutter/material.dart';

void main() {
  group('amount_format_thousands_test', _registerAmount);
  group('identity_cid_display_test', _registerCid);
  group('identity_cid_selectable_text_test', _registerSelection);
}

// 验证金额千分位编辑、光标和非法小数输入保留。

void _registerAmount() {
  group('ThousandSeparatorFormatter', () {
    test('输入插入千分位后光标仍在末尾', () {
      final value = ThousandSeparatorFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1234.50',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(value.text, '1,234.50');
      expect(value.selection.baseOffset, 8);
    });
    test('中间插入数字后光标跟随有效字符', () {
      final value = ThousandSeparatorFormatter().formatEditUpdate(
        const TextEditingValue(
          text: '1,234.50',
          selection: TextSelection.collapsed(offset: 2),
        ),
        const TextEditingValue(
          text: '1,9234.50',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(value.text, '19,234.50');
      expect(value.selection.baseOffset, 2);
    });
    test('非法字符与超出小数位的输入保留原值', () {
      const old = TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 5),
      );
      final formatter = ThousandSeparatorFormatter();
      for (final text in ['12x', '12.345']) {
        expect(
          formatter.formatEditUpdate(old, TextEditingValue(text: text)),
          same(old),
        );
      }
      expect(
        formatter.formatEditUpdate(old, TextEditingValue.empty),
        same(TextEditingValue.empty),
      );
    });
  });
}

// 验证CID显示缩写、标签规范及完整与部分选区复制。

void _registerCid() {
  const full = 'GZ018-CREGM-159197206-2026';
  const short = 'GZ018-CREGM-159197206';
  test(
    'display only hides the final CID year and normalizes system labels',
    () {
      expect(formatIdentityCidText(full), short);
      expect(identityCidUiText('CID编号'), identityCidLabel);
      expect(identityCidReviewText('CID编号', full), short);
      expect(identityCidReviewText('姓名', full), full);
      expect(full, 'GZ018-CREGM-159197206-2026');
      expect(formatIdentityCidText(short), short);
      expect(identityCidFieldText('remark', full), full);
      expect(identityCidFieldText('actor_cid_number', full), short);
      expect(identityCidFieldText('admins', '张三 / $full'), '张三 / $short');
      expect(
        formatIdentityCidText('CN001-NATP4-123456789-10000'),
        'CN001-NATP4-123456789',
      );
      for (final other in [
        '2026-11-22',
        'personal-account:0x1234',
        '0xabcdef',
        'GZ018-CREGM-159197206-20261234567',
      ]) {
        expect(formatIdentityCidText(other), other);
      }
      expect(
        identityCidUiText('公民CID号 / 居民CID号 / 机构CID号 / 身份ID / 公民号'),
        '身份CID号 / 身份CID号 / 身份CID号 / 身份CID号 / 身份CID号',
      );
    },
  );
  test(
    'selection copying restores full identifiers and preserves partial selection',
    () {
      expect(identityCidSelectionText(full, 0, short.length), full);
      expect(identityCidSelectionText(full, 0, 5), 'GZ018');
      final other = full.replaceFirst('2026', '2036');
      final original = '甲：$full；乙：$other';
      final display = '甲：$short；乙：$short';
      expect(identityCidSelectionText(original, 0, display.length), original);
      expect(
        identityCidSelectionText(original, 2 + short.length, display.length),
        '；乙：$other',
      );
    },
  );
}

// 验证可选择CID通过键盘和工具栏复制完整原值。

void _registerSelection() {
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
