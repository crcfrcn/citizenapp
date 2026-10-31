import 'package:citizen_citizen/proposal/proposal_query_service.dart';

import 'dart:convert';

import 'package:polkadart/polkadart.dart' show Hasher;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/proposal/internal_vote_service.dart';

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

/// 合成metadata只描述真实runtime事件字段；字节由依赖官方V14编码器生成。
/// 历史票据键不参与此事件的who；who始终是当前交易签名账户。
Uint8List voteMetadata() => base64Decode(
  'bWV0YQ48AAAABQMABAAABQUACAAABQYADAAABQAAEAAAAyAAAAAAABQAAAIAABgAAAEMOEFwcGx5RXh0cmluc2ljBAAEARhzaGFyZWQAAAAwRmluYWxpemF0aW9uAAEAOEluaXRpYWxpemF0aW9uAAIAABwAAAEEQEludGVybmFsVm90ZUNhc3QQASxwcm9wb3NhbF9pZAgAAAEMd2hvEAAAATx2b3Rlcl9yb2xlX2NvZGU0AAABHGFwcHJvdmUMAAAAAAAgAAABCDBJbnRlcm5hbFZvdGUEABwAABQAJEpvaW50Vm90ZQQAOAAAFQAAJAAAAhAAKAAAAAwBFHBoYXNlGAEYc2hhcmVkAAEUZXZlbnQgARhzaGFyZWQAARh0b3BpY3MkARhzaGFyZWQAACwAAAIoADAAAAQAADQAAAEIEE5vbmUAAAAQU29tZQQAFAAAAQAAOAAAAQR4Sm9pbnRJbnN0aXR1dGlvblRpY2tldFZvdGVDYXN0FAEscHJvcG9zYWxfaWQIAAABKGNpZF9udW1iZXIUAAABDHdobxAAAAE8dm90ZXJfcm9sZV9jb2RlFAAAARxhcHByb3ZlDAAAAAAABBhTeXN0ZW0BGFN5c3RlbQQYRXZlbnRzAQAsBAAAAAAAAAAwBAAw',
);
Uint8List voteEvents({
  bool joint = false,
  String? role = 'DIRECTOR',
  String cid = 'CID-A',
  int who = 1,
  int id = 7,
  int index = 2,
  int phase = 0,
  bool approve = true,
  bool twice = false,
}) {
  final row = <int>[
    phase,
    if (phase == 0) ...[index, 0, 0, 0],
    joint ? 21 : 20,
    0,
    id,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    if (joint) ...[utf8.encode(cid).length << 2, ...utf8.encode(cid)],
    ...List.filled(32, who),
    if (!joint) role == null ? 0 : 1,
    if (role != null) ...[utf8.encode(role).length << 2, ...utf8.encode(role)],
    approve ? 1 : 0,
    0,
  ];
  return Uint8List.fromList([twice ? 8 : 4, ...row, if (twice) ...row]);
}

class Chain extends TestChainReads {
  Uint8List? events;
  String? cid = 'CID-A';
  int heads = 0;
  CitizenBlockRef? contextBlock;
  final reads = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    throw StateError('不得重新选链头');
  }

  @override
  Future<Uint8List?> getSystemEvents(CitizenBlockRef ref) async {
    reads.add(ref);
    return events;
  }

  @override
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef ref) async =>
      CitizenRuntimeContext(
        block: contextBlock ?? ref,
        specVersion: 1,
        transactionVersion: 1,
        metadata: voteMetadata(),
      );
  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async {
    reads.add(ref);
    // 只交付真实提案元数据；若实现再用签名公钥查历史票据，此夹具立即失败。
    expect(key.sublist(0, 16), Hasher.twoxx128.hashString('VotingEngine'));
    expect(key.sublist(16, 32), Hasher.twoxx128.hashString('Proposals'));
    expect(key.sublist(key.length - 8), [7, 0, 0, 0, 0, 0, 0, 0]);
    return Uint8List.fromList([
      0,
      0,
      0,
      0,
      cid == null ? 0 : 1,
      if (cid != null) ...[utf8.encode(cid!).length << 2, ...utf8.encode(cid!)],
      0,
      0,
      ...List.filled(8, 0),
    ]);
  }
}

void main() {
  for (final cold in [false, true]) {
    for (final institutional in [false, true]) {
      test('换绑后当前签名人投票冷热签，不猜历史票据主键：$cold/$institutional', () async {
        final tx = flow(cold: cold),
            chain = Chain()
              ..events = voteEvents(role: institutional ? 'DIRECTOR' : null);
        final result =
            await InternalVoteService(
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getFinalizedHead: chain.getFinalizedHead,
                getStorage: chain.getStorage,
                getStorageBatch: chain.getStorageBatch,
              ),
              prepareTransaction: tx.prepareTransaction,
              executePreparedTransaction: tx.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  tx.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  tx.consumePreparedTransactionQrResponse,
            ).submit(
              proposalId: 7,
              approve: true,
              actorCidNumber: institutional ? 'CID-A' : null,
              voterRoleCode: institutional ? 'DIRECTOR' : null,
              signerPublicKey: signer,
              externalSigning: (_) async => 'synthetic-response',
            );
        expect(result.blockHash, block.hash);
        expect(result.usedNonce, 3);
        expect(chain.heads, 0);
        expect(chain.reads.length, institutional ? 2 : 1);
        expect(chain.reads.every((ref) => identical(ref, block)), true);
        expect(tx.consumeCount, cold ? 1 : 0);
        expect(tx.callData!.last, 1);
        expect(tx.callData![10], institutional ? 1 : 0);
      });
    }
    for (final fields in [
      (null, 'DIRECTOR'),
      ('CID-A', null),
      ('', 'DIRECTOR'),
      ('CID-A', ''),
      ('CID-A', 'x' * 65),
    ]) {
      test('机构参数$fields在SDK准备前失败', () async {
        final tx = flow();
        await expectLater(
          (() {
            final reads0 = Chain();
            return InternalVoteService(
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: reads0.getSystemEvents,
                getRuntimeContext: reads0.getRuntimeContext,
                getFinalizedHead: reads0.getFinalizedHead,
                getStorage: reads0.getStorage,
                getStorageBatch: reads0.getStorageBatch,
              ),
              prepareTransaction: tx.prepareTransaction,
              executePreparedTransaction: tx.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  tx.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  tx.consumePreparedTransactionQrResponse,
            );
          })().submit(
            proposalId: 7,
            approve: true,
            actorCidNumber: fields.$1,
            voterRoleCode: fields.$2,
            signerPublicKey: signer,
            externalSigning: (_) async => null,
          ),
          throwsArgumentError,
        );
        expect(tx.prepareCount, 0);
      });
    }
    for (final bad in [
      'missing',
      'direction',
      'signer',
      'proposal',
      'role',
      'index',
      'phase',
      'twice',
      'cid',
      'context',
    ]) {
      test('内部投票事件或提案$bad不匹配不能成功：$cold', () async {
        final chain = Chain()
          ..events = bad == 'missing'
              ? Uint8List.fromList([0])
              : voteEvents(
                  approve: bad != 'direction',
                  who: bad == 'signer' ? 2 : 1,
                  id: bad == 'proposal' ? 8 : 7,
                  role: bad == 'role' ? 'OTHER' : 'DIRECTOR',
                  index: bad == 'index' ? 3 : 2,
                  phase: bad == 'phase' ? 1 : 0,
                  twice: bad == 'twice',
                );
        if (bad == 'cid') chain.cid = 'CID-B';
        if (bad == 'context') {
          chain.contextBlock = CitizenBlockRef(
            hash: 'other',
            number: BigInt.one,
            finality: CitizenBlockFinality.finalized,
          );
        }
        await expectLater(
          (() {
            final reads0 = flow(cold: cold);
            return InternalVoteService(
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getFinalizedHead: chain.getFinalizedHead,
                getStorage: chain.getStorage,
                getStorageBatch: chain.getStorageBatch,
              ),
              prepareTransaction: reads0.prepareTransaction,
              executePreparedTransaction: reads0.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  reads0.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  reads0.consumePreparedTransactionQrResponse,
            );
          })().submit(
            proposalId: 7,
            actorCidNumber: 'CID-A',
            voterRoleCode: 'DIRECTOR',
            approve: true,
            signerPublicKey: signer,
            externalSigning: (_) async => 'synthetic-response',
          ),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
      });
    }
    for (final cancel in [true, false]) {
      test('冷签取消或回调异常取消pending且不重播：$cancel', () async {
        final tx = flow(cold: true);
        await expectLater(
          (() {
            final reads0 = Chain();
            return InternalVoteService(
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: reads0.getSystemEvents,
                getRuntimeContext: reads0.getRuntimeContext,
                getFinalizedHead: reads0.getFinalizedHead,
                getStorage: reads0.getStorage,
                getStorageBatch: reads0.getStorageBatch,
              ),
              prepareTransaction: tx.prepareTransaction,
              executePreparedTransaction: tx.executePreparedTransaction,
              cancelPreparedTransactionExecution:
                  tx.cancelPreparedTransactionExecution,
              consumePreparedTransactionQrResponse:
                  tx.consumePreparedTransactionQrResponse,
            );
          })().submit(
            proposalId: 7,
            approve: false,
            signerPublicKey: signer,
            externalSigning: (_) async {
              if (cancel) return null;
              throw StateError('合成回调失败');
            },
          ),
          throwsStateError,
        );
        expect(tx.cancelCount, 1);
        expect(tx.consumeCount, 0);
        expect(tx.executeCount, 1);
      });
    }
  }
  for (final resolution in CitizenTransactionResolution.values.where(
    (x) => x != CitizenTransactionResolution.finalizedSuccess,
  )) {
    test('执行非成功终态不查询业务记录：$resolution', () async {
      final chain = Chain();
      await expectLater(
        (() {
          final reads0 = flow(result: completed(resolution: resolution));
          return InternalVoteService(
            queryFactory: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              getFinalizedHead: chain.getFinalizedHead,
              getStorage: chain.getStorage,
              getStorageBatch: chain.getStorageBatch,
            ),
            prepareTransaction: reads0.prepareTransaction,
            executePreparedTransaction: reads0.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                reads0.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                reads0.consumePreparedTransactionQrResponse,
          );
        })().submit(
          proposalId: 7,
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        ),
        throwsStateError,
      );
      expect(chain.reads, isEmpty);
    });
  }
  test('准备与未知执行异常原样传播，禁止重签或自动取消广播', () async {
    for (final stage in ['prepare', 'execute']) {
      final failure = StateError('合成未知结果'), tx = flow();
      if (stage == 'prepare') {
        tx.prepare = (_, _) async => throw failure;
      } else {
        tx.execute = (_) async => throw failure;
      }
      await expectLater(
        (() {
          final reads0 = Chain();
          return InternalVoteService(
            queryFactory: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: reads0.getSystemEvents,
              getRuntimeContext: reads0.getRuntimeContext,
              getFinalizedHead: reads0.getFinalizedHead,
              getStorage: reads0.getStorage,
              getStorageBatch: reads0.getStorageBatch,
            ),
            prepareTransaction: tx.prepareTransaction,
            executePreparedTransaction: tx.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                tx.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                tx.consumePreparedTransactionQrResponse,
          );
        })().submit(
          proposalId: 7,
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        ),
        throwsA(same(failure)),
      );
      expect(tx.prepareCount, 1);
      expect(tx.executeCount, stage == 'prepare' ? 0 : 1);
      expect(tx.cancelCount, 0);
    }
  });
}
