// 验证充值弹窗交互和失败处理。

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_topup/web.dart';
import 'package:citizen_topup/page.dart';
import 'package:citizen_topup/api.dart';
import 'package:citizen_topup/data.dart';
import 'package:citizen_topup/store.dart';

// 验证充值表单、宿主预备、金额换算及键盘和图标布局。

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
    final session = TopupWalletSession(),
        api = FakeApi(),
        store = MemoryStore();
    var preparations = 0;
    session.addListener(() => preparations++);
    Widget app() => ChangeNotifierProvider<TopupWalletSession>.value(
      value: session,
      child: MaterialApp(
        home: Scaffold(
          body: TopupSheet(
            accountId: '0x${'04' * 32}',
            token: 'USDT',
            api: api,
            store: store,
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    expect(session.started, true);
    expect(preparations, 1);
    expect(api.requests, 0);
    expect(find.byType(TopupWebviewPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    expect(preparations, 1);
    expect(api.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    session.close();
    session.dispose();
  });
  testWidgets('App付款宿主只请求创建一次，关闭会唤醒等待者且不访问充值接口', (tester) async {
    final session = TopupWalletSession(),
        api = FakeApi(),
        store = MemoryStore();
    var starts = 0;
    session.addListener(() => starts++);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final selection = TopupSelection(
      token: 'USDT',
      package: TopupConfig.local().packageById('pkg_10'),
      network: TopupNetwork.ethereum,
    );
    final record = TopupRecord.signed(
      TopupDraft.create(selection, '0x${'04' * 32}'),
      TopupWallet.id,
      '0x${'01' * 64}',
      now: 1000000,
    );
    final first = session.pay(record, store);
    final second = session.pay(record, store);
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

  testWidgets('初始空输入、三处文案与中文图标；无效金额不建单，合法金额实时换算', (tester) async {
    final api = FakeApi(), store = MemoryStore();
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TopupSheet(
          accountId: '0x${'04' * 32}',
          token: 'USDT',
          api: api,
          store: store,
          paymentOpener: (_) async {
            opened++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('充值1美元获得1000元公民币。'), findsNothing);
    expect(find.text('充值1美元获得1000元公民币，充值仅限1000的整数倍。'), findsOneWidget);
    expect(find.text('请输入充值金额'), findsOneWidget);
    expect(find.text('0.00USDT'), findsOneWidget);
    final field = find.byKey(const ValueKey('topup-amount'));
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.byType(ChoiceChip), findsNothing);
    for (final network in TopupNetwork.values) {
      expect(find.text(network.label.split('/').last), findsOneWidget);
      expect(find.text(network.label.split('/').first), findsNothing);
    }
    final circles = tester.widgetList<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(circles.length, 3);
    for (final circle in circles) {
      expect(circle.constraints!.maxWidth, 39);
      expect(circle.constraints!.maxHeight, 39);
    }
    final svgs = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(svgs.map((v) => v.width), containsAll([24.0, 25.0, 25.0, 17.0]));
    final handle = find.byKey(const ValueKey('topup-handle'));
    expect(
      tester.getTopLeft(handle).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('topup-metamask-logo'))).dy,
      ),
    );
    for (final bad in [
      '',
      '0',
      '999',
      '1100',
      '1500',
      '1000.01',
      '-1000',
      '1e3',
      '184467440737096000',
    ]) {
      await tester.enterText(field, bad);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('topup-network-ethereum')));
      await tester.pump();
      expect(find.text('0.00USDT'), findsOneWidget);
      expect(opened, 0);
    }
    for (final amount in [1000, 2000, 10000]) {
      await tester.enterText(field, '$amount');
      await tester.pump();
      expect(find.text('${amount ~/ 1000}.00USDT'), findsOneWidget);
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '10000.00');
    expect(api.requests, 0);
    expect(store.values, isEmpty);
    api.close();
  });
  testWidgets('两行标题对齐控件中心，小字右移一字，两币种付款量分别显示', (tester) async {
    for (final scale in [1.0, 1.4]) {
      for (final token in ['USDT', 'USDC']) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(480, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: TopupSheet(
                accountId: '0x${'04' * 32}',
                token: token,
                paymentOpener: (_) async => null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('topup-amount'));
        expect(
          tester.getCenter(find.text('充值金额')).dy,
          closeTo(tester.getCenter(field).dy, 0.01),
        );
        for (final network in TopupNetwork.values) {
          final tile = find.byKey(ValueKey('topup-network-${network.wire}'));
          final circle = find.descendant(
            of: tile,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.circle,
            ),
          );
          final group = tester
              .getRect(circle)
              .expandToInclude(
                tester.getRect(find.text(network.label.split('/').last)),
              );
          expect(
            tester.getCenter(find.text('支付网络')).dy,
            closeTo(group.center.dy, 0.01),
          );
        }
        expect(
          tester.getTopLeft(find.text('充值1美元获得1000元公民币，充值仅限1000的整数倍。')).dx -
              tester.getTopLeft(field).dx,
          closeTo(12 * scale, 0.01),
        );
        expect(find.text('0.00$token'), findsOneWidget);
        for (final amount in [1000, 2000, 10000]) {
          await tester.enterText(field, '$amount');
          await tester.pump();
          expect(find.text('${amount ~/ 1000}.00$token'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('真实底部弹窗随键盘避让，输入框不被遮挡', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTopup(
                context,
                accountId: '0x${'04' * 32}',
                token: 'USDC',
                paymentOpener: (_) async => null,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('topup-amount'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(field).bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 250,
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('三网络两币种两个输入金额共12种链点击，直接开始且连点只交付一次', (tester) async {
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
          await tester.enterText(
            find.byKey(const ValueKey('topup-amount')),
            package == 0 ? '1000' : '2000',
          );
          await tester.pump();
          final icon = find.byKey(ValueKey('topup-network-${network.wire}'));
          await tester.tap(icon);
          await tester.pump();
          await tester.tap(icon);
          expect(opened.length, 1);
          expect(opened.single.toJson(), {
            'token': token,
            'package_id': package == 0 ? 'pkg_1' : 'pkg_2',
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
    await tester.enterText(find.byKey(const ValueKey('topup-amount')), '1000');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('topup-network-ethereum')));
    await tester.pumpAndSettle();
    expect(find.text('充值未完成，请核实本地订单'), findsOneWidget);
    expect(find.byType(TopupWebviewPage), findsNothing);
    expect(api.requests, 0);
    for (final network in TopupNetwork.values) {
      final node = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == network.label.split('/').last,
        ),
      );
      expect(node.properties.selected, false);
    }
    api.close();
  });
  testWidgets('窄屏大字体和键盘下可滚动输入，点击链直接开始付款', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            viewInsets: EdgeInsets.only(bottom: 240),
            textScaler: TextScaler.linear(1.4),
          ),
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
    await tester.enterText(
      find.byKey(const ValueKey('topup-amount')),
      '1000000',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('topup-network-bnb')));
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
    await tester.enterText(find.byKey(const ValueKey('topup-amount')), '1000');
    await tester.pump();
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
