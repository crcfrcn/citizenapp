// 展示机构人员与岗位，按本机冷钱包状态提供管理员激活。

import 'package:citizen_widgets/chain_balance_scope.dart';
import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/administrators/admin_activation_service.dart';
import 'package:citizen_citizen/administrators/institution_admin_service.dart';
import 'package:citizen_citizen/institution/institution_assignment_card.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 管理员列表页面。
///
/// 展示机构所有管理员的完整 SS58 地址，支持 QR 扫码激活。
class AdminListPage extends StatefulWidget {
  const AdminListPage({
    super.key,
    required this.institution,
    required this.accountIdentity,
    required this.admins,
    required this.activatedAccountIds,
    required this.badgeColor,
    this.onActivated,
  });

  final InstitutionInfo institution;
  final AdminAccountIdentity accountIdentity;

  /// 机构管理员人员视图；同一管理员的多个岗位归在同一人员行。
  final List<InstitutionAdminView> admins;

  /// 已激活管理员的规范 AccountId 集合。
  final Set<String> activatedAccountIds;
  final Color badgeColor;

  /// 激活成功后的回调（通知父页面刷新）。
  final VoidCallback? onActivated;

  @override
  State<AdminListPage> createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  AdminListState? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data != null) return;
    _data = AdminListState(
      admins: widget.admins,
      identity: widget.accountIdentity,
      activatedAccountIds: widget.activatedAccountIds,
      sdk: context.read<CitizenSdk?>(),
    )..addListener(_changed);
    unawaited(_data!.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data?.removeListener(_changed);
    _data?.dispose();
    super.dispose();
  }

  void _onAdminActivated(String accountId) {
    _data!.markActivated(accountId);
    widget.onActivated?.call();
  }

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: _data!.admins.map((view) => view.admin.accountId),
    builder: _buildBalanceView,
  );

  Widget _buildBalanceView(BuildContext context, CitizenBalances balances) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '管理员列表',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 机构信息
          _buildInstitutionHeader(),
          SizedBox(height: AppLayout.scaled(context, 16)),
          // 管理员总数
          Text(
            '共 ${_data!.admins.length} 位管理员　通过阈值 ${widget.institution.internalThreshold}',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 13),
              color: AppTheme.textTertiary,
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 12)),
          // 管理员列表
          if (_data!.admins.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppLayout.scaled(context, 24),
              ),
              child: Center(
                child: Text(
                  '暂无管理员信息',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 14),
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_data!.admins.length, (index) {
              final adminView = _data!.admins[index];
              final accountId = adminView.admin.accountId;
              final isImported =
                  _data!.walletsReady &&
                  _data!.coldAccountIds.contains(accountId);
              final isActivated = _data!.activatedAccountIds.contains(
                accountId,
              );
              return InstitutionAdminTile(
                index: index + 1,
                adminView: adminView,
                isImported: isImported,
                isActivated: isActivated,
                accountIdentity: widget.accountIdentity,
                onActivated: () => _onAdminActivated(accountId),
                balanceFen: balances.accountState(accountId).value?.freeFen,
              );
            }),
        ],
      ),
    );
  }

  // 机构简称只在左侧显示一次，不重复附加机构类型标签。
  Widget _buildInstitutionHeader() {
    return Row(
      children: [
        Container(
          width: AppLayout.scaledValue(36),
          height: AppLayout.scaledValue(36),
          decoration: BoxDecoration(
            color: widget.badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
          ),
          child: Icon(
            Icons.people_outline,
            size: AppLayout.scaledValue(18),
            color: widget.badgeColor,
          ),
        ),
        SizedBox(width: AppLayout.scaledValue(10)),
        Expanded(
          child: Text(
            widget.institution.shortName,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(15),
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// 两个管理员列表共用本地钱包与激活状态；每个列表只读一次目录并合并变更事件。
/// 岗位未读到时独立补读，任何本地钱包故障都不能抹去公共人员资料。
class AdminListState extends ChangeNotifier {
  AdminListState({
    required List<InstitutionAdminView> admins,
    required AdminAccountIdentity? identity,
    CitizenSdk? sdk,
    Set<String> activatedAccountIds = const {},
    Future<CitizenWalletState> Function()? walletReader,
    Future<Set<String>> Function()? activationReader,
    Future<List<InstitutionAdminView>> Function()? adminReader,
    Stream<CitizenSdkEvent>? events,
  }) : admins = admins,
       activatedAccountIds = Set.of(activatedAccountIds),
       _sdk = sdk,
       _walletReader =
           walletReader ??
           (sdk == null ? null : () => sdk.getWalletState().result),
       _adminReader =
           adminReader ??
           (sdk == null || identity == null
               ? null
               : () => InstitutionAdminService(
                   chain: sdk,
                 ).fetchAdminViews(identity, identity.cidNumber!)),
       _activationReader =
           activationReader ??
           (sdk == null || identity == null
               ? null
               : () async {
                   final all = await ActivationService(
                     adminService: InstitutionAdminService(chain: sdk),
                   ).loadAll();
                   final ids = admins
                       .map((view) => view.admin.accountId)
                       .toSet();
                   return {
                     for (final entry in all)
                       if (entry.cidNumber == identity.cidNumber &&
                           ids.contains(entry.accountId))
                         entry.accountId,
                   };
                 }) {
    _events = (events ?? sdk?.events)?.listen((event) {
      if (event is CitizenSdkWalletChanged) unawaited(reloadWallets());
    });
  }

  List<InstitutionAdminView> admins;
  Set<String> activatedAccountIds;
  Set<String> coldAccountIds = const {};
  bool walletsReady = false;
  final CitizenSdk? _sdk;
  final Future<CitizenWalletState> Function()? _walletReader;
  final Future<Set<String>> Function()? _activationReader;
  final Future<List<InstitutionAdminView>> Function()? _adminReader;
  StreamSubscription<CitizenSdkEvent>? _events;
  Future<void>? _walletFlight;
  bool _walletDirty = false;
  bool _disposed = false;
  final Completer<void> _closed = Completer<void>();

  Future<void> load() async {
    await Future.wait<void>([
      reloadWallets(),
      _loadActivation(),
      _loadMissingAdmins(),
    ]);
  }

  Future<void> reloadWallets() {
    if (_disposed || _walletReader == null) return Future.value();
    _walletDirty = true;
    walletsReady = false;
    notifyListeners();
    final pending = _walletFlight;
    if (pending != null) return pending;
    late final Future<void> task;
    task =
        (() async {
          while (_walletDirty && !_disposed) {
            _walletDirty = false;
            try {
              final state = await _walletReader();
              if (_disposed) return;
              if (_walletDirty) continue;
              coldAccountIds = {
                for (final account in state.accounts)
                  if (account.signMode == CitizenWalletSignMode.cold)
                    account.accountId,
              };
              walletsReady = true;
            } on Object {
              if (_disposed) return;
              coldAccountIds = const {};
              walletsReady = false;
            }
            if (!_disposed) notifyListeners();
          }
        })().whenComplete(() {
          if (identical(_walletFlight, task)) _walletFlight = null;
        });
    _walletFlight = task;
    return task;
  }

  Future<void> _loadActivation() async {
    if (_activationReader == null) return;
    try {
      final ids = await _activationReader();
      if (_disposed) return;
      activatedAccountIds = ids;
      notifyListeners();
    } on Object {
      // 激活展示读取失败保留进入页面时的已有记录；执行时仍重新校验签名资格。
    }
  }

  Future<void> _loadMissingAdmins() async {
    if (_adminReader == null || admins.every((view) => view.assignmentsLoaded))
      return;
    try {
      final sdk = _sdk;
      if (sdk != null &&
          !await waitForProposalRead(
            getCapabilities: sdk.getCapabilities,
            lifecycle: () => sdk.lifecycle,
            events: sdk.events,
            cancelled: _closed.future,
          ))
        return;
      if (_disposed) return;
      final rows = await _adminReader();
      if (_disposed) return;
      admins = rows;
      notifyListeners();
    } on Object catch (error) {
      AppLog.proposalFailure(stage: 'institution_roles', error: error);
    }
  }

  void markActivated(String accountId) {
    if (_disposed) return;
    activatedAccountIds.add(accountId);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closed.complete();
    unawaited(_events?.cancel());
    super.dispose();
  }
}

class InstitutionAdminTile extends StatelessWidget {
  const InstitutionAdminTile({
    super.key,
    required this.index,
    required this.adminView,
    required this.isImported,
    required this.isActivated,
    required this.accountIdentity,
    required this.onActivated,
    required this.balanceFen,
  });

  final int index;

  final InstitutionAdminView adminView;

  /// 管理员规范 AccountId；激活和匹配只按账户 ID。
  String get accountId => adminView.admin.accountId;

  /// 用户是否已导入此账户 ID 的冷钱包。
  final bool isImported;

  /// 此管理员是否已激活。
  final bool isActivated;
  final AdminAccountIdentity? accountIdentity;
  final VoidCallback onActivated;
  final BigInt? balanceFen;

  Future<void> _startActivation(BuildContext context) async {
    final identity = accountIdentity;
    if (!isImported || isActivated || identity == null) return;
    // 检查是否为冷钱包（热钱包不允许激活）
    final wallets =
        (await context.read<CitizenSdk>().getWalletState().result).accounts;
    final wallet = wallets.where((w) {
      return w.accountId == accountId;
    }).firstOrNull;

    if (wallet == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到对应钱包')));
      return;
    }

    if (wallet.signMode != CitizenWalletSignMode.cold) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('管理员仅支持冷钱包激活')));
      return;
    }
    if (!context.mounted) return;
    final sdk = context.read<CitizenSdk>();

    // SDK编码原业务字段并负责冷热账户签名与QR_V1会话。
    final activationService = ActivationService(
      adminService: InstitutionAdminService(chain: sdk),
    );
    final payload = await activationService.buildActivationPayload(
      accountId: accountId,
      identity: identity,
    );

    if (!context.mounted) return;
    await signCitizenPayload(
      signing: sdk,
      context: context,
      accountId: accountId,
      payload: payload,
      action: CitizenQrActions.activateAdmin,
    );
    if (!context.mounted) return;

    // 验证并存储激活记录
    try {
      await activationService.activate(
        accountId: accountId,
        identity: identity,
      );
      onActivated();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('管理员激活成功')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('激活失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 6)),
      child: InstitutionAssignmentCard(
        adminView: adminView,
        index: index,
        balanceFen: balanceFen,
        trailing: _buildActivationControl(context),
      ),
    );
  }

  Widget _buildActivationControl(BuildContext context) {
    // 公共资料不受本机钱包影响；激活入口始终占位，未就绪或不匹配时明确禁用。
    final enabled = isImported && !isActivated && accountIdentity != null;
    final color = isActivated
        ? AppTheme.success
        : enabled
        ? AppTheme.primary
        : AppTheme.textTertiary;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => _startActivation(context) : null,
        child: Container(
          height: InstitutionAssignmentCard.actionHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 8),
            vertical: AppLayout.scaled(context, 4),
          ),
          decoration: BoxDecoration(
            color: enabled || isActivated
                ? color.withValues(alpha: 0.1)
                : AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
          ),
          child: Text(
            isActivated ? '已激活' : '激活',
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 11),
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
