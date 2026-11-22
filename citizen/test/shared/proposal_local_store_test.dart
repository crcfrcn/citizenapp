import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/governance_registry.dart';
import 'package:citizen_citizen/proposal/proposal_local_store.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
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
