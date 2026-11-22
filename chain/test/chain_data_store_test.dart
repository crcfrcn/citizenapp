// 验证读模型持久隔离、块序及独立价格和损坏记录处理。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_storage/chain_state.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;

void main() {
  useIsolatedIsar();
  test('持久读模型按链和账户隔离，并拒绝旧区块覆盖', () async {
    final store = IsarChainDataStore(), owner = f.account(1);
    await store.write(f.snapshot(f.block(103), owner), () => true);
    final restored = await store.read(f.hash(0), owner);
    expect(restored!.block.number, BigInt.from(103));
    expect(restored.memberActive(f.cidA), isTrue);
    expect(await store.read(f.hash(0), f.account(2)), isNull);
    expect(await store.read(f.hash(1), owner), isNull);
    await store.write(f.snapshot(f.block(86), owner), () => true);
    expect(
      (await store.read(f.hash(0), owner))!.block.number,
      BigInt.from(103),
    );
  });
  test('本人档位缓存保留已读空列表、会员档与绑定版本，未读保持null', () async {
    final store = IsarChainDataStore(), owner = f.account(1);
    await store.write(
      f.snapshot(
        f.block(103),
        owner,
        ownCreator: true,
        bindRev: 2,
        memberLevel: 'democracy',
      ),
      () => true,
    );
    final restored = (await store.read(f.hash(0), owner))!;
    expect(restored.own!.creatorTiers, isEmpty);
    expect(restored.own!.identity!.bindRev, 2);
    expect(restored.memberLevel(f.cidA), 'democracy');
    await store.write(f.snapshot(f.block(104), owner), () => true);
    expect((await store.read(f.hash(0), owner))!.own!.creatorTiers, isNull);
  });
  ChainPriceSnapshot prices(int height, {String? blockHash, int spec = 1}) =>
      ChainPriceSnapshot(
        genesisHash: f.hash(0),
        block: CitizenBlockRef(
          hash: blockHash ?? f.hash(height),
          number: BigInt.from(height),
          finality: CitizenBlockFinality.finalized,
        ),
        runtimeSpecVersion: spec,
        runtimeTransactionVersion: 4,
        checkedAtMillis: 1000000,
        prices: const {'freedom': 100, 'democracy': 200},
      );

  test('独立价格持久化按链共享，不被账户会员快照或无价格同步覆盖', () async {
    final store = IsarChainDataStore();
    await store.writePrices(prices(103), () => true);
    await store.write(f.snapshot(f.block(104), f.account(1)), () => true);
    await store.write(f.snapshot(f.block(105), f.account(2)), () => true);
    final restored = (await store.readPrices(f.hash(0)))!;
    expect(restored.block.number, BigInt.from(103));
    expect(restored.runtimeSpecVersion, 1);
    expect(restored.prices['democracy'], 200);
    expect(await store.readPrices(f.hash(1)), isNull);
    await store.writePrices(prices(86), () => true);
    expect((await store.readPrices(f.hash(0)))!.block.number, BigInt.from(103));
    await expectLater(
      store.writePrices(prices(103, blockHash: f.hash(999)), () => true),
      throwsStateError,
    );
  });
  test('价格缓存损坏不恢复，失效请求不写入，已验证结果可替换损坏行', () async {
    final store = IsarChainDataStore();
    await store.writePrices(prices(103), () => false);
    expect(await store.readPrices(f.hash(0)), isNull);
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<ChainState>().putByKey(
        ChainState()
          ..key = 'prices:${f.hash(0)}'
          ..data = '{"schema":0}',
      );
    });
    expect(await store.readPrices(f.hash(0)), isNull);
    await store.writePrices(prices(104, spec: 2), () => true);
    expect((await store.readPrices(f.hash(0)))!.runtimeSpecVersion, 2);
  });
  test('失效代次不写库；损坏或旧display不被恢复为轻节点数据', () async {
    final store = IsarChainDataStore(), owner = f.account(1);
    await store.write(f.snapshot(f.block(103), owner), () => false);
    expect(await store.read(f.hash(0), owner), isNull);
    await UserIsar.instance.writeTxn((db) async {
      await db.collection<ChainState>().putByKey(
        ChainState()
          ..key = '${f.hash(0)}:$owner'
          ..data = '{"membergate":{"active":true},"member_at":1}',
      );
    });
    expect(await store.read(f.hash(0), owner), isNull);
    await store.write(f.snapshot(f.block(103), owner), () => true);
    expect(
      (await store.read(f.hash(0), owner))!.block.number,
      BigInt.from(103),
    );
  });
}
