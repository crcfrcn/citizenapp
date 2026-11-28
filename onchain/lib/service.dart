// 付款模型、错误解释及转账准备服务。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_chain/service.dart';
import 'dart:convert';
import 'dart:typed_data';

// 定义转账步骤、账户选择、冻结收款目标及明确错误模型。

enum OnchainPaymentErrorCode { walletMissing, invalidDraft }

/// 页面只按已进入的真实交易步骤解释 SDK 错误，不把准备失败写成已发送失败。
enum OnchainPaymentStep { preparation, execution, externalSignature }

String onchainPaymentFailureText(
  OnchainPaymentStep step,
  CitizenSdkErrorCode code,
) {
  final action = switch (step) {
    OnchainPaymentStep.preparation => '交易准备',
    OnchainPaymentStep.execution => '交易执行',
    OnchainPaymentStep.externalSignature => '交易签名',
  };
  final reason = switch (code) {
    CitizenSdkErrorCode.decode => '链上数据解析异常',
    CitizenSdkErrorCode.network ||
    CitizenSdkErrorCode.unavailable ||
    CitizenSdkErrorCode.notReady ||
    CitizenSdkErrorCode.timeout => '区块链暂不可用',
    CitizenSdkErrorCode.invalidArgument => '交易参数无效',
    CitizenSdkErrorCode.authenticationCancelled ||
    CitizenSdkErrorCode.cancelled => '操作已取消',
    CitizenSdkErrorCode.authenticationRequired ||
    CitizenSdkErrorCode.permissionDenied => '需要完成授权',
    _ => '请稍后重试',
  };
  return '$action失败：$reason';
}

class OnchainPaymentException implements Exception {
  const OnchainPaymentException(this.code, this.message);

  final OnchainPaymentErrorCode code;
  final String message;

  @override
  String toString() {
    return 'OnchainPaymentException(${code.name}): $message';
  }
}

/// 选择结果只属于当前表单；目录修订用于拒绝选择期间目录变化，不更改SDK默认账户。
class PaymentAccountSelection {
  const PaymentAccountSelection({
    required this.accountId,
    required this.revision,
  });
  final String accountId;
  final BigInt revision;
}

/// 一次签名前确认的收款目标；地址、CID和绑定版本在该次确认后冻结。
class OnchainRecipient {
  const OnchainRecipient({
    required this.address,
    this.cidNumber,
    this.bindRev,
    this.blockHash,
  });
  final String address;
  final String? cidNumber;
  final int? bindRev;
  final String? blockHash;
}

class OnchainPaymentDraft {
  const OnchainPaymentDraft({
    required this.sourceAccountId,
    required this.toAddress,
    required this.amountFen,
    required this.symbol,
    required this.remark,
    this.recipient,
  });

  final String sourceAccountId;
  final String toAddress;
  final BigInt amountFen;
  final String symbol;
  final String remark;
  final OnchainRecipient? recipient;
}

// 核对准确付款账户及收款绑定，按Runtime编码并交SDK执行转账。

class OnchainPaymentService {
  OnchainPaymentService({
    CitizenSdk? wallet,
    CitizenSdk? transactions,
    CitizenSdk? chain,
    CitizenIdentityChainReader? bindingReader,
    Future<CitizenBlockRef> Function()? getBestHead,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<void> Function(String preparationId)? cancelPreparedTransaction,
  }) : _chain = chain,
       _getBestHead =
           getBestHead ?? chain?.getBestHead ??
           (() => throw StateError('未配置getBestHead')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((CitizenBlockRef block) =>
               throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _bindingReader =
           bindingReader ??
           (chain == null ? null : CitizenIdentityChainReader(chain: chain)),
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState')),
       _prepareTransaction =
           prepareTransaction ??
           transactions?.prepareTransaction ??
           ((Uint8List sourceAccountId, Uint8List callData) =>
               throw StateError('未配置prepareTransaction')),
       _cancelPreparedTransaction =
           cancelPreparedTransaction ??
           transactions?.cancelPreparedTransaction ??
           ((String preparationId) =>
               throw StateError('未配置cancelPreparedTransaction'));
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;
  final Future<CitizenPreparedTransaction> Function(
    Uint8List sourceAccountId,
    Uint8List callData,
  )
  _prepareTransaction;
  final Future<void> Function(String preparationId) _cancelPreparedTransaction;

  final CitizenSdk? _chain;
  final CitizenIdentityChainReader? _bindingReader;

  Future<CitizenFeeSnapshot> quoteFee(BigInt amountFen) =>
      _chain!.getFeeSnapshot(amountFen: amountFen);

  Future<int> readRemarkLimit(CitizenBlockRef block) async {
    return _remarkLimit(await _runtimeAt(block));
  }

  Future<CitizenRuntimeContext> _runtimeAt(CitizenBlockRef block) async {
    final runtime = await _getRuntimeContext(block);
    if (runtime.block.hash != block.hash ||
        runtime.block.number != block.number ||
        runtime.block.finality != block.finality) {
      throw StateError('Runtime 与请求区块不一致');
    }
    return runtime;
  }

  static int _remarkLimit(CitizenRuntimeContext runtime) {
    final limit = runtime.unsignedConstant(
      'Onchain',
      'MaxTransferRemarkLen',
    );
    if (limit.isNegative || limit.bitLength > 32) {
      throw StateError('链上备注长度上限无效');
    }
    return limit.toInt();
  }

  final Future<CitizenBlockRef> Function() _getBestHead;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef block)
  _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  /// 直接地址统一解析为公民链SS58；联系人在签名前核对CID当前有效绑定。
  Future<OnchainRecipient> resolveRecipient({
    required String address,
    String? cidNumber,
  }) async {
    if (cidNumber == null) {
      final text = address.trim();
      if (text.startsWith('0x')) return _resolveEthereumRecipient(text);
      try {
        citizenAccountIdBytesFromSs58(text);
      } on FormatException {
        throw const FormatException('公民链SS58地址无效');
      }
      return OnchainRecipient(address: text);
    }
    final reader = _bindingReader;
    if (reader == null) throw StateError('收款人链验证不可用');
    final binding = await reader.readBindingByCidNumber(cidNumber);
    if (binding == null ||
        binding.block?.finality != CitizenBlockFinality.finalized ||
        binding.cidNumber != cidNumber ||
        binding.bindRev <= 0) {
      throw StateError('收款人CID当前没有有效钱包绑定');
    }
    return OnchainRecipient(
      address: citizenSs58FromAccountId(binding.accountIdText),
      cidNumber: cidNumber,
      bindRev: binding.bindRev,
      blockHash: binding.block!.hash,
    );
  }

  Future<OnchainRecipient> _resolveEthereumRecipient(String address) async {
    final account = await resolveCitizenEvmAddress(
      address, _getFinalizedHead, _getRuntimeContext, _getStorage,
    );
    return OnchainRecipient(address: account.ss58Address, blockHash: account.block.hash);
  }

  /// 首次按默认账户初始化表单；选定后只核对该精确账户，缺失绝不回退账户0。
  Future<CitizenWalletStateAccount?> getCurrentWallet({
    String? accountId,
  }) async {
    final state = await _getWalletState().result;
    if (accountId == null) return state.defaultAccount;
    for (final account in state.accounts) {
      if (account.accountId == accountId) return account;
    }
    throw const OnchainPaymentException(
      OnchainPaymentErrorCode.walletMissing,
      '付款账户已不可用，请重新选择',
    );
  }

  /// App 选择转账字段，SDK 使用同一份 Runtime metadata 编码。
  Future<CitizenPreparedTransaction> prepareTransfer(
    OnchainPaymentDraft draft,
  ) async {
    final toAddress = draft.toAddress.trim();
    if (draft.recipient != null && draft.recipient!.address != toAddress) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '收款账户与已确认目标不一致',
      );
    }
    final symbol = draft.symbol.trim().toUpperCase();
    if (!isCitizenAccountId(draft.sourceAccountId) ||
        toAddress.isEmpty ||
        symbol.isEmpty ||
        draft.amountFen <= BigInt.zero ||
        draft.amountFen.bitLength > 128) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '交易草稿不合法，请检查收款地址、数量和币种',
      );
    }
    final wallet = await getCurrentWallet(accountId: draft.sourceAccountId);
    if (wallet == null) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.walletMissing,
        '请先创建或导入钱包，再进行链上交易',
      );
    }

    final sourceAccountId = citizenAccountIdBytes(wallet.accountId);
    final runtime = await _runtimeAt(await _getBestHead());
    final remark = Uint8List.fromList(utf8.encode(draft.remark));
    if (remark.length > _remarkLimit(runtime)) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '转账备注超过链上长度上限',
      );
    }
    // 表单编码错误只属于准备前校验；SDK 的原始错误码和阶段必须原样交还页面。
    late final Uint8List callData;
    try {
      callData = runtime.encodeCall('Onchain', 'transfer_with_remark', [
        citizenAccountIdBytesFromSs58(toAddress),
        draft.amountFen,
        remark,
      ]);
    } on FormatException {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '收款地址或金额格式错误',
      );
    } on ArgumentError {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '收款地址或金额超出允许范围',
      );
    }
    final prepared = await _prepareTransaction(sourceAccountId, callData);
    if (prepared.sourceAccountId.length != sourceAccountId.length ||
        List.generate(sourceAccountId.length, (index) => index).any(
          (index) => prepared.sourceAccountId[index] != sourceAccountId[index],
        )) {
      await _cancelPreparedTransaction(prepared.preparationId);
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '交易准备的付款账户不一致',
      );
    }
    if (prepared.runtimeSpecNumber != runtime.specVersion ||
        prepared.transactionFormatNumber != runtime.transactionVersion) {
      await _cancelPreparedTransaction(prepared.preparationId);
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '链上运行时已变化，请重新确认交易',
      );
    }
    return prepared;
  }

}
