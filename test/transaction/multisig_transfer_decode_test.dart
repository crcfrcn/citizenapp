import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizenapp/citizen/proposal/proposal_tab.dart';
import 'package:citizenapp/citizen/proposal/proposal_context.dart';
import 'package:citizenapp/citizen/proposal/proposal_local_store.dart';
import 'package:citizenapp/citizen/administrators/institution_admin_service.dart';
import 'package:citizenapp/citizen/administrators/admin_activation_service.dart';
import 'package:citizenapp/citizen/institution/institution_repository.dart';
import 'package:citizenapp/citizen/proposal/internal_vote_query_service.dart';
import 'package:citizenapp/citizen/runtime/runtime_upgrade_service.dart';
import 'package:citizenapp/transaction/multisig/multisig_transfer_proposal_adapter.dart';

import '../support/isar_test_env.dart';
import 'package:citizenapp/storage/wallet_isar.dart';
import '../citizen/public/public_nav_harness.dart';

import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:citizenapp/citizen/institution/institution_info.dart';
import 'package:citizenapp/citizen/proposal/proposal_models.dart';
import 'package:citizenapp/citizen/proposal/proposal_query_service.dart';
import 'package:citizenapp/transaction/multisig/multisig_transfer_service.dart';

import '../support/fake_citizen_sdk.dart';

class _RawStorageChain extends TestCitizenChain {
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

/// 合成只读依赖只控制结果与时序，页面仍执行同一加载、持久化和刷新路径。
class _PageFeed extends MultisigTransferProposalFeed {
  _PageFeed()
    : super(
        service: MultisigTransferService(
          chain: TestCitizenChain(),
          transactions: TestCitizenTransactions(),
        ),
      );
  List<int> ids = [1];
  final scopes = <FutureOr<List<int>> Function()>[];
  final forced = <bool>[];
  Future<List<ProposalWithDetail>> Function(List<int>)? details;
  @override
  Future<List<int>> fetchCitizenProposalFeedIds({
    required Set<String> defaultCodes,
    required Set<String> subscribedInstitutionCidNumbers,
    bool forceRefresh = false,
  }) async {
    expectSync(defaultCodes, contains('NRC'));
    forced.add(forceRefresh);
    return scopes.isEmpty ? ids : scopes.removeAt(0)();
  }

  static List<ProposalWithDetail> proposals(List<int> ids) => [
    for (final id in ids)
      ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: id,
          kind: 1,
          stage: 1,
          status: 0,
          internalCode: 'NRC',
          displayMeta: ProposalDisplayMeta(year: 2026, seqInYear: id),
        ),
      ),
  ];
  @override
  Future<List<ProposalWithDetail>> fetchProposalsByIds(List<int> ids) async =>
      details == null ? proposals(ids) : details!(ids);
}

class _PageContext extends ProposalContextResolver {
  _PageContext()
    : super(
        wallet: TestCitizenSdkWallet(),
        adminService: InstitutionAdminService(chain: TestCitizenChain()),
        activationService: ActivationService(
          adminService: InstitutionAdminService(chain: TestCitizenChain()),
        ),
      );
  @override
  Future<List<ProposalContext>> resolveBatch(
    List<String?> actorCidNumbers, {
    List<List<int>?>? executionAccountIds,
    List<String?>? internalCodeList,
    Map<String, InstitutionInfo> knownInstitutionsByCidNumber = const {},
  }) async => [for (final _ in actorCidNumbers) const ProposalContext()];
}

class _PageVotes extends VoteChecker {
  _PageVotes()
    : super(
        internalVoteService: InternalVoteQueryService(
          chain: TestCitizenChain(),
        ),
        runtimeService: RuntimeUpgradeService(
          chain: TestCitizenChain(),
          transactions: TestCitizenTransactions(),
        ),
        proposalQueryService: ProposalQueryService(chain: TestCitizenChain()),
      );
  @override
  Future<Set<int>> proposalsNeedingVote(List<VoteCheckTarget> targets) async =>
      targets
          .where((item) => item.proposalId.isOdd)
          .map((item) => item.proposalId)
          .toSet();
}

class _PageTransport extends TestCitizenSdkTransport {
  _PageTransport() : super({'walletGetState': (_) => testCitizenWalletState()});
  final controller = StreamController<Object?>.broadcast();
  int sequence = 1;
  @override
  Stream<Object?> get events => controller.stream;
  void finalized() => controller.add([
    2,
    'synthetic-ui-session',
    sequence++,
    'finalizedBlockChanged',
    [
      ['0x${'11' * 32}', '1', 'finalized'],
    ],
  ]);
  @override
  Future<void> dispose() async {
    await controller.close();
    await super.dispose();
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

Future<_PageTransport> _openProposal(
  WidgetTester tester,
  _PageFeed feed,
  List<int> counts,
) async {
  final transport = _PageTransport();
  final sdk = await transport.open();
  addTearDown(() async {
    await _flush(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await sdk.close();
      await transport.dispose();
    });
  });
  await tester.runAsync(() => WalletIsar.instance.db());
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
            repository: InstitutionRepository(directory: directory),
            contextResolver: _PageContext(),
            voteChecker: _PageVotes(),
            onPendingVoteCountChanged: counts.add,
          ),
        ),
      ),
    ),
  );
  for (var attempt = 0; attempt < 20; attempt++) {
    await _flush(tester);
    if (counts.isNotEmpty || find.text('提案读取失败，请重试').evaluate().isNotEmpty) break;
  }
  expect(counts.isNotEmpty || find.text('提案读取失败，请重试').evaluate().isNotEmpty,
      isTrue, reason: '必须等待真实首批读取完成，不能把骨架内部ListView认作提案列表');
  return transport;
}

Future<void> _refreshProposal(WidgetTester tester) =>
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();

/// 提案页真实交互路径与批量解码布局回归。
///
/// 固化当前 runtime `MODULE_TAG + TransferAction` SCALE 布局，确保机构转账
/// 始终按 actor CID + funding account 解码，短备注和空备注都不会静默消失。
void main() {
  useIsolatedIsar();
  testWidgets('提案合法空索引成功为空，不显示链不可用或错误', (tester) async {
    final feed = _PageFeed()..ids = [];
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    expect(feed.forced, [false]);
    expect(counts, [0]);
    expect(find.text('加载失败'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('首次提案失败后按钮走强制重试，成功后清除错误', (tester) async {
    final feed = _PageFeed()..scopes.add(() => throw StateError('合成首次读取失败'));
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    expect(find.text('提案读取失败，请重试'), findsOneWidget);
    expect(counts, isEmpty);
    await tester.tap(find.text('重试'));
    await _flush(tester);
    expect(feed.forced, [false, true]);
    expect(find.text('2026000001'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(counts.last, 1);
  });
  testWidgets('提案刷新失败保留列表与待投票数，重试成功再替换', (tester) async {
    final feed = _PageFeed();
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    feed.scopes.add(() => throw StateError('合成刷新失败'));
    await _refreshProposal(tester);
    await _flush(tester);
    expect(find.text('2026000001'), findsOneWidget);
    expect(find.text('提案刷新失败，已保留当前列表'), findsOneWidget);
    expect(counts, [1]);
    feed.ids = [2];
    await tester.tap(find.text('重试'));
    await _flush(tester);
    expect(feed.forced, [false, true, true]);
    expect(find.text('2026000002'), findsOneWidget);
    expect(find.text('2026000001'), findsNothing);
    expect(counts, [1, 0]);
  });
  for (final fail in [false, true]) {
    testWidgets('迟到提案刷新${fail ? '失败' : '成功'}不覆盖最新刷新', (tester) async {
      final feed = _PageFeed();
      final counts = <int>[];
      await _openProposal(tester, feed, counts);
      final delayed = Completer<List<int>>();
      feed.scopes.add(() => delayed.future);
      final first = _refreshProposal(tester);
      await _flush(tester);
      feed.ids = [3];
      final second = _refreshProposal(tester);
      await _flush(tester);
      await second;
      if (fail) {
        delayed.completeError(StateError('合成迟到失败'));
      } else {
        delayed.complete([2]);
      }
      await first;
      await _flush(tester);
      expect(find.text('2026000003'), findsOneWidget);
      expect(find.text('2026000002'), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(counts, [1, 1]);
    });
    testWidgets('迟到后台索引${fail ? '失败' : '成功'}不覆盖手动刷新', (tester) async {
      final feed = _PageFeed();
      final counts = <int>[];
      final transport = await _openProposal(tester, feed, counts);
      final delayed = Completer<List<int>>();
      feed.scopes.add(() => delayed.future);
      transport.finalized();
      await _flush(tester);
      expect(feed.forced, [false, false]);
      feed.ids = [3];
      final refreshed = _refreshProposal(tester);
      await _flush(tester);
      await refreshed;
      if (fail) {
        delayed.completeError(StateError('合成旧后台失败'));
      } else {
        delayed.complete([2, 1]);
      }
      await _flush(tester);
      expect(find.text('2026000003'), findsOneWidget);
      expect(find.text('2026000002'), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(counts, [1, 1]);
    });
  }
  testWidgets('翻页失败保留首批，按钮重试该页且不重复首批', (tester) async {
    final feed = _PageFeed()..ids = List.generate(11, (i) => 11 - i);
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    var fail = true;
    var pages = 0;
    feed.details = (ids) async {
      pages++;
      if (fail) throw StateError('合成翻页失败');
      return _PageFeed.proposals(ids);
    };
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await _flush(tester);
    expect(find.text('更多提案读取失败，请重试'), findsOneWidget);
    expect(counts, [5]);
    fail = false;
    await tester.tap(find.text('重试'));
    await _flush(tester);
    expect(pages, 2);
    expect(counts.last, 6);
    expect(find.text('2026000001'), findsOneWidget);
  });
  testWidgets('旧翻页返回不能追加到新刷新，也不写入旧摘要', (tester) async {
    final feed = _PageFeed()..ids = List.generate(11, (i) => 11 - i);
    final counts = <int>[];
    await _openProposal(tester, feed, counts);
    final delayed = Completer<List<ProposalWithDetail>>();
    feed.details = (_) => delayed.future;
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await _flush(tester);
    feed.details = null;
    feed.ids = [30];
    final refreshed = _refreshProposal(tester);
    await _flush(tester);
    await refreshed;
    delayed.complete(_PageFeed.proposals([1]));
    await _flush(tester);
    expect(find.text('2026000030'), findsOneWidget);
    expect(find.text('2026000001'), findsNothing);
    final old = await tester.runAsync(
      () => ProposalLocalStore.instance.readSummariesForIds([1]),
    );
    expect(old, isEmpty);
    expect(counts.last, 0);
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

  final service = MultisigTransferService(
    chain: TestCitizenChain(),
    transactions: TestCitizenTransactions(),
  );

  test('机构 propose_transfer 当前 SCALE payload 的短备注必须可解码', () {
    final institutionAccountId = List<int>.filled(32, 0x11);
    final beneficiary = List<int>.filled(32, 0x22);
    final decoded = service.debugDecodeProposalData(
      0,
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
    expect(
      decoded.beneficiary,
      Keyring().encodeAddress(Uint8List.fromList(beneficiary), 2027),
    );
  });

  test('机构 propose_transfer 当前 SCALE payload 的空备注必须可解码', () {
    final decoded = service.debugDecodeProposalData(
      1,
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

    expect(service.debugDecodeProposalData(2, raw), isNull);
  });

  test('MODULE_TAG 不符返回 null', () {
    final body = <int>[
      ...'dq-xxxx'.codeUnits,
      ...List<int>.filled(114, 0x11),
    ];
    final raw = Uint8List.fromList([...compactU32(body.length), ...body]);

    expect(service.debugDecodeProposalData(3, raw), isNull);
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
    final decoded = await MultisigTransferService(chain: _RawStorageChain(raw), transactions: TestCitizenTransactions()).fetchSafetyFundAction(4);

    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.institutionAccountId, institutionAccountId);
    expect(decoded.amountFen, BigInt.from(500));
    expect(
      decoded.proposer,
      Keyring().encodeAddress(Uint8List.fromList(proposer), 2027),
    );

    final trailing = Uint8List.fromList([...raw, 0]);
    expect(
      await MultisigTransferService(chain: _RawStorageChain(trailing), transactions: TestCitizenTransactions()).fetchSafetyFundAction(4),
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
    final decoded = await MultisigTransferService(chain: _RawStorageChain(raw), transactions: TestCitizenTransactions()).fetchSweepAction(5);

    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.institutionAccountId, institutionAccountId);
    expect(decoded.amountFen, BigInt.from(800));
    expect(
      decoded.proposer,
      Keyring().encodeAddress(Uint8List.fromList(proposer), 2027),
    );

    final trailing = Uint8List.fromList([...raw, 0]);
    expect(
      await MultisigTransferService(chain: _RawStorageChain(trailing), transactions: TestCitizenTransactions()).fetchSweepAction(5),
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
    final decoded = service.debugDecodeProposalMeta(6, raw);
    expect(decoded, isNotNull);
    expect(decoded!.actorCidNumber, actorCidNumber);
    expect(decoded.executionAccountId, executionAccountId);
    expect(decoded.subjectCidNumbers, [subjectCidNumber]);

    expect(
      service.debugDecodeProposalMeta(6, Uint8List.fromList([...raw, 0])),
      isNull,
    );
    final invalidOption = Uint8List.fromList(raw)..[3] = 2;
    expect(service.debugDecodeProposalMeta(6, invalidOption), isNull);
  });

  test('ProposalSubject 唯一编码严格区分机构 CID 与个人多签账户', () {
    const institutionCidNumber = 'LN001-CGOVC-000000001-2026';
    final institution = InstitutionInfo(
      cidFullName: '测试机构',
      cidShortName: '测试机构',
      cidFullNameEn: 'Test Institution',
      cidShortNameEn: 'TI',
      cidNumber: institutionCidNumber,
      orgType: OrgType.institution,
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'11' * 32}',
        feeAccountId: '0x${'22' * 32}',
      ),
    );
    final institutionKey = ProposalQueryService.proposalSubjectKey(institution);
    expect(institutionKey.first, 0);
    expect(institutionKey[1], utf8.encode(institutionCidNumber).length << 2);
    expect(utf8.decode(institutionKey.sublist(2)), institutionCidNumber);

    final personalAccount = '0x${'ab' * 32}';
    final personal = InstitutionInfo(
      cidFullName: '个人多签',
      cidShortName: '个人多签',
      cidFullNameEn: 'Personal Multisig',
      cidShortNameEn: 'PMUL',
      cidNumber: 'personal-account:$personalAccount',
      orgType: OrgType.personalMultisig,
      personalAccountId: personalAccount,
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
    expect(
      ProposalQueryService.decodeAdminSnapshot(adminsRaw),
      ['0x${'11' * 32}', '0x${'22' * 32}'],
    );
    expect(
      ProposalQueryService.decodeAdminSnapshot(
        Uint8List.fromList([...adminsRaw, 0]),
      ),
      isNull,
    );

    final activeRaw = Uint8List.fromList([
      8, // Compact(2)
      ...u64Le(7),
      ...u64Le(9),
    ]);
    expect(ProposalQueryService.decodeActiveProposalIds(activeRaw), [7, 9]);
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
    final query = ProposalQueryService(chain: rpc);
    final institution = InstitutionInfo(
      cidFullName: '测试机构',
      cidShortName: '测试机构',
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
      cidFullName: '个人多签',
      cidShortName: '个人多签',
      cidFullNameEn: 'Personal Multisig',
      cidShortNameEn: 'PMUL',
      cidNumber: 'personal-account:$personalAccount',
      orgType: OrgType.personalMultisig,
      personalAccountId: personalAccount,
    );

    expect(
      await query.fetchRoleVoterSnapshot(
        7,
        institution.cidNumber,
        'COMMITTEE_MEMBER',
      ),
      ['0x${'33' * 32}'],
    );
    expect(
      await query.fetchEligibleVoterSnapshot(7, personal),
      ['0x${'33' * 32}'],
    );
    expect(rpc.storageKeys, hasLength(2));
    expect(rpc.storageKeys[0], isNot(rpc.storageKeys[1]));
  });

  test('公民提案流按默认机构码和订阅机构 CID 合并过滤', () {
    Uint8List accountIdBytes(int seed) => Uint8List.fromList(
          List<int>.filled(32, seed),
        );

    ProposalWithDetail proposal(
      int id, {
      required String code,
      required Uint8List institution,
      List<String> subjectCidNumbers = const [],
    }) {
      return ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: id,
          kind: 0,
          stage: 0,
          status: 0,
          internalCode: code,
          actorCidNumber:
              subjectCidNumbers.isEmpty ? null : subjectCidNumbers.first,
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

    expect(ids, [6, 4, 1]);
  });
}
