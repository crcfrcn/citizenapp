// 验证CID生成、人验、注册流程及注册界面。

import 'package:citizen_user/identity/registration.dart' show FinalizedRegistration, RegisterChoice, RegisterIdentitySheet, RegistrationApi, RegistrationContext, RegistrationCoordinator, RegistrationException, RegistrationPage, RegistrationRecord, RegistrationStore, RegistrationSubmitOutcome, RegistrationVerification, ensureCidRegisteredOrPrompt, generateCitizenCid, kCidInstitutionCitizen, kCidInstitutionResident, showRegisterIdentitySheet, startCidRegistrationFlow;
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionResolution, SquareSessionStatus;
import 'package:citizen_user/api.dart' show SquareSession;
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_chain/service.dart';
import 'package:citizen_user/identity/state.dart' show FinalizedIdentity, FinalizedIdentityResolver, MyIdService;
import 'package:citizen_system/theme.dart';
import 'dart:async';
import 'package:citizen_topup/page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:io';
import 'package:citizen_system/security/storage.dart';

void main() {
  group('cid_generator_golden_test', suite76);
  group('register_identity_flow_test', suite87);
  group('register_identity_sheet_test', suite88);
  group('registration_api_test', suite89);
  group('registration_coordinator_test', suite90);
  group('registration_page_test', suite91);
  group('registration_store_test', suite92);
}

// 以链端黄金向量验证人主体CID生成和年份范围。

void suite76() {
  // model B dev //0 账户公钥(与链端 golden `public_key` 逐字节一致)。
  const accountId =
      '0x2afba9278e30ccf6a6ceb3a8b6e336b70068f045c666f2e7f4f9cc5f47db8972';

  group('generateCitizenCid 金标 (硬门禁)', () {
    test('CTZN 2026 == 链端钉死金标 CN951-CTZN1-539598435-2026', () {
      final cid = generateCitizenCid(
        accountId: accountId,
        institution: 'CTZN',
        year: 2026,
      );
      expect(cid, 'CN951-CTZN1-539598435-2026');
    });

    test('CTZN 号形完整校验:CN 前缀 + R5 全数字 + N9 全数字 + 定长', () {
      final cid = generateCitizenCid(
        accountId: accountId,
        institution: 'CTZN',
        year: 2026,
      );
      // 总长 = R5(5)+'-'+seg2(5)+'-'+N9(9)+'-'+year(4) + 3 个连字符 = 26。
      expect(cid.length, 26);
      final segments = cid.split('-');
      expect(segments, hasLength(4));
      final r5 = segments[0];
      expect(r5.substring(0, 2), 'CN');
      expect(RegExp(r'^[0-9]{3}$').hasMatch(r5.substring(2, 5)), isTrue);
      expect(RegExp(r'^[0-9]{9}$').hasMatch(segments[2]), isTrue);
      expect(segments[3], '2026');
    });

    test('NATP 同账户同年:CN 前缀 + segment2 = NATP+digit + 号形回环', () {
      final cid = generateCitizenCid(
        accountId: accountId,
        institution: 'NATP',
        year: 2026,
      );
      expect(cid.startsWith('CN'), isTrue);
      final segments = cid.split('-');
      expect(segments, hasLength(4));
      // segment2 = 'NATP' + 单个 digit(Profit 策略 ⇒ M1 是数字)。
      expect(segments[1].substring(0, 4), 'NATP');
      expect(RegExp(r'^[0-9]$').hasMatch(segments[1].substring(4)), isTrue);
      // 整体格式 CN\d{3}-NATP\d-\d{9}-2026。
      expect(
        RegExp(r'^CN[0-9]{3}-NATP[0-9]-[0-9]{9}-2026$').hasMatch(cid),
        isTrue,
      );
    });

    test('非人主体机构码与非法年份被拒', () {
      expect(
        () => generateCitizenCid(
          accountId: accountId,
          institution: 'SFGF',
          year: 2026,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateCitizenCid(
          accountId: accountId,
          institution: 'CTZN',
          year: 202,
        ),
        throwsArgumentError,
      );
    });
  });
}

// 验证既有CID恢复、统一注册入口及明确取消和失败不重复授权。

const _accountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

/// 已注册:resolve 返回带链上闭环快照的身份。
class _RegisteredCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: _accountId,
    accountAddress: 'ss58-demo',
    snapshot: CitizenIdentityChainSnapshot(
      cidNumber: 'CN220-CTZN2-100000001-2026',
      accountId: Uint8List.fromList(List.filled(32, 0x11)),
      bindRev: 1,
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
    accountAddress: 'ss58-demo',
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
  Future<FinalizedRegistration> registerCid({
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
        bindRev: 1,
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
    required Future<RegistrationVerification?> Function() showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
  }) async {
    await requireCurrent();
    await requireAffordable();
    return registerCid((_) async {});
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
            bindRev: 1,
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

void suite87() {
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
    expect(find.textContaining('身份CID号 已注册'), findsOneWidget);
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

// 验证主体账户选择、单次提交、失败留页及余额不足充值交互。

CitizenWalletStateAccount _account({int index = 0, String? id}) =>
    CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: index,
      accountId: id ?? '0x${index.toRadixString(16).padLeft(64, '0')}',
      ss58Address: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
      name: '账户$index',
      createdAtMillis: BigInt.zero,
      isDefault: index == 0,
    );

void suite88() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 面板提交回调读取选择；成功后才关闭，失败会留在当前面板。
  Future<void> openSheet(
    WidgetTester tester,
    void Function(RegisterChoice) sink, {
    List<CitizenWalletStateAccount>? accounts,
    RegistrationSubmitOutcome outcome = const RegistrationSubmitOutcome.success(
      '已注册',
    ),
    Future<RegistrationSubmitOutcome> Function(BuildContext, RegisterChoice)?
    submit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showRegisterIdentitySheet(
                    context,
                    accounts: accounts ?? [_account()],
                    onSubmit: (sheetContext, choice) async {
                      sink(choice);
                      if (submit != null) {
                        return await submit(sheetContext, choice);
                      }
                      return outcome;
                    },
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('默认选公民 + 默认绑账户0,确认返回 CTZN', (tester) async {
    RegisterChoice? picked;
    await openSheet(tester, (v) => picked = v);

    expect(find.text('公民'), findsOneWidget);
    expect(find.text('居民'), findsOneWidget);
    // 单账户不露出绑定账户选择。
    expect(find.text('绑定钱包账户'), findsNothing);

    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.institution, kCidInstitutionCitizen);
    expect(picked?.bindAccountId, _account().accountId);
  });

  testWidgets('确认按钮连续点击只提交一个选择', (tester) async {
    var calls = 0;
    await openSheet(tester, (_) => calls++);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认注册'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('选居民后确认返回 NATP', (tester) async {
    RegisterChoice? picked;
    await openSheet(tester, (v) => picked = v);

    await tester.tap(find.text('居民'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.institution, kCidInstitutionResident);
  });

  testWidgets('注册失败仍停留身份面板并展示准确原因', (tester) async {
    await openSheet(
      tester,
      (_) {},
      outcome: const RegistrationSubmitOutcome.failure('余额读取失败，请重试'),
    );
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.text('余额读取失败，请重试'), findsOneWidget);
  });

  testWidgets('提交期间系统返回与遮罩点击不关闭面板，结束后可主动取消', (tester) async {
    final pending = Completer<RegistrationSubmitOutcome>();
    await openSheet(tester, (_) {}, submit: (_, _) => pending.future);
    await tester.tap(find.text('确认注册'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );

    pending.complete(const RegistrationSubmitOutcome.failure('注册服务超时，请重试'));
    await tester.pumpAndSettle();
    expect(find.text('注册服务超时，请重试'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsNothing);
  });

  testWidgets('余额不足先显示两种U入口，所选币种进入同一两行弹窗并返回注册面板', (tester) async {
    final target = _account(index: 5);
    await openSheet(
      tester,
      (_) {},
      accounts: [_account(), target],
      outcome: const RegistrationSubmitOutcome.failure(
        '注册失败：钱包余额不足',
        recharge: true,
      ),
    );
    await tester.tap(find.text('账户5'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pump();
    expect(find.byType(TopupSheet), findsNothing);
    await tester.tap(find.text('充值/USDC'));
    await tester.pumpAndSettle();
    final topup = tester.widget<TopupSheet>(find.byType(TopupSheet));
    expect(topup.accountId, target.accountId);
    expect(topup.token, 'USDC');
    expect(find.byType(BottomSheet), findsNWidgets(2));
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.textContaining('钱包余额不足'), findsOneWidget);
  });

  testWidgets('多账户时露出绑定账户选择,可选非0账户', (tester) async {
    RegisterChoice? picked;
    final a0 = _account(index: 0);
    final a5 = _account(
      index: 5,
      id: '0x5555555555555555555555555555555555555555555555555555555555555555',
    );
    await openSheet(tester, (v) => picked = v, accounts: [a0, a5]);

    expect(find.text('绑定钱包账户'), findsOneWidget);
    await tester.tap(find.text('账户5'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.bindAccountId, a5.accountId);
  });

  testWidgets('新说明和身份类型标题，取消在标题行右侧且不提交注册', (tester) async {
    var submits = 0;
    await openSheet(tester, (_) => submits++);
    expect(
      find.text('身份CID号是公民App的唯一用户账号，所绑定的钱包是唯一登录与控制凭证，请妥善保存。'),
      findsOneWidget,
    );
    expect(find.text('身份类型'), findsOneWidget);
    expect(find.text('主体类型'), findsNothing);
    expect(find.textContaining('占用一个匿名身份CID号'), findsNothing);
    expect(find.textContaining('自助注册只产生匿名身份'), findsNothing);
    final cancel = find.widgetWithText(TextButton, '取消');
    expect(cancel, findsOneWidget);
    final titleRect = tester.getRect(find.text('注册身份'));
    final descriptionRect = tester.getRect(
      find.text('身份CID号是公民App的唯一用户账号，所绑定的钱包是唯一登录与控制凭证，请妥善保存。'),
    );
    final typeRect = tester.getRect(find.text('身份类型'));
    final upperGap = descriptionRect.top - titleRect.bottom;
    final lowerGap = typeRect.top - descriptionRect.bottom;
    expect(upperGap, greaterThan(4));
    expect(upperGap, lessThan(lowerGap));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(find.text('取消')).dy,
      closeTo(titleRect.center.dy, 1),
    );
    expect(
      tester.getCenter(cancel).dx,
      greaterThan(tester.getCenter(find.text('注册身份')).dx),
    );
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsNothing);
    expect(submits, 0);
  });
}

// 验证Siteverify精确字段、成功闭集及错误正文和超限拒绝。

RegistrationContext registrationContext() => RegistrationContext(
  accountId: '0x${'11' * 32}',
  orgCode: 'CTZN',
  chainScope: '0x${'22' * 32}',
);
RegistrationVerification verification() => RegistrationVerification(
  checkId: '11111111-1111-4111-8111-111111111111',
  token: 'ephemeral-cloudflare-token',
);
void suite89() {
  test('默认Siteverify仅两字段，成功只接受is_ok，无任务或后续令牌', () async {
    final requests = <http.Request>[];
    final api = RegistrationApi(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"is_ok":true}', 200);
      }),
    );
    addTearDown(api.close);
    await api.verify(registrationContext(), verification());
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/user/registration/verify');
    expect(requests.single.url.hasQuery, false);
    expect(jsonDecode(requests.single.body), {
      'check_id': verification().checkId,
      'turnstile_token': verification().token,
    });
  });
  test('未通过、错误成功正文、附加字段和超限均不能放行', () async {
    for (final body in [
      '{"is_ok":false}',
      '{"is_ok":true,"credential":"x"}',
      '{}',
      'x' * 4097,
    ]) {
      final api = RegistrationApi(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.verify(registrationContext(), verification()),
        throwsA(isA<Exception>()),
      );
    }
  });
  test('403和服务故障明确失败且不透传原始响应', () async {
    for (final status in [400, 403, 429, 503]) {
      final api = RegistrationApi(
        client: MockClient(
          (_) async => http.Response('private-cloudflare-details', status),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.verify(registrationContext(), verification()),
        throwsA(
          isA<RegistrationException>()
              .having((e) => e.code, '固定代码', 'registration_http_$status')
              .having(
                (e) => e.message,
                '正文隔离',
                isNot(contains('private-cloudflare-details')),
              ),
        ),
      );
    }
  });
  test('CF结果限制UUID和令牌，页面URL无能力查询', () {
    expect(
      () => RegistrationVerification(checkId: 'invalid', token: 'x'),
      throwsFormatException,
    );
    expect(
      () =>
          RegistrationVerification(checkId: verification().checkId, token: ''),
      throwsFormatException,
    );
    expect(RegistrationApi.pageUri().path, '/api/user/registration/page');
    expect(RegistrationApi.pageUri().hasQuery, false);
  });
}

// 验证一次人验和原链交易，未知结果只恢复同一交易。

class Api extends RegistrationApi {
  Api(this.events);
  final List<String> events;
  bool acceptVerification = true;
  @override
  Future<void> verify(RegistrationContext c, RegistrationVerification v) async {
    events.add('siteverify');
    if (!acceptVerification) {
      throw const RegistrationException('未通过', code: 'verification_failed');
    }
  }
}

class MemoryStore extends RegistrationStore {
  MemoryStore(this.events);
  final List<String> events;
  RegistrationRecord? value;
  bool failWrite = false;
  @override
  Future<RegistrationRecord?> read(RegistrationContext c) async => value;
  @override
  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (failWrite) throw StateError('storage');
    if (value != previous) throw StateError('CAS');
    RegistrationRecord.decode(next.encode());
    value = next;
    events.add(next.finalized == null ? 'checkpoint' : 'finalized');
  }
}

/// Widget业务测试只替换人验页面交付，不跳过实际Siteverify编排。
class VerifiedCoordinator extends RegistrationCoordinator {
  VerifiedCoordinator({required super.api, required super.store});
  @override
  Future<FinalizedRegistration> run({
    required RegistrationContext context,
    required Future<void> Function() requireCurrent,
    required Future<RegistrationVerification?> Function() showVerification,
    required Future<void> Function() requireAffordable,
    required Future<FinalizedRegistration?> Function() readFinalized,
    required Future<FinalizedRegistration> Function(
      Future<void> Function(Map<String, dynamic>),
    )
    registerCid,
    Future<bool> Function(Map<String, dynamic>?)? canRetryChain,
  }) => super.run(
    context: context,
    requireCurrent: requireCurrent,
    showVerification: () async => verification(),
    requireAffordable: requireAffordable,
    readFinalized: readFinalized,
    registerCid: registerCid,
    canRetryChain: canRetryChain,
  );
}

FinalizedRegistration chainResult() => FinalizedRegistration(
  binding: IdentityBinding(
    genesisHash: registrationContext().chainScope,
    cidNumber: 'CN220-CTZN2-100000001-2026',
    bindRev: 1,
    accountId: registrationContext().accountId,
  ),
  blockHash: '0x${'aa' * 32}',
  txHash: '0x${'bb' * 32}',
);
void suite90() {
  late List<String> events;
  late Api api;
  late MemoryStore store;
  late RegistrationCoordinator coordinator;
  int wallets = 0, pages = 0;
  bool exists = false, cancel = false, guardOk = true;
  Future<FinalizedRegistration> run() => coordinator.run(
    context: registrationContext(),
    requireCurrent: () async {
      if (!guardOk) throw StateError('account changed');
    },
    showVerification: () async {
      pages++;
      events.add('page');
      return cancel ? null : verification();
    },
    requireAffordable: () async {
      events.add('balance');
    },
    readFinalized: () async {
      events.add('chain');
      return exists ? chainResult() : null;
    },
    registerCid: (save) async {
      final point = {
        'preparation_id': 'prepared-id',
        'account_id': registrationContext().accountId,
        'call_data_hash': '0x${'cc' * 32}',
        'state': 'prepared',
      };
      await save(point);
      await save({...point, 'state': 'executing'});
      wallets++;
      events.add('wallet');
      exists = true;
      return chainResult();
    },
    canRetryChain: (_) async => false,
  );
  setUp(() {
    events = [];
    api = Api(events);
    store = MemoryStore(events);
    coordinator = RegistrationCoordinator(api: api, store: store);
    wallets = pages = 0;
    exists = cancel = false;
    guardOk = true;
  });
  tearDown(() => api.close());
  test('一次人验通过后原交易，以持久化的最终结果收尾', () async {
    final result = await run();
    expect(result.binding.cidNumber, chainResult().binding.cidNumber);
    expect(wallets, 1);
    expect(pages, 1);
    expect(events.indexOf('siteverify'), lessThan(events.indexOf('balance')));
    expect(events.indexOf('balance'), lessThan(events.indexOf('wallet')));
    expect(events.last, 'finalized');
    final encoded = store.value!.encode();
    for (final text in [
      'reg_id',
      'recovery_token',
      'human_verified',
      'turnstile_token',
      'context_hash',
      'job_state',
    ]) {
      expect(encoded, isNot(contains(text)));
    }
  });
  test('人验失败与取消均零链交易、零存储', () async {
    api.acceptVerification = false;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(wallets, 0);
    expect(store.value, isNull);
    api.acceptVerification = true;
    cancel = true;
    await expectLater(run(), throwsA(isA<RegistrationException>()));
    expect(events.where((e) => e == 'siteverify'), hasLength(1));
    expect(wallets, 0);
  });
  test('已保存的最终结果可以恢复且不再次注册', () async {
    final first = await run();
    final second = await run();
    expect(second.blockHash, first.blockHash);
    expect(wallets, 1);
    expect(pages, 1);
    expect(store.value!.finalized!.blockHash, chainResult().blockHash);
  });
  test('未知执行只恢复原交易，不再人验或签名', () async {
    store.value = RegistrationRecord(
      context: registrationContext(),
      checkpoint: {
        'preparation_id': 'p',
        'execution_id': 'e',
        'account_id': registrationContext().accountId,
        'call_data_hash': '0x${'cc' * 32}',
        'state': 'executing',
      },
    );
    await expectLater(
      run(),
      throwsA(
        isA<RegistrationException>().having(
          (e) => e.code,
          '代码',
          'chain_pending',
        ),
      ),
    );
    expect(pages, 0);
    expect(wallets, 0);
  });
  test('链读取失败与本机检查点失败不进入钱包签名', () async {
    await expectLater(
      coordinator.run(
        context: registrationContext(),
        requireCurrent: () async {},
        showVerification: () async {
          pages++;
          return verification();
        },
        requireAffordable: () async {},
        readFinalized: () async => throw StateError('chain offline'),
        registerCid: (_) async {
          wallets++;
          return chainResult();
        },
      ),
      throwsStateError,
    );
    expect(pages, 0);
    store.failWrite = true;
    await expectLater(run(), throwsStateError);
    expect(wallets, 0);
  });
  test('已有公民号保存最终结果，账户变化停止后续动作', () async {
    exists = true;
    await run();
    expect(pages, 0);
    expect(wallets, 0);
    guardOk = false;
    await expectLater(run(), throwsStateError);
  });
  test('同一账户在途合并，结束后释放', () async {
    final gate = Completer<void>();
    var calls = 0;
    Future<FinalizedRegistration> call() => coordinator.run(
      context: registrationContext(),
      requireCurrent: () async {},
      showVerification: () async => verification(),
      requireAffordable: () async {},
      readFinalized: () async {
        calls++;
        await gate.future;
        return chainResult();
      },
      registerCid: (_) async => throw StateError('unexpected'),
    );
    final first = call(), second = call();
    expect(identical(first, second), true);
    expect(coordinator.isRegistering, true);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(coordinator.isRegistering, false);
  });
}

// 验证核验页面只接纳本次UUID和令牌，拒绝伪成功及附加字段。

void suite91() {
  const id = '11111111-1111-4111-8111-111111111111';
  test('默认页面只接受本次CF的UUID及token', () {
    final value = RegistrationPage.verificationFromMessage(
      jsonEncode({'check_id': id, 'token': 'ephemeral-token'}),
    );
    expect(value!.checkId, id);
    expect(value.token, 'ephemeral-token');
    expect(RegistrationApi.pageUri().hasQuery, false);
  });
  test('未知字段、伪造成功、无效ID和超限令牌不能放行', () {
    for (final value in [
      <String, Object>{'is_ok': true},
      {'check_id': 'invalid', 'token': 'x'},
      {'check_id': id, 'token': ''},
      {'check_id': id, 'token': 'x' * 2049},
      {'check_id': id, 'token': 'x', 'credential': 'x'},
    ]) {
      expect(
        RegistrationPage.verificationFromMessage(jsonEncode(value)),
        isNull,
      );
    }
  });
}

// 验证注册事实原生CAS、重启持久化及跨链和记录闭集。

void suite92() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('registration_chain_');
    root = Directory(await root.resolveSymbolicLinks());
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  RegistrationStore store() => RegistrationStore(
    records: SystemProtectedRecordStore(
      'registration.json',
      directory: () async => root.path,
    ),
  );
  RegistrationRecord record() => RegistrationRecord(
    context: registrationContext(),
    checkpoint: {
      'preparation_id': 'p',
      'account_id': registrationContext().accountId,
      'call_data_hash': '0x${'cc' * 32}',
      'state': 'executing',
    },
    finalized: chainResult(),
  );
  test('原生保护记录CAS并发只有一个胜者，重启保留真实交易事实', () async {
    final value = record();
    final wins = await Future.wait([
      store().save(null, value).then((_) => true, onError: (_) => false),
      store().save(null, value).then((_) => true, onError: (_) => false),
    ]);
    expect(wins.where((v) => v), hasLength(1));
    expect(
      (await store().read(value.context))!.finalized!.txHash,
      value.finalized!.txHash,
    );
    expect(await File('${root.path}/registration.json.part').exists(), false);
  });
  test('链账户自然键不因切机构绕过交易；跨链隔离，损坏和链接拒绝', () async {
    await store().save(null, record());
    final c = registrationContext();
    final other = RegistrationContext(
      accountId: c.accountId,
      orgCode: 'NATP',
      chainScope: c.chainScope,
    );
    expect((await store().read(other))!.checkpoint, isNotNull);
    final otherChain = RegistrationContext(
      accountId: c.accountId,
      orgCode: c.orgCode,
      chainScope: '0x${'33' * 32}',
    );
    expect(await store().read(otherChain), isNull);
    await File('${root.path}/registration.json').writeAsString('{');
    await expectLater(store().read(c), throwsFormatException);
    await File('${root.path}/registration.json').delete();
    await Link('${root.path}/registration.json').create('${root.path}/outside');
    await expectLater(store().read(c), throwsStateError);
  });
  test('仅当前链记录闭集，不保存人验、登记凭据或接受附加字段', () async {
    final value = record(),
        raw = jsonDecode(record().encode()) as Map<String, dynamic>;
    for (final key in [
      'reg_id',
      'recovery_token',
      'turnstile_token',
      'response',
      'job_state',
    ]) {
      expect(
        () => RegistrationRecord.decode(jsonEncode({...raw, key: 'forbidden'})),
        throwsFormatException,
      );
    }
    final bad = RegistrationRecord(
      context: value.context,
      checkpoint: {...value.checkpoint!, 'signature': 'forbidden'},
    );
    await expectLater(store().save(null, bad), throwsFormatException);
    expect(await store().read(value.context), isNull);
  });
}
