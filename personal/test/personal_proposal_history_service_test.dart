// 验证个人多签历史的本地更新、状态和快照，以及链读取失败路径。

import 'dart:typed_data';
import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_personal/personal_proposal_history_service.dart';
import 'package:citizen_personal/personal_local_store.dart';
import 'package:citizen_storage/user_isar.dart' as store;

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

/// 离线链读取函数：本单测只验证 Isar 持久层，注入它切断真链依赖。
/// 可达探针为 false(等价「链不可达 → 仅返回本机 Isar」)。避免本机是否连着真链
/// 造成 flaky;配合服务端「链不可达不删幽灵」的容错回退,写入的历史必被完整读回。
class _OfflineChain extends TestChainReads {
  @override
  Future<CitizenChainSyncStatus> getSyncStatus() async {
    final finalized = CitizenBlockRef(
      hash: '0x${'00' * 32}',
      number: BigInt.zero,
      finality: CitizenBlockFinality.finalized,
    );
    return CitizenChainSyncStatus(
      peerCount: BigInt.zero,
      isSyncing: false,
      isUsable: false,
      best: finalized,
      finalized: finalized,
    );
  }
}

PersonalProposalHistoryService _service() {
  final chain = _OfflineChain();
  return PersonalProposalHistoryService(
    getSyncStatus: chain.getSyncStatus,
    getFinalizedHead: chain.getFinalizedHead,
    getStorage: chain.getStorage,
    proposalService: ProposalQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
      getRuntimeContext: chain.getRuntimeContext,
      getSystemEvents: chain.getSystemEvents,
    ),
    getSystemEvents: chain.getSystemEvents,
    getRuntimeContext: chain.getRuntimeContext,
    getStorageBatch: chain.getStorageBatch,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('多签名称只按指定账户从本地批量读取，完整名称不被截断', () async {
    final id = '0x${'11' * 32}';
    final missing = '0x${'22' * 32}';
    await store.UserIsar.instance.writeTxn((isar) async {
      await isar.accounts.put(
        store.Account()
          ..accountId = id
          ..accountName = '家庭基金账户甲乙'
          ..creatorAccount = id
          ..addedAt = 1,
      );
    });
    expect(await readMultisigNames([id, id, missing]), {id: '家庭基金账户甲乙'});
    expect(await readMultisigNames([]), isEmpty);
    await expectLater(readMultisigNames(['invalid']), throwsFormatException);
  });

  const personalAccount =
      'aabbccddeeff00112233445566778899'
      '00112233445566778899aabbccddeeff';

  List<int> compactU32(int value) {
    if (value < 64) return [value << 2];
    final encoded = (value << 2) | 1;
    return [encoded & 0xff, encoded >> 8];
  }

  test('ProposalData 只识别当前 per-mgmt / multisig 标签并拒绝尾随字节', () {
    final service = _service();
    Uint8List wrap(List<int> body) =>
        Uint8List.fromList([...compactU32(body.length), ...body]);

    expect(
      service.debugDecodeActionFromProposalData(
        wrap([...utf8.encode('per-mgmt'), 0, ...List.filled(32, 1)]),
      ),
      PersonalProposalAction.create,
    );
    expect(
      service.debugDecodeActionFromProposalData(
        wrap([...utf8.encode('per-mgmt'), 1, ...List.filled(32, 1)]),
      ),
      PersonalProposalAction.close,
    );
    expect(
      service.debugDecodeActionFromProposalData(
        wrap([
          ...utf8.encode('multisig'),
          0, // actor_cid_number: None（个人多签）
          ...List.filled(32, 1), // funding_account_id
          ...List.filled(32, 2), // beneficiary
          ...List.filled(16, 0), // amount
          0, // empty remark
          ...List.filled(32, 3), // proposer
        ]),
      ),
      PersonalProposalAction.transfer,
    );
    expect(
      service.debugDecodeActionFromProposalData(
        wrap([...utf8.encode('multisig-transfer'), 0]),
      ),
      isNull,
    );

    final current = wrap([...utf8.encode('multisig'), 0]);
    expect(
      service.debugDecodeActionFromProposalData(
        Uint8List.fromList([...current, 0]),
      ),
      isNull,
    );
  });

  test('recordOrUpdate inserts new entity then readAllFromIsar 返回单条', () async {
    final service = _service();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(42),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 1,
      noCount: 0,
      snapshot: {'name': 'TestPersonal', 'amount_fen': '1000'},
    );

    final list = await service.fetchAll(personalAccount);
    expect(list.length, 1);
    expect(list[0].proposalId, BigInt.from(42));
    expect(list[0].actionKind, PersonalProposalAction.create);
    expect(list[0].proposalState, PersonalProposalStatus.voting);
    expect(list[0].yesCount, 1);
    expect(list[0].noCount, 0);
    expect(list[0].isActive, isTrue);
    expect(list[0].finalAt, isNull);
    expect(list[0].snapshot?['name'], 'TestPersonal');
    expect(list[0].snapshot?['amount_fen'], '1000');
  });

  test('recordOrUpdate 同 proposalId upsert,createdAt 保留首次值,'
      'snapshot 沿用旧值若新调用未传', () async {
    final service = _service();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(7),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
      snapshot: {'name': 'X'},
    );
    final firstList = await service.fetchAll(personalAccount);
    final firstCreatedAt = firstList[0].createdAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));

    // 二次写入只更新投票计数和状态,不传 snapshot
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(7),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.executed,
      yesCount: 3,
      noCount: 0,
    );
    final list = await service.fetchAll(personalAccount);
    expect(list.length, 1);
    expect(list[0].proposalState, PersonalProposalStatus.executed);
    expect(list[0].yesCount, 3);
    expect(list[0].finalAt, isNotNull);
    expect(
      list[0].createdAt,
      firstCreatedAt,
      reason: '二次 upsert 必须保留首次 createdAt',
    );
    expect(list[0].snapshot?['name'], 'X', reason: 'snapshot 旧值应保留');
  });

  test('voting → executed 转换会写入 finalStatusAtMillis', () async {
    final service = _service();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(1),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );
    var list = await service.fetchAll(personalAccount);
    expect(list[0].finalAt, isNull);
    expect(list[0].isFinal, isFalse);

    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(1),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.rejected,
      yesCount: 0,
      noCount: 3,
    );
    list = await service.fetchAll(personalAccount);
    expect(list[0].finalAt, isNotNull);
    expect(list[0].isFinal, isTrue);
  });

  test('多个 proposal 按 createdAt desc 排序', () async {
    final service = _service();
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(100),
      actionKind: PersonalProposalAction.create,
      status: PersonalProposalStatus.voting,
      yesCount: 0,
      noCount: 0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(101),
      actionKind: PersonalProposalAction.transfer,
      status: PersonalProposalStatus.voting,
      yesCount: 1,
      noCount: 0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.recordOrUpdate(
      accountId: personalAccount,
      proposalId: BigInt.from(102),
      actionKind: PersonalProposalAction.close,
      status: PersonalProposalStatus.executed,
      yesCount: 3,
      noCount: 0,
    );

    final list = await service.fetchAll(personalAccount);
    expect(list.map((v) => v.proposalId).toList(), [102, 101, 100].map(BigInt.from).toList());
  });

  test('mapChainStatus 链上 u8 → 字符串映射穷尽', () {
    expect(mapChainStatus(0), PersonalProposalStatus.voting);
    expect(mapChainStatus(1), PersonalProposalStatus.passed);
    expect(mapChainStatus(2), PersonalProposalStatus.rejected);
    expect(mapChainStatus(3), PersonalProposalStatus.executed);
    expect(mapChainStatus(4), PersonalProposalStatus.executionFailed);
    expect(mapChainStatus(null), PersonalProposalStatus.voting);
    expect(mapChainStatus(99), PersonalProposalStatus.voting);
  });
}
