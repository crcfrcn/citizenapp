import 'dart:async';

import 'package:flutter/material.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/account/profile/citizen_profile_api.dart';
import 'package:citizenapp/account/profile/user_profile_page.dart';
import 'package:citizenapp/account/identity/identity_register_guide.dart';

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
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CitizenServiceGate(
        title: '用户主页',
        description: '注册后即可查看用户主页。',
        child: UserProfilePage(cidNumber: cid, isSelf: cid == self),
      ),
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
  int? _next;
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
        _next = page['next_cursor'] as int?;
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
