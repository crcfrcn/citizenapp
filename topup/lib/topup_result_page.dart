// 展示原充值明细，仅可补充原付款定位并独立核验，不再次付款。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_topup/topup_api.dart';
import 'package:citizen_storage/user_isar.dart' show Entry;
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_wallet/history/record_format.dart';
import 'package:citizen_topup/store.dart';

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
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.updates.recoverPayment(widget.order, _input.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '未能核实原付款，请核对交易哈希或稍后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
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
                enabled: !_busy,
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
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
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _busy ? null : _verify,
          child: _busy
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
