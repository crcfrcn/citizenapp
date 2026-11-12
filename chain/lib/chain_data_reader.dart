import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'chain_data.dart';
import 'citizen_identity_chain_reader.dart';
import 'subscription_chain.dart';

typedef ChainStorageRead =
    Future<List<Uint8List?>> Function(CitizenBlockRef, List<Uint8List>);

/// 每次读取固定一个finalized锚；动态绑定反查和档位名自然合并为后续批次。
class ChainDataReader {
  ChainDataReader({
    required this.getRuntimeContext,
    required this.getStorageBatch,
  });
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  getRuntimeContext;
  final ChainStorageRead getStorageBatch;
  Future<ChainDataSnapshot> read({
    required String genesisHash,
    required String accountId,
    required CitizenBlockRef block,
    Set<String> citizens = const {},
    Set<String> creators = const {},
    bool prices = false,
  }) async {
    if (block.finality != CitizenBlockFinality.finalized)
      throw StateError('只接受最终区块');
    final runtime = await getRuntimeContext(block);
    if (runtime.block.hash != block.hash ||
        runtime.block.number != block.number)
      throw StateError('runtime区块不一致');
    final batch = _BlockStorage(block, getStorageBatch);
    final identities = CitizenIdentityChainReader(
      getFinalizedHead: () async => block,
      getRuntimeContext: (_) async => runtime,
      getStorageBatch: batch.read,
      getStorage: batch.single,
    );
    final subscriptions = SubscriptionChain(
      getFinalizedHead: () async => block,
      getRuntimeContext: (_) async => runtime,
      getStorageBatch: batch.read,
      getStorage: batch.single,
    );
    final ownFuture = identities.readByAccountId(accountId, at: block);
    final nowFuture = batch.single(
      block,
      runtime.storageKey('Timestamp', 'Now'),
    );
    const levels = ['freedom', 'democracy', 'spark'];
    final pricesFuture = prices
        ? batch.read(block, [
            for (final level in levels)
              runtime.storageKey('SquarePost', 'PlatformPrice', [
                SubscriptionChain.membershipLevelVariant(level),
              ]),
          ])
        : Future.value(<Uint8List?>[]);
    final data = <String, Future<ChainCitizenData>>{};
    Future<ChainCitizenData> citizen(
      String cid, [
      CitizenIdentityChainSnapshot? own,
    ]) async {
      final values = await Future.wait<Object?>([
        own == null
            ? identities.readByCidNumber(cid, at: block)
            : Future.value(own),
        subscriptions.fetchSubscriptionSnapshot(cidNumber: cid, at: block),
        creators.contains(cid)
            ? subscriptions.fetchCreatorPlansAtBlock(cid, block)
            : Future.value(null),
      ]);
      return ChainCitizenData(
        cidNumber: cid,
        identity: values[0] as CitizenIdentityChainSnapshot?,
        platform: (values[1] as FinalizedSubscriptionSnapshot).state,
        creatorTiers: values[2] == null
            ? null
            : List.unmodifiable(values[2] as List<ChainCreatorTier>),
      );
    }

    for (final cid in {...citizens, ...creators}) {
      data[cid] = citizen(cid);
    }
    // Attach error handlers immediately, including while the default CID is being discovered.
    final targets = Future.wait(data.values);
    final common = Future.wait<Object?>([
      ownFuture,
      nowFuture,
      pricesFuture,
      targets,
    ]);
    final resolved = await common;
    final own = resolved[0] as CitizenIdentityChainSnapshot?;
    if (own != null && !data.containsKey(own.cidNumber))
      data[own.cidNumber] = citizen(own.cidNumber, own);
    final entries = await Future.wait(
      data.entries.map((e) async => MapEntry(e.key, await e.value)),
    );
    final subscribed = <String, ChainSubscriptionState?>{};
    if (own != null) {
      final values = await Future.wait([
        for (final cid in creators)
          subscriptions.fetchSubscriptionSnapshot(
            cidNumber: own.cidNumber,
            creatorCid: cid,
            at: block,
          ),
      ]);
      for (var i = 0; i < creators.length; i++)
        subscribed[creators.elementAt(i)] = values[i].state;
    }
    final now = resolved[1] as Uint8List?;
    if (now == null || now.length != 8) throw const FormatException('链时间无效');
    final chainNow = CitizenScale.readUnsigned(now, 0, 8).toInt();
    if (chainNow <= 0 || chainNow > 9007199254740991)
      throw const FormatException('链时间越界');
    final rawPrices = resolved[2] as List<Uint8List?>,
        decodedPrices = <String, int>{};
    for (var i = 0; prices && i < levels.length; i++) {
      final bytes = rawPrices[i];
      if (bytes == null) continue;
      if (bytes.length != 16) throw const FormatException('链上价格布局无效');
      final amount = CitizenScale.readUnsigned(bytes, 0, 16);
      if (amount <= BigInt.zero || amount > BigInt.from(9007199254740991))
        throw const FormatException('链上价格越界');
      decodedPrices[levels[i]] = amount.toInt();
    }
    return ChainDataSnapshot(
      genesisHash: genesisHash,
      accountId: accountId,
      block: block,
      chainNowMs: chainNow,
      ownCid: own?.cidNumber,
      citizens: Map.fromEntries(entries),
      subscriptions: subscribed,
      prices: decodedPrices,
      pricesLoaded: prices,
    );
  }

  Future<({int subscribers, BigInt monthly, CitizenBlockRef block})>
  creatorSummary({
    required CitizenBlockRef block,
    required String creator,
    required Set<String> candidates,
  }) async {
    if (block.finality != CitizenBlockFinality.finalized)
      throw StateError('统计只接受最终块');
    final runtime = await getRuntimeContext(block);
    if (runtime.block.hash != block.hash ||
        runtime.block.number != block.number)
      throw StateError('统计Runtime错块');
    final batch = _BlockStorage(block, getStorageBatch);
    final subs = SubscriptionChain(
      getFinalizedHead: () async => block,
      getRuntimeContext: (_) async => runtime,
      getStorageBatch: batch.read,
      getStorage: batch.single,
    );
    final time = await batch.single(
      block,
      runtime.storageKey('Timestamp', 'Now'),
    );
    if (time == null || time.length != 8)
      throw const FormatException('统计链时间无效');
    final now = CitizenScale.readUnsigned(time, 0, 8).toInt();
    if (now <= 0 || now > 9007199254740991)
      throw const FormatException('统计链时间越界');
    var count = 0;
    var monthly = BigInt.zero;
    final ids = candidates.toList();
    for (var offset = 0; offset < ids.length; offset += 32) {
      final rows = await Future.wait([
        for (final cid in ids.skip(offset).take(32))
          subs.fetchSubscriptionSnapshot(
            cidNumber: cid,
            creatorCid: creator,
            at: block,
          ),
      ]);
      for (final row in rows) {
        final value = row.state;
        if (value == null || !value.isEffectiveAt(now)) continue;
        if (value.plan.kind != 'creator')
          throw const FormatException('统计订阅用途错误');
        final months = switch (value.plan.billingPeriod) {
          'monthly' => 1,
          'quarterly' => 3,
          'yearly' => 12,
          _ => throw const FormatException('统计周期无效'),
        };
        count++;
        monthly += value.priceFen ~/ BigInt.from(months);
      }
    }
    return (subscribers: count, monthly: monthly, block: block);
  }
}

final class _BlockStorage {
  _BlockStorage(this.block, this.fetch);
  final CitizenBlockRef block;
  final ChainStorageRead fetch;
  final _values = <String, Future<Uint8List?>>{};
  final _pending = <String, (Uint8List, Completer<Uint8List?>)>{};
  bool _scheduled = false;
  Future<Uint8List?> single(CitizenBlockRef at, Uint8List key) async =>
      (await read(at, [key])).single;
  Future<List<Uint8List?>> read(CitizenBlockRef at, List<Uint8List> keys) {
    if (at.hash != block.hash) throw StateError('禁止跨块混读');
    return Future.wait([for (final key in keys) _value(key)]);
  }

  Future<Uint8List?> _value(Uint8List key) {
    final id = base64Encode(key);
    return _values.putIfAbsent(id, () {
      final done = Completer<Uint8List?>();
      _pending[id] = (key, done);
      if (!_scheduled) {
        _scheduled = true;
        scheduleMicrotask(_flush);
      }
      return done.future;
    });
  }

  Future<void> _flush() async {
    _scheduled = false;
    final work = _pending.values.toList();
    _pending.clear();
    for (var offset = 0; offset < work.length; offset += 256) {
      final chunk = work.skip(offset).take(256).toList();
      try {
        final values = await fetch(block, [for (final e in chunk) e.$1]);
        if (values.length != chunk.length) throw StateError('批量存储响应缺失');
        for (var i = 0; i < chunk.length; i++) chunk[i].$2.complete(values[i]);
      } on Object catch (e, st) {
        for (final item in chunk) item.$2.completeError(e, st);
      }
    }
  }
}
