import 'package:flutter/material.dart';
// 个人多签proposals功能回归，保留迁入用例和断言。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_personal/accounts.dart';
import 'package:citizen_personal/chain.dart';
import 'package:citizen_personal/proposals.dart';
import 'package:citizen_personal/storage.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_multisig/multisig_transfer_models.dart';
import 'package:citizen_storage/user_isar.dart' as store;
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';

// 原用例所属：personal/test/personal_proposal_history_service_test.dart
// 验证个人多签历史的本地更新、状态和快照，以及链读取失败路径。

/// 离线链读取函数：本单测只验证 Isar 持久层，注入它切断真链依赖。
/// 可达探针为 false(等价「链不可达 → 仅返回本机 Isar」)。避免本机是否连着真链
/// 造成 flaky;配合服务端「链不可达不删幽灵」的容错回退,写入的历史必被完整读回。
class PersonalproposalhistoryserviceOfflineChain extends TestChainReads {
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

PersonalProposalHistoryService _personalproposalhistoryserviceservice() {
  final chain = PersonalproposalhistoryserviceOfflineChain();
  return PersonalProposalHistoryService(
    getSyncStatus: chain.getSyncStatus,
    getFinalizedHead: chain.getFinalizedHead,
    getStorage: chain.getStorage,
    proposalService: PersonalProposalQueryService(
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

void _registerPersonalproposalhistoryservice() {
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
    final service = _personalproposalhistoryserviceservice();
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
    final service = _personalproposalhistoryserviceservice();
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
    final service = _personalproposalhistoryserviceservice();
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
    final service = _personalproposalhistoryserviceservice();
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
    final service = _personalproposalhistoryserviceservice();
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
    expect(
      list.map((v) => v.proposalId).toList(),
      [102, 101, 100].map(BigInt.from).toList(),
    );
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

void main() {
  group(
    'personal_proposal_history_service_test',
    _registerPersonalproposalhistoryservice,
  );
  group('个人提案上下文', _registerPersonalContexts);
  group('个人展示和上下文原回归', _registerMovedPersonalViews);
}

void _registerPersonalContexts() {
  test('个人转账只接收当前资金账户，机构主体或另一账户不能混入', () {
    final id = '0x${'11' * 32}';
    final account = PersonalAccountInfo(
      fullName: '个人',
      shortName: '个人',
      accountId: id,
    );
    TransferProposalInfo transfer(String? cid, String funding) =>
        TransferProposalInfo(
          proposalId: BigInt.one,
          actorCidNumber: cid,
          fundingAccountId: citizenAccountIdBytes(funding),
          beneficiary: '收款人',
          amountFen: BigInt.one,
          remark: '',
          proposer: '发起人',
        );
    expect(
      () => PersonalProposalContextResolver.ensureTransferAccount(
        transfer(null, id),
        account,
      ),
      returnsNormally,
    );
    expect(
      () => PersonalProposalContextResolver.ensureTransferAccount(
        transfer('TEST-INSTITUTION', id),
        account,
      ),
      throwsStateError,
    );
    expect(
      () => PersonalProposalContextResolver.ensureTransferAccount(
        transfer(null, '0x${'22' * 32}'),
        account,
      ),
      throwsStateError,
    );
  });
  test('个人提案只接受规范钱包账户', () async {
    var reads = 0;
    final resolver = PersonalProposalContextResolver(
      getWalletState: () => testCitizenOperation(testCitizenWalletState),
      readNames: (_) async {
        reads++;
        return {};
      },
    );
    final invalid = await resolver.resolve(accountId: 'invalid-account');
    expect(invalid.account, isNull);
    expect(
      (await resolver.resolve(accountId: '0X${'01' * 32}')).account,
      isNull,
    );
    expect(reads, 0);
  });
  test('已知个人账户保持原始ID和名称且不重复查名称', () async {
    final id = '0x${'11' * 32}';
    final account = PersonalAccountInfo(
      fullName: '原名称',
      shortName: '原名称',
      accountId: id,
    );
    final resolver = PersonalProposalContextResolver(
      getWalletState: () => testCitizenOperation(testCitizenWalletState),
      readNames: (_) async => throw StateError('不应读取'),
    );
    final value = await resolver.resolve(accountId: id, knownAccount: account);
    expect(value.account, same(account));
    expect(value.isAdmin, isFalse);
  });
  test('名称只作展示，名称读取失败仍保留真实执行账户', () async {
    final value = await PersonalProposalContextResolver(
      getWalletState: () => testCitizenOperation(testCitizenWalletState),
      readNames: (_) async => throw StateError('离线'),
    ).resolve(accountId: '0x${'22' * 32}');
    expect(value.account!.accountId, '0x${'22' * 32}');
    expect(value.isAdmin, isFalse);
  });
}

void _registerMovedPersonalViews() {
  for (final names in <(String, String)>[
    ('家庭基金', '家庭基金'),
    ('家庭基金账户甲乙', '家庭基金账户'),
    ('👨‍👩‍👧‍👦家庭基金账户甲', '👨‍👩‍👧‍👦家庭基金账'),
    ('e\u0301家庭基金账户甲', 'e\u0301家庭基金账'),
  ]) {
    testWidgets('个人多签统一首行保留前6个可见字符：${names.$1}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: Row(
                children: [
                  Expanded(
                    child: PersonalProposalHeader(
                      subjectName: names.$1,
                      proposalNumber: '#123',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('投票中'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text(names.$2), findsOneWidget);
      final nameElement = tester.element(find.text(names.$2));
      final nameText = tester.widget<Text>(find.text(names.$2));
      final painter = TextPainter(
        text: TextSpan(
          text: names.$2,
          style: DefaultTextStyle.of(nameElement).style.merge(nameText.style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(nameElement),
      )..layout();
      // 按真实字号测量，避免布局缩放导致固定像素断言误判；展示的六字不得被裁短。
      expect(
        tester.getSize(find.text(names.$2)).width + 0.1,
        greaterThanOrEqualTo(painter.width),
      );
      painter.dispose();
      expect(find.textContaining('...'), findsNothing);
      expect(
        tester.getRect(find.text(names.$2)).right,
        lessThan(tester.getRect(find.text('#123')).left),
      );
      expect(
        tester.getRect(find.text('#123')).right,
        lessThan(tester.getRect(find.text('投票中')).left),
      );
      expect(tester.takeException(), isNull);
    });
  }
  test('个人多签上下文按规范钱包去重批量取真实名称', () async {
    final requested = <List<String>>[];
    final id = '0x${'12' * 32}';
    var failNames = false;
    final resolver = PersonalProposalContextResolver(
      getWalletState: () => testCitizenOperation(testCitizenWalletState),
      readNames: (ids) async {
        requested.add(ids.toList());
        if (failNames) throw StateError('synthetic name read failure');
        return {id: '家庭基金账户甲乙'};
      },
    );
    final contexts = await resolver.resolveBatch([id, id, 'invalid-account']);
    expect(requested, [
      [id],
    ]);
    expect(contexts[0].account!.shortName, '家庭基金账户甲乙');
    expect(contexts[1].account!.accountId, id);
    expect(contexts[2].account, isNull);
    await resolver.resolveBatch(['invalid-account']);
    expect(requested, hasLength(1));
    failNames = true;
    final unnamed = await resolver.resolveBatch([id]);
    expect(unnamed.single.account!.shortName, isEmpty);
    expect(unnamed.single.account!.accountId, id);
  });
}
