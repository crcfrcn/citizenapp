import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'proposal/internal_vote_service_test.dart' show voteMetadata, voteEvents;

final signer = Uint8List.fromList(List.filled(32, 1));
final block = CitizenBlockRef(
  hash: '0x${'ab' * 32}',
  number: BigInt.from(50),
  finality: CitizenBlockFinality.finalized,
);
CitizenPreparedTransaction prepared() => CitizenPreparedTransaction(
  preparationId: 'prepared',
  sourceAccountId: signer,
  callDataHash: Uint8List(32),
  bestBlock: block,
  runtimeSpecNumber: 1,
  transactionFormatNumber: 1,
  nonce: BigInt.from(3),
);
CitizenTransactionExecutionCompleted completed({
  CitizenTransactionResolution resolution =
      CitizenTransactionResolution.finalizedSuccess,
  CitizenExecution? execution,
  bool missing = false,
}) => CitizenTransactionExecutionCompleted(
  executionId: 'execution',
  sourceAccountId: signer,
  callDataHash: Uint8List(32),
  transactionHash: Uint8List(32),
  resolution: resolution,
  execution: missing
      ? null
      : execution ??
            CitizenExecution(
              status: CitizenExecutionStatus.success,
              block: block,
              extrinsicIndex: 2,
              dispatchVariant: null,
              palletIndex: null,
              errorIndex: null,
            ),
  poolRejectionReason: null,
  replacementHash: null,
);
CitizenTransactionExternalSigningPending pending() =>
    CitizenTransactionExternalSigningPending(
      executionId: 'execution',
      sourceAccountId: signer,
      callDataHash: Uint8List(32),
      qrRequest: 'synthetic-qr',
      expiresAt: DateTime.utc(2027),
    );
TestCitizenTransactionFlow flow({
  bool cold = false,
  CitizenTransactionExecutionCompleted? result,
}) => TestCitizenTransactionFlow()
  ..prepare = ((_, _) async => prepared())
  ..execute = ((_) async => cold ? pending() : result ?? completed())
  ..consume = ((_, _) async => result ?? completed())
  ..cancel = ((_) async {});

class VoteChain extends TestCitizenChain {
  int heads = 0;
  Uint8List? events = voteEvents(joint: true);
  final reads = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    throw StateError('不得重新选链头');
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async =>
      throw StateError('不能用当前签名人猜历史票据键');
  @override
  Future<Uint8List?> getSystemEvents(CitizenBlockRef ref) async {
    reads.add(ref);
    return events;
  }

  @override
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef ref) async =>
      CitizenRuntimeContext(
        block: ref,
        specVersion: 1,
        transactionVersion: 1,
        metadata: voteMetadata(),
      );
}

void main() {
  Uint8List compactLength(int length) {
    if (length < 64) {
      return Uint8List.fromList([length << 2]);
    }
    if (length < 16384) {
      final encoded = (length << 2) | 0x01;
      return Uint8List.fromList([encoded & 0xff, (encoded >> 8) & 0xff]);
    }
    throw ArgumentError('测试辅助函数只覆盖 16KB 以下 Vec');
  }

  Uint8List compactBytes(Uint8List value) {
    return Uint8List.fromList([...compactLength(value.length), ...value]);
  }

  Uint8List storageValue(Uint8List proposalData) {
    return compactBytes(proposalData);
  }

  List<int> u32le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  List<int> u64le(int value) => [...u32le(value), ...u32le(value >> 32)];

  List<int> powParams() => [
    ...u32le(1),
    1,
    0,
    ...u64le(360000),
    ...u32le(600),
    ...u64le(4),
    ...u64le(4),
  ];

  for (final cold in [true, false]) {
    test('联合投票冷热签确认绑定执行块，不重新选链头：$cold', () async {
      final tx = flow(cold: cold), chain = VoteChain();
      final result = await RuntimeUpgradeService(chain: chain, transactions: tx)
          .submitJointVote(
            proposalId: 7,
            actorCidNumber: 'CID-A',
            voterRoleCode: 'DIRECTOR',
            approve: true,
            signerPublicKey: signer,
            externalSigning: (_) async => 'synthetic-response',
          );
      expect(result.blockHash, block.hash);
      expect(chain.heads, 0);
      expect(chain.reads.single, same(block));
    });
  }
  for (final bad in [
    'missing',
    'direction',
    'signer',
    'proposal',
    'role',
    'cid',
    'index',
    'phase',
    'twice',
  ]) {
    test('联合投票事件$bad不符不得成功', () async {
      final chain = VoteChain()
        ..events = bad == 'missing'
            ? Uint8List.fromList([0])
            : voteEvents(
                joint: true,
                approve: bad != 'direction',
                who: bad == 'signer' ? 2 : 1,
                id: bad == 'proposal' ? 8 : 7,
                role: bad == 'role' ? 'OTHER' : 'DIRECTOR',
                cid: bad == 'cid' ? 'CID-B' : 'CID-A',
                index: bad == 'index' ? 3 : 2,
                phase: bad == 'phase' ? 1 : 0,
                twice: bad == 'twice',
              );
      await expectLater(
        RuntimeUpgradeService(
          chain: chain,
          transactions: flow(),
        ).submitJointVote(
          proposalId: 7,
          actorCidNumber: 'CID-A',
          voterRoleCode: 'DIRECTOR',
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        ),
        throwsStateError,
      );
    });
  }
  test('联合投票取消、未知广播结果及参数失败不重签', () async {
    for (final fail in ['cancel', 'execute', 'role']) {
      final tx = flow(cold: fail == 'cancel');
      if (fail == 'execute') {
        tx.execute = (_) async => throw StateError('合成未知结果');
      }
      await expectLater(
        RuntimeUpgradeService(
          chain: VoteChain(),
          transactions: tx,
        ).submitJointVote(
          proposalId: 7,
          actorCidNumber: 'CID-A',
          voterRoleCode: fail == 'role' ? '' : 'DIRECTOR',
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        ),
        throwsA(anything),
      );
      expect(tx.prepareCount, fail == 'role' ? 0 : 1);
      expect(tx.cancelCount, fail == 'cancel' ? 1 : 0);
    }
  });
  group('RuntimeUpgradeService 协议升级详情解码', () {
    test('解码带 rt-upg 前缀的协议升级提案摘要', () {
      final service = RuntimeUpgradeService(
        chain: TestCitizenChain(),
        transactions: TestCitizenTransactions(),
      );
      final actorCid = Uint8List.fromList(
        utf8.encode('ZS001-NRC0G-944805165-2026'),
      );
      final proposer = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final reason = Uint8List.fromList(utf8.encode('升级协议参数'));
      final codeHash = Uint8List.fromList(List<int>.filled(32, 0xab));
      final paramsHash = Uint8List.fromList(List<int>.filled(32, 0xcd));
      final proposalData = Uint8List.fromList([
        ...utf8.encode('rt-upg'),
        ...compactBytes(actorCid),
        ...proposer,
        ...compactBytes(reason),
        ...codeHash,
        ...paramsHash,
        ...powParams(),
      ]);

      final decoded = service.decodeRuntimeUpgradeStorageValue(
        7,
        storageValue(proposalData),
      );

      expect(decoded, isNotNull);
      expect(decoded!.proposalId, 7);
      expect(decoded.actorCidNumber, 'ZS001-NRC0G-944805165-2026');
      expect(decoded.reason, '升级协议参数');
      expect(decoded.codeHashHex, List.filled(32, 'ab').join());
      expect(decoded.paramsVersion, 1);
      expect(decoded.targetBlockTimeMs, 360000);
      expect(decoded.adjustmentInterval, 600);
    });

    test('非 rt-upg 提案摘要不按协议升级解码', () {
      final service = RuntimeUpgradeService(
        chain: TestCitizenChain(),
        transactions: TestCitizenTransactions(),
      );
      final proposer = Uint8List.fromList(List<int>.filled(32, 1));
      final actorCid = Uint8List.fromList(
        utf8.encode('ZS001-NRC0G-944805165-2026'),
      );
      final reason = Uint8List.fromList(utf8.encode('其他提案'));
      final codeHash = Uint8List.fromList(List<int>.filled(32, 0xcd));
      final proposalData = Uint8List.fromList([
        ...utf8.encode('other'),
        ...compactBytes(actorCid),
        ...proposer,
        ...compactBytes(reason),
        ...codeHash,
        ...Uint8List.fromList(List<int>.filled(32, 0xcd)),
        ...powParams(),
      ]);

      final decoded = service.decodeRuntimeUpgradeStorageValue(
        8,
        storageValue(proposalData),
      );

      expect(decoded, isNull);
    });

    test('带旧业务状态字段的协议升级摘要不再兼容', () {
      final service = RuntimeUpgradeService(
        chain: TestCitizenChain(),
        transactions: TestCitizenTransactions(),
      );
      final proposer = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final actorCid = Uint8List.fromList(
        utf8.encode('ZS001-NRC0G-944805165-2026'),
      );
      final reason = Uint8List.fromList(utf8.encode('旧摘要'));
      final codeHash = Uint8List.fromList(List<int>.filled(32, 0xef));
      final proposalData = Uint8List.fromList([
        ...utf8.encode('rt-upg'),
        ...compactBytes(actorCid),
        ...proposer,
        ...compactBytes(reason),
        ...codeHash,
        ...Uint8List.fromList(List<int>.filled(32, 0xcd)),
        ...powParams(),
        0,
      ]);

      final decoded = service.decodeRuntimeUpgradeStorageValue(
        9,
        storageValue(proposalData),
      );

      expect(decoded, isNull);
    });
  });
}
