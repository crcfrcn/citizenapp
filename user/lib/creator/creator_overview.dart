/// 同一最终块、已登记集合的有效人数与预计月收入；不代表结算收入。
class CreatorOverview {
  const CreatorOverview({
    required this.subscriberCount,
    required this.monthlyIncomeFen,
    required this.blockNumber,
    required this.blockHash,
  });
  final int subscriberCount;
  final BigInt monthlyIncomeFen;
  final int blockNumber;
  final String blockHash;
  static final zero = CreatorOverview(
    subscriberCount: 0,
    monthlyIncomeFen: BigInt.zero,
    blockNumber: 0,
    blockHash: '',
  );
  Map<String, dynamic> toJson() => {
    'subscriber_count': subscriberCount,
    'monthly_income_fen': monthlyIncomeFen.toString(),
    'final_block': blockNumber,
    'final_hash': blockHash,
  };
  factory CreatorOverview.fromJson(Map<String, dynamic> value) {
    if (value['subscriber_count'] is! int ||
        value['monthly_income_fen'] is! String ||
        value['final_block'] is! int ||
        value['final_hash'] is! String) {
      throw const FormatException('轻节点统计快照无效');
    }
    return CreatorOverview(
      subscriberCount: value['subscriber_count'] as int,
      monthlyIncomeFen: BigInt.parse(value['monthly_income_fen'] as String),
      blockNumber: value['final_block'] as int,
      blockHash: value['final_hash'] as String,
    );
  }
}
