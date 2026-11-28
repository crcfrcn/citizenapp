// 记录条目及显示格式。

import 'package:citizen_storage/user.dart' as wallet_store show Entry;
import 'package:flutter/material.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_topup/store.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'store.dart' show LocalTxStore;
import 'package:citizen_storage/user.dart' show Entry;
import 'package:citizen_topup/data.dart';

// 展示本机交易流水行及可选的详情导航箭头。

class LocalTxRecordTile extends StatelessWidget {
  const LocalTxRecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.showChevron = false,
  });

  final wallet_store.Entry record;
  final VoidCallback? onTap;

  /// 钱包详情页最近记录需要显式展示进入详情的箭头；完整列表保持原布局。
  final bool showChevron;

  BigInt get _amountDeltaFen =>
      hasVerifiedDelta(record) ? BigInt.parse(record.amountDelta) : BigInt.zero;
  bool get _isExpense => _amountDeltaFen < BigInt.zero;
  bool get _isIncome => _amountDeltaFen > BigInt.zero;

  Color get _iconColor {
    if (_isExpense) return AppTheme.danger;
    if (_isIncome) return AppTheme.primaryDark;
    return AppTheme.textTertiary;
  }

  Color get _iconBgColor {
    if (_isExpense) return AppTheme.danger.withAlpha(20);
    if (_isIncome) return AppTheme.success.withAlpha(20);
    return AppTheme.surfaceElevated;
  }

  IconData get _icon {
    switch (record.entryKind) {
      case 'topup':
        return Icons.account_balance_wallet_outlined;
      case 'reward':
        return Icons.token;
      case 'interest':
        return Icons.account_balance;
      case 'issuance':
        return Icons.gavel;
      case 'fee':
        return Icons.receipt_long;
      case 'burn':
        return Icons.delete_forever;
      case 'multisig_transfer':
        return Icons.groups_2_outlined;
      default:
        return _isExpense ? Icons.arrow_upward : Icons.arrow_downward;
    }
  }

  @override
  Widget build(BuildContext context) {
    TopupRecord? topup;
    if (record.entryKind == 'topup') {
      try {
        topup = TopupStore.fromEntry(record);
      } on Object {
        /* 损坏明细保持可见，不能触发付款。 */
      }
    }
    final label = topup == null
        ? businessTypeLabel(record.entryKind)
        : '充值 · ${topup.payment.token}';
    final counterpartyPrefix = _isExpense || !hasVerifiedDelta(record)
        ? '去向'
        : '来自';
    final counterparty = record.entryKind == 'reward'
        ? '链上发行'
        : shortAddress(record.peerAddress);
    final timeStr = formatMillis(record.confirmedAt ?? record.createdAt);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: AppLayout.scaled(context, 18),
        backgroundColor: _iconBgColor,
        child: Icon(
          _icon,
          size: AppLayout.scaled(context, 18),
          color: _iconColor,
        ),
      ),
      title: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 15),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: AppLayout.scaled(context, 6)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaled(context, 4),
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: recordStatusColor(record).withAlpha(30),
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(4)),
            ),
            child: Text(
              recordStatusLabel(record),
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 10),
                color: recordStatusColor(record),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        record.entryKind == 'topup' && topup == null
            ? '本地订单明细不可用\n$timeStr'
            : topup == null
            ? '$counterpartyPrefix：$counterparty\n$timeStr'
            : '${topup.payment.network.label}\n$timeStr',
        style: TextStyle(fontSize: AppLayout.scaled(context, 12), height: 1.5),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            record.entryKind == 'topup' && topup == null
                ? '-'
                : topup == null
                ? recordDeltaLabel(record) ?? '—'
                : topupPaymentLabel(topup),
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 15),
              fontWeight: FontWeight.w700,
              color: _iconColor,
            ),
          ),
          if (showChevron) ...[
            SizedBox(width: AppLayout.scaled(context, 4)),
            Icon(
              Icons.chevron_right,
              size: AppLayout.scaled(context, 20),
              color: AppTheme.textTertiary,
            ),
          ],
        ],
      ),
    );
  }
}

// 统一格式化交易类型、地址、精确金额和执行状态。

// 流水列表与详情共用原格式化实现，资金仍使用整数分。
String businessTypeLabel(String type) {
  switch (type) {
    case 'topup':
      return '充值';
    case 'transfer':
      return '转账';
    case 'fee':
      return '手续费';
    case 'reward':
      return '奖励';
    case 'interest':
      return '利息';
    case 'issuance':
      return '增发';
    case 'burn':
      return '资金销毁';
    case 'multisig_transfer':
      return '多签转账';
    default:
      return type;
  }
}

String sourceLabel(String source) {
  switch (source) {
    case 'topup_order':
      return '本地充值订单';
    case 'local_submit':
      return '本机发起';
    case 'chain_event':
    case 'sdk_finalized_event':
      return '链上事件';
    case 'resync':
      return '后台补同步';
    default:
      return source;
  }
}

String statusLabel(String status) {
  switch (status) {
    case LocalTxStore.statusPending:
    case LocalTxStore.statusInBlock:
      return '待确认';
    case LocalTxStore.statusFinalized:
      return '已确认';
    case LocalTxStore.statusFailed:
      return '失败';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case LocalTxStore.statusPending:
    case LocalTxStore.statusInBlock:
      return AppTheme.warning;
    case LocalTxStore.statusFinalized:
      return AppTheme.success;
    case LocalTxStore.statusFailed:
      return AppTheme.danger;
    default:
      return AppTheme.textTertiary;
  }
}

String pad(int n) => n.toString().padLeft(2, '0');

String formatMillis(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}';
}

String formatMillisFull(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
}

String shortAddress(String? address) {
  if (address == null || address.length <= 12) return address ?? '-';
  return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
}

// ─── 交易记录列表项 ──────────────────────────────────────────

/// 本机提交要等同一笔链事件到达后才能展示实际余额变化。
bool hasVerifiedDelta(Entry row) =>
    row.entrySource != 'local_submit' || row.eventIndex != null;

String? recordDeltaLabel(Entry row) {
  if (!hasVerifiedDelta(row)) return null;
  final amount = BigInt.parse(row.amountDelta);
  return '${amount.isNegative ? '-' : '+'}${formatFen(amount.abs())}';
}

/// 已支付是付款链验证结果，不等同于公民币已到账。
String recordStatusLabel(Entry row) {
  if (row.entryKind != 'topup') return statusLabel(row.entryState);
  final TopupRecord record;
  try {
    record = TopupStore.fromEntry(row);
  } on Object {
    return '记录损坏';
  }
  return switch (record.progress) {
    TopupProgress.pending => '待支付',
    TopupProgress.paid => '已支付',
    TopupProgress.completed => '已完成',
  };
}

/// 三种业务状态使用同一显示规则；取消与失败事实仅在详情说明中保留。
Color recordStatusColor(Entry row) => statusColor(row.entryState);

String topupPaymentLabel(TopupRecord record) {
  final decimals = record.payment.network == TopupNetwork.bnb ? 18 : 6;
  final amount = BigInt.parse(record.payment.payAmount);
  final unit = BigInt.from(10).pow(decimals);
  final fraction = (amount % unit)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '${amount ~/ unit}${fraction.isEmpty ? '' : '.$fraction'} ${record.payment.token}';
}
