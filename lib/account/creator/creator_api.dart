import 'package:citizenapp/system/notifications/notifications.dart';
import 'package:citizenapp/network/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:citizenapp/network/square_api_client.dart'
    show SquareApiConfig, SquareSession;
import 'package:citizenapp/network/square_request_signer.dart';
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
    required String blockHash,
  });

  /// 读某创作者档位及当前会话对其订阅状态；两者均来自 CitizenServe finalized 投影。
  Future<CreatorView> fetchViewOf(SquareSession session, String creatorCid);

  /// 订阅/取消创作者会员上链后确认查询投影（best-effort，链上已是真源）。
  Future<void> confirmCreatorSubscription({
    required String creatorCid,
    required SquareSession session,
    required String txHash,
    required String blockHash,
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
    required this.subState,
    required this.paidUntil,
  });

  final String tierId;
  final String billingPeriod;
  final String subState;
  final int paidUntil;

  factory CreatorSubscriptionState.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriptionState(
      tierId: json['tier_id']?.toString() ?? '',
      billingPeriod: json['billing_period']?.toString() ?? '',
      subState: json['sub_state']?.toString() ?? '',
      paidUntil: json['paid_until'] is int ? json['paid_until'] as int : 0,
    );
  }
}

class CreatorApiException implements Exception {
  const CreatorApiException(this.message, {this.statusCode, this.errorCode});
  final String message;
  final int? statusCode;
  final String? errorCode;
  @override
  String toString() => 'CreatorApiException: $message';
}

/// 生产实现：直连 Cloudflare Worker，复用会话与设备级请求认证。
///
/// 使用CitizenServe现有公开端点：
///   GET  /membergate/creators/{cid}/plans
///   GET  /membergate/creator/overview
///   POST /membergate/creators/plans             （校验 finalized 链状态后覆盖查询投影）
class CreatorApiHttp implements CreatorApi {
  CreatorApiHttp({String? baseUrl, http.Client? httpClient})
    : baseUrl = SquareApiConfig.normalizeBaseUrl(
        baseUrl ?? SquareApiConfig.defaultBaseUrl,
      ),
      _http = HttpsOnlyClient(httpClient ?? http.Client());

  final String baseUrl;
  final http.Client _http;
  final Map<(SquareSession, Uri), Future<http.Response>> _reads = {};
  final Map<SquareSession, Map<String, dynamic>> _ownSnapshots = {};

  Future<Map<String, dynamic>> _ownSnapshot(SquareSession session) async {
    final cached = _ownSnapshots[session];
    final creatorRev = cached?['creator_rev'];
    final raw = await _getJson(
      '/membergate/creator/overview${creatorRev is int && creatorRev > 0 ? '?creator_rev=$creatorRev' : ''}',
      session,
    );
    final Map<String, dynamic> data;
    if (raw['unchanged'] == true) {
      if (cached == null || raw['creator_rev'] != creatorRev) {
        throw const CreatorApiException('创作者版本基线缺失');
      }
      data = cached;
    } else {
      data = raw;
    }
    final plan = data['plan'], overview = data['overview'];
    if (plan is! Map<String, dynamic> ||
        overview is! Map<String, dynamic> ||
        data['creator_rev'] is! int) {
      throw const CreatorApiException('创作者快照不完整');
    }
    CreatorPlan.fromJson(plan);
    for (final key in [
      'subscriber_count',
      'monthly_income_fen',
      'tier_count',
    ]) {
      final value = overview[key];
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw const CreatorApiException('创作者概览响应无效');
      }
    }
    await session.validateCurrent();
    _ownSnapshots.removeWhere(
      (key, _) =>
          key.cidNumber == session.cidNumber && !identical(key, session),
    );
    if (_ownSnapshots.length >= 16) {
      _ownSnapshots.remove(_ownSnapshots.keys.first);
    }
    _ownSnapshots[session] = data;
    await Notifications.instance.acceptCreator(
      session.cidNumber,
      data['creator_rev'] as int,
      {'gated': false, 'plan': plan, 'overview': overview},
      session: session,
    );
    return data;
  }

  @override
  Future<CreatorPlan?> fetchMyPlan(SquareSession session) async {
    final data = await _ownSnapshot(session);
    if (data['plan'] is! Map<String, dynamic>) {
      throw const CreatorApiException('创作者档位响应不完整');
    }
    return CreatorPlan.fromJson(data['plan'] as Map<String, dynamic>);
  }

  @override
  Future<CreatorOverview> fetchOverview(SquareSession session) async {
    final data = await _ownSnapshot(session);
    final overview = data['overview'];
    if (data["is_ok"] != true ||
        overview is! Map<String, dynamic> ||
        [
          "subscriber_count",
          "monthly_income_fen",
          "tier_count",
        ].any((key) => overview[key] is! int || (overview[key] as int) < 0)) {
      throw const CreatorApiException("创作者概览响应不完整");
    }
    return CreatorOverview.fromJson(overview);
  }

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHash,
  }) async {
    final saved = await _postFinalizedProjectionJson(
      '/membergate/creators/plans',
      {'tx_hash': txHash, 'block_hash': blockHash},
      session,
    );
    if (saved['is_ok'] != true ||
        saved['tx_hash'] != txHash ||
        saved['block_hash'] != blockHash) {
      throw const CreatorApiException('创作者档位确认回执不一致');
    }
    return await fetchMyPlan(session) ?? CreatorPlan.empty();
  }

  @override
  Future<CreatorView> fetchViewOf(
    SquareSession session,
    String creatorCid,
  ) async {
    final data = await _getJson(
      '/membergate/creators/${Uri.encodeComponent(creatorCid)}/plans',
      session,
    );
    if (data['is_ok'] != true ||
        data['creator_cid'] != creatorCid ||
        data['tiers'] is! List ||
        data['membergate_active'] is! bool) {
      throw const CreatorApiException('创作者档位响应不完整');
    }
    final subscription = data['subscription'];
    if (subscription != null && subscription is! Map<String, dynamic>) {
      throw const CreatorApiException('订阅响应无效');
    }
    return CreatorView(
      plan: CreatorPlan.fromJson(data),
      subscription: subscription == null
          ? null
          : CreatorSubscriptionState.fromJson(
              subscription as Map<String, dynamic>,
            ),
    );
  }

  @override
  Future<void> confirmCreatorSubscription({
    required String creatorCid,
    required SquareSession session,
    required String txHash,
    required String blockHash,
  }) async {
    await _postFinalizedProjectionJson(
      '/membergate/creators/${Uri.encodeComponent(creatorCid)}/subscription/confirm',
      {'tx_hash': txHash, 'block_hash': blockHash},
      session,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    SquareSession session,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final key = (session, uri);
    final pending = _reads[key] ??= () async {
      try {
        return await _http
            .get(uri, headers: await _headers('GET', uri, '', session))
            .timeout(const Duration(seconds: 20));
      } finally {
        _reads.remove(key);
      }
    }();
    final response = await pending;
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
        '创作者服务请求失败（${response.statusCode}）',
        statusCode: response.statusCode,
        errorCode: decoded['error_code'] is String
            ? decoded['error_code'] as String
            : null,
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
        monthlyIncomeFen: 0,
        tierCount: _plan?.tiers.length ?? 0,
      );

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHash,
  }) async {
    lastSaveTxHash = txHash;
    _plan ??= CreatorPlan.empty();
    return _plan!;
  }

  @override
  Future<CreatorView> fetchViewOf(
    SquareSession session,
    String creatorCid,
  ) async => CreatorView(plan: _plan, subscription: null);

  @override
  Future<void> confirmCreatorSubscription({
    required String creatorCid,
    required SquareSession session,
    required String txHash,
    required String blockHash,
  }) async {}
}
