import 'dart:async';

import 'package:flutter/material.dart';

import 'package:citizenapp/system/theme/app_theme.dart';

import 'topup_api.dart';
import 'topup_models.dart';
import 'store.dart';

import 'package:citizenapp/system/theme/app_layout.dart';

/// 原签名/交易定位来自保护记录；只重提同一订单，不在结果页调用钱包重新付款。
/// 支付结果页(第 3 屏)：用付款前意图确认交易 → 凭同一份意图轮询该订单到账。
///
/// 只有服务端paid/exception是终态；处理中或无法核实时不会宣告到账或未收到U。
/// 付款意图既是确认凭证也是查单凭证，不需要账户会话。
enum _Phase { processing, success, failure, unresolved }

class TopupResultPage extends StatefulWidget {
  const TopupResultPage({
    super.key,
    required this.api,
    required this.store,
    required this.record,
    required this.package,
    required this.onReplay,
  });
  final TopupApi api;
  final TopupStore store;
  final TopupRecord record;
  final TopupPackage package;
  final Future<TopupRecord?> Function(TopupRecord) onReplay;

  @override
  State<TopupResultPage> createState() => _TopupResultPageState();
}

class _TopupResultPageState extends State<TopupResultPage>
    with WidgetsBindingObserver {
  late TopupRecord _record;
  _Phase _phase = _Phase.processing;
  String _message = '正在核实原充值订单…';
  Timer? _timer;
  bool _polling = false, _active = true;
  int _attempts = 0;
  @override
  void initState() {
    super.initState();
    _record = widget.record;
    WidgetsBinding.instance.addObserver(this);
    _run();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_active) _run();
  }

  Future<void> _save(TopupRecord next) async {
    await widget.store.save(next, before: _record);
    _record = next;
  }

  Future<void> _run() async {
    if (!mounted || !_active || _polling) return;
    _timer?.cancel();
    if (_record.terminal) {
      _showOrder(_record.order!);
      return;
    }
    _polling = true;
    try {
      final TopupOrder order;
      if (_record.txid != null &&
          _record.signature != null &&
          _record.progress != TopupProgress.confirmed) {
        order = await widget.api.confirm(
          intent: _record.intent,
          paymentTxid: _record.txid!,
          payerSignature: _record.signature!,
        );
        await _save(
          _record.update(progress: TopupProgress.confirmed, order: order),
        );
      } else {
        order = await widget.api.status(_record.intent);
        await _save(_record.update(order: order));
      }
      if (!mounted) return;
      _showOrder(order);
    } on Object {
      if (mounted)
        setState(() {
          _phase = _Phase.unresolved;
          _message = '暂时无法核实原订单，请稍后重试，勿重复付款';
        });
    } finally {
      _polling = false;
    }
    if (mounted && _active && !_record.terminal) {
      _attempts++;
      _timer = Timer(Duration(seconds: _attempts < 20 ? 3 : 10), _run);
    }
  }

  void _showOrder(TopupOrder order) {
    setState(() {
      _message = order.message;
      _phase = order.status == TopupOrderStatus.paid
          ? _Phase.success
          : order.status == TopupOrderStatus.exception
          ? _Phase.failure
          : _record.txid == null
          ? _Phase.unresolved
          : _Phase.processing;
    });
  }

  Future<void> _recoverTx() async {
    if (_polling) return;
    _timer?.cancel();
    _polling = true;
    final field = TextEditingController();
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('补交原付款交易'),
          content: TextField(
            controller: field,
            decoration: const InputDecoration(labelText: '原付款钱包中的交易编号'),
            autocorrect: false,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, field.text.trim()),
              child: const Text('核实原交易'),
            ),
          ],
        ),
      );
      if (value == null || !mounted) return;
      final canonical = _record.intent.network == TopupNetwork.solana
          ? value
          : value.toLowerCase();
      if (_record.signature == null ||
          !_record.intent.network.transaction(canonical)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('缺少原付款授权或交易编号无效')));
        return;
      }
      await _save(
        _record.update(progress: TopupProgress.submitted, txid: canonical),
      );
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('原订单记录未更新，请稍后核实')));
    } finally {
      field.dispose();
      _polling = false;
      await _run();
    }
  }

  Future<void> _replay() async {
    if (_polling) return;
    _timer?.cancel();
    _polling = true;
    try {
      final restored = await widget.onReplay(_record);
      if (restored != null) _record = restored;
    } finally {
      _polling = false;
      await _run();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支付结果'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaled(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(),
              SizedBox(height: AppLayout.scaled(context, 18)),
              Text(
                _title(),
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 18),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 6)),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 6)),
              Text(
                _record.txid == null
                    ? '原付款回执待核实'
                    : 'tx ${_shortHash(_record.txid!)}',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: AppTheme.textTertiary,
                  fontFamily: 'monospace',
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 28)),
              if (!_record.terminal &&
                  _record.txid == null &&
                  _record.signature != null)
                OutlinedButton(
                  onPressed: _recoverTx,
                  child: const Text('补交原付款交易'),
                ),
              if (!_record.terminal)
                TextButton(onPressed: _run, child: const Text('重新核实')),
              if (!_record.terminal &&
                  _record.wire != null &&
                  _record.txid != null &&
                  _record.intent.network.evmId == null &&
                  DateTime.now().millisecondsSinceEpoch <
                      _record.intent.expiresAt)
                OutlinedButton(
                  onPressed: _replay,
                  child: const Text('继续广播原交易'),
                ),
              if (_phase != _Phase.processing)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(
                        vertical: AppLayout.scaled(context, 13),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppLayout.scaledValue(14),
                        ),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(_phase == _Phase.success),
                    child: Text(
                      _phase == _Phase.success ? '查看钱包' : '返回',
                      style: TextStyle(fontSize: AppLayout.scaled(context, 15)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    switch (_phase) {
      case _Phase.processing:
        return SizedBox(
          width: AppLayout.scaledValue(64),
          height: AppLayout.scaledValue(64),
          child: const CircularProgressIndicator(color: AppTheme.primary),
        );
      case _Phase.success:
        return _circleIcon(Icons.check, AppTheme.success);
      case _Phase.failure:
        return _circleIcon(Icons.priority_high, AppTheme.danger);
      case _Phase.unresolved:
        return _circleIcon(Icons.hourglass_empty, AppTheme.warning);
    }
  }

  Widget _circleIcon(IconData icon, Color color) {
    return Container(
      width: AppLayout.scaledValue(72),
      height: AppLayout.scaledValue(72),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: AppLayout.scaledValue(38), color: color),
    );
  }

  String _title() {
    switch (_phase) {
      case _Phase.processing:
        return '处理中';
      case _Phase.success:
        return '已到账';
      case _Phase.failure:
        return '需要核查';
      case _Phase.unresolved:
        return '仍在确认';
    }
  }

  static String _shortHash(String hash) {
    if (hash.length <= 14) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';
  }
}
