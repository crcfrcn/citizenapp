import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart' as store;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';

const owner = 'CID-1';
final ownerAccount = '0x${'11' * 32}', peerAccount = '0x${'22' * 32}';
IdentityBinding binding() => IdentityBinding(
  genesisHash: '0x${'aa' * 32}',
  cidNumber: owner,
  bindRev: 1,
  accountId: ownerAccount,
);

class Security implements AccountSecurityService {
  bool probeDatabase = false;
  @override
  final revision = ValueNotifier<int>(0);
  @override
  Future<IdentityBinding?> readIdentityBindingForCid(String cid) async {
    if (probeDatabase) {
      await store.UserIsar.instance.read(
        (db) => db.collection<store.Contact>().count(),
      );
    }
    return binding();
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected security operation');
}

class Current implements CurrentUserContext {
  bool changed = false;
  @override
  Future<CurrentUser?> resolve() async => CurrentUser(
    account: CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: ownerAccount,
      ss58Address: citizenSs58FromAccountId(ownerAccount),
      name: '测试',
      createdAtMillis: BigInt.one,
      isDefault: true,
    ),
    binding: changed ? null : binding(),
  );
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected identity operation');
}

class Sessions implements SquareSessionProvider {
  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    return SquareSession(
      deviceId: 'ab' * 32,
      sessionToken: 'token',
      cidNumber: owner,
      bindRev: 1,
      accountId: ownerAccount,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected session operation');
}

class Api extends SquareApiClient {
  Api() : super(baseUrl: 'https://service.test/api');
  int reads = 0, puts = 0, deletes = 0, clock = 1, pageSize = 1000;
  final records = <String, Map<String, dynamic>>{};
  final sent = <String>[];
  Object? putFailure, deleteFailure, listFailure;
  final putGates = <Completer<void>>[];
  final putStarts = <int, Completer<void>>{};
  Completer<void>? listGate;
  final listStarted = Completer<void>();
  void Function()? afterPut;
  Future<void> waitForPut(int number) => putStarts
      .putIfAbsent(number, Completer<void>.new)
      .future
      .timeout(const Duration(seconds: 3));
  @override
  Future<Map<String, dynamic>> fetchUserContacts({
    required SquareSession session,
    String? cursor,
  }) async {
    reads++;
    sent.add('list');
    if (!listStarted.isCompleted) listStarted.complete();
    final all = records.values.map((r) => Map<String, dynamic>.of(r)).toList();
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final result = {
      'is_ok': true,
      'contacts': all.sublist(start, end),
      'next_cursor': end < all.length ? '$end' : null,
    };
    await listGate?.future;
    if (listFailure != null) throw listFailure!;
    return result;
  }

  @override
  Future<Map<String, dynamic>> saveUserContact({
    required SquareSession session,
    required String cidNumber,
    required String accountId,
    required String contactRemark,
  }) async {
    puts++;
    final number = puts;
    sent.add('put:$cidNumber');
    putStarts.putIfAbsent(number, Completer<void>.new).complete();
    if (number <= putGates.length) await putGates[number - 1].future;
    if (putFailure != null) throw putFailure!;
    final contact = {
      'cid_number': cidNumber,
      'account_id': accountId,
      'contact_remark': contactRemark,
      'updated_at': clock++,
    };
    records[cidNumber] = contact;
    afterPut?.call();
    return {'is_ok': true, 'contact': contact};
  }

  @override
  Future<Map<String, dynamic>> deleteUserContact({
    required SquareSession session,
    required String cidNumber,
  }) async {
    deletes++;
    sent.add('delete:$cidNumber');
    if (deleteFailure != null) throw deleteFailure!;
    records.remove(cidNumber);
    return {'is_ok': true, 'deleted_cid_number': cidNumber};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late Security security;
  late Current current;
  late Sessions sessions;
  late Api api;
  UserContactService service({bool automatic = true}) => UserContactService(
    accountSecurity: security,
    currentUserContext: current,
    sessionProvider: sessions,
    apiClient: api,
    autoSync: automatic,
  );
  setUp(() {
    security = Security();
    current = Current();
    sessions = Sessions();
    api = Api();
  });
  tearDown(() {
    api.close();
    security.revision.dispose();
  });
  Future<int> rowCount() => store.UserIsar.instance.read(
    (db) => db.collection<store.Contact>().count(),
  );
  Future<store.Contact> row() => store.UserIsar.instance.read(
    (db) async =>
        (await db.collection<store.Contact>().where().findAll()).single,
  );
  Future<void> add(UserContactService s, {String remark = '同事'}) async {
    await s.addContact(
      cidNumber: 'CID-2',
      accountId: peerAccount,
      contactRemark: remark,
    );
  }

  test('本地查看搜索所需数据不获取会话，不同步未变内容', () async {
    final s = service(automatic: false);
    await add(s);
    await s.renameContact('CID-2', 'Alice');
    final contact = (await s.getContacts()).single;
    await s.readSyncState();
    expect(contact.ss58Address, citizenSs58FromAccountId(peerAccount));
    expect(contact.contactRemark, 'Alice');
    expect(sessions.calls, 0);
    expect(api.sent, isEmpty);
    await s.flushPending();
    final calls = sessions.calls;
    await add(s, remark: 'Alice');
    await s.renameContact('CID-2', 'Alice');
    await s.getContacts();
    await s.flushPending();
    expect(api.puts, 1);
    expect(api.reads, 0);
    expect(sessions.calls, calls);
  });
  test('自动新增与备注修改各只上传变化项，不读取清单', () async {
    final s = service();
    await add(s);
    await s.flushPending();
    expect(api.puts, 1);
    expect(api.records['CID-2']!['contact_remark'], '同事');
    await s.renameContact('CID-2', 'Bob');
    await s.flushPending();
    expect(api.puts, 2);
    expect(api.reads, 0);
    expect(api.records['CID-2']!['contact_remark'], 'Bob');
    await add(s, remark: '');
    await s.flushPending();
    expect(api.puts, 2);
  });
  test('离线变更同条落盘，重新打开后只补发最终值', () async {
    final s = service(automatic: false);
    await add(s);
    await s.renameContact('CID-2', 'Bob');
    await (await store.UserIsar.instance.db()).close();
    final reopened = service(automatic: false);
    expect((await reopened.getContacts()).single.contactRemark, 'Bob');
    await reopened.flushPending();
    expect(api.puts, 1);
    expect(api.reads, 0);
    expect((await row()).pendingAction, '');
  });
  test('删除立即隐藏，失败保留待删除动作，成功后物理清除', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    expect(await s.deleteContact('CID-2'), isEmpty);
    expect(await rowCount(), 1);
    api.deleteFailure = const SocketException('synthetic');
    await s.flushPending();
    expect(await s.getContacts(), isEmpty);
    expect((await row()).pendingAction, 'delete');
    expect(api.records, hasLength(1));
    api.deleteFailure = null;
    await s.flushPending();
    expect(await rowCount(), 0);
    expect(api.records, isEmpty);
    final requests = api.sent.length;
    await s.deleteContact('CID-2');
    await s.flushPending();
    expect(api.sent.length, requests);
  });
  test('下拉先补发再完整读取，云端备注覆盖已确认旧值，未变项不上传', () async {
    final s = service(automatic: false);
    await add(s);
    await s.sync();
    expect(api.sent, ['put:CID-2', 'list']);
    api.records['CID-2']!['contact_remark'] = '远端';
    api.records['CID-2']!['updated_at'] = 30;
    expect((await s.sync()).single.contactRemark, '远端');
    expect(api.puts, 1);
    api.records.clear();
    expect(await s.sync(), isEmpty);
    expect(await rowCount(), 0);
    expect(api.puts, 1);
  });
  test('云端完整分页读取恢复全部备注，不逐条写回', () async {
    api.pageSize = 1;
    for (var i = 2; i < 5; i++) {
      api.records['CID-$i'] = {
        'cid_number': 'CID-$i',
        'account_id': peerAccount,
        'contact_remark': '朋友',
        'updated_at': i,
      };
    }
    final s = service();
    expect(await s.sync(), hasLength(3));
    expect(api.reads, 3);
    expect(api.puts + api.deletes, 0);
  });
  test('同步中再次编辑，旧回执不能清除新变更', () async {
    api.putGates.addAll([Completer<void>(), Completer<void>()]);
    final s = service();
    await add(s);
    await api.waitForPut(1);
    await s.renameContact('CID-2', 'Bob');
    api.putGates[0].complete();
    await api.waitForPut(2);
    expect((await row()).pendingAction, 'put');
    expect((await s.getContacts()).single.contactRemark, 'Bob');
    api.putGates[1].complete();
    await s.flushPending();
    expect(api.records['CID-2']!['contact_remark'], 'Bob');
    expect((await row()).pendingAction, '');
  });
  test('拉取期间新修改保留，并在当前全量任务后上传', () async {
    final s = service();
    await add(s);
    await s.flushPending();
    api.listGate = Completer<void>();
    final refreshing = s.sync();
    await api.listStarted.future;
    await s.renameContact('CID-2', 'Bob');
    api.listGate!.complete();
    await refreshing;
    await s.flushPending();
    expect((await s.getContacts()).single.contactRemark, 'Bob');
    expect(api.records['CID-2']!['contact_remark'], 'Bob');
  });
  test('同时到达的补传事件共用一次在途写入，失败不排队重试', () async {
    final s = service(automatic: false);
    await add(s);
    api.putGates.add(Completer<void>());
    api.putFailure = const SocketException('synthetic');
    final first = s.flushPending();
    await api.waitForPut(1);
    final second = s.flushPending();
    await pumpEventQueue();
    api.putGates[0].complete();
    await Future.wait([first, second]);
    expect(api.puts, 1);
    expect(api.reads, 0);
    expect((await row()).pendingAction, 'put');
  });
  test('并发下拉共用一次清单请求', () async {
    final s = service();
    api.listGate = Completer<void>();
    final first = s.sync();
    await api.listStarted.future;
    final second = s.sync();
    await pumpEventQueue();
    expect(api.reads, 1);
    api.listGate!.complete();
    await Future.wait([first, second]);
    expect(api.reads, 1);
  });
  test('待发失败不读取整本，也不覆盖尚未备份的本地备注', () async {
    final s = service(automatic: false);
    await add(s);
    api.putFailure = const SocketException('synthetic');
    await s.sync();
    expect(api.puts, 1);
    expect(api.reads, 0);
    expect((await s.getContacts()).single.contactRemark, '同事');
    expect((await row()).pendingAction, 'put');
    api.putFailure = null;
    await s.flushPending();
    expect(api.puts, 2);
    expect(api.reads, 0);
  });
  test('身份读取不在主库事务内，迟到回执不能清除原属主待发动作', () async {
    security.probeDatabase = true;
    final s = service(automatic: false);
    await add(s);
    api.afterPut = () => current.changed = true;
    await s.flushPending();
    expect((await row()).pendingAction, 'put');
    expect((await row()).ownerCidNumber, owner);
  });
  test('拒绝自身和不合法备注，未发起任何云端操作', () async {
    final s = service();
    await expectLater(
      s.addContact(cidNumber: owner, accountId: peerAccount, contactRemark: ''),
      throwsFormatException,
    );
    await expectLater(
      s.addContact(
        cidNumber: 'CID-2',
        accountId: peerAccount,
        contactRemark: '朋友1',
      ),
      throwsFormatException,
    );
    expect(api.sent, isEmpty);
    expect(sessions.calls, 0);
  });
}
