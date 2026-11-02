import 'package:citizen_account/identity/citizen_identity_chain_reader.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart' show KeccakDigest;
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:polkadart/scale_codec.dart' show ByteInput;
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;
import 'package:substrate_metadata/substrate_metadata.dart' as metadata;

import 'package:citizen_transaction/onchain/onchain_payment_models.dart';
import 'package:citizen_transaction/onchain/onchain_transfer_call.dart';

class OnchainPaymentService {
  OnchainPaymentService({
    CitizenSdk? wallet,
    CitizenSdk? transactions,
    CitizenSdk? chain,
    CitizenIdentityChainReader? bindingReader,
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
  }) : _getFinalizedHead =
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

  final CitizenIdentityChainReader? _bindingReader;
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
        final account = Keyring().decodeAddress(text);
        if (account.length != 32 || ss58FromAccountId(account) != text) {
          throw const FormatException('公民链SS58地址无效');
        }
      } on Object {
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
      address: ss58FromAccountIdText(binding.accountIdText),
      cidNumber: cidNumber,
      bindRev: binding.bindRev,
      blockHash: binding.block!.hash,
    );
  }

  Future<OnchainRecipient> _resolveEthereumRecipient(String address) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      throw const FormatException('以太坊地址必须为0x加40位十六进制字符');
    }
    final original = address.substring(2), lower = original.toLowerCase();
    if (RegExp('[a-f]').hasMatch(original) &&
        RegExp('[A-F]').hasMatch(original)) {
      final hash = KeccakDigest(
        256,
      ).process(Uint8List.fromList(utf8.encode(lower)));
      for (var i = 0; i < original.length; i++) {
        final character = original[i];
        final nibble = i.isEven ? hash[i ~/ 2] >> 4 : hash[i ~/ 2] & 15;
        if (RegExp('[a-fA-F]').hasMatch(character) &&
            (character == character.toUpperCase()) != (nibble >= 8)) {
          throw const FormatException('以太坊地址大小写校验和无效');
        }
      }
    }
    final ethereum = _hexToBytes(lower);
    final block = await _getFinalizedHead();
    if (block.finality != CitizenBlockFinality.finalized) {
      throw StateError('收款地址解析必须使用最终确认区块');
    }
    final context = await _getRuntimeContext(block);
    if (context.block.hash != block.hash ||
        context.block.number != block.number ||
        context.block.finality != CitizenBlockFinality.finalized) {
      throw StateError('收款地址元数据区块不一致');
    }
    final input = ByteInput(context.metadata);
    final runtime = metadata.RuntimeMetadataPrefixed.codec
        .decode(input)
        .metadata;
    input.assertEndOfDataReached();
    final revive = runtime.pallets.where((p) => p.name == 'Revive').toList();
    if (revive.length != 1 || revive.single.storage == null) {
      throw StateError('当前最终确认Runtime不支持以太坊收款地址');
    }
    final storage = revive.single.storage!;
    final entries = storage.entries
        .where((e) => e.name == 'OriginalAccount')
        .toList();
    if (entries.length != 1 ||
        entries.single.modifier != metadata.StorageEntryModifier.optional ||
        entries.single.type.key == null ||
        entries.single.type.hashers.length != 1 ||
        entries.single.type.hashers.single != metadata.StorageHasher.identity) {
      throw StateError('Runtime以太坊账户映射存储格式不受支持');
    }
    // OriginalAccount使用Identity，不能复用Blake2_128Concat的普通map key。
    final key = Uint8List.fromList([
      ...Hasher.twoxx128.hashString(storage.prefix),
      ...Hasher.twoxx128.hashString('OriginalAccount'),
      ...ethereum,
    ]);
    final mapped = await _getStorage(block, key);
    if (mapped != null && mapped.length != 32) {
      throw const FormatException('链上以太坊账户映射必须为32字节');
    }
    // 只有成功读取且明确无映射才补12字节EE；读取失败原样抛出。
    final account =
        mapped ?? Uint8List.fromList([...ethereum, ...List.filled(12, 0xee)]);
    return OnchainRecipient(
      address: ss58FromAccountId(account),
      blockHash: block.hash,
    );
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
    final prepared = await _prepareTransaction(
      Uint8List.fromList(sourceAccountId),
      callData,
    );
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
