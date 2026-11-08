import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';

/// 扫码支付清算体系中清算行(L2)业务的链上 RuntimeCall 与执行入口。
///
/// - 绑定和切换使用机构 CID，由 Runtime metadata 决定调用编码。
/// - CitizenApp 负责选择清算调用和参数；nonce、era、tip、sr25519、
///   extrinsic 和 finalized execution 全部由 CitizenSDK 负责。
/// - 所有金额参数以**分**为单位的整数进入 SCALE 编码,与链上 `u128` 对齐。
class OnchainClearingBankChain {
  OnchainClearingBankChain({
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
           ((_, _, _) => throw StateError('未配置 RuntimeCall 编码')),
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

  /// `bind_clearing_bank(bank_cid)` 绑定清算行，绑定即开户，无预存。
  ///
  /// [signerPublicKey]     L3 用户公钥(32 字节)
  /// [bankCid] 目标清算行的机构 CID。
  /// [externalSigning]  冷账户展示 SDK QR_V1 后返回的扫描原文
  Future<({String txHash, int usedNonce})> bindClearingBank({
    required Uint8List signerPublicKey,
    required String bankCid,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final callData = await _buildBankCidCall('bind_clearing_bank', bankCid);
    return _executeFinalized(
      signerPublicKey: signerPublicKey,
      callData: callData,
      externalSigning: externalSigning,
    );
  }

  /// `deposit(amount)`:L3 自持账户 → 清算行主账户充值。
  ///
  /// [amountFen] 充值金额(分,u128 范围内的正整数)。
  Future<({String txHash, int usedNonce})> deposit({
    required Uint8List signerPublicKey,
    required BigInt amountFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final callData = await _buildAmountOnlyCall('deposit', amountFen);
    return _executeFinalized(
      signerPublicKey: signerPublicKey,
      callData: callData,
      externalSigning: externalSigning,
    );
  }

  /// `withdraw(amount)`:清算行主账户 → L3 自持账户提现。
  Future<({String txHash, int usedNonce})> withdraw({
    required Uint8List signerPublicKey,
    required BigInt amountFen,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final callData = await _buildAmountOnlyCall('withdraw', amountFen);
    return _executeFinalized(
      signerPublicKey: signerPublicKey,
      callData: callData,
      externalSigning: externalSigning,
    );
  }

  /// `switch_bank(new_bank_cid)` 切换清算行，旧清算行余额必须为 0。
  Future<({String txHash, int usedNonce})> switchBank({
    required Uint8List signerPublicKey,
    required String bankCid,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    final callData = await _buildBankCidCall('switch_bank', bankCid);
    return _executeFinalized(
      signerPublicKey: signerPublicKey,
      callData: callData,
      externalSigning: externalSigning,
    );
  }

  // ──────────── 内部：业务 RuntimeCall 编码 ────────────

  Future<Uint8List> _buildBankCidCall(String method, String bankCid) {
    final bytes = Uint8List.fromList(utf8.encode(bankCid));
    if (bytes.isEmpty || bytes.length > 32) {
      throw ArgumentError('清算行机构 CID 必须为 1 到 32 个 UTF-8 字节');
    }
    return _buildCall('OffchainTransaction', method, [bytes]);
  }

  /// 链端金额字段是 u128，由同一 Runtime metadata 决定实际字节。
  Future<Uint8List> _buildAmountOnlyCall(String method, BigInt amountFen) {
    if (amountFen <= BigInt.zero || amountFen.bitLength > 128) {
      throw ArgumentError('amount 必须为正 u128 分');
    }
    return _buildCall('OffchainTransaction', method, [amountFen]);
  }

  /// 把 App 业务 callData 直接交给 CitizenSDK；nonce、era、签名、
  /// extrinsic、提交、观察与 finalized Runtime 终态均不在本类实现。
  Future<({String txHash, int usedNonce})> _executeFinalized({
    required Uint8List signerPublicKey,
    required Uint8List callData,
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
    if (completed == null) throw StateError('清算行链上交易签名已取消');
    if (completed.resolution != CitizenTransactionResolution.finalizedSuccess) {
      throw StateError(completed.poolRejectionReason ?? '清算行链上交易执行失败');
    }
    return (
      txHash: '0x${_hex(completed.transactionHash)}',
      usedNonce: prepared.nonce.toInt(),
    );
  }

  // ──────────── 通用工具 ────────────

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
