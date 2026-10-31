import 'dart:async';
import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_result_page.dart';
import 'dart:convert';
import 'package:citizen_testing/fixture.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
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

class _WaitingTopupApi extends TopupApi {
  final response = Completer<TopupOrder>();
  int calls = 0;
  @override
  Future<TopupOrder> status(TopupPaymentIntent intent) {
    calls++;
    return response.future;
  }
}

void main() {
  useIsolatedIsar();
  TopupRecord order() => TopupRecord(
    origin: 'https://www.crcfrcn.com',
    intent: TopupPaymentIntent.fromJson(
      (jsonDecode(
                fixtureFile(
                  'citizen_transaction',
                  'topup/contract.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['intent_data']
          as Map<String, dynamic>,
    ),
  );

  testWidgets('充值详情复用本地快照，过期订单可见且不展示恢复秘密', (tester) async {
    final value = order(), row = TopupStore.toEntry(order());
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: row)),
    );
    expect(find.text('充值订单详情'), findsOneWidget);
    expect(find.text('报价已过期'), findsOneWidget);
    expect(find.text(value.intent.orderId), findsOneWidget);
    expect(find.text('预计公民币'), findsOneWidget);
    expect(find.text(value.intent.intentToken), findsNothing);
    expect(find.text(value.intent.signMessage), findsNothing);
    expect(find.text('+0.00'), findsNothing);
  });

  testWidgets('充值明细损坏时列表和详情显示固定错误且仍有删除入口', (tester) async {
    final row = TopupStore.toEntry(order())..orderData = '{';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalTxRecordTile(record: row)),
      ),
    );
    expect(find.text('记录损坏'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: row)),
    );
    expect(find.text('本地充值记录损坏，不能继续付款'), findsOneWidget);
    expect(find.byTooltip('删除本地记录'), findsOneWidget);
  });

  testWidgets('充值列表打开详情并删除，同一列表立即移除本地订单', (tester) async {
    final store = TopupStore(), value = order();
    await tester.runAsync(() => store.save(value));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: TransactionHistoryPage(
            accountAddress: 'synthetic',
            accountId: value.intent.accountId,
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.text('充值 · USDC').evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text('充值 · USDC'), findsOneWidget);
      await tester.tap(find.text('充值 · USDC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除本地记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      for (var i = 0; i < 40 && find.text('暂无交易记录').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.text('暂无交易记录'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }
  });

  testWidgets('删除进行中订单立即停止结果页轮询，迟到响应不重新保存', (tester) async {
    final store = TopupStore(), value = order(), api = _WaitingTopupApi();
    await tester.runAsync(() => store.save(value));
    final row = TopupStore.toEntry(value);
    final saved = await tester.runAsync(
      () => LocalTxStore.queryByAccountId(value.intent.accountId),
    );
    row.rowId = saved!.single.rowId;
    final fixture =
        jsonDecode(
              fixtureFile(
                'citizen_transaction',
                'topup/contract.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final package = TopupConfig.fromJson(
      fixture['config'] as Map<String, dynamic>,
    ).packageById(value.intent.intentData['package_id'] as String);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TopupResultPage(
                  api: api,
                  store: store,
                  record: value,
                  package: package,
                  onReplay: (_) async => null,
                ),
              ),
            ),
            child: const Text('打开原订单'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开原订单'));
    await tester.pump();
    expect(api.calls, 1);
    await tester.runAsync(() => store.delete(row));
    api.response.complete(
      TopupOrder(
        orderId: value.intent.orderId,
        orderState: TopupPhase.awaiting,
        coinFen: value.intent.coinFen,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(api.calls, 1);
    expect(find.text('支付结果'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });

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
