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

void main() {
  useIsolatedIsar();
  TopupRecord order() => TopupRecord.signed(
    TopupDraft.create(
      TopupSelection(
        token: 'USDC',
        package: TopupConfig.local().packages.first,
        network: TopupNetwork.base,
      ),
      '0x${'04' * 32}',
    ),
    TopupWallets.ids.first,
    '0x${'01' * 64}',
    now: 1000000,
  );

  testWidgets('充值详情复用本地快照，创建即显示待付款且不展示恢复秘密', (tester) async {
    final value = order();
    final row = TopupStore.toEntry(value);
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: row)),
    );
    expect(find.text('充值订单详情'), findsOneWidget);
    expect(find.text('待支付'), findsOneWidget);
    expect(find.text(value.payment.orderId), findsOneWidget);
    expect(find.text('预计公民币'), findsOneWidget);
    expect(find.text('recovery_token'), findsNothing);
    expect(find.text(value.accountSignature), findsNothing);
    expect(find.text('+0.00'), findsNothing);
  });

  testWidgets('付款验款通过显示已支付，金额不伪造为公民币收入', (tester) async {
    final value = order(),
        p = value.payment,
        payer = '0x${'01' * 20}',
        tx = '0x${'02' * 32}';
    final proof = TopupProof.fromJson({
      'network': p.network.wire,
      'payment_txid': tx,
      'payer_address': payer,
      'asset': p.asset,
      'recv_address': p.recvAddress,
      'pay_amount': p.payAmount,
      'binding_hash': value.binding,
      'block_hash': '0x${'03' * 32}',
      'block_number': 10,
      'block_at': 1000000,
      'transfer_index': 0,
      'checked_at': 1000000,
      'finalized': true,
      'succeeded': true,
    });
    final row = TopupStore.toEntry(
      value.update(
        progress: TopupProgress.paid,
        payer: payer,
        txid: tx,
        wire: 'synthetic original transaction',
        proof: proof,
        requestAt: 1000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalTxRecordTile(record: row)),
      ),
    );
    expect(find.text('已支付'), findsOneWidget);
    expect(find.text('已到账'), findsNothing);
    expect(row.amountDelta, '0');
    await tester.pumpWidget(
      MaterialApp(home: LocalTxRecordDetailPage(record: row)),
    );
    expect(find.text('已支付'), findsOneWidget);
    expect(find.text('预计公民币'), findsOneWidget);
    expect(find.text('到账公民币'), findsNothing);
  });
  testWidgets('明确取消和失败不会在详情中误显示付款待核实', (tester) async {
    for (final code in ['payment_cancelled', 'payment_failed']) {
      final row = TopupStore.toEntry(order().update(failureCode: code));
      await tester.pumpWidget(
        MaterialApp(home: LocalTxRecordDetailPage(record: row)),
      );
      final reason = code == 'payment_cancelled'
          ? '本次付款已取消，未上传服务端'
          : '付款验证失败，未上传服务端';
      await tester.ensureVisible(find.text(reason));
      expect(find.text(reason), findsOneWidget);
      expect(find.text('付款结果尚未核实，请保留原交易'), findsNothing);
    }
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
            accountId: value.payment.accountId,
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

  testWidgets('原结果页仅展示本地详情，删除立即退出且不含恢复重付入口', (tester) async {
    final store = TopupStore(), value = order();
    await tester.runAsync(() => store.save(value));
    final rows = await tester.runAsync(
      () => LocalTxStore.queryByAccountId(value.payment.accountId),
    );
    final row = rows!.single;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LocalTxRecordDetailPage(record: row),
              ),
            ),
            child: const Text('打开原订单'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开原订单'));
    await tester.pumpAndSettle();
    expect(find.text('待支付'), findsOneWidget);
    expect(find.text('重新付款'), findsNothing);
    await tester.runAsync(() => store.delete(row));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('打开原订单'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
