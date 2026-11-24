// 定义治理提案进入交易页面所需的已校验导航参数。

import 'package:flutter/widgets.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:typed_data';
import 'institution/institution_info.dart';
import 'proposal/proposal_context.dart';

enum InstitutionPayment { transfer, sweep, safety }

// 治理提案只提供经原门禁核对的参数，根App负责接入对应交易页面。
final class GovernanceNavigation {
  final bool Function(BigInt proposalId, Uint8List raw)? skipBusinessData;
  const GovernanceNavigation({
    required this.payment,
    required this.proposalDetail,
    this.skipBusinessData,
  });
  final Widget Function(
    InstitutionPayment kind, {
    required InstitutionInfo institution,
    required IconData icon,
    required Color badgeColor,
    required List<CitizenWalletStateAccount> adminWallets,
  })
  payment;
  final Widget Function({
    required InstitutionInfo institution,
    required BigInt proposalId,
    required ProposalContext proposalContext,
  })
  proposalDetail;
}
