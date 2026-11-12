import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_user/navigation.dart';
import 'package:http/http.dart' as http;

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/mls_authentication_fixture.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as chain_fixture;
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_user/identity/identity_badge.dart';

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/cid_business_gate.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/contacts/contact_book_page.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_system/theme/app_theme.dart';

const _accountId =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const _contactAddress = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
const _contactAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

/// 联系人身份主键 CID 号。通讯录关系按 cid_number 建立，页面直接用它索引公开资料。
const _contactCidNumber = 'CN220-CTZN2-100000001-2026';
final _ownerAccount = CitizenWalletStateAccount(
  signMode: CitizenWalletSignMode.hot,
  walletIndex: 1,
  accountIndex: 0,
  accountId: _accountId,
  ss58Address: 'ss58-owner',
  name: '默认账户',
  createdAtMillis: BigInt.one,
  isDefault: true,
);

IdentityBinding _ownerBinding() => IdentityBinding(
  genesisHash: '0x${'11' * 32}',
  cidNumber: 'CN220-CTZN2-100000009-2026',
  accountId: _accountId,
  bindRev: 1,
);
const _contact = UserContact(
  cidNumber: _contactCidNumber,
  contactRemark: '张三',
  updatedAt: 2,
);
const _profile = CitizenProfile(
  accountId: _contactAccountId,
  displayName: 'Rhett',
  profileBio: '建设一个可信、自由的社会',
  avatarKey: null,
  bannerKey: null,
  cidNumber: _contactCidNumber,
  isCertified: true,
  cidLevel: 'voting',
  memberLevel: 'democracy',
  membergateActive: true,
  following: 1,
  followers: 2,
  mutualFollowing: 1,
  posts: 3,
  campaigns: 0,
  videos: 1,
  articles: 1,
  isFollowing: false,
  isFollowedBy: false,
  isNotifying: false,
  profileAt: 2,
);

class _FakeContacts implements UserContactService {
  @override
  final ValueNotifier<ContactSyncState> syncState =
      ValueNotifier<ContactSyncState>(
        const ContactSyncState(phase: ContactSyncPhase.idle),
      );

  List<UserContact> contacts = <UserContact>[_contact];

  /// `getContacts` 调用次数。未注册时必须为 0——通讯录属主就是 CID,
  /// 没有 CID 连读都不该读(读了必抛 WalletAuthException 并落成假的「空通讯录」)。
  int getContactsCalls = 0;
  int syncCalls = 0;
  int flushCalls = 0;

  @override
  Future<void> flushPending() async {
    flushCalls++;
  }

  @override
  Future<List<UserContact>> getContacts() async {
    getContactsCalls++;
    return contacts;
  }

  @override
  Future<List<UserContact>> sync() async {
    syncCalls++;
    syncState.value = const ContactSyncState(phase: ContactSyncPhase.synced);
    return contacts;
  }

  @override
  Future<ContactSyncState> readSyncState() async =>
      const ContactSyncState(phase: ContactSyncPhase.synced);

  @override
  Future<List<UserContact>> renameContact(
    String cidNumber,
    String contactRemark,
  ) async {
    contacts = <UserContact>[
      UserContact(
        cidNumber: cidNumber,
        contactRemark: contactRemark,
        updatedAt: 3,
      ),
    ];
    return contacts;
  }

  @override
  Future<List<UserContact>> deleteContact(String cidNumber) async {
    contacts = const <UserContact>[];
    return contacts;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailedContacts extends _FakeContacts {
  static final failure = SquareSessionResolution.fromError(
    const SquareApiException('synthetic', statusCode: 503),
  );
  @override
  Future<ContactSyncState> readSyncState() async => ContactSyncState(
    phase: ContactSyncPhase.failed,
    message: failure.message,
    errorCode: failure.errorCode,
    stage: failure.stage,
  );
  @override
  Future<List<UserContact>> sync() async {
    syncState.value = await readSyncState();
    return contacts;
  }
}

class _FailedSessions extends _FakeSessionProvider {
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async => _FailedContacts.failure;
}

class _PendingContacts extends _FakeContacts {
  final Completer<List<UserContact>> completer = Completer<List<UserContact>>();

  @override
  Future<List<UserContact>> getContacts() => completer.future;
}

class _FakeProfileApi extends CitizenProfileApi {
  _FakeProfileApi(this.profile);

  final CitizenProfile profile;
  int cardReads = 0;

  @override
  Future<CitizenProfileCard> fetchCard(
    String cidNumber, {
    SquareSession? session,
  }) async {
    cardReads++;
    return CitizenProfileCard(profile.toJson());
  }
}

class _PendingProfileApi extends CitizenProfileApi {
  final Completer<CitizenProfile> completer = Completer<CitizenProfile>();

  @override
  Future<CitizenProfileCard> fetchCard(
    String cidNumber, {
    SquareSession? session,
  }) =>
      completer.future.then((profile) => CitizenProfileCard(profile.toJson()));
}

class _FakeSessionProvider implements SquareSessionProvider {
  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'token',
    cidNumber: "CN220-CTZN2-198805200-2026",
    bindRev: 1,
    accountId: _accountId,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    final session = await ensureSession();
    return SquareSessionResolution(SquareSessionStatus.ready, session: session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryProfileCache extends CitizenProfileCache {
  const _MemoryProfileCache(this.profile);

  final CitizenProfile? profile;

  @override
  Future<CitizenProfile?> read(String cidNumber) async => profile;

  @override
  Future<void> write(CitizenProfile profile) async {}
}

class _ThrowingProfileCache extends CitizenProfileCache {
  const _ThrowingProfileCache();

  @override
  Future<CitizenProfile?> read(String cidNumber) async =>
      throw StateError('cache unavailable');
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

Widget _page({
  TargetPlatform platform = TargetPlatform.android,
  ContactPickMode mode = ContactPickMode.browse,
  CitizenProfile profile = _profile,
  CitizenProfileApi? profileApi,
  UserContactService? service,
  Map<String, CitizenProfile>? initialProfiles,
  CitizenProfileCache? profileCache,
  CitizenProfileMediaCache? profileMediaCache,
  DirectChatOpener? directChatOpener,
  Future<void> Function(BuildContext context, {required String cidNumber})?
  transferOpener,
  CurrentUserContext? currentUserContext,
  Listenable? identityRevision,
  SquareSessionProvider? sessionProvider,
}) => Provider<CidBusinessGate>.value(
  value: _ReadyBusinessGate(),
  child: MaterialApp(
    theme: AppTheme.lightTheme.copyWith(platform: platform),
    home: ContactBookPage(
      mode: mode,
      service: service ?? _FakeContacts(),
      profileApi: profileApi ?? _FakeProfileApi(profile),
      profileCache: profileCache,
      profileMediaCache: profileMediaCache,
      sessionProvider: sessionProvider ?? _FakeSessionProvider(),
      initialProfiles: initialProfiles ?? {_contactCidNumber: profile},
      directChatOpener: directChatOpener,
      transferOpener: transferOpener,
      currentUserContext: currentUserContext ?? _RegisteredIdentityCache(),
      identityRevision: identityRevision,
    ),
  ),
);

class _ReadyBusinessGate implements CidBusinessGate {
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  @override
  Future<CidBusinessDecision> resolve() async => const CidBusinessDecision(
    CidBusinessStatus.ready,
    cidNumber: _contactCidNumber,
  );
}

/// 身份账户缓存 fake:**已注册**。通讯录属主 = CID,页面对未注册身份整页显示注册
/// 引导,因此常规用例必须注入已注册身份,否则测的全是引导态。
/// `account_id` 仍返回 null,让点开他人主页时 `_resolveOwnAccount` 回退成「非本人」
///;避免 instance 触发真链读/真 Isar。
class _RegisteredIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async =>
      CurrentUser(account: _ownerAccount, binding: _ownerBinding());
  @override
  Future<String?> accountId() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 未注册：当前默认账户的本地绑定为空，不回退到其他账户。
class _UnregisteredIdentityCache implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: _ownerAccount,
    binding: null,
    verifiedUnregistered: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableIdentityCache implements CurrentUserContext {
  bool registered = false;

  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: _ownerAccount,
    binding: registered ? _ownerBinding() : null,
    verifiedUnregistered: !registered,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brokenCache in [false, true]) {
      testWidgets('$platform非空通讯录独立加载徽章，资料缓存故障=$brokenCache', (tester) async {
        final reader = chain_fixture.Reader();
        var head = chain_fixture.block(103);
        final requestedCids = <String>{};
        reader.behavior = (account, block, citizens, creators) async {
          requestedCids.addAll(citizens);
          return chain_fixture.snapshot(
            block,
            account,
            cidNumber: _ownerBinding().cidNumber,
            citizens: citizens,
            creators: creators,
            hasMembership: block.number < BigInt.from(104),
          );
        };
        final source = ChainDataService(
          reader: reader,
          getFinalizedHead: () async => head,
          getGenesisHash: () async => chain_fixture.hash(0),
          getAccount: () async => _accountId,
        );
        addTearDown(source.close);
        await source.start();
        final contacts = _FakeContacts()
          ..contacts = [
            _contact,
            const UserContact(
              cidNumber: chain_fixture.cidB,
              contactRemark: '李四',
              updatedAt: 3,
            ),
          ];
        final profiles = _FakeProfileApi(_profile);
        await tester.pumpWidget(
          ChangeNotifierProvider<ChainDataService>.value(
            value: source,
            child: _page(
              platform: platform,
              service: contacts,
              profileApi: profiles,
              initialProfiles: const {},
              profileCache: brokenCache
                  ? const _ThrowingProfileCache()
                  : const _MemoryProfileCache(null),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('备注：张三'), findsOneWidget);
        expect(find.text('备注：李四'), findsOneWidget);
        expect(
          requestedCids,
          containsAll([_contactCidNumber, chain_fixture.cidB]),
        );
        expect(find.byType(IdentityBadge), findsNWidgets(2));
        for (final badge in tester.widgetList<IdentityBadge>(
          find.byType(IdentityBadge),
        )) {
          expect(badge.style.checked, isTrue);
          expect(badge.tooltip, '访客 · 自由会员');
        }
        head = chain_fixture.block(104);
        await source.refresh();
        await tester.pumpAndSettle();
        for (final badge in tester.widgetList<IdentityBadge>(
          find.byType(IdentityBadge),
        )) {
          expect(badge.style.checked, isFalse);
          expect(badge.tooltip, '访客');
        }
        expect(profiles.cardReads, 0);
        expect(contacts.syncCalls, 0);
        expect(contacts.flushCalls, 0);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  final sdk = TestCitizenSdkHarness(physicalUi: true);
  testWidgets('点击扫码直接启动相机，不等待公民服务会话', (tester) async {
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk.sdk,
        child: _page(sessionProvider: _FailedSessions()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('扫码添加联系人'));
    for (var i = 0; i < 100 && find.byType(Texture).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byType(Texture), findsOneWidget);
    expect(
      sdk.fixture.calls.where((call) => call == 'openQrCapture'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 100 && sdk.fixture.nativeResources.isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(sdk.fixture.nativeResources, isEmpty);
  });
  testWidgets('进页只读本地，下拉只同步通讯录且不逐人刷新资料', (tester) async {
    final service = _FakeContacts();
    final profiles = _FakeProfileApi(_profile);
    await tester.pumpWidget(_page(service: service, profileApi: profiles));
    await tester.pumpAndSettle();
    expect(profiles.cardReads, 0);
    expect(service.syncCalls, 0);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(service.syncCalls, 1);
    expect(profiles.cardReads, 0);
  });
  testWidgets('备注对话框打开后身份变化，不能把旧编辑保存给当前身份', (tester) async {
    final revision = ValueNotifier<int>(0), service = _FakeContacts();
    await tester.pumpWidget(
      _page(service: service, identityRevision: revision),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '李四');
    revision.value++;
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(service.contacts.single.contactRemark, '张三');
    await tester.pumpWidget(const SizedBox());
    revision.dispose();
  });
  testWidgets('删除确认期间身份变化，不能删除当前身份的同CID联系人', (tester) async {
    final revision = ValueNotifier<int>(0), service = _FakeContacts();
    await tester.pumpWidget(
      _page(service: service, identityRevision: revision),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除联系人'));
    await tester.pumpAndSettle();
    revision.value++;
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(service.contacts, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    revision.dispose();
  });
  testWidgets('身份变化后的迟到同步错误不污染新页面或泄漏异步异常', (tester) async {
    final revision = ValueNotifier<int>(0), service = _LateSyncContacts();
    await tester.pumpWidget(
      _page(service: service, identityRevision: revision),
    );
    await tester.pumpAndSettle();
    final refreshing = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    revision.value++;
    await tester.pump();
    service.completion.completeError(
      const AccountSecurityException('identity changed'),
    );
    await refreshing;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(service.contacts, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    revision.dispose();
  });
  testWidgets('本地失败状态保留联系人，主动重试失败不清空列表', (tester) async {
    final contacts = _FailedContacts();
    await tester.pumpWidget(
      _page(service: contacts, sessionProvider: _FailedSessions()),
    );
    await tester.pumpAndSettle();
    expect(find.text(_FailedContacts.failure.message), findsOneWidget);
    expect(find.text('备注：张三'), findsOneWidget);
    await tester.tap(find.text(_FailedContacts.failure.message));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('注册验证'), findsNothing);
    expect(find.text('备注：张三'), findsOneWidget);
    expect(contacts.contacts, hasLength(1));
    expect(contacts.flushCalls, 1);
    expect(contacts.syncCalls, 0);
  });
  testWidgets('本地通讯录未返回时直接显示页面结构且不使用整页转圈', (tester) async {
    final service = _PendingContacts();
    await tester.pumpWidget(_page(service: service));
    await tester.pump();

    expect(find.text('我的通讯录'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contacts-local-load-progress')),
      findsOneWidget,
    );
    expect(find.text('正在读取本地通讯录'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    service.completer.complete(const <UserContact>[]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('contacts-local-load-progress')),
      findsNothing,
    );
  });

  testWidgets('联系人卡以公开昵称为主并只展示备注与公民号', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.text('云端已同步'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('contact-card-$_contactCidNumber')),
        matching: find.text('Rhett'),
      ),
      findsOneWidget,
    );
    expect(find.text('备注：张三'), findsOneWidget);
    expect(find.text('公民号：$_contactCidNumber'), findsOneWidget);
    expect(find.textContaining('SS58：'), findsNothing);
    expect(find.text('建设一个可信、自由的社会'), findsNothing);
    expect(
      find.byKey(const ValueKey('contact-card-$_contactCidNumber')),
      findsOneWidget,
    );
  });

  testWidgets('联系人列表首帧直接使用公开资料与本机头像缓存', (tester) async {
    final profile = _profile.copyWith(
      avatarKey:
          'i/$_contactCidNumber/avatar/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    const avatarPath = '/cached/profile/avatar.webp';
    await tester.pumpWidget(
      _page(
        profile: profile,
        initialProfiles: const <String, CitizenProfile>{},
        profileCache: _MemoryProfileCache(profile),
        profileMediaCache: _MemoryProfileMediaCache(
          const CitizenProfileMediaSnapshot(avatarPath: avatarPath),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.imagePath, avatarPath);
    expect(avatar.userImageSet, isTrue);
    expect(avatar.memberLevel, isNull);
    expect(avatar.membergateActive, isFalse);
    expect(avatar.showBadge, isTrue);
  });

  testWidgets('公开资料缓存故障不阻塞通讯录且未知态不显示旧头像徽章', (tester) async {
    final profileApi = _PendingProfileApi();
    await tester.pumpWidget(
      _page(
        initialProfiles: const <String, CitizenProfile>{},
        profileApi: profileApi,
        profileCache: const _ThrowingProfileCache(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('contact-card-$_contactCidNumber')),
      findsOneWidget,
    );
    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.userImageSet, isTrue);
    expect(avatar.showBadge, isTrue);
    expect(find.byType(IdentityBadge), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Android 与 iOS 联系人卡的高度和操作图标一致', (tester) async {
    final sizes = <TargetPlatform, Size>{};
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await tester.pumpWidget(_page(platform: platform));
      await tester.pumpAndSettle();
      sizes[platform] = tester.getSize(
        find.byKey(const ValueKey('contact-card-$_contactCidNumber')),
      );
      expect(tester.getSize(find.byIcon(Icons.more_vert)), const Size(24, 24));
    }

    expect(sizes[TargetPlatform.iOS], sizes[TargetPlatform.android]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索只匹配公开昵称、备注或公民号，不匹配账户地址', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('contact-search')),
      'Rhett',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('contact-card-$_contactCidNumber')),
        matching: find.text('Rhett'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('contact-search')),
      _contactAddress,
    );
    await tester.pump();
    expect(find.text('没有匹配的联系人'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('contact-search')),
      _contactAccountId,
    );
    await tester.pump();
    expect(find.text('没有匹配的联系人'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('contact-search')), '不存在');
    await tester.pump();
    expect(find.text('没有匹配的联系人'), findsOneWidget);
  });

  testWidgets('公开昵称缺失时显示默认昵称而不是把账户当昵称', (tester) async {
    final emptyProfile = _profile.copyWith(displayName: '');
    await tester.pumpWidget(_page(profile: emptyProfile));
    await tester.pumpAndSettle();

    final fallback = ProfilePresentation.forIdentityKey(
      _contactCidNumber,
    ).fallbackName;
    expect(find.text(fallback), findsOneWidget);
    expect(find.textContaining('SS58：'), findsNothing);
  });

  testWidgets('普通点击进入唯一 UserProfilePage', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rhett'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(UserProfilePage), findsOneWidget);
  });

  testWidgets('联系人菜单顺序正确且删除联系人使用红色文字', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    // 显式竖向图标保证 Android/iOS 一致，不依赖平台自适应默认值。
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();

    final labels = <String>['转账', '私信', '修改备注', '删除联系人'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    final deleteText = tester.widget<Text>(find.text('删除联系人'));
    expect(deleteText.style?.color, AppTheme.danger);
  });

  testWidgets('修改私人备注可取消、保存中文或清空', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '李四');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('备注：张三'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '李四');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('备注：李四'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('联系人转账入口只传公民号', (tester) async {
    String? openedCid;
    Future<void> opener(
      BuildContext context, {
      required String cidNumber,
    }) async {
      openedCid = cidNumber;
    }

    await tester.pumpWidget(_page(transferOpener: opener));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转账'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(openedCid, _contact.cidNumber);
  });

  testWidgets('私信复用统一聊天入口并使用公开昵称', (tester) async {
    String? openedPeerCidNumber;
    String? openedTitle;
    Future<void> opener(
      BuildContext context, {
      required String peerUserId,
      required String title,
    }) async {
      // 注入只用于断言路由参数，不替代正式 openDirectChat 实现。
      openedPeerCidNumber = peerUserId;
      openedTitle = title;
    }

    await tester.pumpWidget(_page(directChatOpener: opener));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('联系人操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私信'));
    await tester.pump();

    expect(openedPeerCidNumber, _contactCidNumber);
    expect(openedTitle, 'Rhett');
  });

  testWidgets('发私信模式点联系人直接开私聊、无操作菜单', (tester) async {
    String? openedPeerCidNumber;
    String? openedTitle;
    Future<void> opener(
      BuildContext context, {
      required String peerUserId,
      required String title,
    }) async {
      openedPeerCidNumber = peerUserId;
      openedTitle = title;
    }

    await tester.pumpWidget(
      _page(mode: ContactPickMode.pickForMessage, directChatOpener: opener),
    );
    await tester.pumpAndSettle();

    // 选私信模式:不显示逐项操作菜单,点联系人卡即开私聊。
    expect(find.byTooltip('联系人操作'), findsNothing);
    await tester.tap(find.text('Rhett'));
    await tester.pump();

    expect(openedPeerCidNumber, _contactCidNumber);
    expect(openedTitle, 'Rhett');
  });

  testWidgets('未注册身份显示统一注册引导,且不读通讯录', (tester) async {
    final service = _FakeContacts();
    await tester.pumpWidget(
      _page(service: service, currentUserContext: _UnregisteredIdentityCache()),
    );
    await tester.pumpAndSettle();

    // 整页统一引导,不再是假的「空通讯录」。
    expect(find.text('尚未注册'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('还没有联系人'), findsNothing);
    expect(find.byKey(const ValueKey('contact-search')), findsNothing);

    // 短路铁证:通讯录一次都没读。
    expect(service.getContactsCalls, 0);
  });

  testWidgets('已注册身份正常展示通讯录(引导不误伤)', (tester) async {
    final service = _FakeContacts();
    await tester.pumpWidget(_page(service: service));
    await tester.pumpAndSettle();

    expect(find.text('尚未注册'), findsNothing);
    expect(find.byKey(const ValueKey('contact-search')), findsOneWidget);
    expect(service.getContactsCalls, greaterThan(0));
  });

  testWidgets('同一账户 finalized 注册广播后原地退出尚未注册页', (tester) async {
    final identityCache = _MutableIdentityCache();
    final revision = ValueNotifier<int>(0);
    final service = _FakeContacts();
    await tester.pumpWidget(
      _page(
        service: service,
        currentUserContext: identityCache,
        identityRevision: revision,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚未注册'), findsOneWidget);
    expect(service.getContactsCalls, 0);

    identityCache.registered = true;
    revision.value += 1;
    await tester.pumpAndSettle();

    expect(find.text('尚未注册'), findsNothing);
    expect(find.byKey(const ValueKey('contact-search')), findsOneWidget);
    expect(service.getContactsCalls, greaterThan(0));
  });
}

class _LateSyncContacts extends _FakeContacts {
  final completion = Completer<List<UserContact>>();
  @override
  Future<List<UserContact>> sync() => completion.future;
}
