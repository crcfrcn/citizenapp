import 'package:citizen_user/navigation.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;

import 'dart:async';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_wallet/history/wallet_transaction_history_service.dart';

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
import 'package:citizen_scanner/address_scan_button.dart';

const _walletAAccountId =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _walletBAccountId =
    '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _RecipientService extends OnchainPaymentService {
  _RecipientService(this.recipient, {this.onResolve, this.FLAT_FEE = 100});
  // ignore: non_constant_identifier_names
  final int FLAT_FEE;
  final String recipient;
  final Future<OnchainRecipient> Function(String?)? onResolve;
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
    if (onResolve != null) return onResolve!(cidNumber);
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
      FLAT_FEE: BigInt.from(FLAT_FEE),
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

CitizenPreparedTransaction _feedbackPrepared() => CitizenPreparedTransaction(
  preparationId: 'feedback-prepared',
  sourceAccountId: citizenAccountIdBytes(_walletAAccountId),
  callDataHash: Uint8List.fromList(List.filled(32, 0x22)),
  bestBlock: CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.best,
  ),
  runtimeSpecNumber: 1,
  transactionFormatNumber: 4,
  nonce: BigInt.zero,
);

CitizenTransactionHistoryRecord _feedbackRecord(
  CitizenTransactionHistoryStatus status, {
  String executionId = 'feedback-prepared',
}) {
  final finalized =
      status == CitizenTransactionHistoryStatus.finalizedSuccess ||
      status == CitizenTransactionHistoryStatus.finalizedFailed;
  final block = CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: finalized
        ? CitizenBlockFinality.finalized
        : CitizenBlockFinality.best,
  );
  return CitizenTransactionHistoryRecord(
    executionId: executionId,
    sourceAccountId: _walletAAccountId,
    callDataHash: '0x${'22' * 32}',
    transactionHash: '0x${'33' * 32}',
    status: status,
    block: block,
    execution: finalized
        ? CitizenExecution(
            status: status == CitizenTransactionHistoryStatus.finalizedSuccess
                ? CitizenExecutionStatus.success
                : CitizenExecutionStatus.failed,
            block: block,
            extrinsicIndex: 0,
            dispatchVariant: null,
            palletIndex: null,
            errorIndex: null,
          )
        : null,
    replacementHash: null,
    createdAtMillis: BigInt.one,
    updatedAtMillis: BigInt.two,
    poolRejectionReason: status == CitizenTransactionHistoryStatus.poolRejected
        ? 'invalid'
        : null,
  );
}

class _FeedbackService extends _RecipientService {
  _FeedbackService(super.recipient);
  bool failPreparation = false;
  @override
  Future<CitizenPreparedTransaction> prepareTransfer(
    OnchainPaymentDraft draft,
  ) async {
    preparations++;
    if (failPreparation)
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.unavailable,
        message: 'preparation unavailable',
      );
    // 不注册原生准备，SDK会拒绝执行；此夹具不会签名或广播真实交易。
    return _feedbackPrepared();
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
  useIsolatedIsar();

  test('执行网络异常按本次SDK终态反馈，未知状态不假报成功或失败', () {
    for (final (status, prefix, success) in [
      (CitizenTransactionHistoryStatus.finalizedSuccess, '交易已完成', true),
      (CitizenTransactionHistoryStatus.finalizedFailed, '交易已最终失败', false),
      (CitizenTransactionHistoryStatus.poolRejected, '交易池已拒绝', false),
      (CitizenTransactionHistoryStatus.pending, '交易结果待确认', false),
      (CitizenTransactionHistoryStatus.inBlock, '交易结果待确认', false),
    ]) {
      for (final step in [
        OnchainPaymentStep.execution,
        OnchainPaymentStep.externalSignature,
      ]) {
        final result = onchainTransactionFeedback(
          step: step,
          record: _feedbackRecord(status),
          errorCode: CitizenSdkErrorCode.network,
        )!;
        expect(result.message, startsWith(prefix));
        expect(result.succeeded, success);
      }
    }
    for (final code in [
      CitizenSdkErrorCode.network,
      CitizenSdkErrorCode.unavailable,
      CitizenSdkErrorCode.notReady,
      CitizenSdkErrorCode.timeout,
    ]) {
      final result = onchainTransactionFeedback(
        step: OnchainPaymentStep.execution,
        record: null,
        errorCode: code,
      )!;
      expect(result.message, '暂未取得交易确认结果，请查看交易记录');
      expect(result.succeeded, isFalse);
    }
  });
  test('准备失败与签名取消不被改写成已成功或待确认', () {
    expect(
      onchainTransactionFeedback(
        step: OnchainPaymentStep.preparation,
        record: null,
        errorCode: CitizenSdkErrorCode.unavailable,
      ),
      isNull,
    );
    expect(
      onchainTransactionFeedback(
        step: OnchainPaymentStep.externalSignature,
        record: null,
        errorCode: CitizenSdkErrorCode.authenticationCancelled,
      ),
      isNull,
    );
    expect(
      onchainTransactionFeedback(
        step: OnchainPaymentStep.execution,
        record: null,
        errorCode: CitizenSdkErrorCode.authenticationRequired,
      ),
      isNull,
    );
  });

  for (final status in [
    CitizenTransactionHistoryStatus.finalizedSuccess,
    CitizenTransactionHistoryStatus.finalizedFailed,
    CitizenTransactionHistoryStatus.poolRejected,
    CitizenTransactionHistoryStatus.pending,
  ]) {
    testWidgets('SDK执行异常但回读为${status.name}，页面使用本笔状态且只查询一次', (tester) async {
      final core = await openTestSdk();
      var reads = 0, watches = 0;
      final service = _FeedbackService(
        citizenSs58FromAccountId(_walletBAccountId),
      );
      final history = WalletTransactionHistoryService(
        events: const Stream.empty(),
        watchPreparedTransaction: (_) {
          watches++;
          return const Stream.empty();
        },
        getPreparedTransactionRecord: (_) async {
          reads++;
          return _feedbackRecord(status);
        },
        syncTransactionHistory: () async => CitizenTransactionHistoryPage(
          revision: BigInt.zero,
          records: const [],
          nextBeforeExecutionId: null,
        ),
        getWalletState: () => testCitizenOperation(
          () async => CitizenWalletState(
            initializationState: CitizenWalletInitializationState.empty,
            cleanupPending: false,
            revision: BigInt.zero,
            hotProfile: null,
            accounts: const [],
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(history.stop);
      });
      await history.start();
      await history.sync();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CitizenSdk>.value(value: core.sdk),
            Provider<WalletTransactionHistoryService>.value(value: history),
          ],
          child: MaterialApp(
            home: OnchainPaymentPanel(
              title: '交易',
              paymentService: service,
              currentWalletLoader: () async => _wallet(
                index: 0,
                name: '测试钱包',
                address: citizenSs58FromAccountId(_walletAAccountId),
                accountId: _walletAAccountId,
              ),
              balanceLoader: (_) async => BigInt.from(10000),
              localRecordsLoader: (_, {limit = 100}) async => const [],
            ),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
      final block = CitizenBlockRef(
        hash: _walletAAccountId,
        number: BigInt.one,
        finality: CitizenBlockFinality.finalized,
      );
      final banner = tester.widget<ChainProgressBanner>(
        find.byType(ChainProgressBanner),
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
      final fields = find.byType(TextField);
      await tester.enterText(
        fields.at(0),
        citizenSs58FromAccountId(_walletBAccountId),
      );
      await tester.enterText(fields.at(1), '1');
      await tester.ensureVisible(find.text('签名交易'));
      await tester.tap(find.text('签名交易'));
      await tester.pumpAndSettle();
      expect(find.text('确认交易'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      final prefix = switch (status) {
        CitizenTransactionHistoryStatus.finalizedSuccess => '交易已完成',
        CitizenTransactionHistoryStatus.finalizedFailed => '交易已最终失败',
        CitizenTransactionHistoryStatus.poolRejected => '交易池已拒绝',
        _ => '交易结果待确认',
      };
      for (
        var attempt = 0;
        attempt < 100 && find.textContaining(prefix).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.textContaining(prefix), findsOneWidget);
      expect(find.textContaining('交易执行失败'), findsNothing);
      expect((reads, watches, service.preparations), (1, 1, 1));
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        status == CitizenTransactionHistoryStatus.finalizedSuccess ? '' : '1',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(history.stop);
    });
  }

  Future<void> openKeyboardForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: OnchainPaymentPanel(
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
      ),
    );
    await _pumpUntilFound(tester, find.textContaining('钱包可用余额：100'));
  }

  testWidgets('金额和多行备注均可用键盘上方按钮收起，输入内容保留', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await openKeyboardForm(tester);
    final fields = find.byType(TextField);
    for (final index in [1, 2]) {
      final field = fields.at(index);
      await tester.ensureVisible(field);
      await tester.enterText(field, index == 1 ? '12.50' : '备注第一行\n第二行');
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      final hide = find.byKey(const ValueKey('transaction-hide-keyboard'));
      expect(hide, findsOneWidget);
      await tester.tap(hide);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        tester.widget<TextField>(field).controller!.text,
        index == 1 ? '12.50' : '备注第一行\n第二行',
      );
      tester.view.resetViewInsets();
      await tester.pump();
      expect(hide, findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('金额完成键和点击输入框外均可收起键盘', (tester) async {
    await openKeyboardForm(tester);
    final amount = find.byType(TextField).at(1);
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '2.50');
    await tester.pump();
    // 嵌套Scaffold或硬件键盘没有可见insets时，输入焦点仍提供收起入口。
    expect(
      find.byKey(const ValueKey('transaction-hide-keyboard')),
      findsOneWidget,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.enterText(amount, '3.50');
    await tester.pump();
    await tester.tap(find.text('金额'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.widget<TextField>(amount).controller!.text, '3.50');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('拖动表单可收起备注键盘，多行文字不丢失', (tester) async {
    await openKeyboardForm(tester);
    final remark = find.byType(TextField).at(2);
    await tester.ensureVisible(remark);
    await tester.enterText(remark, '保留备注\n另一行');
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, 180));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.widget<TextField>(remark).controller!.text, '保留备注\n另一行');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('0x收款地址进入原确认弹窗，显示原始地址及解析账户，取消不准备交易', (tester) async {
    const address = '0x6D66a0cB155051055F3FB3Cc73d9230D3Fb4D5B5';
    const recipient = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
    final service = _RecipientService(recipient, FLAT_FEE: 137);
    var balanceFen = 10000;
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
          balanceLoader: (_) async => BigInt.from(balanceFen),
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
    expect(find.text('预估手续费：1.54 GMB'), findsOneWidget);
    expect(find.text('合计：3.57 GMB'), findsOneWidget);
    expect(find.text('以太坊地址：$address'), findsOneWidget);
    expect(find.text('收款账户：$recipient'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(service.preparations, 0);
    // 使用非100的快照值，验证备注费确实读取 FLAT_FEE；清空后恢复基础费。
    for (final note in ['', ' ', '\n', 'aaa']) {
      await tester.enterText(remark, note);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await _pumpUntilFound(tester, find.text('确认交易'));
      expect(
        find.text('预估手续费：${note.isEmpty ? '0.17' : '1.54'} GMB'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(remark, '测');
    balanceFen = 491; // 本金203 + 手续费154 + ED135，差一分。
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.textContaining('余额不足，可用余额：'));
    expect(find.text('确认交易'), findsNothing);
    balanceFen = 492;
    await tester.tap(submit);
    await _pumpUntilFound(tester, find.text('确认交易'));
    expect(find.text('预估手续费：1.54 GMB'), findsOneWidget);
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

  testWidgets('换绑后先更新预填地址，不直接进入签名确认', (tester) async {
    const cid = 'CN220-CTZN2-100000002-2026';
    const address = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
    final service = _RecipientService(address);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnchainPaymentPanel(
          title: '交易',
          paymentService: service,
          initialRecipientCid: cid,
          initialToAddress: 'previous-address',
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
    await tester.pumpAndSettle();
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
    await tester.enterText(find.widgetWithText(TextField, '请输入金额'), '2.03');
    final submit = find.widgetWithText(FilledButton, '签名交易');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('收款人钱包绑定已变更，请核对新地址后重新确认'), findsOneWidget);
    expect(find.text('确认交易'), findsNothing);
    expect(service.preparations, 0);
    final field = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == '请输入 公民链SS58地址 或 以太坊0x地址',
    );
    expect(tester.widget<TextField>(field).controller!.text, address);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final outcome in ['success', 'failure', 'edit', 'scan', 'reselect']) {
    testWidgets('选择联系人立即解析地址：$outcome', (tester) async {
      const cid = 'CN220-CTZN2-100000002-2026';
      const address = 'w5Bc7ma8qUcECfQDJmRyQM2wGmga5XSYtz7DvEengQ86xBWrT';
      final pending = Completer<OnchainRecipient>();
      var reads = 0;
      final service = _RecipientService(
        address,
        onResolve: (_) {
          reads++;
          if (reads == 1) return pending.future;
          return Future.value(const OnchainRecipient(address: 'new-contact'));
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OnchainPaymentPanel(
            title: '交易',
            chainStatusInHeader: true,
            paymentService: service,
            currentWalletLoader: () async => _wallet(
              index: 0,
              name: '测试钱包',
              address: 'wallet_a',
              accountId: _walletAAccountId,
            ),
            balanceLoader: (_) async => BigInt.from(10000),
            localRecordsLoader: (_, {limit = 100}) async => const [],
            contactPageBuilder: (_) => const Scaffold(body: Text('选择联系人测试页')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> select(String selectedCid) async {
        await tester.tap(find.byTooltip('我的通讯录'));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.text('选择联系人测试页'))).pop(selectedCid);
        await tester.pumpAndSettle();
      }

      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == '请输入 公民链SS58地址 或 以太坊0x地址',
      );
      await select(cid);
      expect(reads, 1);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('正在读取收款账户…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '签名交易'))
            .onPressed,
        isNull,
      );
      if (outcome == 'failure') {
        pending.completeError(StateError('无有效绑定'));
      } else {
        if (outcome == 'edit') await tester.enterText(field, 'manual-address');
        if (outcome == 'scan') {
          tester
              .widget<AddressScanButton>(find.byType(AddressScanButton))
              .onAddressScanned('scan-address');
        }
        if (outcome == 'reselect') await select('another-cid');
        pending.complete(
          const OnchainRecipient(address: address, cidNumber: cid),
        );
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        switch (outcome) {
          'success' => address,
          'failure' => '',
          'edit' => 'manual-address',
          'scan' => 'scan-address',
          _ => 'new-contact',
        },
      );
      if (outcome == 'failure') {
        expect(find.text('无法读取收款人有效钱包账户，请重新选择或填写地址'), findsOneWidget);
      }
      expect(find.textContaining('钱包可用余额：100'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
