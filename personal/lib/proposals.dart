// 个人提案入口、详情、投票、上下文和历史聚合。

import 'package:citizen_citizen/proposal/data.dart' show ProposalKind;
import 'package:citizen_multisig/data.dart' show MultisigTransferBalanceGuard;
import 'package:citizen_multisig/data.dart' show TransferProposalInfo;
import 'package:citizen_multisig/service.dart' show MultisigTransferService;
import 'package:citizen_citizen/proposal/store.dart' show ProposalDetailLocalStore, ProposalDetailSnapshot;
import 'package:citizen_citizen/proposal/service.dart' show ProposalLimitService;

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'dart:convert';
import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteService;
import 'package:citizen_citizen/proposal/data.dart' show ProposalRole;
import 'package:citizen_citizen/proposal/data.dart' show EligibleVoterTicket;
import 'package:citizen_citizen/proposal/service.dart' show proposalReadStage, readProposalBlock;
import 'package:citizen_citizen/proposal/vote.dart' show ProposalAdminVoteList, ProposalCardHeader, ProposalStatusBadge, ProposalVoteActions, ProposalVoteProgress;
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_storage/user.dart' as wallet_store;
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_system/log.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_widgets/progress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'accounts.dart';
import 'members.dart';
import 'chain.dart';
import 'storage.dart';

// 个人上下文只持有个人账户及真实可签名钱包。
class PersonalProposalContext {
  const PersonalProposalContext({
    this.account,
    this.adminWallets = const [],
    this.role = ProposalRole.viewer,
  });
  final PersonalAccountInfo? account;
  final List<CitizenWalletStateAccount> adminWallets;
  final ProposalRole role;
  bool get isAdmin => role == ProposalRole.admin;
  bool get hasAdminWallets => adminWallets.isNotEmpty;
}

// 分页展示个人多签活跃及历史提案并提供详情入口。

class PersonalProposalListSection extends StatefulWidget {
  const PersonalProposalListSection({
    super.key,
    required this.account,
    required this.adminWallets,
    this.historyService,
  });

  final PersonalAccountInfo account;
  final List<CitizenWalletStateAccount> adminWallets;
  final PersonalProposalHistoryService? historyService;

  @override
  State<PersonalProposalListSection> createState() =>
      _PersonalProposalListSectionState();
}

class _PersonalProposalListSectionState
    extends State<PersonalProposalListSection> {
  late final PersonalProposalHistoryService _service;
  bool _dependenciesReady = false;

  bool _loading = true;
  List<PersonalAccountProposalView> _items = const [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _service =
        widget.historyService ??
        PersonalProposalHistoryService(chain: context.read<CitizenSdk>());
    _dependenciesReady = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.fetchAll(widget.account.accountId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = list;
    });
  }

  Future<void> _openProposal(PersonalAccountProposalView view) async {
    // 历史(已终态)提案在链上可能已被 90 天清理,详情页以链上为准,
    // 终态后可能拉不到完整数据;但仍允许进入展示已知信息。
    //
    // 按 view.action 分流到对应详情页:
    // - transfer → PersonalTransferDetailPage(个人转账提案详情)
    // - create / close → PersonalProposalDetailPage(多签管理提案,只懂 create/close)
    final ctx = PersonalProposalContext(
      account: widget.account,
      adminWallets: widget.adminWallets,
      role: widget.adminWallets.isEmpty
          ? ProposalRole.viewer
          : ProposalRole.admin,
    );
    final Widget page;
    if (view.actionKind == PersonalProposalAction.transfer) {
      page = PersonalTransferDetailPage(
        account: widget.account,
        proposalId: view.proposalId,
        proposalContext: ctx,
      );
    } else {
      page = PersonalProposalDetailPage(
        account: widget.account,
        proposalId: view.proposalId,
        proposalContext: ctx,
      );
    }
    final pushed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (pushed == true && mounted) {
      // 投票/操作后可能改变了提案状态,重读
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = _items.where((v) => v.isActive).toList();
    final historyItems = _items.where((v) => v.isFinal).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提案列表',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 16),
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        SizedBox(height: AppLayout.scaled(context, 12)),
        if (_loading)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (activeItems.isEmpty && historyItems.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.ballot_outlined,
                  size: AppLayout.scaled(context, 40),
                  color: AppTheme.textTertiary,
                ),
                SizedBox(height: AppLayout.scaled(context, 8)),
                Text(
                  '暂无提案',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 14),
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (activeItems.isNotEmpty) ...[
            _buildSubheader('进行中'),
            ...activeItems.map(
              (v) => Padding(
                padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 8)),
                child: _buildProposalCard(v),
              ),
            ),
          ],
          if (historyItems.isNotEmpty) ...[
            _buildSubheader('历史'),
            ...historyItems.map(
              (v) => Padding(
                padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 8)),
                child: _buildProposalCard(v),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSubheader(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppLayout.scaledValue(8)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.scaledValue(12),
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  /// 提案方块卡片(对齐治理机构详情页 `institution_detail_page._buildProposalCard:520`):
  /// Card with statusColor border(alpha 0.2) + 36×36 statusColor icon container +
  /// 标题/子标题 + 右侧状态徽章。
  Widget _buildProposalCard(PersonalAccountProposalView view) {
    final statusColor = _statusColor(view.proposalState);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _openProposal(view),
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
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: Icon(
                  _actionIcon(view.actionKind),
                  size: AppLayout.scaledValue(18),
                  color: statusColor,
                ),
              ),
              SizedBox(width: AppLayout.scaledValue(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonalProposalHeader(
                      subjectName: widget.account.shortName,
                      proposalNumber: '#${view.proposalId}',
                    ),
                    SizedBox(height: AppLayout.scaledValue(2)),
                    Text(
                      '${_actionLabel(view.actionKind)} · 赞成 ${view.yesCount} · 反对 ${view.noCount}',
                      style: TextStyle(
                        fontSize: AppLayout.scaledValue(12),
                        color: AppTheme.textTertiary,
                      ),
                    ),
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
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaledValue(10),
                  ),
                ),
                child: Text(
                  _statusLabel(view.proposalState),
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(11),
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case PersonalProposalAction.create:
        return '创建提案';
      case PersonalProposalAction.transfer:
        return '转账提案';
      case PersonalProposalAction.close:
        return '关闭提案';
      default:
        return '提案';
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case PersonalProposalAction.create:
        return Icons.fiber_new_outlined;
      case PersonalProposalAction.transfer:
        return Icons.swap_horiz;
      case PersonalProposalAction.close:
        return Icons.close;
      default:
        return Icons.description_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case PersonalProposalStatus.voting:
        return '投票中';
      case PersonalProposalStatus.passed:
        return '已通过';
      case PersonalProposalStatus.rejected:
        return '已拒绝';
      case PersonalProposalStatus.executed:
        return '已执行';
      case PersonalProposalStatus.executionFailed:
        return '执行失败';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case PersonalProposalStatus.voting:
        return AppTheme.primaryDark;
      case PersonalProposalStatus.passed:
      case PersonalProposalStatus.executed:
        return AppTheme.success;
      case PersonalProposalStatus.rejected:
      case PersonalProposalStatus.executionFailed:
        return AppTheme.danger;
      default:
        return AppTheme.textTertiary;
    }
  }
}

// 合并个人多签链上活跃提案与本地终态历史，并持久化业务快照。

// 个人多签提案历史聚合服务(req 5)。
//
// 双轨制数据源:
// 1. 链上 `votingengine.ActiveProposalsBySubject[PersonalAccount(personal_account_id)]`
//    返回当前活跃(STATUS_VOTING)的提案 ID 列表。
// 2. 本机 Isar `action_kind` 永久保留所有历史快照,覆盖
//    链上 90 天后已清理的终态提案。
//
// `fetchAll` 把两条数据合并去重(以 proposal_id 为 key),并把链上活跃提案的
// 最新状态 upsert 到 Isar(同步缓存,防止其他设备发起的提案漏记)。

/// 提案动作类型常量(对齐 Isar entity action_kind 字段)。
class PersonalProposalAction {
  static const String create = 'create';
  static const String transfer = 'transfer';
  static const String close = 'close';
}

/// 提案状态字符串(对齐 votingengine 链上枚举,但用人类可读字符串持久化)。
class PersonalProposalStatus {
  static const String voting = 'voting';
  static const String passed = 'passed';
  static const String rejected = 'rejected';
  static const String executed = 'executed';
  static const String executionFailed = 'execution_failed';
}

/// 链上 votingengine status u8 → Isar 字符串。
String mapChainStatus(int? chainStatus) {
  switch (chainStatus) {
    case 0:
      return PersonalProposalStatus.voting;
    case 1:
      return PersonalProposalStatus.passed;
    case 2:
      return PersonalProposalStatus.rejected;
    case 3:
      return PersonalProposalStatus.executed;
    case 4:
      return PersonalProposalStatus.executionFailed;
    default:
      return PersonalProposalStatus.voting;
  }
}

/// 详情页提案列表渲染所需的视图模型。
class PersonalAccountProposalView {
  const PersonalAccountProposalView({
    required this.proposalId,
    required this.actionKind,
    required this.proposalState,
    required this.yesCount,
    required this.noCount,
    required this.createdAt,
    this.finalAt,
    this.snapshot,
  });

  final BigInt proposalId;
  final String actionKind;
  final String proposalState;
  final int yesCount;
  final int noCount;
  final int createdAt;
  final int? finalAt;
  final Map<String, dynamic>? snapshot;

  bool get isActive => proposalState == PersonalProposalStatus.voting;
  bool get isFinal => !isActive;
}

class PersonalProposalHistoryService {
  PersonalProposalHistoryService({
    CitizenSdk? chain,
    PersonalProposalQueryService? proposalService,
    Future<CitizenChainSyncStatus> Function()? getSyncStatus,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _proposalService =
           proposalService ??
           PersonalProposalQueryService(
             chain: chain,
             getFinalizedHead: getFinalizedHead,
             getStorage: getStorage,
             getSystemEvents: getSystemEvents,
             getRuntimeContext: getRuntimeContext,
             getStorageBatch: getStorageBatch,
           ),
       _getSyncStatus =
           getSyncStatus ??
           chain?.getSyncStatus ??
           (() => throw StateError('未配置getSyncStatus'));
  final Future<CitizenChainSyncStatus> Function() _getSyncStatus;

  final PersonalProposalQueryService _proposalService;

  /// 拉取该多签的全部提案(活跃 + 历史),按 created_at desc 排序。
  ///
  /// 容错:链上失败仅回退 Isar;Isar 失败仅回退链上;两者都失败返回空列表。
  ///
  /// 状态新鲜度策略:
  /// 1. 链上 ActiveProposalsBySubject 同步活跃提案到 Isar(防其他设备漏记)
  /// 2. **额外**:遍历 Isar 中本机已知 status='voting' 的 entity,挨个查链上
  ///    Proposals[id] 拿最新 status + tally。这步必须独立于 active 列表,
  ///    因为提案一旦终态(passed/executed/rejected)就从 active 列表移除,
  ///    本机 Isar 永远停在 voting 状态,UI 卡片显示"投票中"是假数据。
  Future<List<PersonalAccountProposalView>> fetchAll(String accountId) async {
    final activeIds = await _safeFetchActiveProposalIds(accountId);

    // 链可达性正向探针:只有确认链已同步可达时,才允许把「链上查不到」判为幽灵
    // 并清理本机记录;离线/未同步一律保留本机 Isar 历史(容错回退→仅返回 Isar)。
    final chainReachable = (await _getSyncStatus()).isUsable;

    // Step 1: 链上活跃提案逐个同步到 Isar(防止其他设备发起的提案在本机无记录)。
    for (final pid in activeIds) {
      await _syncActiveProposalToIsar(accountId, pid);
    }

    // Step 2: 重查本机 Isar 中 status='voting' 的 entity,即使它们已不在 active 列表
    // (提案终态后就从 active 列表移除,但本机 entity 还停在 voting)。
    await _refreshLocalVotingEntities(accountId, chainReachable);

    return _readAllFromIsar(accountId);
  }

  /// 判断本机是否存在“创建提案仍是 voting，但链上 Proposals[id] 从未存在”的快照。
  ///
  /// 这类记录通常来自旧版本把 tx_hash 当成功后提前落库；它不是
  /// 正常注销历史，列表页可据此删除本地幽灵多签。
  Future<bool> hasUnchainedVotingCreateProposal(String accountId) async {
    try {
      // 离线/未同步无法确认提案是否真在链上,一律不判幽灵,避免误删本机记录。
      if (!(await _getSyncStatus()).isUsable) return false;
      final entities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .actionKindEqualTo(PersonalProposalAction.create)
            .proposalStateEqualTo(PersonalProposalStatus.voting)
            .findAll();
      });
      for (final e in entities) {
        final chainStatus = await _proposalService.fetchProposalStatus(
          e.proposalId,
        );
        if (chainStatus == null) return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// 遍历本机 Isar 中所有 status='voting' 的 entity,查链上 `Proposals[id]` 拿最新状态。
  /// 链上若已终态(passed/executed/rejected/execution_failed),upsert 为终态;
  /// 链上仍 voting 则只刷新 yes_count/no_count;链上 storage 不存在(已被 90 天清理)
  /// 也只刷新 vote tally(取现有值)— 不强制覆盖为终态,等本机其他渠道写入历史。
  Future<void> _refreshLocalVotingEntities(
    String accountId,
    bool chainReachable,
  ) async {
    try {
      final votingEntities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .proposalStateEqualTo(PersonalProposalStatus.voting)
            .findAll();
      });

      for (final e in votingEntities) {
        try {
          final chainStatus = await _proposalService.fetchProposalStatus(
            e.proposalId,
          );
          if (chainStatus == null) {
            // 仅当链确认可达却查不到该提案时,才判为「本机幽灵创建提案」并清理;
            // 离线/未同步则保留本机记录,避免误删待投票提案(数据丢失)。
            if (chainReachable &&
                e.actionKind == PersonalProposalAction.create) {
              await _deleteProposalEntity(
                accountId: accountId,
                proposalId: e.proposalId,
              );
            }
            continue;
          }
          final tally = await _proposalService.fetchVoteTally(e.proposalId);
          await recordOrUpdate(
            accountId: accountId,
            proposalId: e.proposalId,
            actionKind: e.actionKind,
            status: mapChainStatus(chainStatus),
            yesCount: tally.yes,
            noCount: tally.no,
          );
        } catch (_) {
          // 单条刷新失败不阻断其他 entity
        }
      }
    } catch (_) {
      // 整个刷新失败也不阻断主流程
    }
  }

  Future<void> _deleteProposalEntity({
    required String accountId,
    required BigInt proposalId,
  }) async {
    await UserIsar.instance.writeTxn((isar) async {
      await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .proposalIdTextEqualTo(proposalId.toString())
          .deleteAll();
    });
  }

  /// 写入或更新 Isar 提案 entity。
  ///
  /// [snapshot] 若非空将以 JSON 形式持久化(转账金额 / beneficiary / account_name 等)。
  Future<void> recordOrUpdate({
    required String accountId,
    required BigInt proposalId,
    required String actionKind,
    required String status,
    required int yesCount,
    required int noCount,
    Map<String, dynamic>? snapshot,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await UserIsar.instance.writeTxn((isar) async {
      final existing = await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .proposalIdTextEqualTo(proposalId.toString())
          .findFirst();

      final isFinal = status != PersonalProposalStatus.voting;

      final entity = existing ?? wallet_store.Action()
        ..accountId = accountId
        ..proposalId = proposalId
        ..createdAt = existing?.createdAt ?? now;

      entity.actionKind = actionKind;
      entity.proposalState = status;
      entity.yesCount = yesCount;
      entity.noCount = noCount;
      entity.finalAt = isFinal ? (existing?.finalAt ?? now) : null;
      if (snapshot != null) {
        entity.snapshotData = jsonEncode(snapshot);
      } else if (existing != null) {
        entity.snapshotData = existing.snapshotData;
      }

      await isar.collection<wallet_store.Action>().put(entity);
    });
  }

  // ──── 内部 ─────────────────────────────────────────────

  Future<List<BigInt>> _safeFetchActiveProposalIds(String accountId) async {
    try {
      return await _proposalService.fetchActivePersonalProposalIds(accountId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _syncActiveProposalToIsar(
    String accountId,
    BigInt proposalId,
  ) async {
    try {
      final chainStatus = await _proposalService.fetchProposalStatus(
        proposalId,
      );
      final tally = await _proposalService.fetchVoteTally(proposalId);
      final statusStr = mapChainStatus(chainStatus);

      final existing = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .proposalIdTextEqualTo(proposalId.toString())
            .findFirst();
      });

      // 本机已有记录沿用其真实动作；首次发现则必须从当前链上
      // ProposalData 严格识别，禁止把缺失/未知载荷伪装成 create。
      String? actionKind = existing?.actionKind;
      if (existing == null) {
        final raw = await _fetchProposalDataRaw(proposalId);
        if (raw == null) return;
        actionKind = _decodeActionFromProposalData(raw);
        if (actionKind == null) return;
      }

      await recordOrUpdate(
        accountId: accountId,
        proposalId: proposalId,
        actionKind: actionKind!,
        status: statusStr,
        yesCount: tally.yes,
        noCount: tally.no,
      );
    } catch (_) {
      // 单条同步失败不阻断其他提案同步。
    }
  }

  /// 从链上 `VotingEngine.ProposalData[id]` 原始字节解码 `PersonalProposalAction`。
  ///
  /// ProposalData 是 `BoundedVec<u8>:Compact<len> + bytes`。
  ///
  /// 个人多签提案能命中的映射:
  /// - per-mgmt + 0 → create (Personal::propose_create)
  /// - per-mgmt + 1 → close  (Personal::propose_close)
  /// - multisig → transfer (Multisig::propose_transfer)
  /// 个人多签不会触发 safety_fund/sweep,无需识别。
  String? _decodeActionFromProposalData(Uint8List raw) {
    try {
      final (length, lenSize) = _decodeCompact(raw, 0);
      if (lenSize + length != raw.length) return null;
      final data = Uint8List.sublistView(raw, lenSize);

      // per-mgmt = b"per-mgmt" 8 字节，后接 action_kind byte。
      const perMgmt = [0x70, 0x65, 0x72, 0x2d, 0x6d, 0x67, 0x6d, 0x74];
      if (_startsWithAt(data, perMgmt, 0)) {
        if (perMgmt.length >= data.length) return null;
        final actionKind = data[perMgmt.length];
        if (actionKind == 0) return PersonalProposalAction.create;
        if (actionKind == 1) return PersonalProposalAction.close;
        return null;
      }

      // 当前 multisig ProposalData 不含 action_kind byte；tag 本身唯一表示转账。
      final multisig = 'multisig'.codeUnits;
      if (_startsWithAt(data, multisig, 0) &&
          data.length >= multisig.length + 1 + 32 + 32 + 16 + 1 + 32 &&
          (data[multisig.length] == 0 || data[multisig.length] == 1)) {
        return PersonalProposalAction.transfer;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 测试入口：锁定当前投票引擎 ProposalData 模块标签。
  @visibleForTesting
  String? debugDecodeActionFromProposalData(Uint8List raw) {
    return _decodeActionFromProposalData(raw);
  }

  bool _startsWithAt(Uint8List data, List<int> prefix, int offset) {
    if (offset + prefix.length > data.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  /// 读取 `VotingEngine.ProposalData[id]` 原始字节(`BoundedVec<u8>` SCALE 编码)。
  Future<Uint8List?> _fetchProposalDataRaw(BigInt proposalId) async {
    try {
      return await _proposalService.fetchProposalData(proposalId);
    } catch (_) {
      return null;
    }
  }

  Future<List<PersonalAccountProposalView>> _readAllFromIsar(
    String accountId,
  ) async {
    try {
      final entities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .sortByCreatedAtDesc()
            .findAll();
      });
      return entities.map(_entityToView).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  PersonalAccountProposalView _entityToView(wallet_store.Action e) {
    Map<String, dynamic>? snapshot;
    if (e.snapshotData != null && e.snapshotData!.isNotEmpty) {
      try {
        snapshot = jsonDecode(e.snapshotData!) as Map<String, dynamic>;
      } catch (_) {
        snapshot = null;
      }
    }
    return PersonalAccountProposalView(
      proposalId: e.proposalId,
      actionKind: e.actionKind,
      proposalState: e.proposalState,
      yesCount: e.yesCount,
      noCount: e.noCount,
      createdAt: e.createdAt,
      finalAt: e.finalAt,
      snapshot: snapshot,
    );
  }

  (int, int) _decodeCompact(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('Compact<u32>长度超出范围');
    return result;
  }
}

// 定义个人多签创建、关闭提案及账户生命周期模型。

/// Personal 创建个人多签提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`per-mgmt` + ACTION_CREATE=0 之后）：
///   account_id: AccountId32(32) + proposer_account_id: AccountId32(32)
///   + amount: u128(16) + fee: u128(16)。
class CreateProposalInfo {
  const CreateProposalInfo({
    required this.proposalId,
    required this.accountId,
    required this.proposerSs58Address,
    required this.amountFen,
    required this.feeAmount,
    this.status,
  });

  final BigInt proposalId;

  /// 个人多签账户 ID（小写 `0x` + 64 位 hex）。
  final String accountId;

  /// 发起人 SS58 地址。
  final String proposerSs58Address;

  /// 初始资金（分）。
  final BigInt amountFen;

  /// 创建手续费快照（分）。
  final BigInt feeAmount;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

  CreateProposalInfo copyWithStatus(int? newStatus) {
    return CreateProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      proposerSs58Address: proposerSs58Address,
      amountFen: amountFen,
      feeAmount: feeAmount,
      status: newStatus,
    );
  }
}

/// Personal 关闭个人多签提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`per-mgmt` + ACTION_CLOSE=1 之后）：
///   account_id: AccountId32(32) + beneficiary_account_id: AccountId32(32)
///   + proposer_account_id: AccountId32(32)。
class CloseProposalInfo {
  const CloseProposalInfo({
    required this.proposalId,
    required this.accountId,
    required this.beneficiarySs58Address,
    required this.proposerSs58Address,
    this.status,
  });

  final BigInt proposalId;

  /// 个人多签账户 ID（小写 `0x` + 64 位 hex）。
  final String accountId;

  /// 受益人 SS58 地址。
  final String beneficiarySs58Address;

  /// 发起人 SS58 地址。
  final String proposerSs58Address;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

  CloseProposalInfo copyWithStatus(int? newStatus) {
    return CloseProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      beneficiarySs58Address: beneficiarySs58Address,
      proposerSs58Address: proposerSs58Address,
      status: newStatus,
    );
  }
}

// 个人创建与注销提案详情。
// 展示多签账户管理提案详情、计票和当前可用投票动作。

/// 多签管理提案详情页：展示创建/关闭提案信息、投票进度及投票操作。
class PersonalProposalDetailPage extends StatefulWidget {
  const PersonalProposalDetailPage({
    super.key,
    required this.account,
    required this.proposalId,
    required this.proposalContext,
    this.resolveVoteContext,
  });

  final PersonalAccountInfo account;
  final BigInt proposalId;
  final PersonalProposalContext proposalContext;
  final Future<PersonalProposalContext> Function()? resolveVoteContext;

  List<CitizenWalletStateAccount> get adminWallets =>
      proposalContext.adminWallets;

  @override
  State<PersonalProposalDetailPage> createState() =>
      _PersonalProposalDetailPageState();
}

class _PersonalProposalDetailPageState
    extends State<PersonalProposalDetailPage> {
  static const int _statusVoting = 0;

  PersonalProposalContext? _verifiedVoteContext;
  PersonalProposalContext get _proposalContext =>
      _verifiedVoteContext ?? widget.proposalContext;
  List<CitizenWalletStateAccount> get _voteWallets =>
      _proposalContext.adminWallets;
  StreamSubscription<Set<BigInt>>? _localUpdates;
  bool _preparingVote = false;

  Future<void> _readLocalDetail() async {
    final snapshot = await _applyLocalSnapshot();
    if (!mounted || snapshot != null) return;
    setState(() {
      _loading = false;
      _error = '该提案的本机记录已不可用';
    });
  }

  final ProposalDetailLocalStore _detailStore =
      ProposalDetailLocalStore.instance;
  late final PersonalManageService _personalManageService;
  late final PersonalMemberService _adminService;
  bool _dependenciesReady = false;
  int _generation = 0;
  Future<void>? _loadFlight;
  final Completer<void> _closed = Completer<void>();
  bool _ticketsReady = false;
  bool _hasDetails = false;
  bool _isCurrent(int generation) => mounted && generation == _generation;

  PersonalMemberIdentity get _accountIdentity =>
      PersonalMemberIdentity.fromAccount(widget.account);
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  int? _status;

  // 提案详情（二选一）
  CreateProposalInfo? _createInfo;
  CloseProposalInfo? _closeInfo;

  bool get _isCreateProposal => _createInfo != null;

  // 投票计数
  int _yesCount = 0;
  int _noCount = 0;
  int _threshold = 0;

  // 提案创建时冻结的成员钱包与投票记录。
  List<String> _admins = const [];
  Map<String, bool?> _adminVotes = {};
  List<EligibleVoterTicket> _voterTickets = const [];

  List<CitizenWalletStateAccount> _votableWallets = const [];
  CitizenWalletStateAccount? _selectedVoteWallet;
  String? _voteNotice;
  bool _voteNoticeIsError = false;

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
    _adminService = PersonalMemberService(chain: sdk);
    _dependenciesReady = true;
    if (widget.resolveVoteContext == null) {
      _load();
    } else {
      _localUpdates = _detailStore.changes.listen((ids) {
        if (ids.contains(widget.proposalId) &&
            mounted &&
            !_submitting &&
            !_preparingVote) {
          _verifiedVoteContext = null;
          unawaited(_readLocalDetail());
        }
      });
      unawaited(_readLocalDetail());
    }
  }

  @override
  void dispose() {
    unawaited(_localUpdates?.cancel());
    ++_generation;
    _closed.complete();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) {
    final pending = _loadFlight;
    if (pending != null) return pending;
    final generation = ++_generation;
    late final Future<void> task;
    task = _readDetails(generation, showSpinner: showSpinner).whenComplete(() {
      if (identical(_loadFlight, task)) _loadFlight = null;
    });
    _loadFlight = task;
    return task;
  }

  Future<void> _readDetails(int generation, {required bool showSpinner}) async {
    if (!_isCurrent(generation)) return;
    setState(() => _ticketsReady = false);

    AppLog.d('[VoteDetail._load] 开始 proposalId=${widget.proposalId}');
    ProposalDetailSnapshot? localSnapshot;
    if (showSpinner) {
      localSnapshot = await _applyLocalSnapshot();
    }
    if (!_isCurrent(generation)) return;
    // 本地详情仅展示，投票资格必须重新核对链上冻结成员快照；
    // 即使缓存新鲜也继续读取链上 VotePlan/VoterSnapshot。

    if (showSpinner && localSnapshot == null && !_hasDetails) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }

    try {
      if (!mounted) {
        return;
      }
      final sdk = context.read<CitizenSdk>();
      final block = await readProposalBlock(sdk, _closed.future);
      if (block == null || !_isCurrent(generation)) return;
      final reads = PersonalProposalQueryService(chain: sdk, block: block);
      // step1:并行加载合格选民快照、提案状态、投票计数、阈值快照。
      // 个人资格只来自冻结成员快照；缺失或损坏
      // 必须失败，禁止回落到当前 admins。
      AppLog.d(
        '[VoteDetail._load] step1: 并行 fetchSnapshot/Status/Tally/Threshold...',
      );
      final results = await Future.wait([
        proposalReadStage(
          'proposal_snapshot',
          () => PersonalProposalQueryService(
            chain: sdk,
            block: block,
          ).fetchPersonalVoterTickets(widget.proposalId, widget.account),
        ),
        proposalReadStage(
          'proposal_status',
          () => reads.fetchProposalStatus(widget.proposalId),
        ),
        proposalReadStage(
          'proposal_tally',
          () => reads.fetchVoteTally(widget.proposalId),
        ),
        proposalReadStage(
          'proposal_threshold',
          () => reads.fetchInternalThresholdSnapshot(widget.proposalId),
        ),
      ]);

      final voterTickets = results[0] as List<EligibleVoterTicket>;
      final admins = voterTickets
          .map((ticket) => _requireAccountId(ticket.voterAccountId))
          .toSet()
          .toList();
      final status = results[1] as int?;
      final tally = results[2] as ({int yes, int no});
      final thresholdSnapshot = results[3] as int?;
      final threshold = _resolveVoteThreshold(
        thresholdSnapshot,
        voterTickets.length,
      );
      AppLog.d(
        '[VoteDetail._load] step1 完成 admins.len=${admins.length} status=$status yes=${tally.yes} no=${tally.no} threshold=$threshold',
      );

      final browseLocal = widget.resolveVoteContext != null;
      final raw = browseLocal
          ? null
          : await proposalReadStage(
              'proposal_details',
              () => reads.fetchProposalData(widget.proposalId),
            );
      var createInfo = browseLocal ? _createInfo : null;
      var closeInfo = browseLocal ? _closeInfo : null;
      if (raw != null && raw.isNotEmpty) {
        final personalDetail = _personalManageService
            .decodePersonalProposalData(widget.proposalId, raw);
        if (personalDetail is CreateProposalInfo) {
          createInfo = personalDetail;
        } else if (personalDetail is CloseProposalInfo) {
          closeInfo = personalDetail;
        }
      }

      // step3:批量查询每张快照票据的投票记录，避免逐条 RPC。
      AppLog.d(
        '[VoteDetail._load] step3: 批量查冻结钱包票据 (${voterTickets.length} 张)',
      );
      final votes = await proposalReadStage(
        'proposal_votes',
        () => reads.fetchTicketVotesBatch(widget.proposalId, voterTickets),
      );
      AppLog.d('[VoteDetail._load] step3 完成');

      // 筛选可投票钱包
      final votable = <CitizenWalletStateAccount>[];
      for (final w in _voteWallets) {
        final accountId = _requireAccountId(w.accountId);
        final walletTickets = voterTickets.where(
          (ticket) => _requireAccountId(ticket.voterAccountId) == accountId,
        );
        if (walletTickets.any((ticket) => votes[ticket.ticketKey] == null)) {
          votable.add(w);
        }
      }

      if (!_isCurrent(generation)) {
        AppLog.d('[VoteDetail._load] !mounted 提前返回');
        return;
      }
      if (widget.resolveVoteContext == null) {
        try {
          await _detailStore.put(
            _snapshotFromChain(
              status: status,
              tally: tally,
              threshold: threshold,
              admins: admins,
              votes: votes,
              createInfo: createInfo,
              closeInfo: closeInfo,
            ),
          );
        } catch (_) {
          // 详情快照只是首屏加速，写入失败不能影响链上结果展示。
        }
      }
      if (!_isCurrent(generation)) return;
      AppLog.d('[VoteDetail._load] step5: setState');
      setState(() {
        _admins = admins;
        _status = status;
        _yesCount = tally.yes;
        _noCount = tally.no;
        _threshold = threshold;
        _adminVotes = votes;
        _voterTickets = voterTickets;
        _votableWallets = votable;
        _selectedVoteWallet = votable.isNotEmpty ? votable.first : null;
        _createInfo = createInfo;
        _closeInfo = closeInfo;
        _loading = false;
        _error = null;
        _ticketsReady = true;
        _hasDetails = true;
      });
      AppLog.d('[VoteDetail._load] 结束');
    } on Object catch (error) {
      AppLog.proposalFailure(stage: 'proposal_display', error: error);
      if (!_isCurrent(generation)) return;
      if (widget.resolveVoteContext != null) rethrow;
      setState(() {
        _ticketsReady = false;
        _loading = false;
        if (!_hasDetails) _error = '提案链状态暂时不可用';
      });
    }
  }

  Future<ProposalDetailSnapshot?> _applyLocalSnapshot() async {
    try {
      final snapshot = await _detailStore.read('personal', widget.proposalId);
      if (snapshot == null || !mounted) return snapshot;
      final admins = snapshot.admins;
      final votable = <CitizenWalletStateAccount>[];
      for (final w in _voteWallets) {
        final accountId = _requireAccountId(w.accountId);
        if (admins.contains(accountId) &&
            snapshot.adminVotes[accountId] == null) {
          votable.add(w);
        }
      }
      final createInfo = _createInfoFromSnapshot(snapshot);
      final closeInfo = _closeInfoFromSnapshot(snapshot);
      if (createInfo == null && closeInfo == null) {
        return null;
      }
      setState(() {
        _hasDetails = true;
        _admins = admins;
        _status = snapshot.status;
        _yesCount = snapshot.yesCount;
        _noCount = snapshot.noCount;
        _threshold = snapshot.threshold ?? 0;
        _adminVotes = snapshot.adminVotes;
        if (widget.resolveVoteContext != null) {
          _voterTickets = snapshot.voterTickets;
        }
        _votableWallets = votable;
        _selectedVoteWallet = votable.isNotEmpty ? votable.first : null;
        _createInfo = createInfo;
        _closeInfo = closeInfo;
        _loading = false;
        _error = null;
      });
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  ProposalDetailSnapshot _snapshotFromChain({
    required int? status,
    required ({int yes, int no}) tally,
    required int threshold,
    required List<String> admins,
    required Map<String, bool?> votes,
    required CreateProposalInfo? createInfo,
    required CloseProposalInfo? closeInfo,
  }) {
    return ProposalDetailSnapshot(
      proposalId: widget.proposalId,
      proposalKind: 'personal',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: status,
      yesCount: tally.yes,
      noCount: tally.no,
      threshold: threshold,
      admins: admins.map(_requireAccountId).toList(growable: false),
      // 按冻结个人钱包票据的原键保存投票。
      adminVotes: Map.of(votes),
      pendingPublicKeys: const [],
      detail: createInfo != null
          ? _createInfoToJson(createInfo)
          : closeInfo != null
          ? _closeInfoToJson(closeInfo)
          : const {},
    );
  }

  Map<String, Object?> _createInfoToJson(CreateProposalInfo info) {
    return {
      'kind': 'create',
      'account_id': info.accountId,
      'proposer_ss58_address': info.proposerSs58Address,
      'amount_fen': info.amountFen.toString(),
      'fee_fen': info.feeAmount.toString(),
      'status': info.status,
    };
  }

  Map<String, Object?> _closeInfoToJson(CloseProposalInfo info) {
    return {
      'kind': 'close',
      'account_id': info.accountId,
      'beneficiary_ss58_address': info.beneficiarySs58Address,
      'proposer_ss58_address': info.proposerSs58Address,
      'status': info.status,
    };
  }

  CreateProposalInfo? _createInfoFromSnapshot(ProposalDetailSnapshot snapshot) {
    final detail = snapshot.detail;
    if (detail['kind'] != 'create') return null;
    final amountFen = BigInt.tryParse(detail['amount_fen']?.toString() ?? '');
    final feeAmount = BigInt.tryParse(detail['fee_fen']?.toString() ?? '');
    final accountId = detail['account_id']?.toString();
    if (amountFen == null || feeAmount == null || accountId == null) {
      return null;
    }
    return CreateProposalInfo(
      proposalId: snapshot.proposalId,
      accountId: accountId,
      proposerSs58Address: detail['proposer_ss58_address']?.toString() ?? '',
      amountFen: amountFen,
      feeAmount: feeAmount,
      status: snapshot.status,
    );
  }

  CloseProposalInfo? _closeInfoFromSnapshot(ProposalDetailSnapshot snapshot) {
    final detail = snapshot.detail;
    if (detail['kind'] != 'close') return null;
    final accountId = detail['account_id']?.toString();
    if (accountId == null) return null;
    return CloseProposalInfo(
      proposalId: snapshot.proposalId,
      accountId: accountId,
      beneficiarySs58Address:
          detail['beneficiary_ss58_address']?.toString() ?? '',
      proposerSs58Address: detail['proposer_ss58_address']?.toString() ?? '',
      status: snapshot.status,
    );
  }

  // ──── 工具方法 ────

  String _truncateAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  int _resolveVoteThreshold(int? snapshotThreshold, int adminsLen) {
    if (snapshotThreshold != null && snapshotThreshold > 0) {
      return snapshotThreshold;
    }
    final configuredThreshold = widget.account.internalThreshold;
    if (configuredThreshold > 0) return configuredThreshold;
    return adminsLen;
  }

  // ──── 投票提交 ────

  bool get _isCurrentUserAdmin => _proposalContext.isAdmin;

  bool get _canVote {
    if (!_ticketsReady) return false;
    if (_selectedVoteWallet == null) return false;
    if (_status != _statusVoting) return false;
    return _votableWallets.isNotEmpty;
  }

  bool get _allVoted {
    if (!_ticketsReady) return false;
    if (_voteWallets.isEmpty) return false;
    for (final w in _voteWallets) {
      final accountId = _requireAccountId(w.accountId);
      final tickets = _voterTickets.where(
        (ticket) => _requireAccountId(ticket.voterAccountId) == accountId,
      );
      if (tickets.any((ticket) => _adminVotes[ticket.ticketKey] == null)) {
        return false;
      }
    }
    return true;
  }

  Future<EligibleVoterTicket?> _selectTicket(
    List<EligibleVoterTicket> tickets,
  ) async {
    if (tickets.length == 1) return tickets.single;
    return showDialog<EligibleVoterTicket>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择本次投票岗位'),
        children: tickets
            .map(
              (ticket) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, ticket),
                child: Text(ticket.voterRoleCode ?? '个人多签管理员'),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _submitVote(bool approve) async {
    if (!_ticketsReady) return;
    AppLog.d(
      '[VoteDetail] _submitVote 开始 approve=$approve proposalId=${widget.proposalId}',
    );
    final wallet = _selectedVoteWallet;
    if (wallet == null) {
      AppLog.d('[VoteDetail] _submitVote 无可投钱包,直接 return');
      return;
    }
    AppLog.d(
      '[VoteDetail] 选中钱包 ${wallet.ss58Address} accountId=${wallet.accountId} isHot=${wallet.signMode == CitizenWalletSignMode.hot}',
    );

    setState(() => _submitting = true);

    try {
      final signerPublicKeyBytes = citizenAccountIdBytes(wallet.accountId);
      final accountId = _requireAccountId(wallet.accountId);
      final availableTickets = _voterTickets
          .where(
            (ticket) =>
                _requireAccountId(ticket.voterAccountId) == accountId &&
                _adminVotes[ticket.ticketKey] == null,
          )
          .toList(growable: false);
      if (availableTickets.isEmpty) {
        throw StateError('当前钱包不在该提案的合格选民快照中，不能投票');
      }
      final ticket = await _selectTicket(availableTickets);
      if (ticket == null) throw StateError('已取消选择投票岗位');
      if (!mounted) return;
      final sdk = context.read<CitizenSdk>();
      final balance = await sdk.getAccountBalance(
        accountId,
        forceRefresh: true,
      );
      if (balance.freeFen <= BigInt.zero) {
        throw StateError('当前投票钱包余额不足，无法支付链上投票手续费');
      }

      // 创建/关闭多签的投票都走 InternalVote::cast(20.0),
      // 由 runtime 的 InternalVoteExecutor 按 MODULE_TAG+ACTION 分派。
      AppLog.d('[VoteDetail] 调 InternalVoteService.submit');
      final result = await InternalVoteService(chain: sdk, transactions: sdk)
          .submit(
            proposalId: widget.proposalId,
            approve: approve,
            actorCidNumber: null,
            voterRoleCode: null,
            signerPublicKey: Uint8List.fromList(signerPublicKeyBytes),
            externalSigning: (pending) => showCitizenSdkQrResponse(
              context,
              request: pending.qrRequest,
              expiresAt: BigInt.from(
                pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          );
      AppLog.d(
        '[VoteDetail] submit 已入块 txHash=${result.txHash} nonce=${result.usedNonce} block=${result.blockHash}',
      );

      if (!mounted) return;
      setState(() {
        _adminVotes[ticket.ticketKey] = approve;
        _votableWallets = _votableWallets
            .where((w) {
              final accountId = _requireAccountId(w.accountId);
              return _voterTickets.any(
                (candidate) =>
                    _requireAccountId(candidate.voterAccountId) == accountId &&
                    _adminVotes[candidate.ticketKey] == null,
              );
            })
            .toList(growable: false);
        _selectedVoteWallet = _votableWallets.isNotEmpty
            ? _votableWallets.first
            : null;
        _voteNotice = '链上已确认该合格选民投票。';
        _voteNoticeIsError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('投票已由 runtime 确认：${_truncateAddress(result.txHash)}'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );

      _adminService.clearCache(_accountIdentity);
      if (widget.resolveVoteContext == null) {
        unawaited(_load());
      }
    } catch (e, st) {
      AppLog.d('[VoteDetail] _submitVote catch 异常: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投票失败：$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      AppLog.d('[VoteDetail] finally setState(_submitting=false)');
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _requireAccountId(String? accountId) {
    if (accountId == null || !isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  Future<void> _confirmVote(bool approve) async {
    final resolve = widget.resolveVoteContext;
    if (_preparingVote || _submitting) return;
    if (resolve != null) setState(() => _preparingVote = true);
    try {
      if (resolve != null) {
        final verified = await resolve();
        if (!mounted) return;
        if (!verified.isAdmin) throw StateError('当前钱包没有投票资格');
        _verifiedVoteContext = verified;
        await _load(showSpinner: false);
        if (!mounted) return;
        if (_error != null || !(_isCurrentUserAdmin && _canVote)) {
          throw StateError(_error ?? '提案已停止投票或当前钱包没有未使用的投票票据');
        }
      }
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      final label = approve ? '赞成' : '反对';
      final choices = resolve != null && _votableWallets.length > 1
          ? _votableWallets
          : const <CitizenWalletStateAccount>[];
      var selected = _selectedVoteWallet;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, updateDialog) {
            return AlertDialog(
              title: Text('确认$label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确定要对此提案投"$label"票吗？投票后不可更改。'),
                  if (choices.isNotEmpty)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: selected?.walletIndex,
                      items: [
                        for (final wallet in choices)
                          DropdownMenuItem(
                            value: wallet.walletIndex,
                            child: Text(
                              wallet.ss58Address,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (index) => updateDialog(() {
                        selected = choices.firstWhere(
                          (wallet) => wallet.walletIndex == index,
                        );
                      }),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(label),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || confirmed != true) return;
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      _selectedVoteWallet = selected;
      await _submitVote(approve);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('投票校验未通过：$error')));
      }
    } finally {
      if (resolve != null && mounted) {
        _verifiedVoteContext = null;
        _ticketsReady = false;
        await _readLocalDetail();
        if (mounted) setState(() => _preparingVote = false);
      }
    }
  }
  // ──── 构建 UI ────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '提案详情',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
      bottomNavigationBar:
          !_loading &&
              _error == null &&
              _status == _statusVoting &&
              (widget.resolveVoteContext != null || _isCurrentUserAdmin)
          ? ProposalVoteActions(
              votableWallets: _votableWallets,
              selectedWallet: _selectedVoteWallet,
              submitting: _submitting || _preparingVote,
              canVote: widget.resolveVoteContext != null || _canVote,
              allVoted: _allVoted,
              onWalletChanged: (w) => setState(() => _selectedVoteWallet = w),
              onVote: _confirmVote,
            )
          : null,
    );
  }

  Widget _buildError() {
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
            OutlinedButton(
              onPressed: widget.resolveVoteContext == null
                  ? _load
                  : _readLocalDetail,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        _adminService.clearCache(_accountIdentity);
        if (widget.resolveVoteContext == null) {
          await _load();
        } else {
          await _readLocalDetail();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ProposalStatusBadge(status: _status, proposalId: widget.proposalId),
          if (_voteNotice != null) ...[
            SizedBox(height: AppLayout.scaledValue(12)),
            _buildVoteNotice(),
          ],
          SizedBox(height: AppLayout.scaledValue(16)),
          _buildProposalInfoCard(),
          SizedBox(height: AppLayout.scaledValue(16)),
          ProposalVoteProgress(
            yesCount: _yesCount,
            noCount: _noCount,
            threshold: _threshold,
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          ProposalAdminVoteList(
            admins: _admins,
            voterTickets: _voterTickets,
            adminVotes: _adminVotes,
            pendingPublicKeys: const {},
          ),
        ],
      ),
    );
  }

  Widget _buildVoteNotice() {
    final color = _voteNoticeIsError ? AppTheme.danger : AppTheme.info;
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(12)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _voteNoticeIsError ? Icons.error_outline : Icons.info_outline,
            size: AppLayout.scaledValue(18),
            color: color,
          ),
          SizedBox(width: AppLayout.scaledValue(8)),
          Expanded(
            child: Text(
              _voteNotice!,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalInfoCard() {
    return Card(
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
              _isCreateProposal ? '创建多签提案信息' : '关闭多签提案信息',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            if (_createInfo != null) ..._buildCreateInfoRows(),
            if (_closeInfo != null) ..._buildCloseInfoRows(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCreateInfoRows() {
    final info = _createInfo!;
    final accountSs58 = citizenSs58FromAccountId(info.accountId);
    return [
      _buildInfoRow(
        '多签账户',
        _truncateAddress(accountSs58),
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
      Divider(height: AppLayout.scaledValue(20)),
      _buildInfoRow('发起人', _truncateAddress(info.proposerSs58Address)),
      Divider(height: AppLayout.scaledValue(20)),
      _buildInfoRow('初始资金', '${formatFen(info.amountFen)} 元'),
      Divider(height: AppLayout.scaledValue(20)),
      _buildInfoRow('创建手续费', '${formatFen(info.feeAmount)} 元'),
    ];
  }

  List<Widget> _buildCloseInfoRows() {
    final info = _closeInfo!;
    final accountSs58 = citizenSs58FromAccountId(info.accountId);
    return [
      _buildInfoRow(
        '多签账户',
        _truncateAddress(accountSs58),
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
      Divider(height: AppLayout.scaledValue(20)),
      _buildInfoRow(
        '受益人',
        _truncateAddress(info.beneficiarySs58Address),
        onCopy: () {
          Clipboard.setData(ClipboardData(text: info.beneficiarySs58Address));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('地址已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      Divider(height: AppLayout.scaledValue(20)),
      _buildInfoRow('发起人', _truncateAddress(info.proposerSs58Address)),
    ];
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onCopy}) {
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
              color: AppTheme.textPrimary,
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

// 个人转账提案的展示与投票归本包。
/// 转账提案详情页：展示提案信息、投票进度、合格选民投票明细及投票操作。
///
/// 读取普通个人转账详情，并通过共用投票接口提交投票。
class PersonalTransferDetailPage extends StatefulWidget {
  const PersonalTransferDetailPage({
    super.key,
    required this.account,
    required this.proposalId,
    required this.proposalContext,
    this.resolveVoteContext,
    this.readBlock,
    this.readService,
  });

  final PersonalAccountInfo account;
  final BigInt proposalId;

  /// 只读边界可注入测试；正式路径始终消费SDK与同块业务服务。
  final Future<CitizenBlockRef?> Function(Future<void> cancelled)? readBlock;
  final MultisigTransferService Function(CitizenBlockRef block)? readService;

  /// 统一的提案上下文。
  final PersonalProposalContext proposalContext;
  final Future<PersonalProposalContext> Function()? resolveVoteContext;

  /// 便捷访问。
  List<CitizenWalletStateAccount> get adminWallets =>
      proposalContext.adminWallets;

  @override
  State<PersonalTransferDetailPage> createState() =>
      _PersonalTransferDetailPageState();
}

class _PersonalTransferDetailPageState
    extends State<PersonalTransferDetailPage> {
  static const int _statusVoting = 0;

  PersonalProposalContext? _verifiedVoteContext;
  PersonalProposalContext get _proposalContext =>
      _verifiedVoteContext ?? widget.proposalContext;
  List<CitizenWalletStateAccount> get _voteWallets =>
      _proposalContext.adminWallets;
  StreamSubscription<Set<BigInt>>? _localUpdates;
  bool _preparingVote = false;

  Future<void> _readLocalDetail() async {
    final snapshot = await _applyLocalSnapshot();
    if (!mounted || snapshot != null) return;
    setState(() {
      _loading = false;
      _error = '该提案的本机记录已不可用';
    });
  }

  final ProposalDetailLocalStore _detailStore =
      ProposalDetailLocalStore.instance;
  late final PersonalMemberService _adminService;
  bool _dependenciesReady = false;
  int _generation = 0;
  Future<void>? _loadFlight;
  final Completer<void> _closed = Completer<void>();
  bool _ticketsReady = false;
  bool _hasDetails = false;
  bool _isCurrent(int generation) => mounted && generation == _generation;

  PersonalMemberIdentity get _accountIdentity =>
      PersonalMemberIdentity.fromAccount(widget.account);
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  // 提案状态
  int? _status;

  // 从链上读取的个人转账详情。
  TransferProposalInfo? _transferInfo;
  bool _remarkExpanded = false;

  /// 本详情页绑定的提案类型标签（供本地详情快照区分 key）。
  String get _proposalKind => 'transfer';

  /// 签名显示用的人类可读类型名。
  String get _kindLabel => '转账提案';

  // 投票计数
  int _yesCount = 0;
  int _noCount = 0;
  int? _thresholdSnapshot;

  // 提案创建时冻结的合格选民与投票记录。
  List<String> _admins = const [];
  // publicKey → true(赞成) / false(反对) / null(未投票)
  Map<String, bool?> _adminVotes = {};
  List<EligibleVoterTicket> _voterTickets = const [];

  // 当前用户已导入且属于合格选民快照的投票钱包。
  List<CitizenWalletStateAccount> _votableWallets = const [];
  CitizenWalletStateAccount? _selectedVoteWallet;

  String? _voteNotice;
  bool _voteNoticeIsError = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final sdk = context.read<CitizenSdk>();
    _adminService = PersonalMemberService(chain: sdk);
    _dependenciesReady = true;
    if (widget.resolveVoteContext == null) {
      _load();
    } else {
      _localUpdates = _detailStore.changes.listen((ids) {
        if (ids.contains(widget.proposalId) &&
            mounted &&
            !_submitting &&
            !_preparingVote) {
          _verifiedVoteContext = null;
          unawaited(_readLocalDetail());
        }
      });
      unawaited(_readLocalDetail());
    }
  }

  @override
  void dispose() {
    unawaited(_localUpdates?.cancel());
    ++_generation;
    _closed.complete();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) {
    final pending = _loadFlight;
    if (pending != null) return pending;
    final generation = ++_generation;
    late final Future<void> task;
    task = _readDetails(generation, showSpinner: showSpinner).whenComplete(() {
      if (identical(_loadFlight, task)) _loadFlight = null;
    });
    _loadFlight = task;
    return task;
  }

  Future<void> _readDetails(int generation, {required bool showSpinner}) async {
    if (!_isCurrent(generation)) return;
    setState(() => _ticketsReady = false);

    ProposalDetailSnapshot? localSnapshot;
    if (showSpinner) {
      localSnapshot = await _applyLocalSnapshot();
    }
    if (!_isCurrent(generation)) return;
    // 本地快照仅展示；本轮票据和投票记录核验成功前不开放投票。

    if (showSpinner && localSnapshot == null && !_hasDetails) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }

    try {
      if (!mounted) {
        return;
      }
      final sdk = context.read<CitizenSdk>();
      final block =
          await (widget.readBlock?.call(_closed.future) ??
              readProposalBlock(sdk, _closed.future));
      if (block == null || !_isCurrent(generation)) return;
      final reads =
          widget.readService?.call(block) ??
          MultisigTransferService(
            chain: sdk,
            getFinalizedHead: () async => block,
          );
      // 个人转账沿用VotingEngine.ProposalData中的multisig载荷。
      final detailFuture = widget.resolveVoteContext == null
          ? (reads.fetchProposalAction(widget.proposalId))
          : Future.value((_transferInfo));

      // 并行加载提案快照、提案状态、投票计数、提案详情。
      // 多签转账投票资格和进度必须以提案创建时的快照为准，
      // 个人路径不能使用当前
      // 管理员集合；否则任职或人员变化后旧提案会显示错误。
      final results = await Future.wait([
        proposalReadStage(
          'proposal_snapshot',
          () => PersonalProposalQueryService(
            chain: sdk,
            block: block,
          ).fetchPersonalVoterTickets(widget.proposalId, widget.account),
        ),
        proposalReadStage(
          'proposal_threshold',
          () => reads.fetchInternalThresholdSnapshot(widget.proposalId),
        ),
        proposalReadStage(
          'proposal_status',
          () => reads.fetchProposalStatus(widget.proposalId),
        ),
        proposalReadStage(
          'proposal_tally',
          () => reads.fetchVoteTally(widget.proposalId),
        ),
        proposalReadStage('proposal_details', () => detailFuture),
      ]);

      final voterTickets = results[0] as List<EligibleVoterTicket>;
      final admins = voterTickets
          .map((ticket) => _requireAccountId(ticket.voterAccountId))
          .toSet()
          .toList();
      final thresholdSnapshot = results[1] as int?;
      final status = results[2] as int?;
      final tally = results[3] as ({int yes, int no});
      final detail = results[4];
      if (detail != null) {
        PersonalProposalContextResolver.ensureTransferAccount(
          detail as TransferProposalInfo,
          widget.account,
        );
      }
      // 选民投票记录批量读取，避免逐个产生 RPC。
      final votes = await proposalReadStage(
        'proposal_votes',
        () => reads.fetchTicketVotesBatch(widget.proposalId, voterTickets),
      );

      // 筛选出尚未投票的冻结成员钱包。
      final votable = <CitizenWalletStateAccount>[];
      for (final w in _voteWallets) {
        final accountId = _requireAccountId(w.accountId);
        final walletTickets = voterTickets.where(
          (ticket) => _requireAccountId(ticket.voterAccountId) == accountId,
        );
        if (walletTickets.any((ticket) => votes[ticket.ticketKey] == null)) {
          votable.add(w);
        }
      }

      if (!_isCurrent(generation)) return;
      if (widget.resolveVoteContext == null) {
        try {
          await _detailStore.put(
            _snapshotFromChain(
              status: status,
              tally: tally,
              thresholdSnapshot: thresholdSnapshot,
              admins: admins,
              votes: votes,
              detail: detail,
            ),
          );
        } catch (e) {
          // 详情快照写入失败不能影响链上最新结果展示；仅留痕便于排查。
          AppLog.d('[MultisigDetail] 详情快照写入失败: $e');
        }
      }
      if (!_isCurrent(generation)) return;
      setState(() {
        _admins = admins;
        _status = status;
        _yesCount = tally.yes;
        _noCount = tally.no;
        _thresholdSnapshot = thresholdSnapshot;
        _adminVotes = votes;
        _voterTickets = voterTickets;
        _votableWallets = votable;
        _selectedVoteWallet = votable.isNotEmpty ? votable.first : null;
        _transferInfo = null;
        {
          _transferInfo = detail as TransferProposalInfo?;
        }
        _loading = false;
        _error = null;
        _ticketsReady = true;
        _hasDetails = true;
      });
    } on Object catch (error) {
      AppLog.proposalFailure(stage: 'proposal_display', error: error);
      if (!_isCurrent(generation)) return;
      if (widget.resolveVoteContext != null) rethrow;
      setState(() {
        _ticketsReady = false;
        _loading = false;
        if (!_hasDetails) _error = '多签提案链状态暂时不可用';
      });
    }
  }

  Future<ProposalDetailSnapshot?> _applyLocalSnapshot() async {
    try {
      final snapshot = await _detailStore.read(
        _proposalKind,
        widget.proposalId,
      );
      if (snapshot == null || !mounted) return snapshot;
      final admins = snapshot.admins;
      final votable = <CitizenWalletStateAccount>[];
      for (final w in _voteWallets) {
        final accountId = _requireAccountId(w.accountId);
        if (admins.contains(accountId) &&
            snapshot.adminVotes[accountId] == null) {
          votable.add(w);
        }
      }
      final detail = _detailFromSnapshot(snapshot);
      setState(() {
        _hasDetails = true;
        _admins = admins;
        _status = snapshot.status;
        _yesCount = snapshot.yesCount;
        _noCount = snapshot.noCount;
        _thresholdSnapshot = snapshot.threshold;
        _adminVotes = snapshot.adminVotes;
        if (widget.resolveVoteContext != null) {
          _voterTickets = snapshot.voterTickets;
        }
        _votableWallets = votable;
        _selectedVoteWallet = votable.isNotEmpty ? votable.first : null;
        _transferInfo = null;
        {
          _transferInfo = detail as TransferProposalInfo?;
        }
        _loading = false;
        _error = null;
      });
      return snapshot;
    } catch (e) {
      AppLog.d('[MultisigDetail] 加载多签详情快照失败: $e');
      return null;
    }
  }

  ProposalDetailSnapshot _snapshotFromChain({
    required int? status,
    required ({int yes, int no}) tally,
    required int? thresholdSnapshot,
    required List<String> admins,
    required Map<String, bool?> votes,
    required Object? detail,
  }) {
    return ProposalDetailSnapshot(
      proposalId: widget.proposalId,
      proposalKind: _proposalKind,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: status,
      yesCount: tally.yes,
      noCount: tally.no,
      threshold: thresholdSnapshot,
      admins: admins.map(_requireAccountId).toList(growable: false),
      // 按冻结个人钱包票据的原键保存投票。
      adminVotes: Map.of(votes),
      pendingPublicKeys: const [],
      detail: _detailToJson(detail),
    );
  }

  Map<String, Object?> _detailToJson(Object? detail) {
    if (detail is TransferProposalInfo) {
      return {
        'kind': 'transfer',
        'funding_account_id': citizenAccountIdFromBytes(
          detail.fundingAccountId,
        ),
        'beneficiary': detail.beneficiary,
        'amount_fen': detail.amountFen.toString(),
        'remark': detail.remark,
        'proposer': detail.proposer,
        'status': detail.status,
      };
    }

    return const {};
  }

  Object? _detailFromSnapshot(ProposalDetailSnapshot snapshot) {
    final detail = snapshot.detail;
    final kind = detail['kind']?.toString();
    if (kind == 'transfer') {
      if (detail.containsKey('institution_account_id') ||
          detail['actor_cid_number'] != null) {
        return null;
      }
      final amountFen = BigInt.tryParse(detail['amount_fen']?.toString() ?? '');
      final fundingAccountId = detail['funding_account_id']?.toString();
      if (amountFen == null || fundingAccountId == null) return null;
      final transfer = TransferProposalInfo(
        proposalId: snapshot.proposalId,
        actorCidNumber: null,
        fundingAccountId: citizenAccountIdBytes(fundingAccountId),
        beneficiary: detail['beneficiary']?.toString() ?? '',
        amountFen: amountFen,
        remark: detail['remark']?.toString() ?? '',
        proposer: detail['proposer']?.toString() ?? '',
        status: snapshot.status,
      );
      PersonalProposalContextResolver.ensureTransferAccount(
        transfer,
        widget.account,
      );
      return transfer;
    }

    return null;
  }

  // ──── SS58 编码工具 ────

  String _truncateAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _requireAccountId(String? accountId) {
    if (accountId == null || !isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  // ──── 投票提交 ────

  /// 当前用户是否是此个人账户的管理员（可能导入了多个管理员钱包）。
  bool get _isCurrentUserAdmin => _proposalContext.isAdmin;

  /// 是否还有可投票的钱包（未投票的管理员钱包）。
  bool get _canVote {
    if (!_ticketsReady) return false;
    if (_selectedVoteWallet == null) return false;
    if (_status != _statusVoting) return false;
    return _votableWallets.isNotEmpty;
  }

  /// 所有管理员钱包都已投过票或正在投票中。
  bool get _allVoted {
    if (!_ticketsReady) return false;
    if (_voteWallets.isEmpty) return false;
    for (final w in _voteWallets) {
      final accountId = _requireAccountId(w.accountId);
      final tickets = _voterTickets.where(
        (ticket) => _requireAccountId(ticket.voterAccountId) == accountId,
      );
      if (tickets.any((ticket) => _adminVotes[ticket.ticketKey] == null)) {
        return false;
      }
    }
    return true;
  }

  Future<EligibleVoterTicket?> _selectTicket(
    List<EligibleVoterTicket> tickets,
  ) async {
    if (tickets.length == 1) return tickets.single;
    return showDialog<EligibleVoterTicket>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择本次投票岗位'),
        children: tickets
            .map(
              (ticket) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, ticket),
                child: Text(ticket.voterRoleCode ?? '个人多签管理员'),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _submitVote(bool approve) async {
    if (!_ticketsReady) return;
    final wallet = _selectedVoteWallet;
    if (wallet == null) return;

    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final sdk = context.read<CitizenSdk>();
      final fees = await sdk.getFeeSnapshot();
      final balanceBlockedReason =
          await MultisigTransferBalanceGuard.checkAdminWalletBalance(
            wallet: wallet,
            requiredFeeFen: fees.FLAT_FEE,
            edFen: fees.existentialDepositFen,
            actionLabel: '提交多签转账投票',
            chain: sdk,
          );
      if (balanceBlockedReason != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(balanceBlockedReason),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
      if (!mounted) return;
      final signerPublicKeyBytes = citizenAccountIdBytes(wallet.accountId);
      final accountId = _requireAccountId(wallet.accountId);
      final availableTickets = _voterTickets
          .where(
            (ticket) =>
                _requireAccountId(ticket.voterAccountId) == accountId &&
                _adminVotes[ticket.ticketKey] == null,
          )
          .toList(growable: false);
      if (availableTickets.isEmpty) {
        throw StateError('当前钱包没有未使用的投票票据');
      }
      final ticket = await _selectTicket(availableTickets);
      if (ticket == null) throw StateError('已取消选择投票岗位');
      if (!mounted) return;

      // 个人多签管理员通过共用 InternalVote::cast(20.0) 提交投票。
      final result = await InternalVoteService(chain: sdk, transactions: sdk)
          .submit(
            proposalId: widget.proposalId,
            approve: approve,
            actorCidNumber: null,
            voterRoleCode: null,
            signerPublicKey: Uint8List.fromList(signerPublicKeyBytes),
            externalSigning: (pending) => showCitizenSdkQrResponse(
              context,
              request: pending.qrRequest,
              expiresAt: BigInt.from(
                pending.expiresAt.millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          );
      AppLog.d(
        '[MultisigTransferVote] submit 已入块 txHash=${result.txHash} nonce=${result.usedNonce} block=${result.blockHash}',
      );

      if (!mounted) return;
      setState(() {
        _adminVotes[ticket.ticketKey] = approve;
        _votableWallets = _votableWallets
            .where((w) {
              final accountId = _requireAccountId(w.accountId);
              return _voterTickets.any(
                (candidate) =>
                    _requireAccountId(candidate.voterAccountId) == accountId &&
                    _adminVotes[candidate.ticketKey] == null,
              );
            })
            .toList(growable: false);
        _selectedVoteWallet = _votableWallets.isNotEmpty
            ? _votableWallets.first
            : null;
        _voteNotice = '链上已确认该合格选民投票。';
        _voteNoticeIsError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('投票已由 runtime 确认：${_truncateAddress(result.txHash)}'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );

      _adminService.clearCache(_accountIdentity);
      if (widget.resolveVoteContext == null) {
        unawaited(_load(showSpinner: false));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投票失败：$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmVote(bool approve) async {
    final resolve = widget.resolveVoteContext;
    if (_preparingVote || _submitting) return;
    if (resolve != null) setState(() => _preparingVote = true);
    try {
      if (resolve != null) {
        final verified = await resolve();
        if (!mounted) return;
        if (!verified.isAdmin) throw StateError('当前钱包没有投票资格');
        _verifiedVoteContext = verified;
        await _load(showSpinner: false);
        if (!mounted) return;
        if (_error != null || !(_isCurrentUserAdmin && _canVote)) {
          throw StateError(_error ?? '提案已停止投票或当前钱包没有未使用的投票票据');
        }
      }
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      final label = approve ? '赞成' : '反对';
      final choices = resolve != null && _votableWallets.length > 1
          ? _votableWallets
          : const <CitizenWalletStateAccount>[];
      var selected = _selectedVoteWallet;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, updateDialog) {
            return AlertDialog(
              title: Text('确认$label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确定要对此提案投"$label"票吗？投票后不可更改。'),
                  if (choices.isNotEmpty)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: selected?.walletIndex,
                      items: [
                        for (final wallet in choices)
                          DropdownMenuItem(
                            value: wallet.walletIndex,
                            child: Text(
                              wallet.ss58Address,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (index) => updateDialog(() {
                        selected = choices.firstWhere(
                          (wallet) => wallet.walletIndex == index,
                        );
                      }),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(label),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || confirmed != true) return;
      if (resolve != null && ModalRoute.of(context)?.isCurrent != true) return;
      _selectedVoteWallet = selected;
      await _submitVote(approve);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('投票校验未通过：$error')));
      }
    } finally {
      if (resolve != null && mounted) {
        _verifiedVoteContext = null;
        _ticketsReady = false;
        await _readLocalDetail();
        if (mounted) setState(() => _preparingVote = false);
      }
    }
  }
  // ──── 构建 UI ────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          '$_kindLabel详情',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
      bottomNavigationBar:
          !_loading &&
              _error == null &&
              _status == _statusVoting &&
              (widget.resolveVoteContext != null || _isCurrentUserAdmin)
          ? ProposalVoteActions(
              votableWallets: _votableWallets,
              selectedWallet: _selectedVoteWallet,
              submitting: _submitting || _preparingVote,
              canVote: widget.resolveVoteContext != null || _canVote,
              allVoted: _allVoted,
              onWalletChanged: (w) => setState(() => _selectedVoteWallet = w),
              onVote: _confirmVote,
            )
          : null,
    );
  }

  Widget _buildError() {
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
            OutlinedButton(
              onPressed: widget.resolveVoteContext == null
                  ? _load
                  : _readLocalDetail,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        _adminService.clearCache(_accountIdentity);
        if (widget.resolveVoteContext == null) {
          await _load();
        } else {
          await _readLocalDetail();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ProposalStatusBadge(status: _status, proposalId: widget.proposalId),
          if (_voteNotice != null) ...[
            SizedBox(height: AppLayout.scaledValue(12)),
            _buildVoteNotice(),
          ],
          SizedBox(height: AppLayout.scaledValue(16)),
          _buildProposalInfoCard(),
          SizedBox(height: AppLayout.scaledValue(16)),
          ProposalVoteProgress(
            yesCount: _yesCount,
            noCount: _noCount,
            threshold: _thresholdSnapshot ?? widget.account.internalThreshold,
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          ProposalAdminVoteList(
            admins: _admins,
            voterTickets: _voterTickets,
            adminVotes: _adminVotes,
            pendingPublicKeys: const {},
            proposerSs58: _proposerSs58,
          ),
        ],
      ),
    );
  }

  Widget _buildVoteNotice() {
    final color = _voteNoticeIsError ? AppTheme.danger : AppTheme.info;
    return Container(
      padding: EdgeInsets.all(AppLayout.scaledValue(12)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _voteNoticeIsError ? Icons.error_outline : Icons.info_outline,
            size: AppLayout.scaledValue(18),
            color: color,
          ),
          SizedBox(width: AppLayout.scaledValue(8)),
          Expanded(
            child: Text(
              _voteNotice!,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(13),
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──── 提案信息卡片 ────

  /// 提案创建者公钥。
  String? get _proposerSs58 => _transferInfo?.proposer;

  Widget _buildProposalInfoCard() {
    return Card(
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
              '提案信息',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            ..._buildInfoRowsByKind(),
          ],
        ),
      ),
    );
  }

  /// 生成个人转账信息卡的内容行（含 Divider）。
  List<Widget> _buildInfoRowsByKind() => _buildTransferRows();

  /// 个人转账：账户简称、金额、收款地址与备注。
  List<Widget> _buildTransferRows() {
    final info = _transferInfo;
    final rows = <Widget>[_buildInfoRow('账户简称', widget.account.shortName)];
    if (info != null) {
      rows
        ..add(Divider(height: AppLayout.scaledValue(20)))
        ..add(_buildInfoRow('转账金额', '${formatFen(info.amountFen)} 元'))
        ..add(Divider(height: AppLayout.scaledValue(20)))
        ..add(
          _buildInfoRow(
            '收款地址',
            _truncateAddress(info.beneficiary),
            onCopy: () => _copyToClipboard(info.beneficiary),
          ),
        );
    }
    rows
      ..add(Divider(height: AppLayout.scaledValue(20)))
      ..add(_buildRemarkRow(info?.remark ?? ''));
    return rows;
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地址已复制'), duration: Duration(seconds: 1)),
    );
  }

  Widget _buildRemarkRow(String remark) {
    if (remark.isEmpty) {
      return _buildInfoRow('备注', '无');
    }
    final isLong = remark.length > 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppLayout.scaledValue(80),
              child: Text(
                '备注',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(13),
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                remark,
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(13),
                  color: AppTheme.textPrimary,
                ),
                maxLines: _remarkExpanded ? null : 1,
                overflow: _remarkExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
            if (isLong)
              GestureDetector(
                onTap: () => setState(() => _remarkExpanded = !_remarkExpanded),
                child: Icon(
                  _remarkExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: AppLayout.scaledValue(20),
                  color: AppTheme.textTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onCopy}) {
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
              color: AppTheme.textPrimary,
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
}

// 个人提案发起入口。
// 按个人账户能力展示转账及成员变更入口。

/// 个人多签提案类型选择页，能力由PersonalProposalCapabilities定义。
class PersonalProposalEntryPage extends StatefulWidget {
  const PersonalProposalEntryPage({
    super.key,
    required this.account,
    required this.orgCode,
    required this.icon,
    required this.badgeColor,
    required this.adminWallets,
    required this.isActivated,
  });

  final PersonalAccountInfo account;

  /// 个人多签业务分类码PMUL。
  final String orgCode;
  final IconData icon;
  final Color badgeColor;

  /// 当前用户已激活的管理员钱包列表。
  final List<CitizenWalletStateAccount> adminWallets;

  /// 用户是否已激活管理员身份。
  final bool isActivated;

  @override
  State<PersonalProposalEntryPage> createState() =>
      _PersonalProposalEntryPageState();
}

class _PersonalProposalEntryPageState extends State<PersonalProposalEntryPage> {
  CitizenChainSyncStatus? _chainProgress;
  String? _chainProgressError;

  @override
  Widget build(BuildContext context) {
    final proposalActionsEnabled =
        widget.isActivated && _proposalBlockedReason == null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '发起提案',
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
      body: Stack(
        children: [
          ChainProgressBanner(
            onProgressChanged: _handleChainProgressChanged,
            onErrorChanged: _handleChainProgressErrorChanged,
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 个人账户信息
              Padding(
                padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 16)),
                child: Row(
                  children: [
                    Container(
                      width: AppLayout.scaled(context, 36),
                      height: AppLayout.scaled(context, 36),
                      decoration: BoxDecoration(
                        color: widget.badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppLayout.scaledValue(10),
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: AppLayout.scaled(context, 18),
                        color: widget.badgeColor,
                      ),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    Expanded(
                      child: Text(
                        widget.account.shortName,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.scaled(context, 8),
                        vertical: AppLayout.scaled(context, 2),
                      ),
                      decoration: BoxDecoration(
                        color: widget.badgeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppLayout.scaledValue(10),
                        ),
                      ),
                      child: Text(
                        '个人多签',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 11),
                          color: widget.badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ──── 未激活签名钱包提示 ────
              if (!widget.isActivated)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: AppLayout.scaled(context, 16),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppLayout.scaled(context, 12),
                      vertical: AppLayout.scaled(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                      border: Border.all(
                        color: AppTheme.textTertiary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppLayout.scaled(context, 16),
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(width: AppLayout.scaled(context, 8)),
                        Expanded(
                          child: Text(
                            '请先完成个人多签激活，使用成员钱包发起提案',
                            style: TextStyle(
                              fontSize: AppLayout.scaled(context, 12),
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.isActivated && _proposalBlockedReason != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: AppLayout.scaled(context, 16),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppLayout.scaled(context, 12),
                      vertical: AppLayout.scaled(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync_problem,
                          size: AppLayout.scaled(context, 16),
                          color: AppTheme.warning,
                        ),
                        SizedBox(width: AppLayout.scaled(context, 8)),
                        Expanded(
                          child: Text(
                            _proposalBlockedReason!,
                            style: TextStyle(
                              fontSize: AppLayout.scaled(context, 12),
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ──── 可发起提案(按主体能力 registry 渲染,单一真源) ────
              _buildSectionTitle('可发起提案'),
              ..._buildProposalCards(proposalActionsEnabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppLayout.scaledValue(14),
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
      ),
    );
  }

  /// 按主体能力 registry 取可发起提案,逐项渲染卡片。
  List<Widget> _buildProposalCards(bool enabled) => [
    for (final kind in PersonalProposalCapabilities.forAccount(
      widget.account,
    )) ...[
      SizedBox(height: AppLayout.scaledValue(8)),
      switch (kind) {
        ProposalKind.transfer => _typeCard(
          Icons.send_outlined,
          '转账',
          '从个人多签账户向指定地址发起转账提案',
          AppTheme.primary,
          enabled,
          () => _checkAndOpenProposal(
            context,
            () => context.read<PersonalNavigation>().transfer(
              account: widget.account,
              icon: widget.icon,
              badgeColor: widget.badgeColor,
              adminWallets: widget.adminWallets,
              onCreated: (id) async => PersonalProposalHistoryService(
                chain: context.read<CitizenSdk>(),
              ).fetchAll(widget.account.accountId).then((_) {}),
            ),
          ),
        ),
        ProposalKind.adminsChange => _typeCard(
          Icons.swap_horiz,
          '换管理员',
          '提议更换个人多签成员',
          AppTheme.accent,
          enabled,
          () => _checkAndOpenProposal(
            context,
            () => PersonalMembersPage(
              account: widget.account,
              accountIdentity: PersonalMemberIdentity.fromAccount(
                widget.account,
              ),
              adminWallets: widget.adminWallets,
            ),
          ),
        ),
        _ => throw StateError('个人账户没有此提案入口'),
      },
    ],
  ];

  /// 单种提案 → 卡片(图标/标题/副标题/跳转)。类B(协议升级/发起立法)直接进展示页,
  /// 其余走 `_checkAndOpenProposal`(校验活跃提案上限)。

  Widget _typeCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    bool enabled,
    VoidCallback onTap,
  ) {
    return _ProposalTypeCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      enabled: enabled,
      onTap: onTap,
    );
  }

  /// 检查活跃提案数，未达上限则打开页面，达上限则弹窗提示。
  /// [pageBuilder] 为 null 时表示该功能开发中。
  Future<void> _checkAndOpenProposal(
    BuildContext context,
    Widget Function()? pageBuilder, {
    String? name,
  }) async {
    final blockedReason = _proposalBlockedReason;
    if (blockedReason != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(blockedReason)));
      }
      return;
    }
    try {
      final service = PersonalProposalLimitService(
        chain: context.read<CitizenSdk>(),
      );
      final activeIds = await service.fetchActiveProposalIds(widget.account);
      if (!context.mounted) return;

      if (activeIds.length >=
          ProposalLimitService.maxActiveProposalsPerSubject) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提案数量已达上限'),
            content: Text(
              '本账户当前有 ${activeIds.length} 个活跃提案，'
              '已达上限 ${ProposalLimitService.maxActiveProposalsPerSubject} 个。'
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

      if (pageBuilder != null) {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => pageBuilder()),
        );
        if (created == true && context.mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${name ?? "该"}功能开发中')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公民链状态暂时不可用')));
    }
  }

  void _handleChainProgressChanged(CitizenChainSyncStatus? progress) {
    if (!mounted) return;
    setState(() {
      _chainProgress = progress;
    });
  }

  void _handleChainProgressErrorChanged(String? error) {
    if (!mounted) return;
    setState(() {
      _chainProgressError = error;
    });
  }

  String? get _proposalBlockedReason {
    final progress = _chainProgress;
    if (progress == null) {
      return _chainProgressError ?? '正在读取区块链状态，请稍后再试';
    }
    if (progress.peerCount == BigInt.zero) {
      return '轻节点尚未连接到区块链网络，暂不能发起提案';
    }
    if (progress.isSyncing) {
      return '轻节点仍在验证或同步链状态，完成后才能发起提案';
    }
    if (!progress.isUsable) {
      return _chainProgressError ?? '区块链状态尚未就绪，暂不能发起提案';
    }
    return null;
  }
}

class _ProposalTypeCard extends StatelessWidget {
  const _ProposalTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// 是否可点击。未激活管理员时为 false，显示灰色禁用态。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppTheme.textTertiary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: BorderSide(color: effectiveColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
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
                  width: AppLayout.scaled(context, 40),
                  height: AppLayout.scaled(context, 40),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(10),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: AppLayout.scaled(context, 20),
                    color: effectiveColor,
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 15),
                          fontWeight: FontWeight.w600,
                          color: effectiveColor,
                        ),
                      ),
                      SizedBox(height: AppLayout.scaled(context, 2)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 12),
                          color: AppTheme.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppLayout.scaled(context, 20),
                  color: enabled
                      ? AppTheme.textTertiary
                      : AppTheme.textTertiary.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 活跃提案限制沿用原引擎数量上限，个人主体编码归本包。
class PersonalProposalLimitService {
  PersonalProposalLimitService({required CitizenSdk chain})
    : _reads = PersonalProposalQueryService(chain: chain);
  final PersonalProposalQueryService _reads;
  Future<List<BigInt>> fetchActiveProposalIds(PersonalAccountInfo account) =>
      _reads.fetchActivePersonalProposalIds(account.accountId);
}

/// 原个人转账完成后的本地历史写入；写入失败不改变已上链结果。
extension PersonalTransferHistory on PersonalProposalHistoryService {
  Future<void> recordTransferIfKnown({
    required String accountId,
    required BigInt proposalId,
    required String beneficiary,
    required BigInt amountFen,
  }) async {
    try {
      final personal = await UserIsar.instance.read(
        (isar) => isar
            .collection<wallet_store.Account>()
            .filter()
            .accountIdEqualTo(accountId)
            .findFirst(),
      );
      if (personal == null) return;
      await recordOrUpdate(
        accountId: accountId,
        proposalId: proposalId,
        actionKind: PersonalProposalAction.transfer,
        status: PersonalProposalStatus.voting,
        yesCount: 0,
        noCount: 0,
        snapshot: {
          'beneficiary': beneficiary,
          'amount_fen': amountFen.toString(),
        },
      );
    } catch (error) {
      AppLog.d('[PersonalProposalHistory] 本地转账历史写入失败');
    }
  }
}

/// 个人账户展示资料只使用原账户ID和名称，不构造机构CID。
PersonalAccountInfo? personalAccountFromBytes(
  List<int> bytes, {
  String? accountName,
}) {
  if (bytes.length != 32) return null;
  final id = citizenAccountIdFromBytes(bytes);
  final name = accountName?.trim() ?? '';
  return PersonalAccountInfo(
    fullName: name.isEmpty ? '个人多签 ${id.substring(2, 10)}' : name,
    shortName: name,
    accountId: id,
  );
}

/// 保留原提案浏览上下文的查看者状态，投票资格仍由详情页冻结快照核验。
class PersonalProposalContextResolver {
  /// 通用转账详情进入个人页面前，只允许无机构主体且资金账户精确匹配。
  static void ensureTransferAccount(
    TransferProposalInfo transfer,
    PersonalAccountInfo account,
  ) {
    if (transfer.actorCidNumber != null ||
        !listEquals(
          transfer.fundingAccountId,
          citizenAccountIdBytes(account.accountId),
        )) {
      throw StateError('转账提案不属于当前个人多签账户');
    }
  }

  PersonalProposalContextResolver({
    CitizenSdk? wallet,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    Future<Map<String, String>> Function(Iterable<String>)? readNames,
  }) : _readNames = readNames ?? readMultisigNames,
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState'));
  final Future<Map<String, String>> Function(Iterable<String>) _readNames;
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;
  List<CitizenWalletStateAccount>? _wallets;
  Future<void> _readWallets() async {
    _wallets ??= (await _getWalletState().result).accounts;
  }

  void clearWalletCache() {
    _wallets = null;
  }

  Future<Map<String, String>> _names(Iterable<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      return await _readNames(ids);
    } catch (_) {
      AppLog.d('proposal_personal_names_read_failed');
      return const {};
    }
  }

  Future<PersonalProposalContext> resolve({
    required String accountId,
    PersonalAccountInfo? knownAccount,
  }) async {
    await _readWallets();
    if (!isCitizenAccountId(accountId)) return const PersonalProposalContext();
    if (knownAccount?.accountId == accountId) {
      return PersonalProposalContext(account: knownAccount);
    }
    final names = await _names([accountId]);
    return PersonalProposalContext(
      account: personalAccountFromBytes(
        citizenAccountIdBytes(accountId),
        accountName: names[accountId],
      ),
    );
  }

  Future<List<PersonalProposalContext>> resolveBatch(
    List<String> accountIds, {
    Map<String, PersonalAccountInfo> knownAccountsById = const {},
  }) async {
    await _readWallets();
    final valid = accountIds.where(isCitizenAccountId).toSet();
    final names = await _names(
      valid.where((id) => !knownAccountsById.containsKey(id)),
    );
    return [
      for (final id in accountIds)
        !isCitizenAccountId(id)
            ? const PersonalProposalContext()
            : PersonalProposalContext(
                account:
                    knownAccountsById[id] ??
                    personalAccountFromBytes(
                      citizenAccountIdBytes(id),
                      accountName: names[id],
                    ),
              ),
    ];
  }
}

/// 个人提案的两项原有能力由本包拥有，机构注册表不提供这些页面。
class PersonalProposalCapabilities {
  static const Set<ProposalKind> kinds = {
    ProposalKind.transfer,
    ProposalKind.adminsChange,
  };
  static Set<ProposalKind> forAccount(PersonalAccountInfo account) => kinds;
}

/// 个人名称按原规则取前六个可见字符，通用标题组件只承担布局。
class PersonalProposalHeader extends StatelessWidget {
  const PersonalProposalHeader({
    super.key,
    required this.subjectName,
    required this.proposalNumber,
  });
  final String? subjectName;
  final String proposalNumber;
  @override
  Widget build(BuildContext context) => ProposalCardHeader(
    subjectName: (subjectName?.trim() ?? '').characters.take(6).toString(),
    proposalNumber: proposalNumber,
  );
}
