// 展示当前创作者会员、档位及统计，并复用按身份隔离的链缓存。

import 'package:citizen_system/identity_cid_display.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:citizen_user/creator/creator_plan_edit_sheet.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/creator/creator_overview.dart';
import 'package:citizen_user/creator/creator_plan.dart';
import 'package:citizen_user/creator/creator_overview_card.dart';
import 'package:citizen_user/creator/creator_tier_card.dart';
import 'package:citizen_user/membership/membership_page.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/identity/cid_business_gate.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/identity_badge.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_user/identity/identity_register_guide.dart';
import 'package:citizen_system/theme/app_layout.dart';

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
          ? () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('订阅者明细即将上线')))
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
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const MembershipPage()));
    if (mounted) _onChainData();
  }
}
