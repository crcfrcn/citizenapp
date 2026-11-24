// 缓存进程内提案数据，并在主动刷新时清理重载。

import 'package:citizen_citizen/proposal/proposal_models.dart';

/// 提案内存缓存。
///
/// App 生命周期内有效，下拉刷新时清空重载。
/// 提案数据量小（几百字节/个），内存缓存即可。
class ProposalCache {
  // ──── 内存缓存 ────

  static final Map<BigInt, ProposalMeta> _metaCache = {};
  static final Map<BigInt, RuntimeUpgradeProposalInfo>
  _runtimeUpgradeDetailCache = {};

  // ──── 读取 ────

  /// 获取提案元数据，命中返回缓存，未命中返回 null。
  static ProposalMeta? getMeta(BigInt proposalId) => _metaCache[proposalId];

  /// 获取协议升级提案详情，命中返回缓存，未命中返回 null。
  static RuntimeUpgradeProposalInfo? getRuntimeUpgradeDetail(
    BigInt proposalId,
  ) => _runtimeUpgradeDetailCache[proposalId];

  // ──── 写入 ────

  /// 存入提案元数据。
  static void putMeta(BigInt proposalId, ProposalMeta meta) =>
      _metaCache[proposalId] = meta;

  /// 存入协议升级提案详情。
  static void putRuntimeUpgradeDetail(
    BigInt proposalId,
    RuntimeUpgradeProposalInfo detail,
  ) => _runtimeUpgradeDetailCache[proposalId] = detail;

  // ──── 清除 ────

  /// 清空所有缓存（下拉刷新时调用）。
  static void clear() {
    _metaCache.clear();
    _runtimeUpgradeDetailCache.clear();
  }

  /// 使单个提案缓存失效（轻节点推送新区块时用）。
  static void invalidate(BigInt proposalId) {
    _metaCache.remove(proposalId);
    _runtimeUpgradeDetailCache.remove(proposalId);
  }
}
