import 'package:flutter/material.dart';
import 'package:citizen_storage/user_isar.dart' show Entry;
import 'package:citizen_citizen/account_derivation.dart'
    show ss58FromAccountIdText;
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_wallet/history/record_format.dart';
import 'package:citizen_topup/store.dart';

/// 本地充值详情正文；原交易详情拥有行快照、变更监听、复制和删除。
/// 无网络、定时器、钱包恢复或再次付款入口。
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
          value: formatFen(payment.coinFen, symbol: '公民币'),
        ),
        row(
          context,
          label: '目标账户',
          value: ss58FromAccountIdText(payment.accountId),
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
          row(context, label: '付款验证', value: '${order.checkCount}/11轮'),
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
                    _ => '付款结果尚未核实，请保留原交易',
                  },
          ),
      ],
    );
  }
}
