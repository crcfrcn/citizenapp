// 验证双地址复制、映射确认、身份布局和固定账户码。

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/qr_display_scaffold.dart' show AppQrImage;
import 'package:citizen_wallet/account/wallet_identity_card.dart';
import 'package:citizen_wallet/account/wallet_qr_dialog.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

/// 几何和交互断言取自be75a90b原件；仅账户模型与QR底层改用现有SDK。
void main() {
  final core = TestCitizenSdkHarness();
  late CitizenSdk sdk;
  setUp(() => sdk = core.sdk);
  final wallet = CitizenWalletStateAccount(
    signMode: CitizenWalletSignMode.hot,
    walletIndex: 0,
    accountIndex: 0,
    name: '账户名称与钱包名不同',
    ss58Address: 'w5FSaGABE2SVAogLtyW4ZSuVnXQRURpNyyrRtTcQKSui6EH6m',
    accountId:
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    createdAtMillis: BigInt.zero,
    isDefault: true,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    String name = '我的钱包',
    TargetPlatform platform = TargetPlatform.android,
    Future<String> Function(String)? evmAddressLoader,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = platform == TargetPlatform.iOS
        ? const Size(402, 874)
        : const Size(411, 914);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => Theme(
            data: AppTheme.lightThemeFor(context).copyWith(platform: platform),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 411,
                child: WalletIdentityCard(
                  wallet: wallet,
                  name: name,
                  evmAddressLoader:
                      evmAddressLoader ??
                      (accountId) async =>
                          citizenEvmAddressFromAccountId(accountId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('一个复制按钮打开双地址弹窗，并复制所选公民链地址', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-identity-copy-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('wallet-address-copy-dialog')),
      findsOneWidget,
    );
    expect(find.text(wallet.ss58Address), findsOneWidget);
    expect(
      find.text(citizenEvmAddressFromAccountId(wallet.accountId)),
      findsOneWidget,
    );
    expect(copied, isNull);
    await tester.tap(find.byKey(const ValueKey('wallet-copy-ss58-button')));
    await tester.pumpAndSettle();
    expect(copied, wallet.ss58Address);
    expect(
      find.byKey(const ValueKey('wallet-address-copy-dialog')),
      findsNothing,
    );
  });

  testWidgets('以太坊地址只在确认映射后可复制，等待时仍可复制公民链地址', (tester) async {
    final confirmation = Completer<String>();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester, evmAddressLoader: (_) => confirmation.future);
    await tester.tap(find.byKey(const ValueKey('wallet-identity-copy-button')));
    await tester.pumpAndSettle();
    final ethereum = citizenEvmAddressFromAccountId(wallet.accountId);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('wallet-copy-evm-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('wallet-copy-ss58-button')),
          )
          .onPressed,
      isNotNull,
    );
    confirmation.complete(ethereum);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-copy-evm-button')));
    await tester.pumpAndSettle();
    expect(copied, ethereum);
  });

  testWidgets('映射查询失败或返回其他地址均不可复制以太坊地址', (tester) async {
    for (final fails in [true, false]) {
      await pumpCard(
        tester,
        evmAddressLoader: (_) async {
          if (fails) throw StateError('read failed');
          return '0x1111111111111111111111111111111111111111';
        },
      );
      await tester.tap(
        find.byKey(const ValueKey('wallet-identity-copy-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('以太坊地址尚未确认，请稍后重试'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('wallet-copy-evm-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('renders wallet name and full address', (tester) async {
    await pumpCard(tester);
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.textContaining('...'), findsNothing);
    final firstLine = tester.widget<Text>(
      find.byKey(const ValueKey('wallet-identity-address-line-1')),
    );
    final secondLine = tester.widget<Text>(
      find.byKey(const ValueKey('wallet-identity-address-line-2')),
    );
    expect('${firstLine.data}${secondLine.data}', wallet.ss58Address);
    expect(secondLine.data, isNotEmpty);
    // 测试字体下第一行可容纳 20 个字符；锁定“排满第一行后再换行”，
    // 防止恢复为优先塞满第二行而导致第一行过短的旧拆分逻辑。
    expect(firstLine.data, wallet.ss58Address.substring(0, 20));
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);
  });

  testWidgets('方案 2 身份区高度和二维码竖分隔线固定', (tester) async {
    final platformHeights = <TargetPlatform, double>{};
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      await pumpCard(tester, platform: platform);
      platformHeights[platform] = tester
          .getSize(find.byKey(const ValueKey('wallet-identity-section')))
          .height;
    }

    expect(platformHeights[TargetPlatform.android], 112);
    expect(
      platformHeights[TargetPlatform.iOS],
      closeTo(112 * AppLayout.visualScaleForSize(const Size(402, 874)), 0.001),
    );

    // 后续精确几何断言都在 411×914 设计基准视口下量取。
    await pumpCard(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('wallet-identity-qr-divider'))),
      const Size(1, 48),
    );
    final copyButtonRect = tester.getRect(
      find.byKey(const ValueKey('wallet-identity-copy-button')),
    );
    final dividerRect = tester.getRect(
      find.byKey(const ValueKey('wallet-identity-qr-divider')),
    );
    final qrButtonRect = tester.getRect(
      find.byKey(const ValueKey('wallet-identity-qr-button')),
    );
    expect(dividerRect.left - copyButtonRect.right, 21.25);
    expect(qrButtonRect.left - dividerRect.right, 16);
    // 复制图标保持原 copy_outlined 原子与 12 尺寸；21.25 的按钮外间距是
    // Pixel 8a 真机可见图形边缘校准值，不用按钮盒理论留白代替视觉量取。

    final copyIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('wallet-identity-copy-icon')),
    );
    expect(copyIcon.icon, Icons.copy_outlined);
    expect(copyIcon.size, 12);
    final copyIconRect = tester.getRect(
      find.byKey(const ValueKey('wallet-identity-copy-icon')),
    );
    expect(copyIconRect.center.dy - copyButtonRect.center.dy, 4);
    final qrMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('wallet-identity-qr-button')),
    );
    expect(qrMaterial.color, Colors.transparent);

    final nameRect = tester.getRect(find.text('我的钱包'));
    final firstLineRect = tester.getRect(
      find.byKey(const ValueKey('wallet-identity-address-line-1')),
    );
    expect(copyIconRect.center.dy, greaterThan(firstLineRect.center.dy));
    expect(copyButtonRect.center.dy, isNot(closeTo(nameRect.center.dy, 1)));
  });

  testWidgets('冷热钱包账户码弹窗严格使用居中地址和左右对称文字按钮', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byKey(const ValueKey('wallet-identity-qr-button')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('我的钱包'), findsWidgets);
    expect(find.text('账户地址'), findsNothing);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-account-qr')), findsOneWidget);
    expect(find.byType(AppQrImage), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);

    final address = tester.widget<SelectableText>(
      find.byKey(const ValueKey('wallet-account-address')),
    );
    expect(address.textAlign, TextAlign.center);

    final dialogRect = tester.getRect(find.byType(Dialog));
    final closeRect = tester.getRect(find.widgetWithText(TextButton, '关闭'));
    final copyRect = tester.getRect(find.widgetWithText(TextButton, '复制'));
    expect(closeRect.size, copyRect.size);
    expect(
      dialogRect.center.dx - closeRect.center.dx,
      closeTo(copyRect.center.dx - dialogRect.center.dx, 0.01),
    );

    await tester.tap(find.widgetWithText(TextButton, '复制'));
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  test('二维码载荷固定为k5且不携带本机名称和SS58', () async {
    final raw = await buildWalletAccountQrData(sdk, wallet.accountId);
    final parsed = await sdk.parseForPurpose(
      raw,
      CitizenQrScanPurpose.coldAccountImport,
    );
    expect(parsed.document.kind, CitizenQrKind.accountId);
    expect(parsed.document.requestId, isNull);
    expect(parsed.document.expiresAt, isNull);
    expect(parsed.accountId, wallet.accountId);
    expect(raw, isNot(contains('我的钱包')));
    expect(raw, isNot(contains('ss58_address')));
  });

  testWidgets('详情名称只读，点击不会显示输入框或编辑铅笔', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('我的钱包'));
    await tester.pump();
    expect(find.text('我的钱包'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('列表改名后的新名称可由外部刷新展示，详情仍不可编辑', (tester) async {
    await pumpCard(tester);
    await pumpCard(tester, name: '新钱包名称');
    expect(find.text('我的钱包'), findsNothing);
    expect(find.text('新钱包名称'), findsOneWidget);
    await tester.tap(find.text('新钱包名称'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
