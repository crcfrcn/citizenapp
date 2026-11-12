import 'dart:async';
import 'dart:convert';


import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_wallet/history/local_tx_store.dart';
import 'package:citizen_wallet/history/wallet_transaction_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

const _accountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  useIsolatedIsar();

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
      failed: true, feeAmount: BigInt.from(10), duplicateFee: true,
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
    expect((await LocalTxStore.queryByAccountId(_accountId)).single.feeAmount, '10');
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
      executionId: executionId, sourceAccountId: _accountId,
      callDataHash: '0x${'22' * 32}', transactionHash: txHash,
      status: CitizenTransactionHistoryStatus.pending, block: null,
      execution: null, replacementHash: null, createdAtMillis: BigInt.one,
      updatedAtMillis: BigInt.one, poolRejectionReason: null,
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
      for (var i = start; i <= end; i += BigInt.one) await getFinalizedBlockAt(i),
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

  Future<List<CitizenSystemEvent>> getFinalizedEvents(CitizenBlockRef block) async {
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
    events.add(CitizenSystemEvent(
      eventIndex: events.length, extrinsicIndex: 0,
      pallet: pallet, name: name, fields: fields,
    ));
  }
  for (final note in ['合成备注', if (twice) '第二笔']) {
    add('Balances', 'Transfer', {'from': from, 'to': to, 'amount': '100'});
    add('OnchainTransaction', 'TransferWithRemark', {
      'from_account_id': from, 'beneficiary_account_id': to, 'amount': '100',
      'remark': utf8.encode(note).map((byte) => byte.toString()).toList(),
    });
  }
  if (feeAmount != null) {
    for (var i = 0; i < (duplicateFee ? 2 : 1); i++) {
      add('OnchainTransaction', 'FeePaid', {
        'account_id': from, 'fee': feeAmount.toString(),
      });
    }
  }
  if (!omitOutcome) {
    add('System', failed ? 'ExtrinsicFailed' : 'ExtrinsicSuccess', null);
  }
  return events;
}
