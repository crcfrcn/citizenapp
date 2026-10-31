import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'dart:convert';

import 'package:citizen_citizen/proposal/proposal_query_service.dart';

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

Uint8List eventMetadata() => base64Decode(
  'bWV0YQ40AAAABQMABAAABQUACAAABQYADAAABQAAEAAAAyAAAAAAABQAAAIAABgAAAEMOEFwcGx5RXh0cmluc2ljBAAEARhzaGFyZWQAAAAwRmluYWxpemF0aW9uAAEAOEluaXRpYWxpemF0aW9uAAIAABwAAAEQWFJlcHJlc2VudGF0aXZlVm90ZUNhc3QUASxwcm9wb3NhbF9pZAgBGHNoYXJlZAABKGJvZHlfaW5kZXgEARhzaGFyZWQAAQx3aG8QARhzaGFyZWQAATx2b3Rlcl9yb2xlX2NvZGUUARhzaGFyZWQAARxhcHByb3ZlDAEYc2hhcmVkAAEAaExlZ2lzbGF0aW9uRXhlY3V0aXZlU2lnbmVkDAEscHJvcG9zYWxfaWQIARhzaGFyZWQAAQx3aG8QARhzaGFyZWQAARxhcHByb3ZlDAEYc2hhcmVkAAYAZExlZ2lzbGF0aW9uT3ZlcnJpZGVTaWduZWQMASxwcm9wb3NhbF9pZAgBGHNoYXJlZAABDHdobxABGHNoYXJlZAABHGFwcHJvdmUMARhzaGFyZWQACABUTGVnaXNsYXRpb25HdWFyZFZvdGVkDAEscHJvcG9zYWxfaWQIARhzaGFyZWQAAQx3aG8QARhzaGFyZWQAARxhcHByb3ZlDAEYc2hhcmVkAAoAACAAAAEEPExlZ2lzbGF0aW9uVm90ZQQAHAEYc2hhcmVkABoAACQAAAIQACgAAAAMARRwaGFzZRgBGHNoYXJlZAABFGV2ZW50IAEYc2hhcmVkAAEYdG9waWNzJAEYc2hhcmVkAAAsAAACKAAwAAAEAAAEGFN5c3RlbQEYU3lzdGVtBBhFdmVudHMBACwEAAAAAAAAADAEADA=',
);

Uint8List eventBytes({
  int index = 2,
  int event = 8,
  int id = 7,
  bool approve = true,
  int who = 1,
  int phase = 0,
  int body = 0,
  String role = 'DIRECTOR',
}) => Uint8List.fromList([
  4,
  phase,
  if (phase == 0) ...[index, 0, 0, 0],
  26,
  event,
  id,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  if (event == 1) ...[body, 0, 0, 0],
  ...List.filled(32, who),
  if (event == 1) ...[utf8.encode(role).length << 2, ...utf8.encode(role)],
  approve ? 1 : 0,
  0,
]);

class Chain extends TestChainReads {
  Uint8List? data;
  Uint8List? events;
  CitizenBlockRef? contextBlock;
  final reads = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async => block;
  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async {
    reads.add(ref);
    return data;
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
        metadata: eventMetadata(),
      );
}

void main() {
  test('绑定块查询，缺失与损坏提案严格区分', () async {
    final chain = Chain(),
        query = (() {
          final reads0 = Chain();
          return ProposalQueryService(
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: block,
          );
        })();
    expect(await query.fetchProposalMeta(7), isNull);
    chain.data = Uint8List.fromList([
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      ...List.filled(8, 0),
    ]);
    final anchored = ProposalQueryService(
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
      block: block,
    );
    expect((await anchored.fetchProposalMeta(7))!.status, 0);
    expect(chain.reads.single, same(block));
    for (final value in [
      <int>[],
      <int>[0],
      [...chain.data!, 0],
      [0, 0, 9, ...chain.data!.skip(3)],
    ]) {
      chain.data = Uint8List.fromList(value);
      await expectLater(anchored.fetchProposalMeta(7), throwsFormatException);
    }
  });
  test('计票、阈值和NextProposalId损坏不伪装成零或缺失', () async {
    final chain = Chain()..data = Uint8List(1),
        query = (() {
          final reads0 = Chain();
          return ProposalQueryService(
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: block,
          );
        })();
    expect(await query.fetchNextProposalId(), 0);
    final anchored = ProposalQueryService(
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
      block: block,
    );
    await expectLater(anchored.fetchNextProposalId(), throwsFormatException);
    await expectLater(anchored.fetchVoteTally(7), throwsFormatException);
    await expectLater(
      anchored.fetchInternalThresholdSnapshot(7),
      throwsFormatException,
    );
  });
  test('真实metadata字段名、稀疏事件索引和交易索引完整保留', () async {
    final chain = Chain()..events = eventBytes();
    final events = await ProposalQueryService(
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchExecutionEvents(completed().execution!);
    expect(events.single.index, 2);
    expect(events.single.name, 'LegislationOverrideSigned');
    expect((events.single.fields as Map)['approve'], true);
    expect(chain.reads.single, same(block));
  });
  test('坏Phase、截断、尾随字节及metadata块不符立即失败', () async {
    for (final value in [
      eventBytes(phase: 3),
      eventBytes().sublist(0, 10),
      Uint8List.fromList([...eventBytes(), 0]),
    ]) {
      final chain = Chain()..events = value;
      await expectLater(
        ProposalQueryService(
          getSystemEvents: chain.getSystemEvents,
          getRuntimeContext: chain.getRuntimeContext,
          getFinalizedHead: chain.getFinalizedHead,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
        ).fetchExecutionEvents(completed().execution!),
        throwsA(anything),
      );
    }
    final chain = Chain()
      ..events = eventBytes()
      ..contextBlock = CitizenBlockRef(
        hash: 'other',
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      );
    await expectLater(
      ProposalQueryService(
        getSystemEvents: chain.getSystemEvents,
        getRuntimeContext: chain.getRuntimeContext,
        getFinalizedHead: chain.getFinalizedHead,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchExecutionEvents(completed().execution!),
      throwsStateError,
    );
  });
}
