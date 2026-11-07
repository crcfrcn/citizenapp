import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_wallet/history/wallet_transaction_history_service.dart';

import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_wallet/history/local_tx_store.dart';
import 'package:citizen_wallet/history/tx_auto_refresh_mixin.dart';

import 'package:citizen_testing/isar_test_env.dart';

// 原生 watcher 通知通过真实事件循环推进，页面去抖通过 widget 时钟推进；
// 分别推进这两个阶段，验证账户切换、取消和迟到回执，不用单次固定延迟猜测通知。
void main() {
  useIsolatedIsar();

  tearDown(() {
    LocalTxAccountChangeSubscription.debugCancelSubscription = null;
  });

  const fromAccountId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const fromAddress = 'from-wallet';
  const toAddress = 'to-wallet';

  const otherAccountId =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  Future<void> settleLocal(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  Future<void> write(String account) => LocalTxStore.upsert(
    Entry()
      ..accountId = account
      ..entryKind = 'transfer'
      ..amountDelta = '100'
      ..transferAmount = '100'
      ..entryState = LocalTxStore.statusFinalized
      ..entrySource = 'chain_event'
      ..blockHash = '0x1111'
      ..blockNumber = 1
      ..eventIndex = 0
      ..createdAt = 1,
  );

  testWidgets('旧账户已排队的去抖回调不能重读新账户，新账户监听仍有效', (tester) async {
    final key = GlobalKey<_TxWatcherHostState>();
    await tester.pumpWidget(_TxWatcherHost(key: key, accountId: fromAccountId));
    await settleLocal(tester);
    await tester.runAsync(() => write(fromAccountId));
    await settleLocal(tester);
    expect(key.currentState!.reloads, isEmpty);
    await tester.pumpWidget(
      _TxWatcherHost(key: key, accountId: otherAccountId),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(key.currentState!.reloads, isEmpty);
    await settleLocal(tester);
    await tester.runAsync(() => write(otherAccountId));
    await settleLocal(tester);
    await tester.pump(const Duration(milliseconds: 250));
    expect(key.currentState!.reloads, [otherAccountId]);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('重复主动刷新共用一次完成任务及本机重读', (tester) async {
    final service = WalletTransactionHistoryService(
      events: const Stream<CitizenSdkEvent>.empty(),
    );
    final key = GlobalKey<_TxWatcherHostState>();
    await tester.pumpWidget(
      Provider.value(
        value: service,
        child: _TxWatcherHost(key: key, accountId: fromAccountId),
      ),
    );
    final first = key.currentState!.refreshTxHistory(),
        second = key.currentState!.refreshTxHistory();
    expect(identical(first, second), isTrue);
    await tester.pump();
    await first;
    expect(key.currentState!.reloads, [fromAccountId]);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('主动同步在途切账户，旧刷新完成不重复重读新账户', (tester) async {
    final held = Completer<CitizenTransactionHistoryPage>();
    final service = WalletTransactionHistoryService(
      events: const Stream<CitizenSdkEvent>.empty(),
      syncTransactionHistory: () => held.future,
      getWalletState: () => testCitizenOperation(
        () => CitizenWalletState(
          revision: BigInt.one,
          hotProfile: null,
          cleanupPending: false,
          initializationState: CitizenWalletInitializationState.empty,
          accounts: [],
        ),
      ),
    );
    final key = GlobalKey<_TxWatcherHostState>();
    Widget page(String account) => Provider.value(
      value: service,
      child: _TxWatcherHost(key: key, accountId: account),
    );
    await tester.pumpWidget(page(fromAccountId));
    await tester.runAsync(service.start);
    final oldRefresh = key.currentState!.refreshTxHistory();
    await tester.pumpWidget(page(otherAccountId));
    final newRefresh = key.currentState!.refreshTxHistory();
    expect(identical(oldRefresh, newRefresh), isFalse);
    held.complete(
      CitizenTransactionHistoryPage(
        revision: BigInt.zero,
        records: [],
        nextBeforeExecutionId: null,
      ),
    );
    await tester.pump();
    await settleLocal(tester);
    await Future.wait([oldRefresh, newRefresh]);
    expect(key.currentState!.reloads, [otherAccountId]);
    await tester.runAsync(service.stop);
    await tester.pumpWidget(const SizedBox());
    await settleLocal(tester);
  });

  testWidgets('listenAccountChanges 在记录 pending→finalized 写库时发出事件', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LocalTxStore.upsertLocalSubmitTransfer(
        accountId: fromAccountId,
        txHash: '0xfeed',
        amountDelta: '-101',
        transferAmount: '100',
        feeAmount: '1',
        fromAddress: fromAddress,
        toAddress: toAddress,
        executionId: 'execution-refresh',
        callHash: '0x${'11' * 32}',

        createdAt: 1,
      );

      final seen = <void>[];
      final sub = LocalTxStore.listenAccountChanges(
        fromAccountId,
        () => seen.add(null),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150)); // 订阅生效

      // 模拟 SDK history 把记录投影为 finalized。
      await LocalTxStore.markLocalSubmitFinalized(
        accountId: fromAccountId,
        txHash: '0xfeed',
        executionId: 'execution-refresh',
        callHash: '0x${'11' * 32}',
        blockHash: '0x22',
        blockNumber: 9,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200)); // 通知送达

      expect(seen, isNotEmpty, reason: 'finalized 写库应触发 watch 事件驱动 UI 重刷');
      await sub.cancel();
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('UserIsar 擦除会等待已登记 watcher 真实取消', (tester) async {
    await tester.runAsync(() async {
      final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await UserIsar.instance.closeAndDeleteFromDisk();

      // close 已取得同一个 single-flight 取消任务，调用方随后重复取消仍应幂等完成。
      await sub.cancel();
      expect(() => UserIsar.instance.db(), throwsA(isA<StateError>()));
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('关闭命中 watcher 启动窗口时不会晚到挂回数据库', (tester) async {
    await tester.runAsync(() async {
      final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});

      // 不等待 db() 和原生 subscription 建立，直接同步发出关闭意图。
      await UserIsar.instance.closeAndDeleteFromDisk();
      await sub.cancel();

      expect(UserIsar.instance.db, throwsA(isA<StateError>()));
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('Widget dispose 后全局擦除会确定性等待 fake-async watcher', (tester) async {
    await tester.pumpWidget(const _TxWatcherHost(accountId: fromAccountId));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    for (
      var attempt = 0;
      attempt < 20 && UserIsar.instance.hasActiveOperation;
      attempt++
    ) {
      // 原生 Future 先在真实事件循环前进，再回 widget fake-async Zone 收尾；打开、
      // 查询是两个异步阶段，不能用一次固定延迟假定都已经完成。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(UserIsar.instance.hasActiveOperation, isFalse);
    await tester.runAsync(UserIsar.instance.closeAndDeleteFromDisk);
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('外部消费者取消失败会使擦除可见失败并允许重试', (tester) async {
    await tester.runAsync(() async {
      var shouldFail = true;
      late IsarConsumerLease lease;
      lease = UserIsar.instance.registerExternalConsumer(() async {
        if (shouldFail) {
          throw StateError('模拟 watcher 取消失败');
        }
        lease.release();
      });

      await expectLater(
        UserIsar.instance.closeAndDeleteFromDisk(),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('取消 用户库外部消费者失败'),
          ),
        ),
      );
      expect(UserIsar.instance.db, throwsA(isA<StateError>()));

      shouldFail = false;
      await UserIsar.instance.closeAndDeleteFromDisk();
    });
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('原生 watcher 取消失败由调用方观察且 root Zone 不泄漏', (tester) async {
    await tester.runAsync(() async {
      final uncaught = <Object>[];
      await runZonedGuarded(
        () async {
          final sub = LocalTxStore.listenAccountChanges(fromAccountId, () {});
          await Future<void>.delayed(const Duration(milliseconds: 100));

          var shouldFail = true;
          LocalTxAccountChangeSubscription.debugCancelSubscription =
              (subscription) async {
                if (shouldFail) throw StateError('模拟原生 watcher 取消失败');
                await subscription.cancel();
              };

          await expectLater(
            sub.cancel(),
            throwsA(
              isA<StateError>().having(
                (error) => error.toString(),
                'message',
                contains('模拟原生 watcher 取消失败'),
              ),
            ),
          );

          // 失败保留 lease/subscription；同一句柄可在原生边界恢复后重试并真实释放。
          shouldFail = false;
          await sub.cancel();
          await UserIsar.instance.closeAndDeleteFromDisk();
        },
        (error, _) {
          uncaught.add(error);
        },
      );
      expect(uncaught, isEmpty);
    });
  }, timeout: const Timeout(Duration(seconds: 40)));
}

class _TxWatcherHost extends StatefulWidget {
  const _TxWatcherHost({super.key, required this.accountId});

  final String accountId;

  @override
  State<_TxWatcherHost> createState() => _TxWatcherHostState();
}

class _TxWatcherHostState extends State<_TxWatcherHost>
    with TxAutoRefreshMixin<_TxWatcherHost> {
  @override
  void initState() {
    super.initState();
    unawaited(LocalTxStore.queryRecentByAccountId(widget.accountId));
    startTxAutoRefresh(widget.accountId);
  }

  final reloads = <String>[];

  @override
  void didUpdateWidget(covariant _TxWatcherHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    startTxAutoRefresh(widget.accountId);
  }

  @override
  Future<void> onTxRecordsChanged() async {
    reloads.add(widget.accountId);
  }

  @override
  void dispose() {
    unawaited(stopTxAutoRefresh().catchError((Object _, StackTrace _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
