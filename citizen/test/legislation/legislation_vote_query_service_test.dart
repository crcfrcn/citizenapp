import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/legislation/legislation_vote_query_service.dart';

final block = CitizenBlockRef(
  hash: 'block',
  number: BigInt.one,
  finality: CitizenBlockFinality.finalized,
);

class Chain extends TestChainReads {
  Uint8List? value;
  int heads = 0;
  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    return block;
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef ref, Uint8List key) async {
    expect(ref, same(block));
    return value;
  }
}

void main() {
  test('真实缺失返回null、零计票或空签署，绑定块不选择链头', () async {
    final chain = Chain(),
        query = LegislationVoteQueryService(
          getFinalizedHead: chain.getFinalizedHead,
          getStorage: chain.getStorage,
          block: block,
          getSystemEvents: chain.getSystemEvents,
          getRuntimeContext: chain.getRuntimeContext,
          getStorageBatch: chain.getStorageBatch,
        );
    expect(await query.fetchRepresentativeMeta(7), null);
    expect(await query.fetchLegislationMeta(7), null);
    expect(await query.fetchRepresentativeTally(7, 0), (yes: 0, no: 0));
    expect(await query.fetchReferendumTally(7), (yes: 0, no: 0));
    expect(await query.fetchOverrideSigns(7), isEmpty);
    expect(chain.heads, 0);
  });
  for (final bytes in [
    <int>[],
    <int>[2],
    <int>[0, 0],
  ]) {
    test('元数据损坏$bytes不得伪装不存在', () async {
      final query = (() {
        final reads0 = Chain()..value = Uint8List.fromList(bytes);
        return LegislationVoteQueryService(
          getFinalizedHead: reads0.getFinalizedHead,
          getStorage: reads0.getStorage,
          block: block,
          getSystemEvents: reads0.getSystemEvents,
          getRuntimeContext: reads0.getRuntimeContext,
          getStorageBatch: reads0.getStorageBatch,
        );
      })();
      await expectLater(
        query.fetchRepresentativeMeta(7),
        throwsFormatException,
      );
      await expectLater(query.fetchLegislationMeta(7), throwsFormatException);
    });
  }
  test('签署严格校验bool、数量、重复账户、截断和尾随字节', () async {
    for (final bytes in [
      <int>[],
      [4, ...List.filled(32, 1), 2],
      [4, ...List.filled(32, 1), 1, 0],
      [8, ...List.filled(32, 1), 1, ...List.filled(32, 1), 1],
      [32],
    ]) {
      final query = (() {
        final reads0 = Chain()..value = Uint8List.fromList(bytes);
        return LegislationVoteQueryService(
          getFinalizedHead: reads0.getFinalizedHead,
          getStorage: reads0.getStorage,
          block: block,
          getSystemEvents: reads0.getSystemEvents,
          getRuntimeContext: reads0.getRuntimeContext,
          getStorageBatch: reads0.getStorageBatch,
        );
      })();
      await expectLater(query.fetchOverrideSigns(7), throwsFormatException);
      await expectLater(query.fetchGuardSigns(7), throwsFormatException);
    }
  });
  test('账本准确保留反对方向，损坏计票与票据失败关闭', () async {
    final chain = Chain()
      ..value = Uint8List.fromList([4, ...List.filled(32, 1), 0]);
    final query = LegislationVoteQueryService(
      getFinalizedHead: chain.getFinalizedHead,
      getStorage: chain.getStorage,
      block: block,
      getSystemEvents: chain.getSystemEvents,
      getRuntimeContext: chain.getRuntimeContext,
      getStorageBatch: chain.getStorageBatch,
    );
    expect((await query.fetchOverrideSigns(7)).single.approve, false);
    chain.value = Uint8List.fromList([2]);
    await expectLater(
      query.fetchRepresentativeTally(7, 0),
      throwsFormatException,
    );
    await expectLater(query.fetchReferendumTally(7), throwsFormatException);
    await expectLater(
      query.fetchRepresentativeVote(7, 0, 'CID', 'ROLE', '0x${'01' * 32}'),
      throwsFormatException,
    );
  });
  test('合法法律岗位主体选项，非法Option和非最短Compact拒绝', () {
    expect(
      LegislationVoteQueryService.debugDecodeLegislationMeta(
        Uint8List.fromList([0, 0, 0, 0]),
      ),
      isNotNull,
    );
    for (final bytes in [
      [2, 0, 0, 0],
      [0, 0, 2, 0],
      [0, 1, 0, 0, 0],
      [0, 0, 0, 2],
    ]) {
      expect(
        LegislationVoteQueryService.debugDecodeLegislationMeta(
          Uint8List.fromList(bytes),
        ),
        null,
      );
    }
  });
}
