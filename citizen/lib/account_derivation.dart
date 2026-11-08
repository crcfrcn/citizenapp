// GMB 账户统一派生原语 —— 全 app 唯一入口。
//
// 与 citizenchain `primitives::core_const` 单一权威源严格字节对齐:
//   preimage = b"GMB"(3B) || op_tag(1B) || ss58.to_le_bytes()(2B) || payload
//   address  = blake2b_256(preimage)            // 32 字节 account id
// op_tag 与 payload(见各常量注释)逐一对齐 core_const.rs;任何模块禁止
// 自行拼接 preimage,一律调用本文件。
//
// 派生输出为 32 字节账户；文本及 SS58 编解码直接调用 CitizenSDK。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_citizen/reserved_account_names.dart';

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

/// 个人多签账户 · payload = creator(32B) || account_name。
const int kOpPersonal = 0x06;

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
Uint8List derivePersonalAccountId({
  required Uint8List creatorAccount,
  required String accountName,
}) {
  if (creatorAccount.length != 32) {
    throw ArgumentError('creator account_id 必须为 32 字节');
  }
  return deriveAccountId(
    opTag: kOpPersonal,
    payload: <int>[...creatorAccount, ...utf8.encode(accountName)],
  );
}
