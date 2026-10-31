import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

import 'package:citizen_citizen/proposal/proposal_query_service.dart';

/// 立法投票阶段(链端 votingengine STAGE_LEG_*,Proposal.stage 字节)。
class LegStage {
  static const int representative = 10; // 代表机构表决
  static const int referendum = 11; // 特别案公投
  static const int sign = 12; // 行政首长签署
  static const int override_ = 13; // 三人会签
  static const int guard = 14; // 护宪大法官终审
}

/// 提案状态(VotingEngine.Proposals 第 3 字节)。
class LegProposalStatus {
  static const int voting = 0;
  static const int passed = 1;
  static const int rejected = 2;
}

/// 代表机构表决元数据（RepresentativeMetas 镜像）。
class LegRepresentativeMeta {
  const LegRepresentativeMeta({
    required this.sequential,
    required this.bodies,
    required this.currentBody,
    required this.rule,
    required this.procedure,
  });

  final bool sequential;

  /// 按状态机顺序排列的代表机构岗位主体。
  final List<LegRepresentativeBody> bodies;
  final int currentBody;
  final int rule; // 0常规/1重要/2特别
  final int procedure; // 0代表表决终局/1法律专属程序
}

/// 代表机构表决路线中的完整岗位主体。
class LegRepresentativeBody {
  const LegRepresentativeBody({
    required this.cidNumber,
    required this.roleCode,
  });

  final String cidNumber;
  final String roleCode;

  @override
  String toString() => '$cidNumber / $roleCode';
}

/// 法律专属元数据（LegislationMetas 镜像）。
class LegislationMeta {
  const LegislationMeta({
    required this.executive,
    required this.overrideSigners,
    required this.needsGuard,
    required this.guard,
  });
  final LegRepresentativeBody? executive;
  final List<LegRepresentativeBody> overrideSigners;
  final bool needsGuard;
  final LegRepresentativeBody? guard;
}

/// 提案核心阶段/状态(VotingEngine.Proposals 头三字节)。
class LegProposalState {
  const LegProposalState({
    required this.kind,
    required this.stage,
    required this.status,
  });
  final int kind;
  final int stage;
  final int status;
}

/// 立法投票查询服务：代表表决、法律程序、计票和签署账本分别读取。
///
/// 代表元数据、法律元数据、各 tally 与签署记录集中在本服务，
/// 不借用 internal-vote 查询。核心 Proposal 阶段/状态读
/// VotingEngine.Proposals。
class LegislationVoteQueryService {
  LegislationVoteQueryService({
    CitizenSdk? chain,
    CitizenBlockRef? block,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _block = block,
       _proposalQuery = ProposalQueryService(
         chain: chain,
         block: block,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getSystemEvents: getSystemEvents,
         getRuntimeContext: getRuntimeContext,
         getStorageBatch: getStorageBatch,
       ),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  final CitizenBlockRef? _block;
  final ProposalQueryService _proposalQuery;

  static const String _votePallet = 'LegislationVote';

  /// 核心提案阶段/状态(不存在返回 null)。
  Future<LegProposalState?> fetchProposalState(int proposalId) async {
    final proposal = await _proposalQuery.fetchProposalMeta(proposalId);
    if (proposal == null) return null;
    return LegProposalState(
      kind: proposal.kind,
      stage: proposal.stage,
      status: proposal.status,
    );
  }

  Future<LegRepresentativeMeta?> fetchRepresentativeMeta(int proposalId) async {
    final key = _mapKey(_votePallet, 'RepresentativeMetas', _u64Le(proposalId));
    final data = await _readStorage(key);
    if (data == null) return null;
    final result = _decodeRepresentativeMeta(data);
    if (result == null) throw const FormatException('RepresentativeMetas编码无效');
    return result;
  }

  Future<LegislationMeta?> fetchLegislationMeta(int proposalId) async {
    final key = _mapKey(_votePallet, 'LegislationMetas', _u64Le(proposalId));
    final data = await _readStorage(key);
    if (data == null) return null;
    final result = _decodeLegislationMeta(data);
    if (result == null) throw const FormatException('LegislationMetas编码无效');
    return result;
  }

  static LegRepresentativeMeta? debugDecodeRepresentativeMeta(Uint8List data) =>
      _decodeRepresentativeMeta(data);

  static LegislationMeta? debugDecodeLegislationMeta(Uint8List data) =>
      _decodeLegislationMeta(data);

  static LegRepresentativeMeta? _decodeRepresentativeMeta(Uint8List data) {
    try {
      final c = _Cursor(data);
      final routeVariant = c.u8();
      final bodies = switch (routeVariant) {
        0 => [c.representativeBody()],
        1 => c.vec(c.representativeBody),
        _ => throw const FormatException('未知代表机构路线'),
      };
      if (bodies.isEmpty || bodies.length > 4) return null;
      final currentBody = c.u32();
      final rule = c.u8();
      final procedure = c.u8();
      if (!c.isDone ||
          currentBody >= bodies.length ||
          rule > 2 ||
          procedure > 1) {
        return null;
      }
      return LegRepresentativeMeta(
        sequential: routeVariant == 1,
        bodies: List.unmodifiable(bodies),
        currentBody: currentBody,
        rule: rule,
        procedure: procedure,
      );
    } on Object {
      return null;
    }
  }

  static LegislationMeta? _decodeLegislationMeta(Uint8List data) {
    try {
      final c = _Cursor(data);
      LegRepresentativeBody? subject() {
        final tag = c.u8();
        if (tag == 0) return null;
        if (tag != 1) throw const FormatException('岗位主体Option无效');
        return c.representativeBody();
      }

      final executive = subject();
      final signers = c.vec(c.representativeBody, max: 3);
      final guardTag = c.u8();
      if (guardTag > 1) return null;
      final guard = subject();
      if (!c.isDone) return null;
      return LegislationMeta(
        executive: executive,
        overrideSigners: List.unmodifiable(signers),
        needsGuard: guardTag == 1,
        guard: guard,
      );
    } on Object {
      return null;
    }
  }

  /// 当前代表机构计票，按 body_index 独立保存。
  Future<({int yes, int no})> fetchRepresentativeTally(
    int proposalId,
    int bodyIndex,
  ) async {
    final key = _doubleMapKey(
      _votePallet,
      'RepresentativeTallies',
      _u64Le(proposalId),
      _u32Le(bodyIndex),
    );
    final data = await _readStorage(key);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 8) throw const FormatException('代表机构计票长度无效');
    return (yes: _u32(data, 0), no: _u32(data, 4));
  }

  /// 公投计票(VoteCountU64:yes u64 + no u64)。
  Future<({int yes, int no})> fetchReferendumTally(int proposalId) async {
    final key = _mapKey(_votePallet, 'LegReferendumTally', _u64Le(proposalId));
    final data = await _readStorage(key);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 16) throw const FormatException('公投计票长度无效');
    return (yes: _u64(data, 0), no: _u64(data, 8));
  }

  /// 某钱包在指定代表机构岗位席位的投票。
  Future<bool?> fetchRepresentativeVote(
    int proposalId,
    int bodyIndex,
    String cidNumber,
    String voterRoleCode,
    String publicKey,
  ) async {
    final tupleKey = Uint8List.fromList([
      ..._u32Le(bodyIndex),
      ..._encodeBoundedText(cidNumber, 32, 'cid_number'),
      ..._encodeBoundedText(voterRoleCode, 64, 'voter_role_code'),
      ..._hexDecode(publicKey),
    ]);
    final key = _doubleMapKey(
      _votePallet,
      'RepresentativeVotesByTicket',
      _u64Le(proposalId),
      tupleKey,
    );
    final data = await _readStorage(key);
    if (data == null) return null;
    if (data.length != 1 || data[0] > 1) {
      throw const FormatException('代表机构投票必须为SCALE bool');
    }
    return data[0] == 1;
  }

  Uint8List _encodeBoundedText(String value, int maxBytes, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('$field 长度不合法');
    }
    final length = bytes.length;
    final prefix = length < 64
        ? <int>[length << 2]
        : <int>[(length << 2 | 1) & 0xff, (length << 2 | 1) >> 8];
    return Uint8List.fromList([...prefix, ...bytes]);
  }

  /// 三人会签记录(LegOverrideSigns:BoundedVec<(AccountId,bool)>)。
  Future<List<({String accountId, bool approve})>> fetchOverrideSigns(
    int proposalId,
  ) {
    return _fetchSigns('LegOverrideSigns', proposalId);
  }

  /// 护宪大法官终审记录(LegGuardSigns:BoundedVec<(AccountId,bool)>)。
  Future<List<({String accountId, bool approve})>> fetchGuardSigns(
    int proposalId,
  ) {
    return _fetchSigns('LegGuardSigns', proposalId);
  }

  Future<List<({String accountId, bool approve})>> _fetchSigns(
    String storage,
    int proposalId,
  ) async {
    final key = _mapKey(_votePallet, storage, _u64Le(proposalId));
    final data = await _readStorage(key);
    if (data == null) return const [];
    try {
      final c = _Cursor(data);
      final signs = c.vec(() {
        final accountId = '0x${_hex(c.bytes(32))}';
        final approveTag = c.u8();
        if (approveTag > 1) throw const FormatException('签署 bool 非法');
        return (accountId: accountId, approve: approveTag == 1);
      }, max: storage == 'LegOverrideSigns' ? 3 : 7);
      if (!c.isDone ||
          signs.map((s) => s.accountId).toSet().length != signs.length) {
        throw const FormatException('签署记录重复或尾随字节');
      }
      return signs;
    } on Object {
      throw const FormatException('签署记录编码无效');
    }
  }

  Future<Uint8List?> _readStorage(Uint8List key) async {
    final finalized = _block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('立法查询需要finalized块');
    }
    return _getStorage(finalized, key);
  }

  // ──── key 构造 ────

  Uint8List _mapKey(String pallet, String storage, Uint8List keyData) {
    final p = Hasher.twoxx128.hashString(pallet);
    final s = Hasher.twoxx128.hashString(storage);
    final k = _blake2128Concat(keyData);
    return Uint8List.fromList([...p, ...s, ...k]);
  }

  Uint8List _doubleMapKey(
    String pallet,
    String storage,
    Uint8List key1,
    Uint8List key2,
  ) {
    final p = Hasher.twoxx128.hashString(pallet);
    final s = Hasher.twoxx128.hashString(storage);
    final k1 = _blake2128Concat(key1);
    final k2 = _blake2128Concat(key2);
    return Uint8List.fromList([...p, ...s, ...k1, ...k2]);
  }

  Uint8List _blake2128Concat(Uint8List data) {
    final hash = Hasher.blake2b128.hash(data);
    return Uint8List.fromList([...hash, ...data]);
  }

  Uint8List _u64Le(int value) {
    if (value < 0) throw ArgumentError('proposal_id不得为负');
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setUint64(0, value, Endian.little);
    return bytes;
  }

  Uint8List _u32Le(int value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value, Endian.little);
    return bytes;
  }

  int _u32(Uint8List data, int offset) =>
      ByteData.sublistView(data).getUint32(offset, Endian.little);

  int _u64(Uint8List data, int offset) =>
      ByteData.sublistView(data).getUint64(offset, Endian.little);

  Uint8List _hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(h)) {
      throw const FormatException('签署公钥必须为32字节');
    }
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

/// 极简 SCALE 游标(本服务局部用)。
class _Cursor {
  _Cursor(this.data);
  final Uint8List data;
  int _i = 0;

  bool get isDone => _i == data.length;

  int u8() => data[_i++];

  int u32() {
    final v =
        data[_i] |
        (data[_i + 1] << 8) |
        (data[_i + 2] << 16) |
        (data[_i + 3] << 24);
    _i += 4;
    return v;
  }

  int compact() {
    final b0 = data[_i];
    final mode = b0 & 0x03;
    if (mode == 0) {
      _i += 1;
      return b0 >> 2;
    }
    if (mode == 1) {
      final v = (data[_i] | (data[_i + 1] << 8)) >> 2;
      _i += 2;
      if (v < 64) throw const FormatException('Compact非最短');
      return v;
    }
    if (mode == 2) {
      final v =
          (data[_i] |
              (data[_i + 1] << 8) |
              (data[_i + 2] << 16) |
              (data[_i + 3] << 24)) >>
          2;
      _i += 4;
      if (v < 16384) throw const FormatException('Compact非最短');
      return v;
    }
    throw const FormatException('长度Compact超出范围');
  }

  Uint8List bytes(int n) {
    final b = data.sublist(_i, _i + n);
    _i += n;
    return b;
  }

  String cidNumber() {
    final length = compact();
    if (length <= 0 || length > 32) {
      throw const FormatException('机构 CID 长度必须为 1..32 字节');
    }
    return utf8.decode(bytes(length));
  }

  String roleCode() {
    final length = compact();
    if (length <= 0 || length > 64) {
      throw const FormatException('岗位码长度必须为 1..64 字节');
    }
    return utf8.decode(bytes(length));
  }

  LegRepresentativeBody representativeBody() =>
      LegRepresentativeBody(cidNumber: cidNumber(), roleCode: roleCode());

  List<T> vec<T>(T Function() item, {int max = 4}) {
    final n = compact();
    if (n > max) throw const FormatException('向量超过链端上限');
    return [for (var k = 0; k < n; k++) item()];
  }
}
