// 个人账户模型、入口、列表、详情及导航合同。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'dart:convert';
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_storage/user.dart' as wallet_store;
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_system/log.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_widgets/balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'lifecycle.dart';
import 'members.dart';
import 'proposals.dart';
import 'chain.dart';
import 'storage.dart';

// 个人账户的展示与导航主体，不是机构CID或InstitutionInfo。
class PersonalAccountInfo {
  const PersonalAccountInfo({
    required this.fullName,
    required this.shortName,
    required this.accountId,

    this.internalThresholdOverride,
  });
  final String fullName;
  final String shortName;
  final String accountId;

  final int? internalThresholdOverride;
  String get mainAccountId => accountId;
  int get internalThreshold => internalThresholdOverride ?? 0;
  PersonalAccountInfo copyWith({int? internalThresholdOverride}) =>
      PersonalAccountInfo(
        fullName: fullName,
        shortName: shortName,
        accountId: accountId,

        internalThresholdOverride:
            internalThresholdOverride ?? this.internalThresholdOverride,
      );
}

/// 根App只装配通用转账页面；个人详情与成员页面由本包自己构造。
class PersonalNavigation {
  const PersonalNavigation({required this.transfer});
  final Widget Function({
    required PersonalAccountInfo account,
    required IconData icon,
    required Color badgeColor,
    required List<CitizenWalletStateAccount> adminWallets,
    required Future<void> Function(BigInt proposalId) onCreated,
  })
  transfer;
}

// 提供交易页进入个人多签账户列表的整卡入口。

/// 交易页顶部「多签账户」入口卡片。
///
/// 与同目录的多签转账入口卡片同形：左图标 + 标题 + 右向 chevron，整张卡是点击区
/// （chevron 只作指示，不单独包 InkWell）。
class PersonalAccountEntryCard extends StatelessWidget {
  const PersonalAccountEntryCard({super.key, this.onTap});

  /// 默认打开多签账户列表；测试可注入替身断言路由。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => _openPersonalAccounts(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 12),
              vertical: AppLayout.scaled(context, 16),
            ),
            child: Row(
              children: [
                RotatedBox(
                  // Material 的分享关系图旋转后为“一上两下”圆形节点，
                  // 与确认稿的多签关系结构和线性描边最接近。
                  quarterTurns: 1,
                  child: Icon(
                    Icons.share_outlined,
                    size: AppLayout.scaled(context, 24),
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 12)),
                Expanded(
                  child: Text(
                    '多签账户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppLayout.scaled(context, 15),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // 与链上交易状态行右侧同一颗 chevron。
                Icon(Icons.chevron_right, size: AppLayout.scaled(context, 22)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPersonalAccounts(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PersonalAccountListPage()));
  }
}

// 发现、刷新并展示本机相关个人多签账户。

// 个人多签账户列表页。
//
// 设计边界：
// - 本页只读取、发现、刷新和展示个人多签账户。
// - 机构账户由 OnChina 注册局登记，CitizenApp 这里不再发现或展示机构多签。
// - 入口放在交易 tab，避免把个人自助多签与机构登记流程混在一起。

class PersonalAccountListPage extends StatefulWidget {
  const PersonalAccountListPage({super.key});

  @override
  State<PersonalAccountListPage> createState() =>
      _PersonalAccountListPageState();
}

class _PersonalAccountListPageState extends State<PersonalAccountListPage> {
  late final PersonalManageService _personalManageService;
  late final PersonalProposalHistoryService _personalProposalHistoryService;
  late final PersonalScanService _scanService;
  late final PersonalManageDiscoveryService _discoveryService;
  bool _dependenciesReady = false;

  List<wallet_store.Account> _items = [];
  Map<String, String?> _statuses = const {};
  bool _loading = true;
  bool _scanning = false;
  String? _scanProgress;

  static const _activeStatusTtl = Duration(minutes: 60);
  static const _inactiveStatusTtl = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _personalManageService = PersonalManageService(
      chain: sdk,
      transactions: sdk,
    );
    _personalProposalHistoryService = PersonalProposalHistoryService(
      chain: sdk,
    );
    _scanService = PersonalScanService(chain: sdk);
    _discoveryService = PersonalManageDiscoveryService(
      personalManageService: _personalManageService,
    );
    _dependenciesReady = true;
    _load();
  }

  Future<void> _load({bool runDiscovery = true}) async {
    setState(() => _loading = true);
    try {
      await _readFromIsar();
    } catch (_) {
      // 本地库异常不阻塞页面进入，用户仍可通过下拉刷新重试。
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (runDiscovery) {
      unawaited(_runBackgroundRefresh());
    }
  }

  Future<void> _readFromIsar() async {
    final snapshot = await UserIsar.instance.read((isar) async {
      final personals = await isar
          .collection<wallet_store.Account>()
          .where()
          .findAll();
      final statuses = await PersonalMultisigLocalState.readStatuses(
        isar,
        personals.map((p) => p.accountId),
      );
      return (personals: personals, statuses: statuses);
    });

    final sorted = [...snapshot.personals]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (!mounted) return;
    setState(() {
      _items = sorted;
      _statuses = snapshot.statuses;
    });
  }

  Future<void> _runBackgroundRefresh() async {
    await _refreshKnownStatuses();
    await _runDiscoveryIfWalletsChanged();
  }

  Future<void> _refreshKnownStatuses({
    bool force = false,
    Set<String>? personalAccounts,
  }) async {
    final snapshot = await UserIsar.instance.read((isar) async {
      final personals = await isar
          .collection<wallet_store.Account>()
          .where()
          .findAll();
      final statuses = await PersonalMultisigLocalState.readStatusSnapshots(
        isar,
        personals.map((p) => p.accountId),
      );
      return (personals: personals, statuses: statuses);
    });

    final filter = personalAccounts?.map(_requireAccountId).toSet();
    final targets = snapshot.personals
        .where((item) {
          final address = _requireAccountId(item.accountId);
          if (filter != null && !filter.contains(address)) return false;
          return force || _shouldRefreshStatus(snapshot.statuses[address]);
        })
        .toList(growable: false);

    if (targets.isEmpty) return;
    await _syncPersonalStatuses(targets);
    await _readFromIsar();
  }

  bool _shouldRefreshStatus(MultisigLocalStatusSnapshot? snapshot) {
    if (snapshot?.syncedAt == null) return true;
    final lastSyncAt = DateTime.fromMillisecondsSinceEpoch(snapshot!.syncedAt!);
    final ttl = snapshot.groupState == PersonalMultisigLocalState.statusActive
        ? _activeStatusTtl
        : _inactiveStatusTtl;
    return DateTime.now().difference(lastSyncAt) >= ttl;
  }

  Future<void> _syncPersonalStatuses(
    List<wallet_store.Account> personals,
  ) async {
    if (personals.isEmpty) return;
    Map<String, AccountInfo?> infos;
    try {
      infos = await _personalManageService.fetchPersonalAccountsBatch(
        personals.map((p) => p.accountId),
      );
    } catch (_) {
      // 批量查链失败时保留本地旧状态，不能把网络失败写成已注销。
      return;
    }

    for (final personal in personals) {
      try {
        final info = infos[_requireAccountId(personal.accountId)];
        if (info == null &&
            await _personalProposalHistoryService
                .hasUnchainedVotingCreateProposal(personal.accountId)) {
          await _deletePersonalGhost(personal.accountId);
          continue;
        }
        final status = info == null
            ? PersonalMultisigLocalState.statusClosed
            : info.status == MultisigStatus.active
            ? PersonalMultisigLocalState.statusActive
            : PersonalMultisigLocalState.statusPending;
        await UserIsar.instance.writeTxn((isar) async {
          await PersonalMultisigLocalState.putStatusInTxn(
            isar,
            personal.accountId,
            status,
          );
          if (info == null) {
            await PersonalMultisigLocalState.deleteDetailInTxn(
              isar,
              personal.accountId,
            );
          } else {
            await PersonalMultisigLocalState.putDetailInTxn(
              isar,
              personal.accountId,
              MultisigLocalDetailSnapshot(
                groupState: status,
                admins: info.admins,
                threshold: info.threshold,
                syncedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
        });
      } catch (_) {
        // 单个账户刷新失败只跳过该账户，避免影响整页列表。
      }
    }
  }

  Future<void> _deletePersonalGhost(String accountId) async {
    await UserIsar.instance.writeTxn((isar) async {
      // 旧版本曾在 tx_hash 返回后提前写入本地多签；若链上没有账户
      // 且创建提案也不存在，说明它从未上链，不能展示为“已注销”。
      await isar
          .collection<wallet_store.Account>()
          .where()
          .accountIdEqualTo(_requireAccountId(accountId))
          .deleteAll();
      await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .deleteAll();
      await PersonalMultisigLocalState.deleteStatusInTxn(isar, accountId);
      await PersonalMultisigLocalState.deleteDetailInTxn(isar, accountId);
    });
  }

  Future<({bool anyChanged, bool completed})> _runBackgroundDiscovery() async {
    if (_scanning) return (anyChanged: false, completed: false);

    final myAccountIds = await _currentWalletAccountIds();
    if (myAccountIds.isEmpty) return (anyChanged: false, completed: true);

    setState(() {
      _scanning = true;
      _scanProgress = '扫描个人多签中...';
    });

    var anyChanged = false;
    var completed = false;
    try {
      // 这里只做个人多签发现，扫描结果直接交给个人多签服务处理。
      final scan = await _scanService.scanAll(
        onProgress: (scanned, total, decoded) {
          if (!mounted) return;
          setState(() {
            _scanProgress =
                '个人多签扫描 $scanned${total == null ? '' : '/$total'} · 已解码 $decoded';
          });
        },
      );
      final stats = await _discoveryService.processScanned(
        scan,
        myAccountIds: myAccountIds,
      );
      anyChanged = stats.newlyAdded > 0 || stats.orphansRemoved > 0;
      completed = !stats.partialFailure;
    } catch (e) {
      AppLog.d('[PersonalAccountListPage] discovery 失败: $e');
    } finally {
      if (anyChanged) {
        await _readFromIsar();
      }
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanProgress = null;
        });
      }
    }
    return (anyChanged: anyChanged, completed: completed);
  }

  Future<void> _runDiscoveryIfWalletsChanged() async {
    final fingerprint = await _currentWalletFingerprint();
    if (fingerprint.isEmpty) return;
    final lastFingerprint = await _readDiscoveryWalletFingerprint();
    if (lastFingerprint == fingerprint) return;
    final result = await _runBackgroundDiscovery();
    if (result.completed) {
      await _writeDiscoveryWalletFingerprint(fingerprint);
    }
  }

  Future<void> _onPullRefresh() async {
    await _refreshKnownStatuses(force: true);
    final result = await _runBackgroundDiscovery();
    if (result.completed) {
      await _writeDiscoveryWalletFingerprint(await _currentWalletFingerprint());
    }
    await _readFromIsar();
  }

  Future<void> _openCreatePersonal() async {
    final createdAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PersonalAccountCreatePage()),
    );
    if (createdAddress != null) {
      await _refreshKnownStatuses(
        force: true,
        personalAccounts: {createdAddress},
      );
    }
  }

  void _onCardTap(wallet_store.Account item) {
    final localStatus = _statuses[_requireAccountId(item.accountId)];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalManageAccountInfoPage(
          account: PersonalAccountInfo(
            fullName: item.accountName,
            shortName: item.accountName,

            accountId: item.accountId,
          ),
          initialLocalStatus: localStatus,
          initialAdminAccountIds: item.adminAccounts,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      unawaited(
        _refreshKnownStatuses(force: true, personalAccounts: {item.accountId}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '多签账户',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增个人多签',
            onPressed: _openCreatePersonal,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning && _scanProgress != null) _buildScanBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryDark.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(16),
        vertical: AppLayout.scaledValue(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppLayout.scaledValue(12),
            height: AppLayout.scaledValue(12),
            child: const CircularProgressIndicator(strokeWidth: 1.5),
          ),
          SizedBox(width: AppLayout.scaledValue(8)),
          Expanded(
            child: Text(
              _scanProgress!,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12),
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _onPullRefresh,
      child: ListView(
        children: [
          SizedBox(height: AppLayout.scaledValue(80)),
          Icon(
            Icons.account_tree_outlined,
            size: AppLayout.scaledValue(64),
            color: AppTheme.border,
          ),
          SizedBox(height: AppLayout.scaledValue(12)),
          Center(
            child: Text(
              '暂无多签账户',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
          Center(
            child: Text(
              '点击右上角 + 新增个人多签;\n你作为管理员参与的个人多签会自动出现在此',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _onPullRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _items.length,
        separatorBuilder: (_, _) => SizedBox(height: AppLayout.scaledValue(8)),
        itemBuilder: (_, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildCard(wallet_store.Account item) {
    final ss58 = _accountAddressLabel(item.accountId);
    final localStatus = _statuses[_requireAccountId(item.accountId)];
    final isClosed = localStatus == PersonalMultisigLocalState.statusClosed;
    final subtitleParts = <String>[
      _truncateAddress(ss58),
      if (item.isFound) '我作为 ${item.adminAccounts.length} 位管理员之一参与',
    ];
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: () => _onCardTap(item),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaledValue(14),
            vertical: AppLayout.scaledValue(12),
          ),
          child: Row(
            children: [
              Container(
                width: AppLayout.scaledValue(40),
                height: AppLayout.scaledValue(40),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: AppLayout.scaledValue(20),
                  color: AppTheme.accent,
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppLayout.scaledValue(6),
                            vertical: AppLayout.scaledValue(2),
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppLayout.scaledValue(4),
                            ),
                          ),
                          child: Text(
                            '个人',
                            style: TextStyle(
                              fontSize: AppLayout.scaledValue(11),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        if (isClosed) ...[
                          SizedBox(width: AppLayout.scaledValue(6)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppLayout.scaledValue(6),
                              vertical: AppLayout.scaledValue(2),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.textTertiary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppLayout.scaledValue(4),
                              ),
                            ),
                            child: Text(
                              '已注销',
                              style: TextStyle(
                                fontSize: AppLayout.scaledValue(11),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(width: AppLayout.scaledValue(6)),
                        Expanded(
                          child: Text(
                            item.accountName,
                            style: TextStyle(
                              fontSize: AppLayout.scaledValue(15),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppLayout.scaledValue(2)),
                    Text(
                      subtitleParts.join(' · '),
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

  String _accountAddressLabel(String hex) {
    try {
      return citizenSs58FromAccountId(hex);
    } on FormatException {
      return '地址无效';
    }
  }

  String _truncateAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  Future<Set<String>> _currentWalletAccountIds() async {
    final wallets =
        (await context.read<CitizenSdk>().getWalletState().result).accounts;
    return wallets.map((wallet) => wallet.accountId).toSet();
  }

  Future<String> _currentWalletFingerprint() async {
    final accountIds = (await _currentWalletAccountIds()).toList()..sort();
    return accountIds.join('|');
  }

  Future<String?> _readDiscoveryWalletFingerprint() {
    return UserIsar.instance.read((isar) async {
      return (await isar.collection<wallet_store.Scan>().get(0))?.walletHash;
    });
  }

  Future<void> _writeDiscoveryWalletFingerprint(String fingerprint) {
    return UserIsar.instance.writeTxn((isar) async {
      await isar.collection<wallet_store.Scan>().put(
        wallet_store.Scan()
          ..rowId = 0
          ..walletHash = fingerprint,
      );
    });
  }
}

// 展示个人多签资料、余额、管理员及提案历史。

/// 个人多签账户详情页。
///
/// 展示个人多签名称、地址、余额、状态、管理员列表和个人提案历史。
class PersonalManageAccountInfoPage extends StatefulWidget {
  const PersonalManageAccountInfoPage({
    super.key,
    required this.account,
    this.initialLocalStatus,
    this.manageService,
    this.historyService,
    this.walletStateLoader,
    this.initialAdminAccountIds = const [],
  });

  final PersonalAccountInfo account;
  final String? initialLocalStatus;

  /// 测试可注入公开资源边界；正式入口使用SDK链读及钱包状态。
  final PersonalManageService? manageService;
  final PersonalProposalHistoryService? historyService;
  final Future<CitizenWalletState> Function()? walletStateLoader;
  final List<String> initialAdminAccountIds;

  @override
  State<PersonalManageAccountInfoPage> createState() =>
      _PersonalManageAccountInfoPageState();
}

class _PersonalManageAccountInfoPageState
    extends State<PersonalManageAccountInfoPage> {
  late final CitizenSdk _chain;
  late final PersonalManageService _personalManageService;
  bool _dependenciesReady = false;

  AccountInfo? _accountInfo;
  List<PersonalMember> _admins = const [];
  String _localStatus = PersonalMultisigLocalState.statusPending;
  int? _lastDetailRefreshAtMillis;
  bool _isClosed = false;
  bool _revoking = false;

  /// 账户余额(元):Active 来自链上 freeFen,Pending 来自本机 Isar
  /// action.snapshot_data.amount_fen(发起人承诺入金)。
  BigInt? _pendingAmountFen;
  BigInt? get _balanceFen => _isClosed
      ? null
      : _localStatus == PersonalMultisigLocalState.statusActive
      ? _chain.balances.accountState(widget.account.accountId).value?.freeFen
      : _pendingAmountFen;

  @override
  void initState() {
    super.initState();
    _localStatus =
        widget.initialLocalStatus ?? PersonalMultisigLocalState.statusPending;
    _admins = _adminsFromAccounts(widget.initialAdminAccountIds);
    _isClosed = _localStatus == PersonalMultisigLocalState.statusClosed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _chain = sdk;
    _personalManageService =
        widget.manageService ??
        PersonalManageService(chain: _chain, transactions: sdk);
    _dependenciesReady = true;
    _load();
  }

  Future<void> _load() async {
    await _loadFromLocal();
    if (_shouldRefreshDetail()) {
      unawaited(_refreshChainDetail());
    } else {}
  }

  Future<void> _loadFromLocal() async {
    try {
      final local = await UserIsar.instance.read((isar) async {
        final entity = await isar
            .collection<wallet_store.Account>()
            .filter()
            .accountIdEqualTo(widget.account.accountId)
            .findFirst();
        final statuses = await PersonalMultisigLocalState.readStatusSnapshots(
          isar,
          [widget.account.accountId],
        );
        final detail = await PersonalMultisigLocalState.readDetail(
          isar,
          widget.account.accountId,
        );
        final pendingBalance = await _readPendingBalanceFromIsar(isar);
        return (
          entity: entity,
          status: statuses[widget.account.accountId],
          detail: detail,
          pendingBalance: pendingBalance,
        );
      });

      final status =
          local.status?.groupState ??
          local.detail?.groupState ??
          widget.initialLocalStatus ??
          PersonalMultisigLocalState.statusPending;
      final isClosed = status == PersonalMultisigLocalState.statusClosed;
      final normalizedAdmins = local.detail?.admins.isNotEmpty == true
          ? _normalizeAdmins(local.detail!.admins)
          : _adminsFromAccounts(
              local.entity?.adminAccounts.isNotEmpty == true
                  ? local.entity!.adminAccounts
                  : widget.initialAdminAccountIds,
            );
      final statusEnum = _statusEnumFromLocal(status);
      final accountInfo = isClosed
          ? null
          : AccountInfo(
              adminsLen: normalizedAdmins.length,
              threshold: local.detail?.threshold,
              admins: normalizedAdmins,
              status: statusEnum,
            );

      if (!mounted) return;
      setState(() {
        _localStatus = status;
        _accountInfo = accountInfo;
        _admins = normalizedAdmins;
        _isClosed = isClosed;
        _pendingAmountFen = local.pendingBalance;
        _lastDetailRefreshAtMillis =
            local.detail?.syncedAt ?? local.status?.syncedAt;
      });
    } catch (_) {
      // 本地读取失败也不能让详情页进入全屏错误；保留入口传入的
      // 名称、地址和状态，用户仍可下拉触发链上强制刷新。
    }
  }

  bool _shouldRefreshDetail() {
    if (_lastDetailRefreshAtMillis == null) return true;
    final lastSyncAt = DateTime.fromMillisecondsSinceEpoch(
      _lastDetailRefreshAtMillis!,
    );
    final ttl = _localStatus == PersonalMultisigLocalState.statusActive
        ? const Duration(minutes: 60)
        : const Duration(minutes: 10);
    return DateTime.now().difference(lastSyncAt) >= ttl;
  }

  Future<void> _refreshChainDetail({bool force = false}) async {
    if (!force && !_shouldRefreshDetail()) return;
    try {
      final infos = await _personalManageService.fetchPersonalAccountsBatch([
        widget.account.accountId,
      ]);
      final info = infos[widget.account.accountId];
      final status = info == null
          ? PersonalMultisigLocalState.statusClosed
          : _localStatusFromInfo(info.status);
      final now = DateTime.now().millisecondsSinceEpoch;

      await UserIsar.instance.writeTxn((isar) async {
        await PersonalMultisigLocalState.putStatusInTxn(
          isar,
          widget.account.accountId,
          status,
        );
        if (info == null) {
          await PersonalMultisigLocalState.deleteDetailInTxn(
            isar,
            widget.account.accountId,
          );
        } else {
          await PersonalMultisigLocalState.putDetailInTxn(
            isar,
            widget.account.accountId,
            MultisigLocalDetailSnapshot(
              groupState: status,
              admins: info.admins,
              threshold: info.threshold,
              syncedAt: now,
            ),
          );
        }
      });

      if (!mounted) return;
      setState(() {
        _localStatus = status;
        _isClosed = status == PersonalMultisigLocalState.statusClosed;
        _accountInfo = info;
        _admins = _normalizeAdmins(info?.admins);
        _lastDetailRefreshAtMillis = now;
      });
    } catch (_) {
      // 链上刷新失败只保留本地详情，不弹进度提示或全屏失败。
    }
  }

  Future<BigInt?> _readPendingBalanceFromIsar(Isar isar) async {
    // Pending 态:从本机 Isar action 取
    // (该 multisig 的 create 提案 snapshot 含 amount_fen)。
    try {
      final entity = await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(widget.account.accountId)
          .actionKindEqualTo('create')
          .findFirst();
      if (entity?.snapshotData == null || entity!.snapshotData!.isEmpty) {
        return null;
      }
      final snapshot = jsonDecode(entity.snapshotData!) as Map<String, dynamic>;
      final amountFenStr = snapshot['amount_fen']?.toString();
      if (amountFenStr == null) return null;
      return BigInt.tryParse(amountFenStr);
    } catch (_) {
      return null;
    }
  }

  String _localStatusFromInfo(MultisigStatus status) {
    return status == MultisigStatus.active
        ? PersonalMultisigLocalState.statusActive
        : PersonalMultisigLocalState.statusPending;
  }

  MultisigStatus _statusEnumFromLocal(String status) {
    return status == PersonalMultisigLocalState.statusActive
        ? MultisigStatus.active
        : MultisigStatus.pending;
  }

  List<PersonalMember> _normalizeAdmins(List<PersonalMember>? admins) {
    if (admins == null) return const [];
    return admins
        .map(
          (admin) =>
              admin.copyWith(accountId: _requireAccountId(admin.accountId)),
        )
        .where((admin) => admin.accountId.isNotEmpty)
        .toList(growable: false);
  }

  List<PersonalMember> _adminsFromAccounts(List<String> accountIds) =>
      accountIds
          .map(_requireAccountId)
          .where((accountId) => accountId.isNotEmpty)
          .map(
            (accountId) => PersonalMember(
              accountId: accountId,
              familyName: '管理',
              givenName: '员',
            ),
          )
          .toList(growable: false);

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  // ──── 关闭 ────

  void _confirmClose() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭个人多签'),
        content: const Text('关闭个人多签将发起链上关闭提案，需要其他管理员投票通过后才会真正关闭。\n\n确定要发起关闭吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openClosePage();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('发起关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _openClosePage() async {
    var wallets = await _getAdminWallets();
    if (wallets.isEmpty) {
      await _refreshChainDetail(force: true);
      wallets = await _getAdminWallets();
    }
    if (!mounted || wallets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先导入此账户的管理员钱包')));
      }
      return;
    }

    final closed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalAccountClosePage(
          account: widget.account,
          adminWallets: wallets,
        ),
      ),
    );
    if (closed == true && mounted) {
      // 关闭提案已提交,但**链上 close 还没真正执行**(要等其他管理员投票通过)。
      // 此时 admins-change AdminAccounts 仍存,反向索引下次扫还会拉回 → **不能立即删本地**。
      // 等链上 close execute 自动清掉 AdminAccounts 后,反向索引下次扫不到再清孤立 entity。
      Navigator.pop(context);
    }
  }

  /// 是否展示右上角三点菜单；Active 显关闭，Pending 显撤销创建，Closed 显删除。
  bool _shouldShowMenu() {
    if (_isClosed) return true;
    return _localStatus == PersonalMultisigLocalState.statusActive ||
        _localStatus == PersonalMultisigLocalState.statusPending;
  }

  Future<List<CitizenWalletStateAccount>> _getAdminWallets() async {
    final wallets =
        (await (widget.walletStateLoader?.call() ??
                _chain.getWalletState().result))
            .accounts;
    final adminSet = _admins.map((admin) => admin.accountId).toSet();
    return wallets.where((w) {
      return adminSet.contains(w.accountId);
    }).toList();
  }

  Future<void> _removeFromLocal() async {
    await UserIsar.instance.writeTxn((isar) async {
      await isar
          .collection<wallet_store.Account>()
          .where()
          .accountIdEqualTo(widget.account.accountId)
          .deleteAll();
      // 个人多签 create/transfer/close 提案 snapshot 一并清掉,否则
      // [PersonalProposalHistoryService] 下次会把它们再拉回详情页。
      await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(widget.account.accountId)
          .deleteAll();
      await PersonalMultisigLocalState.deleteStatusInTxn(
        isar,
        widget.account.accountId,
      );
      await PersonalMultisigLocalState.deleteDetailInTxn(
        isar,
        widget.account.accountId,
      );
    });
  }

  Future<void> _confirmDeleteLocal() async {
    if (!_isClosed) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确认删除该已注销个人多签账户在本机的所有数据？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _removeFromLocal();
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// 撤销创建由尚未投票的冻结成员投反对票；冷热钱包共用公开投票服务。
  Future<void> _confirmRevokeCreate() async {
    if (_revoking || _localStatus != PersonalMultisigLocalState.statusPending) {
      return;
    }
    setState(() => _revoking = true);
    try {
      final id = await PersonalPendingCreateLookup().findActiveCreate(
        widget.account.accountId,
      );
      if (!mounted) return;
      if (id == null) throw StateError('未找到本机创建提案，请先刷新账户');
      final eligible = (await _personalManageService.pendingCreateVoters(
        widget.account.accountId,
        id,
      )).toSet();
      final wallets =
          (await (widget.walletStateLoader?.call() ??
                  _chain.getWalletState().result))
              .accounts
              .where((wallet) => eligible.contains(wallet.accountId))
              .toList(growable: false);
      if (!mounted) return;
      if (wallets.isEmpty) throw StateError('本机没有尚未投票的冻结成员钱包；已投出的赞成票不能撤回');
      final wallet = await showDialog<CitizenWalletStateAccount>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('选择撤销投票钱包'),
          children: [
            for (final wallet in wallets)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, wallet),
                child: Text(
                  '${wallet.signMode == CitizenWalletSignMode.hot ? '热钱包' : '冷钱包'} ${wallet.accountId.substring(0, 10)}…${wallet.accountId.substring(wallet.accountId.length - 6)}',
                ),
              ),
          ],
        ),
      );
      if (wallet == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('撤销创建'),
          content: const Text('使用所选成员钱包提交反对票。链上确认否决并清理待建记录后，创建资金释放，再清理本机记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('提交反对票'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final cleared = await _personalManageService.revokeCreate(
        accountId: widget.account.accountId,
        proposalId: id,
        signerPublicKey: citizenAccountIdBytes(wallet.accountId),
        externalSigning: (pending) => showCitizenSdkQrResponse(
          context,
          request: pending.qrRequest,
          expiresAt: BigInt.from(
            pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
          ),
        ),
      );
      if (!mounted) return;
      if (!cleared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('反对票已确认，待同步到链上否决及清理结果后再删除本机记录')),
        );
        return;
      }
      await _removeFromLocal();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撤销未完成：$error')));
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  // ──── UI ────

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: _localStatus == PersonalMultisigLocalState.statusActive
        ? [widget.account.accountId]
        : const <String>[],
    builder: _buildBalanceView,
  );
  Widget _buildBalanceView(BuildContext context, CitizenBalances balances) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '个人多签账户',
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
        // 个人多签菜单:
        // - Active  → 关闭个人多签，走 Personal::propose_close，不显示删除图标。
        // - Pending → 撤销创建，走 InternalVote approve=false 早期否决。
        actions: [
          if (_shouldShowMenu())
            PopupMenuButton<String>(
              enabled: !_revoking,
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete') _confirmDeleteLocal();
                if (value == 'close') _confirmClose();
                if (value == 'revoke_create') _confirmRevokeCreate();
              },
              itemBuilder: (_) {
                final isActive =
                    _localStatus == PersonalMultisigLocalState.statusActive;
                return [
                  if (_isClosed)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: AppLayout.scaled(context, 20),
                            color: AppTheme.danger,
                          ),
                          SizedBox(width: AppLayout.scaled(context, 8)),
                          const Text(
                            '删除',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                        ],
                      ),
                    )
                  else if (isActive)
                    const PopupMenuItem(
                      value: 'close',
                      child: Text(
                        '关闭个人多签',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: 'revoke_create',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: AppLayout.scaled(context, 20),
                            color: AppTheme.danger,
                          ),
                          SizedBox(width: AppLayout.scaled(context, 8)),
                          const Text(
                            '撤销创建',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final accountSs58 = citizenSs58FromAccountId(widget.account.accountId);
    final info = _accountInfo;
    final statusLabel = _isClosed
        ? '已注销'
        : _localStatus == PersonalMultisigLocalState.statusActive
        ? '已激活'
        : '待激活';
    final statusColor = _isClosed
        ? AppTheme.textTertiary
        : _localStatus == PersonalMultisigLocalState.statusActive
        ? AppTheme.success
        : AppTheme.warning;

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshChainDetail(force: true);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 基本信息卡片
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppLayout.scaledValue(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '账户信息',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(16),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  SizedBox(height: AppLayout.scaledValue(12)),
                  _buildInfoRow('账户简称', widget.account.shortName),
                  Divider(height: AppLayout.scaledValue(20)),
                  _buildInfoRow(
                    '多签账户',
                    accountSs58,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: accountSs58));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('地址已复制'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  if (!_isClosed) ...[
                    // 账户余额：Active 显示链上 freeFen，Pending 显示
                    // 发起人承诺金额；注销账户不再显示旧金额。
                    Divider(height: AppLayout.scaledValue(20)),
                    _buildBalanceRow(_statusEnumFromLocal(_localStatus)),
                  ],
                  Divider(height: AppLayout.scaledValue(20)),
                  _buildInfoRow('状态', statusLabel, valueColor: statusColor),
                  // 管理员数量 / 通过阈值不单列:管理员列表卡片
                  // subtitle 已显示这两项信息,避免重复。
                ],
              ),
            ),
          ),

          if (!_isClosed) ...[
            SizedBox(height: AppLayout.scaledValue(16)),
            PersonalTransferEntryCard(
              account: widget.account,
              enabled: _localStatus == PersonalMultisigLocalState.statusActive,
              loadAdminWallets: _getAdminWallets,
              onCreated: () => _refreshChainDetail(force: true),
            ),
            SizedBox(height: AppLayout.scaledValue(16)),
          ] else
            SizedBox(height: AppLayout.scaledValue(16)),

          // 管理员列表(折叠成单行,点击进入子页)
          _buildAdminEntryCard(info),

          // 个人多签提案列表(req 5):活跃 + 历史(本机 Isar 永久保留终态记录)
          SizedBox(height: AppLayout.scaledValue(16)),
          FutureBuilder<List<CitizenWalletStateAccount>>(
            future: _getAdminWallets(),
            builder: (context, snapshot) {
              final wallets =
                  snapshot.data ?? const <CitizenWalletStateAccount>[];
              return PersonalProposalListSection(
                account: widget.account,
                adminWallets: wallets,
                historyService: widget.historyService,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 管理员列表入口卡片(req 1):点击进入完整管理员列表页。
  Widget _buildAdminEntryCard(AccountInfo? info) {
    final adminsLen = _admins.length;
    final threshold = info?.threshold;
    final subtitle = _isClosed
        ? '已注销'
        : threshold == null
        ? '$adminsLen 人'
        : '$adminsLen 人 · 阈值 $threshold/$adminsLen';

    // 卡片高度对齐 institution_detail_page._buildAdminEntry,
    // 用 InkWell + Padding(14,12) + Row(36×36 icon)而非 ListTile 减少视觉高度。
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: () => _openAdminListPage(info),
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
                  Icons.group_outlined,
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
                      '管理员列表',
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

  Future<void> _openAdminListPage(AccountInfo? info) async {
    if (_admins.isEmpty) {
      await _refreshChainDetail(force: true);
    }
    final wallets = await _getAdminWallets();
    if (!mounted) return;
    final creator = await _resolvePersonalCreatorAccountId();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalAdminListPage(
          account: widget.account,
          multisigStatus: _statusEnumFromLocal(_localStatus),
          admins: _admins,
          adminWallets: wallets,
          creatorAccount: creator,
        ),
      ),
    );
    // 子页可能完成投票 → 精准刷新当前多签状态(可能已激活)。
    if (mounted) await _refreshChainDetail(force: true);
  }

  /// 从本机 Isar 读取个人多签创建者账户 ID。
  /// req 3 未实现时,只有创建者本机有此记录;非创建者打开子页 creator_account 为 null
  /// (届时所有 admin 都按"非创建者"渲染,语义略损但不阻塞主流程)。
  Future<String?> _resolvePersonalCreatorAccountId() async {
    try {
      final entity = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Account>()
            .filter()
            .accountIdEqualTo(widget.account.accountId)
            .findFirst();
      });
      if (entity == null) return null;
      return entity.creatorAccount;
    } catch (_) {
      return null;
    }
  }

  /// 账户余额行(bug 4):
  /// - Active:wallet 持久化 finalized freeFen(无标签)
  /// - Pending:发起人承诺金额(snapshot.amount_fen)+ "不可用" 灰色标签
  Widget _buildBalanceRow(MultisigStatus? status) {
    final balanceStr = _balanceFen == null ? '—' : formatFen(_balanceFen!);
    final isPending = status != MultisigStatus.active;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppLayout.scaledValue(80),
          child: Text(
            '账户余额',
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: AppLayout.scaledValue(8),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                balanceStr,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(13),
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isPending && _balanceFen != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.scaledValue(6),
                    vertical: AppLayout.scaledValue(2),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(4),
                    ),
                  ),
                  child: Text(
                    '不可用',
                    style: TextStyle(
                      fontSize: AppLayout.scaledValue(11),
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    VoidCallback? onCopy,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppLayout.scaledValue(80),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppLayout.scaledValue(13),
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            ),
          ),
        ),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(
              Icons.copy,
              size: AppLayout.scaledValue(16),
              color: AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }

  // ──── 工具 ────
}

/// 个人多签账户状态。
enum MultisigStatus {
  /// 提案投票中，尚未激活。
  pending,

  /// 投票通过、入金完成，已激活。
  active,
}

/// 个人多签账户链上信息。
///
/// 个人状态和管理员来自 `Personal`，动态阈值来自 `InternalVote`。
class AccountInfo {
  const AccountInfo({
    required this.adminsLen,
    required this.threshold,
    required this.admins,
    required this.status,
  });

  final int adminsLen;
  final int? threshold;

  /// 完整管理员人员集合；授权只比较 `account_id`。
  final List<PersonalMember> admins;

  final MultisigStatus status;
}

// 个人转账入口归账户功能。
// 展示多签转账入口并核对管理员钱包后导航。

/// 多签转账入口卡片。
///
/// 转账入口按钮、管理员钱包检查和页面跳转都归 `multisig-transfer`
/// 模块实现，外部页面只负责把当前账户上下文传进来。
class PersonalTransferEntryCard extends StatelessWidget {
  const PersonalTransferEntryCard({
    super.key,
    required this.account,
    required this.enabled,
    required this.loadAdminWallets,
    this.onCreated,
  });

  final PersonalAccountInfo account;
  final bool enabled;
  final Future<List<CitizenWalletStateAccount>> Function() loadAdminWallets;
  final Future<void> Function()? onCreated;

  @override
  Widget build(BuildContext context) {
    final accentColor = enabled ? AppTheme.primaryDark : AppTheme.textTertiary;
    final subtitle = enabled ? '从当前多签账户发起链上转账' : '账户尚未激活,无法发起转账';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: BorderSide(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 14),
              vertical: AppLayout.scaled(context, 12),
            ),
            child: Row(
              children: [
                Container(
                  width: AppLayout.scaled(context, 36),
                  height: AppLayout.scaled(context, 36),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(10),
                    ),
                  ),
                  child: Icon(
                    Icons.send_outlined,
                    size: AppLayout.scaled(context, 18),
                    color: accentColor,
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发起转账',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      SizedBox(height: AppLayout.scaled(context, 2)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppLayout.scaled(context, 20),
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final wallets = await loadAdminWallets();
    if (!context.mounted || wallets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未找到此多签账户的管理员钱包')));
      }
      return;
    }

    final limitService = PersonalProposalLimitService(
      chain: context.read<CitizenSdk>(),
    );
    final activeIds = await limitService.fetchActiveProposalIds(account);
    if (!context.mounted) return;
    if (activeIds.length >= ProposalQueryService.maxActiveProposalsPerSubject) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提案数量已达上限'),
          content: Text(
            '本账户当前有 ${activeIds.length} 个活跃提案，'
            '已达上限 ${ProposalQueryService.maxActiveProposalsPerSubject} 个。'
            '请等待现有提案完成后再发起新提案。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => context.read<PersonalNavigation>().transfer(
          account: account,
          icon: Icons.person,
          badgeColor: AppTheme.accent,
          adminWallets: wallets,
          onCreated: (id) async {
            await PersonalProposalHistoryService(
              chain: context.read<CitizenSdk>(),
            ).fetchAll(account.accountId);
          },
        ),
      ),
    );
    if (created == true && context.mounted) {
      await onCreated?.call();
    }
  }
}
