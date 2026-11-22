// 验证联系人读取、单选私聊和多选建群及失败重试。

import 'dart:async';

import 'package:chat/chat.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_testing/isar_test_env.dart';

const _self = 'CN220-CTZN2-100000001-2026';
const _peer = 'CN220-CTZN2-100000002-2026';
const _other = 'CN220-CTZN2-100000003-2026';
final _account = '0x${'ab' * 32}';
const _contacts = [
  UserContact(cidNumber: _self, contactRemark: '自己', changeVersion: 1),
  UserContact(cidNumber: _peer, contactRemark: '联系人甲', changeVersion: 1),
  UserContact(cidNumber: _other, contactRemark: '联系人乙', changeVersion: 1),
];

class _Identity extends Fake implements CurrentUserContext {
  String cid = _self;
  String accountValue = _account;
  String genesis = '0x${'cd' * 32}';
  int revision = 1;
  int failReads = 0;
  @override
  Future<CurrentUser?> resolve() async {
    if (failReads-- > 0) throw StateError('初次身份读取暂不可用');
    return CurrentUser(
      account: CitizenWalletStateAccount(
        signMode: CitizenWalletSignMode.hot,
        walletIndex: 0,
        accountIndex: 0,
        accountId: accountValue,
        ss58Address: 'synthetic',
        name: '测试账户',
        createdAtMillis: BigInt.zero,
        isDefault: true,
      ),
      binding: IdentityBinding(
        genesisHash: genesis,
        cidNumber: cid,
        accountId: accountValue,
        bindRev: revision,
      ),
    );
  }
}

class _Security extends Fake implements AccountSecurityService {
  _Security(this.revision);
  @override
  final ValueNotifier<int> revision;
}

class _Contacts extends Fake implements UserContactService {
  final completer = Completer<List<UserContact>>();
  int reads = 0;
  @override
  final syncState = ValueNotifier(
    const ContactSyncState(phase: ContactSyncPhase.idle),
  );
  @override
  Future<ContactSyncState> readSyncState() async => syncState.value;
  @override
  Future<List<UserContact>> getContacts() {
    reads++;
    return completer.future;
  }
}

class _Sessions extends Fake implements SquareSessionProvider {
  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async => const SquareSessionResolution(SquareSessionStatus.noWallet);
}

class _Runtime extends Fake implements ChatRuntime {
  final calls = <({String name, List<String> users})>[];
  Completer<ChatGroup>? pending;
  bool fail = false;
  @override
  Future<ChatGroup> createGroup({
    required String name,
    List<String> inviteeUserIds = const [],
  }) async {
    calls.add((name: name, users: [...inviteeUserIds]));
    if (fail) throw StateError('测试建群失败');
    return pending == null ? _group(name) : pending!.future;
  }
}

ChatGroup _group(String name) => ChatGroup(
  groupId: 'grp:$_self:synthetic',
  name: name,
  creatorUserId: _self,
  epoch: 1,
  roster: const [GroupMember(userId: _self, role: GroupMemberRole.admin)],
);

// 真实Navigator接收选择结果，不替换页面内的联系人读取及人数分流。
Future<void> _open(
  WidgetTester tester,
  _Contacts contacts,
  _Runtime runtime,
  void Function(ChatCreateResult?) onResult, {
  _Identity? user,
  ValueNotifier<int>? revision,
}) async {
  final owner = user ?? _Identity();
  final notifier = revision ?? ValueNotifier(0);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // 取消页后让真实Isar异步读取释放原lease，再执行测试框架的强制删库。
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    if (revision == null) notifier.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<CurrentUserContext>.value(value: owner),
        Provider<AccountSecurityService>.value(value: _Security(notifier)),
        Provider<SquareSessionProvider>.value(value: _Sessions()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                onResult(
                  await Navigator.of(context).push<ChatCreateResult>(
                    MaterialPageRoute(
                      builder: (_) => ChatCreatePage(
                        contactService: contacts,
                        runtime: runtime,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开选择页'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开选择页'));
  // 联系人可保持未返回；只推进路由动画，不等待持续的读取进度动画结束。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _select(WidgetTester tester, String name) async {
  // 原通讯录首帧等待真实本地资料缓存；让原生异步读取完成后再操作卡片。
  for (var i = 0; i < 30 && find.text('备注：$name').evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    find.text('备注：$name'),
    findsOneWidget,
    reason: '原通讯录关系及本地缓存读取后应显示联系人备注',
  );
  await tester.ensureVisible(find.text('备注：$name'));
  await tester.tap(find.text('备注：$name'));
  await tester.pumpAndSettle();
}

void main() {
  useIsolatedIsar();
  testWidgets('通讯录等待及空列表保持禁用，自己不列为联系人', (tester) async {
    final contacts = _Contacts();
    await _open(tester, contacts, _Runtime(), (_) {});
    expect(find.text('发起聊天'), findsOneWidget);
    expect(find.text('群名称（选填）'), findsNothing);
    expect(
      find.byKey(const ValueKey('contacts-local-load-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
          .onPressed,
      isNull,
    );
    contacts.completer.complete([_contacts.first]);
    await tester.pumpAndSettle();
    expect(find.text('自己'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(contacts.reads, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('通讯录读取失败不可发起聊天', (tester) async {
    final contacts = _Contacts();
    final runtime = _Runtime();
    await _open(tester, contacts, runtime, (_) {});
    contacts.completer.completeError(StateError('测试通讯录不可用'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
          .onPressed,
      isNull,
    );
    expect(runtime.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单选不建群，返回正确私聊目标及备注', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime();
    ChatCreateResult? result;
    await _open(tester, contacts, runtime, (value) => result = value);
    await _select(tester, '联系人甲');
    expect(find.text('群名称（选填）'), findsNothing);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, (
      targetId: _peer,
      title: '联系人甲',
      isGroup: false,
      owner: (
        genesisHash: '0x${'cd' * 32}',
        cidNumber: _self,
        accountId: _account,
        bindRev: 1,
      ),
    ));
    expect(runtime.calls, isEmpty);
    expect(find.byType(ChatCreatePage), findsNothing);
  });

  for (final name in ['', '  自定群名  ']) {
    testWidgets('多选复用建群且群名选填：$name', (tester) async {
      final contacts = _Contacts()..completer.complete(_contacts);
      final runtime = _Runtime();
      ChatCreateResult? result;
      await _open(tester, contacts, runtime, (value) => result = value);
      await _select(tester, '联系人甲');
      await _select(tester, '联系人乙');
      await tester.enterText(find.widgetWithText(TextField, '群名称（选填）'), name);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(runtime.calls.single.users, [_peer, _other]);
      expect(
        runtime.calls.single.name,
        name.trim().isEmpty ? '群聊' : name.trim(),
      );
      expect(result, (
        targetId: 'grp:$_self:synthetic',
        title: runtime.calls.single.name,
        isGroup: true,
        owner: (
          genesisHash: '0x${'cd' * 32}',
          cidNumber: _self,
          accountId: _account,
          bindRev: 1,
        ),
      ));
      expect(contacts.reads, 1);
    });
  }

  testWidgets('多选退回单选隐藏群名，继续走私聊', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime();
    ChatCreateResult? result;
    await _open(tester, contacts, runtime, (value) => result = value);
    await _select(tester, '联系人甲');
    await _select(tester, '联系人乙');
    await tester.enterText(
      find.widgetWithText(TextField, '群名称（选填）'),
      '不能变成私聊标题',
    );
    await _select(tester, '联系人乙');
    expect(find.text('群名称（选填）'), findsNothing);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result!.isGroup, isFalse);
    expect(result!.title, '联系人甲');
    expect(runtime.calls, isEmpty);
  });

  testWidgets('建群失败保留选择，重试期间不重复创建', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime()..fail = true;
    ChatCreateResult? result;
    await _open(tester, contacts, runtime, (value) => result = value);
    await _select(tester, '联系人甲');
    await _select(tester, '联系人乙');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((w) => w.value == true),
      isTrue,
    );
    runtime
      ..fail = false
      ..pending = Completer<ChatGroup>();
    await tester.tap(find.text('确定'));
    await tester.pump();
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((w) => w.onChanged == null),
      isTrue,
    );
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(runtime.calls.length, 2);
    runtime.pending!.complete(_group('群聊'));
    await tester.pumpAndSettle();
    expect(result!.isGroup, isTrue);
  });

  testWidgets('初次身份读取失败恢复后可继续，不永久禁用创建', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime(), user = _Identity()..failReads = 1;
    ChatCreateResult? result;
    await _open(
      tester,
      contacts,
      runtime,
      (value) => result = value,
      user: user,
    );
    await _select(tester, '联系人甲');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result!.targetId, _peer);
    expect(result!.owner.cidNumber, _self);
    expect(runtime.calls, isEmpty);
  });

  for (final field in ['cid', 'account', 'genesis', 'revision']) {
    testWidgets('提交前绑定$field变化不使用旧联系人创建', (tester) async {
      final contacts = _Contacts()..completer.complete(_contacts);
      final runtime = _Runtime(), user = _Identity();
      ChatCreateResult? result;
      await _open(
        tester,
        contacts,
        runtime,
        (value) => result = value,
        user: user,
      );
      await _select(tester, '联系人甲');
      switch (field) {
        case 'cid':
          user.cid = _other;
        case 'account':
          user.accountValue = '0x${'ef' * 32}';
        case 'genesis':
          user.genesis = '0x${'12' * 32}';
        case 'revision':
          user.revision++;
      }
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(runtime.calls, isEmpty);
      expect(find.byType(ChatCreatePage), findsNothing);
    });
  }
  testWidgets('建群期间身份广播同步失效，迟到群不在新身份打开', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime()..pending = Completer<ChatGroup>();
    final user = _Identity(), revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    ChatCreateResult? result;
    await _open(
      tester,
      contacts,
      runtime,
      (value) => result = value,
      user: user,
      revision: revision,
    );
    await _select(tester, '联系人甲');
    await _select(tester, '联系人乙');
    await tester.tap(find.text('确定'));
    await tester.pump();
    user.cid = _other;
    revision.value++;
    await tester.pumpAndSettle();
    runtime.pending!.complete(_group('旧身份的群'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(runtime.calls.length, 1);
    expect(find.byType(ChatCreatePage), findsNothing);
  });

  testWidgets('取消选择页后建群迟到不再导航', (tester) async {
    final contacts = _Contacts()..completer.complete(_contacts);
    final runtime = _Runtime()..pending = Completer<ChatGroup>();
    ChatCreateResult? result;
    await _open(tester, contacts, runtime, (value) => result = value);
    await _select(tester, '联系人甲');
    await _select(tester, '联系人乙');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    runtime.pending!.complete(_group('群聊'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('打开选择页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
