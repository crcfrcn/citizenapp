import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  test('提案详情快照可持久化管理员投票和业务详情', () async {
    final snapshot = ProposalDetailSnapshot(
      proposalId: 77,
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

    final loaded = await ProposalDetailLocalStore.instance.read('transfer', 77);

    expect(loaded, isNotNull);
    expect(loaded!.proposalId, 77);
    expect(loaded.adminVotes['aa'], isTrue);
    expect(loaded.adminVotes['bb'], isNull);
    expect(loaded.detail['amount_fen'], '12300');
    expect(loaded.isFresh(ProposalDetailLocalStore.activeTtl), isTrue);
  });

  test('相同提案号按种类隔离，覆盖本种类不影响另一种类', () async {
    final store = ProposalDetailLocalStore.instance;
    for (final kind in ['transfer', 'institution_multisig']) {
      await store.put(
        ProposalDetailSnapshot(
          proposalId: 77,
          proposalKind: kind,
          updatedAt: 1,
          status: 0,
          detail: {'kind': kind},
        ),
      );
    }
    await store.put(
      const ProposalDetailSnapshot(
        proposalId: 77,
        proposalKind: 'transfer',
        updatedAt: 2,
        status: 1,
        detail: {'amount_fen': '12300'},
      ),
    );
    final transfer = (await store.read('transfer', 77))!;
    final institution = (await store.read('institution_multisig', 77))!;
    expect(transfer.updatedAt, 2);
    expect(transfer.isFinal, true);
    expect(transfer.detail['amount_fen'], '12300');
    expect(institution.updatedAt, 1);
    expect(institution.isFinal, false);
    expect(institution.detail['kind'], 'institution_multisig');
    expect(await store.read('transfer', 78), isNull);
  });
}
