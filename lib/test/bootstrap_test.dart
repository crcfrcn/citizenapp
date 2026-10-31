import 'package:tatachat_sdk/tatachat_sdk.dart' as chat;

import 'dart:io';
import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/main.dart';
import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/myid_service.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_account/identity/cid_business_gate.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_system/notifications/app_push_service.dart';
import 'package:citizen_transaction/history/wallet_transaction_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_testing/isar_test_env.dart';

import 'package:flutter_test/flutter_test.dart';

class _Security extends Fake implements AccountSecurityService {
  @override
  void dispose() {}
}

class _Current extends Fake implements CurrentUserContext {
  @override
  Future<CurrentUser?> resolve() async => null;
  @override
  void invalidate() {}
}

class _PublicSync extends Fake implements MyIdService {
  int calls = 0;
  @override
  Future<MyIdState> refreshState() async {
    calls++;
    return const MyIdState(tier: MyIdTier.visitor);
  }
}

class _Resolver extends Fake implements FinalizedIdentityResolver {}

class _Sessions extends Fake implements SquareSessionProvider {
  @override
  void installRuntimeFactory(chat.ChatSdk Function() factory) {}
  @override
  void closeAuthentication() {}
}

class _History extends TestHistoryReads {
  @override
  Future<CitizenTransactionHistoryPage> syncTransactionHistory() async =>
      CitizenTransactionHistoryPage(
        revision: BigInt.zero,
        records: const [],
        nextBeforeExecutionId: null,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  for (final stopFails in [false, true]) {
    testWidgets('根关闭遇监听异常仍尝试有序停止，停止失败不绕过checkpoint：$stopFails', (tester) async {
      // 擦除门闩与记录目录是不同方法；PIN只读取本用例的真实空目录。
      final records = await tester.runAsync(() async {
        final temporary = await Directory.systemTemp.createTemp(
          'bootstrap_records_',
        );
        return Directory(await temporary.resolveSymbolicLinks());
      });
      final gate = Completer<Object?>();
      const storage = MethodChannel('citizenapp/system_protected_data');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            if (call.method == 'prepareRecords') return records!.path;
            if (call.method == 'eraseObsoleteDataMaterial') return gate.future;
            throw StateError('未预期的系统保护记录方法');
          });
      final core = await openTestSdk(
        modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
      );
      final sdk = core.sdk;
      await tester.runAsync(()=>sdk.importColdAccount(accountId:testCitizenAccountId).result);
      final calls = <String>[];
      Future<void> stop() async {
        calls.add('stop');
        if (stopFails)
          throw const CitizenSdkException(
            code: CitizenSdkErrorCode.storage,
            message: '合成checkpoint失败',
          );
      }

      Future<void> close() async {
        calls.add('close');
        await sdk.close();
      }

      var cancelled = false;
      final events = StreamController<CitizenSdkEvent>(
        onCancel: () async {
          cancelled = true;
          throw StateError('合成监听停止失败');
        },
      );
      final history = (() {
        final reads0 = _History();
        final reads1 = TestChainReads();
        return WalletTransactionHistoryService(
          syncTransactionHistory: reads0.syncTransactionHistory,
          getTransactionHistory: reads0.getTransactionHistory,
          getGenesisHash: reads1.getGenesisHash,
          getFinalizedHead: reads1.getFinalizedHead,
          getFinalizedBlockAt: reads1.getFinalizedBlockAt,
          getStorage: reads1.getStorage,
          getSystemEvents: reads1.getSystemEvents,
          getRuntimeContext: reads1.getRuntimeContext,
          getBlockBody: reads1.getBlockBody,
          getAccountBalance: reads1.getAccountBalance,
          getAccountBalances: reads1.getAccountBalances,
          getWalletState: sdk.getWalletState,
          events: events.stream,
        );
      })();
      await tester.runAsync(history.start);
      final publicSync = _PublicSync();
      var runtimeCreations = 0;
      var runtimeCloses = 0;
      await tester.pumpWidget(
        CitizenApp(
          sdk: sdk,
          startChain: () async {},
          stopSdk: stop,
          closeSdk: close,
          identityService: publicSync,
          accountSecurity: _Security(),
          currentUserContext: _Current(),
          finalizedIdentityResolver: _Resolver(),
          cidBusinessGate: CidBusinessGate(
            currentUserContext: _Current(),
            identityResolver: _Resolver(),
            revision: ValueNotifier<int>(0),
            synchronizeIdentity: (_) async {},
          ),
          squareSessionProvider: _Sessions(),
          squareApiClient: SquareApiClient(),
          appPushService: AppPushService(),
          transactionHistory: history,
          chatRuntimeFactory: () {
            runtimeCreations++;
            throw StateError("擦除/锁门期间禁止创建MLS");
          },
          closeChatRuntime: () async {
            runtimeCloses++;
          },
        ),
      );
      await tester.pump();
      expect(publicSync.calls, 1);
      await tester.runAsync(() async {
        for (final name in ['first', 'second']) {
          final state = await sdk.getWalletState().result;
          await sdk
              .renameWallet(
                expectedRevision: state.revision,
                walletIndex: 0,
                name: name,
              )
              .result;
        }
      });
      await tester.pump();
      await tester.pump();
      expect(publicSync.calls, 1, reason: '同一默认账户事件不得重复查询身份');
      expect(runtimeCreations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      // 新身份监听与交易监听均真实撤销后才停SDK，虚拟帧不能代替原生I/O。
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !calls.contains('stop'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      expect(runtimeCreations, 0);
      expect(runtimeCloses, 1);
      expect(cancelled, isTrue);
      expect(calls.where((m) => m == 'stop'), hasLength(1));
      if (stopFails) {
        expect(calls, isNot(contains('close')));
        expect(sdk.lifecycle, CitizenSdkLifecycle.created);

        await tester.runAsync(() async {
          await sdk.close();
        });
      } else {
        await tester.runAsync(() async {
          for (var i = 0; i < 100 && !calls.contains('close'); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        expect(calls.indexOf('stop'), lessThan(calls.indexOf('close')));
        expect(sdk.lifecycle, CitizenSdkLifecycle.disposed);
      }
      gate.complete(null);
      // 根关闭已断言完成；按SDK启动维护最多三次重试的既有上限排空虚拟定时器。
      // 每轮让真实文件I/O完成，再推进虚拟时钟，不留异步维护到下一个用例。
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, null);
      // 流控制器关闭可能投递真实事件；离开Widget虚拟时钟完成夹具清理。
      await tester.runAsync(() async {
        // 合成取消失败会保留历史服务租约；根关闭断言之后单独排空夹具。
        await history.stop();
        await events.close();

        await records!.delete(recursive: true);
      });
    });
  }

  test('根实例只打开并启动一个完整 CitizenSDK session', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('CitizenSdkModules.full'));
    expect(RegExp(r'CitizenSdk\.open\(').allMatches(source), hasLength(1));
    expect(RegExp(r'citizenSdk\.start\(').allMatches(source), hasLength(1));
  });

  test('CitizenApp 生产源码不再包含旧钱包与本机 sr25519 实现', () {
    const removed = <String>[
      'lib/wallet/core/wallet_manager.dart',
      'lib/wallet/core/default_account_service.dart',
      'lib/wallet/core/native_sr25519.dart',
      'lib/wallet/core/hardware_bound_seed_vault.dart',
    ];
    for (final path in removed) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    // 原App页面必须存在；只禁止旧钱包/金库/签名核心，不把UI恢复判成残留。
    for (final path in const [
      'wallet/lib/create_wallet_flow.dart',
      'wallet/lib/import_wallet_page.dart',
      'wallet/lib/add_account_sheet.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('package:citizen_sdk/citizen_sdk.dart'),
        reason: path,
      );
      expect(source, isNot(contains('WalletManager')), reason: path);
      expect(source, isNot(contains('NativeSr25519')), reason: path);
    }
  });
}
