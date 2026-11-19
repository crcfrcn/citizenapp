part of 'main.dart';

// App界面、生命周期和跨包装配由根App包唯一拥有。
class CitizenApp extends StatefulWidget {
  const CitizenApp({
    super.key,
    this.registrationCoordinator,
    this.identityService,
    this.startChain,
    this.stopSdk,
    this.closeSdk,
    this.sdkLifecycle,
    required this.sdk,
    required this.accountSecurity,
    required this.currentUserContext,
    required this.finalizedIdentityResolver,
    required this.cidBusinessGate,
    required this.squareSessionProvider,
    required this.squareApiClient,
    required this.appPushService,
    required this.transactionHistory,
  });

  final MyIdService? identityService;
  final Future<void> Function()? startChain;

  /// 根关闭的动作边界；缺省仍遵守同一SDK停止/检查点及关闭顺序。
  final Future<void> Function()? stopSdk;
  final Future<void> Function()? closeSdk;
  final CitizenSdkLifecycle Function()? sdkLifecycle;
  final RegistrationCoordinator? registrationCoordinator;
  final CitizenSdk sdk;
  final AccountSecurityService accountSecurity;
  final CurrentUserContext currentUserContext;
  final FinalizedIdentityResolver finalizedIdentityResolver;
  final CidBusinessGate cidBusinessGate;
  final SquareSessionProvider squareSessionProvider;
  final SquareApiClient squareApiClient;
  final AppPushService appPushService;
  final WalletTransactionHistoryService transactionHistory;

  @override
  State<CitizenApp> createState() => _CitizenAppState();
}

class _CitizenAppState extends State<CitizenApp> with WidgetsBindingObserver {
  Future<void> _chainStartup = Future<void>.value();
  bool _closing = false;
  StreamSubscription<CitizenSdkEvent>? _identityEvents;
  String? _identityAccount;
  bool _identityRetry = true;
  bool _identityRequested = false;
  Future<void>? _identitySync;
  late final _chainData = ChainDataService.forSdk(widget.sdk);
  String? _chainIdentityKey;
  void _onChainData() {
    if (_closing || _chainData.isStale) return;
    final value = _chainData.snapshot;
    if (value == null) return;
    final identity = value.own?.identity;
    final key = jsonEncode([
      value.accountId,
      value.ownCid,
      identity?.bindRev,
      identity?.votingIdentity,
      identity?.candidateIdentity,
    ]);
    if (_chainIdentityKey == key) return;
    _chainIdentityKey = key;
    _identityRetry = true;
    _requestIdentitySync();
  }

  final _topupUpdates = TopupUpdates();
  final _topupWallet = TopupWalletSession();
  final _topupPushSubs = <StreamSubscription<Map<String, dynamic>>>[];
  Future<void> _receiveTopupPush(Map<String, dynamic> data) async {
    try {
      final raw = data['citizen'] ?? data;
      if (raw is String && utf8.encode(raw).length > 4096) return;
      final payload = raw is String ? jsonDecode(raw) : raw;
      if (payload is Map<String, dynamic>) await _topupUpdates.receive(payload);
    } on Object {
      AppLog.d('topup_push_unavailable');
    }
  }

  /// 充值通知不要求CID；只读已有系统令牌，不新申请通知权限。
  Future<void> _refreshTopupNotify() async {
    try {
      final endpoint = await widget.appPushService
          .readToken(requestPermission: false)
          .timeout(const Duration(seconds: 2));
      if (_closing) return;
      _topupUpdates.notify = {
        'push_provider': endpoint.provider,
        'push_token': endpoint.token,
        'apns_env': endpoint.apnsEnvironment,
        'expires_at': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,
      };
    } on Object {
      AppLog.d('topup_push_unavailable');
    }
  }

  void _startTopupUpdates() {
    _topupUpdates.start();
    unawaited(_refreshTopupNotify());
    try {
      for (final stream in [
        widget.appPushService.foregroundMessages,
        widget.appPushService.openedMessages,
      ]) {
        _topupPushSubs.add(
          stream.listen((data) => unawaited(_receiveTopupPush(data))),
        );
      }
      unawaited(
        widget.appPushService
            .initialMessage(consume: false)
            .then((data) async {
              if (data != null) await _receiveTopupPush(data);
            })
            .catchError((Object _) {
              AppLog.d('topup_initial_push_unavailable');
            }),
      );
    } on Object {
      AppLog.d('topup_push_unavailable');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_closing) unawaited(_topupUpdates.resume());
    });
  }

  /// 身份生命周期只在账户变化或首次缺绑定时做公开同步。
  void _requestIdentitySync() {
    if (_closing || widget.identityService == null) return;
    _identityRequested = true;
    if (_identitySync != null) return;
    _identitySync = _synchronizeIdentity().whenComplete(() {
      _identitySync = null;
      if (_identityRequested && !_closing) _requestIdentitySync();
    });
  }

  Future<void> _synchronizeIdentity() async {
    while (_identityRequested && !_closing) {
      _identityRequested = false;
      try {
        final account =
            (await widget.sdk.getWalletState().result).defaultAccount;
        if (_closing) return;
        if (account == null) {
          _identityAccount = null;
          _identityRetry = true;
          widget.currentUserContext.invalidate();
          continue;
        }
        final changed = _identityAccount != account.accountId;
        if (changed) widget.currentUserContext.invalidate();
        await widget.currentUserContext.resolve();
        if (!changed && !_identityRetry) continue;
        _identityAccount = account.accountId;
        final state = await widget.identityService!.refreshState();
        _identityRetry =
            state.status == MyIdStatus.queryFailed ||
            state.status == MyIdStatus.unknown;
      } on Object {
        _identityRetry = true;
        AppLog.d('identity_sync_unavailable');
      }
    }
  }

  Future<void> _startChain() async {
    try {
      await widget.startChain?.call();
      if (!_closing) {
        // 身份同步不等待交易历史恢复；仍使用同一SDK和当前默认账户。
        _requestIdentitySync();
        await widget.transactionHistory.start();
        await _chainData.start();
      }
    } on Object {
      // 原生安全诊断归SDK；App不记录可能含业务数据的异常原文。
      AppLog.d('[CitizenSDK] chain_start_failed');
    }
  }

  Future<void> _stopSdk() async {
    _closing = true;
    _topupWallet.close();
    // 先停止接收；充值本地恢复不得成为SDK停止/checkpoint的前置门闩。
    final topupClose = _topupUpdates.close().catchError((Object _) {
      AppLog.d('topup_close_unavailable');
    });
    for (final sub in _topupPushSubs) {
      unawaited(
        sub.cancel().catchError((Object _) {
          AppLog.d('topup_push_close_unavailable');
        }),
      );
    }
    try {
      await _identityEvents?.cancel();
    } on Object {
      // 身份监听撤销失败也必须继续原SDK的有序关闭。
      AppLog.d('identity_listener_close_failed');
    }
    _chainData.removeListener(_onChainData);
    try {
      await _chainData.close();
    } on Object {
      AppLog.d('chain_data_close_unavailable');
    }
    await _chainStartup;
    await _identitySync;
    try {
      await _closeCitizenSdk(
        widget.sdk,
        widget.transactionHistory,
        stop: widget.stopSdk,
        close: widget.closeSdk,
        lifecycle: widget.sdkLifecycle,
      );
    } finally {
      await topupClose;
    }
  }

  late final _registrationCoordinator =
      widget.registrationCoordinator ?? RegistrationCoordinator();
  @override
  void initState() {
    super.initState();
    _chainData.addListener(_onChainData);
    _startTopupUpdates();
    WidgetsBinding.instance.addObserver(this);
    _identityEvents = widget.sdk.events.listen((event) {
      if (event is CitizenSdkWalletChanged ||
          ((event is CitizenSdkFinalizedBlockChanged ||
                  event is CitizenSdkCapabilitiesChanged) &&
              _identityRetry)) {
        _requestIdentitySync();
      }
    });
    _chainStartup = _startChain();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 系统授权造成的短暂 inactive 不终止同步；真正退后台才使迟到读取失效。
    if (state == AppLifecycleState.resumed) {
      _chainData.setForeground(true);
      unawaited(_refreshTopupNotify());
      unawaited(_topupUpdates.resume());
      widget.transactionHistory.setForeground(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _chainData.setForeground(false);
      widget.transactionHistory.setForeground(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.squareSessionProvider.closeAuthentication();
    _registrationCoordinator.api.close();
    widget.accountSecurity.dispose();
    unawaited(_stopSdk());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WalletNavigation>.value(value: walletNavigation),
        Provider<GovernanceNavigation>.value(value: governanceNavigation),
        Provider<TransactionNavigation>.value(value: transactionNavigation),
        Provider<UserNavigation>.value(
          value: UserNavigation(
            openTransfer: (context, {required cidNumber}) async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OnchainPaymentPage(initialRecipientCid: cidNumber),
                ),
              );
            },
          ),
        ),
        Provider<ScanDispatch>.value(value: const AppScanDispatch()),
        Provider<RegistrationCoordinator>.value(
          value: _registrationCoordinator,
        ),
        Provider<CitizenSdk>.value(value: widget.sdk),
        ChangeNotifierProvider<ChainDataService>.value(value: _chainData),
        if (widget.identityService != null)
          Provider<MyIdService>.value(value: widget.identityService!),
        Provider<AccountSecurityService>.value(value: widget.accountSecurity),
        Provider<CurrentUserContext>.value(value: widget.currentUserContext),
        Provider<FinalizedIdentityResolver>.value(
          value: widget.finalizedIdentityResolver,
        ),
        Provider<CidBusinessGate>.value(value: widget.cidBusinessGate),
        Provider<SquareSessionProvider>.value(
          value: widget.squareSessionProvider,
        ),
        Provider<SquareApiClient>.value(value: widget.squareApiClient),
        Provider<UserContactService>(
          create: (_) => UserContactService(
            accountSecurity: widget.accountSecurity,
            currentUserContext: widget.currentUserContext,
            sessionProvider: widget.squareSessionProvider,
            apiClient: widget.squareApiClient,
          ),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AppPushService>.value(value: widget.appPushService),
        Provider<TopupUpdates>.value(value: _topupUpdates),
        ChangeNotifierProvider<TopupWalletSession>.value(value: _topupWallet),
        Provider<WalletTransactionHistoryService>.value(
          value: widget.transactionHistory,
        ),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [chainBalanceRoutes],
        title: '公民',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // 只根据完整逻辑视口注入动态 UI 主题；不覆盖 MediaQuery。
        builder: (context, child) => Theme(
          data: AppTheme.lightThemeFor(context),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              Positioned(
                left: 0,
                bottom: 0,
                width: 1,
                height: 1,
                child: ListenableBuilder(
                  listenable: _topupWallet,
                  builder: (context, _) => _topupWallet.started
                      ? ExcludeSemantics(
                          child: IgnorePointer(
                            child: TopupWebviewPage(session: _topupWallet),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        home: const _AppLockGate(),
      ),
    );
  }
}

/// 按 CitizenSDK 的 checkpoint 合同先停止唯一轻节点，再释放 session。
///
/// App 生命周期回调不能等待 Future，因此调用方使用 [unawaited]；
/// 本函数内仍保证 stop 与 close 顺序，不用 close 绕过节点持久化。
Future<void> _closeCitizenSdk(
  CitizenSdk sdk,
  WalletTransactionHistoryService transactionHistory, {
  Future<void> Function()? stop,
  Future<void> Function()? close,
  CitizenSdkLifecycle Function()? lifecycle,
}) async {
  try {
    await transactionHistory.stop();
  } on Object catch (error, stackTrace) {
    // 业务监听停止失败不能跳过轻节点的checkpoint与关闭；分别保留真实失败记录。
    AppLog.d('[CitizenSDK] 交易监听停止失败: $error\n$stackTrace');
  }
  try {
    if ((lifecycle?.call() ?? sdk.lifecycle) == CitizenSdkLifecycle.running) {
      await (stop ?? sdk.stop)();
    }
  } on Object catch (error, stackTrace) {
    AppLog.d('[CitizenSDK] 轻节点停止失败: $error\n$stackTrace');
    return;
  }
  try {
    await (close ?? sdk.close)();
  } on Object catch (error, stackTrace) {
    AppLog.d('[CitizenSDK] session 关闭失败: $error\n$stackTrace');
  }
}

/// 应用锁入口：先检查 PIN 锁 → 再检查设备锁 → 进入主界面。
class _AppLockGate extends StatefulWidget {
  const _AppLockGate();

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate>
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _authenticated = false;
  bool _checking = true;
  bool _showDeviceLock = false;

  /// 后台超过此时长后回到前台需重新验证。
  static const Duration _sessionTimeout = Duration(minutes: 5);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _authenticated) {
      final paused = _pausedAt;
      if (paused != null &&
          DateTime.now().difference(paused) > _sessionTimeout) {
        AppLog.d('[AppLock] 后台超过 ${_sessionTimeout.inMinutes} 分钟,重锁入口');
        // 超时只重新锁定 App 入口（PIN/设备锁），不清会话签名密钥：
        // App 锁已拦住入口，会话密钥留到进程结束，避免每次重进都为发广场
        // 动态等低敏感操作重复生物识别。转账/投票/切换身份仍每次强制认证。
        setState(() {
          _authenticated = false;
          _checking = true;
          _showDeviceLock = false;
        });
        _checkLock();
      }
      _pausedAt = null;
    }
  }

  Future<void> _checkLock() async {
    // 1. 检查 PIN 锁
    final pinSet = await AppLockService.isPinSet();
    if (pinSet) {
      if (!mounted) return;
      setState(() => _checking = false);
      _showPinVerify();
      return;
    }

    // 2. 检查系统保护记录中的设备锁设置
    final deviceLockStr = await SystemProtectedRecordStore.lock.read(
      'device_lock_enabled',
    );
    final deviceLockEnabled = deviceLockStr == 'true';
    if (deviceLockEnabled) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showDeviceLock = true;
      });
      _authenticateDevice();
      return;
    }

    // 3. 无锁，直接进入
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _checking = false;
    });
  }

  Future<void> _showPinVerify() async {
    if (!mounted) return;
    // 诊断:定位"签名后多弹一次输入框"到底是谁 —— 若是本页,日志会给出时点。
    AppLog.d('[AppLock] 弹出 PIN 验证输入框');
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinInputPage(mode: PinInputMode.verify),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() => _authenticated = true);
    }
  }

  Future<void> _authenticateDevice() async {
    AppLog.d('[AppLock] 弹出设备锁验证');
    try {
      final success = await _localAuth.authenticate(
        localizedReason: BiometricAuthText.pick(
          zh: '请验证身份以进入应用',
          en: 'Verify your identity to open CitizenApp',
        ),
        authMessages: BiometricAuthText.messages(),
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      if (!mounted) return;
      if (success) {
        setState(() => _authenticated = true);
      }
    } catch (_) {
      // 认证失败，保持锁定状态
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: AppLayout.scaled(context, 24),
            height: AppLayout.scaled(context, 24),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primary,
            ),
          ),
        ),
      );
    }

    if (_authenticated) {
      // 账户门禁排在最后一环：任一热／冷账户均放行，目录为空才进入SDK唯一初始化页。
      return const AppPermissionGate(child: WalletGate(child: AppShell()));
    }

    if (_showDeviceLock) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppLayout.scaled(context, 80),
                height: AppLayout.scaled(context, 80),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(50),
                      blurRadius: AppLayout.scaled(context, 24),
                      offset: Offset(0, AppLayout.scaled(context, 8)),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: AppLayout.scaled(context, 36),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 32)),
              Text(
                '应用已锁定',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 22),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 8)),
              Text(
                '请验证身份以继续',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 40)),
              SizedBox(
                width: AppLayout.scaled(context, 200),
                child: FilledButton.icon(
                  onPressed: _authenticateDevice,
                  icon: Icon(
                    Icons.fingerprint,
                    size: AppLayout.scaled(context, 22),
                  ),
                  label: const Text('验证身份'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PIN 锁模式下，PinInputPage 已通过 Navigator 展示
    return Scaffold(
      body: Center(
        child: Container(
          width: AppLayout.scaled(context, 64),
          height: AppLayout.scaled(context, 64),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(16)),
          ),
          child: Icon(
            Icons.how_to_vote_outlined,
            color: Colors.white,
            size: AppLayout.scaled(context, 30),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.tabBuilder,
    this.openedPushData,
    this.initialPushDataLoader,
  });

  /// 测试只替换主页面，避免为了验证壳层懒加载而启动真实链、网络或数据库。
  @visibleForTesting
  final Widget Function(int tabIndex)? tabBuilder;

  /// 测试只注入 App 级“点击推送打开”数据；生产直接监听 Firebase。
  @visibleForTesting
  final Stream<Map<String, dynamic>>? openedPushData;

  /// 测试只注入冷启动推送；生产读取 Firebase 唯一 initial message。
  @visibleForTesting
  final Future<Map<String, dynamic>?> Function()? initialPushDataLoader;

  /// 主 Tab 的系统栏样式由壳层单源控制，避免保活页面留下上一页的明暗状态。
  ///
  /// 「我的」顶部是照片，使用浅色图标；其余主 Tab 都是浅色背景，必须使用深色
  /// 图标。子路由的 AppBar 仍可用更靠前的 AnnotatedRegion 覆盖本样式。
  static SystemUiOverlayStyle systemUiOverlayStyleForTab(int tabIndex) {
    final statusStyle = tabIndex == 3
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return statusStyle.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppTheme.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AccountSecurityService? _preparationSecurity;
  bool _preparationAttached = false;
  final AppUpdateController _updateController = AppUpdateController.instance;
  late final ValueNotifier<int> _selectedTab;
  int _currentIndex = 0;
  int _pendingVoteCount = 0;
  int _squareNotifyCount = 0;
  bool _isRooted = false;
  StreamSubscription<Map<String, dynamic>>? _pushOpenSub;
  StreamSubscription<AppPushToken>? _pushTokenSub;
  StreamSubscription<bool>? _contactNetworkSub;

  @override
  void initState() {
    super.initState();
    _selectedTab = ValueNotifier<int>(_currentIndex);
    Notifications.instance.addListener(_onSquareNotificationState);
    _squareNotifyCount = Notifications.instance.unread;
    _updateController.addListener(_handleUpdateStateChanged);
    _checkRootStatus();
    // 启动后异步检查 Release 更新，只更新设置页状态，不阻塞主界面进入。
    _updateController.check();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startPushOpenRouting());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparationAttached) return;
    _preparationAttached = true;
    final api = context.read<SquareApiClient?>(),
        sessions = context.read<SquareSessionProvider?>(),
        user = context.read<CurrentUserContext?>();
    if (api != null && sessions != null && user != null) {
      Notifications.instance.configure(
        api: api,
        sessions: sessions,
        user: user,
        push: context.read<AppPushService?>(),
      );
    }
    _contactNetworkSub = context
        .read<AppPushService?>()
        ?.networkAvailability
        .listen((available) {
          if (available && mounted) {
            unawaited(context.read<UserContactService?>()?.flushPending());
          }
        });
    _preparationSecurity = context.read<AccountSecurityService?>();
    _preparationSecurity?.revision.addListener(_onPreparationIdentityChanged);
    WidgetsBinding.instance.addObserver(this);
    _schedulePreparation();
  }

  void _onPreparationIdentityChanged() {
    Notifications.instance.invalidate();
    context.read<UserContactService?>()?.invalidate();
    _schedulePreparation();
  }

  void _schedulePreparation() {
    // 首帧和账户变更后异步消费唯一准备任务，不阻塞钱包、交易及链页面。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<SquareSessionProvider?>()?.resolveSession());
        unawaited(Notifications.instance.calibrate());
        unawaited(context.read<UserContactService?>()?.flushPending());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Notifications.instance.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _schedulePreparation();
      unawaited(Notifications.instance.calibrate(force: true));
    }
  }

  Future<void> _startPushOpenRouting() async {
    try {
      final injectedOpened = widget.openedPushData;
      if (injectedOpened != null) {
        _pushOpenSub = injectedOpened.listen(
          (data) => unawaited(_handleOpenedPushData(data)),
        );
        final initial = await widget.initialPushDataLoader?.call();
        if (initial != null) await _handleOpenedPushData(initial);
        return;
      }

      final appPush = context.read<AppPushService>();
      final endpoint = await appPush.initialize();
      await _registerCitizenServePush(endpoint);
      if (!mounted) return;
      _pushOpenSub = appPush.openedMessages.listen(
        (data) => unawaited(_handleOpenedPushData(data)),
      );
      _pushTokenSub = appPush.tokenChanges.listen(
        (token) => unawaited(_registerCitizenServePush(token)),
      );
      final initial = await appPush.initialMessage();
      if (initial != null) await _handleOpenedPushData(initial);
    } catch (error, stackTrace) {
      AppLog.d('[AppPush] 打开路由初始化失败: $error\n$stackTrace');
    }
  }

  Future<void> _handleOpenedPushData(Map<String, dynamic> data) async {
    if (!mounted) return;
    final Map<String, dynamic> payload;
    try {
      final raw = data['citizen'] ?? data;
      if (raw is String && utf8.encode(raw).length > 4096) return;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return;
      payload = decoded.cast<String, dynamic>();
    } on Object {
      return;
    }
    // 充值结果独立于广场CID认证，先验真并更新原行，不导航至广场。
    if (payload['kind'] == 'topup_result') return;
    await Notifications.instance.receive(data);
    if (!mounted) return;
    if (payload['post_id'] is String &&
        ['square_post', 'notification_state'].contains(payload['kind'])) {
      _openSquareTab();
      await openSquareNotification(
        context,
        postId: payload['post_id'] as String,
        commentId: payload['comment_id'] is String
            ? payload['comment_id'] as String
            : null,
      );
      return;
    }
    if (payload['kind'] == 'storage_cleanup') {
      _openSquareTab();
      return;
    }
  }

  Future<void> _registerCitizenServePush(AppPushToken endpoint) async {
    context.read<TopupUpdates?>()?.notify = {
      'push_provider': endpoint.provider,
      'push_token': endpoint.token,
      'apns_env': endpoint.apnsEnvironment,
      'expires_at': DateTime.now()
          .add(const Duration(days: 7))
          .millisecondsSinceEpoch,
    };
    try {
      final sessionProvider = context.read<SquareSessionProvider>();
      final client = context.read<SquareApiClient>();
      final session = await sessionProvider.ensureSession();
      if (session == null) return;
      await client.registerPushEndpoint(session: session, endpoint: endpoint);
    } catch (error, stackTrace) {
      // 普通通知是软功能；登记失败不得阻断主界面或广场读取，Token刷新会再次尝试。
      AppLog.d('[AppPush] CitizenServe端点登记失败: $error\n$stackTrace');
    }
  }

  void _openSquareTab() {
    if (!mounted || _currentIndex == 0) return;
    _selectedTab.value = 0;
    setState(() => _currentIndex = 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preparationSecurity?.revision.removeListener(
      _onPreparationIdentityChanged,
    );
    Notifications.instance.stop();
    unawaited(_contactNetworkSub?.cancel());
    _updateController.removeListener(_handleUpdateStateChanged);
    unawaited(_pushOpenSub?.cancel());
    unawaited(_pushTokenSub?.cancel());
    Notifications.instance.removeListener(_onSquareNotificationState);
    _selectedTab.dispose();
    super.dispose();
  }

  void _onSquareNotificationState() {
    if (mounted && _squareNotifyCount != Notifications.instance.unread) {
      setState(() => _squareNotifyCount = Notifications.instance.unread);
    }
  }

  void _handleUpdateStateChanged() {
    if (!mounted) return;
    // 我的页懒建缓存失效以刷新「设置有更新」红点。
    _tabCache[4] = null;
    setState(() {});
  }

  Future<void> _checkRootStatus() async {
    final rooted = await ScreenshotGuard.isDeviceRooted();
    if (!mounted) return;
    setState(() => _isRooted = rooted);
  }

  late final Widget _citizenPage = CitizenTabPage(
    onPendingVoteCountChanged: (count) {
      if (mounted && count != _pendingVoteCount) {
        setState(() => _pendingVoteCount = count);
      }
    },
  );

  /// 广场落地页（index 0）：发帖通知红点数经回调上抛到底部 tab；selectedTab
  /// 广播让广场在被切回时清广场红点（进广场清广场、关注红点另在关注子 tab 清）。
  late final Widget _squarePage = SquareTab(
    selectedTab: _selectedTab,
    tabIndex: 0,
    onSquareUnreadChanged: (count) {
      if (mounted && count != _squareNotifyCount) {
        setState(() => _squareNotifyCount = count);
      }
    },
  );

  /// 顶层 tab 懒建缓存：仅访问过的 index 建真页并由 IndexedStack 保活，未访问
  /// 的用占位，避免「打开即全建」把 42k 行政区同步 / 广场拉流等
  /// 全拖到启动。先开广场，其余点到才建立。
  static const int _tabCount = 4;
  final List<Widget?> _tabCache = List<Widget?>.filled(_tabCount, null);

  Widget _buildTab(int index) {
    final injected = widget.tabBuilder;
    if (injected != null) {
      return injected(index);
    }
    switch (index) {
      case 0:
        return _squarePage;
      case 1:
        return _citizenPage;
      case 2:
        return const TransactionTabPage();
      case 3:
        return MyTab(showSettingsUpdateDot: _updateController.state.hasUpdate);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 当前页按需建入缓存并保活，未访问的页用占位，避免启动即全建。
  List<Widget> _lazyPages() {
    _tabCache[_currentIndex] ??= _buildTab(_currentIndex);
    return List<Widget>.generate(
      _tabCount,
      (i) => ChainBalanceVisibility(
        active: i == _currentIndex,
        child: _tabCache[i] ?? const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      body: Column(
        children: [
          if (_isRooted)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaled(context, 12),
                vertical: AppLayout.scaled(context, 10),
              ),
              decoration: AppTheme.bannerDecoration(AppTheme.danger),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: AppTheme.danger,
                      size: AppLayout.scaled(context, 18),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 8)),
                    Expanded(
                      child: Text(
                        '检测到设备已 root/越狱，密钥安全无法保障',
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontSize: AppLayout.scaled(context, 13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _lazyPages()),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceCard,
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: NavigationBar(
          // 只补充放大后导航文字需要的高度，图标、边距和指示器保持结构令牌尺寸。
          height: AppLayout.navigationBarHeight(context),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            // IndexedStack 会保活旧页面，因此必须额外广播唯一活动 Tab；
            _selectedTab.value = index;
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _squareNotifyCount > 0,
                label: Text(
                  _squareNotifyCount > 99 ? '99+' : '$_squareNotifyCount',
                  style: TextStyle(fontSize: AppLayout.scaled(context, 10)),
                ),
                child: SvgPicture.asset(
                  'packages/citizen_assets/icons/tank.svg',
                  width: AppLayout.scaled(context, 26),
                  height: AppLayout.scaled(context, 26),
                  colorFilter: const ColorFilter.mode(
                    AppTheme.textTertiary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              selectedIcon: Badge(
                isLabelVisible: _squareNotifyCount > 0,
                label: Text(
                  _squareNotifyCount > 99 ? '99+' : '$_squareNotifyCount',
                  style: TextStyle(fontSize: AppLayout.scaled(context, 10)),
                ),
                child: SvgPicture.asset(
                  'packages/citizen_assets/icons/tank.svg',
                  width: AppLayout.scaled(context, 26),
                  height: AppLayout.scaled(context, 26),
                  colorFilter: const ColorFilter.mode(
                    AppTheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              label: '广场',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _pendingVoteCount > 0,
                label: Text(
                  '$_pendingVoteCount',
                  style: TextStyle(fontSize: AppLayout.scaled(context, 10)),
                ),
                child: const Icon(Icons.how_to_vote_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _pendingVoteCount > 0,
                label: Text(
                  '$_pendingVoteCount',
                  style: TextStyle(fontSize: AppLayout.scaled(context, 10)),
                ),
                child: const Icon(Icons.how_to_vote),
              ),
              label: '公民',
            ),
            NavigationDestination(
              icon: SvgPicture.asset(
                'packages/citizen_assets/icons/scale.svg',
                width: AppLayout.scaled(context, 22),
                height: AppLayout.scaled(context, 22),
                colorFilter: const ColorFilter.mode(
                  AppTheme.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
              selectedIcon: SvgPicture.asset(
                'packages/citizen_assets/icons/scale.svg',
                width: AppLayout.scaled(context, 22),
                height: AppLayout.scaled(context, 22),
                colorFilter: const ColorFilter.mode(
                  AppTheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              label: '交易',
            ),
            NavigationDestination(
              icon: UpdateDotBadge(
                show: _updateController.state.hasUpdate,
                dotKey: const Key('my-tab-update-dot'),
                child: const Icon(Icons.person_outline),
              ),
              selectedIcon: UpdateDotBadge(
                show: _updateController.state.hasUpdate,
                dotKey: const Key('my-tab-selected-update-dot'),
                child: const Icon(Icons.person),
              ),
              label: '我的',
            ),
          ],
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('app-shell-system-ui-style'),
      value: AppShell.systemUiOverlayStyleForTab(_currentIndex),
      child: scaffold,
    );
  }
}
