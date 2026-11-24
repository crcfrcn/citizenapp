// 定义机构岗位、任职、业务权限及投票计划的链协议模型。

import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';

/// 机构岗位状态，序号与 entity runtime 枚举一致。
enum InstitutionRoleStatus { active, inactive }

/// 岗位对一个业务动作拥有的权限操作，序号与 runtime SCALE 枚举一致。
enum RolePermissionOperation { propose, vote }

/// 业务模块静态指定的投票引擎，序号与 runtime SCALE 枚举一致。
enum VotingEngineKind { internal, joint, election, legislation }

/// 完整机构岗位授权主体；CID 和岗位码缺一不可。
class RoleSubject {
  const RoleSubject({required this.cidNumber, required this.roleCode});

  final String cidNumber;
  final String roleCode;
}

/// 业务模块与模块内动作的稳定标识。
class BusinessActionId {
  const BusinessActionId({required this.moduleTag, required this.actionCode});

  final String moduleTag;
  final int actionCode;
}

/// 一条完整岗位业务权限。
class RoleBusinessPermission {
  const RoleBusinessPermission({
    required this.roleSubject,
    required this.businessActionId,
    required this.operation,
  });

  final RoleSubject roleSubject;
  final BusinessActionId businessActionId;
  final RolePermissionOperation operation;
}

/// 机构岗位或个人多签授权主体。
///
/// 两个字段只允许存在其一；构造器固定分支，避免调用方混合主体。
class AuthorizationSubject {
  const AuthorizationSubject.institution(this.roleSubject) : accountId = null;

  const AuthorizationSubject.personalMultisig(this.accountId)
    : roleSubject = null;

  final RoleSubject? roleSubject;
  final String? accountId;

  bool get isInstitution => roleSubject != null;
}

/// 业务模块创建提案时绑定的投票计划。
class VotePlan {
  const VotePlan({
    required this.businessActionId,
    required this.proposalOwner,
    required this.proposerSubject,
    required this.voterSubjects,
    required this.votingEngine,
    required this.businessObjectHash,
  });

  final BusinessActionId businessActionId;
  final String proposalOwner;
  final AuthorizationSubject proposerSubject;
  final List<AuthorizationSubject> voterSubjects;
  final VotingEngineKind votingEngine;
  final String businessObjectHash;
}

/// 管理员任职来源，序号与 entity runtime 枚举一致。
enum InstitutionAssignmentSource {
  genesis,
  registry,
  popularElection,
  mutualElection,
  nominationAppointment,
  institutionGovernance,
}

extension InstitutionAssignmentSourceLabel on InstitutionAssignmentSource {
  String get label => switch (this) {
    InstitutionAssignmentSource.genesis => '创世',
    InstitutionAssignmentSource.registry => '注册局',
    InstitutionAssignmentSource.popularElection => '普选',
    InstitutionAssignmentSource.mutualElection => '互选',
    InstitutionAssignmentSource.nominationAppointment => '提名任免',
    InstitutionAssignmentSource.institutionGovernance => '机构内部治理',
  };
}

/// 机构岗位定义；岗位只在所属机构 CID 内唯一。
class InstitutionRole {
  const InstitutionRole({
    required this.cidNumber,
    required this.roleCode,
    required this.roleName,
    required this.termRequired,
    required this.status,
    required this.seats,
  });

  final String cidNumber;
  final String roleCode;
  final String roleName;
  final bool termRequired;
  final InstitutionRoleStatus status;
  final int seats;
}

/// 管理员钱包与机构岗位的一条任职关系。
class InstitutionAssignment {
  const InstitutionAssignment({
    required this.cidNumber,
    required this.personCid,
    required this.roleCode,
    required this.termStart,
    required this.termEnd,
    required this.source,
    required this.sourceRef,
    required this.active,
    this.roleName = '',
    this.termRequired = false,
  });

  final String cidNumber;
  final String personCid;
  final String roleCode;
  final String roleName;
  final bool termRequired;
  final int termStart;
  final int termEnd;
  final InstitutionAssignmentSource source;
  final String sourceRef;
  final bool active;

  /// 日序只用于链上比较；展示统一转换为 UTC 公历日期。
  String get termLabel {
    if (!termRequired) return '无固定任期';
    if (termStart == 0 && termEnd == 0) return '待写入';
    String day(int value) {
      if (value == 0) return '—';
      final date = DateTime.fromMillisecondsSinceEpoch(
        value * Duration.millisecondsPerDay,
        isUtc: true,
      );
      return '${date.year.toString().padLeft(4, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return '${day(termStart)}-${day(termEnd)}';
  }

  /// 与 runtime 一致按 UTC 纪元日判断有效任职；起止日均包含在任期内。
  bool isEffectiveOnDay(int currentDay) {
    if (!active) return false;
    if (!termRequired) return termStart == 0 && termEnd == 0;
    return termStart > 0 && termStart <= currentDay && currentDay <= termEnd;
  }

  InstitutionAssignment withRole(InstitutionRole role) => InstitutionAssignment(
    cidNumber: cidNumber,
    personCid: personCid,
    roleCode: roleCode,
    roleName: role.roleName,
    termRequired: role.termRequired,
    termStart: termStart,
    termEnd: termEnd,
    source: source,
    sourceRef: sourceRef,
    active: active,
  );
}

/// 机构查询主体仅保存机构CID及所属公私权类别，不保存独立管理员钱包。
class InstitutionIdentity {
  const InstitutionIdentity({
    required this.cidNumber,
    required this.orgCode,
    this.kind,
    this.accountLabel = '',
  });
  factory InstitutionIdentity.fromInstitution(InstitutionInfo institution) =>
      InstitutionIdentity(
        cidNumber: institution.cidNumber,
        orgCode:
            institution.adminCode ??
            switch (institution.orgType) {
              0 => 'NRC',
              1 => 'PRC',
              2 => 'PRB',
              _ => throw ArgumentError('机构缺少机构码'),
            },
        kind: institution.adminCode == null
            ? 0
            : InstitutionCodeLabel.isUnincorporated(institution.adminCode!)
            ? null
            : InstitutionCodeLabel.entityKind(institution.adminCode!),
        accountLabel: institution.shortName,
      );
  final String cidNumber;
  final String orgCode;
  final int? kind;
  final String accountLabel;
  String get pallet => switch (kind) {
    0 => 'PublicEntity',
    1 => 'PrivateEntity',
    _ => throw StateError('机构所属公私权类别尚未查链'),
  };
}

/// 同一人员在一个机构的有效任职；当前钱包只是同块链上解析结果。
class InstitutionPersonView {
  const InstitutionPersonView({
    required this.personCid,
    required this.accountId,
    required this.assignments,
  });
  final String personCid;
  final String? accountId;
  final List<InstitutionAssignment> assignments;
}
