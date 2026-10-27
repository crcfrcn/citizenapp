import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/storage/social_isar.dart';
import 'package:citizenapp/system/notifications/notifications.dart';

import 'square_models.dart';

typedef CommentCacheWriter = Future<void> Function(
  String cid,
  String post,
  String page,
  String? pending, {
  required bool Function() isCurrent,
});

/// 所有帖子详情共用评论区；先读本地，缺失、主动刷新及相关新通知才获取远端。
class Comments extends StatefulWidget {
  const Comments({
    super.key,
    required this.postId,
    this.api,
    this.sessionProvider,
    this.ownerCid,
    this.initialCommentId,
    this.cacheWriter,
  });
  final String postId;
  final SquareApiClient? api;
  final SquareSessionProvider? sessionProvider;
  final String? ownerCid;
  final String? initialCommentId;
  final CommentCacheWriter? cacheWriter;
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> with WidgetsBindingObserver {
  late final SquareApiClient _api;
  late final SquareSessionProvider _sessions;
  final _text = TextEditingController();
  final _keys = <String, GlobalKey>{};
  final _seen = <String>{};
  final _reading = <String>{};
  final _random = Random.secure();
  ScrollPosition? _position;
  List<SquareComment> _rows = [];
  Map<String, dynamic>? _pending;
  SquareComment? _reply;
  String _cid = '';
  int? _next;
  int _generation = 0, _notice = 0, _revision = 0;
  bool _ready = false, _loading = false, _sending = false;
  String? _error;
  NotificationScope? _ownerScope;
  bool _reloadPending = false;
  bool _abandoning = false;
  bool get _visible =>
      ModalRoute.isCurrentOf(context) != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_markVisible);
      _position = position;
      _position?.addListener(_markVisible);
    }
    if (_ready) {
      if (_reloadPending && _visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _visible) unawaited(_load(reset: true));
        });
      }
      return;
    }
    _ready = true;
    _api = widget.api ?? context.read<SquareApiClient>();
    _sessions = widget.sessionProvider ?? context.read<SquareSessionProvider>();
    Notifications.instance.addListener(_onNotice);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final generation = ++_generation;
    final previousCid = _cid,
        draft = _text.text,
        pending = _pending,
        reload = _reloadPending;
    // 身份尚未确认时立即隐藏旧输入；同一CID核对通过后再恢复其本机草稿。
    setState(() {
      _cid = '';
      _rows = [];
      _ownerScope = null;
      _pending = null;
      _reply = null;
      _next = null;
      _loading = true;
      _sending = false;
      _abandoning = false;
      _error = null;
      _text.clear();
      _seen.clear();
      _reading.clear();
      _keys.clear();
      _notice = 0;
      _reloadPending = false;
    });
    try {
      final owner =
          widget.ownerCid ??
          (await context.read<CurrentUserContext>().resolve())?.cidNumber;
      if (!mounted || generation != _generation) return;
      if (owner == null || owner.isEmpty) {
        setState(() {
          _cid = '';
          _rows = [];
          _loading = false;
        });
        return;
      }
      final restored = await Notifications.instance.restore();
      if (!mounted || generation != _generation) return;
      if (!restored || Notifications.instance.scope?.cid != owner) {
        // 旧详情的ownerCid不能把新身份切换回旧草稿或继续发送。
        setState(() {
          _cid = '';
          _loading = false;
          _pending = null;
          _text.clear();
          _error = '评论身份已变化，请重新打开详情';
        });
        return;
      }
      final scope = Notifications.instance.scope!;
      _ownerScope = scope;
      _notice = Notifications.instance.interactionSequence;
      final saved = await SocialIsar.instance.read(
        (db) async => await db.squareCommentsEntitys.getByCidNumberPostId(
          owner,
          widget.postId,
        ),
      );
      if (!mounted ||
          generation != _generation ||
          !Notifications.instance.isCurrent(scope)) {
        return;
      }
      // 完整缓存校验及升级提交后才安装CID，失败不能留下可继续操作的旧快照。
      _ownerScope = scope;
      if (owner == previousCid) {
        _reloadPending = _reloadPending || reload;
        _pending = pending;
        _text.text = pending?['reply_text'] as String? ?? draft;
      }
      if (saved != null) {
        final page = jsonDecode(saved.pageJson) as Map<String, dynamic>;
        var upgraded = false;
        void move(Map<String, dynamic> value, String old, String current) {
          if (!value.containsKey(old)) return;
          if (value.containsKey(current)) throw StateError('评论旧记录字段冲突');
          value[current] = value.remove(old);
          upgraded = true;
        }

        if (page['comments'] is List) {
          for (final raw in page['comments'] as List) {
            final value = (raw as Map).cast<String, dynamic>();
            move(value, 'sequence', 'reply_seq');
            move(value, 'body', 'reply_text');
            move(value, 'state', 'reply_state');
          }
        }
        _rows = _decode(page);
        _next = page['next_cursor'] as int?;
        if (saved.pendingJson != null) {
          _pending = (jsonDecode(saved.pendingJson!) as Map)
              .cast<String, dynamic>();
          move(_pending!, 'body', 'reply_text');
          _text.text = _pending!['reply_text'] as String;
        }
        if (upgraded) {
          await _save(
            ownerCid: owner,
            priorPage: saved.pageJson,
            priorPending: saved.pendingJson,
          );
        }
        _afterLayout();
      }
      if (!mounted ||
          generation != _generation ||
          !Notifications.instance.isCurrent(scope)) {
        return;
      }
      _cid = owner;
      setState(() => _loading = false);
      if (_reloadPending ||
          saved == null ||
          (widget.initialCommentId != null &&
              !_rows.any((r) => r.commentId == widget.initialCommentId))) {
        await _load(reset: true, target: widget.initialCommentId);
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(() {
          // 升级未确认时撤销内存操作入口；原记录保留，刷新须重新读取完整快照。
          _cid = '';
          _ownerScope = null;
          _rows = [];
          _pending = null;
          _reply = null;
          _next = null;
          _text.clear();
          _loading = false;
          _error = '评论暂时不可用，请刷新重试';
        });
      }
    }
  }

  List<SquareComment> _decode(Map<String, dynamic> page) {
    final raw = page['comments'];
    if (raw is! List || raw.length > 50) throw const FormatException('评论分页无效');
    final rows = raw
        .map(
          (value) =>
              SquareComment.fromJson((value as Map).cast<String, dynamic>()),
        )
        .toList();
    if (rows.any((r) => r.postId != widget.postId)) {
      throw const FormatException('评论不属于当前帖子');
    }
    return rows;
  }

  Future<SquareSession> _session() async {
    final session = await _sessions.ensureSession();
    if (session == null || session.cidNumber != _cid) {
      throw StateError('评论身份已变化');
    }
    await session.validateCurrent();
    return session;
  }

  Future<void> _load({bool reset = false, String? target}) async {
    if (_cid.isEmpty) return;
    if (!_visible) {
      if (reset) _reloadPending = true;
      return;
    }
    if (_loading || _sending) {
      if (reset) _reloadPending = true;
      return;
    }
    _reloadPending = false;
    final generation = _generation, revision = _revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _session();
      if (!mounted || generation != _generation) return;
      if (!_visible) {
        _reloadPending = true;
        return;
      }
      final page = await _api.fetchComments(
        session: session,
        postId: widget.postId,
        cursor: reset ? null : _next,
        target: target,
      );
      await session.validateCurrent();
      if (!mounted || generation != _generation) return;
      // 同帖写操作在途或已完成时，旧GET不能覆盖新评论和删除结果。
      if (_sending || revision != _revision) {
        _reloadPending = true;
        return;
      }
      final incoming = _decode(page), merged = <String, SquareComment>{};
      if (!reset) {
        for (final row in _rows) {
          merged[row.commentId] = row;
        }
      }
      for (final row in incoming) {
        merged[row.commentId] = row;
      }
      _rows = merged.values.toList()
        ..sort((a, b) => b.replySeq.compareTo(a.replySeq));
      _next = page['next_cursor'] as int?;
      setState(() {});
      await _save();
      _afterLayout();
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = '评论读取失败，已保留本地内容');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        _reloadIfNeeded();
      }
    }
  }

  void _reloadIfNeeded() {
    if (mounted &&
        _reloadPending &&
        _cid.isNotEmpty &&
        !_loading &&
        !_sending &&
        _visible) {
      unawaited(_load(reset: true));
    }
  }

  Future<void> _save({
    bool completed = false,
    String? ownerCid,
    String? priorPage,
    String? priorPending,
  }) async {
    final generation = _generation, cid = ownerCid ?? _cid;
    final page = jsonEncode({
      'comments': _rows.take(50).map((r) => r.toJson()).toList(),
      'next_cursor': _rows.length > 50 ? _rows[49].replySeq : _next,
    });
    final pending = completed || _pending == null ? null : jsonEncode(_pending);
    if (widget.cacheWriter != null) {
      await widget.cacheWriter!(
        cid,
        widget.postId,
        page,
        pending,
        isCurrent: () => mounted && generation == _generation,
      );
      return;
    }
    await SocialIsar.instance.writeTxn((db) async {
      if (generation != _generation || cid.isEmpty) return;
      final row =
          await db.squareCommentsEntitys.getByCidNumberPostId(
            cid,
            widget.postId,
          ) ??
          SquareCommentsEntity();
      if (priorPage != null &&
          (row.pageJson != priorPage || row.pendingJson != priorPending)) {
        throw StateError('评论旧记录已变化，升级未提交');
      }
      if (!mounted || generation != _generation) return;
      row
        ..cidNumber = cid
        ..postId = widget.postId
        ..pageJson = page
        ..pendingJson = pending;
      await db.squareCommentsEntitys.put(row);
    });
  }

  Future<void> _send() async {
    if (_sending || _cid.isEmpty) return;
    final body = _text.text.trim();
    if (body.isEmpty ||
        body.runes.length > 2000 ||
        utf8.encode(body).length > 8192) {
      return;
    }
    final generation = _generation;
    var submitted = false;
    _pending ??= {
      'operation_id': List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'reply_text': body,
      'reply_to': _reply?.commentId,
    };
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _save();
      if (!mounted || generation != _generation) return;
      final session = await _session();
      if (!mounted || generation != _generation) return;
      final pending = _pending!;
      final result = await _api.createComment(
        session: session,
        postId: widget.postId,
        operationId: pending['operation_id'] as String,
        replyText: pending['reply_text'] as String,
        replyTo: pending['reply_to'] as String?,
      );
      await session.validateCurrent();
      if (!mounted || generation != _generation) return;
      final row = SquareComment.fromJson(
        (result['comment'] as Map).cast<String, dynamic>(),
      );
      if (row.postId != widget.postId || row.authorCid != _cid) {
        throw StateError('评论回执不一致');
      }
      submitted = true;
      _revision++;
      _rows = [row, ..._rows.where((r) => r.commentId != row.commentId)];
      // 原操作保留到完成状态落盘；失败仍按同一ID核对服务端结果。
      await _save(completed: true);
      if (!mounted || generation != _generation) return;
      _pending = null;
      _reply = null;
      _text.clear();
      setState(() {});
      _afterLayout();
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () => _error = submitted ? '服务端已确认，本机保存失败，请重试原操作' : '发送失败，原评论已保留，请重试',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
        _reloadIfNeeded();
      }
    }
  }

  /// 放弃的是本机重试意图；保存失败仍保留原操作，不自动换ID或声称撤回服务端。
  Future<void> _abandon() async {
    if (_cid.isEmpty || _sending || _pending == null) {
      return;
    }
    final generation = _generation, previous = _pending, reply = _reply;
    setState(() {
      _sending = true;
      _abandoning = true;
    });
    try {
      _pending = null;
      _reply = null;
      await _save();
      if (mounted && generation == _generation) {
        setState(() => _error = '已放弃本机待发记录，请先刷新核对服务端结果');
      }
    } on Object {
      if (mounted && generation == _generation) {
        _pending = previous;
        _reply = reply;
        setState(() => _error = '本机保存失败，原待发记录仍保留');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _sending = false;
          _abandoning = false;
        });
        _reloadIfNeeded();
      }
    }
  }

  Future<void> _delete(SquareComment row) async {
    if (row.authorCid != _cid || _sending) return;
    final generation = _generation;
    try {
      final session = await _session();
      if (!mounted || generation != _generation) return;
      await _api.deleteComment(
        session: session,
        postId: widget.postId,
        commentId: row.commentId,
      );
      await session.validateCurrent();
      if (!mounted || generation != _generation) return;
      _revision++;
      final data = row.toJson()
        ..['reply_text'] = ''
        ..['reply_state'] = 'deleted';
      _rows = [
        for (final current in _rows)
          current.commentId == row.commentId
              ? SquareComment.fromJson(data)
              : current,
      ];
      await _save();
      setState(() {});
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _error = '删除失败，请重试');
      }
    }
  }

  void _onNotice() {
    if (!mounted) return;
    final notifications = Notifications.instance;
    if ((_ownerScope != null && !notifications.isCurrent(_ownerScope)) ||
        (_cid.isNotEmpty && notifications.cidNumber != _cid)) {
      _rows = [];
      _seen.clear();
      unawaited(_restore());
      return;
    }
    if (_ownerScope != notifications.scope && notifications.cidNumber == _cid) {
      _ownerScope = notifications.scope;
      _reading.clear();
      _seen.clear();
      _afterLayout();
    }
    // 统一互动序号覆盖同批多帖；当前可见区补取一次，隐藏页面只记意图。
    if (notifications.interactionSequence > _notice) {
      _notice = notifications.interactionSequence;
      _reloadPending = true;
      if (_visible) {
        unawaited(_load(reset: true));
      }
    }
  }

  void _afterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[widget.initialCommentId]?.currentContext;
      if (target != null) unawaited(Scrollable.ensureVisible(target));
      _markVisible();
    });
  }

  void _markVisible() {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    final size = MediaQuery.sizeOf(context),
        padding = MediaQuery.paddingOf(context),
        insets = MediaQuery.viewInsetsOf(context);
    final viewport = Rect.fromLTRB(
      0,
      padding.top + kToolbarHeight,
      size.width,
      size.height - insets.bottom - padding.bottom,
    );
    final ids = <String>[];
    for (final row in _rows) {
      if (_seen.contains(row.commentId) || _reading.contains(row.commentId)) {
        continue;
      }
      final box = _keys[row.commentId]?.currentContext?.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(viewport)) {
        ids.add(row.commentId);
      }
    }
    if (ids.isNotEmpty) {
      final owner = _ownerScope, visible = ids.take(50).toList();
      _reading.addAll(visible);
      unawaited(
        Notifications.instance.read(owner: owner, commentIds: visible).then((
          queued,
        ) {
          if (mounted && owner == _ownerScope) {
            _reading.removeAll(visible);
            if (queued) _seen.addAll(visible);
          }
        }),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _afterLayout();
      if (_reloadPending && ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_load(reset: true));
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _position?.removeListener(_markVisible);
    Notifications.instance.removeListener(_onNotice);
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(child: Text('评论')),
          IconButton(
            tooltip: '刷新评论',
            onPressed: _loading
                ? null
                : () =>
                      unawaited(_cid.isEmpty ? _restore() : _load(reset: true)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (_rows.isEmpty && !_loading && _error == null) const Text('暂无评论'),
      for (final row in _rows)
        ListTile(
          key: _keys.putIfAbsent(row.commentId, GlobalKey.new),
          title: Text(row.displayName.trim().isEmpty ? '公民' : row.displayName),
          subtitle: Text(row.replyState == 'deleted' ? '评论已删除' : row.replyText),
          trailing: row.replyState == 'active'
              ? PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'reply') {
                      setState(() => _reply = row);
                    } else {
                      unawaited(_delete(row));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'reply', child: Text('回复')),
                    if (row.authorCid == _cid)
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                )
              : null,
        ),
      if (_next != null)
        TextButton(
          onPressed: _loading ? null : () => unawaited(_load()),
          child: const Text('更早评论'),
        ),
      if (_reply != null)
        Row(
          children: [
            Expanded(
              child: Text(
                '回复 ${_reply!.displayName.trim().isEmpty ? '公民' : _reply!.displayName}',
              ),
            ),
            IconButton(
              onPressed: _sending ? null : () => setState(() => _reply = null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      if (_pending != null)
        TextButton(
          onPressed: _cid.isEmpty || _sending
              ? null
              : () => unawaited(_abandon()),
          child: const Text('放弃本机待发'),
        ),
      TextField(
        key: const ValueKey('comment-input'),
        controller: _text,
        readOnly: _cid.isEmpty || _sending || _pending != null,
        maxLength: 2000,
        minLines: 1,
        maxLines: 5,
        decoration: const InputDecoration(hintText: '发表评论'),
      ),
      FilledButton(
        key: const ValueKey('comment-send'),
        onPressed: _cid.isEmpty || _sending ? null : () => unawaited(_send()),
        child: Text(
          _abandoning
              ? '保存中'
              : _sending
              ? '发送中'
              : _pending == null
              ? '发送'
              : '重试发送',
        ),
      ),
    ],
  );
}
