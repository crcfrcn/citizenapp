// 验证帧、消息及密文字段编解码。

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_network/frame.dart';
import 'package:citizen_network/message.dart';

void main() {
  group('frame_test', _registerFrames);
  group('message_proto_test', _registerMessages);
}

// 验证聊天帧、邮箱进度、资源回执和每设备密文的协议往返。

void _registerFrames() {
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

// 验证消息只携带密文投递字段及部署中立设备路由。

void _registerMessages() {
  test('EncryptedMessage 只往返端到端密文瞬时投递字段', () {
    final message = EncryptedMessage(
      messageId: 'env-1',
      conversationId: 'conv-1',
      senderUserId:
          '0x1111111111111111111111111111111111111111111111111111111111111111',
      senderDeviceId: 'alice-phone',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(
            userId:
                '0x2222222222222222222222222222222222222222222222222222222222222222',
            deviceId: 'bob-phone',
          ),
          openmlsCiphertext: <int>[0xaa, 0xbb, 0xcc],
        ),
      ],
      createdAtMillis: Int64(1),
    );

    final restored = EncryptedMessage.fromBuffer(message.writeToBuffer());
    expect(restored.messageId, 'env-1');
    expect(restored.openmlsCiphertext, [0xaa, 0xbb, 0xcc]);
    expect(restored.recipientDeviceId, 'bob-phone');
    expect(
      restored.recipientUserId,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
  });

  test('ChatRoute 只保存宿主确认的设备路由', () {
    final route = ChatRoute(
      peerUserId:
          '0x2222222222222222222222222222222222222222222222222222222222222222',
      deviceId: 'bob-phone',
      createdAtMillis: Int64(1),
      expiresAtMillis: Int64(2),
    );

    final restored = ChatRoute.fromBuffer(route.writeToBuffer());
    expect(
      restored.peerUserId,
      '0x2222222222222222222222222222222222222222222222222222222222222222',
    );
    expect(restored.deviceId, 'bob-phone');
  });
  test('protocol uses deployment-neutral user identifiers', () {
    final route = ChatRoute(
      peerUserId: 'user-42',
      deviceId: 'device-a',
      createdAtMillis: Int64.ONE,
      expiresAtMillis: Int64.TWO,
    );
    final message = EncryptedMessage(
      messageId: 'message-a',
      conversationId: 'conversation-a',
      senderUserId: 'user-1',
      senderDeviceId: 'device-a',
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(userId: 'user-2', deviceId: 'device-b'),
          openmlsCiphertext: <int>[1, 2, 3],
        ),
      ],
      createdAtMillis: Int64.ONE,
    );

    expect(route.peerUserId, 'user-42');
    expect(message.senderUserId, 'user-1');
    expect(message.recipientUserId, 'user-2');
    expect(message.openmlsCiphertext, <int>[1, 2, 3]);
  });
}
