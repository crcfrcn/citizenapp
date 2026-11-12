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
  }) : _reader = reader,
       _head = getFinalizedHead,
       _genesis = getGenesisHash,
       _account = getAccount,
       _events = events,
       _store = store;
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
    if (_snapshot?.pricesLoaded != true) {
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

  Future<ChainDataSnapshot?> ensurePrices() async {
    final release = watchPrices();
    try {
      return await refresh();
    } finally {
      release();
    }
  }

  VoidCallback watchCitizen(String cid) => _watch(_citizens, cid);
  VoidCallback watchCreator(String cid) => _watch(_creators, cid);
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
      _scope = scope;
      if (!_restored) {
        _restored = true;
        try {
          final cached = await _store?.read(scope, account);
          if (!_closed &&
              owner == _generation &&
              _snapshot == null &&
              cached != null) {
            _snapshot = cached;
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
        _snapshot = value;
        _verified = true;
        _error = null;
        if (changed) {
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
