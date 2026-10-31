import 'package:citizen_citizen/legislation/legislation_vote_query_service.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';

import 'dart:typed_data';
import 'dart:convert';

import 'package:polkadart/polkadart.dart' show Hasher;

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/legislation/legislation_vote_service.dart';

import '../proposal/proposal_query_service_test.dart'
    show eventMetadata, eventBytes;

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

class Chain extends TestChainReads {
  Uint8List? storage;
  Uint8List? route;
  Uint8List? events;
  int heads = 0;
  final reads = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    return block;
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async {
    reads.add(ref);
    if (route != null &&
        key.sublist(16, 32).toString() ==
            Hasher.twoxx128.hashString('RepresentativeMetas').toString()) {
      return route;
    }
    return storage;
  }

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
        metadata: eventMetadata(),
      );
}

Future<Object> submit(
  LegislationVoteService service,
  int event,
  bool approve,
) => event == 6
    ? service.executiveSign(
        proposalId: 7,
        approve: approve,
        signerPublicKey: signer,
        externalSigning: (_) async => 'synthetic-response',
      )
    : event == 8
    ? service.overrideSign(
        proposalId: 7,
        approve: approve,
        signerPublicKey: signer,
        externalSigning: (_) async => 'synthetic-response',
      )
    : service.guardVote(
        proposalId: 7,
        approve: approve,
        signerPublicKey: signer,
        externalSigning: (_) async => 'synthetic-response',
      );
void main() {
  test('代表机构投票按当前CID/岗位、同执行块票据及事件确认', () async {
    final chain = Chain()
      ..route = Uint8List.fromList([
        0,
        20,
        ...utf8.encode('CID-A'),
        32,
        ...utf8.encode('DIRECTOR'),
        0,
        0,
        0,
        0,
        0,
        0,
      ])
      ..storage = Uint8List.fromList([0])
      ..events = eventBytes(event: 1, approve: false);
    final tx = flow(cold: true),
        service = LegislationVoteService(
          eventQuery: (block) => ProposalQueryService(
            block: block,
            getSystemEvents: chain.getSystemEvents,
            getRuntimeContext: chain.getRuntimeContext,
            getFinalizedHead: chain.getFinalizedHead,
            getStorage: chain.getStorage,
            getStorageBatch: chain.getStorageBatch,
          ),
          voteQuery: (block) => LegislationVoteQueryService(
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
        );
    final result = await service.castRepresentativeVote(
      proposalId: 7,
      voterRoleCode: 'DIRECTOR',
      approve: false,
      signerPublicKey: signer,
      externalSigning: (_) async => 'synthetic-response',
    );
    expect(result.blockHash, block.hash);
    expect(chain.heads, 1);
    expect(chain.reads.every((ref) => identical(ref, block)), true);
    await expectLater(
      service.castRepresentativeVote(
        proposalId: 7,
        voterRoleCode: 'OTHER',
        approve: false,
        signerPublicKey: signer,
        externalSigning: (_) async => null,
      ),
      throwsArgumentError,
    );
    expect(tx.prepareCount, 1);
  });
  test('代表事件错误body/岗位以及重复签署事件不得通过', () async {
    for (final mode in ['body', 'role', 'duplicate']) {
      final bytes = eventBytes(
        event: 1,
        body: mode == 'body' ? 1 : 0,
        role: mode == 'role' ? 'OTHER' : 'DIRECTOR',
      );
      final chain = Chain()
        ..route = Uint8List.fromList([
          0,
          20,
          ...utf8.encode('CID-A'),
          32,
          ...utf8.encode('DIRECTOR'),
          0,
          0,
          0,
          0,
          0,
          0,
        ])
        ..events = mode == 'duplicate'
            ? Uint8List.fromList([8, ...bytes.skip(1), ...bytes.skip(1)])
            : bytes;
      await expectLater(
        (() {
          final reads0 = flow();
          return LegislationVoteService(
            eventQuery: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              getFinalizedHead: chain.getFinalizedHead,
              getStorage: chain.getStorage,
              getStorageBatch: chain.getStorageBatch,
            ),
            voteQuery: (block) => LegislationVoteQueryService(
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
        })().castRepresentativeVote(
          proposalId: 7,
          voterRoleCode: 'DIRECTOR',
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async => null,
        ),
        throwsStateError,
      );
    }
  });

  for (final event in [6, 8, 10]) {
    for (final approve in [true, false]) {
      for (final cold in [true, false]) {
        test('行政/会签/终审冷热签，终态清账仍核对事件：$event/$approve/$cold', () async {
          final chain = Chain()
                ..events = eventBytes(event: event, approve: approve),
              tx = flow(cold: cold);
          await submit(
            LegislationVoteService(
              eventQuery: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getFinalizedHead: chain.getFinalizedHead,
                getStorage: chain.getStorage,
                getStorageBatch: chain.getStorageBatch,
              ),
              voteQuery: (block) => LegislationVoteQueryService(
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
            ),
            event,
            approve,
          );
          expect(chain.heads, 0);
          expect(chain.reads.every((r) => identical(r, block)), true);
          expect(tx.consumeCount, cold ? 1 : 0);
        });
      }
    }
  }
  for (final bad in [
    'direction',
    'signer',
    'proposal',
    'index',
    'phase',
    'missing',
    'record',
  ]) {
    test('事件或账本$bad不符不得报签署成功', () async {
      final chain = Chain()
        ..events = bad == 'missing'
            ? Uint8List.fromList([0])
            : eventBytes(
                approve: bad != 'direction',
                who: bad == 'signer' ? 2 : 1,
                id: bad == 'proposal' ? 8 : 7,
                index: bad == 'index' ? 3 : 2,
                phase: bad == 'phase' ? 1 : 0,
              );
      if (bad == 'record') {
        chain.storage = Uint8List.fromList([4, ...signer, 0]);
      }
      await expectLater(
        submit(
          (() {
            final reads0 = flow();
            return LegislationVoteService(
              eventQuery: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getFinalizedHead: chain.getFinalizedHead,
                getStorage: chain.getStorage,
                getStorageBatch: chain.getStorageBatch,
              ),
              voteQuery: (block) => LegislationVoteQueryService(
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
          })(),
          8,
          true,
        ),
        throwsStateError,
      );
    });
  }
  test('损坏签署账本不能被正确事件掩盖', () async {
    final chain = Chain()
      ..events = eventBytes()
      ..storage = Uint8List.fromList([2]);
    await expectLater(
      submit(
        (() {
          final reads0 = flow();
          return LegislationVoteService(
            eventQuery: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              getFinalizedHead: chain.getFinalizedHead,
              getStorage: chain.getStorage,
              getStorageBatch: chain.getStorageBatch,
            ),
            voteQuery: (block) => LegislationVoteQueryService(
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
        })(),
        8,
        true,
      ),
      throwsFormatException,
    );
  });
  test('取消、准备失败与未知结果不查询事件或重签', () async {
    for (final fail in ['cancel', 'prepare', 'execute', 'consume']) {
      final tx = flow(cold: fail == 'cancel' || fail == 'consume'),
          chain = Chain();
      if (fail == 'prepare') {
        tx.prepare = (_, _) async => throw StateError('合成准备失败');
      }
      if (fail == 'execute') {
        tx.execute = (_) async => throw StateError('合成未知执行');
      }
      if (fail == 'consume') {
        tx.consume = (_, _) async => throw StateError('合成未知消费');
      }
      await expectLater(
        LegislationVoteService(
          eventQuery: (block) => ProposalQueryService(
            block: block,
            getSystemEvents: chain.getSystemEvents,
            getRuntimeContext: chain.getRuntimeContext,
            getFinalizedHead: chain.getFinalizedHead,
            getStorage: chain.getStorage,
            getStorageBatch: chain.getStorageBatch,
          ),
          voteQuery: (block) => LegislationVoteQueryService(
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
        ).overrideSign(
          proposalId: 7,
          approve: true,
          signerPublicKey: signer,
          externalSigning: (_) async =>
              fail == 'cancel' ? null : 'synthetic-response',
        ),
        throwsStateError,
      );
      expect(chain.reads, isEmpty);
      expect(tx.cancelCount, fail == 'cancel' ? 1 : 0);
      expect(tx.prepareCount, 1);
    }
  });
  test('未知调用、负提案ID、空岗位与坏公钥均拒绝', () async {
    for (final args in [
      (99, 7, null),
      (1, -1, 'ROLE'),
      (1, 7, ''),
      (4, 7, 'ROLE'),
    ]) {
      expect(
        () => LegislationVoteService.buildCallData(
          callIndex: args.$1,
          proposalId: args.$2,
          voterRoleCode: args.$3,
          approve: true,
        ),
        throwsArgumentError,
      );
    }
    final tx = flow();
    await expectLater(
      (() {
        final reads0 = Chain();
        return LegislationVoteService(
          eventQuery: (block) => ProposalQueryService(
            block: block,
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
          ),
          voteQuery: (block) => LegislationVoteQueryService(
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
      })().guardVote(
        proposalId: 7,
        approve: true,
        signerPublicKey: Uint8List(31),
        externalSigning: (_) async => null,
      ),
      throwsArgumentError,
    );
    expect(tx.prepareCount, 0);
  });
}
