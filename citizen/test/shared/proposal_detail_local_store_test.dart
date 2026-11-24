// 验证提案详情持久化、冻结岗位票据及种类隔离。

import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
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
