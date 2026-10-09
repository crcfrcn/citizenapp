import 'package:citizenapp/security/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:citizenapp/8964/services/square_api_client.dart'
    show SquareApiConfig, SquareSession;
import 'package:citizenapp/8964/services/square_request_signer.dart';
import 'package:citizenapp/account/creator/creator_overview.dart';
import 'package:citizenapp/account/creator/creator_plan.dart';

/// 创作者档位/概览的边缘（Cloudflare）数据源。
///
/// tier_id、tier_name、周期和价格均以 finalized 链状态为真源；Cloudflare 只保存查询投影。
abstract interface class CreatorApi {
  /// 读我的档位；无档位返回 null。
  Future<CreatorPlan?> fetchMyPlan(SquareSession session);

  /// 读概览（订阅人数 / 预计月收入 / 档位数，均为预计值）。
  Future<CreatorOverview> fetchOverview(SquareSession session);

  /// 链上一次签名交易 finalized 后确认查询投影；本请求不得再触发账户业务签名。
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  });

  /// 读某创作者档位及当前会话对其订阅状态；两者均来自 CitizenServe finalized 投影。
  Future<CreatorView> fetchViewOf(
    SquareSession session,
    String creatorCidNumber,
  );

  /// 订阅/取消创作者会员上链后确认查询投影（best-effort，链上已是真源）。
  Future<void> confirmCreatorSubscription({
    required String creatorCidNumber,
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  });
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
    required this.subscriptionStatus,
    required this.paidUntil,
    required this.active,
  });

  final String tierId;
  final String billingPeriod;
  final String subscriptionStatus;
  final int paidUntil;
  final bool active;

  factory CreatorSubscriptionState.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriptionState(
      tierId: json['tier_id']?.toString() ?? '',
      billingPeriod: json['billing_period']?.toString() ?? '',
      subscriptionStatus: json['subscription_status']?.toString() ?? '',
      paidUntil: json['paid_until'] is int ? json['paid_until'] as int : 0,
      active: json['active'] == true,
    );
  }
}

class CreatorApiException implements Exception {
  const CreatorApiException(this.message);
  final String message;
  @override
  String toString() => 'CreatorApiException: $message';
}

/// 生产实现：直连 Cloudflare Worker，复用会话与设备级请求认证。
///
/// 依赖 BFF 端点（另立 Cloudflare 卡实现）：
///   GET  /membership/creators/{cid}/plans
///   GET  /membership/creator/overview
///   POST /membership/creators/plans             （校验 finalized 链状态后覆盖查询投影）
class CreatorApiHttp implements CreatorApi {
  CreatorApiHttp({String? baseUrl, http.Client? httpClient})
    : baseUrl = SquareApiConfig.normalizeBaseUrl(
        baseUrl ?? SquareApiConfig.defaultBaseUrl,
      ),
      _http = HttpsOnlyClient(httpClient ?? http.Client());

  final String baseUrl;
  final http.Client _http;

  @override
  Future<CreatorPlan?> fetchMyPlan(SquareSession session) async {
    return (await fetchViewOf(session, session.cidNumber)).plan;
  }

  @override
  Future<CreatorOverview> fetchOverview(SquareSession session) async {
    final data = await _getJson('/membership/creator/overview', session);
    final overview = data['overview'];
    if (data["ok"] != true ||
        overview is! Map<String, dynamic> ||
        [
          "subscriber_count",
          "monthly_income_fen",
          "tier_count",
        ].any((key) => overview[key] is! int || (overview[key] as int) < 0)) {
      throw const CreatorApiException("创作者概览响应不完整");
    }
    return CreatorOverview.fromJson({
      ...overview,
      "month_income_fen": overview["monthly_income_fen"],
    });
  }

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    final saved = await _postFinalizedProjectionJson(
      '/membership/creators/plans',
      {'tx_hash': txHash, 'block_hash': blockHashHex},
      session,
    );
    if (saved['ok'] != true ||
        saved['tx_hash'] != txHash ||
        saved['block_hash'] != blockHashHex) {
      throw const CreatorApiException('创作者档位确认回执不一致');
    }
    return await fetchMyPlan(session) ?? CreatorPlan.empty(session.cidNumber);
  }

  @override
  Future<CreatorView> fetchViewOf(
    SquareSession session,
    String creatorCidNumber,
  ) async {
    final data = await _getJson(
      '/membership/creators/${Uri.encodeComponent(creatorCidNumber)}/plans',
      session,
    );
    if (data['ok'] != true ||
        data['tiers'] is! List ||
        data['membership_active'] is! bool) {
      throw const CreatorApiException('创作者档位响应不完整');
    }
    final subscription = data['subscription'];
    if (subscription != null && subscription is! Map<String, dynamic>) {
      throw const CreatorApiException('订阅响应无效');
    }
    return CreatorView(
      plan: CreatorPlan.fromJson({
        ...data,
        'creator_cid_number': creatorCidNumber,
      }),
      subscription: subscription == null
          ? null
          : CreatorSubscriptionState.fromJson(
              subscription as Map<String, dynamic>,
            ),
    );
  }

  @override
  Future<void> confirmCreatorSubscription({
    required String creatorCidNumber,
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    await _postFinalizedProjectionJson(
      '/membership/creators/${Uri.encodeComponent(creatorCidNumber)}/subscription/confirm',
      {'tx_hash': txHash, 'block_hash': blockHashHex},
      session,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    SquareSession session,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _http
        .get(uri, headers: await _headers('GET', uri, '', session))
        .timeout(const Duration(seconds: 20));
    await session.validateCurrent();
    return _decode(response);
  }

  /// 链上业务已经由账户签名并 finalized；投影确认携带会话及purpose=request的MLS证明，不再次请求钱包交易签名。
  Future<Map<String, dynamic>> _postFinalizedProjectionJson(
    String path,
    Map<String, Object?> body,
    SquareSession session,
  ) async {
    await session.validateCurrent();
    final encoded = jsonEncode(body);
    final uri = Uri.parse('$baseUrl$path');
    final response = await _http
        .post(
          uri,
          headers: await _headers('POST', uri, encoded, session),
          body: encoded,
        )
        .timeout(const Duration(seconds: 20));
    await session.validateCurrent();
    return _decode(response);
  }

  Future<Map<String, String>> _headers(
    String method,
    Uri uri,
    String body,
    SquareSession session,
  ) async {
    await session.validateCurrent();
    final signer = session.authenticateRequest;
    if (signer == null) {
      throw const CreatorApiException('MLS请求认证未接入，请重新登录');
    }
    return {
      'content-type': 'application/json; charset=utf-8',
      'authorization': 'Bearer ${session.sessionToken}',
      ...await squareRequestHeaders(
        method: method,
        uri: uri,
        body: body,
        sessionToken: session.sessionToken,
        authenticate: signer,
      ),
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw CreatorApiException('创作者服务响应不是 JSON：${response.statusCode}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw CreatorApiException('创作者服务响应结构不合法：${response.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CreatorApiException(
        decoded['message']?.toString() ?? '创作者服务请求失败（${response.statusCode}）',
      );
    }
    return decoded;
  }
}

/// 离线内存实现：本地开发 / 测试用（不依赖真 Cloudflare）。
class FakeCreatorApi implements CreatorApi {
  FakeCreatorApi({CreatorPlan? initialPlan, CreatorOverview? overview})
    : _plan = initialPlan,
      _overview = overview;

  CreatorPlan? _plan;
  final CreatorOverview? _overview;

  String? lastSaveTxHash;

  @override
  Future<CreatorPlan?> fetchMyPlan(SquareSession session) async => _plan;

  @override
  Future<CreatorOverview> fetchOverview(SquareSession session) async =>
      _overview ??
      CreatorOverview(
        subscriberCount: 0,
        monthIncomeFen: 0,
        tierCount: _plan?.tiers.length ?? 0,
      );

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    lastSaveTxHash = txHash;
    _plan ??= CreatorPlan.empty(session.cidNumber);
    return _plan!;
  }

  @override
  Future<CreatorView> fetchViewOf(
    SquareSession session,
    String creatorCidNumber,
  ) async => CreatorView(plan: _plan, subscription: null);

  @override
  Future<void> confirmCreatorSubscription({
    required String creatorCidNumber,
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {}
}
