import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;
import 'package:citizen_transaction/offchain/offchain_clearing_rpc.dart';
import 'package:citizen_transaction/offchain/payment_intent.dart';
import 'package:citizen_transaction/offchain/clearing_bank_directory.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 扫码支付清算体系付款确认页。
///
///
/// - 入口:`offchain_scan_flow.dart` 扫商户码成功后跳转过来
///   (商户码 `UserTransferBody` 的 `bank` 字段是收款方清算行 `cid_number`)。
/// - Step 3 范围:同行 / 跨行都提交到**收款方清算行节点**,与 runtime
///   `submit_offchain_batch` 的收款方主导模型对齐。
/// - 流程:
///   1. 连清算行节点 RPC,查 `offchain_queryUserBank(user)` 得付款方清算行
///      `payer_bank_cid`（未绑定 → 结束）;
///   2. 重读 finalized `ClearingBankNodes[cid_number]`，核对收款方清算行声明;
///   3. 付款方和收款方清算行都使用机构 CID，不混用主账户地址;
///   4. 查 `offchain_queryFeeRate(recipient_bank_cid)` 得 `(rate_bp, min_fee_fen)`,本地
///      计算 `fee_fen`(与 runtime 一致的四舍五入);
///   5. 展示确认 UI(金额 / 手续费 / 合计 / 收款方地址 / 备注);
///   6. 用户点确认 → 查 `offchain_queryNextNonce(user)` → 构造
///      `NodePaymentIntent`(随机 tx_id + `expires_at = currentBlock + 100`) →
///      `signingHash()` → 热钱包 `signWithWallet` → 提交
///      `offchain_submitPayment(intent_hex, sig_hex)` → 显示结果。
class OffchainClearingPayPage extends StatefulWidget {
  const OffchainClearingPayPage({
    super.key,
    required this.wallet,
    required this.toAddress,
    required this.recipientBankCidNumber,
    required this.clearingNodeWssUrl,
    this.initialAmountYuan,
    this.memo,
    this.nodeRpc,
    this.directory,
    this.payloadSigner,
  });

  /// 付款方当前钱包(仅支持热钱包)。
  final CitizenWalletStateAccount wallet;

  /// 商户 QR `UserTransferBody.account_address` 收款方 SS58 展示地址。
  final String toAddress;

  /// 商户 QR `UserTransferBody.bank` 收款方清算行 `cid_number`。
  final String recipientBankCidNumber;

  /// 收款方清算行节点 WSS URL。
  final String clearingNodeWssUrl;

  /// 商户 QR 预填金额(元,字符串)。空 → 由用户输入。
  final String? initialAmountYuan;

  final String? memo;

  /// 可由调用方交付同一公开清算RPC客户端；正式入口按已声明WSS创建。
  final OffchainClearingBankRpc? nodeRpc;
  final ClearingBankDirectory? directory;
  final PayloadSigner? payloadSigner;

  @override
  State<OffchainClearingPayPage> createState() =>
      _OffchainClearingPayPageState();
}

enum _PageState { loading, ready, submitting, unverified, error }

class _OffchainClearingPayPageState extends State<OffchainClearingPayPage> {
  static const int _expiresInBlocks = 100; // 仅按块高留余量，不承诺固定墙钟有效期

  _PageState _state = _PageState.loading;
  String _errorMessage = '';

  // 预取:付款方绑定的清算行 CID
  String? _payerBankCid;
  // 预取:QR 收款方清算行 CID
  String? _recipientBankCid;
  // 预取:费率
  int _rateBp = 0;
  int _minFeeFen = 1;
  // 预取:当前最新块高(用于 expires_at)
  int _currentBlockNumber = 0;

  // 金额输入(元,字符串)
  final TextEditingController _amountCtrl = TextEditingController();

  // 提交结果
  String? _resultTxId;
  bool _submissionAttempted = false;

  late final OffchainClearingBankRpc _nodeRpc =
      widget.nodeRpc ?? OffchainClearingBankRpc(widget.clearingNodeWssUrl);

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.initialAmountYuan ?? '';
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    final chain = context.read<CitizenSdk>();
    try {
      // 1. 付款方绑定的清算行
      final payerBank = await _nodeRpc.queryUserBank(widget.wallet.ss58Address);
      if (payerBank == null || payerBank.isEmpty) {
        _setError('您尚未绑定清算行,请先返回"选择/绑定清算行"完成绑定');
        return;
      }

      // 2. 付款前重新确认收款方仍有链上清算行声明，主账户只按链统一原语派生。
      final endpoint =
          await (widget.directory ?? ClearingBankDirectory(chain: chain))
              .fetchEndpoint(widget.recipientBankCidNumber);
      if (endpoint == null) {
        _setError('收款方清算行未在链上声明节点,无法付款');
        return;
      }
      // 身份主键=CID:付款方 CID 来自 queryUserBank,收款方 CID 来自扫码入参。
      _payerBankCid = payerBank;
      _recipientBankCid = widget.recipientBankCidNumber;

      // 3. 费率按收款方清算行计算;同行 / 跨行都由收款方清算行拿 fee 并付 gas。
      final rate = await _nodeRpc.queryFeeRate(_recipientBankCid!);
      if (rate.rateBp <= 0) {
        _setError('清算行费率未配置(rate_bp=${rate.rateBp}),请联系清算行运维');
        return;
      }
      _rateBp = rate.rateBp;
      _minFeeFen = rate.minFeeFen;

      // 5. 当前块高
      final latest = await chain.getBestHead();
      _currentBlockNumber = latest.number.toInt();

      if (mounted) {
        setState(() => _state = _PageState.ready);
      }
    } catch (e) {
      _setError('加载支付信息失败:$e');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _state = _PageState.error;
      _errorMessage = msg;
    });
  }

  BigInt? _parseAmountFen() {
    final txt = _amountCtrl.text.trim();
    if (txt.isEmpty) return null;
    final yuan = double.tryParse(txt);
    if (yuan == null || yuan <= 0) return null;
    final fen = BigInt.from((yuan * 100).round());
    return fen > BigInt.zero ? fen : null;
  }

  BigInt? _computeFeeFen(BigInt amountFen) {
    try {
      return NodePaymentIntent.calcFeeFen(
        amountFen: amountFen,
        rateBp: _rateBp,
        minFeeFen: _minFeeFen,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmAndSubmit() async {
    final amountFen = _parseAmountFen();
    if (amountFen == null) {
      _showSnack('请输入有效金额');
      return;
    }
    final feeAmount = _computeFeeFen(amountFen);
    if (feeAmount == null) {
      _showSnack('手续费计算失败');
      return;
    }

    setState(() => _state = _PageState.submitting);
    try {
      // 6. nonce
      final nonce = await _nodeRpc.queryNextNonce(widget.wallet.ss58Address);

      // 7. 构造 intent
      final payer = hexToBytes(widget.wallet.accountId);
      if (payer.length != 32) {
        throw Exception('钱包公钥长度异常:${payer.length}');
      }
      final recipient = _decodeAccount(widget.toAddress);
      final payerBankCidBytes = Uint8List.fromList(utf8.encode(_payerBankCid!));
      final recipientBankCidBytes = Uint8List.fromList(
        utf8.encode(_recipientBankCid!),
      );

      final intent = NodePaymentIntent(
        txId: NodePaymentIntent.randomTxId(),
        payer: payer,
        payerBankCid: payerBankCidBytes,
        recipient: recipient,
        recipientBankCid: recipientBankCidBytes,
        amount: amountFen,
        fee: feeAmount,
        nonce: BigInt.from(nonce),
        expiresAt: _currentBlockNumber + _expiresInBlocks,
      );

      // 8. 签名:热钱包直签;冷钱包不能独立验证 PaymentIntent hash,必须拒绝。
      final sig = await _signSigningHash(
        signingHash: await intent.signingHash(),
        amountFen: amountFen,
        feeAmount: feeAmount,
      );
      if (sig.length != 64) {
        throw Exception('签名长度异常:${sig.length}');
      }

      // 9. 提交
      // 请求可能已经被节点受理；从发送起，失败不能被解释成未付款并诱导重试。
      _resultTxId = bytesToHex(intent.txId);
      _submissionAttempted = true;
      await _nodeRpc.submitPayment(
        expectedTxId: _resultTxId!,
        intentHex: bytesToHex(intent.scaleEncode()),
        payerSigHex: bytesToHex(sig),
      );

      if (!mounted) return;
      setState(() {
        // 现行公开合同未交付可信ACK签名身份；格式与tx_id匹配仍不能证明已受理。
        _state = _PageState.unverified;
      });
    } catch (e) {
      if (_submissionAttempted) {
        if (mounted) setState(() => _state = _PageState.unverified);
      } else {
        _setError('提交失败:$e');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码付款(清算行)')),
      body: _body(),
    );
  }

  Widget _body() {
    switch (_state) {
      case _PageState.loading:
        return const Center(child: CircularProgressIndicator());
      case _PageState.error:
        return _errorView();
      case _PageState.submitting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: AppLayout.scaledValue(12)),
              const Text('正在签名并提交到清算行...'),
            ],
          ),
        );
      case _PageState.unverified:
        return _unverifiedView();
      case _PageState.ready:
        return _confirmView();
    }
  }

  Widget _errorView() {
    return Padding(
      padding: EdgeInsets.all(AppLayout.scaledValue(24)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppLayout.scaledValue(48),
              color: Colors.red,
            ),
            SizedBox(height: AppLayout.scaledValue(16)),
            Text(_errorMessage, textAlign: TextAlign.center),
            SizedBox(height: AppLayout.scaledValue(16)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unverifiedView() {
    return Padding(
      padding: EdgeInsets.all(AppLayout.scaledValue(24)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: AppLayout.scaledValue(48),
              color: Colors.orange,
            ),
            SizedBox(height: AppLayout.scaledValue(16)),
            const Text('付款结果未核实，请勿重复付款。请核对本笔交易记录。'),
            SizedBox(height: AppLayout.scaledValue(8)),
            SelectableText(
              'tx_id: ${_resultTxId ?? ''}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppLayout.scaledValue(12),
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(16)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmView() {
    final amountFen = _parseAmountFen();
    final feeAmount = (amountFen != null) ? _computeFeeFen(amountFen) : null;
    final totalFen = (amountFen != null && feeAmount != null)
        ? amountFen + feeAmount
        : null;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppLayout.scaledValue(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('收款方地址', widget.toAddress),
          if (_payerBankCid != null) _kv('付款方清算行', _payerBankCid!),
          _kv('收款方清算行', widget.recipientBankCidNumber),
          if (_payerBankCid != null && _recipientBankCid != null)
            _kv('清算类型', _payerBankCid == _recipientBankCid ? '同行' : '跨行'),
          if (widget.memo != null && widget.memo!.isNotEmpty)
            _kv('备注', widget.memo!),
          Divider(height: AppLayout.scaledValue(32)),
          TextField(
            controller: _amountCtrl,
            enabled:
                widget.initialAmountYuan == null ||
                widget.initialAmountYuan!.isEmpty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额(元)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppLayout.scaledValue(16)),
          _kv('费率', '$_rateBp bp (万分之 $_rateBp)'),
          _kv('手续费', feeAmount == null ? '—' : '${_fenToYuan(feeAmount)} 元'),
          _kv('合计扣款', totalFen == null ? '—' : '${_fenToYuan(totalFen)} 元'),
          SizedBox(height: AppLayout.scaledValue(24)),
          ElevatedButton(
            onPressed: (amountFen != null && feeAmount != null)
                ? _confirmAndSubmit
                : null,
            child: const Text('确认并签名付款'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.scaledValue(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppLayout.scaledValue(96),
            child: Text(key, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  // ─── 地址编解码工具 ───

  /// 把 SS58 地址转成 32 字节。
  Uint8List _ss58ToBytes(String ss58) {
    final bytes = Keyring().decodeAddress(ss58);
    if (bytes.length != 32) {
      throw Exception('SS58 解码长度异常:${bytes.length}');
    }
    return Uint8List.fromList(bytes);
  }

  /// 热钱包 / 冷钱包统一签名入口。
  ///
  /// - 热钱包:交给 CitizenSDK 按精确 account_id 完成设备认证与签名。
  /// - 清算行付款 payload 当前是 32 字节 signing_hash,冷钱包无法从 hash 独立还原
  ///   PaymentIntent 业务字段,因此不生成离线签名二维码。
  Future<Uint8List> _signSigningHash({
    required Uint8List signingHash,
    required BigInt amountFen,
    required BigInt feeAmount,
  }) async {
    final wallet = widget.wallet;
    if (wallet.signMode == CitizenWalletSignMode.hot) {
      return (widget.payloadSigner ??
          ((id, payload, action, ctx) => signCitizenPayload(
            signing: context.read<CitizenSdk>(),
            context: ctx,
            accountId: id,
            payload: payload,
            action: action,
          )))(wallet.accountId, signingHash, kOpSignL3Pay, context);
    }

    throw Exception('清算行付款签名必须使用本机热钱包；冷钱包无法独立验证付款 hash');
  }

  /// 分转元(两位小数)。本地化展示,不参与任何链上金额计算。
  String _fenToYuan(BigInt fen) {
    // 避免 BigInt → double 丢精度(最大 9e18 分 ≈ 2^63,double 精度 2^53)。
    // 这里走字符串分隔:整数部分 / 小数部分。
    final neg = fen.isNegative;
    final abs = fen.abs();
    final yuan = abs ~/ BigInt.from(100);
    final cents = (abs % BigInt.from(100)).toInt();
    final s = '$yuan.${cents.toString().padLeft(2, '0')}';
    return neg ? '-$s' : s;
  }

  /// QR 里的 `to_address` 是用户展示/扫码边界，只允许 SS58。
  Uint8List _decodeAccount(String address) {
    return _ss58ToBytes(address.trim());
  }
}
