import 'package:flutter_test/flutter_test.dart';
import 'package:chat/chat.dart';

void main() {
  test('私聊路由使用 SDK 唯一会话标识规则', () {
    expect(
      ChatRuntime.directConversationId('user-b', 'user-a'),
      ChatRuntime.directConversationId('user-a', 'user-b'),
    );
  });
}
