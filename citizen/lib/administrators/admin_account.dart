// 业务含义与Rust管理员结构统一；Dart成员用camelCase，JSON键沿所属接口。

import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/administrators/account_id_codec.dart';

enum AdminAccountIdentityType { institution, personalAccount }

/// 全仓统一的管理员人员记录。
///
/// `account_id` 是人员记录唯一标识与去重字段；姓、名只用于人员姓名展示，
/// 页面需要姓名时现场按中文顺序组合，不保存合并姓名。机构业务授权必须另查
/// `CID + 岗位码`，个人多签才直接以管理员集合授权。
class AdminPerson {
  const AdminPerson({
    required this.accountId,
    this.cidNumber = '',
    required this.familyName,
    required this.givenName,
  });

  final String accountId;

  /// 所有机构管理员均保存公民 CID；个人多签不是机构，其管理员固定为空。
  final String cidNumber;
  final String familyName;
  final String givenName;

  AdminPerson copyWith({
    String? accountId,
    String? cidNumber,
    String? familyName,
    String? givenName,
  }) => AdminPerson(
    accountId: accountId ?? this.accountId,
    cidNumber: cidNumber ?? this.cidNumber,
    familyName: familyName ?? this.familyName,
    givenName: givenName ?? this.givenName,
  );
}

/// 管理员查询主体。机构只以 CID 为主键；个人多签只以 personal_account 为主键。
class AdminAccountIdentity {
  const AdminAccountIdentity._({
    required this.type,
    required this.identityKey,
    required this.accountLabel,
    required this.orgCode,
    required this.kind,
    this.cidNumber,
    this.accountId,
  });

  factory AdminAccountIdentity.fromInstitution(InstitutionInfo institution) {
    final personal = personalAccountIdFromIdentity(institution.cidNumber);
    if (personal != null) {
      return AdminAccountIdentity.personalAccount(
        accountId: personal,
        accountLabel: institution.shortName,
      );
    }
    final code =
        institution.adminCode?.toUpperCase() ??
        switch (institution.orgType) {
          0 => 'NRC',
          1 => 'PRC',
          2 => 'PRB',
          _ => throw ArgumentError('机构管理员查询必须提供 institutionCode'),
        };
    return AdminAccountIdentity.institution(
      cidNumber: institution.cidNumber,
      orgCode: code,
      accountLabel: institution.shortName,
    );
  }

  factory AdminAccountIdentity.institution({
    required String cidNumber,
    required String orgCode,
    required String accountLabel,
    int? kind,
  }) {
    final cid = cidNumber.trim();
    if (cid.isEmpty) throw ArgumentError('机构 cidNumber 不能为空');
    final normalizedCode = orgCode.toUpperCase();
    if (!InstitutionCodeLabel.isInstitution(normalizedCode) &&
        !InstitutionCodeLabel.isFixedGovernance(normalizedCode)) {
      throw ArgumentError('institutionCode 必须是机构码: $orgCode');
    }
    final resolvedKind = kind ?? _deriveInstitutionKind(normalizedCode);
    return AdminAccountIdentity._(
      type: AdminAccountIdentityType.institution,
      identityKey: 'institution:$cid',
      accountLabel: accountLabel,
      orgCode: normalizedCode,
      kind: resolvedKind,
      cidNumber: cid,
    );
  }

  factory AdminAccountIdentity.personalAccount({
    required String accountId,
    required String accountLabel,
  }) {
    final account = AdminAccountIdCodec.requireAccountId(accountId);
    AdminAccountIdCodec.fromAccountIdText(account);
    return AdminAccountIdentity._(
      type: AdminAccountIdentityType.personalAccount,
      identityKey: 'personal-account:$account',
      accountLabel: accountLabel,
      orgCode: 'PMUL',
      kind: 2,
      accountId: account,
    );
  }

  static int _deriveInstitutionKind(String orgCode) {
    if (InstitutionCodeLabel.isUnincorporatedAdminCode(orgCode)) {
      throw ArgumentError('非法人机构码必须显式传入所属法人 kind');
    }
    return InstitutionCodeLabel.adminAccountKind(orgCode);
  }

  final AdminAccountIdentityType type;
  final String identityKey;
  final String accountLabel;
  final String orgCode;
  final int kind;
  final String? cidNumber;
  final String? accountId;

  String get typeLabel => switch (type) {
    AdminAccountIdentityType.institution => '机构',
    AdminAccountIdentityType.personalAccount => '个人多签',
  };

  String get orgLabel => InstitutionCodeLabel.codeLabel(orgCode);
}

class AdminAccountState {
  const AdminAccountState({
    this.cidNumber,
    this.accountId,
    required this.orgCode,
    required this.kind,
    required this.admins,
    required this.threshold,
    this.personalCreatorAccountId,
    this.personalCreatedAt,
    this.personalUpdatedAt,
    this.personalStatus,
  }) : assert((cidNumber == null) != (accountId == null));

  final String? cidNumber;
  final String? accountId;
  final String orgCode;
  final int kind;
  final List<AdminPerson> admins;
  final int threshold;

  /// 以下字段只属于 PersonalAdmins 的个人多签生命周期。
  final String? personalCreatorAccountId;
  final int? personalCreatedAt;
  final int? personalUpdatedAt;
  final int? personalStatus;

  bool get isActive => cidNumber != null || personalStatus == 1;

  AdminAccountState copyWith({int? threshold}) => AdminAccountState(
    cidNumber: cidNumber,
    accountId: accountId,
    orgCode: orgCode,
    kind: kind,
    admins: admins,
    threshold: threshold ?? this.threshold,
    personalCreatorAccountId: personalCreatorAccountId,
    personalCreatedAt: personalCreatedAt,
    personalUpdatedAt: personalUpdatedAt,
    personalStatus: personalStatus,
  );

  String get kindLabel => switch (kind) {
    0 => '公权机构',
    1 => '私权机构',
    2 => '个人多签',
    _ => '未知账户',
  };

  String get orgLabel => InstitutionCodeLabel.codeLabel(orgCode);

  String get statusLabel {
    if (cidNumber != null) return '机构管理员';
    return switch (personalStatus) {
      0 => '待激活',
      1 => '已激活',
      2 => '已关闭',
      _ => '未知状态',
    };
  }
}
