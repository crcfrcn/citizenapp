import 'dart:convert';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'citizen_identity_chain_reader.dart';
import 'subscription_chain.dart';

final class ChainCitizenData {
  const ChainCitizenData({
    required this.cidNumber,
    required this.identity,
    required this.platform,
    required this.creatorTiers,
  });
  final String cidNumber;
  final CitizenIdentityChainSnapshot? identity;
  final ChainSubscriptionState? platform;
  final List<ChainCreatorTier>? creatorTiers;
  String identityLevelAt(int millis) {
    final voting = identity?.votingIdentity;
    if (voting == null ||
        !CitizenIdentityChainReader.votingIdentityLayoutIsValid(voting) ||
        voting[8] != 0) {
      return 'visitor';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(
      millis,
      isUtc: true,
    ).add(const Duration(hours: 8));
    final today = date.year * 10000 + date.month * 100 + date.day;
    if (today < CitizenScale.readUnsigned(voting, 0, 4).toInt() ||
        today > CitizenScale.readUnsigned(voting, 4, 4).toInt()) {
      return 'visitor';
    }
    return identity?.candidateIdentity == null ? 'voting' : 'candidate';
  }
}

/// 一个最终区块上的全部关注数据。公开缓存只供展示，服务端独立鉴权。
final class ChainDataSnapshot {
  ChainDataSnapshot({
    required this.genesisHash,
    required this.accountId,
    required this.block,
    required this.chainNowMs,
    required this.ownCid,
    required Map<String, ChainCitizenData> citizens,
    required Map<String, ChainSubscriptionState?> subscriptions,
    required Map<String, int> prices,
    this.pricesLoaded = false,
  }) : citizens = Map.unmodifiable(citizens),
       subscriptions = Map.unmodifiable(subscriptions),
       prices = Map.unmodifiable(prices);
  final String genesisHash;
  final String accountId;
  final CitizenBlockRef block;
  final int chainNowMs;
  final String? ownCid;
  final Map<String, ChainCitizenData> citizens;
  final Map<String, ChainSubscriptionState?> subscriptions;
  final Map<String, int> prices;
  final bool pricesLoaded;
  ChainCitizenData? get own => citizens[ownCid];
  String? identityLevel(String cid) =>
      citizens[cid]?.identityLevelAt(chainNowMs);
  bool memberActive(String cid) =>
      citizens[cid]?.identity != null &&
      citizens[cid]?.platform?.isEffectiveAt(chainNowMs) == true;
  String? memberLevel(String cid) =>
      memberActive(cid) ? citizens[cid]?.platform?.plan.memberLevel : null;

  // 最终高度和时间变化本身不引起数据库重写；到期造成的业务变化必须通知。
  String get contentKey => jsonEncode(
    _canonical({
      ...toJson()
        ..remove('block')
        ..remove('chain_now'),
      'identity_levels': {
        for (final cid in citizens.keys) cid: identityLevel(cid),
      },
      'effective': {for (final cid in citizens.keys) cid: memberActive(cid)},
    }),
  );
  Map<String, Object?> toJson() => {
    'schema': 2,
    'genesis': genesisHash,
    'account': accountId,
    'block': {'hash': block.hash, 'number': block.number.toString()},
    'chain_now': chainNowMs,
    'own_cid': ownCid,
    'prices': prices,
    'prices_loaded': pricesLoaded,
    'citizens': {
      for (final e in citizens.entries)
        e.key: {
          'identity': _identityJson(e.value.identity),
          'platform': _subscriptionJson(e.value.platform),
          'tiers': e.value.creatorTiers == null
              ? null
              : [
                  for (final t
                      in e.value.creatorTiers ?? const <ChainCreatorTier>[])
                    {
                      'id': t.tierId,
                      'name': t.tierName,
                      'prices': {
                        for (final p in t.pricesFen.entries)
                          p.key: p.value.toString(),
                      },
                    },
                ],
        },
    },
    'subscriptions': {
      for (final e in subscriptions.entries) e.key: _subscriptionJson(e.value),
    },
  };

  static ChainDataSnapshot decode(String raw, String genesis, String account) {
    final v = jsonDecode(raw) as Map<String, dynamic>,
        b = v['block'] as Map<String, dynamic>;
    final hash = RegExp(r'^0x[0-9a-f]{64}$');
    if (v['schema'] != 2 ||
        v['genesis'] != genesis ||
        v['account'] != account ||
        !hash.hasMatch(genesis) ||
        !isCitizenAccountId(account) ||
        !hash.hasMatch(b['hash'] as String) ||
        BigInt.parse(b['number'] as String) < BigInt.zero ||
        (v['chain_now'] as int) <= 0) {
      throw const FormatException('轻节点缓存归属或区块锚无效');
    }
    final citizens = <String, ChainCitizenData>{};
    for (final e in (v['citizens'] as Map<String, dynamic>).entries) {
      final value = e.value as Map<String, dynamic>;
      final identity = _identityFrom(value['identity']);
      if (identity != null && identity.cidNumber != e.key) {
        throw const FormatException('CID不一致');
      }
      citizens[e.key] = ChainCitizenData(
        cidNumber: e.key,
        identity: identity,
        platform: _subscriptionFrom(value['platform']),
        creatorTiers: value['tiers'] == null
            ? null
            : List.unmodifiable([
                for (final t in value['tiers'] as List)
                  ChainCreatorTier(
                    tierId: t['id'] as String,
                    tierName: t['name'] as String?,
                    pricesFen: Map.unmodifiable(
                      (t['prices'] as Map<String, dynamic>).map(
                        (k, v) => MapEntry(k, _amount(v)),
                      ),
                    ),
                  ),
              ]),
      );
    }
    final ownCid = v['own_cid'] as String?;
    final ownIdentity = citizens[ownCid]?.identity;
    if (ownCid != null &&
        (ownIdentity == null ||
            citizenAccountIdFromBytes(ownIdentity.accountId) != account)) {
      throw const FormatException('默认账户绑定不一致');
    }
    return ChainDataSnapshot(
      genesisHash: genesis,
      accountId: account,
      block: CitizenBlockRef(
        hash: b['hash'] as String,
        number: BigInt.parse(b['number'] as String),
        finality: CitizenBlockFinality.finalized,
      ),
      chainNowMs: v['chain_now'] as int,
      ownCid: ownCid,
      citizens: citizens,
      subscriptions: (v['subscriptions'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, _subscriptionFrom(v)),
      ),
      pricesLoaded: v['prices_loaded'] == true,
      prices: (v['prices'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
    );
  }
}

Map<String, Object?>? _identityJson(CitizenIdentityChainSnapshot? v) =>
    v == null
    ? null
    : {
        'cid': v.cidNumber,
        'account': base64Encode(v.accountId),
        'rev': v.bindRev,
        'voting': v.votingIdentity == null
            ? null
            : base64Encode(v.votingIdentity!),
        'candidate': v.candidateIdentity == null
            ? null
            : base64Encode(v.candidateIdentity!),
      };
CitizenIdentityChainSnapshot? _identityFrom(dynamic v) {
  if (v == null) {
    return null;
  }
  final a = base64Decode(v['account'] as String), rev = v['rev'] as int;
  if (a.length != 32 || rev <= 0) {
    throw const FormatException('绑定无效');
  }
  return CitizenIdentityChainSnapshot(
    cidNumber: v['cid'] as String,
    accountId: a,
    bindRev: rev,
    votingIdentity: v['voting'] == null
        ? null
        : base64Decode(v['voting'] as String),
    candidateIdentity: v['candidate'] == null
        ? null
        : base64Decode(v['candidate'] as String),
  );
}

Map<String, Object?>? _subscriptionJson(ChainSubscriptionState? s) => s == null
    ? null
    : {
        'kind': s.plan.kind,
        'level': s.plan.memberLevel,
        'tier': s.plan.tierId,
        'period': s.plan.billingPeriod,
        'started': s.startedAt,
        'charge': s.chargeAt,
        'charge_fen': s.chargeFen.toString(),
        'paid': s.paidUntil,
        'state': s.subState,
        'price': s.priceFen.toString(),
        'reason': s.suspendReason,
      };
ChainSubscriptionState? _subscriptionFrom(dynamic s) {
  if (s == null) {
    return null;
  }
  if (![
        'active',
        'cancelled',
        'terminated',
        'suspended',
        'issuerPaused',
      ].contains(s['state']) ||
      (s['paid'] as int) <= (s['charge'] as int)) {
    throw const FormatException('订阅无效');
  }
  return ChainSubscriptionState(
    plan: s['kind'] == 'platform'
        ? ChainSubscriptionPlan.platform(s['level'] as String)
        : ChainSubscriptionPlan.creator(
            s['tier'] as String,
            s['period'] as String,
          ),
    startedAt: s['started'] as int,
    chargeAt: s['charge'] as int,
    chargeFen: _amount(s['charge_fen']),
    paidUntil: s['paid'] as int,
    subState: s['state'] as String,
    priceFen: _amount(s['price']),
    suspendReason: s['reason'] as String?,
  );
}

BigInt _amount(dynamic v) {
  final n = BigInt.parse(v as String);
  if (n < BigInt.zero || n.bitLength > 128) {
    throw const FormatException('金额无效');
  }
  return n;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) {
    return value.map(_canonical).toList();
  }
  return value;
}
