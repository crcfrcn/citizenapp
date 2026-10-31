import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:citizen_system/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_wallet/wallet_action_card.dart';
import 'package:citizen_wallet/navigation.dart';
import 'package:citizen_wallet/wallet_identity_card.dart';
import 'package:citizen_wallet/wallet_onchain_balance_card.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

/// 验证双币入口、精确账户、共有余额及原零钱包绑定门禁，不调用真实付款。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const accountId =
      '0x0404040404040404040404040404040404040404040404040404040404040404';
  const address = '5DummyAddress';
  final opened = <String>[];
  Completer<bool?>? waiting;
  var paidRefreshes = 0;
  Future<void> pumpCard(WidgetTester tester) async {
    opened.clear();
    paidRefreshes = 0;
    final navigation = WalletNavigation(
      history: ({required accountAddress, required accountId}) =>
          const SizedBox.shrink(),
      topup: (context, {required accountId, required token}) async {
        opened.add('$accountId:$token');
        return waiting == null ? false : await waiting!.future;
      },
      pettyWallet: ({
        required accountId,
        required accountAddress,
        required wssUrl,
        required displayTitle,
      }) => const SizedBox.shrink(),
      identity: () => const SizedBox.shrink(),
      recordDetail: ({required record}) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: navigation,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                WalletActionCard(
                  accountId: accountId,
                  accountAddress: address,
                  onTopupPaid: () async {
                    paidRefreshes++;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('三个入口统一圆形图标，零钱包为实色圆底白图形', (tester) async {
    await pumpCard(tester);
    expect(find.text('充值/USDT'), findsOneWidget);
    expect(find.text('充值/USDC'), findsOneWidget);
    expect(find.text('提现'), findsNothing);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    final icon = tester.widget<Container>(
      find.byKey(const ValueKey('wallet-petty-icon')),
    );
    expect((icon.decoration! as BoxDecoration).shape, BoxShape.circle);
    expect((icon.decoration! as BoxDecoration).color, AppTheme.primary);
    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.account_balance_wallet_outlined))
          .color,
      Colors.white,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('wallet-petty-icon'))),
      tester.getSize(find.byType(SvgPicture).first),
    );
  });
  for (final token in ['USDT', 'USDC']) {
    testWidgets('$token充值不要求清算行绑定且传递准确目标账户', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('充值/$token'));
      await tester.pumpAndSettle();
      expect(opened, ['$accountId:$token']);
      expect(find.textContaining('请先'), findsNothing);
    });
  }
  testWidgets('两个入口共享进行中门禁，不同时开启两次充值', (tester) async {
    waiting = Completer<bool?>();
    await pumpCard(tester);
    await tester.tap(find.text('充值/USDT'));
    await tester.tap(find.text('充值/USDC'));
    expect(opened, ['$accountId:USDT']);
    waiting!.complete(false);
    await tester.pumpAndSettle();
    waiting = null;
  });
  testWidgets('到账后只刷新发起充值账户的链上余额', (tester) async {
    waiting = Completer<bool?>();
    await pumpCard(tester);
    final before = paidRefreshes;
    await tester.tap(find.text('充值/USDC'));
    waiting!.complete(true);
    await tester.pumpAndSettle();
    expect(paidRefreshes, before + 1);
    expect(opened, ['$accountId:USDC']);
    waiting = null;
  });
  testWidgets('充值区无重复链上金额，三图标与两条40短线居中', (tester) async {
    await pumpCard(tester);
    final first = tester.getCenter(find.byType(SvgPicture).first);
    final second = tester.getCenter(find.byType(SvgPicture).last);
    final petty = tester.getCenter(
      find.byKey(const ValueKey('wallet-petty-icon')),
    );
    final short = find.byKey(const ValueKey('wallet-topup-divider'));
    final long = find.byKey(const ValueKey('wallet-petty-divider'));
    expect(find.byKey(const ValueKey('wallet-onchain-balance')), findsNothing);
    expect(find.text('1,280.35 元'), findsNothing);
    expect(first.dy, closeTo(second.dy, .1));
    expect(second.dy, closeTo(petty.dy, .1));
    expect(tester.getCenter(short).dy, closeTo(first.dy, .1));
    expect(tester.getCenter(long).dy, closeTo(petty.dy, .1));
    expect(
      tester.getSize(short).height,
      closeTo(tester.getSize(long).height, .1),
    );
    final iconHeight = tester.getSize(find.byType(SvgPicture).first).height;
    expect(tester.getSize(short).height, closeTo(iconHeight * 40 / 48, .1));
    expect(tester.getSize(short).height, lessThan(iconHeight));
    expect(tester.getCenter(long).dx, closeTo((second.dx + petty.dx) / 2, .1));
    expect(second.dx - first.dx, closeTo(petty.dx - second.dx, .1));
  });
  testWidgets('零钱包未绑定仍显示原状态并提示绑定', (tester) async {
    await pumpCard(tester);
    expect(find.text('未绑定'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.text('请先在“清算行”页面绑定清算行'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('统一详情仅顶部显示链上余额，交易记录四角完整', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final account = CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: 0,
      accountId: accountId,
      ss58Address: address,
      name: '测试账户',
      createdAtMillis: BigInt.zero,
      isDefault: true,
    );
    Future<({List<int> pixels, int width, int height})> pixels() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final value = (
          pixels: data!.buffer.asUint8List() as List<int>,
          width: image.width,
          height: image.height,
        );
        image.dispose();
        return value;
      }))!;
    }

    Widget host(Widget body) => RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: body),
      ),
    );
    await tester.pumpWidget(
      host(
        WalletDetailBody(
          account: account,
          name: account.name,
          onNameChanged: (_) async {},
          onRefresh: () async {},
          balanceKey: GlobalKey<WalletOnchainBalanceCardState>(),
          actionKey: GlobalKey<WalletActionCardState>(),
          records: const [],
          balanceLoader: (id) async => CitizenAccountBalance(
            accountId: id,
            block: CitizenBlockRef(
              hash: '0x${'11' * 32}',
              number: BigInt.one,
              finality: CitizenBlockFinality.finalized,
            ),
            freeFen: BigInt.from(128035),
            reservedFen: BigInt.zero,
            totalFen: BigInt.from(128035),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1,280.35'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-onchain-balance')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final rect = tester.getRect(
      find.byKey(const ValueKey('wallet-recent-records-card')),
    );
    final actual = await pixels();
    await tester.pumpWidget(
      host(
        Stack(
          children: [
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expected = await pixels();
    var differences = 0;
    for (var x = 1; x < 12; x++) {
      for (var y = 1; y < 12; y++) {
        for (final p in [
          (rect.left.round() + x, rect.top.round() + y),
          (rect.right.round() - 1 - x, rect.top.round() + y),
          (rect.left.round() + x, rect.bottom.round() - 1 - y),
          (rect.right.round() - 1 - x, rect.bottom.round() - 1 - y),
        ]) {
          final index = (p.$2 * actual.width + p.$1) * 4;
          if (List.generate(
            4,
            (c) =>
                (actual.pixels[index + c] - expected.pixels[index + c]).abs(),
          ).any((d) => d > 2)) {
            differences++;
          }
        }
      }
    }
    expect(differences, 0, reason: '共用交易记录卡四角边框完整');
  });
}
