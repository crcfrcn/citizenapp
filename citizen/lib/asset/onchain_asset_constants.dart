// 声明尚未开放代币业务的固定调用索引和动作编号。

import 'package:citizen_citizen/pallet_registry.dart';

class OnchainAssetActions {
  OnchainAssetActions._();

  // ---------- pallet_index / call_index(与链端 + citizenwallet PalletRegistry 同步) ----------

  /// OnchainIssue pallet_index(单源 PalletRegistry,对齐 construct_runtime)。
  static const int onchainIssuePalletIndex =
      PalletRegistry.onchainIssuePallet;

  /// pallet_assets 内核 pallet_index(原生 extrinsic 全部被 RuntimeCallFilter reject)。
  static const int assetsPalletIndex = PalletRegistry.assetsPallet;

  // 业务 propose_X(call_index 0..=4)
  static const int callProposeIssue = PalletRegistry.proposeIssueCall;
  static const int callProposeMint = PalletRegistry.proposeMintCall;
  static const int callProposeBurn = PalletRegistry.proposeBurnCall;
  static const int callProposeClose = PalletRegistry.proposeCloseAssetCall;
  static const int callProposeTransfer =
      PalletRegistry.proposeAssetTransferCall;

  // 监管 propose_monitor_X(call_index 10..=14)
  static const int callProposeMonitorFreeze =
      PalletRegistry.proposeMonitorFreezeCall;
  static const int callProposeMonitorUnfreeze =
      PalletRegistry.proposeMonitorUnfreezeCall;
  static const int callProposeMonitorConfiscate =
      PalletRegistry.proposeMonitorConfiscateCall;
  static const int callProposeMonitorForceTransfer =
      PalletRegistry.proposeMonitorForceTransferCall;
  static const int callProposeMonitorForceClose =
      PalletRegistry.proposeMonitorForceCloseCall;

  // ---------- ACTION 字符串常量(VotingEngine ProposalData 业务标签) ----------

  // 业务 ACTION(InternalVote)
  static const String actionIssue = 'OAIS';
  static const String actionMint = 'OAMT';
  static const String actionBurn = 'OABN';
  static const String actionClose = 'OACL';
  static const String actionTransfer = 'OATR';

  // 监管 ACTION(JointVote)
  static const String actionMonitorFreeze = 'OMFZ';
  static const String actionMonitorUnfreeze = 'OMUF';
  static const String actionMonitorConfiscate = 'OMCF';
  static const String actionMonitorForceTransfer = 'OMFT';
  static const String actionMonitorForceClose = 'OMFC';

  /// VotingEngine ProposalData 业务标签前缀(与链端 MODULE_TAG 一致)。
  static const String moduleTag = 'onc-iss';

  /// decimals合法区间，对齐链端onchainissue::validation。
  static const int minDecimals = 0;
  static const int maxDecimals = 18;
}
