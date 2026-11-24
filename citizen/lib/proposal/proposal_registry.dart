// 按机构主体及制度身份计算允许发起的提案能力。

import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';

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
