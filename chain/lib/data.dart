// 定义链上展示快照并闭环读取CID身份与钱包绑定。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'subscription.dart';

// 定义带最终块锚点的公民绑定、会员、创作者及独立价格展示快照。

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
    this.runtimeSpecVersion,
    this.runtimeTransactionVersion,
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
  final int? runtimeSpecVersion;
  final int? runtimeTransactionVersion;
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
    'runtime_spec': runtimeSpecVersion,
    'runtime_transaction': runtimeTransactionVersion,
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
      runtimeSpecVersion: v['runtime_spec'] as int?,
      runtimeTransactionVersion: v['runtime_transaction'] as int?,
      prices: (v['prices'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
    );
  }
}

/// 独立价格快照保留自己的最终块锚，不冒充后来会员快照中的同块数据。
final class ChainPriceSnapshot {
  ChainPriceSnapshot({
    required this.genesisHash,
    required this.block,
    required this.runtimeSpecVersion,
    required this.runtimeTransactionVersion,
    required this.checkedAtMillis,
    required Map<String, int> prices,
  }) : prices = Map.unmodifiable(prices);

  final String genesisHash;
  final CitizenBlockRef block;
  final int runtimeSpecVersion;
  final int runtimeTransactionVersion;
  final int checkedAtMillis;
  final Map<String, int> prices;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'genesis': genesisHash,
    'block': {'hash': block.hash, 'number': block.number.toString()},
    'runtime_spec': runtimeSpecVersion,
    'runtime_transaction': runtimeTransactionVersion,
    'checked_at': checkedAtMillis,
    'prices': prices,
  };

  static ChainPriceSnapshot decode(String raw, String genesis) {
    final v = jsonDecode(raw) as Map<String, dynamic>;
    final b = v['block'] as Map<String, dynamic>;
    final hash = RegExp(r'^0x[0-9a-f]{64}$');
    final prices = Map<String, int>.from(v['prices'] as Map);
    if (v['schema'] != 1 ||
        v['genesis'] != genesis ||
        !hash.hasMatch(genesis) ||
        !hash.hasMatch(b['hash'] as String) ||
        BigInt.parse(b['number'] as String) < BigInt.zero ||
        (v['runtime_spec'] as int) < 0 ||
        (v['runtime_transaction'] as int) < 0 ||
        (v['checked_at'] as int) <= 0 ||
        prices.entries.any(
          (e) =>
              !const ['freedom', 'democracy', 'spark'].contains(e.key) ||
              e.value <= 0 ||
              e.value > 9007199254740991,
        )) {
      throw const FormatException('价格缓存无效');
    }
    return ChainPriceSnapshot(
      genesisHash: genesis,
      block: CitizenBlockRef(
        hash: b['hash'] as String,
        number: BigInt.parse(b['number'] as String),
        finality: CitizenBlockFinality.finalized,
      ),
      runtimeSpecVersion: v['runtime_spec'] as int,
      runtimeTransactionVersion: v['runtime_transaction'] as int,
      checkedAtMillis: v['checked_at'] as int,
      prices: prices,
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

// 读取并闭环核对CID登记、双向钱包绑定及链上身份快照。

/// 由永久 CID 定位的链上公民身份快照。
///
/// CID 与钱包的双向绑定、CID 登记状态均已在读取阶段闭环校验;调用方不得再把
/// 裸钱包或单向映射当作已注册 CID。
///
/// [votingIdentity] 为 `null` 表示**匿名已注册**:账户自助占了一个 CID 并双向绑定
/// (`CidRegistry` Active),但链上无 `VotingIdentityByCid`(未经注册局线下升级)。
/// 匿名态只暴露 `cid_number`,不得据此当投票/竞选公民。非空即投票身份已闭环校验。
class CitizenIdentityChainSnapshot {
  const CitizenIdentityChainSnapshot({
    required this.cidNumber,
    required this.accountId,
    required this.bindRev,
    required this.votingIdentity,
    this.candidateIdentity,
  });

  /// 已注册且绑定闭环的匿名 CID(无投票身份)。
  bool get isAnonymous => votingIdentity == null;

  final String cidNumber;
  final Uint8List accountId;

  /// CID 单调绑定版本；初绑为 1，每次换绑或撤销递增。
  final int bindRev;
  final Uint8List? votingIdentity;
  final Uint8List? candidateIdentity;
}

/// 某 CID 在同一 finalized 区块上的有效钱包绑定。
///
/// 该快照只表达“CID 当前由哪个钱包授权”，不把钱包提升为身份主键。
class CitizenBindingChainSnapshot {
  const CitizenBindingChainSnapshot({
    this.block,
    required this.cidNumber,
    required this.accountId,
    required this.bindRev,
  });

  final String cidNumber;
  final Uint8List accountId;
  final int bindRev;

  final CitizenBlockRef? block;

  String get accountIdText => citizenAccountIdFromBytes(accountId);
}

/// `citizen-identity` 永久 CID 存储的统一读取器。
class CitizenIdentityChainReader {
  CitizenIdentityChainReader({
    CitizenSdk? chain,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
  }) : _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((_) => throw StateError('未配置getRuntimeContext')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  /// 按需解析一个CID的当前绑定；注册/换绑核验和CID转账复用同一准确块闭环。
  Future<CitizenBindingChainSnapshot?> readBindingByCidNumber(
    String cidNumber, {
    CitizenBlockRef? at,
  }) async {
    final cid = _normalizeCidNumber(cidNumber);
    final block = at ?? await _getFinalizedHead();
    final context = await _getRuntimeContext(block);
    final key = (scale: encodeBoundedBytes(utf8.encode(cid)));
    final rows = await _getStorageBatch(block, [
      context.storageKey('Identity', 'AccountIdByCid', [key]),
      context.storageKey('Identity', 'CidRegistry', [key]),
      context.storageKey('Identity', 'BindingRevisionByCid', [key]),
    ]);
    final account = rows[0], revision = _decodeU64(rows[2]);
    if (account == null ||
        account.length != 32 ||
        !cidRecordIsActive(rows[1]) ||
        revision <= 0) {
      return null;
    }
    final reverse = await _getStorage(
      block,
      context.storageKey('Identity', 'CidByAccountId', [account]),
    );
    if (decodeCidNumber(reverse) != cid) return null;
    return CitizenBindingChainSnapshot(
      cidNumber: cid,
      accountId: account,
      bindRev: revision,
      block: block,
    );
  }

  /// 按规范账户 ID 读取身份闭环,区分**纯访客 / 匿名已注册 / 投票 / 竞选**。
  ///
  /// 顺序固定为:`CidByAccountId` → `CidRegistry` Active → `AccountIdByCid`
  /// 反向一致(**绑定闭环**)→ `VotingIdentityByCid`;竞选再读 `CandidateIdentityByCid`。
  /// - `CidByAccountId` 无、或绑定不闭环(反向错配 / 非 Active)→ 返回 `null`
  ///   (**纯访客**,可自助占号)。
  /// - 绑定闭环但无 `VotingIdentityByCid`(或其布局损坏)→ 返回 `isAnonymous` 快照
  ///   (**匿名已注册**,只带 `cid_number`)。布局损坏归匿名是 fail-closed 的**安全降级**
  ///   (降到匿名而非误升成投票公民)。
  /// - 绑定闭环 + 合法 `VotingIdentityByCid` → **投票**;再有合法 candidate → **竞选**。
  Future<CitizenIdentityChainSnapshot?> readByAccountId(
    String accountIdText, {
    CitizenBlockRef? at,
  }) async {
    final accountId = citizenAccountIdBytes(accountIdText);

    // 同一次身份判断必须锚定同一个 finalized 区块，避免 CID 映射与身份值跨块混读。
    final finalized = at ?? await _getFinalizedHead();
    final context = await _getRuntimeContext(finalized);

    final cidByAccountIdKey = context.storageKey(
      'Identity',
      'CidByAccountId',
      [accountId],
    );
    final cidRaw = await _getStorage(finalized, cidByAccountIdKey);
    final cidNumber = decodeCidNumber(cidRaw);
    if (cidNumber == null) return null;

    final cidScale = (scale: encodeBoundedBytes(utf8.encode(cidNumber)));
    final accountIdByCidKey = context.storageKey(
      'Identity',
      'AccountIdByCid',
      [cidScale],
    );
    final cidRegistryKey = context.storageKey(
      'Identity',
      'CidRegistry',
      [cidScale],
    );
    final votingKey = context.storageKey(
      'Identity',
      'VotingIdentityByCid',
      [cidScale],
    );
    final candidateKey = context.storageKey(
      'Identity',
      'CandidateIdentityByCid',
      [cidScale],
    );
    final bindingRevisionKey = context.storageKey(
      'Identity',
      'BindingRevisionByCid',
      [cidScale],
    );
    final keys = <Uint8List>[
      accountIdByCidKey,
      cidRegistryKey,
      votingKey,
      candidateKey,
      bindingRevisionKey,
    ];
    final rows = await _getStorageBatch(finalized, keys);
    final boundAccountId = rows[0];
    final cidRecord = rows[1];
    final votingIdentity = rows[2];
    final candidateIdentity = rows[3];
    final bindRev = _decodeU64(rows[4]);
    // 绑定闭环:AccountIdByCid 反向一致 + CidRegistry Active。不闭环(反查为空/错配/
    // 非 Active)= 该账户没有有效 CID → 纯访客兜底(可重新占号,链上残留绑定占号时再拒)。
    if (boundAccountId == null ||
        boundAccountId.length != accountId.length ||
        !_sameBytes(boundAccountId, accountId) ||
        !cidRecordIsActive(cidRecord) ||
        bindRev <= 0) {
      return null;
    }

    // CID 闭环成立。VotingIdentity 键不存在或布局损坏 → 匿名已注册(安全降级,只暴露 CID)。
    if (votingIdentity == null ||
        !votingIdentityLayoutIsValid(votingIdentity)) {
      return CitizenIdentityChainSnapshot(
        cidNumber: cidNumber,
        accountId: accountId,
        bindRev: bindRev,
        votingIdentity: null,
        candidateIdentity: null,
      );
    }

    // 合法投票身份;竞选身份布局非法时降级为纯投票(不误升竞选)。
    return CitizenIdentityChainSnapshot(
      cidNumber: cidNumber,
      accountId: accountId,
      bindRev: bindRev,
      votingIdentity: votingIdentity,
      candidateIdentity:
          candidateIdentity != null &&
              candidateIdentityLayoutIsValid(candidateIdentity)
          ? candidateIdentity
          : null,
    );
  }

  Future<CitizenIdentityChainSnapshot?> readByCidNumber(
    String cid, {
    CitizenBlockRef? at,
  }) async {
    final block = at ?? await _getFinalizedHead();
    final binding = await readBindingByCidNumber(cid, at: block);
    if (binding == null) return null;
    final identity = await readByAccountId(binding.accountIdText, at: block);
    if (identity?.cidNumber != cid) return null;
    return identity;
  }

  static Uint8List encodeBoundedBytes(List<int> value) {
    if (value.isEmpty || value.length > 32) {
      throw const FormatException('CID 长度不合法');
    }
    return Uint8List.fromList([
      ...CitizenScale.compact(value.length),
      ...value,
    ]);
  }

  static String _normalizeCidNumber(String cidNumber) {
    final normalized = cidNumber.trim();
    final bytes = utf8.encode(normalized);
    if (bytes.isEmpty || bytes.length > 32) {
      throw const FormatException('CID 长度不合法');
    }
    return normalized;
  }

  static String? decodeCidNumber(Uint8List? data) {
    if (data == null) return null;
    try {
      final value = _readBoundedBytes(data, 0, 32);
      if (value.nextOffset != data.length) return null;
      final cid = utf8.decode(value.bytes, allowMalformed: false).trim();
      return cid.isEmpty ? null : cid;
    } catch (_) {
      return null;
    }
  }

  static int _decodeU64(Uint8List? data) {
    if (data == null || data.length != 8) return 0;
    return CitizenScale.readUnsigned(data, 0, 8).toSigned(64).toInt();
  }

  /// 解码 `CidRecord` 到 status 字段；只接受 `Active = 0`。
  ///
  /// 严格区分「解析成功但没有有效登记」与「读不准」,绝不把后者压成未注册:
  /// - 记录不存在、状态为 `Revoked`、状态与 `revoked_at` 自相矛盾 → `false`
  ///   (结论可信:该 CID 确实没有有效登记)。
  /// - SCALE 布局无法解析(截断 / 长度非法 / 尾随字节)→ 抛 [FormatException],
  ///   交调用方按链读失败处理(门禁落 queryFailed 让用户重试)。吞成 `false` 会让
  ///   解析器与链端结构不同步时全体用户静默变访客。
  ///
  /// `residence_province_code` / `residence_city_code` 恒为空:创世
  /// `initial_cid_bindings`、`self_occupy_cid` 与注册局占号都写
  /// `AreaCodeBound::default()`,换绑只 clone 旧值。故必须 `allowEmpty: true`。
  static bool cidRecordIsActive(Uint8List? data) {
    if (data == null) return false;
    var offset = _readBoundedBytes(data, 0, 32).nextOffset;
    offset += 32; // commitment
    if (offset > data.length) {
      throw const FormatException('CidRecord commitment 越界');
    }
    offset = _readBoundedBytes(data, offset, 16, allowEmpty: true).nextOffset;
    offset = _readBoundedBytes(data, offset, 16, allowEmpty: true).nextOffset;
    // status(1) + registered_at(4) + revoked_at 标记(1) 必须齐全。
    if (offset + 1 + 4 + 1 > data.length) {
      throw const FormatException('CidRecord 尾部截断');
    }
    if (data[offset] != 0) return false; // CidRecordStatus::Revoked
    offset += 1 + 4;
    switch (data[offset]) {
      case 0: // revoked_at = None
        if (offset + 1 != data.length) {
          throw const FormatException('CidRecord 尾随字节非法');
        }
        return true;
      case 1: // revoked_at = Some(BlockNumber)
        if (offset + 1 + 4 != data.length) {
          throw const FormatException('CidRecord 尾随字节非法');
        }
        // Active 却带撤销块号:自相矛盾,fail-closed 判非 Active。
        return false;
      default:
        throw const FormatException('CidRecord revoked_at 标记非法');
    }
  }

  /// 校验 `VotingIdentity<BlockNumber>` 的最终 SCALE 布局，不接受截断或尾随字节。
  static bool votingIdentityLayoutIsValid(Uint8List data) {
    try {
      if (data.length < 9) return false;
      final validFrom = _readU32Le(data, 0);
      final validUntil = _readU32Le(data, 4);
      if (!_isValidDateInt(validFrom) || !_isValidDateInt(validUntil)) {
        return false;
      }
      if (data[8] != 0 && data[8] != 1) return false;
      var offset = 9;
      offset = _readBoundedBytes(data, offset, 16, allowEmpty: true).nextOffset;
      offset = _readBoundedBytes(data, offset, 16, allowEmpty: true).nextOffset;
      offset = _readBoundedBytes(data, offset, 16, allowEmpty: true).nextOffset;
      return offset + 4 == data.length;
    } catch (_) {
      return false;
    }
  }

  /// 校验 `CandidateIdentity<BlockNumber>` 的最终 SCALE 布局。
  static bool candidateIdentityLayoutIsValid(Uint8List data) {
    try {
      var offset = 0;
      for (var index = 0; index < 3; index++) {
        offset = _readBoundedBytes(
          data,
          offset,
          16,
          allowEmpty: true,
        ).nextOffset;
      }
      final familyName = _readBoundedBytes(data, offset, 128);
      offset = familyName.nextOffset;
      final givenName = _readBoundedBytes(data, offset, 128);
      offset = givenName.nextOffset;
      if (offset + 1 + 4 + 4 != data.length) return false;
      if (data[offset] != 0 && data[offset] != 1) return false;
      final birthDate = _readU32Le(data, offset + 1);
      return _isValidDateInt(birthDate);
    } catch (_) {
      return false;
    }
  }

  static ({Uint8List bytes, int nextOffset}) _readBoundedBytes(
    Uint8List data,
    int offset,
    int maxLength, {
    bool allowEmpty = false,
  }) {
    final (length, width) = CitizenScale.readCompact(data, offset);
    if (width != 1) {
      throw const FormatException('当前身份键只允许短 Compact 长度');
    }
    final start = offset + width;
    final end = start + length;
    if ((!allowEmpty && length == 0) ||
        length > maxLength ||
        end > data.length) {
      throw const FormatException('BoundedVec 长度不合法');
    }
    return (bytes: Uint8List.sublistView(data, start, end), nextOffset: end);
  }

  static int _readU32Le(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();

  static bool _isValidDateInt(int value) {
    final year = value ~/ 10000;
    final month = (value % 10000) ~/ 100;
    final day = value % 100;
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  static bool _sameBytes(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
