import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/feed/square_feed_tabs.dart';
import 'package:citizen_system/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  testWidgets('关注子 tab 有未读时显示红点数字', (tester) async {
    await tester.pumpWidget(
      wrap(
        SquareFeedTabs(
          selected: SquareFeedKind.recommended,
          followingUnread: 3,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('未读为 0 时不显示红点', (tester) async {
    await tester.pumpWidget(
      wrap(
        SquareFeedTabs(
          selected: SquareFeedKind.recommended,
          followingUnread: 0,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
  });

  testWidgets('未读超过 99 显示 99+', (tester) async {
    await tester.pumpWidget(
      wrap(
        SquareFeedTabs(
          selected: SquareFeedKind.recommended,
          followingUnread: 128,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('点击分类回调对应 feedKind', (tester) async {
    SquareFeedKind? tapped;
    await tester.pumpWidget(
      wrap(
        SquareFeedTabs(
          selected: SquareFeedKind.recommended,
          onChanged: (kind) => tapped = kind,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关注'));
    expect(tapped, SquareFeedKind.following);
  });
  testWidgets('七项在窄屏显示，松手才提交全部分类的拖动排序', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var order = List<SquareFeedKind>.of(SquareFeedKind.values);
    var commits = 0;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return SquareFeedTabs(
              order: order,
              selected: SquareFeedKind.recommended,
              onChanged: (_) {},
              onReorder: (from, to) => setState(() {
                commits++;
                final next = List<SquareFeedKind>.of(order);
                next.insert(to, next.removeAt(from));
                order = next;
              }),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final kind in SquareFeedKind.values) {
      expect(find.text(kind.label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    for (final kind in SquareFeedKind.values) {
      final from = find.byKey(ValueKey('square-tab-${kind.name}'));
      final targetKind = order.first == kind ? order.last : order.first;
      final target = find.byKey(ValueKey('square-tab-${targetKind.name}'));
      final before = commits;
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      expect(commits, before);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, before + 1, reason: kind.name);
      expect(order.toSet(), SquareFeedKind.values.toSet());
    }
  });
}
