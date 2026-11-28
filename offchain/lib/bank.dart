// 清算行目录、绑定快照及本地缓存。

import 'dart:convert';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/data.dart' show Institution;
import 'package:citizen_citizen/institution/service.dart' show InstitutionRepository;
import 'package:citizen_citizen/data.dart' show deriveInstitutionFeeAccountId, deriveInstitutionMainAccountId;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 从最终链状态读取清算行资格及安全WSS节点目录。

/// 清算行节点链上声明。
///
/// 该结构直接解码 finalized 链状态
/// `Offchain::ClearingBankNodes[cid_number]`。
class ClearingBankNodeEndpoint {
  const ClearingBankNodeEndpoint({
    required this.cidNumber,
    required this.peerId,
    required this.rpcDomain,
    required this.rpcPort,
    required this.registeredAt,
    required this.registeredBy,
  });

  final String cidNumber;
  final String peerId;
  final String rpcDomain;
  final int rpcPort;
  final int registeredAt;
  final String registeredBy;

  /// 所有端点统一使用WSS，不按本机或局域网主机名降级。
  String get wssUrl => 'wss://$rpcDomain:$rpcPort';

  bool sameTarget(ClearingBankNodeEndpoint other) =>
      cidNumber == other.cidNumber &&
      peerId == other.peerId &&
      rpcDomain == other.rpcDomain &&
      rpcPort == other.rpcPort;
}

/// 节点来自已验证区块。名称只供展示，不参与路由或授权。
typedef ClearingBankBinding = ({ClearingBankNodeEndpoint endpoint, String title});

/// 链上清算行声明与 finalized 机构快照的组合结果。
class ClearingBankCandidate {
  const ClearingBankCandidate({
    required this.cidNumber,
    required this.fullName,
    required this.shortName,
    required this.areaPath,
    required this.endpoint,
  });

  final String cidNumber;
  final String fullName;
  final String? shortName;
  final String areaPath;
  final ClearingBankNodeEndpoint endpoint;

  String get displayTitle {
    final shortLabel = shortName?.trim() ?? '';
    if (shortLabel.isNotEmpty) return shortLabel;
    final fullLabel = fullName.trim();
    return fullLabel.isEmpty ? cidNumber : fullLabel;
  }

  /// 机构账户由链统一派生规则确定。
  String get mainAccountId =>
      citizenAccountIdFromBytes(deriveInstitutionMainAccountId(cidNumber));

  String get feeAccountId =>
      citizenAccountIdFromBytes(deriveInstitutionFeeAccountId(cidNumber));
}

/// CitizenApp 清算行目录服务。
///
/// 搜索、端点和用户绑定状态全部来自 finalized 链状态；机构目录只补充名称与行政区
/// 展示，不参与清算行资格判断。关键操作每次重新读链，不保留长 TTL 权限缓存。
class ClearingBankDirectory {
  ClearingBankDirectory({
    CitizenSdk? chain,
    InstitutionRepository? institutionRepository,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List>> Function(
      CitizenBlockRef block,
      Uint8List prefix, {
      Uint8List? startKey,
      int limit,
    })?
    getStorageKeysPaged,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _institutionRepository =
           institutionRepository ?? InstitutionRepository(),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext = getRuntimeContext ?? chain?.getRuntimeContext ??
           ((_) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getStorageKeysPaged =
           getStorageKeysPaged ??
           chain?.getStorageKeysPaged ??
           ((
             CitizenBlockRef block,
             Uint8List prefix, {
             Uint8List? startKey,
             int limit = 1000,
           }) => throw StateError('未配置getStorageKeysPaged')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<Uint8List>> Function(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit,
  })
  _getStorageKeysPaged;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;

  final InstitutionRepository _institutionRepository;

  static const int _pageSize = 256;
  static const int _batchSize = 100;

  Future<List<ClearingBankCandidate>> search(String query) async {
    await _institutionRepository.directory.ensureSynced();
    final endpoints = await _fetchAllEndpoints();
    final keyword = query.trim().toLowerCase();
    final candidates = <ClearingBankCandidate>[];

    for (final endpoint in endpoints) {
      final institution = await _institutionRepository.getByCid(
        endpoint.cidNumber,
      );
      final candidate = await _candidate(endpoint, institution);
      if (keyword.isEmpty ||
          candidate.cidNumber.toLowerCase().contains(keyword) ||
          candidate.fullName.toLowerCase().contains(keyword) ||
          (candidate.shortName?.toLowerCase().contains(keyword) ?? false)) {
        candidates.add(candidate);
      }
    }

    candidates.sort((a, b) => a.cidNumber.compareTo(b.cidNumber));
    return candidates.take(20).toList(growable: false);
  }

  Future<ClearingBankCandidate> _candidate(
    ClearingBankNodeEndpoint endpoint,
    Institution? institution,
  ) async {
    var areaPath = '';
    if (institution != null) {
      try {
        areaPath = await _institutionRepository.institutionAreaPath(
          institution,
        );
      } on Exception {
        areaPath = '';
      }
    }
    return ClearingBankCandidate(
      cidNumber: endpoint.cidNumber,
      fullName: institution?.fullName ?? endpoint.cidNumber,
      shortName: institution?.shortName,
      areaPath: areaPath,
      endpoint: endpoint,
    );
  }

  /// 精确读取付款方所选收款行的链上节点声明。
  Future<ClearingBankNodeEndpoint?> fetchEndpoint(String cidNumber) async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    return _readEndpoint(finalized, runtime, cidNumber);
  }

  Future<ClearingBankNodeEndpoint?> _readEndpoint(
    CitizenBlockRef finalized,
    CitizenRuntimeContext runtime,
    String cidNumber,
  ) async {
    final key = runtime.storageKey('Offchain', 'ClearingBankNodes', [
      Uint8List.fromList(utf8.encode(cidNumber)),
    ]);
    final raw = await _getStorage(finalized, key);
    if (raw == null || raw.isEmpty) return null;
    return _decodeEndpoint(cidNumber, raw);
  }

  /// 查询 finalized `UserBank[user]`，仅当链上无绑定时返回 null。
  Future<String?> fetchUserBankCid(String accountId) async {
    final account = citizenAccountIdBytes(accountId);
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    return _readUserBankCid(finalized, runtime, account);
  }

  /// 同块核对绑定和节点。无绑定返回 null，节点缺失或损坏按读取失败处理。
  Future<ClearingBankBinding?> fetchUserBank(String accountId) async {
    final account = citizenAccountIdBytes(accountId);
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final cid = await _readUserBankCid(finalized, runtime, account);
    if (cid == null) return null;
    final endpoint = await _readEndpoint(finalized, runtime, cid);
    if (endpoint == null) throw StateError('当前清算行节点不可用');
    final cached = await ClearingBankPrefs.loadSnapshot(accountId)
        .onError((_, _) => null);
    final title = cached != null && cached.cidNumber == cid
        ? cached.displayTitle
        : cid;
    return (endpoint: endpoint, title: title);
  }

  Future<String?> _readUserBankCid(
    CitizenBlockRef finalized,
    CitizenRuntimeContext runtime,
    Uint8List account,
  ) async {
    final key = runtime.storageKey('Offchain', 'UserBank', [account]);
    final raw = await _getStorage(finalized, key);
    if (raw == null) return null;
    final (cid, next) = _readUtf8Vec(raw, 0, maxLength: 32);
    if (cid == null || next != raw.length) {
      throw const FormatException('链上清算行机构 CID 数据无效');
    }
    return cid;
  }

  Future<List<ClearingBankNodeEndpoint>> _fetchAllEndpoints() async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final prefix = runtime.storageKey('Offchain', 'ClearingBankNodes');
    final keys = <Uint8List>[];
    Uint8List? startKey;
    while (true) {
      final page = await _getStorageKeysPaged(
        finalized,
        prefix,
        startKey: startKey,
        limit: _pageSize,
      );
      if (page.isEmpty) break;
      keys.addAll(page);
      if (page.length < _pageSize) break;
      startKey = page.last;
    }

    final values = <Uint8List?>[];
    for (var offset = 0; offset < keys.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, keys.length);
      values.addAll(
        await _getStorageBatch(finalized, keys.sublist(offset, end)),
      );
    }
    final out = <ClearingBankNodeEndpoint>[];
    for (var index = 0; index < keys.length; index++) {
      final key = keys[index];
      final cidNumber = _decodeBlake2MapStringKey(key);
      final raw = values[index];
      if (cidNumber == null || raw == null) continue;
      final endpoint = _decodeEndpoint(cidNumber, raw);
      if (endpoint != null) out.add(endpoint);
    }
    return out;
  }

  static ClearingBankNodeEndpoint? _decodeEndpoint(
    String cidNumber,
    Uint8List raw,
  ) {
    var offset = 0;
    final (peerId, peerNext) = _readUtf8Vec(raw, offset, maxLength: 64);
    if (peerId == null) return null;
    offset = peerNext;
    final (domain, domainNext) = _readUtf8Vec(raw, offset, maxLength: 128);
    if (domain == null) return null;
    offset = domainNext;
    if (offset + 2 + 4 + 32 != raw.length) return null;
    final port = CitizenScale.readUnsigned(raw, offset, 2).toInt();
    offset += 2;
    final registeredAt = CitizenScale.readUnsigned(raw, offset, 4).toInt();
    offset += 4;
    final registeredBy = citizenSs58FromAccountIdBytes(
      raw.sublist(offset, offset + 32),
    );
    return ClearingBankNodeEndpoint(
      cidNumber: cidNumber,
      peerId: peerId,
      rpcDomain: domain,
      rpcPort: port,
      registeredAt: registeredAt,
      registeredBy: registeredBy,
    );
  }

  static String? _decodeBlake2MapStringKey(Uint8List bytes) {
    const valueOffset = 32 + 16;
    if (bytes.length <= valueOffset) return null;
    final (value, next) = _readUtf8Vec(bytes, valueOffset, maxLength: 32);
    return next == bytes.length ? value : null;
  }

  static (String?, int) _readUtf8Vec(
    Uint8List bytes,
    int offset, {
    required int maxLength,
  }) {
    final (len, lenSize) = _decodeCompactU32(bytes, offset);
    if (lenSize == 0 || len <= 0 || len > maxLength) return (null, offset);
    offset += lenSize;
    if (offset + len > bytes.length) return (null, offset);
    try {
      return (utf8.decode(bytes.sublist(offset, offset + len)), offset + len);
    } on FormatException {
      return (null, offset);
    }
  }

  static (int, int) _decodeCompactU32(Uint8List bytes, int offset) {
    try {
      final decoded = CitizenScale.readCompact(bytes, offset);
      return decoded.$2 <= 4 ? decoded : (0, 0);
    } on FormatException {
      return (0, 0);
    }
  }
}

// 按账户保存清算行展示快照，实际绑定和操作仍由链上核验。

/// 当前钱包绑定清算行的本地快照。
///
///
/// - 链上权威仍然是 `UserBank[user]` 与 `ClearingBankNodes[cid_number]`。
/// - 本地快照只供展示。当前绑定和操作端点均须查链。
class ClearingBankBindingSnapshot {
  const ClearingBankBindingSnapshot({
    required this.cidNumber,
    required this.fullName,
    required this.shortName,
    required this.mainAccountId,
    required this.feeAccountId,
    required this.peerId,
    required this.rpcDomain,
    required this.rpcPort,
    required this.boundAtMs,
    required this.lastVerifiedAtMs,
  });

  final String cidNumber;
  final String fullName;
  final String shortName;
  final String mainAccountId;
  final String feeAccountId;
  final String peerId;
  final String rpcDomain;
  final int rpcPort;
  final int boundAtMs;
  final int lastVerifiedAtMs;

  /// 本机、局域网与公网端点统一使用WSS，不按主机名降级。
  String get wssUrl => 'wss://$rpcDomain:$rpcPort';

  String get displayTitle {
    final cidShort = shortName.trim();
    if (cidShort.isNotEmpty) return cidShort;
    final cidFull = fullName.trim();
    return cidFull.isEmpty ? cidNumber : cidFull;
  }

  Map<String, dynamic> toJson() => {
    'cid_number': cidNumber,
    'cid_full_name': fullName,
    'cid_short_name': shortName,
    'main_account_id': mainAccountId,
    'fee_account_id': feeAccountId,
    'peer_id': peerId,
    'rpc_domain': rpcDomain,
    'rpc_port': rpcPort,
    'bound_at_ms': boundAtMs,
    'last_verified_at_ms': lastVerifiedAtMs,
  };

  factory ClearingBankBindingSnapshot.fromJson(Map<String, dynamic> json) {
    return ClearingBankBindingSnapshot(
      cidNumber: (json['cid_number'] as String?) ?? '',
      fullName: (json['cid_full_name'] as String?) ?? '',
      shortName: (json['cid_short_name'] as String?) ?? '',
      mainAccountId: (json['main_account_id'] as String?) ?? '',
      feeAccountId: (json['fee_account_id'] as String?) ?? '',
      peerId: (json['peer_id'] as String?) ?? '',
      rpcDomain: (json['rpc_domain'] as String?) ?? '',
      rpcPort: (json['rpc_port'] as num?)?.toInt() ?? 0,
      boundAtMs: (json['bound_at_ms'] as num?)?.toInt() ?? 0,
      lastVerifiedAtMs: (json['last_verified_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 扫码支付 Step 3:**用户绑定清算行本地快照缓存**。
///
/// - 链上 `Offchain::UserBank[user]` 保存清算行机构 CID。
/// - 本地快照补充名称、派生账户和节点端点，绑定和切换以 finalized 链状态为准。
/// - 缓存按 `account_id` 隔离(单钱包多账户下,每个账户独立绑定清算行,互不干扰)。
class ClearingBankPrefs {
  ClearingBankPrefs._();

  static const String _keyPrefix = 'clearing_bank_binding_';

  @visibleForTesting
  static Future<bool> Function(SharedPreferences prefs, String key)?
  debugRemoveForTest;

  @visibleForTesting
  static Future<bool> Function(SharedPreferences prefs, String key, String value)?
  debugSetForTest;

  /// 写入完整绑定快照。[accountId] 为该绑定账户的链账户主键(0x+64hex)。
  static Future<void> saveSnapshot(
    String accountId,
    ClearingBankBindingSnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$accountId';
    final value = jsonEncode(snapshot.toJson());
    final set = debugSetForTest;
    final saved = await (set == null
        ? prefs.setString(key, value)
        : set(prefs, key, value));
    if (!saved) throw StateError('清算行缓存写入未提交');
  }

  /// 读取完整绑定快照。[accountId] 为该账户的链账户主键(0x+64hex)。
  static Future<ClearingBankBindingSnapshot?> loadSnapshot(
    String accountId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$accountId');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = ClearingBankBindingSnapshot.fromJson(json);
      if (snapshot.cidNumber.isEmpty ||
          snapshot.mainAccountId.isEmpty ||
          snapshot.feeAccountId.isEmpty ||
          snapshot.rpcDomain.isEmpty ||
          snapshot.rpcPort <= 0) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  /// 清除本地快照，链上绑定状态独立存储。
  static Future<void> clear(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$accountId';
    if (!prefs.containsKey(key)) return;
    final remove = debugRemoveForTest;
    final removed = await (remove == null
        ? prefs.remove(key)
        : remove(prefs, key));
    if (!removed) {
      throw StateError('清算行缓存删除未提交');
    }
    // remove 返回 true 也不代表当前事实已不存在；并发写入或异常后端
    // 可在回读前重建该键。只要值仍存在就必须抛错，上层 pending 不得 ack。
    if (prefs.containsKey(key)) {
      throw StateError('清算行缓存删除后回读仍存在');
    }
  }
}
