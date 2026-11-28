// 展示点赞条和列表，保留原身份与访问复核。

import 'dart:async';

import 'package:citizen_square/interaction/actions.dart';
import 'package:citizen_user/api.dart' show SquareApiClient, SquareSession;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/notifications.dart'
    show NotificationScope, Notifications;
import 'package:citizen_user/profile/data.dart' show CitizenProfileApi;
import 'package:citizen_user/profile/page.dart' show UserProfilePage;
import 'package:flutter/material.dart';

// 展示帖子点赞用户列表并连接主页入口。

Widget squareLikerAvatar(
  Map<String, dynamic> row,
  SquareApiClient api,
  SquareSession? session,
) {
  final key = row['avatar_key'] as String?;
  return CircleAvatar(
    backgroundImage: key == null || session == null
        ? null
        : CitizenProfileApi(client: api).mediaImage(key, session: session),
    child: key == null ? const Icon(Icons.person_outline) : null,
  );
}

void openSquareLiker(BuildContext context, String cid, String? self) {
  unawaited(
    UserProfilePage.open(
      context,
      UserProfilePage(cidNumber: cid, isSelf: cid == self),
    ),
  );
}

class SquareLikesPage extends StatefulWidget {
  const SquareLikesPage({
    super.key,
    required this.postId,
    required this.api,
    required this.sessions,
  });
  final String postId;
  final SquareApiClient api;
  final SquareSessionProvider sessions;
  @override
  State<SquareLikesPage> createState() => _SquareLikesPageState();
}

class _SquareLikesPageState extends State<SquareLikesPage> {
  final _rows = <Map<String, dynamic>>[];
  String? _next;
  int _total = 0;
  bool _loading = false;
  String? _error;
  SquareSession? _session;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.sessions.ensureSession();
      if (session == null) throw StateError('当前身份不可用');
      final page = await widget.api.fetchLikes(
        session: session,
        postId: widget.postId,
        cursor: reset ? null : _next,
      );
      await session.validateCurrent();
      if (!mounted) return;
      if (_session != null && _session!.cidNumber != session.cidNumber) {
        throw StateError('身份已变化，请重新打开');
      }
      final rows = (page['items'] as List).map(
        (v) => (v as Map).cast<String, dynamic>(),
      );
      setState(() {
        _session = session;
        final byCid = {
          for (final r in reset ? <Map<String, dynamic>>[] : _rows)
            r['cid_number']: r,
          for (final r in rows) r['cid_number']: r,
        };
        _rows
          ..clear()
          ..addAll(byCid.values);
        _next = page['next_cursor'] as String?;
        _total = ((page['state'] as Map)['like_count'] as int);
      });
    } on Object {
      if (mounted) setState(() => _error = '点赞列表读取失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('点赞（$_total）')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              title: Text(_error!),
              onTap: () => _load(reset: _rows.isEmpty),
            ),
          if (_rows.isEmpty && !_loading && _error == null)
            const ListTile(title: Text('暂无点赞')),
          for (final row in _rows)
            ListTile(
              leading: squareLikerAvatar(row, widget.api, _session),
              title: Text(
                (row['display_name'] as String?)?.isNotEmpty == true
                    ? row['display_name'] as String
                    : '公民',
              ),
              onTap: () => openSquareLiker(
                context,
                row['cid_number'] as String,
                _session?.cidNumber,
              ),
            ),
          if (_next != null)
            TextButton(
              onPressed: _loading ? null : () => _load(),
              child: const Text('更多点赞用户'),
            ),
        ],
      ),
    ),
  );
}

// 展示帖子点赞头像及点赞列表入口。

class SquareLikesStrip extends StatefulWidget {
  const SquareLikesStrip({
    super.key,
    required this.postId,
    required this.api,
    required this.sessions,
    this.showLikeButton = true,
  });
  final String postId;
  final bool showLikeButton;
  final SquareApiClient api;
  final SquareSessionProvider sessions;
  @override
  State<SquareLikesStrip> createState() => _SquareLikesStripState();
}

class _SquareLikesStripState extends State<SquareLikesStrip> {
  List<Map<String, dynamic>> _rows = [];
  SquareSession? _session;
  String? _error;
  int _total = 0;
  bool _loading = false, _reloadPending = false;
  NotificationScope? _owner;
  final service = SquareInteractionService.instance;
  bool? _liked;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    Notifications.instance.addListener(_identityChanged);
    _owner = Notifications.instance.scope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reloadPending && ModalRoute.isCurrentOf(context) != false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  void _identityChanged() {
    final owner = Notifications.instance.scope;
    if (owner == _owner) return;
    _owner = owner;
    setState(() {
      _liked = null;
      _session = null;
    });
    _reloadPending = true;
    if (owner != null && ModalRoute.isCurrentOf(context) != false) {
      unawaited(_load());
    }
  }

  void _changed() {
    final state = service.state(widget.postId);
    if (state == null) return;
    final liked = state['liked_by_me'] == true || state['liked_by_me'] == 1;
    if (_reloadPending || liked != _liked || state['like_count'] != _total) {
      _liked = liked;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading) {
      _reloadPending = true;
      return;
    }
    if (ModalRoute.isCurrentOf(context) == false) {
      _reloadPending = true;
      return;
    }
    _reloadPending = false;
    _loading = true;
    try {
      final session = await widget.sessions.ensureSession();
      if (session == null) return;
      final previous = service.state(widget.postId);
      final page = await widget.api.fetchLikes(
        session: session,
        postId: widget.postId,
        limit: 8,
      );
      await session.validateCurrent();
      if (!mounted) return;
      final owner = Notifications.instance.scope;
      if (owner != null &&
          (owner.cidNumber != session.cidNumber ||
              owner.bindRev != session.bindRev)) {
        return;
      }
      if (!identical(previous, service.state(widget.postId)) ||
          service.busy(widget.postId)) {
        _reloadPending = true;
        return;
      }
      setState(() {
        _session = session;
        _rows = (page['items'] as List)
            .map((r) => (r as Map).cast<String, dynamic>())
            .toList();
        _total = (page['state'] as Map)['like_count'] as int;
        _liked =
            (page['state'] as Map)['liked_by_me'] == true ||
            (page['state'] as Map)['liked_by_me'] == 1;
        _error = null;
      });
      service.install(session, (page['state'] as Map).cast<String, dynamic>());
    } on Object {
      if (mounted) setState(() => _error = '点赞信息暂时不可用');
    } finally {
      _loading = false;
      if (mounted &&
          _reloadPending &&
          !service.busy(widget.postId) &&
          Notifications.instance.scope != null &&
          ModalRoute.isCurrentOf(context) != false) {
        unawaited(_load());
      }
    }
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    Notifications.instance.removeListener(_identityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('点赞 $_total'),
            if (widget.showLikeButton)
              IconButton(
                tooltip: _liked == true ? '取消点赞' : '点赞',
                onPressed: service.busy(widget.postId)
                    ? null
                    : () async {
                        try {
                          await service.toggle(
                            widget.postId,
                            widget.api,
                            widget.sessions,
                          );
                        } on Object {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('点赞操作失败，请重试')),
                            );
                          }
                        }
                      },
                icon: Icon(
                  _liked == true
                      ? Icons.thumb_up_alt
                      : Icons.thumb_up_alt_outlined,
                ),
              ),
          ],
        ),
        if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
        LayoutBuilder(
          builder: (context, c) {
            final count = ((c.maxWidth - 64) / 44).floor().clamp(
              0,
              _rows.length,
            );
            return Row(
              children: [
                for (final row in _rows.take(count))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => openSquareLiker(
                        context,
                        row['cid_number'] as String,
                        _session?.cidNumber,
                      ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: squareLikerAvatar(row, widget.api, _session),
                      ),
                    ),
                  ),
                if (_rows.isEmpty && _error == null) const Text('暂无点赞'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => SquareLikesPage(
                          postId: widget.postId,
                          api: widget.api,
                          sessions: widget.sessions,
                        ),
                      ),
                    );
                    if (mounted) unawaited(_load());
                  },
                  child: const Text('更多'),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
