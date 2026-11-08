import 'package:citizen_storage/user_isar.dart'
    as wallet_store
    show WalletCursor, Entry;

import 'dart:async';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_system/app_log.dart';
import 'package:citizen_wallet/history/local_tx_store.dart';

/// 钱包业务流水的唯一同步入口；所有读取复用 SDK 已验证链。
/// SDK history 决定本机提交状态，App 原子保存业务事件与逐账户进度。
final class WalletTransactionHistoryService {
  WalletTransactionHistoryService({
    CitizenSdk? history,
    CitizenSdk? chain,
    CitizenSdk? wallet,
    required Stream<CitizenSdkEvent> events,
    CitizenBalances? balances,
    Future<CitizenAccountBalance> Function(String accountId)? getAccountBalance,
    Future<List<CitizenAccountBalance>> Function(List<String> accountIds)?
    getAccountBalances,
    Future<CitizenTransactionHistoryPage> Function()? syncTransactionHistory,
    Future<CitizenTransactionHistoryPage> Function({
      String? beforeExecutionId,
      int limit,
    })?
    getTransactionHistory,
    Future<String> Function()? getGenesisHash,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenBlockRef> Function(BigInt number)? getFinalizedBlockAt,
    Future<List<CitizenBlockRef>> Function(BigInt start, BigInt end)? getFinalizedBlockRange,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<CitizenSystemEvent>> Function(CitizenBlockRef block)? getFinalizedEvents,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<CitizenBlockBody> Function(CitizenBlockRef block)? getBlockBody,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
  }) : _sdkEvents = events,
       _balances =
           balances ??
           chain?.balances ??
           CitizenBalances(
             getAccountBalance:
                 getAccountBalance ?? (_) => throw StateError('未配置余额读取'),
             getAccountBalances:
                 getAccountBalances ?? (_) => throw StateError('未配置批量余额读取'),
           ),
       _syncTransactionHistory =
           syncTransactionHistory ??
           history?.syncTransactionHistory ??
           (() => throw StateError('未配置syncTransactionHistory')),
       _getTransactionHistory =
           getTransactionHistory ??
           history?.getTransactionHistory ??
           (({String? beforeExecutionId, int limit = 100}) =>
               throw StateError('未配置getTransactionHistory')),
       _getGenesisHash =
           getGenesisHash ??
           chain?.getGenesisHash ??
           (() => throw StateError('未配置getGenesisHash')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getFinalizedBlockAt =
           getFinalizedBlockAt ??
           chain?.getFinalizedBlockAt ??
           ((BigInt number) => throw StateError('未配置getFinalizedBlockAt')),
       _getFinalizedBlockRange = getFinalizedBlockRange ?? chain?.getFinalizedBlockRange ??
           ((_, _) => throw StateError('未配置 SDK finalized 区块范围')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getFinalizedEvents = getFinalizedEvents ?? chain?.getFinalizedEvents ??
           ((block) => readCitizenFinalizedEvents(
             block,
             readEvents: getSystemEvents ?? (_) => throw StateError('未配置事件读取'),
             readRuntime: getRuntimeContext ?? (_) => throw StateError('未配置事件 metadata'),
           )),
       _getBlockBody =
           getBlockBody ??
           chain?.getBlockBody ??
           ((CitizenBlockRef block) => throw StateError('未配置getBlockBody')),
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState'));
  final Future<CitizenTransactionHistoryPage> Function()
  _syncTransactionHistory;
  final Future<CitizenTransactionHistoryPage> Function({
    String? beforeExecutionId,
    int limit,
  })
  _getTransactionHistory;
  final Future<String> Function() _getGenesisHash;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenBlockRef> Function(BigInt number) _getFinalizedBlockAt;
  final Future<List<CitizenBlockRef>> Function(BigInt start, BigInt end) _getFinalizedBlockRange;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<CitizenSystemEvent>> Function(CitizenBlockRef block) _getFinalizedEvents;
  final Future<CitizenBlockBody> Function(CitizenBlockRef block) _getBlockBody;
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final CitizenBalances _balances;

  final Stream<CitizenSdkEvent> _sdkEvents;
  StreamSubscription<CitizenSdkEvent>? _events;
  IsarConsumerLease? _lease;
  Future<void>? _flight;
  Timer? _retry;
  bool _active = false;
  bool _foreground = true;
  int _epoch = 0;
  int _retrySeconds = 2;
  bool _requested = false;
  final _submissionWrites = <Future<void>>{};

  /// 表单只绑定已签记录的产品字段。SDK 历史通知负责及时写入，结束时回读原记录。
  Future<T> trackTransfer<T>({
    required CitizenSdk sdk,
    required CitizenPreparedTransaction prepared,
    required BigInt amountFen,
    required String fromAddress,
    required String toAddress,
    required String remark,
    required Future<T> Function() execute,
  }) async {
    final epoch = _epoch;
    Future<void> save(CitizenTransactionHistoryRecord record) async {
      if (!_current(epoch)) return;
      final write = LocalTxStore.applyExecution(
        record,
        amountFen: amountFen,
        fromAddress: fromAddress,
        toAddress: toAddress,
        txNote: remark,
      ).catchError((Object _) {
        AppLog.d('[TransactionHistory] submission_projection_failed');
      });
      _submissionWrites.add(write);
      try {
        await write;
      } finally {
        _submissionWrites.remove(write);
      }
    }

    final subscription = sdk.watchPreparedTransaction(prepared)
        .asyncMap(save)
        .listen((_) {}, onError: (Object _) {
          AppLog.d('[TransactionHistory] submission_watch_failed');
        });
    try {
      return await execute();
    } finally {
      try {
        await subscription.cancel();
      } on Object {
        AppLog.d('[TransactionHistory] submission_watch_close_failed');
      }
      if (_current(epoch)) {
        try {
          final latest = await sdk.getPreparedTransactionRecord(prepared);
          if (latest != null) await save(latest);
        } on Object {
          AppLog.d('[TransactionHistory] submission_read_failed');
        }
      }
    }
  }


  /// 启动不等待网络补齐，离线不能阻塞钱包原页面。
  Future<void> start() async {
    if (_active) return;
    _lease = UserIsar.instance.registerExternalConsumer(stop);
    _active = true;
    _events = _sdkEvents.listen((event) {
      if (event is CitizenSdkWalletChanged) _epoch++;
      if (event is CitizenSdkWalletChanged ||
          event is CitizenSdkHistoryChanged ||
          event is CitizenSdkFinalizedBlockChanged) {
        requestSync();
      }
    });
    requestSync();
  }

  /// 后台停止调度，迟到结果失效；前台从持久进度继续。
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _epoch++;
      _retry?.cancel();
      _retry = null;
    } else {
      requestSync();
    }
  }

  void requestSync() {
    if (!_active || !_foreground) return;
    unawaited(
      sync().catchError((Object _) {
        AppLog.d('[TransactionHistory] sync_failed');
      }),
    );
  }

  /// 手动刷新和 SDK 事件合并在途任务，最多每轮处理 32 块。
  Future<void> sync() {
    if (!_active || !_foreground) return Future<void>.value();
    if (_flight != null) {
      _requested = true;
      return _flight!;
    }
    _retry?.cancel();
    _retry = null;
    _requested = false;
    final epoch = _epoch;
    final future = _syncPass(epoch)
        .then((more) {
          _retrySeconds = 2;
          if (more || _requested || epoch != _epoch) {
            _schedule(const Duration(seconds: 1));
          }
        })
        .catchError((Object error, StackTrace stack) {
          _schedule(Duration(seconds: _retrySeconds));
          _retrySeconds = (_retrySeconds * 2).clamp(2, 30);
          Error.throwWithStackTrace(error, stack);
        })
        .whenComplete(() => _flight = null);
    _flight = future;
    return future;
  }

  void _schedule(Duration delay) {
    if (!_active || !_foreground || _retry != null) return;
    _retry = Timer(delay, () {
      _retry = null;
      requestSync();
    });
  }

  bool _current(int epoch) => _active && _foreground && epoch == _epoch;

  /// 停止后等待在途读取退出，禁止迟到写入重新打开已擦除的库。
  Future<void> stop() async {
    _active = false;
    _epoch++;
    _retry?.cancel();
    _retry = null;
    final events = _events;
    _events = null;
    await events?.cancel();
    try {
      await _flight;
    } catch (_) {
      // 读取失败不阻断关闭；业务进度留在上次已提交块。
    } finally {
      await Future.wait(_submissionWrites.toList());
      _lease?.release();
      _lease = null;
    }
  }

  Future<void> _syncExecutionFacts(int epoch) async {
    var page = await _syncTransactionHistory();
    final consumed = <String>{};
    while (true) {
      for (final record in page.records) {
        if (!_current(epoch)) return;
        await _applyExecution(record);
      }
      final cursor = page.nextBeforeExecutionId;
      if (cursor == null) return;
      if (!consumed.add(cursor)) throw StateError('SDK history 分页游标重复');
      page = await _getTransactionHistory(beforeExecutionId: cursor);
    }
  }

  Future<void> _applyExecution(CitizenTransactionHistoryRecord record) async {
    await LocalTxStore.applyExecution(record);
    final accountId = record.sourceAccountId;
    final block = record.block;
    if (_active &&
        _foreground &&
        block != null &&
        (record.status == CitizenTransactionHistoryStatus.finalizedSuccess ||
            record.status == CitizenTransactionHistoryStatus.finalizedFailed)) {
      try {
        await _balances.afterFinalized(block, [accountId]);
      } catch (_) {
        // 交易的链上结果已确认；余额刷新失败不得把结果降为失败或清空原快照。
      }
    }
  }

  Future<bool> _syncPass(int epoch) async {
    await _syncExecutionFacts(epoch);
    if (!_current(epoch)) return false;
    final wallet = await _getWalletState().result;
    if (!_current(epoch) || wallet.accounts.isEmpty) return false;
    final genesis = await _getGenesisHash();
    final head = await _getFinalizedHead();
    if (head.number < BigInt.zero ||
        head.number >= BigInt.from(0x7fffffffffffffff)) {
      throw StateError('finalized 高度超出本机进度范围');
    }
    _requireBlock(head, head.number.toInt());
    final cursors = <String, wallet_store.WalletCursor>{};
    final accounts = {for (final a in wallet.accounts) a.accountId: a};
    // 同次导入的多个账户共享边界定位结果，避免重复二分查询。
    final starts = <BigInt, int>{};
    for (final account in accounts.values) {
      if (!_current(epoch)) return false;
      var cursor = await LocalTxStore.historyCursor(account.accountId);
      if (cursor == null) {
        final start =
            starts[account.createdAtMillis] ??
            await _findStartBlock(head, account.createdAtMillis, epoch);
        starts[account.createdAtMillis] = start;
        if (!_current(epoch)) return false;
        cursor = wallet_store.WalletCursor()
          ..accountId = account.accountId
          ..createdAt = account.createdAtMillis.toInt()
          ..genesisHash = genesis
          ..startBlock = start
          ..cursorBlock = start - 1;
        await LocalTxStore.insertHistoryCursor(cursor);
      }
      if (cursor.genesisHash != genesis ||
          BigInt.from(cursor.createdAt) != account.createdAtMillis ||
          cursor.startBlock < 1 ||
          cursor.cursorBlock < cursor.startBlock - 1 ||
          cursor.cursorBlock > head.number.toInt()) {
        throw StateError('钱包进度的链身份或账户代次不一致');
      }
      cursors[account.accountId] = cursor;
    }
    final first = cursors.values
        .map((c) => c.cursorBlock + 1)
        .reduce((a, b) => a < b ? a : b);
    final target = head.number.toInt();
    final end = first + 31 < target ? first + 31 : target;
    final blocks = first > end
        ? const <CitizenBlockRef>[]
        : await _getFinalizedBlockRange(BigInt.from(first), BigInt.from(end));
    for (final block in blocks) {
      if (!_current(epoch)) return false;
      final number = block.number.toInt();
      final time = await _timestamp(block);
      final participants = cursors.values
          .where((c) => c.cursorBlock == number - 1)
          .toList();
      final addresses = <String, String>{
        for (final c in participants)
          if (time >= c.createdAt)
            c.accountId: accounts[c.accountId]!.ss58Address,
      };
      final records = await _readRecords(block, time, addresses);
      if (!_current(epoch)) return false;
      await LocalTxStore.commitHistoryBlock(
        blockNumber: number,
        cursors: participants,
        records: records,
      );
      for (final cursor in participants) {
        cursor.cursorBlock = number;
      }
      // 历史补齐不逐块刷新余额，只有最新块影响钱包时通知余额唯一入口。
      if (number == target && records.isNotEmpty && _current(epoch)) {
        try {
          await _balances.afterFinalized(
            block,
            records.map((r) => r.accountId).toSet(),
          );
        } catch (_) {
          // 余额失败不撤销交易记录，也不清空原快照。
        }
      }
    }
    return cursors.values.any((c) => c.cursorBlock < target);
  }

  Future<int> _findStartBlock(CitizenBlockRef head, BigInt createdAt, int epoch) =>
      firstCitizenBlockAtOrAfter(
        head, createdAt, _getFinalizedBlockAt, _timestamp,
        active: () => _current(epoch),
      );

  Future<int> _timestamp(CitizenBlockRef block) => readCitizenBlockTimestamp(block, _getStorage);

  void _requireBlock(CitizenBlockRef block, int number) {
    if (number < 0 ||
        block.finality != CitizenBlockFinality.finalized ||
        block.number != BigInt.from(number)) {
      throw StateError('SDK 区块与 finalized 请求高度不一致');
    }
  }

  Future<List<wallet_store.Entry>> _readRecords(
    CitizenBlockRef block,
    int time,
    Map<String, String> addresses,
  ) async {
    final facts = await readCitizenWalletEvents(
      block,
      addresses.keys,
      readEvents: _getFinalizedEvents,
      readBody: _getBlockBody,
    );
    final records = <wallet_store.Entry>[];
    final fees = <(int, String), BigInt>{};
    for (final fee in facts.fees) {
      final index = fee.extrinsicIndex;
      if (index != null) {
        fees.update((index, fee.accountId), (total) => total + fee.feeFen,
            ifAbsent: () => fee.feeFen);
      }
    }

    wallet_store.Entry row(
      String accountId, int eventIndex, int? extrinsicIndex, String? hash,
    ) => wallet_store.Entry()
      ..accountId = accountId
      ..entryState = LocalTxStore.statusFinalized
      ..entrySource = 'sdk_finalized_event'
      ..txHash = hash
      ..blockNumber = block.number.toInt()
      ..blockHash = block.hash
      ..eventIndex = eventIndex
      ..extrinsicIndex = extrinsicIndex
      ..createdAt = time
      ..confirmedAt = time;

    final attached = <(int, String)>{};
    for (final transfer in facts.transfers) {
      final from = transfer.fromAccountId;
      final to = transfer.toAccountId;
      final index = transfer.extrinsicIndex;
      final fromAddress = citizenSs58FromAccountId(from);
      final toAddress = citizenSs58FromAccountId(to);
      for (final accountId in {from, to}) {
        if (!addresses.containsKey(accountId)) continue;
        final fee = index != null && attached.add((index, accountId))
            ? fees[(index, accountId)] : null;
        final principal = from == to ? BigInt.zero :
            accountId == to ? transfer.amountFen : -transfer.amountFen;
        records.add(row(accountId, transfer.eventIndex, index, transfer.transactionHash)
          ..entryKind = 'transfer'
          ..amountDelta = (principal - (fee ?? BigInt.zero)).toString()
          ..feeAmount = fee?.toString()
          ..transferAmount = transfer.amountFen.toString()
          ..fromAddress = fromAddress
          ..toAddress = toAddress
          ..txNote = transfer.remark);
      }
    }
    for (final fee in facts.fees) {
      final index = fee.extrinsicIndex;
      if (index != null && attached.contains((index, fee.accountId))) continue;
      records.add(row(fee.accountId, fee.eventIndex, index, fee.transactionHash)
        ..entryKind = 'fee'
        ..amountDelta = (-fee.feeFen).toString()
        ..feeAmount = fee.feeFen.toString()
        ..failReason = fee.status == CitizenExecutionStatus.failed ? '链上执行失败' : null);
    }
    return records;
  }
}
