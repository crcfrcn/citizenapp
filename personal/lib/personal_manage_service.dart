import 'dart:convert';

import 'package:citizen_citizen/proposal/proposal_query_service.dart';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';

import 'package:citizen_personal/personal_manage_models.dart';
import 'package:citizen_personal/personal_manage_storage_codec.dart';

/// PersonalManage 链上交互服务。
///
/// 只负责个人多签的创建、关闭、查询和 PersonalManage ProposalData 解码；
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
  }) : _buildCall = buildCall ?? transactions?.buildCall ?? chain?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
       _getRuntimeContext = getRuntimeContext ?? chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedEvents = ((block) => readCitizenFinalizedEvents(
             block,
             readEvents: getSystemEvents ?? chain?.getSystemEvents ??
                 ((_) => throw StateError('未配置事件读取')),
             readRuntime: getRuntimeContext ?? chain?.getRuntimeContext ??
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
  final Future<List<CitizenSystemEvent>> Function(CitizenBlockRef) _getFinalizedEvents;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getRuntimeContext;
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

  /// PersonalManage ProposalData action。
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

  /// 提交 PersonalManage::propose_create extrinsic（个人多签，无需 CID）。
  Future<
    ({
      String txHash,
      int usedNonce,
      int proposalId,
      String accountId,
      String blockHash,
    })
  >
  submitProposeCreatePersonal({
    required Uint8List accountName,
    required List<AdminPerson> admins,
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
    required List<AdminPerson> admins,
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

    return buildCall('PersonalManage', 'propose_create', [
      accountName,
      [
        for (final admin in admins)
          [
            citizenAccountIdBytes(admin.accountId),
            Uint8List.fromList(utf8.encode(admin.cidNumber)),
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

  /// 提交 PersonalManage::propose_close extrinsic。
  Future<({String txHash, int usedNonce})> submitProposeClosePersonal({
    required String accountId,
    required String beneficiaryAddress,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final call = await _buildCall('PersonalManage', 'propose_close', [
      citizenAccountIdBytes(accountId),
      citizenAccountIdBytesFromSs58(beneficiaryAddress),
    ]);
    final result = await _execute(
      callData: call,
      signerPublicKey: signerPublicKey,
      externalSigning: externalSigning,
    );
    return (txHash: result.txHash, usedNonce: result.usedNonce);
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
    final key = PersonalManageStorageCodec.personalAccountsKey(runtime, accountId);
    final data = await _getStorage(runtime.block, key);
    if (data == null) return null;
    final personal = PersonalManageStorageCodec.decodePersonalAccount(data);
    if (personal == null) return null;
    final accountIdBytes = citizenAccountIdBytes(accountId);
    final adminKey = PersonalManageStorageCodec.adminAccountKey(runtime, accountIdBytes);
    final adminData = await _getStorage(runtime.block, adminKey);
    if (adminData == null) return null;
    final admin = PersonalManageStorageCodec.decodeAdminAccount(adminData);
    if (admin == null) return null;
    final threshold = await _fetchActivePersonalThreshold(runtime, accountIdBytes);
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
          '0x${_hexEncode(PersonalManageStorageCodec.activePersonalThresholdKey(runtime,accountId))}';
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

  Future<int?> _fetchActivePersonalThreshold(CitizenRuntimeContext runtime, Uint8List personalAccount) async {
    final key = PersonalManageStorageCodec.activePersonalThresholdKey(runtime,
      personalAccount,
    );
    final data = await _getStorage(runtime.block, key);
    return PersonalManageStorageCodec.decodeDynamicThreshold(data);
  }

  /// 从 ProposalData 解码 PersonalManage 创建或关闭提案。
  Object? decodePersonalProposalData(int proposalId, Uint8List raw) {
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

  CreateProposalInfo? _decodeCreateAction(int proposalId, Uint8List data) {
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

  CloseProposalInfo? _decodeCloseAction(int proposalId, Uint8List data) {
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

  Future<({int proposalId, String accountId})>
  _confirmPersonalAccountProposedEvent({
    required CitizenExecution execution,
    required Uint8List accountName,
    required List<AdminPerson> admins,
    required int regularThreshold,
    required BigInt amountFen,
    required Uint8List proposerPublicKey,
  }) async {
    final events = await _getFinalizedEvents(execution.block);
    final matches = events.where((event) =>
        event.extrinsicIndex == execution.extrinsicIndex &&
        event.pallet == 'PersonalManage' &&
        event.name == 'PersonalCreateProposed').toList();
    if (matches.length != 1) {
      throw StateError('执行块缺少唯一的本次个人多签创建提案事件');
    }
    final event = matches.single;
    final fields = event.fields as Map<String, Object?>;
    var entries = fields['admins'];
    while (entries is List<Object?> && entries.length == 1 &&
        entries.single is List<Object?>) {
      entries = entries.single;
    }
    final equalBytes = ProposalQueryService.eventBytesEqual;
    if (!listEquals(event.fieldBytes('proposer_account_id'), proposerPublicKey) ||
        !listEquals(event.fieldBytes('account_name'), accountName) ||
        event.fieldUnsigned('admins_len') != BigInt.from(admins.length) ||
        event.fieldUnsigned('threshold') != BigInt.from(regularThreshold) ||
        event.fieldUnsigned('amount') != amountFen ||
        entries is! List<Object?> || entries.length != admins.length) {
      throw StateError('个人多签创建事件与本次提案不一致');
    }
    for (var i = 0; i < admins.length; i++) {
      final admin = admins[i];
      final entry = entries[i];
      if (entry is! Map<String, Object?> ||
          !equalBytes(entry['account_id'], citizenAccountIdBytes(admin.accountId)) ||
          !equalBytes(entry['cid_number'], const []) ||
          !equalBytes(entry['family_name'], utf8.encode(admin.familyName)) ||
          !equalBytes(entry['given_name'], utf8.encode(admin.givenName))) {
        throw StateError('个人多签创建事件的管理员与本次提案不一致');
      }
    }
    final id = event.fieldUnsigned('proposal_id');
    if (!id.isValidInt) throw const FormatException('提案事件ID无效');
    return (
      proposalId: id.toInt(),
      accountId: citizenAccountIdFromBytes(event.fieldBytes('account_id')),
    );
  }

  Future<({String txHash, int usedNonce, CitizenExecution execution})> _execute({
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
        completed.execution == null) {
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

  /// 普通提案最低阈值：必须严格过半。
  static int minimumRegularThreshold(int adminsLen) {
    if (adminsLen < 2) return 2;
    return (adminsLen ~/ 2) + 1;
  }

  static BigInt _readU128Le(Uint8List bytes) => CitizenScale.readUnsigned(bytes, 0, 16);

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
