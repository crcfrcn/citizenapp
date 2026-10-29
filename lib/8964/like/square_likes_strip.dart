import 'package:citizenapp/system/notifications/notifications.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/8964/post/square_interaction_service.dart';

import 'square_likes_page.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(_load());});
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
