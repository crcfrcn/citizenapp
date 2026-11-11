import 'package:citizen_user/navigation.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;

import 'dart:async';

import 'package:citizen_onchain/onchain_payment_models.dart';
import 'package:citizen_onchain/onchain_payment_service.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_onchain/onchain_payment_page.dart';
import 'package:citizen_personal/personal_account_entry.dart';
import 'package:citizen_wallet/history/local_tx_store.dart';
import 'package:citizen_widgets/chain_progress_banner.dart';

const _walletAAccountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _walletBAccountId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _RecipientService extends OnchainPaymentService {
  _RecipientService(this.recipient);
  final String recipient;
  String? input;
  String? inputCid;
  BigInt? quotedAmountFen;
  int preparations = 0;
  CitizenBlockRef? remarkBlock;

  @override
  Future<int> readRemarkLimit(CitizenBlockRef block) async {
    remarkBlock = block;
    return 3;
  }

  @override
  Future<OnchainRecipient> resolveRecipient({
    required String address,
    String? cidNumber,
  }) async {
    input = address;
    inputCid = cidNumber;
    return OnchainRecipient(address: recipient, cidNumber: cidNumber);
  }

  @override
  Future<CitizenFeeSnapshot> quoteFee(BigInt amountFen) async {
    quotedAmountFen = amountFen;
    return CitizenFeeSnapshot(
      bestBlock: CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.best,
      ),
      feeRateParts: 1000000,
      minimumFeeFen: BigInt.from(17),
      existentialDepositFen: BigInt.from(135),
      voteFeeFen: BigInt.from(100),
      feeFen: BigInt.from(17),
      minimumSelfPayFen: BigInt.from(152),
    );
  }

  @override
  Future<CitizenPreparedTransaction> prepareTransfer(
    OnchainPaymentDraft draft,
  ) async {
    preparations++;
    throw StateError('确认取消后不得准备交易');
  }
}

CitizenWalletStateAccount _wallet({
  required int index,
  required String name,
  required String address,
  required String accountId,
}) {
  return CitizenWalletStateAccount(
    signMode: CitizenWalletSignMode.hot,
    walletIndex: index,
    accountIndex: index,
    name: name,
    ss58Address: address,
    accountId: accountId,
    createdAtMillis: BigInt.from(index),
    isDefault: true,
  );
}

wallet_store.Entry _tx({
  required int eventIndex,
  required String fromAddress,
  required String accountId,
  required String amountDelta,
  required String status,
}) {
  return wallet_store.Entry()
    ..accountId = LocalTxStore.requireAccountId(accountId)
    ..entryKind = 'transfer'
    ..amountDelta = amountDelta
    ..transferAmount = amountDelta.replaceFirst('-', '')
    ..fromAddress = fromAddress
    ..toAddress = 'counterparty'
    ..entryState = status
    ..entrySource = 'test'
    ..createdAt = eventIndex
    ..blockHash = '0x11'
    ..eventIndex = eventIndex;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('0x收款地址进入原确认弹窗，显示原始地址及解析账户，取消不准备交易', (tester) async {
    const address = '0x6D66a0cB155051055F3FB3Cc73d9230D3Fb4D5B5';
    const recipient = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
    final service = _RecipientService(recipient);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          paymentService: service,
          currentWalletLoader: () async => _wallet(
            index: 0,
            name: '测试钱包',
            address: 'wallet_a',
            accountId: _walletAAccountId,
          ),
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (_, {limit = 100}) async => const [],
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
    final banner = tester.widget<ChainProgressBanner>(
      find.byType(ChainProgressBanner),
    );
    final block = CitizenBlockRef(
      hash: _walletAAccountId,
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    banner.onProgressChanged?.call(
      CitizenChainSyncStatus(
        peerCount: BigInt.one,
        isSyncing: false,
        isUsable: true,
        best: block,
        finalized: block,
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == '请输入 公民链SS58地址 或 以太坊0x地址',
      ),
      address,
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '请输入金额',
      ),
      '2.03',
    );
    final submit = find.widgetWithText(FilledButton, '签名交易');
    final remark = find.widgetWithText(TextField, '请输入转账备注（选填）');
    await tester.enterText(remark, '测试');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.text('转账备注不能超过 3 字节，当前 6 字节'));
    expect(find.text('转账备注不能超过 3 字节，当前 6 字节'), findsOneWidget);
    expect(find.text('确认交易'), findsNothing);
    expect(service.remarkBlock?.hash, '0x${'11' * 32}');
    await tester.enterText(remark, '测');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.text('确认交易'));
    expect(service.input, address);
    expect(service.quotedAmountFen, BigInt.from(203));
    expect(find.text('转账金额：2.03 GMB'), findsOneWidget);
    expect(find.text('预估手续费：0.17 GMB'), findsOneWidget);
    expect(find.text('合计：2.20 GMB'), findsOneWidget);
    expect(find.text('以太坊地址：$address'), findsOneWidget);
    expect(find.text('收款账户：$recipient'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(service.preparations, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('联系人只有 CID 也能显示链上解析的收款账户', (tester) async {
    const cid = 'CN220-CTZN2-100000002-2026';
    const recipient = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
    final service = _RecipientService(recipient);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          initialRecipientCid: cid,
          paymentService: service,
          currentWalletLoader: () async => _wallet(
            index: 0,
            name: '测试钱包',
            address: 'wallet_a',
            accountId: _walletAAccountId,
          ),
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (_, {limit = 100}) async => const [],
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
    final block = CitizenBlockRef(
      hash: _walletAAccountId,
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    tester
        .widget<ChainProgressBanner>(find.byType(ChainProgressBanner))
        .onProgressChanged
        ?.call(
          CitizenChainSyncStatus(
            peerCount: BigInt.one,
            isSyncing: false,
            isUsable: true,
            best: block,
            finalized: block,
          ),
        );
    await tester.pump();
    expect(service.inputCid, isNull);
    await tester.enterText(find.widgetWithText(TextField, '请输入金额'), '2.03');
    final submit = find.widgetWithText(FilledButton, '签名交易');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.text('确认交易'));
    expect(service.input, isEmpty);
    expect(service.inputCid, cid);
    expect(find.text('收款账户：$recipient'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('隐藏底层错误行但保留未就绪禁用与同步恢复', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          currentWalletLoader: () async => _wallet(
            index: 0,
            name: '测试钱包',
            address: 'wallet_a',
            accountId: _walletAAccountId,
          ),
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (_, {limit = 100}) async => const [],
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
    FilledButton submit() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '签名交易'));
    final banner = tester.widget<ChainProgressBanner>(
      find.byType(ChainProgressBanner),
    );
    banner.onErrorChanged?.call('capability unavailable: engine_not_running');
    await tester.pump();
    expect(find.textContaining('capability unavailable'), findsNothing);
    expect(submit().onPressed, isNull);
    final block = CitizenBlockRef(
      hash: _walletAAccountId,
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
    banner.onProgressChanged?.call(
      CitizenChainSyncStatus(
        peerCount: BigInt.one,
        isSyncing: false,
        isUsable: true,
        best: block,
        finalized: block,
      ),
    );
    banner.onErrorChanged?.call(null);
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    banner.onProgressChanged?.call(null);
    banner.onErrorChanged?.call('capability unavailable: engine_not_running');
    await tester.pump();
    expect(submit().onPressed, isNull);
    expect(find.textContaining('capability unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('交易页顶栏显示链状态，入口只剩多签账户卡片，扫码收进收款地址框', (tester) async {
    ContactPickMode? openedContactMode;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TransactionTabPage(
          currentWalletLoader: () async => null,
          localRecordsLoader: (_, {limit = 100}) async => const [],
          balanceLoader: (_) async => BigInt.zero,
          contactPageBuilder: (mode) {
            openedContactMode = mode;
            return const Scaffold(body: Text('通讯录测试页'));
          },
        ),
      ),
    );
    await tester.pump();

    // 个人多签账户列表已经迁入交易页入口，机构多签不在这里展示。
    // 链上支付主体字段(收款地址 / 金额 / 签名交易)由 `OnchainPaymentPanel`
    // 在选中钱包后渲染,本测试只校验顶层入口结构。
    expect(find.text('交易'), findsNothing);
    expect(find.byTooltip('我的通讯录'), findsOneWidget);
    expect(find.byTooltip('选择交易钱包'), findsOneWidget);
    expect(find.byType(ChainProgressBanner), findsOneWidget);
    expect(find.text('公民链'), findsOneWidget);
    expect(find.text('最终区块 —'), findsOneWidget);
    final chainLabel = tester.widget<Text>(find.text('公民链'));
    final finalizedLabel = tester.widget<Text>(find.text('最终区块 —'));
    expect(chainLabel.style?.color, AppTheme.info);
    expect(finalizedLabel.style?.color, AppTheme.info);
    expect(find.textContaining('已更新'), findsNothing);
    expect(find.textContaining('更新中'), findsNothing);
    expect(find.textContaining('连接失败'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('transaction-chain-status-inline')),
      findsOneWidget,
    );
    final centerGap = tester.getRect(
      find.byKey(const ValueKey<String>('transaction-chain-status-center-gap')),
    );
    final screenWidth = tester.getSize(find.byType(Scaffold).first).width;
    expect(centerGap.center.dx, closeTo(screenWidth / 2, 0.01));
    // 交易顶栏状态不再使用原卡片中的竖线。
    expect(
      find.byKey(const ValueKey<String>('transaction-chain-status-divider')),
      findsNothing,
    );
    // 顶部入口只剩多签账户一张独立卡片：不再是双入口，故也不再有中间竖线。
    expect(find.byType(PersonalAccountEntryCard), findsOneWidget);
    expect(find.text('多签账户'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PersonalAccountEntryCard),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.account_tree_outlined), findsNothing);
    expect(find.text('个人多签'), findsNothing);
    expect(find.text('机构多签'), findsNothing);

    // 扫一扫入口已撤销，扫码收进收款地址框内；签名请求改由「聊天 → 扫一扫」承接。
    expect(find.text('扫一扫'), findsNothing);
    expect(find.byTooltip('扫码填入收款地址'), findsOneWidget);

    await tester.tap(find.byTooltip('我的通讯录'));
    await _pumpUntilFound(tester, find.text('通讯录测试页'));
    // 交易入口只声明“选择收款人”意图，页面不再接收当前付款钱包账户。
    expect(openedContactMode, ContactPickMode.pickForTransfer);
    const cid = 'CN220-CTZN2-100000002-2026';
    Navigator.of(tester.element(find.text('通讯录测试页'))).pop(cid);
    await _pumpUntilFound(tester, find.text('收款公民号：$cid'));
    expect(find.text('收款公民号：$cid'), findsOneWidget);
  });

  testWidgets('钱包选择、取消与切回均核对真实付款源无障碍值', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final wallets = [
        _wallet(
          index: 1,
          name: '合成A',
          address: 'wallet_a',
          accountId: _walletAAccountId,
        ),
        _wallet(
          index: 2,
          name: '合成B',
          address: 'wallet_b',
          accountId: _walletBAccountId,
        ),
      ];
      var current = wallets.first;
      int? pick = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: OnchainPaymentPanel(
            title: '交易',
            currentWalletLoader: () async => current,
            balanceLoader: (_) async => BigInt.from(10000),
            localRecordsLoader: (_, {limit = 100}) async => [],
            walletPicker: () async {
              if (pick == null) return null;
              current = wallets[pick];
              return PaymentAccountSelection(
                accountId: current.accountId,
                revision: BigInt.one,
              );
            },
          ),
        ),
      );
      await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
      String value() => tester
          .getSemantics(
            find
                .ancestor(
                  of: find.byTooltip('选择交易钱包'),
                  matching: find.byType(MergeSemantics),
                )
                .first,
          )
          .getSemanticsData()
          .value;
      expect(value(), '当前付款账户：#1');
      for (final choice in [1, null, 0]) {
        pick = choice;
        await tester.tap(find.byTooltip('选择交易钱包'));
        await tester.pump();
        await tester.pump();
        expect(value(), '当前付款账户：#${choice == 0 ? 1 : 2}');
      }
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('链上交易状态跟随精确付款账户切换刷新且只统计转出', (tester) async {
    final walletA = _wallet(
      index: 1,
      name: '钱包A',
      address: 'wallet_a',
      accountId: _walletAAccountId,
    );
    final walletB = _wallet(
      index: 2,
      name: '钱包B',
      address: 'wallet_b',
      accountId: _walletBAccountId,
    );
    var currentWallet = walletA;
    final records = [
      _tx(
        eventIndex: 1,
        fromAddress: 'wallet_a',
        accountId: _walletAAccountId,
        amountDelta: '-101',
        status: LocalTxStore.statusPending,
      ),
      _tx(
        eventIndex: 2,
        fromAddress: 'wallet_a',
        accountId: _walletAAccountId,
        amountDelta: '-202',
        status: LocalTxStore.statusInBlock,
      ),
      _tx(
        eventIndex: 3,
        fromAddress: 'wallet_a',
        accountId: _walletAAccountId,
        amountDelta: '-303',
        status: LocalTxStore.statusFinalized,
      ),
      _tx(
        eventIndex: 4,
        fromAddress: 'wallet_a',
        accountId: _walletAAccountId,
        amountDelta: '-404',
        status: LocalTxStore.statusFailed,
      ),
      _tx(
        eventIndex: 5,
        fromAddress: 'wallet_b',
        accountId: _walletBAccountId,
        amountDelta: '404',
        status: LocalTxStore.statusFinalized,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          currentWalletLoader: () async => currentWallet,
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (accountId, {limit = 100}) async {
            final normalizedAccountId = LocalTxStore.requireAccountId(
              accountId,
            );
            return records
                .where((record) => record.accountId == normalizedAccountId)
                .take(limit)
                .toList();
          },
          walletPicker: () async {
            currentWallet = walletB;
            return PaymentAccountSelection(
              accountId: walletB.accountId,
              revision: BigInt.one,
            );
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('待确认 2'));

    expect(find.text('待确认 2'), findsOneWidget);
    expect(find.textContaining('已出块'), findsNothing);
    expect(find.textContaining('已提交'), findsNothing);
    expect(find.text('已确认 1'), findsOneWidget);
    expect(find.text('失败 1'), findsOneWidget);

    await tester.tap(find.byTooltip('选择交易钱包'));
    await _pumpUntilFound(tester, find.text('待确认 0'));

    expect(find.text('待确认 0'), findsOneWidget);
    expect(find.text('已确认 0'), findsOneWidget);
    expect(find.text('失败 0'), findsOneWidget);
  });

  testWidgets('迟到的初始账户读取不能污染已经选定的付款账户和记录', (tester) async {
    final delayed = Completer<CitizenWalletStateAccount?>();
    final accountA = _wallet(
      index: 0,
      name: '合成账户A',
      address: 'a',
      accountId: _walletAAccountId,
    );
    final accountB = _wallet(
      index: 1,
      name: '合成账户B',
      address: 'b',
      accountId: _walletBAccountId,
    );
    var reads = 0;
    final balanceAccounts = <String>[];
    final recordAccounts = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OnchainPaymentPanel(
          title: '交易',
          currentWalletLoader: () {
            reads++;
            return reads == 1 ? delayed.future : Future.value(accountB);
          },
          walletPicker: () async => PaymentAccountSelection(
            accountId: accountB.accountId,
            revision: BigInt.one,
          ),
          balanceLoader: (id) async {
            balanceAccounts.add(id);
            return BigInt.from(10000);
          },
          localRecordsLoader: (id, {limit = 100}) async {
            recordAccounts.add(id);
            return [];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('选择交易钱包'));
    await _pumpUntilFound(tester, find.text('待确认 0'));
    delayed.complete(accountA);
    await tester.pump(const Duration(milliseconds: 100));
    expect(balanceAccounts, isNotEmpty);
    expect(recordAccounts, isNotEmpty);
    expect(balanceAccounts.toSet(), {_walletBAccountId});
    expect(recordAccounts.toSet(), {_walletBAccountId});
  });

  testWidgets('通讯录转账只预填收款地址且不改变付款钱包', (tester) async {
    final payer = _wallet(
      index: 2,
      name: '付款钱包B',
      address: 'wallet_b',
      accountId: _walletBAccountId,
    );
    const recipient = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          initialToAddress: recipient,
          currentWalletLoader: () async => payer,
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (_, {limit = 100}) async => const [],
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));

    final addressField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '请输入 公民链SS58地址 或 以太坊0x地址',
      ),
    );
    expect(addressField.controller?.text, recipient);
    expect(find.textContaining('钱包可用余额：100'), findsOneWidget);
    expect(find.text('GMB'), findsOneWidget);
    final gmbMark = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'packages/citizen_assets/logo/mark256.png',
      ),
    );
    expect(gmbMark.width, 18);
    expect(gmbMark.height, 18);
    expect(gmbMark.color, AppTheme.primary);
    expect(gmbMark.colorBlendMode, BlendMode.srcIn);
    expect(find.text('CNY'), findsNothing);
    expect(find.textContaining('钱包可用余额：100.00 GMB'), findsOneWidget);
  });

  testWidgets('独立链上支付下拉刷新重载数据且保留后台链状态读取', (tester) async {
    var walletLoads = 0;
    var recordLoads = 0;
    final payer = _wallet(
      index: 1,
      name: '付款钱包',
      address: 'wallet_a',
      accountId: _walletAAccountId,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          currentWalletLoader: () async {
            walletLoads++;
            return payer;
          },
          balanceLoader: (_) async => BigInt.from(10000),
          localRecordsLoader: (_, {limit = 100}) async {
            recordLoads++;
            return const [];
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));

    // 独立链上支付页只保留后台状态读取；下拉刷新组件仍就位。
    expect(find.byType(ChainProgressBanner), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('transaction-chain-status-inline')),
      findsNothing,
    );
    expect(find.text('公民链'), findsNothing);
    expect(find.textContaining('最终区块'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    final walletLoadsAfterInit = walletLoads;
    final recordLoadsAfterInit = recordLoads;
    expect(walletLoadsAfterInit, greaterThanOrEqualTo(1));
    expect(recordLoadsAfterInit, greaterThanOrEqualTo(1));

    // 下拉触发刷新：余额（currentWalletLoader）+ 本地记录（localRecordsLoader）重载。
    await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
    for (
      var i = 0;
      i < 40 &&
          (walletLoads <= walletLoadsAfterInit ||
              recordLoads <= recordLoadsAfterInit);
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(walletLoads, greaterThan(walletLoadsAfterInit));
    expect(recordLoads, greaterThan(recordLoadsAfterInit));
  });
}
