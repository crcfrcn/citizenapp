import 'package:citizen_wallet/navigation.dart';
import 'package:citizen_wallet/wallet_page.dart';
import 'package:citizen_transaction/navigation.dart';
import 'package:citizen_transaction/history/transaction_history_page.dart';
import 'package:citizen_transaction/topup/onchain_topup_page.dart';
import 'package:citizen_transaction/offchain/withdraw_page.dart';
import 'package:citizen_transaction/offchain/petty_wallet_page.dart';
import 'package:citizen_transaction/multisig/multisig_transfer_page.dart';
import 'package:citizen_transaction/multisig/sweep_to_main_page.dart';
import 'package:citizen_transaction/multisig/safety_fund_transfer_page.dart';
import 'package:citizen_citizen/navigation.dart';
import 'package:citizen_citizen/proposal/institution_manage_detail_page.dart';
import 'package:citizen_account/identity/myid_page.dart';
import 'package:citizen_account/contacts/contact_book_page.dart';

// 全部工厂仅构造原有页面，不保留账户、余额或业务授权副本。
final walletNavigation = WalletNavigation(
  history: ({required accountAddress, required accountId}) => TransactionHistoryPage(accountAddress: accountAddress, accountId: accountId),
  topup: ({required accountId}) => OnchainTopupPage(accountId: accountId),
  withdraw: ({required accountId, required accountAddress, required wssUrl}) => WithdrawPage(accountId: accountId, accountAddress: accountAddress, wssUrl: wssUrl),
  pettyWallet: ({required accountId, required accountAddress, required wssUrl, required displayTitle}) => PettyWalletPage(accountId: accountId, accountAddress: accountAddress, wssUrl: wssUrl, displayTitle: displayTitle),
  identity: () => const MyIdPage(),
  recordDetail: ({required record}) => LocalTxRecordDetailPage(record: record),
);
final governanceNavigation = GovernanceNavigation(
  payment: (kind, {required institution, required icon, required badgeColor, required adminWallets}) => switch(kind) {
    InstitutionPayment.transfer => MultisigTransferPage(institution: institution, icon: icon, badgeColor: badgeColor, adminWallets: adminWallets),
    InstitutionPayment.sweep => SweepToMainPage(institution: institution, icon: icon, badgeColor: badgeColor, adminWallets: adminWallets),
    InstitutionPayment.safety => SafetyFundTransferPage(institution: institution, icon: icon, badgeColor: badgeColor, adminWallets: adminWallets),
  },
  proposalDetail: ({required institution, required proposalId, required proposalContext}) => MultisigProposalDetailPage(institution: institution, proposalId: proposalId, proposalContext: proposalContext),
);
final transactionNavigation = TransactionNavigation(
  walletPicker: () => const WalletTab(selectForTrade: true),
  contactPicker: (mode) => ContactBookPage(mode: mode),
);
