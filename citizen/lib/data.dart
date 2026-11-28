// 共用链常量、账户派生及保留名称。

library ;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:convert';
import 'dart:typed_data';

// 按统一公民域、操作标签和账户参数派生各类公开账户地址。

// ── 账户派生 op_tag,逐字节对齐链端唯一真源 account_derive.rs ──
// 字节空间分区:0x00-0x0F 地址派生;0x10-0x1D 签名域(sign.rs,禁用);
// 0x1E-0xFF 未分配保留。新增协议账户只取"当前最大 + 1",不改动既有 tag
// (改 tag 会重派生全部地址)。
/// CID 机构自定义命名账户(**永久冻结 0x00**)· payload = cid_number || account_name。
const int kOpName = 0x00;

/// 所有机构主账户 · payload = cid_number。
const int kOpMain = 0x01;

/// 所有机构费用账户 · payload = cid_number。
const int kOpFee = 0x02;

/// 永久质押(制度专属)· payload = cid_number。
const int kOpStake = 0x03;

/// 安全基金(制度专属)· payload = cid_number。
const int kOpSafetyFund = 0x04;

/// 两和基金(制度专属)· payload = cid_number。
const int kOpHe = 0x05;

/// 清算账户(私法人股份公司专属)· payload = cid_number。
const int kOpClearing = 0x07;

/// 联邦公民安全基金(联邦安全局 FSC 专属)· payload = cid_number。
const int kOpFcsf = 0x08;

const String _domain = 'GMB';

/// 派生 GMB account id(32 字节)。底层唯一实现,上层全部经此。
Uint8List deriveAccountId({required int opTag, required List<int> payload}) {
  final input = <int>[
    ...utf8.encode(_domain),
    opTag & 0xFF,
    ...CitizenScale.unsigned(BigInt.from(citizenSs58Prefix), 2),
    ...payload,
  ];
  return CitizenScale.blake2b256(input);
}

// ── 机构账户(payload 含 cid_number)──

/// 机构主账户 id(OP_MAIN,payload = cid_number,不含名字)。
Uint8List deriveInstitutionMainAccountId(String cidNumber) =>
    deriveAccountId(opTag: kOpMain, payload: utf8.encode(cidNumber));

/// 机构费用账户 id(OP_FEE,payload = cid_number,不含名字)。
Uint8List deriveInstitutionFeeAccountId(String cidNumber) =>
    deriveAccountId(opTag: kOpFee, payload: utf8.encode(cidNumber));

/// 机构清算账户 id(OP_CLEARING,payload = cid_number,不含名字)。
///
/// 仅私法人股份公司(SFGF)自动拥有;地址派生与主/费同构,不参与自定义命名。
Uint8List deriveInstitutionClearingAccountId(String cidNumber) =>
    deriveAccountId(opTag: kOpClearing, payload: utf8.encode(cidNumber));

/// 机构自定义命名账户 id(OP_NAME,payload = cid_number || account_name)。
///
/// 字节对齐链端:account_name 取原始字节不 trim;空名/主/费/制度专属名一律拒绝
/// (对齐链端注册策略 is_registrable_custom_name:空→EmptyAccountName,
/// 主/费走各自 op_tag,其余协议账户名禁注册)。
Uint8List deriveInstitutionCustomAccountId(
  String cidNumber,
  String accountName,
) {
  if (!isRegistrableCustomName(accountName)) {
    throw ArgumentError('自定义账户名不可注册(空/主/费/制度专属): $accountName');
  }
  return deriveAccountId(
    opTag: kOpName,
    payload: <int>[...utf8.encode(cidNumber), ...utf8.encode(accountName)],
  );
}

/// 按 account_name 路由派生机构账户 id —— 镜像 onchina `accounts/derive.rs` 单一源:
/// 主/费/质押/安全基金/两和基金/清算账户/联邦公民安全基金 → 各自 op_tag
/// (payload 不含名字);其他非空名 → OP_NAME(payload 追加名字)。空名抛错。
Uint8List deriveInstitutionAccountIdByName(
  String cidNumber,
  String accountName,
) {
  if (accountName.isEmpty) {
    throw ArgumentError('账户名不能为空(对齐链端 EmptyAccountName)');
  }
  final (int opTag, bool appendName) = switch (accountName) {
    kReservedNameMain => (kOpMain, false),
    kReservedNameFee => (kOpFee, false),
    kReservedNameStake => (kOpStake, false),
    kReservedNameSafetyFund => (kOpSafetyFund, false),
    kReservedNameHe => (kOpHe, false),
    kReservedNameClearing => (kOpClearing, false),
    kReservedNameFcsf => (kOpFcsf, false),
    _ => (kOpName, true),
  };
  final payload = <int>[
    ...utf8.encode(cidNumber),
    if (appendName) ...utf8.encode(accountName),
  ];
  return deriveAccountId(opTag: opTag, payload: payload);
}

// ── 个人多签(payload = creator || account_name)──

/// 派生个人多签账户，输出 32 字节 AccountId。

// 声明与链端一致的受限账户名称，供自定义名称校验。

/// 主账户（强制默认账户）。
const String kReservedNameMain = '主账户';

/// 费用账户（强制默认账户）。
const String kReservedNameFee = '费用账户';

/// 永久质押（制度专属，禁止自定义）。
const String kReservedNameStake = '永久质押';

/// 安全基金（制度专属，禁止自定义）。
const String kReservedNameSafetyFund = '安全基金';

/// 两和基金（制度专属，禁止自定义）。
const String kReservedNameHe = '两和基金';

/// 清算账户（私法人股份公司专属，禁止自定义）。
const String kReservedNameClearing = '清算账户';

/// 联邦公民安全基金（联邦安全局专属，禁止自定义）。
const String kReservedNameFcsf = '联邦公民安全基金';

/// 全部 7 个受限保留名。
const List<String> kReservedAccountNames = <String>[
  kReservedNameMain,
  kReservedNameFee,
  kReservedNameStake,
  kReservedNameSafetyFund,
  kReservedNameHe,
  kReservedNameClearing,
  kReservedNameFcsf,
];

/// 制度专属「禁止注册」名。主/费不在此列（强制默认账户语义）。
///
/// 与链端 `account_derive::is_forbidden_account_name` 字节对齐：只判 5 名，
/// **不 trim**（trim 仅允许在 UI 输入层，绝不进派生/校验）。
bool isForbiddenAccountName(String name) {
  return name == kReservedNameStake ||
      name == kReservedNameSafetyFund ||
      name == kReservedNameHe ||
      name == kReservedNameClearing ||
      name == kReservedNameFcsf;
}

/// 注册策略（非派生）：自定义名是否可注册。空/主/费/制度专属 一律拒绝。
///
/// 对齐链端 `account_derive::is_registrable_custom_name`。不 trim。
bool isRegistrableCustomName(String name) {
  return name.isNotEmpty &&
      name != kReservedNameMain &&
      name != kReservedNameFee &&
      !isForbiddenAccountName(name);
}

// 集中登记App链调用和存储使用的pallet及call索引。

/// CitizenApp 链上 pallet / call 索引唯一真源。
///
/// 索引由 citizenchain 的 runtime/src/lib.rs 中显式 pallet_index 声明确定。
/// 链升级调整 pallet 顺序后，**只改本文件**，全端各 service 引用这里、不再各自写死字面量。
/// 冷钱包 `citizenwallet/lib/signing/pallet_registry.dart` 是同一契约的另一份镜像，
/// 两者必须逐项一致；本文件仅收录 CitizenApp 实际构造 extrinsic 用到的 pallet/call。
///
/// 约定：pallet 常量以 `Pallet` 结尾；call 常量以 `Call` 结尾。
class PalletRegistry {
  const PalletRegistry._();

  // ---- Balances (2) · 只读余额账本(外部转账入口在 Onchain) ----
  static const int balancesPallet = 2;

  // ---- Identity (10) · 公民链上身份(匿名自助占号 / 换绑) ----
  static const int identityPallet = 10;
  static const int selfOccupyCidCall = 5;
  static const int selfRebindCidAccountCall = 9;

  // ---- Multisig (17) ----
  static const int multisigPallet = 17;

  // ---- InternalVote (20) · 内部投票管理员一人一票 ----
  static const int internalVotePallet = 20;
  static const int internalVoteCastCall = 0;

  // ---- JointVote (21) · 联合投票(内部投票阶段 + 联合公投) ----
  static const int jointVotePallet = 21;
  static const int jointVoteCastAdminCall = 0;

  // ---- OnchainIssue (23) · 链上发行代币(Plain FT, ADR-011) ----
  // call_index 5..=9 / 15+ 留洞不复用(永久 ABI)。
  static const int onchainIssuePallet = 23;
  static const int proposeIssueCall = 0;
  static const int proposeMintCall = 1;
  static const int proposeBurnCall = 2;
  static const int proposeCloseAssetCall = 3;
  static const int proposeAssetTransferCall = 4;
  static const int proposeMonitorFreezeCall = 10;
  static const int proposeMonitorUnfreezeCall = 11;
  static const int proposeMonitorConfiscateCall = 12;
  static const int proposeMonitorForceTransferCall = 13;
  static const int proposeMonitorForceCloseCall = 14;

  // ---- Assets (24) · pallet_assets 内核(原生 extrinsic 全被 RuntimeCallFilter reject) ----
  static const int assetsPallet = 24;

  // ---- LegislationVote (26) · 立法专属投票引擎 ----
  // call_index 0 留洞(特别案快照内联生成)。
  static const int legislationVotePallet = 26;
  static const int castRepresentativeVoteCall = 1;
  static const int castLegislationReferendumCall = 2;
  static const int executiveSignCall = 3;
  static const int overrideSignCall = 4;
  static const int guardVoteCall = 5;

  // ---- Square (34) · 广场发帖 + 会员订阅价格治理 ----
  static const int squarePallet = 34;
  static const int publishPostCall = 0;
  static const int subscribeCall = 1;
  static const int cancelSubscriptionCall = 2;
  static const int setCreatorPlansCall = 3;
  static const int changeSubscriptionPlanCall = 4;
  static const int updateCreatorTierNameCall = 6;
}
