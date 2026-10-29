import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/system/notifications/notifications.dart';

/// 互动状态按浏览者CID归属，不写入帖子manifest或改变信息流顺序。
class SquareInteractionService extends ChangeNotifier {
  static final instance = SquareInteractionService();
  final _states = <String, Map<String, dynamic>>{};
  final _busy = <String>{};
  final _versions = <String, int>{};
  final _pending = <String, Completer<void>>{};
  final _reading = <String, Future<void>>{};
  SquareApiClient? _api;
  SquareSessionProvider? _sessions;
  Map<String, dynamic>? state(String post) =>
      _states['${Notifications.instance.scope?.cidNumber}:$post'];
  bool busy(String post) =>
      _busy.contains('${Notifications.instance.scope?.cidNumber}:$post');
  Future<void> load(
    String post,
    SquareApiClient api,
    SquareSessionProvider sessions,
  ) {
    final existing = _pending[post];
    if (existing != null) return existing.future;
    _api = api;
    _sessions = sessions;
    final c = Completer<void>();
    _pending[post] = c;
    if (_pending.length == 1) scheduleMicrotask(_flush);
    return c.future;
  }

  Future<void> _flush() async {
    final work = Map<String, Completer<void>>.of(_pending);
    _pending.clear();
    final api = _api, sessions = _sessions;
    try {
      if (api == null ||
          sessions == null ||
          !await Notifications.instance.restore()) {
        return;
      }
      final session = await sessions.ensureSession();
      if (session == null) return;
      final owner = Notifications.instance.scope;
      if (owner == null ||
          owner.cidNumber != session.cidNumber ||
          owner.bindRev != session.bindRev) {
        return;
      }
      final ids = work.keys.toList();
      for (var at = 0; at < ids.length; at += 50) {
        final versions = {
          for (final id in ids.skip(at).take(50))
            '${session.cidNumber}:$id':
                _versions['${session.cidNumber}:$id'] ?? 0,
        };
        final result = await api.fetchPostInteractions(
          session: session,
          postIds: ids.skip(at).take(50).toList(),
        );
        await session.validateCurrent();
        if (!Notifications.instance.isCurrent(owner)) return;
        for (final item in (result['items'] as List).whereType<Map>()) {
          final row = item.cast<String, dynamic>();
          final key = '${session.cidNumber}:${row['post_id']}';
          if (!_busy.contains(key) && (_versions[key] ?? 0) == versions[key]) {
            _states[key] = row;
          }
        }
      }
      notifyListeners();
    } on Object {
      /* 互动失败不阻断正文；用户可通过原下拉刷新重试。 */
    } finally {
      for (final c in work.values) {
        if (!c.isCompleted) c.complete();
      }
    }
  }

  void install(SquareSession session, Map<String, dynamic> row) {
    final owner = Notifications.instance.scope;
    if (owner == null ||
        owner.cidNumber != session.cidNumber ||
        owner.bindRev != session.bindRev) {
      return;
    }
    final post = row['post_id'];
    if (post is! String) return;
    final key = '${session.cidNumber}:$post';
    if (_busy.contains(key)) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    _states[key] = Map.unmodifiable(row);
    notifyListeners();
  }

  Future<void> toggle(
    String post,
    SquareApiClient api,
    SquareSessionProvider sessions,
  ) async {
    if (!await Notifications.instance.restore()) throw StateError('当前身份不可用');
    final owner = Notifications.instance.scope!;
    final key = '${owner.cidNumber}:$post';
    if (!_busy.add(key)) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    notifyListeners();
    try {
      final session = await sessions.ensureSession();
      if (session == null ||
          session.cidNumber != owner.cidNumber ||
          session.bindRev != owner.bindRev) {
        throw StateError('身份已变化');
      }
      final result = await api.setLike(
        session: session,
        postId: post,
        liked:
            !(_states[key]?['liked_by_me'] == true ||
                _states[key]?['liked_by_me'] == 1),
      );
      await session.validateCurrent();
      if (Notifications.instance.isCurrent(owner)) {
        _states[key] = (result['state'] as Map).cast<String, dynamic>();
      }
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  Future<void> viewed(String post, {int? through}) {
    final owner = Notifications.instance.scope;
    if (owner == null) return Future.value();
    final bound = through ?? Notifications.instance.through;
    final key = '$owner:$post:$bound';
    return _reading[key] ??= _viewed(
      post,
      owner,
      bound,
    ).whenComplete(() => _reading.remove(key));
  }

  Future<void> _viewed(
    String post,
    NotificationScope owner,
    int through,
  ) async {
    if (through <= 0) return;
    final key = '${owner.cidNumber}:$post';
    _versions[key] = (_versions[key] ?? 0) + 1;
    final queued = await Notifications.instance.read(
      owner: owner,
      scope: 'post',
      postId: post,
      through: through,
    );
    if (queued && Notifications.instance.isCurrent(owner)) {
      final key = '${owner.cidNumber}:$post';
      final previous = _states[key];
      if (previous != null && ((previous['through'] as int?) ?? 0) <= through) {
        _states[key] = {...previous, 'comment_unread': 0};
      }
      notifyListeners();
    }
  }
}
