// 定义机构和多签共用资料、账户集合及公开身份编码工具。

library;

import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';

/// 提案展示号格式化（双层 ID）：`2026000123` 风格。
///
/// 主键 `proposal_id` 是全局单调 u128,与展示无关。展示号由链上
/// `ProposalDisplayId[id] = ProposalDisplayMeta { year, seq_in_year }`
/// 反查得到,本函数把它拼成纯数字字符串(年份 + 6 位补零序号)。
///
/// 当 `seq_in_year` 突破 6 位(>=1_000_000)时自动扩展到 7、8 位等,
/// 不会截断。
String formatProposalId(ProposalDisplayMeta? meta) {
  if (meta == null) return '—';
  final seq = meta.seqInYear.toString().padLeft(6, '0');
  return '${meta.year}$seq';
}

class OrgType {
  OrgType._();

  /// 国家储委会 National Reserve Committee
  static const int nrc = 0;

  /// 省储委会 Provincial Reserve Committee
  static const int prc = 1;

  /// 省储行 Provincial Reserve Bank
  static const int prb = 2;

  /// 其它机构（包括注册机构与非储备类固定治理机构）。
  static const int institution = 3;

  static String label(int orgType) {
    switch (orgType) {
      case nrc:
        return '国家储委会';
      case prc:
        return '省储委会';
      case prb:
        return '省储行';
      case institution:
        return '机构';
      default:
        return '未知';
    }
  }
}

/// 治理机构及多签账户的制度账户集合。
///
/// 内置治理机构没有笼统的 `account`；链端按主账户、费用账户、
/// 国家储委会安全基金/两和基金账户、省储行永久质押账户分别建模。
/// 所有机构强制具有主账户与费用账户；个人多签不使用本类型。
class InstitutionAccounts {
  const InstitutionAccounts({
    required this.mainAccountId,
    required this.feeAccountId,
    this.safetyFundAccountId,
    this.heAccountId,
    this.stakeAccountId,
  });

  /// 主账户 AccountId（ADR-040 规范形式：小写 `0x` + 64 位十六进制）。
  final String mainAccountId;

  /// 费用账户 AccountId hex；所有机构强制存在。
  final String feeAccountId;

  /// 安全基金账户 AccountId hex；仅国家储委会存在。
  final String? safetyFundAccountId;

  /// 两和基金账户 hex（Reconciliation Fund，链端 NRC_HE_ACCOUNT）；仅国家储委会存在。
  final String? heAccountId;

  /// 永久质押账户 AccountId hex；仅省储行存在。
  final String? stakeAccountId;
}

/// 单个机构或多签账户的结构化信息。
class InstitutionInfo {
  const InstitutionInfo({
    required this.fullName,
    required this.shortName,
    required this.cidFullNameEn,
    required this.cidShortNameEn,
    required this.cidNumber,
    required this.orgType,
    required this.accounts,
    this.adminCode,
    this.internalThresholdOverride,
  });

  /// 机构全称,与后端/链端 `cid_full_name` 对齐。
  final String fullName;

  /// 机构简称,与后端/链端 `cid_short_name` 对齐。
  final String shortName;

  /// 机构英文全称,与后端/链端 `cid_full_name_en` 对齐。
  final String cidFullNameEn;

  /// 机构英文简称,与后端/链端 `cid_short_name_en` 对齐。
  final String cidShortNameEn;

  /// 链上机构身份唯一主键（与 Rust `cid_number` 完全一致）。
  /// 任何主/费/安全基金/两和基金/质押/自定义账户都不得替代本字段。
  final String cidNumber;

  /// 机构类型：0=NRC, 1=PRC, 2=PRB。
  final int orgType;

  /// 注册机构账户管理员更换使用的机构码（如 "CGOV"/"CGOV" 等注册机构 CID 码）。
  final String? adminCode;

  /// 制度账户集合。
  ///
  /// 所有机构使用完整账户集合；个人多签不使用本字段。
  final InstitutionAccounts accounts;

  /// 机构资金操作的默认主账户。
  /// 本字段只是账户参数，不得替代机构 `cid_number`。
  String get mainAccountId => accounts.mainAccountId;

  /// 机构账户的动态阈值覆盖。
  final int? internalThresholdOverride;

  /// 是否为链上注册机构。个人多签不属于机构。
  bool get isRegisteredInstitution =>
      orgType == OrgType.institution &&
      !InstitutionCodeLabel.isFixedGovernance(adminCode ?? '');

  /// 内部投票通过阈值。
  int get internalThreshold {
    if (internalThresholdOverride != null) return internalThresholdOverride!;
    final fixedByCode = InstitutionCodeLabel.fixedGovernanceThreshold(
      adminCode ?? '',
    );
    if (fixedByCode != null) return fixedByCode;
    switch (orgType) {
      case OrgType.nrc:
        return 13;
      case OrgType.prc:
        return 6;
      case OrgType.prb:
        return 6;
      case OrgType.institution:
        return 0;
      default:
        return 0;
    }
  }

  /// 联合投票中的机构权重。
  int get jointVoteWeight {
    switch (orgType) {
      case OrgType.nrc:
        return 19;
      case OrgType.prc:
      case OrgType.prb:
        return 1;
      default:
        return 0;
    }
  }

  InstitutionInfo copyWith({
    String? fullName,
    String? shortName,
    String? cidFullNameEn,
    String? cidShortNameEn,
    String? cidNumber,
    int? orgType,
    InstitutionAccounts? accounts,
    String? adminCode,
    int? internalThresholdOverride,
  }) {
    return InstitutionInfo(
      fullName: fullName ?? this.fullName,
      shortName: shortName ?? this.shortName,
      cidFullNameEn: cidFullNameEn ?? this.cidFullNameEn,
      cidShortNameEn: cidShortNameEn ?? this.cidShortNameEn,
      cidNumber: cidNumber ?? this.cidNumber,
      orgType: orgType ?? this.orgType,
      accounts: accounts ?? this.accounts,
      adminCode: adminCode ?? this.adminCode,
      internalThresholdOverride:
          internalThresholdOverride ?? this.internalThresholdOverride,
    );
  }
}
