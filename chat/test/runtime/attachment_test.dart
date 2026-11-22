// 以真实MLS验证群控制及按冻结设备路由持久化附件投递。

import 'package:citizen_testing/chat_runtime_fixture.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chat/message/chat_content.dart';
import 'package:chat/message/chat_message.dart';
import 'package:chat/mls/mls_boundary.dart';
import 'package:chat/mls/mls_group_boundary.dart';
import 'package:citizen_network/protocol/message.dart';
import 'package:chat/message/direct_flow.dart';
import 'package:chat/group/group_flow.dart';
import 'package:chat/chat_store.dart';
import 'package:chat/chat_models.dart';
import 'package:citizen_testing/chat_isar_test_env.dart';
import 'package:citizen_testing/mls_test_env.dart';
import 'package:chat/transport/chat_connection.dart';

Future<GroupState> _joinedDirectGroup(
  TestMlsDevice sender,
  List<TestMlsDevice> receivers,
  List<MlsKeyPackage> packages,
) async {
  final created = await sender.crypto.withMessage(
    'group-bootstrap',
    () => sender.crypto.createGroup(''),
  );
  final staged = await sender.crypto.withMessage(
    'group-bootstrap',
    () => sender.crypto.addMembers(created.groupId, packages),
  );
  expect((await sender.crypto.groupState(created.groupId)).epoch, 0);
  expect(staged.epoch, 0);
  await sender.crypto.finishCommit('group-bootstrap', accepted: true);
  for (final receiver in receivers) {
    await receiver.crypto.withMessage(
      'group-welcome',
      () => receiver.crypto.groupProcess(staged.welcome!),
    );
  }
  return sender.crypto.groupState(created.groupId);
}

void main() {
  test('真实MLS同epoch改名A到B再到A，每次控制都实际应用', () async {
    final dir = await createMlsTestDirectory(),
        a = await createTestMlsDevice(dir, 'a'),
        b = await createTestMlsDevice(dir, 'b', cid: 'CID-B');
    final store = ChatStore(), account = '0x${'33' * 32}';
    Future<ChatBindingFenceToken> token(String user) =>
        store.activateBindingFence(
          ChatBinding(
            userId: user,
            accountId: account,
            bindingRevision: 1,
            bindingScope: '0x${'44' * 32}',
          ),
        );
    final receiver = ChatGroupFlow(
      crypto: b.crypto,
      store: store,
      bindingToken: await token('CID-B'),
      ownerUserId: 'CID-B',
      userId: 'CID-B',
      currentAccountId: account,
      localDeviceId: b.identity.deviceId,
      submitCommit: (_) async => throw StateError('收件端不得提交 Commit'),
      deliverer: (message, _, _, _) async => ChatDeliveryResult(
        messageId: message.messageId,
        state: ChatMessageDeliveryState.sent,
      ),
    );
    final ids = <String>[];
    final sender = ChatGroupFlow(
      crypto: a.crypto,
      store: store,
      bindingToken: await token('CID-A'),
      ownerUserId: 'CID-A',
      userId: 'CID-A',
      currentAccountId: account,
      localDeviceId: a.identity.deviceId,
      submitCommit: (frame) async {
        for (final message in frame.messages) {
          await receiver.processIncomingGroupMessage(message.writeToBuffer());
        }
      },
      deliverer: (message, bytes, _, _) async {
        ids.add(message.messageId);
        await receiver.processIncomingGroupMessage(bytes);
        return ChatDeliveryResult(
          messageId: message.messageId,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    const group = 'grp:CID-A:rename';
    await sender.createGroup(
      groupId: group,
      name: '原名',
      userId: 'CID-A',
      localDeviceId: a.identity.deviceId,
      invitees: [await b.crypto.createKeyPackage(b.identity)],
    );
    ids.clear();
    for (final name in ['A', 'B', 'A']) {
      await sender.renameGroup(group, name);
      expect((await store.readGroup('CID-B', group))!.name, name);
    }
    expect(ids.toSet(), hasLength(3));
    expect((await a.crypto.groupState(group)).epoch, 1);
  });
  for (final sticker in [false, true]) {
    test('真实MLS已确认组的待发${sticker ? '贴纸' : '文字'}为每台设备保存应用密文，重试不覆盖', () async {
      final dir = await createMlsTestDirectory(),
          a = await createTestMlsDevice(dir, 'a');
      final receivers = [
        await createTestMlsDevice(dir, 'b', cid: 'CID-B'),
        await createTestMlsDevice(dir, 'c', cid: 'CID-B'),
      ];
      final store = ChatStore(), account = '0x${'33' * 32}';
      final token = await store.activateBindingFence(
        ChatBinding(
          userId: 'CID-A',
          accountId: account,
          bindingRevision: 1,
          bindingScope: '0x${'44' * 32}',
        ),
      );
      final payload = sticker
          ? ChatContent.sticker(packId: 'fluent3d', stickerId: 'grinning_face')
          : ChatContent.text('hello');
      await store.savePendingOutgoingMessage(
        bindingToken: token,
        ownerUserId: 'CID-A',
        currentAccountId: account,
        localMessageId: 'pending:devices',
        conversationId: 'direct-devices',
        recipientUserId: 'CID-B',
        messageKind: payload.kind,
        payload: ChatPayloadCodec.encode(payload),
        createdAtMillis: 1234,
      );
      final packages = <MlsKeyPackage>[];
      for (final receiver in receivers) {
        packages.add(await receiver.crypto.createKeyPackage(receiver.identity));
      }
      final audience = await _joinedDirectGroup(a, receivers, packages);
      final flow = ChatFlow(
        groupIdBytes: mlsGroupIdBytes(audience.groupId),
        mediaLimits: const TestChatMediaLimits(),
        crypto: a.crypto,
        store: store,
        bindingToken: token,
        ownerUserId: 'CID-A',
        currentAccountId: account,
        deliveryScheduler: (_, _) {},
        deliverer: (_, _, _, _) async => throw StateError('队列持久化阶段不得联网'),
      );
      if (sticker) {
        await flow.sendSticker(
          conversationId: 'direct-devices',
          senderUserId: 'CID-A',
          recipientUserId: 'CID-B',
          senderDeviceId: a.identity.deviceId,
          packId: 'fluent3d',
          stickerId: 'grinning_face',
          pendingLocalMessageId: 'pending:devices',
          createdAtMillis: 1234,
        );
      } else {
        await flow.sendText(
          conversationId: 'direct-devices',
          senderUserId: 'CID-A',
          recipientUserId: 'CID-B',
          senderDeviceId: a.identity.deviceId,
          text: 'hello',
          pendingLocalMessageId: 'pending:devices',
          createdAtMillis: 1234,
        );
      }
      final queued = await store.readQueuedMessages(
        bindingToken: token,
        ownerUserId: 'CID-A',
      );
      expect(queued, hasLength(2));
      expect(queued.map((q) => q.messageId).toSet(), hasLength(2));
      expect(
        await store.readMessages(
          ownerUserId: 'CID-A',
          currentAccountId: account,
          conversationId: 'direct-devices',
        ),
        hasLength(1),
      );
      for (final receiver in receivers) {
        var applications = 0;
        for (final item in queued) {
          final message = EncryptedMessage.fromBuffer(item.messageBytes);
          if (message.recipientDeviceId != receiver.identity.deviceId) {
            continue;
          }
          final received = await receiver.crypto.withMessage(
            message.messageId,
            () => receiver.crypto.groupProcess(
              mlsWireMessageFromEncryptedMessage(message),
            ),
          );
          if (received.kind == GroupInboundKind.application) {
            applications++;
            expect(
              ChatPayloadCodec.decode(utf8.decode(received.plaintext!)).kind,
              payload.kind,
            );
          }
          await receiver.crypto.acknowledgeMessage(message.messageId);
          final replay = await receiver.crypto.withMessage(
            message.messageId,
            () => receiver.crypto.groupProcess(
              mlsWireMessageFromEncryptedMessage(message),
            ),
          );
          expect(replay.status, GroupProcessStatus.stale);
        }
        expect(applications, 1);
      }
    });
  }

  useIsolatedChatIsar();
  requireMlsTestLibrary();

  test('真实MLS附件控制为已确认组的两台收件设备分别持久化投递条目', () async {
    final dir = await createMlsTestDirectory(),
        a = await createTestMlsDevice(dir, 'a');
    final receivers = [
      await createTestMlsDevice(dir, 'b', cid: 'CID-B'),
      await createTestMlsDevice(dir, 'c', cid: 'CID-B'),
    ];
    final packages = <MlsKeyPackage>[];
    for (final receiver in receivers) {
      packages.add(
        await receiver.crypto.createKeyPackage(
          receiver.identity,
          lastResort: true,
        ),
      );
    }
    final database = ChatStore();
    final account = '0x${'33' * 32}';
    final token = await database.activateBindingFence(
      ChatBinding(
        userId: a.identity.userId,
        accountId: account,
        bindingRevision: 1,
        bindingScope: '0x${'44' * 32}',
      ),
    );
    final tasks = <Future<void> Function()>[];
    final controls = <ChatContent>[];
    final audience = await _joinedDirectGroup(a, receivers, packages);
    final flow = ChatFlow<ChatBindingFenceToken>(
      groupIdBytes: mlsGroupIdBytes(audience.groupId),
      mediaLimits: const TestChatMediaLimits(),
      crypto: a.crypto,
      store: database,
      bindingToken: token,
      ownerUserId: a.identity.userId,
      currentAccountId: account,
      deliveryScheduler: (_, delivery) => tasks.add(delivery),
      deliverer: (message, bytes, user, device) async {
        final receiver = receivers.singleWhere(
          (r) => r.identity.deviceId == device,
        );
        final result = await receiver.crypto.withMessage(
          message.messageId,
          () => receiver.crypto.groupProcess(
            mlsWireMessageFromEncryptedMessage(message),
          ),
        );
        if (result.kind == GroupInboundKind.application) {
          controls.add(ChatPayloadCodec.decode(utf8.decode(result.plaintext!)));
        }
        return ChatDeliveryResult(
          messageId: message.messageId,
          state: ChatMessageDeliveryState.sent,
        );
      },
    );
    const conversation = 'direct-two-devices';
    Future<List<ChatQueuedMessage>> queued() => database.readQueuedMessages(
      bindingToken: token,
      ownerUserId: a.identity.userId,
      conversationId: conversation,
    );
    expect(await queued(), isEmpty);
    final source = File('${a.root.path}/source'),
        cipher = File('${a.root.path}/cipher');
    await source.writeAsBytes([1, 2, 3], flush: true);
    final roster = [...audience.memberIdentities]..sort();
    final content = await a.attachment().seal(
      attachmentId: 'file-1',
      byteSize: 3,
      source: source,
      target: cipher,
      members: roster,
      keyPackages: packages,
      contentBuilder: (d) => createTestMediaContent(d, 3),
    );
    await flow.sendMediaControl(
      conversationId: conversation,
      senderUserId: a.identity.userId,
      recipientUserId: 'CID-B',
      senderDeviceId: a.identity.deviceId,
      media: content,
      createdAtMillis: 1234,
    );
    final media = await queued();
    expect(media.length, 2);
    expect(media.map((m) => m.messageId).toSet().length, 2);
    final envelopes = media
        .map((m) => EncryptedMessage.fromBuffer(m.messageBytes))
        .toList();
    expect(
      envelopes.map((m) => m.recipientDeviceId).toSet(),
      receivers.map((r) => r.identity.deviceId).toSet(),
    );
    expect(envelopes.first.openmlsCiphertext, envelopes.last.openmlsCiphertext);
    await tasks.removeAt(0)();
    expect(controls.length, 2);
    expect(
      controls.every((c) => c.attachmentGroupId == content.attachmentGroupId),
      true,
    );
    expect(
      (await a.crypto.groupState(audience.groupId)).memberIdentities.toSet(),
      roster.toSet(),
    );
  });
}
