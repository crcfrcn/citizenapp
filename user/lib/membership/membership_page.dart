import 'package:citizen_user/identity/register_identity_flow.dart';
import 'package:citizen_chain/citizen_chain.dart';

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/membership/membership_detail_page.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/identity_badge.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_system/theme/app_layout.dart';

const List<String> _tierOrder = ['freedom', 'democracy', 'spark'];

/// 会员链上状态与价格来自统一轻节点；云端额度及用量独立读取。
class MembershipPage extends StatefulWidget {
  const MembershipPage({
    super.key,
    ChainDataService? chainData,
    SquareSessionProvider? sessionProvider,
    SubscriptionService? subscriptionService,
  }) : _chainData = chainData,
       _sessionProvider = sessionProvider,
       _subscriptionService = subscriptionService;
  final ChainDataService? _chainData;
  final SquareSessionProvider? _sessionProvider;
  final SubscriptionService? _subscriptionService;
  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage>
    with SingleTickerProviderStateMixin {
  ChainDataService? _chainData;
  late final SquareSessionProvider _sessionProvider;
  late final SubscriptionService _subscriptionService;
  AccountSecurityService? _accountSecurity;
  bool _dependenciesReady = false,
      _refreshing = false,
      _identityReloadPending = false,
      _unregistered = false,
      _busy = false;
  String? _loadFailure;
  SquareSessionStatus? _sessionStatus;
  late final AnimationController _snapController;
  Animation<double>? _snapAnim;
  double _page = 0;
  int _cardCount = 0;
  _MembershipViewData _data = const _MembershipViewData(
    accountId: '',
    cidNumber: '',
    state: _emptyMembershipState,
    prices: {},
    subscriptionReady: false,
  );
  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          final anim = _snapAnim;
          if (anim != null && mounted) {
            setState(() => _page = anim.value);
          }
        });
  }

  VoidCallback? _releasePrices;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) {
      return;
    }
    _chainData = widget._chainData ?? context.read<ChainDataService?>();
    _releasePrices = _chainData?.watchPrices();
    _chainData?.addListener(_onChainData);
    _sessionProvider =
        widget._sessionProvider ?? context.read<SquareSessionProvider>();
    if (widget._subscriptionService case final service?) {
      _subscriptionService = service;
    } else {
      final sdk = context.read<CitizenSdk>();
      _subscriptionService = SubscriptionService(
        chainData: _chainData,
        wallet: sdk,
        chain: sdk,
        transactions: sdk,
        identityResolver: context.read<FinalizedIdentityResolver>(),
      );
    }
    _accountSecurity = context.read<AccountSecurityService?>();
    _accountSecurity?.revision.addListener(_onIdentityChanged);
    _dependenciesReady = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _releasePrices?.call();
    _chainData?.removeListener(_onChainData);
    _accountSecurity?.revision.removeListener(_onIdentityChanged);
    _snapController.dispose();
    super.dispose();
  }

  /// 同账户从未注册推进到 finalized CID 时钱包列表不变；身份 revision 仍需让已挂载
  /// 会员页立即重建会话与订阅快照。若正在刷新，记一次尾随重载避免丢广播。
  void _onIdentityChanged() {
    if (!mounted) {
      return;
    }
    if (_refreshing) {
      _identityReloadPending = true;
      return;
    }
    unawaited(_load());
  }

  /// 普通加载与主动重试共用自动准备；明确取消的钱包授权仅由主动重试继续。
  Future<void> _retryLoad() => _load(forceRefresh: true);

  void _onChainData() {
    final data = _chainData?.snapshot;
    if (!mounted) {
      return;
    }
    if (data == null) {
      _applyViewData(
        const _MembershipViewData(
          accountId: '',
          cidNumber: '',
          state: _emptyMembershipState,
          prices: {},
          subscriptionReady: false,
        ),
      );
      return;
    }
    // 新账户或未知状态立即撤下旧显示，不能把未知写成无会员。
    if (_data.accountId.isNotEmpty && data.accountId != _data.accountId) {
      _applyViewData(
        _MembershipViewData(
          accountId: data.accountId,
          cidNumber: '',
          state: _emptyMembershipState,
          prices: data.prices,
          subscriptionReady: false,
        ),
      );
    }
    _applyLightData(data);
  }

  void _applyLightData(ChainDataSnapshot data) {
    if (!mounted) {
      return;
    }
    final state = data.own?.platform;
    _unregistered = data.ownCid == null && _chainData?.isStale == false;
    _applyViewData(
      _MembershipViewData(
        accountId: data.accountId,
        cidNumber: data.ownCid ?? '',
        state: SquareMembershipState(
          active: data.ownCid != null && data.memberActive(data.ownCid!),
          memberLevel: state?.plan.memberLevel,
          subState: state?.subState,
          chargeAt: state?.chargeAt ?? 0,
          paidUntil: state?.paidUntil ?? 0,
          plans: _data.state.plans,
          usageState: _data.state.usageState,
          cleanupAfter: _data.state.cleanupAfter,
        ),
        prices: data.prices,
        subscriptionReady: _chainData?.isStale == false && data.ownCid != null,
      ),
    );
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      final source = _chainData;
      if (source == null) {
        throw StateError('轻节点会员数据尚未就绪');
      }
      final data = await source.ensurePrices();
      if (!mounted) {
        return;
      }
      if (data == null) {
        _loadFailure = '请先添加钱包账户';
        return;
      }
      _applyLightData(data);
      _loadFailure = null;
      // 云端规则与用量独立读取；故障不覆盖轻节点订阅和价格。
      try {
        final resolution = await _sessionProvider.resolveSession();
        if (!mounted ||
            (source.snapshot?.accountId != data.accountId ||
                source.snapshot?.ownCid != data.ownCid ||
                source.snapshot?.own?.identity?.bindRev !=
                    data.own?.identity?.bindRev)) {
          return;
        }
        _sessionStatus = resolution.status;
        final session = resolution.session;
        if (session != null && session.cidNumber == data.ownCid) {
          final resources = await _subscriptionService.authorizeResources(
            session,
            forceRefresh: forceRefresh,
          );
          if (!mounted ||
              (source.snapshot?.accountId != data.accountId ||
                  source.snapshot?.ownCid != data.ownCid ||
                  source.snapshot?.own?.identity?.bindRev !=
                      data.own?.identity?.bindRev)) {
            return;
          }
          final current = _data.state;
          _applyViewData(
            _MembershipViewData(
              accountId: _data.accountId,
              cidNumber: _data.cidNumber,
              state: SquareMembershipState(
                active: current.active,
                paidUntil: current.paidUntil,
                memberLevel: current.memberLevel,
                subState: current.subState,
                chargeAt: current.chargeAt,
                plans: resources.plans,
                usageState: resources.usageState,
                cleanupAfter: resources.cleanupAfter,
              ),
              prices: _data.prices,
              subscriptionReady: !source.isStale,
            ),
          );
        }
      } on Object {
        if (mounted) {
          _loadFailure = '云端用量暂不可用';
        }
      }
    } on Object {
      if (mounted) {
        _loadFailure = '轻节点会员读取失败，请刷新重试';
        _applyViewData(
          _MembershipViewData(
            accountId: _data.accountId,
            cidNumber: _data.cidNumber,
            state: _data.state,
            prices: _data.prices,
            subscriptionReady: false,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
      if (mounted && _identityReloadPending) {
        _identityReloadPending = false;
        unawaited(_load());
      }
    }
  }

  void _applyViewData(_MembershipViewData data) {
    if (!mounted) {
      return;
    }
    final accountChanged = _data.accountId != data.accountId;
    final membershipChanged = _data.state.memberLevel != data.state.memberLevel;
    final defaultIndex = _tierIndexOfLevel(data.state.memberLevel);
    setState(() {
      _data = data;
      if (accountChanged || membershipChanged || _cardCount == 0) {
        _page = defaultIndex.toDouble();
      }
    });
  }

  /// App 内订阅 / 取消：据当前订阅态决定动作 → 上链热签（生物识别）→ confirm → 刷新。
  /// 失败弹 SnackBar（文案单源自 [SubscriptionException]）。
  Future<void> _handleAction(String level) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _chainData?.ensurePrices();
      if (data == null || _chainData!.isStale || data.ownCid == null) {
        throw const SubscriptionException('当前轻节点身份尚未就绪');
      }
      if (!mounted) {
        return;
      }
      _applyLightData(data);
      final action = _actionFor(_data.state, level), price = data.prices[level];
      if (action != _SubscribeAction.cancel && price == null) {
        throw const SubscriptionException('链上价格尚未就绪');
      }
      if (action == _SubscribeAction.cancel) {
        await _subscriptionService.cancel(context: context);
      } else if (action == _SubscribeAction.change) {
        await _subscriptionService.changePlan(level, price!, context: context);
      } else {
        await _subscriptionService.subscribe(level, price!, context: context);
      }
      await _chainData!.ensurePrices();
      if (mounted) {
        _onChainData();
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// 打开该档「会员详情页」（完整权益只读展示 + 订阅入口，订阅动作仍走本页 [_handleAction]）。
  void _openDetail(
    String level,
    SquareMembershipPlan? plan,
    int? priceFen,
    SquareMembershipState state,
  ) {
    final action = _actionFor(state, level);
    final noWallet = _sessionStatus == SquareSessionStatus.noWallet;
    // 缓存只提供展示，详情按钮与会员卡一样必须有当前可用会话。
    final sessionUnavailable = _data.accountId.isEmpty;
    final stateNotReady = !_data.subscriptionReady;
    final label = noWallet
        ? '请先添加钱包账户'
        : sessionUnavailable
        ? _sessionStatus?.message ?? '会员状态同步中'
        : stateNotReady
        ? '会员状态同步中'
        : action != _SubscribeAction.cancel && priceFen == null
        ? '链上价格未就绪'
        : _actionLabel(action);
    final enabled =
        !noWallet &&
        !sessionUnavailable &&
        !stateNotReady &&
        (action == _SubscribeAction.cancel || priceFen != null);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MembershipDetailPage(
          memberLevel: level,
          plan: plan,
          usageState: state.memberLevel == level ? state.usageState : null,
          priceFen: priceFen,
          actionLabel: label,
          subscribeEnabled: enabled,
          onSubscribe: () => _handleAction(level),
        ),
      ),
    );
  }

  void _animateToPage(int target) {
    final clamped = target.clamp(0, (_cardCount - 1).clamp(0, 99)).toDouble();
    _snapAnim = Tween<double>(begin: _page, end: clamped).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails details, double dragUnit) {
    setState(() {
      _page = (_page - details.primaryDelta! / dragUnit).clamp(
        0.0,
        (_cardCount - 1).toDouble(),
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final int target;
    if (velocity.abs() > 320) {
      target = velocity < 0 ? _page.ceil() : _page.floor();
    } else {
      target = _page.round();
    }
    _animateToPage(target);
  }

  @override
  Widget build(BuildContext context) {
    // 三张套餐卡始终显示；未注册引导与真实数据的加载状态不替换卡片。
    // 会员、价格与钱包状态由 [_load] 后台补齐；真正订阅、
    // 换档或取消时由 [SubscriptionService] 核验钱包、CID 与轻节点会员状态，
    // 随后的链上交易继续执行最终状态校验。
    return Scaffold(
      appBar: AppBar(
        title: const Text('会员｜订阅'),
        centerTitle: true,
        actions: [
          if (!_unregistered)
            IconButton(
              tooltip: '刷新',
              onPressed: _refreshing ? null : _retryLoad,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data;
    final state = data.state;
    // 卡片身份来自固定三档；服务端缺档只让该档权益未知，不能删除卡片。
    _cardCount = _tierOrder.length;
    final size = MediaQuery.of(context).size;
    final cardWidth = (size.width * 0.8).clamp(280.0, 360.0);
    final bandHeight = (size.height * 0.60).clamp(430.0, 540.0);
    final peek = cardWidth * 0.40;
    final frontIndex = _page.round().clamp(0, _tierOrder.length - 1);
    final activeColor = _tierColor(_tierOrder[frontIndex]);

    // 绘制顺序：离最上层越远越先画（在下层），当前卡最后画（压在最上层）。
    final drawOrder = List<int>.generate(_tierOrder.length, (i) => i)
      ..sort((a, b) => (b - _page).abs().compareTo((a - _page).abs()));

    return Column(
      children: [
        if (_unregistered)
          ListTile(
            title: const Text('尚未注册'),
            subtitle: const Text('注册后即可使用会员服务。'),
            trailing: TextButton(
              onPressed: () async {
                if (await startCidRegistrationFlow(context) && mounted) {
                  await _load(forceRefresh: true);
                }
              },
              child: const Text('注册'),
            ),
          ),
        if (_loadFailure != null && !_refreshing)
          _LoadFailureBanner(
            key: const ValueKey('membership-load-failure-banner'),
            message: _loadFailure!,
            onRetry: _retryLoad,
          ),
        if (state.cleanupAfter case final deadline?)
          ListTile(
            title: const Text('会员存储超额'),
            subtitle: Text(
              '请在 ${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(deadline))} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(deadline)))} 前降低存储用量或恢复会员，届时服务端将回收超额内容。',
            ),
          ),
        if (state.hasSubscriptionWindow) _ActiveMembershipBanner(state: state),
        Expanded(
          child: GestureDetector(
            key: const ValueKey('membership-tier-stack-gesture'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _snapController.stop(),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, cardWidth),
            onHorizontalDragEnd: _onDragEnd,
            child: Center(
              child: SizedBox(
                height: bandHeight,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final index in drawOrder)
                      _buildStackedCard(
                        index: index,
                        level: _tierOrder[index],
                        plan: state.planForLevel(_tierOrder[index]),
                        state: state,
                        priceFen: data.prices[_tierOrder[index]],
                        canSubscribe:
                            data.accountId.isNotEmpty && data.subscriptionReady,
                        unavailableLabel: _unregistered
                            ? '注册后可订阅'
                            : data.accountId.isEmpty && !_refreshing
                            ? _sessionStatus?.message ?? '会员状态同步中'
                            : '会员状态同步中',
                        cardWidth: cardWidth,
                        cardHeight: bandHeight,
                        peek: peek,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _PageDots(
          count: _tierOrder.length,
          activeIndex: frontIndex,
          activeColor: activeColor,
        ),
        SizedBox(height: AppLayout.scaledValue(10)),
        Text(
          '左右滑动切换会员档',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: AppLayout.scaledValue(12),
          ),
        ),
        SizedBox(height: AppLayout.scaledValue(20)),
      ],
    );
  }

  Widget _buildStackedCard({
    required int index,
    required String level,
    required SquareMembershipPlan? plan,
    required SquareMembershipState state,
    required int? priceFen,
    required bool canSubscribe,
    required String unavailableLabel,
    required double cardWidth,
    required double cardHeight,
    required double peek,
  }) {
    final off = index - _page;
    final absOff = off.abs();
    final scale = (1.0 - 0.16 * absOff).clamp(0.68, 1.0);
    final opacity = (1.0 - 0.55 * absOff).clamp(0.0, 1.0);
    final isFront = absOff < 0.5;

    final visual = Transform.translate(
      offset: Offset(off * peek, 0),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: _MembershipTierCard(
              memberLevel: level,
              plan: plan,
              state: state,
              priceFen: priceFen,
              canSubscribe: canSubscribe,
              unavailableLabel: unavailableLabel,
              busy: _busy,
              onTapAction: () => _handleAction(level),
              onViewDetail: () => _openDetail(level, plan, priceFen, state),
              elevated: isFront,
            ),
          ),
        ),
      ),
    );

    if (isFront) {
      // 当前卡在最上层，内部按钮可点。
      return KeyedSubtree(
        key: const ValueKey('membership-front-card'),
        child: visual,
      );
    }
    // 下层候选卡：点击整卡切到最上层（拦掉内部按钮点击）。
    return IgnorePointer(
      ignoring: opacity < 0.05,
      child: GestureDetector(
        onTap: () => _animateToPage(index),
        child: IgnorePointer(child: visual),
      ),
    );
  }
}

class _MembershipViewData {
  const _MembershipViewData({
    required this.accountId,
    required this.cidNumber,
    required this.state,
    required this.prices,
    required this.subscriptionReady,
  });

  final String accountId;
  final String cidNumber;
  final SquareMembershipState state;

  /// 各档链上月价（分，公民币）；缺档表示链上未设该档价，卡片显示占位「—」。
  final Map<String, int> prices;

  /// 至少成功读取过一次 finalized 订阅态；未就绪时只展示卡片，禁止动权入口。
  final bool subscriptionReady;

  /// 只替换价格,保留其余字段。价格由已注册但会话暂不可用时的独立链读刷新，不能覆盖
  /// 会话侧已取得的订阅态。
  _MembershipViewData copyWithPrices(Map<String, int> prices) =>
      _MembershipViewData(
        accountId: accountId,
        cidNumber: cidNumber,
        state: state,
        prices: prices,
        subscriptionReady: subscriptionReady,
      );
}

/// 单张会员档卡（ADR-037）：一张卡 = 一个订阅档（自由/民主/薪火）。档色顶带 + 大字档名
/// + 会员权益（完整聊天矩阵 / 公文 / 文章 / 视频）+ 公民币月价 + 订阅按钮。无任何身份字段。
class _MembershipTierCard extends StatelessWidget {
  const _MembershipTierCard({
    required this.memberLevel,
    required this.plan,
    required this.state,
    required this.priceFen,
    required this.canSubscribe,
    required this.unavailableLabel,
    required this.busy,
    required this.onTapAction,
    required this.onViewDetail,
    this.elevated = true,
  });

  final String memberLevel;
  final SquareMembershipPlan? plan;
  final SquareMembershipState state;

  /// 本档链上月价（分）；null=链上未设该档价，价签显示占位「—」。
  final int? priceFen;

  /// 是否已有可执行订阅动作的默认钱包账户会话。
  final bool canSubscribe;

  final String unavailableLabel;

  /// 订阅 / 取消上链进行中：禁用按钮并显示进度圈。
  final bool busy;

  final VoidCallback onTapAction;

  /// 点击「查看详细权益」进入该档会员详情页。
  final VoidCallback onViewDetail;

  /// 是否在最上层（决定投影强度）。
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final level = memberLevel;
    final plan = this.plan;
    final benefits = membershipBenefits(level, plan);
    final tierColor = _tierColor(level);
    final onTier = _onTierColor(level);
    // 当前所购且有效的档：高亮边框 + 顶带「当前会员」标记。
    final isCurrentTier = state.active && state.memberLevel == level;
    final action = _actionFor(state, level);
    final actionLabel = !canSubscribe
        ? unavailableLabel
        : action != _SubscribeAction.cancel && priceFen == null
        ? '链上价格未就绪'
        : _actionLabel(action);

    return Container(
      key: ValueKey('membership-tier-card-$level'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isCurrentTier ? tierColor : AppTheme.border,
          width: isCurrentTier ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.22 : 0.08),
            blurRadius: AppLayout.scaledValue(elevated ? 24 : 8),
            offset: Offset(0, AppLayout.scaledValue(elevated ? 12 : 4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(level, tierColor, onTier, isCurrentTier, priceFen),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            icon: Icons.workspace_premium_outlined,
                            text: '会员权益',
                            color: tierColor,
                          ),
                          SizedBox(height: AppLayout.scaled(context, 10)),
                          // 原七行顺序、图标和排版保持；只更新文案，完整权益见详情。
                          _ParamLine(
                            icon: Icons.chat_bubble_outline,
                            color: tierColor,
                            text: '聊天 文字/表情/贴纸/图片',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.mic_none_outlined,
                            color: tierColor,
                            text: '语音/视频消息 ${benefits.voice} · 语音/视频通话',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.attach_file_outlined,
                            color: tierColor,
                            text: '聊天附件 每个 ${benefits.file}',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.videocam_outlined,
                            color: tierColor,
                            text:
                                '视频 ${benefits.videoDuration} · ${benefits.videoQuality} · ${benefits.videoSize}',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.photo_outlined,
                            color: tierColor,
                            text:
                                '公文 ${benefits.documentText} · ${benefits.documentImages}图',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.article_outlined,
                            color: tierColor,
                            text:
                                '文章 ${benefits.articleBody} · ${benefits.articleImages}图 · ${benefits.articleVideos}视频',
                          ),
                          SizedBox(height: AppLayout.scaled(context, 8)),
                          _ParamLine(
                            icon: Icons.storage_outlined,
                            color: tierColor,
                            text: '广场存储 ${benefits.storage}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 8)),
                  // 查看详细权益：整行可点，进入该档会员详情页。
                  InkWell(
                    onTap: onViewDetail,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppLayout.scaled(context, 8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '查看详细权益',
                            style: TextStyle(
                              color: tierColor,
                              fontSize: AppLayout.scaled(context, 13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: AppLayout.scaled(context, 18),
                            color: tierColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppLayout.scaled(context, 12)),
                  SizedBox(
                    width: double.infinity,
                    child: _SubscribeButton(
                      label: actionLabel,
                      color: tierColor,
                      busy: busy,
                      action: action,
                      enabled:
                          canSubscribe &&
                          (action == _SubscribeAction.cancel ||
                              priceFen != null),
                      onTap: onTapAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String level,
    Color tierColor,
    Color onTier,
    bool isCurrentTier,
    int? priceFen,
  ) {
    // 自由金底使用规范允许的主文字色；民主蓝/薪火红深色底使用纯白标志。
    final gmbMarkColor = level == 'freedom'
        ? AppTheme.textPrimary
        : Colors.white;
    final badgeStyle = identityBadgeStyle(
      cidLevel: null,
      memberLevel: level,
      membergateActive: true,
    )!;
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '会员订阅',
          style: TextStyle(
            color: onTier.withValues(alpha: 0.82),
            fontSize: AppLayout.scaledValue(12),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: AppLayout.scaledValue(4)),
        Row(
          key: ValueKey('membership-tier-title-$level'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // 会员名称复用全 App 唯一八花瓣徽章；浅色底衬只解决同色头部上的对比度。
            Container(
              width: AppLayout.scaledValue(26),
              height: AppLayout.scaledValue(26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: IdentityBadge(
                key: ValueKey('membership-tier-badge-$level'),
                style: badgeStyle,
                size: AppLayout.scaledValue(22),
                tooltip: plan?.displayName ?? membershipTitle(level),
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(8)),
            Text(
              plan?.displayName ?? membershipTitle(level),
              style: TextStyle(
                color: onTier,
                fontSize: AppLayout.scaledValue(22),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (isCurrentTier) ...[
          SizedBox(height: AppLayout.scaledValue(10)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaledValue(10),
              vertical: AppLayout.scaledValue(4),
            ),
            decoration: BoxDecoration(
              color: onTier.withAlpha(38),
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(999)),
            ),
            child: Text(
              '当前会员',
              style: TextStyle(
                color: onTier,
                fontSize: AppLayout.scaledValue(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
    final priceColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标志只辅助识别，价格文本继续承担金额和无障碍语义。
            ExcludeSemantics(
              child: Image.asset(
                'packages/citizen_assets/logo/mark256.png',
                key: ValueKey('membership-price-gmb-mark-$level'),
                width: 18,
                height: 18,
                color: gmbMarkColor,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(6)),
            Text(
              priceFen == null ? '—' : '${formatFen(BigInt.from(priceFen))} 元',
              style: TextStyle(
                color: onTier,
                fontSize: AppLayout.scaledValue(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (priceFen != null)
          Text(
            '/月',
            style: TextStyle(
              color: onTier.withValues(alpha: 0.82),
              fontSize: AppLayout.scaledValue(11),
            ),
          ),
      ],
    );
    return Container(
      key: ValueKey('membership-colored-header-$level'),
      color: tierColor,
      // 宣传语下方只保留紧凑边距，避免彩色头部在白色内容区上方虚高。
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // 窄屏时价格独占下一行，避免通过缩小徽章或标题牺牲可读性。
              if (constraints.maxWidth < 270) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleColumn,
                    SizedBox(height: AppLayout.scaledValue(8)),
                    Align(alignment: Alignment.centerRight, child: priceColumn),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleColumn),
                  SizedBox(width: AppLayout.scaledValue(12)),
                  // 常规宽度价格保持右上角；宣传语在下方独占全宽。
                  priceColumn,
                ],
              );
            },
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
          _buildCenteredMotto(level, onTier),
        ],
      ),
    );
  }

  /// 宣传语中的 ASCII 句点不能继续跟随字体基线落在文字底部。
  ///
  /// 原文仍以 `.` 保存并用于无障碍语义；视觉层把每个分隔点拆成稍大的独立圆点，
  /// 在固定行盒中精确上下、左右居中。长宣传语只整体缩小，不换行、不改变头部高度。
  Widget _buildCenteredMotto(String level, Color onTier) {
    final motto = _membershipMotto(level);
    final segments = motto.split('.');
    final textStyle = TextStyle(
      color: onTier.withValues(alpha: 0.86),
      fontSize: AppLayout.scaledValue(11),
      fontWeight: FontWeight.w500,
      height: 1,
    );
    return Semantics(
      label: motto,
      child: ExcludeSemantics(
        child: SizedBox(
          key: ValueKey('membership-motto-$level'),
          width: double.infinity,
          height: AppLayout.scaledValue(14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              key: ValueKey('membership-motto-content-$level'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var index = 0; index < segments.length; index++) ...[
                  Text(segments[index], maxLines: 1, style: textStyle),
                  if (index < segments.length - 1)
                    SizedBox(
                      key: ValueKey('membership-motto-dot-$level-$index'),
                      width: AppLayout.scaledValue(8),
                      height: AppLayout.scaledValue(14),
                      child: Center(
                        child: Container(
                          key: ValueKey(
                            'membership-motto-dot-shape-$level-$index',
                          ),
                          // 最长宣传语会被整体轻微缩小；4.5px 可确保最终可见点仍不小于 4px。
                          width: AppLayout.scaledValue(4.5),
                          height: AppLayout.scaledValue(4.5),
                          decoration: BoxDecoration(
                            color: onTier.withValues(alpha: 0.86),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 同一业务操作只签一次：新订阅、取消当前订阅、换到另一档分别提交一笔链上交易。
enum _SubscribeAction { subscribe, change, cancel }

_SubscribeAction _actionFor(SquareMembershipState state, String level) {
  if (state.subState == 'active') {
    return state.memberLevel == level
        ? _SubscribeAction.cancel
        : _SubscribeAction.change;
  }
  if (state.subState == 'cancelled' && state.memberLevel != level) {
    return _SubscribeAction.change;
  }
  return _SubscribeAction.subscribe;
}

String _actionLabel(_SubscribeAction action) => switch (action) {
  _SubscribeAction.subscribe => '订阅',
  _SubscribeAction.change => '更换为此档',
  _SubscribeAction.cancel => '取消订阅',
};

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.label,
    required this.color,
    required this.busy,
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool busy;

  final _SubscribeAction action;

  /// 链上价格未就绪时禁止发起订阅；取消既有订阅不依赖当前价格。
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy || !enabled ? null : onTap,
      icon: busy
          ? SizedBox(
              width: AppLayout.scaled(context, 16),
              height: AppLayout.scaled(context, 16),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(switch (action) {
              _SubscribeAction.subscribe => Icons.workspace_premium_outlined,
              _SubscribeAction.change => Icons.swap_horiz,
              _SubscribeAction.cancel => Icons.cancel_outlined,
            }, size: AppLayout.scaled(context, 16)),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(AppLayout.scaled(context, 46)),
        textStyle: TextStyle(
          fontSize: AppLayout.scaled(context, 14),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 卡内分区小标题（会员权益）。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppLayout.scaled(context, 15), color: color),
        SizedBox(width: AppLayout.scaled(context, 6)),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: AppLayout.scaled(context, 12),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ParamLine extends StatelessWidget {
  const _ParamLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: AppLayout.scaled(context, 16), color: color),
        ),
        SizedBox(width: AppLayout.scaled(context, 8)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppLayout.scaled(context, 13),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 3),
          ),
          width: AppLayout.scaledValue(active ? 18 : 6),
          height: AppLayout.scaled(context, 6),
          decoration: BoxDecoration(
            color: active ? activeColor : AppTheme.border,
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(999)),
          ),
        );
      }),
    );
  }
}

/// 订阅起止横幅（ADR-037）：展示当前有效会员的档位、续费态与订阅起止日期。
/// 会员操作（订阅 / 取消）已在 App 内卡片按钮完成，横幅只读展示。
/// 首载失败横幅:与 [_ActiveMembershipBanner] 同款卡式,不遮挡三张静态卡。
class _LoadFailureBanner extends StatelessWidget {
  const _LoadFailureBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: AppTheme.bannerDecoration(AppTheme.warning),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: AppLayout.scaled(context, 18),
            color: AppTheme.warning,
          ),
          SizedBox(width: AppLayout.scaled(context, 8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 13),
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _ActiveMembershipBanner extends StatelessWidget {
  const _ActiveMembershipBanner({required this.state});

  final SquareMembershipState state;

  @override
  Widget build(BuildContext context) {
    final plan = state.planForLevel(state.memberLevel);
    final name = plan?.displayName ?? '会员';
    // 用户订阅授权未取消时，runtime 按链上真实公历到期时间自动扣款。
    final route = switch (state.subState) {
      'cancelled' => '已取消 · 到期终止',
      'terminated' => '扣款失败 · 订阅已终止',
      'suspended' => '已挂起 · 待重新签名或充值',
      'issuerPaused' => '创作者暂停 · 恢复后自动续',
      _ => '链上到期自动续费',
    };
    final window =
        '订阅 ${_formatYmd(state.chargeAt)} ~ ${_formatYmd(state.paidUntil)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
      decoration: AppTheme.bannerDecoration(AppTheme.info),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_available,
            size: AppLayout.scaled(context, 18),
            color: AppTheme.info,
          ),
          SizedBox(width: AppLayout.scaled(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · $route',
                  style: TextStyle(
                    color: AppTheme.info,
                    fontSize: AppLayout.scaled(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 2)),
                Text(
                  window,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 毫秒时间戳格式化为本地 YYYY-MM-DD。
String _formatYmd(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

// 缺少真实快照只表示未知；三档UI不生成套餐额度或本地授权。
const SquareMembershipState _emptyMembershipState = SquareMembershipState(
  active: false,
  paidUntil: 0,
);
Color _tierColor(String level) => switch (level) {
  'spark' => AppTheme.identityCandidate,
  'democracy' => AppTheme.identityVoting,
  _ => AppTheme.identityVisitor,
};

/// 顶带/价格标签前景色：自由金底用深棕保证对比度，民主蓝/薪火红底用白字。
Color _onTierColor(String level) =>
    level == 'freedom' ? const Color(0xFF4A3000) : Colors.white;

/// 会员宣传语是稳定的本地 UI 文案，不进入会员套餐 DTO 或订阅契约。
String _membershipMotto(String level) => switch (level) {
  'freedom' => '生命诚可贵.爱情价更高.若为自由故.两者皆可抛',
  'democracy' => '民主不是万能的.没有民主是万万不能的',
  'spark' => '自由民主.薪火相传',
  _ => '',
};

/// 会员档在固定档序中的下标；未知/无订阅归 0（自由）。
int _tierIndexOfLevel(String? level) {
  final index = _tierOrder.indexOf(level ?? '');
  return index < 0 ? 0 : index;
}
