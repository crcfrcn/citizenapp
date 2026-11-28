// 验证同步调度、会员价格缓存、并发、过期及生命周期。

import 'dart:async';
import 'package:citizen_chain/service.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/chain.dart' as f;

void main() {
  group('同步调度', _syncTests);
  group('会员价格缓存', _priceTests);
}

// 验证共享同步、账户代次、后台暂停及失败保留和重试。

void _syncTests() {
  late StreamController<CitizenSdkEvent> events;
  late f.Reader reader;
  late f.Store store;
  late ChainDataService service;
  late String owner;
  late String genesis;
  late int headReads;
  late CitizenBlockRef head;
  setUp(() {
    events = StreamController.broadcast(sync: true);
    reader = f.Reader();
    store = f.Store();
    owner = f.account(1);
    genesis = f.hash(0);
    headReads = 0;
    head = f.block(103);
    service = ChainDataService(
      reader: reader,
      store: store,
      getAccount: () async => owner,
      getGenesisHash: () async => genesis,
      getFinalizedHead: () async {
        headReads++;
        return head;
      },
      events: events.stream,
    );
  });
  tearDown(() async {
    await service.close();
    await events.close();
  });
  test('同一最终块合并读取，只有业务数据改变才写库或通知', () async {
    var notifications = 0;
    service.addListener(() => notifications++);
    await service.start();
    final release = service.watchCitizen(f.cidA);
    addTearDown(release);
    await Future.wait([service.refresh(), service.refresh()]);
    expect(reader.calls.length, 1);
    expect(store.writes.length, 1);
    final before = notifications;
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    expect(service.snapshot!.block.number, BigInt.from(104));
    expect(store.writes.length, 1);
    expect(notifications, before);
  });
  test('读取中连续最终块只追随最新块，跳过中间块', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (a, b, c, d) => b.number == BigInt.from(104)
        ? pending.future
        : Future.value(f.snapshot(b, a, citizens: c, creators: d));
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    events.add(
      CitizenSdkFinalizedBlockChanged(sequence: 2, finalized: f.block(105)),
    );
    head = f.block(106);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 3, finalized: head));
    pending.complete(f.snapshot(f.block(104), owner));
    await f.flush();
    expect(reader.calls.map((e) => e.$2), [103, 104, 106]);
    expect(service.snapshot!.block.number, BigInt.from(106));
  });
  test('换账户立即撤下旧状态，迟到读取不能写回', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (a, b, c, d) => a == f.account(1)
        ? pending.future
        : Future.value(f.snapshot(b, a, citizens: c, creators: d));
    head = f.block(104);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    owner = f.account(2);
    events.add(const CitizenSdkWalletChanged(sequence: 2));
    expect(service.snapshot, isNull);
    await f.flush();
    expect(service.snapshot!.accountId, owner); // 新账户不等待旧账户的请求。
    pending.complete(f.snapshot(head, f.account(1)));
    await f.flush();
    expect(service.snapshot!.accountId, owner);
    expect(store.writes.map((e) => e.accountId), [f.account(1), f.account(2)]);
  });
  test('读取失败保留成功状态并标记陈旧，重试恢复', () async {
    await service.start();
    reader.behavior = (_, _, _, _) =>
        Future.error(StateError('proof unavailable'));
    head = f.block(104);
    await expectLater(service.refresh(), throwsStateError);
    expect(service.snapshot!.block.number, BigInt.from(103));
    expect(service.isStale, isTrue);
    reader.behavior = null;
    await service.refresh();
    expect(service.isStale, isFalse);
    expect(service.snapshot!.block.number, BigInt.from(104));
  });
  test('后台暂停业务读取，恢复直接追到最新最终块', () async {
    await service.start();
    service.setForeground(false);
    head = f.block(110);
    events.add(CitizenSdkFinalizedBlockChanged(sequence: 1, finalized: head));
    await f.flush();
    expect(reader.calls.length, 1);
    service.setForeground(true);
    await f.flush();
    expect(reader.calls.map((e) => e.$2), [103, 110]);
  });
  test('恢复缓存仍需轻节点核验，不能把缓存当作新最终块', () async {
    store.cached = f.snapshot(f.block(86), owner);
    reader.behavior = (_, _, _, _) => Future.error(StateError('offline'));
    await expectLater(service.start(), throwsStateError);
    expect(service.snapshot!.block.number, BigInt.from(86));
    expect(service.isStale, isTrue);
  });
  test('按需关注可移除，下一块不再读取已离开的目标', () async {
    await service.start();
    final release = service.watchCitizen(f.cidB);
    await service.refresh();
    expect(service.snapshot!.citizens.containsKey(f.cidB), isTrue);
    release();
    head = f.block(104);
    await service.refresh();
    expect(service.snapshot!.citizens.containsKey(f.cidB), isFalse);
  });
  test('最终块跨过已付终期后，生效状态变化必须通知并持久化', () async {
    reader.behavior = (a, b, c, d) => Future.value(
      f.snapshot(b, a, paidUntil: 1104, citizens: c, creators: d),
    );
    await service.start();
    expect(service.snapshot!.memberActive(f.cidA), isTrue);
    head = f.block(104);
    await service.refresh();
    expect(service.snapshot!.memberActive(f.cidA), isFalse);
    expect(store.writes.length, 2);
  });
  Future<ChainDataSnapshot> own({
    String? account,
    String? cid,
    int revision = 1,
  }) => service.ensureOwnCreator(
    genesisHash: genesis,
    accountId: account ?? owner,
    cidNumber: cid ?? (owner == f.account(1) ? f.cidA : f.cidB),
    bindRev: revision,
  );

  test('本人档位补取合并，有效缓存重复进入不请求区块或重读', () async {
    await service.start();
    expect(service.snapshot!.own!.creatorTiers, isNull);
    final results = await Future.wait([own(), own(), own()]);
    expect(results.every((v) => v.own!.creatorTiers != null), isTrue);
    expect(reader.calls.length, 2);
    expect(service.snapshot!.subscriptions, isEmpty);
    final beforeHeads = headReads;
    await own();
    expect(reader.calls.length, 2);
    expect(headReads, beforeHeads);
    reader.ownBehavior = (_, _, _, _, _) => throw StateError('缓存命中不能重读');
    await own();
    expect(service.isStale, isFalse);
  });
  test('本人关注不随页面退出丢失，下一块保留；其他创作者仍按需释放', () async {
    await service.start();
    await own();
    final release = service.watchCreator(f.cidB);
    await service.refresh();
    release();
    head = f.block(104);
    await service.refresh();
    expect(service.snapshot!.own!.creatorTiers, isNotNull);
    expect(service.snapshot!.citizens.containsKey(f.cidB), isFalse);
    expect(service.snapshot!.subscriptions, isEmpty);
    final before = reader.calls.length;
    await own();
    expect(reader.calls.length, before);
  });
  test('无会员和空档位也是已确认缓存，反复进入不补取', () async {
    reader.ownBehavior = (a, b, c, d, ownCreator) async => f.snapshot(
      b,
      a,
      citizens: c,
      creators: d,
      ownCreator: ownCreator,
      hasMembership: false,
    );
    await service.start();
    final data = await own();
    expect(data.memberActive(f.cidA), isFalse);
    expect(data.own!.creatorTiers, isEmpty);
    final before = reader.calls.length;
    await own();
    expect(reader.calls.length, before);
  });
  test('磁盘恢复本人档位关注，核验失败只保留陈旧展示，重试可恢复', () async {
    store.cached = f.snapshot(f.block(86), owner, ownCreator: true);
    reader.ownBehavior = (_, _, _, _, _) => Future.error(StateError('offline'));
    await expectLater(service.start(), throwsStateError);
    expect(service.snapshot!.own!.creatorTiers, isNotNull);
    await expectLater(own(), throwsStateError);
    expect(service.isStale, isTrue);
    reader.ownBehavior = null;
    await own();
    expect(service.isStale, isFalse);
    expect(service.snapshot!.block.number, BigInt.from(103));
    expect(service.snapshot!.own!.creatorTiers, isNotNull);
  });
  test('账户切换时本人关注重新按新身份准备，旧请求不能写回', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.ownBehavior = (a, b, c, d, ownCreator) => a == f.account(1)
        ? pending.future
        : Future.value(f.snapshot(b, a, ownCreator: ownCreator));
    final old = own();
    final rejected = expectLater(old, throwsStateError);
    await f.flush();
    owner = f.account(2);
    events.add(const CitizenSdkWalletChanged(sequence: 1));
    await f.flush();
    expect(service.snapshot!.own!.creatorTiers, isNull);
    await own();
    pending.complete(f.snapshot(head, f.account(1), ownCreator: true));
    await rejected;
    await f.flush();
    expect(service.snapshot!.accountId, f.account(2));
    expect(service.snapshot!.own!.creatorTiers, isNotNull);
    expect(store.writes.last.accountId, f.account(2));
  });
  test('同账户绑定CID或版本改变，旧归属不能命中或交付', () async {
    await service.start();
    await own();
    reader.ownBehavior = (a, b, c, d, ownCreator) async =>
        f.snapshot(b, a, cidNumber: f.cidB, bindRev: 2, ownCreator: ownCreator);
    head = f.block(104);
    await service.refresh();
    await expectLater(own(), throwsStateError);
    final before = reader.calls.length;
    final data = await own(cid: f.cidB, revision: 2);
    expect(data.ownCid, f.cidB);
    expect(reader.calls.length, before);
  });

  test('同账户切换链不复用旧链缓存，也不把旧链高度当成新链高度', () async {
    await service.start();
    await own();
    genesis = f.hash(1);
    head = f.block(86);
    await service.refresh();
    expect(service.snapshot!.genesisHash, genesis);
    expect(service.snapshot!.block.number, BigInt.from(86));
    expect(service.snapshot!.own!.creatorTiers, isNull);
    await own();
    expect(service.snapshot!.own!.creatorTiers, isNotNull);
    expect(service.snapshot!.genesisHash, genesis);
    await service.close();
    await expectLater(own(), throwsStateError);
  });

  test('关闭不等待未返回的SDK请求，迟到结果不写库或通知', () async {
    await service.start();
    final pending = Completer<ChainDataSnapshot>();
    reader.behavior = (_, _, _, _) => pending.future;
    head = f.block(104);
    final refresh = service.refresh();
    final rejected = expectLater(refresh, throwsStateError);
    await f.flush();
    await service.close().timeout(const Duration(seconds: 1));
    await rejected;
    pending.complete(f.snapshot(head, owner));
    await f.flush();
    expect(store.writes.length, 1);
  });
}

// 验证会员价格缓存、并发合并、过期及交易前强制核价。

void _priceTests() {
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
