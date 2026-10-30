import 'package:citizen_storage/user_isar.dart' as user_store show Notice;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/membership/subscription_service.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_system/notifications/app_push_service.dart';

/// 通知动作固定发起时的身份与代次，不能在异步结束时改归当前账号。
typedef NotificationScope = ({
  String cidNumber,
  String accountId,
  int bindRev,
  int generation,
});
typedef NotificationCacheWriter = Future<void> Function(
  NotificationScope owner,
  String state,
  String pending, {
  required bool Function() isCurrent,
});
typedef NotificationMemberWriter = Future<void> Function(
  String cidNumber,
  Map<String, dynamic> data, {
  required int receivedAt,
  required bool Function() isCurrent,
});

/// CID通知唯一展示状态；恢复、校准和已读各自合并在途任务，推送不生成业务许可。
class Notifications extends ChangeNotifier {
  Notifications({
    SquareApiClient? api,
    SquareSessionProvider? sessions,
    CurrentUserContext? user,
    NotificationMemberWriter? memberWriter,
    NotificationCacheWriter? cacheWriter,
  }) : _api = api,
       _sessions = sessions,
       _user = user,
       _memberWriter = memberWriter ?? SubscriptionService.applyPushedDisplay,
       _cacheWriter = cacheWriter ?? _writeCache;
  static final instance = Notifications();
  SquareApiClient? _api;
  SquareSessionProvider? _sessions;
  CurrentUserContext? _user;
  final NotificationMemberWriter _memberWriter;
  final NotificationCacheWriter _cacheWriter;
  bool _cacheDirty = false;
  int _cacheVersion = 0;
  StreamSubscription<Map<String, dynamic>>? _messages;
  StreamSubscription<bool>? _network;
  bool _foreground = true,
      _calibrated = false,
      _restored = false,
      _known = false;
  Future<void>? _restoring, _calibration, _readFlight, _memberFlight;
  int _applyingMember = 0, _appliedMember = 0;
  final List<Map<String, dynamic>> _pending = [];
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
  int get memberReceivedAt =>
      (_state['_member_received_at'] as int?) ?? receivedAt;
  int get creatorReceivedAt =>
      (_state['_creator_received_at'] as int?) ?? receivedAt;
  int get unread => (_state['square_unread'] as int?) ?? 0;
  int get notificationUnread =>
      (_state['notifications_unread'] as int?) ??
      (_state['interaction_unread'] as int?) ??
      0;
  int get through => (_state['through'] as int?) ?? 0;
  int get followingUnread => (_state['following_unread'] as int?) ?? 0;
  int get noticeRev => (_state['notice_rev'] as int?) ?? 0;
  Map<String, dynamic>? creatorFor(String cidNumber) =>
      cidNumber == _cidNumber && _state['creator'] is Map<String, dynamic>
      ? _state['creator'] as Map<String, dynamic>
      : null;
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
    _memberFlight = null;
    _applyingMember = 0;
    _appliedMember = 0;
    _calibrated = false;
    _restored = false;
    _known = false;
    _state = {};
    _pending.clear();
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
          final baseline = valid(value, owner.cidNumber);
          final partial =
              !value.containsKey('notice_rev') &&
              value['creator'] is Map<String, dynamic> &&
              value['creator_rev'] is int &&
              (value['creator_rev'] as int) > 0;
          if (baseline || partial) {
            _state = value;
            _known = baseline;
          }
        }
      } on FormatException {
        /* 坏展示不安装；下次明确事件校准。 */
      }
    }
    if (row?.pendingData != null) {
      try {
        final values = jsonDecode(row!.pendingData!);
        if (values is List) {
          _pending.addAll(
            values
                .whereType<Map>()
                .map((e) => _canonicalRead(e.cast<String, dynamic>()))
                .where(_validRead),
          );
          if (_pending.length != values.length) _cacheDirty = true;
        } else {
          _cacheDirty = true;
        }
      } on FormatException {
        _cacheDirty = true;
        /* 损坏的本机意图不跨身份采用。 */
      }
    }
    _restored = true;
    await _applyMember(owner);
    if (isCurrent(owner)) notifyListeners();
  }

  Future<void> _applyMember(NotificationScope owner) async {
    final version = (_state['member_rev'] as int?) ?? 0,
        data = _state['membergate'];
    if (!isCurrent(owner) ||
        data is! Map<String, dynamic> ||
        version <= _appliedMember) {
      return;
    }
    if (_memberFlight != null && _applyingMember == version) {
      await _memberFlight;
      return;
    }
    _applyingMember = version;
    late final Future<void> task;
    task = Future<void>.microtask(() async {
      try {
        bool current() => isCurrent(owner) && _state['member_rev'] == version;
        await _memberWriter(
          owner.cidNumber,
          data,
          receivedAt: memberReceivedAt,
          isCurrent: current,
        );
        if (current()) _appliedMember = version;
      } on Object {
        /* 原快照已持久化；同版本或下次恢复从本地补写，不增加GET。 */
      } finally {
        if (identical(_memberFlight, task)) _memberFlight = null;
      }
    });
    _memberFlight = task;
    await task;
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
    for (final (section, version, present) in [
      (
        value['membergate'],
        value['member_rev'],
        value.containsKey('member_rev'),
      ),
      (
        value['creator'],
        value['creator_rev'],
        value.containsKey('creator_rev'),
      ),
    ]) {
      if (present &&
          (version is! int || version < 0 || version > 9007199254740991)) {
        return false;
      }
      if (section != null &&
          (section is! Map<String, dynamic> ||
              version is! int ||
              version <= 0)) {
        return false;
      }
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

  Future<bool> accept(Map<String, dynamic> value) async {
    if (!await restore() ||
        !valid(value, _cidNumber) ||
        value['bind_rev'] != _bindRev) {
      return false;
    }
    final owner = scope!;
    final counter = (value['notice_rev'] as int) > noticeRev || !_known;
    final interaction =
        (value['interaction_sequence'] as int) > interactionSequence;
    final creator =
        value['creator'] is Map &&
        ((value['creator_rev'] as int?) ?? 0) >
            ((_state['creator_rev'] as int?) ?? 0);
    final member =
        value['membergate'] is Map &&
        ((value['member_rev'] as int?) ?? 0) >
            ((_state['member_rev'] as int?) ?? 0);
    if (!counter && !creator && !member && !interaction) {
      // 保存失败不能把内存版本当作已落盘版本；同版本允许补存并更新页面。
      if (_cacheDirty &&
          await _persist(owner) &&
          isCurrent(owner) &&
          !_cacheDirty) {
        notifyListeners();
      }
      if (!_cacheDirty) await _applyMember(owner);
      return false;
    }
    final merged = Map<String, dynamic>.from(_state),
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
    if (creator) {
      merged['creator'] = value['creator'];
      merged['creator_rev'] = value['creator_rev'];
      merged['_creator_received_at'] = now;
    }
    if (member) {
      merged['membergate'] = value['membergate'];
      merged['member_rev'] = value['member_rev'];
      merged['_member_received_at'] = now;
    }
    merged['interaction_sequence'] = interaction
        ? value['interaction_sequence']
        : interactionSequence;
    if ((merged['through'] as int) < (merged['interaction_sequence'] as int)) {
      merged['through'] = merged['interaction_sequence'];
    }
    merged['_received_at'] = now;
    _state = merged;
    if (!await _persist(owner) || !isCurrent(owner) || _cacheDirty) {
      return false;
    }
    await _applyMember(owner);
    if (isCurrent(owner)) notifyListeners();
    return isCurrent(owner);
  }

  Future<void> acceptCreator(
    String cidNumber,
    int version,
    Map<String, dynamic> creator, {
    required SquareSession session,
  }) async {
    if (!await restore()) return;
    final owner = scope!;
    await session.validateCurrent();
    if (!isCurrent(owner) ||
        cidNumber != owner.cidNumber ||
        session.cidNumber != cidNumber ||
        session.bindRev != owner.bindRev ||
        session.accountId != owner.accountId) {
      return;
    }
    if (version <= ((_state['creator_rev'] as int?) ?? 0)) {
      if (_cacheDirty &&
          await _persist(owner) &&
          isCurrent(owner) &&
          !_cacheDirty) {
        notifyListeners();
      }
      return;
    }
    _state['cid_number'] = cidNumber;
    _state['bind_rev'] = owner.bindRev;
    _state['creator_rev'] = version;
    _state['creator'] = creator;
    _state['_creator_received_at'] = DateTime.now().millisecondsSinceEpoch;
    if (await _persist(owner) && isCurrent(owner) && !_cacheDirty) {
      notifyListeners();
    }
  }

  Future<bool> _persist(NotificationScope owner) async {
    final version = ++_cacheVersion;
    _cacheDirty = true;
    bool current() => isCurrent(owner);
    await _cacheWriter(
      owner,
      jsonEncode(Map<String, dynamic>.of(_state)..remove('cid_number')),
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

  // 旧待提交记录在内存中明确归类；不会把逐评论阅读重放成父层全部已读。
  static Map<String, dynamic> _canonicalRead(Map<String, dynamic> value) {
    final result = Map<String, dynamic>.from(value);
    final selector =
        (value['ids'] is List && (value['ids'] as List).isNotEmpty) ||
        (value['comment_ids'] is List &&
            (value['comment_ids'] as List).isNotEmpty);
    final posts =
        value['post_ids'] is List && (value['post_ids'] as List).isNotEmpty;
    if (value['scope'] == null ||
        (value['scope'] == 'square' && value['through'] == null)) {
      result['scope'] = selector
          ? 'interaction'
          : posts
          ? 'following'
          : 'square';
    }
    return result;
  }

  static bool _validRead(Map<String, dynamic> value) {
    final scope = value['scope'];
    if (scope != null &&
        ![
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
      _pending.add(intent);
      if (!await _persist(owner) || !isCurrent(owner)) return false;
      await _flushReads(owner);
      return isCurrent(owner);
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
              session.bindRev != owner.bindRev) {
            return;
          }
          final value = await api.markNotifyRead(
            session: session,
            scope:
                intent['scope'] as String? ??
                ((intent['comment_ids'] as List).isNotEmpty ||
                        (intent['ids'] as List).isNotEmpty
                    ? 'interaction'
                    : (intent['post_ids'] as List).isNotEmpty
                    ? 'following'
                    : 'square'),
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
          await accept(value);
          if (!isCurrent(owner)) return;
          if (_pending.isNotEmpty && identical(_pending.first, intent)) {
            _pending.removeAt(0);
          }
          await _persist(owner);
          if (!isCurrent(owner)) return;
          _calibrated = true;
        }
        successful = true;
      } on Object {
        /* 原意图仍归原CID，下一次明确事件再重放。 */
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
