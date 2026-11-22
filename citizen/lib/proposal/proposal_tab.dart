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
import 'package:citizen_citizen/proposal/proposal_context.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';
import 'package:citizen_citizen/proposal/proposal_local_store.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_detail_page.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/proposal/proposal_vote_widgets.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_multisig/multisig_transfer_proposal_adapter.dart';
import 'package:citizen_multisig/multisig_transfer_service.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 公民 tab「提案」统一列表:默认公共机构 + 当前钱包订阅公权机构,按 ID 倒序。
///
/// 本机保存提案数据，可见范围按下列规则在手机上过滤。
/// - 默认机构码: NRC/NLG/NSN/NRP/NED/NJD/NSP/PRS。
/// - 订阅机构:按当前热钱包订阅的公权机构 CID 精确命中。
/// - 不把全部公权机构提案塞进列表,订阅范围也不得按机构码放大。
///
/// **分页**:cursor 模式按 `_allIds` 切分,翻页天然不会卡空页。
/// 最终区块事件只更新涉及的提案，列表和翻页直接读本机。
class ProposalTab extends StatefulWidget {
  const ProposalTab({
    super.key,
    this.onPendingVoteCountChanged,
    this.feed,
    this.repository,
    this.contextResolver,
    this.capabilitiesReader,
    this.sdkEvents,
    this.lifecycleReader,
    this.walletStateReader,
    this.genesisReader,
    this.finalizedHeadReader,
    this.finalizedBlockReader,
    this.query,
  });

  /// 待投票数变化时的回调（用于底部 tab 红点数字）。
  final ValueChanged<int>? onPendingVoteCountChanged;

  /// 可注入既有只读依赖；首屏、刷新和事件更新始终走同一加载路径。
  final MultisigTransferProposalFeed? feed;
  final InstitutionRepository? repository;
  final ProposalContextResolver? contextResolver;

  /// 公开SDK只读事实边界，生产缺省仍读取同一会话。
  final Future<CitizenCapabilitySnapshot> Function()? capabilitiesReader;
  final Stream<CitizenSdkEvent>? sdkEvents;
  final CitizenSdkLifecycle Function()? lifecycleReader;
  final CitizenSdkOperation<CitizenWalletState> Function()? walletStateReader;
  final Future<String> Function()? genesisReader;
  final Future<CitizenBlockRef> Function()? finalizedHeadReader;
  final Future<CitizenBlockRef> Function(BigInt)? finalizedBlockReader;
  final ProposalQueryService? query;

  @override
  State<ProposalTab> createState() => _ProposalViewState();
}

class _ProposalViewState extends State<ProposalTab> {
  static const int _pageSize = 10;
  // 与 VotingEngine 清理排程的 90 天、每天 240 块一致。时间只安排核验。
  static const int _blocksPerDay = 240;
  static const int _retentionBlocks = 90 * _blocksPerDay;

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
  final ScrollController _scrollController = ScrollController();
  late final InstitutionRepository _institutionRepo;
  late final CitizenSdk _wallet;
  late final CitizenSdk _sdk;
  Completer<void>? _chainChanged;
  bool _dependenciesReady = false;

  StreamSubscription<CitizenSdkEvent>? _eventSub;

  // 分页状态
  bool _loading = true;
  bool _refreshing = false;
  int _generation = 0;

  bool _isCurrent(int generation) => mounted && generation == _generation;
  // 机构/行政区数据包是否已后台同步（首次进「公民」才触发，不阻塞首屏）。
  Future<void>? _directorySync;
  Map<String, Institution> _directoryNames = const {};
  String? _error;
  List<_ProposalDisplayItem> _items = [];
  List<_ProposalDisplayItem> _localItems = const [];

  /// 当前钱包可见提案 ID(降序排列)。
  /// 列表页基于此切分翻页 — cursor `_items.length` 标记已加载到第几条,
  /// `_hasMore = _items.length < _allIds.length`。
  List<BigInt> _allIds = const [];

  /// cid_number -> InstitutionInfo。列表和详情只按机构唯一 CID 复用上下文。
  Map<String, InstitutionInfo> _knownInstitutionsByCidNumber = const {};

  /// 待投票计数。
  int _pendingVoteCount = 0;

  late final ProposalQueryService _proposalQuery;
  final _store = ProposalLocalStore.instance;
  String? _feedKey;
  CitizenBlockRef? _pendingHead;
  Future<void>? _feedSync;
  Future<void>? _headRead;
  Timer? _retry;
  int _retrySeconds = 2;
  bool _checkCleanup = false;
  bool _cleanupFailed = false;
  bool _chainReady = false;
  CitizenBlockRef? _maintenanceHead;
  bool _maintenanceRunning = false;
  bool _syncBlocked = false;
  final _pendingDetails = <BigInt>{};
  int _pageLimit = _pageSize;
  int _renderRevision = 0;

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
    _proposalQuery = widget.query ?? ProposalQueryService(chain: sdk);
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
        _queueFinalized(event.finalized);
      }
      if (event is CitizenSdkCapabilitiesChanged) {
        final status = event.snapshot[CitizenCapabilityName.chainRead];
        final ready = status.supported && status.available && status.enabled && status.ready;
        if (ready && !_chainReady && _feedKey != null && !_refreshing) {
          _checkCleanup = true;
          _retry?.cancel();
          _retry = null;
          _syncBlocked = false;
          unawaited(_resumeFinalized(_generation));
        }
        _chainReady = ready;
      }
      if (event is CitizenSdkWalletChanged) {
        _contextResolver.clearWalletCache();
        unawaited(_refresh());
      }
    });
    _loadFirstPage();
  }

  @override
  void dispose() {
    ++_generation;
    _wakeChainReaders();
    _retry?.cancel();
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
        _chainReady = true;
        return true;
      }
      _chainReady = false;
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

  void _scheduleRetry() {
    if (!mounted || _retry != null) return;
    _retry = Timer(Duration(seconds: _retrySeconds), () {
      _syncBlocked = false;
      _retry = null;
      unawaited(_resumeFinalized(_generation));
    });
    if (_retrySeconds < 32) _retrySeconds *= 2;
  }

  void _queueFinalized(CitizenBlockRef head) {
    if (!mounted) return;
    if (_pendingHead == null || _pendingHead!.number <= head.number) {
      _pendingHead = head;
    }
    if (_feedSync != null || _feedKey == null || _refreshing || _syncBlocked) return;
    _feedSync = _syncPendingBlocks().whenComplete(() {
      _feedSync = null;
      final pending = _pendingHead;
      if (pending != null && mounted && !_syncBlocked) _queueFinalized(pending);
    });
  }

  Future<void> _syncPendingBlocks() async {
    final key = _feedKey!;
    CitizenBlockRef? target;
    try {
      while (mounted && _pendingHead != null) {
        final head = target = _pendingHead!;
        _pendingHead = null;
        final local = await _store.readFeed(key);
        if (local?.finalizedHeight == null) return;
        var changed = false;
        try {
          for (
            var height = local!.finalizedHeight! + BigInt.one;
            mounted && height <= head.number;
            height += BigInt.one
          ) {
            final block = height == head.number
                ? head
                : await (widget.finalizedBlockReader ?? _sdk.getFinalizedBlockAt)(height);
            changed = await _applyBlock(key, block) || changed;
            if (height % BigInt.from(_blocksPerDay) == BigInt.zero) _checkCleanup = true;
          }
          if (mounted && head.number >= local.finalizedHeight!) _queueMaintenance(head);
        } finally {
          if (changed && mounted) await _renderLocal(key);
        }
        target = null;
      }
    } on Object catch (error) {
      if (target != null && (_pendingHead == null || _pendingHead!.number < target.number)) {
        _pendingHead = target;
      }
      AppLog.proposalFailure(stage: 'proposal_feed', error: error);
      _syncBlocked = true;
      _scheduleRetry();
    }
  }

  void _queueMaintenance(CitizenBlockRef block) {
    if (!_checkCleanup && !_cleanupFailed && _pendingDetails.isEmpty) {
      _maintenanceHead = null;
      if (_retry == null) _retrySeconds = 2;
      return;
    }
    _maintenanceHead = block;
    if (_maintenanceRunning) return;
    _maintenanceRunning = true;
    unawaited(_maintainFeed().whenComplete(() {
      _maintenanceRunning = false;
      final next = _maintenanceHead;
      if (mounted && next != null && _retry == null) _queueMaintenance(next);
    }));
  }

  Future<void> _maintainFeed() async {
    final key = _feedKey!;
    final block = _maintenanceHead!;
    _maintenanceHead = null;
    var changed = false;
    try {
      if (_checkCleanup || _cleanupFailed) {
        final index = await _store.readFeed(key);
        // 候选必须已在被核验的区块出现。游标已经领先时交给新任务，
        // 避免把较晚入库的提案在旧块中的空值误认为已删除。
        if (index?.finalizedHeight != block.number ||
            index?.finalizedHash != block.hash) return;
        _checkCleanup = false;
        _cleanupFailed = false;
        final candidates = (await _store.readSummariesForIds(index!.ids))
            .where((item) => item.status >= 2 &&
                (item.cleanupHeight == null || item.cleanupHeight! <= block.number))
            .map((item) => item.proposalId).toList();
        for (var offset = 0; mounted && offset < candidates.length; offset += 128) {
          try {
            final confirmed = await _proposalQuery.deletedProposalIds(
              block, candidates.skip(offset).take(128),
            );
            if (!mounted) return;
            await _store.removeConfirmed(confirmed);
            _pendingDetails.removeAll(confirmed);
            changed = changed || confirmed.isNotEmpty;
          } on Object catch (error) {
            _cleanupFailed = true;
            AppLog.proposalFailure(stage: 'proposal_feed', error: error);
          }
        }
      }
      final requested = _pendingDetails.toList();
      final missing = await _store.readSummariesForIds(requested);
      final stillPending = missing.where((summary) => summary.detailPending)
          .map((summary) => summary.proposalId).toSet();
      _pendingDetails.removeAll(requested.where((id) => !stillPending.contains(id)));
      for (final summary in missing.where((item) => item.detailPending)) {
        if (!mounted) return;
        final id = summary.proposalId;
        try {
          final failed = <BigInt>{};
          final result = await _multisigTransferFeed.proposalsAt(
            block, [id], onDetailFailure: failed.add,
          );
          if (failed.contains(id) || !mounted) continue;
          final proposal = result.firstOrNull;
          var detail = proposal == null ? null : ProposalDetailSnapshot.fromProposal(proposal);
          if (detail != null) detail = await _snapshotAt(block, proposal!.meta, detail);
          if (!mounted) return;
          if (await _store.saveRepairedDetail(
            key: key, block: block, summary: summary.withRepairedDetail(proposal), detail: detail,
          )) {
            _pendingDetails.remove(id);
            changed = true;
          }
        } on Object catch (error) {
          AppLog.proposalFailure(stage: 'proposal_details', error: error);
        }
      }
    } on Object catch (error) {
      _cleanupFailed = true;
      AppLog.proposalFailure(stage: 'proposal_feed', error: error);
    } finally {
      if (mounted && (_cleanupFailed || _pendingDetails.isNotEmpty)) {
        _scheduleRetry();
      }
      if (mounted && changed) {
        try {
          await _renderLocal(key);
        } on Object catch (error) {
          AppLog.proposalFailure(stage: 'proposal_feed', error: error);
        }
      }
    }
  }

  Future<bool> _applyBlock(String key, CitizenBlockRef block) async {
    final local = (await _store.readFeed(key))!;
    final events = await _proposalQuery.proposalEvents(block);
    final newIds = <BigInt>{};
    final changedEvents = <BigInt, List<CitizenSystemEvent>>{};
    final stateChanges = <BigInt>{};
    final known = local.ids.toSet();
    for (final event in events) {
      final id = event.fieldUnsigned('proposal_id');
      (changedEvents[id] ??= []).add(event);
      if (known.contains(id)) {
        if (event.pallet == 'VotingEngine' ||
            ((event.pallet == 'LegislationVote' || event.pallet == 'ElectionVote') &&
                !event.name.endsWith('VoteCast'))) {
          stateChanges.add(id);
        }
      } else if (event.pallet == 'VotingEngine' &&
          event.name == 'ProposalCreated') {
        newIds.add(id);
      }
    }
    final detailFailures = <BigInt>{};
    final proposals = newIds.isEmpty
        ? const <ProposalWithDetail>[]
        : await _multisigTransferFeed.proposalsAt(
            block, newIds.toList(), onDetailFailure: detailFailures.add,
          );
    final details = await _detailsAt(block, proposals);
    detailFailures.removeAll(details.map((detail) => detail.proposalId));
    final summaries = [
      for (final proposal in proposals)
        LocalProposalSummary.fromProposal(proposal,
            detailPending: detailFailures.contains(proposal.meta.proposalId))
            .withChainState(proposal.meta, trackTallies: await _proposalQuery.trackTalliesAt(
              block, proposal.meta.proposalId, changedEvents[proposal.meta.proposalId] ?? const [],
            )),
    ];
    final deleted = <BigInt>{};
    for (final summary in await _store.readSummariesForIds(
      changedEvents.keys.where(known.contains).toList(),
    )) {
      final meta = stateChanges.contains(summary.proposalId)
          ? await _proposalQuery.proposalMetaAt(block, summary.proposalId)
          : summary.meta;
      if (meta == null) {
        deleted.add(summary.proposalId);
      } else {
        summaries.add(
          summary.withChainState(
            meta,
            trackTallies: await _proposalQuery.trackTalliesAt(
              block, summary.proposalId, changedEvents[summary.proposalId]!,
            ),
            cleanupHeight: summary.status < 2 && meta.status >= 2
                ? block.number + BigInt.from(_retentionBlocks)
                : null,
          ),
        );
        final detail = await ProposalDetailLocalStore.instance.readForFeed(
          meta.proposalId,
        );
        if (detail != null) {
          details.add(await _snapshotAt(block, meta, detail));
        }
      }
    }
    if (!mounted) return false;
    await _store.saveFeed(
      key: key,
      block: block,
      summaries: summaries,
      details: details,
      added: proposals.map((proposal) => proposal.meta.proposalId).toList(),
      deleted: deleted,
    );
    _pendingDetails.addAll(summaries.where((item) => item.detailPending).map((item) => item.proposalId));
    _pendingDetails.removeAll(deleted);
    return summaries.isNotEmpty || deleted.isNotEmpty;
  }

  Future<List<ProposalDetailSnapshot>> _detailsAt(
    CitizenBlockRef block,
    List<ProposalWithDetail> proposals,
  ) async {
    final details = <ProposalDetailSnapshot>[];
    for (final proposal in proposals) {
      final detail = ProposalDetailSnapshot.fromProposal(proposal);
      if (detail == null) continue;
      details.add(await _snapshotAt(block, proposal.meta, detail));
    }
    return details;
  }

  Future<ProposalDetailSnapshot> _snapshotAt(
    CitizenBlockRef block,
    ProposalMeta meta,
    ProposalDetailSnapshot detail,
  ) async {
    final counts = await _proposalQuery.proposalTalliesAt(block, meta);
    final cid = meta.actorCidNumber;
    List<String>? accounts;
    Map<String, bool?>? votes;
    List<EligibleVoterTicket>? tickets;
    int? threshold;
    ({bool? result, ({int yes, int no}) tally})? institutionVote;
    if (detail.proposalKind == 'runtime_upgrade' && cid != null) {
      final institution = await _localInstitution(cid);
      if (institution != null) {
        final joint = await _proposalQuery.jointInstitutionAt(
          block,
          meta,
          institution,
          detail.admins,
        );
        accounts = joint.accounts;
        votes = joint.votes;
        institutionVote = (result: joint.result, tally: joint.tally);
      }
    } else if (meta.kind == 0 &&
        cid != null &&
        (meta.status == 0 || detail.voterTickets.isNotEmpty)) {
      final institution = await _localInstitution(cid);
      if (institution != null) {
        final query = ProposalQueryService(chain: _sdk, block: block);
        tickets = detail.voterTickets;
        if (tickets.isEmpty) {
          tickets = await query.fetchEligibleVoterTickets(
            meta.proposalId,
            institution,
            includeRoleNames: true,
          );
        }
        accounts = tickets
            .map((ticket) => ticket.voterAccountId)
            .toSet()
            .toList();
        votes = await query.fetchTicketVotesBatch(meta.proposalId, tickets);
        threshold =
            detail.threshold ??
            await query.fetchInternalThresholdSnapshot(meta.proposalId);
      }
    }
    return detail.withState(
      meta,
      tally: counts.tally,
      referendum: counts.referendum,
      institution: institutionVote,
      eligibleAccounts: accounts,
      votes: votes,
      tickets: tickets,
      thresholdSnapshot: threshold,
    );
  }

  Future<InstitutionInfo?> _localInstitution(String cid) async {
    final known =
        _knownInstitutionsByCidNumber[cid] ??
        _institutionRepo.governanceInfo(cid);
    if (known != null) return known;
    final local = await _institutionRepo.getByCid(cid);
    return local == null ? null : _institutionInfoFromInstitution(local);
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
    unawaited(_directorySync ??= _syncDirectoryNames());

    final defaultInstitutions = await _institutionRepo
        .listByCodes(_defaultProposalCodes)
        .catchError((_) => <Institution>[]);
    CitizenWalletStateAccount? activeWallet;
    try {
      activeWallet =
          (await (widget.walletStateReader?.call() ?? _wallet.getWalletState())
                  .result)
              .defaultAccount;
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

  /// 目录就绪只更新机构名称，提案列表和待投票数沿用已取得的结果。
  Future<void> _syncDirectoryNames() async {
    try {
      if (!await _institutionRepo.directory.ensureSynced() || !mounted) return;
      final defaults = await _institutionRepo.listByCodes(
        _defaultProposalCodes,
      );
      final wallet =
          (await (widget.walletStateReader?.call() ?? _wallet.getWalletState())
                  .result)
              .defaultAccount;
      final subscribed = wallet == null
          ? <Institution>[]
          : await _institutionRepo.listSubscribed(wallet.accountId);
      if (!mounted) return;
      setState(() {
        _directoryNames = {
          for (final institution in [...defaults, ...subscribed])
            institution.cidNumber: institution,
        };
      });
    } catch (_) {
      // 目录不可用时继续显示已取得的机构名称。
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
      shortName: inst.shortName?.trim() ?? '',
      cidFullNameEn: inst.fullName,
      cidShortNameEn: inst.cidShortNameOrFullName,
      cidNumber: inst.cidNumber,
      orgType: inst.orgType,
      accounts: InstitutionAccounts(mainAccountId: main, feeAccountId: fee),
      adminCode: inst.orgCode,
    );
  }

  Future<void> _renderLocal(String key) async {
    final generation = _generation;
    final revision = ++_renderRevision;
    final scope = await _loadInstitutionScope();
    if (!_isCurrent(generation) || revision != _renderRevision) return;
    final index = await _store.readFeed(key);
    if (index == null) return;
    final summaries = await _store.readSummariesForIds(index.ids);
    if (!_isCurrent(generation) || revision != _renderRevision) return;
    final visible = summaries
        .where(
          (summary) =>
              _defaultProposalCodes.contains(
                summary.internalCode?.toUpperCase(),
              ) ||
              summary.subjectCidNumbers.any(
                scope.subscribedInstitutionCidNumbers.contains,
              ),
        )
        .toList();
    final wallet =
        await (widget.walletStateReader?.call() ?? _wallet.getWalletState())
            .result;
    final accounts = wallet.accounts.map((entry) => entry.accountId).toSet();
    final pending = <BigInt>{};
    if (accounts.isNotEmpty) {
      for (final summary in visible.where((summary) => summary.status == 0)) {
        final detail = await ProposalDetailLocalStore.instance.readForFeed(
          summary.proposalId,
        );
        if (detail != null &&
            (summary.kind != 1 ||
                (summary.stage == 1 && detail.extra['institution_vote'] == null)) &&
            detail.adminVotes.entries.any(
              (vote) =>
                  vote.value == null &&
                  accounts.contains(vote.key.split(':').last),
            )) {
          pending.add(summary.proposalId);
        }
      }
    }
    if (!_isCurrent(generation) || revision != _renderRevision) return;
    setState(() {
      _knownInstitutionsByCidNumber = scope.knownInstitutionsByCidNumber;
      _allIds = visible.map((summary) => summary.proposalId).toList();
      _localItems = [
        for (final summary in visible)
          _ProposalDisplayItem(
            summary: summary,
            institution:
                scope.knownInstitutionsByCidNumber[summary.actorCidNumber] ??
                (summary.actorCidNumber == null
                    ? null
                    : _institutionRepo.governanceInfo(summary.actorCidNumber!)),
            needsVote: pending.contains(summary.proposalId),
          ),
      ];
      _items = _localItems.take(_pageLimit).toList();
      _loading = false;
      _error = null;
    });
    _updatePendingVoteCount(pending.length);
  }

  Future<void> _loadFirstPage() async {
    if (_refreshing) return;
    final generation = ++_generation;
    _refreshing = true;
    try {
      final key = _feedKey ??= ProposalLocalStore.feedKey(
        await (widget.genesisReader ?? _sdk.getGenesisHash)(),
        null,
      );
      final saved = await _store.readFeed(key);
      if (saved == null) {
        if (!await _waitForChainRead(generation, reportWaiting: true)) return;
        final head =
            await (widget.finalizedHeadReader ?? _sdk.getFinalizedHead)();
        AppLog.proposalRead(state: 'started');
        final detailFailures = <BigInt>{};
        final proposals = await _multisigTransferFeed.bootstrapAt(
          head, onDetailFailure: detailFailures.add,
        );
        final details = await _detailsAt(head, proposals);
        detailFailures.removeAll(details.map((detail) => detail.proposalId));
        if (!_isCurrent(generation)) return;
        await _store.saveFeed(
          key: key,
          block: head,
          summaries: [
            for (final proposal in proposals)
              LocalProposalSummary.fromProposal(proposal,
                  detailPending: detailFailures.contains(proposal.meta.proposalId)),
          ]..sort((a, b) => b.proposalId.compareTo(a.proposalId)),
          details: details,
        );
      }
      final index = await _store.readFeed(key);
      final cached = await _store.readSummariesForIds(index?.ids ?? const []);
      _pendingDetails.addAll(cached.where((item) => item.detailPending).map((item) => item.proposalId));
      _checkCleanup = saved != null;
      await _renderLocal(key);
      if (_isCurrent(generation) && saved == null) {
        AppLog.proposalRead(state: _items.isEmpty ? 'empty' : 'nonempty');
      }
      // 旧本机副本先显示，补读走独立任务。
      unawaited(_resumeFinalized(generation));
    } on Object catch (error) {
      if (!_isCurrent(generation)) return;
      AppLog.proposalFailure(stage: 'proposal_feed', error: error);
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = '提案读取失败，请重试';
      });
    } finally {
      if (_isCurrent(generation)) _refreshing = false;
      final head = _pendingHead;
      if (mounted && head != null) _queueFinalized(head);
    }
  }

  Future<void> _resumeFinalized(int generation) {
    return _headRead ??= _readFinalizedHead(generation).whenComplete(() {
      _headRead = null;
    });
  }

  Future<void> _readFinalizedHead(int generation) async {
    try {
      if (!await _waitForChainRead(generation)) return;
      final head = await (widget.finalizedHeadReader ?? _sdk.getFinalizedHead)();
      if (_isCurrent(generation)) _queueFinalized(head);
    } on Object catch (error) {
      AppLog.proposalFailure(stage: 'proposal_feed', error: error);
      _scheduleRetry();
    }
  }

  void _loadNextPage() {
    if (_refreshing || !_hasMore) return;
    setState(() {
      _pageLimit += _pageSize;
      _items = _localItems.take(_pageLimit).toList();
    });
  }

  void _updatePendingVoteCount(int count) {
    _pendingVoteCount = count;
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
              TextButton(onPressed: _refresh, child: const Text('重试')),
            ],
          ),
        Expanded(child: _buildForeground()),
      ],
    );
  }

  Future<void> _refresh() async {
    final key = _feedKey;
    if (key == null || await _store.readFeed(key) == null) {
      await _loadFirstPage();
    } else if (mounted) {
      await _renderLocal(key);
    }
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
          // 留出滚动触发下一页的空间，分页数据已经来自本机。
          return const SizedBox(height: 56);
        },
      ),
    );
  }

  Widget _buildProposalCard(_ProposalDisplayItem item) {
    final statusColor = _statusColor(item.status);
    final statusLabel = _statusLabel(item.status);
    final directoryName = _directoryNames[item.summary.cidNumber]?.shortName
        ?.trim();
    final shortName = directoryName == null || directoryName.isEmpty
        ? item.shortName
        : directoryName;

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
                      ProposalCardHeader(
                        subjectName: shortName,
                        proposalNumber: item.displayId,
                        personal:
                            item.institution?.orgType ==
                            OrgType.personalMultisig,
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
                SizedBox(width: AppLayout.scaledValue(8)),
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
    final summary = item.summary;
    final id = summary.proposalId;
    final snapshot = await ProposalDetailLocalStore.instance.readForFeed(id);
    if (!mounted || snapshot == null) return;
    final cid = summary.actorCidNumber;
    final institution = cid == null ? null : await _localInstitution(cid);
    if (!mounted) return;
    final local = ProposalContext(institution: institution);
    Future<ProposalContext> resolveVoteContext() {
      _contextResolver.clearWalletCache();
      return _contextResolver.resolve(
        actorCidNumber: summary.actorCidNumber,
        executionAccountId: summary.meta.executionAccountId?.toList(),
        internalCode: summary.internalCode,
        knownInstitution: institution,
      );
    }
    if (snapshot.proposalKind == 'runtime_upgrade') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RuntimeUpgradeDetailPage(
            proposalId: id,
            proposalContext: local,
            resolveVoteContext: resolveVoteContext,
          ),
        ),
      );
    } else if (snapshot.proposalKind == 'institution_multisig' &&
        institution != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MultisigProposalDetailPage(
            institution: institution,
            proposalId: id,
            proposalContext: local,
            resolveVoteContext: resolveVoteContext,
          ),
        ),
      );
    } else if (institution != null) {
      await MultisigTransferProposalAdapter.openLocalDetail(
        context,
        proposalId: id,
        kind: snapshot.proposalKind,
        institution: institution,
        proposalContext: local,
        resolveVoteContext: resolveVoteContext,
      );
    }
  }
}

class _ProposalDisplayItem {
  const _ProposalDisplayItem({
    required this.summary,
    this.institution,
    required this.needsVote,
  });

  final LocalProposalSummary summary;
  final InstitutionInfo? institution;
  final bool needsVote;

  BigInt get proposalId => summary.proposalId;
  int get status => summary.status;
  String get displayId => summary.displayId;
  String? get shortName {
    final name = institution?.shortName.trim();
    return name == null || name.isEmpty ? null : name;
  }
}
