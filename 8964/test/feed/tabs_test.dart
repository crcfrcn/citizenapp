// 归并广场原有回归，保留各来源用例、断言及独立生命周期。

import 'package:citizen_square/feed/tabs.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_storage/user.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

// 验证分类顺序规范及真实重开后保留最后拖动结果。

void _registerSquareTabOrderStore() {
  useIsolatedIsar();

  test('旧顺序去重并保留已保存顺序，缺失分类补回', () {
    expect(resolveSquareTabOrder(['videos', 'article', 'videos', 'unknown']), [
      SquareFeedKind.videos,
      SquareFeedKind.article,
      SquareFeedKind.recommended,
      SquareFeedKind.circle,
      SquareFeedKind.following,
      SquareFeedKind.campaign,
      SquareFeedKind.notifications,
    ]);
  });

  test('连续拖动事务持久保存最后顺序，关闭真库重新打开仍保留', () async {
    const store = SquareTabOrderStore();
    await UserIsar.instance.writeTxn((isar) async {
      await isar.collection<Setting>().put(
        Setting()
          ..guideSeen = true
          ..councilOrder = ['council']
          ..bankOrder = ['bank'],
      );
    });
    final first = List<SquareFeedKind>.of(SquareFeedKind.values.reversed);
    final last = [
      SquareFeedKind.circle,
      ...first.where((k) => k != SquareFeedKind.circle),
    ];
    await Future.wait([store.write(first), store.write(last)]);
    expect(await store.read(), last);
    final db = await UserIsar.instance.db();
    final directory = db.directory!;
    await db.close();
    // 丢弃已关闭的内存实例，从同一个真实文件读取，模拟 App 重启。
    final reopened = Isar.openSync(
      [
        ProfileSchema,
        EditSchema,
        ProfileMediaSchema,
        IdentitySchema,
        ContactSchema,
        NoticeSchema,
        SettingSchema,
        FollowSchema,
      ],
      directory: directory,
      name: 'citizenapp_user',
      relaxedDurability: false,
      inspector: false,
    );
    try {
      final settings = reopened.collection<Setting>().getSync(0)!;
      expect(resolveSquareTabOrder(settings.squareTabOrder), last);
      expect(settings.guideSeen, isTrue);
      expect(settings.councilOrder, ['council']);
      expect(settings.bankOrder, ['bank']);
    } finally {
      await reopened.close();
    }
  });
}

// 验证分类交互、未读计数、窄屏及拖动完成后提交。

void _registerSquareFeedTabs() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  testWidgets('互动入口使用讨论图标并保留通知计数及标识', (tester) async {
    SquareFeedKind? selected;
    await tester.pumpWidget(
      wrap(
        SquareFeedTabs(
          selected: SquareFeedKind.recommended,
          notificationsUnread: 7,
          onChanged: (kind) => selected = kind,
        ),
      ),
    );
    expect(find.text('互动'), findsOneWidget);
    expect(find.text('通知'), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.text('互动'));
    expect(selected, SquareFeedKind.notifications);
    expect(selected!.workerValue, 'notifications');
  });

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

void main() {
  group("square_tab_order_store_test", _registerSquareTabOrderStore);
  group("widgets/square_feed_tabs_test", _registerSquareFeedTabs);
}
