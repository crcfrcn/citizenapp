part of '../chat.dart';

/// 聊天页加号菜单 5 个动作的可注入入口。
///
/// 默认全为 null，各动作走真实实现；测试整体替换后即可断言路由，
/// 而不会真的拉起相机、建群页或通讯录（它们会触发 Isar / ChatRuntime / 相机）。
class ChatEntryOpeners {
  const ChatEntryOpeners({
    this.openScan,
    this.openReceivePay,
    this.openSendMessage,
    this.openCreateGroup,
    this.openAddFriend,
  });

  /// 扫一扫 = 交易·扫一扫统一分派（扫到用户码按收款人进入转账）。
  final ChatEntryOpener? openScan;

  /// 收付款 = 展示本账户账户码（收款码 `k=4` 生成方待实现）。
  final ChatEntryOpener? openReceivePay;

  /// 发私信 = 通讯录单选后直开私聊。
  final ChatEntryOpener? openSendMessage;

  /// 发群聊 = 通讯录多选（≥2 人）建群。
  final ChatEntryOpener? openCreateGroup;

  /// 加好友 = 扫对方二维码写入本人通讯录。
  final ChatEntryOpener? openAddFriend;
}

/// 加号菜单单个动作的入口签名；默认钱包等依赖一律由真实实现内部解析，
/// 注入替身时不触碰 CitizenSDK 钱包、Isar 或相机。
typedef ChatEntryOpener = Future<void> Function(BuildContext context);

/// 公民“聊天”Tab。
///
/// 顶部为搜索框（进入 [ChatSearchPage]），右上角加号弹出 5 个入口：
/// 扫一扫 / 收付款 / 发私信 / 发群聊 / 加好友。会话列表在其下方。
class ChatTab extends StatefulWidget {
  ChatTab({
    super.key,
    ChatStore? store,
    this.wallet,
    this.cidNumber,
    this.accountId,
    required this.runtime,
    this.selectedTab,
    this.tabIndex = 2,
    this.openers,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
    this.contactService,
    this.subscriptionService,
  }) : store = store ?? runtime.store;

  /// 生产固定使用同一 ChatRuntime 的 Store；显式值只用于不启动原生运行时的组件测试。
  final ChatStore store;
  final CitizenSdk? wallet;
  final String? cidNumber;
  final String? accountId;
  final ChatRuntime runtime;
  final ValueListenable<int>? selectedTab;
  final int tabIndex;

  /// 加号菜单动作入口；仅测试注入，正式运行为 null 走真实实现。
  final ChatEntryOpeners? openers;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;
  final UserContactService? contactService;
  final SubscriptionService? subscriptionService;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<ChatConversationPreview> _conversations = const [];
  // 用户确认删除后先从所有页面读取结果中屏蔽该会话；物理清理即使仍在
  // 等待文件 lease，轮询、Realtime 或路由返回重载也不得把卡片重新插回。
  final Set<String> _conversationDeletesInFlight = <String>{};
  late final CitizenProfileCache _profileCache =
      widget.profileCache ?? const CitizenProfileCache();
  late final CitizenProfileMediaCache _profileMediaCache =
      widget.profileMediaCache ?? CitizenProfileMediaCache();
  SquareSessionProvider? _sessionProvider;
  SubscriptionService? _subscriptionService;
  UserContactService? _contactService;
  CitizenSdk? _wallet;
  AccountSecurityService? _accountSecurity;
  CurrentUserContext? _currentUserContext;
  bool _dependenciesReady = false;
  final Map<String, CitizenProfile> _peerProfiles = <String, CitizenProfile>{};
  final Map<String, CitizenProfileMediaSnapshot> _peerProfileMedia =
      <String, CitizenProfileMediaSnapshot>{};
  final Set<String> _resolvedPeerCidNumbers = <String>{};
  final Map<String, String> _peerContactRemarks = <String, String>{};
  SquareSession? _chatSession;
  String _cidNumber = '';
  String _accountId = '';
  bool _loading = true;
  String? _error;

  late ChatConversationListController _listController;
  int _controllerGeneration = 0, _identityProbe = 0, _cacheSequence = 0;
  bool _checkingIdentity = false;
  final _profileRequests = <String, int>{};

  bool get _isTabSelected =>
      widget.selectedTab == null ||
      widget.selectedTab!.value == widget.tabIndex;

  bool get _isActive => _listController.isActive;

  @override
  void initState() {
    super.initState();
    _createListController();
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    widget.selectedTab?.addListener(_onSelectedTabChanged);
    CitizenProfileCache.revision.addListener(_onProfileRevision);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCoordinate());
  }

  void _createListController() {
    final generation = ++_controllerGeneration;
    _listController = ChatConversationListController(
      runtime: widget.runtime,
      onCoordinate: () => _reload(syncFirst: true),
      onRefresh: (account) => _syncAndRefresh(account, generation),
    );
    _listController.start(visible: _isTabSelected);
  }

  void _resetScope() {
    _reloadGeneration++;
    _listController.dispose();
    _createListController();
    _conversations = const [];
    _peerProfiles.clear();
    _peerProfileMedia.clear();
    _resolvedPeerCidNumbers.clear();
    _profileRequests.clear();
    _peerContactRemarks.clear();
    _conversationDeletesInFlight.clear();
    _chatSession = null;
    _cidNumber = '';
    _accountId = '';
    _loading = true;
    _error = null;
  }

  bool _displayCurrent(int generation, String cid, String account) =>
      mounted &&
      !_checkingIdentity &&
      generation == _reloadGeneration &&
      cid == _cidNumber &&
      account == _accountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    if (widget.cidNumber != null && widget.accountId != null) {
      _wallet = widget.wallet;
      _sessionProvider = widget.sessionProvider;
      _subscriptionService = widget.subscriptionService;
      _contactService = widget.contactService;
      _dependenciesReady = true;
      return;
    }
    final runtime = context.read<CitizenSdk>();
    final accountSecurity = context.read<AccountSecurityService>();
    final currentUserContext = context.read<CurrentUserContext>();
    _currentUserContext = currentUserContext;
    final identityResolver = context.read<FinalizedIdentityResolver>();
    _wallet = widget.wallet ?? runtime;
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    _subscriptionService =
        widget.subscriptionService ??
        SubscriptionService(
          chainData: context.read<ChainDataService?>(),
          wallet: _wallet!,
          chain: runtime,
          transactions: runtime,
          identityResolver: identityResolver,
        );
    _contactService =
        widget.contactService ??
        context.read<UserContactService?>() ??
        UserContactService(
          accountSecurity: accountSecurity,
          currentUserContext: currentUserContext,
          sessionProvider: _sessionProvider!,
        );
    _accountSecurity = accountSecurity;
    accountSecurity.revision.addListener(_onWalletsChanged);
    _dependenciesReady = true;
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      oldWidget.selectedTab?.removeListener(_onSelectedTabChanged);
      widget.selectedTab?.addListener(_onSelectedTabChanged);
    }
    if (oldWidget.cidNumber != widget.cidNumber ||
        oldWidget.accountId != widget.accountId ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.store != widget.store) {
      _identityProbe++;
      _checkingIdentity = false;
      _resetScope();
      _sessionProvider = widget.sessionProvider ?? _sessionProvider;
      _subscriptionService = widget.subscriptionService ?? _subscriptionService;
      _contactService = widget.contactService ?? _contactService;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestCoordinate();
      });
    }
    _onSelectedTabChanged();
  }

  @override
  void dispose() {
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    CitizenProfileCache.revision.removeListener(_onProfileRevision);
    _accountSecurity?.revision.removeListener(_onWalletsChanged);
    widget.selectedTab?.removeListener(_onSelectedTabChanged);
    _listController.dispose();
    super.dispose();
  }

  void _onMembershipChanged() {
    final event = MembershipRevision.instance.listenable.value;
    if (mounted && event != null && event.cidNumber == _cidNumber) {
      setState(() {});
    }
  }

  void _onProfileRevision() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event == null) return;
    final matches = _conversations.any(
      (preview) => !preview.isGroup && preview.peerUserId == event.cidNumber,
    );
    if (!matches) return;
    unawaited(_readCachedPeerProfiles(_conversations, force: true));
  }

  void _onSelectedTabChanged() {
    _listController.setVisible(_isTabSelected);
    if (_isActive) {
      _requestCoordinate();
    } else {
      _pauseSync();
    }
  }

  /// init、进入 Tab、App resume 全部汇入同一个 coordinator；同一时刻只允许
  /// 一个 reload/sync 链，避免系统 UI 导致 lifecycle 抖动时重复初始化。
  void _requestCoordinate() => _listController.requestCoordinate();

  Future<void> _onWalletsChanged() async {
    final probe = ++_identityProbe;
    setState(() => _checkingIdentity = true);
    try {
      final identity = await _readIdentity();
      if (!mounted || probe != _identityProbe) return;
      if (identity.accountId == _accountId &&
          identity.cidNumber == _cidNumber) {
        return;
      }
      final previous = _accountId;
      setState(_resetScope);
      if (previous.isNotEmpty) await widget.runtime.invalidateAccount(previous);
      if (!mounted || probe != _identityProbe) return;
      _checkingIdentity = false;
      _requestCoordinate();
    } on Object catch (error) {
      if (mounted && probe == _identityProbe) {
        setState(() {
          _resetScope();
          _loading = false;
          _error = chatUserErrorMessage(error);
        });
      }
    } finally {
      if (mounted && probe == _identityProbe) {
        setState(() => _checkingIdentity = false);
      }
    }
  }

  /// 本地加载世代号。切默认钱包后并发 reload 乱序完成时，旧身份不得覆写
  /// 新身份；网络与 MLS 后台任务由 聊天列表控制器的内部世代隔离。
  int _reloadGeneration = 0;

  List<ChatConversationPreview> _withoutDeletingConversations(
    Iterable<ChatConversationPreview> conversations,
  ) => conversations
      .where(
        (preview) =>
            !_conversationDeletesInFlight.contains(preview.conversationId),
      )
      .toList(growable: false);

  Future<void> _reload({bool syncFirst = false}) async {
    if (!_isActive) {
      return;
    }
    final generation = ++_reloadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    String? serviceAccountId;
    String? serviceCidNumber;
    try {
      final identity = await _readIdentity();
      final activeWallet = widget.accountId ?? identity.accountId;
      final ownerUserId = widget.cidNumber ?? identity.cidNumber;
      if (!_isActive) {
        return;
      }
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        if (_cidNumber != ownerUserId || _accountId != activeWallet) {
          _conversations = const [];
          _peerContactRemarks.clear();
          _peerProfiles.clear();
          _peerProfileMedia.clear();
          _resolvedPeerCidNumbers.clear();
          _profileRequests.clear();
        }
        _cidNumber = ownerUserId;
        _accountId = activeWallet;
      });
      unawaited(_ensureChatEntitlement(ownerUserId, generation));
      if (ownerUserId.isEmpty) {
        // 默认账户未注册 CID 是合法状态；禁止回退到其他账户，必须在此
        // 短路。会话存储读取第一步就要解析密钥绑定,对未注册身份必抛
        // AccountSecurityException,catch 成 _error 横幅后会盖住注册引导;轮询/realtime
        // 同样是注定失败的空转。渲染层 `_cidNumber.isEmpty` 分支显示统一注册引导。
        _pauseSync();
        return;
      }
      // 本地阶段只读 ChatIsar。发送队列、Realtime、MLS、FCM 与唤醒端点
      // 全部在本地结果显示后静默执行，不得延长本地加载提示。
      final conversations = await widget.store.readConversationPreviews(
        ownerUserId: ownerUserId,
        currentAccountId: activeWallet,
      );
      if (!mounted || !_isActive || generation != _reloadGeneration) {
        return;
      }
      final visible = _withoutDeletingConversations(conversations);
      setState(() {
        _conversations = visible;
      });
      unawaited(_hydratePeerProfiles(visible));
      if (activeWallet.isNotEmpty) {
        serviceAccountId = activeWallet;
        serviceCidNumber = ownerUserId;
      }
    } catch (error) {
      if (mounted && generation == _reloadGeneration) {
        setState(() {
          // 本机缺绑定使用已知闭集身份提示，未知底层异常仍走原脱敏文案。
          _error =
              error is SquareApiException &&
                  error.errorCode == 'identity_local_missing'
              ? SquareSessionResolution.fromError(error).message
              : chatUserErrorMessage(error);
        });
      }
    } finally {
      if (mounted && generation == _reloadGeneration) {
        setState(() {
          _loading = false;
        });
      }
    }
    if (serviceAccountId != null && serviceCidNumber != null) {
      if (syncFirst) {
        _listController.synchronizeScope(serviceAccountId);
      } else if (mounted && _isActive && generation == _reloadGeneration) {
        // 二级页返回只需恢复既有轮询/Realtime，不重复执行首次补发链。
        _configurePolling(serviceAccountId);
      }
    }
  }

  /// 打开聊天复用普通会话；附件动作单独读取服务端资源许可。
  Future<void> _ensureChatEntitlement(
    String cidNumber,
    int reloadGeneration,
  ) async {
    if (cidNumber.isEmpty) return;
    final sessionProvider = _sessionProvider;
    if (sessionProvider == null || _subscriptionService == null) return;
    if (!mounted ||
        reloadGeneration != _reloadGeneration ||
        cidNumber != _cidNumber) {
      return;
    }
    try {
      final session = _chatSession ?? await sessionProvider.ensureSession();
      if (!mounted ||
          reloadGeneration != _reloadGeneration ||
          cidNumber != _cidNumber ||
          session == null ||
          session.cidNumber.trim() != cidNumber) {
        return;
      }
      await session.validateCurrent();
      if (!mounted ||
          reloadGeneration != _reloadGeneration ||
          cidNumber != _cidNumber) {
        return;
      }
      _chatSession = session;
      SubscriptionService.rememberCitizenSession(session);
      // 打开聊天只登记基础会话；首次附件动作由聊天模块异步钩子取得唯一会员缓存。
    } on Exception {
      // 基础会话失败不读取会员；保留离线展示，服务端仍最终核验会话。
    }
    if (mounted &&
        reloadGeneration == _reloadGeneration &&
        cidNumber == _cidNumber) {
      setState(() {});
    }
  }

  /// 本地首屏完成后静默收敛聊天服务。该 Future 不进入页面 loading/error，
  /// 服务失败时保留已经显示的本地列表，由后续轮询或下一次进入页面重试。
  Iterable<String> _directPeerCidNumbers(
    List<ChatConversationPreview> conversations,
  ) sync* {
    final seen = <String>{};
    for (final preview in conversations) {
      final cidNumber = preview.peerUserId.trim();
      if (!preview.isGroup && cidNumber.isNotEmpty && seen.add(cidNumber)) {
        yield cidNumber;
      }
    }
  }

  /// Chat UI 只按 CID 联合读取 UserIsar 公开资料；不会向 ChatIsar 增加头像、昵称或会员列。
  Future<void> _readCachedPeerProfiles(
    List<ChatConversationPreview> conversations, {
    bool force = false,
  }) async {
    final generation = _reloadGeneration,
        owner = _cidNumber,
        account = _accountId;
    final profiles = widget.profileCache ?? _profileCache;
    final mediaCache = widget.profileMediaCache ?? _profileMediaCache;
    await Future.wait(
      _directPeerCidNumbers(conversations).map((peer) async {
        if (!force && _resolvedPeerCidNumbers.contains(peer)) return;
        final request = ++_cacheSequence;
        _profileRequests[peer] = request;
        try {
          final profile = await profiles.read(peer);
          if (profile == null ||
              profile.cidNumber != peer ||
              !_displayCurrent(generation, owner, account) ||
              _profileRequests[peer] != request) {
            return;
          }
          final media = await mediaCache.read(profile);
          if (!_displayCurrent(generation, owner, account) ||
              _profileRequests[peer] != request) {
            return;
          }
          final previous = _peerProfiles[peer];
          if (previous != null && previous.profileAt > profile.profileAt) {
            return;
          }
          _peerProfiles[peer] = profile;
          _peerProfileMedia[peer] = media;
          _resolvedPeerCidNumbers.add(peer);
        } on Object {
          /* 单个本地资料故障不阻塞本机消息列表。 */
        }
      }),
    );
    if (force && _displayCurrent(generation, owner, account)) setState(() {});
  }

  /// 会话标题先用 ChatIsar 已有预览立即显示；公开资料缓存随后把中性头像替换为真实
  /// 头像。缓存读取失败不能阻塞聊天列表，也不触发远端补取。
  Future<void> _hydratePeerProfiles(
    List<ChatConversationPreview> conversations,
  ) async {
    final generation = _reloadGeneration,
        owner = _cidNumber,
        account = _accountId;
    unawaited(_hydrateContactRemarks(conversations));
    try {
      await _readCachedPeerProfiles(conversations);
      if (_displayCurrent(generation, owner, account)) setState(() {});
    } on Exception {
      // 公开资料是 Chat UI 的联合展示数据；失败不影响加密会话本身。
    }
  }

  /// 通讯录备注是本机私人数据，只与当前 CID 下的直接会话联合展示。读取失败不阻塞
  /// ChatIsar 首屏，也不允许用 CID 代替昵称回退到界面。
  Future<void> _hydrateContactRemarks(
    List<ChatConversationPreview> conversations,
  ) async {
    final ownerUserId = _cidNumber,
        generation = _reloadGeneration,
        account = _accountId;
    if (ownerUserId.isEmpty) return;
    final contactService = _contactService;
    if (contactService == null) return;
    final peers = _directPeerCidNumbers(conversations).toSet();
    try {
      final contacts = await contactService.getContacts();
      if (!_displayCurrent(generation, ownerUserId, account)) return;
      final remarks = <String, String>{
        for (final contact in contacts)
          if (peers.contains(contact.cidNumber) &&
              contact.contactRemark.trim().isNotEmpty)
            contact.cidNumber: contact.contactRemark.trim(),
      };
      setState(() {
        _peerContactRemarks
          ..removeWhere((cidNumber, _) => peers.contains(cidNumber))
          ..addAll(remarks);
      });
    } on Exception {
      // 通讯录不可用不影响消息收发；卡片继续显示公开昵称或稳定默认昵称。
    }
  }

  void _configurePolling(String activeWallet) {
    if (!_isActive || activeWallet.isEmpty) {
      _pauseSync();
      return;
    }
    _listController.configureScope(activeWallet);
  }

  Future<bool> _syncAndRefresh(
    String accountId,
    int controllerGeneration,
  ) async {
    final generation = _reloadGeneration, owner = _cidNumber;
    if (controllerGeneration != _controllerGeneration) return false;
    if (!_isActive || _accountId != accountId) return false;
    final conversations = await widget.store.readConversationPreviews(
      ownerUserId: _cidNumber,
      currentAccountId: accountId,
    );
    if (!_displayCurrent(generation, owner, accountId) ||
        !_isActive ||
        controllerGeneration != _controllerGeneration) {
      return false;
    }
    final visible = _withoutDeletingConversations(conversations);
    setState(() {
      _conversations = visible;
    });
    unawaited(_hydratePeerProfiles(visible));
    return true;
  }

  void _pauseSync() {
    _listController.pause();
  }

  Future<({String cidNumber, String accountId})> _readIdentity() async {
    if (widget.cidNumber != null && widget.accountId != null) {
      return (cidNumber: widget.cidNumber!, accountId: widget.accountId!);
    }
    final currentUserContext = _currentUserContext;
    if (currentUserContext != null) {
      // 根准备与页面复用同一CID事实门禁；读取失败不能冒充没有公民号。
      final decision = await context.read<CidBusinessGate?>()?.resolve();
      if (decision?.status == CidBusinessStatus.unavailable) {
        throw const SquareApiException(
          '身份读取失败，请重试',
          errorCode: 'identity_projection_unavailable',
        );
      }
      return _resolveChatIdentity(currentUserContext);
    }
    final current = await widget.runtime.readCurrentUser();
    return (cidNumber: current.userId, accountId: current.accountId);
  }

  Future<void> _deleteLocalConversation(String conversationId) {
    return widget.runtime.deleteLocalConversation(conversationId);
  }

  /// 逻辑删除先于物理删除完成：调用本方法的同步阶段立刻移除卡片并登记过滤，
  /// 返回的 Future 只代表后台 Store/附件清理。成功后解除过滤；失败才恢复
  /// 本地真值并显示错误，不能让页面因等待内部锁而停在不可操作状态。
  Future<void> _deleteConversationInBackground(String conversationId) async {
    final generation = _controllerGeneration,
        cid = _cidNumber,
        account = _accountId;
    bool current() =>
        mounted &&
        generation == _controllerGeneration &&
        cid == _cidNumber &&
        account == _accountId;
    if (!_conversationDeletesInFlight.add(conversationId)) return;
    setState(() {
      _conversations = _conversations
          .where((item) => item.conversationId != conversationId)
          .toList(growable: false);
      _error = null;
    });
    try {
      await _deleteLocalConversation(conversationId);
      if (!current()) return;
      if (!_checkingIdentity) await _reload();
      if (current()) _conversationDeletesInFlight.remove(conversationId);
    } catch (error) {
      if (!current()) return;
      _conversationDeletesInFlight.remove(conversationId);
      if (!_checkingIdentity) await _reload();
      if (current() && !_checkingIdentity) {
        setState(() => _error = chatUserErrorMessage(error));
      }
    }
  }

  Future<void> _confirmAndDeleteConversation(
    ChatConversationPreview preview,
  ) async {
    final generation = _controllerGeneration,
        cid = _cidNumber,
        account = _accountId;
    final confirmed = await _confirmDeleteConversationList(context);
    if (!confirmed ||
        !mounted ||
        _checkingIdentity ||
        generation != _controllerGeneration ||
        cid != _cidNumber ||
        account != _accountId) {
      return;
    }
    unawaited(_deleteConversationInBackground(preview.conversationId));
  }

  void _openConversation(ChatConversationPreview preview) {
    if (!_requireChatIdentity()) return;
    if (preview.isGroup) {
      openGroupChat(
        context,
        groupId: preview.conversationId,
        title: preview.title,
        onDeleteConversation: () =>
            _deleteConversationInBackground(preview.conversationId),
      ).then((_) => _reload());
      return;
    }
    _openDirectConversation(preview);
  }

  void _openCreateGroup() {
    if (!_requireChatIdentity()) return;
    final opener = widget.openers?.openCreateGroup;
    if (opener != null) {
      unawaited(opener(context));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GroupCreatePage()))
        .then((_) => _reload());
  }

  /// 没有默认钱包账户时统一提示并拦截；冷热钱包均可作为当前账户。
  bool _requireAccount() {
    if (_checkingIdentity) return false;
    if (_accountId.isEmpty) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return false;
    }
    return true;
  }

  /// 聊天业务先由公民号门禁判定；私信、群聊、加好友动作继续复核账户与 CID。
  ///
  /// 未注册时只保留页面内统一注册引导；动作不得绕过引导直接弹注册面板。
  bool _requireChatIdentity() {
    if (!_requireAccount()) return false;
    if (_cidNumber.isEmpty) {
      _requestCoordinate();
      return false;
    }
    return true;
  }

  /// 加号菜单动作分派。
  Future<void> _onEntryAction(_ChatEntryAction action) async {
    switch (action) {
      case _ChatEntryAction.scan:
        await _openScan();
      case _ChatEntryAction.receivePay:
        await _openReceivePay();
      case _ChatEntryAction.sendMessage:
        await _openSendMessage();
      case _ChatEntryAction.createGroup:
        _openCreateGroup();
      case _ChatEntryAction.addFriend:
        await _openAddFriend();
    }
  }

  /// 扫一扫 = 交易·扫一扫统一分派；扫到用户码按收款人进入转账。
  Future<void> _openScan() async {
    final opener = widget.openers?.openScan;
    if (opener != null) {
      await opener(context);
      return;
    }
    final walletPort = _wallet;
    if (walletPort == null) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return;
    }
    final wallet = (await walletPort.getWalletState().result).defaultAccount;
    if (!mounted) return;
    await context.read<ScanDispatch>().openScanDispatchFlow(
      context: context,
      paymentWallet: wallet,
    );
  }

  /// 收付款 = 展示本账户账户码（`k=5`），他人扫码后按账户向我转账。
  ///
  /// 本入口最终归属是收款码（`k=4`，带金额与备注、临时有效），当前其生成方尚未实现，
  /// 暂出账户码；收款码落地时只切这一处，码型契约由共享 QR registry 固定。
  Future<void> _openReceivePay() async {
    if (!_requireAccount()) return;
    final opener = widget.openers?.openReceivePay;
    if (opener != null) {
      await opener(context);
      return;
    }
    final walletPort = _wallet;
    if (walletPort == null) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return;
    }
    final wallet = (await walletPort.getWalletState().result).defaultAccount;
    if (!mounted) return;
    if (wallet == null) {
      setState(() => _error = '请先在「我的 → 我的钱包」添加钱包账户');
      return;
    }
    await showWalletQrDialog(
      context,
      accountId: wallet.accountId,
      accountName: wallet.name,
    );
  }

  /// 发私信 = 通讯录单选，点联系人直接开私聊。
  Future<void> _openSendMessage() async {
    if (!_requireChatIdentity()) return;
    final opener = widget.openers?.openSendMessage;
    if (opener != null) {
      await opener(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ContactBookPage(mode: ContactPickMode.pickForMessage),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  /// 加好友 = 扫对方二维码写入本人密文通讯录。
  Future<void> _openAddFriend() async {
    if (!_requireChatIdentity()) return;
    final opener = widget.openers?.openAddFriend;
    if (opener != null) {
      await opener(context);
      return;
    }
    await scanAndAddContact(context);
  }

  /// 搜索 = 进入独立搜索页；透传 store 与账户，避免搜索页重复解析依赖。
  Future<void> _openSearch() async {
    if (!_requireChatIdentity()) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatSearchPage(
          store: widget.store,
          cidNumber: _cidNumber,
          accountId: _accountId,
          contactService: _contactService,
        ),
      ),
    );
  }

  void _openGroupManage(ChatConversationPreview preview) {
    if (!_requireChatIdentity()) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GroupManagePage(
              groupId: preview.conversationId,
              cidNumber: _cidNumber,
            ),
          ),
        )
        .then((_) => _reload());
  }

  void _openDirectConversation(ChatConversationPreview preview) {
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ChatConversationPage(
                conversationId: ChatRuntime.directConversationId(
                  _cidNumber,
                  preview.peerUserId,
                ),
                runtime: widget.runtime,
                initialProfile: _peerProfiles[preview.peerUserId],
                initialProfileMedia: _peerProfileMedia[preview.peerUserId],
                profileApi: widget.profileApi,
                profileCache: _profileCache,
                profileMediaCache: _profileMediaCache,
                sessionProvider: _sessionProvider,

                currentUserId: _cidNumber,
                accountId: _accountId,
                peerUserId: preview.peerUserId,
                title: preview.title,
                onDeleteConversation: () =>
                    _deleteConversationInBackground(preview.conversationId),
              ),
            ),
          )
          .then((_) => _reload()),
    );
  }

  ChatConversationListItem _conversationItem(
    BuildContext context,
    ChatConversationPreview preview,
  ) {
    final profile = _peerProfiles[preview.peerUserId];
    final media = _peerProfileMedia[preview.peerUserId];
    final resolved = _resolvedPeerCidNumbers.contains(preview.peerUserId);
    final publicName = preview.isGroup
        ? preview.title
        : ProfilePresentation.forIdentityKey(
            preview.peerUserId,
          ).resolveDisplayName(
            publicName: profile?.displayName ?? preview.title,
          );
    final remark = _peerContactRemarks[preview.peerUserId]?.trim() ?? '';
    final title = !preview.isGroup && remark.isNotEmpty
        ? '$remark（$publicName）'
        : publicName;
    final leading = preview.isGroup
        ? CircleAvatar(
            radius: AppLayout.scaled(context, 22),
            backgroundColor: AppTheme.primary.withAlpha(20),
            child: const Icon(Icons.groups_outlined, color: AppTheme.primary),
          )
        : ProfileAvatar(
            size: AppLayout.scaled(context, 44),
            seed: preview.peerUserId,
            imagePath: media?.avatarPath,
            userImageSet: resolved
                ? profile?.avatarKey?.trim().isNotEmpty == true
                : true,
            cidLevel: profile?.cidLevel,
            memberLevel: profile?.memberLevel,
            membergateActive: profile?.membergateActive ?? false,
            showBadge: resolved,
          );
    return ChatConversationListItem(
      id: preview.conversationId,
      title: title,
      subtitle: preview.lastMessage,
      updatedAt: preview.lastUpdatedAt,
      unreadCount: preview.unreadCount,
      leading: leading,
      onTap: () => _openConversation(preview),
      onDelete: () => _confirmAndDeleteConversation(preview),
      onLongPress: preview.isGroup ? () => _openGroupManage(preview) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? unavailable = _cidNumber.isEmpty && _error != null
        ? ChatConversationPlaceholder(message: _error!)
        : _accountId.isEmpty
        ? const ChatConversationPlaceholder(message: '请先在「我的 → 我的钱包」添加钱包账户')
        : _cidNumber.isEmpty
        ? IdentityRegisterGuide(
            description: '注册后即可使用聊天与通讯录。',
            onRegistered: _requestCoordinate,
          )
        : null;
    return ChatConversationOverview(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatSectionHeader<_ChatEntryAction>(
            onAction: _onEntryAction,
            actions: [
              for (final item in _chatEntryItems)
                ChatHeaderAction<_ChatEntryAction>(
                  value: item.action,
                  label: item.label,
                  icon: item.asset != null
                      ? SvgPicture.asset(
                          item.asset!,
                          width: AppLayout.scaled(context, 18),
                          height: AppLayout.scaled(context, 18),
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(
                          item.icon,
                          size: AppLayout.scaled(context, 20),
                          color: Colors.white,
                        ),
                ),
            ],
          ),
        ],
      ),
      onRefresh: () => _reload(syncFirst: true),
      onSearch: () => unawaited(_openSearch()),
      items: [
        for (final preview
            in _checkingIdentity ? <ChatConversationPreview>[] : _conversations)
          _conversationItem(context, preview),
      ],
      loading: _loading || _checkingIdentity,
      errorMessage: _error,
      unavailable: unavailable,
    );
  }
}

/// 加号菜单的 5 个动作。
enum _ChatEntryAction { scan, receivePay, sendMessage, createGroup, addFriend }

/// 加号菜单的一项：图标 + 文案。
///
/// [asset] 与 [icon] 二选一：扫一扫必须用与「交易 → 扫一扫」同一份
/// `assets/icons/scan-line.svg`（扫码图标），不能拿 Material 的二维码图标顶替。
class _ChatEntryItem {
  const _ChatEntryItem(this.action, this.label, {this.icon, this.asset});

  final _ChatEntryAction action;
  final String label;
  final IconData? icon;
  final String? asset;
}

const List<_ChatEntryItem> _chatEntryItems = [
  _ChatEntryItem(
    _ChatEntryAction.scan,
    '扫一扫',
    asset: 'packages/citizen_assets/icons/scan-line.svg',
  ),
  _ChatEntryItem(
    _ChatEntryAction.receivePay,
    '收付款',
    icon: Icons.payments_outlined,
  ),
  // 与底部导航「聊天」tab 同一个图标，保持同一语义同一形。
  _ChatEntryItem(
    _ChatEntryAction.sendMessage,
    '发私信',
    icon: Icons.textsms_outlined,
  ),
  _ChatEntryItem(
    _ChatEntryAction.createGroup,
    '发群聊',
    icon: Icons.group_outlined,
  ),
  _ChatEntryItem(
    _ChatEntryAction.addFriend,
    '加好友',
    icon: Icons.person_add_alt_1_outlined,
  ),
];

Future<bool> _confirmDeleteConversationList(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除聊天记录'),
      content: const Text('确定删除这台设备上的聊天记录？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// 群聊打开器；测试可注入替身，正式运行走 [openGroupChat]。
