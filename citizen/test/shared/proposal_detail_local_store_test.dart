import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
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

    final loaded = await ProposalDetailLocalStore.instance.read('transfer', BigInt.from(77));

    expect(loaded, isNotNull);
    expect(loaded!.proposalId, BigInt.from(77));
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
    final institution = (await store.read('institution_multisig', BigInt.from(77)))!;
    expect(transfer.updatedAt, 2);
    expect(transfer.isFinal, true);
    expect(transfer.detail['amount_fen'], '12300');
    expect(institution.updatedAt, 1);
    expect(institution.isFinal, false);
    expect(institution.detail['kind'], 'institution_multisig');
    expect(await store.read('transfer', BigInt.from(78)), isNull);
  });
}
