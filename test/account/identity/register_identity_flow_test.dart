import 'package:citizenapp/account/identity/registration_coordinator.dart';
import 'package:citizenapp/account/identity/registration_models.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/network/square_api_client.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/account/identity/myid_service.dart';
import 'package:citizenapp/account/identity/register_identity_flow.dart';
import 'package:citizenapp/system/theme/app_theme.dart';

const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

/// 已注册:resolve 返回带链上闭环快照的身份。
class _RegisteredCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: _accountId,
    ss58Address: 'ss58-demo',
    snapshot: CitizenIdentityChainSnapshot(
      cidNumber: 'CN220-CTZN2-100000001-2026',
      accountId: Uint8List.fromList(List.filled(32, 0x11)),
      bindingRevision: 1,
      votingIdentity: null,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 未注册:resolve 命中缓存但快照为空(链读结论=全账户未占号,回退账户0)。
class _UnregisteredCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => const FinalizedIdentity(
    accountId: _accountId,
    ss58Address: 'ss58-demo',
    snapshot: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 链读失败:fail-closed,绝不冒充"未注册"。
class _ThrowingCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => throw Exception('链读失败');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 注册流程 fake:余额充足,占号直接成功。与 myid_page_test 同款口径。
class _FlowService implements MyIdService {
  _FlowService({this.guardFailure});
  final Object? guardFailure;
  int registerCalls = 0;
  int synchronizations = 0;
  @override
  Future<void> synchronizeIdentity(FinalizedIdentity identity) async {
    synchronizations++;
  }

  @override
  Future<List<CitizenWalletStateAccount>> listBindableAccounts() async =>
      <CitizenWalletStateAccount>[
        CitizenWalletStateAccount(
          signMode: CitizenWalletSignMode.hot,
          walletIndex: 0,
          accountIndex: 0,
          accountId: _accountId,
          ss58Address: 'ss58-demo',
          name: '账户0',
          createdAtMillis: BigInt.zero,
          isDefault: true,
        ),
      ];

  @override
  Future<({BigInt balanceFen, BigInt requiredFen})>
  fetchRegistrationAffordability(String bindAccountId) async =>
      (requiredFen: BigInt.from(121), balanceFen: BigInt.from(10000));

  @override
  Future<String> registerAnonymousCid({
    required BuildContext? context,
    required String institution,
    String? bindAccountId,
  }) async {
    registerCalls++;
    return 'CN220-CTZN2-100000009-2026';
  }

  @override
  Future<String> registrationChainScope() async => '0x${'22' * 32}';
  @override
  Future<Future<void> Function()> registrationGuard(String accountId) async {
    if (guardFailure != null) throw guardFailure!;
    return () async {};
  }

  @override
  Future<FinalizedRegistration> registerEnrollmentCid({
    required BuildContext? context,
    required String institution,
    required String accountId,
    required Future<void> Function(Map<String, dynamic>) onCheckpoint,
  }) async {
    final cid = await registerAnonymousCid(
      context: context,
      institution: institution,
      bindAccountId: accountId,
    );
    return FinalizedRegistration(
      binding: IdentityBinding(
        genesisHash: '0x${'22' * 32}',
        cidNumber: cid,
        bindingRevision: 1,
        accountId: accountId,
      ),
      blockHash: '0x${'aa' * 32}',
    );
  }

  @override
  Future<FinalizedRegistration?> readRegistrationIdentity(
    String accountId,
  ) async => null;
  @override
  Future<String> activateRegistration(FinalizedRegistration result) async =>
      '33' * 32;
  @override
  Future<bool> canRetryRegistration(Map<String, dynamic>? checkpoint) async =>
      false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Widget测试替换编排边界，真实验证/保存/取消/恢复顺序另由coordinator测试覆盖。
class _FlowCoordinator extends RegistrationCoordinator {
  @override
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<String?> Function(RegistrationVerification)
    showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
    required Future<String> Function(FinalizedRegistration) activate,
  }) async {
    await requireCurrent();
    await requireAffordable();
    final result = await registerCid((_) async {});
    await activate(result);
    return result;
  }
}

class _ReadySession implements SquareSessionProvider {
  _ReadySession({this.missing = false, this.cancel = false});
  bool missing, cancel;
  int registrations = 0;
  @override
  Future<SquareSession?> registerCurrentDevice() async {
    registrations++;
    if (cancel) {
      throw const CitizenSdkException(
        code: CitizenSdkErrorCode.authenticationCancelled,
        message: '合成用户取消',
      );
    }
    missing = false;
    return (await resolveSession()).session;
  }

  @override
  Future<SquareSessionResolution> resolveSession({
    bool refresh = false,
  }) async => missing
      ? const SquareSessionResolution(
          SquareSessionStatus.deviceUnavailable,
          errorCode: 'device_not_registered',
        )
      : SquareSessionResolution(
          SquareSessionStatus.ready,
          session: SquareSession(
            sessionToken: 'ordinary',
            cidNumber: 'CN220-CTZN2-100000001-2026',
            bindingRevision: 1,
            accountId: _accountId,
            deviceId: '33' * 32,
            expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
          ),
        );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 挂一个按钮驱动 [ensureCidRegisteredOrPrompt],把返回值收进 [results]。
Widget _harness(
  List<bool> results,
  MyIdService service,
  FinalizedIdentityResolver resolver, {
  bool directRegistration = false,
  _ReadySession? sessions,
}) {
  return MultiProvider(
    providers: [
      Provider<FinalizedIdentityResolver>.value(value: resolver),
      Provider<RegistrationCoordinator>.value(value: _FlowCoordinator()),
      Provider<SquareSessionProvider>.value(value: sessions ?? _ReadySession()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await (directRegistration
                    ? startCidRegistrationFlow(context, myIdService: service)
                    : ensureCidRegisteredOrPrompt(
                        context,
                        myIdService: service,
                      )),
              );
            },
            child: const Text('触发动作'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('已有公民号点击注册也不打开面板或再次占号', (tester) async {
    final results = <bool>[], service = _FlowService();
    await tester.pumpWidget(
      _harness(results, service, _RegisteredCache(), directRegistration: true),
    );
    await tester.tap(find.text('触发动作'));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(service.registerCalls, 0);
    expect(find.text('确认注册'), findsNothing);
  });
  testWidgets('已注册 → 放行返回 true,不弹注册面板', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(results, _FlowService(), _RegisteredCache()),
    );

    await tester.tap(find.text('触发动作'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.text('确认注册'), findsNothing);
  });

  for (final cancelled in [false, true]) {
    testWidgets('只有明确业务点击可登记设备，取消=$cancelled且不重复占号', (tester) async {
      final service = _FlowService();
      final sessions = _ReadySession(missing: true, cancel: cancelled);
      final results = <bool>[];
      await tester.pumpWidget(
        _harness(results, service, _RegisteredCache(), sessions: sessions),
      );
      await tester.pumpAndSettle();
      expect(sessions.registrations, 0);
      await tester.tap(find.text('触发动作'));
      await tester.pumpAndSettle();
      expect(sessions.registrations, 1);
      expect(service.synchronizations, 1);
      expect(service.registerCalls, 0);
      expect(results, [!cancelled]);
      if (cancelled) expect(find.text('设备授权已取消，可再次主动发起'), findsOneWidget);
      await tester.pump();
      expect(sessions.registrations, 1, reason: '渲染和重连不能自动重复授权');
    });
  }

  testWidgets('未注册动作不越过统一注册页面直接打开面板', (tester) async {
    final results = <bool>[];
    final service = _FlowService();
    await tester.pumpWidget(_harness(results, service, _UnregisteredCache()));

    await tester.tap(find.text('触发动作'));
    await tester.pumpAndSettle();

    expect(find.text('确认注册'), findsNothing);
    expect(results, [false]);
    expect(service.synchronizations, 1);
    expect(service.registerCalls, 0);
  });

  testWidgets('统一注册入口确认占号:只提交一次，缓存收敛归服务层', (tester) async {
    final cache = _UnregisteredCache();
    final service = _FlowService();
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(results, service, cache, directRegistration: true),
    );

    await tester.tap(find.text('触发动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();

    expect(service.registerCalls, 1);
    // Widget 流程不抢在 finalized 闭环前失效缓存或广播；MyIdService 在完整闭环成立后
    // 统一执行，相关“一次失效 + 一次 revision”由 myid_service_test 单独钉死。
    expect(find.textContaining('身份 CID 已注册'), findsOneWidget);
  });

  for (final failure in <(CitizenSdkErrorCode, String)>[
    (CitizenSdkErrorCode.network, '链网络连接失败'),
    (CitizenSdkErrorCode.keyInvalidated, '钱包签名密钥已失效'),
  ]) {
    testWidgets('SDK ${failure.$1.name} 失败显示具体原因并留在注册面板', (tester) async {
      final service = _FlowService(
        guardFailure: CitizenSdkException(
          code: failure.$1,
          message: '内部错误正文不得直接展示',
        ),
      );
      await tester.pumpWidget(
        _harness(
          <bool>[],
          service,
          _UnregisteredCache(),
          directRegistration: true,
        ),
      );
      await tester.tap(find.text('触发动作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认注册'));
      await tester.pumpAndSettle();
      expect(find.textContaining(failure.$2), findsOneWidget);
      expect(find.textContaining('内部错误正文'), findsNothing);
      expect(find.text('注册身份'), findsOneWidget);
      expect(service.registerCalls, 0);
    });
  }

  testWidgets('身份链读失败 → fail-closed 提示,不弹面板不放行', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _harness(results, _FlowService(), _ThrowingCache()),
    );

    await tester.tap(find.text('触发动作'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(find.text('确认注册'), findsNothing);
    expect(find.text('暂时无法验证身份，请稍后重试'), findsOneWidget);
  });
}
