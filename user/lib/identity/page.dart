// 展示本人身份卡和钱包换绑交互。

import 'package:citizen_system/format.dart';
import 'package:citizen_system/security/access.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/chat.dart';
import 'package:citizen_user/context.dart' show CurrentUserContext;
import 'package:citizen_user/identity/state.dart' show FinalizedIdentityResolver, IdentityBadgeSnapshotStore, MyIdService, MyIdState, MyIdStatus, MyIdSync, MyIdTier;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/identity/registration.dart' show startCidRegistrationFlow;
import 'package:citizen_system/theme.dart';
import 'package:citizen_user/identity/badge.dart' show IdentityBadge, identityBadgeStyle;
import 'package:citizen_user/security.dart' show AccountSecurityService;

// 展示访客、投票和竞选三档身份卡及当前身份操作。

/// 身份页(原电子护照)。
///
/// 页面始终展示访客、投票身份、竞选身份三张卡。只有当前身份对应的卡片排在
/// 首位、标记"当前身份"并展示持久快照;非当前公民卡只展示该身份涉及的字段名称,
/// 不能重复泄露当前用户数据。链读取失败时不静默降级成访客。
///
/// 右上角按钮随状态切换:纯访客→「注册」(自助占一个匿名 CID);匿名已注册→「更换」
/// (把 CID 换绑到另一个本地账户);投票/竞选→「更换」但只提示须去注册局。访客卡在
/// 已占匿名 CID 时按公民/居民显示标题，并补显 CID 和绑定账户，徽章色沿用。
/// 顶部支持下拉刷新。
class MyIdPage extends StatefulWidget {
  const MyIdPage({super.key, this.myIdService, this.openRegistrationTopup});

  final MyIdService? myIdService;

  /// 仅测试注入；正式流程始终打开所选账户的充值弹窗。
  final Future<void> Function(BuildContext, String)? openRegistrationTopup;

  @override
  State<MyIdPage> createState() => _MyIdPageState();
}

class _MyIdPageState extends State<MyIdPage> {
  static const List<MyIdTier> _baseTierOrder = <MyIdTier>[
    MyIdTier.visitor,
    MyIdTier.voting,
    MyIdTier.candidate,
  ];

  MyIdService? _myIdService;
  AccountSecurityService? _accountSecurity;
  MyIdState _state = const MyIdState(tier: MyIdTier.visitor);
  bool _loading = true;
  bool _submitting = false;
  int _loadGeneration = 0;

  bool get _isQueryFailed => _state.status == MyIdStatus.queryFailed;

  /// 右上主操作按钮文案:状态未知(链读失败)不给操作;纯访客「注册」;其余(匿名已
  /// 注册 / 投票 / 竞选)「更换」。civic 的「更换」点击后只提示走注册局。
  String? get _actionLabel {
    if (_isQueryFailed || _state.status == MyIdStatus.unknown) return null;
    if (_state.tier == MyIdTier.visitor && !_state.isAnonymousRegistered) {
      return '注册';
    }
    return '更换';
  }

  @override
  void initState() {
    super.initState();
    IdentityBadgeSnapshotStore.revision.addListener(_onSnapshotChanged);
    if (widget.myIdService != null) {
      _myIdService = widget.myIdService;
      _myIdService!.sync.addListener(_onSyncChanged);
      _openIdentity();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_myIdService != null) return;
    final sdk = context.read<CitizenSdk>();
    final accountSecurity = context.read<AccountSecurityService>();
    _accountSecurity = accountSecurity;
    _myIdService =
        context.read<MyIdService?>() ??
        MyIdService(
          wallet: sdk,
          signing: sdk,
          chain: sdk,
          transactions: sdk,
          accountSecurity: accountSecurity,
          currentUserContext: context.read<CurrentUserContext>(),
          identityResolver: context.read<FinalizedIdentityResolver>(),
          sessionProvider: context.read<SquareSessionProvider>(),
          onChatBindingChanged: (binding, {required existingOnly}) async {
            final ChatRuntime? runtime = existingOnly
                ? null
                : (() => context.read<ChatRuntime>())();
            await runtime?.convergeFinalizedBinding(
              ChatBinding.fromIdentity(binding),
            );
          },
        );
    // 身份账户切换必须让身份页立即重排，和广场、聊天共用同一身份版本号。
    accountSecurity.revision.addListener(_onIdentityChanged);
    _myIdService!.sync.addListener(_onSyncChanged);
    _openIdentity();
  }

  @override
  void dispose() {
    IdentityBadgeSnapshotStore.revision.removeListener(_onSnapshotChanged);
    _accountSecurity?.revision.removeListener(_onIdentityChanged);
    _myIdService?.sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSnapshotChanged() {
    if (_myIdService != null && !_refreshing && !_submitting) {
      _loadState();
    }
  }

  MyIdSync? _pendingSync;

  void _onSyncChanged() {
    if (_submitting) return;
    final result = _myIdService!.sync.value;
    if (result == null) return;
    if (_refreshing) {
      _pendingSync = result;
    } else {
      _applySync(result);
    }
  }

  Future<void> _applySync(MyIdSync result) async {
    final generation = _loadGeneration;
    try {
      if (!await _myIdService!.isCurrentSync(result) ||
          !mounted ||
          generation != _loadGeneration) {
        return;
      }
      setState(() {
        ++_loadGeneration;
        _state = result.state;
        _loading = false;
      });
    } on Object {
      // 本机上下文暂不可读不能把旧失败改为成功。
    }
  }

  bool _refreshing = false;
  bool _identityChanged = false;

  Future<void> _openIdentity() async {
    await _loadState();
    if (mounted) await _refreshState();
  }

  void _onIdentityChanged() {
    if (_submitting) return;
    if (_refreshing) {
      _identityChanged = true;
    } else {
      _loadState();
    }
  }

  Future<void> _refreshState() async {
    if (_refreshing || _submitting) return;
    _refreshing = true;
    final generation = ++_loadGeneration;
    final currentUser = context.read<CurrentUserContext?>();
    String? account;
    setState(() {
      _loading = true;
    });
    try {
      account = (await currentUser?.resolve())?.accountId;
      if (!mounted || generation != _loadGeneration) return;
      final result = await _myIdService!.refreshState();
      if (!mounted || generation != _loadGeneration) return;
      if (currentUser != null &&
          (await currentUser.resolve())?.accountId != account) {
        await _loadState();
        return;
      }
      setState(() {
        if (result.status != MyIdStatus.queryFailed) _state = result;
      });
    } catch (_) {
      // 核实失败保留当前身份展示，不新增提示。
    } finally {
      _refreshing = false;
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
      if (_identityChanged && mounted) {
        _identityChanged = false;
        await _loadState();
      }
      final pending = _pendingSync;
      _pendingSync = null;
      if (pending != null && mounted) await _applySync(pending);
    }
  }

  Future<void> _loadState() async {
    final generation = ++_loadGeneration;
    if (mounted) setState(() => _loading = true);
    MyIdState nextState;
    try {
      await context.read<CurrentUserContext?>()?.resolve();
      nextState = await _myIdService!.getState();
    } on Object {
      // 本地展示读取失败时保留错误状态，不能把未知误认成访客。
      nextState = const MyIdState(
        tier: MyIdTier.visitor,
        status: MyIdStatus.queryFailed,
        errorMessage: '本地身份读取失败',
      );
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _state = nextState;
      _loading = false;
    });
  }

  /// 右上按钮总入口:civic 提示走注册局;匿名已注册→换绑;纯访客→注册。
  Future<void> _onPrimaryAction() async {
    if (_submitting || _loading) return;
    if (_state.isCitizen) {
      _showSnack('投票 / 竞选身份只能在对应注册局线下更换。');
      return;
    }
    if (_state.isAnonymousRegistered) {
      await _onRebind();
    } else {
      await _onRegister();
    }
  }

  /// 注册走全 App 唯一共享流程(弹窗、余额闸、占号提交、缓存失效、成败提示全在
  /// [startCidRegistrationFlow] 单源);本页只驱动提交阶段转圈与成功后回刷。
  ///
  /// [_submitting] 只跟随提交阶段(onSubmitting 回调),与旧实现一致:面板打开
  /// 期间不转圈;选择阶段的重入由模态面板天然阻挡。
  Future<void> _onRegister() async {
    final registered = await startCidRegistrationFlow(
      context,
      myIdService: _myIdService,
      openTopup: widget.openRegistrationTopup,
      onSubmitting: (submitting) {
        if (mounted) setState(() => _submitting = submitting);
      },
    );
    if (registered && mounted) await _loadState();
  }

  Future<void> _onRebind() async {
    final cid = _state.cidNumber;
    if (cid == null || cid.trim().isEmpty) return;
    final targets = await _myIdService!.listRebindTargets();
    if (!mounted) return;
    final newAccountId = await showRebindAccountSheet(
      context,
      targets: targets,
    );
    if (newAccountId == null || !mounted) return;
    await _runSubmit(() async {
      await _myIdService!.rebindCidTo(
        buildContext: context,
        cidNumber: cid,
        newAccountId: newAccountId,
      );
      return '身份CID号 已换绑到所选账户';
    });
  }

  /// 统一提交外壳：动作与本地身份回刷均完成后才报告成功;不吞异常。
  Future<void> _runSubmit(Future<String> Function() action) async {
    setState(() => _submitting = true);
    try {
      final message = await action();
      if (!mounted) return;
      final cid = _state.cidNumber;
      await _loadState();
      if (!mounted) return;
      if (_state.status == MyIdStatus.queryFailed ||
          _state.cidNumber != cid ||
          !_state.isAnonymousRegistered) {
        throw const AccountSecurityException('链上已换绑，身份显示尚未同步，请勿重复换绑');
      }
      _showSnack(message);
    } on Object catch (error) {
      if (!mounted) return;
      _showSnack(_describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(identityCidUiText(message)),
        backgroundColor: isError ? AppTheme.danger : null,
      ),
    );
  }

  String _describeError(Object error) {
    if (error is AccountSecurityException) return error.message;
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  List<MyIdTier> _orderedTiers() {
    if (_isQueryFailed) return _baseTierOrder;
    return <MyIdTier>[
      _state.tier,
      ..._baseTierOrder.where((tier) => tier != _state.tier),
    ];
  }

  bool _isCurrent(MyIdTier tier) =>
      !_isQueryFailed &&
      _state.status != MyIdStatus.unknown &&
      tier == _state.tier;

  bool _showActualValues(MyIdTier tier) =>
      _isCurrent(tier) && tier != MyIdTier.visitor;

  String get _visitorTitle {
    final cid = _state.cidNumber?.trim() ?? '';
    final parts = cid.split('-');
    if (parts.length == 4 && parts[1].length == 5) {
      switch (parts[1].substring(0, 4)) {
        case 'CTZN':
          return '身份 · 公民';
        case 'NATP':
          return '身份 · 居民';
      }
    }
    if (cid.isNotEmpty ||
        _state.status == MyIdStatus.unknown ||
        _isQueryFailed) {
      return '身份';
    }
    return '身份 · 访客';
  }

  @override
  Widget build(BuildContext context) {
    final tiers = _orderedTiers();
    return Scaffold(
      appBar: AppBar(
        title: const Text('身份'),
        centerTitle: true,
        actions: [
          if (_actionLabel != null)
            _submitting
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppLayout.scaled(context, 18),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: AppLayout.scaled(context, 18),
                        height: AppLayout.scaled(context, 18),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(
                      right: AppLayout.scaled(context, 4),
                    ),
                    child: TextButton(
                      onPressed: _loading ? null : _onPrimaryAction,
                      child: Text(_actionLabel!),
                    ),
                  ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshState,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 12),
            vertical: AppLayout.scaled(context, 14),
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_loading)
              LinearProgressIndicator(minHeight: AppLayout.scaled(context, 2))
            else
              SizedBox(height: AppLayout.scaled(context, 2)),
            SizedBox(height: AppLayout.scaled(context, 14)),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.scaled(context, 560),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < tiers.length; index++) ...[
                      _PassportIdentityCard(
                        key: ValueKey<String>(
                          'passport-card-${tiers[index].name}',
                        ),
                        tier: tiers[index],
                        current: _isCurrent(tiers[index]),
                        showActualValues: _showActualValues(tiers[index]),
                        fields: _fieldsFor(tiers[index]),
                        visitorTitle: _visitorTitle,
                        registeredCid:
                            tiers[index] == MyIdTier.visitor &&
                                _state.isAnonymousRegistered
                            ? _state.cidNumber
                            : null,
                        registeredAccount: _shortAddress(
                          _state.votingAccountId,
                        ),
                      ),
                      if (index != tiers.length - 1)
                        SizedBox(height: AppLayout.scaled(context, 14)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_PassportField> _fieldsFor(MyIdTier tier) {
    if (tier == MyIdTier.visitor) return const <_PassportField>[];
    final showValues = _showActualValues(tier);
    final fields = <_PassportField>[
      _PassportField(
        label: '身份CID号',
        value: showValues
            ? formatIdentityCidText(_displayValue(_state.cidNumber))
            : null,
        mono: true,
        singleLine: true,
      ),
      _PassportField(
        label: '绑定账户',
        value: showValues ? _shortAddress(_state.votingAccountId) : null,
        mono: true,
      ),
      _PassportField(
        label: '居住选区',
        value: showValues ? _displayValue(_state.residenceDistrict) : null,
      ),
      _PassportField(
        label: '身份状态',
        value: showValues ? _statusText(_state.status) : null,
      ),
      _PassportField(
        label: '身份有效期',
        value: showValues ? _validityText() : null,
      ),
    ];
    if (tier == MyIdTier.candidate) {
      fields.addAll(<_PassportField>[
        _PassportField(
          label: '公民姓名',
          value: showValues
              ? _displayValue(
                  '${_state.familyName ?? ''}${_state.givenName ?? ''}',
                )
              : null,
        ),
        _PassportField(
          label: '性别',
          value: showValues ? _displayValue(_state.citizenSexLabel) : null,
        ),
        _PassportField(
          label: '出生日期',
          value: showValues
              ? (_formatDate(_state.citizenBirthDate) ?? '—')
              : null,
        ),
        _PassportField(
          label: '出生地',
          value: showValues ? _displayValue(_state.birthDistrict) : null,
        ),
      ]);
    }
    return fields;
  }

  String _validityText() {
    final from = _formatDate(_state.passportValidFrom);
    final until = _formatDate(_state.passportValidUntil);
    if (from == null || until == null) return '—';
    return '$from 至 $until';
  }

  static String _displayValue(String? input) {
    final value = input?.trim() ?? '';
    return value.isEmpty ? '—' : value;
  }

  static String _shortAddress(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return '—';
    if (value.length <= 20) return value;
    return '${value.substring(0, 8)}......${value.substring(value.length - 12)}';
  }

  static String _statusText(MyIdStatus? status) => switch (status) {
    MyIdStatus.normal => '正常',
    MyIdStatus.notYetValid => '未生效',
    MyIdStatus.expired => '已过期',
    MyIdStatus.revoked => '已吊销',
    _ => '—',
  };

  static String? _formatDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return '${year.toString().padLeft(4, '0')}年'
        '${month.toString().padLeft(2, '0')}月'
        '${day.toString().padLeft(2, '0')}日';
  }
}

class _PassportIdentityCard extends StatelessWidget {
  const _PassportIdentityCard({
    super.key,
    required this.tier,
    required this.current,
    required this.showActualValues,
    required this.fields,
    required this.visitorTitle,
    required this.registeredAccount,
    this.registeredCid,
  });

  final MyIdTier tier;
  final bool current;
  final bool showActualValues;
  final List<_PassportField> fields;
  final String visitorTitle;
  final String registeredAccount;

  /// 访客卡专用:已占匿名 CID 时的 身份CID号(非空则在卡内补显「身份CID号」)。
  final String? registeredCid;

  String get _title => switch (tier) {
    MyIdTier.visitor => visitorTitle,
    MyIdTier.voting || MyIdTier.candidate => '身份 · 公民',
  };

  Color get _color => switch (tier) {
    MyIdTier.visitor => AppTheme.identityVisitor,
    MyIdTier.voting => AppTheme.identityVoting,
    MyIdTier.candidate => AppTheme.identityCandidate,
  };

  String get _identityLevel => switch (tier) {
    MyIdTier.visitor => 'visitor',
    MyIdTier.voting => 'voting',
    MyIdTier.candidate => 'candidate',
  };

  /// 是否在右上角挂「当前身份」徽章。
  ///
  /// 当前卡才挂，且**纯访客（无 CID）不挂**：投票/竞选必有 CID，匿名已注册有 CID
  /// （`registeredCid` 非空），只有从未占号的纯访客不挂。链读失败时 `current` 恒 false，
  /// 天然不挂——「不挂徽章」绝不能把「没读到链」冒充成「没注册」。
  bool get _showsCurrentBadge {
    if (!current) return false;
    if (tier != MyIdTier.visitor) return true;
    return registeredCid != null && registeredCid!.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final badgeStyle = identityBadgeStyle(
      cidLevel: _identityLevel,
      memberLevel: null,
      membergateActive: false,
    )!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
      decoration: BoxDecoration(
        color: Color.alphaBlend(_color.withAlpha(8), AppTheme.surfaceCard),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _color, width: current ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: _color.withAlpha(current ? 38 : 13),
            blurRadius: AppLayout.scaledValue(current ? 18 : 8),
            offset: Offset(0, AppLayout.scaledValue(current ? 8 : 3)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                // 徽章不挂时不预留其 88px 位置，避免纯访客卡标题行右侧留空。
                padding: EdgeInsets.only(
                  right: AppLayout.scaledValue(_showsCurrentBadge ? 88 : 0),
                ),
                child: Row(
                  children: [
                    IdentityBadge(
                      style: badgeStyle,
                      size: AppLayout.scaled(context, 44),
                      tooltip: _title,
                    ),
                    SizedBox(width: AppLayout.scaled(context, 12)),
                    // Flexible（非 Expanded）让标题只占内容宽度，类型胶囊紧贴标题右侧，
                    // 而不是被撑到卡片最右端；标题过长时仍走省略号避免溢出。
                    Flexible(
                      child: Text(
                        _title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 18),
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: _color,
                        ),
                      ),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 8)),
                    _IdentityTag(tier: tier),
                  ],
                ),
              ),
              // 普通卡:已注册时依次显示 CID、绑定账户；纯访客只留标题行。
              if (tier == MyIdTier.visitor) ...[
                if (registeredCid != null &&
                    registeredCid!.trim().isNotEmpty) ...[
                  SizedBox(height: AppLayout.scaled(context, 14)),
                  _PassportFieldRow(
                    field: _PassportField(
                      label: '身份CID号',
                      value: formatIdentityCidText(registeredCid!),
                      mono: true,
                      singleLine: true,
                    ),
                    color: _color,
                    showValue: true,
                  ),
                  SizedBox(height: AppLayout.scaled(context, 6)),
                  _PassportFieldRow(
                    field: _PassportField(
                      label: '绑定账户',
                      value: registeredAccount,
                      mono: true,
                    ),
                    color: _color,
                    showValue: true,
                  ),
                ],
              ] else ...[
                SizedBox(height: AppLayout.scaled(context, 14)),
                for (var index = 0; index < fields.length; index++) ...[
                  _PassportFieldRow(
                    field: fields[index],
                    color: _color,
                    showValue: showActualValues,
                  ),
                  if (index != fields.length - 1)
                    SizedBox(height: AppLayout.scaled(context, 6)),
                ],
              ],
            ],
          ),
          if (_showsCurrentBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                key: ValueKey<String>('current-identity-${tier.name}'),
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 9),
                  vertical: AppLayout.scaled(context, 5),
                ),
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(AppLayout.scaledValue(7)),
                ),
                child: Text(
                  '当前身份',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppLayout.scaled(context, 11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 身份类型胶囊：匿名金色、投票蓝色、竞选黄色，各配对应图标。
class _IdentityTag extends StatelessWidget {
  const _IdentityTag({required this.tier});

  final MyIdTier tier;

  @override
  Widget build(BuildContext context) {
    final (name, label, icon, color) = switch (tier) {
      MyIdTier.visitor => (
        'anonymous',
        '匿名',
        Icons.visibility_off_outlined,
        AppTheme.identityVisitor,
      ),
      MyIdTier.voting => (
        'voting',
        '投票',
        Icons.how_to_vote_outlined,
        AppTheme.identityVoting,
      ),
      MyIdTier.candidate => (
        'candidate',
        '竞选',
        Icons.campaign_outlined,
        AppTheme.gold,
      ),
    };
    return Container(
      key: ValueKey<String>('passport-$name-tag'),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 8),
        vertical: AppLayout.scaled(context, 3),
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(999)),
        border: Border.all(color: color.withAlpha(64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppLayout.scaled(context, 12), color: color),
          SizedBox(width: AppLayout.scaled(context, 3)),
          Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 11),
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportField {
  const _PassportField({
    required this.label,
    this.value,
    this.mono = false,
    this.singleLine = false,
  });

  final String label;
  final String? value;
  final bool mono;
  final bool singleLine;
}

class _PassportFieldRow extends StatelessWidget {
  const _PassportFieldRow({
    required this.field,
    required this.color,
    required this.showValue,
  });

  final _PassportField field;
  final Color color;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 10),
        vertical: AppLayout.scaled(context, 7),
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(showValue ? 10 : 7),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        border: Border.all(color: color.withAlpha(24)),
      ),
      child: showValue
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称按自身宽度占位，值紧随其后；不再为短名称保留固定列空白。
                Text(
                  field.label,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.4,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 6)),
                Expanded(child: _PassportFieldValue(field: field)),
              ],
            )
          : Text(
              field.label,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 12),
                height: 1.35,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _PassportFieldValue extends StatelessWidget {
  const _PassportFieldValue({required this.field});

  final _PassportField field;

  @override
  Widget build(BuildContext context) {
    final value = Text(
      field.value ?? '—',
      maxLines: field.singleLine ? 1 : null,
      softWrap: !field.singleLine,
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: AppLayout.scaledValue(field.mono ? 12 : 13),
        height: 1.4,
        fontFamily: field.mono ? 'monospace' : null,
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!field.singleLine) return value;
    // 身份CID号必须完整保持一行；窄屏只在必要时等比缩小，不用换行或省略破坏号码。
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: value,
    );
  }
}

// 从已过滤的本机其他账户中选择CID换绑目标。

/// 弹出“更换身份CID号绑定的账户”底部面板：从本地其他账户中挑选新的签名账户。
///
/// 返回选定账户的 `accountId`;取消 / 无可选账户返回 `null`。授权与提交由调用方
/// ([MyIdService.rebindCidTo])承接;目标账户已由调用方过滤掉当前身份账户。
Future<String?> showRebindAccountSheet(
  BuildContext context, {
  required List<CitizenWalletStateAccount> targets,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RebindAccountSheet(targets: targets),
  );
}

class RebindAccountSheet extends StatelessWidget {
  const RebindAccountSheet({super.key, required this.targets});

  final List<CitizenWalletStateAccount> targets;

  static String _rebindShortAddress(String value) {
    if (value.length <= 18) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: AppLayout.scaled(context, 36),
                height: AppLayout.scaled(context, 4),
                margin: EdgeInsets.only(bottom: AppLayout.scaled(context, 16)),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(AppLayout.scaledValue(2)),
                ),
              ),
            ),
            Text(
              '更换身份CID号绑定的账户',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 17),
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 6)),
            Text(
              '更换身份CID号绑定的签名账户为以下选中的账户，更换绑定需当前钱包账户与目标钱包账户'
              '各签名一次（共两次生物识别授权）。',
              style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textSecondary),
            ),
            SizedBox(height: AppLayout.scaled(context, 16)),
            if (targets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: AppTheme.bannerDecoration(AppTheme.warning),
                child: Text(
                  '暂无可换绑的其他账户。请先在钱包里添加账户,再来更换。',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    height: 1.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ...targets.map(
                (account) => Padding(
                  padding:
                      EdgeInsets.only(bottom: AppLayout.scaled(context, 10)),
                  child: _AccountOption(
                    account: account,
                    shortAddress: _rebindShortAddress(account.ss58Address),
                    onTap: () => Navigator.of(context).pop(account.accountId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单个可换绑账户行:账户名 + 序号 + 短地址,点击即选中并回传。
class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.account,
    required this.shortAddress,
    required this.onTap,
  });

  final CitizenWalletStateAccount account;
  final String shortAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 15),
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: AppLayout.scaled(context, 8)),
                      Text(
                        '#${account.accountIndex}',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppLayout.scaled(context, 3)),
                  Text(
                    shortAddress,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 12),
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: AppLayout.scaled(context, 20),
            ),
          ],
        ),
      ),
    );
  }
}
