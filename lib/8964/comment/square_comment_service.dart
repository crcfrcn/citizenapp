/// 主评论区与讨论串共享每个CID/内容的写操作围栏；重试仍使用原op_id。
class SquareCommentService {
  static final _active = <String>{};
  static Future<void> run(
    String cid,
    String post,
    Future<void> Function() action,
  ) async {
    final key = '$cid:$post';
    if (!_active.add(key)) throw StateError('该内容的评论操作正在提交，请稍后重试');
    try {
      await action();
    } finally {
      _active.remove(key);
    }
  }
}
