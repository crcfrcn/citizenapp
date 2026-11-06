import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/notifications.dart';

class SquareNotificationsPage extends StatefulWidget {
  const SquareNotificationsPage({
    super.key,
    required this.api,
    required this.sessions,
    required this.onOpenPost,
    this.selectedTab,
    this.tabIndex = 0,
  });
  final SquareApiClient api;
  final SquareSessionProvider? sessions;
  final ValueListenable<int>? selectedTab;
  final int tabIndex;
  final Future<void> Function(String postId, int through) onOpenPost;
  @override
  State<SquareNotificationsPage> createState() =>
      SquareNotificationsPageState();
}

class SquareNotificationsPageState extends State<SquareNotificationsPage>
    with WidgetsBindingObserver {
  final _rows = <Map<String, dynamic>>[];
  int? _next, _through;
  int _revision = -1,
      _observedRevision = -1,
      _observedSequence = -1,
      _request = 0;
  bool _loading = false, _dirty = true, _scheduled = false;
  bool _networkStarted = false,
      _resetFlight = false,
      _resetRequested = false,
      _forceRefresh = false;
  Future<void>? _loadFlight;
  String? _error;
  NotificationScope? _owner, _observedOwner;

  bool get _visible =>
      mounted &&
      (widget.selectedTab == null ||
          widget.selectedTab!.value == widget.tabIndex) &&
      ModalRoute.isCurrentOf(context) != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    final notifications = Notifications.instance;
    _observedOwner = notifications.scope;
    _observedRevision = notifications.listRevision;
    _observedSequence = notifications.interactionSequence;
    notifications.addListener(_changed);
    widget.selectedTab?.addListener(_activityChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activityChanged();
  }

  @override
  void didUpdateWidget(covariant SquareNotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      oldWidget.selectedTab?.removeListener(_activityChanged);
      widget.selectedTab?.addListener(_activityChanged);
    }
    if (oldWidget.api != widget.api || oldWidget.sessions != widget.sessions) {
      _request++;
      _loadFlight = null;
      _loading = false;
      _dirty = true;
      _forceRefresh = true;
    }
    if (oldWidget.selectedTab != widget.selectedTab ||
        oldWidget.tabIndex != widget.tabIndex) {
      _activityChanged();
    } else {
      _scheduleRefresh();
    }
  }

  void _activityChanged() {
    _scheduleRefresh();
    unawaited(_readVisible());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _activityChanged();
  }

  void _scheduleRefresh() {
    if (!_dirty || _loading || _scheduled || !_visible) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && _dirty && !_loading && _visible) {
        unawaited(_load(reset: true));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _changed() {
    if (!mounted) return;
    final notifications = Notifications.instance, owner = notifications.scope;
    if (owner != _observedOwner) {
      _request++;
      _loadFlight = null;
      _observedOwner = owner;
      setState(() {
        _owner = null;
        _revision = -1;
        _rows.clear();
        _next = null;
        _through = null;
        _error = null;
        _loading = false;
        _networkStarted = false;
        _forceRefresh = false;
        _resetRequested = false;
      });
      _dirty = true;
    } else if (notifications.listRevision != _observedRevision ||
        notifications.interactionSequence != _observedSequence) {
      _dirty = true;
    }
    _observedRevision = notifications.listRevision;
    _observedSequence = notifications.interactionSequence;
    _scheduleRefresh();
  }

  bool _isCurrent(int request, NotificationScope owner) =>
      mounted && request == _request && Notifications.instance.isCurrent(owner);
  Future<void> refresh() async {
    if (!_visible) {
      _dirty = true;
      _forceRefresh = true;
      return;
    }
    if (_loading) {
      final owner = Notifications.instance.scope;
      final needsReset = !_resetFlight || !_networkStarted;
      if (!_networkStarted) {
        _forceRefresh = true;
        _dirty = true;
      }
      if (!_resetFlight) {
        _resetRequested = true;
        _dirty = true;
        _forceRefresh = true;
      }
      await _loadFlight;
      if (needsReset &&
          mounted &&
          _visible &&
          Notifications.instance.isCurrent(owner)) {
        if (_loading && _resetFlight) {
          await _loadFlight;
        } else if (_dirty && _forceRefresh) {
          await _load(reset: true);
        }
      }
      return;
    }
    _forceRefresh = true;
    await _load(reset: true);
  }

  void _install(NotificationScope owner, NotificationListSnapshot snapshot) {
    setState(() {
      _owner = owner;
      _revision = snapshot.revision;
      _through = snapshot.through;
      _next = snapshot.nextCursor;
      _rows
        ..clear()
        ..addAll(snapshot.items);
    });
  }

  Future<void> _readVisible() async {
    final owner = _owner, through = _through, request = _request;
    if (owner == null ||
        through == null ||
        through <= 0 ||
        !_visible ||
        !_isCurrent(request, owner) ||
        Notifications.instance.notificationUnread <= 0) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (_isCurrent(request, owner) && _visible) {
      await Notifications.instance.read(
        owner: owner,
        scope: 'notifications',
        through: through,
      );
    }
  }

  Future<void> _load({bool reset = false}) {
    if (_loading) return _loadFlight ?? Future<void>.value();
    if (!_visible) return Future<void>.value();
    final request = ++_request;
    _resetFlight = reset;
    _networkStarted = false;
    _resetRequested = false;
    setState(() {
      _loading = true;
      _error = null;
    });
    _dirty = false;
    late final Future<void> task;
    task = _loadCurrent(request, reset).whenComplete(() {
      if (mounted && request == _request) {
        setState(() => _loading = false);
        if (identical(_loadFlight, task)) _loadFlight = null;
        _scheduleRefresh();
      }
    });
    _loadFlight = task;
    return task;
  }

  Future<void> _loadCurrent(int request, bool reset) async {
    NotificationScope? owner;
    final notifications = Notifications.instance;
    try {
      if (!await notifications.restore()) throw StateError('当前身份不可用');
      if (!mounted || request != _request) return;
      owner = notifications.scope!;
      final cached = notifications.cachedList;
      if (reset && cached != null) {
        _install(owner, cached);
        if (!_forceRefresh &&
            cached.revision >= notifications.listRevision &&
            cached.sequence >= notifications.interactionSequence) {
          _dirty = _resetRequested;
          await _readVisible();
          return;
        }
      }
      _networkStarted = true;
      _forceRefresh = false;
      final session = await widget.sessions?.ensureSession();
      if (!_isCurrent(request, owner)) return;
      if (session == null ||
          session.cidNumber != owner.cidNumber ||
          session.accountId != owner.accountId ||
          session.bindRev != owner.bindRev) {
        throw StateError('互动身份已变化');
      }
      final page = await widget.api.fetchNotifications(
        session: session,
        groupByPost: true,
        cursor: reset ? null : _next,
        through: reset ? null : _through,
      );
      await session.validateCurrent();
      if (!_isCurrent(request, owner)) return;
      final state = (page['state'] as Map).cast<String, dynamic>();
      if (!Notifications.valid(state, owner.cidNumber) ||
          state['bind_rev'] != owner.bindRev) {
        throw const FormatException('互动列表状态无效');
      }
      final merged = {
        for (final row in reset ? <Map<String, dynamic>>[] : _rows)
          row['post_id']: row,
        for (final raw in page['items'] as List)
          (raw as Map)['post_id']: raw.cast<String, dynamic>(),
      };
      final snapshot = NotificationListSnapshot(
        revision: state['notice_rev'] as int,
        sequence: state['interaction_sequence'] as int,
        through: page['through'] as int,
        nextCursor: page['next_cursor'] as int?,
        items: merged.values,
      );
      await notifications.accept(state, listChanged: false);
      if (!_isCurrent(request, owner)) return;
      if (notifications.listRevision > snapshot.revision ||
          notifications.interactionSequence > snapshot.sequence ||
          (_owner == owner && snapshot.revision < _revision)) {
        _dirty = true;
        return;
      }
      _dirty = _resetRequested;
      final stored = await notifications.cacheList(
        owner,
        snapshot,
        isCurrentRequest: () => _isCurrent(request, owner!),
      );
      if (!_isCurrent(request, owner)) return;
      if (!stored) {
        _dirty = true;
        return;
      }
      if (notifications.listRevision > snapshot.revision ||
          notifications.interactionSequence > snapshot.sequence) {
        _dirty = true;
        return;
      }
      _install(owner, snapshot);
      _dirty = _resetRequested;
      await _readVisible();
    } on Object {
      if (mounted &&
          request == _request &&
          (owner == null || notifications.isCurrent(owner))) {
        setState(() => _error = '互动读取失败，请下拉重试');
      }
    }
  }

  @override
  void dispose() {
    _request++;
    Notifications.instance.removeListener(_changed);
    widget.selectedTab?.removeListener(_activityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ListTile(title: Text(_error!), onTap: refresh),
        if ((_owner == null || _rows.isEmpty) && !_loading && _error == null)
          const ListTile(title: Text('暂无评论互动')),
        for (final row in _owner == null ? <Map<String, dynamic>>[] : _rows)
          Card(
            child: ListTile(
              title: Text(
                (row['post_title'] as String?)?.isNotEmpty == true
                    ? row['post_title'] as String
                    : (row['post_excerpt'] as String? ?? '内容'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('收到 ${row['notice_count']} 条评论互动'),
              trailing: Badge(
                isLabelVisible: (row['comment_unread'] as int) > 0,
                label: Text(
                  (row['comment_unread'] as int) > 99
                      ? '99+'
                      : '${row['comment_unread']}',
                ),
                child: const Icon(Icons.mode_comment_outlined),
              ),
              onTap: () =>
                  widget.onOpenPost(row['post_id'] as String, _through ?? 0),
            ),
          ),
        if (_next != null)
          TextButton(
            onPressed: _loading ? null : () => _load(),
            child: const Text('更多互动'),
          ),
      ],
    ),
  );
}
