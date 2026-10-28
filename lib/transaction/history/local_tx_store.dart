import 'package:citizenapp/storage/wallet_isar.dart'
    as wallet_store
    show WalletCursor, Entry;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizenapp/storage/wallet_isar.dart' hide Group;

/// 本机钱包交易流水存储服务。
///
/// 这里保存的是“钱包进入本机 App 之后”的余额变化流水。
/// 链上账户唯一性用account_id，流水用真实提交/事件自然字段定位，不保存拼接键。
class LocalTxStore {
  static const String statusPending = 'pending';
  static const String statusInBlock = 'inBlock';
  static const String statusFinalized = 'finalized';
  static const String statusFailed = 'failed';

  static String requireAccountId(String accountId) {
    if (!isAccountIdText(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  static String normalizeBlockHash(String blockHash) {
    return blockHash.startsWith('0x')
        ? blockHash.toLowerCase()
        : '0x${blockHash.toLowerCase()}';
  }

  static String fenFromYuan(double amountYuan) {
    return BigInt.from((amountYuan * 100).round()).toString();
  }

  static double fenToYuan(String amountFen) {
    return BigInt.parse(amountFen).toDouble() / 100.0;
  }

  static String negateFen(String amountFen) {
    final value = BigInt.parse(amountFen);
    return (-value).toString();
  }

  /// 写入或替换一条交易流水。
  static Future<void> upsert(wallet_store.Entry entity) async {
    entity.accountId = requireAccountId(entity.accountId);
    await WalletIsar.instance.writeTxn((isar) async {
      final existing =
          entity.entrySource == 'local_submit' && entity.txHash != null
          ? await _submit(isar, entity.accountId, entity.txHash!)
          : await _event(
              isar,
              entity.accountId,
              entity.blockHash,
              entity.eventIndex,
            );
      if (existing != null) entity.rowId = existing.rowId;
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 查询某个钱包的交易流水（按本机记录时间倒序）。
  /// 记录来源只描述写入路径，不能作为展示门禁；SDK execution 校验仅用于状态更新。
  static Future<List<wallet_store.Entry>> queryByAccountId(
    String accountId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final normalizedAccountId = requireAccountId(accountId);
    return WalletIsar.instance.read((isar) async {
      return isar
          .collection<wallet_store.Entry>()
          .where()
          .accountIdEqualTo(normalizedAccountId)
          .sortByCreatedAtDesc()
          .offset(offset)
          .limit(limit)
          .findAll();
    });
  }

  /// 查询某个钱包最近 N 条记录。
  static Future<List<wallet_store.Entry>> queryRecentByAccountId(
    String accountId, {
    int limit = 5,
  }) async {
    return queryByAccountId(accountId, limit: limit);
  }

  /// 单条本机记录直接使用Isar原主键，不生成第二个业务标识。
  static Future<wallet_store.Entry?> readEntry(int rowId) => WalletIsar.instance
      .read((isar) => isar.collection<wallet_store.Entry>().get(rowId));

  static Future<wallet_store.Entry?> _single(
    QueryBuilder<wallet_store.Entry, wallet_store.Entry, QAfterFilterCondition>
    query,
  ) async {
    final rows = await query.limit(2).findAll();
    if (rows.length > 1) throw StateError('交易自然身份重复，拒绝猜测合并');
    return rows.singleOrNull;
  }

  static Future<wallet_store.Entry?> _submit(
    Isar isar,
    String accountId,
    String txHash,
  ) => _single(
    isar
        .collection<wallet_store.Entry>()
        .where()
        .accountIdEqualTo(requireAccountId(accountId))
        .filter()
        .txHashEqualTo(txHash.toLowerCase())
        .entrySourceEqualTo('local_submit'),
  );

  static Future<wallet_store.Entry?> _event(
    Isar isar,
    String accountId,
    String? blockHash,
    int? eventIndex,
  ) {
    if (blockHash == null ||
        blockHash.isEmpty ||
        eventIndex == null ||
        eventIndex < 0) {
      throw const FormatException('交易事件缺少真实区块和事件定位');
    }
    return _single(
      isar
          .collection<wallet_store.Entry>()
          .where()
          .accountIdEqualTo(requireAccountId(accountId))
          .filter()
          .blockHashEqualTo(normalizeBlockHash(blockHash))
          .eventIndexEqualTo(eventIndex),
    );
  }

  /// 写入本机发起的普通转账记录。
  ///
  /// SDK execution/history 和 finalized 业务事件可能先于页面本地写入返回。这里先查是否
  /// 已有同账户、同准确交易哈希的区块事件记录；若有，直接
  /// 合并手续费和tx_hash，避免“本金事件 + 本机扣费记录”显示两条。
  static Future<void> upsertLocalSubmitTransfer({
    required String accountId,
    required String txHash,
    required String amountDelta,
    required String transferAmount,
    required String feeAmount,
    required String fromAddress,
    required String toAddress,
    required String executionId,
    required String callHash,

    required int createdAt,
    String? txNote,
    String? blockHash,
  }) async {
    final normalizedAccountId = requireAccountId(accountId);
    final normalizedTxHash = txHash.toLowerCase();
    await WalletIsar.instance.writeTxn((isar) async {
      final existingPending = await _submit(
        isar,
        normalizedAccountId,
        normalizedTxHash,
      );
      if (existingPending != null) {
        existingPending
          ..accountId = normalizedAccountId
          ..entryKind = 'transfer'
          ..amountDelta = existingPending.eventIndex == null
              ? amountDelta
              : existingPending.amountDelta
          ..transferAmount = transferAmount
          ..feeAmount = existingPending.eventIndex == null
              ? feeAmount
              : existingPending.feeAmount
          ..fromAddress = fromAddress
          ..toAddress = toAddress
          ..txNote = _mergeRemark(txNote, existingPending.txNote)
          ..entryState = _mergeStatus(existingPending.entryState, statusPending)
          ..entrySource = 'local_submit'
          ..txHash = normalizedTxHash
          ..executionId = executionId
          ..callHash = callHash
          ..createdAt = existingPending.createdAt
          ..failReason = null;
        await isar.collection<wallet_store.Entry>().put(existingPending);
        return;
      }

      final candidates = await isar
          .collection<wallet_store.Entry>()
          .filter()
          .accountIdEqualTo(normalizedAccountId)
          .txHashEqualTo(normalizedTxHash)
          .findAll();
      final events = candidates
          .where(
            (row) =>
                row.executionId == null &&
                row.fromAddress == fromAddress &&
                row.toAddress == toAddress &&
                row.transferAmount == transferAmount,
          )
          .toList();
      if (events.length > 1) {
        throw StateError('同一提交交易匹配多个业务事件，拒绝猜测合并');
      }
      final existingEvent = events.singleOrNull;
      final entity = existingEvent ?? wallet_store.Entry();
      entity
        // SDK history按同一账户与准确tx_hash推进原记录，原row_id保持。
        ..accountId = normalizedAccountId
        ..entryKind = 'transfer'
        ..amountDelta = existingEvent?.amountDelta ?? amountDelta
        ..transferAmount = transferAmount
        ..feeAmount = existingEvent != null
            ? existingEvent.feeAmount
            : feeAmount
        ..fromAddress = fromAddress
        ..toAddress = toAddress
        ..txNote = _mergeRemark(txNote, existingEvent?.txNote)
        // 这是 SDK execution 记录；业务事件不能替 SDK 宣布交易终态。
        ..entryState = statusPending
        ..entrySource = 'local_submit'
        ..txHash = normalizedTxHash
        ..executionId = executionId
        ..callHash = callHash
        ..createdAt = existingEvent?.createdAt ?? createdAt
        ..confirmedAt = null
        ..failReason = null;
      if (blockHash != null && blockHash.isNotEmpty) {
        entity.blockHash = normalizeBlockHash(blockHash);
      }
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 写入一个经过验证的 finalized 业务事件；精确交易哈希用于关联本机提交。
  /// SDK execution 状态只由 SDK history 推进，业务事件仅补全展示字段。
  static Future<void> upsertBlockTransferEvent({
    required String accountId,
    required String entryState,
    required String amountDelta,
    required String transferAmount,
    required String fromAddress,
    required String toAddress,
    required int blockNumber,
    required String blockHash,
    required int eventIndex,
    int? extrinsicIndex,
    int? confirmedAt,
    String? txNote,
    String? feeAmount,
    String? txHash,
  }) async {
    if (entryState != statusFinalized) {
      throw ArgumentError('业务事件必须来自 finalized 区块');
    }
    final time = confirmedAt ?? DateTime.now().millisecondsSinceEpoch;
    final row = wallet_store.Entry()
      ..accountId = requireAccountId(accountId)
      ..entryKind = 'transfer'
      ..amountDelta = amountDelta
      ..transferAmount = transferAmount
      ..feeAmount = feeAmount
      ..fromAddress = fromAddress
      ..toAddress = toAddress
      ..blockNumber = blockNumber
      ..blockHash = normalizeBlockHash(blockHash)
      ..eventIndex = eventIndex
      ..extrinsicIndex = extrinsicIndex
      ..txNote = txNote
      ..txHash = txHash?.toLowerCase()
      ..entryState = statusFinalized
      ..entrySource = 'sdk_finalized_event'
      ..createdAt = time
      ..confirmedAt = time;
    await WalletIsar.instance.writeTxn((isar) => _upsertEventInTxn(isar, row));
  }

  static Future<void> _upsertEventInTxn(
    Isar isar,
    wallet_store.Entry incoming,
  ) async {
    final existing = await _event(
      isar,
      incoming.accountId,
      incoming.blockHash,
      incoming.eventIndex,
    );
    final hash = incoming.txHash;
    final submitted = hash == null
        ? null
        : await _submit(isar, incoming.accountId, hash);
    // 单独收费事件只补全同一账户与准确正文哈希的 SDK 提交，不接管其终态。
    if (incoming.entryKind == 'fee' &&
        submitted != null &&
        submitted.entrySource == 'local_submit' &&
        submitted.executionId?.isNotEmpty == true &&
        submitted.callHash?.isNotEmpty == true) {
      if (submitted.blockHash != null &&
          submitted.eventIndex != null &&
          (submitted.blockHash != incoming.blockHash ||
              submitted.eventIndex != incoming.eventIndex)) {
        throw StateError('收费事实与本机提交已绑定的事件不一致');
      }
      submitted
        ..feeAmount = incoming.feeAmount
        ..blockNumber = incoming.blockNumber
        ..blockHash = incoming.blockHash
        ..eventIndex = incoming.eventIndex
        ..extrinsicIndex = incoming.extrinsicIndex;
      if (incoming.failReason != null) {
        submitted.amountDelta = incoming.amountDelta;
      }
      await isar.collection<wallet_store.Entry>().put(submitted);
      if (existing != null && existing.rowId != submitted.rowId) {
        await isar.collection<wallet_store.Entry>().delete(existing.rowId);
      }
      return;
    }
    // 交易哈希之外还核对业务内容；同金额从来不是关联依据。
    final matchesSubmit =
        submitted != null &&
        submitted.entrySource == 'local_submit' &&
        submitted.executionId?.isNotEmpty == true &&
        submitted.callHash?.isNotEmpty == true &&
        submitted.fromAddress == incoming.fromAddress &&
        submitted.toAddress == incoming.toAddress &&
        submitted.transferAmount == incoming.transferAmount &&
        (submitted.eventIndex == null ||
            (submitted.eventIndex == incoming.eventIndex &&
                submitted.blockHash == incoming.blockHash));
    if (matchesSubmit) {
      submitted
        ..blockNumber = incoming.blockNumber
        ..blockHash = incoming.blockHash
        ..eventIndex = incoming.eventIndex
        ..extrinsicIndex = incoming.extrinsicIndex
        ..feeAmount = incoming.feeAmount
        ..amountDelta = incoming.amountDelta
        ..txNote = _mergeRemark(incoming.txNote, submitted.txNote);
      await isar.collection<wallet_store.Entry>().put(submitted);
      if (existing != null && existing.rowId != submitted.rowId) {
        // 同一个事件与同一个提交的两种到达顺序收敛到原主键。
        await isar.collection<wallet_store.Entry>().delete(existing.rowId);
      }
    } else {
      if (existing != null) {
        incoming.rowId = existing.rowId;
        incoming.createdAt = existing.createdAt;
      }
      await isar.collection<wallet_store.Entry>().put(incoming);
    }
  }

  /// 读取账户进度；调用方必须再核对导入时间与链身份。
  static Future<wallet_store.WalletCursor?> historyCursor(String accountId) =>
      WalletIsar.instance.read(
        (isar) => isar
            .collection<wallet_store.WalletCursor>()
            .where()
            .accountIdEqualTo(requireAccountId(accountId))
            .findFirst(),
      );

  /// 初始起点必须已由账户导入时间和 verified Timestamp.Now 确定。
  static Future<void> insertHistoryCursor(wallet_store.WalletCursor cursor) =>
      WalletIsar.instance.writeTxn((isar) async {
        final existing = await isar
            .collection<wallet_store.WalletCursor>()
            .where()
            .accountIdEqualTo(requireAccountId(cursor.accountId))
            .findFirst();
        if (existing != null) throw StateError('账户进度已存在，拒绝覆盖');
        if (cursor.startBlock < 1 ||
            cursor.cursorBlock != cursor.startBlock - 1) {
          throw StateError('账户进度起点无效');
        }
        await isar.collection<wallet_store.WalletCursor>().put(cursor);
      });

  /// 全块记录和所有参与账户的进度在同一事务内提交；任一步失败整体回滚。
  static Future<void> commitHistoryBlock({
    required int blockNumber,
    required List<wallet_store.WalletCursor> cursors,
    required List<wallet_store.Entry> records,
  }) => WalletIsar.instance.writeTxn((isar) async {
    final owners = <String>{};
    for (final cursor in cursors) {
      final current = await isar.collection<wallet_store.WalletCursor>().get(
        cursor.rowId,
      );
      if (current == null ||
          current.accountId != cursor.accountId ||
          current.createdAt != cursor.createdAt ||
          current.genesisHash != cursor.genesisHash ||
          current.cursorBlock != blockNumber - 1) {
        throw StateError('账户进度已变化，拒绝过期投影');
      }
      owners.add(current.accountId);
    }
    for (final record in records) {
      if (!owners.contains(record.accountId) ||
          record.blockNumber != blockNumber ||
          record.entryState != statusFinalized) {
        throw StateError('业务事件与提交范围不一致');
      }
      await _upsertEventInTxn(isar, record);
    }
    for (final cursor in cursors) {
      // 只修改从事务中读取的新对象，回滚不能污染调用方内存中的游标。
      final current = (await isar.collection<wallet_store.WalletCursor>().get(
        cursor.rowId,
      ))!;
      current.cursorBlock = blockNumber;
      await isar.collection<wallet_store.WalletCursor>().put(current);
    }
  });

  /// CitizenSDK history 显示交易已进入区块时，把本机 pending 记录升级为 inBlock。
  ///
  /// 这里不把它直接改成 finalized；最终确认只能由 SDK history 的
  /// finalizedSuccess 写回，业务事件不能越权推进。
  static Future<void> markLocalSubmitInBlock({
    required String accountId,
    required String txHash,
    required String executionId,
    required String callHash,
    String? blockHash,
  }) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final entity = await _submit(isar, accountId, txHash);
      if (entity == null ||
          !_matchesSdkExecution(entity, executionId, callHash) ||
          entity.entryState == statusFinalized ||
          entity.entryState == statusFailed) {
        return;
      }
      entity.entryState = statusInBlock;
      if (blockHash != null && blockHash.isNotEmpty) {
        entity.blockHash = normalizeBlockHash(blockHash);
      }
      entity.failReason = null;
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 根据 CitizenSDK history 的 pending 事实保持待确认。
  ///
  /// `inBlock` 只是内部进度，未获得 finalized 前始终属于 UI 的“待确认”。
  /// 保留 SDK 已投影的区块锚点，最终状态只能由后续 SDK history 覆盖。
  static Future<void> markLocalSubmitPending({
    required String accountId,
    required String txHash,
    required String executionId,
    required String callHash,
  }) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final entity = await _submit(isar, accountId, txHash);
      if (entity == null ||
          !_matchesSdkExecution(entity, executionId, callHash) ||
          entity.entryState == statusFinalized ||
          entity.entryState == statusFailed) {
        return;
      }
      // 不清 block_hash：它是 SDK 已公开的 inBlock 进度事实。
      entity
        ..entryState = statusPending
        ..failReason = null;
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 把已签名提交、且被交易池明确拒绝的交易标记为失败。
  ///
  /// 连接中断、监听超时和未获最终性确认都不能调用本入口，避免把未知结果误报为失败。
  static Future<void> markLocalSubmitFailed({
    required String accountId,
    required String txHash,
    required String executionId,
    required String callHash,
    required String failReason,
  }) async {
    await WalletIsar.instance.writeTxn((isar) async {
      final entity = await _submit(isar, accountId, txHash);
      if (entity == null ||
          !_matchesSdkExecution(entity, executionId, callHash) ||
          entity.entryState == statusFinalized) {
        return;
      }
      entity
        ..entryState = statusFailed
        ..failReason = failReason;
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 把 CitizenSDK 已核验的 finalizedSuccess 投影到对应 App 记录。
  static Future<void> markLocalSubmitFinalized({
    required String accountId,
    required String txHash,
    required String executionId,
    required String callHash,
    String? blockHash,
    int? blockNumber,
    int? extrinsicIndex,
    int? confirmedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await WalletIsar.instance.writeTxn((isar) async {
      final entity = await _submit(isar, accountId, txHash);
      if (entity == null ||
          !_matchesSdkExecution(entity, executionId, callHash) ||
          entity.entryState == statusFinalized) {
        return;
      }
      entity
        ..entryState = statusFinalized
        ..extrinsicIndex = extrinsicIndex ?? entity.extrinsicIndex
        ..confirmedAt = confirmedAt ?? now
        ..failReason = null;
      if (blockHash != null && blockHash.isNotEmpty) {
        entity.blockHash = normalizeBlockHash(blockHash);
      }
      if (blockNumber != null) {
        entity.blockNumber = blockNumber;
      }
      await isar.collection<wallet_store.Entry>().put(entity);
    });
  }

  /// 监听某账户交易记录的任何变更。SDK history 和 finalized 业务投影把记录
  /// 写成 finalized 后即触发,供交易列表页响应式重刷(见 TxAutoRefreshMixin),
  /// 取代"提交后延时 N 秒盲刷"。
  ///
  /// 返回的句柄已经在任何异步 `db()` / watcher 创建前同步登记到 [WalletIsar]；
  /// 应用锁擦除会主动取消并等待它真实释放，禁止原生 watcher 晚到挂回已关闭的库。
  static LocalTxAccountChangeSubscription listenAccountChanges(
    String accountId,
    void Function() onChanged, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final normalizedAccountId = requireAccountId(accountId);
    return LocalTxAccountChangeSubscription._listen(
      accountId: normalizedAccountId,
      onChanged: onChanged,
      onError: onError,
    );
  }

  static String _mergeStatus(String? current, String incoming) {
    final currentRank = _statusRank(current);
    final incomingRank = _statusRank(incoming);
    return incomingRank >= currentRank ? incoming : (current ?? incoming);
  }

  static String? _mergeRemark(String? incoming, String? existing) {
    final normalized = incoming == null || incoming.isEmpty ? null : incoming;
    return normalized ?? existing;
  }

  static int _statusRank(String? entryState) {
    switch (entryState) {
      case statusFinalized:
        return 4;
      case statusFailed:
        return 3;
      case statusInBlock:
        return 2;
      case statusPending:
        return 1;
      default:
        return 0;
    }
  }

  /// SDK execution_id 与 opaque callData hash 必须同时匹配本地业务记录；
  /// 仅碰巧相同的账户/交易哈希不得推进另一条业务记录的展示状态。
  static bool _matchesSdkExecution(
    wallet_store.Entry entity,
    String executionId,
    String callHash,
  ) {
    return entity.entrySource == 'local_submit' &&
        executionId.isNotEmpty &&
        callHash.isNotEmpty &&
        entity.executionId == executionId &&
        entity.callHash?.toLowerCase() == callHash.toLowerCase();
  }

  /// 删除某个账户的 CitizenApp 业务交易记录。
  /// SDK execution history 由 CitizenSDK 自己的删除和擦除合同管理。
  static Future<void> deleteWalletLocalHistory(String accountId) async {
    final normalizedAccountId = requireAccountId(accountId);
    await WalletIsar.instance.writeTxn((isar) async {
      await isar
          .collection<wallet_store.Entry>()
          .filter()
          .accountIdEqualTo(normalizedAccountId)
          .deleteAll();
      await isar
          .collection<wallet_store.WalletCursor>()
          .where()
          .accountIdEqualTo(normalizedAccountId)
          .deleteAll();
    });
  }

  /// 清空所有 CitizenApp 业务交易记录。
  static Future<void> clearAllWalletLocalHistory() async {
    await WalletIsar.instance.writeTxn((isar) async {
      await isar.collection<wallet_store.Entry>().clear();
      await isar.collection<wallet_store.WalletCursor>().clear();
    });
  }

  /// 查询某个钱包的交易总数。
  static Future<int> countByAccountId(String accountId) async {
    final normalizedAccountId = requireAccountId(accountId);
    return WalletIsar.instance.read((isar) async {
      return isar
          .collection<wallet_store.Entry>()
          .where()
          .accountIdEqualTo(normalizedAccountId)
          .count();
    });
  }
}

/// 交易流水 watcher 的可等待生命周期句柄。
///
/// 取得 WalletIsar lease、启动 watcher、取消 subscription 和释放 lease 被收敛为一个
/// 状态机。取消请求先同步落位，再等待尚未完成的启动；因此即使关闭发生在 `db()` 等待
/// 期间，启动路径也不会在关闭请求之后重新挂上 watcher。
class LocalTxAccountChangeSubscription {
  LocalTxAccountChangeSubscription._();

  WalletIsarConsumerLease? _lease;
  StreamSubscription<void>? _subscription;
  Future<void>? _startup;
  final Completer<void> _startupAssigned = Completer<void>();
  Future<_LocalTxCancellationOutcome>? _cancelInFlight;
  bool _cancelRequested = false;

  @visibleForTesting
  static Future<void> Function(StreamSubscription<void> subscription)?
  debugCancelSubscription;

  static LocalTxAccountChangeSubscription _listen({
    required String accountId,
    required void Function() onChanged,
    required void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final listener = LocalTxAccountChangeSubscription._();
    final callbackZone = Zone.current;

    // 必须先同步登记 lease；登记失败时尚未开始任何 db() 或 watcher 工作。
    listener._lease = WalletIsar.instance.registerExternalConsumer(
      listener.cancel,
    );
    if (listener._cancelRequested) {
      listener._startup = Future<void>.value();
    } else {
      // 原生 watcher 的启动与取消属于资源生命周期，不能被 UI 的 fake-async/页面
      // Zone 暂停；事件回调再显式送回调用方 Zone，保持 Flutter 状态更新边界不变。
      listener._startup = Zone.root.run(
        () => listener._start(
          accountId: accountId,
          onChanged: onChanged,
          onError: onError,
          callbackZone: callbackZone,
        ),
      );
    }
    listener._startupAssigned.complete();
    return listener;
  }

  void _reportError(
    Object error,
    StackTrace stackTrace,
    void Function(Object error, StackTrace stackTrace)? onError,
    Zone callbackZone,
  ) {
    final callback = onError;
    if (callback == null) {
      callbackZone.handleUncaughtError(error, stackTrace);
      return;
    }
    callbackZone.runGuarded(() => callback(error, stackTrace));
  }

  Future<void> _cancelSubscriptionAfterStartupFailure() async {
    final subscription = _subscription;
    if (subscription == null) {
      _releaseLease();
      return;
    }
    await _cancelNativeSubscription(subscription);
    _subscription = null;
    _releaseLease();
  }

  Future<void> _start({
    required String accountId,
    required void Function() onChanged,
    required void Function(Object error, StackTrace stackTrace)? onError,
    required Zone callbackZone,
  }) async {
    try {
      final isar = await WalletIsar.instance.db();
      if (_cancelRequested) return;

      final subscription = isar
          .collection<wallet_store.Entry>()
          .where()
          .accountIdEqualTo(accountId)
          .watchLazy()
          .listen((_) => callbackZone.runGuarded(onChanged));
      _subscription = subscription;

      // 覆盖 lease 已取得、subscription 尚未赋值时收到关闭请求的竞态。
      if (_cancelRequested) {
        await _cancelNativeSubscription(subscription);
        _subscription = null;
      }
    } catch (error, stackTrace) {
      try {
        // 清理失败时故意保留 subscription 与 lease，让 WalletIsar 擦除可见失败并可重试。
        await _cancelSubscriptionAfterStartupFailure();
      } catch (cleanupError, cleanupStackTrace) {
        _reportError(cleanupError, cleanupStackTrace, onError, callbackZone);
      }

      if (!_cancelRequested) {
        _reportError(error, stackTrace, onError, callbackZone);
      }
    }
  }

  /// 幂等且 single-flight：仅在启动任务和原生 subscription 均真实结束后释放 lease。
  Future<void> cancel() {
    _cancelRequested = true;
    var task = _cancelInFlight;
    if (task == null) {
      late final Future<_LocalTxCancellationOutcome> created;
      created = Zone.root.run(() async {
        try {
          await _cancel();
          return const _LocalTxCancellationOutcome.success();
        } on Object catch (error, stackTrace) {
          return _LocalTxCancellationOutcome.failure(error, stackTrace);
        }
      });
      _cancelInFlight = created;
      task = created;
      // created 永不以 error 完成，因此 root Zone 没有可泄漏的未观察异常。
      unawaited(
        created.then<void>((_) {
          if (identical(_cancelInFlight, created)) _cancelInFlight = null;
        }),
      );
    }
    // 每个调用者在自己的 Zone 解包同一 outcome，保留原始堆栈并让失败可见。
    return task.then<void>((outcome) {
      final error = outcome.error;
      if (error != null) {
        Error.throwWithStackTrace(error, outcome.stackTrace!);
      }
    });
  }

  Future<void> _cancel() async {
    await _startupAssigned.future;
    await _startup;
    final subscription = _subscription;
    if (subscription != null) {
      await _cancelNativeSubscription(subscription);
      _subscription = null;
    }
    _releaseLease();
  }

  static Future<void> _cancelNativeSubscription(
    StreamSubscription<void> subscription,
  ) {
    final testCancel = debugCancelSubscription;
    return testCancel?.call(subscription) ?? subscription.cancel();
  }

  void _releaseLease() {
    final lease = _lease;
    if (lease == null) return;
    lease.release();
    _lease = null;
  }
}

class _LocalTxCancellationOutcome {
  const _LocalTxCancellationOutcome.success() : error = null, stackTrace = null;

  const _LocalTxCancellationOutcome.failure(this.error, this.stackTrace);

  final Object? error;
  final StackTrace? stackTrace;
}
