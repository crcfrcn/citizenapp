/// 订阅周期；枚举值沿用既有链协议，不使用枚举序号。
enum BillingPeriod { monthly, quarterly, yearly }

extension BillingPeriodKey on BillingPeriod {
  String get key => name;
  String get label => switch (this) {
    BillingPeriod.monthly => '每月',
    BillingPeriod.quarterly => '每季',
    BillingPeriod.yearly => '每年',
  };
  static BillingPeriod? tryParse(String value) => switch (value) {
    'monthly' => BillingPeriod.monthly,
    'quarterly' => BillingPeriod.quarterly,
    'yearly' => BillingPeriod.yearly,
    _ => null,
  };
}

/// finalized档位；金额单位为分，未开通周期为null，不保存第二份周期价格表。
class CreatorTier {
  const CreatorTier({
    required this.tierId,
    required this.tierName,
    this.monthFen,
    this.quarterFen,
    this.yearFen,
  });
  final String tierId;
  final String tierName;
  final int? monthFen;
  final int? quarterFen;
  final int? yearFen;

  int? priceFenOf(BillingPeriod period) => switch (period) {
    BillingPeriod.monthly => monthFen,
    BillingPeriod.quarterly => quarterFen,
    BillingPeriod.yearly => yearFen,
  };
  bool hasPeriod(BillingPeriod period) => priceFenOf(period) != null;

  CreatorTier copyWith({String? tierName}) => CreatorTier(
    tierId: tierId,
    tierName: tierName ?? this.tierName,
    monthFen: monthFen,
    quarterFen: quarterFen,
    yearFen: yearFen,
  );
  Map<String, Object?> toJson() => {
    'tier_id': tierId,
    'tier_name': tierName,
    'month_fen': monthFen,
    'quarter_fen': quarterFen,
    'year_fen': yearFen,
  };
  factory CreatorTier.fromJson(Map<String, dynamic> json) {
    const fields = {
      'tier_id',
      'tier_name',
      'month_fen',
      'quarter_fen',
      'year_fen',
    };
    final tierId = json['tier_id'];
    final tierName = json['tier_name'];
    final prices = [json['month_fen'], json['quarter_fen'], json['year_fen']];
    if (json.length != fields.length ||
        json.keys.any((key) => !fields.contains(key)) ||
        tierId is! String ||
        tierId.isEmpty ||
        tierName is! String ||
        tierName.isEmpty ||
        !prices.any((price) => price != null) ||
        prices.any(
          (price) =>
              price != null &&
              (price is! int || price <= 0 || price > 9007199254740991),
        )) {
      throw const FormatException('创作者档位字段无效');
    }
    return CreatorTier(
      tierId: tierId,
      tierName: tierName,
      monthFen: json['month_fen'] as int?,
      quarterFen: json['quarter_fen'] as int?,
      yearFen: json['year_fen'] as int?,
    );
  }
}

/// 属主由请求会话、目标路径或本地自然键持有，档位对象不重复保存身份或占位时间。
class CreatorPlan {
  const CreatorPlan({required this.tiers});
  final List<CreatorTier> tiers;
  static const int maxTiers = 10;
  bool get isEmpty => tiers.isEmpty;
  static CreatorPlan empty() => const CreatorPlan(tiers: []);
  Map<String, Object?> toJson() => {
    'tiers': tiers.map((tier) => tier.toJson()).toList(growable: false),
  };

  factory CreatorPlan.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['tiers'];
    if (rawTiers is! List ||
        rawTiers.length > maxTiers ||
        rawTiers.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('创作者档位列表无效');
    }
    final tiers = rawTiers
        .cast<Map<String, dynamic>>()
        .map(CreatorTier.fromJson)
        .toList(growable: false);
    if (tiers.map((tier) => tier.tierId).toSet().length != tiers.length) {
      throw const FormatException('创作者档位标识重复');
    }
    return CreatorPlan(tiers: List.unmodifiable(tiers));
  }
}
