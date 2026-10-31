import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_wallet/wallet_action_card.dart';
import 'package:citizen_wallet/navigation.dart';

/// 验证双币入口、精确账户、共有余额及原零钱包绑定门禁，不调用真实付款。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const accountId =
      '0x0404040404040404040404040404040404040404040404040404040404040404';
  const address = '5DummyAddress';
  final opened = <String>[];
  Completer<bool?>? waiting;
  var balanceReads = 0;
  Future<void> pumpCard(WidgetTester tester, {bool outer = false}) async {
    opened.clear();
    balanceReads = 0;
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
                  hasOuterCard: outer,
                  finalizedBalanceLoader: (_) async {
                    balanceReads++;
                    return 1280.35;
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

  testWidgets('复用USDT/USDC圆形SVG，两个入口为充值且零钱包保持原图标', (tester) async {
    await pumpCard(tester);
    expect(find.text('充值/USDT'), findsOneWidget);
    expect(find.text('充值/USDC'), findsOneWidget);
    expect(find.text('提现'), findsNothing);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
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
    final before = balanceReads;
    await tester.tap(find.text('充值/USDC'));
    waiting!.complete(true);
    await tester.pumpAndSettle();
    expect(balanceReads, before + 1);
    expect(opened, ['$accountId:USDC']);
    waiting = null;
  });
  testWidgets('金额跨两列居中，短竖线56且零钱包竖线仍88', (tester) async {
    await pumpCard(tester, outer: true);
    final first = tester.getCenter(find.text('充值/USDT'));
    final second = tester.getCenter(find.text('充值/USDC'));
    final balance = tester.getCenter(
      find.byKey(const ValueKey('wallet-onchain-balance')),
    );
    expect(find.text('1,280.35 元'), findsOneWidget);
    expect(balance.dx, closeTo((first.dx + second.dx) / 2, .1));
    expect(balance.dy, greaterThan(first.dy));
    final pettyCenter = tester.getCenter(
      find.byIcon(Icons.account_balance_wallet_outlined),
    );
    final dividerCenter = tester.getCenter(
      find.byKey(const ValueKey('wallet-petty-divider')),
    );
    expect(second.dx - first.dx, closeTo(pettyCenter.dx - second.dx, .1));
    expect(dividerCenter.dx, closeTo((second.dx + pettyCenter.dx) / 2, .1));
    final shortHeight = tester
        .getSize(find.byKey(const ValueKey('wallet-topup-divider')))
        .height;
    final longHeight = tester
        .getSize(find.byKey(const ValueKey('wallet-petty-divider')))
        .height;
    final iconHeight = tester.getSize(find.byType(SvgPicture).first).height;
    expect(shortHeight, closeTo(longHeight * 56 / 88, .1));
    expect(longHeight, closeTo(iconHeight * 88 / 48, .1));
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('wallet-action-card')),
    );
    expect(cardRect.height, closeTo(iconHeight * 136 / 48, .1));
    expect(dividerCenter.dy, closeTo(cardRect.top + iconHeight * 68 / 48, .1));
  });
  testWidgets('热账户已有外框时不重复画操作卡底边', (tester) async {
    await pumpCard(tester, outer: true);
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('wallet-action-card')),
    );
    expect((card.decoration! as BoxDecoration).border, isNull);
  });
  testWidgets('零钱包未绑定仍显示原状态并提示绑定', (tester) async {
    await pumpCard(tester);
    expect(find.text('未绑定'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.text('请先在“清算行”页面绑定清算行'), findsOneWidget);
    expect(opened, isEmpty);
  });
}
