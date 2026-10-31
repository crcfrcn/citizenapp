import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/notifications.dart';

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
  int _revision = -1, _observedRevision = -1, _request = 0;
  bool _loading = false, _dirty = true, _scheduled = false;
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
    _observedOwner = Notifications.instance.scope;
    _observedRevision = Notifications.instance.noticeRev;
    Notifications.instance.addListener(_changed);
    widget.selectedTab?.addListener(_activityChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRefresh();
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
      _loading = false;
      _dirty = true;
    }
    if (oldWidget.selectedTab != widget.selectedTab ||
        oldWidget.tabIndex != widget.tabIndex) {
      _dirty = true;
    }
    _scheduleRefresh();
  }

  void _activityChanged() {
    _dirty = true;
    _scheduleRefresh();
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
    final notifications = Notifications.instance;
    final owner = notifications.scope;
    if (owner != _observedOwner) {
      // 新账号不等待旧HTTP；失效旧请求也不能再改loading、错误或列表。
      _request++;
      _observedOwner = owner;
      _observedRevision = notifications.noticeRev;
      setState(() {
        _owner = null;
        _revision = -1;
        _rows.clear();
        _next = null;
        _through = null;
        _error = null;
        _loading = false;
      });
      _dirty = true;
    } else if (notifications.noticeRev != _observedRevision) {
      _observedRevision = notifications.noticeRev;
      _dirty = true;
    }
    _scheduleRefresh();
  }

  bool _isCurrent(int request, NotificationScope owner) =>
      mounted && request == _request && Notifications.instance.isCurrent(owner);

  Future<void> refresh() async {
    _dirty = true;
    if (!_visible || _loading) return;
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!_visible || _loading) {
      if (reset) _dirty = true;
      return;
    }
    final request = ++_request;
    NotificationScope? owner;
    setState(() {
      _loading = true;
      _error = null;
    });
    _dirty = false;
    try {
      if (!await Notifications.instance.restore()) throw StateError('当前身份不可用');
      if (!mounted || request != _request) return;
      owner = Notifications.instance.scope!;
      final session = await widget.sessions?.ensureSession();
      if (!_isCurrent(request, owner)) return;
      if (session == null ||
          session.cidNumber != owner.cidNumber ||
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
      final revision = state['notice_rev'] as int;
      await Notifications.instance.accept(state);
      if (!_isCurrent(request, owner)) return;
      if (Notifications.instance.noticeRev > revision ||
          (_owner == owner && revision < _revision)) {
        // 数据到达之前已有更新，旧列表不能冒充最新版本或清掉新到事件。
        _dirty = true;
        return;
      }
      setState(() {
        _owner = owner;
        _revision = revision;
        _through = page['through'] as int;
        _next = page['next_cursor'] as int?;
        final merged = {
          for (final row in reset ? <Map<String, dynamic>>[] : _rows)
            row['post_id']: row,
          for (final raw in page['items'] as List)
            (raw as Map)['post_id']: raw.cast<String, dynamic>(),
        };
        _rows
          ..clear()
          ..addAll(merged.values);
      });
      if (_visible &&
          _through! > 0 &&
          Notifications.instance.notificationUnread > 0) {
        await WidgetsBinding.instance.endOfFrame;
        if (_isCurrent(request, owner) && _visible) {
          await Notifications.instance.read(
            owner: owner,
            scope: 'notifications',
            through: _through,
          );
        }
      }
    } on Object {
      if (mounted &&
          request == _request &&
          (owner == null || Notifications.instance.isCurrent(owner))) {
        setState(() => _error = '互动读取失败，请下拉重试');
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
        // 在途刷新、推送和切账号分别保留意图，不按版本数字相等丢弃。
        _scheduleRefresh();
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
