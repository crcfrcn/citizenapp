import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;
import 'package:flutter/material.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'record_format.dart';
import 'package:citizen_topup/store.dart';

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

  BigInt get _amountDeltaFen => BigInt.parse(record.amountDelta);
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
    final counterpartyPrefix = _isExpense ? '去向' : '来自';
    final counterparty = shortAddress(record.peerAddress);
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
                ? '${_isExpense ? "-" : "+"}${formatFen(record.amountDelta, symbol: '')}'
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
