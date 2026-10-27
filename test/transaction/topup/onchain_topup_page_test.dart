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
  final bool ready;
  TopupOrder? order;
  @override
  Future<TopupOrder> status(TopupPaymentIntent intent) async {
    statusCalls++;
    if (order == null) throw StateError('synthetic unavailable');
    return order!;
  }

  FakeApi({this.ready = true}) : super(baseUrl: 'https://www.crcfrcn.com/api');
  @override
  Future<TopupConfig> fetchConfig() async {
    final value =
        (jsonDecode(
              File('test/transaction/topup/contract.json').readAsStringSync(),
            ) as Map<String, dynamic>)['config']
            as Map<String, dynamic>;
    value['ready'] = ready;
    return TopupConfig.fromJson(value);
  }
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
  testWidgets('币种入口保留两张，网络只在套餐内选择', (tester) async {
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
  testWidgets('两个套餐各三条链，点击一次直接传递十二种准确付款组合', (tester) async {
    for (final token in ['USDC', 'USDT']) {
      for (final id in ['pkg_15', 'pkg_1400']) {
        for (final network in TopupNetwork.values.where(
          (n) => allowedPair(token, n),
        )) {
          final opened = <TopupSelection>[];
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$token:$id:${network.wire}'),
              home: OnchainTopupPage(
                accountId: '0x${'04' * 32}',
                api: FakeApi(),
                store: MemoryStore(),
                paymentOpener: (choice, record) async {
                  opened.add(choice);
                  expect(record, isNull);
                  return null;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(token));
          await tester.pumpAndSettle();
          expect(find.text('10,000.00 公民币'), findsOneWidget);
          expect(find.text('1,000,000.00 公民币'), findsOneWidget);
          expect(find.text('连接钱包并支付'), findsNothing);
          for (final n in TopupNetwork.values.where(
            (n) => allowedPair(token, n),
          )) {
            expect(find.text(n.label), findsNWidgets(2));
          }
          expect(find.byType(OutlinedButton), findsNWidgets(6));
          expect(find.byType(TextField), findsNothing);
          final entry = find.byKey(ValueKey('$id:${network.wire}'));
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.tap(entry, warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(opened.length, 1);
          expect(opened.single.toJson(), {
            'token': token,
            'package_id': id,
            'network': network.wire,
          });
        }
      }
    }
  });
  testWidgets('未就绪仍显示两档和三链，但不能进入钱包', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnchainTopupPage(
          accountId: '0x${'04' * 32}',
          api: FakeApi(ready: false),
          store: MemoryStore(),
          paymentOpener: (_, _) async {
            opened++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDT'));
    await tester.pumpAndSettle();
    final buttons = tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(buttons.length, 6);
    expect(buttons.every((b) => b.onPressed == null), true);
    expect(find.text('充值暂未开放'), findsOneWidget);
    expect(opened, 0);
  });
  testWidgets('窄屏和大字体的套餐与完整网络名称不溢出，可滚动选择高档', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TopupSelection? chosen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: OnchainTopupPage(
          accountId: '0x${'04' * 32}',
          api: FakeApi(),
          store: MemoryStore(),
          paymentOpener: (choice, _) async {
            chosen = choice;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDT'));
    await tester.pumpAndSettle();
    final high = find.byKey(const ValueKey('pkg_1400:bnb'));
    await tester.ensureVisible(high);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(high);
    await tester.pumpAndSettle();
    expect(chosen?.package.packageId, 'pkg_1400');
    expect(chosen?.network, TopupNetwork.bnb);
    expect(tester.takeException(), isNull);
  });
  TopupRecord original() {
    final f = jsonDecode(
      File('test/transaction/topup/contract.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return TopupRecord(
      origin: 'https://www.crcfrcn.com',
      intent: TopupPaymentIntent.fromJson(
        f['intent_data'] as Map<String, dynamic>,
      ),
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
        orderId: r.intent.orderId,
        status: TopupOrderStatus.paid,
        orderState: TopupPhase.paid,
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
      orderId: r.intent.orderId,
      status: TopupOrderStatus.pending,
      orderState: TopupPhase.received,
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
