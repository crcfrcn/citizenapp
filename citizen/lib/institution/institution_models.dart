import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:typed_data';

/// 公权/私权机构 关闭机构多签账户提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`pub-mgmt`/`pri-mgmt` + ACTION_CLOSE = 2 前缀之后）：
///   actor_cid_number + institution_account_id: AccountId32(32)
///   + beneficiary: AccountId32(32) + proposer: AccountId32(32)
class CloseProposalInfo {
  const CloseProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.institutionAccountId,
    required this.beneficiary,
    required this.proposer,
    this.status,
  });

  final int proposalId;
  final String actorCidNumber;

  /// 销户提案的公开结果及快照使用 64 位小写十六进制正文。
  final String institutionAccountId;

  /// 受益人 SS58 地址。
  final String beneficiary;

  /// 发起人 SS58 地址。
  final String proposer;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

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
