// 归并聊天原有回归，保留各来源用例、断言及独立生命周期。

import 'dart:io';

import 'package:chat/chat.dart';
import 'package:citizen_system/security/storage.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证最终绑定推进后旧聊天上下文失去读写能力。

void _registerChatStoreIdentityIsolation() {
  useIsolatedIsar();
  test('finalized 公开绑定推进代次，旧上下文不能读取或继续写入', () async {
    const first = ChatBinding(
      bindingScope:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'CID-A',
      bindingRevision: 1,
      accountId: 'account-a',
    );
    const next = ChatBinding(
      bindingScope:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      userId: 'CID-A',
      bindingRevision: 2,
      accountId: 'account-b',
    );
    final a = ChatStore(), b = ChatStore.withIndependentBindingGateForTest();
    final token = await a.activateBindingFence(first);
    final current = await b.convergeFinalizedBinding(next);
    expect(current.generation, greaterThan(token.generation));
    await expectLater(a.validateBindingFenceToken(token), throwsStateError);
    await expectLater(a.captureBindingFenceToken(first), throwsStateError);
    await expectLater(
      a.captureBindingFenceToken(
        const ChatBinding(
          bindingScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          userId: 'CID-B',
          bindingRevision: 2,
          accountId: 'account-b',
        ),
      ),
      throwsStateError,
    );
    await expectLater(a.convergeFinalizedBinding(first), throwsStateError);
  });
}

// 验证聊天正文与搜索索引只保存在独立本机数据库。

void _registerChatStoreSystemProtection() {
  useIsolatedIsar();
  test('ChatIsar 本文和搜索索引只保存于独立本地数据库', () async {
    const cid = 'CID-A';
    const account =
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final store = ChatStore();
    final token = await store.activateBindingFence(
      const ChatBinding(
        bindingScope: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        userId: cid,
        bindingRevision: 1,
        accountId: account,
      ),
    );
    final wire =
        const MlsWireMessage(
          conversationId: 'conversation',
          wireBytes: [1, 2],
          messageKind: MlsMessageKind.application,
        ).toEncryptedMessage(
          messageId: 'message',
          senderUserId: cid,
          senderDeviceId: 'device',
          recipientUserId: 'CID-B',
          recipientDeviceId: 'peer',
          createdAtMillis: 1,
        );
    final payload = ChatPayloadCodec.encode(ChatContent.text('本地查询内容'));
    await store.saveOutgoingMessage(
      bindingToken: token,
      ownerUserId: cid,
      currentAccountId: account,
      message: wire,
      messageBytes: wire.writeToBuffer(),
      recipientUserId: 'CID-B',
      messageKind: ChatMessageKind.text,
      deliveryState: ChatMessageDeliveryState.sent,
      plaintext: payload,
    );
    final row = await ChatIsar.instance.read(
      (isar) =>
          isar.chatMessageEntitys.getByOwnerUserIdMessageId(cid, 'message'),
    );
    expect(row!.payloadJson, payload);
    expect(row.searchTokens, contains('查询'));
    expect(
      (await store.searchMessages(
        ownerUserId: cid,
        currentAccountId: account,
        keyword: '查询',
      )).single.messageId,
      'message',
    );
    expect(wire.openmlsCiphertext, [1, 2]);
  });
}

// 验证聊天路径保护失败及越界或链接目录拒绝。

void _registerSystemProtectedStorage() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('citizenapp/chat/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('系统保护失败不返回可用聊天路径', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'data_storage_unavailable'),
    );
    await expectLater(
      SystemProtectedStorage.prepareChatDataDirectory(),
      throwsA(isA<PlatformException>()),
    );
  });
  test('SDK所属路径之外和链接子目录均拒绝', () async {
    final temporary = await Directory.systemTemp.createTemp('chat_policy_');
    final root = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    messenger.setMockMethodCallHandler(channel, (_) async => root.path);
    final child = await Directory('${root.path}/child').create();
    await SystemProtectedStorage.verifyChatDirectory(child);
    await expectLater(
      SystemProtectedStorage.verifyChatDirectory(root.parent),
      throwsStateError,
    );
    await Link('${root.path}/link').create(child.path);
    await expectLater(
      SystemProtectedStorage.verifyChatDirectory(
        Directory('${root.path}/link'),
      ),
      throwsStateError,
    );
  });
}

void main() {
  group(
    "storage/chat_store_identity_isolation_test",
    _registerChatStoreIdentityIsolation,
  );
  group(
    "storage/chat_store_system_protection_test",
    _registerChatStoreSystemProtection,
  );
  group(
    "storage/system_protected_storage_test",
    _registerSystemProtectedStorage,
  );
}
