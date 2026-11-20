import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/square_api_client.dart';

// 原有公共会员样本只定义一次；不注册业务测试，也不替代服务端真源。
Map<String, dynamic> membergatePlanFixture(String level, {int? price}) {
  const kib = 1024, mib = 1024 * kib, gib = 1024 * mib, tib = 1024 * gib;
  final v = switch (level) {
    'democracy' => (
      800 * kib,
      1600,
      72,
      1280,
      720,
      800000,
      1200000,
      96000,
      1800,
      200 * mib,
      tib,
      15000,
      100 * mib,
      5 * gib,
      256,
      2 * gib,
      5 * gib,
      50,
      3,
    ),
    'spark' => (
      1200 * kib,
      1920,
      78,
      1920,
      1080,
      1200000,
      1800000,
      128000,
      10800,
      1800 * mib,
      10 * tib,
      50000,
      5 * gib,
      12 * gib,
      1024,
      10 * gib,
      50 * gib,
      100,
      10,
    ),
    _ => (
      400 * kib,
      1280,
      65,
      854,
      480,
      450000,
      675000,
      64000,
      180,
      12 * mib,
      256 * gib,
      5000,
      10 * mib,
      gib,
      128,
      512 * mib,
      gib,
      20,
      1,
    ),
  };
  return {
    'member_level': level,
    'price_fen': price,
    'plan': {
      'member_level': level,
      'file_limit': v.$13,
      'video_max_seconds': v.$9,
      'video_max_bytes': v.$10,
      'article_max_images': v.$18,
      'article_max_videos': v.$19,
    },
    'limits': {
      'image_bytes': v.$1,
      'image_dimension': v.$2,
      'image_quality': v.$3,
      'storage_bytes': v.$11,
      'thumbnail_bytes': 80 * kib,
      'thumbnail_dimension': 360,
      'thumbnail_quality': 65,
      'cover_bytes': 120 * kib,
      'cover_dimension': 540,
      'cover_quality': 70,
      'video_width': v.$4,
      'video_height': v.$5,
      'video_total_bitrate': v.$6,
      'video_peak_bitrate': v.$7,
      'audio_bitrate': v.$8,
      'video_frame_rate': 30,
      'keyframe_secs': 2,
      'audio_sample_rate': 48000,
    },
    'resources': {'attachment_bytes': v.$14},
    'daily_limits': {
      'media_requests': v.$12,
      'delivery_bytes': v.$17,
      'upload_bytes': v.$16,
      'attachment_begins': v.$15,
    },
  };
}

List<SquareMembershipPlan> membergatePlansFixture([
  Map<String, int> prices = const {},
]) => SquareApiClient.decodeMembershipPlans([
  for (final level in const ['freedom', 'democracy', 'spark'])
    membergatePlanFixture(level, price: prices[level]),
]);
Map<String, dynamic> membergateUsageFixture() => {
  'used_bytes': 0,
  'reserved_bytes': 0,
  'day_start': 0,
  'daily': {
    'media_requests': 0,
    'upload_bytes': 0,
    'delivery_bytes': 0,
    'attachment_begins': 0,
  },
  'observed_at': 1000,
};

/// 合成规则只用于验证服务端下发值会生效；不是产品额度来源。
Map<String, dynamic> preflightGateFixture(
  SquareSession s, {
  int? now,
  int limit = 2,
}) {
  final time = now ?? DateTime.now().millisecondsSinceEpoch;
  return {
    'version': 2,
    'cid_number': s.cidNumber,
    'account_id': s.accountId,
    'bind_rev': s.bindRev,
    'device_id': s.deviceId,
    'server_time': time,
    'valid_until': time + 60000,
    'day_start': time ~/ 86400000 * 86400000,
    'day_millis': 86400000,
    'rules': {
      'chat': {'self': 'base', 'other': 'base'},
      'media': {'self': 'member', 'other': 'member'},
      'profile_asset': {'self': 'base', 'other': 'member'},
    },
    'daily_limits': {'media_requests': limit, 'delivery_bytes': 10},
    'device_limits': {
      'window_millis': 60000,
      'frames': 2,
      'frame_bytes': 1024,
      'pings': 1,
      'ping_bytes': 64,
    },
    'resource_actions': {
      'chat_command': [
        {'metric': 'media_requests', 'amount': 'one'},
      ],
      'media_request': [
        {'metric': 'media_requests', 'amount': 'one'},
      ],
      'media_body': [
        {'metric': 'delivery_bytes', 'amount': 'bytes'},
      ],
      'profile_read': [
        {'metric': 'media_requests', 'amount': 'one'},
      ],
    },
    'profile_media': {
      'content_type': 'image/webp',
      'avatar_bytes': 512,
      'banner_bytes': 1024,
    },
  };
}

/// 服务端业务授权夹具，不包含链上身份、订阅或价格。
Map<String, dynamic> resourceAuthorizationFixture({
  bool allowed = true,
  String level = 'freedom',
  int validUntil = 9999999999999,
}) {
  final plans = [
    for (final name in ['freedom', 'democracy', 'spark'])
      membergatePlanFixture(name)..remove('price_fen'),
  ];
  return {
    'is_ok': true,
    'authorization': {
      'allowed': allowed,
      'plan': allowed
          ? plans.firstWhere((p) => p['member_level'] == level)
          : null,
    },
    'plans': plans,
    'usage': membergateUsageFixture(),
    'storage_cleanup_notice': null,
    'gate': {'valid_until': validUntil},
  };
}

_LightMembership? _lightMembership;
void setChatLightData(String cid, int? maximum) {
  if (maximum == null) {
    _lightMembership?.stale = true;
    return;
  }
  final session = SubscriptionService.currentSession!;
  final source = _LightMembership(session, maximum > 0);
  _lightMembership = source;
  SubscriptionService(chainData: source, identityResolver: _UnusedIdentity());
  final plan = membergatePlanFixture('freedom')..remove('price_fen');
  (plan['plan'] as Map)['file_limit'] = maximum;
  SubscriptionService.resourceGate.observe('https://fixture.test', session, {
    'gate': {
      ...preflightGateFixture(session),
      'plans': [
        plan,
        for (final level in ['democracy', 'spark'])
          membergatePlanFixture(level)..remove('price_fen'),
      ],
    },
  });
}

class _UnusedIdentity implements FinalizedIdentityResolver {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('UI hint does not resolve identity');
}

class _LightMembership implements ChainDataService {
  _LightMembership(SquareSession s, bool active)
    : snapshot = ChainDataSnapshot(
        genesisHash: '0x${'00' * 32}',
        accountId: s.accountId,
        block: CitizenBlockRef(
          hash: '0x${'11' * 32}',
          number: BigInt.one,
          finality: CitizenBlockFinality.finalized,
        ),
        chainNowMs: 1000,
        ownCid: s.cidNumber,
        citizens: {
          s.cidNumber: ChainCitizenData(
            cidNumber: s.cidNumber,
            identity: CitizenIdentityChainSnapshot(
              cidNumber: s.cidNumber,
              accountId: Uint8List(32),
              bindRev: s.bindRev,
              votingIdentity: null,
            ),
            platform: active
                ? ChainSubscriptionState(
                    plan: const ChainSubscriptionPlan.platform('freedom'),
                    startedAt: 1,
                    chargeAt: 1,
                    chargeFen: BigInt.one,
                    paidUntil: DateTime.now().millisecondsSinceEpoch + 60000,
                    subState: 'active',
                    priceFen: BigInt.one,
                    suspendReason: null,
                  )
                : null,
            creatorTiers: null,
          ),
        },
        subscriptions: const {},
        prices: const {},
      );
  @override
  Future<ChainDataSnapshot?> refresh() async => snapshot;
  bool stale = false;
  @override
  bool get isStale => stale;
  @override
  final ChainDataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('unused light boundary');
}
