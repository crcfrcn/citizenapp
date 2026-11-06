import 'package:citizen_storage/user_isar.dart' as user_store show Notice;
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';

import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_system/notifications/app_push_service.dart';
import 'package:citizen_user/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_testing/isar_test_env.dart';

const _cid = 'CN220-CTZN2-100000008-2026';

class _User implements CurrentUserContext {
  String cid = _cid;
  int bindRev = 1;
  @override
  Future<CurrentUser?> resolve() async {
    final account = '0x${'11' * 32}';
    return CurrentUser(
      account: CitizenWalletStateAccount(
        accountId: account,
        ss58Address: ss58FromAccountIdText(account),
        name: '测试',
        walletIndex: 0,
        accountIndex: 0,
        isDefault: true,
        createdAtMillis: BigInt.one,
        signMode: CitizenWalletSignMode.hot,
      ),
      binding: IdentityBinding(
        genesisHash: '0x${'22' * 32}',
        cidNumber: cid,
        accountId: account,
        bindRev: bindRev,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused user boundary');
}

class _Sessions implements SquareSessionProvider {
  _Sessions(this.user);
  final _User user;
  int calls = 0;
  @override
  Future<SquareSession?> ensureSession() async {
    calls++;
    return SquareSession(
      deviceId: '33' * 32,
      sessionToken: 'synthetic',
      cidNumber: user.cid,
      accountId: '0x${'11' * 32}',
      bindRev: user.bindRev,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused session boundary');
}

Map<String, dynamic> _state(
  int noticeRev,
  int unread, {
  String cid = _cid,
  int bindRev = 1,
}) => {
  'is_ok': true,
  'cid_number': cid,
  'bind_rev': bindRev,
  'notice_rev': noticeRev,
  'square_unread': unread,
  'notifications_unread': 0,
  'following_unread': unread,
  'interaction_unread': 0,
  'interaction_sequence': 0,
  'through': 10,
  'member_rev': 0,
  'creator_rev': 0,
  'membergate': null,
  'creator': null,
};

class _Api extends SquareApiClient {
  _Api() : super(baseUrl: 'https://notifications.test/api');
  int reads = 0, writes = 0;
  final readThrough = <int?>[];
  bool offline = false;
  Completer<Map<String, dynamic>>? heldWrite;
  final writtenIds = <List<int>>[];
  Completer<Map<String, dynamic>>? pending;
  Future<Map<String, dynamic>> Function(SquareSession)? onRead;
  Map<String, dynamic> value = _state(1, 2);
  @override
  Future<Map<String, dynamic>> fetchNotificationState({
    required SquareSession session,
  }) async {
    reads++;
    if (onRead != null) return onRead!(session);
    return pending == null ? value : await pending!.future;
  }

  @override
  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    String? postId,
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) async {
    writes++;
    writtenIds.add(List.of(ids));
    readThrough.add(through);
    if (offline) throw StateError('synthetic offline');
    return heldWrite == null ? value : await heldWrite!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late _User user;
  late _Api api;
  late _Sessions sessions;
  late Notifications service;
  setUp(() {
    user = _User();
    api = _Api();
    sessions = _Sessions(user);
    service = Notifications(api: api, sessions: sessions, user: user);
  });
  tearDown(() {
    service.dispose();
    api.close();
  });
  Map<String, dynamic> cacheState(int revision) => _state(revision, 0)
    ..['interaction_sequence'] = 10
    ..['following_unread'] = 0;
  NotificationListSnapshot list(int revision, {String title = '本机互动'}) =>
      NotificationListSnapshot(
        revision: revision,
        sequence: 10,
        through: 10,
        nextCursor: 5,
        items: [
          {
            'post_id': 'cached-post',
            'post_title': title,
            'post_excerpt': '已获取内容',
            'notice_count': 3,
            'comment_unread': 0,
            'session_token': 'not-a-cache-field',
          },
        ],
      );
  test('通知列表与分页落入原Notice，关闭重开只读本机且不保存多余字段', () async {
    await service.accept(cacheState(7));
    expect(await service.cacheList(service.scope!, list(7)), isTrue);
    final saved = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(saved.listData, isNot(contains('session_token')));
    expect(saved.listData, isNot(contains('cid_number')));
    await (await UserIsar.instance.db()).close();
    final restored = Notifications(api: api, sessions: sessions, user: user);
    addTearDown(restored.dispose);
    expect(await restored.restore(), isTrue);
    expect(restored.cachedList!.nextCursor, 5);
    expect(restored.cachedList!.items.single['post_title'], '本机互动');
    expect(api.reads + api.writes, 0);
    expect(sessions.calls, 0);
  });
  test('列表保存保留计数和待发已读，计数回执也保留列表', () async {
    await service.accept(cacheState(7));
    await service.cacheList(service.scope!, list(7));
    api.offline = true;
    await service.read(
      owner: service.scope,
      scope: 'post',
      postId: 'cached-post',
      through: 10,
    );
    await service.accept(cacheState(8));
    var saved = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(
      NotificationListSnapshot.decode(saved.listData!, service.scope!).revision,
      7,
    );
    expect((jsonDecode(saved.pendingData!) as List), hasLength(1));
    await service.cacheList(service.scope!, list(8));
    saved = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(jsonDecode(saved.stateData)['notice_rev'], 8);
    expect(jsonDecode(saved.pendingData!), hasLength(1));
  });
  test('换绑不采用旧列表或重放旧绑定待发已读，迟到缓存不能写入', () async {
    await service.accept(cacheState(7));
    final old = service.scope!;
    await service.cacheList(old, list(7));
    api.offline = true;
    await service.read(owner: old, scope: 'square', through: 10);
    user.bindRev = 2;
    service.invalidate();
    await service.restore();
    expect(service.cachedList, isNull);
    expect(await service.cacheList(old, list(7)), isFalse);
    api.offline = false;
    api.value = _state(8, 0, bindRev: 2);
    await service.calibrate();
    expect(api.writes, 1);
    expect(api.reads, 1);
  });
  test('等待数据库时请求失效，迟到列表不能覆盖已有缓存', () async {
    await service.accept(cacheState(7));
    final owner = service.scope!;
    await service.cacheList(owner, list(7));
    final entered = Completer<void>(), release = Completer<void>();
    final blocking = UserIsar.instance.read((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    var current = true;
    final saving = service.cacheList(
      owner,
      list(7, title: '迟到内容'),
      isCurrentRequest: () => current,
    );
    await pumpEventQueue();
    current = false;
    release.complete();
    await blocking;
    expect(await saving, isFalse);
    final row = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(
      NotificationListSnapshot.decode(
        row.listData!,
        owner,
      ).items.single['post_title'],
      '本机互动',
    );
  });
  test('损坏列表缓存不展示也不删除原缓存', () async {
    await service.accept(cacheState(7));
    await UserIsar.instance.writeTxn((db) async {
      final row = (await db.notices.getByCidNumber(_cid))!;
      row.listData = '{"items":"bad"}';
      await db.notices.put(row);
    });
    service.invalidate();
    await service.restore();
    expect(service.cachedList, isNull);
    final row = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(row.listData, '{"items":"bad"}');
    expect(api.reads + api.writes, 0);
  });
  test('相同已读选择排序去重，合并在途请求并跳过已确认意图', () async {
    await service.restore();
    api.heldWrite = Completer<Map<String, dynamic>>();
    final first = service.read(owner: service.scope, ids: [2, 1]);
    await pumpEventQueue();
    final second = service.read(owner: service.scope, ids: [1, 2, 2]);
    await pumpEventQueue();
    expect(api.writes, 1);
    api.heldWrite!.complete(_state(2, 0));
    await Future.wait([first, second]);
    final calls = sessions.calls;
    await service.read(owner: service.scope, ids: [2, 1]);
    expect(api.writes, 1);
    expect(api.writtenIds.single, [1, 2]);
    expect(sessions.calls, calls);
  });
  test('仅确认队列维护不通知页面，不触发无数据变化的补拉', () async {
    await service.accept(_state(1, 2));
    var changes = 0;
    service.addListener(() => changes++);
    api.value = _state(1, 2);
    await service.read(owner: service.scope, ids: [1]);
    expect(api.writes, 1);
    expect(changes, 0);
    final row = (await UserIsar.instance.read(
      (db) => db.notices.getByCidNumber(_cid),
    ))!;
    expect(jsonDecode(row.pendingData!), isEmpty);
  });
  test('云端确认后本机保存失败，重复意图只补保存不再POST', () async {
    var failAckSave = true;
    String? pending;
    final controlled = Notifications(
      api: api,
      sessions: sessions,
      user: user,
      cacheWriter: (owner, state, queue, {required isCurrent}) async {
        if (api.writes > 0 &&
            (jsonDecode(queue) as List).isEmpty &&
            failAckSave) {
          failAckSave = false;
          throw StateError('synthetic local write failure');
        }
        pending = queue;
      },
    );
    addTearDown(controlled.dispose);
    await controlled.restore();
    var changes = 0;
    controlled.addListener(() => changes++);
    api.value = _state(2, 0);
    await controlled.read(owner: controlled.scope, ids: [1]);
    expect(api.writes, 1);
    expect(changes, 0);
    expect(jsonDecode(pending!), hasLength(1));
    await controlled.read(owner: controlled.scope, ids: [1]);
    expect(api.writes, 1);
    expect(api.reads, 0);
    expect(changes, 1);
    expect(jsonDecode(pending!), isEmpty);
  });
  test('重复的持久待发意图只重放一次，作用域不会合并', () async {
    final intent = {
      'scope': 'interaction',
      'post_id': null,
      'ids': [2, 1],
      'through': null,
      'post_ids': [],
      'comment_ids': [],
    };
    await UserIsar.instance.writeTxn((db) async {
      await db.notices.put(
        user_store.Notice()
          ..cidNumber = _cid
          ..stateData = jsonEncode(cacheState(1)..remove('cid_number'))
          ..pendingData = jsonEncode([
            intent,
            {
              ...intent,
              'ids': [1, 2, 2],
            },
          ]),
      );
    });
    api.value = cacheState(2);
    await service.calibrate();
    expect(api.writes, 1);
    expect(api.reads, 0);
    await service.read(owner: service.scope, scope: 'square', through: 10);
    expect(api.writes, 2);
  });
  test('父层和通知层回执不使列表失效，内容层变化仍要求刷新', () async {
    await service.accept(cacheState(1));
    await service.cacheList(service.scope!, list(1));
    api.value = cacheState(2);
    await service.read(owner: service.scope, scope: 'square', through: 10);
    expect(service.listRevision, 1);
    api.value = cacheState(3);
    await service.read(
      owner: service.scope,
      scope: 'notifications',
      through: 10,
    );
    expect(service.listRevision, 1);
    api.value = cacheState(4);
    await service.read(
      owner: service.scope,
      scope: 'post',
      postId: 'cached-post',
      through: 10,
    );
    expect(service.listRevision, 4);
  });
  test('旧通知快照拒绝展示且原样保留，读取不升级或删除待回执', () async {
    final old = _state(7, 4);
    old['revision'] = old.remove('notice_rev');
    old['ok'] = old.remove('is_ok');
    old.remove('cid_number');
    final pending = jsonEncode([
      {
        'scope': 'square',
        'ids': [],
        'through': 1,
        'post_ids': [],
        'comment_ids': [],
      },
    ]);
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<user_store.Notice>().put(
        user_store.Notice()
          ..cidNumber = _cid
          ..stateData = jsonEncode(old)
          ..pendingData = pending,
      );
    });
    expect(await service.restore(), true);
    expect(service.noticeRev, 0);
    expect(service.unread, 0);
    expect(api.reads, 0);
    final saved = await UserIsar.instance.read(
      (db) => db.collection<user_store.Notice>().getByCidNumber(_cid),
    );
    expect(saved!.stateData, jsonEncode(old));
    expect(saved.pendingData, pending);
  });
  test('缓存只在自然索引保存CID，重开恢复计数而不联网', () async {
    await service.accept(_state(7, 3));
    final row = (await UserIsar.instance.read(
      (db) => db.collection<user_store.Notice>().getByCidNumber(_cid),
    ))!;
    expect(row.cidNumber, _cid);
    expect((jsonDecode(row.stateData) as Map).containsKey('cid_number'), false);
    final restored = Notifications(api: api, sessions: sessions, user: user);
    addTearDown(restored.dispose);
    expect(await restored.restore(), true);
    expect(restored.unread, 3);
    expect(restored.noticeRev, 7);
    expect(api.reads, 0);
  });
  test('绝对计数按新版本覆盖，重复、乱序和错误身份不累加', () async {
    await service.accept(_state(3, 5));
    await service.accept(_state(3, 5));
    await service.accept(_state(2, 9));
    await service.accept(_state(4, 9, cid: 'CN220-CTZN2-100000009-2026'));
    await service.accept({..._state(4, 9), 'interaction_unread': -1});
    await service.accept({..._state(4, 9), 'notifications_unread': -1});
    expect(service.unread, 5);
    expect(service.noticeRev, 3);
    expect(api.reads, 0);
  });
  test('独立通知子tab计数按版本持久恢复，不从内容未读或关注计数推算', () async {
    await service.accept({
      ..._state(3, 5),
      'notifications_unread': 2,
      'interaction_unread': 7,
    });
    expect(
      [service.unread, service.notificationUnread, service.followingUnread],
      [5, 2, 5],
    );
    final restored = Notifications(api: api, sessions: sessions, user: user);
    addTearDown(restored.dispose);
    await restored.restore();
    expect(
      [restored.unread, restored.notificationUnread, restored.followingUnread],
      [5, 2, 5],
    );
    expect(api.reads, 0);
  });
  test('并发校准只读取一次，已有成功基线不因普通准备重复读取', () async {
    api.pending = Completer<Map<String, dynamic>>();
    final first = service.calibrate(), second = service.calibrate();
    await Future<void>.delayed(Duration.zero);
    api.pending!.complete(api.value);
    await Future.wait([first, second]);
    await service.calibrate();
    expect(api.reads, 1);
    expect(service.unread, 2);
  });
  test('紧凑帖子帧先到时，同版本完整帧仍补齐展示，旧创作者段不覆盖新段', () async {
    await service.accept(_state(3, 5));
    final creator = {'gated': true};
    await service.accept({
      ..._state(3, 5),
      'creator_rev': 2,
      'creator': creator,
    });
    expect(service.creatorFor(_cid), creator);
    await service.acceptCreator(_cid, 4, {
      'gated': false,
    }, session: (await sessions.ensureSession())!);
    await service.accept({
      ..._state(5, 1),
      'creator_rev': 3,
      'creator': creator,
    });
    expect(service.unread, 1);
    expect(service.creatorFor(_cid), {'gated': false});
    await service.accept({
      ..._state(6, 9),
      'creator_rev': 'bad',
      'creator': creator,
    });
    expect(service.unread, 1);
  });
  test('坏校准响应不标成功基线，下次明确准备仍可请求', () async {
    api.value = {..._state(1, 2), 'square_unread': -1};
    await service.calibrate();
    api.value = _state(2, 1);
    await service.calibrate();
    expect(api.reads, 2);
    expect(service.unread, 1);
  });
  test('本地基线恢复不联网，换绑代次不采用此前状态', () async {
    await service.accept(_state(3, 5));
    final restored = Notifications(api: api, sessions: sessions, user: user);
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.unread, 5);
    expect(api.reads, 0);
    user.bindRev = 2;
    await restored.restore();
    expect(restored.unread, 0);
    await restored.accept(_state(4, 9));
    expect(restored.unread, 0);
    await restored.accept(_state(5, 1, bindRev: 2));
    expect(restored.unread, 1);
  });
  test('离线已读持久保存，恢复重放原意图并使用POST回执校准', () async {
    await service.accept(_state(1, 2));
    api.offline = true;
    await service.read(owner: service.scope, ids: [1]);
    expect(service.unread, 2);
    final restored = Notifications(api: api, sessions: sessions, user: user);
    addTearDown(restored.dispose);
    api.offline = false;
    api.value = _state(2, 0);
    await restored.calibrate(force: true);
    expect(restored.unread, 0);
    expect(api.writes, 2);
    expect(api.reads, 0);
    await restored.calibrate();
    expect(api.reads, 0);
  });
  test('损坏展示缓存不装入计数并可通过一次校准修复', () async {
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<user_store.Notice>().put(
        user_store.Notice()
          ..cidNumber = _cid
          ..stateData = jsonEncode({
            ...(_state(8, 9)..remove('cid_number')),
            'square_unread': 'bad',
          }),
      );
    });
    await service.restore();
    expect(service.unread, 0);
    await service.calibrate();
    expect(service.unread, 2);
    expect(api.reads, 1);
  });
  test('并发冷恢复和推送不能回退版本，也不重复装入离线意图', () async {
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<user_store.Notice>().put(
        user_store.Notice()
          ..cidNumber = _cid
          ..stateData = jsonEncode(_state(1, 2)..remove('cid_number'))
          ..pendingData = jsonEncode([
            {
              'scope': 'interaction',
              'ids': [1],
              'through': null,
              'post_ids': [],
              'comment_ids': [],
            },
          ]),
      );
    });
    await Future.wait([
      service.accept(_state(5, 3)),
      service.accept(_state(3, 9)),
      service.restore(),
    ]);
    expect(service.noticeRev, 5);
    expect(service.unread, 3);
    api.value = _state(6, 1);
    await service.calibrate(force: true);
    expect(api.writes, 1);
    expect(service.unread, 1);
  });
  test('旧账号校准不阻止新账号首次校准，旧页面读意图不能改归新账号', () async {
    final old = Completer<Map<String, dynamic>>();
    api.onRead = (session) async => session.cidNumber == _cid
        ? await old.future
        : _state(2, 4, cid: session.cidNumber);
    final first = service.calibrate();
    for (var i = 0; i < 100 && api.reads == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final previous = service.scope!;
    user.cid = 'CN220-CTZN2-100000009-2026';
    service.invalidate();
    await service.calibrate();
    expect(api.reads, 2);
    expect(service.cidNumber, user.cid);
    expect(service.unread, 4);
    expect(await service.read(owner: previous, ids: [1]), false);
    old.complete(_state(9, 9));
    await first;
    expect(service.unread, 4);
    expect(api.writes, 0);
  });
  test('明确广场范围使用捕获上界，不使用后来的推送上界', () async {
    await service.accept(_state(1, 2));
    final owner = service.scope!;
    final through = service.through;
    await service.accept({..._state(2, 3, cid: user.cid), 'through': 20});
    api.value = {..._state(3, 1, cid: user.cid), 'through': 20};
    await service.read(owner: owner, scope: 'square', through: through);
    expect(api.readThrough.single, 10);
    expect(service.unread, 1);
  });
  test('会员展示部分写入失败后从持久快照重放，同版本不额外GET或重复写', () async {
    final value = {
      ..._state(3, 0),
      '_member_received_at': 123456,
      'member_rev': 3,
      'membergate': {
        'active': true,
        'paid_until': 9999999999999,
        'member_level': 'freedom',
        'sub_state': 'active',
        'prices': {'freedom': 1, 'democracy': 2, 'spark': 3},
      },
    };
    final failed = Notifications(
      api: api,
      sessions: sessions,
      user: user,
      memberWriter:
          (cid, data, {required receivedAt, required isCurrent}) async {
            throw StateError('synthetic display write failure');
          },
    );
    await failed.accept(value);
    failed.dispose();
    var writes = 0;
    int? received;
    final recovered = Notifications(
      api: api,
      sessions: sessions,
      user: user,
      memberWriter:
          (cid, data, {required receivedAt, required isCurrent}) async {
            if (isCurrent()) {
              writes++;
              received = receivedAt;
            }
          },
    );
    addTearDown(recovered.dispose);
    await recovered.restore();
    expect(writes, 1);
    final actualTime = recovered.memberReceivedAt;
    expect(received, actualTime);
    await recovered.accept(value);
    await recovered.accept({
      ...value,
      'notice_rev': 4,
      'square_unread': 1,
      'following_unread': 1,
    });
    expect(writes, 1);
    expect(recovered.memberReceivedAt, actualTime);
    expect(api.reads, 0);
  });
  test('互动序号覆盖同批多帖，已读计数和重复快照不反复刷新', () async {
    await service.accept(_state(5, 2));
    var changes = 0;
    service.addListener(() => changes++);
    final state = {..._state(5, 2), 'through': 12, 'interaction_sequence': 12};
    await service.receive({
      'state': state,
      'post_id': 'another-post',
      'comment_id': 'comment',
    });
    expect(service.interactionSequence, 12);
    expect(changes, 1);
    await service.receive({'state': state});
    expect(changes, 1);
    await service.accept({
      ..._state(6, 1),
      'through': 12,
      'interaction_sequence': 12,
    });
    expect(service.interactionSequence, 12);
    await service.accept({
      ..._state(4, 9),
      'through': 11,
      'interaction_sequence': 11,
    });
    expect(service.interactionSequence, 12);
    expect(service.unread, 1);
  });
  test('通知保存失败后同版本补存，页面与会员展示只在保存成功后推进', () async {
    var attempts = 0, notifications = 0;
    Map<String, dynamic>? saved;
    final cache = Notifications(
      api: api,
      sessions: sessions,
      user: user,
      cacheWriter: (owner, state, pending, {required isCurrent}) async {
        if (++attempts == 1) throw StateError('synthetic cache write failure');
        if (isCurrent()) saved = jsonDecode(state) as Map<String, dynamic>;
      },
    );
    addTearDown(cache.dispose);
    await cache.restore();
    cache.addListener(() => notifications++);
    await expectLater(cache.accept(_state(7, 4)), throwsStateError);
    expect(notifications, 0);
    await cache.accept(_state(7, 4));
    expect(attempts, 2);
    expect(saved?['notice_rev'], 7);
    expect(notifications, 1);
    await cache.accept(_state(7, 4));
    expect(attempts, 2);
  });
  test('坏待发已读不阻断有效意图和首次状态校准', () async {
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<user_store.Notice>().put(
        user_store.Notice()
          ..cidNumber = _cid
          ..stateData = jsonEncode(_state(1, 2)..remove('cid_number'))
          ..pendingData = jsonEncode([
            {'ids': 'bad'},
            {
              'ids': [],
              'through': null,
              'post_ids': ['self'],
              'comment_ids': [],
            },
          ]),
      );
    });
    await service.calibrate();
    expect(api.reads, 1);
    expect(api.writes, 0);
    final cleaned = await UserIsar.instance.read(
      (db) => db.collection<user_store.Notice>().getByCidNumber(_cid),
    );
    expect(cleaned?.pendingData, '[]');
    service.invalidate();
    await UserIsar.instance.writeTxn((db) async {
      final row = (await db.collection<user_store.Notice>().getByCidNumber(
        _cid,
      ))!;
      row.pendingData = jsonEncode([
        {'ids': 'bad'},
        {
          'scope': 'interaction',
          'ids': [1],
          'through': null,
          'post_ids': [],
          'comment_ids': [],
        },
      ]);
      await db.collection<user_store.Notice>().put(row);
    });
    await service.calibrate();
    expect(api.writes, 1);
    expect(api.reads, 1);
  });
  test('系统网络恢复只在前台校准，不建立轮询', () async {
    const channel = EventChannel('notifications.test/network');
    late MockStreamHandlerEventSink sink;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
        },
      ),
    );
    addTearDown(() => messenger.setMockStreamHandler(channel, null));
    final push = AppPushService(networkChannel: channel);
    service.configure(api: api, sessions: sessions, user: user, push: push);
    await Future<void>.delayed(Duration.zero);
    service.setForeground(false);
    sink.success(false);
    sink.success(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.reads, 0);
    service.setForeground(true);
    await service.calibrate(force: true);
    expect(api.reads, 1);
    sink.success(false);
    sink.success(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.reads, 2);
  });
}
