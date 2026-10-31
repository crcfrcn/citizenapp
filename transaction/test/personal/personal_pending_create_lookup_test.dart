// 个人多签待激活创建提案反查单元测试。
//
// 验证:
// - Isar 无 entity → null
// - 仅有非 voting 状态 entity → null(只匹配 voting + create 双条件)
// - 有 voting 状态 entity → 返回其 proposal_id
// - 同地址多 entity 时按状态过滤选 create+voting

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_transaction/personal/personal_pending_create_lookup.dart';
import 'package:citizen_transaction/personal/personal_proposal_history_service.dart';

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  const personalAccount =
      '0x11223344556677889900aabbccddeeff'
      'ffeeddccbbaa00998877665544332211';

  test('无 entity → 返回 null', () async {
    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('仅有 executed/rejected entity → 不命中,返回 null', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: 5,
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.executed,
      yesCount: 3,
      noCount: 0,
    );
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: 6,
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.rejected,
      yesCount: 0,
      noCount: 3,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('voting 状态的 create entity 命中,返回 proposalId', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: 99,
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 1,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), 99);
  });

  test('voting 但 action != create(如 transfer)不命中', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: 200,
      actionKind: PersonalProposalAction.transfer,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
  });

  test('其他多签账户的 entity 不命中(filter 按地址过滤)', () async {
    final service = (() {
      final reads0 = TestChainReads();
      return PersonalProposalHistoryService(
        getSyncStatus: reads0.getSyncStatus,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorage: reads0.getStorage,
        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        getStorageBatch: reads0.getStorageBatch,
      );
    })();
    const otherAccountId =
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
    await service.recordOrUpdate(
      accountId: otherAccountId,
      proposalId: 77,
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );

    final lookup = PersonalPendingCreateLookup();
    expect(await lookup.findActiveCreate(personalAccount), isNull);
    expect(await lookup.findActiveCreate(otherAccountId), 77);
  });
}
