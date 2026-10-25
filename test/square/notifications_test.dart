import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';

import 'package:citizenapp/storage/user_isar.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/system/notifications/app_push_service.dart';
import 'package:citizenapp/system/notifications/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/isar_test_env.dart';

const _cid = 'CN220-CTZN2-100000008-2026';

class _User implements CurrentUserContext {
  String cid = _cid;
  int revision = 1;
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
        bindingRevision: revision,
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
  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: '33' * 32,
    sessionToken: 'synthetic',
    cidNumber: user.cid,
    accountId: '0x${'11' * 32}',
    bindingRevision: user.revision,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused session boundary');
}

Map<String, dynamic> _state(
  int revision,
  int unread, {
  String cid = _cid,
  int binding = 1,
}) => {
  'ok': true,
  'cid_number': cid,
  'binding_revision': binding,
  'revision': revision,
  'square_unread': unread,
  'following_unread': unread,
  'interaction_unread': 0,
  'interaction_sequence': 0,
  'through': 10,
  'membergate_revision': 0,
  'creator_revision': 0,
  'membergate': null,
  'creator': null,
};

class _Api extends SquareApiClient {
  _Api() : super(baseUrl: 'https://notifications.test/api');
  int reads = 0, writes = 0;
  final readThrough = <int?>[];
  Future<Map<String, dynamic>> Function(SquareSession)? onPage;
  bool offline = false;
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
  Future<Map<String, dynamic>> fetchNotifications({
    required SquareSession session,
    int? cursor,
  }) async => onPage == null
      ? {'ok': true, 'items': <Object>[], 'state': value, 'next_cursor': null}
      : await onPage!(session);
  @override
  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) async {
    writes++;
    readThrough.add(through);
    if (offline) throw StateError('synthetic offline');
    return value;
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
  test('绝对计数按新版本覆盖，重复、乱序和错误身份不累加', () async {
    await service.accept(_state(3, 5));
    await service.accept(_state(3, 5));
    await service.accept(_state(2, 9));
    await service.accept(_state(4, 9, cid: 'CN220-CTZN2-100000009-2026'));
    await service.accept({..._state(4, 9), 'interaction_unread': -1});
    expect(service.unread, 5);
    expect(service.revision, 3);
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
      'creator_revision': 2,
      'creator': creator,
    });
    expect(service.creatorFor(_cid), creator);
    await service.acceptCreator(_cid, 4, {
      'gated': false,
    }, session: (await sessions.ensureSession())!);
    await service.accept({
      ..._state(5, 1),
      'creator_revision': 3,
      'creator': creator,
    });
    expect(service.unread, 1);
    expect(service.creatorFor(_cid), {'gated': false});
    await service.accept({
      ..._state(6, 9),
      'creator_revision': 'bad',
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
    user.revision = 2;
    await restored.restore();
    expect(restored.unread, 0);
    await restored.accept(_state(4, 9));
    expect(restored.unread, 0);
    await restored.accept(_state(5, 1, binding: 2));
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
      await db.userNotificationStateEntitys.put(
        UserNotificationStateEntity()
          ..cidNumber = _cid
          ..stateJson = jsonEncode({..._state(8, 9), 'square_unread': 'bad'}),
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
      await db.userNotificationStateEntitys.put(
        UserNotificationStateEntity()
          ..cidNumber = _cid
          ..stateJson = jsonEncode(_state(1, 2))
          ..pendingJson = jsonEncode([
            {
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
    expect(service.revision, 5);
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
    expect(await service.readAll(owner: previous, through: 10000), false);
    await expectLater(service.page(owner: previous), throwsStateError);
    old.complete(_state(9, 9));
    await first;
    expect(service.unread, 4);
    expect(api.writes, 0);
  });
  test('列表迟到响应被丢弃，全部已读使用列表捕获上界而非后来的推送上界', () async {
    await service.accept(_state(1, 2));
    final owner = service.scope!;
    final response = Completer<Map<String, dynamic>>();
    api.onPage = (_) => response.future;
    final oldPage = service.page(owner: owner);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    user.cid = 'CN220-CTZN2-100000009-2026';
    service.invalidate();
    await service.restore();
    final rejected = expectLater(oldPage, throwsStateError);
    response.complete({
      'ok': true,
      'state': _state(1, 2),
      'items': <Object>[],
      'next_cursor': null,
    });
    await rejected;
    await service.accept({..._state(2, 3, cid: user.cid), 'through': 20});
    api.value = {..._state(3, 1, cid: user.cid), 'through': 20};
    await service.readAll(owner: service.scope!, through: 10);
    expect(api.readThrough.single, 10);
    expect(service.unread, 1);
  });
  test('会员展示部分写入失败后从持久快照重放，同版本不额外GET或重复写', () async {
    final value = {
      ..._state(3, 0),
      '_member_received_at': 123456,
      'membergate_revision': 3,
      'membergate': {
        'active': true,
        'paid_until': 9999999999999,
        'membergate_level': 'freedom',
        'subscription_status': 'active',
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
      'revision': 4,
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
    expect(saved?['revision'], 7);
    expect(notifications, 1);
    await cache.accept(_state(7, 4));
    expect(attempts, 2);
  });
  test('坏待发已读不阻断有效意图和首次状态校准', () async {
    await UserIsar.instance.writeTxn((db) async {
      await db.userNotificationStateEntitys.put(
        UserNotificationStateEntity()
          ..cidNumber = _cid
          ..stateJson = jsonEncode(_state(1, 2))
          ..pendingJson = jsonEncode([
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
      (db) => db.userNotificationStateEntitys.getByCidNumber(_cid),
    );
    expect(cleaned?.pendingJson, '[]');
    service.invalidate();
    await UserIsar.instance.writeTxn((db) async {
      final row = (await db.userNotificationStateEntitys.getByCidNumber(_cid))!;
      row.pendingJson = jsonEncode([
        {'ids': 'bad'},
        {
          'ids': [1],
          'through': null,
          'post_ids': [],
          'comment_ids': [],
        },
      ]);
      await db.userNotificationStateEntitys.put(row);
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
