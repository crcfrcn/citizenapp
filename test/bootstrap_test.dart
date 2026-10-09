import 'package:tatachat_sdk/tatachat_sdk.dart' as chat;

import 'dart:io';
import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/main.dart';
import 'package:citizenapp/security/account_security_service.dart';
import 'package:citizenapp/account/identity/current_user_context.dart';
import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/8964/profile/square_session_provider.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/notifications/app_push_service.dart';
import 'package:citizenapp/transaction/history/wallet_transaction_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'support/fake_citizen_sdk.dart';
import 'support/isar_test_env.dart';

import 'package:flutter_test/flutter_test.dart';

class _Security extends Fake implements AccountSecurityService {
  @override
  void dispose() {}
}

class _Current extends Fake implements CurrentUserContext {}

class _Resolver extends Fake implements FinalizedIdentityResolver {}

class _Sessions extends Fake implements SquareSessionProvider {
  @override
  void installRuntimeFactory(chat.ChatSdk Function() factory) {}
  @override
  void closeAuthentication() {}
}

class _History extends TestCitizenHistory {
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
      final transport = TestCitizenSdkTransport({
        'start': (_) => ['running'],
        'stop': (_) {
          if (stopFails) {
            throw const CitizenSdkException(
              code: CitizenSdkErrorCode.timeout,
              message: '合成checkpoint失败',
            );
          }
          return ['stopped'];
        },
      });
      final sdk = await transport.open();
      await sdk.start();
      var cancelled = false;
      final events = StreamController<CitizenSdkEvent>(
        onCancel: () async {
          cancelled = true;
          throw StateError('合成监听停止失败');
        },
      );
      final history = WalletTransactionHistoryService(
        history: _History(),
        chain: TestCitizenChain(),
        wallet: sdk.wallet,
        events: events.stream,
      );
      await history.start();
      var runtimeCreations = 0;
      var runtimeCloses = 0;
      await tester.pumpWidget(
        CitizenApp(
          sdk: sdk,
          accountSecurity: _Security(),
          currentUserContext: _Current(),
          finalizedIdentityResolver: _Resolver(),
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
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 30 && !transport.calls.contains('stop'); i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump();
      expect(runtimeCreations, 0);
      expect(runtimeCloses, 1);
      expect(cancelled, isTrue);
      expect(transport.calls.where((m) => m == 'stop'), hasLength(1));
      if (stopFails) {
        expect(transport.calls, isNot(contains('close')));
        expect(sdk.lifecycle, CitizenSdkLifecycle.running);
        transport.handlers['stop'] = (_) => ['stopped'];
        await tester.runAsync(() async {
          await sdk.stop();
          await sdk.close();
        });
      } else {
        for (var i = 0; i < 30 && !transport.calls.contains('close'); i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(
          transport.calls.indexOf('stop'),
          lessThan(transport.calls.indexOf('close')),
        );
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
        await events.close();
        await transport.dispose();
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
      'lib/wallet/pages/create_wallet_flow.dart',
      'lib/wallet/pages/import_wallet_page.dart',
      'lib/wallet/widgets/add_account_sheet.dart',
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
