import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_topup/topup_result_page.dart';
import 'package:citizen_topup/store.dart';
import 'record_format.dart';
import 'record_tile.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Entry;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:citizen_system/app_log.dart';
import 'package:flutter/services.dart';
import 'package:citizen_wallet/history/local_tx_store.dart';
import 'package:citizen_wallet/history/tx_auto_refresh_mixin.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({
    super.key,
    required this.accountAddress,
    required this.accountId,
    this.queryRecords = LocalTxStore.queryByAccountId,
  });

  final Future<List<wallet_store.Entry>> Function(
    String accountId, {
    required int limit,
    required int offset,
  })
  queryRecords;
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
  int _scope = 0;
  Future<void>? _readFlight;
  bool _refreshRequested = false;
  List<TopupChange>? _readChanges;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
    startTxAutoRefresh(widget.accountId);
  }

  @override
  void didUpdateWidget(covariant TransactionHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId == widget.accountId &&
        oldWidget.queryRecords == widget.queryRecords) {
      return;
    }
    _scope++;
    _readFlight = null;
    _readChanges = null;
    _refreshRequested = false;
    _records = [];
    _loadingMore = false;
    _hasMore = false;
    startTxAutoRefresh(widget.accountId);
    unawaited(_loadFirstPage());
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _scope++;
    _readChanges = null;
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

  Future<void> _loadFirstPage() => _readRecords(firstPage: true);

  Future<void> _loadNextPage() {
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _records.isEmpty ||
        _readFlight != null) {
      return Future<void>.value();
    }
    return _readRecords(append: true);
  }

  /// 同一账户串行读取本机窗口；读取期间的多次库变更合并为一次后续刷新。
  /// 新账户不等待旧账户的 Future，充值完整回执叠加到查询结果，不另行取回订单。
  Future<void> _readRecords({bool firstPage = false, bool append = false}) {
    final active = _readFlight;
    if (active != null) {
      _refreshRequested = true;
      return active;
    }
    final scope = _scope, account = widget.accountId;
    bool current() => mounted && scope == _scope && account == widget.accountId;
    final changes = <TopupChange>[];
    _readChanges = changes;
    setState(() {
      if (firstPage) _loading = true;
      if (append) _loadingMore = true;
      _error = null;
    });
    Future<void> read() async {
      do {
        _refreshRequested = false;
        changes.clear();
        final prefix = append
            ? List<wallet_store.Entry>.of(_records)
            : <wallet_store.Entry>[];
        final limit = firstPage || append || _records.length < _pageSize
            ? _pageSize
            : _records.length;
        try {
          final page = await widget.queryRecords(
            account,
            limit: limit,
            offset: prefix.length,
          );
          if (!current()) return;
          var rows = <int, wallet_store.Entry>{
            for (final row in [...prefix, ...page]) row.rowId: row,
          }.values.toList();
          for (final change in changes) {
            rows = change.apply(rows, limit: prefix.length + limit);
          }
          setState(() {
            _records = rows;
            _error = null;
            _hasMore = page.length >= limit;
            _loading = false;
            _loadingMore = false;
          });
        } catch (_) {
          if (!current()) return;
          setState(() {
            if (firstPage) _error = '暂时无法读取交易记录';
            _loading = false;
            _loadingMore = false;
          });
          AppLog.d('[TxHistory] 本机记录读取失败');
        }
        firstPage = false;
        append = false;
      } while (current() && _refreshRequested);
    }

    late final Future<void> task;
    task = read().whenComplete(() {
      if (current() && identical(_readFlight, task)) {
        _readFlight = null;
        _readChanges = null;
      }
    });
    _readFlight = task;
    return task;
  }

  /// 后台变更只重查已加载窗口，不增加远端查询或重置用户的分页位置。
  @override
  Future<void> onTxRecordsChanged() =>
      _records.isEmpty ? _loadFirstPage() : _readRecords();

  @override
  void onTopupRecordChanged(TopupChange change) {
    _readChanges?.add(change);
    setState(
      () => _records = change.apply(
        _records,
        limit: _records.length > _pageSize ? _records.length : _pageSize,
      ),
    );
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

class LocalTxRecordDetailPage extends StatefulWidget {
  const LocalTxRecordDetailPage({super.key, required this.record});

  final wallet_store.Entry record;
  @override
  State<LocalTxRecordDetailPage> createState() =>
      _LocalTxRecordDetailPageState();
}

class _LocalTxRecordDetailPageState extends State<LocalTxRecordDetailPage> {
  late wallet_store.Entry record;
  StreamSubscription<TopupChange>? _changes;
  bool _deleting = false;
  @override
  void initState() {
    super.initState();
    record = widget.record;
    _observeOrder();
  }

  @override
  void didUpdateWidget(covariant LocalTxRecordDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.record, oldWidget.record)) {
      record = widget.record;
      _observeOrder();
    }
  }

  void _observeOrder() {
    unawaited(_changes?.cancel());
    _changes = null;
    if (record.entryKind == 'topup') {
      _changes = TopupStore.changes.listen((change) {
        if (!mounted ||
            change.rowId != record.rowId ||
            change.accountId != record.accountId ||
            change.origin != record.serviceOrigin ||
            change.orderId != record.orderId) {
          return;
        }
        final next = change.record;
        if (next == null) {
          Navigator.of(context).pop();
        } else {
          setState(() => record = next);
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _deleteOrder() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除本地充值记录'),
        content: const Text('删除本机订单记录。已提交的付款及服务端处理不会因此撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await TopupStore.shared.delete(record);
    } on Object {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地记录删除失败，请重试')));
      }
    }
  }

  BigInt get _amountDeltaFen =>
      hasVerifiedDelta(record) ? BigInt.parse(record.amountDelta) : BigInt.zero;
  bool get _isExpense => _amountDeltaFen < BigInt.zero;
  bool get _isIncome => _amountDeltaFen > BigInt.zero;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制')));
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
    final delta = recordDeltaLabel(record);

    return Scaffold(
      appBar: AppBar(
        title: Text(record.entryKind == 'topup' ? '充值订单详情' : '交易详情'),
        centerTitle: true,
        actions: [
          if (record.entryKind == 'topup')
            IconButton(
              onPressed: _deleting ? null : _deleteOrder,
              tooltip: '删除本地记录',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: record.entryKind == 'topup'
          ? TopupDetails(record: record, row: _buildRow)
          : ListView(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              children: [
                Center(
                  child: Text(
                    delta == null ? '—' : '$delta 元',
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
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(4),
                      ),
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
                  value:
                      delta == null ? '待链上核实' : '$delta 元',
                ),
                if (record.transferAmount != null)
                  _buildRow(
                    context,
                    label: hasVerifiedDelta(record) ? '转账金额' : '申请转账金额',
                    value: '${formatFen(BigInt.parse(record.transferAmount!).abs())} 元',
                  ),
                if (record.feeAmount != null)
                  _buildRow(
                    context,
                    label:
                        record.eventIndex == null &&
                            record.entrySource == 'local_submit'
                        ? '预估手续费'
                        : '真实手续费',
                    value: '${formatFen(BigInt.parse(record.feeAmount!).abs())} 元',
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
                  _buildRow(
                    context,
                    label: '区块号',
                    value: '${record.blockNumber}',
                  ),
                if (record.blockHash != null)
                  _buildRow(
                    context,
                    label: '区块哈希',
                    value: record.blockHash!,
                    copyable: true,
                  ),
                if (record.eventIndex != null)
                  _buildRow(
                    context,
                    label: '事件序号',
                    value: '${record.eventIndex}',
                  ),
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
