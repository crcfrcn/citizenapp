import 'package:citizenapp/account/identity/citizen_identity_chain_reader.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizenapp/transaction/onchain/onchain_payment_models.dart';
import 'package:citizenapp/transaction/onchain/onchain_transfer_call.dart';

class OnchainPaymentService {
  OnchainPaymentService({
    required CitizenSdkWallet wallet,
    required CitizenTransactions transactions,
    CitizenChain? chain,
    CitizenIdentityChainReader? bindingReader,
  }) : _wallet = wallet,
       _transactions = transactions,
       _bindingReader =
           bindingReader ??
           (chain == null ? null : CitizenIdentityChainReader(chain: chain));

  final CitizenSdkWallet _wallet;
  final CitizenTransactions _transactions;
  final CitizenIdentityChainReader? _bindingReader;

  /// 联系人列表不解析地址；用户发起签名时唯一一次核对CID当前有效绑定。
  Future<OnchainRecipient> resolveRecipient({
    required String address,
    String? cidNumber,
  }) async {
    if (cidNumber == null) return OnchainRecipient(address: address.trim());
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
      address: ss58FromAccountIdText(binding.accountIdText),
      cidNumber: cidNumber,
      bindRev: binding.bindRev,
      chainHash: binding.block!.hash,
    );
  }

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
    final toAddress = draft.toAddress.trim();
    if (draft.recipient != null && draft.recipient!.address != toAddress) {
      throw const OnchainPaymentException(
        OnchainPaymentErrorCode.invalidDraft,
        '收款账户与已确认目标不一致',
      );
    }
    final symbol = draft.symbol.trim().toUpperCase();
    final remarkBytes = utf8.encode(draft.remark).length;
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(draft.sourceAccountId) ||
        toAddress.isEmpty ||
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
        destinationSs58Address: toAddress,
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
