/// 创作者概览：按当前有效订阅和周期摊算预计月收入，与服务端同一口径。
///
/// 金额一律以「分」为后端口径；展示层换算「元」（分÷100，全仓约定）。
class CreatorOverview {
  const CreatorOverview({
    required this.subscriberCount,
    required this.monthlyIncomeFen,
    required this.tierCount,
  });

  /// 订阅人数（活跃订阅者去重计数）。
  final int subscriberCount;

  /// 预计月收入（分）：当前有效订阅按周期折算，不代表已结算收入。
  final int monthlyIncomeFen;

  /// 档位数（= 当前计划档位数量）。
  final int tierCount;

  static const CreatorOverview zero = CreatorOverview(
    subscriberCount: 0,
    monthlyIncomeFen: 0,
    tierCount: 0,
  );

  factory CreatorOverview.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => value is int ? value : 0;
    return CreatorOverview(
      subscriberCount: asInt(json['subscriber_count']),
      monthlyIncomeFen: asInt(json['monthly_income_fen']),
      tierCount: asInt(json['tier_count']),
    );
  }
}
