import 'dart:convert';

import 'package:citizen_citizen/pallet_registry.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:polkadart/scale_codec.dart' show ByteOutput;

import 'package:citizen_citizen/legislation/legislation_vote_query_service.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';

/// 立法投票/签署提交服务(LegislationVote sub-pallet,pallet_index=26)。
///
/// 代表机构表决/行政签署/三人会签/护宪终审四个动作都是**纯 extrinsic**
/// (signer=origin=动作人本人,零 op_tag)，业务层只编码 RuntimeCall，
/// 交易准备、冷热签名和最终执行由 CitizenSDK 完成。提交后回读 legislation-vote storage 确认
/// runtime 已记账,tx_hash 不代表已执行。特别案公投属于链端独立的公投流程。
///
/// 代表机构表决额外携带 `voter_role_code`；其余签署调用保持
/// `[26][call_index][proposal_id:u64_le][approve:bool]`。
class LegislationVoteService {
  LegislationVoteService({
    required CitizenChain chain,
    required CitizenTransactions transactions,
  }) : _chain = chain,
       _transactions = transactions,
       _query = LegislationVoteQueryService(chain: chain);

  final CitizenChain _chain;
  final CitizenTransactions _transactions;
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
    final query = LegislationVoteQueryService(
      chain: _chain,
      block: result.execution.block,
    );
    final vote = await query.fetchRepresentativeVote(
      proposalId,
      bodyIndex,
      meta.bodies[bodyIndex].cidNumber,
      voterRoleCode,
      '0x${_hexEncode(signerPublicKey)}',
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
    final signs = await LegislationVoteQueryService(
      chain: _chain,
      block: result.execution.block,
    ).fetchOverrideSigns(proposalId);
    final account = '0x${_hexEncode(signerPublicKey)}';
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
    final signs = await LegislationVoteQueryService(
      chain: _chain,
      block: result.execution.block,
    ).fetchGuardSigns(proposalId);
    final account = '0x${_hexEncode(signerPublicKey)}';
    if (signs.any((s) => s.accountId == account && s.approve != approve)) {
      throw StateError('执行块签署记录与本次方向不一致');
    }
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      blockHash: result.execution.block.hash,
    );
  }

  /// 构造 `[26][call][proposal_id:u64_le][approve:bool]` call data(对外公开供冷钱包复用)。
  static Uint8List buildCallData({
    required int callIndex,
    required int proposalId,
    String? voterRoleCode,
    required bool approve,
  }) {
    if (!const [
      callCastRepresentativeVote,
      callExecutiveSign,
      callOverrideSign,
      callGuardVote,
    ].contains(callIndex)) {
      throw ArgumentError('未知立法投票调用');
    }
    if (proposalId < 0) throw ArgumentError('proposal_id不得为负');
    final output = ByteOutput();
    output.pushByte(legislationVotePallet);
    output.pushByte(callIndex);
    output.write(_u64ToLeBytes(proposalId));
    if (callIndex == callCastRepresentativeVote) {
      final roleBytes = Uint8List.fromList(
        voterRoleCode == null ? const [] : utf8.encode(voterRoleCode),
      );
      if (voterRoleCode != voterRoleCode?.trim() ||
          roleBytes.isEmpty ||
          roleBytes.length > 64) {
        throw ArgumentError('代表机构表决必须提供 1..64 字节 voter_role_code');
      }
      output.write(_encodeCompact(roleBytes.length));
      output.write(roleBytes);
    } else if (voterRoleCode != null) {
      throw ArgumentError('当前立法签署调用不得携带 voter_role_code');
    }
    output.pushByte(approve ? 1 : 0);
    return output.toBytes();
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
    final callData = buildCallData(
      callIndex: callIndex,
      proposalId: proposalId,
      voterRoleCode: voterRoleCode,
      approve: approve,
    );
    final prepared = await _transactions.prepareTransaction(
      signerPublicKey,
      callData,
    );
    final started = await _transactions.executePreparedTransaction(
      prepared.preparationId,
    );
    CitizenTransactionExecutionCompleted completed;
    if (started is CitizenTransactionExternalSigningPending) {
      final String? response;
      try {
        response = await externalSigning(started);
      } catch (_) {
        await _transactions.cancelPreparedTransactionExecution(
          started.executionId,
        );
        rethrow;
      }
      if (response == null) {
        await _transactions.cancelPreparedTransactionExecution(
          started.executionId,
        );
        throw StateError('立法投票签名已取消');
      }
      completed = await _transactions.consumePreparedTransactionQrResponse(
        started.executionId,
        response,
      );
    } else {
      completed = started as CitizenTransactionExecutionCompleted;
    }
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
    final events = await ProposalQueryService(
      chain: _chain,
      block: execution.block,
    ).fetchExecutionEvents(execution);
    final matches = events
        .where(
          (event) =>
              event.index == execution.extrinsicIndex &&
              event.pallet == 'LegislationVote' &&
              event.name == name,
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次立法投票事件');
    final fields = matches.single.fields;
    if (fields is! Map ||
        fields['proposal_id'].toString() != '$proposalId' ||
        fields['approve'] != approve ||
        fields['who'] is! List ||
        _hexEncode(Uint8List.fromList((fields['who'] as List).cast<int>())) !=
            _hexEncode(signer) ||
        voterRoleCode != null &&
            (fields['voter_role_code'] is! List ||
                utf8.decode((fields['voter_role_code'] as List).cast<int>()) !=
                    voterRoleCode ||
                fields['body_index'] != bodyIndex)) {
      throw StateError('执行块立法投票事件与本次提案、签署人、岗位或方向不一致');
    }
  }

  // ──── 内部:编码工具 ────

  static Uint8List _u64ToLeBytes(int value) {
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setUint64(0, value, Endian.little);
    return bytes;
  }

  static Uint8List _encodeCompact(int value) {
    if (value < 0 || value >= 1 << 14) {
      throw ArgumentError('长度超出 SCALE Compact 两字节范围');
    }
    if (value < 1 << 6) return Uint8List.fromList([value << 2]);
    final encoded = (value << 2) | 1;
    return Uint8List.fromList([encoded & 0xff, encoded >> 8]);
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
