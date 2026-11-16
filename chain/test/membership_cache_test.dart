import 'dart:async';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late f.Reader reader;
  late f.Store store;
  late ChainDataService source;
  late StreamController<CitizenSdkEvent> events;
  late CitizenBlockRef head;
  late String account, genesis;
  late int now, heads;
  setUp(() {
    reader = f.Reader();
    store = f.Store();
    events = StreamController.broadcast(sync: true);
    head = f.block(103);
    account = f.account(1);
    genesis = f.hash(0);
    now = 1000000;
    heads = 0;
    source = ChainDataService(
      reader: reader,
      store: store,
      events: events.stream,
      now: () => DateTime.fromMillisecondsSinceEpoch(now),
      priceCacheDuration: const Duration(minutes: 5),
      getAccount: () async => account,
      getGenesisHash: () async => genesis,
      getFinalizedHead: () async {
        heads++;
        return head;
      },
    );
  });
  tearDown(() async {
    await source.close();
    await events.close();
  });
  Future<ChainDataSnapshot> prepare({
    bool force = false,
    String? cid,
    int rev = 1,
  }) => source.ensureMembership(
    genesisHash: genesis,
    accountId: account,
    cidNumber: cid ?? (account == f.account(1) ? f.cidA : f.cidB),
    bindRev: rev,
    forceRefresh: force,
  );

  test('普通进入复用有效会员和价格，不再查询最终块，未知与无会员区分', () async {
    reader.behavior = (a, b, c, d) async =>
        f.snapshot(b, a, hasMembership: false);
    await source.start();
    await prepare();
    expect(source.snapshot!.memberActive(f.cidA), isFalse);
    expect(source.priceSnapshot!.prices['freedom'], 100);
    final before = (heads, reader.calls.length, reader.priceCalls.length);
    await prepare();
    await prepare();
    expect((heads, reader.calls.length, reader.priceCalls.length), before);
  });

  test('后台多块同步不重读价格，独立缓存保留原区块锚', () async {
    await source.start();
    await prepare();
    final priceBlock = source.priceSnapshot!.block.hash;
    for (var block = 104; block < 109; block++) {
      head = f.block(block);
      await source.refresh();
    }
    expect(reader.priceCalls.length, 1);
    expect(source.snapshot!.prices, isEmpty);
    expect(source.snapshot!.pricesLoaded, isFalse);
    expect(source.priceSnapshot!.block.hash, priceBlock);
    expect(source.snapshot!.block.hash, f.hash(108));
    expect(source.pricesReady, isTrue);
    final before = heads;
    await prepare();
    expect(heads, before);
  });

  test('会员同步进行中进入页面共用该任务，不连带重读有效价格', () async {
    await source.start();
    await prepare();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (a, b, c, d) => pending.future;
    head = f.block(104);
    final syncing = source.refresh();
    await f.flush();
    final entering = prepare();
    await f.flush();
    pending.complete(f.snapshot(head, account));
    await Future.wait([syncing, entering]);
    expect(reader.priceCalls.length, 1);
    expect(source.snapshot!.block.number, BigInt.from(104));
    expect(source.pricesReady, isTrue);
  });

  test('价格过期才补取，并行页面合并为一次读取', () async {
    await source.start();
    await prepare();
    now += const Duration(minutes: 5).inMilliseconds;
    expect(source.pricesReady, isFalse);
    expect(source.priceSnapshot!.prices['democracy'], 200);
    await Future.wait([prepare(), prepare(), prepare()]);
    expect(reader.priceCalls.length, 2);
    expect(source.pricesReady, isTrue);
  });

  test('主动刷新和交易前核价即使同块也强制读取价格', () async {
    await source.start();
    await prepare();
    reader.behavior = (a, b, c, d) async => f.snapshot(
      b,
      a,
      priceValues: const {'freedom': 900, 'democracy': 200, 'spark': 300},
    );
    await prepare(force: true);
    expect(reader.priceCalls.length, 2);
    expect(source.priceSnapshot!.prices['freedom'], 900);
  });

  test('运行时版本变化立即使旧价格失效，补取后记录新版本', () async {
    await source.start();
    await prepare();
    reader.behavior = (a, b, c, d) async =>
        f.snapshot(b, a, runtimeSpecVersion: 2);
    head = f.block(104);
    await source.refresh();
    expect(source.pricesReady, isFalse);
    expect(source.priceSnapshot!.runtimeSpecVersion, 1);
    await prepare();
    expect(reader.priceCalls.length, 2);
    expect(source.priceSnapshot!.runtimeSpecVersion, 2);
    expect(source.pricesReady, isTrue);
  });

  test('磁盘价格只供展示，重启后核验失败不开放操作，重试重新核价', () async {
    store.cached = f.snapshot(f.block(86), account);
    store.cachedPrices = ChainPriceSnapshot(
      genesisHash: genesis,
      block: f.block(86),
      runtimeSpecVersion: 1,
      runtimeTransactionVersion: 4,
      checkedAtMillis: now,
      prices: const {'freedom': 100},
    );
    reader.behavior = (_, _, _, _) => Future.error(StateError('offline'));
    await expectLater(source.start(), throwsStateError);
    expect(source.priceSnapshot!.block.hash, f.hash(86));
    expect(source.pricesReady, isFalse);
    reader.behavior = null;
    await prepare();
    expect(source.pricesReady, isTrue);
    expect(source.priceSnapshot!.block.hash, f.hash(103));
  });

  test('切换账户复用同链公开价格，仍核对新账户会员；旧CID不能命中', () async {
    await source.start();
    await prepare();
    account = f.account(2);
    events.add(const CitizenSdkWalletChanged(sequence: 1));
    await f.flush();
    final before = reader.priceCalls.length;
    await prepare();
    expect(source.snapshot!.accountId, account);
    expect(reader.priceCalls.length, before);
    await expectLater(prepare(cid: f.cidA), throwsStateError);
  });

  test('切链不串价格，重新读取价格并保留各自区块', () async {
    await source.start();
    await prepare();
    genesis = f.hash(1);
    head = f.block(86);
    await source.refresh();
    expect(source.priceSnapshot, isNull);
    await prepare();
    expect(source.priceSnapshot!.genesisHash, genesis);
    expect(source.pricesFor(f.hash(0))!.block.hash, f.hash(103));
    expect(reader.priceCalls.length, 2);
  });

  test('失败保留旧价，禁止把失败当成已核价；恢复后才能重新就绪', () async {
    await source.start();
    await prepare();
    reader.behavior = (_, _, _, _) => Future.error(StateError('offline'));
    await expectLater(prepare(force: true), throwsStateError);
    expect(source.priceSnapshot!.prices['freedom'], 100);
    expect(source.pricesReady, isFalse);
    reader.behavior = null;
    await prepare();
    expect(source.pricesReady, isTrue);
  });
}
