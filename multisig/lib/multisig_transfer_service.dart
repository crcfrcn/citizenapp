
import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_citizen/institution/institution_models.dart'
    as institution_models;
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_personal/personal_manage_models.dart';
import 'package:citizen_personal/personal_manage_service.dart';

import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_cache.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/proposal/proposal_query_service.dart';
import 'package:citizen_multisig/multisig_transfer_cache.dart';
import 'package:citizen_multisig/multisig_transfer_models.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';

/// 固定治理机构资金业务的默认岗位码；普通机构必须由任职人明确填写动态岗位码。
String defaultInstitutionProposerRoleCode(InstitutionInfo institution) {
  switch (institution.orgType) {
    case OrgType.nrc:
    case OrgType.prc:
      return 'COMMITTEE_MEMBER';
    case OrgType.prb:
      return 'DIRECTOR';
    default:
      return '';
  }
}

/// 机构转账提案链上交互服务。
///
/// 负责 extrinsic 编码/提交 和 storage 查询。
class MultisigTransferService {
  MultisigTransferService({
    CitizenSdk? chain,
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<List<Uint8List>> Function(
      CitizenBlockRef block,
      Uint8List prefix, {
      Uint8List? startKey,
      int limit,
    })?
    getStorageKeysPaged,
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
       _getStorageRuntimeContext = getStorageRuntimeContext ?? getRuntimeContext ??
           chain?.getRuntimeContext ?? ((block) => throw StateError('未配置getRuntimeContext')),
       _internalVoteQuery = InternalVoteQueryService(
         chain: chain,
         getRuntimeContext: getStorageRuntimeContext ?? getRuntimeContext,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       ),
       _proposalQuery = ProposalQueryService(
         chain: chain,
         getSystemEvents: getSystemEvents,
         getRuntimeContext: getRuntimeContext,
         getStorageRuntimeContext: getStorageRuntimeContext,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       ),
       _runtimeService = RuntimeUpgradeService(
         chain: chain,
         transactions: transactions,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
         getSystemEvents: getSystemEvents,
         getRuntimeContext: getRuntimeContext,
         getStorageRuntimeContext: getStorageRuntimeContext,
         prepareTransaction: prepareTransaction,
         executePreparedTransaction: executePreparedTransaction,
         cancelPreparedTransactionExecution: cancelPreparedTransactionExecution,
         consumePreparedTransactionQrResponse:
             consumePreparedTransactionQrResponse,
       ),
       _personalService = PersonalManageService(
         chain: chain,
         getRuntimeContext: getStorageRuntimeContext ?? getRuntimeContext,
         transactions: transactions,
         getSystemEvents: getSystemEvents,
         getFinalizedHead: getFinalizedHead,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
         prepareTransaction: prepareTransaction,
         executePreparedTransaction: executePreparedTransaction,
         cancelPreparedTransactionExecution: cancelPreparedTransactionExecution,
         consumePreparedTransactionQrResponse:
             consumePreparedTransactionQrResponse,
       ),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorageKeysPaged =
           getStorageKeysPaged ??
           chain?.getStorageKeysPaged ??
           ((
             CitizenBlockRef block,
             Uint8List prefix, {
             Uint8List? startKey,
             int limit = 1000,
           }) => throw StateError('未配置getStorageKeysPaged')),
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
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getStorageRuntimeContext;
  final CitizenCallBuilder _buildCall;
  final Future<List<Uint8List>> Function(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit,
  })
  _getStorageKeysPaged;
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

  final RuntimeUpgradeService _runtimeService;
  final PersonalManageService _personalService;

  final InternalVoteQueryService _internalVoteQuery;
  final ProposalQueryService _proposalQuery;

  // ──── 常量 ────

  /// MultisigTransfer pallet index（runtime pallet_index=17）。
  ///
  /// 本 pallet 只保留 propose_X(0/1/2)；机构岗位选民/个人多签管理员投票一律走
  /// 与 runtime `multisig::MODULE_TAG` 唯一对齐的提案数据标签。
  static const _moduleTag = 'multisig';

  // ──── Extrinsic 提交 ────

  /// 提交 propose_transfer extrinsic。
  ///
  /// 返回真实创建出的 proposal_id、交易哈希、nonce 和入块哈希。
  Future<({String txHash, int usedNonce, int proposalId, String blockHash})>
  submitProposeTransfer({
    required InstitutionInfo institution,
    required String? proposerRoleCode,
    required String beneficiaryAddress,
    required BigInt amountFen,
    required String remark,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final actorCidNumber = isPersonalAccountIdentity(institution.cidNumber)
        ? null
        : institution.cidNumber;
    final normalizedRoleCode = actorCidNumber == null
        ? null
        : _requireProposerRoleCode(proposerRoleCode);
    final beneficiaryPublicKey = _ss58AddressToAccountId(
      beneficiaryAddress,
      '收款地址',
    );
    // InstitutionInfo.mainAccountId 是 App 内部 AccountId hex，
    // 不能按 SS58/Base58 解码，否则 hex 中的 0 会被当成非法 Base58 字符。
    final fromPublicKey = _parseAccountId(institution.mainAccountId, '转出主账户');
    final callData = await _buildProposeTransferCall(
      actorCidNumber: actorCidNumber,
      proposerRoleCode: normalizedRoleCode,
      fundingAccountId: institution.mainAccountId,
      beneficiaryAddress: beneficiaryAddress,
      amountFen: amountFen,
      remark: remark,
    );
    final submitResult = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    final proposalId = await _confirmTransferProposedEvent(
      execution: submitResult.execution,
      orgCode: institution.adminCode ?? 'PMUL',
      actorCidNumber: actorCidNumber,
      proposerPublicKey: signerPublicKey,
      fromPublicKey: fromPublicKey,
      beneficiaryPublicKey: beneficiaryPublicKey,
      amountFen: amountFen,
      remark: remark.trim(),
    );
    return (
      txHash: submitResult.txHash,
      usedNonce: submitResult.usedNonce,
      proposalId: proposalId,
      blockHash: submitResult.execution.block.hash,
    );
  }

  /// 提交 propose_safety_fund_transfer extrinsic（安全基金转账提案）。
  ///
  /// 提案创建类交易必须等真正入块并核对事件后才算业务成功
  /// （与 submitProposeTransfer 同标准），返回事件中的 proposal_id
  /// 供后续投票跟踪；submit-only 给不出 proposal_id，也无法区分
  /// "已接受"与"已上链"。
  Future<({String txHash, int usedNonce, int proposalId, String blockHash})>
  submitProposeSafetyFund({
    required InstitutionInfo institution,
    required String proposerRoleCode,
    required String beneficiaryAddress,
    required BigInt amountFen,
    required String remark,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final actorCidNumber = institution.cidNumber;
    final safetyFundAccountId =
        institution.accounts?.safetyFundAccountId ??
        (throw StateError('国家储委会缺少安全基金账户'));
    final safetyFundAccountIdBytes = Uint8List.fromList(
      citizenAccountIdBytes(safetyFundAccountId),
    );
    final beneficiaryPublicKey = _ss58AddressToAccountId(
      beneficiaryAddress,
      '收款地址',
    );
    final callData = await _buildProposeSafetyFundCall(
      actorCidNumber: actorCidNumber,
      proposerRoleCode: _requireProposerRoleCode(proposerRoleCode),
      institutionAccountId: safetyFundAccountId,
      beneficiaryAddress: beneficiaryAddress,
      amountFen: amountFen,
      remark: remark,
    );
    final submitResult = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    final proposalId = await _confirmProposalEvent(
      execution: submitResult.execution,
      eventLabel: 'SafetyFundTransferProposed',
      matches: (event) =>
          utf8.decode(event.fieldBytes('actor_cid_number')) == actorCidNumber &&
          listEquals(event.fieldBytes('institution_account_id'), safetyFundAccountIdBytes) &&
          listEquals(event.fieldBytes('proposer_account_id'), signerPublicKey) &&
          listEquals(event.fieldBytes('beneficiary_account_id'), beneficiaryPublicKey) &&
          event.fieldUnsigned('amount') == amountFen &&
          utf8.decode(event.fieldBytes('remark')) == remark.trim(),
    );
    return (
      txHash: submitResult.txHash,
      usedNonce: submitResult.usedNonce,
      proposalId: proposalId,
      blockHash: submitResult.execution.block.hash,
    );
  }

  /// 提交 propose_sweep_to_main extrinsic（手续费划转提案）。
  ///
  /// 同 submitProposeSafetyFund，提案类必须入块+核对事件。
  Future<({String txHash, int usedNonce, int proposalId, String blockHash})>
  submitProposeSweep({
    required InstitutionInfo institution,
    required String proposerRoleCode,
    required BigInt amountFen,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final feeAccountId =
        institution.accounts?.feeAccountId ?? (throw StateError('机构缺少费用账户'));
    final institutionAccountId = Uint8List.fromList(
      citizenAccountIdBytes(feeAccountId),
    );
    final toPublicKey = _parseAccountId(institution.mainAccountId, '机构主账户');
    final callData = await _buildProposeSweepCall(
      actorCidNumber: institution.cidNumber,
      proposerRoleCode: _requireProposerRoleCode(proposerRoleCode),
      institutionAccountId: feeAccountId,
      amountFen: amountFen,
    );
    final submitResult = await _executeFinalized(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    final proposalId = await _confirmProposalEvent(
      execution: submitResult.execution,
      eventLabel: 'SweepToMainProposed',
      matches: (event) =>
          utf8.decode(event.fieldBytes('actor_cid_number')) == institution.cidNumber &&
          listEquals(event.fieldBytes('institution_account_id'), institutionAccountId) &&
          listEquals(event.fieldBytes('proposer_account_id'), signerPublicKey) &&
          listEquals(event.fieldBytes('main_account'), toPublicKey) &&
          event.fieldUnsigned('amount') == amountFen,
    );
    return (
      txHash: submitResult.txHash,
      usedNonce: submitResult.usedNonce,
      proposalId: proposalId,
      blockHash: submitResult.execution.block.hash,
    );
  }

  // ──── 链上查询 ────

  // ──── 双层 ID 与反向索引 ────

  /// 查询提案展示号:`ProposalDisplayId[proposal_id] = ProposalDisplayMeta { year, seq_in_year }`。
  ///
  /// 返回 null 表示链上不存在该展示号(理论上不应该发生 — 创建提案时
  /// 同事务一定写入)。
  Future<ProposalDisplayMeta?> fetchProposalDisplayId(int proposalId) async {
    final data = await _fetchStorage('VotingEngine', 'ProposalDisplayId', [proposalId]);
    if (data == null || data.length != 6) return null;
    // SCALE: u16 LE (year) + u32 LE (seq_in_year) = 6 bytes
    return ProposalDisplayMeta(
      year: CitizenScale.readUnsigned(data, 0, 2).toInt(),
      seqInYear: CitizenScale.readUnsigned(data, 2, 4).toInt(),
    );
  }

  /// 批量查询展示号(列表页一次性 batch fetch,避免 N 次 RPC)。
  Future<Map<int, ProposalDisplayMeta>> fetchProposalDisplayIdBatch(
    List<int> proposalIds, {
    CitizenRuntimeContext? atRuntime,
  }) async {
    if (proposalIds.isEmpty) return const {};
    final runtime = atRuntime ?? await _finalizedRuntime();
    final keyHexList = proposalIds
        .map(
          (id) =>
              '0x${_hexEncode(runtime.storageKey('VotingEngine', 'ProposalDisplayId', [id]))}',
        )
        .toList();
    final batchResult = await _fetchStorageBatch(runtime.block, keyHexList);
    final result = <int, ProposalDisplayMeta>{};
    for (var i = 0; i < proposalIds.length; i++) {
      final data = batchResult[keyHexList[i]];
      if (data == null || data.length != 6) continue;
      result[proposalIds[i]] = ProposalDisplayMeta(
        year: CitizenScale.readUnsigned(data, 0, 2).toInt(),
        seqInYear: CitizenScale.readUnsigned(data, 2, 4).toInt(),
      );
    }
    return result;
  }

  // 提案查询统一走按年取 + 客户端过滤:code 过滤(filterGovernanceIds)、
  // CID 过滤(filterInstitutionVisible)。链端归属真源是 Proposal.subject_cid_numbers,
  // `ProposalsByYear` 是全量短 key 入口,列表页只从已解码 CID 集合筛选。

  /// 按当前 metadata 生成按年索引前缀，并从完整键尾部读取提案编号。
  Future<List<int>> _fetchProposalIdsByYear(CitizenRuntimeContext runtime, int year) async {
    final prefix = runtime.storageKey('VotingEngine', 'ProposalsByYear', [year]);
    final keys = await _getStorageKeysPaged(runtime.block, prefix);
    if (keys.isEmpty) return const [];

    // 每条 key 末 8 字节 = proposal_id u64 LE(twox64_concat 的 raw 部分)
    final ids = <int>[];
    for (final keyBytes in keys) {
      if (keyBytes.length < 8) continue;
      final tail = keyBytes.sublist(keyBytes.length - 8);
      ids.add(_decodeU64(tail));
    }
    return ids;
  }

  /// 查询主体活跃提案；机构按 CID，个人多签按 AccountId。
  Future<List<int>> fetchActiveProposalIds(InstitutionInfo institution) {
    return _proposalQuery.fetchActiveProposalIds(institution);
  }

  /// 查询投票计数。
  Future<({int yes, int no})> fetchVoteTally(int proposalId) {
    return _proposalQuery.fetchVoteTally(proposalId);
  }

  /// 查询内部投票阈值快照。
  ///
  /// 个人多签创建提案的创建阈值是提案级快照，
  /// 不能使用 InstitutionInfo.internalThreshold 的多签默认值。
  Future<int?> fetchInternalThresholdSnapshot(int proposalId) {
    return _proposalQuery.fetchInternalThresholdSnapshot(proposalId);
  }

  /// 查询提案创建时锁定的实际投票账户快照。
  ///
  /// 机构按岗位有效任职快照，个人多签按管理员快照；详情页展示和
  /// 可投钱包筛选必须使用同一份创建时快照。
  Future<List<EligibleVoterTicket>> fetchEligibleVoterTickets(
    int proposalId,
    InstitutionInfo institution,
  ) {
    return _proposalQuery.fetchEligibleVoterTickets(proposalId, institution);
  }

  /// 查询提案状态。返回 status（0=voting, 1=passed, 2=rejected），null 表示不存在。
  Future<int?> fetchProposalStatus(int proposalId) {
    return _proposalQuery.fetchProposalStatus(proposalId);
  }

  /// 查询提案完整元数据（actor CID + execution account + subject CIDs）。
  /// 返回 null 表示提案不存在。
  Future<ProposalMeta?> fetchProposalMeta(int proposalId) async {
    final decoded = await _proposalQuery.fetchProposalMeta(proposalId);
    if (decoded == null) return null;

    // 双层 ID：同时查 ProposalDisplayId 反查表（失败不阻塞，fallback null）。
    ProposalDisplayMeta? displayMeta;
    try {
      displayMeta = await fetchProposalDisplayId(proposalId);
    } catch (e) {
      // 展示号缺失不阻断主流程，但必须留痕，否则 RPC 故障会伪装成"无展示号"。
      AppLog.d('[MultisigTransfer] fetchProposalDisplayId($proposalId) 失败: $e');
    }

    return ProposalMeta(
      proposalId: proposalId,
      kind: decoded.kind,
      stage: decoded.stage,
      status: decoded.status,
      internalCode: decoded.internalCode,
      actorCidNumber: decoded.actorCidNumber,
      executionAccountId: decoded.executionAccountId,
      subjectCidNumbers: decoded.subjectCidNumbers,
      displayMeta: displayMeta,
    );
  }

  // ──── 分页 + 缓存 + 批量查询 ────

  /// 给定一组 proposal_id,batch 查 meta + 业务详情 + 展示号,
  /// 返回 `ProposalWithDetail` 列表(顺序按 ids 入参,不重排)。
  ///
  /// 双层 ID 模式下,客户端先通过反向索引拿 ID 列表,再调本方法取详情。
  /// 多签管理提案(ACTION_CREATE_PERSONAL / ACTION_CLOSE)按既有规则过滤掉。
  Future<List<ProposalWithDetail>> fetchProposalsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    return _fetchProposalsForIds(ids);
  }

  /// 分页查询提案:从 [startId] 往前(含 startId)加载 [count] 个。
  ///
  /// 优先读缓存,未命中的用 [fetchStorageBatch] 批量查询。
  /// 返回结果按 ID 倒序。
  Future<List<ProposalWithDetail>> fetchProposalPage(
    int startId,
    int count,
  ) async {
    // 把范围转成显式 ids 列表,然后委派给 _fetchProposalsForIds。
    final ids = <int>[
      for (var id = startId; id > startId - count && id >= 0; id--) id,
    ];
    return _fetchProposalsForIds(ids);
  }

  /// 给定 [ids] 一组提案 ID,batch 拉 meta + 业务详情 + 展示号,
  /// 返回 `ProposalWithDetail` 列表,**顺序与入参一致**。
  /// 多签管理类提案(ACTION_CREATE_PERSONAL / ACTION_CLOSE)在装配阶段过滤掉。
  Future<List<ProposalWithDetail>> _fetchProposalsForIds(
    List<int> ids, {
    CitizenRuntimeContext? runtime,
  }) async {
    final results = <ProposalWithDetail>[];
    final uncachedMetaKeys = <String>[];
    final uncachedMetaIds = <int>[];
    final cachedMetas = <int, ProposalMeta>{};
    final runtimeUpgradeService = _runtimeService;

    for (final id in ids) {
      final cached = ProposalCache.getMeta(id);
      if (cached != null) {
        cachedMetas[id] = cached;
      } else {
        final context = runtime ??= await _finalizedRuntime();
        final keyBytes = context.storageKey('VotingEngine', 'Proposals', [id]);
        uncachedMetaKeys.add('0x${_hexEncode(keyBytes)}');
        uncachedMetaIds.add(id);
      }
    }

    // 批量查询未命中的 meta
    if (uncachedMetaKeys.isNotEmpty) {
      final batchResult = await _fetchStorageBatch(runtime!.block, uncachedMetaKeys);
      for (var i = 0; i < uncachedMetaIds.length; i++) {
        final id = uncachedMetaIds[i];
        final data = batchResult[uncachedMetaKeys[i]];
        if (data != null) {
          final meta = _decodeProposalMeta(id, data);
          if (meta != null) {
            cachedMetas[id] = meta;
            ProposalCache.putMeta(id, meta);
          }
        }
      }
      // 双层 ID：为这一批 meta 同步批量读取 ProposalDisplayId 并回填。
      final displayMap = await fetchProposalDisplayIdBatch(uncachedMetaIds, atRuntime: runtime);
      for (final id in uncachedMetaIds) {
        final meta = cachedMetas[id];
        final dm = displayMap[id];
        if (meta != null && dm != null) {
          final patched = ProposalMeta(
            proposalId: meta.proposalId,
            kind: meta.kind,
            stage: meta.stage,
            status: meta.status,
            internalCode: meta.internalCode,
            actorCidNumber: meta.actorCidNumber,
            executionAccountId: meta.executionAccountId,
            subjectCidNumbers: meta.subjectCidNumbers,
            displayMeta: dm,
          );
          cachedMetas[id] = patched;
          ProposalCache.putMeta(id, patched);
        }
      }
    }

    // 对有 meta 的提案，批量查询 ProposalData（先查缓存）。
    // 联合投票提案不能再走“统一按转账解码”的旧逻辑，
    // 否则 runtime 升级这类提案会被漏掉或误判类型。
    final uncachedDetailKeys = <String>[];
    final uncachedDetailIds = <int>[];
    final cachedTransferDetails = <int, TransferProposalInfo>{};
    final cachedRuntimeUpgradeDetails = <int, RuntimeUpgradeProposalInfo>{};
    final cachedCreateMultisigDetails = <int, CreateProposalInfo>{};
    final cachedCloseMultisigDetails = <int, CloseProposalInfo>{};
    final institutionCloseIds = <int>{};

    for (final entry in cachedMetas.entries) {
      final meta = entry.value;
      if (meta.kind == 1) {
        final cachedDetail = ProposalCache.getRuntimeUpgradeDetail(entry.key);
        if (cachedDetail != null) {
          cachedRuntimeUpgradeDetails[entry.key] = cachedDetail;
          continue;
        }
      } else {
        // 内部投票提案：先查转账缓存，再查管理缓存
        final cachedTransfer = MultisigTransferCache.getTransferDetail(
          entry.key,
        );
        if (cachedTransfer != null) {
          cachedTransferDetails[entry.key] = cachedTransfer;
          continue;
        }
        final cachedCreate = ProposalCache.getCreateMultisigDetail(entry.key);
        if (cachedCreate != null) {
          cachedCreateMultisigDetails[entry.key] = cachedCreate;
          continue;
        }
        final cachedClose = ProposalCache.getCloseMultisigDetail(entry.key);
        if (cachedClose != null) {
          cachedCloseMultisigDetails[entry.key] = cachedClose;
          continue;
        }
      }
      final context = runtime ??= await _finalizedRuntime();
      final keyBytes = context.storageKey('VotingEngine', 'ProposalData', [entry.key]);
      uncachedDetailKeys.add('0x${_hexEncode(keyBytes)}');
      uncachedDetailIds.add(entry.key);
    }

    if (uncachedDetailKeys.isNotEmpty) {
      final manageService = InstitutionChainService();
      final personalManageService = _personalService;
      final batchResult = await _fetchStorageBatch(runtime!.block, uncachedDetailKeys);
      for (var i = 0; i < uncachedDetailIds.length; i++) {
        final id = uncachedDetailIds[i];
        final meta = cachedMetas[id];
        final raw = batchResult[uncachedDetailKeys[i]];
        if (meta == null || raw == null || raw.isEmpty) {
          continue;
        }
        if (meta.kind == 1) {
          final runtimeDetail = runtimeUpgradeService
              .decodeRuntimeUpgradeStorageValue(id, raw);
          if (runtimeDetail != null) {
            cachedRuntimeUpgradeDetails[id] = runtimeDetail;
            ProposalCache.putRuntimeUpgradeDetail(id, runtimeDetail);
          }
          continue;
        }

        // 内部投票提案：先按 PersonalAdmins 解码，再按机构管理(公权/私权)解码，
        // 失败后才尝试普通多签转账提案。
        final personalDetail = personalManageService.decodePersonalProposalData(
          id,
          raw,
        );
        if (personalDetail is CreateProposalInfo) {
          cachedCreateMultisigDetails[id] = personalDetail;
          ProposalCache.putCreateMultisigDetail(id, personalDetail);
          continue;
        }
        if (personalDetail is CloseProposalInfo) {
          cachedCloseMultisigDetails[id] = personalDetail;
          ProposalCache.putCloseMultisigDetail(id, personalDetail);
          continue;
        }
        final orgManageDetail = manageService.decodeManageProposalData(id, raw);
        if (orgManageDetail is institution_models.CloseProposalInfo) {
          // 机构关闭与个人多签关闭是两种不同协议主体；
          // 只在当前查询中标记跳过，不得转换或写入个人多签缓存。
          institutionCloseIds.add(id);
          continue;
        }

        final transferDetail = _decodeProposalData(id, raw);
        if (transferDetail != null) {
          cachedTransferDetails[id] = transferDetail;
          MultisigTransferCache.putTransferDetail(id, transferDetail);
        }
      }
    }

    // 组装结果(跳过多签管理提案,这些在多签账户详情页单独展示)
    for (final id in ids) {
      final meta = cachedMetas[id];
      if (meta == null) continue;
      // 多签管理提案不在治理列表中显示
      if (cachedCreateMultisigDetails.containsKey(id) ||
          cachedCloseMultisigDetails.containsKey(id) ||
          institutionCloseIds.contains(id)) {
        continue;
      }
      final transferDetail = cachedTransferDetails[id];
      final runtimeUpgradeDetail = cachedRuntimeUpgradeDetails[id];
      final createMultisigDetail = cachedCreateMultisigDetails[id];
      final closeMultisigDetail = cachedCloseMultisigDetails[id];
      // 如果都没匹配到，尝试安全基金 / 手续费划转提案。
      SafetyFundProposalInfo? safetyFundDetail;
      SweepProposalInfo? sweepDetail;
      if (transferDetail == null &&
          runtimeUpgradeDetail == null &&
          createMultisigDetail == null &&
          closeMultisigDetail == null &&
          meta.kind == 0) {
        try {
          safetyFundDetail = await fetchSafetyFundAction(id);
        } catch (e) {
          // 查询失败必须留痕，否则与"确实不是安全基金提案"无法区分。
          AppLog.d('[MultisigTransfer] fetchSafetyFundAction($id) 失败: $e');
        }
        if (safetyFundDetail == null) {
          try {
            sweepDetail = await fetchSweepAction(id);
          } catch (e) {
            AppLog.d('[MultisigTransfer] fetchSweepAction($id) 失败: $e');
          }
        }
      }
      // 联合提案且不是 runtime 升级，尝试检测决议发行/销毁
      String? resIssuanceSummary;
      String? resDestroySummary;
      if (meta.kind == 1 && runtimeUpgradeDetail == null) {
        try {
          final raw = await fetchProposalDataRaw(id);
          if (raw != null) {
            final tag = _detectJointProposalTag(raw);
            if (tag == 'res-iss') {
              resIssuanceSummary = '决议发行提案';
            } else if (tag == 'res-dst') {
              resDestroySummary = '决议销毁提案';
            }
          }
        } catch (e) {
          AppLog.d('[MultisigTransfer] 联合提案类型检测($id) 失败: $e');
        }
      }
      results.add(
        ProposalWithDetail(
          meta: meta,
          runtimeUpgradeDetail: runtimeUpgradeDetail,
          createMultisigDetail: createMultisigDetail?.copyWithStatus(
            meta.status,
          ),
          closeMultisigDetail: closeMultisigDetail?.copyWithStatus(meta.status),
          businessDetails: {
            if (transferDetail != null)
              MultisigTransferProposalDetailKeys.transfer: transferDetail
                  .copyWithStatus(meta.status),
            MultisigTransferProposalDetailKeys.safetyFund: ?safetyFundDetail,
            MultisigTransferProposalDetailKeys.sweep: ?sweepDetail,
          },
          resolutionIssuanceSummary: resIssuanceSummary,
          resolutionDestroySummary: resDestroySummary,
        ),
      );
    }

    return results;
  }

  /// ADR-018 统一提案查询:按年取当前年全部提案一次。
  ///
  /// `ProposalsByYear[year]` 是短 key 索引,轻节点可正常前缀扫描;
  /// 链端对每个提案无条件写入该索引、终态清理时移除,所以按年取得到的就是
  /// "全部存活提案"。公民-提案 / 机构详情 / 个人多签统一从这一份结果客户端按
  /// 已解码 `subject_cid_numbers` 过滤,替代旧的账户归属过滤。
  /// 长前缀扫描,并让多页面共用一次查询(见 ProposalFeedCache,降全节点负载)。
  Future<List<ProposalWithDetail>> fetchCurrentYearProposals() async {
    // 仅标记原读取失败边界，不记年份/索引内容，不把失败改成空列表。
    var stage = 'proposal_year';
    try {
      final runtime = await _finalizedRuntime();
      final currentYear = await _resolveCurrentYear(runtime);
      if (currentYear == null) return const [];
      stage = 'proposal_index';
      final ids = await _fetchProposalIdsByYear(runtime, currentYear);
      stage = 'proposal_details';
      return await _fetchProposalsForIds(ids, runtime: runtime);
    } on Object catch (error) {
      AppLog.proposalFailure(stage: stage, error: error);
      rethrow;
    }
  }

  /// 从当前年提案全集过滤出指定机构页可见的提案(纯客户端,不联网):
  /// 本机构关联提案(`subject_cid_numbers` 包含机构 CID)。
  List<ProposalWithDetail> filterInstitutionVisible(
    List<ProposalWithDetail> all,
    InstitutionInfo institution,
  ) {
    final cidNumber = institution.cidNumber;
    final visible = all.where((p) {
      return p.meta.subjectCidNumbers.contains(cidNumber);
    }).toList();
    visible.sort((a, b) => b.meta.proposalId.compareTo(a.meta.proposalId));
    return visible;
  }

  /// 从当前年提案全集过滤出指定治理类型(机构码)的提案 id(广场用,纯客户端)。
  List<int> filterGovernanceIds(
    List<ProposalWithDetail> all,
    Set<String> codes,
  ) {
    final ids = all
        .where(
          (p) =>
              p.meta.internalCode != null &&
              codes.contains(p.meta.internalCode),
        )
        .map((p) => p.meta.proposalId)
        .toList();
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  /// 公民 tab「提案」统一流:默认公共机构码 ∪ 当前钱包订阅机构 CID。
  ///
  /// 默认范围按机构码命中(如 NRC/NLG/PRS),订阅范围必须按机构
  /// CID 精确命中,不能按机构码放大,否则会把同类所有省/市机构全部塞进用户提案流。
  List<int> filterCitizenProposalFeedIds(
    List<ProposalWithDetail> all, {
    required Set<String> defaultCodes,
    required Set<String> subscribedInstitutionCidNumbers,
  }) {
    final normalizedDefaultCodes = defaultCodes
        .map((code) => code.toUpperCase())
        .toSet();
    final normalizedSubscribedCidNumbers = subscribedInstitutionCidNumbers
        .map((cid) => cid.trim())
        .where((cid) => cid.isNotEmpty)
        .toSet();
    final ids = all
        .where((p) {
          final code = p.meta.internalCode?.toUpperCase();
          if (code != null && normalizedDefaultCodes.contains(code)) {
            return true;
          }
          return p.meta.subjectCidNumbers.any(
            normalizedSubscribedCidNumbers.contains,
          );
        })
        .map((p) => p.meta.proposalId)
        .toSet()
        .toList();
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  /// 查询对指定机构用户可见的提案事件(ADR-018:按年取 + 客户端过滤)。
  Future<List<ProposalWithDetail>> fetchInstitutionVisibleProposals(
    InstitutionInfo institution,
  ) async {
    final all = await fetchCurrentYearProposals();
    return filterInstitutionVisible(all, institution);
  }

  /// 从 `CurrentProposalYear` 拿当前提案分配年份(用于反向索引按年迭代)。
  Future<int?> _resolveCurrentYear(CitizenRuntimeContext runtime) async {
    final key = runtime.storageKey('VotingEngine', 'CurrentProposalYear');
    final data = await _getStorage(runtime.block, key);
    if (data == null || data.length < 2) return null;
    return CitizenScale.readUnsigned(data, 0, 2).toInt();
  }

  /// 查询指定机构的所有转账提案（包括已完成的），按 ID 倒序。
  Future<List<TransferProposalInfo>> fetchAllInstitutionProposals(
    InstitutionInfo institution,
  ) async {
    final visibleProposals = await fetchInstitutionVisibleProposals(
      institution,
    );
    final proposals = <TransferProposalInfo>[];

    for (final proposal in visibleProposals) {
      final detailObject =
          proposal.businessDetails[MultisigTransferProposalDetailKeys.transfer];
      if (detailObject is! TransferProposalInfo) {
        continue;
      }
      if (detailObject.actorCidNumber == institution.cidNumber) {
        proposals.add(detailObject.copyWithStatus(proposal.meta.status));
      }
    }

    proposals.sort((a, b) => b.proposalId.compareTo(a.proposalId));
    return proposals;
  }

  /// 从原始 SCALE 字节解码 ProposalMeta（与 fetchProposalMeta 相同逻辑）。
  ProposalMeta? _decodeProposalMeta(int proposalId, Uint8List data) {
    return ProposalQueryService.decodeProposalMeta(proposalId, data);
  }

  /// 读取原始 ProposalData 存储字节。
  Future<Uint8List?> fetchProposalDataRaw(int proposalId) async {
    return _proposalQuery.fetchProposalData(proposalId);
  }

  /// 检测联合提案 ProposalData 的 MODULE_TAG 前缀。
  /// 返回 'rt-upg'、'res-iss'、'res-dst' 或 null。
  static String? _detectJointProposalTag(Uint8List raw) {
    if (raw.length < 2) return null;
    // BoundedVec<u8>：Compact<len> + bytes
    final int offset;
    try {
      final (_, width) = CitizenScale.readCompact(raw, 0);
      if (width > 4) return null;
      offset = width;
    } on FormatException {
      return null;
    }
    if (offset + 7 > raw.length) return null;
    final tag = String.fromCharCodes(raw.sublist(offset, offset + 7));
    if (tag == 'res-iss') return 'res-iss';
    if (tag == 'res-dst') return 'res-dst';
    if (offset + 6 <= raw.length) {
      final tag6 = String.fromCharCodes(raw.sublist(offset, offset + 6));
      if (tag6 == 'rt-upg') return 'rt-upg';
    }
    return null;
  }

  /// 测试入口：暴露批量解码路径（_decodeProposalData），用链上真实
  /// payload 字节做布局回归，防止"守卫长度与链端布局漂移"导致提案静默消失。
  @visibleForTesting
  TransferProposalInfo? debugDecodeProposalData(int proposalId, Uint8List raw) {
    return _decodeProposalData(proposalId, raw);
  }

  /// 测试入口：锁定 VotingEngine::Proposal 当前完整 SCALE 布局。
  @visibleForTesting
  ProposalMeta? debugDecodeProposalMeta(int proposalId, Uint8List raw) {
    return _decodeProposalMeta(proposalId, raw);
  }

  /// 从原始 SCALE 字节解码 ProposalData（`BoundedVec<u8>` → TransferAction）。
  TransferProposalInfo? _decodeProposalData(int proposalId, Uint8List raw) {
    try {
      int offset = 0;
      final (vecLen, lenBytes) = _decodeCompact(raw, offset);
      offset += lenBytes;
      // storage value 必须恰好是一段完整 BoundedVec，拒绝截断或尾随脏字节。
      if (offset + vecLen != raw.length) return null;
      final data = raw.sublist(offset, offset + vecLen);
      // 跳过 MODULE_TAG 前缀。
      final tag = _moduleTag.codeUnits;
      // 个人多签最小长度 = tag + actor Option(1) + funding account(32)
      // + beneficiary(32) + amount(16) + empty remark Compact(1) + proposer(32)。
      // 机构转账还必须在 actor Option 后携带 CID 的 Compact 长度和正文。
      if (data.length < tag.length + 1 + 32 + 32 + 16 + 1 + 32) {
        return null;
      }
      for (var i = 0; i < tag.length; i++) {
        if (data[i] != tag[i]) return null;
      }
      return _decodeTransferAction(proposalId, data.sublist(tag.length));
    } catch (e) {
      // SCALE 解码失败必须留痕：runtime 升级布局变更时提案会"凭空消失"，
      // 没有日志就无从排查。
      AppLog.d('[MultisigTransfer] 提案 $proposalId ProposalData 解码失败: $e');
      return null;
    }
  }

  /// 查询某快照选民对提案的投票记录。null=未投票，true=赞成，false=反对。
  Future<bool?> fetchAdminVote(int proposalId, String publicKey) async {
    return _internalVoteQuery.fetchAdminVote(proposalId, publicKey);
  }

  /// 批量查询某提案下多名快照选民的投票记录。
  ///
  /// 转账/多签管理详情页展示全部合格选民投票时走批量读取，
  /// 避免逐个产生 storage RPC。
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    int proposalId,
    Iterable<String> publicKeysHex,
  ) {
    return _internalVoteQuery.fetchAdminVotesBatch(proposalId, publicKeysHex);
  }

  Future<Map<String, bool?>> fetchTicketVotesBatch(
    int proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) {
    return _internalVoteQuery.fetchTicketVotesBatch(proposalId, tickets);
  }

  /// 查询 NextProposalId（投票引擎全局递增 ID）。
  Future<int> fetchNextProposalId() {
    return _proposalQuery.fetchNextProposalId();
  }

  /// 查询单个转账提案详情。返回 null 表示不存在。
  ///
  /// ProposalData 是 `BoundedVec<u8>`，SCALE 编码为 Compact 长度前缀 + 原始字节。
  /// 原始字节为 TransferAction SCALE 布局：
  ///   `actor_cid_number:Option<CidNumber> + funding_account_id:AccountId32`
  ///   + beneficiary: AccountId32(32) + amount: u128(16)
  ///   + `remark: Vec<u8>`(Compact len + bytes) + proposer: AccountId32(32)
  Future<TransferProposalInfo?> fetchProposalAction(int proposalId) async {
    final raw = await _fetchStorage('VotingEngine', 'ProposalData', [proposalId]);
    if (raw == null || raw.isEmpty) return null;
    // 单笔与批量读取统一消费同一严格解码入口，禁止标签或布局双轨漂移。
    return _decodeProposalData(proposalId, raw);
  }

  /// 解码 TransferAction SCALE 数据。
  TransferProposalInfo? _decodeTransferAction(int proposalId, Uint8List data) {
    try {
      var offset = 0;
      if (data.isEmpty) return null;

      String? actorCidNumber;
      final actorOption = data[offset++];
      if (actorOption == 1) {
        final actorCid = _readCidNumber(data, offset);
        if (actorCid == null) return null;
        actorCidNumber = actorCid.$1;
        offset = actorCid.$2;
      } else if (actorOption != 0) {
        return null;
      }

      // funding_account_id: AccountId32
      if (offset + 32 > data.length) return null;
      final institutionAccountId = data.sublist(offset, offset + 32);
      offset += 32;

      // beneficiary: AccountId32 (32 bytes)
      if (offset + 32 > data.length) return null;
      final beneficiaryBytes = data.sublist(offset, offset + 32);
      offset += 32;

      // amount: u128 little-endian (16 bytes)
      if (offset + 16 > data.length) return null;
      final amountBig = CitizenScale.readUnsigned(data, offset, 16);
      offset += 16;

      // remark: Vec<u8> (Compact length + bytes)
      final (remarkLen, remarkLenSize) = _decodeCompact(data, offset);
      offset += remarkLenSize;
      // remark 后必须只剩固定 32 字节 proposer，拒绝截断和尾随字段。
      if (offset + remarkLen + 32 != data.length) return null;
      final remarkBytes = data.sublist(offset, offset + remarkLen);
      final remark = utf8.decode(remarkBytes, allowMalformed: true);
      offset += remarkLen;

      // proposer: AccountId32 (32 bytes)
      final proposerBytes = data.sublist(offset, offset + 32);

      final beneficiarySs58 = citizenSs58FromAccountIdBytes(beneficiaryBytes);
      final proposerSs58 = citizenSs58FromAccountIdBytes(proposerBytes);

      return TransferProposalInfo(
        proposalId: proposalId,
        actorCidNumber: actorCidNumber,
        institutionAccountId: Uint8List.fromList(institutionAccountId),
        beneficiary: beneficiarySs58,
        amountFen: amountBig,
        remark: remark,
        proposer: proposerSs58,
      );
    } catch (e) {
      // 字段级解码失败同样要留痕，与上层"提案不存在"区分开。
      AppLog.d('[MultisigTransfer] 提案 $proposalId TransferAction 解码失败: $e');
      return null;
    }
  }

  /// 解码 SCALE `Compact<u32>`，返回 (value, bytesConsumed)。
  (int, int) _decodeCompact(Uint8List data, int offset) =>
      CitizenScale.readCompact(data, offset);

  (String, int)? _readCidNumber(Uint8List data, int offset) {
    if (offset >= data.length) return null;
    final (length, compactSize) = _decodeCompact(data, offset);
    final start = offset + compactSize;
    final end = start + length;
    if (length <= 0 || length > 32 || end > data.length) return null;
    try {
      return (
        utf8.decode(data.sublist(start, end), allowMalformed: false),
        end,
      );
    } catch (_) {
      return null;
    }
  }

  // ──── 内部：extrinsic 编码 ────

  /// 构造 propose_transfer call data。
  ///
  /// 格式：`[0x11][0x00][actor_cid_number:Option<CidNumber>]`
  /// `[proposer_role_code:Option<RoleCode>][funding_account_id:AccountId32]`
  /// `[beneficiary:AccountId32][amount:u128][remark:Vec<u8>]`。
  Future<Uint8List> _buildProposeTransferCall({
    required String? actorCidNumber,
    required String? proposerRoleCode,
    required String fundingAccountId,
    required String beneficiaryAddress,
    required BigInt amountFen,
    required String remark,
  }) {
    if (actorCidNumber == null && proposerRoleCode != null) {
      throw StateError('个人多签不得携带机构岗位码');
    }
    return _buildCall('MultisigTransfer', 'propose_transfer', [
      _optionalBytes(actorCidNumber == null ? null : _cidBytes(actorCidNumber)),
      _optionalBytes(actorCidNumber == null ? null : _roleBytes(proposerRoleCode)),
      citizenAccountIdBytes(fundingAccountId),
      _ss58AddressToAccountId(beneficiaryAddress, '收款地址'),
      _amount(amountFen),
      Uint8List.fromList(utf8.encode(remark)),
    ]);
  }

  Future<Uint8List> _buildProposeSweepCall({
    required String actorCidNumber,
    required String proposerRoleCode,
    required String institutionAccountId,
    required BigInt amountFen,
  }) => _buildCall('MultisigTransfer', 'propose_sweep_to_main', [
    _cidBytes(actorCidNumber),
    _roleBytes(proposerRoleCode),
    citizenAccountIdBytes(institutionAccountId),
    _amount(amountFen),
  ]);

  Future<Uint8List> _buildProposeSafetyFundCall({
    required String actorCidNumber,
    required String proposerRoleCode,
    required String institutionAccountId,
    required String beneficiaryAddress,
    required BigInt amountFen,
    required String remark,
  }) => _buildCall('MultisigTransfer', 'propose_safety_fund_transfer', [
    _cidBytes(actorCidNumber),
    _roleBytes(proposerRoleCode),
    citizenAccountIdBytes(institutionAccountId),
    _ss58AddressToAccountId(beneficiaryAddress, '收款地址'),
    _amount(amountFen),
    Uint8List.fromList(utf8.encode(remark)),
  ]);

  CitizenScaleVariant _optionalBytes(Uint8List? bytes) => bytes == null
      ? (variant: 'None', fields: const [])
      : (variant: 'Some', fields: [bytes]);

  /// 从链上 SafetyFundProposalActions 存储查询安全基金转账提案详情。
  Future<SafetyFundProposalInfo?> fetchSafetyFundAction(int proposalId) async {
    final raw = await _fetchStorage('MultisigTransfer', 'SafetyFundProposalActions', [proposalId]);
    // SafetyFundAction: actor CID + institution_account_id + beneficiary + amount + remark + proposer。
    if (raw == null || raw.length < 1 + 32 + 32 + 16 + 1 + 32) {
      return null;
    }
    try {
      var offset = 0;
      final actorCid = _readCidNumber(raw, offset);
      if (actorCid == null) return null;
      offset = actorCid.$2;
      final institutionAccountId = Uint8List.fromList(
        raw.sublist(offset, offset + 32),
      );
      offset += 32;
      final beneficiaryBytes = raw.sublist(offset, offset + 32);
      offset += 32;
      final amountBig = CitizenScale.readUnsigned(raw, offset, 16);
      offset += 16;
      final (remarkLen, remarkLenSize) = _decodeCompact(raw, offset);
      offset += remarkLenSize;
      if (offset + remarkLen + 32 != raw.length) return null;
      final remark = utf8.decode(
        raw.sublist(offset, offset + remarkLen),
        allowMalformed: true,
      );
      offset += remarkLen;
      final proposerBytes = raw.sublist(offset, offset + 32);
      return SafetyFundProposalInfo(
        proposalId: proposalId,
        actorCidNumber: actorCid.$1,
        institutionAccountId: institutionAccountId,
        beneficiary: citizenSs58FromAccountIdBytes(beneficiaryBytes),
        amountFen: amountBig,
        remark: remark,
        proposer: citizenSs58FromAccountIdBytes(proposerBytes),
      );
    } catch (e) {
      // SCALE 解码失败必须留痕，与"确实不是安全基金提案"区分开。
      AppLog.d('[MultisigTransfer] 提案 $proposalId SafetyFundAction 解码失败: $e');
      return null;
    }
  }

  /// 从链上 SweepProposalActions 存储查询手续费划转提案详情。
  Future<SweepProposalInfo?> fetchSweepAction(int proposalId) async {
    final raw = await _fetchStorage('MultisigTransfer', 'SweepProposalActions', [proposalId]);
    // SweepAction: actor CID + institution_account_id + amount + proposer。
    if (raw == null || raw.length < 1 + 32 + 16 + 32) return null;
    try {
      final actorCid = _readCidNumber(raw, 0);
      if (actorCid == null) return null;
      final institutionOffset = actorCid.$2;
      if (institutionOffset + 32 + 16 + 32 != raw.length) return null;
      final institutionAccountId = Uint8List.fromList(
        raw.sublist(institutionOffset, institutionOffset + 32),
      );
      final amountBig = CitizenScale.readUnsigned(raw, institutionOffset + 32, 16);
      final proposerOffset = institutionOffset + 32 + 16;
      final proposerBytes = Uint8List.fromList(
        raw.sublist(proposerOffset, proposerOffset + 32),
      );
      return SweepProposalInfo(
        proposalId: proposalId,
        actorCidNumber: actorCid.$1,
        institutionAccountId: institutionAccountId,
        amountFen: amountBig,
        proposer: citizenSs58FromAccountIdBytes(proposerBytes),
      );
    } catch (e) {
      // SCALE 解码失败必须留痕，与"确实不是手续费划转提案"区分开。
      AppLog.d('[MultisigTransfer] 提案 $proposalId SweepAction 解码失败: $e');
      return null;
    }
  }

  Future<CitizenRuntimeContext> _finalizedRuntime() async =>
      _getStorageRuntimeContext(await _getFinalizedHead());

  Future<Uint8List?> _fetchStorage(String pallet, String storage, List<Object> keys) async {
    final runtime = await _finalizedRuntime();
    return _getStorage(runtime.block, runtime.storageKey(pallet, storage, keys));
  }

  Future<Map<String, Uint8List?>> _fetchStorageBatch(
    CitizenBlockRef finalized,
    List<String> keyHexes,
  ) async {
    if (keyHexes.isEmpty) return const <String, Uint8List?>{};
    final values = await _getStorageBatch(
      finalized,
      keyHexes.map(_hexDecode).toList(growable: false),
    );
    return <String, Uint8List?>{
      for (var index = 0; index < keyHexes.length; index++)
        keyHexes[index]: values[index],
    };
  }

  Future<({String txHash, int usedNonce, CitizenExecution execution})>
  _executeFinalized({
    required Uint8List callData,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('多签提案交易签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '多签提案交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
  }

  Future<int> _confirmTransferProposedEvent({
    required CitizenExecution execution,
    required String orgCode,
    required String? actorCidNumber,
    required Uint8List proposerPublicKey,
    required Uint8List fromPublicKey,
    required Uint8List beneficiaryPublicKey,
    required BigInt amountFen,
    required String remark,
  }) {
    return _confirmProposalEvent(
      execution: execution,
      eventLabel: 'TransferProposed',
      matches: (event) {
        final fields = event.fields as Map<String, Object?>;
        return InstitutionCodeLabel.codeToString(event.fieldBytes('institution_code')) == orgCode &&
            ProposalQueryService.eventOptionalText(fields['actor_cid_number'], actorCidNumber) &&
            listEquals(event.fieldBytes('proposer_account_id'), proposerPublicKey) &&
            listEquals(event.fieldBytes('funding_account_id'), fromPublicKey) &&
            listEquals(event.fieldBytes('beneficiary_account_id'), beneficiaryPublicKey) &&
            event.fieldUnsigned('amount') == amountFen &&
            utf8.decode(event.fieldBytes('remark')) == remark;
      },
    );
  }

  /// 以真实metadata逐条解码完整事件，只承认当前SDK执行索引所属的唯一事件。
  Future<int> _confirmProposalEvent({
    required CitizenExecution execution,
    required String eventLabel,
    required bool Function(CitizenSystemEvent) matches,
  }) async {
    final events = await _proposalQuery.fetchExecutionEvents(execution);
    final found = events
        .where(
          (event) =>
              event.pallet == 'MultisigTransfer' &&
              event.name == eventLabel,
        )
        .toList();
    if (found.length != 1 || !matches(found.single)) {
      throw StateError('执行块缺少唯一且业务字段匹配的MultisigTransfer.$eventLabel事件');
    }
    final id = found.single.fieldUnsigned('proposal_id');
    if (!id.isValidInt) throw const FormatException('提案事件ID无效');
    return id.toInt();
  }

  Uint8List _cidBytes(String cidNumber) {
    final bytes = utf8.encode(cidNumber);
    if (bytes.isEmpty || bytes.length > 32) {
      throw ArgumentError('actor_cid_number 必须为 1..32 字节');
    }
    return Uint8List.fromList(bytes);
  }

  String _requireProposerRoleCode(String? proposerRoleCode) {
    final value = proposerRoleCode?.trim() ?? '';
    final bytes = utf8.encode(value);
    if (bytes.isEmpty || bytes.length > 64) {
      throw ArgumentError('proposer_role_code 必须为 1..64 字节');
    }
    return value;
  }

  Uint8List _roleBytes(String? value) =>
      Uint8List.fromList(utf8.encode(_requireProposerRoleCode(value)));

  BigInt _amount(BigInt value) {
    if (value.isNegative || value.bitLength > 128) {
      throw const FormatException('金额超出范围');
    }
    return value;
  }

  int _decodeU64(Uint8List data) => CitizenScale.readUnsigned(data, 0, 8).toInt();

  static String _hexEncode(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  Uint8List _parseAccountId(String accountId, String fieldName) {
    try {
      return citizenAccountIdBytes(accountId);
    } on FormatException {
      throw FormatException('$fieldName必须是规范 AccountId');
    }
  }

  Uint8List _ss58AddressToAccountId(String address, String fieldName) {
    try {
      return citizenAccountIdBytesFromSs58(address);
    } catch (_) {
      throw FormatException('$fieldName必须是SS58地址');
    }
  }
}
