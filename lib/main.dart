import 'navigation.dart';
import 'package:citizen_wallet/navigation.dart';
import 'package:citizen_citizen/navigation.dart';
import 'package:citizen_transaction/navigation.dart';
import 'package:citizen_account/navigation.dart';
import 'package:citizen_transaction/onchain/onchain_payment_page.dart';
import 'scan_dispatch_flow.dart';
import 'package:citizen_scanner/scan_dispatch.dart';
import 'package:citizen_system/security/account_security_exception.dart';
import 'package:citizen_account/membership/subscription_service.dart';

import 'dart:convert';

import 'package:citizen_account/notifications.dart';
import 'package:citizen_square/feed/square_home_page.dart'
    show openSquareNotification;

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_system/app_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as chat;
import 'package:citizen_square/feed/square_tab_page.dart';
import 'package:citizen_citizen/citizen_tab_page.dart';
import 'package:citizen_chat/chat_product_configuration.dart';
import 'package:citizen_chat/tatachat_sdk_adapter.dart';
import 'package:citizen_chat/chat_entry.dart';
import 'package:citizenapp/security/app_lock_service.dart';
import 'package:citizen_system/security/emergency_wipe_platform.dart';
import 'package:citizenapp/security/pin_input_page.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_transaction/transaction_tab_page.dart';
import 'package:citizen_transaction/history/wallet_transaction_history_service.dart';
import 'package:citizen_system/security/screenshot_guard.dart';
import 'package:citizenapp/user.dart';
import 'package:citizen_account/identity/current_user_context.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_account/identity/cid_business_gate.dart';
import 'package:citizen_account/identity/myid_service.dart';
import 'package:citizen_account/identity/identity_badge_snapshot_store.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizenapp/security/app_permission_gate.dart';
import 'package:citizen_system/update/app_update.dart';
import 'package:citizen_system/update/update_badge.dart';
import 'package:citizen_account/identity/mls_device_registrar.dart';
import 'package:citizen_account/identity/mls_authentication.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_system/notifications/app_push_service.dart';
import 'package:citizen_system/notifications/app_push_token.dart';
import 'package:citizen_account/identity/registration_coordinator.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_account/identity/identity_binding.dart';
import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_wallet/wallet_gate.dart';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/security/biometric_auth_text.dart';

part 'app.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只删除App明确拥有的旧非钱包材料，删除失败终止启动。
  await SystemProtectedStorage.eraseObsoleteDataMaterial();

  // CitizenApp 只打开一个完整 CitizenSDK session。钱包、签名、QR_V1、
  // 轻节点、交易与 execution history 共用同一个 Engine generation。
  final citizenSdk = await CitizenSdk.open(modules: CitizenSdkModules.full);
  late final CurrentUserContext currentUserContext;
  late final chat.ChatSdk Function() readChatRuntime;
  final registrationCoordinator = RegistrationCoordinator();
  final authentication = MlsAuthentication(
    runtime: () => readChatRuntime(),
    currentBinding: () async {
      final registering = registrationCoordinator.activeBinding;
      // 新注册在真实回执持久保存前不让根自动准备抢跑；注册激活继续复用同一实例。
      if (registrationCoordinator.isRegistering && registering == null) {
        throw const MlsAuthenticationException(
          '注册回执正在保存',
          code: 'identityUnavailable',
        );
      }
      if (registering != null) {
        await registrationCoordinator.requireActiveCurrent();
        return (
          cidNumber: registering.cidNumber,
          accountId: registering.accountId,
          bindRev: registering.bindRev,
        );
      }
      final current = await currentUserContext.resolve();
      final binding = current?.binding;
      if (current == null ||
          binding == null ||
          binding.accountId != current.accountId) {
        throw const MlsAuthenticationException(
          '当前身份尚未验证',
          code: 'identityUnavailable',
        );
      }
      return (
        cidNumber: binding.cidNumber,
        accountId: binding.accountId,
        bindRev: binding.bindRev,
      );
    },
  );
  final registrar = MlsDeviceRegistrar(
    authentication: authentication,
    registrationCapabilities: (identity) async =>
        registrationCoordinator.store.forDevice(
          identity,
          chainScope: await citizenSdk.chain.getGenesisHash(),
        ),
  );
  final accountSecurity = AccountSecurityService(
    wallet: citizenSdk.wallet,
    signing: citizenSdk.signing,
    mlsDeviceRegistrar: registrar.register,
    coldMlsDeviceBindingSigner:
        ({
          required binding,
          required payload,
          required signingMessage,
          required publicKey,
          required issuedAtMillis,
        }) => _signColdMlsDeviceBinding(
          wallet: citizenSdk.wallet,
          signing: citizenSdk.signing,
          binding: binding,
          payload: payload,
          signingMessage: signingMessage,
          publicKey: publicKey,
          issuedAtMillis: issuedAtMillis,
        ),
  );
  currentUserContext = CurrentUserContext(
    wallet: citizenSdk.wallet,
    accountSecurity: accountSecurity,
  );
  final finalizedIdentityResolver = FinalizedIdentityResolver(
    wallet: citizenSdk.wallet,
    chain: citizenSdk.chain,
    snapshotStore: IdentityBadgeSnapshotStore(),
    identityRevision: accountSecurity.revision,
  );
  SquareApiClient.resourceGate = SubscriptionService.resourceGate;
  final squareApiClient = SquareApiClient();
  final appPushService = AppPushService();
  late final SquareSessionProvider squareSessionProvider;
  late final MyIdService identityService;
  chat.ChatSdk? sharedChatRuntime;
  final cidBusinessGate = CidBusinessGate(
    currentUserContext: currentUserContext,
    identityResolver: finalizedIdentityResolver,
    revision: accountSecurity.revision,
    synchronizeIdentity: (verified) =>
        identityService.synchronizeIdentity(verified),
  );
  squareSessionProvider = SquareSessionProvider(
    accountSecurity: accountSecurity,
    currentUserContext: currentUserContext,
    client: squareApiClient,
    authentication: authentication,
    cidBusinessGate: cidBusinessGate,
  );

  identityService = MyIdService(
    wallet: citizenSdk.wallet,
    signing: citizenSdk.signing,
    chain: citizenSdk.chain,
    transactions: citizenSdk.transactions,
    history: citizenSdk.history,
    accountSecurity: accountSecurity,
    currentUserContext: currentUserContext,
    identityResolver: finalizedIdentityResolver,
    sessionProvider: squareSessionProvider,
    chatRuntime: () => readChatRuntime(),
    activeChatRuntime: () => sharedChatRuntime,
  );

  // 任何 ChatSdk、钱包页或 PIN 门禁构造前先处理跨重启擦除门闩。
  // pending 不依赖已被平台阶段删除的 PIN，直接继续全量擦除；
  // 当前进程无论成败都只允许重试或退出，禁止恢复业务运行态。
  var wipeStartupResult = await AppLockService.recoverPersistentWipeAtStartup(
    wallet: citizenSdk.wallet,
    accountSecurity: accountSecurity,
  );
  // Documents 暂时不可用时先在业务初始化前有界复查；只有连续失败才进入
  // 安全阻断页，不能要求用户通过强退重开代替正常的启动恢复。
  if (wipeStartupResult == AppDataWipeStartupResult.preflightBlocked) {
    for (final delay in <Duration>[
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 900),
    ]) {
      await Future<void>.delayed(delay);
      wipeStartupResult = await AppLockService.recoverPersistentWipeAtStartup(
        wallet: citizenSdk.wallet,
        accountSecurity: accountSecurity,
      );
      if (wipeStartupResult != AppDataWipeStartupResult.preflightBlocked) {
        break;
      }
    }
  }
  if (wipeStartupResult != AppDataWipeStartupResult.ready) {
    runApp(
      _DataWipeRecoveryApp(
        initialResult: wipeStartupResult,
        sdk: citizenSdk,
        accountSecurity: accountSecurity,
      ),
    );
    return;
  }

  // 普通认证和聊天惰性共用一个运行实例；擦除门闩通过前不创建MLS状态。
  readChatRuntime = () => sharedChatRuntime ??= createCitizenChatRuntime(
    accountSecurity: accountSecurity,
    currentUserContext: currentUserContext,
    squareSessionProvider: squareSessionProvider,
    appPushService: appPushService,
    onClosing: authentication.close,
  );

  // 钱包仍由唯一SDK拥有；轻节点启动不再成为本地页面显示的前置等待。
  final transactionHistory = WalletTransactionHistoryService(
    history: citizenSdk.history,
    chain: citizenSdk.chain,
    wallet: citizenSdk.wallet,
    events: citizenSdk.events,
  );
  // 擦除恢复及原安全前置已完成，聊天仍惰性创建；后台入口不负责启动钱包或节点。
  registerAppPushBackgroundHandler(chatRuntimeBackgroundHandler);

  // 诊断 — 把所有 framework / widget 静默吞掉的异常都打到 logcat。
  // 默认 ErrorWidget 在某些场景下表现为空白方块（白屏），这里换成显眼的红框 + 文字。
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    AppLog.d(
      '[FlutterError-Diag] library=${details.library} ctx=${details.context} '
      'exception=${details.exception}',
    );
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    AppLog.d(
      '[ErrorWidget-Diag] exception=${details.exception}\nstack=${details.stack}',
    );
    return Material(
      color: const Color(0xFFFFEEEE),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(12)),
        child: SingleChildScrollView(
          child: Text(
            'WIDGET ERROR:\n${details.exception}\n\n${details.stack}',
            style: TextStyle(
              color: const Color(0xFFB00020),
              fontSize: AppLayout.scaledValue(12),
            ),
          ),
        ),
      ),
    );
  };

  // 状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    CitizenApp(
      sdk: citizenSdk,
      startChain: () => citizenSdk.start(),
      registrationCoordinator: registrationCoordinator,
      identityService: identityService,
      accountSecurity: accountSecurity,
      currentUserContext: currentUserContext,
      finalizedIdentityResolver: finalizedIdentityResolver,
      cidBusinessGate: cidBusinessGate,
      squareSessionProvider: squareSessionProvider,
      squareApiClient: squareApiClient,
      appPushService: appPushService,
      transactionHistory: transactionHistory,
      chatRuntimeFactory: readChatRuntime,
      closeChatRuntime: () async {
        await sharedChatRuntime?.close();
      },
    ),
  );
}

/// 持久 pending marker 的唯一启动终态：不构造任何业务页面。
class _DataWipeRecoveryApp extends StatelessWidget {
  const _DataWipeRecoveryApp({
    required this.initialResult,
    required this.sdk,
    required this.accountSecurity,
  });

  final AppDataWipeStartupResult initialResult;
  final CitizenSdk sdk;
  final AccountSecurityService accountSecurity;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '公民',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _DataWipeRecoveryPage(
        initialResult: initialResult,
        sdk: sdk,
        accountSecurity: accountSecurity,
      ),
    );
  }
}

class _DataWipeRecoveryPage extends StatefulWidget {
  const _DataWipeRecoveryPage({
    required this.initialResult,
    required this.sdk,
    required this.accountSecurity,
  });

  final AppDataWipeStartupResult initialResult;
  final CitizenSdk sdk;
  final AccountSecurityService accountSecurity;

  @override
  State<_DataWipeRecoveryPage> createState() => _DataWipeRecoveryPageState();
}

class _DataWipeRecoveryPageState extends State<_DataWipeRecoveryPage> {
  late AppDataWipeStartupResult _result;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    // 擦除待重试时不再等待用户操作；完成态也立即退出，禁止停留在恢复页面重新进入业务流程。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_result == AppDataWipeStartupResult.retryRequired) {
        unawaited(_retryUntilComplete());
      } else if (_result == AppDataWipeStartupResult.dataWiped) {
        unawaited(SystemNavigator.pop());
      }
    });
  }

  Future<void> _retryUntilComplete() async {
    if (_retrying || _result != AppDataWipeStartupResult.retryRequired) return;
    setState(() => _retrying = true);
    await EmergencyWipePlatform.beginProtectedExecution();
    while (mounted) {
      try {
        await AppLockService.wipeAllData(
          wallet: widget.sdk.wallet,
          accountSecurity: widget.accountSecurity,
        );
        if (!mounted) return;
        setState(() => _result = AppDataWipeStartupResult.dataWiped);
        await EmergencyWipePlatform.finishProtectedExecution();
        await SystemNavigator.pop();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preflightBlocked =
        _result == AppDataWipeStartupResult.preflightBlocked;
    if (!preflightBlocked) {
      return const PopScope(
        canPop: false,
        child: ColoredBox(color: Colors.black),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber,
                  size: 56,
                  color: AppTheme.danger,
                ),
                const SizedBox(height: 20),
                const Text(
                  '安全状态无法确认',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  '应用不会擅自清理任何数据。请退出后重新启动。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('退出'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 当前默认账户是冷账户时，用 CitizenWallet 扫码签署同一MLS公钥的0x1C登记摘要。
Future<String> _signColdMlsDeviceBinding({
  required CitizenSdkWallet wallet,
  required CitizenSigning signing,
  required IdentityBinding binding,
  required Uint8List payload,
  required Uint8List signingMessage,
  required String publicKey,
  required int issuedAtMillis,
}) async {
  final account = (await wallet.getState().result).defaultAccount;
  if (account == null ||
      account.signMode != CitizenWalletSignMode.cold ||
      account.accountId != binding.accountId ||
      !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(publicKey)) {
    throw const AccountSecurityException('当前默认账户不是该 CID 的冷钱包账户');
  }
  final context = appNavigatorKey.currentContext;
  if (context == null) {
    throw const AccountSecurityException('当前页面无法发起冷钱包MLS登记签名');
  }
  if (!context.mounted) {
    throw const AccountSecurityException('当前页面已经关闭');
  }
  final signature = await signCitizenPayload(
    signing: signing,
    context: context,
    accountId: binding.accountId,
    payload: payload,
    action: CitizenQrActions.mlsDeviceBind,
    transform: CitizenSigningTransform.blake2Domain(
      Uint8List.fromList(<int>[...kGmbSignDomain, kOpSignMlsDeviceBind]),
    ),
  );
  final current = (await wallet.getState().result).defaultAccount;
  if (current == null ||
      current.signMode != CitizenWalletSignMode.cold ||
      current.accountId != binding.accountId ||
      !await CitizenSigning.verify(
        accountId: binding.accountId,
        signature: signature,
        payload: signingMessage,
      )) {
    throw const AccountSecurityException('冷钱包MLS登记签名无效');
  }
  return '0x${_lowerHex(signature)}';
}

String _lowerHex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
