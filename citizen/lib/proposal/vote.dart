// 内部投票服务及投票组件。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_citizen/proposal/data.dart' show EligibleVoterTicket;
import 'dart:typed_data';
import 'dart:convert';
import 'package:citizen_citizen/institution/codec.dart' show InstitutionRoleStorageCodec;
import 'package:citizen_citizen/data.dart' show PalletRegistry;
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;

// 统一展示提案标题、展示号、计票进度、投票动作和状态。

/// 所有提案列表的统一首行：主体名称在左、编号在右，均单行限宽。
/// 个人多签只截取展示名称的前6个可见字符，不修改原账户名称。
class ProposalCardHeader extends StatelessWidget {
  const ProposalCardHeader({
    super.key,
    required this.subjectName,
    required this.proposalNumber,
  });

  final String? subjectName;
  final String proposalNumber;

  @override
  Widget build(BuildContext context) {
    final original = subjectName?.trim() ?? '';
    final name = original;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (name.isNotEmpty) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaledValue(6),
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: AppLayout.scaledValue(10),
                    color: AppTheme.primaryDark,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(8)),
          ],
          Expanded(
            child: Text(
              proposalNumber,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(15),
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──── 投票进度组件 ────

/// 提案投票进度条（赞成/反对计数 + 阈值 + 进度条）。
class ProposalVoteProgress extends StatelessWidget {
  const ProposalVoteProgress({
    super.key,
    required this.yesCount,
    required this.noCount,
    required this.threshold,
  });

  final int yesCount;
  final int noCount;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final progress = threshold > 0
        ? (yesCount / threshold).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '投票进度',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 16),
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(6)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: AppLayout.scaled(context, 10),
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryDark,
                ),
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '赞成 $yesCount 票 / 阈值 $threshold',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 14),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Text(
                  '反对 $noCount 票',
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 13),
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──── 合格选民投票明细组件 ────

/// 提案创建时合格选民的投票明细列表（编号地址 + 投票状态标签）。
class ProposalAdminVoteList extends StatelessWidget {
  const ProposalAdminVoteList({
    super.key,
    required this.admins,
    required this.adminVotes,
    required this.pendingPublicKeys,
    this.voterTickets = const [],
    this.proposerSs58,
  });

  /// 合格选民公钥列表（小写 hex，不含 0x）。
  final List<String> admins;

  /// 机构岗位票据；非空时逐票据展示，同一钱包多个岗位各占一行。
  final List<EligibleVoterTicket> voterTickets;

  /// 投票记录：publicKey → true(赞成) / false(反对) / null(未投票)。
  final Map<String, bool?> adminVotes;

  /// 已提交但尚未上链确认的选民公钥集合。
  final Set<String> pendingPublicKeys;

  /// 发起人的 SS58 地址（可选，用于显示"发起人"徽章）。
  final String? proposerSs58;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppLayout.scaled(context, 8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '合格投票票据明细（共 ${voterTickets.isEmpty ? admins.length : voterTickets.length} 票）',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 16),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            const Divider(),
            ...List.generate(
              voterTickets.isEmpty ? admins.length : voterTickets.length,
              (index) {
                final ticket = voterTickets.isEmpty
                    ? null
                    : voterTickets[index];
                final accountId = ticket == null
                    ? admins[index]
                    : ticket.voterAccountId;
                final ticketKey = ticket?.ticketKey ?? accountId!;
                final vote = adminVotes[ticketKey];
                final ss58 = accountId == null
                    ? null
                    : citizenSs58FromAccountId(accountId);
                final isProposer = proposerSs58 != null && proposerSs58 == ss58;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: AppLayout.scaled(context, 16),
                    backgroundColor: AppTheme.primaryDark.withValues(
                      alpha: 0.08,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          ticket?.personCid ??
                              (ss58 == null ? '未绑定钱包' : _truncateAddress(ss58)),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 13),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ticket?.voterRoleCode != null) ...[
                        SizedBox(width: AppLayout.scaled(context, 6)),
                        Text(
                          ticket!.voterRoleName ?? '—',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 10),
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                      if (isProposer) ...[
                        SizedBox(width: AppLayout.scaled(context, 6)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppLayout.scaled(context, 6),
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppLayout.scaledValue(8),
                            ),
                          ),
                          child: Text(
                            '发起人',
                            style: TextStyle(
                              fontSize: AppLayout.scaled(context, 10),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: ticket?.isInstitution == true
                      ? Text(
                          ss58 == null
                              ? '当前无有效钱包绑定，不能签名'
                              : _truncateAddress(ss58),
                          maxLines: ss58 == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: _buildVoteStatusChip(vote, ticketKey),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteStatusChip(bool? vote, String publicKey) {
    if (vote == true) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(8),
          vertical: AppLayout.scaledValue(2),
        ),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
        ),
        child: Text(
          '赞成 \u2713',
          style: TextStyle(
            fontSize: AppLayout.scaledValue(12),
            fontWeight: FontWeight.w600,
            color: AppTheme.success,
          ),
        ),
      );
    } else if (vote == false) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(8),
          vertical: AppLayout.scaledValue(2),
        ),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
        ),
        child: Text(
          '反对 \u2717',
          style: TextStyle(
            fontSize: AppLayout.scaledValue(12),
            fontWeight: FontWeight.w600,
            color: AppTheme.danger,
          ),
        ),
      );
    } else if (pendingPublicKeys.contains(publicKey)) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(8),
          vertical: AppLayout.scaledValue(2),
        ),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: AppLayout.scaledValue(10),
              height: AppLayout.scaledValue(10),
              child: const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.warning,
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(4)),
            Text(
              '投票中',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12),
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(8),
          vertical: AppLayout.scaledValue(2),
        ),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
        ),
        child: Text(
          '未投票 -',
          style: TextStyle(
            fontSize: AppLayout.scaledValue(12),
            fontWeight: FontWeight.w500,
            color: AppTheme.textTertiary,
          ),
        ),
      );
    }
  }
}

// ──── 底部投票操作组件 ────

/// 底部投票操作栏（钱包选择 + 赞成/反对按钮）。
///
/// 通过 [onVote] 回调通知父页面投票意向，父页面自行处理确认对话框和提交逻辑。
class ProposalVoteActions extends StatelessWidget {
  const ProposalVoteActions({
    super.key,
    required this.votableWallets,
    required this.selectedWallet,
    required this.submitting,
    required this.canVote,
    required this.allVoted,
    required this.onWalletChanged,
    required this.onVote,
  });

  final List<CitizenWalletStateAccount> votableWallets;
  final CitizenWalletStateAccount? selectedWallet;
  final bool submitting;
  final bool canVote;
  final bool allVoted;
  final ValueChanged<CitizenWalletStateAccount?> onWalletChanged;

  /// 投票回调：true=赞成，false=反对。
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
            blurRadius: AppLayout.scaled(context, 8),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 多管理员时显示钱包选择器
          if (votableWallets.length > 1)
            Padding(
              padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 10)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 12),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedWallet?.walletIndex,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryDark,
                    ),
                    items: votableWallets.map((w) {
                      return DropdownMenuItem<int>(
                        value: w.walletIndex,
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: AppLayout.scaled(context, 14),
                              color: AppTheme.success,
                            ),
                            SizedBox(width: AppLayout.scaled(context, 6)),
                            Expanded(
                              child: Text(
                                _truncateWalletAddress(w.ss58Address),
                                style: TextStyle(
                                  fontSize: AppLayout.scaled(context, 13),
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (index) {
                      if (index == null) return;
                      final wallet = votableWallets.firstWhere(
                        (w) => w.walletIndex == index,
                      );
                      onWalletChanged(wallet);
                    },
                  ),
                ),
              ),
            ),
          if (allVoted)
            Padding(
              padding: EdgeInsets.only(bottom: AppLayout.scaled(context, 10)),
              child: Text(
                '你已导入的合格投票钱包均已投票',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 13),
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (submitting || !canVote)
                      ? null
                      : () => onVote(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canVote
                        ? AppTheme.danger
                        : AppTheme.border,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaled(context, 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: submitting
                      ? SizedBox(
                          width: AppLayout.scaled(context, 20),
                          height: AppLayout.scaled(context, 20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '反对',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 16)),
              Expanded(
                child: ElevatedButton(
                  onPressed: (submitting || !canVote)
                      ? null
                      : () => onVote(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.success.withValues(
                      alpha: 0.25,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.scaled(context, 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(10),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: submitting
                      ? SizedBox(
                          width: AppLayout.scaled(context, 20),
                          height: AppLayout.scaled(context, 20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '赞成',
                          style: TextStyle(
                            fontSize: AppLayout.scaled(context, 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _truncateWalletAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}

// ──── 状态徽章组件 ────

/// 提案状态徽章（投票中/已通过/已拒绝/已执行）。
class ProposalStatusBadge extends StatelessWidget {
  const ProposalStatusBadge({
    super.key,
    required this.status,
    required this.proposalId,
  });

  final int? status;
  final BigInt proposalId;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.proposalStatusColor(status ?? -1);
    final label = _statusLabel(status);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 12),
            vertical: AppLayout.scaled(context, 6),
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppLayout.scaledValue(20)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == 0
                    ? Icons.how_to_vote
                    : status == 1
                    ? Icons.check_circle
                    : status == 2
                    ? Icons.cancel
                    : status == 3
                    ? Icons.check_circle
                    : status == 4
                    ? Icons.error_outline
                    : Icons.error,
                size: AppLayout.scaled(context, 16),
                color: color,
              ),
              SizedBox(width: AppLayout.scaled(context, 4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          '提案 #$proposalId',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 13),
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  static String _statusLabel(int? status) {
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
}

// ──── 共享工具 ────

String _truncateAddress(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
}

// 读取统一内部投票票据、计票及准确主体资格。

/// InternalVote 通用查询服务。
///
/// 内部投票记录属于投票引擎通用状态，不放进具体业务模块，
/// 避免 proposal 共享层依赖业务 service。
class InternalVoteQueryService {
  InternalVoteQueryService({
    CitizenSdk? chain,
    CitizenBlockRef? block,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _block = block,
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;

  final CitizenBlockRef? _block;

  /// 查询某管理员对某提案的投票记录。null=未投票，true=赞成，false=反对。
  Future<bool?> fetchAdminVote(BigInt proposalId, String accountId) async {
    final data = await readVoteFields(_ticketVoteFields(proposalId, accountId));
    return decodeVote(data);
  }

  /// 查询一张机构岗位票据；CID、岗位码、钱包三者共同确定唯一票。
  Future<bool?> fetchInstitutionTicketVote(
    BigInt proposalId,
    String cidNumber,
    String voterRoleCode,
    String personCid,
  ) async {
    final data = await readVoteFields(
      _ticketVoteFields(
        proposalId,
        personCid,
        cidNumber: cidNumber,
        voterRoleCode: voterRoleCode,
      ),
    );
    return decodeVote(data);
  }

  /// 批量查询管理员投票记录。
  ///
  /// 详情页和红点判断不能再按管理员逐条 RPC；这里统一拼好
  /// `InternalVotesByTicket` 的个人票据 storage key 后分块读取。
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    BigInt proposalId,
    Iterable<String> accountIds,
  ) async {
    final keyByAccountId = <String, List<Object>>{};
    for (final accountId in accountIds) {
      final normalizedAccountId = _requireAccountId(accountId);
      keyByAccountId[normalizedAccountId] = _ticketVoteFields(
        proposalId,
        normalizedAccountId,
      );
    }
    if (keyByAccountId.isEmpty) return const {};

    final values = await readVoteFieldsBatch(keyByAccountId.values.toList());
    return {
      for (var index = 0; index < keyByAccountId.length; index++)
        keyByAccountId.keys.elementAt(index): decodeVote(values[index]),
    };
  }

  /// 批量查询完整票据；返回键为 [EligibleVoterTicket.ticketKey]。
  Future<Map<String, bool?>> fetchTicketVotesBatch(
    BigInt proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) async {
    final storageByTicket = <String, List<Object>>{};
    for (final ticket in tickets) {
      storageByTicket[ticket.ticketKey] = _ticketVoteFields(
        proposalId,
        ticket.isInstitution ? ticket.personCid! : ticket.voterAccountId!,
        cidNumber: ticket.cidNumber,
        voterRoleCode: ticket.voterRoleCode,
      );
    }
    final values = await readVoteFieldsBatch(storageByTicket.values.toList());
    return {
      for (var index = 0; index < storageByTicket.length; index++)
        storageByTicket.keys.elementAt(index): decodeVote(values[index]),
    };
  }

  /// 跨提案批量查询内部投票:输入 `{proposal_id: [account_id]}`,一次链查返回
  /// `{proposal_id: {account_id: vote?}}`。
  ///
  /// (ADR-018 R2):公民-提案列表原来每个提案各发一次批量 RPC(P 个提案
  /// = P 次往返),这里把所有 (proposal_id, admin) 的 storage key 一次拼齐、单次
  /// 分块读取,P 次往返降为 1 次。
  Future<Map<BigInt, Map<String, bool?>>> fetchAdminVotesForProposals(
    Map<BigInt, List<String>> accountIdsByProposal,
  ) async {
    final keys = <List<Object>>[];
    final coordinates = <({BigInt pid, String accountId})>[];
    for (final entry in accountIdsByProposal.entries) {
      for (final accountId in entry.value) {
        final normalizedAccountId = _requireAccountId(accountId);
        keys.add(_ticketVoteFields(entry.key, normalizedAccountId));
        coordinates.add((pid: entry.key, accountId: normalizedAccountId));
      }
    }
    if (keys.isEmpty) return const {};
    final values = await readVoteFieldsBatch(keys);
    final result = <BigInt, Map<String, bool?>>{};
    for (var index = 0; index < coordinates.length; index++) {
      final coord = coordinates[index];
      (result[coord.pid] ??= <String, bool?>{})[coord.accountId] = decodeVote(
        values[index],
      );
    }
    return result;
  }

  /// 跨提案批量查询完整票据；机构岗位票据和个人票据共用一次分块读取。
  Future<Map<BigInt, Map<String, bool?>>> fetchTicketVotesForProposals(
    Map<BigInt, List<EligibleVoterTicket>> ticketsByProposal,
  ) async {
    final keys = <List<Object>>[];
    final coordinates = <({BigInt pid, String ticketKey})>[];
    for (final entry in ticketsByProposal.entries) {
      for (final ticket in entry.value) {
        final storageKey = _ticketVoteFields(
          entry.key,
          ticket.isInstitution ? ticket.personCid! : ticket.voterAccountId!,
          cidNumber: ticket.cidNumber,
          voterRoleCode: ticket.voterRoleCode,
        );
        keys.add(storageKey);
        coordinates.add((pid: entry.key, ticketKey: ticket.ticketKey));
      }
    }
    if (keys.isEmpty) return const {};
    final values = await readVoteFieldsBatch(keys);
    final result = <BigInt, Map<String, bool?>>{};
    for (var index = 0; index < coordinates.length; index++) {
      final coord = coordinates[index];
      (result[coord.pid] ??= <String, bool?>{})[coord.ticketKey] = decodeVote(
        values[index],
      );
    }
    return result;
  }

  List<Object> _ticketVoteFields(
    BigInt proposalId,
    String accountId, {
    String? cidNumber,
    String? voterRoleCode,
  }) {
    if (proposalId.isNegative) throw ArgumentError('proposal_id不得为负');
    final CitizenScaleVariant ticket;
    if (cidNumber == null && voterRoleCode == null) {
      ticket = (
        variant: 'Personal',
        fields: [citizenAccountIdBytes(accountId)],
      );
    } else if (cidNumber != null && voterRoleCode != null) {
      if (!InstitutionRoleStorageCodec.isPersonCid(accountId)) {
        throw ArgumentError('机构票据必须使用人员CID');
      }
      ticket = (
        variant: 'Institution',
        fields: [
          [
            [
              _boundedText(cidNumber, 32, 'cid_number'),
              _boundedText(voterRoleCode, 64, 'voter_role_code'),
            ],
            _boundedText(accountId, 32, 'person_cid'),
          ],
        ],
      );
    } else {
      throw ArgumentError('机构票据查询必须同时提供 cid_number 和 voter_role_code');
    }
    return [proposalId, ticket];
  }

  Future<CitizenRuntimeContext> _finalizedRuntime() async {
    final finalized = _block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('投票查询需要finalized块');
    }
    return _getRuntimeContext(finalized);
  }

  Future<Uint8List?> readVoteFields(List<Object> fields) async {
    final runtime = await _finalizedRuntime();
    return _getStorage(
      runtime.block,
      runtime.storageKey('InternalVote', 'InternalVotesByTicket', fields),
    );
  }

  Future<List<Uint8List?>> readVoteFieldsBatch(
    List<List<Object>> fields,
  ) async {
    if (fields.isEmpty) return const <Uint8List?>[];
    final runtime = await _finalizedRuntime();
    final keys = [
      for (final key in fields)
        runtime.storageKey('InternalVote', 'InternalVotesByTicket', key),
    ];
    final result = <Uint8List?>[];
    for (var offset = 0; offset < keys.length; offset += 100) {
      final end = (offset + 100).clamp(0, keys.length);
      final values = await _getStorageBatch(
        runtime.block,
        keys.sublist(offset, end),
      );
      if (values.length != end - offset) {
        throw const FormatException('投票批量响应数量不符');
      }
      result.addAll(values);
    }
    return result;
  }

  bool? decodeVote(Uint8List? data) {
    if (data == null) return null;
    if (data.length != 1 || (data[0] != 0 && data[0] != 1)) {
      throw const FormatException('InternalVotesByTicket 必须是严格的 SCALE bool');
    }
    return data[0] == 1;
  }

  Uint8List _boundedText(String value, int maxBytes, String field) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    if (value != value.trim() || bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('$field 长度不合法');
    }
    return bytes;
  }

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}

// 编码并执行统一内部投票，核对当前签名人和准确执行事件。

/// 投票引擎统一投票入口服务。
///
/// - 所有业务 pallet(admins_change / resolution_destroy /
///   grandpakey_change / institution_multisig / transaction 业务)的
///   管理员一人一票一律走
///   `InternalVote::cast(proposal_id, ticket_claim, approve)` 一条路径。
/// - 业务 service(InstitutionChainService 等)
///   只负责发起提案(propose_X)；执行重试统一走 VotingEngine.retry_passed_proposal,
///   投票动作统一
///   委托本服务,避免多处构造相同的 call。
///
/// Runtime 位置: `pallet_index=20, call_index=0`(InternalVote sub-pallet)。
/// Call 编码: `[0x14][0x00][proposal_id:u128_le][ticket_claim][approve:bool]`。
class InternalVoteService {
  InternalVoteService({
    CitizenSdk? chain,
    ProposalQueryService Function(CitizenBlockRef block)? queryFactory,
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
  }) : _buildCall = buildCall ?? transactions?.buildCall ?? chain?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _queryFactory =
           queryFactory ??
           ((block) => ProposalQueryService(chain: chain, block: block)),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _executePreparedTransaction =
           executePreparedTransaction ??
           transactions?.executePreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置executePreparedTransaction')),
       _cancelPreparedTransactionExecution =
           cancelPreparedTransactionExecution ??
           transactions?.cancelPreparedTransactionExecution ??
           ((String executionId) =>
               throw StateError('未配置cancelPreparedTransactionExecution')),
       _consumePreparedTransactionQrResponse =
           consumePreparedTransactionQrResponse ??
           transactions?.consumePreparedTransactionQrResponse ??
           ((String executionId, String response) =>
               throw StateError('未配置consumePreparedTransactionQrResponse'));
  final CitizenCallBuilder _buildCall;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<CitizenTransactionExecution> Function(String preparationId)
  _executePreparedTransaction;
  final Future<void> Function(String executionId)
  _cancelPreparedTransactionExecution;
  final Future<CitizenTransactionExecutionCompleted> Function(
    String executionId,
    String response,
  )
  _consumePreparedTransactionQrResponse;

  final ProposalQueryService Function(CitizenBlockRef block) _queryFactory;

  // ──── 常量 ────

  /// InternalVote sub-pallet。runtime pallet_index=20。
  static const int internalVotePallet = PalletRegistry.internalVotePallet;

  /// InternalVote::cast call_index=0。
  static const int internalVoteCallIndex = PalletRegistry.internalVoteCastCall;

  // ──── 公开 API ────

  /// 提交 `InternalVote::cast(proposal_id, ticket_claim, approve)` extrinsic(pallet 20.0)。
  ///
  /// 投票提交必须等待交易进入区块。tx_hash 只代表交易已提交，
  /// 不能代表 runtime 已执行 `InternalVote::cast`。
  ///
  /// 返回交易哈希、runtime nonce 和最终执行块哈希。业务模块无需感知提案所属
  /// pallet/MODULE_TAG，投票引擎会按 ProposalData 前缀自动分派到对应
  /// `InternalVoteExecutor`；本次写入以同一 finalized 执行的准确事件证明，展示查询仍读取投票引擎 storage。
  Future<({String txHash, int usedNonce, String blockHash})> submit({
    required BigInt proposalId,
    required bool approve,
    String? actorCidNumber,
    String? voterRoleCode,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    if ((actorCidNumber == null) != (voterRoleCode == null)) {
      throw ArgumentError('机构CID与岗位码必须同时提供');
    }
    if (actorCidNumber != null &&
        (actorCidNumber != actorCidNumber.trim() ||
            utf8.encode(actorCidNumber).isEmpty ||
            utf8.encode(actorCidNumber).length > 32)) {
      throw ArgumentError('机构CID长度必须为1..32字节');
    }
    final callData = await buildCallData(
      buildCall: _buildCall,
      proposalId: proposalId,
      voterRoleCode: voterRoleCode,
      approve: approve,
    );
    final result = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmRuntimeVote(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      voterRoleCode: voterRoleCode,
      approve: approve,
      signerPublicKey: signerPublicKey,
      execution: result.execution,
    );
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  static Future<Uint8List> buildCallData({
    required CitizenCallBuilder buildCall,
    required BigInt proposalId,
    String? voterRoleCode,
    required bool approve,
  }) {
    if (proposalId.isNegative) throw ArgumentError('proposal_id不得为负');
    final CitizenScaleVariant ticket;
    if (voterRoleCode == null) {
      ticket = (variant: 'Personal', fields: const []);
    } else {
      final bytes = Uint8List.fromList(utf8.encode(voterRoleCode));
      if (voterRoleCode != voterRoleCode.trim() || bytes.isEmpty || bytes.length > 64) {
        throw ArgumentError('voter_role_code 超过 64 字节');
      }
      ticket = (variant: 'InstitutionRole', fields: [bytes]);
    }
    return buildCall('InternalVote', 'cast', [proposalId, ticket, approve]);
  }

  // ──── 内部：签名提交 ────

  Future<({String txHash, int usedNonce, CitizenExecution execution})>
  _executeFinalized({
    required Uint8List callData,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('投票签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '投票交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
  }

  /// runtime 事件中的 who 是当前签名账户；历史票据的 canonical 账户可能不同。
  /// 只接受本次 finalized 交易的唯一投票事件，不用当前公钥猜历史 storage 主键。
  Future<void> _confirmRuntimeVote({
    required BigInt proposalId,
    required CitizenExecution execution,
    required String? actorCidNumber,
    required String? voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
  }) async {
    final query = _queryFactory(execution.block);
    final events = await query.fetchExecutionEvents(execution);
    final matches = events
        .where(
          (event) =>
              event.pallet == 'InternalVote' &&
              event.name == 'InternalVoteCast',
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次内部投票事件');
    final event = matches.single;
    final fields = event.fields as Map<String, Object?>;
    if (event.fieldUnsigned('proposal_id') != proposalId ||
        fields['approve'] != approve ||
        _hexEncode(event.fieldBytes('who')) != _hexEncode(signerPublicKey) ||
        !ProposalQueryService.eventOptionalText(fields['voter_role_code'], voterRoleCode)) {
      throw StateError('内部投票事件与本次提案、签署人、岗位或方向不一致');
    }
    if (actorCidNumber != null) {
      final proposal = await query.fetchProposalMeta(proposalId);
      if (proposal?.actorCidNumber != actorCidNumber) {
        throw StateError('执行块提案所属机构与投票票据不一致');
      }
    }
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
