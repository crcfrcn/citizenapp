import 'dart:convert';

import 'package:citizen_citizen/pallet_registry.dart';

import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:polkadart/scale_codec.dart' show ByteOutput;

import 'package:citizen_citizen/proposal/proposal_query_service.dart';

/// 投票引擎统一投票入口服务。
///
/// - 所有业务 pallet(admins_change / resolution_destroy /
///   grandpakey_change / institution_multisig / transaction 业务)的
///   管理员一人一票一律走
///   `InternalVote::cast(proposal_id, ticket_claim, approve)` 一条路径。
/// - 业务 service(InstitutionChainService 等)
///   只负责发起提案(propose_X)；执行重试统一走 VotingEngine.retry_passed_proposal,
///   投票动作统一
///   委托本服务,避免多处构造相同的 call。
///
/// Runtime 位置: `pallet_index=20, call_index=0`(InternalVote sub-pallet)。
/// Call 编码: `[0x14][0x00][proposal_id:u64_le][ticket_claim][approve:bool]`。
class InternalVoteService {
  InternalVoteService({
    CitizenSdk? chain,
    ProposalQueryService Function(CitizenBlockRef block)? queryFactory,
    CitizenSdk? transactions,
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
  }) : _queryFactory =
           queryFactory ??
           ((block) => ProposalQueryService(chain: chain, block: block)),
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

  final ProposalQueryService Function(CitizenBlockRef block) _queryFactory;

  // ──── 常量 ────

  /// InternalVote sub-pallet。runtime pallet_index=20。
  static const int internalVotePallet = PalletRegistry.internalVotePallet;

  /// InternalVote::cast call_index=0。
  static const int internalVoteCallIndex = PalletRegistry.internalVoteCastCall;

  // ──── 公开 API ────

  /// 提交 `InternalVote::cast(proposal_id, ticket_claim, approve)` extrinsic(pallet 20.0)。
  ///
  /// 投票提交必须等待交易进入区块。tx_hash 只代表交易已提交，
  /// 不能代表 runtime 已执行 `InternalVote::cast`。
  ///
  /// 返回交易哈希、runtime nonce 和最终执行块哈希。业务模块无需感知提案所属
  /// pallet/MODULE_TAG，投票引擎会按 ProposalData 前缀自动分派到对应
  /// `InternalVoteExecutor`；本次写入以同一 finalized 执行的准确事件证明，展示查询仍读取投票引擎 storage。
  Future<({String txHash, int usedNonce, String blockHash})> submit({
    required int proposalId,
    required bool approve,
    String? actorCidNumber,
    String? voterRoleCode,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    if ((actorCidNumber == null) != (voterRoleCode == null)) {
      throw ArgumentError('机构CID与岗位码必须同时提供');
    }
    if (actorCidNumber != null &&
        (actorCidNumber != actorCidNumber.trim() ||
            utf8.encode(actorCidNumber).isEmpty ||
            utf8.encode(actorCidNumber).length > 32)) {
      throw ArgumentError('机构CID长度必须为1..32字节');
    }
    final callData = buildCallData(
      proposalId: proposalId,
      voterRoleCode: voterRoleCode,
      approve: approve,
    );
    final result = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    await _confirmRuntimeVote(
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

  /// 构造 InternalVote::cast call data(对外公开,便于冷钱包/热钱包复用)。
  ///
  /// `voterRoleCode == null` 编码个人票据声明 0；机构岗位编码声明 1 + RoleCode。
  static Uint8List buildCallData({
    required int proposalId,
    String? voterRoleCode,
    required bool approve,
  }) {
    final output = ByteOutput();
    output.pushByte(internalVotePallet);
    output.pushByte(internalVoteCallIndex);
    output.write(_u64ToLeBytes(proposalId));
    final roleCode = voterRoleCode;
    if (roleCode == null) {
      output.pushByte(0); // InternalVoteTicketClaim::Personal
    } else {
      final roleBytes = Uint8List.fromList(utf8.encode(roleCode));
      if (roleCode != roleCode.trim() ||
          roleBytes.isEmpty ||
          roleBytes.length > 64) {
        throw ArgumentError('voter_role_code 超过 64 字节');
      }
      output.pushByte(1); // InternalVoteTicketClaim::InstitutionRole
      output.write(_encodeCompact(roleBytes.length));
      output.write(roleBytes);
    }
    output.pushByte(approve ? 1 : 0);
    return output.toBytes();
  }

  // ──── 内部：签名提交 ────

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
    CitizenTransactionExecutionCompleted completed;
    if (started is CitizenTransactionExternalSigningPending) {
      final String? response;
      try {
        response = await externalSigning(started);
      } catch (_) {
        await _cancelPreparedTransactionExecution(started.executionId);
        rethrow;
      }
      if (response == null) {
        await _cancelPreparedTransactionExecution(started.executionId);
        throw StateError('投票签名已取消');
      }
      completed = await _consumePreparedTransactionQrResponse(
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
      throw StateError(completed.poolRejectionReason ?? '投票交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
  }

  /// runtime 事件中的 who 是当前签名账户；历史票据的 canonical 账户可能不同。
  /// 只接受本次 finalized 交易的唯一投票事件，不用当前公钥猜历史 storage 主键。
  Future<void> _confirmRuntimeVote({
    required int proposalId,
    required CitizenExecution execution,
    required String? actorCidNumber,
    required String? voterRoleCode,
    required bool approve,
    required Uint8List signerPublicKey,
  }) async {
    final query = _queryFactory(execution.block);
    final events = await query.fetchExecutionEvents(execution);
    final matches = events
        .where(
          (event) =>
              event.index == execution.extrinsicIndex &&
              event.pallet == 'InternalVote' &&
              event.name == 'InternalVoteCast',
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次内部投票事件');
    final fields = matches.single.fields;
    final role = fields is Map ? fields['voter_role_code'] : null;
    final roleMatches =
        role is Map &&
        role.length == 1 &&
        (voterRoleCode == null
            ? role.containsKey('None') && role['None'] == null
            : role['Some'] is List &&
                  utf8.decode((role['Some'] as List).cast<int>()) ==
                      voterRoleCode);
    if (fields is! Map ||
        fields['proposal_id'].toString() != '$proposalId' ||
        fields['approve'] != approve ||
        fields['who'] is! List ||
        _hexEncode(Uint8List.fromList((fields['who'] as List).cast<int>())) !=
            _hexEncode(signerPublicKey) ||
        !roleMatches) {
      throw StateError('内部投票事件与本次提案、签署人、岗位或方向不一致');
    }
    if (actorCidNumber != null) {
      final proposal = await query.fetchProposalMeta(proposalId);
      if (proposal?.actorCidNumber != actorCidNumber) {
        throw StateError('执行块提案所属机构与投票票据不一致');
      }
    }
  }

  static Uint8List _encodeCompact(int value) {
    if (value < 0 || value >= 1 << 14) {
      throw ArgumentError('岗位码长度超出 SCALE Compact 两字节范围');
    }
    if (value < 1 << 6) return Uint8List.fromList([value << 2]);
    final encoded = (value << 2) | 1;
    return Uint8List.fromList([encoded & 0xff, encoded >> 8]);
  }

  // ──── 内部：编码工具 ────

  static Uint8List _u64ToLeBytes(int value) {
    if (value < 0) throw ArgumentError('proposal_id不得为负');
    final bytes = Uint8List(8);
    final bd = ByteData.sublistView(bytes);
    bd.setUint64(0, value, Endian.little);
    return bytes;
  }

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
