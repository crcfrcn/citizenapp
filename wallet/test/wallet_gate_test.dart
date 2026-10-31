import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_wallet/wallet_gate.dart';
import 'package:citizen_wallet/create_wallet_onboarding_page.dart';

import 'package:citizen_testing/fake_citizen_sdk.dart';

void main() {
  final core = TestCitizenSdkHarness(
    modules: CitizenSdkModules.wallet | CitizenSdkModules.qr,
  );
  CitizenSdkOperation<CitizenWalletState> Function()? readOperation;
  Future<List<CitizenSdkDiagnostic>> Function()? diagnostics;
  var diagnosticReads = 0;
  setUp(() {
    readOperation = null;
    diagnostics = null;
    diagnosticReads = 0;
  });

  Widget gate(
    Future<CitizenWalletState> Function()? loader, {
    Duration timeout = const Duration(seconds: 5),
    VoidCallback? introduced,
  }) => Provider<CitizenSdk>.value(
    value: core.sdk,
    child: MaterialApp(
      home: WalletGate(
        walletStateLoader: loader,
        walletOperation: readOperation,
        diagnosticsLoader: () {
          diagnosticReads++;
          return (diagnostics ?? core.sdk.readDiagnostics)();
        },
        loadTimeout: timeout,
        onInitialized: (_) => introduced?.call(),
        child: const Scaffold(body: Text('main-shell')),
      ),
    ),
  );

  test('失败原因按SDK错误码和完整固定文本精确匹配，未知原文及身份不输出', () {
    const cases = {
      'SQLite resource operation failed': 'sqlite_operation',
      'SQLite job was not executed': 'sqlite_job',
      'host wallet profile load failed': 'host_wallet_load',
      'host encrypted blob load failed': 'host_secret_load',
      'wallet profile revision disagrees with its typed payload':
          'wallet_revision',
      'public database schema version differs': 'schema_version',
      'public database object set differs': 'schema_objects',
      'public database schema differs': 'schema_definition',
      'public database auto-vacuum differs': 'schema_vacuum',
      'public database durability setting differs': 'schema_durability',
      'public database trusted-schema setting differs': 'schema_trust',
      'host record corruption digest does not match': 'record_digest',
      'host record belongs to a different typed store': 'record_domain',
      'persisted wallet identity is invalid': 'wallet_identity',
      'persisted cold identity is invalid': 'cold_identity',
      'persisted wallet order is duplicated': 'wallet_order',
      'persisted wallet state is invalid': 'wallet_state',
      'persisted wallet profile is invalid': 'wallet_profile',
    };
    final logs = <String>[];
    runZoned(
      () {
        for (final entry in cases.entries) {
          final line = AppLog.walletFailure(
            CitizenSdkException(
              code: CitizenSdkErrorCode.integrity,
              message: 'integrity: ${entry.key}',
            ),
          );
          expect(
            line,
            '[CitizenWallet] method=getWalletState code=integrity stage=verification reason=${entry.value}',
          );
        }
        expect(
          AppLog.walletFailure(
            const CitizenSdkException(
              code: CitizenSdkErrorCode.integrity,
              message: 'CitizenSDK native operation failed',
            ),
          ),
          endsWith('reason=native_unspecified'),
        );
        for (final error in [
          const CitizenSdkException(
            code: CitizenSdkErrorCode.integrity,
            message: 'integrity: public database schema differs synthetic-private-content',
            method: 'synthetic-private-method',
            sessionId: 'synthetic-private-session',
            requestSequence: 99881,
          ),
          const CitizenSdkException(
            code: CitizenSdkErrorCode.storage,
            message: 'integrity: public database schema differs',
          ),
          StateError('synthetic-private-content'),
        ]) {
          expect(AppLog.walletFailure(error), endsWith('reason=other'));
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );
    expect(logs, hasLength(cases.length + 4));
    expect(logs.join('\n'), isNot(contains('synthetic-private')));
    expect(logs.join('\n'), isNot(contains('99881')));
    expect(logs.join('\n'), isNot(contains('public database')));
  });

  testWidgets('门禁保留实际SDK失败分支，查看只调用已有诊断接口且不重读钱包', (tester) async {
    var reads = 0, fail = true;
    readOperation = () {
      reads++;
      return testCitizenOperation(() {
        if (fail) {
          throw const CitizenSdkException(
            code: CitizenSdkErrorCode.integrity,
            message: 'integrity: public database schema differs',
          );
        }
        return testCitizenWalletState();
      });
    };
    diagnostics = () async => [
      CitizenSdkDiagnostic.decode(<Object?>[
        'getWalletState',
        'COMPLETE',
        9,
        6,
        'NONE',
        3,
      ]),
    ];
    await tester.pumpWidget(gate(null));
    await tester.pumpAndSettle();
    expect(find.text('本地钱包记录校验失败，请查看诊断'), findsOneWidget);
    expect(find.text('main-shell'), findsNothing);
    expect(diagnosticReads, 0);
    await tester.tap(find.byKey(const ValueKey('wallet-gate-diagnostics')));
    await tester.pumpAndSettle();
    final text = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(
      text,
      contains('code=integrity stage=verification reason=schema_definition'),
    );
    expect(
      text,
      contains(
        'method=getWalletState phase=COMPLETE code=9 stage=6 point=NONE elapsed_ms=3',
      ),
    );
    expect(diagnosticReads, 1);
    expect(reads, 1);
    Navigator.of(tester.element(find.byType(SelectableText))).pop();
    await tester.pumpAndSettle();
    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsOneWidget);
    expect(find.text('查看诊断'), findsNothing);
    expect(reads, 2);
  });

  testWidgets('诊断接口失败或返回空记录仍保留本次安全原因，不显示异常原文', (tester) async {
    for (final fails in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      diagnostics = () async {
        if (fails) throw StateError('synthetic-private-diagnostic');
        return <CitizenSdkDiagnostic>[];
      };
      await tester.pumpWidget(
        gate(
          () async => throw const CitizenSdkException(
            code: CitizenSdkErrorCode.integrity,
            message: 'integrity: public database object set differs',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看诊断'));
      await tester.pumpAndSettle();
      final text = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(text, contains('reason=schema_objects'));
      expect(text, contains(fails ? '安全诊断暂不可读取' : '暂无安全诊断记录'));
      expect(text, isNot(contains('synthetic-private')));
      Navigator.of(tester.element(find.byType(SelectableText))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('诊断请求在途合并重复点击，卸载后迟到记录不打开页面', (tester) async {
    final pending = Completer<List<CitizenSdkDiagnostic>>();
    diagnostics = () => pending.future;
    await tester.pumpWidget(
      gate(
        () async => throw const CitizenSdkException(
          code: CitizenSdkErrorCode.integrity,
          message: 'integrity: public database schema version differs',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看诊断'));
    await tester.pump();
    await tester.tap(find.text('查看诊断'));
    await tester.pump();
    expect(diagnosticReads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(<CitizenSdkDiagnostic>[]);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无钱包保留原App入口，SDK就绪事件不越过原备份结束回调', (tester) async {
    var ready = false, introduced = 0;
    await tester.pumpWidget(
      gate(
        () async =>
            ready ? _state([_account(CitizenWalletSignMode.cold)]) : _state([]),
        introduced: () => introduced++,
      ),
    );
    await tester.pumpAndSettle();
    // 原页面使用惰性ListView，先按真实滚动行为使底部按钮进入构建范围。
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '创建钱包'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.widgetWithText(FilledButton, '创建钱包'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('导入助记词'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('导入助记词'), findsOneWidget);
    expect(find.byType(CreateWalletOnboardingPage), findsOneWidget);
    ready = true;
    await tester.runAsync(
      () => core.sdk.importColdAccount(accountId: testCitizenAccountId).result,
    );
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsNothing);
    tester
        .widget<CreateWalletOnboardingPage>(
          find.byType(CreateWalletOnboardingPage),
        )
        .onCreated();
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsOneWidget);
    expect(introduced, 1);
    expect(core.fixture.calls, isNot(contains('initializeWallet')));
  });

  testWidgets('热账户或冷账户任一存在都放行，不触发初始化', (tester) async {
    for (final mode in CitizenWalletSignMode.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(gate(() async => _state([_account(mode)])));
      await tester.pumpAndSettle();
      expect(find.text('main-shell'), findsOneWidget);
      expect(find.byType(CreateWalletOnboardingPage), findsNothing);
    }
  });

  testWidgets('异常钱包也不是空目录，门禁放行由SDK事实决定', (tester) async {
    await tester.pumpWidget(
      gate(
        () async => CitizenWalletState(
          revision: BigInt.one,
          hotProfile: null,
          accounts: const [],
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          diagnostics: [
            CitizenWalletDiagnostic(
              walletIndex: 0,
              walletName: '异常',
              accountId: testCitizenAccountId,
              ss58Address: null,
              diagnosticReason: CitizenWalletDiagnosticReason.invalidStructure,
              signMode: null,
              cleanupTargets: null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsOneWidget);
  });

  testWidgets('SDK读取失败不当空，原重试成功后放行', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      gate(() async {
        if (++calls == 1) throw Exception('合成读取失败');
        return _state([_account(CitizenWalletSignMode.hot)]);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('本地钱包读取失败'), findsOneWidget);
    expect(find.byType(CreateWalletOnboardingPage), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsOneWidget);
  });

  testWidgets('运行期SDK删除至空回原门禁，不自动调用SDK窗口', (tester) async {
    var state = _state([_account(CitizenWalletSignMode.hot)]);
    await tester.pumpWidget(gate(() async => state));
    await tester.pumpAndSettle();
    state = _state([]);
    await tester.runAsync(
      () => core.sdk.importColdAccount(accountId: testCitizenAccountId).result,
    );
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsNothing);
    expect(find.byType(CreateWalletOnboardingPage), findsOneWidget);
    expect(core.fixture.calls, isNot(contains('initializeWallet')));
  });

  testWidgets('未收敛状态和超时保留原错误与重试，不启动初始化', (tester) async {
    await tester.pumpWidget(
      gate(
        () async => CitizenWalletState(
          revision: BigInt.one,
          hotProfile: null,
          accounts: const [],
          initializationState: CitizenWalletInitializationState.recovering,
          cleanupPending: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('本地钱包读取失败'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final pending = Completer<CitizenWalletState>();
    await tester.pumpWidget(
      gate(() => pending.future, timeout: const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 25));
    expect(find.text('本地钱包读取超时，请重试'), findsOneWidget);
    expect(find.byType(CreateWalletOnboardingPage), findsNothing);
  });
  testWidgets('门禁超时不等待取消确认，重试等真实请求排空后恢复', (tester) async {
    final pending = Completer<CitizenWalletState>();
    final cancellation = Completer<bool>();
    var reads = 0;
    var cancels = 0;
    readOperation = () {
      reads++;
      return CitizenSdkOperation(
        operationId: 'read-$reads',
        result: reads == 1
            ? pending.future
            : Future.value(testCitizenWalletState()),
        cancel: () {
          cancels++;
          return cancellation.future;
        },
      );
    };
    await tester.pumpWidget(
      gate(null, timeout: const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();
    expect(find.text('本地钱包读取超时，请重试'), findsOneWidget);
    expect(cancels, 1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('本地钱包正忙，请稍后重试'), findsOneWidget);
    cancellation.complete(true);
    pending.complete(testCitizenWalletState());
    await tester.pumpAndSettle();
    expect(find.text('main-shell'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('main-shell'), findsOneWidget);
  });
}

CitizenWalletState _state(List<CitizenWalletStateAccount> accounts) =>
    CitizenWalletState(
      revision: BigInt.one,
      hotProfile:
          accounts.any((value) => value.signMode == CitizenWalletSignMode.hot)
          ? testCitizenWalletProfile()
          : null,
      accounts: accounts,
      initializationState: accounts.isEmpty
          ? CitizenWalletInitializationState.empty
          : CitizenWalletInitializationState.ready,
      cleanupPending: false,
    );

CitizenWalletStateAccount _account(CitizenWalletSignMode mode) {
  final hot = testCitizenWalletState().accounts.single;
  return mode == CitizenWalletSignMode.hot
      ? hot
      : CitizenWalletStateAccount(
          signMode: mode,
          walletIndex: 1,
          accountIndex: null,
          accountId: hot.accountId,
          ss58Address: hot.ss58Address,
          name: 'cold',
          createdAtMillis: BigInt.one,
          isDefault: true,
        );
}
