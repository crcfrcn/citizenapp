import 'package:citizen_sdk/citizen_sdk.dart';

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
