import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_wallet/account/wallet_page.dart';

void main() {
  CitizenWalletStateAccount account({
    CitizenWalletSignMode mode = CitizenWalletSignMode.hot,
    int index = 1,
    String name = '我的钱包',
    bool isDefault = false,
  }) {
    final accountId = '0x${index.toRadixString(16).padLeft(64, '0')}';
    return CitizenWalletStateAccount(
      signMode: mode,
      walletIndex: index,
      accountIndex: mode == CitizenWalletSignMode.hot ? index : null,
      accountId: accountId,
      ss58Address: citizenSs58FromAccountId(accountId),
      name: name,
      createdAtMillis: BigInt.zero,
      isDefault: isDefault,
    );
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required CitizenWalletStateAccount wallet,
    bool showActions = true,
    bool isBroken = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WalletListTile(
          wallet: wallet,
          walletName: wallet.name,
          balanceFen: BigInt.from(123456789),
          showActions: showActions,
          isDefault: wallet.isDefault,
          isBroken: isBroken,
          onTap: () {},
          onRename: () {},
          onDelete: () {},
        ),
      ),
    ),
  );

  testWidgets('保留名称、余额、默认文字和冷热配色', (tester) async {
    await pumpTile(
      tester,
      wallet: account(mode: CitizenWalletSignMode.cold, isDefault: true),
    );
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.text('1,234,567.89'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);
    final icon = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_rounded).first,
    );
    expect(icon.color, AppTheme.info);
  });

  testWidgets('操作菜单仍只有重命名和删除钱包', (tester) async {
    await pumpTile(tester, wallet: account());
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除钱包'), findsOneWidget);
    expect(find.text('钱包详情'), findsNothing);
  });

  testWidgets('异常事实仍复用原卡片，按SDK原模式保留配色而不构造正常账户', (tester) async {
    for (final mode in <CitizenWalletSignMode?>[
      CitizenWalletSignMode.hot,
      CitizenWalletSignMode.cold,
      null,
    ]) {
      final diagnostic = CitizenWalletDiagnostic(
        walletIndex: 0,
        walletName: '原异常钱包',
        accountId: account().accountId,
        ss58Address: null,
        diagnosticReason: CitizenWalletDiagnosticReason.invalidStructure,
        signMode: mode,
        cleanupTargets: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletListTile(
              wallet: null,
              diagnostic: diagnostic,
              walletName: diagnostic.walletName,
              balanceFen: BigInt.zero,
              showActions: true,
              isBroken: true,
              onTap: () {},
              onRename: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      expect(find.text('钱包数据异常，请验证热钱包或重新导入冷钱包'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.account_balance_wallet_rounded))
            .color,
        mode == CitizenWalletSignMode.hot
            ? AppTheme.primaryDark
            : AppTheme.info,
      );
    }
  });

  testWidgets('账户码只填表，确认后才写入真实冷钱包目录', (tester) async {
    final core = (await tester.runAsync(
      () => openTestSdk(
        modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
        physicalUi: true,
      ),
    ))!;
    final sdk = core.sdk;
    final accountId = account(mode: CitizenWalletSignMode.cold).accountId;
    final wire = (await tester.runAsync(() => sdk.encodeAccountId(accountId)))!;
    final before = (await tester.runAsync(() => sdk.getWalletState().result))!;
    expect(before.accounts, isEmpty);

    Future<void> waitFor(bool Function() ready) async {
      for (var i = 0; i < 100 && !ready(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(ready(), isTrue);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ImportColdWalletPage(),
                  ),
                ),
                child: const Text('打开导入页'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导入页'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('扫码填入账户'));
    await waitFor(() => core.fixture.nativeResources.isNotEmpty);
    core.fixture.scanText(wire, CitizenQrScanPurpose.coldAccountImport);
    final field = find.byType(TextField);
    await waitFor(() => field.evaluate().isNotEmpty);
    expect(tester.widget<TextField>(field).controller!.text, accountId);
    final filled = (await tester.runAsync(() => sdk.getWalletState().result))!;
    expect(filled.accounts, isEmpty);
    expect(filled.revision, before.revision);

    await tester.tap(find.text('确认导入'));
    final opener = find.text('打开导入页');
    await waitFor(() => opener.evaluate().isNotEmpty);
    expect(opener, findsOneWidget);
    final after = (await tester.runAsync(() => sdk.getWalletState().result))!;
    expect(after.accounts.single.accountId, accountId);
    expect(after.accounts.single.signMode, CitizenWalletSignMode.cold);
    expect(after.revision, before.revision + BigInt.one);
  });
}
