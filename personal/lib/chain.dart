// 个人链调用、存储编解码、扫描发现和地址派生。

import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteQueryService;
import 'package:citizen_citizen/proposal/vote.dart' show InternalVoteService;

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'dart:convert';
import 'package:citizen_citizen/data.dart' show deriveAccountId;
import 'package:citizen_citizen/proposal/data.dart' show EligibleVoterTicket, ProposalMeta;
import 'package:citizen_citizen/proposal/service.dart' show ProposalQueryService;
import 'package:citizen_storage/user.dart' as wallet_store;
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_system/log.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'accounts.dart';
import 'members.dart';
import 'proposals.dart';
import 'storage.dart';

// 准备个人多签创建和关闭，查询账户并严格解码业务提案。

/// Personal 链上交互服务。
///
/// 只负责个人多签的创建、关闭、查询和 Personal ProposalData 解码；
/// 机构多签链访问由 `citizen/institution` 的 InstitutionChainService 处理。
class PersonalManageService {
  PersonalManageService({
    CitizenSdk? chain,
    CitizenSdk? transactions,
    CitizenCallBuilder? buildCall,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
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
  }) : _votes = InternalVoteService(
         chain: chain,
         transactions: transactions,
         buildCall: buildCall,
         prepareTransaction: prepareTransaction,
         executePreparedTransaction: executePreparedTransaction,
         cancelPreparedTransactionExecution: cancelPreparedTransactionExecution,
         consumePreparedTransactionQrResponse:
             consumePreparedTransactionQrResponse,
         queryFactory: (block) => PersonalProposalQueryService(
           chain: chain,
           block: block,
           getRuntimeContext: getRuntimeContext,
           getStorageRuntimeContext: getRuntimeContext,
           getSystemEvents: getSystemEvents,
           getFinalizedHead: getFinalizedHead,
           getStorage: getStorage,
           getStorageBatch: getStorageBatch,
         ),
       ),
       _buildCall =
           buildCall ??
           transactions?.buildCall ??
           chain?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedEvents = ((block) => readCitizenFinalizedEvents(
         block,
         readEvents:
             getSystemEvents ??
             chain?.getSystemEvents ??
             ((_) => throw StateError('未配置事件读取')),
         readRuntime:
             getRuntimeContext ??
             chain?.getRuntimeContext ??
             ((_) => throw StateError('未配置事件 metadata')),
       )),
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
  final Future<List<CitizenSystemEvent>> Function(CitizenBlockRef)
  _getFinalizedEvents;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final InternalVoteService _votes;
  final CitizenCallBuilder _buildCall;
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

  /// Personal ProposalData action。
  static const actionCreate = 0;
  static const actionClose = 1;

  static const _moduleTag = [
    0x70,
    0x65,
    0x72,
    0x2d,
    0x6d,
    0x67,
    0x6d,
    0x74,
  ]; // "per-mgmt"

  /// 提交 Personal::propose_create extrinsic（个人多签，无需 CID）。
  Future<
    ({
      String txHash,
      int usedNonce,
      BigInt proposalId,
      String accountId,
      String blockHash,
    })
  >
  submitProposeCreatePersonal({
    required Uint8List accountName,
    required List<PersonalMember> admins,
    required int regularThreshold,
    required BigInt amountFen,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final callData = await buildProposeCreatePersonalCallData(
      buildCall: _buildCall,
      accountName: accountName,
      admins: admins,
      regularThreshold: regularThreshold,
      amountFen: amountFen,
    );
    final submitResult = await _execute(
      callData: callData,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    final event = await _confirmPersonalAccountProposedEvent(
      execution: submitResult.execution,
      accountName: accountName,
      admins: admins,
      regularThreshold: regularThreshold,
      amountFen: amountFen,
      proposerPublicKey: signerPublicKey,
    );
    return (
      txHash: submitResult.txHash,
      usedNonce: submitResult.usedNonce,
      proposalId: event.proposalId,
      accountId: event.accountId,
      blockHash: submitResult.execution.block.hash,
    );
  }

  /// 构造个人多签创建 call_data。用于生产提交与测试逐字节对齐。
  @visibleForTesting
  static Future<Uint8List> buildProposeCreatePersonalCallData({
    required CitizenCallBuilder buildCall,
    required Uint8List accountName,
    required List<PersonalMember> admins,
    required int regularThreshold,
    required BigInt amountFen,
  }) {
    if (accountName.isEmpty || accountName.length > 128) {
      throw ArgumentError('account_name 长度需在 1..=128 字节');
    }
    if (admins.length < 2 || admins.length > 64) {
      throw ArgumentError('个人多签管理员数量需在 2..=64');
    }
    final minThreshold = minimumRegularThreshold(admins.length);
    if (regularThreshold < minThreshold || regularThreshold > admins.length) {
      throw ArgumentError(
        'regular_threshold 范围必须在 $minThreshold..=${admins.length}',
      );
    }
    final seen = <String>{};
    for (final admin in admins) {
      if (!isCitizenAccountId(admin.accountId)) {
        throw ArgumentError('admins 每项必须为规范 AccountId');
      }
      if (!seen.add(admin.accountId)) {
        throw ArgumentError('admins 不允许重复');
      }
      _validateAdminName(admin.familyName, 'family_name');
      _validateAdminName(admin.givenName, 'given_name');
    }
    if (amountFen <= BigInt.zero) {
      throw ArgumentError('amount 必须大于 0');
    }

    return buildCall('Personal', 'propose_create', [
      accountName,
      [
        for (final admin in admins)
          [
            citizenAccountIdBytes(admin.accountId),
            Uint8List.fromList(utf8.encode(admin.familyName.trim())),
            Uint8List.fromList(utf8.encode(admin.givenName.trim())),
          ],
      ],
      regularThreshold,
      amountFen,
    ]);
  }

  static void _validateAdminName(String value, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > 128) {
      throw ArgumentError('$field 长度必须在 1..=128 字节');
    }
  }

  /// 提交 Personal::propose_close extrinsic。
  Future<({String txHash, int usedNonce, BigInt proposalId})>
  submitProposeClosePersonal({
    required String accountId,
    required String beneficiaryAddress,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final call = await _buildCall('Personal', 'propose_close', [
      citizenAccountIdBytes(accountId),
      citizenAccountIdBytesFromSs58(beneficiaryAddress),
    ]);
    final result = await _execute(
      callData: call,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    final events = await _getFinalizedEvents(result.execution.block);
    final matches = events
        .where(
          (event) =>
              event.extrinsicIndex == result.execution.extrinsicIndex &&
              event.pallet == 'Personal' &&
              event.name == 'PersonalCloseProposed',
        )
        .toList();
    if (matches.length != 1) throw StateError('执行块缺少唯一的本次个人多签注销提案事件');
    final event = matches.single;
    if (!listEquals(
          event.fieldBytes('account_id'),
          citizenAccountIdBytes(accountId),
        ) ||
        !listEquals(
          event.fieldBytes('beneficiary_account_id'),
          citizenAccountIdBytesFromSs58(beneficiaryAddress),
        ) ||
        !listEquals(event.fieldBytes('proposer_account_id'), signerPublicKey)) {
      throw StateError('注销提案事件与本次账户、受益账户或签名钱包不一致');
    }
    final proposalId = event.fieldUnsigned('proposal_id');
    if (proposalId.isNegative || proposalId.bitLength > 128) {
      throw const FormatException('注销提案ID无效');
    }
    return (
      txHash: result.txHash,
      usedNonce: result.usedNonce,
      proposalId: proposalId,
    );
  }

  /// 撤销候选只能取同一finalized块中冻结且尚未投票的钱包。
  Future<List<String>> pendingCreateVoters(
    String accountId,
    BigInt proposalId,
  ) async {
    final read = await _readCreateProposal(accountId, proposalId);
    if (read.meta.status != 0) throw StateError('创建提案已结束，不能再投票');
    final members = await read.query.fetchPersonalAdminSnapshot(
      proposalId,
      accountId,
    );
    final votes = await read.query.fetchAdminVotesBatch(proposalId, members);
    return members.where((id) => votes[id] == null).toList(growable: false);
  }

  /// 使用同一公开投票服务完成热签或冷签；再次核验未投票资格，失败不重发。
  Future<bool> revokeCreate({
    required String accountId,
    required BigInt proposalId,
    required Uint8List signerPublicKey,
    required Future<String?> Function(CitizenTransactionExternalSigningPending)
    externalSigning,
  }) async {
    final eligible = await pendingCreateVoters(accountId, proposalId);
    if (!eligible.contains(citizenAccountIdFromBytes(signerPublicKey))) {
      throw StateError('该钱包不在未投票的冻结成员中，已投出的赞成票不能撤回');
    }
    await _votes.submit(
      proposalId: proposalId,
      approve: false,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    return createRejectedAndCleared(accountId, proposalId);
  }

  /// 只有确认为该账户的创建提案已否决且三项待建记录均消失，才允许清本机记录。
  Future<bool> createRejectedAndCleared(
    String accountId,
    BigInt proposalId,
  ) async {
    final read = await _readCreateProposal(accountId, proposalId);
    if (read.meta.status != 2) return false;
    final account = citizenAccountIdBytes(accountId);
    final records = await Future.wait([
      read.query.readProposalStorage('Personal', 'PendingPersonalCreate', [
        proposalId,
      ]),
      read.query.readProposalStorage('Personal', 'PersonalAccounts', [account]),
      read.query.readProposalStorage('Personal', 'AdminAccounts', [account]),
    ]);
    return records.every((record) => record == null);
  }

  Future<({PersonalProposalQueryService query, ProposalMeta meta})>
  _readCreateProposal(String accountId, BigInt proposalId) async {
    if (proposalId.isNegative || !isCitizenAccountId(accountId)) {
      throw const FormatException('个人创建提案身份无效');
    }
    final block = await _getFinalizedHead();
    final query = PersonalProposalQueryService(
      block: block,
      getFinalizedHead: _getFinalizedHead,
      getRuntimeContext: _getRuntimeContext,
      getStorageRuntimeContext: _getRuntimeContext,
      getStorage: _getStorage,
      getStorageBatch: _getStorageBatch,
    );
    final meta = await query.fetchProposalMeta(proposalId);
    final rawOwner = await query.readProposalStorage(
      'VotingEngine',
      'ProposalOwner',
      [proposalId],
    );
    final owner = rawOwner == null
        ? null
        : PersonalManageStorageCodec.readBoundedBytes(rawOwner, 0);
    final rawData = await query.fetchProposalData(proposalId);
    final action = rawData == null
        ? null
        : decodePersonalProposalData(proposalId, rawData);
    if (meta == null ||
        meta.kind != 0 ||
        meta.stage != 0 ||
        meta.internalCode != 'PMUL' ||
        meta.actorCidNumber != null ||
        !listEquals(
          meta.executionAccountId,
          citizenAccountIdBytes(accountId),
        ) ||
        owner == null ||
        owner.nextOffset != rawOwner!.length ||
        !listEquals(owner.value, _moduleTag) ||
        action is! CreateProposalInfo ||
        action.accountId != accountId) {
      throw StateError('创建提案的owner、动作或冻结主体与该个人账户不一致');
    }
    return (query: query, meta: meta);
  }

  /// 批量反查多个个人多签账户的发起人 / 账户名(`PersonalAccounts` 精确整键)。
  ///
  /// 返回以入参地址原样为键的 map;未注册或解码失败的地址值为 null。
  /// 个人多签发现的唯一反查入口(ADR-018 R2:多 key 一律批量,杜绝循环内逐条)。
  Future<Map<String, ({String creatorAccountId, String accountName})?>>
  fetchPersonalMetasBatch(
    Iterable<String> personalAccountIdList, {
    int chunkSize = 100,
  }) async {
    final addresses = personalAccountIdList
        .where((address) => address.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (addresses.isEmpty) return {};
    final runtime = await _getRuntimeContext(await _getFinalizedHead());

    final storageKeyByAccountId = <String, String>{
      for (final address in addresses)
        address:
            '0x${_hexEncode(PersonalManageStorageCodec.personalAccountsKey(runtime, address))}',
    };

    final values = await _fetchStorageBatchChunked(
      runtime.block,
      storageKeyByAccountId.values.toSet(),
      chunkSize: chunkSize,
    );

    final result = <String, ({String creatorAccountId, String accountName})?>{};
    for (final entry in storageKeyByAccountId.entries) {
      final data = values[entry.value];
      final meta = data == null
          ? null
          : PersonalManageStorageCodec.decodePersonalAccount(data);
      result[entry.key] = meta == null
          ? null
          : (
              creatorAccountId: meta.creatorAccount,
              accountName: PersonalManageStorageCodec.accountNameText(
                meta.accountName,
              ),
            );
    }
    return result;
  }

  /// 查询个人多签账户信息。
  Future<AccountInfo?> fetchPersonalAccount(String accountId) async {
    final runtime = await _getRuntimeContext(await _getFinalizedHead());
    final key = PersonalManageStorageCodec.personalAccountsKey(
      runtime,
      accountId,
    );
    final data = await _getStorage(runtime.block, key);
    if (data == null) return null;
    final personal = PersonalManageStorageCodec.decodePersonalAccount(data);
    if (personal == null) return null;
    final accountIdBytes = citizenAccountIdBytes(accountId);
    final adminKey = PersonalManageStorageCodec.adminAccountKey(
      runtime,
      accountIdBytes,
    );
    final adminData = await _getStorage(runtime.block, adminKey);
    if (adminData == null) return null;
    final admin = PersonalManageStorageCodec.decodeAdminAccount(adminData);
    if (admin == null) return null;
    final threshold = await _fetchActivePersonalThreshold(
      runtime,
      accountIdBytes,
    );
    return AccountInfo(
      adminsLen: admin.adminsLen,
      threshold: threshold,
      admins: admin.admins,
      status: _statusFromByte(personal.statusByte),
    );
  }

  /// 批量查询个人多签账户状态。
  ///
  /// 多签列表页不能对每个账户逐个调用 [fetchPersonalAccount]。
  /// 这里按 storage 依赖分阶段批量读取：先读账户与管理员主体，再批量读动态阈值。
  Future<Map<String, AccountInfo?>> fetchPersonalAccountsBatch(
    Iterable<String> accountIdList, {
    int chunkSize = 100,
  }) async {
    final addresses = accountIdList
        .map(_requireAccountId)
        .where((accountId) => accountId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (addresses.isEmpty) return {};
    final runtime = await _getRuntimeContext(await _getFinalizedHead());

    final personalKeyByAddress = <String, String>{};
    final adminKeyByAccountId = <String, String>{};
    final accountIdByAccountId = <String, Uint8List>{};
    final firstRoundKeys = <String>[];

    for (final address in addresses) {
      final accountId = citizenAccountIdBytes(address);
      final personalKey =
          '0x${_hexEncode(PersonalManageStorageCodec.personalAccountsKey(runtime, address))}';
      final adminKey =
          '0x${_hexEncode(PersonalManageStorageCodec.adminAccountKey(runtime, accountId))}';
      accountIdByAccountId[address] = accountId;
      personalKeyByAddress[address] = personalKey;
      adminKeyByAccountId[address] = adminKey;
      firstRoundKeys
        ..add(personalKey)
        ..add(adminKey);
    }

    final firstRoundValues = await _fetchStorageBatchChunked(
      runtime.block,
      firstRoundKeys,
      chunkSize: chunkSize,
    );
    final result = <String, AccountInfo?>{};
    final personalByAddress = <String, PersonalManageAccountSnapshot>{};
    final adminByAccountId = <String, PersonalManageAdminSnapshot>{};

    for (final address in addresses) {
      final personalData = firstRoundValues[personalKeyByAddress[address]];
      final adminData = firstRoundValues[adminKeyByAccountId[address]];
      if (personalData == null || adminData == null) {
        result[address] = null;
        continue;
      }
      final personal = PersonalManageStorageCodec.decodePersonalAccount(
        personalData,
      );
      final admin = PersonalManageStorageCodec.decodeAdminAccount(adminData);
      if (personal == null || admin == null) {
        result[address] = null;
        continue;
      }
      personalByAddress[address] = personal;
      adminByAccountId[address] = admin;
    }

    final activeThresholdKeyByAccountId = <String, String>{};
    for (final entry in adminByAccountId.entries) {
      final accountId = accountIdByAccountId[entry.key]!;
      activeThresholdKeyByAccountId[entry.key] =
          '0x${_hexEncode(PersonalManageStorageCodec.activePersonalThresholdKey(runtime, accountId))}';
    }
    final activeThresholdValues = await _fetchStorageBatchChunked(
      runtime.block,
      activeThresholdKeyByAccountId.values,
      chunkSize: chunkSize,
    );

    final thresholdByAccountId = <String, int?>{};
    for (final entry in activeThresholdKeyByAccountId.entries) {
      final threshold = PersonalManageStorageCodec.decodeDynamicThreshold(
        activeThresholdValues[entry.value],
      );
      thresholdByAccountId[entry.key] = threshold;
    }

    for (final address in addresses) {
      final personal = personalByAddress[address];
      final admin = adminByAccountId[address];
      if (personal == null || admin == null) continue;
      result[address] = AccountInfo(
        adminsLen: admin.adminsLen,
        threshold: thresholdByAccountId[address],
        admins: admin.admins,
        status: _statusFromByte(personal.statusByte),
      );
    }

    return result;
  }

  Future<int?> _fetchActivePersonalThreshold(
    CitizenRuntimeContext runtime,
    Uint8List personalAccount,
  ) async {
    final key = PersonalManageStorageCodec.activePersonalThresholdKey(
      runtime,
      personalAccount,
    );
    final data = await _getStorage(runtime.block, key);
    return PersonalManageStorageCodec.decodeDynamicThreshold(data);
  }

  /// 从 ProposalData 解码 Personal 创建或关闭提案。
  Object? decodePersonalProposalData(BigInt proposalId, Uint8List raw) {
    try {
      var offset = 0;
      final (vecLen, lenBytes) = _decodeCompact(raw, offset);
      offset += lenBytes;
      if (offset + vecLen > raw.length) return null;
      final data = raw.sublist(offset, offset + vecLen);

      if (!_startsWith(data, _moduleTag)) return null;
      final actionType = data[_moduleTag.length];
      final payload = data.sublist(_moduleTag.length + 1);
      if (actionType == actionCreate) {
        return _decodeCreateAction(proposalId, payload);
      }
      if (actionType == actionClose) {
        return _decodeCloseAction(proposalId, payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  CreateProposalInfo? _decodeCreateAction(BigInt proposalId, Uint8List data) {
    if (data.length != 32 + 32 + 16 + 16) return null;
    var offset = 0;

    final accountId = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;

    final proposerBytes = data.sublist(offset, offset + 32);
    final proposerSs58 = citizenSs58FromAccountIdBytes(proposerBytes);
    offset += 32;

    final amountFen = _readU128Le(data.sublist(offset, offset + 16));
    offset += 16;

    final feeAmount = _readU128Le(data.sublist(offset, offset + 16));

    return CreateProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      proposerSs58Address: proposerSs58,
      amountFen: amountFen,
      feeAmount: feeAmount,
    );
  }

  CloseProposalInfo? _decodeCloseAction(BigInt proposalId, Uint8List data) {
    if (data.length != 32 + 32 + 32) return null;
    var offset = 0;

    final accountId = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;

    final beneficiaryBytes = data.sublist(offset, offset + 32);
    final beneficiarySs58 = citizenSs58FromAccountIdBytes(beneficiaryBytes);
    offset += 32;

    final proposerBytes = data.sublist(offset, offset + 32);
    final proposerSs58 = citizenSs58FromAccountIdBytes(proposerBytes);

    return CloseProposalInfo(
      proposalId: proposalId,
      accountId: accountId,
      beneficiarySs58Address: beneficiarySs58,
      proposerSs58Address: proposerSs58,
    );
  }

  Future<({BigInt proposalId, String accountId})>
  _confirmPersonalAccountProposedEvent({
    required CitizenExecution execution,
    required Uint8List accountName,
    required List<PersonalMember> admins,
    required int regularThreshold,
    required BigInt amountFen,
    required Uint8List proposerPublicKey,
  }) async {
    final events = await _getFinalizedEvents(execution.block);
    final matches = events
        .where(
          (event) =>
              event.extrinsicIndex == execution.extrinsicIndex &&
              event.pallet == 'Personal' &&
              event.name == 'PersonalCreateProposed',
        )
        .toList();
    if (matches.length != 1) {
      throw StateError('执行块缺少唯一的本次个人多签创建提案事件');
    }
    final event = matches.single;
    final fields = event.fields as Map<String, Object?>;
    var entries = fields['admins'];
    while (entries is List<Object?> &&
        entries.length == 1 &&
        entries.single is List<Object?>) {
      entries = entries.single;
    }
    final equalBytes = ProposalQueryService.eventBytesEqual;
    if (!listEquals(
          event.fieldBytes('proposer_account_id'),
          proposerPublicKey,
        ) ||
        !listEquals(event.fieldBytes('account_name'), accountName) ||
        event.fieldUnsigned('admins_len') != BigInt.from(admins.length) ||
        event.fieldUnsigned('threshold') != BigInt.from(regularThreshold) ||
        event.fieldUnsigned('amount') != amountFen ||
        entries is! List<Object?> ||
        entries.length != admins.length) {
      throw StateError('个人多签创建事件与本次提案不一致');
    }
    for (var i = 0; i < admins.length; i++) {
      final admin = admins[i];
      final entry = entries[i];
      if (entry is! Map<String, Object?> ||
          !equalBytes(
            entry['account_id'],
            citizenAccountIdBytes(admin.accountId),
          ) ||
          !equalBytes(entry['family_name'], utf8.encode(admin.familyName)) ||
          !equalBytes(entry['given_name'], utf8.encode(admin.givenName))) {
        throw StateError('个人多签创建事件的管理员与本次提案不一致');
      }
    }
    final id = event.fieldUnsigned('proposal_id');
    if (id.isNegative || id.bitLength > 128) {
      throw const FormatException('提案事件ID无效');
    }
    return (
      proposalId: id,
      accountId: citizenAccountIdFromBytes(event.fieldBytes('account_id')),
    );
  }

  Future<({String txHash, int usedNonce, CitizenExecution execution})>
  _execute({
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
    if (completed == null) throw StateError('个人多签交易签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '个人多签交易执行失败');
    }
    return (
      txHash: '0x${_hexEncode(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
      execution: completed.execution!,
    );
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
        chunk.map(_hexDecode).toList(growable: false),
      );
      for (var index = 0; index < chunk.length; index++) {
        result[chunk[index]] = values[index];
      }
    }
    return result;
  }

  static MultisigStatus _statusFromByte(int statusByte) {
    return statusByte == 1 ? MultisigStatus.active : MultisigStatus.pending;
  }

  /// 个人普通阈值允许1..=成员数，创建和注销仍由引擎要求全员。
  static int minimumRegularThreshold(int adminsLen) {
    return 1;
  }

  static BigInt _readU128Le(Uint8List bytes) =>
      CitizenScale.readUnsigned(bytes, 0, 16);

  static bool _startsWith(Uint8List data, List<int> prefix) {
    if (data.length < prefix.length + 1) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  static (int, int) _decodeCompact(Uint8List data, int offset) =>
      CitizenScale.readCompact(data, offset);

  static String _hexEncode(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }

  Uint8List _hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

// 解码个人多签生命周期、管理员及独立阈值快照。

/// 个人多签账户生命周期快照。
///
/// `Personal::PersonalAccounts` 只保存个人账户生命周期元数据；
/// 管理员真源在 `Personal::AdminAccounts`，动态阈值真源在 `InternalVote`。
class PersonalManageAccountSnapshot {
  const PersonalManageAccountSnapshot({
    required this.creatorAccount,
    required this.accountName,
    required this.createdAt,
    required this.statusByte,
  });

  final String creatorAccount;
  final Uint8List accountName;
  final int createdAt;
  final int statusByte;
}

/// 管理员与阈值快照。
class PersonalManageAdminSnapshot {
  const PersonalManageAdminSnapshot({
    required this.orgCode,
    required this.adminsLen,
    required this.admins,
  });

  final String orgCode;
  final int adminsLen;
  final List<PersonalMember> admins;
}

/// Personal 专属 storage codec。
class PersonalManageStorageCodec {
  PersonalManageStorageCodec._();

  static Uint8List personalAccountsKey(
    CitizenRuntimeContext runtime,
    String accountId,
  ) => runtime.storageKey('Personal', 'PersonalAccounts', [
    citizenAccountIdBytes(accountId),
  ]);

  static Uint8List adminAccountKey(
    CitizenRuntimeContext runtime,
    Uint8List accountId,
  ) => runtime.storageKey('Personal', 'AdminAccounts', [accountId]);

  static Uint8List activePersonalThresholdKey(
    CitizenRuntimeContext runtime,
    Uint8List personalAccount,
  ) => runtime.storageKey('InternalVote', 'ActivePersonalThresholds', [
    personalAccount,
  ]);

  static PersonalManageAccountSnapshot? decodePersonalAccount(Uint8List data) {
    if (data.length < 32 + 1 + 4 + 1) return null;
    var offset = 0;
    final creatorAccount = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;
    final accountName = readBoundedBytes(data, offset);
    if (accountName == null) return null;
    offset = accountName.nextOffset;
    if (offset + 4 + 1 > data.length) return null;
    final createdAt = readU32Le(data, offset);
    offset += 4;
    final statusByte = data[offset];
    return PersonalManageAccountSnapshot(
      creatorAccount: creatorAccount,
      accountName: accountName.value,
      createdAt: createdAt,
      statusByte: statusByte,
    );
  }

  static PersonalManageAdminSnapshot? decodeAdminAccount(Uint8List data) {
    final state = PersonalMemberCodec.decodeRecord(data);
    if (state == null) return null;
    return PersonalManageAdminSnapshot(
      orgCode: state.orgCode,
      adminsLen: state.admins.length,
      admins: state.admins,
    );
  }

  static int? decodeDynamicThreshold(Uint8List? data) {
    if (data == null || data.length < 4) return null;
    return readU32Le(data, 0);
  }

  static ({Uint8List value, int nextOffset})? readBoundedBytes(
    Uint8List data,
    int offset,
  ) {
    if (offset >= data.length) return null;
    final (len, lenSize) = readCompactU32(data, offset);
    offset += lenSize;
    if (offset + len > data.length) return null;
    return (
      value: Uint8List.fromList(data.sublist(offset, offset + len)),
      nextOffset: offset + len,
    );
  }

  static (int, int) readCompactU32(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('Compact<u32>长度超出范围');
    return result;
  }

  static int readU32Le(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();

  static String accountNameText(Uint8List bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List hexDecode(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(h.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

// 从管理员反向索引发现本机相关个人多签并更新本地记录。

// 个人多签反向索引发现:后处理(ADR-018 §九)。
//
// 从 AdminAccounts 单次扫描结果(PersonalScanService)里筛出个人多签
// (kind=Personal,且管理员含本地钱包),反查发起人 / 账户名后 upsert
// `account`。机构账户登记与展示不走本服务。

/// 个人多签后处理统计。
class PersonalManageDiscoveryStats {
  const PersonalManageDiscoveryStats({
    required this.subjectsScanned,
    required this.matchedPersonals,
    required this.newlyAdded,
    required this.orphansRemoved,
    required this.elapsed,
    this.partialFailure = false,
  });

  final int subjectsScanned;
  final int matchedPersonals;
  final int newlyAdded;
  final int orphansRemoved;
  final Duration elapsed;
  final bool partialFailure;

  static const empty = PersonalManageDiscoveryStats(
    subjectsScanned: 0,
    matchedPersonals: 0,
    newlyAdded: 0,
    orphansRemoved: 0,
    elapsed: Duration.zero,
  );
}

class PersonalManageDiscoveryService {
  PersonalManageDiscoveryService({
    required PersonalManageService personalManageService,
  }) : _personalManage = personalManageService;

  final PersonalManageService _personalManage;

  /// 处理一次共享扫描结果:筛出我的个人多签 → 批量反查发起人/账户名 → upsert Isar + 孤儿校验。
  Future<PersonalManageDiscoveryStats> processScanned(
    PersonalScanResult scan, {
    required Set<String> myAccountIds,
  }) async {
    final start = DateTime.now();

    final mine = PersonalScanService.filterMine(
      scan,
      myAccountIds: myAccountIds,
      kind: PersonalMemberStorageCodec.kindPersonal,
      codeWhitelist: const {'PMUL'},
    );

    // 批量反查发起人/账户名(PersonalAccounts 精确整键)。
    Map<String, ({String creatorAccountId, String accountName})?> metas;
    try {
      metas = await _personalManage.fetchPersonalMetasBatch(
        mine.map((a) => a.accountId),
      );
    } catch (e) {
      AppLog.d('[PersonalManageDiscovery] 批量反查个人多签元数据失败: $e');
      // 反查整体失败时不做孤儿状态变更,避免把瞬时 RPC 失败误判为注销。
      return PersonalManageDiscoveryStats(
        subjectsScanned: scan.totalKeys,
        matchedPersonals: mine.length,
        newlyAdded: 0,
        orphansRemoved: 0,
        elapsed: DateTime.now().difference(start),
        partialFailure: true,
      );
    }

    final scannedAccountIds = <String>{};
    var newlyAdded = 0;

    for (final acc in mine) {
      final accountId = acc.accountId;
      final meta = metas[accountId];
      if (meta == null) continue;
      scannedAccountIds.add(accountId);
      final added = await _upsertPersonal(
        accountId: accountId,
        name: meta.accountName,
        creatorAccount: meta.creatorAccountId,
        adminAccounts: acc.admins
            .map((admin) => admin.accountId)
            .where(myAccountIds.contains)
            .toList(growable: false),
      );
      if (added) newlyAdded++;
    }

    final orphans = await _reverseValidateAndDelete(scannedAccountIds);

    return PersonalManageDiscoveryStats(
      subjectsScanned: scan.totalKeys,
      matchedPersonals: mine.length,
      newlyAdded: newlyAdded,
      orphansRemoved: orphans,
      elapsed: DateTime.now().difference(start),
      partialFailure: scan.partialFailure,
    );
  }

  Future<bool> _upsertPersonal({
    required String accountId,
    required String name,
    required String creatorAccount,
    required List<String> adminAccounts,
  }) async {
    final normalizedCreatorAccountId = _requireAccountId(creatorAccount);
    _requireAccountId(accountId);

    return UserIsar.instance.writeTxn((isar) async {
      final exists = await isar
          .collection<wallet_store.Account>()
          .filter()
          .accountIdEqualTo(accountId)
          .findFirst();

      if (exists != null) {
        if (!exists.isFound) return false;
        exists.adminAccounts = adminAccounts;
        await isar.collection<wallet_store.Account>().put(exists);
        await PersonalMultisigLocalState.putStatusInTxn(
          isar,
          accountId,
          PersonalMultisigLocalState.statusActive,
        );
        return false;
      }

      final entity = wallet_store.Account()
        ..accountId = accountId
        ..accountName = name
        ..creatorAccount = normalizedCreatorAccountId
        ..addedAt = DateTime.now().millisecondsSinceEpoch
        ..isFound = true
        ..adminAccounts = adminAccounts;
      await isar.collection<wallet_store.Account>().put(entity);
      await PersonalMultisigLocalState.putStatusInTxn(
        isar,
        accountId,
        PersonalMultisigLocalState.statusActive,
      );
      return true;
    });
  }

  Future<int> _reverseValidateAndDelete(Set<String> scannedAccountIds) async {
    var closed = 0;
    await UserIsar.instance.writeTxn((isar) async {
      final stalePersonals = await isar
          .collection<wallet_store.Account>()
          .filter()
          .isFoundEqualTo(true)
          .findAll();
      for (final p in stalePersonals) {
        if (!scannedAccountIds.contains(_requireAccountId(p.accountId))) {
          // 链上注销后仍保留本地账户入口，只把状态标成已注销；
          // 用户在详情页点“删除”时才真正清空本机数据。
          await PersonalMultisigLocalState.putStatusInTxn(
            isar,
            p.accountId,
            PersonalMultisigLocalState.statusClosed,
          );
          closed++;
        }
      }
    });
    return closed;
  }

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}

// 按明确主体读取管理员名册及所属治理阈值并缓存结果。

/// 个人成员链读门面，按AccountId读取Personal成员表及InternalVote动态阈值。
class PersonalMemberService {
  PersonalMemberService({
    CitizenSdk? chain,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
  }) : _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, _AdminAccountCacheEntry> _cache = {};
  static final Map<String, Future<PersonalMemberState?>> _inFlight = {};
  static final Map<String, Future<_AdminAccountCacheEntry?>> _accountReads = {};

  Future<PersonalMemberState?> fetchByIdentity(
    PersonalMemberIdentity identity,
  ) async {
    final cacheKey = identity.identityKey;
    final cached = _cache[cacheKey];
    if (cached != null && cached.isFresh(_cacheTtl) && cached.thresholdLoaded) {
      return cached.state;
    }
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final future = _fetchUncached(identity);
    _inFlight[cacheKey] = future;
    return future.whenComplete(() {
      if (_inFlight[cacheKey] == future) _inFlight.remove(cacheKey);
    });
  }

  Future<PersonalMemberState?> _fetchUncached(
    PersonalMemberIdentity identity,
  ) async {
    final account = await _loadAccount(identity);
    if (account == null) return null;
    // 完整权限仍要求同一 finalized 块的阈值读取成功，失败不把名册当权限快照。
    final threshold = await _resolveThreshold(identity, account.runtime);
    account.state = account.state.copyWith(threshold: threshold ?? 0);
    account.thresholdLoaded = true;
    return account.state;
  }

  Future<_AdminAccountCacheEntry?> _loadAccount(
    PersonalMemberIdentity identity,
  ) {
    final key = identity.identityKey;
    final cached = _cache[key];
    if (cached != null && cached.isFresh(_cacheTtl)) {
      return Future.value(cached);
    }
    final existing = _accountReads[key];
    if (existing != null) return existing;
    late final Future<_AdminAccountCacheEntry?> pending;
    pending = _readAccount(identity)
        .then((account) {
          // clearCache之后的迟到读取不重新填入已作废的缓存。
          if (account != null && identical(_accountReads[key], pending)) {
            _cache[key] = account;
          }
          return account;
        })
        .whenComplete(() {
          if (identical(_accountReads[key], pending)) _accountReads.remove(key);
        });
    _accountReads[key] = pending;
    return pending;
  }

  /// 成员名册与完整状态共用唯一整键读取及公开解码。
  Future<_AdminAccountCacheEntry?> _readAccount(
    PersonalMemberIdentity identity,
  ) async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final key = PersonalMemberStorageCodec.personalAdminStorageKey(
      citizenAccountIdBytes(identity.accountId),
      runtime: runtime,
    );
    final data = await _getStorage(finalized, key);
    if (data == null) return null;
    final decoded = PersonalMemberCodec.decodePersonal(
      citizenAccountIdBytes(identity.accountId),
      data,
    );
    if (decoded == null) throw const FormatException('管理员人员记录无效');
    return _AdminAccountCacheEntry(decoded, runtime);
  }

  /// 名册只消费人员；阈值失败不会丢弃同一缓存中已核实的人员集合。
  Future<List<PersonalMember>> fetchAdmins(
    PersonalMemberIdentity identity,
  ) async => (await _loadAccount(identity))?.state.admins ?? const [];

  Future<int?> fetchThreshold(PersonalMemberIdentity identity) async =>
      (await fetchByIdentity(identity))?.threshold;

  Future<bool> isAdmin(
    String accountId,
    PersonalMemberIdentity identity,
  ) async {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('管理员账户标识无效');
    }
    // 此入口仍是完整状态门禁，不能因只读名册解耦而跳过阈值故障。
    return ((await fetchByIdentity(identity))?.admins ??
            const <PersonalMember>[])
        .any((admin) => admin.accountId == accountId);
  }

  void clearCache([PersonalMemberIdentity? identity]) {
    if (identity == null) {
      _cache.clear();
      _inFlight.clear();
      _accountReads.clear();
      return;
    }
    _cache.remove(identity.identityKey);
    _inFlight.remove(identity.identityKey);
    _accountReads.remove(identity.identityKey);
  }

  void clearPersonalAccountCache(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('管理员账户标识无效');
    }
    final key = 'personal-account:$accountId';
    _cache.remove(key);
    _inFlight.remove(key);
    _accountReads.remove(key);
  }

  Future<int?> _resolveThreshold(
    PersonalMemberIdentity identity,
    CitizenRuntimeContext runtime,
  ) => _fetchThresholdStorage(
    palletName: 'InternalVote',
    storageName: 'ActivePersonalThresholds',
    runtime: runtime,
    keyData: citizenAccountIdBytes(identity.accountId),
  );

  Future<int?> _fetchThresholdStorage({
    required String palletName,
    required String storageName,
    required Uint8List keyData,
    required CitizenRuntimeContext runtime,
  }) async {
    final key = runtime.storageKey(palletName, storageName, [keyData]);
    final data = await _getStorage(runtime.block, key);
    if (data == null || data.length != 4) return null;
    return CitizenScale.readUnsigned(data, 0, 4).toInt();
  }
}

class _AdminAccountCacheEntry {
  _AdminAccountCacheEntry(this.state, this.runtime)
    : createdAt = DateTime.now();

  PersonalMemberState state;
  final CitizenRuntimeContext runtime;
  bool thresholdLoaded = false;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

// 解码管理员记录及账户资料，区分名册与独立阈值。

class PersonalMemberCodec {
  PersonalMemberCodec._();

  /// 唯一的个人成员向量解码：钱包账户、姓、名；不读取机构成员布局。
  static (List<PersonalMember>, int)? decodeVector(Uint8List data, int offset) {
    try {
      final (count, size) = CitizenScale.readCompact(data, offset);
      if (count > 64) return null;
      offset += size;
      final members = <PersonalMember>[];
      final seen = <String>{};
      for (var index = 0; index < count; index++) {
        if (offset + 32 > data.length) return null;
        final accountId = citizenAccountIdFromBytes(
          data.sublist(offset, offset + 32),
        );
        offset += 32;
        if (!seen.add(accountId)) return null;
        final names = <String>[];
        for (var field = 0; field < 2; field++) {
          final (length, lengthSize) = CitizenScale.readCompact(data, offset);
          offset += lengthSize;
          if (length > 128 || offset + length > data.length) return null;
          names.add(utf8.decode(data.sublist(offset, offset + length)));
          offset += length;
        }
        members.add(
          PersonalMember(
            accountId: accountId,
            familyName: names[0],
            givenName: names[1],
          ),
        );
      }
      return (List<PersonalMember>.unmodifiable(members), offset);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  static PersonalMemberState? decodePersonal(
    Uint8List personalAccount,
    Uint8List data,
  ) {
    final record = decodeRecord(data);
    if (record == null) return null;
    return PersonalMemberState(
      accountId: citizenAccountIdFromBytes(personalAccount),
      orgCode: record.orgCode,
      kind: record.kind,
      admins: record.admins,
      threshold: 0,
      personalCreatorAccountId: record.creatorAccount,
      personalCreatedAt: record.createdAt,
      personalUpdatedAt: record.updatedAt,
      personalStatus: record.status,
    );
  }

  /// 解码成员表的值；账户身份由实际存储键提供。
  static ({
    String orgCode,
    int kind,
    List<PersonalMember> admins,
    String creatorAccount,
    int createdAt,
    int updatedAt,
    int status,
  })?
  decodeRecord(Uint8List data) {
    if (data.length < 5) return null;
    var offset = 0;
    if (offset + 5 > data.length) return null;
    final orgCode = String.fromCharCodes(
      data.sublist(offset, offset + 4).where((b) => b != 0),
    );
    offset += 4;
    final kind = data[offset++];
    if (kind != 2 || orgCode != 'PMUL') return null;
    final decodedAdmins = PersonalMemberCodec.decodeVector(data, offset);
    if (decodedAdmins == null) return null;
    final admins = decodedAdmins.$1;
    offset = decodedAdmins.$2;
    if (offset + 32 + 4 + 4 + 1 != data.length) return null;
    final creatorAccount = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    );
    offset += 32;
    final createdAt = _readU32(data, offset);
    offset += 4;
    final updatedAt = _readU32(data, offset);
    offset += 4;
    final status = data[offset];
    if (status > 2) return null;
    return (
      orgCode: orgCode,
      kind: kind,
      admins: admins,
      creatorAccount: creatorAccount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status,
    );
  }

  static (int, int) readCompactU32(Uint8List data, int offset) {
    final decoded = CitizenScale.readCompact(data, offset);
    if (decoded.$1 > 0xffffffff) {
      throw const FormatException('Compact 长度超出 u32');
    }
    return decoded;
  }

  static int _readU32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();
}

// 严格解码个人账户键对应的成员存储布局。

class PersonalMemberStorageDecoded {
  const PersonalMemberStorageDecoded({
    required this.orgCode,
    required this.kind,
    required this.admins,
  });

  final String orgCode;
  final int kind;
  final List<PersonalMember> admins;
}

class PersonalMemberStorageCodec {
  PersonalMemberStorageCodec._();

  static const int kindPersonal = 2;

  static Uint8List personalAdminStorageKey(
    Uint8List accountId, {
    required CitizenRuntimeContext runtime,
  }) {
    if (accountId.length != 32) {
      throw ArgumentError('accountId 必须为 32 字节');
    }
    return runtime.storageKey('Personal', 'AdminAccounts', [accountId]);
  }

  /// [kind] 必须由扫描到的 pallet 名确定，不能再从机构 value 猜测。
  static PersonalMemberStorageDecoded? tryDecode(
    Uint8List bytes, {
    required int kind,
  }) {
    if (kind != kindPersonal) return null;
    try {
      final state = PersonalMemberCodec.decodeRecord(bytes);
      if (state == null) return null;
      return PersonalMemberStorageDecoded(
        orgCode: state.orgCode,
        kind: state.kind,
        admins: state.admins,
      );
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// Personal 的 key 仍是 32B personal_account。
  static Uint8List? extractPersonalAccountFromKey(Uint8List storageKey) {
    const expectedLength = 32 + 16 + 32;
    if (storageKey.length != expectedLength) return null;
    return Uint8List.fromList(storageKey.sublist(storageKey.length - 32));
  }
}

// 分页扫描并批读各类管理员名册，提取与本机账户相关的条目。

/// 单条已解码的 AdminAccount 记录(地址 + 过滤所需字段)。
@immutable
class PersonalScannedAccount {
  const PersonalScannedAccount({
    required this.accountId,
    required this.orgCode,
    required this.kind,
    required this.admins,
  });

  /// 个人多签管理员表的唯一主键。
  final String accountId;

  /// 个人多签业务分类码PMUL。
  final String orgCode;

  /// 个人多签记录分类，编码保持2。
  final int kind;

  /// 完整管理员人员集合；账户使用规范 AccountId，姓、名只用于展示。
  final List<PersonalMember> admins;
}

/// 一次全表扫描的结果。
@immutable
class PersonalScanResult {
  const PersonalScanResult({
    required this.accounts,
    required this.totalKeys,
    required this.partialFailure,
  });

  /// 全部成功解码的条目(未过滤)。
  final List<PersonalScannedAccount> accounts;

  /// 扫描到的 storage key 总数(含未能解码者),用于统计。
  final int totalKeys;

  /// 翻页或批量读取过程中出现过失败(结果可能不完整)。
  final bool partialFailure;

  static const empty = PersonalScanResult(
    accounts: <PersonalScannedAccount>[],
    totalKeys: 0,
    partialFailure: false,
  );
}

/// 分类管理员 `AdminAccounts` 单次扫描服务。
class PersonalScanService {
  PersonalScanService({
    CitizenSdk? chain,
    this.palletNames = const ['Personal'],
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
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
  }) : _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
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
               throw StateError('未配置getStorageBatch')) {
    if (palletNames.isEmpty) {
      throw ArgumentError.value(palletNames, 'palletNames', '不能为空');
    }
  }
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
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

  /// 本次只允许扫描Personal的成员表。
  final List<String> palletNames;

  static const Set<String> _allowedPalletNames = {'Personal'};

  /// 翻页大小。
  static const _pageSize = 256;

  /// 单批 storage 读取上限(防 RPC 超时)。
  static const _batchSize = 100;

  /// 全表扫描 AdminAccounts,返回全部已解码条目。
  ///
  /// [onProgress] 进度回调:(已扫描 key 数, 已知总数或 null, 已解码条目数)。
  Future<PersonalScanResult> scanAll({
    void Function(int scanned, int? total, int decoded)? onProgress,
  }) async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final allKeys = <Uint8List>[];
    final kinds = <int>[];
    var partialFailure = false;

    for (final entry in _adminAccountsPrefixes(runtime)) {
      Uint8List? startKey;
      while (true) {
        List<Uint8List> page;
        try {
          page = await _getStorageKeysPaged(
            finalized,
            entry.prefix,
            startKey: startKey,
            limit: _pageSize,
          );
        } catch (e) {
          AppLog.d('[AdminAccountsScan] getKeysPaged 失败: $e');
          partialFailure = true;
          break;
        }
        if (page.isEmpty) break;
        allKeys.addAll(page);
        kinds.addAll(List<int>.filled(page.length, entry.kind));
        onProgress?.call(allKeys.length, null, 0);
        if (page.length < _pageSize) break;
        startKey = page.last;
      }
    }

    final accounts = <PersonalScannedAccount>[];
    for (var start = 0; start < allKeys.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, allKeys.length);
      final batchKeys = allKeys.sublist(start, end);

      List<Uint8List?> values;
      try {
        values = await _getStorageBatch(finalized, batchKeys);
      } catch (e) {
        AppLog.d('[AdminAccountsScan] fetchStorageBatch 失败: $e');
        partialFailure = true;
        continue;
      }

      for (var index = 0; index < batchKeys.length; index++) {
        final keyBytes = batchKeys[index];
        final value = values[index];
        if (value == null) continue;
        final kind = kinds[start + index];
        final decoded = PersonalMemberStorageCodec.tryDecode(value, kind: kind);
        if (decoded == null) continue;
        if (kind == PersonalMemberStorageCodec.kindPersonal) {
          final accountIdBytes =
              PersonalMemberStorageCodec.extractPersonalAccountFromKey(
                keyBytes,
              );
          if (accountIdBytes == null) continue;
          final accountId = citizenAccountIdFromBytes(accountIdBytes);
          accounts.add(
            PersonalScannedAccount(
              accountId: accountId,
              orgCode: decoded.orgCode,
              kind: decoded.kind,
              admins: decoded.admins,
            ),
          );
        }
      }
      onProgress?.call(allKeys.length, allKeys.length, accounts.length);
    }

    return PersonalScanResult(
      accounts: accounts,
      totalKeys: allKeys.length,
      partialFailure: partialFailure,
    );
  }

  /// 纯函数:从扫描结果里筛出"我的"账户(指定 kind,可选机构码白名单,
  /// 且管理员集合含本地任一钱包账户 ID)。供个人多签发现复用,便于单测。
  static List<PersonalScannedAccount> filterMine(
    PersonalScanResult scan, {
    required Set<String> myAccountIds,
    int? kind,
    Set<int>? kinds,
    Set<String>? codeWhitelist,
  }) {
    final acceptedKinds = kinds ?? (kind == null ? const <int>{} : {kind});
    return scan.accounts
        .where(
          (a) =>
              acceptedKinds.contains(a.kind) &&
              (codeWhitelist == null || codeWhitelist.contains(a.orgCode)) &&
              a.admins.any((admin) => myAccountIds.contains(admin.accountId)),
        )
        .toList(growable: false);
  }

  /// 每个短 prefix 同时携带 pallet 决定的主体类型，禁止再从 value 猜 kind。
  List<({Uint8List prefix, int kind})> _adminAccountsPrefixes(
    CitizenRuntimeContext runtime,
  ) {
    final invalid = palletNames.where(
      (name) => !_allowedPalletNames.contains(name),
    );
    if (invalid.isNotEmpty) {
      throw ArgumentError.value(
        invalid.join(','),
        'palletNames',
        '包含未知分类管理员 pallet',
      );
    }
    return palletNames
        .toSet()
        .map(
          (palletName) => (
            prefix: runtime.storageKey(palletName, 'AdminAccounts'),
            kind: switch (palletName) {
              'Personal' => PersonalMemberStorageCodec.kindPersonal,
              _ => throw StateError('未知管理员 pallet'),
            },
          ),
        )
        .toList(growable: false);
  }
}

/// 个人主体、冻结成员及票据由本包组装；通用提案字段仍消费引擎公开查询。
class PersonalProposalQueryService extends ProposalQueryService {
  PersonalProposalQueryService({
    super.chain,
    super.block,
    super.getSystemEvents,
    super.getRuntimeContext,
    super.getStorageRuntimeContext,
    super.getFinalizedHead,
    super.getStorage,
    super.getStorageBatch,
  }) : _personalVotes = PersonalVoteQueryService(
         chain: chain,
         block: block,
         getFinalizedHead: getFinalizedHead,
         getRuntimeContext: getStorageRuntimeContext ?? getRuntimeContext,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       );
  final PersonalVoteQueryService _personalVotes;
  Future<List<BigInt>> fetchActivePersonalProposalIds(String accountId) {
    return fetchActiveProposalIdsBySubjectKey(
      personalAccountSubjectKey(accountId),
    );
  }

  static Uint8List personalAccountSubjectKey(String accountId) {
    return Uint8List.fromList([1, ...citizenAccountIdBytes(accountId)]);
  }

  Future<List<String>> fetchPersonalAdminSnapshot(
    BigInt proposalId,
    String accountId,
  ) async {
    final data = await readProposalStorage('VotingEngine', 'AdminSnapshot', [
      proposalId,
      (scale: personalAccountSubjectKey(accountId)),
    ]);
    if (data == null) {
      throw StateError('提案 $proposalId 缺少 VotingEngine::AdminSnapshot');
    }
    final decoded = ProposalQueryService.decodeAdminSnapshot(data);
    if (decoded == null || decoded.isEmpty) {
      throw const FormatException('VotingEngine::AdminSnapshot SCALE 数据无效');
    }
    return decoded;
  }

  Future<List<EligibleVoterTicket>> fetchPersonalVoterTickets(
    BigInt id,
    PersonalAccountInfo account, {
    bool includeRoleNames = false,
  }) async => [
    for (final wallet in await fetchPersonalAdminSnapshot(
      id,
      account.accountId,
    ))
      EligibleVoterTicket(voterAccountId: wallet),
  ];
  @override
  Future<bool?> fetchAdminVote(BigInt proposalId, String accountId) =>
      _personalVotes.fetchVote(proposalId, accountId);
  @override
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    BigInt proposalId,
    Iterable<String> accountIds,
  ) => _personalVotes.fetchVotesBatch(proposalId, accountIds);
  @override
  Future<Map<String, bool?>> fetchTicketVotesBatch(
    BigInt proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) async {
    final personalTickets = tickets.toList(growable: false);
    final accounts = personalTickets
        .map((ticket) {
          final account = ticket.voterAccountId;
          if (ticket.isInstitution || account == null) {
            throw StateError('个人票据必须包含冻结钱包且不能包含机构岗位');
          }
          return account;
        })
        .toList(growable: false);
    final votes = await _personalVotes.fetchVotesBatch(proposalId, accounts);
    return {
      for (final ticket in personalTickets)
        ticket.ticketKey: votes[ticket.voterAccountId],
    };
  }
}

/// 个人票据只以冻结钱包标识；批读和metadata存储编码使用引擎通用接口。
class PersonalVoteQueryService {
  PersonalVoteQueryService({
    CitizenSdk? chain,
    CitizenBlockRef? block,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef, Uint8List)? getStorage,
    Future<List<Uint8List?>> Function(CitizenBlockRef, List<Uint8List>)?
    getStorageBatch,
  }) : _reader = InternalVoteQueryService(
         chain: chain,
         block: block,
         getFinalizedHead: getFinalizedHead,
         getRuntimeContext: getRuntimeContext,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       );
  final InternalVoteQueryService _reader;
  List<Object> _key(BigInt id, String account) {
    if (id.isNegative) throw ArgumentError('proposal_id不得为负');
    return [
      id,
      (variant: 'Personal', fields: [citizenAccountIdBytes(account)]),
    ];
  }

  Future<bool?> fetchVote(BigInt id, String account) async =>
      _reader.decodeVote(await _reader.readVoteFields(_key(id, account)));
  Future<Map<String, bool?>> fetchVotesBatch(
    BigInt id,
    Iterable<String> accounts,
  ) async {
    final ids = accounts.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final values = await _reader.readVoteFieldsBatch([
      for (final account in ids) _key(id, account),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        ids[i]: _reader.decodeVote(values[i]),
    };
  }
}

/// 个人派生op保持0x06，地址算法和字节不变。
const int kOpPersonal = 0x06;
Uint8List derivePersonalAccountId({
  required Uint8List creatorAccount,
  required String accountName,
}) {
  if (creatorAccount.length != 32) {
    throw ArgumentError('creator account_id 必须为 32 字节');
  }
  return deriveAccountId(
    opTag: kOpPersonal,
    payload: <int>[...creatorAccount, ...utf8.encode(accountName)],
  );
}
