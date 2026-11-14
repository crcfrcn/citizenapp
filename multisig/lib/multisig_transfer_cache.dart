import 'package:citizen_multisig/multisig_transfer_models.dart';

/// 多签转账提案详情缓存。
///
/// 只缓存 MultisigTransfer pallet 解码出的业务详情；通用提案 meta、
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
