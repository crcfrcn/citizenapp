import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

import 'dart:convert';

import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_citizen/institution/governance_registry.dart';

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
  ...List.filled(15, 0),
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
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef ref) =>
      CitizenSdkTestFixture.runtimeContext(contextBlock ?? ref);
}

void main() {
  test('删除核验只认最终块的空存储结果且透传读取失败', () async {
    final block = CitizenBlockRef(
      hash: '0x${'11' * 32}',
      number: BigInt.from(240),
      finality: CitizenBlockFinality.finalized,
    );
    var fail = false;
    var calls = 0;
    final query = ProposalQueryService(
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorageBatch: (at, keys) async {
        expect(at, same(block));
        expect(keys, hasLength(2));
        calls++;
        if (fail) throw StateError('合成读取失败');
        return [
          Uint8List.fromList([1]),
          null,
        ];
      },
    );
    final ids = [BigInt.one, BigInt.from(2)];
    expect(await query.deletedProposalIds(block, ids), {BigInt.from(2)});
    fail = true;
    await expectLater(query.deletedProposalIds(block, ids), throwsStateError);
    expect(calls, 2);
  });

  test('立法和选举计票只读事件涉及的键及同一最终块', () async {
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    final id = BigInt.from(7);
    final cid = utf8.encode('CN220');
    final data = <String, Uint8List>{
      runtime.storageKey('LegislationVote', 'RepresentativeTallies', [id, 2]).join(','):
          Uint8List.fromList([3, 0, 0, 0, 2, 0, 0, 0]),
      runtime.storageKey('ElectionVote', 'ElectionTallyStore', [id]).join(','):
          Uint8List.fromList([5, 0, 0, 0]),
      runtime.storageKey('ElectionVote', 'ElectionCandidateTallies', [id, cid]).join(','):
          Uint8List.fromList([4, 0, 0, 0]),
    };
    final read = <String>[];
    final query = ProposalQueryService(
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorage: (at, key) async {
        expect(at, same(block));
        read.add(key.join(','));
        return data[key.join(',')];
      },
    );
    final events = [
      const CitizenSystemEvent(
        eventIndex: 0, extrinsicIndex: 0,
        pallet: 'LegislationVote', name: 'RepresentativeVoteCast',
        fields: {'proposal_id': '7', 'body_index': '2'},
      ),
      CitizenSystemEvent(
        eventIndex: 1, extrinsicIndex: 0,
        pallet: 'ElectionVote', name: 'ElectionVoteCast',
        fields: {'proposal_id': '7', 'candidate_subject': {'cid_number': cid.map((byte) => '$byte').toList()}},
      ),
    ];
    expect(await query.trackTalliesAt(block, id, events), {
      'representative_2_yes': 3, 'representative_2_no': 2,
      'election_casted': 5, 'candidate_CN220': 4,
    });
    expect(read, unorderedEquals(data.keys));
  });

  test('详情按冻结岗位去重批量取名，缺失、失败和错CID不增删票据；列表不取名', () async {
    final fixture =
        jsonDecode(
              File(
                '${Platform.environment['CITIZENCHAIN_ROOT']}/runtime/primitives/tests/fixtures/role_permission.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    Uint8List fixtureBytes(String name) {
      final entry = (fixture['cases'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((row) => row['name'] == name);
      final hex = entry['encoded_hex'] as String;
      return Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
    }

    List<int> text(String value) => [
      ...CitizenScale.compact(utf8.encode(value).length),
      ...utf8.encode(value),
    ];
    final institution = kNrc.first;
    final runtime = await CitizenSdkTestFixture.runtimeContext(block);
    final planKey = base64.encode(
      runtime.storageKey('VotingEngine', 'ProposalVotePlans', [BigInt.one]),
    );
    final snapshotKey = base64.encode(
      runtime.storageKey('VotingEngine', 'VoterSnapshot', [
        BigInt.one,
        (
          scale: Uint8List.fromList([
            0,
            ...fixtureBytes('role_subject_nrc_committee'),
          ]),
        ),
      ]),
    );
    final roleKey = runtime.storageKey('PublicManage', 'InstitutionRoles', [
      Uint8List.fromList(utf8.encode(institution.cidNumber)),
      Uint8List.fromList(utf8.encode('COMMITTEE_MEMBER')),
    ]);
    final snapshot = Uint8List.fromList([
      8,
      ...List.filled(32, 7),
      ...List.filled(32, 8),
    ]);
    for (final mode in ['ready', 'missing', 'failed', 'wrongCid']) {
      var roleReads = 0;
      final query = ProposalQueryService(
        block: block,
        getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getStorage: (at, key) async {
          expect(at.hash, block.hash);
          final id = base64.encode(key);
          if (id == planKey)
            return fixtureBytes('vote_plan_resolution_issuance_joint');
          if (id == snapshotKey) return snapshot;
          throw StateError('不应读取当前管理员姓名或额外storage');
        },
        getStorageBatch: (at, keys) async {
          roleReads++;
          expect(at.hash, block.hash);
          expect(keys, hasLength(1), reason: '同岗位两张票据只读一次名称');
          expect(keys.single, roleKey);
          if (mode == 'failed') throw StateError('synthetic role failure');
          return [
            mode == 'missing'
                ? null
                : Uint8List.fromList([
                    ...text(
                      mode == 'wrongCid' ? 'OTHER-CID' : institution.cidNumber,
                    ),
                    ...text('COMMITTEE_MEMBER'), ...text('委员'), 0, 1,
                    // 已停用岗位仍可为历史冻结票据提供名称，不代表当前授予投票资格。
                  ]),
          ];
        },
      );
      final plain = await query.fetchEligibleVoterTickets(
        BigInt.one,
        institution,
      );
      expect(roleReads, 0);
      final named = await query.fetchEligibleVoterTickets(
        BigInt.one,
        institution,
        includeRoleNames: true,
      );
      expect(roleReads, 1);
      expect(
        named.map((ticket) => ticket.ticketKey),
        plain.map((ticket) => ticket.ticketKey),
      );
      expect(named.map((ticket) => ticket.voterAccountId), [
        '0x${'07' * 32}',
        '0x${'08' * 32}',
      ]);
      for (final ticket in named)
        expect(ticket.voterRoleName, mode == 'ready' ? '委员' : isNull);
    }
  });

  test('提案ID列表完整保留u128且拒绝旧宽度', () {
    final id = (BigInt.one << 127) + BigInt.from(19);
    final raw = Uint8List.fromList([4, ...CitizenScale.unsigned(id, 16)]);
    expect(ProposalQueryService.decodeActiveProposalIds(raw), [id]);
    expect(
      ProposalQueryService.decodeActiveProposalIds(
        Uint8List.fromList([4, ...List.filled(8, 0)]),
      ),
      isNull,
    );
  });

  test('绑定块查询，缺失与损坏提案严格区分', () async {
    final chain = Chain(),
        query = (() {
          final reads0 = Chain();
          return ProposalQueryService(
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: block,
          );
        })();
    expect(await query.fetchProposalMeta(BigInt.from(7)), isNull);
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
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
      block: block,
    );
    expect((await anchored.fetchProposalMeta(BigInt.from(7)))!.status, 0);
    expect(chain.reads.single, same(block));
    for (final value in [
      <int>[],
      <int>[0],
      [...chain.data!, 0],
      [0, 0, 9, ...chain.data!.skip(3)],
    ]) {
      chain.data = Uint8List.fromList(value);
      await expectLater(
        anchored.fetchProposalMeta(BigInt.from(7)),
        throwsFormatException,
      );
    }
  });
  test('计票、阈值和NextProposalId损坏不伪装成零或缺失', () async {
    final chain = Chain()..data = Uint8List(1),
        query = (() {
          final reads0 = Chain();
          return ProposalQueryService(
            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: block,
          );
        })();
    expect(await query.fetchNextProposalId(), BigInt.from(0));
    final anchored = ProposalQueryService(
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
      block: block,
    );
    await expectLater(anchored.fetchNextProposalId(), throwsFormatException);
    await expectLater(
      anchored.fetchVoteTally(BigInt.from(7)),
      throwsFormatException,
    );
    await expectLater(
      anchored.fetchInternalThresholdSnapshot(BigInt.from(7)),
      throwsFormatException,
    );
  });
  test('真实metadata字段名、稀疏事件索引和交易索引完整保留', () async {
    final chain = Chain()..events = eventBytes();
    final events = await ProposalQueryService(
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchExecutionEvents(completed().execution!);
    expect(events.single.extrinsicIndex, 2);
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
          getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
        getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getFinalizedHead: chain.getFinalizedHead,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchExecutionEvents(completed().execution!),
      throwsStateError,
    );
  });
}
