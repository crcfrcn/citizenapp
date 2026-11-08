import 'dart:convert';

import 'package:citizen_citizen/pallet_registry.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:citizen_citizen/legislation/legislation_vote_query_service.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';

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

  /// 当前代表机构表决；同一钱包在不同机构的席位分别记票。
  Future<({String txHash, int usedNonce, String blockHash})>
  castRepresentativeVote({
    required int proposalId,
    required String voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
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
      citizenAccountIdFromBytes(signerPublicKey),
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
    required int proposalId,
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
    required int proposalId,
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
    required int proposalId,
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
    required int proposalId,
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
    if (proposalId < 0) throw ArgumentError('proposal_id不得为负');
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
    required int proposalId,
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
    int proposalId,
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
    if (event.fieldUnsigned('proposal_id') != BigInt.from(proposalId) ||
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
