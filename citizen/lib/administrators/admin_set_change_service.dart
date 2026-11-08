import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/administrators/admin_set_change_call_codec.dart';
import 'package:citizen_citizen/administrators/admin_set_change_result.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/administrators/admin_set_validation.dart';

/// 本服务校验并编码管理员集合变更业务 RuntimeCall，再委托 CitizenSDK 准备和执行通用交易；
/// 热签、QR_V1 冷签和链上终态观察均由 SDK 提供，不在 CitizenApp 业务层重复实现。
class AdminsChangeService {
  AdminsChangeService({
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
  }) : _buildCall = buildCall ?? transactions?.buildCall ??
           ((pallet, method, fields) => throw StateError('未配置buildCall')),
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

  Future<Uint8List> buildCallData({
    required AdminAccountState account,
    required String proposerAccountId,
    required List<AdminPerson> admins,
    required int newThreshold,
  }) {
    final normalized = AdminSetValidation.validate(
      account: account,
      proposerAccountId: proposerAccountId,
      admins: admins,
      newThreshold: newThreshold,
    );
    return PersonalAdminsChangeCallCodec.build(
      buildCall: _buildCall,
      orgCode: account.orgCode,
      adminKind: account.kind,
      accountId: citizenAccountIdBytes(account.accountId!),
      admins: normalized.admins,
      newThreshold: normalized.threshold,
    );
  }

  Future<AdminsChangeSubmitResult> submit({
    required AdminAccountState account,
    required List<AdminPerson> admins,
    required int newThreshold,
    required Uint8List signerPublicKey,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    if (signerPublicKey.length != 32) throw ArgumentError('签名公钥必须为32字节');
    final callData = await buildCallData(
      account: account,
      proposerAccountId: citizenAccountIdFromBytes(signerPublicKey),
      admins: admins,
      newThreshold: newThreshold,
    );
    final prepared = await _prepareTransaction(signerPublicKey, callData);
    final started = await _executePreparedTransaction(prepared.preparationId);
    final completed = await completeCitizenTransaction(
      started,
      requestResponse: externalSigning,
      consumeResponse: _consumePreparedTransactionQrResponse,
      cancelExecution: _cancelPreparedTransactionExecution,
    );
    if (completed == null) throw StateError('管理员更换签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess ||
        completed.execution == null ||
        completed.execution!.status != CitizenExecutionStatus.success ||
        completed.execution!.block.finality != CitizenBlockFinality.finalized) {
      throw StateError(completed.poolRejectionReason ?? '管理员更换交易执行失败');
    }
    return AdminsChangeSubmitResult(
      txHash:
          '0x${completed.transactionHash.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
    );
  }
}
