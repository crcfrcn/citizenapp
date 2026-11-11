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
