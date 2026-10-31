import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_citizen/account_derivation.dart'
    show ss58FromAccountIdText;
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
  void onTopupRecordChanged(TopupChange change) {
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
            change.orderId != record.orderId)
          return;
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

  Widget _buildTopup(BuildContext context) {
    final TopupRecord order;
    try {
      order = TopupStore.fromEntry(record);
    } on Object {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('本地充值记录损坏，不能继续付款'),
          if (record.orderId != null)
            _buildRow(context, label: '订单号', value: record.orderId!),
        ],
      );
    }
    final intent = order.intent;
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
        _buildRow(context, label: '订单号', value: intent.orderId, copyable: true),
        _buildRow(
          context,
          label: '付款币种',
          value: intent.intentData['token'] as String,
        ),
        _buildRow(context, label: '付款网络', value: intent.network.label),
        _buildRow(context, label: '付款金额', value: topupPaymentLabel(order)),
        _buildRow(
          context,
          label: record.entryState == 'paid' ? '到账公民币' : '预计公民币',
          value: formatFen(intent.coinFen, symbol: '公民币'),
        ),
        _buildRow(
          context,
          label: '目标账户',
          value: ss58FromAccountIdText(intent.accountId),
          copyable: true,
        ),
        _buildRow(context, label: '付款地址', value: intent.payer, copyable: true),
        _buildRow(
          context,
          label: '收款地址',
          value: intent.intentData['recv_address'] as String,
          copyable: true,
        ),
        _buildRow(context, label: '服务来源', value: order.origin),
        _buildRow(
          context,
          label: '创建时间',
          value: formatMillisFull(record.createdAt),
        ),
        _buildRow(
          context,
          label: '报价期限',
          value: formatMillisFull(intent.expiresAt),
        ),
        if (order.txid != null)
          _buildRow(context, label: '付款交易', value: order.txid!, copyable: true),
        if (record.txHash != null)
          _buildRow(
            context,
            label: '到账交易',
            value: record.txHash!,
            copyable: true,
          ),
        if (record.confirmedAt != null)
          _buildRow(
            context,
            label: '到账时间',
            value: formatMillisFull(record.confirmedAt!),
          ),
        if (record.failReason != null)
          _buildRow(
            context,
            label: '异常原因',
            value: order.order?.message ?? '订单需要核查',
          ),
      ],
    );
  }

  BigInt get _amountDeltaFen => BigInt.parse(record.amountDelta);
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
          ? _buildTopup(context)
          : ListView(
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
                      '${_isExpense ? "-" : "+"}${formatFen(record.amountDelta)}',
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
