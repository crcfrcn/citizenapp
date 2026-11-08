import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_offchain/clearing_bank_prefs.dart';

/// 清算行节点链上声明。
///
/// 该结构直接解码 finalized 链状态
/// `OffchainTransaction::ClearingBankNodes[cid_number]`。
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
    final key = runtime.storageKey('OffchainTransaction', 'ClearingBankNodes', [
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
    final key = runtime.storageKey('OffchainTransaction', 'UserBank', [account]);
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
    final prefix = runtime.storageKey('OffchainTransaction', 'ClearingBankNodes');
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
