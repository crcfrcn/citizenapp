import 'package:citizen_testing/membergate_fixture.dart';
import 'package:flutter/services.dart';
import 'package:citizen_system/security/account_security_exception.dart';
import 'package:http/http.dart' as http;

import 'package:citizen_testing/mls_authentication_fixture.dart';

import 'dart:async';
import 'dart:io';

import 'package:citizen_user/identity/identity_binding.dart';

import 'package:citizen_testing/isar_test_env.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizenapp/main.dart' show AppShell;
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:chat/chat.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_system/theme/app_theme.dart';

const _ownerUserId = 'CN220-CTZN2-100000001-2026';
const _peerUserId = 'CN220-CTZN2-100000002-2026';
const _carolCidNumber = 'CN220-CTZN2-100000003-2026';
const _directConversationId =
    'dm:CN220-CTZN2-100000001-2026:CN220-CTZN2-100000002-2026';
const _peerAccountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _peerProfile = CitizenProfile(
  accountId: _peerAccountId,
  displayName: '会员用户',
  profileBio: '公开签名',
  avatarKey: 'profile/$_peerUserId/avatar',
  bannerKey: null,
  cidNumber: _peerUserId,
  isCertified: true,
  cidLevel: 'voting',
  memberLevel: 'democracy',
  membergateActive: true,
  following: 0,
  followers: 0,
  mutualFollowing: 0,
  posts: 0,
  campaigns: 0,
  videos: 0,
  articles: 0,
  isFollowing: false,
  isFollowedBy: false,
  isNotifying: false,
  profileAt: 2,
);

void main() {
  setUp(() {
    // 公民会话与附件会员许可分别提供，普通贴纸不以会员额度证明身份。
    SubscriptionService.rememberCitizenSession(
      SquareSession(
        deviceId: testMlsDeviceId,
        sessionToken: 'synthetic-chat-session',
        cidNumber: _ownerUserId,
        bindRev: 1,
        accountId: '0x${List.filled(32, '11').join()}',
        expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
      ),
    );
    setChatLightData(_ownerUserId, 10 * 1024 * 1024);
  });
  tearDown(() => setChatLightData(_ownerUserId, null));

  testWidgets('根首帧及账户/前台变化自动准备，挂起不阻止导航也不提前启动聊天', (tester) async {
    final sessions = _PendingPreparationSessions(),
        security = _UnusedSecurity();
    var chatInstances = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SquareSessionProvider>.value(value: sessions),
          Provider<AccountSecurityService>.value(value: security),
        ],
        child: MaterialApp(
          home: AppShell(
            openedPushData: const Stream<Map<String, dynamic>>.empty(),
            chatRuntimeFactory: () {
              chatInstances++;
              return _FakeRuntime(address: testMlsAccountId);
            },
            tabBuilder: (index, _) => Center(child: Text('page:$index')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(sessions.calls, 1);
    expect(find.text('page:0'), findsOneWidget);
    expect(chatInstances, 0);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('交易'));
    await tester.pump();
    expect(find.text('page:3'), findsOneWidget);
    security.revision.value++;
    await tester.pump();
    await tester.pump();
    expect(sessions.calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(sessions.calls, 3);
    expect(chatInstances, 0);
    await tester.pumpWidget(const SizedBox());
    sessions.pending.complete(
      const SquareSessionResolution(SquareSessionStatus.noWallet),
    );
    await tester.pump();
    security.revision.dispose();
  });
  test('链上绑定/设备故障不提示再次注册或真人验证', () {
    for (final code in ['cid_not_bound', 'device_not_registered']) {
      final message = chatUserErrorMessage(
        SquareApiException('synthetic', errorCode: code),
      );
      expect(message, isNot(contains('注册')));
      expect(message, isNot(contains('验证')));
    }
  });

  Future<void> pumpTab(WidgetTester tester, {ChatEntryOpeners? openers}) async {
    const accountId =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: _FakeChatStore(),
            cidNumber: _ownerUserId,
            accountId: accountId,
            runtime: _FakeRuntime(address: accountId),
            openers: openers,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 菜单开合有动画，但聊天列表有轮询计时器，测试使用固定步长推进动画。
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('聊天构造期不恢复会员交易', () {
    useIsolatedIsar();
    testWidgets('真实默认服务打开及重连时不读取会员或确认交易', (tester) async {
      final security = _UnusedSecurity(),
          sessions = _FakeProfileSessionProvider(),
          resolver = _NoChatChainRecovery();
      final core = await openTestSdk();
      final sdk = core.sdk;
      final network = _ChatNetworkCounter();
      addTearDown(() async {
        await sdk.close();

        security.revision.dispose();
      });
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<CitizenSdk>.value(value: sdk),
              Provider<AccountSecurityService>.value(value: security),
              Provider<FinalizedIdentityResolver>.value(value: resolver),
              Provider<CurrentUserContext>.value(
                value: _LocalChatIdentity(registered: true),
              ),
              Provider<SquareSessionProvider>.value(value: sessions),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChatTab(
                  runtime: _FakeRuntime(address: testMlsAccountId),
                  store: _FakeChatStore(),
                  contactService: _FakeContactService([]),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(network.requests, 0);
        expect(resolver.reads, 0);
        expect(core.fixture.calls, ['open']);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, createHttpClient: (_) => network);
    });
  });

  testWidgets('打开与附件动作均不预查云端会员，未知本机规则明确失败', (tester) async {
    final service = _AttachmentOnlySubscription();
    final provider = _FakeProfileSessionProvider();
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: _peerUserId,
          lastMessage: 'hi',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.sent,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId: '0x${'11' * 32}',
            runtime: _FakeRuntime(
              address: '0x${'11' * 32}',
              store: store,
              squareSessionProvider: provider,
              subscriptionService: service,
            ),
            sessionProvider: provider,
            subscriptionService: service,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests, 0);
    await tester.tap(
      find.byKey(const ValueKey('chat-conversation-$_directConversationId')),
    );
    await tester.pumpAndSettle();
    final page = tester.widget<ChatConversationPage>(
      find.byType(ChatConversationPage),
    );
    expect(service.requests, 0);
    await expectLater(
      page.runtime.prepareAttachmentForUser(
        userId: _ownerUserId,
        accountId: page.accountId,
      ),
      throwsA(isA<SquareApiException>()),
    );
    expect(service.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('真实聊天适配器后台不建会话不刷新，核对账户/revision/设备；基础聊天独立', () async {
    final provider = _FakeProfileSessionProvider();
    final host = ChatRuntime(
      accountSecurity: _UnusedSecurity(),
      currentUserContext: _UnusedCurrentUser(),
      squareSessionProvider: provider,
    );
    addTearDown(host.push.dispose);
    final capability = host;
    final account = ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope: 'genesis',
      userId: _ownerUserId,
      bindingRevision: 1,
      accountId: provider.value.accountId,
      displayName: 'A',
    );
    setChatLightData(_ownerUserId, null);
    expect(
      await capability.prepareAttachment(
        account,
        allowRefresh: false,
        expectedDeviceId: testMlsDeviceId,
      ),
      isFalse,
    );
    expect(provider.calls, 0);
    expect(await host.canSend(_ownerUserId), isTrue);
    expect(provider.calls, 1);
    setChatLightData(_ownerUserId, 10 * 1024 * 1024);
    expect(
      await capability.prepareAttachment(
        account,
        allowRefresh: false,
        expectedDeviceId: testMlsDeviceId,
      ),
      isTrue,
    );
    expect(provider.calls, 1);
    expect(
      await capability.prepareAttachment(
        account,
        allowRefresh: false,
        expectedDeviceId: 'wrong-device',
      ),
      isFalse,
    );
    expect(provider.calls, 1);
    await expectLater(
      capability.prepareAttachment(
        account,
        allowRefresh: true,
        expectedDeviceId: 'wrong-device',
      ),
      throwsA(
        isA<SquareApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
    final changed = ChatRuntimeAccount(
      hostIndex: 0,
      bindingScope: 'genesis',
      userId: _ownerUserId,
      bindingRevision: 2,
      accountId: account.accountId,
      displayName: 'A',
    );
    await expectLater(
      capability.prepareAttachment(changed, allowRefresh: true),
      throwsA(
        isA<SquareApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });

  testWidgets('系统保护记录读取失败显示可重试错误', (tester) async {
    const accountId =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: accountId),
            store: _UnavailableRecordsChatStore(),
            cidNumber: _ownerUserId,
            accountId: accountId,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('聊天暂时无法使用，请稍后重试'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('本地会话未返回时直接显示聊天页面且不使用整页转圈', (tester) async {
    final store = _PendingChatStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: _peerAccountId),
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('搜索会话、联系人和聊天记录'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-sync-progress')), findsOneWidget);
    final searchTopBefore = tester.getTopLeft(find.text('搜索会话、联系人和聊天记录')).dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('chat-sync-progress'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('chat-add-button'))).dy,
      ),
    );
    expect(find.text('正在读取本地会话'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    store.completer.complete(const <ChatConversationPreview>[]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('chat-sync-progress')), findsNothing);
    expect(tester.getTopLeft(find.text('搜索会话、联系人和聊天记录')).dy, searchTopBefore);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('聊天本机绑定未知提示身份刷新，不调用会话/会员/加密存储', (tester) async {
    final store = _FakeChatStore(), sessions = _FakeProfileSessionProvider();
    final memberships = _AttachmentOnlySubscription(),
        security = _UnusedSecurity();
    final core = await openTestSdk();
    final sdk = core.sdk;
    addTearDown(() async {
      await sdk.close();

      security.revision.dispose();
    });
    final resolver = _NoChatChainRecovery();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CitizenSdk>.value(value: sdk),
          Provider<AccountSecurityService>.value(value: security),
          Provider<FinalizedIdentityResolver>.value(value: resolver),
          Provider<CurrentUserContext>.value(value: _LocalChatIdentity()),
          Provider<SquareSessionProvider>.value(value: sessions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatTab(
              runtime: _FakeRuntime(address: _peerAccountId),
              store: store,
              subscriptionService: memberships,
              contactService: _FakeContactService([]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // 原错误横幅和空态各显示同一固定提示。
    expect(find.textContaining('身份信息暂不可用，请在身份页刷新后重试'), findsNWidgets(2));
    expect(find.text('尚未注册'), findsNothing);
    expect(sessions.calls, 0);
    expect(memberships.requests, 0);
    expect(resolver.reads, 0);
    expect(core.fixture.calls, ['open']);
    expect(store.readPreviewCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('未注册身份显示统一注册引导,不读加密存储不报底层异常', (tester) async {
    final store = _FakeChatStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: _peerAccountId),
            store: store,
            cidNumber: '',
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 统一引导态(标题 + 注册按钮),不是错误横幅。
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.textContaining('尚未激活'), findsNothing);
    // 短路铁证:加密会话存储一次都不读——其密钥绑定解析对未注册身份必抛
    // AccountSecurityException，读了就会以错误横幅盖住引导。
    expect(store.readPreviewCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('隐藏 Chat Tab 不初始化，进入后 init/resume 只同步一次', (tester) async {
    final selectedTab = ValueNotifier<int>(0);
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: _FakeChatStore(),
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
            selectedTab: selectedTab,
            tabIndex: 2,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(runtime.syncCount, 0);

    selectedTab.value = 2;
    await tester.pump(const Duration(milliseconds: 100));
    expect(runtime.syncCount, 1);

    // 一次 pause/resume 可以同步一次；同一 resume burst 不得创建两条链。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(runtime.syncCount, 2);

    selectedTab.dispose();
  });

  ChatConversationPreview preview(String id, String text) =>
      ChatConversationPreview(
        conversationId: id,
        title: text,
        peerUserId: _peerUserId,
        lastMessage: '本机消息',
        lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        unreadCount: 0,
        deliveryState: ChatMessageDeliveryState.receivedByDevice,
      );
  Future<void> settleLocal(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  testWidgets('列表和聊天标题缺少资料缓存时不获取会话或名片', (tester) async {
    const record = MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      record,
      (call) async => call.method == 'isRecording' ? false : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        record,
        null,
      ),
    );
    final store = _FakeChatStore(
      conversations: [preview(_directConversationId, '本机标题')],
    );
    final api = _FakeProfileApi(_peerProfile),
        sessions = _FakeProfileSessionProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: testMlsAccountId, store: store),
            store: store,
            cidNumber: _ownerUserId,
            accountId: testMlsAccountId,
            profileApi: api,
            profileCache: const _EmptyProfileCache(),
            sessionProvider: sessions,
          ),
        ),
      ),
    );
    await settleLocal(tester);
    expect(find.text('本机标题'), findsOneWidget);
    expect(api.calls, 0);
    expect(sessions.calls, 0);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).imageUrl,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-conversation-$_directConversationId')),
    );
    await settleLocal(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ChatConversationPage), findsOneWidget);
    expect(api.calls, 0);
    expect(sessions.calls, 0);
    final header = find.byKey(const ValueKey('chat-peer-profile-entry'));
    expect(
      tester
          .widget<ProfileAvatar>(
            find.descendant(of: header, matching: find.byType(ProfileAvatar)),
          )
          .imageUrl,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });
  testWidgets('已有名片但本机头像缺失，浏览列表不会回退请求远端图片', (tester) async {
    final api = _FakeProfileApi(_peerProfile), network = _ChatNetworkCounter();
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatTab(
              runtime: _FakeRuntime(address: testMlsAccountId),
              store: _FakeChatStore(
                conversations: [preview('local-avatar', '本机标题')],
              ),
              cidNumber: _ownerUserId,
              accountId: testMlsAccountId,
              profileApi: api,
              profileCache: const _MemoryProfileCache(_peerProfile),
              profileMediaCache: _MemoryProfileMediaCache(
                const CitizenProfileMediaSnapshot(
                  avatarPath: '/missing/local-avatar.webp',
                ),
              ),
            ),
          ),
        ),
      );
      await settleLocal(tester);
      expect(api.calls, 0);
      expect(network.requests, 0);
      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(avatar.imageUrl, isNull);
      expect(avatar.userImageSet, isTrue);
      await tester.pumpWidget(const SizedBox());
      await settleLocal(tester);
    }, createHttpClient: (_) => network);
  });
  for (final error in [false, true]) {
    testWidgets('切CID不等待旧本机列表，迟到${error ? '错误' : '结果'}不影响新CID', (tester) async {
      final old = Completer<List<ChatConversationPreview>>(),
          store = _ScopedPreviews();
      store.onRead = (cid) => cid == _ownerUserId
          ? old.future
          : Future.value([preview('new-owner', '新身份会话')]);
      final runtime = _FakeRuntime(address: testMlsAccountId);
      Widget page(String cid, String account) => MaterialApp(
        home: Scaffold(
          body: ChatTab(
            key: const ValueKey('scope'),
            runtime: runtime,
            store: store,
            cidNumber: cid,
            accountId: account,
            profileCache: const _EmptyProfileCache(),
          ),
        ),
      );
      await tester.pumpWidget(page(_ownerUserId, testMlsAccountId));
      await settleLocal(tester);
      await tester.pumpWidget(page(_carolCidNumber, '0x${'44' * 32}'));
      await settleLocal(tester);
      expect(find.text('新身份会话'), findsOneWidget);
      if (error) {
        old.completeError(StateError('stale'));
      } else {
        old.complete([preview('old-owner', '旧身份会话')]);
      }
      await settleLocal(tester);
      expect(find.text('旧身份会话'), findsNothing);
      expect(find.text('新身份会话'), findsOneWidget);
      expect(find.text('聊天暂时无法使用，请稍后重试'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settleLocal(tester);
    });
  }
  testWidgets('迟到私人备注不能落到新CID的同一对端', (tester) async {
    final delayed = _DelayedContacts(),
        store = _FakeChatStore(conversations: [preview('same-peer', '公开称呼')]);
    final runtime = _FakeRuntime(address: testMlsAccountId);
    Widget page(String cid, UserContactService contacts) => MaterialApp(
      home: Scaffold(
        body: ChatTab(
          key: const ValueKey('remark-scope'),
          runtime: runtime,
          store: store,
          cidNumber: cid,
          accountId: cid == _ownerUserId ? testMlsAccountId : '0x${'44' * 32}',
          profileCache: const _EmptyProfileCache(),
          contactService: contacts,
        ),
      ),
    );
    await tester.pumpWidget(page(_ownerUserId, delayed));
    await settleLocal(tester);
    await tester.pumpWidget(
      page(
        _carolCidNumber,
        _FakeContactService([
          const UserContact(
            cidNumber: _peerUserId,
            contactRemark: '乙备注',
            updatedAt: 1,
          ),
        ]),
      ),
    );
    await settleLocal(tester);
    expect(find.text('乙备注（公开称呼）'), findsOneWidget);
    delayed.held.complete([
      const UserContact(
        cidNumber: _peerUserId,
        contactRemark: '甲备注',
        updatedAt: 1,
      ),
    ]);
    await settleLocal(tester);
    expect(find.textContaining('甲备注'), findsNothing);
    expect(find.text('乙备注（公开称呼）'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });
  testWidgets('旧CID迟到的公开资料不能覆盖新CID的本机预览', (tester) async {
    final delayed = _DelayedProfileCache();
    final store = _FakeChatStore(conversations: [preview('same-peer', '本机预览')]);
    final runtime = _FakeRuntime(address: testMlsAccountId);
    Widget page(String cid, CitizenProfileCache profiles) => MaterialApp(
      home: Scaffold(
        body: ChatTab(
          key: const ValueKey('profile-scope'),
          runtime: runtime,
          store: store,
          cidNumber: cid,
          accountId: cid == _ownerUserId ? testMlsAccountId : '0x${'44' * 32}',
          profileCache: profiles,
        ),
      ),
    );
    await tester.pumpWidget(page(_ownerUserId, delayed));
    await settleLocal(tester);
    await tester.pumpWidget(page(_carolCidNumber, const _EmptyProfileCache()));
    await settleLocal(tester);
    expect(find.text('本机预览'), findsOneWidget);
    delayed.held.complete(_peerProfile);
    await settleLocal(tester);
    expect(find.text(_peerProfile.displayName), findsNothing);
    expect(find.text('本机预览'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  for (final failed in [false, true]) {
    testWidgets('旧CID后台删除${failed ? '失败' : '完成'}不影响新CID的同名会话', (tester) async {
      final deletion = Completer<void>();
      final store = _FakeChatStore(conversations: [preview('same-id', '当前会话')]);
      final runtime = _FakeRuntime(
        address: testMlsAccountId,
        store: store,
        onDeleteConversation: (_) => deletion.future,
      );
      Widget page(String cid) => MaterialApp(
        home: Scaffold(
          body: ChatTab(
            key: const ValueKey('delete-scope'),
            runtime: runtime,
            store: store,
            cidNumber: cid,
            accountId: cid == _ownerUserId
                ? testMlsAccountId
                : '0x${'44' * 32}',
            profileCache: const _EmptyProfileCache(),
          ),
        ),
      );
      await tester.pumpWidget(page(_ownerUserId));
      await settleLocal(tester);
      await tester.drag(find.text('当前会话'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await settleLocal(tester);
      await tester.pumpWidget(page(_carolCidNumber));
      await settleLocal(tester);
      expect(find.text('当前会话'), findsOneWidget);
      if (failed) {
        deletion.completeError(StateError('old delete failed'));
      } else {
        deletion.complete();
      }
      await settleLocal(tester);
      expect(find.text('当前会话'), findsOneWidget);
      expect(find.text('聊天暂时无法使用，请稍后重试'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settleLocal(tester);
    });
  }

  testWidgets('聊天 Tab 按 CID 身份渲染会话列表', (tester) async {
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: 'CN220-CTZN2-100000002-2026',
          lastMessage: 'hello',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          unreadCount: 1,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: _peerAccountId),
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text(_peerAccountId), findsNothing);
    expect(find.text('hello'), findsOneWidget);
    expect(
      store.lastAccountFilter,
      '0x1111111111111111111111111111111111111111111111111111111111111111',
    );
    expect(find.byIcon(Icons.add_comment_outlined), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
    final tile = find.byKey(
      const ValueKey('chat-conversation-$_directConversationId'),
    );
    final cardDecoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: tile, matching: find.byType(DecoratedBox)),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.border != null);
    expect((cardDecoration.border! as Border).top.color, AppTheme.borderLight);
  });

  testWidgets('聊天卡片联合显示私人备注、公开昵称、真实头像和会员徽章', (tester) async {
    const avatarPath = '/cached/chat-list/avatar.webp';
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: 'dm:owner:peer',
          title: '旧昵称',
          peerUserId: _peerUserId,
          lastMessage: '',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: _peerAccountId),
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            profileApi: _FakeProfileApi(_peerProfile),
            profileCache: const _MemoryProfileCache(_peerProfile),
            profileMediaCache: _MemoryProfileMediaCache(
              const CitizenProfileMediaSnapshot(avatarPath: avatarPath),
            ),
            sessionProvider: _FakeProfileSessionProvider(),
            contactService: _FakeContactService(<UserContact>[
              const UserContact(
                cidNumber: _peerUserId,
                contactRemark: '同事',
                updatedAt: 1,
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(find.text('同事（会员用户）'), findsOneWidget);
    expect(find.text(_peerUserId), findsNothing);
    expect(find.text('暂无消息'), findsOneWidget);
    expect(find.text('旧昵称'), findsNothing);
    expect(avatar.imagePath, avatarPath);
    expect(avatar.memberLevel, 'democracy');
    expect(avatar.membergateActive, isTrue);
    expect(avatar.showBadge, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('进会话点贴纸 → 接线到 runtime.sendSticker(peer/conv/pack/sticker 正确)', (
    tester,
  ) async {
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: _peerUserId,
          lastMessage: 'hi',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.sent,
        ),
      ],
    );
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      store: store,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 点会话进入 SDK 完整会话页。
    await tester.tap(find.text('Bob'));
    await tester.pump(const Duration(milliseconds: 400)); // 路由转场
    await tester.pump(const Duration(milliseconds: 100));

    // 点贴纸开关 → 面板 → 选 grinning_face。
    await tester.tap(find.byKey(const ValueKey('chat-expression-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-expression-sticker')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sticker-grinning_face')));
    await tester.pump(const Duration(milliseconds: 100));

    // 委托四参逐字正确(named 参数不会换位,守的是漏接/错映射的回归)。
    expect(runtime.sentStickers.single, [
      _peerUserId,
      _directConversationId,
      'fluent3d',
      'grinning_face',
    ]);
    expect(
      runtime.retryScopes,
      contains((
        recipientUserId: _peerUserId,
        conversationId: _directConversationId,
      )),
      reason: '进入私聊只能重试当前对端的当前会话队列',
    );
    expect(runtime.realtimeRetryOutgoingOnConnect, contains(false));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('聊天 Tab deletes one local conversation after confirmation', (
    tester,
  ) async {
    final allowPhysicalDelete = Completer<void>();
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: _peerUserId,
          lastMessage: 'hello',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.sent,
        ),
        ChatConversationPreview(
          conversationId: 'dm:alice-wallet:carol-wallet',
          title: 'Carol',
          peerUserId: _carolCidNumber,
          lastMessage: 'keep',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.sent,
        ),
      ],
    );
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      store: store,
      onDeleteConversation: (conversationId) async {
        await allowPhysicalDelete.future;
        await store.deleteConversation(
          _ownerUserId,
          conversationId,
          bindingToken: const ChatBindingFenceToken(
            ownerUserId: _ownerUserId,
            bindingRevision: 1,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            bindingScope:
                '0x4242424242424242424242424242424242424242424242424242424242424242',
            generation: 1,
          ),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.text('Bob'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('删除聊天记录'), findsOneWidget);
    expect(find.text('确定删除这台设备上的聊天记录？'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump();

    expect(store.deletedConversationIds, isEmpty, reason: '后台物理删除仍被测试门闩阻塞');
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Carol'), findsOneWidget);

    allowPhysicalDelete.complete();
    await tester.pumpAndSettle();
    expect(store.deletedConversationIds, [_directConversationId]);
  });

  testWidgets('聊天窗口确认删除后立即返回且路由重载不恢复待清理卡片', (tester) async {
    final allowPhysicalDelete = Completer<void>();
    var deleteCalls = 0;
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: _peerUserId,
          lastMessage: 'hello',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.sent,
        ),
      ],
      messages: [
        ChatStoredMessage(
          messageId: 'env-window-delete',
          conversationId: _directConversationId,
          direction: 'incoming',
          senderUserId: _peerUserId,
          recipientUserId: _ownerUserId,
          messageKind: ChatMessageKind.text,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
          createdAtMillis: 1000,
          plaintext: ChatPayloadCodec.encode(ChatContent.text('hello')),
        ),
      ],
    );
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      store: store,
      onDeleteConversation: (conversationId) async {
        deleteCalls += 1;
        await allowPhysicalDelete.future;
        await store.deleteConversation(
          _ownerUserId,
          conversationId,
          bindingToken: const ChatBindingFenceToken(
            ownerUserId: _ownerUserId,
            bindingRevision: 1,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            bindingScope:
                '0x4242424242424242424242424242424242424242424242424242424242424242',
            generation: 1,
          ),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('chat-conversation-$_directConversationId')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChatConversationPage), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除聊天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(find.text('聊天暂时无法使用，请稍后重试'), findsNothing);
    expect(
      find.byType(ChatConversationPage),
      findsNothing,
      reason: '确认后 公民聊天 聊天窗口必须立即关闭',
    );
    expect(find.text('Bob'), findsNothing, reason: '后台删除未完成时路由重载也不得恢复卡片');
    expect(store.deletedConversationIds, isEmpty);

    allowPhysicalDelete.complete();
    await tester.pumpAndSettle();
    expect(store.deletedConversationIds, [_directConversationId]);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('聊天 Tab 鉴权仍要求当前绑定钱包账户', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            runtime: _FakeRuntime(address: _peerAccountId),
            store: _FakeChatStore(),
            cidNumber: _ownerUserId,
            accountId: '',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('请先在「我的 → 我的钱包」添加钱包账户'), findsOneWidget);
  });

  testWidgets('聊天 Tab 打开后自动重试本机发送队列', (tester) async {
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
    );
    final store = _FakeChatStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(runtime.syncCount, 1);
    // 首次本地读立即出首屏；发送队列重试完成后再读一次以合并最新状态。
    expect(store.readPreviewCount, 2);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(runtime.syncCount, 2);
    expect(store.readPreviewCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('本地空会话先结束加载，静默后台服务不得阻塞首屏', (tester) async {
    final retryCompleter = Completer<int>();
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      retryCompleter: retryCompleter,
    );
    final store = _FakeChatStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(runtime.syncCount, 1);
    expect(find.text('暂无会话'), findsOneWidget);
    expect(find.text('正在读取本地会话'), findsNothing);
    expect(find.byKey(const ValueKey('chat-sync-progress')), findsNothing);
    expect(find.textContaining('正在连接'), findsNothing);

    store.replaceConversations([
      ChatConversationPreview(
        conversationId: _directConversationId,
        title: 'Bob',
        peerUserId: _peerUserId,
        lastMessage: '后台补发完成后的本地结果',
        lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(2),
        unreadCount: 0,
        deliveryState: ChatMessageDeliveryState.receivedByDevice,
      ),
    ]);
    retryCompleter.complete(0);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('后台补发完成后的本地结果'), findsOneWidget);
    expect(find.textContaining('正在连接'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('后台聊天服务失败保留已显示的本地会话且不显示连接文案', (tester) async {
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      retryError: StateError('测试后台服务失败'),
    );
    final store = _FakeChatStore(
      conversations: [
        ChatConversationPreview(
          conversationId: _directConversationId,
          title: 'Bob',
          peerUserId: _peerUserId,
          lastMessage: '本地会话必须保留',
          lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          unreadCount: 0,
          deliveryState: ChatMessageDeliveryState.receivedByDevice,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('本地会话必须保留'), findsOneWidget);
    expect(find.text('正在读取本地会话'), findsNothing);
    expect(find.textContaining('正在连接'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('聊天 Tab uses realtime notice before polling fallback', (
    tester,
  ) async {
    final runtime = _FakeRuntime(
      address:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      enableRealtime: true,
    );
    final store = _FakeChatStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            store: store,
            cidNumber: _ownerUserId,
            accountId:
                '0x1111111111111111111111111111111111111111111111111111111111111111',
            runtime: runtime,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(runtime.syncCount, 1);
    expect(runtime.realtimeStartCount, 1);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(runtime.syncCount, 1);

    await runtime.realtimeNotice?.call();
    await tester.pump();

    expect(runtime.syncCount, 2);
    expect(store.readPreviewCount, greaterThanOrEqualTo(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(runtime.realtimeStopCount, 1);
  });

  testWidgets('顶部为搜索框、右上角为加号，旧「新建群聊」卡片已删', (tester) async {
    await pumpTab(tester);

    expect(find.text('搜索会话、联系人和聊天记录'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('新建群聊'), findsNothing);
    expect(find.byIcon(Icons.group_add_outlined), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('点加号弹出扫一扫/收付款/发私信/发群聊/加好友五项', (tester) async {
    await pumpTab(tester);
    await openMenu(tester);

    for (final label in ['扫一扫', '收付款', '发私信', '发群聊', '加好友']) {
      expect(find.text(label), findsOneWidget, reason: '缺少菜单项 $label');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('加号弹窗每项在基准视口下约 40 逻辑像素高', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTab(tester);
    await openMenu(tester);

    final rows = <Finder>[];
    for (final label in ['扫一扫', '收付款', '发私信', '发群聊', '加好友']) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, closeTo(40, 0.5));
      rows.add(row);
    }
    expect(
      tester.getCenter(rows.last).dy - tester.getCenter(rows.first).dy,
      closeTo(160, 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('扫一扫用扫码 svg（不是二维码图标）、发私信用聊天 tab 同款图标', (tester) async {
    await pumpTab(tester);
    await openMenu(tester);

    // 扫一扫必须与「交易 → 扫一扫」同一份 scan-line.svg。
    final svg = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    expect(
      svg.any((item) {
        final loader = item.bytesLoader;
        return loader is SvgAssetLoader &&
            loader.assetName == 'packages/citizen_assets/icons/scan-line.svg';
      }),
      isTrue,
      reason: '扫一扫应使用 assets/icons/scan-line.svg 扫码图标',
    );
    // 防回归：不得再用 Material 的二维码图标顶替扫码图标。
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    expect(find.byIcon(Icons.qr_code_rounded), findsNothing);
    // 发私信与底部导航「聊天」tab 同一个图标。
    expect(find.byIcon(Icons.textsms_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('五项分别路由到对应动作', (tester) async {
    final fired = <String>[];
    await pumpTab(
      tester,
      openers: ChatEntryOpeners(
        openScan: (_) async => fired.add('scan'),
        openReceivePay: (_) async => fired.add('receivePay'),
        openSendMessage: (_) async => fired.add('sendMessage'),
        openCreateGroup: (_) async => fired.add('createGroup'),
        openAddFriend: (_) async => fired.add('addFriend'),
      ),
    );

    for (final label in ['扫一扫', '收付款', '发私信', '发群聊', '加好友']) {
      await openMenu(tester);
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(fired, [
      'scan',
      'receivePay',
      'sendMessage',
      'createGroup',
      'addFriend',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('点搜索框进入聊天搜索页', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('搜索会话、联系人和聊天记录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ChatSearchPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeChatStore extends ChatStore {
  _FakeChatStore({
    List<ChatConversationPreview> conversations = const [],
    List<ChatStoredMessage> messages = const [],
  }) : _conversations = List<ChatConversationPreview>.from(conversations),
       _messages = List<ChatStoredMessage>.from(messages);

  final List<ChatConversationPreview> _conversations;
  final List<ChatStoredMessage> _messages;
  String? lastAccountFilter;
  int readPreviewCount = 0;
  int readMessagesCount = 0;
  final List<String> deletedConversationIds = <String>[];

  void replaceConversations(List<ChatConversationPreview> conversations) {
    _conversations
      ..clear()
      ..addAll(conversations);
  }

  @override
  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) async {
    readPreviewCount += 1;
    lastAccountFilter = currentAccountId;
    return List<ChatConversationPreview>.from(_conversations);
  }

  @override
  Future<List<ChatStoredMessage>> readMessages({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async {
    readMessagesCount += 1;
    return _messages
        .where((message) => message.conversationId == conversationId)
        .toList(growable: false);
  }

  @override
  Future<ChatMessageDisplayBatch> readMessagesForDisplay({
    required String ownerUserId,
    required String currentAccountId,
    required String conversationId,
  }) async {
    // 测试替身必须走当前聊天窗口读取契约，同时保留子类对旧读取入口的可控 Future。
    final messages = await readMessages(
      ownerUserId: ownerUserId,
      currentAccountId: currentAccountId,
      conversationId: conversationId,
    );
    return ChatMessageDisplayBatch(
      messages: messages,
      integrityFailureCount: 0,
    );
  }

  @override
  Future<void> deleteConversation(
    String ownerUserId,
    String conversationId, {
    required ChatBindingFenceToken bindingToken,
  }) async {
    deletedConversationIds.add(conversationId);
    _conversations.removeWhere(
      (conversation) => conversation.conversationId == conversationId,
    );
    _messages.removeWhere(
      (message) => message.conversationId == conversationId,
    );
  }

  @override
  Future<int> outboundQueueCount(String ownerUserId) async {
    return 0;
  }
}

class _PendingChatStore extends _FakeChatStore {
  final Completer<List<ChatConversationPreview>> completer =
      Completer<List<ChatConversationPreview>>();

  @override
  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) => completer.future;
}

class _UnavailableRecordsChatStore extends _FakeChatStore {
  @override
  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) async => throw const AccountSecurityException('系统保护记录不可用');
}

class _FakeProfileApi extends CitizenProfileApi {
  _FakeProfileApi(this.profile);

  final CitizenProfile profile;
  int calls = 0;

  @override
  Future<CitizenProfileCard> fetchCard(
    String cidNumber, {
    SquareSession? session,
  }) async {
    calls++;
    return CitizenProfileCard(profile.toJson());
  }
}

class _FakeContactService implements UserContactService {
  _FakeContactService(this.contacts);

  final List<UserContact> contacts;

  @override
  Future<List<UserContact>> getContacts() async => contacts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryProfileCache extends CitizenProfileCache {
  const _MemoryProfileCache(this.profile);

  final CitizenProfile profile;

  @override
  Future<CitizenProfile?> read(String cidNumber) async => profile;

  @override
  Future<void> write(CitizenProfile profile) async {}
}

class _MemoryProfileMediaCache extends CitizenProfileMediaCache {
  _MemoryProfileMediaCache(this.snapshot);

  final CitizenProfileMediaSnapshot snapshot;

  @override
  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) async =>
      snapshot;

  @override
  Future<CitizenProfileMediaSnapshot> refresh({
    required CitizenProfile profile,
    required String? avatarUrl,
    required String? bannerUrl,
    required http.Client client,
  }) async => snapshot;
}

class _PendingPreparationSessions implements SquareSessionProvider {
  final pending = Completer<SquareSessionResolution>();
  int calls = 0;
  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected preparation operation');
}

class _FakeProfileSessionProvider implements SquareSessionProvider {
  int calls = 0;
  late final value = SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'profile-token',
    cidNumber: _ownerUserId,
    bindRev: 1,
    accountId:
        '0x1111111111111111111111111111111111111111111111111111111111111111',
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );

  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    return value;
  }

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    final session = await ensureSession();
    return SquareSessionResolution(SquareSessionStatus.ready, session: session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRuntime extends ChatRuntime {
  _FakeRuntime({
    required this.address,
    super.store,
    super.squareSessionProvider,
    super.subscriptionService,
    this.enableRealtime = false,
    this.onDeleteConversation,
    this.retryCompleter,
    this.retryError,
  });

  @override
  Future<ChatRuntimeAccount?> currentAccount({
    String? expectedAccountId,
  }) async => ChatRuntimeAccount(
    hostIndex: 0,
    bindingScope: 'genesis',
    userId: _ownerUserId,
    bindingRevision: 1,
    accountId: address,
    displayName: 'A',
  );
  final String address;
  final bool enableRealtime;
  final Future<void> Function(String conversationId)? onDeleteConversation;
  final Completer<int>? retryCompleter;
  final Object? retryError;
  int syncCount = 0;
  int realtimeStartCount = 0;
  int realtimeStopCount = 0;
  final List<({String? recipientUserId, String? conversationId})> retryScopes =
      [];
  final List<bool> realtimeRetryOutgoingOnConnect = [];
  Future<void> Function()? realtimeNotice;
  Future<void> Function()? realtimeDisconnected;
  // 记录贴纸发送接线的四参,验证 chat_tab 委托到 runtime.sendSticker 无换位/漏接。
  final List<List<String>> sentStickers = <List<String>>[];

  @override
  Future<String?> readAccountId() async {
    return address;
  }

  @override
  Future<String?> readUserId() async => _ownerUserId;

  @override
  Future<List<ChatDeliveryResult>> sendSticker({
    required String peerUserId,
    required String conversationId,
    required String packId,
    required String stickerId,
  }) async {
    sentStickers.add([peerUserId, conversationId, packId, stickerId]);
    return const [];
  }

  @override
  Future<int> retryOutgoing({
    String? recipientUserId,
    String? conversationId,
  }) async {
    syncCount += 1;
    retryScopes.add((
      recipientUserId: recipientUserId,
      conversationId: conversationId,
    ));
    final error = retryError;
    if (error != null) {
      throw error;
    }
    final completer = retryCompleter;
    if (completer != null) {
      return completer.future;
    }
    return 0;
  }

  @override
  Future<void> deleteLocalConversation(String conversationId) async {
    final deleter = onDeleteConversation;
    if (deleter == null) {
      throw StateError('测试未注入 ChatRuntime 会话删除入口');
    }
    await deleter(conversationId);
  }

  @override
  Future<Future<void> Function()?> startRealtimeSync({
    required Future<void> Function() onNotice,
    Future<void> Function()? onDisconnected,
    Future<void> Function(Map<String, dynamic> signal)? onSignal,
    bool retryOutgoingOnConnect = true,
  }) async {
    realtimeStartCount += 1;
    realtimeRetryOutgoingOnConnect.add(retryOutgoingOnConnect);
    realtimeNotice = onNotice;
    realtimeDisconnected = onDisconnected;
    if (!enableRealtime) {
      return null;
    }
    return () async {
      realtimeStopCount += 1;
    };
  }
}

class _AttachmentOnlySubscription implements SubscriptionService {
  int requests = 0;
  @override
  Future<SquareResourceAuthorization> authorizeResources(
    SquareSession session, {
    bool forceRefresh = false,
  }) async {
    requests++;
    throw const SquareApiException('附件会员不可用', statusCode: 503);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSecurity implements AccountSecurityService {
  @override
  final revision = ValueNotifier<int>(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCurrentUser implements CurrentUserContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalChatIdentity implements CurrentUserContext {
  _LocalChatIdentity({this.registered = false});
  final bool registered;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: testMlsAccountId,
      ss58Address: 'synthetic',
      name: '测试账户',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    ),
    binding: registered
        ? IdentityBinding(
            genesisHash: '0x${'ab' * 32}',
            cidNumber: _ownerUserId,
            bindRev: 1,
            accountId: testMlsAccountId,
          )
        : null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoChatChainRecovery implements FinalizedIdentityResolver {
  int reads = 0;
  @override
  Future<FinalizedIdentity?> resolve() async {
    reads++;
    throw StateError('聊天禁止查链');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 真实默认HTTP客户端的网络边界；构造服务本身不计请求，任何发送都立即失败并计数。
class _ChatNetworkCounter implements HttpClient {
  int requests = 0;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests++;
    throw const SocketException('聊天禁止补发会员交易');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyProfileCache extends CitizenProfileCache {
  const _EmptyProfileCache();
  @override
  Future<CitizenProfile?> read(String cidNumber) async => null;
}

class _ScopedPreviews extends _FakeChatStore {
  Future<List<ChatConversationPreview>> Function(String)? onRead;
  @override
  Future<List<ChatConversationPreview>> readConversationPreviews({
    required String ownerUserId,
    required String currentAccountId,
  }) {
    readPreviewCount++;
    return onRead!(ownerUserId);
  }
}

class _DelayedContacts implements UserContactService {
  final held = Completer<List<UserContact>>();
  @override
  Future<List<UserContact>> getContacts() => held.future;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected contact operation');
}

class _DelayedProfileCache extends CitizenProfileCache {
  final held = Completer<CitizenProfile?>();
  @override
  Future<CitizenProfile?> read(String cidNumber) => held.future;
}
