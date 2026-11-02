import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_transaction/topup/topup_webview_page.dart';
import 'package:citizen_transaction/topup/topup_sheet.dart';
import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_result_page.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_system/theme/app_theme.dart';

class FakeApi extends TopupApi {
  int requests = 0;
  @override
  Future<Object?> paymentRpc(
    TopupNetwork network,
    String method,
    List<Object?> params,
  ) async {
    requests++;
    throw StateError('unexpected payment request');
  }

  @override
  Future<TopupReceipt> requestIssuance(
    PaidTopupOrder order, {
    Map<String, Object?>? notify,
  }) async {
    requests++;
    throw StateError('unexpected issuance request');
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
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('打开真实充值弹窗只预备一次本地宿主，不签名建单或访问接口', (tester) async {
    final session = TopupWalletSession(), api = FakeApi(), store = MemoryStore();
    var preparations = 0; session.addListener(() => preparations++);
    Widget app() => ChangeNotifierProvider<TopupWalletSession>.value(value:session,
      child:MaterialApp(home:Scaffold(body:TopupSheet(accountId:'0x${'04' * 32}',token:'USDT',api:api,store:store))));
    await tester.pumpWidget(app()); await tester.pump();
    expect(session.started, true); expect(preparations, 1); expect(api.requests, 0);
    expect(find.byType(TopupWebviewPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app()); await tester.pump();
    expect(preparations, 1); expect(api.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink()); session.close(); session.dispose();
  });
  testWidgets('App付款宿主只请求创建一次，关闭会唤醒等待者且不访问充值接口', (tester) async {
    final session = TopupWalletSession(),
        api = FakeApi(),
        store = MemoryStore();
    var starts = 0;
    session.addListener(() => starts++);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final selection = TopupSelection(
      token: 'USDT',
      package: TopupConfig.local().packages.first,
      network: TopupNetwork.ethereum,
    );
    final first = session.pay(context, selection, '0x${'04' * 32}', api, store);
    final second = session.pay(
      context,
      selection,
      '0x${'04' * 32}',
      api,
      store,
    );
    final firstError = expectLater(first, throwsStateError),
        secondError = expectLater(second, throwsStateError);
    expect(session.started, true);
    expect(starts, 1);
    expect(api.requests, 0);
    session.close();
    await firstError;
    await secondError;
    expect(find.byType(TopupWebviewPage), findsNothing);
    session.dispose();
  });
  testWidgets('三链与MetaMask官方SVG实际渲染原色', (tester) async {
    final key = GlobalKey();
    for (final name in ['ethereum', 'base', 'bnb', 'metamask']) {
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
                  child: name == 'metamask'
                      ? SvgPicture.string(TopupWallet.logo, fit: BoxFit.contain)
                      : SvgPicture.asset(
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
          'bnb' => r > 200 && g > 100 && b < 70,
          'ethereum' => b > r && b > g && b < 245,
          'metamask' => r > 200 && g > 50 && g < 180 && b < 100,
          _ => (g > 140 && r < 130 && b > 80) || (r > 80 && b > 100 && g < 130),
        };
        if (matches) colored++;
      }
      expect(colored, greaterThan(20), reason: name);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('默认10000、所有链未选，顶部固定MetaMask，切换套餐不建单不访问充值接口', (tester) async {
    final api = FakeApi(), store = MemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
          accountId: '0x${'04' * 32}',
          token: 'USDT',
          api: api,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in ['充值金额', '支付网络', '使用 ', ' MetaMask 钱包支付']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('topup-metamask-logo')), findsOneWidget);
    expect(
      tester
          .widget<SvgPicture>(find.byKey(const ValueKey('topup-metamask-logo')))
          .bytesLoader,
      isA<SvgStringLoader>(),
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('topup-package-0')))
          .selected,
      true,
    );
    for (final network in TopupNetwork.values) {
      final node = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == network.label,
        ),
      );
      expect(node.properties.selected, false);
    }
    expect(find.text('10,000.00 元'), findsOneWidget);
    expect(find.text('1,000,000.00 元'), findsOneWidget);
    expect(find.text('公民币'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('付款金额：10.00USD'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('topup-pay-amount'))).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('topup-package-1'))).bottom,
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
      findsNWidgets(3),
    );
    final selected = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('topup-package-0')),
    );
    expect(selected.checkmarkColor, AppTheme.primary);
    expect(selected.labelStyle?.color, AppTheme.primary);
    for (final network in TopupNetwork.values) {
      expect(
        find.text(
          '${network.label.split('/').last}\n${network.label.split('/').first}',
        ),
        findsOneWidget,
      );
    }
    expect(find.text('付款钱包'), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('topup-package-1')));
    await tester.pumpAndSettle();
    expect(find.text('付款金额：900.00USD'), findsOneWidget);
    expect(find.text('付款金额：10.00USD'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('topup-package-0')));
    await tester.pumpAndSettle();
    expect(find.text('付款金额：10.00USD'), findsOneWidget);
    expect(api.requests, 0);
    expect(store.values, isEmpty);
    expect(find.byType(TopupWebviewPage), findsNothing);
    expect(find.byType(TextField), findsNothing);
    api.close();
  });
  testWidgets('三网络两币种两套餐共12种链点击，直接开始且连点只交付一次', (tester) async {
    var combinations = 0;
    for (final token in ['USDT', 'USDC']) {
      for (var package = 0; package < 2; package++) {
        for (final network in TopupNetwork.values) {
          final api = FakeApi(), opened = <TopupSelection>[];
          final waiting = Completer<TopupRecord?>();
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: TopupSheet(
                accountId: '0x${'04' * 32}',
                token: token,
                api: api,
                store: MemoryStore(),
                paymentOpener: (selection) {
                  opened.add(selection);
                  return waiting.future;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('topup-package-$package')));
          final icon = find.byKey(ValueKey('topup-network-${network.wire}'));
          await tester.tap(icon);
          await tester.pump();
          await tester.tap(icon);
          expect(opened.length, 1);
          expect(opened.single.toJson(), {
            'token': token,
            'package_id': package == 0 ? 'pkg_10' : 'pkg_900',
            'network': network.wire,
          });
          expect(api.requests, 0);
          combinations++;
          api.close();
        }
      }
    }
    expect(combinations, 12);
  });
  testWidgets('签名或本地保存失败停留原弹窗、取消链选中，不创建付款页面', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
          accountId: '0x${'04' * 32}',
          token: 'USDC',
          api: api,
          store: MemoryStore(),
          paymentOpener: (_) async =>
              throw StateError('synthetic signing failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topup-network-ethereum')));
    await tester.pumpAndSettle();
    expect(find.text('充值未完成，请核实本地订单'), findsOneWidget);
    expect(find.byType(TopupWebviewPage), findsNothing);
    expect(api.requests, 0);
    for (final network in TopupNetwork.values) {
      final node = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == network.label,
        ),
      );
      expect(node.properties.selected, false);
    }
    api.close();
  });
  testWidgets('窄屏大字体显示两行，点击链直接开始付款', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: TopupSheet(
            accountId: '0x${'04' * 32}',
            token: 'USDT',
            api: FakeApi(),
            store: MemoryStore(),
            paymentOpener: (_) => Completer<TopupRecord?>().future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topup-package-1')));
    await tester.tap(find.byKey(const ValueKey('topup-network-bnb')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('付款结束关闭唯一充值弹窗，返回原账户详情，不打开结果页', (tester) async {
    final api = FakeApi();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('原账户详情')),
            body: TextButton(
              onPressed: () => showTopup(
                context,
                accountId: '0x${'04' * 32}',
                token: 'USDC',
                api: api,
                store: MemoryStore(),
                paymentOpener: (selection) async {
                  opened++;
                  return null;
                },
              ),
              child: const Text('充值入口'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('充值入口'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      greaterThanOrEqualTo(300),
    );
    await tester.tap(find.byKey(const ValueKey('topup-network-ethereum')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('原账户详情'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(TopupDetails), findsNothing);
    expect(api.requests, 0);
    api.close();
  });
}
