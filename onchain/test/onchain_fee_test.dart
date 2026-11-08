import 'package:citizen_multisig/multisig_transfer_balance_guard.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('机构费用账户承担操作费和执行支出，不承担主账户本金', () {
    final fees = CitizenFeeSnapshot(
      bestBlock: CitizenBlockRef(
        hash: '0x${'11' * 32}',
        number: BigInt.one,
        finality: CitizenBlockFinality.best,
      ),
      feeRateParts: 1000000,
      minimumFeeFen: BigInt.from(30),
      existentialDepositFen: BigInt.from(132),
      voteFeeFen: BigInt.from(110),
      feeFen: BigInt.from(51),
      minimumSelfPayFen: BigInt.from(162),
    );
    expect(
      MultisigTransferBalanceGuard.institutionFeeAccountRequiredFen(
        fees,
        fees.feeFen,
      ),
      BigInt.from(213),
    );
    expect(
      MultisigTransferBalanceGuard.institutionFeeAccountRequiredFen(
        fees,
        BigInt.from(50000) + fees.feeFen,
      ),
      BigInt.from(50213),
    );
  });
}
