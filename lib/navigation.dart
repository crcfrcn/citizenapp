import 'package:citizen_wallet/core/navigation.dart';
import 'package:citizen_wallet/account/wallet_page.dart';
import 'package:citizen_onchain/onchain_payment_page.dart';
import 'package:citizen_wallet/history/transaction_history_page.dart';
import 'package:citizen_topup/topup_sheet.dart';
import 'package:citizen_offchain/petty_wallet_page.dart';
import 'package:citizen_multisig/multisig_transfer_page.dart';
import 'package:citizen_multisig/sweep_to_main_page.dart';
import 'package:citizen_multisig/safety_fund_transfer_page.dart';
import 'package:citizen_citizen/navigation.dart';
import 'package:citizen_citizen/proposal/institution_manage_detail_page.dart';
import 'package:citizen_user/identity/myid_page.dart';
import 'package:citizen_user/contacts/contact_book_page.dart';

// 全部工厂仅构造原有页面，不保留账户、余额或业务授权副本。
final walletNavigation = WalletNavigation(
  history: ({required accountAddress, required accountId}) =>
      TransactionHistoryPage(
        accountAddress: accountAddress,
        accountId: accountId,
      ),
  topup: (context, {required accountId, required token}) =>
      showTopup(context, accountId: accountId, token: token),
  pettyWallet:
      ({
        required accountId,
        required accountAddress,
        required wssUrl,
        required displayTitle,
      }) => PettyWalletPage(
        accountId: accountId,
        accountAddress: accountAddress,
        wssUrl: wssUrl,
        displayTitle: displayTitle,
      ),
  identity: () => const MyIdPage(),
  recordDetail: ({required record}) => LocalTxRecordDetailPage(record: record),
);
final governanceNavigation = GovernanceNavigation(
  payment:
      (
        kind, {
        required institution,
        required icon,
        required badgeColor,
        required adminWallets,
      }) => switch (kind) {
        InstitutionPayment.transfer => MultisigTransferPage(
          institution: institution,
          icon: icon,
          badgeColor: badgeColor,
          adminWallets: adminWallets,
        ),
        InstitutionPayment.sweep => SweepToMainPage(
          institution: institution,
          icon: icon,
          badgeColor: badgeColor,
          adminWallets: adminWallets,
        ),
        InstitutionPayment.safety => SafetyFundTransferPage(
          institution: institution,
          icon: icon,
          badgeColor: badgeColor,
          adminWallets: adminWallets,
        ),
      },
  proposalDetail:
      ({required institution, required proposalId, required proposalContext}) =>
          MultisigProposalDetailPage(
            institution: institution,
            proposalId: proposalId,
            proposalContext: proposalContext,
          ),
);
final transactionNavigation = TransactionNavigation(
  walletPicker: () => const WalletTab(selectForTrade: true),
  contactPicker: (mode) => ContactBookPage(mode: mode),
);
