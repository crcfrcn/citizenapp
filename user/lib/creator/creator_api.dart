import 'dart:convert';
import 'package:citizen_network/citizen_serve_api_config.dart'
    show HttpsOnlyClient;
import 'package:citizen_network/square_request_signer.dart';
import 'package:http/http.dart' as http;
import 'package:citizen_user/square_api_client.dart'
    show SquareApiConfig, SquareSession;
import 'package:citizen_user/creator/creator_plan.dart';

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
    if (sign == null) throw const CreatorApiException('MLS请求认证未就绪');
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
    if (raw is! Map<String, dynamic>) throw const CreatorApiException('登记响应无效');
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        raw['is_ok'] != true)
      throw CreatorApiException(
        '创作者请求失败',
        statusCode: response.statusCode,
        errorCode: raw['error_code'] as String?,
      );
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
      if (identical(_reads[key], pending)) _reads.remove(key);
    }
    final list = data['cid_numbers'];
    final next = data['next_cursor'];
    if (list is! List ||
        list.any(
          (v) =>
              v is! String ||
              !RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(v),
        ) ||
        next != null && next is! String)
      throw const CreatorApiException('登记分页无效');
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
