import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_testing/chat_runtime_fixture.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as flyer;
import 'package:flutter_test/flutter_test.dart';
import 'package:chat/chat.dart';

void main() {
  final messages = <String, Message Function(String)>{
    '文字': (author) => Message.text(
      id: 'row',
      authorId: author,
      text: '一条需要换行的消息，用于核对头像与消息卡片共同布局。',
    ),
    '图片': (author) => Message.image(
      id: 'row',
      authorId: author,
      source: '',
      width: 300,
      height: 200,
    ),
    '视频': (author) => Message.video(
      id: 'row',
      authorId: author,
      source: '',
      width: 300,
      height: 200,
    ),
    '文件': (author) => Message.file(
      id: 'row',
      authorId: author,
      source: '',
      name: '较长的文件名称用于检查窄屏.txt',
      size: 1024,
    ),
    '语音': (author) => Message.audio(
      id: 'row',
      authorId: author,
      source: '',
      duration: const Duration(seconds: 12),
    ),
    '贴纸': (author) => Message.custom(
      id: 'row',
      authorId: author,
      metadata: {'pack_id': 'fluent3d', 'sticker_id': 'grinning_face'},
    ),
  };
  for (final scale in [1.0, 2.0]) {
    for (final mine in [false, true]) {
      for (final entry in messages.entries) {
        testWidgets(
          '${entry.key}共用消息外壳，${mine ? '右侧自己' : '左侧对方'}头像顶部对齐，大字$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final author = mine ? 'me' : 'peer';
            final controller = InMemoryChatController(
              messages: [entry.value(author)],
            );
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ChatMessageListView(
                    currentUserId: 'me',
                    chatController: controller,
                    onMessageSend: (_) async {},
                    resolveUser: (id) async => User(id: id),
                    composerBuilder: (_) => const SizedBox(),
                    onDownloadAttachment: (_) async {},
                    onMessagesChanged: () async {},
                    avatarBuilder: (_, id) => SizedBox(
                      key: ValueKey('avatar-$id'),
                      width: 32,
                      height: 32,
                      child: const ColoredBox(color: Colors.teal),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            final row = find.byKey(const ValueKey('chat-message-row-row'));
            expect(tester.widget(row), isA<flyer.ChatMessage>());
            final avatar = tester.getRect(
              find.byKey(ValueKey('avatar-$author')),
            );
            final content = tester.getRect(
              find.byKey(const ValueKey('chat-message-content-row')),
            );
            expect(avatar.top, closeTo(content.top, 0.1));
            final gap = AppLayout.scaled(tester.element(row), 8);
            expect(
              mine ? avatar.left - content.right : content.left - avatar.right,
              closeTo(gap, 0.1),
            );
            expect(avatar.left, greaterThanOrEqualTo(0));
            expect(content.left, greaterThanOrEqualTo(0));
            expect(avatar.right, lessThanOrEqualTo(320));
            expect(content.right, lessThanOrEqualTo(320));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            controller.dispose();
            await tester.pump();
          },
        );
      }
    }
  }

  testWidgets('真实贴纸消息气泡从assets包读取PNG，不依赖宿主同名资产', (tester) async {
    final controller = InMemoryChatController(
      messages: [
        Message.custom(
          id: 'sticker',
          authorId: 'peer',
          metadata: {'pack_id': 'fluent3d', 'sticker_id': 'grinning_face'},
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageListView(
            currentUserId: 'local',
            chatController: controller,
            onMessageSend: (_) async {},
            resolveUser: (id) async => User(id: id),
            composerBuilder: (_) => const SizedBox.shrink(),
            onDownloadAttachment: (_) async {},
            onMessagesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pump();
    final image = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage,
      ),
    );
    final provider = image.image as AssetImage;
    final key = await provider.obtainKey(ImageConfiguration.empty);
    expect(key.name, 'packages/citizen_assets/stickers/grinning_face.png');
    final bytes = await rootBundle.load(key.name);
    expect(bytes.lengthInBytes, greaterThan(24));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // 基准、宽屏视觉倍率和系统大字都须完整显示文案并保留真实菜单动作。
  for (final scenario in [
    (name: '基准', width: 411.0, scale: 1.0, textScale: 1.0),
    (name: '宽屏', width: 480.0, scale: 1.1, textScale: 1.0),
    (name: '大字', width: 300.0, scale: 1.0, textScale: 2.0),
  ]) {
    testWidgets('聊天菜单不溢出并保留动作：${scenario.name}', (tester) async {
      tester.view.physicalSize = Size(scenario.width, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const labels = ['扫一扫', '收付款', '发私信', '发群聊', '加好友'];
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: ChatSectionHeader<int>(
              onAction: (value) => selected = value,
              actions: [
                for (var i = 0; i < labels.length; i++)
                  ChatHeaderAction(
                    value: i,
                    label: labels[i],
                    icon: const Icon(Icons.chat),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chat-add-button')));
      await tester.pumpAndSettle();
      for (final label in labels) {
        final text = find.text(label);
        final row = find.ancestor(of: text, matching: find.byType(InkWell));
        expect(row, findsOneWidget);
        final textRect = tester.getRect(text), rowRect = tester.getRect(row);
        expect(textRect.right, lessThanOrEqualTo(rowRect.right - 22 + 0.01));
        expect(textRect.top, greaterThanOrEqualTo(rowRect.top));
        expect(textRect.bottom, lessThanOrEqualTo(rowRect.bottom));
        expect(rowRect.left, greaterThanOrEqualTo(8));
        expect(rowRect.right, lessThanOrEqualTo(scenario.width - 8));
        expect(
          rowRect.height,
          greaterThanOrEqualTo(
            40 * AppLayout.visualScaleForSize(Size(scenario.width, 914)),
          ),
        );
        if (scenario.name == '基准') {
          expect(rowRect.height, closeTo(40, 0.01));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(labels.last));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'conversation controller keeps one optimistic message until send completes',
    (tester) async {
      final sendGate = Completer<void>();
      final controller = ChatConversationController(
        conversationId: 'direct-a-b',
        currentUserId: 'a',
        loadSnapshot: () async =>
            (messages: <ChatStoredMessage>[], integrityFailureCount: 0),
        onSendText: (_) => sendGate.future,
        onSendMedia: null,
        onSendSticker: null,
        onSync: null,
        onStartRealtime: null,
        onDownloadAttachment: null,
        onResolveMediaPaths: null,
        onMarkRead: null,
        isVisible: () => true,
      );
      addTearDown(controller.dispose);
      controller.start();
      await tester.pump();

      final sending = controller.sendText('hello');
      await tester.pump();
      expect(controller.optimisticMessageCount, 1);

      sendGate.complete();
      await sending;
      expect(controller.optimisticMessageCount, 0);
    },
  );

  testWidgets(
    'conversation list controller creates only one realtime subscription',
    (tester) async {
      var starts = 0;
      var stops = 0;
      final runtime = _Runtime(
        onStart: ({required onNotice, onConnectionChanged}) async {
          starts += 1;
          return () async => stops += 1;
        },
      );
      final controller = ChatConversationListController(
        runtime: runtime,
        onCoordinate: () async {},
        onRefresh: (_) async => true,
      );
      controller.start(visible: true);
      controller.configureScope('account-a');
      controller.configureScope('account-a');
      await tester.pump();
      expect(starts, 1);

      controller.dispose();
      await tester.pump();
      expect(stops, 1);
    },
  );

  testWidgets('列表首次握手静默，真实失败后显示连接中并在恢复后清除', (tester) async {
    final attempt = Completer<void>();
    late Future<void> Function(bool) connection;
    var starts = 0;
    final runtime = _Runtime(
      onStart: ({required onNotice, onConnectionChanged}) async {
        starts++;
        connection = onConnectionChanged!;
        await attempt.future;
        return () async {};
      },
    );
    final c = ChatConversationListController(
      runtime: runtime,
      onCoordinate: () async {},
      onRefresh: (_) async => true,
    );
    c.start(visible: true);
    c.configureScope('account-a');
    c.configureScope('account-a');
    await tester.pump();
    expect(starts, 1);
    expect(c.connectionLabel, isNull);
    await connection(false);
    expect(c.connectionLabel, '连接中');
    attempt.complete();
    await tester.pump();
    expect(c.connectionLabel, '连接中');
    await connection(true);
    expect(c.connectionLabel, isNull);
    await connection(false);
    expect(c.connectionLabel, '连接中');
    c.dispose();
  });

  testWidgets('订阅等待后台重连但没有失败通知时列表保持静默', (tester) async {
    late Future<void> Function(bool) connection;
    final runtime = _Runtime(
      onStart: ({required onNotice, onConnectionChanged}) async {
        connection = onConnectionChanged!;
        return () async {};
      },
    );
    final c = ChatConversationListController(
      runtime: runtime,
      onCoordinate: () async {},
      onRefresh: (_) async => true,
    );
    c.start(visible: true);
    c.configureScope('account-a');
    await tester.pump();
    expect(c.connectionLabel, isNull);
    await connection(false);
    expect(c.connectionLabel, '连接中');
    await connection(true);
    expect(c.connectionLabel, isNull);
    c.dispose();
  });

  testWidgets('列表连接异常归连接中，切换身份后忽略旧连接的迟到状态', (tester) async {
    final first = Completer<void>();
    Future<void> Function(bool)? oldConnection;
    var starts = 0, oldStops = 0;
    final runtime = _Runtime(
      onStart: ({required onNotice, onConnectionChanged}) async {
        if (++starts == 1) {
          oldConnection = onConnectionChanged;
          await first.future;
          return () async {
            oldStops++;
          };
        }
        throw StateError('synthetic connection failure');
      },
    );
    final c = ChatConversationListController(
      runtime: runtime,
      onCoordinate: () async {},
      onRefresh: (_) async => true,
    );
    c.start(visible: true);
    c.configureScope('account-a');
    await tester.pump();
    c.configureScope('account-b');
    await tester.pump();
    expect(c.connectionLabel, '连接中');
    await oldConnection!(true);
    first.complete();
    await tester.pump();
    expect(c.connectionLabel, '连接中');
    expect(oldStops, 1);
    c.setVisible(false);
    expect(c.connectionLabel, isNull);
    c.dispose();
  });

  testWidgets('会话页连接失败静默且页面不发周期网络补发', (tester) async {
    Future<void> Function(bool)? connection;
    var syncs = 0;
    final c = ChatConversationController(
      conversationId: 'dm:a:b',
      currentUserId: 'a',
      loadSnapshot: () async =>
          (messages: <ChatStoredMessage>[], integrityFailureCount: 0),
      onSendText: (_) async {},
      onSendMedia: null,
      onSendSticker: null,
      onSync: () async {
        syncs++;
        return 0;
      },
      onStartRealtime: ({required onNotice, onConnectionChanged}) async {
        connection = onConnectionChanged;
        await connection?.call(false);
        return () async {};
      },
      onDownloadAttachment: null,
      onResolveMediaPaths: null,
      onMarkRead: null,
      isVisible: () => true,
    );
    c.start();
    await tester.pump();
    expect(c.error, isNull);
    await c.reloadMessages();
    await tester.pump(const Duration(seconds: 60));
    expect(c.error, isNull);
    expect(syncs, 0);
    await connection!.call(true);
    expect(c.error, isNull);
    c.dispose();
  });

  test('conversation timestamps use local calendar buckets', () {
    final now = DateTime(2026, 8, 30, 18);
    expect(
      chatConversationTime(DateTime(2026, 8, 30, 9, 5), now: now),
      '09:05',
    );
    expect(chatConversationTime(DateTime(2026, 8, 29, 9), now: now), '昨天');
  });

  test('empty state is hidden during loading and errors', () {
    expect(shouldShowChatEmptyState(loading: false, error: null), isTrue);
    expect(shouldShowChatEmptyState(loading: true, error: null), isFalse);
    expect(
      shouldShowChatEmptyState(loading: false, error: 'integrity error'),
      isFalse,
    );
  });

  testWidgets('conversation overview renders cards and unread badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatConversationOverview(
            header: const SizedBox(height: 20),
            onRefresh: () async {},
            onSearch: () {},
            items: [
              ChatConversationListItem(
                id: 'direct-a-b',
                title: 'Alice',
                subtitle: 'Hello',
                updatedAt: DateTime(2026, 8, 30, 9),
                unreadCount: 2,
                leading: const CircleAvatar(child: Text('A')),
                onTap: () {},
                onDelete: () async {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-conversation-direct-a-b')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('会话双向滑动、置顶切换、视频入口及滑到底动作', (tester) async {
    var pins = 0, deletes = 0, voices = 0, videos = 0;
    var pinned = false;
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatConversationOverview(
            header: const SizedBox(height: 20),
            onRefresh: () async {},
            onSearch: () {},
            items: [
              ChatConversationListItem(
                id: 'swipe',
                title: '滑动会话',
                subtitle: '消息',
                updatedAt: DateTime(2026),
                unreadCount: 1,
                leading: const CircleAvatar(),
                onTap: () {},
                onDelete: () async {
                  deletes++;
                },
                isPinned: pinned,
                onTogglePin: () async {
                  pins++;
                  pinned = !pinned;
                },
                onVoice: () {
                  voices++;
                },
                onVideo: () {
                  videos++;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await show();
    final tile = find.byKey(const ValueKey('chat-conversation-swipe'));
    await tester.drag(tile, const Offset(-170, 0));
    await tester.pumpAndSettle();
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(deletes, 0);
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();
    expect(pins, 1);
    await show();
    await tester.drag(tile, const Offset(-170, 0));
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tap(find.text('取消置顶'));
    await tester.pumpAndSettle();
    expect(pins, 2);
    await tester.drag(tile, const Offset(170, 0));
    await tester.pumpAndSettle();
    expect(find.text('语音'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();
    expect(videos, 1);
    expect(voices, 0);
    final width = tester.getSize(tile).width;
    await tester.drag(tile, Offset(width, 0));
    await tester.pumpAndSettle();
    expect(voices, 1);
    expect(deletes, 0);
    await tester.drag(tile, Offset(-width, 0));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    // 删除回调不移除卡片（例如取消确认）时，应恢复到原位且仍可继续操作。
    expect(tile, findsOneWidget);
    expect(find.text('删除'), findsNothing);
    await tester.drag(tile, const Offset(170, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();
    expect(voices, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('昵称和长群名右侧保留置顶图钉，未置顶不显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final name in ['用户昵称', '这是一个很长很长需要省略但仍必须完整显示置顶标志的群聊名称']) {
      for (final pinned in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatConversationOverview(
                header: const SizedBox(),
                onRefresh: () async {},
                onSearch: () {},
                items: [
                  ChatConversationListItem(
                    id: 'pin-label',
                    title: name,
                    subtitle: '消息',
                    updatedAt: DateTime(2026),
                    unreadCount: 1,
                    leading: const CircleAvatar(),
                    onTap: () {},
                    onDelete: () async {},
                    isPinned: pinned,
                  ),
                ],
              ),
            ),
          ),
        );
        final marker = find.byKey(const ValueKey('chat-pinned-pin-label'));
        expect(marker, pinned ? findsOneWidget : findsNothing);
        if (pinned) {
          final title = tester.getRect(find.text(name));
          final icon = tester.getRect(marker);
          expect(icon.left, greaterThan(title.right));
          expect(icon.center.dy, closeTo(title.center.dy, .5));
          expect(icon.right, lessThan(320));
          expect(find.byTooltip('已置顶'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('左右滑动后按钮底色填满卡片上下圆角接缝', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const captureKey = ValueKey('swipe-capture');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: captureKey,
            child: ChatConversationOverview(
              header: const SizedBox(height: 20),
              onRefresh: () async {},
              onSearch: () {},
              items: [
                ChatConversationListItem(
                  id: 'seam',
                  title: '圆角衔接',
                  subtitle: '消息',
                  updatedAt: DateTime(2026),
                  unreadCount: 0,
                  leading: const CircleAvatar(),
                  onTap: () {},
                  onDelete: () async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final tile = find.byKey(const ValueKey('chat-conversation-seam'));
    final context = tester.element(tile);
    final radius = AppLayout.scaled(context, 12);
    final card = find
        .ancestor(of: find.text('圆角衔接'), matching: find.byType(DecoratedBox))
        .first;
    for (final left in [true, false]) {
      await tester.drag(tile, Offset(left ? -170 : 170, 0));
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(card);
      final capture = tester.getRect(find.byKey(captureKey));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final x =
          (left ? cardRect.right - radius / 4 : cardRect.left + radius / 4) -
          capture.left;
      final expected = left ? Colors.orange.shade700 : Colors.blue.shade600;
      for (final y in [cardRect.top + 2, cardRect.bottom - 3]) {
        final offset =
            (((y - capture.top).floor() * image.width) + x.floor()) * 4;
        final actual = Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        // 圆弧抗锯齿允许两个色阶误差，空白接缝与按钮底色的差异远大于此值。
        expect(actual.r, closeTo(expected.r, 2 / 255), reason: '接缝红色通道');
        expect(actual.g, closeTo(expected.g, 2 / 255), reason: '接缝绿色通道');
        expect(actual.b, closeTo(expected.b, 2 / 255), reason: '接缝蓝色通道');
        expect(actual.a, 1);
      }
      image.dispose();
      await tester.tapAt(cardRect.intersect(tester.getRect(tile)).center);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除确认未完成时不重复触发，取消后短滑可收回', (tester) async {
    final confirmation = Completer<void>();
    var deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatConversationOverview(
            header: const SizedBox(height: 20),
            onRefresh: () async {},
            onSearch: () {},
            items: [
              ChatConversationListItem(
                id: 'confirm',
                title: '会话',
                subtitle: '消息',
                updatedAt: DateTime(2026),
                unreadCount: 0,
                leading: const CircleAvatar(),
                onTap: () {},
                onDelete: () async {
                  deletes++;
                  await confirmation.future;
                },
              ),
            ],
          ),
        ),
      ),
    );
    final tile = find.byKey(const ValueKey('chat-conversation-confirm'));
    final width = tester.getSize(tile).width;
    await tester.drag(tile, Offset(-width, 0));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    await tester.drag(tile, Offset(-width, 0));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    confirmation.complete();
    await tester.pumpAndSettle();
    await tester.drag(tile, const Offset(-25, 0));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing);
    expect(tile, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search view renders injected sections', (tester) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSearchView(
          controller: controller,
          query: 'hello',
          onQueryChanged: (_) {},
          onClear: () {},
          sections: [
            ChatSearchSection(
              title: '聊天记录',
              items: [
                ChatSearchItem(
                  key: const ValueKey('result-1'),
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: 'hello',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('聊天记录'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-1')), findsOneWidget);
  });

  testWidgets('group creation reports generic user selection', (tester) async {
    final controller = TextEditingController(text: 'Group');
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatGroupCreateView(
          nameController: controller,
          users: const [
            ChatSelectableUser(userId: 'alice', displayName: 'Alice'),
          ],
          selectedUserIds: const <String>{},
          onSelectionChanged: (userId, value) {
            if (value) {
              selected = userId;
            }
          },
          canCreate: false,
          onCreate: () {},
        ),
      ),
    );

    await tester.tap(find.byType(CheckboxListTile));
    expect(selected, 'alice');
  });

  // 中文注释：只有读取完成且没有错误时才能显示空态，加载或校验失败不得误导用户为暂无消息。
  test('只有成功且无错误的零消息读取显示真实空态', () {
    expect(shouldShowChatEmptyState(loading: false, error: null), isTrue);
    expect(shouldShowChatEmptyState(loading: true, error: null), isFalse);
    expect(
      shouldShowChatEmptyState(loading: false, error: '本机历史消息无法验证'),
      isFalse,
    );
  });
}

typedef _RealtimeStart =
    Future<Future<void> Function()?> Function({
      required Future<void> Function() onNotice,
      Future<void> Function(bool ready)? onConnectionChanged,
    });

class _Runtime extends TestChatRuntime {
  _Runtime({required this.onStart}) : super(host: _Host());

  final _RealtimeStart onStart;

  @override
  Future<int> retryOutgoing({
    String? recipientUserId,
    String? conversationId,
  }) async => 0;

  @override
  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function(bool ready)? onConnectionChanged,
  }) => onStart(onNotice: onNotice, onConnectionChanged: onConnectionChanged);
}

class _Host implements ChatRuntimeFixture {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
