import 'package:citizen_storage/user_isar.dart' as user_store show Notice;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_system/notifications/app_push_service.dart';

/// 通知动作固定发起时的身份与代次，不能在异步结束时改归当前账号。
typedef NotificationScope = ({
  String cidNumber,
  String accountId,
  int bindRev,
  int generation,
});
typedef NotificationCacheWriter =
    Future<void> Function(
      NotificationScope owner,
      String state,
      String pending, {
      required bool Function() isCurrent,
    });

/// 当前已加载通知列表的本机快照；分页上界不因后续已读回执改变。
class NotificationListSnapshot {
  factory NotificationListSnapshot({
    required int revision,
    required int sequence,
    required int through,
    required String? nextCursor,
    required Iterable<Map<String, dynamic>> items,
  }) {
    bool number(Object? n) => n is int && n >= 0 && n <= 9007199254740991;
    if (!number(revision) ||
        !number(sequence) ||
        !number(through) ||
        sequence > through ||
        (nextCursor != null &&
            (nextCursor.isEmpty || nextCursor.length > 8192))) {
      throw const FormatException('通知列表分页信息无效');
    }
    final ids = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['post_id'];
      if (id is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id) ||
          !ids.add(id) ||
          (item['post_title'] != null && item['post_title'] is! String) ||
          (item['post_excerpt'] != null && item['post_excerpt'] is! String) ||
          !number(item['notice_count']) ||
          !number(item['comment_unread'])) {
        throw const FormatException('通知列表记录无效');
      }
      rows.add(
        Map<String, dynamic>.unmodifiable({
          'post_id': id,
          'post_title': item['post_title'],
          'post_excerpt': item['post_excerpt'],
          'notice_count': item['notice_count'],
          'comment_unread': item['comment_unread'],
        }),
      );
    }
    return NotificationListSnapshot._(
      revision,
      sequence,
      through,
      nextCursor,
      List.unmodifiable(rows),
    );
  }
  const NotificationListSnapshot._(
    this.revision,
    this.sequence,
    this.through,
    this.nextCursor,
    this.items,
  );
  final int revision, sequence, through;
  final String? nextCursor;
  final List<Map<String, dynamic>> items;
  String encode(NotificationScope owner) => jsonEncode({
    'account_id': owner.accountId,
    'bind_rev': owner.bindRev,
    'notice_rev': revision,
    'interaction_sequence': sequence,
    'through': through,
    'next_cursor': nextCursor,
    'items': items,
  });
  static NotificationListSnapshot decode(String data, NotificationScope owner) {
    final value = jsonDecode(data);
    if (value is! Map<String, dynamic> ||
        value.length != 7 ||
        value['account_id'] != owner.accountId ||
        value['bind_rev'] != owner.bindRev ||
        value['notice_rev'] is! int ||
        value['interaction_sequence'] is! int ||
        value['through'] is! int ||
        (value['next_cursor'] != null && value['next_cursor'] is! String) ||
        value['items'] is! List ||
        (value['items'] as List).any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('通知列表缓存归属或结构无效');
    }
    return NotificationListSnapshot(
      revision: value['notice_rev'] as int,
      sequence: value['interaction_sequence'] as int,
      through: value['through'] as int,
      nextCursor: value['next_cursor'] as String?,
      items: (value['items'] as List).cast<Map<String, dynamic>>(),
    );
  }
}

/// CID通知唯一展示状态；恢复、校准和已读各自合并在途任务，推送不生成业务许可。
class Notifications extends ChangeNotifier {
  Notifications({
    SquareApiClient? api,
    SquareSessionProvider? sessions,
    CurrentUserContext? user,
    NotificationCacheWriter? cacheWriter,
  }) : _api = api,
       _sessions = sessions,
       _user = user,

       _cacheWriter = cacheWriter ?? _writeCache;
  static final instance = Notifications();
  SquareApiClient? _api;
  SquareSessionProvider? _sessions;
  CurrentUserContext? _user;
  final NotificationCacheWriter _cacheWriter;
  bool _cacheDirty = false;
  int _cacheVersion = 0;
  StreamSubscription<Map<String, dynamic>>? _messages;
  StreamSubscription<bool>? _network;
  bool _foreground = true,
      _calibrated = false,
      _restored = false,
      _known = false;
  Future<void>? _restoring, _calibration, _readFlight;
  final List<Map<String, dynamic>> _pending = [];
  final _confirmedReads = <String>{};
  final _readSubmissions = <String, Future<bool>>{};
  NotificationListSnapshot? _listSnapshot;
  NotificationListSnapshot? get cachedList => _listSnapshot;
  int get listRevision {
    final value = _state['_list_revision'];
    return value is int && value >= 0 && value <= 9007199254740991
        ? value
        : noticeRev;
  }

  Map<String, dynamic> _state = {};
  String _cidNumber = '', _accountId = '';
  int _bindRev = 0,
      _generation = 0,
      _identityEpoch = 0,
      _resolving = 0,
      _resolved = 0;
  int get interactionSequence => (_state['interaction_sequence'] as int?) ?? 0;
  NotificationScope? get scope => _cidNumber.isEmpty
      ? null
      : (
          cidNumber: _cidNumber,
          accountId: _accountId,
          bindRev: _bindRev,
          generation: _generation,
        );
  bool isCurrent(NotificationScope? owner) => owner != null && owner == scope;
  String get cidNumber => _cidNumber;
  int get receivedAt => (_state['_received_at'] as int?) ?? 0;
  int get unread => (_state['square_unread'] as int?) ?? 0;
  int get notificationUnread =>
      (_state['notifications_unread'] as int?) ??
      (_state['interaction_unread'] as int?) ??
      0;
  int get through => (_state['through'] as int?) ?? 0;
  int get followingUnread => (_state['following_unread'] as int?) ?? 0;
  int get noticeRev => (_state['notice_rev'] as int?) ?? 0;
  void configure({
    required SquareApiClient api,
    required SquareSessionProvider sessions,
    required CurrentUserContext user,
    AppPushService? push,
  }) {
    _api = api;
    _sessions = sessions;
    _user = user;
    if (push != null) {
      unawaited(_messages?.cancel());
      unawaited(_network?.cancel());
      _messages = push.foregroundMessages.listen(
        (data) => unawaited(receive(data)),
      );
      bool? previous;
      _network = push.networkAvailability.listen((available) {
        final recovered = previous == false && available;
        previous = available;
        if (recovered && _foreground) unawaited(calibrate(force: true));
      });
    }
  }

  void _clear() {
    _generation++;
    _restoring = null;
    _calibration = null;
    _readFlight = null;
    _calibrated = false;
    _restored = false;
    _known = false;
    _state = {};
    _pending.clear();
    _confirmedReads.clear();
    _readSubmissions.clear();
    _listSnapshot = null;
    _cacheDirty = false;
    _cacheVersion++;
  }

  /// 账户修订先撤下旧显示；新账号恢复不等待旧HTTP或旧数据库任务。
  void invalidate() {
    _identityEpoch++;
    _clear();
    _cidNumber = '';
    _accountId = '';
    _bindRev = 0;
    notifyListeners();
  }

  Future<bool> restore() async {
    final epoch = _identityEpoch, sequence = ++_resolving;
    final user = await _user?.resolve();
    if (epoch != _identityEpoch) return false;
    final cidNumber = user?.cidNumber ?? '',
        accountId = user?.accountId ?? '',
        bindRev = user?.bindRev ?? 0;
    final changed =
        cidNumber != _cidNumber ||
        accountId != _accountId ||
        bindRev != _bindRev;
    if (sequence < _resolved && changed) return false;
    if (sequence > _resolved) _resolved = sequence;
    if (changed) {
      _clear();
      _cidNumber = cidNumber;
      _accountId = accountId;
      _bindRev = bindRev;
      notifyListeners();
    }
    if (cidNumber.isEmpty) return false;
    final owner = scope!;
    if (!_restored) {
      var pending = _restoring;
      if (pending == null) {
        pending = _restoreLocal(owner);
        _restoring = pending;
        try {
          await pending;
        } finally {
          if (identical(_restoring, pending)) _restoring = null;
        }
      } else {
        await pending;
      }
    }
    return isCurrent(owner);
  }

  Future<void> _restoreLocal(NotificationScope owner) async {
    final row = await UserIsar.instance.read(
      (db) =>
          db.collection<user_store.Notice>().getByCidNumber(owner.cidNumber),
    );
    if (!isCurrent(owner)) return;
    var bindingMatches = false;
    if (row?.stateData != null) {
      try {
        final raw = row!.stateData;
        final value = jsonDecode(raw);
        if (value is Map<String, dynamic> && value.containsKey('cid_number')) {
          throw const FormatException('通知缓存归属重复');
        }
        if (value is Map<String, dynamic>) value['cid_number'] = row.cidNumber;
        if (value is Map<String, dynamic> &&
            value['cid_number'] == owner.cidNumber &&
            value['bind_rev'] == owner.bindRev) {
          bindingMatches = true;
          final baseline = valid(value, owner.cidNumber);
          if (baseline) {
            const fields = {
              'cid_number',
              'bind_rev',
              'notice_rev',
              'through',
              'floor',
              'square_unread',
              'following_unread',
              'interaction_unread',
              'notifications_unread',
              'square_sequence',
              'interaction_sequence',
              'state',
              '_received_at',
            };
            _state = {
              for (final key in fields)
                if (value.containsKey(key)) key: value[key],
            };
            _known = true;
          }
        }
      } on FormatException {
        /* 坏展示不安装；下次明确事件校准。 */
      }
    }
    if (row?.pendingData != null && bindingMatches) {
      try {
        final values = jsonDecode(row!.pendingData!);
        if (values is List) {
          final seen = <String>{};
          for (final raw in values.whereType<Map>()) {
            final value = raw.cast<String, dynamic>();
            if (!_validRead(value)) continue;
            final intent = _canonicalRead(value);
            if (seen.add(_readKey(intent))) _pending.add(intent);
          }
          if (_pending.length != values.length) _cacheDirty = true;
        } else {
          _cacheDirty = true;
        }
      } on FormatException {
        _cacheDirty = true;
        /* 损坏的本机意图不跨身份采用。 */
      }
    }
    if (row?.listData != null) {
      try {
        _listSnapshot = NotificationListSnapshot.decode(row!.listData!, owner);
      } on FormatException {
        /* 损坏或其他绑定的缓存不展示；不删除原行。 */
      }
    }
    _restored = true;
    if (isCurrent(owner)) notifyListeners();
  }

  Future<bool> cacheList(
    NotificationScope owner,
    NotificationListSnapshot snapshot, {
    bool Function()? isCurrentRequest,
  }) async {
    bool current() =>
        isCurrent(owner) &&
        (isCurrentRequest?.call() ?? true) &&
        snapshot.revision >= listRevision &&
        snapshot.sequence >= interactionSequence;
    if (!current()) return false;
    final data = snapshot.encode(owner);
    await UserIsar.instance.writeTxn((db) async {
      if (!current()) return;
      final collection = db.collection<user_store.Notice>();
      final row =
          await collection.getByCidNumber(owner.cidNumber) ??
          (user_store.Notice()
            ..cidNumber = owner.cidNumber
            ..stateData = jsonEncode(
              {..._state, 'bind_rev': owner.bindRev}..remove('cid_number'),
            ));
      if (!current()) return;
      row.listData = data;
      await collection.put(row);
      if (!current()) throw StateError('通知列表归属或版本已变化');
    });
    if (!current()) return false;
    _listSnapshot = snapshot;
    return true;
  }

  static bool valid(Map<String, dynamic> value, String cidNumber) {
    if (value['cid_number'] != cidNumber) return false;
    for (final key in [
      'notice_rev',
      'square_unread',
      'following_unread',
      'interaction_unread',
      'through',
      'interaction_sequence',
    ]) {
      final n = value[key];
      if (n is! int || n < 0 || n > 9007199254740991) return false;
    }
    return (value['interaction_sequence'] as int) <=
            (value['through'] as int) &&
        (value['notifications_unread'] == null ||
            (value['notifications_unread'] is int &&
                (value['notifications_unread'] as int) >= 0 &&
                (value['notifications_unread'] as int) <= 9007199254740991));
  }

  Future<void> receive(Map<String, dynamic> data) async {
    try {
      final raw = data['citizen'] ?? data;
      if (raw is String && utf8.encode(raw).length > 4096) return;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map || !await restore()) return;
      final payload = decoded.cast<String, dynamic>(),
          value = payload['state'],
          owner = scope!;
      if (value is! Map<String, dynamic> ||
          !valid(value, owner.cidNumber) ||
          value['bind_rev'] != owner.bindRev) {
        return;
      }
      await accept(value);
    } on Object {
      /* 推送失败不影响业务，下次明确事件再校准。 */
    }
  }

  Future<bool> accept(
    Map<String, dynamic> value, {
    bool listChanged = true,
  }) async {
    if (!await restore() ||
        !valid(value, _cidNumber) ||
        value['bind_rev'] != _bindRev) {
      return false;
    }
    final owner = scope!;
    final counter = (value['notice_rev'] as int) > noticeRev || !_known;
    final interaction =
        (value['interaction_sequence'] as int) > interactionSequence;
    if (!counter && !interaction) {
      // 保存失败不能把内存版本当作已落盘版本；同版本允许补存并更新页面。
      if (_cacheDirty &&
          await _persist(owner) &&
          isCurrent(owner) &&
          !_cacheDirty) {
        notifyListeners();
      }
      if (!_cacheDirty) return false;
    }
    final previousThrough = through;
    final previousListRevision = listRevision;
    final merged = Map<String, dynamic>.from(_state)..remove('membergate'),
        now = DateTime.now().millisecondsSinceEpoch;
    if (counter) {
      for (final key in [
        'is_ok',
        'cid_number',
        'bind_rev',
        'notice_rev',
        'square_unread',
        'following_unread',
        'interaction_unread',
        'through',
      ]) {
        merged[key] = value[key];
      }
      merged['notifications_unread'] =
          value['notifications_unread'] ?? value['interaction_unread'];
      _known = true;
    }
    merged['interaction_sequence'] = interaction
        ? value['interaction_sequence']
        : interactionSequence;
    if ((merged['through'] as int) < (merged['interaction_sequence'] as int)) {
      merged['through'] = merged['interaction_sequence'];
    }
    merged['_list_revision'] = ((counter && listChanged) || interaction)
        ? (value['notice_rev'] as int).clamp(
            previousListRevision,
            9007199254740991,
          )
        : previousListRevision;
    merged['_received_at'] = now;
    _state = merged;
    if (through > previousThrough) _confirmedReads.clear();
    if (!await _persist(owner) || !isCurrent(owner) || _cacheDirty) {
      return false;
    }
    if (isCurrent(owner)) notifyListeners();
    return isCurrent(owner);
  }

  Future<bool> _persist(NotificationScope owner) async {
    final version = ++_cacheVersion;
    _cacheDirty = true;
    bool current() => isCurrent(owner);
    await _cacheWriter(
      owner,
      jsonEncode({..._state, 'bind_rev': owner.bindRev}..remove('cid_number')),
      jsonEncode(_pending),
      isCurrent: current,
    );
    if (!current()) return false;
    if (version == _cacheVersion) _cacheDirty = false;
    return true;
  }

  static Future<void> _writeCache(
    NotificationScope owner,
    String state,
    String pending, {
    required bool Function() isCurrent,
  }) => UserIsar.instance.writeTxn((db) async {
    if (!isCurrent()) return;
    final row =
        await db.collection<user_store.Notice>().getByCidNumber(
          owner.cidNumber,
        ) ??
        user_store.Notice();
    if (!isCurrent()) return;
    row
      ..cidNumber = owner.cidNumber
      ..stateData = state
      ..pendingData = pending;
    await db.collection<user_store.Notice>().put(row);
    if (!isCurrent()) throw StateError('通知状态已更新');
  });

  static Map<String, dynamic> _canonicalRead(Map<String, dynamic> value) => {
    'scope': value['scope'],
    'post_id': value['post_id'],
    'ids': ((value['ids'] as List).cast<int>().toSet().toList()..sort()),
    'through': value['through'],
    'post_ids': ((value['post_ids'] as List).cast<String>().toSet().toList()
      ..sort()),
    'comment_ids':
        ((value['comment_ids'] as List).cast<String>().toSet().toList()
          ..sort()),
  };
  static String _readKey(Map<String, dynamic> value) => jsonEncode(value);

  static bool _validRead(Map<String, dynamic> value) {
    final scope = value['scope'];
    if (![
      'square',
      'notifications',
      'post',
      'following',
      'interaction',
    ].contains(scope)) {
      return false;
    }
    final ids = value['ids'],
        posts = value['post_ids'],
        comments = value['comment_ids'],
        through = value['through'];
    bool number(dynamic n) => n is int && n > 0 && n <= 9007199254740991;
    bool name(dynamic v) =>
        v is String &&
        v != 'self' &&
        v != 'confirm' &&
        RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(v);
    bool names(dynamic v) => v is List && v.length <= 50 && v.every(name);
    if (ids is! List ||
        ids.length > 50 ||
        !ids.every(number) ||
        !names(posts) ||
        !names(comments) ||
        (through != null && !number(through))) {
      return false;
    }
    if (scope == 'post') {
      return name(value['post_id']) &&
          number(through) &&
          ids.isEmpty &&
          (posts as List).isEmpty &&
          (comments as List).isEmpty;
    }
    if (value['post_id'] != null) return false;
    if (scope == 'square' || scope == 'notifications') {
      return number(through) &&
          ids.isEmpty &&
          (posts as List).isEmpty &&
          (comments as List).isEmpty;
    }
    return [
          ids.isNotEmpty,
          through != null,
          (posts as List).isNotEmpty,
          (comments as List).isNotEmpty,
        ].where((v) => v).length ==
        1;
  }

  void setForeground(bool value) {
    _foreground = value;
  }

  Future<void> calibrate({bool force = false}) async {
    try {
      if (!await restore() || !_foreground) return;
      final owner = scope!, pending = _calibration;
      if (pending != null) {
        await pending;
        return;
      }
      if (_calibrated && !force) return;
      late final Future<void> task;
      task = () async {
        try {
          final session = await _sessions?.ensureSession(), api = _api;
          if (!isCurrent(owner) ||
              session == null ||
              api == null ||
              session.cidNumber != owner.cidNumber ||
              session.accountId != owner.accountId ||
              session.bindRev != owner.bindRev) {
            return;
          }
          if (_pending.isNotEmpty) {
            await _flushReads(owner);
            return;
          }
          final value = await api.fetchNotificationState(session: session);
          await session.validateCurrent();
          if (!isCurrent(owner) ||
              !valid(value, owner.cidNumber) ||
              value['bind_rev'] != owner.bindRev) {
            return;
          }
          await accept(value);
          if (isCurrent(owner)) _calibrated = true;
        } on Object {
          /* 保留当前身份的数据；旧任务不能标记新身份校准成功。 */
        } finally {
          if (identical(_calibration, task)) _calibration = null;
        }
      }();
      _calibration = task;
      await task;
    } on Object {
      /* 依赖未就绪，下一次明确恢复事件重试。 */
    }
  }

  Future<bool> read({
    required NotificationScope? owner,
    String? scope,
    String? postId,
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) async {
    try {
      if (owner == null ||
          !await restore() ||
          !isCurrent(owner) ||
          (ids.isEmpty &&
              through == null &&
              postIds.isEmpty &&
              commentIds.isEmpty)) {
        return false;
      }
      final intent = <String, dynamic>{
        'scope':
            scope ??
            (commentIds.isNotEmpty || ids.isNotEmpty
                ? 'interaction'
                : postIds.isNotEmpty
                ? 'following'
                : 'square'),
        'post_id': postId,
        'ids': List<int>.of(ids),
        'through': through,
        'post_ids': List<String>.of(postIds),
        'comment_ids': List<String>.of(commentIds),
      };
      if (!_validRead(intent)) return false;
      final canonical = _canonicalRead(intent);
      final key = _readKey(canonical);
      if (_confirmedReads.contains(key)) {
        if (_cacheDirty &&
            await _persist(owner) &&
            isCurrent(owner) &&
            !_cacheDirty) {
          if (isCurrent(owner)) notifyListeners();
        }
        return isCurrent(owner);
      }
      final running = _readSubmissions[key];
      if (running != null) return await running;
      late final Future<bool> task;
      task =
          Future<bool>.microtask(() async {
            if (!isCurrent(owner)) return false;
            final exists = _pending.any((value) => _readKey(value) == key);
            if (!exists) _pending.add(canonical);
            if ((!exists || _cacheDirty) && !await _persist(owner)) {
              return false;
            }
            if (!isCurrent(owner)) return false;
            await _flushReads(owner);
            return isCurrent(owner);
          }).whenComplete(() {
            if (identical(_readSubmissions[key], task)) {
              _readSubmissions.remove(key);
            }
          });
      _readSubmissions[key] = task;
      return await task;
    } on Object {
      return false;
    }
  }

  Future<void> _flushReads(NotificationScope owner) async {
    if (!isCurrent(owner)) return;
    final pending = _readFlight;
    if (pending != null) {
      await pending;
      return;
    }
    late final Future<void> task;
    task = () async {
      var successful = false;
      try {
        for (var count = 0; count < 4 && _pending.isNotEmpty; count++) {
          final intent = _pending.first,
              session = await _sessions?.ensureSession(),
              api = _api;
          if (!isCurrent(owner) ||
              session == null ||
              api == null ||
              session.cidNumber != owner.cidNumber ||
              session.accountId != owner.accountId ||
              session.bindRev != owner.bindRev) {
            return;
          }
          final value = await api.markNotifyRead(
            session: session,
            scope: intent['scope'] as String,
            postId: intent['post_id'] as String?,
            ids: (intent['ids'] as List).cast<int>(),
            through: intent['through'] as int?,
            postIds: (intent['post_ids'] as List).cast<String>(),
            commentIds: (intent['comment_ids'] as List).cast<String>(),
          );
          await session.validateCurrent();
          if (!isCurrent(owner)) return;
          if (!valid(value, owner.cidNumber) ||
              value['bind_rev'] != owner.bindRev) {
            throw const FormatException('已读回执状态无效');
          }
          // 分批处理中的回执不能消费本机的原始已读意图。
          if (value['state'] == 'pending') return;
          if (_pending.isNotEmpty && identical(_pending.first, intent)) {
            _pending.removeAt(0);
          }
          final cacheVersion = _cacheVersion;
          try {
            await accept(
              value,
              listChanged: ![
                'square',
                'notifications',
              ].contains(intent['scope']),
            );
          } finally {
            if (isCurrent(owner)) _confirmedReads.add(_readKey(intent));
          }
          if (!isCurrent(owner)) return;
          if (_cacheDirty || cacheVersion == _cacheVersion) {
            await _persist(owner);
          }
          if (!isCurrent(owner)) return;
          _calibrated = true;
        }
        successful = true;
      } on Object {
        /* 未确认动作保留原范围；云端已确认后只需补本机落盘。 */
      } finally {
        if (identical(_readFlight, task)) _readFlight = null;
        if (successful &&
            _foreground &&
            isCurrent(owner) &&
            _pending.isNotEmpty) {
          scheduleMicrotask(() => unawaited(_flushReads(owner)));
        }
      }
    }();
    _readFlight = task;
    await task;
  }

  void stop() {
    _identityEpoch++;
    _clear();
    _cidNumber = '';
    _accountId = '';
    _bindRev = 0;
    unawaited(_messages?.cancel());
    unawaited(_network?.cancel());
    _messages = null;
    _network = null;
    _api = null;
    _sessions = null;
    _user = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
