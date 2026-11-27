// 验证聊天帧、邮箱进度、资源回执和每设备密文的协议往返。

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_network/frame.dart';
import 'package:citizen_network/message.dart';

void main() {
  test('邮箱进度按唯一Proto往返，空消息页也可继续', () {
    final request = ChatFrame()
      ..syncMessages = (SyncMessages()
        ..limit = 100
        ..cursor = 'scanned-key');
    final response = ChatFrame()
      ..messageBatch = (MessageBatch()..nextCursor = 'next-key');
    expect(
      ChatFrame.fromBuffer(request.writeToBuffer()).syncMessages.cursor,
      'scanned-key',
    );
    final page = ChatFrame.fromBuffer(response.writeToBuffer()).messageBatch;
    expect(page.messages, isEmpty);
    expect(page.nextCursor, 'next-key');
  });

  test('宿主资源回执只扩展原帧，指标与窗口完整往返', () {
    final frame = ChatFrame()
      ..success = Success(kind: 'fixture')
      ..resourceUsage = ResourceUsage(
        userId: 'user',
        deviceId: 'phone',
        accountId: 'fixture-account',
        bindingRevision: Int64.ONE,
        serverTimeMillis: Int64(1000),
        counters: [
          ResourceCounter(
            metric: 'device_frames',
            windowStartMillis: Int64.ZERO,
            charged: Int64.ONE,
            used: Int64(3),
            limit: Int64(20000),
          ),
          ResourceCounter(
            metric: 'delivery_bytes',
            windowStartMillis: Int64(100),
            charged: Int64.ONE,
            used: Int64(4),
          ),
        ],
      );
    final decoded = ChatFrame.fromBuffer(frame.writeToBuffer());
    expect(decoded.whichBody(), ChatFrame_Body.success);
    expect(decoded.resourceUsage.counters.first.used, Int64(3));
    expect(decoded.resourceUsage.counters.first.hasLimit(), isTrue);
    expect(decoded.resourceUsage.counters.last.hasLimit(), isFalse);
    expect(decoded.resourceUsage.serverTimeMillis, Int64(1000));
  });
  test('one message keeps distinct OpenMLS ciphertext per device', () {
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-a',
      senderDeviceId: 'device-a',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-b', deviceId: 'device-b'),
          openmlsCiphertext: <int>[1, 2, 3],
        ),
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-b', deviceId: 'device-c'),
          openmlsCiphertext: <int>[4, 5, 6],
        ),
      ],
      createdAtMillis: Int64.ONE,
    );
    final decoded = EncryptedMessage.fromBuffer(message.writeToBuffer());
    expect(decoded.messageId, 'message-a');
    expect(decoded.deliveries[0].openmlsCiphertext, <int>[1, 2, 3]);
    expect(decoded.deliveries[1].openmlsCiphertext, <int>[4, 5, 6]);
  });
}
