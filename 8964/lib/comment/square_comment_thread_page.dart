import 'package:flutter/material.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_session_provider.dart';

import 'package:citizen_square/comment/comments.dart';

class SquareCommentThreadPage extends StatelessWidget {
  const SquareCommentThreadPage({
    super.key,
    required this.postId,
    required this.commentId,
    required this.api,
    required this.sessions,
    required this.ownerCid,
  });
  final String postId, commentId, ownerCid;
  final SquareApiClient api;
  final SquareSessionProvider sessions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('评论对话')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Comments(
          postId: postId,
          api: api,
          sessionProvider: sessions,
          ownerCid: ownerCid,
          threadId: commentId,
        ),
      ],
    ),
  );
}
