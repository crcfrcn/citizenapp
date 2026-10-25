import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/account/membership/subscription_service.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/storage/user_isar.dart';

import 'app_push_service.dart';

/// 通知动作固定发起时的身份与代次，不能在异步结束时改归当前账号。
typedef NotificationScope = ({
  String cid,
  String account,
  int binding,
  int generation,
});
typedef NotificationCacheWriter = Future<void> Function(
  NotificationScope owner,
  String state,
  String pending, {
  required bool Function() isCurrent,
});
typedef NotificationMemberWriter = Future<void> Function(
  String cid,
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
  String _cid = '', _account = '';
  int _binding = 0,
      _generation = 0,
      _identityEpoch = 0,
      _resolving = 0,
      _resolved = 0;
  int get interactionSequence => (_state['interaction_sequence'] as int?) ?? 0;
  NotificationScope? get scope => _cid.isEmpty
      ? null
      : (
          cid: _cid,
          account: _account,
          binding: _binding,
          generation: _generation,
        );
  bool isCurrent(NotificationScope? owner) => owner != null && owner == scope;
  String get cidNumber => _cid;
  int get receivedAt => (_state['_received_at'] as int?) ?? 0;
  int get memberReceivedAt =>
      (_state['_member_received_at'] as int?) ?? receivedAt;
  int get creatorReceivedAt =>
      (_state['_creator_received_at'] as int?) ?? receivedAt;
  int get unread => (_state['square_unread'] as int?) ?? 0;
  int get followingUnread => (_state['following_unread'] as int?) ?? 0;
  int get revision => (_state['revision'] as int?) ?? 0;
  Map<String, dynamic>? creatorFor(String cid) =>
      cid == _cid && _state['creator'] is Map<String, dynamic>
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
    _cid = '';
    _account = '';
    _binding = 0;
    notifyListeners();
  }

  Future<bool> restore() async {
    final epoch = _identityEpoch, sequence = ++_resolving;
    final user = await _user?.resolve();
    if (epoch != _identityEpoch) return false;
    final cid = user?.cidNumber ?? '',
        account = user?.accountId ?? '',
        binding = user?.bindingRevision ?? 0;
    final changed = cid != _cid || account != _account || binding != _binding;
    if (sequence < _resolved && changed) return false;
    if (sequence > _resolved) _resolved = sequence;
    if (changed) {
      _clear();
      _cid = cid;
      _account = account;
      _binding = binding;
      notifyListeners();
    }
    if (cid.isEmpty) return false;
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
      (db) => db.userNotificationStateEntitys.getByCidNumber(owner.cid),
    );
    if (!isCurrent(owner)) return;
    if (row?.stateJson != null) {
      try {
        final value = jsonDecode(row!.stateJson);
        if (value is Map<String, dynamic> &&
            value['cid_number'] == owner.cid &&
            value['binding_revision'] == owner.binding) {
          final baseline = valid(value, owner.cid);
          final partial =
              !value.containsKey('revision') &&
              value['creator'] is Map<String, dynamic> &&
              value['creator_revision'] is int &&
              (value['creator_revision'] as int) > 0;
          if (baseline || partial) {
            _state = value;
            _known = baseline;
          }
        }
      } on FormatException {
        /* 坏展示不安装；下次明确事件校准。 */
      }
    }
    if (row?.pendingJson != null) {
      try {
        final values = jsonDecode(row!.pendingJson!);
        if (values is List) {
          _pending.addAll(
            values
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
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
    final version = (_state['membergate_revision'] as int?) ?? 0,
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
        bool current() =>
            isCurrent(owner) && _state['membergate_revision'] == version;
        await _memberWriter(
          owner.cid,
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

  static bool valid(Map<String, dynamic> value, String cid) {
    if (value['cid_number'] != cid) return false;
    for (final key in [
      'revision',
      'square_unread',
      'following_unread',
      'interaction_unread',
      'through',
      'interaction_sequence',
    ]) {
      final n = value[key];
      if (n is! int || n < 0 || n > 9007199254740991) return false;
    }
    for (final section in ['membergate', 'creator']) {
      final version = value['${section}_revision'];
      if (value.containsKey('${section}_revision') &&
          (version is! int || version < 0 || version > 9007199254740991)) {
        return false;
      }
      if (value[section] != null &&
          (value[section] is! Map<String, dynamic> ||
              version is! int ||
              version <= 0)) {
        return false;
      }
    }
    return (value['interaction_sequence'] as int) <=
            (value['through'] as int) &&
        value['square_unread'] ==
            (value['following_unread'] as int) +
                (value['interaction_unread'] as int);
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
          !valid(value, owner.cid) ||
          value['binding_revision'] != owner.binding) {
        return;
      }
      await accept(value);
    } on Object {
      /* 推送失败不影响业务，下次明确事件再校准。 */
    }
  }

  Future<bool> accept(Map<String, dynamic> value) async {
    if (!await restore() ||
        !valid(value, _cid) ||
        value['binding_revision'] != _binding) {
      return false;
    }
    final owner = scope!;
    final counter = (value['revision'] as int) > revision || !_known;
    final interaction =
        (value['interaction_sequence'] as int) > interactionSequence;
    final creator =
        value['creator'] is Map &&
        ((value['creator_revision'] as int?) ?? 0) >
            ((_state['creator_revision'] as int?) ?? 0);
    final member =
        value['membergate'] is Map &&
        ((value['membergate_revision'] as int?) ?? 0) >
            ((_state['membergate_revision'] as int?) ?? 0);
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
        'ok',
        'cid_number',
        'binding_revision',
        'revision',
        'square_unread',
        'following_unread',
        'interaction_unread',
        'through',
      ]) {
        merged[key] = value[key];
      }
      _known = true;
    }
    if (creator) {
      merged['creator'] = value['creator'];
      merged['creator_revision'] = value['creator_revision'];
      merged['_creator_received_at'] = now;
    }
    if (member) {
      merged['membergate'] = value['membergate'];
      merged['membergate_revision'] = value['membergate_revision'];
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
    String cid,
    int version,
    Map<String, dynamic> creator, {
    required SquareSession session,
  }) async {
    if (!await restore()) return;
    final owner = scope!;
    await session.validateCurrent();
    if (!isCurrent(owner) ||
        cid != owner.cid ||
        session.cidNumber != cid ||
        session.bindingRevision != owner.binding ||
        session.accountId != owner.account) {
      return;
    }
    if (version <= ((_state['creator_revision'] as int?) ?? 0)) {
      if (_cacheDirty &&
          await _persist(owner) &&
          isCurrent(owner) &&
          !_cacheDirty) {
        notifyListeners();
      }
      return;
    }
    _state['cid_number'] = cid;
    _state['binding_revision'] = owner.binding;
    _state['creator_revision'] = version;
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
      jsonEncode(_state),
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
        await db.userNotificationStateEntitys.getByCidNumber(owner.cid) ??
        UserNotificationStateEntity();
    if (!isCurrent()) return;
    row
      ..cidNumber = owner.cid
      ..stateJson = state
      ..pendingJson = pending;
    await db.userNotificationStateEntitys.put(row);
    if (!isCurrent()) throw StateError('通知状态已更新');
  });

  // 与服务端单目标、50项及安全整数边界相同；坏本机意图不阻断后续校准。
  static bool _validRead(Map<String, dynamic> value) {
    final ids = value['ids'],
        posts = value['post_ids'],
        comments = value['comment_ids'],
        through = value['through'];
    bool number(dynamic n) => n is int && n > 0 && n <= 9007199254740991;
    bool names(dynamic values) =>
        values is List &&
        values.length <= 50 &&
        values.every(
          (v) =>
              v is String &&
              v != 'self' &&
              v != 'confirm' &&
              RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(v),
        );
    if (ids is! List ||
        ids.length > 50 ||
        !ids.every(number) ||
        !names(posts) ||
        !names(comments) ||
        (through != null && !number(through))) {
      return false;
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
              session.cidNumber != owner.cid ||
              session.bindingRevision != owner.binding) {
            return;
          }
          if (_pending.isNotEmpty) {
            await _flushReads(owner);
            return;
          }
          final value = await api.fetchNotificationState(session: session);
          await session.validateCurrent();
          if (!isCurrent(owner) ||
              !valid(value, owner.cid) ||
              value['binding_revision'] != owner.binding) {
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

  Future<Map<String, dynamic>> page({
    required NotificationScope owner,
    int? cursor,
  }) async {
    if (!await restore() || !isCurrent(owner)) throw StateError('通知身份已变化');
    final session = await _sessions?.ensureSession(), api = _api;
    if (!isCurrent(owner) ||
        session == null ||
        api == null ||
        session.cidNumber != owner.cid) {
      throw StateError('通知会话不可用');
    }
    final value = await api.fetchNotifications(
      session: session,
      cursor: cursor,
    );
    await session.validateCurrent();
    if (!isCurrent(owner)) throw StateError('通知身份已变化');
    final state = value['state'];
    if (state is Map<String, dynamic>) await accept(state);
    if (!isCurrent(owner)) throw StateError('通知身份已变化');
    return value;
  }

  Future<bool> read({
    required NotificationScope? owner,
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
              session.cidNumber != owner.cid ||
              session.bindingRevision != owner.binding) {
            return;
          }
          final value = await api.markNotifyRead(
            session: session,
            ids: (intent['ids'] as List).cast<int>(),
            through: intent['through'] as int?,
            postIds: (intent['post_ids'] as List).cast<String>(),
            commentIds: (intent['comment_ids'] as List).cast<String>(),
          );
          await session.validateCurrent();
          if (!isCurrent(owner)) return;
          if (!valid(value, owner.cid) ||
              value['binding_revision'] != owner.binding) {
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

  Future<bool> readAll({
    required NotificationScope owner,
    required int through,
  }) =>
      through > 0 ? read(owner: owner, through: through) : Future.value(false);
  void stop() {
    _identityEpoch++;
    _clear();
    _cid = '';
    _account = '';
    _binding = 0;
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
