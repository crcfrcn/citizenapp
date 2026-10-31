import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';

final block = CitizenBlockRef(
  hash: 'block',
  number: BigInt.one,
  finality: CitizenBlockFinality.finalized,
);
final account = '0x${'01' * 32}';

class Chain extends TestChainReads {
  Uint8List? value;
  int heads = 0, batches = 0;
  bool short = false;
  Uint8List? key;
  final refs = <CitizenBlockRef>[];
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    return block;
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

void main() {
  test('缺失、赞成与反对严格按SCALE bool读取，确认查询不换链头', () async {
    final chain = Chain(),
        query = (() {
          final reads0 = Chain();
          return InternalVoteQueryService(
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
            block: block,
          );
        })();
    expect(await query.fetchAdminVote(7, account), null);
    for (final value in [0, 1]) {
      chain.value = Uint8List.fromList([value]);
      expect(
        await InternalVoteQueryService(
          getFinalizedHead: chain.getFinalizedHead,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
          block: block,
        ).fetchAdminVote(7, account),
        value == 1,
      );
    }
    expect(chain.heads, 0);
    expect(chain.refs.every((r) => identical(r, block)), true);
  });
  for (final bytes in [
    <int>[],
    <int>[2],
    <int>[1, 0],
  ]) {
    test('坏投票$bytes不会被当成未投票', () async {
      final chain = Chain()..value = Uint8List.fromList(bytes);
      await expectLater(
        InternalVoteQueryService(
          getFinalizedHead: chain.getFinalizedHead,
          getStorage: chain.getStorage,
          getStorageBatch: chain.getStorageBatch,
        ).fetchAdminVote(7, account),
        throwsFormatException,
      );
    });
  }
  test('机构票据CID、岗位及钱包都进入键，文本按UTF-8编码', () async {
    final chain = Chain();
    await InternalVoteQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchInstitutionTicketVote(7, '机构', '岗位', account);
    final suffix = [
      1,
      utf8.encode('机构').length << 2,
      ...utf8.encode('机构'),
      utf8.encode('岗位').length << 2,
      ...utf8.encode('岗位'),
      ...List.filled(32, 1),
    ];
    expect(chain.key!.sublist(chain.key!.length - suffix.length), suffix);
  });
  test('批量按100分块，仅一次选链头且保持重复账户去重', () async {
    final chain = Chain()..value = Uint8List.fromList([0]);
    final accounts = List.generate(
      201,
      (i) => '0x${i.toRadixString(16).padLeft(64, '0')}',
    );
    final result = await InternalVoteQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      getStorageBatch: chain.getStorageBatch,
    ).fetchAdminVotesBatch(7, [...accounts, accounts.first]);
    expect(result.length, 201);
    expect(chain.batches, 3);
    expect(chain.heads, 1);
    expect(result.values.every((x) => x == false), true);
  });
  test('批量响应缺件必须失败，不越界或制造null', () async {
    await expectLater(
      (() {
        final reads0 = Chain()..short = true;
        return InternalVoteQueryService(
          getFinalizedHead: reads0.getFinalizedHead,
          getStorage: reads0.getStorage,
          getStorageBatch: reads0.getStorageBatch,
        );
      })().fetchAdminVotesBatch(7, [account]),
      throwsFormatException,
    );
  });
  test('坏账户、空岗位和负提案号在读取前拒绝', () async {
    final chain = Chain(),
        query = (() {
          final reads0 = Chain();
          return InternalVoteQueryService(
            getFinalizedHead: reads0.getFinalizedHead,
            getStorage: reads0.getStorage,
            getStorageBatch: reads0.getStorageBatch,
          );
        })();
    await expectLater(query.fetchAdminVote(7, '01'), throwsFormatException);
    await expectLater(
      InternalVoteQueryService(
        getFinalizedHead: chain.getFinalizedHead,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchInstitutionTicketVote(7, 'CID', '', account),
      throwsArgumentError,
    );
    await expectLater(
      InternalVoteQueryService(
        getFinalizedHead: chain.getFinalizedHead,
        getStorage: chain.getStorage,
        getStorageBatch: chain.getStorageBatch,
      ).fetchAdminVote(-1, account),
      throwsArgumentError,
    );
    expect(chain.refs, isEmpty);
  });
}
