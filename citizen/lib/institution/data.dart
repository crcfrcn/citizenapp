// 机构、账户、角色及治理目录模型。

library ;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user.dart' as app_store show Entity;
import 'dart:typed_data';
import 'package:citizen_citizen/data.dart' show deriveInstitutionAccountIdByName, deriveInstitutionFeeAccountId, deriveInstitutionMainAccountId;
import 'package:citizen_citizen/proposal/data.dart' show ProposalDisplayMeta;
import 'package:citizen_citizen/institution/service.dart' show InstitutionChainService;
import 'package:citizen_multisig/proposal.dart' show MultisigTransferProposalFeed;
import 'package:citizen_multisig/service.dart' show MultisigTransferService;
import 'package:citizen_citizen/data.dart' show kReservedNameFee, kReservedNameHe, kReservedNameMain, kReservedNameSafetyFund, kReservedNameStake;
import 'dart:convert';
part 'registry.generated.dart';

// 统一表示按CID分类的机构资料及固定治理账户。

// 统一机构实体(ADR-028 决策 2)——合并公权 `entity` 与治理
// `InstitutionInfo` 两套并行模型为一套。
//
//
// - 所有机构本质都是按 CID `institution_code` 分类的公权多签账户,差异只在权责。
//   本实体是五子 tab(广场/立法/选举/治理/公权)与统一详情页的唯一机构模型。
// - 身份字段来自 finalized 链快照目录 + Isar;创世治理机构的固定账户 hex
//   由 [builtinAccounts] 承载(china 创世常量,不可派生),其余机构主/费/自定义账户
//   一律本地派生(account_derivation,零网络)。
// - 机构分类(是否固定治理 / 是否机构账户)统一从机构码派生,
//   单一源 = `citizen/institution/institution_code_label.dart`,绝不另立第二套。

/// 单个机构的统一信息载体(不可变)。
class Institution {
  const Institution({
    required this.cidNumber,
    required this.fullName,
    required this.orgCode,
    this.shortName,
    this.status = 'ACTIVE',
    this.provinceCode = '',
    this.cityCode = '',
    this.townCode = '',
    this.parentCid,
    this.familyName,
    this.givenName,
    this.legalCid,
    this.legalAccount,
    this.accountCount = 0,
    this.accountNames = const [],
    this.builtinAccounts,
  });

  /// 链上身份标识(CID 号,机构码内含于第二段)。
  final String cidNumber;

  /// 机构全称(与链端 `cid_full_name` 对齐)。
  final String fullName;

  /// 机构简称(与链端 `cid_short_name` 对齐;可空,展示回退全称)。
  final String? shortName;

  /// 机构码(CID 号第二段,如 NRC/PRC/PRB/CGOV/NLG…)。机构分类唯一依据。
  final String orgCode;

  final String status;

  /// 所属省/市/镇 code(行政区唯一真源键;名字由字典 join,见 ADR-021)。
  final String provinceCode;
  final String cityCode;
  final String townCode;

  /// 所属上级法人 CID 号(仅非法人 UNIN 机构有值;法人为 null)。
  final String? parentCid;

  /// 法定代表人的姓、名(公开目录字段,无则详情页留空)。
  final String? familyName;
  final String? givenName;
  final String? legalCid;
  final String? legalAccount;

  final int accountCount;
  final List<String> accountNames;

  /// 创世治理机构的链上固定账户集合(china 创世常量,不可派生)。
  /// 普通机构为 null —— 账户走本地派生。由仓库在加载创世治理机构时附加。
  final InstitutionAccounts? builtinAccounts;

  /// 储备治理三档旧 UI 类型;其它机构统一返回 account,真实分类看 org_code。
  int get orgType {
    switch (orgCode) {
      case 'NRC':
        return OrgType.nrc;
      case 'PRC':
        return OrgType.prc;
      case 'PRB':
        return OrgType.prb;
      default:
        return OrgType.institution;
    }
  }

  /// 是否链端固定治理档。
  bool get isFixedGovernance => InstitutionCodeLabel.isFixedGovernance(orgCode);

  /// 是否非法人机构(挂上级法人;详情页加显「所属上级法人全称」)。
  bool get isUnincorporated => parentCid != null && parentCid!.isNotEmpty;

  /// 详情页顶部标题用:简称优先,回退全称,只取 cid_short_name/cid_full_name。
  String get cidShortNameOrFullName =>
      (shortName != null && shortName!.isNotEmpty) ? shortName! : fullName;

  /// 主账户 AccountId:创世治理机构用 china 固定 hex,其余本地派生。
  Uint8List mainAccountIdBytes() {
    final baked = builtinAccounts?.mainAccountId;
    if (baked != null && baked.isNotEmpty) {
      return citizenAccountIdBytes(baked);
    }
    return deriveInstitutionMainAccountId(cidNumber);
  }

  /// 主账户 ID（小写 `0x` + 64 位 hex）。
  String get mainAccountId => citizenAccountIdFromBytes(mainAccountIdBytes());

  /// 附加创世固定账户集合。
  Institution withBuiltinAccounts(InstitutionAccounts accounts) => Institution(
    cidNumber: cidNumber,
    fullName: fullName,
    orgCode: orgCode,
    shortName: shortName,
    status: status,
    provinceCode: provinceCode,
    cityCode: cityCode,
    townCode: townCode,
    parentCid: parentCid,
    familyName: familyName,
    givenName: givenName,
    legalCid: legalCid,
    legalAccount: legalAccount,
    accountCount: accountCount,
    accountNames: accountNames,
    builtinAccounts: accounts,
  );

  /// 由创世静态账户项构造(回退路径:目录未同步时仍可展示)。
  /// 地域 code 注册表项不带,留空 → 所属地按目录就绪后回填;账户用 baked 集合。
  factory Institution.fromGovernanceInfo(InstitutionInfo info) {
    final code = switch (info.orgType) {
      OrgType.nrc => 'NRC',
      OrgType.prc => 'PRC',
      OrgType.prb => 'PRB',
      _ => info.adminCode ?? '',
    };
    return Institution(
      cidNumber: info.cidNumber,
      fullName: info.fullName,
      shortName: info.shortName,
      orgCode: code,
      builtinAccounts: info.accounts,
    );
  }

  /// 由公权目录 Isar 实体构造(统一路径:全部机构身份来自目录)。
  factory Institution.fromPublicEntity(app_store.Entity e) {
    return Institution(
      cidNumber: e.cidNumber,
      fullName: e.fullName,
      shortName: e.shortName,
      orgCode: e.orgCode,
      status: e.cidState,
      provinceCode: e.provinceCode,
      cityCode: e.cityCode,
      townCode: e.townCode,
      parentCid: e.parentCid,
      familyName: e.familyName,
      givenName: e.givenName,
      legalCid: e.legalCid,
      legalAccount: e.legalAccount,
      accountCount: e.accountCount,
      accountNames: e.accountNames,
    );
  }
}

// 定义机构和多签共用资料、账户集合及公开身份编码工具。

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

// 定义机构内部管理提案的完整展示内容；不以本机详情授予投票资格。

/// 一行冻结业务内容。原始值完整保存，页面可另行决定布局和复制方式。
class InstitutionDetailRow {
  const InstitutionDetailRow(this.label, this.value, {this.copyable = false});
  final String label;
  final String value;
  final bool copyable;
  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    'copyable': copyable,
  };
}

/// 机构管理共用详情接口；状态、票据和阈值快照仍由投票引擎提供。
abstract interface class InstitutionProposalInfo {
  BigInt get proposalId;
  String get actorCidNumber;
  String get title;
  List<InstitutionDetailRow> get rows;
  Map<String, Object?> toJson();

  static InstitutionProposalInfo? fromJson(
    BigInt id,
    Map<String, Object?> json,
  ) {
    try {
      final cid = json['actor_cid_number'];
      if (cid is! String || cid.isEmpty) return null;
      if (json['kind'] == 'institution_close') {
        final account = json['institution_account_id'],
            beneficiary = json['beneficiary'],
            proposer = json['proposer'];
        if (account is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(account) ||
            beneficiary is! String ||
            beneficiary.isEmpty ||
            proposer is! String ||
            proposer.isEmpty) {
          return null;
        }
        return CloseProposalInfo(
          proposalId: id,
          actorCidNumber: cid,
          institutionAccountId: account,
          beneficiary: beneficiary,
          proposer: proposer,
        );
      }
      final action = json['action'], values = json['rows'];
      if (json['kind'] != 'institution_change' ||
          action is! int ||
          ![3, 4, 5].contains(action) ||
          values is! List ||
          values.isEmpty ||
          values.length > 8192) {
        return null;
      }
      final rows = <InstitutionDetailRow>[];
      for (final row in values) {
        if (row is! Map ||
            row['label'] is! String ||
            (row['label'] as String).isEmpty ||
            row['value'] is! String ||
            row['copyable'] is! bool) {
          return null;
        }
        rows.add(
          InstitutionDetailRow(
            row['label'] as String,
            row['value'] as String,
            copyable: row['copyable'] as bool,
          ),
        );
      }
      return InstitutionChangeInfo(
        proposalId: id,
        actorCidNumber: cid,
        action: action,
        rows: rows,
      );
    } on Object {
      return null;
    }
  }
}

/// 岗位、账户新增和原生政策只保存载荷中真实存在的目标内容，不倒推历史人员。
class InstitutionChangeInfo implements InstitutionProposalInfo {
  InstitutionChangeInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.action,
    required List<InstitutionDetailRow> rows,
  }) : rows = List.unmodifiable(rows);
  @override
  final BigInt proposalId;
  @override
  final String actorCidNumber;
  final int action;
  @override
  final List<InstitutionDetailRow> rows;
  @override
  String get title => switch (action) {
    3 => '岗位与任职治理',
    4 => '新增机构账户',
    5 => '原生权限与共同阈值政策',
    _ => throw StateError('未知机构管理动作'),
  };
  @override
  Map<String, Object?> toJson() => {
    'kind': 'institution_change',
    'actor_cid_number': actorCidNumber,
    'action': action,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}

/// 公权/私权机构 关闭机构多签账户提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`pub-mgmt`/`pri-mgmt` + ACTION_CLOSE = 2 前缀之后）：
///   actor_cid_number + institution_account_id: AccountId32(32)
///   + beneficiary: AccountId32(32) + proposer: AccountId32(32)
class CloseProposalInfo implements InstitutionProposalInfo {
  const CloseProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.institutionAccountId,
    required this.beneficiary,
    required this.proposer,
    this.status,
  });

  @override
  final BigInt proposalId;
  @override
  final String actorCidNumber;

  /// 销户提案的公开结果及快照使用 64 位小写十六进制正文。
  final String institutionAccountId;

  /// 受益人 SS58 地址。
  final String beneficiary;

  /// 发起人 SS58 地址。
  final String proposer;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

  @override
  String get title => '关闭机构账户';
  @override
  List<InstitutionDetailRow> get rows => [
    InstitutionDetailRow(
      '机构账户',
      citizenSs58FromAccountIdBytes(institutionBytes),
      copyable: true,
    ),
    InstitutionDetailRow('受益账户', beneficiary, copyable: true),
    InstitutionDetailRow('发起账户', proposer, copyable: true),
  ];
  @override
  Map<String, Object?> toJson() => {
    'kind': 'institution_close',
    'actor_cid_number': actorCidNumber,
    'institution_account_id': institutionAccountId,
    'beneficiary': beneficiary,
    'proposer': proposer,
  };

  /// 机构多签 AccountId32。
  Uint8List get institutionBytes =>
      citizenAccountIdBytes('0x$institutionAccountId');

  CloseProposalInfo copyWithStatus(int? newStatus) {
    return CloseProposalInfo(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      institutionAccountId: institutionAccountId,
      beneficiary: beneficiary,
      proposer: proposer,
      status: newStatus,
    );
  }
}

// 按机构码将统一目录分类到立法、治理和公权视图。

/// 机构所属的子 tab 业务分组(仅机构视图三类;公权为全集不单列)。
enum InstitutionTabGroup {
  /// 立法机构:立法律条文(国家/省立法院含参众议会、市立法会、国家公民教育委员会)。
  legislation,

  /// 治理机构:区块链/货币治理(国家储委会/省储委会/省储行)。≠ 宪法「自治政府」(ADR-028 决策 9)。
  governance,

  /// 其它公权机构(行政/司法/监察/公安…),只在公权 tab 出现。
  other,
}

/// 立法 tab 机构码集合(ADR-028 决策 3):国家/省立法院(含参众议会)、市立法会、
/// 国家公民教育委员会(起草教育类法案,宪法第十/四十四条 → 立法职能)。
const Set<String> kLegislationCodes = <String>{
  'NLG', // 国家立法院
  'NSN', // 国家参议会
  'NRP', // 国家众议会
  'PLG', // 省立法院
  'PSN', // 省参议会
  'PRP', // 省众议会
  'CLEG', // 市立法会(市公民立法委员会)
  'NED', // 国家公民教育委员会
};

/// 治理 tab 机构码集合:仅储备治理三档,不等同于链端全部固定治理档。
const Set<String> kGovernanceCodes = <String>{'NRC', 'PRC', 'PRB'};

/// 机构分类工具(纯函数,单一源)。
class InstitutionClassification {
  const InstitutionClassification._();

  /// 是否立法机构(立法 tab 过滤谓词)。
  static bool isLegislation(String orgCode) =>
      kLegislationCodes.contains(orgCode);

  /// 是否治理机构(治理 tab 过滤谓词)。
  static bool isGovernance(String orgCode) =>
      kGovernanceCodes.contains(orgCode);

  /// 机构所属业务分组(立法/治理/其它)。公权 tab 不依赖本分组(全集)。
  static InstitutionTabGroup groupOf(String orgCode) {
    if (isLegislation(orgCode)) return InstitutionTabGroup.legislation;
    if (isGovernance(orgCode)) return InstitutionTabGroup.governance;
    return InstitutionTabGroup.other;
  }

  /// 机构码人机展示标签(复用单一源:固定治理/个人多签特化中文,其余返回码本身)。
  static String label(String orgCode) =>
      InstitutionCodeLabel.codeLabel(orgCode);
}

// 定义机构岗位、任职、业务权限及投票计划的链协议模型。

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
    this.familyName = '',
    this.givenName = '',
  });
  final String familyName;
  final String givenName;
  final String personCid;
  final String? accountId;
  final List<InstitutionAssignment> assignments;
}

/// 同一最终块的岗位容量与有效任职人员，空席不丢失。
class InstitutionRoster {
  const InstitutionRoster({required this.roles, required this.persons});
  final List<InstitutionRole> roles;
  final List<InstitutionPersonView> persons;
}

// 按机构CID组合链上名册和提案状态，余额交由SDK独立管理。

/// 机构提案摘要(详情页提案列表用)。
class InstitutionProposalSummary {
  const InstitutionProposalSummary({
    required this.proposalId,
    required this.idLabel,
    required this.status,
  });

  final BigInt proposalId;
  final String idLabel;

  /// 0=表决中 1=通过 2=否决 3=已执行 4=执行失败。
  final int status;

  String get statusLabel => switch (status) {
    1 => '已通过',
    2 => '已否决',
    3 => '已执行',
    4 => '执行失败',
    _ => '表决中',
  };
}

/// 统一机构链态读服务接口(可注入 fake 单测)。
abstract interface class InstitutionChainState {
  /// 同一最终块读取岗位容量与有效任职人员。
  Future<InstitutionRoster> roster(Institution institution);

  /// 该机构当年提案(按 subject_cid_numbers 包含机构 CID 过滤当年缓存)。
  Future<List<InstitutionProposalSummary>> proposals(Institution institution);
}

/// 生产实现:复用既有链读基础设施。链读需联网,真机验证。
class LiveInstitutionChainState implements InstitutionChainState {
  LiveInstitutionChainState({
    required CitizenSdk chain,
    required CitizenSdk transactions,
    InstitutionChainService? adminService,
    MultisigTransferProposalFeed? feed,
  }) : _adminService = adminService ?? InstitutionChainService(chain: chain),
       _feed =
           feed ??
           MultisigTransferProposalFeed(
             service: MultisigTransferService(
               chain: chain,
               transactions: transactions,
             ),
           );

  final InstitutionChainService _adminService;
  final MultisigTransferProposalFeed _feed;

  @override
  Future<InstitutionRoster> roster(Institution institution) {
    return _adminService.fetchRoster(institutionIdentityOf(institution));
  }

  @override
  Future<List<InstitutionProposalSummary>> proposals(
    Institution institution,
  ) async {
    final all = await _feed.currentYearProposals();
    final out = <InstitutionProposalSummary>[];
    for (final p in all) {
      if (p.meta.subjectCidNumbers.contains(institution.cidNumber)) {
        out.add(
          InstitutionProposalSummary(
            proposalId: p.meta.proposalId,
            idLabel: '提案 #${p.meta.proposalId}',
            status: p.meta.status,
          ),
        );
      }
    }
    return out;
  }
}

/// 机构 → 管理员账户身份(单一路由,机构码决定):
/// 所有机构统一以 CID 构造管理员主体，具体账户不进入授权身份。
InstitutionIdentity institutionIdentityOf(Institution institution) {
  return InstitutionIdentity(
    cidNumber: institution.cidNumber,
    orgCode: institution.orgCode,
    kind: InstitutionCodeLabel.isUnincorporated(institution.orgCode)
        ? null
        : InstitutionCodeLabel.entityKind(institution.orgCode),
    accountLabel: institution.fullName,
  );
}

// 组合机构制度账户和命名账户的统一展示行。

/// 单个机构账户行（标签 + AccountId + SS58 + 可选余额）。
class InstitutionAccountRow {
  const InstitutionAccountRow({
    required this.label,
    required this.accountId,
    required this.accountAddress,
  });

  final String label;
  final String accountId;
  final String accountAddress;
}

/// 由机构构造全部账户行:固定治理档用 china 固定账户,普通机构本地派生。
List<InstitutionAccountRow> institutionAccountIdRows(Institution inst) {
  final baked = inst.builtinAccounts;
  if (baked != null) {
    final rows = <InstitutionAccountRow>[
      _rowFromAccountId(kReservedNameMain, baked.mainAccountId),
      _rowFromAccountId(kReservedNameFee, baked.feeAccountId),
    ];
    final safety = baked.safetyFundAccountId;
    if (safety != null) {
      rows.add(_rowFromAccountId(kReservedNameSafetyFund, safety));
    }
    final he = baked.heAccountId;
    if (he != null) rows.add(_rowFromAccountId(kReservedNameHe, he));
    final stake = baked.stakeAccountId;
    if (stake != null) rows.add(_rowFromAccountId(kReservedNameStake, stake));
    return rows;
  }

  // 普通机构:主 + 费用 + 链快照列出的附加账户(本地派生)。
  // custom_account_names 是快照字段名，不代表其中每项都允许用户自定义注册：
  // 制度账户必须先按保留名路由到专用 op_tag，普通名称才回落 OP_NAME。
  final rows = <InstitutionAccountRow>[];
  final main = deriveInstitutionMainAccountId(inst.cidNumber);
  rows.add(
    InstitutionAccountRow(
      label: kReservedNameMain,
      accountId: citizenAccountIdFromBytes(main),
      accountAddress: citizenSs58FromAccountIdBytes(main),
    ),
  );
  final feeId = deriveInstitutionFeeAccountId(inst.cidNumber);
  rows.add(
    InstitutionAccountRow(
      label: kReservedNameFee,
      accountId: citizenAccountIdFromBytes(feeId),
      accountAddress: citizenSs58FromAccountIdBytes(feeId),
    ),
  );
  for (final name in inst.accountNames) {
    if (name.isEmpty || name == kReservedNameMain || name == kReservedNameFee) {
      continue;
    }
    final id = deriveInstitutionAccountIdByName(inst.cidNumber, name);
    rows.add(
      InstitutionAccountRow(
        label: name,
        accountId: citizenAccountIdFromBytes(id),
        accountAddress: citizenSs58FromAccountIdBytes(id),
      ),
    );
  }
  return rows;
}

InstitutionAccountRow _rowFromAccountId(String label, String accountId) {
  return InstitutionAccountRow(
    label: label,
    accountId: accountId,
    accountAddress: citizenSs58FromAccountId(accountId),
  );
}

// 提供固定治理机构目录、制度账户、联合投票常量及反向查找。

/// 链上联合投票总票数。
int get jointVoteTotal => 19 + kPrcs.length + kProvincialBanks.length;

/// 链上联合投票立即通过阈值。
const int jointVotePassThreshold = 105;

/// 通过机构唯一 CID 查找内置治理机构。
InstitutionInfo? findInstitutionByCidNumber(String cidNumber) {
  for (final inst in [
    ...kNrc,
    ...kPrcs,
    ...kProvincialBanks,
    ...kFixedGovernanceInstitutions,
  ]) {
    if (inst.cidNumber == cidNumber) return inst;
  }
  return null;
}

/// 把明确属于个人多签的 32 字节执行账户包装为个人多签上下文。
///
/// 机构提案禁止调用本函数；机构只能按 `actor_cid_number` 查找，不能从
/// execution account、主账户或管理员钱包回落反推身份。

// 定义机构码的中文名称及治理分类展示。

/// 机构码(CID institution_code)热钱包端表示与治理分类 = institution_code_label.dart
///
/// (铁律):
/// 本文件逐字镜像冷钱包 `citizenwallet/lib/signing/institution_code.dart`(同一套
/// 104 码)。链上治理统一使用 4 字节 `institution_code`
/// ([u8;4] 原始码字节,3 字符码右补 `0`)。热钱包用本
/// 文件的纯函数从机构码派生治理分类(是不是固定治理档 / 个人多签 / 机构账户)，
/// 绝不另立第二套分类。
///
/// 字节表示：机构码是 3~4 个大写 ASCII 字符，统一用 4 字节，3 字符码右补 `0`：
///   NRC → [78,82,67,0]  CGOV → [67,71,79,86]  PMUL → [80,77,85,76]
class InstitutionCodeLabel {
  const InstitutionCodeLabel._();
  // 治理相关机构码常量(4 字节,3 字符码末位补 0)
  /// 国家储委会(固定治理档)。"NRC\0"。
  static const List<int> nrc = [78, 82, 67, 0];

  /// 省公民储备委员会(固定治理档)。"PRC\0"。
  static const List<int> prc = [80, 82, 67, 0];

  /// 省公民储备银行(固定治理档)。"PRB\0"。
  static const List<int> prb = [80, 82, 66, 0];

  /// 个人多签账户(不发号，仅链上/后端分类常量)。"PMUL"。
  static const List<int> pmul = [80, 77, 85, 76];
  // 字节 ↔ 字符串
  /// 取前 4 字节，去掉尾部 0 字节，UTF-8 → 大写字符串。
  static String codeToString(List<int> bytes) {
    var end = bytes.length < 4 ? bytes.length : 4;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    if (end == 0) return '';
    return utf8
        .decode(bytes.sublist(0, end), allowMalformed: true)
        .toUpperCase();
  }

  /// 字符串机构码 → 4 字节(右补 0，超 4 截断)。
  static List<int> codeBytes(String code) {
    final raw = utf8.encode(code.toUpperCase());
    final out = Uint8List(4);
    for (var i = 0; i < 4 && i < raw.length; i++) {
      out[i] = raw[i];
    }
    return out;
  }

  // 机构码分类清单(与链端 PUBLIC/PRIVATE/UNINCORPORATED 同源)
  /// 公权法人机构码(A 国家级 38 + B 省级 17 + C 市级 17 + D 镇级 14 + 公立大学/学校 2)= 88。
  static const Set<String> _publicLegalCodes = <String>{
    // A 国家级单体(38)
    'PRS', 'FSC', 'FIB', 'FSS', 'FPR', 'FRG', 'MFA', 'MDF',
    'ARM', 'NAV', 'AIR', 'SPF', 'JOS', 'ARC', 'NVC', 'AFC',
    'SFC', 'MHS', 'NGB', 'NGC', 'MCW', 'FDA', 'MHU', 'MAG',
    'MCM', 'MFT', 'MEN', 'MTR', 'NLG', 'NSN', 'NRP', 'NJD',
    'NSP', 'FAC', 'FAU', 'FIV', 'NED', 'NRC',
    // B 省级类型(17)
    'PGV', 'PLG', 'PSN', 'PRP', 'PJD', 'PSP', 'PRC', 'PRB',
    'PDF', 'PHS', 'PCW', 'PHU', 'PAG', 'PCM', 'PFT', 'PEN',
    'PTR',
    // C 市级类型(17)
    'CGOV', 'CLEG', 'CSUP', 'CJUD', 'CEDU', 'CSLF', 'CDEF', 'CHSC', 'CCWF',
    'CHUD', 'CAGR', 'CCOM', 'CFIN', 'CENR', 'CTRN', 'CREG', 'CPOL',
    // D 镇级类型(14)
    'TGOV', 'TCWF', 'THUD', 'TAGR', 'TFIN', 'TDEF', 'THSC', 'TCOM', 'TENR',
    'TTRN', 'TPOL', 'TSLF', 'TSUP', 'TJUD',
    // 公立大学 / 公立学校
    'GUN', 'GSCH',
  };

  /// 私权法人机构码(有限合伙/股权/股份/公益/注册协会 + 私立/教会大学/学校)= 9。
  static const Set<String> _privateLegalCodes = <String>{
    'SFLP',
    'SFGQ',
    'SFGF',
    'SFGY',
    'SFAS',
    'SUN',
    'JUN',
    'SFSC',
    'JSCH',
  };

  /// 非法人机构码(个体经营/无限合伙/非法人组织)= 3。
  static const Set<String> _unincorporatedCodes = <String>{
    'SFGT',
    'SFGP',
    'UNIN',
  };
  // 治理策略派生(纯函数，热钱包唯一分类来源)
  /// 是否为固定治理档机构码(国家储委会/省储委会/省储行/联邦注册局/国家司法院)。
  static bool isFixedGovernance(String code) {
    return code == 'NRC' ||
        code == 'PRC' ||
        code == 'PRB' ||
        code == 'FRG' ||
        code == 'NJD';
  }

  /// 固定治理档制度阈值，逐字镜像 runtime
  /// `fixed_governance_pass_threshold`；其它机构返回 null 并读取链上动态阈值。
  static int? fixedGovernanceThreshold(String code) => switch (code) {
    'NRC' => 13,
    'PRC' || 'PRB' => 6,
    'FRG' => 3,
    'NJD' => 8,
    _ => null,
  };

  /// 是否为个人多签账户机构码(PMUL)。

  /// 是否为公权法人机构码。
  static bool isPublicLegal(String code) => _publicLegalCodes.contains(code);

  /// 是否为私权法人机构码。
  static bool isPrivateLegal(String code) => _privateLegalCodes.contains(code);

  /// 是否为非法人机构码。
  static bool isUnincorporated(String code) =>
      _unincorporatedCodes.contains(code);

  /// 是否为机构账户机构码(公权/私权/非法人法人实体，经机构管理(public/private-manage)注册多签)。
  ///
  /// 个人/个人多签不算机构账户；
  /// 固定治理档(NRC/PRC/PRB/FRG/NJD)是 china 内建创世账户，走固定治理路径，也不算机构账户。
  static bool isInstitution(String code) {
    if (isFixedGovernance(code)) return false;
    return isPublicLegal(code) ||
        isPrivateLegal(code) ||
        _unincorporatedCodes.contains(code);
  }

  /// 是否为注册多签动态阈值账户机构码(个人多签 或 机构账户)。
  /// 固定治理档不在内。镜像链端 `is_registered_multisig_code`。
  static bool isRegisteredMultisig(String code) {
    return isInstitution(code);
  }

  /// 公权法人和固定治理机构的人员任职由PublicEntity管理。
  static bool isPublicEntityCode(String code) =>
      isPublicLegal(code) || isFixedGovernance(code);
  static bool isPrivateEntityCode(String code) => isPrivateLegal(code);

  /// 非法人机构必须以实际链上所属模块确定类别，不能由机构码猜测。
  static int entityKind(String code) {
    if (isPublicEntityCode(code)) return 0;
    if (isPrivateEntityCode(code)) return 1;
    throw ArgumentError('机构所属类别需要查链: $code');
  }

  /// 机构码人机展示标签：固定治理档/个人多签特化为中文名，其余返回码字符串本身。
  static String codeLabel(String code) {
    switch (code) {
      case 'NRC':
        return '国家储委会';
      case 'PRC':
        return '省储委会';
      case 'PRB':
        return '省储行';
      case 'FRG':
        return '联邦注册局';
      case 'NJD':
        return '国家司法院';
      default:
        return code;
    }
  }
}
