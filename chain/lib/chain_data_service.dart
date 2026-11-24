// 为每个SDK共享展示数据同步及价格缓存，协调前后台、账户和最终块变化。

import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'chain_data.dart';
import 'chain_data_reader.dart';
import 'chain_data_store.dart';

/// App内每个SDK只有一个同步器；UI数据走轻节点，服务端授权不进入此模型。
class ChainDataService extends ChangeNotifier {
  ChainDataService({
    required ChainDataReader reader,
    required Future<CitizenBlockRef> Function() getFinalizedHead,
    required Future<String> Function() getGenesisHash,
    required Future<String?> Function() getAccount,
    Stream<CitizenSdkEvent>? events,
    ChainDataStore? store,
    DateTime Function()? now,
    this.priceCacheDuration = const Duration(minutes: 60),
  }) : _reader = reader,
       _head = getFinalizedHead,
       _genesis = getGenesisHash,
       _account = getAccount,
       _events = events,
       _store = store,
       _now = now ?? DateTime.now;
  static final _instances = Expando<ChainDataService>();
  static ChainDataService forSdk(CitizenSdk sdk) {
    final existing = _instances[sdk];
    if (existing != null && !existing._closed) {
      return existing;
    }
    return _instances[sdk] = ChainDataService(
      reader: ChainDataReader(
        getRuntimeContext: sdk.getRuntimeContext,
        getStorageBatch: sdk.getStorageBatch,
      ),
      getFinalizedHead: sdk.getFinalizedHead,
      getGenesisHash: sdk.getGenesisHash,
      getAccount: () async =>
          (await sdk.getWalletState().result).defaultAccount?.accountId,
      events: sdk.events,
      store: IsarChainDataStore(),
    );
  }

  final ChainDataReader _reader;
  final Future<CitizenBlockRef> Function() _head;
  final Future<String> Function() _genesis;
  final Future<String?> Function() _account;
  final Stream<CitizenSdkEvent>? _events;
  final ChainDataStore? _store;
  final DateTime Function() _now;
  final Duration priceCacheDuration;
  final Map<String, ChainPriceSnapshot> _priceSnapshots = {};
  final Set<String> _restoredPrices = {}, _verifiedPrices = {};
  Future<ChainDataSnapshot?>? _priceFlight;
  final Map<(String, String, String, int), Future<ChainDataSnapshot>>
  _membershipFlights = {};

  ChainPriceSnapshot? pricesFor(String genesis) => _priceSnapshots[genesis];
  ChainPriceSnapshot? get priceSnapshot => _priceSnapshots[_scope];
  bool get pricesReady => !isStale && _pricesFresh;
  bool get _pricesFresh {
    final prices = priceSnapshot, data = _snapshot;
    if (prices == null ||
        data == null ||
        !_verifiedPrices.contains(prices.genesisHash) ||
        prices.genesisHash != data.genesisHash ||
        prices.runtimeSpecVersion != data.runtimeSpecVersion ||
        prices.runtimeTransactionVersion != data.runtimeTransactionVersion) {
      return false;
    }
    final age = _now().millisecondsSinceEpoch - prices.checkedAtMillis;
    return age >= 0 && age < priceCacheDuration.inMilliseconds;
  }

  Duration? get priceCacheRemaining {
    if (!pricesReady) return null;
    return Duration(
      milliseconds:
          priceSnapshot!.checkedAtMillis +
          priceCacheDuration.inMilliseconds -
          _now().millisecondsSinceEpoch,
    );
  }

  final _citizens = <String, int>{}, _creators = <String, int>{};
  StreamSubscription<CitizenSdkEvent>? _subscription;
  ChainDataSnapshot? _snapshot;
  ChainDataSnapshot? get snapshot => _snapshot;
  Object? _error;
  Object? get error => _error;
  bool _closed = false,
      _foreground = true,
      _started = false,
      _again = false,
      _restored = false;
  bool get isStale =>
      _error != null || !_verified || _latest?.hash != _snapshot?.block.hash;
  bool _verified = false;
  // 本人档位随共享同步器存活；页面退出不会让后续快照丢掉已加载档位。
  bool _ownCreatorRequested = false;
  Future<ChainDataSnapshot>? _ownCreatorFlight;
  int _generation = 0;
  String? _activeAccount, _scope;
  CitizenBlockRef? _latest, _pending;
  Future<void>? _flight;
  Future<ChainDataSnapshot?>? _refresh;
  Completer<ChainDataSnapshot?>? _completion;

  Future<void> start() async {
    if (_closed) {
      throw StateError('同步器已关闭');
    }
    if (!_started) {
      _started = true;
      _subscription = _events?.listen(_event);
    }
    await refresh();
  }

  void _event(CitizenSdkEvent event) {
    if (_closed) {
      return;
    }
    if (event is CitizenSdkWalletChanged) {
      _generation++;
      _activeAccount = null;
      _scope = null;
      _snapshot = null;
      _verified = false;
      _restored = false;
      _ownCreatorRequested = false;
      _ownCreatorFlight = null;
      _priceFlight = null;
      _membershipFlights.clear();
      _pending = null;
      _flight = null;
      final pending = _completion;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError('账户已变化'));
      }
      _completion = null;
      _refresh = null;
      notifyListeners();
      _backgroundRefresh();
    } else if (event is CitizenSdkFinalizedBlockChanged) {
      _enqueue(event.finalized);
    } else if (event is CitizenSdkCapabilitiesChanged && _foreground) {
      _backgroundRefresh();
    }
  }

  void _backgroundRefresh() {
    if (_foreground) {
      unawaited(refresh().catchError((Object _) => _snapshot));
    }
  }

  int _priceWatchers = 0;
  VoidCallback watchPrices() {
    _priceWatchers++;
    if (!pricesReady) {
      _again = true;
      if (_foreground && _started) {
        _backgroundRefresh();
      }
    }
    var released = false;
    return () {
      if (!released) {
        released = true;
        _priceWatchers--;
      }
    };
  }

  /// 展示命中缓存不查询最终块；交易和主动刷新显式强制核价。
  Future<ChainDataSnapshot?> ensurePrices({bool forceRefresh = false}) async {
    if (_closed) throw StateError('同步器已关闭');
    if (!forceRefresh && pricesReady) return _snapshot;
    if (forceRefresh) _again = true;
    final pending = _priceFlight;
    if (pending != null) return pending;
    final previousPrice = priceSnapshot;
    final release = watchPrices();
    late final Future<ChainDataSnapshot?> work;
    work = () async {
      var data = await refresh();
      // 请求可能在上一轮同步即将结束时加入；该轮没有采集价格就补一轮。
      if (data != null &&
          (!pricesReady ||
              forceRefresh && identical(priceSnapshot, previousPrice))) {
        _again = true;
        data = await refresh();
      }
      return data;
    }();
    _priceFlight = work;
    try {
      return await work;
    } finally {
      release();
      if (identical(_priceFlight, work)) _priceFlight = null;
    }
  }

  /// 会员页补取按完整身份合并；无会员也是可复用的已核实结果。
  Future<ChainDataSnapshot> ensureMembership({
    required String genesisHash,
    required String accountId,
    required String cidNumber,
    required int bindRev,
    bool forceRefresh = false,
  }) async {
    if (_closed) throw StateError('同步器已关闭');
    bool matches(ChainDataSnapshot? data) =>
        data?.genesisHash == genesisHash &&
        data?.accountId == accountId &&
        data?.ownCid == cidNumber &&
        data?.own?.identity?.bindRev == bindRev;
    if (!forceRefresh && matches(_snapshot) && !isStale && pricesReady) {
      return _snapshot!;
    }
    final owner = _generation;
    if (await _account() != accountId || owner != _generation || _closed) {
      throw StateError('会员身份已变化');
    }
    final key = (genesisHash, accountId, cidNumber, bindRev);
    final pending = _membershipFlights[key];
    if (pending != null) {
      if (forceRefresh) _again = true;
      return pending;
    }
    late final Future<ChainDataSnapshot> work;
    work = () async {
      ChainDataSnapshot? data;
      if (!forceRefresh &&
          _pricesFresh &&
          _snapshot?.genesisHash == genesisHash) {
        // 只让会员同步追到当前块，不因会员正在同步而重复核价。
        data = await refresh();
        if (!pricesReady) data = await ensurePrices();
      } else {
        data = await ensurePrices(
          forceRefresh: forceRefresh || !matches(_snapshot),
        );
      }
      if (data == null || !matches(data) || isStale || !pricesReady) {
        throw StateError('会员数据尚未核验');
      }
      return data;
    }();
    _membershipFlights[key] = work;
    try {
      return await work;
    } finally {
      if (identical(_membershipFlights[key], work)) {
        _membershipFlights.remove(key);
      }
    }
  }

  VoidCallback watchCitizen(String cid) => _watch(_citizens, cid);
  VoidCallback watchCreator(String cid) => _watch(_creators, cid);

  /// 本人管理页只需要本人的档位，不读取「本人订阅本人」关系。
  /// 有效快照直接返回；补取共用任务，后台最终块继续维护这份缓存。
  Future<ChainDataSnapshot> ensureOwnCreator({
    required String genesisHash,
    required String accountId,
    required String cidNumber,
    required int bindRev,
  }) async {
    if (_closed) {
      throw StateError('同步器已关闭');
    }
    bool matches(ChainDataSnapshot? data) =>
        data?.genesisHash == genesisHash &&
        data?.accountId == accountId &&
        data?.ownCid == cidNumber &&
        data?.own?.identity?.bindRev == bindRev;
    final cached = _snapshot;
    if (matches(cached) && !isStale && cached!.own?.creatorTiers != null) {
      _ownCreatorRequested = true;
      return cached;
    }
    // 初次同步尚未结束时先与当前钱包核对，避免旧页面启用新账户的关注。
    final owner = _generation;
    if (await _account() != accountId || _closed || owner != _generation) {
      throw StateError('创作者身份已变化');
    }
    if (_activeAccount != accountId || _scope != genesisHash) {
      await refresh();
      if (!matches(_snapshot)) {
        throw StateError('创作者身份已变化');
      }
    }
    final wasRequested = _ownCreatorRequested;
    _ownCreatorRequested = true;
    if (!matches(_snapshot) ||
        !wasRequested && _snapshot?.own?.creatorTiers == null) {
      _again = true;
    }
    final pending = _ownCreatorFlight;
    late final Future<ChainDataSnapshot> work;
    if (pending != null) {
      work = pending;
    } else {
      work = () async {
        final data = await refresh();
        if (data == null || isStale || data.own?.creatorTiers == null) {
          throw StateError('轻节点创作者数据尚未核验');
        }
        return data;
      }();
      _ownCreatorFlight = work;
    }
    try {
      final data = await work;
      if (!matches(data)) {
        throw StateError('创作者身份已变化');
      }
      return data;
    } finally {
      if (identical(_ownCreatorFlight, work)) {
        _ownCreatorFlight = null;
      }
    }
  }

  VoidCallback _watch(Map<String, int> values, String cid) {
    if (cid.trim().isEmpty) {
      throw ArgumentError('CID为空');
    }
    values[cid] = (values[cid] ?? 0) + 1;
    final covered = identical(values, _creators)
        ? _snapshot?.subscriptions.containsKey(cid) == true &&
              _snapshot?.citizens[cid]?.creatorTiers != null
        : _snapshot?.citizens.containsKey(cid) == true;
    if (!covered || isStale) {
      _again = true;
      if (_foreground && _started) {
        _backgroundRefresh();
      }
    }
    bool released = false;
    return () {
      if (released) {
        return;
      }
      released = true;
      final count = (values[cid] ?? 1) - 1;
      if (count <= 0) {
        values.remove(cid);
      } else {
        values[cid] = count;
      }
    };
  }

  Future<({int subscribers, BigInt monthly, CitizenBlockRef block})>
  creatorSummary(String creator, Set<String> candidates) async {
    final owner = _generation;
    final account = _activeAccount;
    final head = await _head();
    final summary = await _reader.creatorSummary(
      block: head,
      creator: creator,
      candidates: candidates,
    );
    if (_closed || owner != _generation || account != _activeAccount) {
      throw StateError('统计期间账户变化');
    }
    return summary;
  }

  Future<ChainDataSnapshot> ensureCitizen(
    String cid, {
    bool creator = false,
  }) async {
    final release = creator ? watchCreator(cid) : watchCitizen(cid);
    try {
      final data = await refresh();
      if (data == null ||
          isStale ||
          !data.citizens.containsKey(cid) ||
          creator && !data.subscriptions.containsKey(cid)) {
        throw StateError('轻节点数据尚未核验');
      }
      return data;
    } finally {
      release();
    }
  }

  Future<ChainDataSnapshot?> refresh() {
    if (_closed) {
      return Future.error(StateError('同步器已关闭'));
    }
    final existing = _refresh;
    if (existing != null) {
      return existing;
    }
    final done = Completer<ChainDataSnapshot?>();
    final work = done.future;
    _refresh = work;
    _completion = done;
    void finish() {
      if (identical(_refresh, work)) {
        _refresh = null;
      }
      if (identical(_completion, done)) {
        _completion = null;
      }
    }

    unawaited(
      _refreshHead().then<void>(
        (value) {
          finish();
          if (!done.isCompleted) {
            done.complete(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          finish();
          if (!done.isCompleted) {
            done.completeError(error, stack);
          }
        },
      ),
    );
    return work;
  }

  Future<ChainDataSnapshot?> _refreshHead() async {
    var owner = _generation;
    try {
      final generation = _generation;
      final account = await _account();
      if (_closed || generation != _generation) {
        throw StateError('账户已变化');
      }
      if (account != _activeAccount) {
        _generation++;
        _activeAccount = account;
        _flight = null;
        _pending = null;
        _snapshot = null;
        _verified = false;
        _restored = false;
        _ownCreatorRequested = false;
        _ownCreatorFlight = null;
        _priceFlight = null;
        _membershipFlights.clear();
      }
      if (account == null) {
        notifyListeners();
        return null;
      }
      owner = _generation;
      final scope = await _genesis();
      if (_closed || owner != _generation) {
        throw StateError('账户已变化');
      }
      if (_scope != null && _scope != scope) {
        _generation++;
        owner = _generation;
        _snapshot = null;
        _verified = false;
        _restored = false;
        _ownCreatorRequested = false;
        _latest = null;
        _ownCreatorFlight = null;
        _priceFlight = null;
        _membershipFlights.clear();
        _pending = null;
        _flight = null;
      }
      _scope = scope;
      if (_restoredPrices.add(scope) && !_priceSnapshots.containsKey(scope)) {
        try {
          final cachedPrices = await _store?.readPrices(scope);
          if (!_closed && owner == _generation && cachedPrices != null) {
            _priceSnapshots[scope] = cachedPrices;
            notifyListeners();
          }
        } on Object {
          /* 独立价格缓存故障不阻塞会员同步。 */
        }
      }
      if (!_restored) {
        _restored = true;
        try {
          final cached = await _store?.read(scope, account);
          if (!_closed &&
              owner == _generation &&
              _snapshot == null &&
              cached != null) {
            _snapshot = cached;
            _ownCreatorRequested = cached.own?.creatorTiers != null;
            notifyListeners();
          }
        } on Object {
          /* 本机缓存故障仍允许轻节点验真。 */
        }
      }
      final head = await _head();
      if (_closed || owner != _generation) {
        throw StateError('账户已变化');
      }
      if (!_foreground) {
        _latest = head;
        throw StateError('应用已进入后台');
      }
      _enqueue(head);
      while (_flight != null) {
        await _flight;
      }
      if (_closed || owner != _generation) {
        throw StateError('账户已变化');
      }
      if (_error != null) {
        throw StateError('轻节点读取失败');
      }
      return _snapshot;
    } on Object catch (e) {
      if (!_closed && owner == _generation) {
        _error = e;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _enqueue(CitizenBlockRef block) {
    if (_closed || block.finality != CitizenBlockFinality.finalized) {
      return;
    }
    final previous = _latest;
    if (previous != null && block.number < previous.number) {
      return;
    }
    if (previous != null &&
        block.number == previous.number &&
        block.hash != previous.hash) {
      _error = StateError('最终区块冲突');
      notifyListeners();
      return;
    }
    _latest = block;
    if (!_foreground || _activeAccount == null || _scope == null) {
      return;
    }
    final covered =
        _snapshot?.block.hash == block.hash &&
        _verified &&
        !_again &&
        _error == null;
    if (covered) {
      return;
    }
    _pending = block;
    if (_flight == null) {
      late final Future<void> work;
      work = _drain(_generation).whenComplete(() {
        if (!identical(_flight, work)) {
          return;
        }
        _flight = null;
        if (_pending != null && !_closed && _foreground) {
          _enqueue(_pending!);
        }
      });
      _flight = work;
    }
  }

  Future<void> _drain(int runGeneration) async {
    while (_pending != null &&
        !_closed &&
        _foreground &&
        runGeneration == _generation) {
      final block = _pending!;
      _pending = null;
      _again = false;
      final generation = _generation,
          account = _activeAccount!,
          scope = _scope!;
      bool current() =>
          !_closed &&
          _foreground &&
          generation == _generation &&
          account == _activeAccount;
      try {
        final value = await _reader.read(
          genesisHash: scope,
          accountId: account,
          block: block,
          citizens: {
            ..._citizens.keys,
            if (_snapshot?.ownCid != null) _snapshot!.ownCid!,
          },
          creators: _creators.keys.toSet(),
          ownCreator: _ownCreatorRequested,
          prices: _priceWatchers > 0,
        );
        if (!current()) {
          continue;
        }
        final changed =
            !_verified ||
            _error != null ||
            _snapshot?.contentKey != value.contentKey;
        if (changed) {
          try {
            await _store?.write(value, current);
          } on Object {
            /* 已验证内存数据仍可使用。 */
          }
        }
        if (!current()) {
          continue;
        }
        ChainPriceSnapshot? prices;
        if (value.pricesLoaded &&
            value.runtimeSpecVersion != null &&
            value.runtimeTransactionVersion != null) {
          prices = ChainPriceSnapshot(
            genesisHash: scope,
            block: value.block,
            runtimeSpecVersion: value.runtimeSpecVersion!,
            runtimeTransactionVersion: value.runtimeTransactionVersion!,
            checkedAtMillis: _now().millisecondsSinceEpoch,
            prices: value.prices,
          );
          try {
            await _store?.writePrices(prices, current);
          } on Object {
            /* 已核实内存价格仍可使用。 */
          }
          if (!current()) continue;
          _priceSnapshots[scope] = prices;
          _verifiedPrices.add(scope);
        }
        _snapshot = value;
        _verified = true;
        _error = null;
        if (changed || prices != null) {
          notifyListeners();
        }
        if (_again) {
          _pending = _latest;
        }
      } on Object catch (e) {
        if (current()) {
          _error = e;
          notifyListeners();
        }
      }
    }
  }

  void setForeground(bool value) {
    if (_closed || _foreground == value) {
      return;
    }
    _foreground = value;
    if (value) {
      _again = true;
      _backgroundRefresh();
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _generation++;
    final pending = _completion;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('同步器已关闭'));
    }
    _completion = null;
    _refresh = null;
    try {
      await _subscription?.cancel();
    } finally {
      super.dispose();
    }
  }
}
