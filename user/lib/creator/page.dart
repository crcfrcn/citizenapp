// 展示创作者管理页、概览、档位卡片及编辑弹窗。

import 'package:citizen_system/format.dart';
import 'package:citizen_chain/service.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:citizen_user/creator/service.dart' show BillingPeriod, BillingPeriodKey, CreatorException, CreatorMembershipStatus, CreatorOverview, CreatorPageData, CreatorPlan, CreatorService, CreatorTier, creatorPlanFromChain;
import 'package:citizen_user/membership/page.dart' show MembershipPage;
import 'package:citizen_user/membership/service.dart' show MembershipRevision;
import 'package:citizen_user/identity/state.dart' show CidBusinessGate, CidBusinessStatus, FinalizedIdentityResolver;
import 'package:citizen_user/context.dart' show CurrentUserContext, IdentityBinding;
import 'package:citizen_user/identity/badge.dart' show IdentityBadge, IdentityRegisterGuide, identityBadgeStyle;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_system/theme.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

// 展示当前创作者会员、档位及统计，并复用按身份隔离的链缓存。

/// 「我的 → 创作者」：会员、档位与统计分别就绪，共用按身份隔离的链缓存。
class CreatorPage extends StatefulWidget {
  const CreatorPage({
    super.key,
    CreatorService? service,
    this.currentUserContext,
  }) : _service = service;

  final CreatorService? _service;
  final CurrentUserContext? currentUserContext;

  @override
  State<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends State<CreatorPage> {
  late final CreatorService _service;
  ChainDataService? _chainData;
  AccountSecurityService? _accountSecurity;
  CurrentUserContext? _currentUser;
  IdentityBinding? _binding;
  bool _dependenciesReady = false;
  CreatorPageData _data = const CreatorPageData();
  bool _businessReady = false;
  bool _unregistered = false;
  bool _refreshing = false;
  String? _error;
  String? _chainError;
  String _cidNumber = '';
  int _loadGeneration = 0;
  int _refreshGeneration = 0;

  bool get _canManage =>
      _businessReady &&
      _matches(_chainData?.snapshot) &&
      _chainData?.isStale == false &&
      _data.membershipStatus == CreatorMembershipStatus.active &&
      _data.plan != null;

  @override
  void initState() {
    super.initState();
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _chainData = context.read<ChainDataService?>();
    _chainData?.addListener(_onChainData);
    _currentUser =
        widget.currentUserContext ?? context.read<CurrentUserContext?>();
    _accountSecurity = context.read<AccountSecurityService?>();
    _accountSecurity?.revision.addListener(_onIdentityChanged);
    _service =
        widget._service ??
        CreatorService(
          chainData: _chainData,
          wallet: context.read<CitizenSdk>(),
          chain: context.read<CitizenSdk>(),
          transactions: context.read<CitizenSdk>(),
          identityResolver: context.read<FinalizedIdentityResolver>(),
          sessionProvider: context.read<SquareSessionProvider>(),
        );
    _dependenciesReady = true;
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _chainData?.removeListener(_onChainData);
    _accountSecurity?.revision.removeListener(_onIdentityChanged);
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    super.dispose();
  }

  void _onIdentityChanged() => unawaited(_bootstrap());

  bool _matches(ChainDataSnapshot? snapshot) {
    final binding = _binding;
    return binding != null &&
        snapshot?.genesisHash == binding.genesisHash &&
        snapshot?.accountId == binding.accountId &&
        snapshot?.ownCid == binding.cidNumber &&
        snapshot?.own?.identity?.bindRev == binding.bindRev;
  }

  void _onChainData() {
    if (!mounted || !_businessReady) return;
    final snapshot = _chainData?.snapshot;
    final matches = _matches(snapshot);
    final ready = matches && _chainData?.isStale == false;
    setState(() {
      _data = CreatorPageData(
        membershipStatus: !ready
            ? CreatorMembershipStatus.unresolved
            : snapshot!.memberActive(_cidNumber)
            ? CreatorMembershipStatus.active
            : CreatorMembershipStatus.inactive,
        memberLevel: ready ? snapshot!.memberLevel(_cidNumber) : null,
        plan: matches && snapshot!.own?.creatorTiers != null
            ? creatorPlanFromChain(snapshot.own!.creatorTiers)
            : null,
        overview: matches ? _data.overview : null,
      );
      if (ready && _data.plan != null) _chainError = null;
      if (_chainData?.error != null) _chainError = '会员状态暂不可用，请重试';
    });
  }

  void _onMembershipChanged() {
    final event = MembershipRevision.instance.listenable.value;
    if (mounted && _businessReady && event?.cidNumber == _cidNumber) {
      // 广播只重读统一缓存；最终区块同步负责推进会员事实。
      _onChainData();
    }
  }

  Future<void> _restoreOverview(int generation) async {
    final cid = _cidNumber;
    final binding = _binding;
    final refreshGeneration = _refreshGeneration;
    try {
      final overview = await _service.cachedOverview(cid);
      if (!mounted ||
          generation != _loadGeneration ||
          refreshGeneration != _refreshGeneration ||
          binding != _binding ||
          cid != _cidNumber ||
          overview == null) {
        return;
      }
      setState(
        () => _data = CreatorPageData(
          membershipStatus: _data.membershipStatus,
          memberLevel: _data.memberLevel,
          plan: _data.plan,
          overview: overview,
        ),
      );
    } on Object {
      // 统计缓存故障不影响订阅和档位。
    }
  }

  Future<void> _prepareChain(int generation) async {
    final source = _chainData;
    final binding = _binding;
    if (source == null || binding == null) return;
    try {
      await source.ensureOwnCreator(
        genesisHash: binding.genesisHash,
        accountId: binding.accountId,
        cidNumber: binding.cidNumber,
        bindRev: binding.bindRev,
      );
      if (!mounted || generation != _loadGeneration) return;
      _onChainData();
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      _onChainData();
      setState(() => _chainError = '会员状态暂不可用，请重试');
    }
  }

  Future<void> _bootstrap() async {
    final generation = ++_loadGeneration;
    ++_refreshGeneration;
    setState(() {
      _businessReady = false;
      _unregistered = false;
      _binding = null;
      _data = const CreatorPageData();
      _refreshing = false;
      _error = null;
      _chainError = null;
    });
    try {
      final decision = await context.read<CidBusinessGate>().resolve();
      final current = await _currentUser?.resolve();
      if (!mounted || generation != _loadGeneration) return;
      if (decision.status == CidBusinessStatus.unregistered) {
        setState(() => _unregistered = true);
        return;
      }
      final cid = decision.cidNumber?.trim() ?? '';
      final binding = current?.binding;
      if (decision.status != CidBusinessStatus.ready ||
          cid.isEmpty ||
          (_chainData != null &&
              (binding == null ||
                  binding.cidNumber != cid ||
                  binding.accountId != current?.accountId))) {
        setState(() => _error = '暂时无法核实身份CID号，请重试');
        return;
      }
      setState(() {
        _businessReady = true;
        _cidNumber = cid;
        _binding = binding;
      });
      _onChainData();
      await Future.wait([
        _prepareChain(generation),
        _restoreOverview(generation),
      ]);
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = '暂时无法核实身份CID号，请重试');
    }
  }

  Future<void> _refresh() async {
    if (!_businessReady || _refreshing) return;
    final owner = ++_refreshGeneration;
    final generation = _loadGeneration;
    final binding = _binding;
    final cid = _cidNumber;
    setState(() => _refreshing = true);
    try {
      await _prepareChain(generation);
      if (!mounted ||
          generation != _loadGeneration ||
          owner != _refreshGeneration ||
          _data.membershipStatus != CreatorMembershipStatus.active) {
        return;
      }
      final result = await _service.load(expectedCidNumber: cid);
      if (!mounted ||
          owner != _refreshGeneration ||
          generation != _loadGeneration ||
          binding != _binding ||
          !_matches(_chainData?.snapshot)) {
        return;
      }
      _onChainData();
      setState(() {
        _data = CreatorPageData(
          membershipStatus: _data.membershipStatus,
          memberLevel: _data.memberLevel,
          plan: _data.plan,
          overview: result.overview ?? _data.overview,
        );
        _error = null;
      });
    } on Object {
      if (mounted &&
          owner == _refreshGeneration &&
          generation == _loadGeneration) {
        setState(() => _error = '统计暂不可用，请重试');
      }
    } finally {
      if (mounted && owner == _refreshGeneration) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('创作者'),
      actions: [
        if (_data.membershipStatus == CreatorMembershipStatus.active)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: IdentityBadge(
                key: const ValueKey('creator-membership-badge'),
                style: identityBadgeStyle(
                  cidLevel: null,
                  memberLevel: _data.memberLevel,
                  membergateActive: true,
                )!,
                tooltip: switch (_data.memberLevel) {
                  'freedom' => '自由会员',
                  'democracy' => '民主会员',
                  'spark' => '薪火会员',
                  _ => '会员',
                },
              ),
            ),
          )
        else
          TextButton(
            key: const ValueKey('creator-subscribe'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.success),
            onPressed:
                _businessReady &&
                    _data.membershipStatus == CreatorMembershipStatus.inactive
                ? _openMembership
                : null,
            child: const Text('订阅'),
          ),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    if (_unregistered) {
      return IdentityRegisterGuide(
        description: '注册后即可开通创作者会员。',
        onRegistered: () => unawaited(_bootstrap()),
      );
    }
    if (!_businessReady) {
      if (_error == null) return const SizedBox.expand();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _inlineError(_error!),
      );
    }
    return _activeView(
      _data.plan ?? CreatorPlan.empty(),
      _data.overview ?? CreatorOverview.zero,
      tiersReady: _data.plan != null,
      overviewResolved: _data.overview != null,
      canManage: _canManage,
    );
  }

  Widget _activeView(
    CreatorPlan plan,
    CreatorOverview overview, {
    required bool tiersReady,
    required bool overviewResolved,
    required bool canManage,
  }) {
    final atMax = plan.tiers.length >= CreatorPlan.maxTiers;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          CreatorOverviewCard(
            overview: overview,
            resolved: overviewResolved,
            membershipActive:
                _data.membershipStatus == CreatorMembershipStatus.active,
          ),
          if (_chainError != null || _error != null) ...[
            SizedBox(height: AppLayout.scaledValue(12)),
            _inlineError(_chainError ?? _error!),
          ],
          SizedBox(height: AppLayout.scaledValue(16)),
          if (plan.tiers.isEmpty)
            _emptyTiers(resolved: tiersReady, canManage: canManage)
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaledValue(2),
              ),
              child: Row(
                children: [
                  Text(
                    '我的会员档',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(14),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${plan.tiers.length} / ${CreatorPlan.maxTiers}',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(12),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            for (final tier in plan.tiers) ...[
              CreatorTierCard(
                tier: tier,
                onEdit: canManage ? () => _openEdit(tier) : null,
              ),
              SizedBox(height: AppLayout.scaledValue(12)),
            ],
            _addTierButton(atMax, enabled: canManage),
          ],
          SizedBox(height: AppLayout.scaledValue(16)),
          _subscribersEntry(
            overview.subscriberCount,
            resolved: overviewResolved,
            enabled: canManage && overviewResolved,
          ),
          SizedBox(height: AppLayout.scaledValue(14)),
          Center(
            child: Text(
              '价格以公民币结算 · 订阅款全额进你的钱包 · 保存只签名一次',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(11),
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTiers({required bool resolved, required bool canManage}) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(16),
        vertical: AppLayout.scaledValue(24),
      ),
      child: Column(
        children: [
          Container(
            width: AppLayout.scaledValue(52),
            height: AppLayout.scaledValue(52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(24),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              Icons.storefront_outlined,
              size: AppLayout.scaledValue(26),
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(12)),
          Text(
            resolved ? '还没有会员档' : '会员档',
            style: TextStyle(
              fontSize: AppLayout.scaledValue(15),
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
          Text(
            resolved ? '创建第一个会员档，粉丝就能用公民币订阅你。' : '创建和管理你的会员档。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          FilledButton.icon(
            onPressed: canManage ? () => _openEdit(null) : null,
            icon: Icon(Icons.add, size: AppLayout.scaledValue(19)),
            label: const Text('创建会员档'),
          ),
        ],
      ),
    );
  }

  Widget _addTierButton(bool atMax, {required bool enabled}) {
    return InkWell(
      onTap: !enabled || atMax ? null : () => _openEdit(null),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: !enabled || atMax ? AppTheme.border : AppTheme.primaryLight,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: AppLayout.scaledValue(18),
              color: !enabled || atMax
                  ? AppTheme.textTertiary
                  : AppTheme.primary,
            ),
            SizedBox(width: AppLayout.scaledValue(6)),
            Text(
              atMax ? '已达 ${CreatorPlan.maxTiers} 档上限' : '新增会员档',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(14),
                fontWeight: FontWeight.w600,
                color: !enabled || atMax
                    ? AppTheme.textTertiary
                    : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subscribersEntry(
    int count, {
    required bool resolved,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled
          ? () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('订阅者明细即将上线')))
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(14),
          vertical: AppLayout.scaledValue(13),
        ),
        child: Row(
          children: [
            Container(
              width: AppLayout.scaledValue(30),
              height: AppLayout.scaledValue(30),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.info.withAlpha(24),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                Icons.group_outlined,
                size: AppLayout.scaledValue(17),
                color: AppTheme.info,
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(10)),
            Expanded(
              child: Text(
                '谁订阅了我',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              resolved ? '$count 位' : '--',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: AppTheme.textSecondary,
              ),
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
    );
  }

  Widget _inlineError(String message) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: EdgeInsets.all(AppLayout.scaledValue(14)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.textTertiary),
          SizedBox(width: AppLayout.scaledValue(10)),
          Expanded(
            child: Text(
              identityCidUiText(message),
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _refreshing
                ? null
                : () => _businessReady ? _refresh() : _bootstrap(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(CreatorTier? tier) async {
    _onChainData();
    if (!_canManage) return;
    final generation = _loadGeneration;
    final binding = _binding;
    final plan = await showModalBottomSheet<CreatorPlan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreatorPlanEditSheet(
        service: _service,
        currentTiers: _data.plan!.tiers,
        editing: tier,
      ),
    );
    if (plan == null ||
        !mounted ||
        generation != _loadGeneration ||
        binding != _binding) {
      return;
    }
    // 保存结果不另造会员或档位真源；由共享最终块缓存推进页面。
    await _prepareChain(generation);
  }

  Future<void> _openMembership() async {
    _onChainData();
    if (!_businessReady ||
        _data.membershipStatus != CreatorMembershipStatus.inactive) {
      return;
    }
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const MembershipPage()));
    if (mounted) _onChainData();
  }
}

// 展示创作者有效订阅人数及预计月收入和估算提示。

/// 创作者概览卡：订阅人数 + 预计月收入（金色锚点）+ 预计提示。
class CreatorOverviewCard extends StatelessWidget {
  const CreatorOverviewCard({
    super.key,
    required this.overview,
    this.resolved = true,
    this.membershipActive = false,
  });

  final CreatorOverview overview;

  /// false 表示尚未取得本地展示快照；只展示中性结构，不出现等待或同步文案。
  final bool resolved;
  final bool membershipActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
      padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppLayout.scaled(context, 26),
                height: AppLayout.scaled(context, 26),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: AppLayout.scaled(context, 16),
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 8)),
              Text(
                '我的创作者会员',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 8),
                  vertical: AppLayout.scaled(context, 2),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(20),
                  ),
                ),
                child: Text(
                  membershipActive ? '已开通' : '创作者',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 11),
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          Row(
            children: [
              Expanded(
                child: _stat(
                  '已登记订阅人数',
                  resolved ? overview.subscriberCount.toString() : '--',
                  AppTheme.primary,
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 12)),
              Expanded(
                child: _stat(
                  '预计月收入',
                  resolved
                      ? '${formatFen(overview.monthlyIncomeFen, group: false, trimZeros: true)} 元'
                      : '--',
                  AppTheme.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 10)),
          Text(
            '按已登记订阅的最终块状态估算，不代表结算收入',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 11),
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(12),
        vertical: AppLayout.scaledValue(10),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(12),
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(2)),
          Text(
            value,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(24),
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// 展示创作者单个档位、各周期开关和价格及编辑入口。

/// 单个会员档卡：档名 + 月/季/年价格 pill（未开启周期灰显「未设」）+ 编辑入口。
class CreatorTierCard extends StatelessWidget {
  const CreatorTierCard({super.key, required this.tier, required this.onEdit});

  final CreatorTier tier;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 14),
        vertical: AppLayout.scaled(context, 13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.tierName.isEmpty ? '未命名档位' : tier.tierName,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.scaledValue(4)),
                  child: Icon(
                    Icons.edit_outlined,
                    size: AppLayout.scaled(context, 18),
                    color: onEdit == null
                        ? AppTheme.textTertiary
                        : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 10)),
          Wrap(
            spacing: AppLayout.scaled(context, 8),
            runSpacing: AppLayout.scaled(context, 8),
            children: BillingPeriod.values.map(_pricePill).toList(),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(BillingPeriod period) {
    final fen = tier.priceFenOf(period);
    final has = fen != null;
    final short = switch (period) {
      BillingPeriod.monthly => '月',
      BillingPeriod.quarterly => '季',
      BillingPeriod.yearly => '年',
    };
    final label = has
        ? '$short ${formatFen(BigInt.from(fen), group: false, trimZeros: true)} 元'
        : '$short 未设';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(10),
        vertical: AppLayout.scaledValue(4),
      ),
      decoration: BoxDecoration(
        color: has ? AppTheme.primary.withAlpha(20) : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.scaledValue(12),
          color: has ? AppTheme.primaryDark : AppTheme.textTertiary,
        ),
      ),
    );
  }
}

// 编辑档位名称和月季年价格，确认后一次覆盖提交方案。

/// 编辑/新增会员档底部弹窗。
///
/// 档名（元展示）+ 月/季/年三周期（开关 + 元价输入，可只开部分）。保存=覆盖式写全部档位，
/// 经 [CreatorService.saveTiers] 一次签名原子写入链上名称和价格。
class CreatorPlanEditSheet extends StatefulWidget {
  const CreatorPlanEditSheet({
    super.key,
    required this.service,
    required this.currentTiers,
    this.editing,
  });

  final CreatorService service;

  /// 当前全部档位（覆盖式保存需要）。
  final List<CreatorTier> currentTiers;

  /// 正在编辑的档位；null = 新增。
  final CreatorTier? editing;

  @override
  State<CreatorPlanEditSheet> createState() => _CreatorPlanEditSheetState();
}

class _CreatorPlanEditSheetState extends State<CreatorPlanEditSheet> {
  late final TextEditingController _tierNameController;
  final Map<BillingPeriod, TextEditingController> _priceControllers = {};
  final Map<BillingPeriod, bool> _enabled = {};
  bool _saving = false;

  bool get _isNew => widget.editing == null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _tierNameController = TextEditingController(text: editing?.tierName ?? '');
    for (final period in BillingPeriod.values) {
      final fen = editing?.priceFenOf(period);
      _enabled[period] = fen != null;
      _priceControllers[period] = TextEditingController(
        text: fen != null ? formatFen(BigInt.from(fen), group: false, trimZeros: true) : '',
      );
    }
  }

  @override
  void dispose() {
    _tierNameController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppLayout.scaled(context, 38),
                  height: AppLayout.scaled(context, 4),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(4),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 14)),
              Text(
                _isNew ? '新增会员档' : '编辑会员档',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 16),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 14)),
              Text(
                '会员档名',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 6)),
              TextField(
                controller: _tierNameController,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: '如「铁杆粉丝」',
                  counterText: '',
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 14)),
              Row(
                children: [
                  Text(
                    '订阅周期与价格',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '（可只开部分周期，单位：元）',
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppLayout.scaled(context, 8)),
              for (final period in BillingPeriod.values) _periodRow(period),
              SizedBox(height: AppLayout.scaled(context, 18)),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: AppLayout.scaled(context, 20),
                        height: AppLayout.scaled(context, 20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存'),
              ),
              if (!_isNew) ...[
                SizedBox(height: AppLayout.scaled(context, 6)),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _confirmDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    child: const Text('删除此档'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodRow(BillingPeriod period) {
    final enabled = _enabled[period] ?? false;
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.scaledValue(10)),
      child: Row(
        children: [
          Switch(
            value: enabled,
            onChanged: _saving
                ? null
                : (value) => setState(() => _enabled[period] = value),
          ),
          SizedBox(width: AppLayout.scaledValue(4)),
          SizedBox(
            width: AppLayout.scaledValue(34),
            child: Text(
              period.label,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(14),
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(width: AppLayout.scaledValue(8)),
          Expanded(
            child: TextField(
              controller: _priceControllers[period],
              enabled: enabled && !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                suffixText: '元',
                hintText: '0.00',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final tierName = _tierNameController.text;
    if (tierName.isEmpty) {
      _toast('请填写会员档名');
      return;
    }
    if (tierName.trim() != tierName) {
      _toast('会员档名首尾不能含空白');
      return;
    }
    if (tierName.runes.length > 20 || utf8.encode(tierName).length > 80) {
      _toast('会员档名最多 20 个字符且最多 80 个 UTF-8 字节');
      return;
    }
    if (tierName.runes.any(
      (value) => value <= 0x1f || (value >= 0x7f && value <= 0x9f),
    )) {
      _toast('会员档名不能含控制字符');
      return;
    }
    final prices = <BillingPeriod, int>{};
    for (final period in BillingPeriod.values) {
      if (_enabled[period] != true) continue;
      final fen = parseFen(_priceControllers[period]!.text.trim().replaceFirst(RegExp(r'^[¥￥]'), ''));
      if (fen == null || fen <= BigInt.zero || !fen.isValidInt) {
        _toast('${period.label}价格无效');
        return;
      }
      prices[period] = fen.toInt();
    }
    if (prices.isEmpty) {
      _toast('至少开启一个周期并填写价格');
      return;
    }

    final tier = CreatorTier(
      tierId: widget.editing?.tierId ?? _newTierId(),
      tierName: tierName,
      monthFen: prices[BillingPeriod.monthly],
      quarterFen: prices[BillingPeriod.quarterly],
      yearFen: prices[BillingPeriod.yearly],
    );
    final editing = widget.editing;
    if (editing != null &&
        editing.tierName != tierName &&
        BillingPeriod.values.every(
          (period) => editing.priceFenOf(period) == prices[period],
        )) {
      await _commitTierName(tier);
      return;
    }
    await _commit(_mergeTiers(tier));
  }

  /// 只有名称变化时走独立链上改名，不重写价格或改变订阅授权。
  Future<void> _commitTierName(CreatorTier tier) async {
    setState(() => _saving = true);
    try {
      final plan = await widget.service.updateTierName(
        context: context,
        currentTiers: widget.currentTiers,
        tierId: tier.tierId,
        tierName: tier.tierName,
      );
      if (!mounted) return;
      Navigator.of(context).pop(plan);
    } on CreatorException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除此档'),
        content: const Text('删除后已订阅该档的用户不再续费，确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final remaining = widget.currentTiers
        .where((t) => t.tierId != widget.editing!.tierId)
        .toList();
    await _commit(remaining);
  }

  /// 覆盖式保存全部档位（一次账户签名）。成功回传最新计划并关闭。
  Future<void> _commit(List<CreatorTier> tiers) async {
    setState(() => _saving = true);
    try {
      final plan = await widget.service.saveTiers(tiers, context: context);
      if (!mounted) return;
      Navigator.of(context).pop(plan);
    } on CreatorException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  List<CreatorTier> _mergeTiers(CreatorTier tier) {
    final tiers = List<CreatorTier>.from(widget.currentTiers);
    final index = tiers.indexWhere((t) => t.tierId == tier.tierId);
    if (index >= 0) {
      tiers[index] = tier;
    } else {
      tiers.add(tier);
    }
    return tiers;
  }

  String _newTierId() => 't_${DateTime.now().microsecondsSinceEpoch}';

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
