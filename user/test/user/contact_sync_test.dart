import 'package:citizen_storage/isar_core_bootstrap.dart';
import 'dart:convert';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart' as store;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_user/contacts/contact_scan.dart';
import 'package:citizen_user/contacts/contact_service.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';

const owner = 'CID-1';
late String ownerAccount;
int boundRev = 1;
IdentityBinding binding() => IdentityBinding(
  genesisHash: '0x${'aa' * 32}',
  cidNumber: owner,
  bindRev: boundRev,
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
  Future<SquareSession?> ensureSession() => ensureContactSession();
  @override
  Future<SquareSession?> ensureContactSession() async {
    calls++;
    return SquareSession(
      deviceId: 'ab' * 32,
      sessionToken: 'token',
      cidNumber: owner,
      bindRev: boundRev,
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
  int reads = 0, puts = 0, deletes = 0, pageSize = 1000;
  final records = <String, Map<String, dynamic>>{};
  final sent = <String>[];
  final deleteSelections = <List<String>>[];
  final signedDeletes = <String>[];
  bool partialDeleteFailure = false;
  Object? putFailure, deleteFailure, listFailure;
  int? listFailureAt;
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
    if (listFailure != null &&
        (listFailureAt == null || listFailureAt == reads))
      throw listFailure!;
    return result;
  }

  @override
  Future<Map<String, dynamic>> saveUserContact({
    required SquareSession session,
    required String cidNumber,
    required String contactRemark,
    required int changeVersion,
  }) async {
    puts++;
    final number = puts;
    sent.add('put:$cidNumber');
    putStarts.putIfAbsent(number, Completer<void>.new).complete();
    if (number <= putGates.length) await putGates[number - 1].future;
    if (putFailure != null) throw putFailure!;
    final old = records[cidNumber];
    if (old != null && old['change_version'] != changeVersion)
      return {
        'is_ok': true,
        'contact': Map<String, dynamic>.of(old),
        'conflict':
            old['deleted'] == true || old['contact_remark'] != contactRemark,
      };
    final contact = {
      'cid_number': cidNumber,
      'contact_remark': contactRemark,
      'change_version': changeVersion + 1,
      'deleted': false,
    };
    records[cidNumber] = contact;
    afterPut?.call();
    return {'is_ok': true, 'contact': contact, 'conflict': false};
  }

  @override
  Future<Map<String, dynamic>> deleteUserContacts({
    required SquareSession session,
    required Map<String, dynamic> signed,
    List<String>? remainingCids,
  }) async {
    deletes++;
    signedDeletes.add(jsonEncode(signed));
    final all = ((signed['intent'] as Map)['contacts'] as List).cast<Map>();
    deleteSelections.add(
      remainingCids ?? all.map((r) => r['cid_number'] as String).toList(),
    );
    if ((signed['intent'] as Map)['bind_rev'] != session.bindRev)
      throw const SquareApiException(
        'synthetic',
        statusCode: 403,
        errorCode: 'contact_delete_signature_invalid',
      );
    if (deleteFailure != null) throw deleteFailure!;
    final results = <Map<String, dynamic>>[];
    for (final target in ((signed['intent'] as Map)['contacts'] as List).where(
      (t) =>
          remainingCids == null ||
          remainingCids.contains((t as Map)['cid_number']),
    )) {
      final cid = (target as Map)['cid_number'] as String;
      if (partialDeleteFailure && results.isNotEmpty) {
        final done = results
            .map((r) => (r['contact'] as Map)['cid_number'])
            .toSet();
        return {
          'is_ok': true,
          'results': results,
          'remaining_cids': deleteSelections.last
              .where((id) => !done.contains(id))
              .toList(),
          'error_code': 'object_storage_unavailable',
          'status_code': 503,
        };
      }
      sent.add('delete:$cid');
      final version = target['change_version'] as int;
      final old = records[cid];
      if (old != null && old['change_version'] != version) {
        results.add({
          'contact': Map<String, dynamic>.of(old),
          'conflict': old['deleted'] != true,
        });
        continue;
      }
      final row = <String, dynamic>{
        'cid_number': cid,
        'contact_remark': '',
        'change_version': version + 1,
        'deleted': true,
      };
      records[cid] = row;
      results.add({'contact': Map<String, dynamic>.of(row), 'conflict': false});
    }
    return {'is_ok': true, 'results': results};
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
  late CitizenSdk sdk;
  var signatures = 0;
  Future<Uint8List> sign(String account, Uint8List payload) async {
    signatures++;
    final result =
        await sdk
                .beginSigning(
                  CitizenSigningIntent(
                    accountId: account,
                    payload: payload,
                    transform: CitizenSigningTransform.raw(),
                  ),
                )
                .result
            as CitizenSigningCompleted;
    return result.signature;
  }

  setUp(() async {
    final opened = await openTestSdk(
      modules:
          CitizenSdkModules.wallet |
          CitizenSdkModules.signing |
          CitizenSdkModules.qr,
      vaultMode: 1,
    );
    sdk = opened.sdk;
    await sdk
        .importWallet(
          mnemonic:
              "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        )
        .result;
    ownerAccount =
        (await sdk.getWalletState().result).defaultAccount!.accountId;
    signatures = 0;
    boundRev = 1;
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
    await s.addContact(cidNumber: 'CID-2', contactRemark: remark);
  }

  test('本地查看搜索所需数据不获取会话，不同步未变内容', () async {
    final s = service(automatic: false);
    await add(s);
    await s.renameContact('CID-2', 'Alice');
    final contact = (await s.getContacts()).single;
    await s.readSyncState();
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
  test('扫码按 CID 离线落盘，重复扫到不同钱包仍保留备注', () async {
    final s = service(automatic: false);
    Future<ContactImportResult> scan(String accountId) => addUserQrContact(
      contactService: s,
      body: CitizenQrDocument(
        kind: CitizenQrKind.userContact,
        canonicalText: '',
        scanPurposeMask: 0,
        cidNumber: 'CID-2',
        accountId: accountId,
      ),
    );
    expect((await scan('0x${'22' * 32}')).created, isTrue);
    expect(sessions.calls, 0);
    expect(api.sent, isEmpty);
    expect((await row()).pendingAction, 'put');
    await s.renameContact('CID-2', '同事');
    await s.flushPending();
    final requests = List.of(api.sent);
    final sessionCalls = sessions.calls;
    final duplicate = await scan('0x${'33' * 32}');
    expect(duplicate.created, isFalse);
    expect(duplicate.contact.contactRemark, '同事');
    await s.flushPending();
    expect(api.sent, requests);
    expect(sessions.calls, sessionCalls);
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
  test('删除立即隐藏，失败保留待发，成功保留高版本删除标记', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    expect(await s.deleteContact('CID-2', signer: sign), isEmpty);
    expect(await rowCount(), 1);
    api.deleteFailure = const SocketException('synthetic');
    await s.flushPending();
    expect(await s.getContacts(), isEmpty);
    expect((await row()).pendingAction, 'delete');
    expect(api.records, hasLength(1));
    api.deleteFailure = null;
    await s.flushPending();
    expect(await rowCount(), 1);
    expect(api.records['CID-2']!['deleted'], isTrue);
    expect(signatures, 1);
    final requests = api.sent.length;
    await s.deleteContact('CID-2', signer: sign);
    await s.flushPending();
    expect(api.sent.length, requests);
  });
  test('下拉先补发再完整读取，云端备注覆盖已确认旧值，未变项不上传', () async {
    final s = service(automatic: false);
    await add(s);
    await s.sync();
    expect(api.sent, ['put:CID-2', 'list']);
    api.records['CID-2']!['contact_remark'] = '远端';
    api.records['CID-2']!['change_version'] = 30;
    expect((await s.sync()).single.contactRemark, '远端');
    expect(api.puts, 1);
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '',
      'change_version': 31,
      'deleted': true,
    };
    expect(await s.sync(), isEmpty);
    expect(await rowCount(), 1);
    expect(api.puts, 1);
  });
  test('云端完整分页读取恢复全部备注，不逐条写回', () async {
    api.pageSize = 1;
    for (var i = 2; i < 5; i++) {
      api.records['CID-$i'] = {
        'cid_number': 'CID-$i',
        'contact_remark': '朋友',
        'change_version': i,
        'deleted': false,
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
  test('拉取失败保留本地联系人，补发不会重试全量拉取', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    api.listFailure = const SocketException('synthetic');
    expect((await s.sync()).single.contactRemark, '同事');
    final failed = await s.readSyncState();
    expect(failed.phase, ContactSyncPhase.offline);
    expect(failed.retryByPull, isTrue);
    await s.flushPending();
    expect(api.reads, 1);
    expect(api.puts, 1);
    expect((await s.readSyncState()).retryByPull, isTrue);
    expect((await s.readSyncState()).phase, isNot(ContactSyncPhase.synced));
    api.listFailure = null;
    expect(await s.sync(), hasLength(1));
    expect((await s.readSyncState()).phase, ContactSyncPhase.synced);
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
      s.addContact(cidNumber: owner, contactRemark: ''),
      throwsFormatException,
    );
    await expectLater(
      s.addContact(cidNumber: 'CID-2', contactRemark: '朋友1'),
      throwsFormatException,
    );
    expect(api.sent, isEmpty);
    expect(sessions.calls, 0);
  });
  test('批量删除只签一次，备份失败重试不重签，其他副本恢复不签名', () async {
    final a = service(automatic: false);
    await add(a);
    await a.addContact(cidNumber: 'CID-3', contactRemark: '朋友');
    await a.flushPending();
    await a.deleteContacts(['CID-3', 'CID-2', 'CID-2'], signer: sign);
    expect(signatures, 1);
    expect(await a.getContacts(), isEmpty);
    api.deleteFailure = const SocketException('synthetic');
    await a.flushPending();
    api.deleteFailure = null;
    await a.flushPending();
    expect(signatures, 1);
    await store.UserIsar.instance.writeTxn((db) async {
      await db.collection<store.Contact>().clear();
      for (final cid in ['CID-2', 'CID-3']) {
        await db.collection<store.Contact>().put(
          store.Contact()
            ..ownerCidNumber = owner
            ..cidNumber = cid
            ..contactRemark = '朋友'
            ..changeVersion = 1
            ..deleted = false,
        );
      }
    });
    final b = service(automatic: false);
    await b.sync();
    expect(await b.getContacts(), isEmpty);
    expect(signatures, 1);
  });
  test('高版本删除覆盖旧待发修改，不复活联系人', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    await s.renameContact('CID-2', '旧修改');
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '',
      'change_version': 2,
      'deleted': true,
    };
    await s.sync();
    expect(await s.getContacts(), isEmpty);
    expect((await row()).changeVersion, 2);
  });
  test('第二页失败不应用第一页，保留完整本机通讯录', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    api.pageSize = 1;
    api.records['CID-3'] = {
      'cid_number': 'CID-3',
      'contact_remark': '朋友',
      'change_version': 1,
      'deleted': false,
    };
    api.listFailure = const SocketException('synthetic');
    api.listFailureAt = api.reads + 2;
    await s.sync();
    expect((await s.getContacts()).single.cidNumber, 'CID-2');
  });
  test('错误钱包签名不能删除，也不保存待发批次', () async {
    final s = service(automatic: false);
    await add(s);
    await expectLater(
      s.deleteContact('CID-2', signer: (_, _) async => Uint8List(64)),
      throwsA(isA<Exception>()),
    );
    expect(await s.getContacts(), hasLength(1));
    expect((await row()).pendingAction, 'put');
  });
  test('本机删除和备注只有一个正式版本，未提交不伪造版本', () async {
    final s = service(automatic: false);
    await add(s);
    expect((await row()).changeVersion, 0);
    await s.flushPending();
    expect((await row()).changeVersion, 1);
    await s.renameContact('CID-2', '新备注');
    expect((await row()).changeVersion, 1);
    await s.flushPending();
    expect((await row()).changeVersion, 2);
  });
  test('前台自动退避三次后停止，原待发记录持续保留', () async {
    final s = service();
    api.putFailure = const SocketException('synthetic');
    await add(s);
    for (var n = 1; n <= 4; n++) {
      await api.putStarts
          .putIfAbsent(n, Completer<void>.new)
          .future
          .timeout(const Duration(seconds: 90));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(api.puts, 4);
    expect((await row()).pendingAction, 'put');
    expect(s.syncState.value.phase, ContactSyncPhase.offline);
    s.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('删除后重新添加只继续原版本计数，仍只有一次删除签名', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    await s.deleteContact('CID-2', signer: sign);
    await s.addContact(cidNumber: 'CID-2', contactRemark: '新备注');
    await s.flushPending();
    expect((await s.getContacts()).single.changeVersion, 3);
    expect((await s.getContacts()).single.contactRemark, '新备注');
    expect(signatures, 1);
  });
  test('冲突回执遇本机再次改备注不能复活高版本删除', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    api.putGates.addAll([Completer<void>()..complete(), Completer<void>()]);
    await s.renameContact('CID-2', '旧修改');
    final flushing = s.flushPending();
    await api.waitForPut(2);
    await s.renameContact('CID-2', '再次修改');
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '',
      'change_version': 2,
      'deleted': true,
    };
    api.putGates[1].complete();
    await flushing;
    expect(await s.getContacts(), isEmpty);
    expect(api.puts, 2);
    expect((await row()).changeVersion, 2);
  });
  test('旧库读取不写回，未备份备注建立基线后仍需原保存动作确认', () async {
    final s = service(automatic: false);
    await store.UserIsar.instance.writeTxn(
      (db) => db.collection<store.Contact>().put(
        store.Contact()
          ..ownerCidNumber = owner
          ..cidNumber = 'CID-2'
          ..contactRemark = '未备份'
          ..changeVersion = 8
          ..pendingAction = 'put',
      ),
    );
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '旧备注',
      'change_version': 1,
      'deleted': false,
    };
    await s.getContacts();
    expect((await row()).changeVersion, 8);
    expect((await row()).deleted, isNull);
    await s.sync();
    expect((await row()).contactRemark, '未备份');
    expect((await row()).pendingAction, 'legacy_put');
    expect((await row()).changeVersion, 1);
    expect(api.puts, 0);
    await s.renameContact('CID-2', '未备份');
    await s.flushPending();
    expect(api.records['CID-2']!['contact_remark'], '未备份');
    expect((await row()).changeVersion, 2);
  });
  test('旧库下载失败原内容计数和待发状态均不变', () async {
    final s = service(automatic: false);
    await store.UserIsar.instance.writeTxn(
      (db) => db.collection<store.Contact>().put(
        store.Contact()
          ..ownerCidNumber = owner
          ..cidNumber = 'CID-2'
          ..contactRemark = '未备份'
          ..changeVersion = 8
          ..pendingAction = 'put',
      ),
    );
    api.listFailure = const SocketException('synthetic');
    await s.sync();
    expect((await row()).contactRemark, '未备份');
    expect((await row()).changeVersion, 8);
    expect((await row()).deleted, isNull);
    expect((await row()).pendingAction, 'put');
    expect(api.puts, 0);
  });
  test('迁移下载期间新编辑使用事务内最新行，不被旧快照覆盖', () async {
    final s = service(automatic: false);
    await store.UserIsar.instance.writeTxn(
      (db) => db.collection<store.Contact>().put(
        store.Contact()
          ..ownerCidNumber = owner
          ..cidNumber = 'CID-2'
          ..contactRemark = '旧本机'
          ..changeVersion = 8,
      ),
    );
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '云端',
      'change_version': 1,
      'deleted': false,
    };
    api.listGate = Completer<void>();
    final syncing = s.sync();
    await api.listStarted.future;
    await s.renameContact('CID-2', '新编辑');
    api.listGate!.complete();
    await syncing;
    expect((await row()).contactRemark, '新编辑');
    expect((await row()).pendingAction, 'legacy_put');
    expect(api.puts, 0);
  });
  test('旧无签名删除只恢复基线，原删除入口整批签一次', () async {
    final s = service(automatic: false);
    await store.UserIsar.instance.writeTxn(
      (db) => db.collection<store.Contact>().put(
        store.Contact()
          ..ownerCidNumber = owner
          ..cidNumber = 'CID-2'
          ..contactRemark = '同事'
          ..changeVersion = 8
          ..pendingAction = 'delete',
      ),
    );
    api.records['CID-2'] = {
      'cid_number': 'CID-2',
      'contact_remark': '同事',
      'change_version': 1,
      'deleted': false,
    };
    await s.sync();
    expect(signatures, 0);
    expect(api.deletes, 0);
    expect(await s.getContacts(), hasLength(1));
    await s.deleteContact('CID-2', signer: sign);
    await s.flushPending();
    expect(signatures, 1);
    expect(api.records['CID-2']!['deleted'], isTrue);
  });
  test('换绑后旧授权永久拒绝不阻塞其它备份与下拉恢复', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    await s.deleteContact('CID-2', signer: sign);
    boundRev = 2;
    security.revision.value++;
    await s.addContact(cidNumber: 'CID-3', contactRemark: '朋友');
    await s.sync();
    expect(signatures, 1);
    expect(api.deletes, 1);
    expect(api.reads, 1);
    expect(api.records.containsKey('CID-3'), isTrue);
    expect(await s.getContacts(), hasLength(2));
    await s.sync();
    expect(api.deletes, 1);
    expect(
      await store.UserIsar.instance.read(
        (db) => db.collection<store.ContactDeleteBatch>().count(),
      ),
      0,
    );
  });
  test('部分回执保存已完成项，剩余子集重试复用同一份签名', () async {
    final s = service(automatic: false);
    await add(s);
    await s.addContact(cidNumber: 'CID-3', contactRemark: '朋友');
    await s.flushPending();
    await s.deleteContacts(['CID-2', 'CID-3'], signer: sign);
    api.partialDeleteFailure = true;
    await s.flushPending();
    api.partialDeleteFailure = false;
    await s.flushPending();
    expect(api.deleteSelections, [
      ['CID-2', 'CID-3'],
      ['CID-3'],
    ]);
    expect(api.signedDeletes[0], api.signedDeletes[1]);
    expect(signatures, 1);
    expect(await s.getContacts(), isEmpty);
  });
  test('429等待不能被新变更、身份广播或前后台同步绕过', () async {
    final s = service(automatic: false);
    await add(s);
    api.putFailure = const SquareApiException(
      'synthetic',
      statusCode: 429,
      retryAfter: Duration(milliseconds: 150),
    );
    await s.flushPending();
    expect(api.puts, 1);
    s.setForeground(false);
    s.setForeground(true);
    s.invalidate();
    await s.renameContact('CID-2', '新备注');
    await s.flushPending();
    await s.sync();
    expect(api.puts, 1);
    expect(api.reads, 0);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    api.putFailure = null;
    await s.flushPending();
    expect(api.puts, 2);
    s.dispose();
  });
  test('排队的同步任务也必须遵守刚建立的429等待', () async {
    final s = service(automatic: false);
    await add(s);
    api.putGates.add(Completer<void>());
    api.putFailure = const SquareApiException(
      'synthetic',
      statusCode: 429,
      retryAfter: Duration(milliseconds: 150),
    );
    final flushing = s.flushPending();
    await api.waitForPut(1);
    final syncing = s.sync();
    await pumpEventQueue();
    api.putGates[0].complete();
    await Future.wait([flushing, syncing]);
    expect(api.puts, 1);
    expect(api.reads, 0);
    s.dispose();
  });
  test('两个隔离本机数据库经R2恢复删除结果，B不重新签名', () async {
    final directoryA = IsarCoreBootstrap.debugTestDirectoryOverride!;
    final directoryB = Directory.systemTemp.createTempSync('replica-b-');
    addTearDown(() async {
      await (await store.UserIsar.instance.db()).close();
      IsarCoreBootstrap.debugTestDirectoryOverride = directoryA;
      if (directoryB.existsSync()) directoryB.deleteSync(recursive: true);
    });
    final a = service(automatic: false);
    await add(a);
    await a.flushPending();
    await (await store.UserIsar.instance.db()).close();
    IsarCoreBootstrap.debugTestDirectoryOverride = directoryB.path;
    final b = service(automatic: false);
    expect(await b.getContacts(), isEmpty);
    await b.sync();
    expect(await b.getContacts(), hasLength(1));
    await (await store.UserIsar.instance.db()).close();
    IsarCoreBootstrap.debugTestDirectoryOverride = directoryA;
    await a.deleteContact('CID-2', signer: sign);
    await a.flushPending();
    expect(signatures, 1);
    await (await store.UserIsar.instance.db()).close();
    IsarCoreBootstrap.debugTestDirectoryOverride = directoryB.path;
    await b.sync();
    expect(await b.getContacts(), isEmpty);
    expect((await row()).changeVersion, 2);
    expect(signatures, 1);
  });
  test('恢复失败后补传新修改不能假报恢复成功', () async {
    final s = service(automatic: false);
    await add(s);
    await s.flushPending();
    api.listFailure = const SocketException('synthetic');
    await s.sync();
    await s.renameContact('CID-2', '新备注');
    await s.flushPending();
    expect(api.reads, 1);
    expect(api.records['CID-2']!['contact_remark'], '新备注');
    expect((await s.readSyncState()).retryByPull, isTrue);
    expect((await s.readSyncState()).phase, isNot(ContactSyncPhase.synced));
    api.listFailure = null;
    await s.sync();
    expect((await s.readSyncState()).retryByPull, isFalse);
    expect((await s.readSyncState()).phase, ContactSyncPhase.synced);
  });
}
