import 'package:citizen_transaction/history/record_tile.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_transaction/history/local_tx_store.dart';
import 'package:citizen_transaction/history/transaction_history_page.dart';

wallet_store.Entry _record({String status = LocalTxStore.statusFinalized}) {
  return wallet_store.Entry()
    ..accountId = '0x${'aa' * 32}'
    ..entryKind = 'transfer'
    ..amountDelta = '120'
    ..transferAmount = '120'
    ..fromAddress = 'from_addr'
    ..toAddress = 'wallet_addr'
    ..entryState = status
    ..entrySource = 'chain_event'
    ..blockNumber = 10
    ..blockHash = '0xblock'
    ..eventIndex = 1
    ..createdAt = DateTime(2026, 5, 20, 12).millisecondsSinceEpoch
    ..confirmedAt = status == LocalTxStore.statusFinalized
        ? DateTime(2026, 5, 20, 12, 1).millisecondsSinceEpoch
        : null;
}

void main() {
  testWidgets('u128真实费用逐分显示，最佳链与预估费用明确标注', (tester) async {
    final pending = _record(status: LocalTxStore.statusInBlock)
      ..entrySource = 'local_submit'
      ..eventIndex = null
      ..feeAmount = '10';
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: pending)),
    );
    expect(find.text('预估手续费'), findsOneWidget);
    expect(find.text('最佳链已打包，等待最终确认'), findsOneWidget);
    final actual = _record()
      ..entrySource = 'sdk_finalized_event'
      ..feeAmount = '340282366920938463463374607431768211455';
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: actual)),
    );
    expect(find.text('真实手续费'), findsOneWidget);
    expect(
      find.text('3,402,823,669,209,384,634,633,746,074,317,682,114.55 元'),
      findsOneWidget,
    );
    expect(find.text('最终链已确认'), findsOneWidget);
  });

  testWidgets('收到和发出记录共用条目，SDK业务事件显示中文来源', (tester) async {
    final income = _record()..entrySource = 'sdk_finalized_event';
    final expense = _record()..amountDelta = '-120';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LocalTxRecordTile(record: income),
              LocalTxRecordTile(record: expense),
            ],
          ),
        ),
      ),
    );
    expect(find.text('+1.20'), findsOneWidget);
    expect(find.text('-1.20'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: income)),
    );
    expect(find.text('链上事件'), findsOneWidget);
    expect(find.text('sdk_finalized_event'), findsNothing);
  });

  testWidgets('交易记录条目显示 finalized 状态标签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalTxRecordTile(record: _record())),
      ),
    );

    expect(find.text('转账'), findsOneWidget);
    expect(find.text('已确认'), findsOneWidget);
    expect(find.text('+1.20'), findsOneWidget);
  });

  testWidgets('钱包详情最近记录可显示进入详情箭头', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalTxRecordTile(record: _record(), showChevron: true),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('点击交易记录条目进入交易详情页', (tester) async {
    final record = _record(status: LocalTxStore.statusInBlock);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => LocalTxRecordTile(
              record: record,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocalTxRecordDetailPage(record: record),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();

    expect(find.text('交易详情'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
    expect(find.text('已出块'), findsNothing);
    expect(find.text('区块号'), findsOneWidget);
  });
}
