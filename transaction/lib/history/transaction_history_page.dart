import 'record_format.dart';
import 'record_tile.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:citizen_system/app_log.dart';
import 'package:flutter/services.dart';
import 'package:citizen_transaction/history/local_tx_store.dart';
import 'package:citizen_transaction/history/tx_auto_refresh_mixin.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({
    super.key,
    required this.accountAddress,
    required this.accountId,
  });

  final String accountAddress;
  final String accountId;

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage>
    with TxAutoRefreshMixin<TransactionHistoryPage> {
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  List<wallet_store.Entry> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
    startTxAutoRefresh(widget.accountId);
  }

  @override
  void dispose() {
    unawaited(
      stopTxAutoRefresh().catchError((Object error, StackTrace stackTrace) {
        AppLog.d('[Wallet] 交易历史 watcher 停止失败: $error\n$stackTrace');
      }),
    );
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await LocalTxStore.queryByAccountId(
        widget.accountId,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _hasMore = records.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '暂时无法读取交易记录';
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore || _records.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final records = await LocalTxStore.queryByAccountId(
        widget.accountId,
        limit: _pageSize,
        offset: _records.length,
      );
      if (!mounted) return;
      setState(() {
        _records = [..._records, ...records];
        _hasMore = records.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      AppLog.d('[TxHistory] 分页加载失败');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// 后台监视器写库后:只重查当前已加载窗口、刷新其状态(如翻已确认),
  /// 不重置分页;空列表时退化为首页加载,拾起新到的第一条。
  @override
  Future<void> onTxRecordsChanged() async {
    if (_records.isEmpty) {
      await _loadFirstPage();
      return;
    }
    try {
      final refreshed = await LocalTxStore.queryByAccountId(
        widget.accountId,
        limit: _records.length,
        offset: 0,
      );
      if (!mounted) return;
      setState(() => _records = refreshed);
    } catch (e) {
      AppLog.d('[TxHistory] 响应式刷新失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('交易记录'), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败: $_error',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppLayout.scaledValue(12),
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(8)),
            TextButton(onPressed: _loadFirstPage, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshTxHistory,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: const Center(
                  child: Text(
                    '暂无交易记录',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: refreshTxHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        itemCount: _records.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _records.length) {
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppLayout.scaled(context, 16),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final record = _records[index];
          return LocalTxRecordTile(
            record: record,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LocalTxRecordDetailPage(record: record),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── 交易详情页 ──────────────────────────────────────────────

class LocalTxRecordDetailPage extends StatelessWidget {
  const LocalTxRecordDetailPage({super.key, required this.record});

  final wallet_store.Entry record;

  BigInt get _amountDeltaFen => BigInt.parse(record.amountDelta);
  bool get _isExpense => _amountDeltaFen < BigInt.zero;
  bool get _isIncome => _amountDeltaFen > BigInt.zero;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制')));
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppLayout.scaled(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppLayout.scaled(context, 88),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 14),
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: AppLayout.scaled(context, 14)),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => _copy(context, value),
              child: Padding(
                padding: EdgeInsets.only(left: AppLayout.scaled(context, 8)),
                child: Icon(
                  Icons.copy,
                  size: AppLayout.scaled(context, 16),
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = _isExpense
        ? AppTheme.danger
        : _isIncome
        ? AppTheme.primaryDark
        : AppTheme.textSecondary;
    final label = businessTypeLabel(record.entryKind);

    return Scaffold(
      appBar: AppBar(title: const Text('交易详情'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        children: [
          Center(
            child: Text(
              '${_isExpense ? "-" : "+"}${formatFen(record.amountDelta)}',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 28),
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 8)),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaled(context, 8),
                vertical: AppLayout.scaled(context, 2),
              ),
              decoration: BoxDecoration(
                color: statusColor(record.entryState).withAlpha(20),
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(4)),
              ),
              child: Text(
                statusLabel(record.entryState),
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: statusColor(record.entryState),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: AppLayout.scaled(context, 24)),
          const Divider(height: 1),
          _buildRow(context, label: '类型', value: label),
          _buildRow(
            context,
            label: '确认进度',
            value: switch (record.entryState) {
              LocalTxStore.statusPending => '等待打包',
              LocalTxStore.statusInBlock => '最佳链已打包，等待最终确认',
              LocalTxStore.statusFinalized => '最终链已确认',
              LocalTxStore.statusFailed => '执行失败',
              _ => '状态未知',
            },
          ),
          _buildRow(
            context,
            label: '余额变化',
            value: '${_isExpense ? "-" : "+"}${formatFen(record.amountDelta)}',
          ),
          if (record.transferAmount != null)
            _buildRow(
              context,
              label: '转账金额',
              value: formatFen(record.transferAmount!),
            ),
          if (record.feeAmount != null)
            _buildRow(
              context,
              label:
                  record.eventIndex == null &&
                      record.entrySource == 'local_submit'
                  ? '预估手续费'
                  : '真实手续费',
              value: formatFen(record.feeAmount!),
            ),
          if (record.fromAddress != null)
            _buildRow(
              context,
              label: '来源地址',
              value: record.fromAddress!,
              copyable: true,
            ),
          if (record.toAddress != null)
            _buildRow(
              context,
              label: '去向地址',
              value: record.toAddress!,
              copyable: true,
            ),
          if (record.peerAddress != null)
            _buildRow(
              context,
              label: '对方地址',
              value: record.peerAddress!,
              copyable: true,
            ),
          if (record.txNote != null && record.txNote!.isNotEmpty)
            _buildRow(
              context,
              label: '转账备注',
              value: record.txNote!,
              copyable: true,
            ),
          if (record.txHash != null)
            _buildRow(
              context,
              label: '交易哈希',
              value: record.txHash!,
              copyable: true,
            ),
          if (record.blockNumber != null)
            _buildRow(context, label: '区块号', value: '${record.blockNumber}'),
          if (record.blockHash != null)
            _buildRow(
              context,
              label: '区块哈希',
              value: record.blockHash!,
              copyable: true,
            ),
          if (record.eventIndex != null)
            _buildRow(context, label: '事件序号', value: '${record.eventIndex}'),
          if (record.extrinsicIndex != null)
            _buildRow(
              context,
              label: '交易序号',
              value: '${record.extrinsicIndex}',
            ),
          _buildRow(
            context,
            label: '记录来源',
            value: sourceLabel(record.entrySource),
          ),
          _buildRow(
            context,
            label: '记录时间',
            value: formatMillisFull(record.createdAt),
          ),
          if (record.confirmedAt != null)
            _buildRow(
              context,
              label: '最终确认时间',
              value: formatMillisFull(record.confirmedAt!),
            ),
          if (record.failReason != null)
            _buildRow(context, label: '失败原因', value: record.failReason!),
        ],
      ),
    );
  }
}
