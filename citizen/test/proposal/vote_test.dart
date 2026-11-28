// 验证内部投票。

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteQueryService;
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteService;

void main() {
  group('internal_vote_query_service_test', _registerQuery);
  group('internal_vote_service_test', _registerService);
}

// 验证准确机构岗位票据键、批量读取及缺项或坏数据拒绝。

final queryBlock = CitizenBlockRef(
  hash: 'block',
  number: BigInt.one,
  finality: CitizenBlockFinality.finalized,
);
final account = '0x${'01' * 32}';

class QueryChain extends TestChainReads {
  Uint8List? value;
  int heads = 0, batches = 0;
  bool short = false;
  Uint8List? key;
  final refs = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    return queryBlock;
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List bytes) async {
    refs.add(ref);
    key = bytes;
    return value;
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef ref,
    List<Uint8List> keys,
  ) async {
    refs.add(ref);
    batches++;
    return List.filled(short ? 0 : keys.length, value);
  }
}

void _registerQuery() {
  test('缺失、赞成与反对严格按SCALE bool读取，确认查询不换链头', () async {
    final chain = QueryChain(),
        query = (() {
          final reads0 = QueryChain();
          return InternalVoteQueryService(
            getFinalizedHead: reads0.getFinalizedHead,
            getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: queryBlock,
          );
        })();
    expect(await query.fetchAdminVote(BigInt.from(7), account), null);
    for (final value in [0, 1]) {
      chain.value = Uint8List.fromList([value]);
      expect(
        await InternalVoteQueryService(
          getFinalizedHead: chain.getFinalizedHead,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
          block: queryBlock,
        ).fetchAdminVote(BigInt.from(7), account),
        value == 1,
      );
    }
    expect(chain.heads, 0);
    expect(chain.refs.every((r) => identical(r, queryBlock)), true);
  });
  for (final bytes in [
    <int>[],
    <int>[2],
    <int>[1, 0],
  ]) {
    test('坏投票$bytes不会被当成未投票', () async {
      final chain = QueryChain()..value = Uint8List.fromList(bytes);
      await expectLater(
        InternalVoteQueryService(
          getFinalizedHead: chain.getFinalizedHead,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
        ).fetchAdminVote(BigInt.from(7), account),
        throwsFormatException,
      );
    });
  }
  test('机构票据包含机构CID、岗位及人员CID，文本按UTF-8编码', () async {
    final chain = QueryChain();
    await InternalVoteQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchInstitutionTicketVote(BigInt.from(7), '机构', '岗位', 'CN220-CTZN2-198805200-2026');
    const personCid = 'CN220-CTZN2-198805200-2026';
    final suffix = [
      2,
      utf8.encode('机构').length << 2,
      ...utf8.encode('机构'),
      utf8.encode('岗位').length << 2,
      ...utf8.encode('岗位'),
      utf8.encode(personCid).length << 2,
      ...utf8.encode(personCid),
    ];
    expect(chain.key!.sublist(chain.key!.length - suffix.length), suffix);
  });
  test('批量按100分块，仅一次选链头且保持重复账户去重', () async {
    final chain = QueryChain()..value = Uint8List.fromList([0]);
    final accounts = List.generate(
      201,
      (i) => '0x${i.toRadixString(16).padLeft(64, '0')}',
    );
    final result = await InternalVoteQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchAdminVotesBatch(BigInt.from(7), [...accounts, accounts.first]);
    expect(result.length, 201);
    expect(chain.batches, 3);
    expect(chain.heads, 1);
    expect(result.values.every((x) => x == false), true);
  });
  test('批量响应缺件必须失败，不越界或制造null', () async {
    await expectLater(
      (() {
        final reads0 = QueryChain()..short = true;
        return InternalVoteQueryService(
          getFinalizedHead: reads0.getFinalizedHead,
          getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getStorage: reads0.getStorage,
          getStorageBatch: reads0.getStorageBatch,
        );
      })().fetchAdminVotesBatch(BigInt.from(7), [account]),
      throwsFormatException,
    );
  });
  test('坏账户、空岗位和负提案号在读取前拒绝', () async {
    final chain = QueryChain(),
        query = (() {
          final reads0 = QueryChain();
          return InternalVoteQueryService(
            getFinalizedHead: reads0.getFinalizedHead,
            getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
          );
        })();
    await expectLater(query.fetchAdminVote(BigInt.from(7), '01'), throwsFormatException);
    await expectLater(
      InternalVoteQueryService(
        getFinalizedHead: chain.getFinalizedHead,
        getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchInstitutionTicketVote(BigInt.from(7), 'CID', '', account),
      throwsArgumentError,
    );
    await expectLater(
      InternalVoteQueryService(
        getFinalizedHead: chain.getFinalizedHead,
        getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchAdminVote(BigInt.from(-1), account),
      throwsArgumentError,
    );
    expect(chain.refs, isEmpty);
  });
}

// 验证当前签名账户的内部投票及执行事件，取消或未知结果不重播。

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

/// 按 SDK 所属 V15 Runtime 金标的布局构造独立事件输入。
/// 历史票据键不参与此事件的who；who始终是当前交易签名账户。
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
    ...List.filled(15, 0),
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
  Future<CitizenRuntimeContext> getRuntimeContext(CitizenBlockRef ref) =>
      CitizenSdkTestFixture.runtimeContext(contextBlock ?? ref);
  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async {
    reads.add(ref);
    // 只交付真实提案元数据；若实现再用签名公钥查历史票据，此夹具立即失败。
    expect(key.sublist(0, 16), Hasher.twoxx128.hashString('VotingEngine'));
    expect(key.sublist(16, 32), Hasher.twoxx128.hashString('Proposals'));
    expect(key.sublist(key.length - 16), [7, ...List.filled(15, 0)]);
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

void _registerService() {
  for (final cold in [false, true]) {
    for (final institutional in [false, true]) {
      test('换绑后当前签名人投票冷热签，不猜历史票据主键：$cold/$institutional', () async {
        final tx = flow(cold: cold),
            chain = Chain()
              ..events = voteEvents(role: institutional ? 'DIRECTOR' : null);
        final result =
            await InternalVoteService(
              buildCall: _buildCall,
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
              proposalId: BigInt.from(7),
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
        expect(tx.callData![18], institutional ? 1 : 0);
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
              buildCall: _buildCall,
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: reads0.getSystemEvents,
                getRuntimeContext: reads0.getRuntimeContext,
                getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
            proposalId: BigInt.from(7),
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
              buildCall: _buildCall,
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: chain.getSystemEvents,
                getRuntimeContext: chain.getRuntimeContext,
                getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
            proposalId: BigInt.from(7),
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
              buildCall: _buildCall,
              queryFactory: (block) => ProposalQueryService(
                block: block,
                getSystemEvents: reads0.getSystemEvents,
                getRuntimeContext: reads0.getRuntimeContext,
                getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
            proposalId: BigInt.from(7),
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
            buildCall: _buildCall,
            queryFactory: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: chain.getSystemEvents,
              getRuntimeContext: chain.getRuntimeContext,
              getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
          proposalId: BigInt.from(7),
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
            buildCall: _buildCall,
            queryFactory: (block) => ProposalQueryService(
              block: block,
              getSystemEvents: reads0.getSystemEvents,
              getRuntimeContext: reads0.getRuntimeContext,
              getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
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
          proposalId: BigInt.from(7),
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

Future<Uint8List> _buildCall(String pallet, String method, Object fields) async {
  final runtime = await CitizenSdkTestFixture.runtimeContext(CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  ));
  return runtime.encodeCall(pallet, method, fields);
}
