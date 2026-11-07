import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:citizen_system/app_log.dart';
import 'package:citizen_topup/store.dart';
import 'package:citizen_wallet/history/local_tx_store.dart';
import 'package:citizen_wallet/history/wallet_transaction_history_service.dart';

/// 交易记录展示页共用:订阅某账户在 Isar 里的交易记录变更,后台
/// SDK history 或 finalized 业务投影更新记录后，列表自动重刷——
/// 取代"提交后延时 N 秒盲刷"。子类给出重载动作,mixin 负责订阅/去抖/取消。
///
/// 用法:
/// ```dart
/// class _FooState extends State<Foo> with TxAutoRefreshMixin<Foo> {
///   @override
///   void initState() {
///     super.initState();
///     startTxAutoRefresh(account_id);
///   }
///   @override
///   Future<void> onTxRecordsChanged() => _loadRecords();
///   @override
///   void dispose() {
///     unawaited(stopTxAutoRefresh().catchError((Object _, StackTrace __) {}));
///     super.dispose();
///   }
/// }
/// ```
mixin TxAutoRefreshMixin<T extends StatefulWidget> on State<T> {
  static const Duration _debounce = Duration(milliseconds: 200);

  LocalTxAccountChangeSubscription? _txAutoSub;
  StreamSubscription<TopupChange>? _topupSub;
  Timer? _txAutoDebounce;
  String? _txAutoAccountId;
  int _txAutoGeneration = 0;
  Future<void>? _txRefreshFlight;

  /// 库变更时执行的重载(通常是页面现成的 `_loadXxx`)。
  Future<void> onTxRecordsChanged();

  /// 充值写入返回完整行，列表与摘要直接应用，不为同一变化重新读库。
  void onTopupRecordChanged(TopupChange change) {}

  /// 两处列表与钱包摘要的主动刷新共用后台同步；离线保留已有记录并继续重试。
  Future<void> refreshTxHistory() {
    if (!mounted || _txAutoAccountId == null) return Future<void>.value();
    final active = _txRefreshFlight;
    if (active != null) return active;
    final generation = _txAutoGeneration;
    Future<void> refresh() async {
      try {
        await context.read<WalletTransactionHistoryService>().sync();
      } catch (_) {
        AppLog.d('[TransactionHistory] refresh_failed');
      }
      if (mounted && generation == _txAutoGeneration) {
        await onTxRecordsChanged();
      }
    }

    late final Future<void> task;
    task = refresh().whenComplete(() {
      if (identical(_txRefreshFlight, task)) _txRefreshFlight = null;
    });
    _txRefreshFlight = task;
    return task;
  }

  /// 开始/切换监听指定账户的交易记录变更;账户为空则停止监听。
  /// 重复传同一账户是幂等空操作(不重复订阅)。
  void startTxAutoRefresh(String? accountId) {
    String? normalized;
    try {
      normalized = (accountId == null || accountId.isEmpty)
          ? null
          : LocalTxStore.requireAccountId(accountId);
    } on Object {
      normalized = null;
    }
    if (normalized == _txAutoAccountId && _txAutoSub != null) return;
    final generation = ++_txAutoGeneration;
    _txAutoDebounce?.cancel();
    _txAutoDebounce = null;
    _txRefreshFlight = null;
    _txAutoAccountId = normalized;
    final previous = _txAutoSub;
    _txAutoSub = null;
    if (previous != null) {
      _observeTxAutoFuture(previous.cancel(), '切换账户取消 watcher');
    }
    final previousTopup = _topupSub;
    _topupSub = null;
    if (previousTopup != null) {
      _observeTxAutoFuture(previousTopup.cancel(), '切换账户取消充值监听');
    }
    if (normalized == null) return;
    _topupSub = TopupStore.changes.listen((change) {
      if (mounted &&
          generation == _txAutoGeneration &&
          change.accountId == normalized) {
        onTopupRecordChanged(change);
      }
    });
    _txAutoSub = LocalTxStore.listenAccountChanges(normalized, () {
      if (!mounted || generation != _txAutoGeneration) return;
      _txAutoDebounce?.cancel();
      _txAutoDebounce = Timer(_debounce, () {
        if (!mounted || generation != _txAutoGeneration) return;
        _txAutoDebounce = null;
        _observeTxAutoFuture(onTxRecordsChanged(), '交易记录自动刷新');
      });
    });
  }

  /// 停止监听并释放定时器；返回值在原生 watcher 真正释放后完成。
  ///
  /// Flutter 的 `dispose` 无法 `await`，可直接发起本方法；UserIsar 全量擦除会通过
  /// 已登记的 lease 再次取得同一个取消 Future 并确定性等待。
  Future<void> stopTxAutoRefresh() {
    _txAutoGeneration++;
    _txRefreshFlight = null;
    _txAutoDebounce?.cancel();
    _txAutoDebounce = null;
    final subscription = _txAutoSub;
    _txAutoSub = null;
    _txAutoAccountId = null;
    final topup = _topupSub;
    _topupSub = null;
    return Future.wait<void>([
      if (subscription != null) subscription.cancel(),
      if (topup != null) topup.cancel(),
    ]).then((_) {});
  }

  void _observeTxAutoFuture(Future<void> future, String action) {
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        AppLog.d('[TxAutoRefresh] $action 失败');
      }),
    );
  }
}
