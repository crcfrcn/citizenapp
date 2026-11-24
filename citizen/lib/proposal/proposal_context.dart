// 以人员CID任职和同块钱包绑定解析机构资格，个人多签保持独立。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/institution/governance_registry.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';

/// 钱包只承接当前有效人员绑定，不从激活缓存获得机构权限。
class ProposalContext {
  const ProposalContext({
    this.institution,
    this.adminWallets = const [],
    this.assignments = const {},
    this.role = ProposalRole.viewer,
  });
  final InstitutionInfo? institution;
  final List<CitizenWalletStateAccount> adminWallets;
  final Map<String, List<InstitutionAssignment>> assignments;
  final ProposalRole role;
  bool get hasInstitutionContext => institution != null;
  bool get isAdmin => role == ProposalRole.admin;
  bool get isCitizen => role == ProposalRole.citizen || isAdmin;
  bool get hasAdminWallets => adminWallets.isNotEmpty;
}

enum ProposalRole { admin, citizen, viewer }

/// 每次解析重新读取最终块任职和当前钱包目录，不保存资格缓存。
class ProposalContextResolver {
  ProposalContextResolver({
    CitizenSdk? wallet,
    required InstitutionChainService institutionService,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
  }) : _institutionService = institutionService,
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置钱包目录'));
  final InstitutionChainService _institutionService;
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  Future<ProposalContext> resolve({
    String? actorCidNumber,
    List<int>? executionAccountId,
    String? internalCode,
    InstitutionInfo? knownInstitution,
  }) async {
    final cid = actorCidNumber;
    if (cid == null || cid.isEmpty || cid != cid.trim()) {
      return const ProposalContext();
    }
    final institution = knownInstitution?.cidNumber == cid
        ? knownInstitution
        : findInstitutionByCidNumber(cid);
    if (institution == null) return const ProposalContext();
    final wallet = await _getWalletState().result;
    if (wallet.accounts.isEmpty) {
      return ProposalContext(institution: institution);
    }
    final runtime = await _institutionService.finalizedRuntime();
    final identity = InstitutionIdentity.fromInstitution(institution);
    final assignments = await _institutionService.walletAssignments(
      identity,
      wallet.accounts.map((account) => account.accountId),
      at: runtime,
    );
    final current = await _getWalletState().result;
    if (current.revision != wallet.revision) {
      throw StateError('任职读取期间钱包目录已变化');
    }
    final matches = wallet.accounts
        .where((account) => assignments.containsKey(account.accountId))
        .toList(growable: false);
    return ProposalContext(
      institution: institution,
      adminWallets: matches,
      assignments: assignments,
      role: matches.isEmpty ? ProposalRole.viewer : ProposalRole.admin,
    );
  }

  Future<List<ProposalContext>> resolveBatch(
    List<String?> actorCidNumbers, {
    List<List<int>?>? executionAccountIds,
    List<String?>? internalCodeList,
    Map<String, InstitutionInfo> knownInstitutionsByCidNumber = const {},
  }) async => [
    for (var i = 0; i < actorCidNumbers.length; i++)
      await resolve(
        actorCidNumber: actorCidNumbers[i],
        knownInstitution: knownInstitutionsByCidNumber[actorCidNumbers[i]],
      ),
  ];
}

/// 统一投票状态检查器。
///
/// 根据提案类型（kind）和阶段（stage）自动选择正确的链上存储查询，
/// 避免不同入口查错存储导致的状态不一致。
class VoteChecker {
  VoteChecker({
    required InternalVoteQueryService internalVoteService,
    required RuntimeUpgradeService runtimeService,
    required ProposalQueryService proposalQueryService,
  }) : _internalVoteService = internalVoteService,
       _runtimeService = runtimeService,
       _proposalQueryService = proposalQueryService;

  final InternalVoteQueryService _internalVoteService;
  final RuntimeUpgradeService _runtimeService;
  final ProposalQueryService _proposalQueryService;

  /// 跨提案批量计算"哪些提案存在本机未投票的管理员钱包"。
  ///
  /// (ADR-018 R2):列表页原来按提案逐个查投票(P 个提案 = P 次往返);
  /// 这里把同类提案(内部/联合)的投票 key 各自一次性拼齐批量读取,P 次往返
  /// 降为最多 2 次。只统计 status==0(投票中)且本机有管理员钱包的提案。
  Future<Set<BigInt>> proposalsNeedingVote(
    List<VoteCheckTarget> targets,
  ) async {
    final active = targets.where(
      (t) => t.status == 0 && t.adminWallets.isNotEmpty,
    );

    final internalByPid = <BigInt, List<EligibleVoterTicket>>{};
    final jointByPid =
        <
          BigInt,
          ({
            String actorCidNumber,
            String voterRoleCode,
            List<String> personCids,
          })
        >{};
    for (final t in active) {
      final accountIds = t.adminWallets.map((w) => w.accountId).toList();
      if (t.kind == 0 && t.institution != null) {
        final localAccountIds = accountIds.map(_requireAccountId).toSet();
        final tickets = await _proposalQueryService.fetchEligibleVoterTickets(
          t.proposalId,
          t.institution!,
        );
        internalByPid[t.proposalId] = tickets
            .where((ticket) => localAccountIds.contains(ticket.voterAccountId))
            .toList(growable: false);
      } else if (t.kind == 1 && t.institution != null) {
        final tickets = await _proposalQueryService.fetchEligibleVoterTickets(
          t.proposalId,
          t.institution!,
        );
        jointByPid[t.proposalId] = (
          actorCidNumber: t.institution!.cidNumber,
          voterRoleCode: t.institution!.orgType == OrgType.prb
              ? 'DIRECTOR'
              : 'COMMITTEE_MEMBER',
          personCids: tickets
              .where((ticket) => accountIds.contains(ticket.voterAccountId))
              .map((ticket) => ticket.personCid!)
              .toList(growable: false),
        );
      }
    }

    final needs = <BigInt>{};
    if (internalByPid.isNotEmpty) {
      final votes = await _internalVoteService.fetchTicketVotesForProposals(
        internalByPid,
      );
      internalByPid.forEach((pid, tickets) {
        final m = votes[pid] ?? const <String, bool?>{};
        if (tickets.any((ticket) => m[ticket.ticketKey] == null)) {
          needs.add(pid);
        }
      });
    }
    if (jointByPid.isNotEmpty) {
      final votes = await _runtimeService.fetchJointTicketVotesForProposals(
        jointByPid,
      );
      jointByPid.forEach((pid, v) {
        final m = votes[pid] ?? const <String, bool?>{};
        if (v.personCids.any((personCid) => m[personCid] == null)) {
          needs.add(pid);
        }
      });
    }
    return needs;
  }

  static String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}

/// [VoteChecker.proposalsNeedingVote] 的输入项:一个提案的投票判定所需上下文。
class VoteCheckTarget {
  const VoteCheckTarget({
    required this.proposalId,
    required this.kind,
    required this.status,
    required this.adminWallets,
    this.institution,
  });

  final BigInt proposalId;
  final int kind;
  final int status;
  final List<CitizenWalletStateAccount> adminWallets;
  final InstitutionInfo? institution;
}
