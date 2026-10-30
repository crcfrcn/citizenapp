import 'package:flutter/widgets.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'institution/institution_info.dart';
import 'proposal/proposal_context.dart';

enum InstitutionPayment { transfer, sweep, safety }

// 治理提案只提供经原门禁核对的参数，根App负责接入对应交易页面。
final class GovernanceNavigation {
  const GovernanceNavigation({required this.payment, required this.proposalDetail});
  final Widget Function(InstitutionPayment kind, {required InstitutionInfo institution, required IconData icon, required Color badgeColor, required List<CitizenWalletStateAccount> adminWallets}) payment;
  final Widget Function({required InstitutionInfo institution, required int proposalId, required ProposalContext proposalContext}) proposalDetail;
}
