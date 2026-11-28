// 提案模型、详情缓存及余额校验。

import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';

// 定义多签转账、安全基金和费用归集提案的业务详情。

/// 多签转账模块写入 ProposalWithDetail.businessDetails 的键名。
class MultisigTransferProposalDetailKeys {
  MultisigTransferProposalDetailKeys._();

  static const transfer = 'multisig-transfer.transfer';
  static const safetyFund = 'multisig-transfer.safety-fund';
  static const sweep = 'multisig-transfer.sweep';
}

/// 多签转账提案链上数据。
class TransferProposalInfo {
  const TransferProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.fundingAccountId,
    required this.beneficiary,
    required this.amountFen,
    required this.remark,
    required this.proposer,
    this.status,
  });

  final BigInt proposalId;
  final String? actorCidNumber;
  final Uint8List fundingAccountId;
  final String beneficiary; // SS58
  final BigInt amountFen;
  final String remark;
  final String proposer; // SS58

  /// 0=voting, 1=passed, 2=rejected, null=unknown
  final int? status;

  TransferProposalInfo copyWithStatus(int? newStatus) {
    return TransferProposalInfo(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      fundingAccountId: fundingAccountId,
      beneficiary: beneficiary,
      amountFen: amountFen,
      remark: remark,
      proposer: proposer,
      status: newStatus,
    );
  }
}

/// 安全基金转账提案详情（从 SafetyFundProposalActions 存储解码）。
class SafetyFundProposalInfo {
  const SafetyFundProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.institutionAccountId,
    required this.beneficiary,
    required this.amountFen,
    required this.remark,
    required this.proposer,
    this.status,
  });

  final BigInt proposalId;
  final String actorCidNumber;
  final Uint8List institutionAccountId;
  final String beneficiary; // SS58
  final BigInt amountFen;
  final String remark;
  final String proposer; // SS58
  final int? status;
}

/// 手续费划转提案详情（从 SweepProposalActions 存储解码）。
class SweepProposalInfo {
  const SweepProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.institutionAccountId,
    required this.amountFen,
    required this.proposer,
    this.status,
  });

  final BigInt proposalId;
  final String actorCidNumber;
  final Uint8List institutionAccountId;
  final BigInt amountFen;
  final String proposer; // SS58
  final int? status;
}

// 缓存多签转账业务详情，隔离通用提案和其他业务缓存。

/// 多签转账提案详情缓存。
///
/// 只缓存 Multisig pallet 解码出的业务详情；通用提案 meta、
/// runtime 升级和多签管理缓存仍由 proposal/shared 自己维护。
class MultisigTransferCache {
  static final Map<BigInt, TransferProposalInfo> _transferDetailCache = {};

  /// 获取普通多签转账提案详情。
  static TransferProposalInfo? getTransferDetail(BigInt proposalId) =>
      _transferDetailCache[proposalId];

  /// 存入普通多签转账提案详情。
  static void putTransferDetail(BigInt proposalId, TransferProposalInfo detail) =>
      _transferDetailCache[proposalId] = detail;

  /// 清空多签转账缓存。
  static void clear() {
    _transferDetailCache.clear();
  }

  /// 使单个多签转账提案缓存失效。
  static void invalidate(BigInt proposalId) {
    _transferDetailCache.remove(proposalId);
  }
}

// 按提案实际付款账户核对可支配余额并提示不足。

/// 按提案的付款账户提示余额不足。
class MultisigTransferBalanceGuard {
  const MultisigTransferBalanceGuard._();

  static BigInt institutionFeeAccountRequiredFen(
    CitizenFeeSnapshot fees,
    BigInt additionalDebitFen,
  ) => fees.minimumSelfPayFen + additionalDebitFen;

  static Future<String?> checkInstitutionFeeAccountBalance({
    required String feeAccountId,
    required String actionLabel,
    required BigInt additionalDebitFen,
    required CitizenFeeSnapshot fees,
    required CitizenSdk chain,
  }) async {
    final balance = await chain.getAccountBalance(
      feeAccountId,
      forceRefresh: true,
    );
    final requiredFen = institutionFeeAccountRequiredFen(
      fees,
      additionalDebitFen,
    );
    if (balance.freeFen >= requiredFen) return null;
    return '机构费用账户余额不足，不能$actionLabel。当前余额 '
        '${formatFen(balance.freeFen)} 元，至少需要 ${formatFen(requiredFen)} 元'
        '（含操作费 ${formatFen(fees.minimumFeeFen)} 元、'
        '后续支出 ${formatFen(additionalDebitFen)} 元，支付后须保留 ED）。';
  }

  static Future<String?> checkAdminWalletBalance({
    required CitizenWalletStateAccount wallet,
    required BigInt requiredFeeFen,
    required BigInt edFen,
    required String actionLabel,
    required CitizenSdk chain,
  }) async {
    final balance = await chain.getAccountBalance(
      wallet.accountId,
      forceRefresh: true,
    );
    final requiredFen = requiredFeeFen + edFen;
    if (balance.freeFen >= requiredFen) return null;
    return '管理员钱包余额不足，不能$actionLabel。当前余额 '
        '${formatFen(balance.freeFen)} 元，至少需要 ${formatFen(requiredFen)} 元'
        '（交易费 ${formatFen(requiredFeeFen)} 元，支付后须保留 ED）。';
  }
}
