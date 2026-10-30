import 'package:flutter/material.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_transaction/amount_format.dart';
import 'local_tx_store.dart';

// 流水列表与详情共用原格式化实现，资金仍使用整数分。
String businessTypeLabel(String type) {
  switch (type) {
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

String formatFen(String fen, {String symbol = '元'}) {
  // u128 分不经过 double；保留原千分位布局并准确展示最后一分。
  final value = BigInt.parse(fen).abs();
  final whole = value ~/ BigInt.from(100);
  final cents = (value % BigInt.from(100)).toString().padLeft(2, '0');
  return AmountFormat.formatString(
    '$whole.$cents${symbol.isEmpty ? '' : ' $symbol'}',
  );
}

// ─── 交易记录列表项 ──────────────────────────────────────────

