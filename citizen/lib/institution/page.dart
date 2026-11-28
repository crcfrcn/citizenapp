// 机构详情、账户及任职页面。

import 'package:citizen_system/format.dart';
import 'package:citizen_widgets/balance.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:citizen_citizen/institution/data.dart' show Institution;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAccountRow, institutionAccountIdRows;
import 'package:citizen_citizen/institution/data.dart' show InstitutionChainState, InstitutionProposalSummary, LiveInstitutionChainState;
import 'package:citizen_citizen/institution/data.dart' show InstitutionClassification;
import 'package:citizen_citizen/institution/service.dart' show InstitutionRepository;
import 'package:citizen_citizen/public/page.dart' show PublicInstitutionAssignmentsPage;
import 'package:citizen_citizen/legislation/data.dart' show LawRegion, LawTier;
import 'package:citizen_citizen/legislation/page.dart' show LawListPage;
import 'package:citizen_citizen/institution/service.dart' show InstitutionChainService;
import 'package:citizen_citizen/proposal/entry.dart' show ProposalEntryPage;
import 'package:citizen_citizen/runtime/detail.dart' show RuntimeUpgradeDetailPage;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAssignmentSourceLabel, InstitutionIdentity, InstitutionPersonView, InstitutionRole;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAccounts, InstitutionInfo;
import 'package:citizen_citizen/proposal/data.dart' show ProposalContext, ProposalContextResolver, ProposalRole;
import 'package:citizen_citizen/proposal/store.dart' show LocalProposalSummary, ProposalLocalStore;
import 'package:citizen_citizen/proposal/data.dart' show ProposalWithDetail;
import 'package:citizen_citizen/proposal/vote.dart' show ProposalCardHeader;
import 'package:citizen_user/context.dart' show CurrentUserContext;
import 'package:citizen_multisig/proposal.dart' show MultisigTransferProposalAdapter, MultisigTransferProposalFeed;
import 'package:citizen_multisig/service.dart' show MultisigTransferService;
import 'package:citizen_system/theme.dart';
import 'package:citizen_scanner/sign.dart';

// 组合机构资料、账户、管理员、提案和关注等统一详情。

/// 统一机构详情页(ADR-028 决策 2/6)——替代公权 `PublicInstitutionDetailPage`
/// 与治理 `InstitutionDetailPage` 两套。
///
/// 公共壳(信息卡/账户/管理员/提案列表/关注)对全部机构统一;按机构类型
/// dispatch 重型流:
/// - 储备治理三档(NRC/PRC/PRB):提案列表可点→`_openProposalDetail`;
/// - 其余注册机构:提案列表仍走只读摘要,但发起提案/管理员激活共用统一入口。
/// 提案能力由 `ProposalCapabilityRegistry` 判断,详情页不再散落机构码 if。
class InstitutionDetailPage extends StatefulWidget {
  const InstitutionDetailPage({
    super.key,
    required this.cidNumber,
    required this.repository,
    this.chainState,
    this.subscriberCidNumberProvider,
    this.contextResolver,
  });

  final String cidNumber;
  final InstitutionRepository repository;

  /// 链态读服务(余额/管理员/提案);测试注入,默认 Live。
  final InstitutionChainState? chainState;

  /// 可注入原角色/激活接口；测试与生产共用同一名册和权限加载路径。
  final ProposalContextResolver? contextResolver;

  /// 当前已注册公民的永久 CID（只用于本地关注关系归属）。
  ///
  /// 账户换绑后 CID 不变，因此关注列表不会随签名账户切换而分叉。
  final Future<String?> Function()? subscriberCidNumberProvider;

  @override
  State<InstitutionDetailPage> createState() => _InstitutionDetailPageState();
}

class _InstitutionDetailPageState extends State<InstitutionDetailPage> {
  late final InstitutionChainState _chainState;
  MultisigTransferProposalFeed? _multisigTransferFeed;
  ProposalContextResolver? _contextResolver;
  bool _dependenciesReady = false;

  Institution? _inst;

  /// 提案/管理员入口使用的链上主体信息。所有机构都以目录或静态注册表中的
  /// CID 为唯一身份；账户集合只用于具体资金操作。
  InstitutionInfo? _govInfo;
  bool get _isGovernance =>
      InstitutionClassification.isGovernance(_inst?.orgCode ?? '');

  bool _loading = true;

  String? _subscriberCidNumber;
  bool _subscribed = false;

  List<InstitutionAccountRow> _accounts = const [];
  String _areaPath = '';

  List<InstitutionPersonView> _adminViews = const [];
  List<InstitutionRole> _rosterRoles = const [];
  bool _assignmentsLoaded = false;
  bool _assignmentsLoading = true;
  int _adminGeneration = 0;
  int _roleGeneration = 0;
  bool _roleLoading = false;
  bool _roleFailed = false;

  // 治理路径专用(管理员角色 / 激活 / 富提案列表)。
  List<CitizenWalletStateAccount> _adminWallets = const [];
  bool _isCurrentUserAdmin = false;
  List<LocalProposalSummary> _govProposals = const [];
  Map<BigInt, ProposalWithDetail> _govProposalDetailsById = const {};

  // 公权路径专用(只读提案摘要)。
  List<InstitutionProposalSummary> _publicProposals = const [];

  InstitutionIdentity? get _accountIdentity {
    final info = _govInfo;
    if (info == null) return null;
    try {
      return InstitutionIdentity.fromInstitution(info);
    } on ArgumentError {
      // 非治理且非注册账户身份暂无法解析 → 优雅降级(提案入口仍开,但需激活后才能发起)。
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk?>();
    if (sdk == null) {
      final injectedChainState = widget.chainState;
      if (injectedChainState == null) {
        throw StateError('机构详情缺少 CitizenSDK');
      }
      // 只读 Widget 夹具可直接注入已经完成链投影的 InstitutionChainState；
      // 正式 App 根始终走下方唯一 CitizenSDK 实例。
      _chainState = injectedChainState;
      _dependenciesReady = true;
      _load();
      return;
    }
    final wallet = sdk;
    final multisigService = MultisigTransferService(
      chain: sdk,
      transactions: sdk,
    );
    final multisigFeed = MultisigTransferProposalFeed(service: multisigService);
    _multisigTransferFeed = multisigFeed;
    final adminService = InstitutionChainService(chain: sdk);
    _chainState =
        widget.chainState ??
        LiveInstitutionChainState(
          chain: sdk,
          transactions: sdk,
          adminService: adminService,
          feed: multisigFeed,
        );
    _contextResolver =
        widget.contextResolver ??
        ProposalContextResolver(
          wallet: wallet,
          institutionService: adminService,
        );
    _dependenciesReady = true;
    _load();
  }

  Future<String?> _resolveSubscriberCidNumber() async {
    final provider = widget.subscriberCidNumberProvider;
    if (provider != null) return provider();
    final identity = await context.read<CurrentUserContext>().resolve();
    return identity?.cidNumber;
  }

  Future<void> _load() async {
    final inst = await widget.repository.getByCid(widget.cidNumber);
    final cidNumber = await _resolveSubscriberCidNumber();
    if (!mounted) return;
    if (inst == null) {
      setState(() => _loading = false);
      return;
    }
    // 全机构统一开提案入口:固定治理档使用静态档(含安全基金等专户),其余机构
    // 由目录 CID 派生主体。是否能发起某类提案交给 ProposalCapabilityRegistry。
    final govInfo =
        widget.repository.governanceInfo(inst.cidNumber) ??
        _infoFromInstitution(inst);
    final subscribed = cidNumber == null
        ? false
        : await widget.repository.isSubscribed(cidNumber, inst.cidNumber);
    final areaPath = await widget.repository.institutionAreaPath(inst);
    if (!mounted) return;
    setState(() {
      _inst = inst;
      _govInfo = govInfo;
      _subscriberCidNumber = cidNumber;
      _subscribed = subscribed;
      _accounts = institutionAccountIdRows(inst);
      _areaPath = areaPath;
      _loading = false;
    });
    unawaited(_loadDynamics());
  }

  /// 为非治理注册机构从 Institution 派生 InstitutionInfo。
  /// CID 始终是机构主键，主/费账户只进入具体账户操作。
  InstitutionInfo _infoFromInstitution(Institution inst) {
    final rows = institutionAccountIdRows(inst);
    if (rows.length < 2) {
      throw StateError('机构账户集合缺少主账户或费用账户: ${inst.cidNumber}');
    }
    final main = rows.first.accountId;
    final fee = rows[1].accountId;
    return InstitutionInfo(
      fullName: inst.fullName,
      shortName: inst.cidShortNameOrFullName,
      cidFullNameEn: inst.fullName, // 普通公权机构暂无英文名,中文兜底
      cidShortNameEn: inst.cidShortNameOrFullName,
      cidNumber: inst.cidNumber,
      orgType: inst.orgType,
      accounts: InstitutionAccounts(mainAccountId: main, feeAccountId: fee),
      adminCode: inst.orgCode,
    );
  }

  Future<void> _loadDynamics({bool force = false}) async {
    final inst = _inst;
    if (inst == null) return;
    // 名册、权限、余额和提案独立完成，任何一项的失败不能抹去其它已读结果。
    await Future.wait<void>([
      _loadAssignments(force: force),
      _loadRole(force: force),
      if (_isGovernance)
        _loadGovernanceProposals(force: force)
      else
        _loadPublicProposals(inst),
    ]);
  }

  /// 所有机构名册只由这一条路径写入；失败保留旧名单，未核实不显示0人。
  Future<void> _loadAssignments({bool force = false}) async {
    final inst = _inst;
    if (inst == null) return;
    final generation = ++_adminGeneration;
    setState(() {
      _assignmentsLoading = true;
    });
    try {
      final roster = await _chainState.roster(inst);
      if (!mounted || generation != _adminGeneration) return;
      setState(() {
        _adminViews = roster.persons;
        _rosterRoles = roster.roles;
        _assignmentsLoaded = true;
        _assignmentsLoading = false;
      });
    } on Object {
      if (!mounted || generation != _adminGeneration) return;
      setState(() {
        _assignmentsLoading = false;
      });
    }
  }

  /// 当前钱包角色独立核对；失败或重查期间撤销旧操作状态，不影响人员展示。
  Future<void> _loadRole({bool force = false}) async {
    final identity = _accountIdentity;
    final govInfo = _govInfo;
    final resolver = _contextResolver;
    if (identity == null || govInfo == null || resolver == null) {
      return;
    }
    final generation = ++_roleGeneration;
    setState(() {
      _roleLoading = true;
      _roleFailed = false;
      _adminWallets = const [];
      _isCurrentUserAdmin = false;
    });
    try {
      final ctx = await resolver.resolve(
        actorCidNumber: govInfo.cidNumber,
        knownInstitution: govInfo,
      );
      if (!mounted || generation != _roleGeneration) return;
      setState(() {
        _govInfo = ctx.institution ?? govInfo;
        _adminWallets = ctx.adminWallets;
        _isCurrentUserAdmin = ctx.isAdmin;
        _roleLoading = false;
      });
    } on Object {
      if (!mounted || generation != _roleGeneration) return;
      setState(() {
        _roleLoading = false;
        _roleFailed = true;
      });
    }
  }

  Future<void> _loadGovernanceProposals({bool force = false}) async {
    final govInfo = _govInfo;
    final feed = _multisigTransferFeed;
    if (govInfo == null || feed == null) return;
    try {
      final proposals = await feed.fetchInstitutionVisibleProposals(
        govInfo,
        forceRefresh: force,
      );
      final summaries = proposals
          .map(
            (p) => LocalProposalSummary.fromProposal(p, institution: govInfo),
          )
          .toList(growable: false);
      await ProposalLocalStore.instance.upsertSummaries(summaries);
      await ProposalLocalStore.instance.putInstitutionIndex(
        govInfo.cidNumber,
        summaries.map((s) => s.proposalId).toList(growable: false),
      );
      if (!mounted) return;
      setState(() {
        _govProposals = summaries;
        _govProposalDetailsById = {
          for (final p in proposals) p.meta.proposalId: p,
        };
      });
    } catch (_) {
      // 同上,保持空。
    }
  }

  // ──── 注册机构路径加载 ────

  Future<void> _loadPublicProposals(Institution inst) async {
    try {
      final proposals = await _chainState.proposals(inst);
      if (mounted) setState(() => _publicProposals = proposals);
    } on Object {
      // 保持空。
    }
  }

  Future<void> _toggleSubscribe() async {
    final inst = _inst;
    final cidNumber = _subscriberCidNumber;
    if (inst == null || cidNumber == null) return;
    if (_subscribed) {
      await widget.repository.unsubscribe(cidNumber, inst.cidNumber);
    } else {
      await widget.repository.subscribe(cidNumber, inst.cidNumber);
    }
    if (!mounted) return;
    setState(() => _subscribed = !_subscribed);
  }

  @override
  Widget build(BuildContext context) {
    final inst = _inst;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(inst?.cidShortNameOrFullName ?? '机构'),
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (inst != null && _subscriberCidNumber != null)
            IconButton(
              tooltip: _subscribed ? '取消关注' : '订阅关注',
              icon: Icon(
                _subscribed ? Icons.bookmark : Icons.bookmark_border,
                color: _subscribed ? AppTheme.primary : AppTheme.textSecondary,
              ),
              onPressed: _toggleSubscribe,
            ),
        ],
      ),
      body: _buildBody(inst),
    );
  }

  Widget _buildBody(Institution? inst) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (inst == null) {
      return const Center(
        child: Text('未找到该机构', style: TextStyle(color: AppTheme.textTertiary)),
      );
    }
    return ListView(
      padding: EdgeInsets.all(AppLayout.scaledValue(16)),
      children: [
        _infoCard(inst),
        SizedBox(height: AppLayout.scaledValue(12)),
        _accountsEntry(inst),
        SizedBox(height: AppLayout.scaledValue(12)),
        _proposalEntry(),
        // 法律原文(仅立法机构):查看该机构全部法律。发起立法=类B,归口提案入口
        // (proposal_entry_page,按 registry 立法机构→发起立法),不在详情页另设入口。
        if (_lawTarget(inst) != null) ...[
          SizedBox(height: AppLayout.scaledValue(12)),
          _lawOriginalEntry(inst),
        ],
        SizedBox(height: AppLayout.scaledValue(12)),
        _assignmentsEntry(),
        SizedBox(height: AppLayout.scaledValue(12)),
        _proposalList(),
      ],
    );
  }

  // ── ① 机构信息卡(全称/身份CID号/主账户/余额/法代/所属地;非法人 +所属上级法人) ──

  Widget _infoCard(Institution inst) {
    final mainSs58 = _accounts.isNotEmpty
        ? _accounts.first.accountAddress
        : '—';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(14),
          vertical: AppLayout.scaledValue(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoTile(
              icon: Icons.account_balance_outlined,
              label: '全称',
              value: inst.fullName,
            ),
            Divider(height: AppLayout.scaledValue(18)),
            _infoTile(
              icon: Icons.badge_outlined,
              label: '身份CID号',
              value: formatIdentityCidText(inst.cidNumber),
            ),
            Divider(height: AppLayout.scaledValue(18)),
            _infoTile(
              icon: Icons.account_balance_wallet_outlined,
              label: '主账户',
              value: mainSs58,
            ),
            Divider(height: AppLayout.scaledValue(18)),
            _infoTile(
              icon: Icons.payments_outlined,
              label: '主账户余额',
              value: '',
              valueWidget: ChainBalanceText(
                accountId: _accounts.first.accountId,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(13),
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: AppLayout.scaledValue(18)),
            _infoTile(
              icon: Icons.person_outline,
              label: '法定代表人',
              value: '${inst.familyName ?? ''}${inst.givenName ?? ''}',
            ),
            Divider(height: AppLayout.scaledValue(18)),
            _infoTile(
              icon: Icons.place_outlined,
              label: '所属地',
              value: _areaPath,
            ),
            // 非法人加显「所属上级法人全称」(ADR-028 决策 6)。
            if (inst.isUnincorporated) ...[
              Divider(height: AppLayout.scaledValue(18)),
              _infoTile(
                icon: Icons.account_tree_outlined,
                label: '所属上级法人',
                value: inst.parentCid ?? '',
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──── ② 机构账户入口 ────

  Widget _accountsEntry(Institution inst) {
    return _entryCard(
      icon: Icons.account_balance_wallet_outlined,
      title: '机构账户',
      subtitle: '共 ${_accounts.length} 个账户',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InstitutionAccountsPage(institution: inst),
        ),
      ),
    );
  }

  // ──── ③ 提案入口(按主体能力统一展示)────

  Widget _proposalEntry() {
    return _entryCard(
      icon: Icons.how_to_vote_outlined,
      title: '发起提案',
      subtitle: _roleFailed
          ? '当前钱包权限暂不可用，请重试'
          : _roleLoading
          ? '正在核实当前钱包权限'
          : _isCurrentUserAdmin
          ? '转账 / 管理员更换 / …（链上按岗位授权）'
          : '激活机构签名钱包后按岗位授权发起',
      onTap: _openProposalTypes,
    );
  }

  // ──── 法律原文入口(仅立法机构,ADR-028 P3-1)────

  /// 法律列表范围使用原省码和省内市号；非立法机构不提供入口。
  ({LawTier tier, LawRegion region})? _lawTarget(Institution inst) {
    const national = {'NLG', 'NRP', 'NSN', 'NED'};
    const provincial = {'PLG', 'PRP', 'PSN'};
    const municipal = {'CLEG'};
    final code = inst.orgCode;
    final tier = national.contains(code)
        ? LawTier.national
        : provincial.contains(code)
        ? LawTier.provincial
        : municipal.contains(code)
        ? LawTier.municipal
        : null;
    if (tier == null) return null;
    return (
      tier: tier,
      region: LawRegion.fromCodes(tier, inst.provinceCode, inst.cityCode),
    );
  }

  Widget _lawOriginalEntry(Institution inst) {
    final target = _lawTarget(inst)!;
    return _entryCard(
      icon: Icons.menu_book_outlined,
      title: '法律原文',
      subtitle: '该机构制定的全部法律',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LawListPage(
            tier: target.tier,
            region: target.region,
            title: '${inst.cidShortNameOrFullName} · 法律原文',
          ),
        ),
      ),
    );
  }

  Future<void> _openProposalTypes() async {
    final govInfo = _govInfo;
    if (govInfo == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProposalEntryPage(
          institution: govInfo,
          orgCode: _inst?.orgCode ?? '',
          icon: Icons.account_balance,
          badgeColor: AppTheme.primary,
          adminWallets: _adminWallets,
          isActivated: _isCurrentUserAdmin,
        ),
      ),
    );
    if (mounted) unawaited(_loadDynamics(force: true));
  }

  // ──── ④ 管理员入口(治理→AdminListPage 含激活;公权→只读列表)────

  /// 管理员入口保持单一卡片；岗位/权限故障不增加外部按钮，也不能伪造零人。
  Widget _assignmentsEntry() => _entryCard(
    icon: Icons.people_outline,
    title: '人员任职',
    subtitle: _assignmentsLoaded
        ? '共 ${_adminViews.length} 位人员'
        : _assignmentsLoading
        ? '正在读取任职'
        : '人员任职暂不可用',
    onTap: !_assignmentsLoaded
        ? null
        : _accountIdentity != null
        ? _openGovernanceAdminList
        : _openPublicAdminList,
  );

  void _openGovernanceAdminList() {
    final govInfo = _govInfo;
    final identity = _accountIdentity;
    if (govInfo == null || identity == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstitutionAssignmentsPage(
          institution: govInfo,
          identity: identity,
          persons: _adminViews,
          roles: _rosterRoles,
        ),
      ),
    );
  }

  void _openPublicAdminList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicInstitutionAssignmentsPage(
          persons: _adminViews,
          roles: _rosterRoles,
          identity: _accountIdentity,
        ),
      ),
    );
  }

  // ──── ⑤ 提案列表 ────

  Widget _proposalList() {
    final hasGov = _isGovernance && _govProposals.isNotEmpty;
    final hasPublic = !_isGovernance && _publicProposals.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppLayout.scaledValue(2),
            bottom: AppLayout.scaledValue(12),
          ),
          child: Text(
            '提案列表',
            style: TextStyle(
              fontSize: AppLayout.scaledValue(16),
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
        ),
        if (!hasGov && !hasPublic)
          _emptyProposalState()
        else if (_isGovernance)
          ...List.generate(_govProposals.length, (i) {
            final s = _govProposals[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: AppLayout.scaledValue(
                  i < _govProposals.length - 1 ? 10 : 0,
                ),
              ),
              child: _govProposalCard(s),
            );
          })
        else
          ...List.generate(_publicProposals.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: AppLayout.scaledValue(
                  i < _publicProposals.length - 1 ? 10 : 0,
                ),
              ),
              child: _publicProposalCard(_publicProposals[i]),
            );
          }),
      ],
    );
  }

  Widget _emptyProposalState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppLayout.scaledValue(24)),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.ballot_outlined,
            size: AppLayout.scaledValue(40),
            color: AppTheme.textTertiary,
          ),
          SizedBox(height: AppLayout.scaledValue(8)),
          Text(
            '暂无提案',
            style: TextStyle(
              fontSize: AppLayout.scaledValue(14),
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 治理:可点卡片 → _openProposalDetail。
  Widget _govProposalCard(LocalProposalSummary s) {
    final statusColor = AppTheme.proposalStatusColor(s.status);
    return InkWell(
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
      onTap: () => _openProposalDetail(s),
      child: _proposalCardBody(
        title: s.displayId,
        subtitle: s.listSubtitle,
        statusColor: statusColor,
        statusLabel: _statusLabel(s.status),
        trailingChevron: true,
      ),
    );
  }

  // 公权:只读卡片。
  Widget _publicProposalCard(InstitutionProposalSummary p) {
    final statusColor = AppTheme.proposalStatusColor(p.status);
    return _proposalCardBody(
      title: p.idLabel,
      subtitle: null,
      statusColor: statusColor,
      statusLabel: p.statusLabel,
      trailingChevron: false,
    );
  }

  Widget _proposalCardBody({
    required String title,
    required String? subtitle,
    required Color statusColor,
    required String statusLabel,
    required bool trailingChevron,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(14),
        vertical: AppLayout.scaledValue(12),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: AppLayout.scaledValue(36),
            height: AppLayout.scaledValue(36),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
            ),
            child: Icon(
              Icons.how_to_vote_outlined,
              size: AppLayout.scaledValue(18),
              color: statusColor,
            ),
          ),
          SizedBox(width: AppLayout.scaledValue(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProposalCardHeader(
                  subjectName: _inst?.shortName,
                  proposalNumber: title,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  SizedBox(height: AppLayout.scaledValue(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(12),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppLayout.scaledValue(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaledValue(8),
              vertical: AppLayout.scaledValue(2),
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
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
          if (trailingChevron) ...[
            SizedBox(width: AppLayout.scaledValue(4)),
            Icon(
              Icons.chevron_right,
              size: AppLayout.scaledValue(20),
              color: AppTheme.textTertiary,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(int status) => switch (status) {
    1 => '已通过',
    2 => '已拒绝',
    3 => '已执行',
    4 => '执行失败',
    _ => '投票中',
  };

  // ──── 治理提案详情路由(port 自治理详情页)────

  Future<void> _openProposalDetail(LocalProposalSummary summary) async {
    final govInfo = _govInfo;
    if (govInfo == null) return;
    final proposal = await _resolveProposalDetail(summary);
    if (!mounted) return;
    if (proposal == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('提案详情读取失败，请稍后重试')));
      return;
    }
    final proposalId = proposal.meta.proposalId;
    final ctx = ProposalContext(
      institution: govInfo,
      adminWallets: _adminWallets,
      role: _isCurrentUserAdmin ? ProposalRole.admin : ProposalRole.viewer,
    );
    if (proposal.runtimeUpgradeDetail != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RuntimeUpgradeDetailPage(
            proposalId: proposalId,
            proposalContext: ctx,
          ),
        ),
      );
    } else if (MultisigTransferProposalAdapter.matches(proposal)) {
      await MultisigTransferProposalAdapter.openDetail(
        context,
        proposal: proposal,
        institution: govInfo,
        proposalContext: ctx,
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该联合提案详情页正在开发中')));
      return;
    }
    if (mounted) unawaited(_loadDynamics(force: true));
  }

  Future<ProposalWithDetail?> _resolveProposalDetail(
    LocalProposalSummary summary,
  ) async {
    final cached = _govProposalDetailsById[summary.proposalId];
    if (cached != null) return cached;
    final feed = _multisigTransferFeed;
    if (feed == null) return null;
    try {
      final fresh = await feed.fetchProposalsByIds([summary.proposalId]);
      if (fresh.isEmpty) return null;
      final proposal = fresh.first;
      if (mounted) {
        setState(() {
          _govProposalDetailsById = {
            ..._govProposalDetailsById,
            proposal.meta.proposalId: proposal,
          };
        });
      }
      return proposal;
    } catch (_) {
      return null;
    }
  }

  // ──── 公用零件 ────

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Widget? valueWidget,
  }) {
    return Row(
      children: [
        Container(
          width: AppLayout.scaledValue(32),
          height: AppLayout.scaledValue(32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(9)),
          ),
          child: Icon(
            icon,
            size: AppLayout.scaledValue(16),
            color: AppTheme.primary,
          ),
        ),
        SizedBox(width: AppLayout.scaledValue(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(11),
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppLayout.scaledValue(2)),
              valueWidget ??
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(13),
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaledValue(14),
            vertical: AppLayout.scaledValue(12),
          ),
          child: Row(
            children: [
              Container(
                width: AppLayout.scaledValue(36),
                height: AppLayout.scaledValue(36),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: Icon(
                  icon,
                  size: AppLayout.scaledValue(18),
                  color: AppTheme.primaryDark,
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppLayout.scaledValue(15),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    SizedBox(height: AppLayout.scaledValue(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppLayout.scaledValue(12),
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppLayout.scaledValue(20),
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 展示机构全部账户并通过SDK可见性订阅读取余额。

/// 统一机构「全部账户」页(ADR-028 决策 2)——替代公权/治理两套账户页。
///
/// 账户行由 [institutionAccountIdRows] 统一构造(固定治理档用 china 固定
/// 账户、普通机构本地派生);余额由 SDK 统一订阅服务批量读取(ADR-018 R2 精确整键批量)。
class InstitutionAccountsPage extends StatefulWidget {
  const InstitutionAccountsPage({super.key, required this.institution});

  final Institution institution;

  @override
  State<InstitutionAccountsPage> createState() =>
      _InstitutionAccountsPageState();
}

class _InstitutionAccountsPageState extends State<InstitutionAccountsPage> {
  late final List<InstitutionAccountRow> _rows = institutionAccountIdRows(
    widget.institution,
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('全部账户'),
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        itemCount: _rows.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: AppLayout.scaled(context, 10)),
        itemBuilder: (context, i) => _AccountCard(row: _rows[i]),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.row});

  final InstitutionAccountRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              ChainBalanceText(
                accountId: row.accountId,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 13.5),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 6)),
          Text(
            row.accountAddress,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 11.5),
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// 展示机构人员任职，节点访问授权独立验真且不保存本机资格。

class InstitutionAssignmentsPage extends StatelessWidget {
  const InstitutionAssignmentsPage({
    super.key,
    required this.persons,
    required this.roles,
    this.identity,
    this.institution,
  });
  final List<InstitutionPersonView> persons;
  final List<InstitutionRole> roles;
  final InstitutionIdentity? identity;
  final InstitutionInfo? institution;

  Future<void> _roleAccess(
    BuildContext context,
    InstitutionPersonView person,
  ) async {
    final subject = identity, account = person.accountId;
    if (subject == null || account == null) return;
    final sdk = context.read<CitizenSdk>();
    final wallets = (await sdk.getWalletState().result).accounts;
    if (!wallets.any((wallet) => wallet.accountId == account)) return;
    final payload = await InstitutionChainService(chain: sdk)
        .buildRoleAccessPayload(identity: subject, accountId: account);
    if (!context.mounted) return;
    await signCitizenPayload(
      signing: sdk,
      context: context,
      accountId: account,
      payload: payload,
      action: CitizenQrActions.roleAccess,
    );
  }

  List<Widget> _cards(
    BuildContext context,
    InstitutionRole role,
    CitizenBalances balances,
  ) {
    final assigned = persons
        .where((p) => p.assignments.any((a) => a.roleCode == role.roleCode))
        .toList();
    return List.generate(role.seats, (index) {
      final person = index < assigned.length ? assigned[index] : null;
      final account = person?.accountId;
      final balance = account == null ? null : balances.accountState(account);
      return InstitutionAssignmentCard(
        person: person,
        role: role,
        index: index + 1,
        balanceFen: balance?.value?.freeFen,
        balanceError: balance?.hasError ?? false,
        trailing: identity == null || account == null || person == null
            ? null
            : TextButton(
                onPressed: () => unawaited(_roleAccess(context, person)),
                child: const Text('节点访问授权'),
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: persons.map((p) => p.accountId).whereType<String>(),
    builder: (context, balances) => Scaffold(
      appBar: AppBar(title: const Text('人员任职')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (institution != null) Text(institution!.fullName),
          for (final role in roles) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${role.roleName}列表',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '共 ${role.seats} 席',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ..._cards(context, role, balances),
          ],
        ],
      ),
    ),
  );
}

// 同一岗位按链上席位展示任职卡；空席保留字段，人员CID不以钱包替代。

class InstitutionAssignmentCard extends StatelessWidget {
  const InstitutionAssignmentCard({
    super.key,
    this.person,
    required this.role,
    required this.index,
    this.balanceFen,
    this.balanceError = false,
    this.trailing,
  });
  final InstitutionPersonView? person;
  final InstitutionRole role;
  final int index;
  final BigInt? balanceFen;
  final bool balanceError;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final current = person;
    final assignments = current?.assignments.where(
      (a) => a.roleCode == role.roleCode,
    );
    final assignment = assignments == null || assignments.isEmpty
        ? null
        : assignments.first;
    final name = current == null
        ? '暂无任职'
        : '${current.familyName}${current.givenName}'.trim();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget field(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: TextStyle(color: muted)),
        ),
        Expanded(child: Text(value)),
      ],
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircleAvatar(
                    child: Text('$index', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${role.roleName} · ${name.isEmpty ? '未填写' : name}',
                  ),
                ),
                if (current != null && trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('来源：${assignment?.source.label ?? '暂无'}'),
                Text('任期：${assignment?.termLabel ?? '暂无'}'),
              ],
            ),
            const SizedBox(height: 10),
            field(
              '账户余额：',
              current == null || current.accountId == null
                  ? '暂无'
                  : balanceError
                  ? '读取失败'
                  : balanceFen == null
                  ? '读取中…'
                  : '${formatFen(balanceFen!)} 元',
            ),
            const SizedBox(height: 10),
            field('身份CID号：', current?.personCid ?? '暂无'),
            const SizedBox(height: 10),
            field(
              '绑定账户：',
              current?.accountId == null
                  ? '暂无'
                  : citizenSs58FromAccountId(current!.accountId!),
            ),
          ],
        ),
      ),
    );
  }
}
