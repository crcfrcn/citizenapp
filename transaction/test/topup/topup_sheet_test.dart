import 'package:citizen_testing/fixture.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:citizen_transaction/topup/topup_webview_page.dart';
import 'package:citizen_transaction/topup/topup_sheet.dart';
import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_result_page.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/store.dart';

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
              fixtureFile(
                'citizen_transaction',
                'topup/contract.json',
              ).readAsStringSync(),
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
  testWidgets('五链官方SVG实际渲染原色，CSS展开后不丢填色', (tester) async {
    final key = GlobalKey();
    for (final name in ['ethereum', 'base', 'solana', 'tron', 'bnb']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 80,
                height: 80,
                child: ColoredBox(
                  color: Colors.transparent,
                  child: SvgPicture.asset(
                    'packages/citizen_assets/icons/$name.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      });
      var colored = 0;
      for (var i = 0; i < pixels!.lengthInBytes; i += 4) {
        final r = pixels.getUint8(i),
            g = pixels.getUint8(i + 1),
            b = pixels.getUint8(i + 2);
        final matches = switch (name) {
          'base' => b > 200 && r < 60 && g < 100,
          'tron' => r > 200 && g < 80 && b < 100,
          'bnb' => r > 200 && g > 100 && b < 70,
          'ethereum' => b > r && b > g && b < 245,
          _ => (g > 140 && r < 130 && b > 80) || (r > 80 && b > 100 && g < 130),
        };
        if (matches) colored++;
      }
      expect(colored, greaterThan(20), reason: name);
      if (name == 'tron') expect(pixels.getUint8((5 * 80 + 5) * 4 + 3), 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('钱包使用账户详情上的底部弹窗，关闭返回且不压入独立支付页面', (tester) async {
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('账户详情')),
            body: TextButton(
              onPressed: () async {
                await showTopupSheet(
                  context,
                  child: Builder(
                    builder: (sheetContext) => Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('关闭测试钱包弹窗'),
                      ),
                    ),
                  ),
                );
                returned = true;
              },
              child: const Text('打开测试钱包弹窗'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开测试钱包弹窗'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('账户详情'), findsOneWidget);
    expect(find.text('连接钱包支付'), findsNothing);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(returned, false);
    await tester.tap(find.text('关闭测试钱包弹窗'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(returned, true);
  });

  testWidgets('币种入口保留两张，网络只在套餐内选择', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
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
      for (final id in ['pkg_10', 'pkg_900']) {
        for (final network in TopupNetwork.values.where(
          (n) => allowedPair(token, n),
        )) {
          final opened = <TopupSelection>[];
          final waiting = Completer<TopupRecord?>();
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$token:$id:${network.wire}'),
              home: TopupSheet(
                token: token,
                accountId: '0x${'04' * 32}',
                api: FakeApi(),
                store: MemoryStore(),
                paymentOpener: (choice, record) async {
                  opened.add(choice);
                  expect(record, isNull);
                  return waiting.future;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('10,000.00 公民币'), findsOneWidget);
          expect(find.text('1,000,000.00 公民币'), findsOneWidget);
          expect(find.text('连接钱包并支付'), findsNothing);
          for (final n in TopupNetwork.values.where(
            (n) => allowedPair(token, n),
          )) {
            expect(find.text(n.label), findsNWidgets(2));
          }
          expect(find.byType(TextButton), findsNWidgets(6));
          expect(find.byType(OutlinedButton), findsNothing);
          // 每档三列圆形底色图标处于同一行，全名称在窄屏也保持一行。
          for (final pkg in ['pkg_10', 'pkg_900']) {
            final icons = <Offset>[];
            for (final n in [
              TopupNetwork.ethereum,
              token == 'USDC' ? TopupNetwork.base : TopupNetwork.tron,
              token == 'USDC' ? TopupNetwork.solana : TopupNetwork.bnb,
            ]) {
              final item = find.byKey(ValueKey('$pkg:${n.wire}'));
              final icon = find.descendant(
                of: item,
                matching: find.byType(SvgPicture),
              );
              expect(icon, findsOneWidget);

              final label = tester.widget<Text>(
                find.descendant(of: item, matching: find.text(n.label)),
              );
              expect(label.textAlign, TextAlign.center);
              expect(label.softWrap, false);
              expect(label.maxLines, 1);
              final circle = find.descendant(
                of: item,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration! as BoxDecoration).shape ==
                          BoxShape.circle,
                ),
              );
              expect(circle, findsOneWidget);
              icons.add(tester.getCenter(circle));
              expect(tester.getSize(circle).width, greaterThan(48));
              expect(
                tester.getSize(circle).width,
                tester.getSize(circle).height,
              );
              expect(
                tester.widget<SvgPicture>(icon).width,
                closeTo(
                  tester.getSize(circle).width *
                      (n == TopupNetwork.base ? 24 : 36) /
                      56,
                  .1,
                ),
              );
            }
            expect(icons[0].dy, closeTo(icons[1].dy, .1));
            expect(icons[1].dy, closeTo(icons[2].dy, .1));
            expect(icons[0].dx, lessThan(icons[1].dx));
            expect(icons[1].dx, lessThan(icons[2].dx));
          }
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
          waiting.complete(null);
          await tester.pumpAndSettle();
        }
      }
    }
  });
  testWidgets('未就绪仍显示两档和三链，但不能进入钱包', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
          token: 'USDT',
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

    final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
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
        home: TopupSheet(
          token: 'USDT',
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

    final high = find.byKey(const ValueKey('pkg_900:bnb'));
    await tester.ensureVisible(high);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(high);
    await tester.pumpAndSettle();
    expect(chosen?.package.packageId, 'pkg_900');
    expect(chosen?.network, TopupNetwork.bnb);
    expect(tester.takeException(), isNull);
  });
  TopupRecord original() {
    final f = jsonDecode(
      fixtureFile(
        'citizen_transaction',
        'topup/contract.json',
      ).readAsStringSync(),
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
  testWidgets('未知付款打开弹窗直接恢复原订单，不显示新套餐', (tester) async {
    final r = original().update(
      progress: TopupProgress.submitting,
      signature: '0x${'aa' * 65}',
    );
    final api = FakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
          accountId: r.intent.accountId,
          api: api,
          store: MemoryStore([r]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TopupResultPage), findsOneWidget);
    expect(find.text('选择充值套餐 · USDC'), findsNothing);
    expect(find.text('暂时无法核实原订单，请稍后重试，勿重复付款'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('到账结果只关闭套餐弹窗，账户详情保留并回传成功', (tester) async {
    final r = original();
    final paid = r.update(
      progress: TopupProgress.confirmed,
      signature: '0x${'aa' * 65}',
      txid: '0x${'09' * 32}',
      order: TopupOrder(
        orderId: r.intent.orderId,
        orderState: TopupPhase.paid,
        coinFen: r.intent.coinFen,
        paymentTxid: '0x${'09' * 32}',
        gmbTxHash: '0x${'08' * 32}',
      ),
    );
    final api = FakeApi();
    bool? outcome;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('账户详情')),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await showTopup(
                  context,
                  accountId: r.intent.accountId,
                  token: 'USDC',
                  api: api,
                  store: MemoryStore([paid]),
                );
              },
              child: const Text('充值/USDC'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('充值/USDC'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('选择充值币种'), findsNothing);
    await tester.tap(find.text('充值订单 · 已到账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看钱包'));
    await tester.pumpAndSettle();
    expect(outcome, true);
    expect(api.statusCalls, 0);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('账户详情'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
