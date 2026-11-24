import 'package:citizen_personal/chain.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_personal/accounts.dart';
import 'package:citizen_personal/proposals.dart';
// 提供跨业务页面工厂，保持导航装配集中于根应用。

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
  pettyWallet: ({required accountId}) => PettyWalletPage(accountId: accountId),
  identity: () => const MyIdPage(),
  recordDetail: ({required record}) => LocalTxRecordDetailPage(record: record),
);
final governanceNavigation = GovernanceNavigation(
  skipBusinessData: (id, raw) =>
      PersonalManageService().decodePersonalProposalData(id, raw) != null,
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

final personalNavigation = PersonalNavigation(
  transfer:
      ({
        required account,
        required icon,
        required badgeColor,
        required adminWallets,
        required onCreated,
      }) => Builder(
        builder: (context) => MultisigTransferPage.account(
          accountId: account.accountId,
          accountName: account.shortName,
          accountCode: 'PMUL',
          icon: icon,
          badgeColor: badgeColor,
          adminWallets: adminWallets,
          onProposed: (id, beneficiary, amount) async {
            await PersonalProposalHistoryService(
              chain: context.read<CitizenSdk>(),
            ).recordTransferIfKnown(
              accountId: account.accountId,
              proposalId: id,
              beneficiary: beneficiary,
              amountFen: amount,
            );
            await onCreated(id);
          },
        ),
      ),
);
