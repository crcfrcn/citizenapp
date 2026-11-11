import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';

/// 创作者链上付款档位中的周期价格。
class CreatorPeriodPriceInput {
  const CreatorPeriodPriceInput({
    required this.billingPeriod,
    required this.priceFen,
  });

  final String billingPeriod;
  final BigInt priceFen;
}

/// 创作者覆盖式提交的链上付款档位；档位名与价格在同一交易中原子写入链上。
class CreatorTierInput {
  const CreatorTierInput({
    required this.tierId,
    required this.tierName,
    required this.pricesFen,
  });

  final String tierId;
  final String tierName;
  final List<CreatorPeriodPriceInput> pricesFen;
}

/// finalized `Subscriptions` 中的平台或创作者付款计划。
class ChainSubscriptionPlan {
  const ChainSubscriptionPlan.platform(this.memberLevel)
    : kind = 'platform',
      tierId = null,
      billingPeriod = null;

  const ChainSubscriptionPlan.creator(this.tierId, this.billingPeriod)
    : kind = 'creator',
      memberLevel = null;

  final String kind;
  final String? memberLevel;
  final String? tierId;
  final String? billingPeriod;
}

/// 链上订阅真态；所有时间字段均为 UTC Unix 毫秒时间戳。
class ChainSubscriptionState {
  const ChainSubscriptionState({
    required this.plan,
    required this.startedAt,
    required this.chargeAt,
    required this.chargeFen,
    required this.paidUntil,
    required this.subState,
    required this.priceFen,
    required this.suspendReason,
  });

  final ChainSubscriptionPlan plan;
  final int startedAt;
  final int chargeAt;
  final BigInt chargeFen;
  final int paidUntil;
  final String subState;

  /// 订阅者已授权用于自动续费的价格；创作者改价后据此提示重新签名。
  final BigInt priceFen;

  /// 挂起原因：`needReconsent` / `insufficientBalance` /
  /// `identityBindingUnavailable` / `null`（非挂起态）。
  final String? suspendReason;

  /// Active 与已签名取消但仍在已付周期内的 Cancelled 都继续提供权益；
  /// suspended / issuerPaused 暂停期无权益。
  bool isEffectiveAt(int chainNowMs) =>
      (subState == 'active' || subState == 'cancelled') &&
      chainNowMs < paidUntil;
}

/// 同一 finalized 区块上的订阅状态与共识时间戳，避免本机时钟参与权益判断。
class FinalizedSubscriptionSnapshot {
  const FinalizedSubscriptionSnapshot({
    required this.state,
    required this.chainNowMs,
    required this.block,
  });

  final ChainSubscriptionState? state;
  final int chainNowMs;
  final CitizenBlockRef block;
}

/// finalized `CreatorPlans` 中的单个链上付款档位。
class ChainCreatorTier {
  const ChainCreatorTier({
    required this.tierId,
    required this.tierName,
    required this.pricesFen,
  });

  final String tierId;

  /// runtime 升级前已经存在的付款计划可能暂时没有链上名称。
  final String? tierName;
  final Map<String, BigInt> pricesFen;
}

/// 一次账户签名交易 finalized 后的最小定位；Cloudflare 按哈希从该区块取得交易。
typedef FinalizedSubscriptionTransaction = ({
  String txHash,
  int usedNonce,
  String blockHash,
});

/// SquarePost 订阅 SCALE 与标准热钱包 extrinsic 入口。
///
/// CitizenApp 只提交需要账户签名的订阅、取消、换档和创作者档位管理。首次扣款后的
/// 真实公历到期时间及后续自动扣款全部由 runtime 根据共识时间戳完成。
class SubscriptionChain {
  SubscriptionChain({
    CitizenSdk? chain,
    CitizenSdk? transactions,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenBlockRef> Function()? getBestHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
  }) : _getBestHead =
           getBestHead ??
           transactions?.getBestHead ??
           chain?.getBestHead ??
           (() => throw StateError('未配置getBestHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           transactions?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _executePreparedTransaction =
           executePreparedTransaction ??
           transactions?.executePreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置executePreparedTransaction')),
       _cancelPreparedTransactionExecution =
           cancelPreparedTransactionExecution ??
           transactions?.cancelPreparedTransactionExecution ??
           ((String executionId) =>
               throw StateError('未配置cancelPreparedTransactionExecution')),
       _consumePreparedTransactionQrResponse =
           consumePreparedTransactionQrResponse ??
           transactions?.consumePreparedTransactionQrResponse ??
           ((String executionId, String response) =>
               throw StateError('未配置consumePreparedTransactionQrResponse'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenBlockRef> Function() _getBestHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<CitizenTransactionExecution> Function(String preparationId)
  _executePreparedTransaction;
  final Future<void> Function(String executionId)
  _cancelPreparedTransactionExecution;
  final Future<CitizenTransactionExecutionCompleted> Function(
    String executionId,
    String response,
  )
  _consumePreparedTransactionQrResponse;

  static const int _planPlatformTag = 0;
  static const int _planCreatorTag = 1;

  static int membershipLevelByte(String level) => switch (level) {
    'freedom' => 0,
    'democracy' => 1,
    'spark' => 2,
    _ => throw ArgumentError('未知平台会员档：$level'),
  };

  static int billingPeriodByte(String period) => switch (period) {
    'monthly' => 0,
    'quarterly' => 1,
    'yearly' => 2,
    _ => throw ArgumentError('未知订阅周期：$period'),
  };

  Future<FinalizedSubscriptionTransaction> subscribePlatform({
    required Uint8List signerPublicKey,
    required String level,
    required BigInt expectedPriceFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildSubscribePlatformCall(
      await _getRuntimeContext(await _getBestHead()),
      membershipLevelByte(level),
      expectedPriceFen,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  Future<FinalizedSubscriptionTransaction> subscribeCreator({
    required Uint8List signerPublicKey,
    required String creatorCid,
    required String tierId,
    required String billingPeriod,
    required BigInt expectedPriceFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildSubscribeCreatorCall(
      await _getRuntimeContext(await _getBestHead()),
      creatorCid,
      tierId,
      billingPeriod,
      expectedPriceFen,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  Future<FinalizedSubscriptionTransaction> cancelPlatform({
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildCancelPlatformCall(
      await _getRuntimeContext(await _getBestHead()),
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  Future<FinalizedSubscriptionTransaction> cancelCreator({
    required Uint8List signerPublicKey,
    required String creatorCid,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildCancelCreatorCall(
      await _getRuntimeContext(await _getBestHead()),
      creatorCid,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  Future<FinalizedSubscriptionTransaction> changePlatformPlan({
    required Uint8List signerPublicKey,
    required String level,
    required BigInt expectedPriceFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildChangePlatformPlanCall(
      await _getRuntimeContext(await _getBestHead()),
      membershipLevelByte(level),
      expectedPriceFen,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  Future<FinalizedSubscriptionTransaction> changeCreatorPlan({
    required Uint8List signerPublicKey,
    required String creatorCid,
    required String tierId,
    required String billingPeriod,
    required BigInt expectedPriceFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildChangeCreatorPlanCall(
      await _getRuntimeContext(await _getBestHead()),
      creatorCid,
      tierId,
      billingPeriod,
      expectedPriceFen,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  /// 创作者一次签名覆盖链上付款档位；Cloudflare 保存展示字段时不得再索要业务签名。
  Future<FinalizedSubscriptionTransaction> setCreatorPlans({
    required Uint8List signerPublicKey,
    required List<CreatorTierInput> tiers,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildSetCreatorPlansCall(
      await _getRuntimeContext(await _getBestHead()),
      tiers,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  /// 只更新既有档位名称，不改变价格、订阅授权或续费状态。
  Future<FinalizedSubscriptionTransaction> updateCreatorTierName({
    required Uint8List signerPublicKey,
    required String tierId,
    required String tierName,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async => _submitFinalized(
    callData: buildUpdateCreatorTierNameCall(
      await _getRuntimeContext(await _getBestHead()),
      tierId,
      tierName,
    ),
    signerPublicKey: signerPublicKey,
    externalSigning: externalSigning,
  );

  /// 在同一个 finalized 区块读取订阅真态与 `Timestamp.Now`。
  Future<FinalizedSubscriptionSnapshot> fetchSubscriptionSnapshot({
    required String cidNumber,
    String? creatorCid,
    CitizenBlockRef? at,
  }) async {
    final block = at ?? await _getFinalizedHead();
    final runtime = await _getRuntimeContext(block);
    final subscriptionKey = buildSubscriptionStorageKey(
      runtime,
      cidNumber,
      creatorCid,
    );
    final timestampKey = runtime.storageKey('Timestamp', 'Now');
    final values = await _getStorageBatch(block, <Uint8List>[
      subscriptionKey,
      timestampKey,
    ]);
    final timestamp = values[1];
    if (timestamp == null || timestamp.length != 8) {
      throw const FormatException('finalized Timestamp.Now 缺失或编码不合法');
    }
    return FinalizedSubscriptionSnapshot(
      state: values[0] == null ? null : decodeSubscriptionState(values[0]!),
      chainNowMs: CitizenScale.readUnsigned(timestamp, 0, 8).toInt(),
      block: block,
    );
  }

  /// 在同一个 finalized 区块读取创作者付款档位及其链上名称。
  Future<List<ChainCreatorTier>> fetchCreatorPlans(
    String creatorCid, {
    CitizenBlockRef? at,
  }) async {
    final block = at ?? await _getFinalizedHead();
    return fetchCreatorPlansAtBlock(creatorCid, block);
  }

  /// 在调用方已经确认的 finalized 区块读取创作者档位。
  ///
  /// 创作者页先在某一 finalized 区块读取会员资格，再把同一区块哈希传入本方法，避免
  /// 页面刷新期间重复取区块头，或把两个不同高度的会员态和创作者档位拼成一个快照。
  Future<List<ChainCreatorTier>> fetchCreatorPlansAtBlock(
    String creatorCid,
    CitizenBlockRef block,
  ) async {
    final runtime = await _getRuntimeContext(block);
    final key = buildCreatorPlansStorageKey(runtime, creatorCid);
    final data = await _getStorage(block, key);
    if (data == null) return const <ChainCreatorTier>[];
    final priceTiers = decodeCreatorPlans(data);
    final encodedNames = await _getStorageBatch(block, <Uint8List>[
      for (final tier in priceTiers)
        buildCreatorTierNameStorageKey(runtime, creatorCid, tier.tierId),
    ]);
    return List.unmodifiable([
      for (var index = 0; index < priceTiers.length; index++)
        ChainCreatorTier(
          tierId: priceTiers[index].tierId,
          tierName: encodedNames[index] == null
              ? null
              : decodeCreatorTierName(encodedNames[index]!),
          pricesFen: priceTiers[index].pricesFen,
        ),
    ]);
  }

  Future<FinalizedSubscriptionTransaction> _submitFinalized({
    required Uint8List callData,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('订阅交易签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null) {
      throw StateError(completed.poolRejectionReason ?? '订阅交易执行失败');
    }
    return (
      txHash: _hexPrefixed(completed.transactionHash),
      usedNonce: prepared.nonce.toInt(),
      blockHash: completed.execution!.block.hash,
    );
  }

  static Uint8List buildSubscribePlatformCall(
    CitizenRuntimeContext runtime,
    int levelByte,
    BigInt expectedPriceFen,
  ) => _platformCall(runtime, 'subscribe', levelByte, expectedPriceFen);

  static Uint8List buildSubscribeCreatorCall(
    CitizenRuntimeContext runtime,
    String creatorCid,
    String tierId,
    String billingPeriod,
    BigInt expectedPriceFen,
  ) => _creatorCall(
    runtime,
    'subscribe',
    creatorCid,
    tierId,
    billingPeriod,
    expectedPriceFen,
  );

  static Uint8List buildCancelPlatformCall(CitizenRuntimeContext runtime) =>
      runtime.encodeCall('SquarePost', 'cancel', [_issuer(null)]);

  static Uint8List buildCancelCreatorCall(
    CitizenRuntimeContext runtime,
    String creatorCid,
  ) => runtime.encodeCall('SquarePost', 'cancel', [_issuer(creatorCid)]);

  static Uint8List buildChangePlatformPlanCall(
    CitizenRuntimeContext runtime,
    int levelByte,
    BigInt expectedPriceFen,
  ) => _platformCall(
    runtime,
    'change_subscription_plan',
    levelByte,
    expectedPriceFen,
  );

  static Uint8List buildChangeCreatorPlanCall(
    CitizenRuntimeContext runtime,
    String creatorCid,
    String tierId,
    String billingPeriod,
    BigInt expectedPriceFen,
  ) => _creatorCall(
    runtime,
    'change_subscription_plan',
    creatorCid,
    tierId,
    billingPeriod,
    expectedPriceFen,
  );

  static Uint8List _platformCall(
    CitizenRuntimeContext runtime,
    String method,
    int levelByte,
    BigInt expectedPriceFen,
  ) => runtime.encodeCall('SquarePost', method, [
    _issuer(null),
    (variant: 'Platform', fields: <Object>[_membershipLevel(levelByte)]),
    _price(expectedPriceFen),
  ]);

  static Uint8List _creatorCall(
    CitizenRuntimeContext runtime,
    String method,
    String creatorCid,
    String tierId,
    String billingPeriod,
    BigInt expectedPriceFen,
  ) => runtime.encodeCall('SquarePost', method, [
    _issuer(creatorCid),
    (
      variant: 'Creator',
      fields: <Object>[_tierId(tierId), _billingPeriod(billingPeriod)],
    ),
    _price(expectedPriceFen),
  ]);

  static Uint8List buildSetCreatorPlansCall(
    CitizenRuntimeContext runtime,
    List<CreatorTierInput> tiers,
  ) => runtime.encodeCall('SquarePost', 'set_creator_plans', [
    [
      for (final tier in tiers)
        [
          _tierId(tier.tierId),
          _tierName(tier.tierName),
          [
            for (final price in tier.pricesFen)
              [_billingPeriod(price.billingPeriod), _price(price.priceFen)],
          ],
        ],
    ],
  ]);

  static Uint8List buildUpdateCreatorTierNameCall(
    CitizenRuntimeContext runtime,
    String tierId,
    String tierName,
  ) => runtime.encodeCall('SquarePost', 'update_creator_tier_name', [
    _tierId(tierId),
    _tierName(tierName),
  ]);

  static CitizenScaleVariant _issuer(String? cid) => cid == null
      ? (variant: 'Platform', fields: const [])
      : (variant: 'Creator', fields: [_cidNumber(cid)]);

  static CitizenScaleVariant membershipLevelVariant(String level) =>
      _membershipLevel(membershipLevelByte(level));

  static CitizenScaleVariant _membershipLevel(int levelByte) => (
    variant: switch (levelByte) {
      0 => 'Freedom',
      1 => 'Democracy',
      2 => 'Spark',
      _ => throw ArgumentError('未知平台会员档：$levelByte'),
    },
    fields: const [],
  );

  static CitizenScaleVariant _billingPeriod(String period) => (
    variant: const [
      'Monthly',
      'Quarterly',
      'Yearly',
    ][billingPeriodByte(period)],
    fields: const [],
  );

  static Uint8List _cidNumber(String cidNumber) {
    final bytes = Uint8List.fromList(utf8.encode(cidNumber));
    if (bytes.isEmpty || bytes.length > 32) {
      throw ArgumentError('cid_number 的 UTF-8 长度必须为 1-32 字节');
    }
    return bytes;
  }

  static Uint8List _tierId(String value) {
    if (value.isEmpty ||
        value.length > 32 ||
        value.codeUnits.any((byte) => byte > 0x7f)) {
      throw ArgumentError('tier_id 必须为 1-32 字节 ASCII');
    }
    return Uint8List.fromList(value.codeUnits);
  }

  static Uint8List _tierName(String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    _validateTierName(value, bytes.length, _argumentTierName);
    return bytes;
  }

  static Never _argumentTierName(String message) =>
      throw ArgumentError(message);

  static Never _formatTierName(String message) =>
      throw FormatException(message);

  static void _validateTierName(
    String tierName,
    int byteLength,
    Never Function(String) fail,
  ) {
    if (tierName.isEmpty || tierName.trim() != tierName) {
      fail('tier_name 不得为空或含首尾空白');
    }
    if (tierName.runes.length > 20 || byteLength > 80) {
      fail('tier_name 最多 20 个 Unicode 标量且最多 80 个 UTF-8 字节');
    }
    if (tierName.runes.any(
      (value) => value <= 0x1f || (value >= 0x7f && value <= 0x9f),
    )) {
      fail('tier_name 不得含控制字符');
    }
  }

  static BigInt _price(BigInt value) {
    if (value <= BigInt.zero) throw ArgumentError('订阅金额必须大于 0');
    if (value.bitLength > 128) throw ArgumentError('金额超出 u128 范围');
    return value;
  }

  static Uint8List buildSubscriptionStorageKey(
    CitizenRuntimeContext runtime,
    String cidNumber,
    String? creatorCid,
  ) => runtime.storageKey('SquarePost', 'Subscriptions', [
    [_cidNumber(cidNumber), _issuer(creatorCid)],
  ]);

  static Uint8List buildCreatorPlansStorageKey(
    CitizenRuntimeContext runtime,
    String creatorCid,
  ) => runtime.storageKey('SquarePost', 'CreatorPlans', [
    _cidNumber(creatorCid),
  ]);

  static Uint8List buildCreatorTierNameStorageKey(
    CitizenRuntimeContext runtime,
    String creatorCid,
    String tierId,
  ) => runtime.storageKey('SquarePost', 'CreatorTierNames', [
    _cidNumber(creatorCid),
    _tierId(tierId),
  ]);

  /// 严格解码 `SubscriptionState`；截断、非法枚举和尾随字节直接报错，禁止降级成无订阅。
  static ChainSubscriptionState decodeSubscriptionState(Uint8List data) {
    final reader = _ScaleReader(data);
    final plan = _readPlan(reader);
    final startedAt = reader.u64();
    final chargeAt = reader.u64();
    final chargeFen = reader.u128();
    final paidUntil = reader.u64();
    final status = switch (reader.byte()) {
      0 => 'active',
      1 => 'cancelled',
      2 => 'terminated',
      3 => 'suspended',
      4 => 'issuerPaused',
      _ => throw const FormatException('sub_state 枚举不合法'),
    };
    final priceFen = reader.u128();
    final suspendTag = reader.byte();
    final String? suspendReason;
    if (suspendTag == 0) {
      suspendReason = null;
    } else if (suspendTag == 1) {
      suspendReason = switch (reader.byte()) {
        0 => 'needReconsent',
        1 => 'insufficientBalance',
        2 => 'identityBindingUnavailable',
        _ => throw const FormatException('suspend_reason 枚举不合法'),
      };
    } else {
      throw const FormatException('suspend_reason Option 枚举不合法');
    }
    reader.requireEnd();
    if (paidUntil <= chargeAt) {
      throw const FormatException('paid_until 必须晚于最近扣款时间');
    }
    return ChainSubscriptionState(
      plan: plan,
      startedAt: startedAt,
      chargeAt: chargeAt,
      chargeFen: chargeFen,
      paidUntil: paidUntil,
      subState: status,
      priceFen: priceFen,
      suspendReason: suspendReason,
    );
  }

  /// 严格解码 `CreatorTiers`；价格、周期和 tier_id 全部来自 finalized 链上真态。
  static List<ChainCreatorTier> decodeCreatorPlans(Uint8List data) {
    final reader = _ScaleReader(data);
    final count = reader.compactLength(max: 10, allowZero: true);
    final tiers = <ChainCreatorTier>[];
    final tierIds = <String>{};
    for (var index = 0; index < count; index++) {
      final tierId = reader.ascii(maxLength: 32);
      if (!tierIds.add(tierId)) {
        throw const FormatException('链上 creator tier_id 重复');
      }
      final priceCount = reader.compactLength(max: 3);
      final prices = <String, BigInt>{};
      for (var priceIndex = 0; priceIndex < priceCount; priceIndex++) {
        final period = switch (reader.byte()) {
          0 => 'monthly',
          1 => 'quarterly',
          2 => 'yearly',
          _ => throw const FormatException('billing_period 枚举不合法'),
        };
        final price = reader.u128();
        if (price <= BigInt.zero || prices.containsKey(period)) {
          throw const FormatException('链上创作者周期价格不合法');
        }
        prices[period] = price;
      }
      tiers.add(
        ChainCreatorTier(tierId: tierId, tierName: null, pricesFen: prices),
      );
    }
    reader.requireEnd();
    return List.unmodifiable(tiers);
  }

  /// 严格解码独立 `CreatorTierNames` storage；缺失由调用方表达为 null。
  static String decodeCreatorTierName(Uint8List data) {
    final reader = _ScaleReader(data);
    final tierName = reader.utf8String(maxByteLength: 80);
    reader.requireEnd();
    _validateTierName(tierName, utf8.encode(tierName).length, _formatTierName);
    return tierName;
  }

  static ChainSubscriptionPlan _readPlan(_ScaleReader reader) {
    final tag = reader.byte();
    if (tag == _planPlatformTag) {
      final level = switch (reader.byte()) {
        0 => 'freedom',
        1 => 'democracy',
        2 => 'spark',
        _ => throw const FormatException('membership_level 枚举不合法'),
      };
      return ChainSubscriptionPlan.platform(level);
    }
    if (tag == _planCreatorTag) {
      final tierId = reader.ascii(maxLength: 32);
      final period = switch (reader.byte()) {
        0 => 'monthly',
        1 => 'quarterly',
        2 => 'yearly',
        _ => throw const FormatException('billing_period 枚举不合法'),
      };
      return ChainSubscriptionPlan.creator(tierId, period);
    }
    throw const FormatException('subscription plan 枚举不合法');
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static String _hexPrefixed(Uint8List bytes) => '0x${_hex(bytes)}';
}

class _ScaleReader {
  _ScaleReader(this.data);

  final Uint8List data;
  int offset = 0;

  int byte() {
    if (offset >= data.length) throw const FormatException('SCALE 数据截断');
    return data[offset++];
  }

  int compactLength({required int max, bool allowZero = false}) {
    final (length, width) = CitizenScale.readCompact(data, offset);
    if (width > 2) throw const FormatException('紧凑长度编码超出当前协议边界');
    offset += width;
    if ((!allowZero && length == 0) || length > max) {
      throw const FormatException('紧凑长度不合法');
    }
    return length;
  }

  String ascii({required int maxLength}) {
    final length = compactLength(max: maxLength);
    if (offset + length > data.length) {
      throw const FormatException('SCALE 字节串截断');
    }
    final bytes = data.sublist(offset, offset + length);
    offset += length;
    if (bytes.any((value) => value > 0x7f)) {
      throw const FormatException('tier_id 必须为 ASCII');
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  String utf8String({required int maxByteLength}) {
    final length = compactLength(max: maxByteLength);
    if (offset + length > data.length) {
      throw const FormatException('SCALE UTF-8 字节串截断');
    }
    final bytes = data.sublist(offset, offset + length);
    offset += length;
    return utf8.decode(bytes, allowMalformed: false);
  }

  int u64() => CitizenScale.readUnsigned(data, _take(8), 8).toInt();

  BigInt u128() => CitizenScale.readUnsigned(data, _take(16), 16);

  int _take(int length) {
    final start = offset;
    if (start + length > data.length) {
      throw const FormatException('SCALE 整数截断');
    }
    offset += length;
    return start;
  }

  void requireEnd() {
    if (offset != data.length) throw const FormatException('SCALE 存在尾随字节');
  }
}
