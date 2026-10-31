import 'package:citizen_storage/user_isar.dart'
    as wallet_store
    show WalletCursor, Entry;
import 'package:citizen_transaction/history/local_tx_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/account_derivation.dart';

import 'package:citizen_testing/isar_test_env.dart';

void main() {
  useIsolatedIsar();

  const fromAccountId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const fromAddress = 'from-wallet';
  const toAddress = 'to-wallet';

  test('对方地址取真实收发双方，净余额因费用为负也不改变收款方向', () {
    final owner = ss58FromAccountIdText(fromAccountId);
    final peer = ss58FromAccountIdText('0x${'bb' * 32}');
    final incoming = wallet_store.Entry()
      ..accountId = fromAccountId
      ..fromAddress = peer
      ..toAddress = owner
      ..amountDelta = '-1';
    expect(incoming.peerAddress, peer);
    incoming
      ..fromAddress = owner
      ..toAddress = peer;
    expect(incoming.peerAddress, peer);
  });

  // 只使用合成账户和金额，覆盖接入前后的同表数据及账户隔离。
  wallet_store.Entry historicalRow(
    String source,
    int timestamp, {
    String? accountId,
  }) {
    final owner = accountId ?? fromAccountId;
    return wallet_store.Entry()
      ..accountId = owner
      ..blockHash = '0x11'
      ..eventIndex = timestamp
      ..entryKind = 'transfer'
      ..amountDelta = '100'
      ..entrySource = source
      ..entryState = LocalTxStore.statusFinalized
      ..createdAt = timestamp;
  }

  test('既有收款按账户可见，分页、单条查询与总数使用同一范围', () async {
    final rows = [
      historicalRow('chain_event', 1),
      historicalRow('resync', 2),
      historicalRow('sdk_finalized_event', 3),
      historicalRow('local_submit', 4),
    ];
    for (final row in rows) {
      await LocalTxStore.upsert(row);
    }
    const other =
        '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    await LocalTxStore.upsert(
      historicalRow('chain_event', 5, accountId: other),
    );
    expect(await LocalTxStore.countByAccountId(fromAccountId), 4);
    expect(await LocalTxStore.countByAccountId(other), 1);
    expect(
      (await LocalTxStore.queryByAccountId(
        fromAccountId,
        offset: 1,
        limit: 2,
      )).map((row) => row.entrySource),
      ['sdk_finalized_event', 'resync'],
    );
    expect(
      await LocalTxStore.queryByAccountId(fromAccountId, offset: 4),
      isEmpty,
    );
    for (final row in rows) {
      expect((await LocalTxStore.readEntry(row.rowId))?.rowId, row.rowId);
    }
    expect(await LocalTxStore.readEntry(-1), isNull);
  });

  test('恢复旧记录可见性不会授予其 SDK 状态更新权限', () async {
    for (final source in [
      'chain_event',
      'sdk_finalized_event',
      'local_submit',
    ]) {
      final row = historicalRow(source, 1)
        ..txHash = '0xabc'
        ..entryState = LocalTxStore.statusPending
        ..executionId = source == 'local_submit' ? '' : 'execution-1'
        ..callHash = source == 'local_submit' ? '' : '0x${'11' * 32}';
      await LocalTxStore.upsert(row);
      await LocalTxStore.markLocalSubmitFinalized(
        accountId: fromAccountId,
        txHash: '0xabc',
        executionId: row.executionId!,
        callHash: row.callHash!,
      );
      expect(
        (await LocalTxStore.readEntry(row.rowId))?.entryState,
        LocalTxStore.statusPending,
      );
    }
  });

  Future<void> insert({String txHash = '0xabc'}) =>
      LocalTxStore.upsertLocalSubmitTransfer(
        accountId: fromAccountId,
        txHash: txHash,
        executionId: 'execution-1',
        callHash: '0x${'11' * 32}',
        amountDelta: '-101',
        transferAmount: '100',
        feeAmount: '1',
        fromAddress: fromAddress,
        toAddress: toAddress,

        createdAt: 1,
        txNote: '备注',
      );

  test('App 业务字段与 SDK execution/hash 关联后只保留一条记录', () async {
    await insert();

    final records = await LocalTxStore.queryByAccountId(fromAccountId);
    expect(records, hasLength(1));
    final record = records.single;
    expect(record.executionId, 'execution-1');
    expect(record.callHash, '0x${'11' * 32}');
    expect(record.txHash, '0xabc');
    expect(record.transferAmount, '100');
    expect(record.feeAmount, '1');
    expect(record.txNote, '备注');
    expect(record.entryState, LocalTxStore.statusPending);
  });

  test('inBlock 和 finalized 只投影 SDK 事实，原主键不变', () async {
    await insert();
    final before = (await LocalTxStore.queryByAccountId(fromAccountId))
        .single
        .rowId;

    await LocalTxStore.markLocalSubmitInBlock(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'execution-1',
      callHash: '0x${'11' * 32}',
      blockHash: '0x${'22' * 32}',
    );
    expect(
      (await LocalTxStore.queryByAccountId(fromAccountId)).single.entryState,
      LocalTxStore.statusInBlock,
    );

    await LocalTxStore.markLocalSubmitFinalized(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'execution-1',
      callHash: '0x${'11' * 32}',
      blockHash: '0x${'22' * 32}',
      blockNumber: 9,
      extrinsicIndex: 2,
    );
    final after = (await LocalTxStore.queryByAccountId(fromAccountId)).single;
    expect(after.rowId, before);
    expect(after.entryState, LocalTxStore.statusFinalized);
    expect(after.blockNumber, 9);
    expect(after.extrinsicIndex, 2);
  });

  test('SDK 交易池拒绝只更新失败展示，不丢失业务字段', () async {
    await insert(txHash: '0xdef');
    await LocalTxStore.markLocalSubmitFailed(
      accountId: fromAccountId,
      txHash: '0xdef',
      executionId: 'execution-1',
      callHash: '0x${'11' * 32}',
      failReason: 'pool rejected',
    );

    final record = (await LocalTxStore.queryByAccountId(fromAccountId)).single;
    expect(record.entryState, LocalTxStore.statusFailed);
    expect(record.failReason, 'pool rejected');
    expect(record.executionId, 'execution-1');
    expect(record.transferAmount, '100');
  });

  test('拒绝 executionId 或 callDataHash 不匹配的 SDK 状态投影', () async {
    await insert();

    await LocalTxStore.markLocalSubmitFinalized(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'other-execution',
      callHash: '0x${'11' * 32}',
    );
    await LocalTxStore.markLocalSubmitFailed(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'execution-1',
      callHash: '0x${'22' * 32}',
      failReason: 'must-not-apply',
    );

    final record = (await LocalTxStore.queryByAccountId(fromAccountId)).single;
    expect(record.entryState, LocalTxStore.statusPending);
    expect(record.failReason, isNull);
  });

  test('finalized 业务事件合并后保留原主键 且不覆盖 SDK 状态', () async {
    await insert();
    final rowId = (await LocalTxStore.queryByAccountId(fromAccountId))
        .single
        .rowId;

    await LocalTxStore.upsertBlockTransferEvent(
      accountId: fromAccountId,
      entryState: LocalTxStore.statusFinalized,
      amountDelta: '-110',
      transferAmount: '100',
      feeAmount: '10',
      fromAddress: fromAddress,
      toAddress: toAddress,
      blockNumber: 10,
      blockHash: '0x${'33' * 32}',
      eventIndex: 4,
      extrinsicIndex: 2,
      txHash: '0xabc',
    );

    final records = await LocalTxStore.queryByAccountId(fromAccountId);
    expect(records, hasLength(1));
    expect(records.single.rowId, rowId);
    expect(records.single.executionId, 'execution-1');
    expect(records.single.entryState, LocalTxStore.statusPending);

    await LocalTxStore.markLocalSubmitFinalized(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'execution-1',
      callHash: '0x${'11' * 32}',
      blockHash: '0x${'33' * 32}',
      blockNumber: 10,
      extrinsicIndex: 2,
    );
    expect(
      (await LocalTxStore.queryByAccountId(fromAccountId)).single.entryState,
      LocalTxStore.statusFinalized,
    );
  });

  Future<void> event({String hash = '0xabc', int index = 4}) =>
      LocalTxStore.upsertBlockTransferEvent(
        accountId: fromAccountId,
        entryState: LocalTxStore.statusFinalized,
        txHash: hash,
        amountDelta: '-110',
        transferAmount: '100',
        feeAmount: '10',
        fromAddress: fromAddress,
        toAddress: toAddress,
        blockNumber: 10,
        blockHash: '0x33',
        eventIndex: index,
        extrinsicIndex: 2,
      );

  test('不同哈希的同金额转账保留两条，重放同一事件不重复', () async {
    await insert();
    await event(hash: '0xdef');
    await event(hash: '0xdef');
    final rows = await LocalTxStore.queryByAccountId(fromAccountId);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.txHash).toSet(), {'0xabc', '0xdef'});
  });

  test('事件先到再本机提交保留已验证费用，预估不能覆盖真实费用', () async {
    await event();
    await insert();
    await event();
    final rows = await LocalTxStore.queryByAccountId(fromAccountId);
    expect(rows, hasLength(1));
    expect(rows.single.txHash, '0xabc');
    expect(rows.single.amountDelta, '-110');
    expect(rows.single.feeAmount, '10');
    expect(rows.single.entryState, LocalTxStore.statusPending);
  });

  test('同一 extrinsic 的第二个独立事件不能覆盖已关联事件', () async {
    await insert();
    await event(index: 4);
    await event(index: 5);
    await event(index: 5);
    final rows = await LocalTxStore.queryByAccountId(fromAccountId);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.eventIndex).toSet(), {4, 5});
  });

  wallet_store.WalletCursor cursor() => wallet_store.WalletCursor()
    ..accountId = fromAccountId
    ..createdAt = 1000
    ..genesisHash = '0x00'
    ..startBlock = 10
    ..cursorBlock = 9;

  test('记录和进度原子提交，重新提交过期进度被拒绝', () async {
    final progress = cursor();
    await LocalTxStore.insertHistoryCursor(progress);
    final row = historicalRow('sdk_finalized_event', 10000)..blockNumber = 10;
    await LocalTxStore.commitHistoryBlock(
      blockNumber: 10,
      cursors: [progress],
      records: [row],
    );
    expect((await LocalTxStore.historyCursor(fromAccountId))!.cursorBlock, 10);
    expect(await LocalTxStore.countByAccountId(fromAccountId), 1);
    await expectLater(
      LocalTxStore.commitHistoryBlock(
        blockNumber: 10,
        cursors: [progress],
        records: [row],
      ),
      throwsStateError,
    );
  });

  test('块内第二条越界记录使第一条和进度一起回滚', () async {
    final progress = cursor();
    await LocalTxStore.insertHistoryCursor(progress);
    final valid = historicalRow('sdk_finalized_event', 10000)..blockNumber = 10;
    final invalid = historicalRow('sdk_finalized_event', 10001)
      ..blockNumber = 11;
    await expectLater(
      LocalTxStore.commitHistoryBlock(
        blockNumber: 10,
        cursors: [progress],
        records: [valid, invalid],
      ),
      throwsStateError,
    );
    expect(await LocalTxStore.countByAccountId(fromAccountId), 0);
    expect((await LocalTxStore.historyCursor(fromAccountId))!.cursorBlock, 9);
    expect(progress.cursorBlock, 9);
  });

  test('导入代次不符或进度跳块时不得写入', () async {
    final progress = cursor();
    await LocalTxStore.insertHistoryCursor(progress);
    await expectLater(
      LocalTxStore.commitHistoryBlock(
        blockNumber: 11,
        cursors: [progress],
        records: [],
      ),
      throwsStateError,
    );
    progress.createdAt++;
    await expectLater(
      LocalTxStore.commitHistoryBlock(
        blockNumber: 10,
        cursors: [progress],
        records: [],
      ),
      throwsStateError,
    );
    expect((await LocalTxStore.historyCursor(fromAccountId))!.cursorBlock, 9);
  });

  test('失败交易的收费事实原子合并，但不代替 SDK 推进执行状态', () async {
    await insert();
    final progress = cursor();
    await LocalTxStore.insertHistoryCursor(progress);
    final fee = wallet_store.Entry()
      ..accountId = fromAccountId
      ..txHash = '0xabc'
      ..entryKind = 'fee'
      ..entrySource = 'sdk_finalized_event'
      ..entryState = LocalTxStore.statusFinalized
      ..amountDelta = '-10'
      ..feeAmount = '10'
      ..blockNumber = 10
      ..blockHash = '0x${'33' * 32}'
      ..eventIndex = 4
      ..extrinsicIndex = 2
      ..failReason = '链上执行失败'
      ..createdAt = 1000;
    await LocalTxStore.commitHistoryBlock(
      blockNumber: 10,
      cursors: [progress],
      records: [fee],
    );
    final record = (await LocalTxStore.queryByAccountId(fromAccountId)).single;
    expect(record.txHash, '0xabc');
    expect(record.amountDelta, '-10');
    expect(record.feeAmount, '10');
    expect(record.entryState, LocalTxStore.statusPending);
    expect((await LocalTxStore.historyCursor(fromAccountId))!.cursorBlock, 10);
    await LocalTxStore.markLocalSubmitFailed(
      accountId: fromAccountId,
      txHash: '0xabc',
      executionId: 'execution-1',
      callHash: '0x${'11' * 32}',
      failReason: 'SDK确认执行失败',
    );
    expect(
      (await LocalTxStore.queryByAccountId(fromAccountId)).single.entryState,
      LocalTxStore.statusFailed,
    );
  });
}
