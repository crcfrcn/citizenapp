// 管理创作者资格、档位方案、概览及登记关系读取。

import 'dart:convert';
import 'package:citizen_network/http.dart';
import 'package:http/http.dart' as http;
import 'package:citizen_user/api.dart' show SquareApiConfig, SquareSession;
import 'package:citizen_chain/service.dart';
import 'package:citizen_storage/user.dart' as wallet_store show Creator;
import 'dart:async';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'package:citizen_user/identity/state.dart' show FinalizedIdentity, FinalizedIdentityResolver;
import 'package:citizen_scanner/sign.dart';

// 发现云端登记订阅关系，连接创作者链状态及统计读取。

/// 云端只发现已登记关系，链上状态、档位和统计由轻节点读取。
abstract interface class CreatorApi {
  Future<CreatorSubscriberPage> fetchSubscribers(
    SquareSession session, {
    String? cursor,
  });
  Future<void> registerSubscription({
    required SquareSession session,
    required String creatorCid,
    required int finalBlock,
  });
}

class CreatorSubscriberPage {
  const CreatorSubscriberPage({required this.cidNumbers, this.nextCursor});
  final List<String> cidNumbers;
  final String? nextCursor;
}

class CreatorView {
  const CreatorView({required this.plan, required this.subscription});

  final CreatorPlan? plan;
  final CreatorSubscriptionState? subscription;
}

class CreatorSubscriptionState {
  const CreatorSubscriptionState({
    required this.tierId,
    required this.billingPeriod,
    required this.subState,
    required this.paidUntil,
  });

  final String tierId;
  final String billingPeriod;
  final String subState;
  final int paidUntil;
}

class CreatorApiException implements Exception {
  const CreatorApiException(this.message, {this.statusCode, this.errorCode});
  final String message;
  final int? statusCode;
  final String? errorCode;
  @override
  String toString() => 'CreatorApiException: $message';
}

class CreatorApiHttp implements CreatorApi {
  CreatorApiHttp({String? baseUrl, http.Client? httpClient})
    : baseUrl = SquareApiConfig.normalizeBaseUrl(
        baseUrl ?? SquareApiConfig.defaultBaseUrl,
      ),
      _http = HttpsOnlyClient(httpClient ?? http.Client());
  final String baseUrl;
  final http.Client _http;
  final Map<(SquareSession, Uri), Future<Map<String, dynamic>>> _reads = {};
  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    SquareSession s, {
    Map<String, Object?>? body,
  }) async {
    await s.validateCurrent();
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body == null ? '' : jsonEncode(body);
    final sign = s.authenticateRequest;
    if (sign == null) {
      throw const CreatorApiException('MLS请求认证未就绪');
    }
    final headers = {
      'content-type': 'application/json; charset=utf-8',
      'authorization': 'Bearer ${s.sessionToken}',
      ...await squareRequestHeaders(
        method: method,
        uri: uri,
        body: encoded,
        sessionToken: s.sessionToken,
        authenticate: sign,
      ),
    };
    final response =
        await (method == 'GET'
                ? _http.get(uri, headers: headers)
                : _http.put(uri, headers: headers, body: encoded))
            .timeout(const Duration(seconds: 20));
    await s.validateCurrent();
    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw const CreatorApiException('登记响应无效');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        raw['is_ok'] != true) {
      throw CreatorApiException(
        '创作者请求失败',
        statusCode: response.statusCode,
        errorCode: raw['error_code'] as String?,
      );
    }
    return raw;
  }

  @override
  Future<CreatorSubscriberPage> fetchSubscribers(
    SquareSession session, {
    String? cursor,
  }) async {
    final path =
        '/membergate/creator/subscribers${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}';
    final uri = Uri.parse('$baseUrl$path');
    final key = (session, uri);
    final pending = _reads.putIfAbsent(
      key,
      () => _request('GET', path, session),
    );
    late Map<String, dynamic> data;
    try {
      data = await pending;
    } finally {
      if (identical(_reads[key], pending)) {
        _reads.remove(key);
      }
    }
    final list = data['cid_numbers'];
    final next = data['next_cursor'];
    if (list is! List ||
        list.any(
          (v) =>
              v is! String ||
              !RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(v),
        ) ||
        next != null && next is! String) {
      throw const CreatorApiException('登记分页无效');
    }
    return CreatorSubscriberPage(
      cidNumbers: List<String>.from(list),
      nextCursor: next as String?,
    );
  }

  @override
  Future<void> registerSubscription({
    required SquareSession session,
    required String creatorCid,
    required int finalBlock,
  }) async {
    await _request(
      'PUT',
      '/membergate/creators/${Uri.encodeComponent(creatorCid)}/subscription',
      session,
      body: {'final_block': finalBlock},
    );
  }

  void close() => _http.close();
}

class FakeCreatorApi implements CreatorApi {
  FakeCreatorApi({this.subscribers = const []});
  final List<String> subscribers;
  final Set<String> registered = {};
  @override
  Future<CreatorSubscriberPage> fetchSubscribers(
    SquareSession session, {
    String? cursor,
  }) async => CreatorSubscriberPage(cidNumbers: subscribers);
  @override
  Future<void> registerSubscription({
    required SquareSession session,
    required String creatorCid,
    required int finalBlock,
  }) async {
    registered.add(creatorCid);
  }
}

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

// 定义创作者档位、可选周期及以分计价的链上方案。

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

/// 将轻节点已核验的链上档位转换为页面模型；金额越界直接拒绝。
CreatorPlan creatorPlanFromChain(List<ChainCreatorTier>? tiers) {
  if (tiers == null) {
    throw const FormatException('创作者档位尚未读取');
  }
  int? price(ChainCreatorTier t, String period) {
    final value = t.pricesFen[period];
    if (value == null) {
      return null;
    }
    if (value <= BigInt.zero || value > BigInt.from(9007199254740991)) {
      throw const FormatException('创作者价格越界');
    }
    return value.toInt();
  }

  return CreatorPlan(
    tiers: List.unmodifiable([
      for (final t in tiers)
        CreatorTier(
          tierId: t.tierId,
          tierName: t.tierName ?? t.tierId,
          monthFen: price(t, 'monthly'),
          quarterFen: price(t, 'quarterly'),
          yearFen: price(t, 'yearly'),
        ),
    ]),
  );
}

// 协调创作者资格、档位管理和概览读取，并按最终链事实确认。

enum CreatorMembershipStatus { unresolved, inactive, active }

/// 页面投影；会员、档位及统计分别就绪，链上事实仍来自统一读模型。
class CreatorPageData {
  const CreatorPageData({
    this.membershipStatus = CreatorMembershipStatus.unresolved,
    this.memberLevel,
    this.plan,
    this.overview,
  });

  final CreatorMembershipStatus membershipStatus;
  final String? memberLevel;
  final CreatorPlan? plan;
  final CreatorOverview? overview;
}

class CreatorException implements Exception {
  const CreatorException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 创作者管理编排：当前有效的平台会员可创建档位、读取概览并收取订阅款。
///
/// - 保存档位只签一次 `set_creator_plans` 链上交易；名称与价格均由 finalized 链状态确认。
class CreatorService {
  CreatorService({
    ChainDataService? chainData,
    CitizenSdk? wallet,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    CreatorApi? api,
    SubscriptionChain? subscriptionChain,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
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
  }) : _chainData =
           chainData ?? (chain == null ? null : ChainDataService.forSdk(chain)),
       _api = api ?? CreatorApiHttp(),
       _subscriptionChain =
           subscriptionChain ??
           SubscriptionChain(
             chain: chain,
             transactions: transactions,
             getFinalizedHead: getFinalizedHead,
             getStorageBatch: getStorageBatch,
             getStorage: getStorage,
             prepareTransaction: prepareTransaction,
             executePreparedTransaction: executePreparedTransaction,
             cancelPreparedTransactionExecution:
                 cancelPreparedTransactionExecution,
             consumePreparedTransactionQrResponse:
                 consumePreparedTransactionQrResponse,
           ),
       _identityResolver = identityResolver,
       _session = sessionProvider,
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState'));
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final ChainDataService? _chainData;
  final CreatorApi _api;
  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final Map<SquareSession, Future<CreatorPageData>> _loads = {};

  /// 主动刷新取得登记CID集合；档位和统计由统一轻节点读模型提供。
  ///
  /// 页面首帧不等待本方法；[expectedCidNumber] 防止旧会话结果写入新身份页面。
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    final resolution = await _session.resolveSession();
    final session = resolution.session;
    if (session == null) {
      throw CreatorException(resolution.message);
    }
    final expected = expectedCidNumber?.trim() ?? '';
    if (expected.isNotEmpty && session.cidNumber != expected) {
      throw const CreatorException('当前会话与创作者身份不一致，请稍后重试');
    }

    final pending = _loads[session];
    if (pending != null) {
      return pending;
    }
    final task = _loadSession(session);
    _loads[session] = task;
    try {
      return await task;
    } on CreatorException {
      rethrow;
    } on Object {
      throw const CreatorException('创作者刷新失败，已保留本地内容');
    } finally {
      if (identical(_loads[session], task)) {
        _loads.remove(session);
      }
    }
  }

  Future<CreatorPageData> _loadSession(SquareSession session) async {
    await session.validateCurrent();
    final source = _chainData;
    if (source == null) {
      throw const CreatorException('轻节点统计尚未就绪');
    }
    final cached = source.snapshot;
    if (cached == null) {
      throw const CreatorException('轻节点身份尚未就绪');
    }
    final data = await source.ensureOwnCreator(
      genesisHash: cached.genesisHash,
      accountId: session.accountId,
      cidNumber: session.cidNumber,
      bindRev: session.bindRev,
    );
    if (data.accountId != session.accountId ||
        data.own?.identity?.bindRev != session.bindRev) {
      throw const CreatorException('统计身份已变化');
    }
    if (!data.memberActive(session.cidNumber)) {
      return CreatorPageData(
        membershipStatus: CreatorMembershipStatus.inactive,
        plan: creatorPlanFromChain(data.own!.creatorTiers),
      );
    }
    final ids = <String>{};
    String? cursor;
    final cursors = <String>{};
    do {
      final page = await _api.fetchSubscribers(session, cursor: cursor);
      await session.validateCurrent();
      ids.addAll(page.cidNumbers);
      cursor = page.nextCursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const CreatorException('登记分页循环');
      }
    } while (cursor != null);
    final summary = await source.creatorSummary(session.cidNumber, ids);
    await session.validateCurrent();
    final overview = CreatorOverview(
      subscriberCount: summary.subscribers,
      monthlyIncomeFen: summary.monthly,
      blockNumber: summary.block.number.toInt(),
      blockHash: summary.block.hash,
    );
    await wallet_store.Creator.saveSummary(
      session.cidNumber,
      overview.toJson(),
      () => session.isUsable,
    );
    return CreatorPageData(
      membershipStatus: CreatorMembershipStatus.active,
      memberLevel: data.memberLevel(session.cidNumber),
      plan: creatorPlanFromChain(data.own!.creatorTiers),
      overview: overview,
    );
  }

  Future<CreatorOverview?> cachedOverview(String cid) async {
    final value = await wallet_store.Creator.readSummary(cid);
    return value == null ? null : CreatorOverview.fromJson(value);
  }

  /// 覆盖式保存档位：一次链上签名原子写入名称与价格，等待轻节点确认 finalized。
  Future<CreatorPlan> saveTiers(
    List<CreatorTier> tiers, {
    BuildContext? context,
  }) async {
    if (tiers.length > CreatorPlan.maxTiers) {
      throw const CreatorException('最多 ${CreatorPlan.maxTiers} 个会员档');
    }
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    try {
      final data = await _chainData?.refresh();
      if (data == null ||
          _chainData!.isStale ||
          data.accountId != identity.accountId ||
          data.ownCid != identity.snapshot!.cidNumber ||
          data.own?.identity?.bindRev != identity.snapshot!.bindRev) {
        throw const CreatorException('轻节点会员状态尚未核验');
      }
      if (!data.memberActive(data.ownCid!)) {
        throw const CreatorException('需要当前有效的平台会员才能设置创作者会员档');
      }
      await _subscriptionChain.setCreatorPlans(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        tiers: tiers
            .map(
              (tier) => CreatorTierInput(
                tierId: tier.tierId,
                tierName: tier.tierName,
                pricesFen: BillingPeriod.values
                    .where(tier.hasPeriod)
                    .map(
                      (period) => CreatorPeriodPriceInput(
                        billingPeriod: period.key,
                        priceFen: BigInt.from(tier.priceFenOf(period)!),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      return CreatorPlan(tiers: tiers);
    } on CreatorApiException catch (e) {
      throw CreatorException(e.message);
    } on Exception catch (e) {
      throw CreatorException('保存失败：$e');
    }
  }

  /// 只改现有档位名称：当前 CID 控制账户签名，价格、授权、续费与扣款完全不变。
  Future<CreatorPlan> updateTierName({
    BuildContext? context,
    required List<CreatorTier> currentTiers,
    required String tierId,
    required String tierName,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final index = currentTiers.indexWhere((tier) => tier.tierId == tierId);
    if (index < 0) {
      throw const CreatorException('要改名的会员档不存在');
    }
    try {
      await _subscriptionChain.updateCreatorTierName(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        tierId: tierId,
        tierName: tierName,
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      final localTiers = List<CreatorTier>.from(currentTiers);
      localTiers[index] = localTiers[index].copyWith(tierName: tierName);
      final localPlan = CreatorPlan(tiers: List.unmodifiable(localTiers));
      return localPlan;
    } on Exception catch (e) {
      throw CreatorException('改名失败：$e');
    }
  }

  /// 当前默认账户经 finalized 闭环验证后，才可签名 `set_creator_plans` 链上
  /// 交易的唯一签名者。档位归属永久 CID，账户只记录签名事实。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await _identityResolver.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const CreatorException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  Future<String?> _showExternalSigning(
    BuildContext? context,
    CitizenTransactionExternalSigningPending pending,
  ) {
    if (context == null || !context.mounted) {
      return Future<String?>.value();
    }
    return showCitizenSdkQrResponse(
      context,
      request: pending.qrRequest,
      expiresAt: BigInt.from(pending.expiresAt.millisecondsSinceEpoch ~/ 1000),
    );
  }

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _getWalletState().result).defaultAccount;
    if (account == null || account.accountId != accountId) {
      throw const CreatorException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }
}
