import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/transaction/topup/onchain_topup_page.dart';
import 'package:citizenapp/transaction/topup/topup_api.dart';
import 'package:citizenapp/transaction/topup/topup_result_page.dart';
import 'package:citizenapp/transaction/topup/topup_models.dart';
import 'package:citizenapp/transaction/topup/store.dart';

class FakeApi extends TopupApi {
  int statusCalls = 0;
  TopupOrder? order;
  @override
  Future<TopupOrder> status(TopupPaymentIntent intent) async {
    statusCalls++;
    if (order == null) throw StateError('synthetic unavailable');
    return order!;
  }

  FakeApi() : super(baseUrl: 'https://www.crcfrcn.com/api');
  @override
  Future<TopupConfig> fetchConfig() async => TopupConfig.fromJson(
    (jsonDecode(File('test/transaction/topup/contract.json').readAsStringSync())
            as Map<String, dynamic>)['config']
        as Map<String, dynamic>,
  );
}

class MemoryStore extends TopupStore {
  MemoryStore([this.values = const []]);
  final List<TopupRecord> values;
  @override
  Future<void> save(TopupRecord record, {TopupRecord? before}) async {}
  @override
  Future<List<TopupRecord>> list(String origin, String account) async => values;
}

void main() {
  testWidgets('复用两张币种卡片，六币轨不变成网络选择', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnchainTopupPage(
          accountId: '0x${'04' * 32}',
          api: FakeApi(),
          store: MemoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('USDC'), findsOneWidget);
    expect(find.text('USDT'), findsOneWidget);
    expect(find.text('去支付'), findsNWidgets(2));
    expect(find.text('Ethereum · Base · Solana'), findsOneWidget);
    expect(find.text('Ethereum · Tron · BNB'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
  testWidgets('原套餐弹窗只显示两项，选择效果和按钮保留', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnchainTopupPage(
          accountId: '0x${'04' * 32}',
          api: FakeApi(),
          store: MemoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDC'));
    await tester.tap(find.text('USDC'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('选择充值套餐 · USDC'), findsOneWidget);
    expect(find.text('10,000.00 公民币'), findsOneWidget);
    expect(find.text('1,000,000.00 公民币'), findsOneWidget);
    expect(find.text('连接钱包并支付'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('1,000,000.00 公民币'));
    await tester.pumpAndSettle();
    expect(find.text('更优汇率'), findsOneWidget);
  });
  TopupRecord original() {
    final f = jsonDecode(
      File('test/transaction/topup/contract.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return TopupRecord(
      origin: 'https://www.crcfrcn.com',
      intent: TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>),
    );
  }

  Future<void> result(
    WidgetTester tester,
    TopupRecord record,
    FakeApi api,
  ) async {
    final config = await api.fetchConfig();
    await tester.pumpWidget(
      MaterialApp(
        home: TopupResultPage(
          api: api,
          store: MemoryStore(),
          record: record,
          package: config.packages.first,
          onReplay: (_) async => null,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('保护记录中已到账的订单离线仍显示到账，不再确认付款', (tester) async {
    final r = original(), api = FakeApi();
    final paid = r.update(
      progress: TopupProgress.confirmed,
      signature: '0x${'aa' * 65}',
      txid: '0x${'09' * 32}',
      order: TopupOrder(
        id: r.intent.order,
        status: TopupOrderStatus.paid,
        phase: TopupPhase.paid,
        coinFen: r.intent.coinFen,
        paymentTxid: '0x${'09' * 32}',
        gmbTxHash: '0x${'08' * 32}',
      ),
    );
    await result(tester, paid, api);
    expect(find.text('已到账'), findsOneWidget);
    expect(find.text('查看钱包'), findsOneWidget);
    expect(api.statusCalls, 0);
  });
  testWidgets('服务端已收U等待发币与长等待均不显示失败或已到账', (tester) async {
    final r = original(), api = FakeApi();
    api.order = TopupOrder(
      id: r.intent.order,
      status: TopupOrderStatus.pending,
      phase: TopupPhase.received,
      coinFen: r.intent.coinFen,
      paymentTxid: '0x${'09' * 32}',
    );
    await result(
      tester,
      r.update(
        progress: TopupProgress.confirmed,
        signature: '0x${'aa' * 65}',
        txid: '0x${'09' * 32}',
      ),
      api,
    );
    expect(find.text('稳定币已收款，等待发币'), findsOneWidget);
    await tester.pump(const Duration(minutes: 3));
    expect(find.text('已到账'), findsNothing);
    expect(find.text('需要核查'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('未知付款返回后点币种卡只恢复原订单，不弹新套餐', (tester) async {
    final r = original().update(
      progress: TopupProgress.submitting,
      signature: '0x${'aa' * 65}',
    );
    final api = FakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: OnchainTopupPage(
          accountId: r.intent.accountId,
          api: api,
          store: MemoryStore([r]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TopupResultPage), findsOneWidget);
    expect(find.text('选择充值套餐 · USDC'), findsNothing);
    expect(find.text('暂时无法核实原订单，请稍后重试，勿重复付款'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
