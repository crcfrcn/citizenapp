// 提案模型、上下文及能力目录。

import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/service.dart' show InstitutionChainService;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAssignment, InstitutionIdentity;
import 'package:citizen_citizen/institution/data.dart' show InstitutionInfo, OrgType;
import 'package:citizen_citizen/institution/data.dart' show findInstitutionByCidNumber;
import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteQueryService;
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;
import 'package:citizen_citizen/runtime/service.dart' show RuntimeUpgradeService;
import 'package:citizen_citizen/institution/data.dart' show InstitutionCodeLabel;

// 定义提案主键与展示号、元数据、冻结票据和业务详情。

/// 提案展示号（双层 ID 设计）。
///
/// 链上 `ProposalDisplayId[u128] = ProposalDisplayMeta { year: u32, seq_in_year: u64 }`
/// 反查表的客户端镜像。主键 `proposal_id` 全局单调与展示号解耦,渲染层基于
/// 本结构拼接 "2026000123" 类格式。
class ProposalDisplayMeta {
  const ProposalDisplayMeta({required this.year, required this.seqInYear});

  /// 创建年份(UTC 公历)。
  final int year;

  /// 年内序号(每年从 0 重置)。对应链上 u64，客户端以 BigInt 保留完整范围。
  final BigInt seqInYear;
}

/// 提案链上元数据（从 VotingEngine::Proposals Storage 解码）。
class ProposalMeta {
  const ProposalMeta({
    required this.proposalId,
    required this.kind,
    required this.stage,
    required this.status,
    this.internalCode,
    this.actorCidNumber,
    this.executionAccountId,
    this.subjectCidNumbers = const [],
    this.displayMeta,
  });

  final BigInt proposalId;
  final int kind; // 0=internal, 1=joint
  final int stage; // 0=internal, 1=joint, 2=citizen
  final int status; // 0=voting, 1=passed, 2=rejected
  final String? internalCode;

  /// 链上 Proposal.actor_cid_number，发起机构身份唯一真源。
  final String? actorCidNumber;

  /// 链上 Proposal.execution_account_id，仅表示具体资产账户或个人多签执行账户。
  final Uint8List? executionAccountId;

  /// 链上 Proposal.subject_cid_numbers，仅表示受影响机构，不替代发起机构 CID。
  final List<String> subjectCidNumbers;

  /// 展示号(双层 ID:主键 `proposal_id` 单调,展示号年份+序号通过 `ProposalDisplayId` 反查)。
  /// 列表页 batch fetch 后填充;详情页解码 ProposalMeta 时同步查询。
  final ProposalDisplayMeta? displayMeta;
}

/// 提案创建时冻结的一张投票票据。个人多签没有 CID/岗位码；机构票据三项齐全。
class EligibleVoterTicket {
  const EligibleVoterTicket({
    required this.voterAccountId,
    this.cidNumber,
    this.voterRoleCode,
    this.voterRoleName,
    this.personCid,
  });

  final String? voterAccountId;
  final String? personCid;
  final String? cidNumber;
  final String? voterRoleCode;

  /// 仅用于详情展示的岗位名称，不参与冻结资格、票据标识或签名。
  final String? voterRoleName;

  bool get isInstitution => cidNumber != null && voterRoleCode != null;

  String get ticketKey => isInstitution
      ? '${cidNumber!}:${voterRoleCode!}:${personCid ?? (throw StateError('机构票据缺少人员CID'))}'
      : 'personal:$voterAccountId';
}

/// Runtime upgrade 提案链上数据。
class RuntimeUpgradeProposalInfo {
  const RuntimeUpgradeProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.proposer,
    required this.reason,
    required this.codeHashHex,
    required this.expectedPowParamsHashHex,
    required this.paramsVersion,
    required this.algorithmVersion,
    required this.targetBlockTimeMs,
    required this.adjustmentInterval,
    required this.maxAdjustUpFactor,
    required this.maxAdjustDownDivisor,
  });

  final BigInt proposalId;
  final String actorCidNumber;
  final String proposer; // SS58 (ss58Format 走 citizenSs58Prefix 单源)
  final String reason; // UTF-8 decoded
  final String codeHashHex; // 32-byte hash as hex
  final String expectedPowParamsHashHex;
  final int paramsVersion;
  final int algorithmVersion;
  final int targetBlockTimeMs;
  final int adjustmentInterval;
  final int maxAdjustUpFactor;
  final int maxAdjustDownDivisor;
}

/// 提案 + 业务详情（用于全局提案列表与机构投票事件展示）。
class ProposalWithDetail {
  const ProposalWithDetail({
    required this.meta,
    this.runtimeUpgradeDetail,
    this.businessDetails = const {},
    this.resolutionIssuanceSummary,
    this.resolutionDestroySummary,
  });

  final ProposalMeta meta;

  /// 协议升级提案详情（非升级提案为 null）。
  final RuntimeUpgradeProposalInfo? runtimeUpgradeDetail;

  /// 业务模块详情集合。proposal/shared 只按字符串键保存不透明对象，
  /// 具体键名、模型和页面跳转由所属业务模块自己定义。
  final Map<String, Object?> businessDetails;

  /// 决议发行提案摘要（仅列表展示用）。
  final String? resolutionIssuanceSummary;

  /// 决议销毁提案摘要（仅列表展示用）。
  final String? resolutionDestroySummary;
}

// 以人员CID任职和同块钱包绑定解析机构资格，个人多签保持独立。

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

// 按机构主体及制度身份计算允许发起的提案能力。

/// 一种可发起的提案。
enum ProposalKind {
  transfer, // 转账(资金,proposal/transaction → MultisigTransferPage)
  feeTransfer, // 手续费划转/归集到主账户(资金,proposal/transaction → SweepToMainPage)
  safetyFundTransfer, // 安全基金转账(资金,仅国家储委会)
  adminsChange, // 跨业务动作标识，实际实现由所属业务包提供。
  resolutionIssuance, // 决议发行(占位)
  resolutionDestroy, // 决议销毁(占位)
  runtimeUpgrade, // 协议升级(类B,proposal/runtime-upgrade)
  grandpaKey, // 验证密钥(占位)
  legislation, // 发起立法/修法/废法(类B,proposal/legislation-yuan)
  election, // 发起选举(占位)
}

/// 发起提案的主体类型。它不是机构码的替代品,而是对机构码+账户身份的解析结果。
enum ProposalSubjectType {
  fixedGovernanceInstitution,
  publicInstitution,
  privateInstitution,
  unincorporatedInstitution,
}

/// 发起提案主体。
class ProposalSubject {
  const ProposalSubject({
    required this.subjectType,
    required this.orgCode,
    required this.entityPallet,
    this.cidNumber,
  });

  factory ProposalSubject.fromInstitution({
    required InstitutionInfo institution,
    required String orgCode,
  }) {
    final code = orgCode.toUpperCase();

    if (InstitutionCodeLabel.isFixedGovernance(code)) {
      return ProposalSubject(
        subjectType: ProposalSubjectType.fixedGovernanceInstitution,
        orgCode: code,
        entityPallet: 'PublicEntity',
        cidNumber: institution.cidNumber,
      );
    }
    if (InstitutionCodeLabel.isPublicEntityCode(code)) {
      return ProposalSubject(
        subjectType: ProposalSubjectType.publicInstitution,
        orgCode: code,
        entityPallet: 'PublicEntity',
        cidNumber: institution.cidNumber,
      );
    }
    if (InstitutionCodeLabel.isPrivateEntityCode(code)) {
      return ProposalSubject(
        subjectType: ProposalSubjectType.privateInstitution,
        orgCode: code,
        entityPallet: 'PrivateEntity',
        cidNumber: institution.cidNumber,
      );
    }
    if (InstitutionCodeLabel.isUnincorporated(code)) {
      return ProposalSubject(
        subjectType: ProposalSubjectType.unincorporatedInstitution,
        orgCode: code,
        // 非法人机构码本身不能决定 public/private 管理员模块。
        entityPallet: 'Unresolved',
        cidNumber: institution.cidNumber,
      );
    }
    return ProposalSubject(
      subjectType: ProposalSubjectType.publicInstitution,
      orgCode: code,
      entityPallet: 'PublicEntity',
      cidNumber: institution.cidNumber,
    );
  }

  final ProposalSubjectType subjectType;
  final String orgCode;
  final String entityPallet;

  /// 机构主体唯一主键。
  final String? cidNumber;

  bool get isFixedGovernance =>
      subjectType == ProposalSubjectType.fixedGovernanceInstitution;
  bool get isUnincorporated =>
      subjectType == ProposalSubjectType.unincorporatedInstitution;
  bool get hasResolvedEntityPallet => entityPallet != 'Unresolved';
}

class ProposalCapability {
  const ProposalCapability({
    required this.kind,
    required this.enabled,
    required this.pallet,
    required this.call,
    required this.voteEngine,
    required this.allows,
  });

  final ProposalKind kind;
  final bool enabled;
  final String pallet;
  final String call;
  final String voteEngine;
  final bool Function(ProposalSubject subject) allows;
}

class ProposalCapabilityRegistry {
  const ProposalCapabilityRegistry._();

  static const Set<String> _jointGovernanceCodes = {'NRC', 'PRC'};
  static const Set<String> _destroyGovernanceCodes = {'NRC', 'PRC', 'PRB'};
  static const Set<String> _sweepCodes = {'NRC', 'PRB'};
  static const Set<String> _legislationProposerCodes = {
    'NRP',
    'NED',
    'PRP',
    'CLEG',
    'CSLF',
    'CEDU',
  };

  static final List<ProposalCapability> _capabilities = [
    ProposalCapability(
      kind: ProposalKind.transfer,
      enabled: true,
      pallet: 'Multisig',
      call: 'propose_transfer',
      voteEngine: 'InternalVote',
      allows: (subject) => true,
    ),
    ProposalCapability(
      kind: ProposalKind.feeTransfer,
      enabled: true,
      pallet: 'Multisig',
      call: 'propose_sweep_to_main',
      voteEngine: 'InternalVote',
      allows: (subject) => _sweepCodes.contains(subject.orgCode),
    ),

    ProposalCapability(
      kind: ProposalKind.safetyFundTransfer,
      enabled: true,
      pallet: 'Multisig',
      call: 'propose_safety_fund_transfer',
      voteEngine: 'InternalVote',
      allows: (subject) => subject.orgCode == 'NRC',
    ),
    ProposalCapability(
      kind: ProposalKind.resolutionIssuance,
      enabled: true,
      pallet: 'ResolutionIssue',
      call: 'propose_issuance',
      voteEngine: 'JointVote',
      allows: (subject) => _jointGovernanceCodes.contains(subject.orgCode),
    ),
    ProposalCapability(
      kind: ProposalKind.resolutionDestroy,
      enabled: true,
      pallet: 'Destroy',
      call: 'propose_destroy',
      voteEngine: 'InternalVote',
      allows: (subject) => _destroyGovernanceCodes.contains(subject.orgCode),
    ),
    ProposalCapability(
      kind: ProposalKind.runtimeUpgrade,
      enabled: true,
      pallet: 'Upgrade',
      call: 'propose_runtime_upgrade',
      voteEngine: 'JointVote',
      allows: (subject) => _jointGovernanceCodes.contains(subject.orgCode),
    ),
    ProposalCapability(
      kind: ProposalKind.grandpaKey,
      enabled: true,
      pallet: 'GrandpaKey',
      call:
          'schedule_grandpa_key_rotation/propose_emergency_grandpa_key_recovery',
      voteEngine: 'Normal=None;Emergency=InternalVote',
      allows: (subject) => _jointGovernanceCodes.contains(subject.orgCode),
    ),
    ProposalCapability(
      kind: ProposalKind.legislation,
      enabled: true,
      pallet: 'Legislation',
      call: 'propose_enact_law/propose_amend_law/propose_repeal_law',
      voteEngine: 'LegislationVote',
      allows: (subject) => _legislationProposerCodes.contains(subject.orgCode),
    ),
    ProposalCapability(
      kind: ProposalKind.election,
      enabled: false,
      pallet: '具体公权选举业务模块尚未接入',
      call: '未开放',
      voteEngine: 'ElectionVote',
      allows: (_) => false,
    ),
  ];

  /// 返回主体当前可展示的提案能力。禁用能力不展示,避免产生假入口。
  static List<ProposalCapability> capabilitiesForSubject(
    ProposalSubject subject,
  ) {
    return _capabilities
        .where((capability) => capability.enabled && capability.allows(subject))
        .toList(growable: false);
  }
}
