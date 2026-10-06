import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import '../../support/isar_test_env.dart';

void main() {
  useIsolatedIsar();
  test('ChatIsar 本文和搜索索引只保存于独立本地数据库', () async {
    const cid = 'CID-A';
    const account = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final store = ChatStore();
    final token = await store.activateBindingFence(const ChatBinding(
      bindingScope: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      userId: cid, bindingRevision: 1, accountId: account));
    final wire = const MlsWireMessage(conversationId: 'conversation', wireBytes: [1,2],
      messageKind: MlsMessageKind.application).toEncryptedMessage(messageId: 'message',
      senderUserId: cid, senderDeviceId: 'device', recipientUserId: 'CID-B',
      recipientDeviceId: 'peer', createdAtMillis: 1);
    final payload = ChatPayloadCodec.encode(ChatContent.text('本地查询内容'));
    await store.saveOutgoingMessage(bindingToken: token, ownerUserId: cid, currentAccountId: account,
      message: wire, messageBytes: wire.writeToBuffer(), recipientUserId: 'CID-B',
      messageKind: ChatMessageKind.text, deliveryState: ChatMessageDeliveryState.sent, plaintext: payload);
    final row = await ChatIsar.instance.read((isar) => isar.chatMessageEntitys.getByOwnerUserIdMessageId(cid, 'message'));
    expect(row!.payloadJson, payload);
    expect(row.searchTokens, contains('查询'));
    expect((await store.searchMessages(ownerUserId: cid, currentAccountId: account, keyword: '查询')).single.messageId, 'message');
    expect(wire.openmlsCiphertext, [1,2]);
  });
}
