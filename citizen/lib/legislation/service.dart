// 立法投票读取及操作服务。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;
import 'package:citizen_citizen/institution/service.dart' show InstitutionChainService;
import 'package:citizen_citizen/institution/codec.dart' show InstitutionRoleStorageCodec;
import 'package:citizen_citizen/data.dart' show PalletRegistry;

// 读取并严格解码立法提案、代表票据、公投和签署状态。

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
       _people = InstitutionChainService(chain: chain, getFinalizedHead: getFinalizedHead, getRuntimeContext: getRuntimeContext, getStorage: getStorage, getStorageBatch: getStorageBatch),
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
       _getRuntimeContext = getRuntimeContext ?? chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  final CitizenBlockRef? _block;
  final InstitutionChainService _people;
  final ProposalQueryService _proposalQuery;

  static const String _votePallet = 'LegislationVote';

  /// 钱包只通过同块有效双向绑定解析为人员CID，不从本地资格或历史账户反推。
  Future<String?> fetchPersonCid(String accountId) async {
    final block = _block ?? await _getFinalizedHead();
    if (block.finality != CitizenBlockFinality.finalized) throw StateError('人员绑定需要finalized块');
    return _people.personCid(accountId, await _getRuntimeContext(block));
  }

  /// 核心提案阶段/状态(不存在返回 null)。
  Future<LegProposalState?> fetchProposalState(BigInt proposalId) async {
    final proposal = await _proposalQuery.fetchProposalMeta(proposalId);
    if (proposal == null) return null;
    return LegProposalState(
      kind: proposal.kind,
      stage: proposal.stage,
      status: proposal.status,
    );
  }

  Future<LegRepresentativeMeta?> fetchRepresentativeMeta(BigInt proposalId) async {
    final data = await _readStorage('RepresentativeMetas', [proposalId]);
    if (data == null) return null;
    final result = _decodeRepresentativeMeta(data);
    if (result == null) throw const FormatException('RepresentativeMetas编码无效');
    return result;
  }

  Future<LegislationMeta?> fetchLegislationMeta(BigInt proposalId) async {
    final data = await _readStorage('LegislationMetas', [proposalId]);
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
    BigInt proposalId,
    int bodyIndex,
  ) async {
    final data = await _readStorage('RepresentativeTallies', [proposalId, bodyIndex]);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 8) throw const FormatException('代表机构计票长度无效');
    return (yes: _u32(data, 0), no: _u32(data, 4));
  }

  /// 公投计票(VoteCountU64:yes u64 + no u64)。
  Future<({int yes, int no})> fetchReferendumTally(BigInt proposalId) async {
    final data = await _readStorage('LegReferendumTally', [proposalId]);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 16) throw const FormatException('公投计票长度无效');
    return (yes: _u64(data, 0), no: _u64(data, 8));
  }

  /// 某钱包在指定代表机构岗位席位的投票。
  Future<bool?> fetchRepresentativeVote(
    BigInt proposalId,
    int bodyIndex,
    String cidNumber,
    String voterRoleCode,
    String personCid,
  ) async {
    if (!InstitutionRoleStorageCodec.isPersonCid(personCid)) throw const FormatException('机构票据必须使用人员CID');
    final tupleKey = Uint8List.fromList([
      ...CitizenScale.unsigned(BigInt.from(bodyIndex), 4),
      ..._encodeBoundedText(cidNumber, 32, 'cid_number'),
      ..._encodeBoundedText(voterRoleCode, 64, 'voter_role_code'),
      ..._encodeBoundedText(personCid, 32, 'person_cid'),
    ]);
    final data = await _readStorage('RepresentativeVotesByTicket', [proposalId, (scale: tupleKey)]);
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
    return Uint8List.fromList([...CitizenScale.compact(bytes.length), ...bytes]);
  }

  /// 三人会签记录(LegOverrideSigns:BoundedVec<(AccountId,bool)>)。
  Future<List<({String accountId, bool approve})>> fetchOverrideSigns(
    BigInt proposalId,
  ) {
    return _fetchSigns('LegOverrideSigns', proposalId);
  }

  /// 护宪大法官终审记录(LegGuardSigns:BoundedVec<(AccountId,bool)>)。
  Future<List<({String accountId, bool approve})>> fetchGuardSigns(
    BigInt proposalId,
  ) {
    return _fetchSigns('LegGuardSigns', proposalId);
  }

  Future<List<({String accountId, bool approve})>> _fetchSigns(
    String storage,
    BigInt proposalId,
  ) async {
    final data = await _readStorage(storage, [proposalId]);
    if (data == null) return const [];
    try {
      final c = _Cursor(data);
      final signs = c.vec(() {
        final accountId = citizenAccountIdFromBytes(c.bytes(32));
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

  Future<Uint8List?> _readStorage(String storage, List<Object> keys) async {
    final finalized = _block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('立法查询需要finalized块');
    }
    final runtime = await _getRuntimeContext(finalized);
    return _getStorage(finalized, runtime.storageKey(_votePallet, storage, keys));
  }

  int _u32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();

  int _u64(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 8).toInt();
}

/// 极简 SCALE 游标(本服务局部用)。
class _Cursor {
  _Cursor(this.data);
  final Uint8List data;
  int _i = 0;

  bool get isDone => _i == data.length;

  int u8() => data[_i++];

  int u32() {
    final value = CitizenScale.readUnsigned(data, _i, 4);
    _i += 4;
    return value.toInt();
  }

  int compact() {
    final (value, width) = CitizenScale.readCompact(data, _i);
    if (width > 4) throw const FormatException('长度Compact超出范围');
    _i += width;
    return value;
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

// 编码立法表决和签署调用，经SDK执行并核对准确业务事件。

/// 立法投票/签署提交服务(LegislationVote sub-pallet,pallet_index=26)。
///
/// 代表机构表决/行政签署/三人会签/护宪终审四个动作都是**纯 extrinsic**
/// (signer=origin=动作人本人,零 op_tag)，业务层只编码 RuntimeCall，
/// 交易准备、冷热签名和最终执行由 CitizenSDK 完成。提交后回读 legislation-vote storage 确认
/// runtime 已记账,tx_hash 不代表已执行。特别案公投属于链端独立的公投流程。
///
/// 代表机构表决额外携带 `voter_role_code`，调用参数由 SDK 按 Runtime metadata 编码。
class LegislationVoteService {
  LegislationVoteService({
    CitizenSdk? chain,
    LegislationVoteQueryService Function(CitizenBlockRef? block)? voteQuery,
    ProposalQueryService Function(CitizenBlockRef? block)? eventQuery,
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
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
  }) : _buildCall = buildCall ?? transactions?.buildCall ?? chain?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _voteQuery =
           voteQuery ??
           ((block) => LegislationVoteQueryService(chain: chain, block: block)),
       _eventQuery =
           eventQuery ??
           ((block) => ProposalQueryService(chain: chain, block: block)),
       _query =
           (voteQuery ??
           ((block) =>
               LegislationVoteQueryService(chain: chain, block: block)))(null),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _executePreparedTransaction =
           executePreparedTransaction ??
           transactions?.executePreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置executePreparedTransaction')),
       _cancelPreparedTransactionExecution =
           cancelPreparedTransactionExecution ??
           transactions?.cancelPreparedTransactionExecution ??
           ((String executionId) =>
               throw StateError('未配置cancelPreparedTransactionExecution')),
       _consumePreparedTransactionQrResponse =
           consumePreparedTransactionQrResponse ??
           transactions?.consumePreparedTransactionQrResponse ??
           ((String executionId, String response) =>
               throw StateError('未配置consumePreparedTransactionQrResponse'));
  final CitizenCallBuilder _buildCall;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<CitizenTransactionExecution> Function(String preparationId)
  _executePreparedTransaction;
  final Future<void> Function(String executionId)
  _cancelPreparedTransactionExecution;
  final Future<CitizenTransactionExecutionCompleted> Function(
    String executionId,
    String response,
  )
  _consumePreparedTransactionQrResponse;

  final LegislationVoteQueryService Function(CitizenBlockRef? block) _voteQuery;
  final ProposalQueryService Function(CitizenBlockRef? block) _eventQuery;

  final LegislationVoteQueryService _query;

  /// LegislationVote runtime pallet_index。
  static const int legislationVotePallet = PalletRegistry.legislationVotePallet;

  static const int callCastRepresentativeVote =
      PalletRegistry.castRepresentativeVoteCall;
  static const int callExecutiveSign = PalletRegistry.executiveSignCall;
  static const int callOverrideSign = PalletRegistry.overrideSignCall;
  static const int callGuardVote = PalletRegistry.guardVoteCall;

  // ──── 公开 API ────

  /// 当前代表机构表决；按机构岗位及人员CID记票，钱包只负责本次签名。
  Future<({String txHash, int usedNonce, String blockHash})>
  castRepresentativeVote({
    required BigInt proposalId,
    required String voterRoleCode,
    required String personCid,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (!InstitutionRoleStorageCodec.isPersonCid(personCid)) {
      throw ArgumentError('代表机构票据必须使用人员CID');
    }
    final meta = await _query.fetchRepresentativeMeta(proposalId);
    if (meta == null) throw StateError('代表机构表决元数据不存在');
    final bodyIndex = meta.currentBody;
    if (meta.bodies[bodyIndex].roleCode != voterRoleCode) {
      throw ArgumentError('投票岗位与当前代表机构不一致');
    }
    final result = await _executeFinalized(
      callIndex: callCastRepresentativeVote,
      proposalId: proposalId,
      voterRoleCode: voterRoleCode,
      approve: approve,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmEvent(
      result.execution,
      proposalId,
      signerPublicKey,
      approve,
      'RepresentativeVoteCast',
      voterRoleCode: voterRoleCode,
      bodyIndex: bodyIndex,
    );
    final query = _voteQuery(result.execution.block);
    final vote = await query.fetchRepresentativeVote(
      proposalId,
      bodyIndex,
      meta.bodies[bodyIndex].cidNumber,
      voterRoleCode,
      personCid,
    );
    if (vote != null && vote != approve) throw StateError('执行块的代表投票方向不一致');
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  /// 行政首长(机构法定代表人)签署或否决。
  Future<({String txHash, int usedNonce, String blockHash})> executiveSign({
    required BigInt proposalId,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final result = await _executeFinalized(
      callIndex: callExecutiveSign,
      proposalId: proposalId,
      approve: approve,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmEvent(
      result.execution,
      proposalId,
      signerPublicKey,
      approve,
      'LegislationExecutiveSigned',
    );
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  /// 三人会签(立法院院长 + 参议长 + 众议长)签署或否决。
  Future<({String txHash, int usedNonce, String blockHash})> overrideSign({
    required BigInt proposalId,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final result = await _executeFinalized(
      callIndex: callOverrideSign,
      proposalId: proposalId,
      approve: approve,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmEvent(
      result.execution,
      proposalId,
      signerPublicKey,
      approve,
      'LegislationOverrideSigned',
    );
    final signs = await _voteQuery(result.execution.block)
        .fetchOverrideSigns(proposalId);
    final account = citizenAccountIdFromBytes(signerPublicKey);
    if (signs.any((s) => s.accountId == account && s.approve != approve)) {
      throw StateError('执行块签署记录与本次方向不一致');
    }
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  /// 护宪大法官终审表决(修宪)。
  Future<({String txHash, int usedNonce, String blockHash})> guardVote({
    required BigInt proposalId,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final result = await _executeFinalized(
      callIndex: callGuardVote,
      proposalId: proposalId,
      approve: approve,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmEvent(
      result.execution,
      proposalId,
      signerPublicKey,
      approve,
      'LegislationGuardVoted',
    );
    final signs = await _voteQuery(result.execution.block)
        .fetchGuardSigns(proposalId);
    final account = citizenAccountIdFromBytes(signerPublicKey);
    if (signs.any((s) => s.accountId == account && s.approve != approve)) {
      throw StateError('执行块签署记录与本次方向不一致');
    }
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  static Future<Uint8List> buildCallData({
    required CitizenCallBuilder buildCall,
    required int callIndex,
    required BigInt proposalId,
    String? voterRoleCode,
    required bool approve,
  }) {
    final method = switch (callIndex) {
      callCastRepresentativeVote => 'cast_representative_vote',
      callExecutiveSign => 'executive_sign',
      callOverrideSign => 'override_sign',
      callGuardVote => 'guard_vote',
      _ => throw ArgumentError('未知立法投票调用'),
    };
    if (proposalId.isNegative) throw ArgumentError('proposal_id不得为负');
    final fields = <Object>[proposalId];
    if (callIndex == callCastRepresentativeVote) {
      final roleBytes = Uint8List.fromList(
        voterRoleCode == null ? const [] : utf8.encode(voterRoleCode),
      );
      if (voterRoleCode != voterRoleCode?.trim() ||
          roleBytes.isEmpty ||
          roleBytes.length > 64) {
        throw ArgumentError('代表机构表决必须提供 1..64 字节 voter_role_code');
      }
      fields.add(roleBytes);
    } else if (voterRoleCode != null) {
      throw ArgumentError('当前立法签署调用不得携带 voter_role_code');
    }
    fields.add(approve);
    return buildCall('LegislationVote', method, fields);
  }

  // ──── 内部:签名提交 ────

  Future<({String txHash, int usedNonce, CitizenExecution execution})>
  _executeFinalized({
    required int callIndex,
    required BigInt proposalId,
    String? voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    final callData = await buildCallData(
      buildCall: _buildCall,
      callIndex: callIndex,
      proposalId: proposalId,
      voterRoleCode: voterRoleCode,
      approve: approve,
    );
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('立法投票签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '立法投票交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
  }

  /// 只接受同块、同交易索引和完整业务字段匹配的事件，终态清账不能替代证明。
  Future<void> _confirmEvent(
    CitizenExecution execution,
    BigInt proposalId,
    Uint8List signer,
    bool approve,
    String name, {
    String? voterRoleCode,
    int? bodyIndex,
  }) async {
    final events = await _eventQuery(execution.block)
        .fetchExecutionEvents(execution);
    final matches = events
        .where(
          (event) =>
              event.pallet == 'LegislationVote' &&
              event.name == name,
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次立法投票事件');
    final event = matches.single;
    final fields = event.fields as Map<String, Object?>;
    if (event.fieldUnsigned('proposal_id') != proposalId ||
        fields['approve'] != approve ||
        _hexEncode(event.fieldBytes('who')) != _hexEncode(signer) ||
        (voterRoleCode != null &&
            (utf8.decode(event.fieldBytes('voter_role_code')) != voterRoleCode ||
                bodyIndex == null ||
                event.fieldUnsigned('body_index') != BigInt.from(bodyIndex)))) {
      throw StateError('执行块立法投票事件与本次提案、签署人、岗位或方向不一致');
    }
  }

  // ──── 内部:编码工具 ────

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
