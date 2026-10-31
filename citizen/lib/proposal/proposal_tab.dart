import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/app_log.dart';
import 'package:provider/provider.dart';
import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_accounts.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/proposal/institution_manage_detail_page.dart';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_widgets/pressable_card.dart';
import 'package:citizen_widgets/shimmer_loading.dart';
import 'package:citizen_citizen/administrators/institution_admin_service.dart';
import 'package:citizen_citizen/administrators/admin_activation_service.dart';
import 'package:citizen_citizen/proposal/proposal_cache.dart';
import 'package:citizen_citizen/proposal/proposal_context.dart';
import 'package:citizen_citizen/proposal/proposal_local_store.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_detail_page.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_transaction/multisig/multisig_transfer_proposal_adapter.dart';
import 'package:citizen_transaction/multisig/multisig_transfer_service.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 公民 tab「提案」统一列表:默认公共机构 + 当前钱包订阅公权机构,按 ID 倒序。
///
/// **数据源(v1 双层 ID + 当前年缓存)**:
/// - 默认机构码: NRC/NLG/NSN/NRP/NED/NJD/NSP/PRS。
/// - 订阅机构:按当前热钱包订阅的公权机构 CID 精确命中。
/// - 不把全部公权机构提案塞进列表,订阅范围也不得按机构码放大。
///
/// **分页**:cursor 模式按 `_allIds` 切分,翻页天然不会卡空页。
/// **新区块订阅**:周期性重 fetch 可见提案 id 列表,补差异。
class ProposalTab extends StatefulWidget {
  const ProposalTab({
    super.key,
    this.onPendingVoteCountChanged,
    this.feed,
    this.repository,
    this.contextResolver,
    this.voteChecker,
    this.capabilitiesReader,
    this.sdkEvents,
    this.lifecycleReader,
  });

  /// 待投票数变化时的回调（用于底部 tab 红点数字）。
  final ValueChanged<int>? onPendingVoteCountChanged;

  /// 可注入既有只读依赖；首屏、刷新和事件更新始终走同一加载路径。
  final MultisigTransferProposalFeed? feed;
  final InstitutionRepository? repository;
  final ProposalContextResolver? contextResolver;
  final VoteChecker? voteChecker;

  /// 公开SDK只读事实边界，生产缺省仍读取同一会话。
  final Future<CitizenCapabilitySnapshot> Function()? capabilitiesReader;
  final Stream<CitizenSdkEvent>? sdkEvents;
  final CitizenSdkLifecycle Function()? lifecycleReader;

  @override
  State<ProposalTab> createState() => _ProposalViewState();
}

class _ProposalViewState extends State<ProposalTab> {
  static const int _pageSize = 10;
  static const Duration _newBlockIndexCheckMinInterval = Duration(seconds: 60);

  // 提案页默认公共机构集合独立于“治理”子 tab。
  // 省储委会/省储行不默认进入提案流,只有用户订阅对应机构后才展示。
  static const Set<String> _defaultProposalCodes = {
    'NRC',
    'NLG',
    'NSN',
    'NRP',
    'NED',
    'NJD',
    'NSP',
    'PRS',
  };

  late final MultisigTransferProposalFeed _multisigTransferFeed;
  late final InstitutionAdminService _adminService;
  late final ProposalContextResolver _contextResolver;
  late final VoteChecker _voteChecker;
  final ScrollController _scrollController = ScrollController();
  late final InstitutionRepository _institutionRepo;
  late final CitizenSdk _wallet;
  late final CitizenSdk _sdk;
  Completer<void>? _chainChanged;
  bool _dependenciesReady = false;

  StreamSubscription<CitizenSdkEvent>? _eventSub;

  // 分页状态
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _checkingIndex = false;
  bool _pageFailed = false;
  int _generation = 0;

  bool _isCurrent(int generation) => mounted && generation == _generation;
  // 机构/行政区数据包是否已后台同步（首次进「公民」才触发，不阻塞首屏）。
  bool _directorySynced = false;
  String? _error;
  List<_ProposalDisplayItem> _items = [];

  /// 当前钱包可见提案 ID(降序排列)。
  /// 列表页基于此切分翻页 — cursor `_items.length` 标记已加载到第几条,
  /// `_hasMore = _items.length < _allIds.length`。
  List<int> _allIds = const [];

  /// cid_number -> InstitutionInfo。列表和详情只按机构唯一 CID 复用上下文。
  Map<String, InstitutionInfo> _knownInstitutionsByCidNumber = const {};

  /// 待投票计数。
  int _pendingVoteCount = 0;

  DateTime? _lastProposalIndexCheckAt;

  bool get _hasMore => _items.length < _allIds.length;
  bool get _isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _sdk = sdk;
    _wallet = sdk;
    _institutionRepo = widget.repository ?? InstitutionRepository();
    final multisigService = MultisigTransferService(
      chain: sdk,
      transactions: sdk,
    );
    _multisigTransferFeed =
        widget.feed ?? MultisigTransferProposalFeed(service: multisigService);
    _adminService = InstitutionAdminService(chain: sdk);
    final activationService = ActivationService(adminService: _adminService);
    _contextResolver =
        widget.contextResolver ??
        ProposalContextResolver(
          wallet: _wallet,
          adminService: _adminService,
          activationService: activationService,
        );
    final proposalQuery = ProposalQueryService(chain: sdk);
    _voteChecker =
        widget.voteChecker ??
        VoteChecker(
          internalVoteService: InternalVoteQueryService(chain: sdk),
          runtimeService: RuntimeUpgradeService(chain: sdk, transactions: sdk),
          proposalQueryService: proposalQuery,
        );
    _dependenciesReady = true;
    if (_isFlutterTest && widget.feed == null) {
      // App 启动 widget test 只验证首屏结构，不验证隐藏提案页的轻节点订阅。
      // 组件测试不启动真实 CitizenSDK 链 session，隐藏页不发起链读。
      _loading = false;
      return;
    }
    // 先订阅再读快照，不能漏掉订阅与首读之间发生的就绪变化。
    _eventSub = (widget.sdkEvents ?? sdk.events).listen((event) {
      if (event is CitizenSdkCapabilitiesChanged ||
          event is CitizenSdkLifecycleChanged ||
          event is CitizenSdkFinalizedBlockChanged) {
        _wakeChainReaders();
      }
      if (event is CitizenSdkFinalizedBlockChanged) {
        _checkForNewProposals();
      }
    });
    _loadFirstPage();
  }

  @override
  void dispose() {
    ++_generation;
    _wakeChainReaders();
    _scrollController.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  void _wakeChainReaders() {
    final changed = _chainChanged;
    _chainChanged = null;
    changed?.complete();
  }

  /// 只等待同一SDK的公开能力变化；不启动节点、不轮询、不把真实读取错误重试成成功。
  Future<bool> _waitForChainRead(
    int generation, {
    bool reportWaiting = false,
  }) async {
    var reportedWaiting = false;
    while (_isCurrent(generation)) {
      final changed = _chainChanged ??= Completer<void>();
      final status =
          (await (widget.capabilitiesReader ??
              _sdk.getCapabilities)())[CitizenCapabilityName.chainRead];
      if (!_isCurrent(generation)) return false;
      final lifecycle = widget.lifecycleReader?.call() ?? _sdk.lifecycle;
      if (lifecycle == CitizenSdkLifecycle.startFailed ||
          lifecycle == CitizenSdkLifecycle.stopped ||
          lifecycle == CitizenSdkLifecycle.disposed) {
        throw StateError('提案读链实例已停止或启动失败');
      }
      // 查询期间发生了能力变化，旧“ready”也不得覆盖最新未就绪事实。
      if (changed.isCompleted) continue;
      if (status.supported &&
          status.available &&
          status.enabled &&
          status.ready) {
        return true;
      }
      if (!status.supported ||
          !status.available ||
          !status.enabled ||
          !const {
            CitizenCapabilityReason.engineNotRunning,
            CitizenCapabilityReason.dependencyNotReady,
            CitizenCapabilityReason.chainStarting,
            CitizenCapabilityReason.chainUnsynced,
          }.contains(status.reason)) {
        throw StateError('提案读链能力不可用');
      }
      if (reportWaiting && !reportedWaiting) {
        AppLog.proposalRead(state: 'waiting');
        reportedWaiting = true;
      }
      await changed.future;
    }
    return false;
  }

  Future<void> _checkForNewProposals() async {
    if (_refreshing || _loadingMore || _checkingIndex) return;
    final now = DateTime.now();
    final lastCheck = _lastProposalIndexCheckAt;
    if (lastCheck != null &&
        now.difference(lastCheck) < _newBlockIndexCheckMinInterval) {
      return;
    }
    _lastProposalIndexCheckAt = now;
    final generation = _generation;
    _checkingIndex = true;

    try {
      if (!await _waitForChainRead(generation)) return;
      final scope = await _fetchVisibleProposalScope();
      if (!_isCurrent(generation)) return;
      final fresh = scope.ids;
      final knownSet = _allIds.toSet();
      final newIds = fresh.where((id) => !knownSet.contains(id)).toList();
      if (newIds.isEmpty) {
        if (!_pageFailed) setState(() => _error = null);
        return;
      }

      // 新增提案插到列表顶部。按 proposal_id 去重(fresh 在前优先保留),避免
      // 本地缓存 _items 与 _allIds 口径不同步时同一提案出现两张卡片。
      final newItems = await _loadItemsForIds(
        newIds,
        generation: generation,
        knownInstitutionsByCidNumber: scope.knownInstitutionsByCidNumber,
      );
      if (_isCurrent(generation)) {
        setState(() {
          if (!_pageFailed) _error = null;
          _items = _dedupById([...newItems, ..._items]);
          _allIds = fresh;
          _knownInstitutionsByCidNumber = scope.knownInstitutionsByCidNumber;
        });
        _updatePendingVoteCount();
      }
    } on Object {
      // 后台读取失败保留现有列表和红点；旧请求不得改变新刷新状态。
      if (_isCurrent(generation)) {
        setState(() {
          _error = _items.isEmpty ? '提案读取失败，请重试' : '提案刷新失败，已保留当前列表';
        });
      }
    } finally {
      _checkingIndex = false;
    }
  }

  // ──── 分页加载 ────

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<
    ({
      Set<String> subscribedInstitutionCidNumbers,
      Map<String, InstitutionInfo> knownInstitutionsByCidNumber,
    })
  >
  _loadInstitutionScope() async {
    // 机构/行政区数据包（首装 4.2 万条行政区，秒级~十几秒）**不阻塞**提案流
    // 首屏：后台同步，首次未就绪先按链上机构码兜底显示（代码本就容忍缺数据），
    // 就绪后回刷一次填充机构名。避免首次进「公民」卡十几秒。
    unawaited(_ensureDirectorySyncedThenRefresh());

    final defaultInstitutions = await _institutionRepo
        .listByCodes(_defaultProposalCodes)
        .catchError((_) => <Institution>[]);
    CitizenWalletStateAccount? activeWallet;
    try {
      activeWallet = (await _wallet.getWalletState().result).defaultAccount;
    } on Object {
      activeWallet = null;
    }
    final subscribedInstitutions = activeWallet == null
        ? <Institution>[]
        : await _institutionRepo
              .listSubscribed(activeWallet.accountId)
              .catchError((_) => <Institution>[]);

    final known = <String, InstitutionInfo>{};
    for (final inst in [...defaultInstitutions, ...subscribedInstitutions]) {
      final info = _institutionInfoFromInstitution(inst);
      known[info.cidNumber] = info;
    }

    final subscribedCidNumbers = <String>{
      for (final inst in subscribedInstitutions) inst.cidNumber,
    };
    return (
      subscribedInstitutionCidNumbers: subscribedCidNumbers,
      knownInstitutionsByCidNumber: known,
    );
  }

  /// 后台同步机构/行政区数据包；首次就绪且有变更时回刷一次提案流以填机构名。
  /// 幂等：同步过一次后直接返回，回刷再进本方法不会二次同步或二次回刷。
  Future<void> _ensureDirectorySyncedThenRefresh() async {
    if (_directorySynced) return;
    try {
      final changed = await _institutionRepo.directory.ensureSynced();
      _directorySynced = true;
      if (changed && mounted) {
        // 名称就绪后静默回刷（_items 非空则不显示 loading，不闪屏）。
        unawaited(_loadFirstPage(force: true));
      }
    } catch (_) {
      // 同步失败：保持按机构码兜底显示，不阻塞。
    }
  }

  /// 为普通公权机构派生 ProposalContext 使用的 InstitutionInfo。
  InstitutionInfo _institutionInfoFromInstitution(Institution inst) {
    final govInfo = _institutionRepo.governanceInfo(inst.cidNumber);
    if (govInfo != null) return govInfo;
    final rows = institutionAccountIdRows(inst);
    if (rows.length < 2) {
      throw StateError('机构账户集合缺少主账户或费用账户: ${inst.cidNumber}');
    }
    final main = rows.first.accountId;
    final fee = rows[1].accountId;
    return InstitutionInfo(
      fullName: inst.fullName,
      shortName: inst.cidShortNameOrFullName,
      cidFullNameEn: inst.fullName,
      cidShortNameEn: inst.cidShortNameOrFullName,
      cidNumber: inst.cidNumber,
      orgType: inst.orgType,
      accounts: InstitutionAccounts(mainAccountId: main, feeAccountId: fee),
      adminCode: inst.orgCode,
    );
  }

  Future<
    ({List<int> ids, Map<String, InstitutionInfo> knownInstitutionsByCidNumber})
  >
  _fetchVisibleProposalScope({bool forceRefresh = false}) async {
    final generation = _generation;
    var stage = 'proposal_institutions';
    try {
      final institutionScope = await _loadInstitutionScope();
      stage = 'proposal_feed';
      final ids = await _multisigTransferFeed.fetchCitizenProposalFeedIds(
        defaultCodes: _defaultProposalCodes,
        subscribedInstitutionCidNumbers:
            institutionScope.subscribedInstitutionCidNumbers,
        forceRefresh: forceRefresh,
      );
      return (
        ids: ids,
        knownInstitutionsByCidNumber:
            institutionScope.knownInstitutionsByCidNumber,
      );
    } on Object catch (error) {
      // 页面诊断同样服从原请求代次；服务层事件是独立的链读失败事实。
      if (_isCurrent(generation)) {
        AppLog.proposalFailure(stage: stage, error: error);
      }
      rethrow;
    }
  }

  /// 每次整页刷新作废旧首批、翻页和后台索引结果。
  Future<void> _loadFirstPage({bool force = false}) async {
    final generation = ++_generation;
    _wakeChainReaders();
    setState(() {
      _refreshing = true;
      _pageFailed = false;
      _loading = _items.isEmpty;
      _error = null;
      _loadingMore = false;
    });

    try {
      if (!await _waitForChainRead(generation, reportWaiting: true)) return;
      AppLog.proposalRead(state: 'started');
      final scope = await _fetchVisibleProposalScope(forceRefresh: force);
      if (!_isCurrent(generation)) return;
      final ids = scope.ids;

      if (ids.isEmpty) {
        if (!_isCurrent(generation)) return;
        setState(() {
          _allIds = const [];
          _items = const [];
          _knownInstitutionsByCidNumber = scope.knownInstitutionsByCidNumber;
          _loading = false;
        });
        _updatePendingVoteCount();
        // 只有当前代次真实取得空可见范围并完成页面更新，才能报告成功空结果。
        if (_isCurrent(generation)) AppLog.proposalRead(state: 'empty');
        return;
      }

      // 切前 _pageSize 条
      final firstPageIds = ids.sublist(
        0,
        ids.length < _pageSize ? ids.length : _pageSize,
      );
      final items = await _loadItemsForIds(
        firstPageIds,
        generation: generation,
        knownInstitutionsByCidNumber: scope.knownInstitutionsByCidNumber,
      );

      if (!_isCurrent(generation)) return;
      setState(() {
        _allIds = ids;
        _items = items;
        _knownInstitutionsByCidNumber = scope.knownInstitutionsByCidNumber;
        _loading = false;
      });

      _updatePendingVoteCount();
      // 可见ID非空但详情尚无可展示项时不冒充空范围；失败/迟到/销毁均无成功回执。
      if (_isCurrent(generation) && items.isNotEmpty) {
        AppLog.proposalRead(state: 'nonempty');
      }
    } catch (e) {
      if (!_isCurrent(generation)) return;
      setState(() {
        _error = _items.isEmpty ? '提案读取失败，请重试' : '提案刷新失败，已保留当前列表';
        _loading = false;
      });
    } finally {
      if (_isCurrent(generation)) _refreshing = false;
    }
  }

  Future<void> _loadNextPage() async {
    if (_refreshing || _checkingIndex || _loadingMore || !_hasMore) return;
    final generation = _generation;

    setState(() {
      _loadingMore = true;
      _pageFailed = false;
      _error = null;
    });

    try {
      if (!await _waitForChainRead(generation)) return;
      final from = _items.length;
      final to = (from + _pageSize) > _allIds.length
          ? _allIds.length
          : (from + _pageSize);
      final pageIds = _allIds.sublist(from, to);
      final newItems = await _loadItemsForIds(
        pageIds,
        generation: generation,
        knownInstitutionsByCidNumber: _knownInstitutionsByCidNumber,
      );

      if (!_isCurrent(generation)) return;
      setState(() {
        _items = _dedupById([..._items, ...newItems]);
        _loadingMore = false;
      });

      _updatePendingVoteCount();
    } catch (e) {
      if (_isCurrent(generation)) {
        setState(() {
          _loadingMore = false;
          _pageFailed = true;
          _error = '更多提案读取失败，请重试';
        });
      }
    }
  }

  /// 给定一组 proposal_id,batch fetch 详情 + 上下文 + 待投票判定,
  /// 返回 `_ProposalDisplayItem` 列表(顺序与入参一致)。
  Future<List<_ProposalDisplayItem>> _loadItemsForIds(
    List<int> ids, {
    required int generation,
    Map<String, InstitutionInfo> knownInstitutionsByCidNumber = const {},
  }) async {
    if (ids.isEmpty) return const [];

    // 只定位原步骤，不吞错或增加读取；旧代次仍不得更新页面。
    var stage = 'proposal_details';
    try {
      // 批量取提案详情(meta + 业务详情)
      final proposals = await _multisigTransferFeed.fetchProposalsByIds(ids);

      stage = 'proposal_context';
      // 批量解析提案上下文
      final contexts = await _contextResolver.resolveBatch(
        proposals.map((p) => p.meta.actorCidNumber).toList(),
        executionAccountIds: proposals
            .map((p) => p.meta.executionAccountId?.toList())
            .toList(),
        internalCodeList: proposals.map((p) => p.meta.internalCode).toList(),
        knownInstitutionsByCidNumber: knownInstitutionsByCidNumber,
      );

      // ADR-018 R2:一次性批量算出"哪些提案需要投票",替代过去每提案各发一次
      // 投票查询 RPC(P 个提案 = P 次往返)。
      stage = 'proposal_votes';
      final needVote = await _voteChecker.proposalsNeedingVote([
        for (var i = 0; i < proposals.length; i++)
          VoteCheckTarget(
            proposalId: proposals[i].meta.proposalId,
            kind: proposals[i].meta.kind,
            status: proposals[i].meta.status,
            adminWallets: contexts[i].adminWallets,
            institution: contexts[i].institution,
          ),
      ]);

      stage = 'proposal_display';
      final items = <_ProposalDisplayItem>[];
      for (var i = 0; i < proposals.length; i++) {
        items.add(
          _ProposalDisplayItem.fromProposal(
            proposal: proposals[i],
            context: contexts[i],
            needsVote: needVote.contains(proposals[i].meta.proposalId),
          ),
        );
      }

      if (!_isCurrent(generation)) return const [];
      stage = 'proposal_summary';
      await ProposalLocalStore.instance.upsertSummaries(
        items.map((item) => item.summary).toList(growable: false),
      );
      return items;
    } on Object catch (error) {
      if (_isCurrent(generation)) {
        AppLog.proposalFailure(stage: stage, error: error);
      }
      rethrow;
    }
  }

  /// 按 proposal_id 去重,保留首次出现(prepend 的 fresh 项优先)。
  /// 防止本地缓存项与新查项口径不同步时同一提案重复成卡片。
  static List<_ProposalDisplayItem> _dedupById(
    List<_ProposalDisplayItem> items,
  ) {
    final seen = <int>{};
    final result = <_ProposalDisplayItem>[];
    for (final item in items) {
      if (seen.add(item.proposalId)) result.add(item);
    }
    return result;
  }

  void _updatePendingVoteCount() {
    _pendingVoteCount = _items.where((i) => i.needsVote).length;
    widget.onPendingVoteCountChanged?.call(_pendingVoteCount);
  }

  // ──── UI ────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null && _items.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.warning),
                  ),
                ),
              ),
              TextButton(
                onPressed: _pageFailed ? _loadNextPage : _refresh,
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(child: _buildForeground()),
      ],
    );
  }

  /// 下拉与错误按钮共用强制刷新，不能命中上一次失败前的年缓存。
  Future<void> _refresh() async {
    _adminService.clearCache();
    _contextResolver.clearWalletCache();
    ProposalCache.clear();
    MultisigTransferProposalAdapter.clearCache();
    await _loadFirstPage(force: true);
  }

  Widget _buildForeground() {
    if (_loading) {
      return ListSkeleton(
        itemCount: 5,
        itemBuilder: (_, _) => const ProposalCardSkeleton(),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaledValue(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: AppLayout.scaledValue(48),
                color: AppTheme.danger,
              ),
              SizedBox(height: AppLayout.scaledValue(12)),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(16),
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaledValue(6)),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(12),
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppLayout.scaledValue(16)),
              OutlinedButton(onPressed: _refresh, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && !_hasMore) {
      // 空态:留给水印,前景透明占位以承接下拉刷新。
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: AppLayout.scaledValue(400))],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: AppLayout.scaledValue(8)),
        itemBuilder: (context, index) {
          if (index < _items.length) {
            return _buildProposalCard(_items[index]);
          }
          // 底部加载指示器
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppLayout.scaled(context, 16),
            ),
            child: Center(
              child: SizedBox(
                width: AppLayout.scaled(context, 24),
                height: AppLayout.scaled(context, 24),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProposalCard(_ProposalDisplayItem item) {
    final statusColor = _statusColor(item.status);
    final statusLabel = _statusLabel(item.status);

    return PressableCard(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
          side: BorderSide(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: () => _openProposalDetail(item),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaledValue(14),
              vertical: AppLayout.scaledValue(12),
            ),
            child: Row(
              children: [
                // 左侧图标
                Container(
                  width: AppLayout.scaledValue(36),
                  height: AppLayout.scaledValue(36),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(10),
                    ),
                  ),
                  child: Icon(
                    _proposalIcon(item),
                    size: AppLayout.scaledValue(18),
                    color: statusColor,
                  ),
                ),
                SizedBox(width: AppLayout.scaledValue(12)),
                // 中间信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.displayId,
                            style: TextStyle(
                              fontSize: AppLayout.scaledValue(15),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          SizedBox(width: AppLayout.scaledValue(8)),
                          if (item.fullName != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppLayout.scaledValue(6),
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppLayout.scaledValue(8),
                                ),
                              ),
                              child: Text(
                                item.fullName!,
                                style: TextStyle(
                                  fontSize: AppLayout.scaledValue(10),
                                  color: AppTheme.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: AppLayout.scaledValue(2)),
                      Text(
                        item.summary.listSubtitle,
                        style: TextStyle(
                          fontSize: AppLayout.scaledValue(12),
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧状态 + 红点
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.scaledValue(8),
                        vertical: AppLayout.scaledValue(2),
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppLayout.scaledValue(10),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: AppLayout.scaledValue(11),
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (item.needsVote) ...[
                      SizedBox(height: AppLayout.scaledValue(4)),
                      Container(
                        width: AppLayout.scaledValue(8),
                        height: AppLayout.scaledValue(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(width: AppLayout.scaledValue(4)),
                Icon(
                  Icons.chevron_right,
                  size: AppLayout.scaledValue(20),
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(int status) {
    switch (status) {
      case 0:
        return '投票中';
      case 1:
        return '已通过';
      case 2:
        return '已拒绝';
      case 3:
        return '已执行';
      case 4:
        return '执行失败';
      default:
        return '未知';
    }
  }

  Color _statusColor(int status) => AppTheme.proposalStatusColor(status);

  /// 根据提案类型返回图标。
  IconData _proposalIcon(_ProposalDisplayItem item) {
    return switch (item.summary.iconKind) {
      'transfer' => Icons.send_outlined,
      'safety_fund' => Icons.health_and_safety_outlined,
      'sweep' => Icons.account_balance_wallet_outlined,
      'create_multisig' => Icons.group_add,
      'close_multisig' => Icons.group_remove,
      'runtime_upgrade' => Icons.arrow_upward,
      'resolution_issuance' => Icons.add_circle_outline,
      'resolution_destroy' => Icons.remove_circle_outline,
      'joint' => Icons.groups_outlined,
      _ => Icons.description_outlined,
    };
  }

  Future<void> _openProposalDetail(_ProposalDisplayItem item) async {
    final resolved = await _resolveProposalDetail(item);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('提案详情读取失败，请稍后重试')));
      return;
    }
    final (:proposal, :proposalContext) = resolved;
    final inst = proposalContext.institution;
    final proposalId = proposal.meta.proposalId;

    // 协议升级提案（联合投票，kind=1）
    if (proposal.runtimeUpgradeDetail != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RuntimeUpgradeDetailPage(
            proposalId: proposalId,
            proposalContext: proposalContext,
          ),
        ),
      );
    } else if (MultisigTransferProposalAdapter.matches(proposal)) {
      await MultisigTransferProposalAdapter.openDetail(
        context,
        proposal: proposal,
        institution: inst,
        proposalContext: proposalContext,
      );
    } else if ((proposal.createMultisigDetail != null ||
            proposal.closeMultisigDetail != null) &&
        inst != null) {
      // 多签管理提案
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MultisigProposalDetailPage(
            institution: inst,
            proposalId: proposalId,
            proposalContext: proposalContext,
          ),
        ),
      );
    } else {
      // 其他未知类型
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该提案类型的详情页面正在开发中')));
      return;
    }

    // 返回后刷新
    if (mounted) {
      _adminService.clearCache();
      ProposalCache.clear();
      MultisigTransferProposalAdapter.clearCache();
      _loadFirstPage(force: true);
    }
  }

  Future<({ProposalWithDetail proposal, ProposalContext proposalContext})?>
  _resolveProposalDetail(_ProposalDisplayItem item) async {
    final existingProposal = item.proposal;
    final existingContext = item.context;
    if (existingProposal != null && existingContext != null) {
      return (proposal: existingProposal, proposalContext: existingContext);
    }

    try {
      final proposals = await _multisigTransferFeed.fetchProposalsByIds([
        item.proposalId,
      ]);
      if (proposals.isEmpty) return null;
      final proposal = proposals.first;
      final contexts = await _contextResolver.resolveBatch(
        [proposal.meta.actorCidNumber],
        executionAccountIds: [proposal.meta.executionAccountId?.toList()],
        internalCodeList: [proposal.meta.internalCode],
        knownInstitutionsByCidNumber: _knownInstitutionsByCidNumber,
      );
      final proposalContext = contexts.isEmpty
          ? const ProposalContext()
          : contexts.first;
      final resolvedItem = _ProposalDisplayItem.fromProposal(
        proposal: proposal,
        context: proposalContext,
        needsVote: item.needsVote,
      );
      await ProposalLocalStore.instance.upsertSummaries([resolvedItem.summary]);
      if (mounted) {
        setState(() {
          _items = [
            for (final current in _items)
              if (current.proposalId == item.proposalId)
                resolvedItem
              else
                current,
          ];
        });
      }
      return (proposal: proposal, proposalContext: proposalContext);
    } catch (_) {
      return null;
    }
  }
}

class _ProposalDisplayItem {
  const _ProposalDisplayItem({
    required this.summary,
    this.proposal,
    this.context,
    this.needsVote = false,
  });

  factory _ProposalDisplayItem.fromProposal({
    required ProposalWithDetail proposal,
    required ProposalContext context,
    bool needsVote = false,
  }) {
    return _ProposalDisplayItem(
      proposal: proposal,
      context: context,
      summary: LocalProposalSummary.fromProposal(
        proposal,
        institution: context.institution,
      ),
      needsVote: needsVote,
    );
  }

  final LocalProposalSummary summary;
  final ProposalWithDetail? proposal;
  final ProposalContext? context;
  final bool needsVote;

  int get proposalId => summary.proposalId;
  int get status => summary.status;
  String get displayId => summary.displayId;
  String? get fullName => context?.institution?.fullName ?? summary.fullName;
}
