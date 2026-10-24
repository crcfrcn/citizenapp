import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/transaction/onchain/onchain_payment_models.dart';
import 'package:citizenapp/transaction/onchain/onchain_transfer_call.dart';

class OnchainPaymentService {
  OnchainPaymentService({
    required CitizenSdkWallet wallet,
    required CitizenTransactions transactions,
  }) : _wallet = wallet,
       _transactions = transactions;

  final CitizenSdkWallet _wallet;
  final CitizenTransactions _transactions;

  /// 首次按默认账户初始化表单；选定后只核对该精确账户，缺失绝不回退账户0。
  Future<CitizenWalletStateAccount?> getCurrentWallet({
    String? accountId,
  }) async {
    final state = await _wallet.getState().result;
    if (accountId == null) return state.defaultAccount;
    for (final account in state.accounts) {
      if (account.accountId == accountId) return account;
    }
    throw const OnchainPaymentException(
      OnchainPaymentErrorCode.walletMissing,
      '付款账户已不可用，请重新选择',
    );
  }

  /// 校验 CitizenApp 转账表单、编码 opaque RuntimeCall，然后直接
  /// 交给 CitizenSDK 准备。签名、广播和最终执行不在 App 业务服务内实现。
  Future<CitizenPreparedTransaction> prepareTransfer(
    OnchainPaymentDraft draft,
  ) async {
    final toSs58Address = draft.toSs58Address.trim();
    final symbol = draft.symbol.trim().toUpperCase();
    final remarkBytes = utf8.encode(draft.remark).length;
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(draft.sourceAccountId) ||
        toSs58Address.isEmpty ||
        symbol.isEmpty ||
        !draft.amount.isFinite ||
        !(draft.amount * 100).isFinite ||
        draft.amount <= 0) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '交易草稿不合法，请检查收款地址、数量和币种',
      );
    }
    if (remarkBytes > OnchainTransferCall.maxTransferRemarkBytes) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '转账备注超过链上长度上限',
      );
    }

    final wallet = await getCurrentWallet(accountId: draft.sourceAccountId);
    if (wallet == null) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.walletMissing,
        '请先创建或导入钱包，再进行链上交易',
      );
    }

    final sourceAccountId = _hexToBytes(wallet.accountId);
    // 表单编码错误只属于准备前校验；SDK 的原始错误码和阶段必须原样交还页面。
    late final Uint8List callData;
    try {
      callData = OnchainTransferCall.encode(
        destinationSs58Address: toSs58Address,
        amountYuan: draft.amount,
        remark: draft.remark,
      );
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
    final prepared = await _transactions.prepareTransaction(
      Uint8List.fromList(sourceAccountId),
      callData,
    );
    if (prepared.sourceAccountId.length != sourceAccountId.length ||
        List.generate(sourceAccountId.length, (index) => index).any(
          (index) => prepared.sourceAccountId[index] != sourceAccountId[index],
        )) {
      await _transactions.cancelPreparedTransaction(prepared.preparationId);
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '交易准备的付款账户不一致',
      );
    }
    return prepared;
  }

  List<int> _hexToBytes(String input) {
    final text = input.startsWith('0x') ? input.substring(2) : input;
    if (text.isEmpty || text.length.isOdd) return const <int>[];
    final out = <int>[];
    for (var i = 0; i < text.length; i += 2) {
      out.add(int.parse(text.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}
