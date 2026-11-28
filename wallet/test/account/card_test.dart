// 验证身份卡片与操作卡片。

import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_scanner/display.dart' show AppQrImage;
import 'package:citizen_wallet/account/card.dart' show WalletDetailBody, WalletIdentityCard;
import 'package:citizen_wallet/account/card.dart' show buildWalletAccountQrData;
import 'package:citizen_system/theme.dart';
import 'package:citizen_testing/sdk.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_wallet/account/card.dart' show WalletActionCard, WalletActionCardState;
import 'package:citizen_wallet/view.dart' show WalletNavigation;
import 'package:citizen_offchain/bank.dart' show ClearingBankBinding, ClearingBankDirectory, ClearingBankNodeEndpoint;
import 'package:citizen_offchain/bank.dart' show ClearingBankBindingSnapshot, ClearingBankPrefs;
import 'package:citizen_offchain/rpc.dart' show ClearingBalances;
import 'package:citizen_offchain/balance.dart' show WithdrawPage;
import 'package:citizen_storage/user.dart';
import 'package:citizen_testing/database.dart';

void main() {
  group('wallet_identity_card_test', suite26);
  group('wallet_action_card_test', suite27);
}

// 验证双地址复制、映射确认、身份布局和固定账户码。

/// 几何和交互断言取自be75a90b原件；仅账户模型与QR底层改用现有SDK。
void suite26() {
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

// 验证双币及零钱包布局、准确账户和共享防重复门禁。

/// 验证双币入口、精确账户、共有余额及原零钱包绑定门禁，不调用真实付款。
void suite27() {
  useIsolatedIsar();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const accountId =
      '0x0404040404040404040404040404040404040404040404040404040404040404';
  const address = '5DummyAddress';
  final opened = <String>[];
  final openedPetty = <String>[];
  Completer<bool?>? waiting;
  Future<void> pumpCard(
    WidgetTester tester, {
    _BankDirectory? directory,
  }) async {
    opened.clear();
    openedPetty.clear();
    final navigation = WalletNavigation(
      history: ({required accountAddress, required accountId}) =>
          const SizedBox.shrink(),
      topup: (context, {required accountId, required token}) async {
        opened.add('$accountId:$token');
        return waiting == null ? false : await waiting!.future;
      },
      pettyWallet: ({required accountId}) {
        openedPetty.add(accountId);
        return const Scaffold(body: Text('测试零钱包'));
      },
      identity: () => const SizedBox.shrink(),
      recordDetail: ({required record}) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: navigation),
          Provider<ClearingBankDirectory>.value(
            value: directory ?? _BankDirectory(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [WalletActionCard(accountId: accountId)]),
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
  testWidgets('充值返回释放入口，下一次仍准确使用发起账户', (tester) async {
    waiting = Completer<bool?>();
    await pumpCard(tester);
    await tester.tap(find.text('充值/USDC'));
    waiting!.complete(true);
    await tester.pumpAndSettle();
    expect(opened, ['$accountId:USDC']);
    waiting = null;
    await tester.tap(find.text('充值/USDC'));
    await tester.pumpAndSettle();
    expect(opened, ['$accountId:USDC', '$accountId:USDC']);
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

  testWidgets('绑定读取失败保持待核对，不冒充未绑定或放行', (tester) async {
    final directory = _BankDirectory()..fail = true;
    await pumpCard(tester, directory: directory);
    expect(find.text('绑定待核对'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.text('无法核对当前清算行，请重试'), findsOneWidget);
    expect(openedPetty, isEmpty);
  });

  testWidgets('无快照或快照旧端点时仍只用当前链上 WSS 并打开同账户', (tester) async {
    const binding = ClearingBankBindingSnapshot(
      cidNumber: 'test-bank',
      fullName: '测试清算行',
      shortName: '',
      mainAccountId: accountId,
      feeAccountId: accountId,
      peerId: 'test-peer',
      rpcDomain: 'clearing.example',
      rpcPort: 443,
      boundAtMs: 1,
      lastVerifiedAtMs: 1,
    );
    final directory = _BankDirectory()
      ..binding = (
        endpoint: const ClearingBankNodeEndpoint(
          cidNumber: 'test-bank',
          peerId: 'test-peer',
          rpcDomain: 'current.example',
          rpcPort: 443,
          registeredAt: 1,
          registeredBy: '',
        ),
        title: '测试清算行',
      );
    final current = directory.binding!.endpoint.wssUrl;
    await tester.runAsync(() async {
      await UserIsar.instance.writeClearingBalance(
        accountId,
        current,
        BigInt.from(425),
      );
      await UserIsar.instance.writeClearingBalance(
        accountId,
        binding.wssUrl,
        BigInt.from(900),
      );
      await ClearingBalances.instance
          .state(accountId: accountId, wssUrl: current)
          .load();
    });
    addTearDown(ClearingBalances.instance.invalidateAll);
    await pumpCard(tester, directory: directory);
    expect(find.text('4.25 元'), findsOneWidget);
    await tester.runAsync(
      () => ClearingBankPrefs.saveSnapshot(accountId, binding),
    );
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(openedPetty, [accountId]);
    expect(find.text('测试零钱包'), findsOneWidget);
    expect(directory.accounts, everyElement(accountId));
    expect(directory.accounts.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('提现前核对到新端点时切换余额并要求重新确认', (tester) async {
    const old = ClearingBankNodeEndpoint(
      cidNumber: 'test-bank',
      peerId: 'peer',
      rpcDomain: 'old.example',
      rpcPort: 9944,
      registeredAt: 1,
      registeredBy: '',
    );
    const current = ClearingBankNodeEndpoint(
      cidNumber: 'test-bank',
      peerId: 'peer',
      rpcDomain: 'current.example',
      rpcPort: 9944,
      registeredAt: 2,
      registeredBy: '',
    );
    final directory = _BankDirectory()
      ..binding = (endpoint: current, title: '测试清算行');
    await tester.runAsync(() async {
      for (final (node, cents) in [(old, 900), (current, 425)]) {
        await UserIsar.instance.writeClearingBalance(
          accountId,
          node.wssUrl,
          BigInt.from(cents),
        );
        await ClearingBalances.instance
            .state(accountId: accountId, wssUrl: node.wssUrl)
            .load();
      }
    });
    addTearDown(ClearingBalances.instance.invalidateAll);
    await tester.pumpWidget(
      MaterialApp(
        home: WithdrawPage(
          accountId: accountId,
          directory: directory,
          bank: (endpoint: old, title: '测试清算行'),
        ),
      ),
    );
    expect(find.textContaining('¥9.00'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1.00');
    await tester.tap(find.text('确认提现'));
    await tester.pumpAndSettle();
    expect(directory.accounts, [accountId]);
    expect(find.text('清算行已变化，请重新确认'), findsOneWidget);
    expect(find.textContaining('¥9.00'), findsNothing);
    expect(find.textContaining('¥4.25'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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
          onRefresh: () async {},
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
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
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

class _BankDirectory extends ClearingBankDirectory {
  final accounts = <String>[];
  ClearingBankBinding? binding;
  bool fail = false;

  @override
  Future<ClearingBankBinding?> fetchUserBank(String accountId) async {
    accounts.add(accountId);
    if (fail) throw StateError('链读取失败');
    return binding;
  }
}
