import 'package:citizen_citizen/runtime/runtime_upgrade_detail_page.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_citizen/proposal/proposal_tab.dart';
import 'package:citizen_citizen/proposal/proposal_vote_widgets.dart';
import 'package:citizen_citizen/proposal/proposal_context.dart';
import 'package:citizen_citizen/proposal/proposal_local_store.dart';
import 'package:citizen_citizen/administrators/institution_admin_service.dart';
import 'package:citizen_citizen/administrators/admin_activation_service.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/public/public_institution_repository.dart';
import 'package:citizen_multisig/multisig_transfer_proposal_adapter.dart';

import 'package:citizen_testing/isar_test_env.dart';

import 'package:citizen_storage/user_isar.dart' hide Group;

import 'package:citizen_testing/institution/public_nav_harness.dart';

import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/institution/governance_registry.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_citizen/proposal/proposal_cache.dart';
import 'package:citizen_multisig/multisig_transfer_service.dart';
import 'package:citizen_multisig/multisig_transfer_detail_page.dart';
import 'package:citizen_multisig/multisig_transfer_models.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

class _RawStorageChain extends TestChainReads {
  _RawStorageChain(this.value);

  final Uint8List value;
  final List<String> storageKeys = [];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async => CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    storageKeys.add(
      '0x${key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    );
    return value;
  }
}

/// 合成链只提供公开读合同；真实Feed/Service负责年份、索引和详情读取。
class _ProposalChain extends _RawStorageChain {
  _ProposalChain({
    this.failureAt,
    this.failure,
    this.missingYear = false,
    this.hasIndex = false,
  }) : super(Uint8List.fromList([0xea, 0x07, 0, 0]));
  final String? failureAt;
  final Object? failure;
  final bool missingYear;
  final bool hasIndex;
  final reads = <String>[];

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    reads.add('year');
    expectSync(key.length, 32);
    if (failureAt == 'year') throw failure!;
    return missingYear ? null : value;
  }

  @override
  Future<List<Uint8List>> getStorageKeysPaged(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit = 1000,
  }) async {
    reads.add('index');
    expectSync(prefix.length, 44);
    expectSync(prefix.sublist(40), [0xea, 0x07, 0, 0]);
    expectSync(startKey, isNull);
    expectSync(limit, 1000);
    if (failureAt == 'index') throw failure!;
    return hasIndex
        ? [
            Uint8List.fromList([
              ...prefix,
              ...List<int>.filled(8, 0),
              1,
              ...List<int>.filled(15, 0),
            ]),
          ]
        : [];
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    reads.add('details');
    if (failureAt == 'details') throw failure!;
    return [for (final _ in keys) null];
  }
}

class _FeedDeletionQuery extends ProposalQueryService {
  bool fail = true;
  int checks = 0;
  final processed = <BigInt>[];

  @override
  Future<List<CitizenSystemEvent>> proposalEvents(
    CitizenBlockRef block,
  ) async {
    processed.add(block.number);
    return [];
  }

  @override
  Future<Set<BigInt>> deletedProposalIds(
    CitizenBlockRef block,
    Iterable<BigInt> ids,
  ) async {
    checks++;
    expect(block.number, greaterThanOrEqualTo(BigInt.from(240)));
    expect(ids, [BigInt.one]);
    if (fail) throw StateError('读取失败');
    return ids.toSet();
  }
}

class _FeedVoteQuery extends ProposalQueryService {
  int eventsRead = 0;
  int metaReads = 0;
  bool voteOnly = false;
  List<CitizenSystemEvent>? eventOverride;
  ProposalMeta? metaOverride;

  @override
  Future<List<CitizenSystemEvent>> proposalEvents(CitizenBlockRef block) async {
    eventsRead++;
    if (eventOverride case final events?) return events;
    if (voteOnly) {
      return const [
        CitizenSystemEvent(
          eventIndex: 0,
          extrinsicIndex: 0,
          pallet: 'JointVote',
          name: 'JointInstitutionTicketVoteCast',
          fields: {'proposal_id': '1'},
        ),
      ];
    }
    return const [
      CitizenSystemEvent(
        eventIndex: 0,
        extrinsicIndex: 0,
        pallet: 'VotingEngine',
        name: 'ProposalFinalized',
        fields: {'proposal_id': '1', 'status': '3'},
      ),
    ];
  }

  @override
  Future<({({int yes, int no}) tally, ({int yes, int no})? referendum})>
  proposalTalliesAt(CitizenBlockRef block, ProposalMeta meta) async =>
      (tally: (yes: voteOnly ? 4 : 3, no: 1), referendum: (yes: 0, no: 0));

  @override
  Future<({
    List<String> accounts,
    Map<String, bool?> votes,
    bool? result,
    ({int yes, int no}) tally,
  })> jointInstitutionAt(
    CitizenBlockRef block,
    ProposalMeta meta,
    InstitutionInfo institution,
    List<String> accounts,
  ) async => (
    accounts: accounts,
    votes: const <String, bool?>{},
    result: null,
    tally: (yes: voteOnly ? 2 : 1, no: 0),
  );

  @override
  Future<ProposalMeta?> proposalMetaAt(CitizenBlockRef block, BigInt id) async {
    metaReads++;
    if (metaOverride case final meta?) return meta;
    return ProposalMeta(
      proposalId: id,
      kind: 1,
      stage: 1,
      status: 3,
      internalCode: 'NRC',
    );
  }
}

class _NamedProposalRepository extends InstitutionRepository {
  _NamedProposalRepository(PublicInstitutionRepository directory, this.known)
    : super(directory: directory);
  final InstitutionInfo known;

  @override
  InstitutionInfo? governanceInfo(String cidNumber) =>
      cidNumber == known.cidNumber ? known : super.governanceInfo(cidNumber);
}

class _FailingScopeRepository extends InstitutionRepository {
  _FailingScopeRepository({required super.directory});
  @override
  InstitutionInfo? governanceInfo(String cidNumber) =>
      throw StateError('synthetic private scope detail');
}

/// 合成只读依赖只控制结果与时序，页面仍执行同一加载、持久化和刷新路径。
class _PageFeed extends MultisigTransferProposalFeed {
  _PageFeed()
    : super(
        service: (() {
          final reads0 = TestChainReads();
          final reads1 = TestTransactionCalls();
          return MultisigTransferService(
            buildCall: _buildCall,
            getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorageKeysPaged: reads0.getStorageKeysPaged,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,

            getSystemEvents: reads0.getSystemEvents,
            getRuntimeContext: reads0.getRuntimeContext,
            prepareTransaction: reads1.prepareTransaction,
            executePreparedTransaction: reads1.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                reads1.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                reads1.consumePreparedTransactionQrResponse,
          );
        })(),
      );
  List<int> ids = [1];
  final scopes = <FutureOr<List<int>> Function()>[];
  final forced = <bool>[];
  Future<List<ProposalWithDetail>> Function(List<int>)? details;
  final failedBodies = <BigInt>{};
  final retries = <List<BigInt>>[];

  @override
  Future<List<ProposalWithDetail>> proposalsAt(
    CitizenBlockRef block, List<BigInt> ids, {
    void Function(BigInt)? onDetailFailure,
  }) async {
    retries.add(ids);
    for (final id in ids.where(failedBodies.contains)) {
      onDetailFailure?.call(id);
    }
    return fetchProposalsByIds(ids);
  }
  @override
  Future<List<BigInt>> fetchCitizenProposalFeedIds({
    required Set<String> defaultCodes,
    required Set<String> subscribedInstitutionCidNumbers,
    bool forceRefresh = false,
  }) async {
    expectSync(defaultCodes, contains('NRC'));
    forced.add(forceRefresh);
    final result = scopes.isEmpty ? ids : await scopes.removeAt(0)();
    return result.map(BigInt.from).toList();
  }

  @override
  Future<List<ProposalWithDetail>> bootstrapAt(
    CitizenBlockRef block, {
    void Function(BigInt)? onDetailFailure,
  }) async {
    final selected = await fetchCitizenProposalFeedIds(
      defaultCodes: {'NRC'},
      subscribedInstitutionCidNumbers: {},
    );
    final proposals = await fetchProposalsByIds(selected);
    for (final id in selected.where(failedBodies.contains)) {
      onDetailFailure?.call(id);
    }
    if (selected.isNotEmpty && proposals.isEmpty) {
      throw StateError('提案索引非空但没有可持久化记录');
    }
    return proposals;
  }

  static List<ProposalWithDetail> proposals(List<int> ids) => [
    for (final id in ids)
      ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: BigInt.from(id),
          kind: 1,
          stage: 1,
          status: 0,
          internalCode: 'NRC',
          displayMeta: ProposalDisplayMeta(
            year: 2026,
            seqInYear: BigInt.from(id),
          ),
        ),
      ),
  ];
  @override
  Future<List<ProposalWithDetail>> fetchProposalsByIds(
    List<BigInt> ids,
  ) async => details == null
      ? proposals(ids.map((id) => id.toInt()).toList())
      : details!(ids.map((id) => id.toInt()).toList());
}

class _PageContext extends ProposalContextResolver {
  _PageContext()
    : super(
        adminService: (() {
          final reads0 = TestChainReads();
          return InstitutionAdminService(
            getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: reads0.getFinalizedHead,
            getStorageKeysPaged: reads0.getStorageKeysPaged,
            getStorageBatch: reads0.getStorageBatch,
          );
        })(),
        activationService: ActivationService(
          adminService: (() {
            final reads0 = TestChainReads();
            return InstitutionAdminService(
              getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
              getFinalizedHead: reads0.getFinalizedHead,
              getStorageKeysPaged: reads0.getStorageKeysPaged,
              getStorageBatch: reads0.getStorageBatch,
            );
          })(),
        ),
      );
  Object? failure;
  InstitutionInfo? institution;
  int voteChecks = 0;
  @override
  Future<ProposalContext> resolve({
    String? actorCidNumber,
    List<int>? executionAccountId,
    String? internalCode,
    InstitutionInfo? knownInstitution,
  }) async {
    voteChecks++;
    if (failure != null) throw failure!;
    return ProposalContext(institution: knownInstitution);
  }

  @override
  Future<List<ProposalContext>> resolveBatch(
    List<String?> actorCidNumbers, {
    List<List<int>?>? executionAccountIds,
    List<String?>? internalCodeList,
    Map<String, InstitutionInfo> knownInstitutionsByCidNumber = const {},
  }) async {
    if (failure != null) throw failure!;
    return [
      for (final _ in actorCidNumbers)
        ProposalContext(institution: institution),
    ];
  }
}

// 业务只读事实夹具；SDK会话本身仍来自真实Core，不实现SDK平台接口。
class _PageReads {
  final physical = CitizenSdkTestFixture();
  final controller = StreamController<CitizenSdkEvent>.broadcast();
  int sequence = 1, revision = 1;
  bool ready = true;
  CitizenCapabilityReason reason = CitizenCapabilityReason.none;
  CitizenSdkLifecycle state = CitizenSdkLifecycle.created;
  Future<CitizenCapabilitySnapshot> Function()? snapshotReader;
  Future<CitizenSdk> open() async {
    physical.install();
    return CitizenSdk.open(modules: CitizenSdkModules.qr);
  }

  List<String> get calls => physical.calls;
  Future<CitizenCapabilitySnapshot> read() =>
      snapshotReader?.call() ?? Future.value(capabilities());
  CitizenCapabilitySnapshot capabilities() => CitizenCapabilitySnapshot(
    revision: BigInt.from(revision),
    statuses: [
      for (final name in CitizenCapabilityName.values)
        CitizenCapabilityStatus(
          name: name,
          supported: true,
          available: true,
          enabled: true,
          ready: name == CitizenCapabilityName.chainRead ? ready : true,
          reason: name == CitizenCapabilityName.chainRead
              ? reason
              : CitizenCapabilityReason.none,
        ),
    ],
  );
  void capability({
    required bool isReady,
    CitizenCapabilityReason why = CitizenCapabilityReason.none,
  }) {
    ready = isReady;
    reason = why;
    revision++;
    controller.add(
      CitizenSdkCapabilitiesChanged(
        sequence: sequence++,
        snapshot: capabilities(),
      ),
    );
  }

  void lifecycle(String value) {
    state = CitizenSdkLifecycle.values.byName(value);
    controller.add(
      CitizenSdkLifecycleChanged(sequence: sequence++, lifecycle: state),
    );
  }

  void finalized([int height = 1]) => controller.add(
    CitizenSdkFinalizedBlockChanged(
      sequence: sequence++,
      finalized: CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.from(height),
        finality: CitizenBlockFinality.finalized,
      ),
    ),
  );
  Future<void> dispose() async {
    await controller.close();
    await physical.dispose();
  }
}

Future<void> _flush(WidgetTester tester) async {
  // 真实Isar IO不使用测试的虚拟时钟；等其队列完成后才核对页面结果。
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<T> _drainRead<T>(WidgetTester tester, Future<T> future) async {
  late T value;
  var complete = false;
  unawaited(future.then((result) {
    value = result;
    complete = true;
  }));
  for (var i = 0; i < 8 && !complete; i++) {
    await _flush(tester);
  }
  expect(complete, true, reason: '本机数据库读取必须完成');
  return value;
}

Future<_PageReads> _openProposal(
  WidgetTester tester,
  _PageFeed feed,
  List<int> counts, {
  ProposalContextResolver? resolver,
  InstitutionRepository? repository,
  _PageReads? transportOverride,
  bool waitForTerminal = true,
  int height = 1,
  Future<CitizenBlockRef> Function()? headReader,
  Future<CitizenBlockRef> Function(BigInt)? blockReader,
  ProposalQueryService? query,
}) async {
  final transport = transportOverride ?? _PageReads();
  final sdk = await transport.open();
  addTearDown(() async {
    await _flush(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await sdk.close();
      await transport.dispose();
    });
  });
  await tester.runAsync(() => UserIsar.instance.db());
  final directory = await buildSeededRepo(
    provinceOrder: const [],
    institutions: const [],
  );
  await tester.pumpWidget(
    Provider<CitizenSdk>.value(
      value: sdk,
      child: MaterialApp(
        home: Scaffold(
          body: ProposalTab(
            feed: feed,
            query: query,
            genesisReader: () async => "test-chain",
            finalizedBlockReader: blockReader,
            finalizedHeadReader: headReader ?? () async => CitizenBlockRef(
              hash: '0x${'11' * 32}',
              number: BigInt.from(height),
              finality: CitizenBlockFinality.finalized,
            ),
            capabilitiesReader: transport.read,
            walletStateReader: () =>
                testCitizenOperation(testCitizenWalletState),
            sdkEvents: transport.controller.stream,
            lifecycleReader: () => transport.state,
            repository:
                repository ?? InstitutionRepository(directory: directory),
            contextResolver: resolver ?? _PageContext(),
            onPendingVoteCountChanged: counts.add,
          ),
        ),
      ),
    ),
  );
  for (var attempt = 0; waitForTerminal && attempt < 20; attempt++) {
    await _flush(tester);
    if (counts.isNotEmpty || find.text('提案读取失败，请重试').evaluate().isNotEmpty) {
      break;
    }
  }
  if (waitForTerminal) {
    expect(
      counts.isNotEmpty || find.text('提案读取失败，请重试').evaluate().isNotEmpty,
      isTrue,
      reason: '必须等待真实首批读取完成，不能把骨架内部ListView认作提案列表',
    );
  }
  return transport;
}

Future<void> _refreshProposal(WidgetTester tester) =>
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();

/// 提案页真实交互路径与批量解码布局回归。
///
/// 固化当前 runtime `MODULE_TAG + TransferAction` SCALE 布局，确保机构转账
/// 始终按 actor CID + funding account 解码，短备注和空备注都不会静默消失。
class _DetailReads extends MultisigTransferService {
  _DetailReads(this.account, {this.roleName = '委员'});
  final String account;
  final String roleName;
  int statusReads = 0;
  bool failVotes = false;
  bool alreadyVoted = false;
  int status = 0;
  Future<Map<String, bool?>>? pendingVotes;
  EligibleVoterTicket get ticket => EligibleVoterTicket(
    voterAccountId: account,
    cidNumber: kNrc.first.cidNumber,
    voterRoleCode: 'COMMITTEE_MEMBER',
    voterRoleName: roleName,
  );
  @override
  Future<List<EligibleVoterTicket>> fetchEligibleVoterTickets(
    BigInt id,
    InstitutionInfo institution, {
    bool includeRoleNames = false,
  }) async => [ticket];
  @override
  Future<int?> fetchInternalThresholdSnapshot(BigInt id) async => 1;
  @override
  Future<int?> fetchProposalStatus(BigInt id) async {
    statusReads++;
    return status;
  }

  @override
  Future<({int yes, int no})> fetchVoteTally(BigInt id) async =>
      (yes: 0, no: 0);
  @override
  Future<TransferProposalInfo?> fetchProposalAction(BigInt id) async => null;
  @override
  Future<Map<String, bool?>> fetchTicketVotesBatch(
    BigInt id,
    Iterable<EligibleVoterTicket> tickets,
  ) async {
    if (failVotes) throw StateError('synthetic vote read failure');
    if (pendingVotes != null) return await pendingVotes!;
    return {ticket.ticketKey: alreadyVoted ? true : null};
  }
}

void main() {
  useIsolatedIsar();
  for (final reason in [
    CitizenCapabilityReason.engineNotRunning,
    CitizenCapabilityReason.dependencyNotReady,
    CitizenCapabilityReason.chainStarting,
    CitizenCapabilityReason.chainUnsynced,
  ]) {
    test('详情只等SDK就绪事件，不轮询或把${reason.name}直接当读取失败', () async {
      final reads = _PageReads()
        ..ready = false
        ..reason = reason;
      final closed = Completer<void>();
      var calls = 0;
      var done = false;
      final wait =
          waitForProposalRead(
            getCapabilities: () {
              calls++;
              return reads.read();
            },
            lifecycle: () => reads.state,
            events: reads.controller.stream,
            cancelled: closed.future,
          ).then((value) {
            done = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(calls, 1);
      reads.capability(isReady: true);
      expect(await wait, isTrue);
      expect(calls, 2);
      closed.complete();
      await reads.controller.close();
    });
  }
  test('详情旧ready快照迟到不能覆盖未就绪事件；取消等待立即解除订阅', () async {
    final reads = _PageReads();
    final old = Completer<CitizenCapabilitySnapshot>();
    final oldReady = reads.capabilities();
    var calls = 0;
    final closed = Completer<void>();
    var done = false;
    final wait =
        waitForProposalRead(
          getCapabilities: () => ++calls == 1 ? old.future : reads.read(),
          lifecycle: () => reads.state,
          events: reads.controller.stream,
          cancelled: closed.future,
        ).then((value) {
          done = true;
          return value;
        });
    reads.capability(
      isReady: false,
      why: CitizenCapabilityReason.chainUnsynced,
    );
    await Future<void>.delayed(Duration.zero);
    old.complete(oldReady);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    expect(calls, 2);
    closed.complete();
    expect(await wait, isFalse);
    expect(reads.controller.hasListener, isFalse);
    await reads.controller.close();
  });
  test('详情启动失败不永久等候，真实读取错误只报固定阶段且原样抛出', () async {
    final reads = _PageReads()..state = CitizenSdkLifecycle.startFailed;
    final closed = Completer<void>();
    await expectLater(
      waitForProposalRead(
        getCapabilities: reads.read,
        lifecycle: () => reads.state,
        events: reads.controller.stream,
        cancelled: closed.future,
      ),
      throwsStateError,
    );
    final failure = StateError('synthetic-private-body');
    await expectLater(
      proposalReadStage('proposal_votes', () async => throw failure),
      throwsA(same(failure)),
    );
    closed.complete();
    await reads.controller.close();
  });

  testWidgets('详情首次失败可重试，刷新防重入且失败保留内容并禁用投票', (tester) async {
    final opened = await openTestSdk();
    await tester.runAsync(() => UserIsar.instance.db());
    final wallet = testCitizenWalletState().accounts.first;
    final reads = _DetailReads(wallet.accountId)..failVotes = true;
    final block = CitizenBlockRef(
      hash: '0x${'11' * 32}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    var blocks = 0;
    final seenBlocks = <CitizenBlockRef>[];
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: opened.sdk,
        child: MaterialApp(
          home: MultisigTransferDetailPage(
            institution: kNrc.first,
            proposalId: BigInt.from(60001),
            proposalContext: ProposalContext(
              institution: kNrc.first,
              adminWallets: [wallet],
              role: ProposalRole.admin,
            ),
            readBlock: (_) async {
              blocks++;
              return block;
            },
            readService: (at) {
              seenBlocks.add(at);
              return reads;
            },
          ),
        ),
      ),
    );
    await _flush(tester);
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    reads.failVotes = false;
    await tester.tap(find.text('重试'));
    await _flush(tester);
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('委员'), findsOneWidget);
    expect(
      tester
          .widget<ProposalVoteActions>(find.byType(ProposalVoteActions))
          .canVote,
      isTrue,
    );
    final pending = Completer<Map<String, bool?>>();
    reads.pendingVotes = pending.future;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final first = refresh.onRefresh();
    final second = refresh.onRefresh();
    await _flush(tester);
    expect(blocks, 3);
    expect(reads.statusReads, 3);
    expect(seenBlocks, everyElement(same(block)));
    expect(
      tester
          .widget<ProposalVoteActions>(find.byType(ProposalVoteActions))
          .canVote,
      isFalse,
    );
    pending.completeError(StateError('synthetic refresh failure'));
    await Future.wait([first, second]);
    await _flush(tester);
    await tester.pumpAndSettle();
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('委员'), findsOneWidget);
    expect(
      tester
          .widget<ProposalVoteActions>(find.byType(ProposalVoteActions))
          .canVote,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('多签详情直接点投票，连点只校验一次，取消和已投票均不提交', (tester) async {
    final opened = await openTestSdk();
    addTearDown(() async {
      await opened.sdk.close();
      await opened.fixture.dispose();
    });
    final wallet = testCitizenWalletState().accounts.first;
    final institution = kNrc.first;
    final reads = _DetailReads(wallet.accountId);
    final id = BigInt.from(60002);
    final detail = ProposalDetailSnapshot(
      proposalId: id, proposalKind: 'transfer', status: 0, updatedAt: 1,
    );
    await tester.runAsync(() => ProposalDetailLocalStore.instance.put(detail));
    var roleChecks = 0;
    final gate = Completer<void>();
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: opened.sdk,
        child: MaterialApp(home: MultisigTransferDetailPage(
          institution: institution, proposalId: id,
          proposalContext: ProposalContext(institution: institution),
          resolveVoteContext: () async {
            roleChecks++;
            await gate.future;
            return ProposalContext(institution: institution, adminWallets: [wallet], role: ProposalRole.admin);
          },
          readBlock: (_) async => CitizenBlockRef(
            hash: '0x${'11' * 32}', number: BigInt.one,
            finality: CitizenBlockFinality.finalized,
          ),
          readService: (_) => reads,
        )),
      ),
    );
    await _flush(tester);
    expect(roleChecks, 0);
    final approve = find.widgetWithText(ElevatedButton, '赞成');
    final reject = find.widgetWithText(ElevatedButton, '反对');
    await tester.tap(approve);
    await tester.tap(reject);
    gate.complete();
    await _flush(tester);
    expect(roleChecks, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await _flush(tester);
    expect(find.byType(AlertDialog), findsNothing);
    reads.alreadyVoted = true;
    await tester.tap(reject);
    await _flush(tester);
    expect(roleChecks, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('投票校验未通过'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('详情退出后的迟到成功不能写回快照或覆盖新页面', (tester) async {
    final opened = await openTestSdk();
    await tester.runAsync(() => UserIsar.instance.db());
    final wallet = testCitizenWalletState().accounts.first;
    final old = _DetailReads(wallet.accountId, roleName: '旧岗位');
    final next = _DetailReads(wallet.accountId, roleName: '新岗位');
    final block = CitizenBlockRef(
      hash: '0x${'11' * 32}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    Widget page(int id, _DetailReads reads) => Provider<CitizenSdk>.value(
      value: opened.sdk,
      child: MaterialApp(
        home: MultisigTransferDetailPage(
          key: ValueKey(id),
          institution: kNrc.first,
          proposalId: BigInt.from(id),
          proposalContext: ProposalContext(institution: kNrc.first),
          readBlock: (_) async => block,
          readService: (_) => reads,
        ),
      ),
    );
    await tester.pumpWidget(page(60002, old));
    await _flush(tester);
    await tester.pumpAndSettle();
    final pending = Completer<Map<String, bool?>>();
    old.pendingVotes = pending.future;
    final flight = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await _flush(tester);
    await tester.pumpWidget(page(60003, next));
    await _flush(tester);
    await tester.pumpAndSettle();
    pending.complete({old.ticket.ticketKey: true});
    await flight;
    await _flush(tester);
    await tester.pumpAndSettle();
    expect(find.text('新岗位'), findsOneWidget);
    expect(find.text('旧岗位'), findsNothing);
    final stored = await tester.runAsync(
      () => ProposalDetailLocalStore.instance.read(
        'transfer',
        BigInt.from(60002),
      ),
    );
    expect(stored!.adminVotes.values, everyElement(isNull));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('票据仅替换岗位名称，圆圈序号、单行地址、发起人和逐岗位状态保留', (tester) async {
    final account = '0x${'07' * 32}';
    final tickets = [
      for (final role in ['ROLE_A', 'ROLE_B'])
        EligibleVoterTicket(
          voterAccountId: account,
          cidNumber: 'CID',
          voterRoleCode: role,
          voterRoleName: '委员',
        ),
    ];
    final ss58 = citizenSs58FromAccountId(account);
    final address =
        '${ss58.substring(0, 6)}...${ss58.substring(ss58.length - 6)}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProposalAdminVoteList(
            admins: [account],
            voterTickets: tickets,
            adminVotes: {tickets.first.ticketKey: true},
            pendingPublicKeys: {tickets.last.ticketKey},
            proposerSs58: ss58,
          ),
        ),
      ),
    );
    expect(find.text('合格投票票据明细（共 2 票）'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(
        find.descendant(
          of: find.byType(CircleAvatar).at(i),
          matching: find.text('${i + 1}'),
        ),
        findsOneWidget,
      );
    }
    expect(find.text(address), findsNWidgets(2));
    expect(find.text('委员'), findsNWidgets(2));
    expect(find.text('ROLE_A'), findsNothing);
    expect(find.text('ROLE_B'), findsNothing);
    expect(find.text('发起人'), findsNWidgets(2));
    expect(find.text('赞成 ✓'), findsOneWidget);
    expect(find.text('投票中'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      final a = tester.getRect(find.text(address).at(i));
      final name = tester.getRect(find.text('委员').at(i));
      expect(a.right, lessThan(name.left));
      expect(a.center.dy, name.center.dy);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  _proposalReadinessTests();
  _proposalReadResultTests();
  _proposalDiagnosticsTests();
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
                    child: ProposalCardHeader(
                      subjectName: names.$1,
                      proposalNumber: '#123',
                      personal: true,
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
  test('个人多签上下文按规范执行账户去重批量取真实名称，机构CID仍优先', () async {
    final reads = TestChainReads();
    final admins = InstitutionAdminService(
      getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: reads.getFinalizedHead,
      getStorageKeysPaged: reads.getStorageKeysPaged,
      getStorageBatch: reads.getStorageBatch,
    );
    final requested = <List<String>>[];
    final id = '0x${'12' * 32}';
    var failNames = false;
    final resolver = ProposalContextResolver(
      adminService: admins,
      activationService: ActivationService(adminService: admins),
      getWalletState: () => testCitizenOperation(testCitizenWalletState),
      readNames: (ids) async {
        requested.add(ids.toList());
        if (failNames) throw StateError('synthetic name read failure');
        return {id: '家庭基金账户甲乙'};
      },
    );
    final bytes = List.filled(32, 0x12);
    final contexts = await resolver.resolveBatch(
      [null, null, kNrc.first.cidNumber],
      executionAccountIds: [bytes, bytes, bytes],
      internalCodeList: ['PMUL', 'pmul', 'PMUL'],
    );
    expect(requested, [
      [id],
    ]);
    expect(contexts[0].institution!.shortName, '家庭基金账户甲乙');
    expect(contexts[1].institution!.accountId, id);
    expect(contexts[2].institution!.cidNumber, kNrc.first.cidNumber);
    await resolver.resolveBatch(
      [kNrc.first.cidNumber],
      internalCodeList: ['NRC'],
    );
    expect(requested, hasLength(1));
    failNames = true;
    final unnamed = await resolver.resolveBatch(
      [null],
      executionAccountIds: [bytes],
      internalCodeList: ['PMUL'],
    );
    expect(unnamed.single.institution!.shortName, isEmpty);
    expect(unnamed.single.institution!.accountId, id);
  });
  for (final shortName in ['国储委', '合成机构的特别长简称用于验证卡片宽度约束', '']) {
    testWidgets('提案卡片简称在编号左侧且窄屏大字号不遮挡状态：$shortName', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final fullName = List.filled(12, '合成机构全称').join();

      final feed = _PageFeed()
        ..details = (_) async => [
          ProposalWithDetail(
            meta: ProposalMeta(
              proposalId: BigInt.one,
              kind: 1,
              stage: 1,
              status: 0,
              internalCode: 'NRC',
              actorCidNumber: kNrc.first.cidNumber,
              displayMeta: ProposalDisplayMeta(
                year: 4294967295,
                seqInYear: BigInt.parse('18446744073709551615'),
              ),
            ),
          ),
        ];
      final known = kNrc.first.copyWith(
        fullName: fullName,
        shortName: shortName,
      );
      final directory = await buildSeededRepo(
        provinceOrder: const [],
        institutions: const [],
      );
      await _openProposal(
        tester,
        feed,
        <int>[],
        repository: _NamedProposalRepository(directory, known),
      );
      final number = find.text('429496729518446744073709551615');
      final status = find.text('投票中');
      expect(number, findsOneWidget);
      expect(status, findsOneWidget);
      expect(find.text(fullName), findsNothing);
      if (shortName.isNotEmpty) {
        final name = find.text(shortName);
        expect(name, findsOneWidget);
        expect(
          tester.getRect(name).right,
          lessThan(tester.getRect(number).left),
        );
        expect(
          tester.getCenter(name).dy,
          closeTo(tester.getCenter(number).dy, 0.1),
        );
      }
      expect(
        tester.getRect(number).right,
        lessThan(tester.getRect(status).left),
      );
      expect(tester.getRect(status).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('提案尾部只在实际分页读取期间显示转圈', (tester) async {
    final feed = _PageFeed()
      ..ids = List<int>.generate(11, (index) => index + 1);
    await _openProposal(tester, feed, <int>[]);
    expect(feed.forced, [false]);
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsNothing,
    );
  });
  testWidgets('提案合法空索引成功为空，不显示链不可用或错误', (tester) async {
    final feed = _PageFeed()..ids = [];
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    expect(feed.forced, [false]);
    expect(counts, [0]);
    expect(find.text('加载失败'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('首次提案失败后按钮重试首次同步，成功后清除错误', (tester) async {
    final feed = _PageFeed()..scopes.add(() => throw StateError('合成首次读取失败'));
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    expect(find.text('提案读取失败，请重试'), findsOneWidget);
    expect(counts, isEmpty);
    await tester.tap(find.text('重试'));
    for (var i = 0; i < 8 && counts.isEmpty; i++) {
      await _flush(tester);
    }
    expect(feed.forced, [false, false]);
    expect(find.text('2026000001'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(counts.last, 0);
  });
  testWidgets('专用提案详情只读本机并显示最终区块投票增量', (tester) async {
    final cid = kNrc.first.cidNumber;
    final feed = _PageFeed()
      ..details = (_) async => [
        ProposalWithDetail(
          meta: ProposalMeta(
            proposalId: BigInt.one,
            kind: 1,
            stage: 1,
            status: 0,
            internalCode: 'NRC',
            actorCidNumber: cid,
            displayMeta: ProposalDisplayMeta(year: 2026, seqInYear: BigInt.one),
          ),
          runtimeUpgradeDetail: RuntimeUpgradeProposalInfo(
            proposalId: BigInt.one,
            actorCidNumber: cid,
            proposer: '',
            reason: '已保存的升级理由',
            codeHashHex: '0x${'11' * 32}',
            expectedPowParamsHashHex: '0x${'22' * 32}',
            paramsVersion: 1,
            algorithmVersion: 1,
            targetBlockTimeMs: 360000,
            adjustmentInterval: 10,
            maxAdjustUpFactor: 4,
            maxAdjustDownDivisor: 4,
          ),
        ),
      ];
    final query = _FeedVoteQuery();
    final resolver = _PageContext()..failure = StateError('票据链查询失败');
    final transport = await _openProposal(tester, feed, <int>[], query: query, resolver: resolver);
    final local = await tester.runAsync(
      () => ProposalLocalStore.instance.readFeed(
        ProposalLocalStore.feedKey('test-chain', null),
      ),
    );
    expect(local?.ids, [BigInt.one]);
    feed.details = (_) async => throw StateError('浏览详情发起了链读取');
    await tester.tap(find.text('2026000001'));
    await _flush(tester);
    expect(find.byType(RuntimeUpgradeDetailPage), findsOneWidget);
    expect(find.textContaining('本机记录已不可用'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('赞成 3 票 / 通过阈值'), findsOneWidget);
    expect(find.text('准备投票'), findsNothing);
    expect(resolver.voteChecks, 0);
    await tester.tap(find.widgetWithText(ElevatedButton, '赞成'));
    await _flush(tester);
    expect(resolver.voteChecks, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('赞成 3 票 / 通过阈值'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '反对'));
    await _flush(tester);
    expect(resolver.voteChecks, 2);
    expect(find.byType(AlertDialog), findsNothing);
    query.voteOnly = true;
    transport.finalized(2);
    for (var i = 0; i < 8; i++) {
      if (find.textContaining('赞成 4 票 / 通过阈值').evaluate().isNotEmpty) break;
      await _flush(tester);
    }
    expect(find.textContaining('赞成 4 票 / 通过阈值'), findsOneWidget);
    await tester.pageBack();
    await _flush(tester);
    expect(find.text('2026000001'), findsOneWidget);
    expect(query.metaReads, 0);
    expect(feed.forced, [false]);
  });

  testWidgets('立法阶段推进从对应最终块更新已持久化的机构码和阶段', (tester) async {
    final query = _FeedVoteQuery()
      ..eventOverride = const [
        CitizenSystemEvent(
          eventIndex: 0, extrinsicIndex: 0,
          pallet: 'LegislationVote', name: 'LegislationAdvancedToSign',
          fields: {'proposal_id': '1'},
        ),
      ]
      ..metaOverride = ProposalMeta(
        proposalId: BigInt.one, kind: 2, stage: 12, status: 0, internalCode: 'NLG',
      );
    final feed = _PageFeed()..details = (_) async => [
      ProposalWithDetail(meta: ProposalMeta(
        proposalId: BigInt.one, kind: 2, stage: 10, status: 0, internalCode: 'NRC',
      )),
    ];
    final transport = await _openProposal(tester, feed, <int>[], query: query);
    transport.finalized(2);
    List<LocalProposalSummary> rows = [];
    for (var i = 0; i < 8; i++) {
      rows = await _drainRead(tester, ProposalLocalStore.instance.readSummariesForIds([BigInt.one]));
      if (rows.single.stage == 12) break;
      await _flush(tester);
    }
    expect(rows.single.stage, 12);
    expect(rows.single.internalCode, 'NLG');
    expect(query.metaReads, 1);
    expect(feed.retries, isEmpty);
  });

  testWidgets('同一最终区块的提案状态只更新一次，终态仍显示', (tester) async {
    final query = _FeedVoteQuery();
    final feed = _PageFeed();
    final transport = await _openProposal(tester, feed, <int>[], query: query);
    feed.details = (_) async => throw StateError('事件重读全部详情');
    transport.finalized(2);
    for (var i = 0; i < 8 && find.text('已执行').evaluate().isEmpty; i++) {
      await _flush(tester);
    }
    expect(find.text('已执行'), findsOneWidget);
    expect(find.text('2026000001'), findsOneWidget);
    transport.finalized(2);
    await _flush(tester);
    expect(query.eventsRead, 1);
    expect(query.metaReads, 1);
    expect(feed.forced, [false]);
  });

  testWidgets('终态保留，核验失败不删除，确认链上不存在才移除', (tester) async {
    final query = _FeedDeletionQuery();
    final feed = _PageFeed()
      ..details = (_) async => [
        ProposalWithDetail(
          meta: ProposalMeta(
            proposalId: BigInt.one,
            kind: 0,
            stage: 0,
            status: 3,
            internalCode: 'NRC',
            displayMeta: ProposalDisplayMeta(year: 2026, seqInYear: BigInt.one),
          ),
        ),
      ];
    final transport = await _openProposal(
      tester,
      feed,
      <int>[],
      height: 239,
      query: query,
    );
    expect(find.text('2026000001'), findsOneWidget);
    transport.finalized(240);
    for (var i = 0; i < 8 && query.checks == 0; i++) {
      await _flush(tester);
    }
    expect(query.checks, 1);
    expect(find.text('2026000001'), findsOneWidget);
    transport.finalized(241);
    for (var i = 0; i < 8 && !query.processed.contains(BigInt.from(241)); i++) {
      await _flush(tester);
    }
    final advanced = await _drainRead(tester, ProposalLocalStore.instance.readFeed(
      ProposalLocalStore.feedKey('test-chain', null),
    ));
    expect(advanced?.finalizedHeight, BigInt.from(241));
    expect(find.text('2026000001'), findsOneWidget);
    query.fail = false;
    transport.finalized(241);
    for (
      var i = 0;
      i < 8 && find.text('2026000001').evaluate().isNotEmpty;
      i++
    ) {
      await _flush(tester);
    }
    expect(query.checks, greaterThanOrEqualTo(2));
    expect(find.text('2026000001'), findsNothing);
    expect(feed.forced, [false]);
  });

  testWidgets('恢复链读取无需新通知即可补齐，并重试失败的中间块', (tester) async {
    var height = 1;
    var fail = true;
    CitizenBlockRef at(BigInt number) => CitizenBlockRef(
      hash: '0x${'11' * 32}', number: number,
      finality: CitizenBlockFinality.finalized,
    );
    final query = _FeedVoteQuery();
    final calls = <BigInt>[];
    final transport = await _openProposal(
      tester, _PageFeed(), <int>[], query: query,
      headReader: () async => at(BigInt.from(height)),
      blockReader: (number) async {
        calls.add(number);
        if (fail) {
          fail = false;
          throw StateError('首次历史块暂时不可用');
        }
        return at(number);
      },
    );
    transport.capability(isReady: false, why: CitizenCapabilityReason.chainUnsynced);
    await tester.pump();
    height = 3;
    transport.capability(isReady: true);
    for (var i = 0; i < 8 && query.eventsRead < 2; i++) {
      await _flush(tester);
    }
    final store = ProposalLocalStore.instance;
    final key = ProposalLocalStore.feedKey('test-chain', null);
    ProposalLocalIndex? index;
    for (var i = 0; i < 8; i++) {
      index = await _drainRead(tester, store.readFeed(key));
      if (index?.finalizedHeight == BigInt.from(3)) break;
      await _flush(tester);
    }
    expect(calls, [BigInt.from(2), BigInt.from(2)]);
    expect(index?.finalizedHeight, BigInt.from(3));
    expect(query.eventsRead, 2);
  });

  testWidgets('正文读取失败持久化待补标记，重开只查询该条', (tester) async {
    final feed = _PageFeed()..ids = [2, 1];
    feed.failedBodies.add(BigInt.one);
    await _openProposal(tester, feed, <int>[]);
    final store = ProposalLocalStore.instance;
    final pending = await _drainRead(tester, store.readSummariesForIds([BigInt.one, BigInt.from(2)]));
    expect(pending.map((item) => item.detailPending), [true, false]);
    await tester.pumpWidget(const SizedBox.shrink());
    feed.failedBodies.clear();
    await _openProposal(tester, feed, <int>[]);
    for (var i = 0; i < 8; i++) {
      final saved = await _drainRead(tester, store.readSummariesForIds([BigInt.one]));
      if (saved.single.detailPending == false) break;
      await _flush(tester);
    }
    final saved = await _drainRead(tester, store.readSummariesForIds([BigInt.one]));
    expect(saved.single.detailPending, false);
    expect(feed.retries, isNotEmpty);
    expect(feed.retries.every((ids) => ids.length == 1 && ids.single == BigInt.one), true);
    expect(feed.forced, [false]);
  });

  testWidgets('下拉与重开复用本机提案，不重新读取年度索引或详情', (tester) async {
    final feed = _PageFeed();
    await _openProposal(tester, feed, <int>[]);
    feed.scopes.add(() => throw StateError('重复读取索引'));
    feed.details = (_) async => throw StateError('重复读取详情');
    unawaited(_refreshProposal(tester));
    await _flush(tester);
    expect(find.text('2026000001'), findsOneWidget);
    expect(feed.forced, [false]);
    await tester.pumpWidget(const SizedBox.shrink());
    await _openProposal(tester, feed, <int>[]);
    expect(find.text('2026000001'), findsOneWidget);
    expect(feed.forced, [false]);
  });

  testWidgets('翻页读取持久化列表，首批同步后无链查询', (tester) async {
    final feed = _PageFeed()..ids = List.generate(11, (i) => 11 - i);
    await _openProposal(tester, feed, <int>[]);
    feed.details = (_) async => throw StateError('翻页重复读取详情');
    final list = tester.widget<ListView>(find.byType(ListView));
    for (var i = 0; i < 8 && find.text('2026000001').evaluate().isEmpty; i++) {
      final position = list.controller!.position;
      list.controller!.jumpTo(0);
      list.controller!.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await _flush(tester);
    }
    expect(find.text('2026000001'), findsOneWidget);
    expect(feed.forced, [false]);
  });

  List<int> compactU32(int value) {
    if (value < 64) return [value << 2];
    final v = (value << 2) | 1;
    return [v & 0xff, (v >> 8) & 0xff];
  }

  List<int> u128Le(BigInt value) {
    final bytes = List<int>.filled(16, 0);
    var remaining = value;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (remaining & BigInt.from(0xff)).toInt();
      remaining >>= 8;
    }
    return bytes;
  }

  List<int> u32Le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  List<int> u64Le(int value) =>
      List<int>.generate(8, (i) => (value >> (i * 8)) & 0xff);

  Uint8List institutionPayload({
    required List<int> institutionAccountId,
    required List<int> beneficiary,
    required BigInt amountFen,
    required String remark,
    required List<int> proposer,
  }) {
    const actorCidNumber = 'LN001-CGOVC-000000001-2026';
    final actorCidBytes = utf8.encode(actorCidNumber);
    final remarkBytes = utf8.encode(remark);
    final body = <int>[
      ...utf8.encode('multisig'),
      0x01, // actor_cid_number: Some
      ...compactU32(actorCidBytes.length),
      ...actorCidBytes,
      ...institutionAccountId,
      ...beneficiary,
      ...u128Le(amountFen),
      ...compactU32(remarkBytes.length),
      ...remarkBytes,
      ...proposer,
    ];
    return Uint8List.fromList([...compactU32(body.length), ...body]);
  }

  List<int> cid(String value) {
    final bytes = utf8.encode(value);
    return [...compactU32(bytes.length), ...bytes];
  }

  final service = (() {
    final reads0 = TestChainReads();
    final reads1 = TestTransactionCalls();
    return MultisigTransferService(
      buildCall: _buildCall,
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getFinalizedHead: reads0.getFinalizedHead,
      getStorageKeysPaged: reads0.getStorageKeysPaged,
      getStorage: reads0.getStorage,
      getStorageBatch: reads0.getStorageBatch,

      getSystemEvents: reads0.getSystemEvents,
      getRuntimeContext: reads0.getRuntimeContext,
      prepareTransaction: reads1.prepareTransaction,
      executePreparedTransaction: reads1.executePreparedTransaction,
      cancelPreparedTransactionExecution:
          reads1.cancelPreparedTransactionExecution,
      consumePreparedTransactionQrResponse:
          reads1.consumePreparedTransactionQrResponse,
    );
  })();

  test('机构 propose_transfer 当前 SCALE payload 的短备注必须可解码', () {
    final institutionAccountId = List<int>.filled(32, 0x11);
    final beneficiary = List<int>.filled(32, 0x22);
    final decoded = service.debugDecodeProposalData(
      BigInt.from(0),
      institutionPayload(
        institutionAccountId: institutionAccountId,
        beneficiary: beneficiary,
        amountFen: BigInt.from(10000000),
        remark: '转账测试',
        proposer: List<int>.filled(32, 0x33),
      ),
    );

    expect(decoded, isNotNull, reason: '短备注机构提案必须进入提案列表和详情页');
    expect(decoded!.actorCidNumber, 'LN001-CGOVC-000000001-2026');
    expect(decoded.institutionAccountId, institutionAccountId);
    expect(decoded.amountFen, BigInt.from(10000000)); // 100,000.00 元
    expect(decoded.remark, '转账测试');
    expect(decoded.beneficiary, citizenSs58FromAccountIdBytes(beneficiary));
  });

  test('机构 propose_transfer 当前 SCALE payload 的空备注必须可解码', () {
    final decoded = service.debugDecodeProposalData(
      BigInt.from(1),
      institutionPayload(
        institutionAccountId: List<int>.filled(32, 0x11),
        beneficiary: List<int>.filled(32, 0x22),
        amountFen: BigInt.zero,
        remark: '',
        proposer: List<int>.filled(32, 0x33),
      ),
    );

    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, 'LN001-CGOVC-000000001-2026');
    expect(decoded.remark, '');
  });

  test('截断 payload(不足下限)返回 null', () {
    final full = institutionPayload(
      institutionAccountId: List<int>.filled(32, 0x11),
      beneficiary: List<int>.filled(32, 0x22),
      amountFen: BigInt.zero,
      remark: '',
      proposer: List<int>.filled(32, 0x33),
    );
    final raw = Uint8List.fromList(full.sublist(0, full.length - 1));

    expect(service.debugDecodeProposalData(BigInt.from(2), raw), isNull);
  });

  test('MODULE_TAG 不符返回 null', () {
    final body = <int>[...'dq-xxxx'.codeUnits, ...List<int>.filled(114, 0x11)];
    final raw = Uint8List.fromList([...compactU32(body.length), ...body]);

    expect(service.debugDecodeProposalData(BigInt.from(3), raw), isNull);
  });

  test('SafetyFundAction 严格解码 actor CID、机构账户和 proposer', () async {
    const actorCidNumber = 'LN001-NRC0G-944805165-2026';
    final institutionAccountId = List<int>.filled(32, 0x41);
    final proposer = List<int>.filled(32, 0x43);
    final remark = utf8.encode('安全基金');
    final raw = Uint8List.fromList([
      ...cid(actorCidNumber),
      ...institutionAccountId,
      ...List<int>.filled(32, 0x42),
      ...u128Le(BigInt.from(500)),
      ...compactU32(remark.length),
      ...remark,
      ...proposer,
    ]);
    final decoded = await (() {
      final reads0 = _RawStorageChain(raw);
      final reads1 = TestTransactionCalls();
      return MultisigTransferService(
        buildCall: _buildCall,
        getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorageKeysPaged: reads0.getStorageKeysPaged,
        getStorage: reads0.getStorage,
        getStorageBatch: reads0.getStorageBatch,

        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        prepareTransaction: reads1.prepareTransaction,
        executePreparedTransaction: reads1.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads1.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads1.consumePreparedTransactionQrResponse,
      );
    })().fetchSafetyFundAction(BigInt.from(4));

    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.institutionAccountId, institutionAccountId);
    expect(decoded.amountFen, BigInt.from(500));
    expect(decoded.proposer, citizenSs58FromAccountIdBytes(proposer));

    final trailing = Uint8List.fromList([...raw, 0]);
    expect(
      await (() {
        final reads0 = _RawStorageChain(trailing);
        final reads1 = TestTransactionCalls();
        return MultisigTransferService(
          buildCall: _buildCall,
          getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getFinalizedHead: reads0.getFinalizedHead,
          getStorageKeysPaged: reads0.getStorageKeysPaged,
          getStorage: reads0.getStorage,
          getStorageBatch: reads0.getStorageBatch,

          getSystemEvents: reads0.getSystemEvents,
          getRuntimeContext: reads0.getRuntimeContext,
          prepareTransaction: reads1.prepareTransaction,
          executePreparedTransaction: reads1.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              reads1.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              reads1.consumePreparedTransactionQrResponse,
        );
      })().fetchSafetyFundAction(BigInt.from(4)),
      isNull,
    );
  });

  test('SweepAction 完整消费 proposer，尾随字节必须拒绝', () async {
    const actorCidNumber = 'ZS001-PRB08-233384677-2026';
    final institutionAccountId = List<int>.filled(32, 0x51);
    final proposer = List<int>.filled(32, 0x52);
    final raw = Uint8List.fromList([
      ...cid(actorCidNumber),
      ...institutionAccountId,
      ...u128Le(BigInt.from(800)),
      ...proposer,
    ]);
    final decoded = await (() {
      final reads0 = _RawStorageChain(raw);
      final reads1 = TestTransactionCalls();
      return MultisigTransferService(
        buildCall: _buildCall,
        getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorageKeysPaged: reads0.getStorageKeysPaged,
        getStorage: reads0.getStorage,
        getStorageBatch: reads0.getStorageBatch,

        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        prepareTransaction: reads1.prepareTransaction,
        executePreparedTransaction: reads1.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads1.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads1.consumePreparedTransactionQrResponse,
      );
    })().fetchSweepAction(BigInt.from(5));

    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.institutionAccountId, institutionAccountId);
    expect(decoded.amountFen, BigInt.from(800));
    expect(decoded.proposer, citizenSs58FromAccountIdBytes(proposer));

    final trailing = Uint8List.fromList([...raw, 0]);
    expect(
      await (() {
        final reads0 = _RawStorageChain(trailing);
        final reads1 = TestTransactionCalls();
        return MultisigTransferService(
          buildCall: _buildCall,
          getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
          getFinalizedHead: reads0.getFinalizedHead,
          getStorageKeysPaged: reads0.getStorageKeysPaged,
          getStorage: reads0.getStorage,
          getStorageBatch: reads0.getStorageBatch,

          getSystemEvents: reads0.getSystemEvents,
          getRuntimeContext: reads0.getRuntimeContext,
          prepareTransaction: reads1.prepareTransaction,
          executePreparedTransaction: reads1.executePreparedTransaction,
          cancelPreparedTransactionExecution:
              reads1.cancelPreparedTransactionExecution,
          consumePreparedTransactionQrResponse:
              reads1.consumePreparedTransactionQrResponse,
        );
      })().fetchSweepAction(BigInt.from(5)),
      isNull,
    );
  });

  test('VotingEngine Proposal 元数据严格按 CID 主体完整解码', () {
    const actorCidNumber = 'LN001-CGOVC-000000001-2026';
    const subjectCidNumber = 'LN001-CGOVC-000000002-2026';
    final executionAccountId = List<int>.filled(32, 0x61);
    final raw = Uint8List.fromList([
      0, 0, 0, // kind / stage / status
      1, ...utf8.encode('CGOV'), // internal_code Some
      1, ...cid(actorCidNumber), // actor CID Some
      1, ...executionAccountId, // execution account Some
      4, ...cid(subjectCidNumber), // subject CID Vec len=1
      ...u32Le(10),
      ...u32Le(20),
    ]);
    final decoded = service.debugDecodeProposalMeta(BigInt.from(6), raw);
    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.executionAccountId, executionAccountId);
    expect(decoded.subjectCidNumbers, [subjectCidNumber]);

    expect(
      service.debugDecodeProposalMeta(
        BigInt.from(6),
        Uint8List.fromList([...raw, 0]),
      ),
      isNull,
    );
    final invalidOption = Uint8List.fromList(raw)..[3] = 2;
    expect(
      service.debugDecodeProposalMeta(BigInt.from(6), invalidOption),
      isNull,
    );
  });

  test('ProposalSubject 唯一编码严格区分机构 CID 与个人多签账户', () {
    const peerCid = 'LN001-CGOVC-000000001-2026';
    final institution = InstitutionInfo(
      fullName: '测试机构',
      shortName: '测试机构',
      cidFullNameEn: 'Test Institution',
      cidShortNameEn: 'TI',
      cidNumber: peerCid,
      orgType: OrgType.institution,
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'11' * 32}',
        feeAccountId: '0x${'22' * 32}',
      ),
    );
    final institutionKey = ProposalQueryService.proposalSubjectKey(institution);
    expect(institutionKey.first, 0);
    expect(institutionKey[1], utf8.encode(peerCid).length << 2);
    expect(utf8.decode(institutionKey.sublist(2)), peerCid);

    final personalAccount = '0x${'ab' * 32}';
    final personal = InstitutionInfo(
      fullName: '个人多签',
      shortName: '个人多签',
      cidFullNameEn: 'Personal Multisig',
      cidShortNameEn: 'PMUL',
      cidNumber: 'personal-account:$personalAccount',
      orgType: OrgType.personalMultisig,
      accountId: personalAccount,
    );
    final personalKey = ProposalQueryService.proposalSubjectKey(personal);
    expect(personalKey, Uint8List.fromList([1, ...List.filled(32, 0xab)]));
  });

  test('投票引擎主体索引和管理员快照必须完整消费 SCALE 字节', () {
    final adminsRaw = Uint8List.fromList([
      8, // Compact(2)
      ...List.filled(32, 0x11),
      ...List.filled(32, 0x22),
    ]);
    expect(ProposalQueryService.decodeAdminSnapshot(adminsRaw), [
      '0x${'11' * 32}',
      '0x${'22' * 32}',
    ]);
    expect(
      ProposalQueryService.decodeAdminSnapshot(
        Uint8List.fromList([...adminsRaw, 0]),
      ),
      isNull,
    );

    final activeRaw = Uint8List.fromList([
      8, // Compact(2)
      ...u64Le(7), ...List.filled(8, 0),
      ...u64Le(9), ...List.filled(8, 0),
    ]);
    expect(ProposalQueryService.decodeActiveProposalIds(activeRaw), [
      BigInt.from(7),
      BigInt.from(9),
    ]);
    expect(
      ProposalQueryService.decodeActiveProposalIds(
        Uint8List.fromList([...activeRaw, 0]),
      ),
      isNull,
    );
  });

  test('机构按完整岗位主体读取选民快照，个人多签读取管理员快照', () async {
    final raw = Uint8List.fromList([
      4, // Compact(1)
      ...List.filled(32, 0x33),
    ]);
    final rpc = _RawStorageChain(raw);
    final query = ProposalQueryService(
      getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
      getSystemEvents: rpc.getSystemEvents,
      getRuntimeContext: rpc.getRuntimeContext,
      getFinalizedHead: rpc.getFinalizedHead,
      getStorage: rpc.getStorage,
      getStorageBatch: rpc.getStorageBatch,
    );
    final institution = InstitutionInfo(
      fullName: '测试机构',
      shortName: '测试机构',
      cidFullNameEn: 'Test Institution',
      cidShortNameEn: 'TI',
      cidNumber: 'LN001-CGOVC-000000001-2026',
      orgType: OrgType.institution,
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'11' * 32}',
        feeAccountId: '0x${'22' * 32}',
      ),
    );
    final personalAccount = '0x${'ab' * 32}';
    final personal = InstitutionInfo(
      fullName: '个人多签',
      shortName: '个人多签',
      cidFullNameEn: 'Personal Multisig',
      cidShortNameEn: 'PMUL',
      cidNumber: 'personal-account:$personalAccount',
      orgType: OrgType.personalMultisig,
      accountId: personalAccount,
    );

    expect(
      await query.fetchRoleVoterSnapshot(
        BigInt.from(7),
        institution.cidNumber,
        'COMMITTEE_MEMBER',
      ),
      ['0x${'33' * 32}'],
    );
    expect(await query.fetchEligibleVoterSnapshot(BigInt.from(7), personal), [
      '0x${'33' * 32}',
    ]);
    expect(rpc.storageKeys, hasLength(2));
    expect(rpc.storageKeys[0], isNot(rpc.storageKeys[1]));
  });

  test('公民提案流按默认机构码和订阅机构 CID 合并过滤', () {
    Uint8List accountIdBytes(int seed) =>
        Uint8List.fromList(List<int>.filled(32, seed));

    ProposalWithDetail proposal(
      int id, {
      required String code,
      required Uint8List institution,
      List<String> subjectCidNumbers = const [],
    }) {
      return ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: BigInt.from(id),
          kind: 0,
          stage: 0,
          status: 0,
          internalCode: code,
          actorCidNumber: subjectCidNumbers.isEmpty
              ? null
              : subjectCidNumbers.first,
          executionAccountId: institution,
          subjectCidNumbers: subjectCidNumbers,
        ),
      );
    }

    const subscribedCid = 'LN001-CGOVC-000000001-2026';
    const ignoredSameCodeCid = 'LN001-CGOVC-000000002-2026';
    final ids = service.filterCitizenProposalFeedIds(
      [
        proposal(1, code: 'NRC', institution: accountIdBytes(0x11)),
        proposal(2, code: 'PRC', institution: accountIdBytes(0x22)),
        proposal(3, code: 'PRB', institution: accountIdBytes(0x33)),
        proposal(
          4,
          code: 'CGOV',
          institution: accountIdBytes(0x44),
          subjectCidNumbers: const [subscribedCid],
        ),
        proposal(
          5,
          code: 'CGOV',
          institution: accountIdBytes(0x45),
          subjectCidNumbers: const [ignoredSameCodeCid],
        ),
        proposal(6, code: 'PRS', institution: accountIdBytes(0x66)),
      ],
      defaultCodes: const {
        'NRC',
        'NLG',
        'NSN',
        'NRP',
        'NED',
        'NJD',
        'NSP',
        'PRS',
      },
      subscribedInstitutionCidNumbers: const {subscribedCid},
    );

    expect(ids, [6, 4, 1].map(BigInt.from).toList());
  });
}

/// 能力等待仍走真实页面/SDK事件，未就绪不得提前触发Feed或另启SDK。
void _proposalReadinessTests() {
  for (final reason in [
    CitizenCapabilityReason.engineNotRunning,
    CitizenCapabilityReason.dependencyNotReady,
    CitizenCapabilityReason.chainStarting,
    CitizenCapabilityReason.chainUnsynced,
  ]) {
    testWidgets('提案等待${reason.name}，就绪事件只触发一次原首读', (tester) async {
      final transport = _PageReads()
        ..ready = false
        ..reason = reason;
      final feed = _PageFeed();
      final counts = <int>[];
      await _openProposal(
        tester,
        feed,
        counts,
        transportOverride: transport,
        waitForTerminal: false,
      );
      await _flush(tester);
      expect(feed.forced, isEmpty);
      expect(counts, isEmpty);
      expect(find.text('提案读取失败，请重试'), findsNothing);
      transport.capability(isReady: false, why: reason);
      transport.finalized();
      await _flush(tester);
      expect(feed.forced, isEmpty);
      transport.capability(isReady: true);
      transport.capability(isReady: true);
      await _flush(tester);
      for (var i = 0; i < 8 && counts.isEmpty; i++) {
        await _flush(tester);
      }
      expect(feed.forced, [false]);
      expect(counts, [0]);
      expect(transport.calls, isNot(contains('start')));
    });
  }
  testWidgets('轻节点暂不可用时下拉仍从本机读取', (tester) async {
    final feed = _PageFeed();
    final transport = await _openProposal(tester, feed, <int>[]);
    transport.capability(
      isReady: false,
      why: CitizenCapabilityReason.chainUnsynced,
    );
    unawaited(_refreshProposal(tester));
    unawaited(_refreshProposal(tester));
    await _flush(tester);
    expect(find.text('2026000001'), findsOneWidget);
    expect(feed.forced, [false]);
  });
  testWidgets('启动失败立即沿原错误页收尾，不永久等待或伪造空成功', (tester) async {
    final transport = _PageReads()
      ..ready = false
      ..reason = CitizenCapabilityReason.chainStarting;
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(
      tester,
      feed,
      counts,
      transportOverride: transport,
      waitForTerminal: false,
    );
    await _flush(tester);
    transport.lifecycle('startFailed');
    await _flush(tester);
    expect(find.text('提案读取失败，请重试'), findsOneWidget);
    expect(feed.forced, isEmpty);
    expect(counts, isEmpty);
  });
  testWidgets('能力不可用不是启动等待，必须保留失败', (tester) async {
    final transport = _PageReads()
      ..ready = false
      ..reason = CitizenCapabilityReason.storageUnavailable;
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(tester, feed, counts, transportOverride: transport);
    expect(find.text('提案读取失败，请重试'), findsOneWidget);
    expect(feed.forced, isEmpty);
    expect(counts, isEmpty);
  });
  for (final code in [
    CitizenSdkErrorCode.decode,
    CitizenSdkErrorCode.network,
  ]) {
    testWidgets('就绪后的真实${code.name}仍失败，不自动重试或改为空列表', (tester) async {
      final feed = _PageFeed()
        ..scopes.add(
          () => throw CitizenSdkException(code: code, message: '合成读取失败'),
        );
      final counts = <int>[];
      final transport = await _openProposal(tester, feed, counts);
      transport.capability(isReady: true);
      await _flush(tester);
      expect(find.text('提案读取失败，请重试'), findsOneWidget);
      expect(feed.forced, [false]);
      expect(counts, isEmpty);
    });
  }
  testWidgets('销毁等待页后就绪事件不得复活旧读取', (tester) async {
    final transport = _PageReads()
      ..ready = false
      ..reason = CitizenCapabilityReason.chainStarting;
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(
      tester,
      feed,
      counts,
      transportOverride: transport,
      waitForTerminal: false,
    );
    await _flush(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    transport.capability(isReady: true);
    await _flush(tester);
    expect(feed.forced, isEmpty);
    expect(counts, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('能力事件先于旧快照返回也不会丢失就绪唤醒', (tester) async {
    final transport = _PageReads()
      ..ready = false
      ..reason = CitizenCapabilityReason.chainStarting;
    final oldSnapshot = transport.capabilities();
    final gate = Completer<CitizenCapabilitySnapshot>();
    var first = true;
    transport.snapshotReader = () {
      if (first) {
        first = false;
        return gate.future;
      }
      return Future.value(transport.capabilities());
    };
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(
      tester,
      feed,
      counts,
      transportOverride: transport,
      waitForTerminal: false,
    );
    await _flush(tester);
    transport.capability(isReady: true);
    gate.complete(oldSnapshot);
    await _flush(tester);
    expect(feed.forced, [false]);
    for (var i = 0; i < 8 && counts.isEmpty; i++) {
      await _flush(tester);
    }
    expect(counts, [0]);
  });
  testWidgets('旧ready快照迟到不得覆盖最新未同步事实', (tester) async {
    final transport = _PageReads();
    final oldReady = transport.capabilities();
    final gate = Completer<CitizenCapabilitySnapshot>();
    var first = true;
    transport.snapshotReader = () {
      if (first) {
        first = false;
        return gate.future;
      }
      return Future.value(transport.capabilities());
    };
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(
      tester,
      feed,
      counts,
      transportOverride: transport,
      waitForTerminal: false,
    );
    await _flush(tester);
    transport.capability(
      isReady: false,
      why: CitizenCapabilityReason.chainUnsynced,
    );
    await tester.pump();
    gate.complete(oldReady);
    await _flush(tester);
    expect(feed.forced, isEmpty);
    expect(counts, isEmpty);
    transport.capability(isReady: true);
    await _flush(tester);
    expect(feed.forced, [false]);
    for (var i = 0; i < 8 && counts.isEmpty; i++) {
      await _flush(tester);
    }
    expect(counts, [0]);
  });
}

/// 日志仅收集固定安全事件；夹具正文均为合成，不替代真实链读取成功。
Future<T> _captureProposal<T>(
  List<String> lines,
  Future<T> Function() action,
) => runZoned(
  action,
  zoneSpecification: ZoneSpecification(
    print: (_, _, _, line) {
      if (line.startsWith('[CitizenFailure]')) lines.add(line);
    },
  ),
);

void _proposalDiagnosticsTests() {
  for (final stage in ['year', 'index', 'details']) {
    test('真实Feed/Service在$stage失败仍抛原SDK异常且不泄漏正文', () async {
      MultisigTransferProposalAdapter.clearCache();
      ProposalCache.clear();
      final failure = CitizenSdkException(
        code: stage == 'year'
            ? CitizenSdkErrorCode.notReady
            : stage == 'index'
            ? CitizenSdkErrorCode.network
            : CitizenSdkErrorCode.decode,
        message: 'synthetic private proposal detail',
        method: 'synthetic private method',
        sessionId: 'synthetic private session',
      );
      final chain = _ProposalChain(
        failureAt: stage,
        failure: failure,
        hasIndex: true,
      );
      final feed = MultisigTransferProposalFeed(
        service: (() {
          final reads0 = TestTransactionCalls();
          return MultisigTransferService(
            buildCall: _buildCall,
            getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: chain.getFinalizedHead,
            getStorageKeysPaged: chain.getStorageKeysPaged,
            getStorage: chain.getStorage,
            getStorageBatch: chain.getStorageBatch,

            getSystemEvents: chain.getSystemEvents,
            getRuntimeContext: chain.getRuntimeContext,
            prepareTransaction: reads0.prepareTransaction,
            executePreparedTransaction: reads0.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                reads0.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                reads0.consumePreparedTransactionQrResponse,
          );
        })(),
      );
      final lines = <String>[];
      await _captureProposal(lines, () async {
        await expectLater(
          feed.fetchCitizenProposalFeedIds(
            defaultCodes: {'NRC'},
            subscribedInstitutionCidNumbers: {},
            forceRefresh: true,
          ),
          throwsA(same(failure)),
        );
      });
      expect(
        chain.reads,
        stage == 'year'
            ? ['year']
            : stage == 'index'
            ? ['year', 'index']
            : ['year', 'index', 'details'],
      );
      expect(lines, [
        '[CitizenFailure] stage=proposal_$stage http=none code=sdk_${failure.code.name}',
      ]);
      expect(lines.join(), isNot(contains('synthetic private')));
      MultisigTransferProposalAdapter.clearCache();
      ProposalCache.clear();
    });
  }
  for (final missingYear in [true, false]) {
    test('真实Feed合法${missingYear ? '缺省年份' : '空索引'}不产生失败事件', () async {
      MultisigTransferProposalAdapter.clearCache();
      final chain = _ProposalChain(missingYear: missingYear);
      final feed = MultisigTransferProposalFeed(
        service: (() {
          final reads0 = TestTransactionCalls();
          return MultisigTransferService(
            buildCall: _buildCall,
            getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
            getFinalizedHead: chain.getFinalizedHead,
            getStorageKeysPaged: chain.getStorageKeysPaged,
            getStorage: chain.getStorage,
            getStorageBatch: chain.getStorageBatch,

            getSystemEvents: chain.getSystemEvents,
            getRuntimeContext: chain.getRuntimeContext,
            prepareTransaction: reads0.prepareTransaction,
            executePreparedTransaction: reads0.executePreparedTransaction,
            cancelPreparedTransactionExecution:
                reads0.cancelPreparedTransactionExecution,
            consumePreparedTransactionQrResponse:
                reads0.consumePreparedTransactionQrResponse,
          );
        })(),
      );
      final lines = <String>[];
      final ids = await _captureProposal(
        lines,
        () => feed.fetchCitizenProposalFeedIds(
          defaultCodes: {'NRC'},
          subscribedInstitutionCidNumbers: {},
          forceRefresh: true,
        ),
      );
      expect(ids, isEmpty);
      expect(chain.reads, missingYear ? ['year'] : ['year', 'index']);
      expect(lines, isEmpty);
      MultisigTransferProposalAdapter.clearCache();
    });
  }
  test('日志出口抛错不替换原链读异常及堆栈', () async {
    final failure = StateError('synthetic private source');
    final service = (() {
      final reads0 = _ProposalChain(failureAt: 'year', failure: failure);
      final reads1 = TestTransactionCalls();
      return MultisigTransferService(
        buildCall: _buildCall,
        getStorageRuntimeContext: CitizenSdkTestFixture.runtimeContext,
        getFinalizedHead: reads0.getFinalizedHead,
        getStorageKeysPaged: reads0.getStorageKeysPaged,
        getStorage: reads0.getStorage,
        getStorageBatch: reads0.getStorageBatch,

        getSystemEvents: reads0.getSystemEvents,
        getRuntimeContext: reads0.getRuntimeContext,
        prepareTransaction: reads1.prepareTransaction,
        executePreparedTransaction: reads1.executePreparedTransaction,
        cancelPreparedTransactionExecution:
            reads1.cancelPreparedTransactionExecution,
        consumePreparedTransactionQrResponse:
            reads1.consumePreparedTransactionQrResponse,
      );
    })();
    await runZoned(
      () async {
        try {
          await service.fetchCurrentYearProposals();
          fail('必须继续抛出原异常');
        } catch (error, stack) {
          expect(error, same(failure));
          expect(stack.toString(), contains('_ProposalChain.getStorage'));
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError('synthetic sink failure'),
      ),
    );
  });
  for (final stage in ['feed', 'details']) {
    testWidgets('页面$stage失败保留错误/重试且仅报告固定阶段', (tester) async {
      final feed = _PageFeed();
      final failure = StateError('synthetic private page detail');
      if (stage == 'feed') feed.scopes.add(() => throw failure);
      if (stage == 'details') feed.details = (_) async => throw failure;
      final counts = <int>[];
      final lines = <String>[];
      await _captureProposal(
        lines,
        () => _openProposal(
          tester,
          feed,
          counts,
        ),
      );
      expect(find.text('提案读取失败，请重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(counts, isEmpty);
      expect(lines, [
        '[CitizenFailure] stage=proposal_feed http=none code=state',
      ]);
      expect(lines.join(), isNot(contains('synthetic private')));
    });
  }
  testWidgets('机构派生异常停在原错误页，不伪造空范围成功', (tester) async {
    final directory = await buildSeededRepo(
      provinceOrder: ['LN'],
      institutions: [
        seedDto(
          'LN001-CGOVC-000000001-2026',
          provinceCode: 'LN',
          cityCode: '001',
          code: 'NRC',
        ),
      ],
    );
    final lines = <String>[];
    final counts = <int>[];
    final feed = _PageFeed();
    await _captureProposal(
      lines,
      () => _openProposal(
        tester,
        feed,
        counts,
        repository: _FailingScopeRepository(directory: directory),
      ),
    );
    expect(find.text('提案读取失败，请重试'), findsOneWidget);
    expect(counts, isEmpty);
    expect(feed.forced, [false]);
    expect(lines, [
      '[CitizenFailure] stage=proposal_feed http=none code=state',
    ]);
  });
}

Future<T> _captureReadResult<T>(
  List<String> lines,
  Future<T> Function() action,
) => runZoned(
  action,
  zoneSpecification: ZoneSpecification(
    print: (_, _, _, line) {
      if (line.startsWith('[CitizenRead]')) lines.add(line);
    },
  ),
);

// 真实页面、公开SDK事件及原Feed夹具联合验证；不靠空白或骨架证明成功。
void _proposalReadResultTests() {
  const prefix = '[CitizenRead] stage=proposal_first state=';
  for (final empty in [true, false]) {
    testWidgets('当前提案首批真实完成才报告${empty ? '空索引' : '非空展示'}', (tester) async {
      final lines = <String>[];
      await _captureReadResult(lines, () async {
        final feed = _PageFeed()..ids = empty ? [] : [1];
        final counts = <int>[];
        await _openProposal(tester, feed, counts);
        expect(lines, [
          '${prefix}started',
          '$prefix${empty ? 'empty' : 'nonempty'}',
        ]);
        expect(counts, [0]);
      });
    });
  }
  testWidgets('等待读链只报waiting，就绪后沿原读取报完成', (tester) async {
    final lines = <String>[];
    await _captureReadResult(lines, () async {
      final transport = _PageReads()
        ..ready = false
        ..reason = CitizenCapabilityReason.chainUnsynced;
      final feed = _PageFeed()..ids = [];
      final counts = <int>[];
      await _openProposal(
        tester,
        feed,
        counts,
        transportOverride: transport,
        waitForTerminal: false,
      );
      await _flush(tester);
      transport.capability(
        isReady: false,
        why: CitizenCapabilityReason.chainUnsynced,
      );
      await _flush(tester);
      expect(lines, ['${prefix}waiting']);
      expect(feed.forced, isEmpty);
      transport.capability(isReady: true);
      await _flush(tester);
      expect(lines, ['${prefix}waiting', '${prefix}started', '${prefix}empty']);
      expect(feed.forced, [false]);
    });
  });
  for (final code in [
    CitizenSdkErrorCode.decode,
    CitizenSdkErrorCode.network,
  ]) {
    testWidgets('提案真实${code.name}失败不产生成功回执', (tester) async {
      final lines = <String>[];
      await _captureReadResult(lines, () async {
        final feed = _PageFeed()
          ..scopes.add(
            () => throw CitizenSdkException(
              code: code,
              message: 'synthetic private read error',
            ),
          );
        await _openProposal(tester, feed, <int>[]);
        expect(lines, ['${prefix}started']);
        expect(find.text('提案读取失败，请重试'), findsOneWidget);
      });
    });
  }
  for (final waiting in [true, false]) {
    testWidgets('提案${waiting ? '等待读链' : '读取中'}销毁后不报成功', (tester) async {
      final lines = <String>[];
      await _captureReadResult(lines, () async {
        final transport = _PageReads()
          ..ready = !waiting
          ..reason = waiting
              ? CitizenCapabilityReason.chainStarting
              : CitizenCapabilityReason.none;
        final lateRead = Completer<List<int>>();
        final feed = _PageFeed()..scopes.add(() => lateRead.future);
        await _openProposal(
          tester,
          feed,
          <int>[],
          transportOverride: transport,
          waitForTerminal: false,
        );
        await _flush(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        transport.capability(isReady: true);
        lateRead.complete([]);
        await _flush(tester);
        expect(lines, ['$prefix${waiting ? 'waiting' : 'started'}']);
        expect(tester.takeException(), isNull);
      });
    });
  }
  testWidgets('非空索引但详情缺失不能报成功空索引', (tester) async {
    final lines = <String>[];
    await _captureReadResult(lines, () async {
      final feed = _PageFeed()..details = (_) async => [];
      await _openProposal(tester, feed, <int>[]);
      expect(lines, ['${prefix}started']);
    });
  });
}

Future<Uint8List> _buildCall(
  String pallet,
  String method,
  Object fields,
) async {
  final runtime = await CitizenSdkTestFixture.runtimeContext(
    CitizenBlockRef(
      hash: '0x${'11' * 32}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    ),
  );
  return runtime.encodeCall(pallet, method, fields);
}
