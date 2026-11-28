// 验证提案持久化。

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/data.dart' show kNrc;
import 'package:citizen_citizen/proposal/store.dart' show LocalProposalSummary, ProposalLocalStore;
import 'package:citizen_citizen/proposal/data.dart' show EligibleVoterTicket, ProposalDisplayMeta, ProposalMeta, ProposalWithDetail;
import 'package:citizen_testing/database.dart';
import 'dart:convert';
import 'package:citizen_citizen/institution/data.dart' show InstitutionChangeInfo, InstitutionDetailRow, InstitutionProposalInfo;
import 'package:citizen_citizen/proposal/store.dart' show ProposalDetailLocalStore, ProposalDetailSnapshot;

void main() {
  group('proposal_local_store_test', _registerLocal);
  group('proposal_detail_local_store_test', _registerDetail);
}

// 验证提案摘要、机构索引及最终游标的并发持久状态。

void _registerLocal() {
  useIsolatedIsar();
  TestWidgetsFlutterBinding.ensureInitialized();
  final nationalCouncil = kNrc.first;

  test('空提案流保留最终区块进度且与其他钱包隔离', () async {
    final store = ProposalLocalStore.instance;
    final key = ProposalLocalStore.feedKey('chain-a', 'wallet-a');
    CitizenBlockRef block(int height, [String hash = 'block']) =>
        CitizenBlockRef(
          hash: hash,
          number: BigInt.from(height),
          finality: CitizenBlockFinality.finalized,
        );
    expect(await store.readFeed(key), isNull);
    await store.saveFeed(key: key, block: block(12), summaries: []);
    final saved = (await store.readFeed(key))!;
    expect(saved.ids, isEmpty);
    expect(saved.finalizedHeight, BigInt.from(12));
    expect(saved.finalizedHash, 'block');
    await store.saveFeed(key: key, block: block(11), summaries: []);
    expect((await store.readFeed(key))!.finalizedHeight, BigInt.from(12));
    await expectLater(
      store.saveFeed(key: key, block: block(12, 'other'), summaries: []),
      throwsStateError,
    );
    expect(
      await store.readFeed(ProposalLocalStore.feedKey('chain-a', 'wallet-b')),
      isNull,
    );
  });

  test('已核验删除保留较新游标及并发加入的提案，机构缓存不覆盖提案状态', () async {
    final store = ProposalLocalStore.instance;
    final key = ProposalLocalStore.feedKey('chain', null);
    CitizenBlockRef at(int height) => CitizenBlockRef(
      hash: 'block-$height', number: BigInt.from(height),
      finality: CitizenBlockFinality.finalized,
    );
    LocalProposalSummary item(int id, int status) => LocalProposalSummary.fromProposal(
      ProposalWithDetail(meta: ProposalMeta(
        proposalId: BigInt.from(id), kind: 0, stage: 0, status: status,
      )),
      detailPending: status == 3,
    );
    final terminal = item(1, 3);
    final fresh = item(2, 0);
    await store.saveFeed(key: key, block: at(1), summaries: [terminal]);
    await store.putInstitutionIndex('institution', [terminal.proposalId]);
    await store.upsertSummaries([item(1, 0)]);
    final stored = await store.readSummariesForIds([terminal.proposalId]);
    expect(stored.single.status, 3);
    expect(stored.single.detailPending, true);
    await store.saveFeed(key: key, block: at(2), summaries: [fresh], added: [fresh.proposalId]);
    await store.removeConfirmed({terminal.proposalId});
    await store.saveFeed(key: key, block: at(3), summaries: [terminal]);
    final index = (await store.readFeed(key))!;
    expect(index.finalizedHeight, BigInt.from(3));
    expect(index.ids, [fresh.proposalId]);
    expect((await store.readInstitutionIndex('institution'))?.ids, isEmpty);
    expect(await store.readSummariesForIds([terminal.proposalId]), isEmpty);
  });

  test('提案摘要按 ID 持久化读取', () async {
    final summary = LocalProposalSummary.fromProposal(
      ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: BigInt.from(12),
          kind: 1,
          stage: 1,
          status: 0,
          internalCode: 'NRC',
          actorCidNumber: nationalCouncil.cidNumber,
          executionAccountId: Uint8List(32),
          subjectCidNumbers: const ['LN001-NRC0G-000000001-2026'],
          displayMeta: ProposalDisplayMeta(
            year: 2026,
            seqInYear: BigInt.from(3),
          ),
        ),
      ),
      institution: nationalCouncil,
    );

    await ProposalLocalStore.instance.upsertSummaries([summary]);

    final page = await ProposalLocalStore.instance.readSummariesForIds([
      BigInt.from(12),
    ]);

    expect(page, hasLength(1));
    expect(page.single.proposalId, BigInt.from(12));
    expect(page.single.displayId, '2026000003');
    expect(page.single.fullName, nationalCouncil.fullName);
    expect(page.single.subjectCidNumbers, ['LN001-NRC0G-000000001-2026']);
  });

  test('提案摘要按机构索引持久化读取', () async {
    final summary = LocalProposalSummary.fromProposal(
      ProposalWithDetail(
        meta: ProposalMeta(
          proposalId: BigInt.from(33),
          kind: 0,
          stage: 0,
          status: 1,
          internalCode: 'NRC',
          actorCidNumber: nationalCouncil.cidNumber,
          executionAccountId: Uint8List(32),
          displayMeta: ProposalDisplayMeta(
            year: 2026,
            seqInYear: BigInt.from(9),
          ),
        ),
      ),
      institution: nationalCouncil,
    );

    await ProposalLocalStore.instance.upsertSummaries([summary]);
    await ProposalLocalStore.instance.putInstitutionIndex(
      nationalCouncil.cidNumber,
      [BigInt.from(33)],
    );

    final list = await ProposalLocalStore.instance.readInstitutionSummaries(
      nationalCouncil.cidNumber,
    );

    expect(list, hasLength(1));
    expect(list.single.proposalId, BigInt.from(33));
    expect(list.single.status, 1);
    expect(
      await ProposalLocalStore.instance.isInstitutionIndexFresh(
        nationalCouncil.cidNumber,
      ),
      isTrue,
    );
  });
}

// 验证提案详情持久化、冻结岗位票据及种类隔离。

void _registerDetail() {
  test('最终块状态更新只替换计票值，保留正文和冻结岗位票据', () async {
    final id = BigInt.from(23);
    final snapshot = ProposalDetailSnapshot(
      proposalId: id,
      proposalKind: 'runtime_upgrade',
      updatedAt: 1,
      status: 0,
      yesCount: 2,
      noCount: 0,
      detail: {'reason': '本机正文'},
    );
    final ticket = EligibleVoterTicket(
      voterAccountId: 'account',
      personCid: 'person-A',
      cidNumber: 'institution',
      voterRoleCode: 'COMMITTEE_MEMBER',
    );
    final state = ProposalMeta(proposalId: id, kind: 1, stage: 1, status: 3);
    final updated = snapshot.withState(
      state,
      tally: (yes: 3, no: 1),
      tickets: [ticket],
      votes: {ticket.ticketKey: true},
    );
    final store = ProposalDetailLocalStore.instance;
    await store.put(updated);
    final restored = (await store.read('runtime_upgrade', id))!;
    expect(restored.status, 3);
    expect(restored.yesCount, 3);
    expect(restored.noCount, 1);
    expect(restored.detail, snapshot.detail);
    expect(restored.voterTickets.single.ticketKey, ticket.ticketKey);
    expect(restored.adminVotes[ticket.ticketKey], isTrue);
  });

  test('机构人员未绑定钱包仍保留冻结票据和已投记录', () {
    const ticket = EligibleVoterTicket(
      voterAccountId: null,
      personCid: 'person-A',
      cidNumber: 'institution',
      voterRoleCode: 'COMMITTEE_MEMBER',
    );
    final id = BigInt.from(24);
    final original =
        ProposalDetailSnapshot(
          proposalId: id,
          proposalKind: 'transfer',
          updatedAt: 1,
        ).withState(
          ProposalMeta(proposalId: id, kind: 0, stage: 0, status: 0),
          tickets: [ticket],
          votes: {ticket.ticketKey: true},
        );
    final restored = ProposalDetailSnapshot.fromJsonString(
      jsonEncode(original.toJson()),
      proposalKind: 'transfer',
      proposalId: id,
    )!;
    expect(restored.voterTickets.single.personCid, 'person-A');
    expect(restored.voterTickets.single.voterAccountId, isNull);
    expect(restored.adminVotes[ticket.ticketKey], isTrue);
  });

  test('缺少人员CID的旧机构缓存失效，不从钱包倒推身份', () {
    final snapshot = ProposalDetailSnapshot(
      proposalId: BigInt.one,
      proposalKind: 'transfer',
      updatedAt: 1,
      extra: const {
        'voter_tickets': [
          {
            'account_id': 'wallet',
            'cid_number': 'institution',
            'role_code': 'MEMBER',
          },
        ],
      },
    );
    expect(
      ProposalDetailSnapshot.fromJsonString(
        jsonEncode(snapshot.toJson()),
        proposalKind: 'transfer',
        proposalId: BigInt.one,
      ),
      isNull,
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  test('政策详情和完整状态指纹经通用缓存保存，计票更新不改业务正文', () async {
    final info = InstitutionChangeInfo(
      proposalId: BigInt.from(91),
      actorCidNumber: 'LN001-CGOV0-944805165-2026',
      action: 5,
      rows: [
        const InstitutionDetailRow('完整替换原生权限', 'R_POLICY'),
        InstitutionDetailRow('期望机构状态指纹', '0x${'09' * 32}', copyable: true),
      ],
    );
    final snapshot = ProposalDetailSnapshot(
      proposalId: info.proposalId,
      proposalKind: 'institution_multisig',
      updatedAt: 1,
      status: 0,
      threshold: 2,
      detail: info.toJson(),
    );
    await ProposalDetailLocalStore.instance.put(snapshot);
    final saved = (await ProposalDetailLocalStore.instance.read(
      'institution_multisig',
      info.proposalId,
    ))!;
    expect(
      InstitutionProposalInfo.fromJson(info.proposalId, saved.detail)?.toJson(),
      info.toJson(),
    );
    final changed = saved.withState(
      ProposalMeta(proposalId: info.proposalId, kind: 0, stage: 0, status: 1),
      tally: (yes: 2, no: 0),
    );
    expect(changed.detail, saved.detail);
    expect(changed.threshold, 2);
  });

  test('同一钱包的岗位票据键完整保留CID和岗位大小写，不按地址去重', () async {
    final account = '0x${'ab' * 32}';
    final first = 'TEST-CID:COMMITTEE_MEMBER:$account';
    final second = 'TEST-CID:DIRECTOR:$account';
    final snapshot = ProposalDetailSnapshot(
      proposalId: BigInt.from(78),
      proposalKind: 'transfer',
      updatedAt: 1,
      admins: [account],
      adminVotes: {first: true, second: false},
    );
    await ProposalDetailLocalStore.instance.put(snapshot);
    final loaded = await ProposalDetailLocalStore.instance.read(
      'transfer',
      BigInt.from(78),
    );
    expect(loaded!.adminVotes, {first: true, second: false});
    expect(loaded.admins, [account]);
  });

  test('提案详情快照可持久化管理员投票和业务详情', () async {
    final snapshot = ProposalDetailSnapshot(
      proposalId: BigInt.from(77),
      proposalKind: 'transfer',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: 0,
      yesCount: 2,
      noCount: 1,
      threshold: 6,
      admins: const ['aa', 'bb'],
      adminVotes: const {'aa': true, 'bb': null},
      pendingPublicKeys: const ['bb'],
      detail: const {'kind': 'transfer', 'amount_fen': '12300'},
    );

    await ProposalDetailLocalStore.instance.put(snapshot);

    final loaded = await ProposalDetailLocalStore.instance.read(
      'transfer',
      BigInt.from(77),
    );

    expect(loaded, isNotNull);
    expect(loaded!.proposalId, BigInt.from(77));
    expect(loaded.adminVotes['aa'], isTrue);
    expect(loaded.adminVotes['bb'], isNull);
    expect(loaded.detail['amount_fen'], '12300');
    expect(loaded.isFresh(ProposalDetailLocalStore.activeTtl), isTrue);
  });

  test('相同提案号按种类隔离，覆盖本种类不影响另一种类', () async {
    final store = ProposalDetailLocalStore.instance;
    for (final kind in ['transfer', 'institution_multisig', 'personal']) {
      await store.put(
        ProposalDetailSnapshot(
          proposalId: BigInt.from(77),
          proposalKind: kind,
          updatedAt: 1,
          status: 0,
          detail: {'kind': kind},
        ),
      );
    }
    await store.put(
      ProposalDetailSnapshot(
        proposalId: BigInt.from(77),
        proposalKind: 'transfer',
        updatedAt: 2,
        status: 1,
        detail: {'amount_fen': '12300'},
      ),
    );
    final transfer = (await store.read('transfer', BigInt.from(77)))!;
    final institution = (await store.read(
      'institution_multisig',
      BigInt.from(77),
    ))!;
    expect(transfer.updatedAt, 2);
    expect(transfer.isFinal, true);
    expect(transfer.detail['amount_fen'], '12300');
    expect(institution.updatedAt, 1);
    expect(institution.isFinal, false);
    expect(institution.detail['kind'], 'institution_multisig');
    final personal = (await store.read('personal', BigInt.from(77)))!;
    expect(personal.detail['kind'], 'personal');
    expect(personal.updatedAt, 1);
    expect(await store.read('transfer', BigInt.from(78)), isNull);
  });
}
