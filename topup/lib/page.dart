// 充值弹窗及订单结果页面。

import 'package:citizen_scanner/sign.dart' show signCitizenPayload;
import 'package:citizen_system/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_topup/api.dart';
import 'package:citizen_topup/data.dart';
import 'package:citizen_topup/web.dart';
import 'package:citizen_topup/store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user.dart' show Entry;
import 'package:citizen_wallet/history/item.dart' show formatMillisFull, recordStatusLabel, topupPaymentLabel;

// 采集充值金额和支付网络，签后建单并打开MetaMask付款。

/// 币种由充值入口确定；充值金额由用户输入、支付网络默认不选，点击链才开始签名建单并打开MetaMask。
Future<bool?> showTopup(
  BuildContext context, {
  required String accountId,
  required String token,
  TopupApi? api,
  TopupStore? store,
  Future<TopupRecord?> Function(TopupSelection)? paymentOpener,
}) {
  if (!const ['USDT', 'USDC'].contains(token)) {
    throw ArgumentError.value(token, 'token', '不支持的充值币种');
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTheme.surfaceCard,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: TopupSheet(
        accountId: accountId,
        token: token,
        api: api,
        store: store,
        paymentOpener: paymentOpener,
      ),
    ),
  );
}

class TopupSheet extends StatefulWidget {
  const TopupSheet({
    super.key,
    required this.accountId,
    required this.token,
    this.api,
    this.store,
    this.paymentOpener,
  });
  final String accountId, token;
  final TopupApi? api;
  final TopupStore? store;
  final Future<TopupRecord?> Function(TopupSelection)? paymentOpener;
  @override
  State<TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<TopupSheet> {
  late final TopupStore _store = widget.store ?? TopupStore.shared;
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  void _normalizeAmount() {
    if (!_amountFocus.hasFocus && _quote != null) {
      _amount.text = _quote!.coinDisplay;
    }
  }

  TopupPackage? get _quote {
    try {
      return TopupPackage.input(_amount.text);
    } on FormatException {
      return null;
    }
  }

  bool _sheetBusy = false;
  TopupSelection? _selection;
  String? _sheetError;
  TopupWalletSession? _wallet;
  String? _orderId;
  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_normalizeAmount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.paymentOpener == null) {
        _wallet = context.read<TopupWalletSession?>();
        _wallet?.prepare();
      }
    });
  }

  @override
  void dispose() {
    if (_orderId != null) _wallet?.leave(_orderId!);
    _amountFocus.removeListener(_normalizeAmount);
    _amountFocus.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limit =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom) *
        .85;
    final quote = _quote;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: limit < 320 ? limit : 320,
        maxHeight: limit,
      ),
      child: Material(
        color: AppTheme.surfaceCard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  key: const ValueKey('topup-handle'),
                  width: AppLayout.scaled(context, 36),
                  height: AppLayout.scaled(context, 4),
                  margin: EdgeInsets.only(
                    bottom: AppLayout.scaled(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(
                      AppLayout.scaledValue(2),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('使用 '),
                  SvgPicture.string(
                    TopupWallet.logo,
                    key: const ValueKey('topup-metamask-logo'),
                    width: 24,
                    height: 24,
                    semanticsLabel: 'MetaMask',
                  ),
                  const Flexible(child: Text(' MetaMask 钱包支付')),
                ],
              ),
              const SizedBox(height: 12),
              // 说明独立放在下一行，让左侧标题只与输入框本身水平居中对齐。
              _row(
                '充值金额',
                TextField(
                  key: const ValueKey('topup-amount'),
                  controller: _amount,
                  focusNode: _amountFocus,
                  enabled: !_sheetBusy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: '请输入充值金额'),
                  onChanged: (_) => setState(() => _sheetError = null),
                  onEditingComplete: () {
                    final quote = _quote;
                    if (quote != null) _amount.text = quote.coinDisplay;
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                ),
                bottom: 4,
              ),
              Padding(
                // 与输入框左边缘相比右移一个12号汉字，跟随系统文字缩放。
                padding: EdgeInsets.only(
                  left: 80 + MediaQuery.textScalerOf(context).scale(12),
                  bottom: 8,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '充值1美元获得1000元公民币，充值仅限1000的整数倍。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  quote == null
                      ? '0.00${widget.token}'
                      : '${quote.payDisplay}.00${widget.token}',
                  key: const ValueKey('topup-pay-amount'),
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              ),
              _row(
                '支付网络',
                Row(
                  children: [
                    for (final network in const [
                      TopupNetwork.ethereum,
                      TopupNetwork.bnb,
                      TopupNetwork.base,
                    ])
                      Expanded(
                        child: _icon(
                          key: ValueKey('topup-network-${network.wire}'),
                          label: network.label.split('/').last,
                          selected: _selection?.network == network,
                          onTap: _sheetBusy || quote == null
                              ? null
                              : () => _pay(network),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 39,
                                  height: 39,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: switch (network) {
                                      TopupNetwork.ethereum => const Color(
                                        0xFFEEEAF7,
                                      ),
                                      TopupNetwork.bnb => const Color(
                                        0xFF181A20,
                                      ),
                                      TopupNetwork.base => const Color(
                                        0xFFE8EFFF,
                                      ),
                                    },
                                  ),
                                  child: SvgPicture.asset(
                                    'packages/citizen_assets/icons/${network.wire}.svg',
                                    width: network == TopupNetwork.base
                                        ? 17
                                        : 25,
                                    height: network == TopupNetwork.base
                                        ? 17
                                        : 25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    network.label.split('/').last,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_sheetError != null)
                Text(_sheetError!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String title, Widget value, {double bottom = 8}) => Padding(
    padding: EdgeInsets.fromLTRB(0, 8, 0, bottom),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: const TextStyle(fontSize: 14)),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _icon({
    required Key key,
    required String label,
    required bool selected,
    required Widget child,
    required VoidCallback? onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 112,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withAlpha(24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );

  Future<void> _pay(TopupNetwork network) async {
    if (_sheetBusy || _quote == null) return;
    final quote = _quote!;
    _amount.text = quote.coinDisplay;
    FocusScope.of(context).unfocus();
    final route = ModalRoute.of(context);
    final accountId = widget.accountId;
    final selection = TopupSelection(
      token: widget.token,
      package: quote,
      network: network,
    );
    setState(() {
      _sheetBusy = true;
      _selection = selection;
      _sheetError = null;
    });
    try {
      TopupRecord? record;
      if (widget.paymentOpener != null) {
        record = await widget.paymentOpener!(selection);
      } else {
        AppLog.topupOrder('signing');
        final created = await _store.signOrder(
          TopupDraft.create(selection, accountId),
          TopupWallet.id,
          (payload) async {
            final signature = await signCitizenPayload(
              signing: context.read<CitizenSdk>(),
              context: context,
              accountId: accountId,
              payload: payload,
              action: TopupDraft.action,
              transform: CitizenSigningTransform.raw(),
            );
            AppLog.topupOrder('signed');
            return signature;
          },
          active: () =>
              mounted &&
              widget.accountId == accountId &&
              widget.token == selection.token,
        );
        AppLog.topupOrder('saved');
        if (!mounted) return;
        _orderId = created.payment.orderId;
        _wallet ??= context.read<TopupWalletSession>();
        record = await _wallet!.pay(
          created,
          _store,
          presenting: () => mounted && (route?.isCurrent ?? false),
        );
      }
      if (mounted) _finished(record, null);
    } on Object catch (error) {
      if (_orderId == null) {
        AppLog.topupOrder(
          'failed',
          sdkCode: error is CitizenSdkException ? error.code : null,
        );
      }
      const reasons = {
        '付款组件初始化超时',
        '付款钱包初始化失败',
        '付款组件启动失败',
        '本次付款已结束',
        '付款通信已关闭',
        '充值签名或保存未完成，未创建订单',
      };
      final message = error is StateError && reasons.contains(error.message)
          ? error.message
          : '充值未完成，请核实本地订单';
      if (mounted) _finished(null, message);
    }
  }

  void _finished(TopupRecord? record, String? error) {
    if (!mounted) return;
    if (record != null || error == null) {
      Navigator.of(context).pop(record?.progress == TopupProgress.completed);
      return;
    }
    setState(() {
      _sheetBusy = false;
      _selection = null;
      _sheetError = error;
    });
  }
}

// 展示原充值明细，仅可补充原付款定位并独立核验，不再次付款。

/// 本地充值详情正文；原交易详情拥有行快照、变更监听、复制和删除。
/// 未知原单可补录交易哈希；输入不会直接改变支付状态。
class TopupDetails extends StatelessWidget {
  const TopupDetails({super.key, required this.record, required this.row});
  final Entry record;
  final Widget Function(
    BuildContext context, {
    required String label,
    required String value,
    bool copyable,
  })
  row;
  @override
  Widget build(BuildContext context) {
    final TopupRecord order;
    try {
      order = TopupStore.fromEntry(record);
    } on Object {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('本地充值记录损坏，不能继续付款'),
          if (record.orderId != null)
            row(context, label: '订单号', value: record.orderId!),
        ],
      );
    }
    final payment = order.payment;
    return ListView(
      padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
      children: [
        Center(
          child: Text(
            topupPaymentLabel(order),
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 28),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(recordStatusLabel(record))),
        const SizedBox(height: 24),
        const Divider(height: 1),
        row(context, label: '订单号', value: payment.orderId, copyable: true),
        row(context, label: '付款币种', value: payment.token),
        row(context, label: '付款网络', value: payment.network.label),
        row(context, label: '付款金额', value: topupPaymentLabel(order)),
        row(
          context,
          label:
              order.progress == TopupProgress.completed ||
                  record.confirmedAt != null
              ? '到账公民币'
              : '预计公民币',
          value: '${formatFen(BigInt.parse(payment.coinFen))} 公民币',
        ),
        row(
          context,
          label: '目标账户',
          value: citizenSs58FromAccountId(payment.accountId),
          copyable: true,
        ),
        row(
          context,
          label: '付款地址',
          value: order.payer ?? '付款人尚未确认',
          copyable: true,
        ),
        row(context, label: '收款地址', value: payment.recvAddress, copyable: true),
        row(context, label: '服务来源', value: order.origin),
        row(context, label: '创建时间', value: formatMillisFull(record.createdAt)),
        if (order.progress == TopupProgress.pending && order.checkCount > 0)
          row(context, label: '付款验证', value: '${order.checkCount}/30轮'),
        if (order.isPaid &&
            order.receipt?.sealed != true &&
            order.checkCount > 0)
          row(context, label: '结果核验', value: '${order.checkCount}/30轮'),
        if (order.progress == TopupProgress.pending &&
            !order.terminal &&
            order.txid == null &&
            order.wire != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final updates = context.read<TopupUpdates>();
                final found = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      _RecoverPayment(order: order, updates: updates),
                );
                if (found == true && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('原付款已进入核验')));
                }
              },
              child: const Text('核验原付款'),
            ),
          ),
        if (order.requestAt != null)
          row(
            context,
            label: '发币请求',
            value: order.receipt == null ? '请求结果待核实' : '请求已受理',
          ),
        if (order.receipt != null)
          row(
            context,
            label: '发币处理',
            value: order.progress == TopupProgress.completed
                ? '公民币已最终到账'
                : order.receipt!.message,
          ),
        if (order.txid != null)
          row(context, label: '付款交易', value: order.txid!, copyable: true),
        if (record.txHash != null)
          row(context, label: '到账交易', value: record.txHash!, copyable: true),
        if (record.confirmedAt != null)
          row(
            context,
            label: '到账时间',
            value: formatMillisFull(record.confirmedAt!),
          ),
        if (record.failReason != null &&
            order.progress != TopupProgress.completed)
          row(
            context,
            label: '异常原因',
            value: order.isPaid
                ? order.receipt?.message ?? '付款已验证，发币请求需要核查'
                : switch (record.failReason) {
                    'payment_cancelled' => '本次付款已取消，未上传服务端',
                    'payment_failed' => '付款验证失败，未上传服务端',
                    'wallet_unauthorized' => '钱包授权已失效，请重新发起充值并完成 MetaMask 授权',
                    _ => '付款结果尚未核实，请保留原交易',
                  },
          ),
      ],
    );
  }
}

/// 恢复只读原交易；错误就地显示，等待中禁止重复提交。
class _RecoverPayment extends StatefulWidget {
  const _RecoverPayment({required this.order, required this.updates});
  final TopupRecord order;
  final TopupUpdates updates;
  @override
  State<_RecoverPayment> createState() => _RecoverPaymentState();
}

class _RecoverPaymentState extends State<_RecoverPayment> {
  final _input = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _resultBusy = false;
  String? _resultError;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_resultBusy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _resultBusy = true;
      _resultError = null;
    });
    try {
      await widget.updates.recoverPayment(widget.order, _input.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _resultBusy = false;
          _resultError = '未能核实原付款，请核对交易哈希或稍后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_resultBusy,
    child: AlertDialog(
      title: const Text('核验原付款'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('已在 MetaMask 付款但订单未更新时，填写原付款的交易哈希进行核验。'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _input,
                enabled: !_resultBusy,
                maxLength: 66,
                minLines: 1,
                maxLines: 2,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '交易哈希',
                  hintText: '0x…',
                  errorMaxLines: 3,
                ),
                validator: (value) =>
                    RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : '请输入0x开头的64位交易哈希',
                onFieldSubmitted: (_) => _verify(),
              ),
              if (_resultError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _resultError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _resultBusy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _resultBusy ? null : _verify,
          child: _resultBusy
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('核验中'),
                  ],
                )
              : const Text('核验'),
        ),
      ],
    ),
  );
}
