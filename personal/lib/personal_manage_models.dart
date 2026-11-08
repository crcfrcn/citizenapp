import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:typed_data';

import 'package:citizen_citizen/administrators/admin_account.dart';

/// PersonalAdmins 创建个人多签提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`per-mgmt` + ACTION_CREATE=0 之后）：
///   account_id: AccountId32(32) + proposer_account_id: AccountId32(32)
///   + amount: u128(16) + fee: u128(16)。
class CreateProposalInfo {
  const CreateProposalInfo({
    required this.proposalId,
    required this.accountId,
    required this.proposerSs58Address,
    required this.amountFen,
    required this.feeAmount,
    this.status,
  });

  final int proposalId;

  /// 个人多签账户 ID（小写 `0x` + 64 位 hex）。
  final String accountId;

  /// 发起人 SS58 地址。
  final String proposerSs58Address;

  /// 初始资金（分）。
  final BigInt amountFen;

  /// 创建手续费快照（分）。
  final BigInt feeAmount;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;


  /// 个人多签治理 AccountId。
  Uint8List get institutionBytes {
    return citizenAccountIdBytes(accountId);
  }

  CreateProposalInfo copyWithStatus(int? newStatus) {
    return CreateProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      proposerSs58Address: proposerSs58Address,
      amountFen: amountFen,
      feeAmount: feeAmount,
      status: newStatus,
    );
  }
}

/// PersonalAdmins 关闭个人多签提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`per-mgmt` + ACTION_CLOSE=1 之后）：
///   account_id: AccountId32(32) + beneficiary_account_id: AccountId32(32)
///   + proposer_account_id: AccountId32(32)。
class CloseProposalInfo {
  const CloseProposalInfo({
    required this.proposalId,
    required this.accountId,
    required this.beneficiarySs58Address,
    required this.proposerSs58Address,
    this.status,
  });

  final int proposalId;

  /// 个人多签账户 ID（小写 `0x` + 64 位 hex）。
  final String accountId;

  /// 受益人 SS58 地址。
  final String beneficiarySs58Address;

  /// 发起人 SS58 地址。
  final String proposerSs58Address;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

  /// 个人多签治理 AccountId。
  Uint8List get institutionBytes {
    return citizenAccountIdBytes(accountId);
  }

  CloseProposalInfo copyWithStatus(int? newStatus) {
    return CloseProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      beneficiarySs58Address: beneficiarySs58Address,
      proposerSs58Address: proposerSs58Address,
      status: newStatus,
    );
  }
}

/// 个人多签账户状态。
enum MultisigStatus {
  /// 提案投票中，尚未激活。
  pending,

  /// 投票通过、入金完成，已激活。
  active,
}

/// 个人多签账户链上信息。
///
/// 个人状态和管理员来自 `PersonalAdmins`，动态阈值来自 `InternalVote`。
class AccountInfo {
  const AccountInfo({
    required this.adminsLen,
    required this.threshold,
    required this.admins,
    required this.status,
  });

  final int adminsLen;
  final int? threshold;

  /// 完整管理员人员集合；授权只比较 `account_id`。
  final List<AdminPerson> admins;

  final MultisigStatus status;
}
