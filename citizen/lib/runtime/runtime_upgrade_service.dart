import 'dart:convert';


import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';

import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';

/// 协议升级提案链上交互服务。
///
/// 负责协议升级提案详情查询，并保留现有详情页投票提交能力。
class RuntimeUpgradeService {
  RuntimeUpgradeService({
    CitizenSdk? chain,
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
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
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getStorageRuntimeContext,
  }) : _buildCall = buildCall ?? transactions?.buildCall ?? chain?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _proposalQuery = ProposalQueryService(
         chain: chain,
         getSystemEvents: getSystemEvents,
         getRuntimeContext: getRuntimeContext,
         getStorageRuntimeContext: getStorageRuntimeContext,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       ),
       _getStorageRuntimeContext = getStorageRuntimeContext ?? getRuntimeContext ??
           chain?.getRuntimeContext ?? ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch')),
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
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getStorageRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;
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

  final ProposalQueryService _proposalQuery;

  // ──── 常量 ────

  /// runtime-upgrade 写入 VotingEngine::ProposalData 的业务前缀。
  static const _moduleTag = [0x72, 0x74, 0x2d, 0x75, 0x70, 0x67]; // rt-upg

  // ──── Extrinsic 提交 ────

  /// 提交机构岗位有效选民的联合投票。
  ///
  /// 联合投票必须等待 finalized，并核对同一交易的完整 runtime 投票事件。
  /// tx_hash 只代表交易提交，不能代表投票已经生效。
  Future<({String txHash, int usedNonce, String blockHash})> submitJointVote({
    required int proposalId,
    required String actorCidNumber,
    required String voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    final callData = await _buildJointVoteCall(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      voterRoleCode: voterRoleCode,
      approve: approve,
    );
    final result = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmRuntimeJointVote(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      voterRoleCode: voterRoleCode,
      approve: approve,
      signerPublicKey: signerPublicKey,
      execution: result.execution,
    );
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  // ──── 链上查询 ────

  /// 查询协议升级提案详情。返回 null 表示不存在。
  ///
  /// ProposalData 是 `BoundedVec<u8>`，SCALE 编码为 Compact 长度前缀 + 原始字节。
  /// 原始字节布局：
  ///   actor_cid_number: CidNumber + proposer: AccountId32(32)
  ///   + reason: `Vec<u8>`(Compact len + bytes)
  ///   + code_hash: [u8;32] + expected_pow_params_hash: [u8;32]
  ///   + PowDifficultyParams 固定字段。真实状态只读取 VotingEngine::Proposals.status。
  Future<RuntimeUpgradeProposalInfo?> fetchRuntimeUpgradeProposal(
    int proposalId,
  ) async {
    final raw = await _readStorage('VotingEngine', 'ProposalData', [proposalId]);
    if (raw == null || raw.isEmpty) return null;
    return decodeRuntimeUpgradeStorageValue(proposalId, raw);
  }

  /// 解码 `ProposalData` 的原始 storage value（带 Compact 长度前缀）。
  ///
  /// 分页列表会批量读取 ProposalData，随后在内存里按提案类型解码；
  /// 这里提供公共入口，避免不同页面各自复制一套 runtime 提案解码逻辑。
  RuntimeUpgradeProposalInfo? decodeRuntimeUpgradeStorageValue(
    int proposalId,
    Uint8List raw,
  ) {
    try {
      int offset = 0;
      final (vecLen, lenBytes) = _decodeCompact(raw, offset);
      offset += lenBytes;
      if (offset + vecLen != raw.length) return null;
      final data = raw.sublist(offset, offset + vecLen);
      return _decodeRuntimeUpgradeAction(proposalId, data);
    } catch (_) {
      return null;
    }
  }

  /// 查询联合投票计数（JointTallies）。
  ///
  /// Value: VoteCountU32 { yes: u32, no: u32 } = 8 bytes。
  Future<({int yes, int no})> fetchJointTally(int proposalId) async {
    final data = await _readStorage('JointVote', 'JointTallies', [proposalId]);
    if (data == null || data.length != 8) return (yes: 0, no: 0);
    // VoteCountU32: { yes: u32, no: u32 } — 4+4 bytes little-endian
    final yes = _decodeU32(data, 0);
    final no = _decodeU32(data, 4);
    return (yes: yes, no: no);
  }

  /// 查询联合投票中某机构的投票记录。
  ///
  /// 双 map：blake2_128_concat(u64_le) + blake2_128_concat(CidNumber)。
  /// Value: `Option<bool>` — null=未投票，true=赞成，false=反对。
  Future<bool?> fetchJointVoteByInstitution(
    int proposalId,
    String actorCidNumber,
  ) async {
    final data = await _readStorage('JointVote', 'JointVotesByInstitution', [proposalId, _cidBytes(actorCidNumber)]);
    return _decodeBoolVote(data);
  }

  /// 查询某机构在联合投票阶段的岗位选民票数统计。
  Future<({int yes, int no})> fetchJointInstitutionTally(
    int proposalId,
    String actorCidNumber,
  ) async {
    final data = await _readStorage('JointVote', 'JointInstitutionTallies', [proposalId, _cidBytes(actorCidNumber)]);
    if (data == null || data.length != 8) return (yes: 0, no: 0);
    return (yes: _decodeU32(data, 0), no: _decodeU32(data, 4));
  }

  /// 查询某岗位快照选民在某机构联合投票中的投票记录。
  Future<bool?> fetchJointTicketVote(
    int proposalId,
    String actorCidNumber,
    String voterRoleCode,
    String publicKey, {
    CitizenBlockRef? block,
  }) async {
    final runtime = await _finalizedRuntime(block);
    final key = _jointTicketVoteKey(
      runtime,
      proposalId,
      actorCidNumber,
      voterRoleCode,
      publicKey,
    );
    if (key == null) return null;
    final data = await _getStorage(runtime.block, key);
    return _decodeBoolVote(data);
  }

  /// 批量查询联合投票岗位选民记录。
  ///
  /// 协议升级详情页必须批量读取稳定 storage `JointVotesByTicket`，不能逐个
  /// 岗位选民发起 RPC；storage 旧名不构成管理员授权语义。
  Future<Map<String, bool?>> fetchJointTicketVotesBatch(
    int proposalId,
    String actorCidNumber,
    String voterRoleCode,
    Iterable<String> accountIds,
  ) async {
    if (accountIds.isEmpty) return const {};
    final runtime = await _finalizedRuntime();
    final keyByAccountId = <String, String>{};
    for (final accountId in accountIds) {
      final normalizedAccountId = _requireAccountId(accountId);
      final key = _jointTicketVoteKey(
        runtime,
        proposalId,
        actorCidNumber,
        voterRoleCode,
        normalizedAccountId,
      );
      if (key == null) continue;
      keyByAccountId[normalizedAccountId] = _hexEncode(key);
    }
    if (keyByAccountId.isEmpty) return const {};
    final values = await _fetchStorageBatchChunked(runtime.block, keyByAccountId.values);
    return {
      for (final entry in keyByAccountId.entries)
        entry.key: _decodeBoolVote(values[entry.value]),
    };
  }

  /// 跨提案批量查询联合投票：输入 `{proposal_id: (机构 CID, [account_id])}`，
  /// 一次链查返回 `{proposal_id: {account_id: vote?}}`。
  ///
  /// (ADR-018 R2):与内部投票同理,广场上多个联合投票提案合并成单次
  /// 分块读取,避免每提案一次 RPC。
  Future<Map<int, Map<String, bool?>>> fetchJointTicketVotesForProposals(
    Map<
      int,
      ({String actorCidNumber, String voterRoleCode, List<String> accountIds})
    >
    byProposal,
  ) async {
    if (byProposal.values.every((item) => item.accountIds.isEmpty)) return const {};
    final runtime = await _finalizedRuntime();
    final keyToCoord = <String, ({int pid, String accountId})>{};
    for (final entry in byProposal.entries) {
      for (final accountId in entry.value.accountIds) {
        final normalizedAccountId = _requireAccountId(accountId);
        final key = _jointTicketVoteKey(
          runtime,
          entry.key,
          entry.value.actorCidNumber,
          entry.value.voterRoleCode,
          normalizedAccountId,
        );
        if (key == null) continue;
        keyToCoord[_hexEncode(key)] = (pid: entry.key, accountId: normalizedAccountId);
      }
    }
    if (keyToCoord.isEmpty) return const {};
    final values = await _fetchStorageBatchChunked(runtime.block, keyToCoord.keys);
    final result = <int, Map<String, bool?>>{};
    keyToCoord.forEach((key, coord) {
      (result[coord.pid] ??= <String, bool?>{})[coord.accountId] =
          _decodeBoolVote(values[key]);
    });
    return result;
  }

  Uint8List? _jointTicketVoteKey(
    CitizenRuntimeContext runtime,
    int proposalId,
    String actorCidNumber,
    String voterRoleCode,
    String accountId,
  ) {
    final account = citizenAccountIdBytes(accountId);
    if (account.length != 32) return null;
    return runtime.storageKey('JointVote', 'JointVotesByTicket', [
      proposalId,
      [
        [_cidBytes(actorCidNumber), _roleBytes(voterRoleCode)],
        account,
      ],
    ]);
  }

  bool? _decodeBoolVote(Uint8List? data) {
    if (data == null) return null;
    if (data.length != 1 || (data[0] != 0 && data[0] != 1)) {
      throw const FormatException('JointVote 投票记录必须是严格的 SCALE bool');
    }
    return data[0] == 1;
  }

  /// 查询联合公投计数（ReferendumTallies）。
  ///
  /// Value: VoteCountU64 { yes: u64, no: u64 } = 16 bytes。
  Future<({int yes, int no})> fetchReferendumTally(int proposalId) async {
    final data = await _readStorage('JointVote', 'ReferendumTallies', [proposalId]);
    if (data == null || data.length != 16) return (yes: 0, no: 0);
    // VoteCountU64: { yes: u64, no: u64 } — 8+8 bytes little-endian
    final yes = _decodeU64(data.sublist(0, 8));
    final no = _decodeU64(data.sublist(8, 16));
    return (yes: yes, no: no);
  }

  /// 查询提案完整元数据（status + institution bytes）。
  /// 返回 null 表示提案不存在。
  Future<ProposalMeta?> fetchProposalMeta(int proposalId) async {
    return _proposalQuery.fetchProposalMeta(proposalId);
  }

  /// 查询 NextProposalId（投票引擎全局递增 ID）。
  Future<int> fetchNextProposalId() {
    return _proposalQuery.fetchNextProposalId();
  }

  // ──── 内部：解码 ────

  /// 解码协议升级提案摘要 SCALE 数据。
  RuntimeUpgradeProposalInfo? _decodeRuntimeUpgradeAction(
    int proposalId,
    Uint8List data,
  ) {
    try {
      if (!_startsWith(data, _moduleTag)) return null;
      var offset = _moduleTag.length;

      final actorCid = _decodeCidNumber(data, offset);
      final actorCidNumber = actorCid.$1;
      offset = actorCid.$2;

      // proposer: AccountId32 (32 bytes)
      if (offset + 32 > data.length) return null;
      final proposerBytes = data.sublist(offset, offset + 32);
      offset += 32;

      // reason: Vec<u8> (Compact length + bytes)
      final (reasonLen, reasonLenSize) = _decodeCompact(data, offset);
      offset += reasonLenSize;
      if (offset + reasonLen > data.length) return null;
      final reasonBytes = data.sublist(offset, offset + reasonLen);
      final reason = utf8.decode(reasonBytes, allowMalformed: false);
      offset += reasonLen;

      // code_hash: [u8; 32]
      if (offset + 32 > data.length) return null;
      final codeHashBytes = data.sublist(offset, offset + 32);
      offset += 32;

      if (offset + 32 + 34 > data.length) return null;
      final expectedPowParamsHashBytes = data.sublist(offset, offset + 32);
      offset += 32;
      final paramsVersion = _decodeU32(data, offset);
      offset += 4;
      final algorithmVersion = data[offset] | (data[offset + 1] << 8);
      offset += 2;
      final targetBlockTimeMs = _decodeU64(data.sublist(offset, offset + 8));
      offset += 8;
      final adjustmentInterval = _decodeU32(data, offset);
      offset += 4;
      final maxAdjustUpFactor = _decodeU64(data.sublist(offset, offset + 8));
      offset += 8;
      final maxAdjustDownDivisor = _decodeU64(data.sublist(offset, offset + 8));
      offset += 8;

      // 协议升级摘要不保存业务状态，避免与投票引擎终态脱节。
      if (offset != data.length) return null;

      final proposerSs58 = citizenSs58FromAccountIdBytes(proposerBytes);
      final codeHashHex = _hexEncode(Uint8List.fromList(codeHashBytes));

      return RuntimeUpgradeProposalInfo(
        proposalId: proposalId,
        actorCidNumber: actorCidNumber,
        proposer: proposerSs58,
        reason: reason,
        codeHashHex: codeHashHex,
        expectedPowParamsHashHex: _hexEncode(
          Uint8List.fromList(expectedPowParamsHashBytes),
        ),
        paramsVersion: paramsVersion,
        algorithmVersion: algorithmVersion,
        targetBlockTimeMs: targetBlockTimeMs,
        adjustmentInterval: adjustmentInterval,
        maxAdjustUpFactor: maxAdjustUpFactor,
        maxAdjustDownDivisor: maxAdjustDownDivisor,
      );
    } catch (_) {
      return null;
    }
  }

  bool _startsWith(Uint8List data, List<int> prefix) {
    if (data.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  // ──── 内部：extrinsic 编码 ────

  Future<Uint8List> _buildJointVoteCall({
    required int proposalId,
    required String actorCidNumber,
    required String voterRoleCode,
    required bool approve,
  }) {
    if (proposalId < 0) throw ArgumentError('proposal_id不得为负');
    return _buildCall('JointVote', 'cast_admin', [
      proposalId,
      _cidBytes(actorCidNumber),
      _roleBytes(voterRoleCode),
      approve,
    ]);
  }

  /// 签名、提交并等待交易最终执行成功。
  ///
  /// 返回交易哈希、runtime nonce 和最终执行块哈希。
  Future<({String txHash, int usedNonce, CitizenExecution execution})>
  _executeFinalized({
    required Uint8List callData,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('联合投票签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '联合投票交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
  }

  /// who 为当前签名账户；换绑后不能据此猜测历史票据的 canonical storage 键。
  Future<void> _confirmRuntimeJointVote({
    required int proposalId,
    required String actorCidNumber,
    required String voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
    required CitizenExecution execution,
  }) async {
    final events = await _proposalQuery.fetchExecutionEvents(execution);
    final matches = events
        .where(
          (event) =>
              event.pallet == 'JointVote' &&
              event.name == 'JointInstitutionTicketVoteCast',
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次联合投票事件');
    final event = matches.single;
    final fields = event.fields as Map<String, Object?>;
    if (event.fieldUnsigned('proposal_id') != BigInt.from(proposalId) ||
        fields['approve'] != approve ||
        _hexEncode(event.fieldBytes('who')) != _hexEncode(signerPublicKey) ||
        utf8.decode(event.fieldBytes('cid_number')) != actorCidNumber ||
        utf8.decode(event.fieldBytes('voter_role_code')) != voterRoleCode) {
      throw StateError('联合投票事件与本次提案、机构、签署人、岗位或方向不一致');
    }
  }

  Future<CitizenRuntimeContext> _finalizedRuntime([CitizenBlockRef? block]) async {
    final finalized = block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('联合投票查询需要finalized块');
    }
    return _getStorageRuntimeContext(finalized);
  }

  Future<Uint8List?> _readStorage(String pallet, String storage, List<Object> keys) async {
    final runtime = await _finalizedRuntime();
    return _getStorage(runtime.block, runtime.storageKey(pallet, storage, keys));
  }

  Future<Map<String, Uint8List?>> _fetchStorageBatchChunked(
    CitizenBlockRef finalized,
    Iterable<String> keyHexes, {
    int chunkSize = 100,
  }) async {
    final keys = keyHexes.toSet().toList(growable: false);
    if (keys.isEmpty) return const <String, Uint8List?>{};
    final result = <String, Uint8List?>{};
    for (var offset = 0; offset < keys.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, keys.length);
      final chunk = keys.sublist(offset, end);
      final values = await _getStorageBatch(
        finalized,
        chunk
            .map((key) => Uint8List.fromList(_hexDecode(key)))
            .toList(growable: false),
      );
      for (var index = 0; index < chunk.length; index++) {
        result[chunk[index]] = values[index];
      }
    }
    return result;
  }

  int _decodeU64(Uint8List data) => CitizenScale.readUnsigned(data, 0, 8).toInt();

  int _decodeU32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();

  (String, int) _decodeCidNumber(Uint8List data, int offset) {
    final (length, lengthSize) = _decodeCompact(data, offset);
    final start = offset + lengthSize;
    final end = start + length;
    if (length == 0 || length > 32 || end > data.length) {
      throw const FormatException('CidNumber SCALE 编码无效');
    }
    return (utf8.decode(data.sublist(start, end), allowMalformed: false), end);
  }

  Uint8List _cidBytes(String cidNumber) {
    final cidBytes = utf8.encode(cidNumber.trim());
    if (cidBytes.isEmpty || cidBytes.length > 32) {
      throw ArgumentError('机构 CID 的 UTF-8 长度必须为 1..32 字节');
    }
    return Uint8List.fromList(cidBytes);
  }

  Uint8List _roleBytes(String voterRoleCode) {
    final roleBytes = utf8.encode(voterRoleCode.trim());
    if (roleBytes.isEmpty || roleBytes.length > 64) {
      throw ArgumentError('岗位码的 UTF-8 长度必须为 1..64 字节');
    }
    return Uint8List.fromList(roleBytes);
  }

  (int, int) _decodeCompact(Uint8List data, int offset) =>
      CitizenScale.readCompact(data, offset);

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexDecode(String hex) {
    final clean = _normalizeHex(hex);
    final out = <int>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      out.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static String _normalizeHex(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    return clean.toLowerCase();
  }

  static String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}
