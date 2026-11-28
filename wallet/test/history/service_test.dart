// 验证历史读取与自动刷新。

import 'dart:async';
import 'package:citizen_storage/user.dart' as store show WalletCursor;
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_wallet/history/store.dart' show LocalTxAccountChangeSubscription, LocalTxStore;
import 'package:citizen_wallet/history/service.dart' show WalletTransactionHistoryService;
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_testing/database.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_wallet/history/service.dart' show TxAutoRefreshMixin;

void main() {
  group('wallet_transaction_history_service_test', suite32);
  group('tx_auto_refresh_test', suite33);
}

// 验证奖励和费用投影、断点补扫及真实执行状态交付。

const _accountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

CitizenPreparedTransaction _submissionPrepared() => CitizenPreparedTransaction(
  preparationId: 'submission-proof',
  sourceAccountId: citizenAccountIdBytes(_accountId),
  callDataHash: Uint8List.fromList(List.filled(32, 0x22)),
  bestBlock: CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.best,
  ),
  runtimeSpecNumber: 1,
  transactionFormatNumber: 4,
  nonce: BigInt.zero,
);

CitizenTransactionHistoryRecord _submissionRecord(
  CitizenTransactionHistoryStatus status, {
  String executionId = 'submission-proof',
  String account = _accountId,
  String? callHash,
}) {
  final finalized =
      status == CitizenTransactionHistoryStatus.finalizedSuccess ||
      status == CitizenTransactionHistoryStatus.finalizedFailed;
  final block = CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: finalized
        ? CitizenBlockFinality.finalized
        : CitizenBlockFinality.best,
  );
  return CitizenTransactionHistoryRecord(
    executionId: executionId,
    sourceAccountId: account,
    callDataHash: callHash ?? '0x${'22' * 32}',
    transactionHash: '0x${'33' * 32}',
    status: status,
    block: block,
    execution: finalized
        ? CitizenExecution(
            status: status == CitizenTransactionHistoryStatus.finalizedSuccess
                ? CitizenExecutionStatus.success
                : CitizenExecutionStatus.failed,
            block: block,
            extrinsicIndex: 0,
            dispatchVariant: null,
            palletIndex: null,
            errorIndex: null,
          )
        : null,
    replacementHash: null,
    createdAtMillis: BigInt.one,
    updatedAtMillis: BigInt.two,
    poolRejectionReason: status == CitizenTransactionHistoryStatus.poolRejected
        ? 'invalid'
        : null,
  );
}

WalletTransactionHistoryService _submissionHistory({
  required Stream<CitizenTransactionHistoryRecord> Function(
    CitizenPreparedTransaction,
  )
  watch,
  required Future<CitizenTransactionHistoryRecord?> Function(
    CitizenPreparedTransaction,
  )
  read,
}) => WalletTransactionHistoryService(
  events: const Stream.empty(),
  watchPreparedTransaction: watch,
  getPreparedTransactionRecord: read,
  syncTransactionHistory: () async => CitizenTransactionHistoryPage(
    revision: BigInt.zero,
    records: const [],
    nextBeforeExecutionId: null,
  ),
  getWalletState: () => testCitizenOperation(
    () async => CitizenWalletState(
      initializationState: CitizenWalletInitializationState.empty,
      cleanupPending: false,
      revision: BigInt.zero,
      hotProfile: null,
      accounts: const [],
    ),
  ),
);

void suite32() {
  useIsolatedIsar();

  CitizenSystemEvent reward(
    int block, {
    String? recipient,
    String amount = '999900',
    int index = 9,
  }) => CitizenSystemEvent(
    eventIndex: index,
    extrinsicIndex: null,
    pallet: 'FullnodeIssue',
    name: 'FullnodeIssuanceIssued',
    fields: {
      'block': '$block',
      'reward_account_id': List<String>.filled(32, recipient ?? '170'),
      'miner_account_id': List<String>.filled(32, '187'),
      'amount': amount,
    },
  );

  test('奖励以接收账户保存，保留导入时间边界且无普通交易哈希', () async {
    final chain = _HistoryChain();
    chain.encodedEvents[3] = [reward(3)];
    chain.encodedEvents[4] = [reward(4)];
    chain.encodedEvents[5] = [reward(5, recipient: '187')];
    chain.encodedEvents[6] = [reward(6, amount: '9007199254740993')];
    final service = _service(chain, _HistoryWallet(createdAt: 4000));
    await service.start();
    await service.sync();
    await service.stop();
    final rows = await LocalTxStore.queryByAccountId(_accountId);
    expect(rows.length, 2);
    expect(rows.map((r) => r.blockNumber), [6, 4]);
    expect(
      rows.every(
        (r) =>
            r.entryKind == 'reward' &&
            r.txHash == null &&
            r.extrinsicIndex == null &&
            r.feeAmount == null,
      ),
      isTrue,
    );
    expect(rows.first.amountDelta, '9007199254740993');
  });

  test('旧游标补扫失败后断点重启且奖励转账手续费均不重复', () async {
    final chain = _HistoryChain()..height = 40;
    chain.encodedEvents[4] = [
      ..._eventFacts(feeAmount: BigInt.from(2)),
      reward(4),
    ];
    chain.encodedEvents[5] = _eventFacts(
      failed: true,
      feeAmount: BigInt.from(2),
    );
    chain.encodedEvents[6] = [reward(6)];
    final wallet = _HistoryWallet(createdAt: 4000);
    final original = _service(chain, wallet);
    await original.start();
    await original.sync();
    await original.sync();
    await original.stop();
    final before = await LocalTxStore.queryByAccountId(_accountId);
    final old = (await LocalTxStore.historyCursor(_accountId))!;
    old.eventVersion = 0;
    await UserIsar.instance.writeTxn(
      (isar) async => isar.collection<store.WalletCursor>().put(old),
    );
    chain.eventBlocks.clear();
    chain.failEventsAt = 6;
    final failed = _service(chain, wallet);
    await failed.start();
    await expectLater(failed.sync(), throwsStateError);
    await failed.stop();
    final partial = (await LocalTxStore.historyCursor(_accountId))!;
    expect(partial.eventVersion, 1);
    expect(partial.cursorBlock, 5);
    chain.eventBlocks.clear();
    chain.failEventsAt = null;
    final resumed = _service(chain, wallet);
    await resumed.start();
    await resumed.sync();
    await resumed.sync();
    await resumed.stop();
    expect(chain.eventBlocks.first, 6);
    final after = await LocalTxStore.queryByAccountId(_accountId);
    expect(
      after.map((r) => r.rowId).toSet(),
      before.map((r) => r.rowId).toSet(),
    );
    expect(after.length, 4);
    expect(after.where((r) => r.entryKind == 'reward').length, 2);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 40);
  });

  test('错误奖励金额高度或阶段拒绝且不推进该块', () async {
    for (final bad in [
      reward(999),
      reward(4, amount: '0'),
      CitizenSystemEvent(
        eventIndex: 9,
        extrinsicIndex: 0,
        pallet: 'FullnodeIssue',
        name: 'FullnodeIssuanceIssued',
        fields: reward(4).fields,
      ),
    ]) {
      await LocalTxStore.clearAllWalletLocalHistory();
      final chain = _HistoryChain();
      chain.encodedEvents[4] = [bad];
      final service = _service(chain, _HistoryWallet(createdAt: 4000));
      await service.start();
      await expectLater(service.sync(), throwsFormatException);
      await service.stop();
      expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 3);
      expect(await LocalTxStore.countByAccountId(_accountId), 0);
    }
  });

  test('执行网络异常但既有回读确认成功，通知页面且不增加查询或重试', () async {
    final core = await openTestSdk();
    var reads = 0, watches = 0, executions = 0;
    final service = _submissionHistory(
      watch: (p) {
        watches++;
        expect(p.preparationId, 'submission-proof');
        return const Stream.empty();
      },
      read: (p) async {
        reads++;
        return _submissionRecord(
          CitizenTransactionHistoryStatus.finalizedSuccess,
        );
      },
    );
    await service.start();
    await service.sync();
    final reported = <CitizenTransactionHistoryRecord>[];
    const failure = CitizenSdkException(
      code: CitizenSdkErrorCode.network,
      message: 'observation failed',
    );
    await expectLater(
      service.trackTransfer<void>(
        sdk: core.sdk,
        prepared: _submissionPrepared(),
        amountFen: BigInt.from(100),
        fromAddress: 'payer',
        toAddress: 'recipient',
        remark: '',
        onRecord: reported.add,
        execute: () async {
          executions++;
          throw failure;
        },
      ),
      throwsA(same(failure)),
    );
    expect(
      reported.single.status,
      CitizenTransactionHistoryStatus.finalizedSuccess,
    );
    expect((reads, watches, executions), (1, 1, 1));
    expect(
      (await LocalTxStore.queryByAccountId(_accountId)).single.entryState,
      LocalTxStore.statusFinalized,
    );
    await service.stop();
  });

  for (final mismatch in ['execution', 'account', 'call']) {
    test('不能把另一笔交易的成功记录交付页面：$mismatch', () async {
      final core = await openTestSdk();
      final wrong = _submissionRecord(
        CitizenTransactionHistoryStatus.finalizedSuccess,
        executionId: mismatch == 'execution'
            ? 'another-execution'
            : 'submission-proof',
        account: mismatch == 'account' ? '0x${'bb' * 32}' : _accountId,
        callHash: mismatch == 'call' ? '0x${'44' * 32}' : null,
      );
      final service = _submissionHistory(
        watch: (_) => Stream.value(wrong),
        read: (_) async => wrong,
      );
      await service.start();
      await service.sync();
      final reported = <CitizenTransactionHistoryRecord>[];
      await service.trackTransfer<String>(
        sdk: core.sdk,
        prepared: _submissionPrepared(),
        amountFen: BigInt.from(100),
        fromAddress: 'payer',
        toAddress: 'recipient',
        remark: '',
        onRecord: reported.add,
        execute: () async => 'completed',
      );
      expect(reported, isEmpty);
      expect(await LocalTxStore.queryByAccountId(_accountId), isEmpty);
      await service.stop();
    });
  }

  test('订阅已成功后迟到的待确认回读不降级页面或本地记录', () async {
    final core = await openTestSdk();
    final observed = Completer<void>();
    final reported = <CitizenTransactionHistoryRecord>[];
    final service = _submissionHistory(
      watch: (_) => Stream.value(
        _submissionRecord(CitizenTransactionHistoryStatus.finalizedSuccess),
      ),
      read: (_) async =>
          _submissionRecord(CitizenTransactionHistoryStatus.pending),
    );
    await service.start();
    await service.sync();
    final result = await service.trackTransfer<String>(
      sdk: core.sdk,
      prepared: _submissionPrepared(),
      amountFen: BigInt.from(100),
      fromAddress: 'payer',
      toAddress: 'recipient',
      remark: '',
      onRecord: (r) {
        reported.add(r);
        if (!observed.isCompleted) observed.complete();
      },
      execute: () async {
        await observed.future;
        return 'ok';
      },
    );
    expect(result, 'ok');
    expect(reported.map((r) => r.status), [
      CitizenTransactionHistoryStatus.finalizedSuccess,
    ]);
    expect(
      (await LocalTxStore.queryByAccountId(_accountId)).single.entryState,
      LocalTxStore.statusFinalized,
    );
    await service.stop();
  });

  test('记录观察者异常不覆盖原交易结果，回读仍只执行一次', () async {
    final core = await openTestSdk();
    var reads = 0;
    final service = _submissionHistory(
      watch: (_) => const Stream.empty(),
      read: (_) async {
        reads++;
        return _submissionRecord(
          CitizenTransactionHistoryStatus.finalizedSuccess,
        );
      },
    );
    await service.start();
    await service.sync();
    final result = await service.trackTransfer<String>(
      sdk: core.sdk,
      prepared: _submissionPrepared(),
      amountFen: BigInt.from(100),
      fromAddress: 'payer',
      toAddress: 'recipient',
      remark: '',
      onRecord: (_) => throw StateError('observer failed'),
      execute: () async => 'ok',
    );
    expect(result, 'ok');
    expect(reads, 1);
    await service.stop();
  });

  test('结束回读异常不覆盖已知的执行结果或签名取消', () async {
    final core = await openTestSdk();
    var reads = 0;
    final service = _submissionHistory(
      watch: (_) => const Stream.empty(),
      read: (_) async {
        reads++;
        throw StateError('history unavailable');
      },
    );
    await service.start();
    await service.sync();
    expect(
      await service.trackTransfer<String?>(
        sdk: core.sdk,
        prepared: _submissionPrepared(),
        amountFen: BigInt.from(100),
        fromAddress: 'payer',
        toAddress: 'recipient',
        remark: '',
        execute: () async => null,
      ),
      isNull,
    );
    expect(reads, 1);
    await service.stop();
  });

  test('真实费用按付款账户附一次，多笔本金与接收方分别投影', () async {
    final chain = _HistoryChain()..height = 1;
    chain.encodedEvents[1] = _eventFacts(
      twice: true,
      feeAmount: BigInt.from(10),
    );
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await service.sync();
    final records = await LocalTxStore.queryByAccountId(_accountId);
    expect(records, hasLength(2));
    expect(records.map((r) => r.amountDelta).toSet(), {'-110', '-100'});
    expect(records.where((r) => r.feeAmount != null).single.feeAmount, '10');
    await service.sync();
    expect(await LocalTxStore.countByAccountId(_accountId), 2);
    await service.stop();
  });

  test('失败执行保留每条真实收费，额外费用按事件身份入账', () async {
    final chain = _HistoryChain()..height = 1;
    chain.encodedEvents[1] = _eventFacts(
      failed: true,
      feeAmount: BigInt.from(10),
      duplicateFee: true,
    );
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await service.sync();
    final rows = await LocalTxStore.queryByAccountId(_accountId);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.entryKind), everyElement('fee'));
    expect(rows.map((row) => row.amountDelta), everyElement('-10'));
    expect(rows.map((row) => row.failReason), everyElement('链上执行失败'));
    expect(rows.map((row) => row.eventIndex).toSet(), {2, 3});
    await service.sync();
    expect(await LocalTxStore.countByAccountId(_accountId), 2);
    await service.stop();
  });

  test('零费用使进度停在原块，修正后重试', () async {
    final chain = _HistoryChain()..height = 1;
    chain.encodedEvents[1] = _eventFacts(feeAmount: BigInt.zero);
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await expectLater(service.sync(), throwsFormatException);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 0);
    expect(await LocalTxStore.countByAccountId(_accountId), 0);
    chain.encodedEvents[1] = _eventFacts(feeAmount: BigInt.from(10));
    await service.sync();
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 1);
    expect(
      (await LocalTxStore.queryByAccountId(_accountId)).single.feeAmount,
      '10',
    );
    await service.stop();
  });

  test('完整遍历 SDK history 分页并只投影 SDK execution 终态', () async {
    await _insert(txHash: '0x01', executionId: 'execution-newer');
    await _insert(txHash: '0x02', executionId: 'execution-older');
    final events = StreamController<CitizenSdkEvent>();
    final service = (() {
      final reads0 = _PagedHistory();
      final reads1 = TestChainReads();
      final reads2 = _HistoryWallet();
      return WalletTransactionHistoryService(
        syncTransactionHistory: reads0.syncTransactionHistory,
        getTransactionHistory: reads0.getTransactionHistory,
        getGenesisHash: reads1.getGenesisHash,
        getFinalizedHead: reads1.getFinalizedHead,
        getFinalizedBlockAt: reads1.getFinalizedBlockAt,
        getStorage: reads1.getStorage,
        getSystemEvents: reads1.getSystemEvents,
        getRuntimeContext: reads1.getRuntimeContext,
        getBlockBody: reads1.getBlockBody,
        getWalletState: reads2.getWalletState,
        events: events.stream,
      );
    })();

    await service.start();
    await service.sync();

    final records = await LocalTxStore.queryByAccountId(_accountId);
    final byHash = {for (final record in records) record.txHash: record};
    expect(byHash['0x01']?.entryState, LocalTxStore.statusInBlock);
    expect(byHash['0x01']?.blockHash, '0x${'11' * 32}');
    expect(byHash['0x02']?.entryState, LocalTxStore.statusFinalized);
    expect(byHash['0x02']?.blockNumber, 8);
    expect(byHash['0x02']?.extrinsicIndex, 3);

    await service.stop();
    await events.close();
  });
  test('按账户导入时间定位起点，只投影边界之后的区块且重启复用进度', () async {
    final chain = _HistoryChain();
    final wallet = _HistoryWallet(createdAt: 3500);
    final service = _service(chain, wallet);
    await service.start();
    await service.sync();
    expect(chain.eventBlocks, [4, 5, 6, 7, 8, 9, 10]);
    final cursor = (await LocalTxStore.historyCursor(_accountId))!;
    expect(cursor.startBlock, 4);
    expect(cursor.cursorBlock, 10);
    await service.stop();

    chain.eventBlocks.clear();
    chain.storageBlocks.clear();
    chain.height = 11;
    final restarted = _service(chain, wallet);
    await restarted.start();
    await restarted.sync();
    expect(chain.eventBlocks, [11]);
    expect(chain.storageBlocks, [11]);
    await restarted.stop();
  });

  test('同一轮有界处理32块，下一轮接续且不会跳过中间区块', () async {
    final chain = _HistoryChain()..height = 40;
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await service.sync();
    expect(chain.eventBlocks, List.generate(32, (i) => i + 1));
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 32);
    await service.sync();
    expect(chain.eventBlocks, List.generate(40, (i) => i + 1));
    await service.stop();
  });

  test('某块读取失败保留前一块进度，恢复后从失败块继续', () async {
    final chain = _HistoryChain()..failEventsAt = 6;
    final service = _service(chain, _HistoryWallet(createdAt: 4000));
    await service.start();
    await expectLater(service.sync(), throwsStateError);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 5);
    chain.failEventsAt = null;
    chain.eventBlocks.clear();
    await service.sync();
    expect(chain.eventBlocks, [6, 7, 8, 9, 10]);
    await service.stop();
  });

  test('SDK 拒绝区间时游标不推进，读取恢复后重试', () async {
    final chain = _HistoryChain()..failRange = true;
    final service = _service(chain, _HistoryWallet(createdAt: 4000));
    await service.start();
    await expectLater(service.sync(), throwsStateError);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 3);
    expect(chain.eventBlocks, isEmpty);
    chain.failRange = false;
    await service.sync();
    expect(chain.eventBlocks, [4, 5, 6, 7, 8, 9, 10]);
    await service.stop();
  });

  test('无法定位时间边界时不建立进度，也不以当前高度跳过', () async {
    final chain = _HistoryChain()..missingTimestamp = true;
    final service = _service(chain, _HistoryWallet(createdAt: 4000));
    await service.start();
    await expectLater(service.sync(), throwsFormatException);
    expect(await LocalTxStore.historyCursor(_accountId), isNull);
    expect(chain.eventBlocks, isEmpty);
    await service.stop();
  });

  test('导入时间晚于当前链时间时等待后续块，保留准确时间边界', () async {
    final chain = _HistoryChain();
    final service = _service(chain, _HistoryWallet(createdAt: 11500));
    await service.start();
    await service.sync();
    expect(chain.eventBlocks, isEmpty);
    expect((await LocalTxStore.historyCursor(_accountId))!.startBlock, 11);
    chain.height = 12;
    await service.sync();
    expect(chain.eventBlocks, [12]);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 12);
    await service.stop();
  });

  test('并发刷新共用读取任务；停止后迟到事件不写库', () async {
    final chain = _HistoryChain()
      ..height = 1
      ..eventBarrier = Completer<List<CitizenSystemEvent>>();
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    final first = service.sync();
    final second = service.sync();
    expect(identical(first, second), isTrue);
    await chain.eventEntered.future;
    final stopping = service.stop();
    chain.eventBarrier!.complete(const []);
    await stopping;
    expect(chain.eventBlocks, [1]);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 0);
  });

  test('退后台使在途块失效，返回前台后继续同一进度', () async {
    final chain = _HistoryChain()
      ..height = 1
      ..eventBarrier = Completer<List<CitizenSystemEvent>>();
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    final waiting = service.sync();
    await chain.eventEntered.future;
    service.setForeground(false);
    chain.eventBarrier!.complete(const []);
    await waiting;
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 0);
    chain.eventBarrier = null;
    service.setForeground(true);
    await service.sync();
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 1);
    await service.stop();
  });

  test('已验证收款写入账户历史；重放不重复，错误执行不入账', () async {
    final chain = _HistoryChain()..height = 2;
    chain.encodedEvents[1] = _eventFacts(incoming: true);
    chain.encodedEvents[2] = _eventFacts(incoming: true, failed: true);
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await service.sync();
    final rows = await LocalTxStore.queryByAccountId(_accountId);
    expect(rows, hasLength(1));
    expect(rows.single.amountDelta, '100');
    expect(rows.single.entrySource, 'sdk_finalized_event');
    expect(rows.single.txNote, '合成备注');
    expect(rows.single.blockNumber, 1);
    await service.sync();
    expect(await LocalTxStore.countByAccountId(_accountId), 1);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 2);
    await service.stop();
  });

  test('缺少 System 执行结果及正文锚点不符均不写记录或推进', () async {
    final chain = _HistoryChain()..height = 1;
    chain.encodedEvents[1] = _eventFacts(incoming: true, omitOutcome: true);
    final service = _service(chain, _HistoryWallet(createdAt: 1000));
    await service.start();
    await expectLater(service.sync(), throwsFormatException);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 0);
    chain.encodedEvents[1] = _eventFacts(incoming: true);
    chain.wrongBodyAnchor = true;
    await expectLater(service.sync(), throwsStateError);
    expect(await LocalTxStore.countByAccountId(_accountId), 0);
    expect((await LocalTxStore.historyCursor(_accountId))!.cursorBlock, 0);
    chain.wrongBodyAnchor = false;
    await service.sync();
    expect(await LocalTxStore.countByAccountId(_accountId), 1);
    await service.stop();
  });
}

Future<void> _insert({required String txHash, required String executionId}) {
  return LocalTxStore.applyExecution(
    CitizenTransactionHistoryRecord(
      executionId: executionId,
      sourceAccountId: _accountId,
      callDataHash: '0x${'22' * 32}',
      transactionHash: txHash,
      status: CitizenTransactionHistoryStatus.pending,
      block: null,
      execution: null,
      replacementHash: null,
      createdAtMillis: BigInt.one,
      updatedAtMillis: BigInt.one,
      poolRejectionReason: null,
    ),
    amountFen: BigInt.from(100),
    fromAddress: 'sender',
    toAddress: 'recipient',
  );
}

final class _PagedHistory extends TestHistoryReads {
  @override
  Future<CitizenTransactionHistoryPage> syncTransactionHistory() async {
    return CitizenTransactionHistoryPage(
      revision: BigInt.one,
      records: [_record('execution-newer', '0x01', inBlock: true)],
      nextBeforeExecutionId: 'execution-newer',
    );
  }

  @override
  Future<CitizenTransactionHistoryPage> getTransactionHistory({
    String? beforeExecutionId,
    int limit = 100,
  }) async {
    expect(beforeExecutionId, 'execution-newer');
    expect(limit, 100);
    return CitizenTransactionHistoryPage(
      revision: BigInt.one,
      records: [_record('execution-older', '0x02', inBlock: false)],
      nextBeforeExecutionId: null,
    );
  }

  CitizenTransactionHistoryRecord _record(
    String executionId,
    String txHash, {
    required bool inBlock,
  }) {
    final block = CitizenBlockRef(
      hash: inBlock ? '0x${'11' * 32}' : '0x${'33' * 32}',
      number: BigInt.from(inBlock ? 7 : 8),
      finality: inBlock
          ? CitizenBlockFinality.best
          : CitizenBlockFinality.finalized,
    );
    return CitizenTransactionHistoryRecord(
      executionId: executionId,
      sourceAccountId: _accountId,
      callDataHash: '0x${'22' * 32}',
      transactionHash: txHash,
      status: inBlock
          ? CitizenTransactionHistoryStatus.inBlock
          : CitizenTransactionHistoryStatus.finalizedSuccess,
      block: block,
      execution: inBlock
          ? null
          : CitizenExecution(
              status: CitizenExecutionStatus.success,
              block: block,
              extrinsicIndex: 3,
              dispatchVariant: null,
              palletIndex: null,
              errorIndex: null,
            ),
      replacementHash: null,
      createdAtMillis: BigInt.one,
      updatedAtMillis: BigInt.from(2),
      poolRejectionReason: null,
    );
  }
}

WalletTransactionHistoryService _service(
  _HistoryChain chain,
  _HistoryWallet wallet,
) => (() {
  final reads0 = _EmptyHistory();
  return WalletTransactionHistoryService(
    syncTransactionHistory: reads0.syncTransactionHistory,
    getTransactionHistory: reads0.getTransactionHistory,
    getGenesisHash: chain.getGenesisHash,
    getFinalizedHead: chain.getFinalizedHead,
    getFinalizedBlockAt: chain.getFinalizedBlockAt,
    getFinalizedBlockRange: chain.getFinalizedBlockRange,
    getStorage: chain.getStorage,
    getFinalizedEvents: chain.getFinalizedEvents,
    getBlockBody: chain.getBlockBody,
    getWalletState: wallet.getWalletState,
    events: const Stream<CitizenSdkEvent>.empty(),
  );
})();

final class _EmptyHistory extends TestHistoryReads {
  @override
  Future<CitizenTransactionHistoryPage> syncTransactionHistory() async =>
      CitizenTransactionHistoryPage(
        revision: BigInt.zero,
        records: [],
        nextBeforeExecutionId: null,
      );
}

final class _HistoryWallet extends TestWalletReads {
  _HistoryWallet({this.createdAt});
  final int? createdAt;
  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () => CitizenWalletState(
          revision: BigInt.one,
          hotProfile: null,
          cleanupPending: false,
          initializationState: createdAt == null
              ? CitizenWalletInitializationState.empty
              : CitizenWalletInitializationState.ready,
          accounts: [
            if (createdAt != null)
              CitizenWalletStateAccount(
                signMode: CitizenWalletSignMode.cold,
                walletIndex: 0,
                accountIndex: null,
                accountId: _accountId,
                ss58Address: 'synthetic-wallet',
                name: '测试钱包',
                createdAtMillis: BigInt.from(createdAt!),
                isDefault: true,
              ),
          ],
        ),
      );
}

final class _HistoryChain extends TestChainReads {
  int height = 10;
  bool failRange = false;
  final encodedEvents = <int, List<CitizenSystemEvent>>{};
  bool wrongBodyAnchor = false;
  int? failEventsAt;
  bool missingTimestamp = false;
  final eventBlocks = <int>[];
  final storageBlocks = <int>[];
  final eventEntered = Completer<void>();
  Completer<List<CitizenSystemEvent>>? eventBarrier;
  CitizenBlockRef block(int height) => CitizenBlockRef(
    hash: '0x${height.toRadixString(16).padLeft(64, '0')}',
    number: BigInt.from(height),
    finality: CitizenBlockFinality.finalized,
  );
  @override
  Future<String> getGenesisHash() async => '0x${'00' * 32}';
  @override
  Future<CitizenBlockRef> getFinalizedHead() async => block(height);
  @override
  Future<CitizenBlockRef> getFinalizedBlockAt(BigInt number) async {
    if (number <= BigInt.zero || number > BigInt.from(height)) {
      throw StateError('高度越界');
    }
    return block(number.toInt());
  }

  Future<List<CitizenBlockRef>> getFinalizedBlockRange(
    BigInt start,
    BigInt end,
  ) async {
    if (failRange) throw StateError('SDK 拒绝不完整的 finalized 区间');
    return [
      for (var i = start; i <= end; i += BigInt.one)
        await getFinalizedBlockAt(i),
    ];
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    storageBlocks.add(block.number.toInt());
    if (missingTimestamp) return null;
    return (ByteData(8)
          ..setUint64(0, block.number.toInt() * 1000, Endian.little))
        .buffer
        .asUint8List();
  }

  Future<List<CitizenSystemEvent>> getFinalizedEvents(
    CitizenBlockRef block,
  ) async {
    final number = block.number.toInt();
    eventBlocks.add(number);
    if (!eventEntered.isCompleted) eventEntered.complete();
    if (number == failEventsAt) throw StateError('合成区块暂时不可读');
    return eventBarrier == null
        ? encodedEvents[number] ?? const []
        : await eventBarrier!.future;
  }

  @override
  Future<CitizenBlockBody> getBlockBody(CitizenBlockRef ref) async =>
      CitizenBlockBody(
        block: wrongBodyAnchor ? block(999) : ref,
        extrinsics: [
          Uint8List.fromList([4, 0]),
        ],
      );
}

/// 以 SDK 公开事件字段构造确定性输入，原生编解码金标归 SDK。
List<CitizenSystemEvent> _eventFacts({
  bool incoming = false,
  bool failed = false,
  bool twice = false,
  bool omitOutcome = false,
  bool duplicateFee = false,
  BigInt? feeAmount,
}) {
  final from = List<String>.filled(32, incoming ? '187' : '170');
  final to = List<String>.filled(32, incoming ? '170' : '187');
  final events = <CitizenSystemEvent>[];
  void add(String pallet, String name, Object? fields) {
    events.add(
      CitizenSystemEvent(
        eventIndex: events.length,
        extrinsicIndex: 0,
        pallet: pallet,
        name: name,
        fields: fields,
      ),
    );
  }

  for (final note in ['合成备注', if (twice) '第二笔']) {
    add('Balances', 'Transfer', {'from': from, 'to': to, 'amount': '100'});
    add('Onchain', 'TransferWithRemark', {
      'from_account_id': from,
      'beneficiary_account_id': to,
      'amount': '100',
      'remark': utf8.encode(note).map((byte) => byte.toString()).toList(),
    });
  }
  if (feeAmount != null) {
    for (var i = 0; i < (duplicateFee ? 2 : 1); i++) {
      add('Onchain', 'FeePaid', {
        'account_id': from,
        'fee': feeAmount.toString(),
      });
    }
  }
  if (!omitOutcome) {
    add('System', failed ? 'ExtrinsicFailed' : 'ExtrinsicSuccess', null);
  }
  return events;
}

// 验证流水监听去抖、账户切换及数据库擦除时真实取消。

// 原生 watcher 通知通过真实事件循环推进，页面去抖通过 widget 时钟推进；
// 分别推进这两个阶段，验证账户切换、取消和迟到回执，不用单次固定延迟猜测通知。
void suite33() {
  useIsolatedIsar();

  tearDown(() {
    LocalTxAccountChangeSubscription.debugCancelSubscription = null;
  });

  const fromAccountId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const fromAddress = 'from-wallet';
  const toAddress = 'to-wallet';

  const otherAccountId =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  Future<void> settleLocal(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  Future<void> write(String account) => LocalTxStore.upsert(
    Entry()
      ..accountId = account
      ..entryKind = 'transfer'
      ..amountDelta = '100'
      ..transferAmount = '100'
      ..entryState = LocalTxStore.statusFinalized
      ..entrySource = 'chain_event'
      ..blockHash = '0x1111'
      ..blockNumber = 1
      ..eventIndex = 0
      ..createdAt = 1,
  );

  testWidgets('旧账户已排队的去抖回调不能重读新账户，新账户监听仍有效', (tester) async {
    final key = GlobalKey<_TxWatcherHostState>();
    await tester.pumpWidget(_TxWatcherHost(key: key, accountId: fromAccountId));
    await settleLocal(tester);
    await tester.runAsync(() => write(fromAccountId));
    await settleLocal(tester);
    expect(key.currentState!.reloads, isEmpty);
    await tester.pumpWidget(
      _TxWatcherHost(key: key, accountId: otherAccountId),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(key.currentState!.reloads, isEmpty);
    await settleLocal(tester);
    await tester.runAsync(() => write(otherAccountId));
    await settleLocal(tester);
    await tester.pump(const Duration(milliseconds: 250));
    expect(key.currentState!.reloads, [otherAccountId]);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('重复主动刷新共用一次完成任务及本机重读', (tester) async {
    final service = WalletTransactionHistoryService(
      events: const Stream<CitizenSdkEvent>.empty(),
    );
    final key = GlobalKey<_TxWatcherHostState>();
    await tester.pumpWidget(
      Provider.value(
        value: service,
        child: _TxWatcherHost(key: key, accountId: fromAccountId),
      ),
    );
    final first = key.currentState!.refreshTxHistory(),
        second = key.currentState!.refreshTxHistory();
    expect(identical(first, second), isTrue);
    await tester.pump();
    await first;
    expect(key.currentState!.reloads, [fromAccountId]);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('主动同步在途切账户，旧刷新完成不重复重读新账户', (tester) async {
    final held = Completer<CitizenTransactionHistoryPage>();
    final service = WalletTransactionHistoryService(
      events: const Stream<CitizenSdkEvent>.empty(),
      syncTransactionHistory: () => held.future,
      getWalletState: () => testCitizenOperation(
        () => CitizenWalletState(
          revision: BigInt.one,
          hotProfile: null,
          cleanupPending: false,
          initializationState: CitizenWalletInitializationState.empty,
          accounts: [],
        ),
      ),
    );
    final key = GlobalKey<_TxWatcherHostState>();
    Widget page(String account) => Provider.value(
      value: service,
      child: _TxWatcherHost(key: key, accountId: account),
    );
    await tester.pumpWidget(page(fromAccountId));
    await tester.runAsync(service.start);
    final oldRefresh = key.currentState!.refreshTxHistory();
    await tester.pumpWidget(page(otherAccountId));
    final newRefresh = key.currentState!.refreshTxHistory();
    expect(identical(oldRefresh, newRefresh), isFalse);
    held.complete(
      CitizenTransactionHistoryPage(
        revision: BigInt.zero,
        records: [],
        nextBeforeExecutionId: null,
      ),
    );
    await tester.pump();
    await settleLocal(tester);
    await Future.wait([oldRefresh, newRefresh]);
    expect(key.currentState!.reloads, [otherAccountId]);
    await tester.runAsync(service.stop);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('listenAccountChanges 在记录 pending→finalized 写库时发出事件', (
    tester,
  ) async {
    await tester.runAsync(() async {
      CitizenTransactionHistoryRecord record(CitizenTransactionHistoryStatus status) =>
          CitizenTransactionHistoryRecord(
            executionId: 'execution-refresh', sourceAccountId: fromAccountId,
            callDataHash: '0x${'11' * 32}', transactionHash: '0xfeed',
            status: status,
            block: status == CitizenTransactionHistoryStatus.pending ? null :
                CitizenBlockRef(hash: '0x22', number: BigInt.from(9),
                    finality: CitizenBlockFinality.finalized),
            execution: null, replacementHash: null, createdAtMillis: BigInt.one,
            updatedAtMillis: BigInt.from(2), poolRejectionReason: null,
          );
      await LocalTxStore.applyExecution(
        record(CitizenTransactionHistoryStatus.pending),
        amountFen: BigInt.from(100),
        fromAddress: fromAddress,
        toAddress: toAddress,
      );

      final seen = <void>[];
      final sub = LocalTxStore.listenAccountChanges(
        fromAccountId,
        () => seen.add(null),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150)); // 订阅生效

      // 模拟 SDK history 把记录投影为 finalized。
      await LocalTxStore.applyExecution(
        record(CitizenTransactionHistoryStatus.finalizedSuccess),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200)); // 通知送达

      expect(seen, isNotEmpty, reason: 'finalized 写库应触发 watch 事件驱动 UI 重刷');
      await sub.cancel();
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('UserIsar 擦除会等待已登记 watcher 真实取消', (tester) async {
    await tester.runAsync(() async {
      final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await UserIsar.instance.closeAndDeleteFromDisk();

      // close 已取得同一个 single-flight 取消任务，调用方随后重复取消仍应幂等完成。
      await sub.cancel();
      expect(() => UserIsar.instance.db(), throwsA(isA<StateError>()));
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('关闭命中 watcher 启动窗口时不会晚到挂回数据库', (tester) async {
    await tester.runAsync(() async {
      final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});

      // 不等待 db() 和原生 subscription 建立，直接同步发出关闭意图。
      await UserIsar.instance.closeAndDeleteFromDisk();
      await sub.cancel();

      expect(UserIsar.instance.db, throwsA(isA<StateError>()));
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('Widget dispose 后全局擦除会确定性等待 fake-async watcher', (tester) async {
    await tester.pumpWidget(const _TxWatcherHost(accountId: fromAccountId));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    for (
      var attempt = 0;
      attempt < 20 && UserIsar.instance.hasActiveOperation;
      attempt++
    ) {
      // 原生 Future 先在真实事件循环前进，再回 widget fake-async Zone 收尾；打开、
      // 查询是两个异步阶段，不能用一次固定延迟假定都已经完成。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(UserIsar.instance.hasActiveOperation, isFalse);
    await tester.runAsync(UserIsar.instance.closeAndDeleteFromDisk);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('外部消费者取消失败会使擦除可见失败并允许重试', (tester) async {
    await tester.runAsync(() async {
      var shouldFail = true;
      late IsarConsumerLease lease;
      lease = UserIsar.instance.registerExternalConsumer(() async {
        if (shouldFail) {
          throw StateError('模拟 watcher 取消失败');
        }
        lease.release();
      });

      await expectLater(
        UserIsar.instance.closeAndDeleteFromDisk(),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('取消 用户库外部消费者失败'),
          ),
        ),
      );
      expect(UserIsar.instance.db, throwsA(isA<StateError>()));

      shouldFail = false;
      await UserIsar.instance.closeAndDeleteFromDisk();
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('原生 watcher 取消失败由调用方观察且 root Zone 不泄漏', (tester) async {
    await tester.runAsync(() async {
      final uncaught = <Object>[];
      await runZonedGuarded(
        () async {
          final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});
          await Future<void>.delayed(const Duration(milliseconds: 100));

          var shouldFail = true;
          LocalTxAccountChangeSubscription.debugCancelSubscription =
              (subscription) async {
                if (shouldFail) throw StateError('模拟原生 watcher 取消失败');
                await subscription.cancel();
              };

          await expectLater(
            sub.cancel(),
            throwsA(
              isA<StateError>().having(
                (error) => error.toString(),
                'message',
                contains('模拟原生 watcher 取消失败'),
              ),
            ),
          );

          // 失败保留 lease/subscription；同一句柄可在原生边界恢复后重试并真实释放。
          shouldFail = false;
          await sub.cancel();
          await UserIsar.instance.closeAndDeleteFromDisk();
        },
        (error, _) {
          uncaught.add(error);
        },
      );
      expect(uncaught, isEmpty);
    });
  }, timeout: const Timeout(Duration(seconds: 40)));
}

class _TxWatcherHost extends StatefulWidget {
  const _TxWatcherHost({super.key, required this.accountId});

  final String accountId;

  @override
  State<_TxWatcherHost> createState() => _TxWatcherHostState();
}

class _TxWatcherHostState extends State<_TxWatcherHost>
    with TxAutoRefreshMixin<_TxWatcherHost> {
  @override
  void initState() {
    super.initState();
    unawaited(LocalTxStore.queryRecentByAccountId(widget.accountId));
    startTxAutoRefresh(widget.accountId);
  }

  final reloads = <String>[];

  @override
  void didUpdateWidget(covariant _TxWatcherHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    startTxAutoRefresh(widget.accountId);
  }

  @override
  Future<void> onTxRecordsChanged() async {
    reloads.add(widget.accountId);
  }

  @override
  void dispose() {
    unawaited(stopTxAutoRefresh().catchError((Object _, StackTrace _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
