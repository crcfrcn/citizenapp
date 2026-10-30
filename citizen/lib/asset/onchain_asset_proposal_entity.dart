// 尚未接线的资产提案数据模型；没有Isar collection/schema或实际持久化实现。
// 字段只表达候选记录，不证明已建案、发行成功或已开放资产功能。
// 后续完整功能需独立实现查询、治理及持久化；本轮不增加数据库结构。

class OnchainAssetProposalEntity {
  OnchainAssetProposalEntity({
    required this.proposalId,
    required this.action,
    required this.assetId,
    required this.proposerSs58,
    required this.createdAtBlock,
    required this.createdAtMs,
    this.amount,
    this.counterpartySs58,
    this.reasonHashHex,
    this.status = 'Voting',
  });

  /// VotingEngine分配的全局u64提案ID；年份/序号属于独立展示元数据，不拆分此主键。
  final int proposalId;

  /// 4 字符 ACTION 常量(OAIS / OAMT / OABN / ... / OMFC)。
  final String action;

  /// 资产编号；发行提案尚无编号时为空，不能由本地候选记录推定已分配。
  int? assetId;

  final String proposerSs58;
  final int createdAtBlock;
  final int createdAtMs;

  /// mint / burn / transfer / confiscate / forceTransfer 时的金额(raw,含 decimals)。
  BigInt? amount;

  /// transfer / forceTransfer 的对方 SS58。
  String? counterpartySs58;

  /// 监管 5 动作的 reason_hash(链下文书 sha256)hex 字符串。
  String? reasonHashHex;

  /// 尚未接线的本地状态文本，不能替代链上提案或资产状态。
  String status;
}
