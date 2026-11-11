import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;

Uint8List number(int value, int width) => Uint8List.fromList(
  List.generate(width, (i) => (BigInt.from(value) >> (8 * i)).toInt() & 255),
);
void main() {
  late CitizenRuntimeContext runtime;
  late Map<String, Uint8List> values;
  late ChainDataReader reader;
  late List<List<String>> calls;
  final at = f.block(103), owner = f.account(1);
  String id(Uint8List key) => base64Encode(key);
  setUp(() async {
    runtime = await CitizenSdkTestFixture.runtimeContext(at);
    values = {};
    calls = [];
    final cid = (
      scale: CitizenIdentityChainReader.encodeBoundedBytes(utf8.encode(f.cidA)),
    );
    void put(String pallet, String name, List<Object> keys, List<int> bytes) =>
        values[id(runtime.storageKey(pallet, name, keys))] = Uint8List.fromList(
          bytes,
        );
    put('CitizenIdentity', 'CidByAccountId', [
      citizenAccountIdBytes(owner),
    ], CitizenIdentityChainReader.encodeBoundedBytes(utf8.encode(f.cidA)));
    put('CitizenIdentity', 'AccountIdByCid', [
      cid,
    ], citizenAccountIdBytes(owner));
    put('CitizenIdentity', 'BindingRevisionByCid', [cid], number(1, 8));
    put(
      'CitizenIdentity',
      'CidRegistry',
      [cid],
      [
        ...CitizenIdentityChainReader.encodeBoundedBytes(utf8.encode(f.cidB)),
        ...List.filled(32, 0),
        0,
        0,
        0,
        ...number(1, 4),
        0,
      ],
    );
    put('Timestamp', 'Now', [], number(1000, 8));
    for (final level in ['freedom', 'democracy', 'spark'])
      put('SquarePost', 'PlatformPrice', [
        SubscriptionChain.membershipLevelVariant(level),
      ], number(199900, 16));
    values[id(
      SubscriptionChain.buildSubscriptionStorageKey(runtime, f.cidA, null),
    )] = Uint8List.fromList([
      0,
      0,
      ...number(1, 8),
      ...number(1, 8),
      ...number(199900, 16),
      ...number(2000, 8),
      0,
      ...number(199900, 16),
      0,
    ]);
    reader = ChainDataReader(
      getRuntimeContext: (block) async {
        expect(block.hash, at.hash);
        return runtime;
      },
      getStorageBatch: (block, keys) async {
        expect(block.hash, at.hash);
        expect(block.finality, CitizenBlockFinality.finalized);
        expect(keys.length, lessThanOrEqualTo(256));
        calls.add(keys.map(id).toList());
        return [for (final key in keys) values[id(key)]];
      },
    );
  });
  test('同一最终块合并绑定闭环、会员、三档价格与链时间，键只取一次', () async {
    final data = await reader.read(
      genesisHash: f.hash(0),
      accountId: owner,
      block: at,
      citizens: {f.cidA},
    );
    expect(data.ownCid, f.cidA);
    expect(data.memberActive(f.cidA), isTrue);
    expect(data.prices.length, 3);
    expect(data.chainNowMs, 1000);
    final keys = calls.expand((e) => e).toList();
    expect(keys.toSet().length, keys.length);
    expect(calls.first.length, greaterThan(4));
  });
  test('链上键不存在才表示无会员，失败不能变成无会员', () async {
    values.remove(
      id(SubscriptionChain.buildSubscriptionStorageKey(runtime, f.cidA, null)),
    );
    final data = await reader.read(
      genesisHash: f.hash(0),
      accountId: owner,
      block: at,
    );
    expect(data.own!.platform, isNull);
    expect(data.memberActive(f.cidA), isFalse);
    final broken = ChainDataReader(
      getRuntimeContext: (_) async => runtime,
      getStorageBatch: (_, __) async => throw StateError('proof unavailable'),
    );
    await expectLater(
      broken.read(genesisHash: f.hash(0), accountId: owner, block: at),
      throwsStateError,
    );
  });
  test('反向绑定错配不能认定注册或会员有效', () async {
    final cid = (
      scale: CitizenIdentityChainReader.encodeBoundedBytes(utf8.encode(f.cidA)),
    );
    values[id(runtime.storageKey('CitizenIdentity', 'AccountIdByCid', [cid]))] =
        citizenAccountIdBytes(f.account(2));
    final data = await reader.read(
      genesisHash: f.hash(0),
      accountId: owner,
      block: at,
      citizens: {f.cidA},
    );
    expect(data.ownCid, isNull);
    expect(data.memberActive(f.cidA), isFalse);
  });
  test('best块、混合runtime块与损坏链时间都拒绝', () async {
    await expectLater(
      reader.read(
        genesisHash: f.hash(0),
        accountId: owner,
        block: CitizenBlockRef(
          hash: at.hash,
          number: at.number,
          finality: CitizenBlockFinality.best,
        ),
      ),
      throwsStateError,
    );
    values[id(runtime.storageKey('Timestamp', 'Now'))] = Uint8List(2);
    await expectLater(
      reader.read(genesisHash: f.hash(0), accountId: owner, block: at),
      throwsFormatException,
    );
    await expectLater(
      reader.read(
        genesisHash: f.hash(0),
        accountId: owner,
        block: f.block(104),
      ),
      throwsA(anything),
    );
  });
}
