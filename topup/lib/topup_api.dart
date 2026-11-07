import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:citizen_network/chain_bootstrap_api.dart' show HttpsOnlyClient;
import 'package:citizen_network/citizen_serve_api_config.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_topup/topup_models.dart';
import 'package:citizen_topup/topup_erc20.dart';
import 'package:citizen_topup/store.dart';

class TopupApiException implements Exception {
  const TopupApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 付款链与发币服务分离。这里没有付款前配置、预建单或公民链读取接口。
class TopupApi {
  TopupApi({
    String baseUrl = CitizenServeApiConfig.production,
    http.Client? httpClient,
  }) : baseUrl = CitizenServeApiConfig.normalize(baseUrl),
       _http = HttpsOnlyClient(httpClient ?? http.Client());
  final String baseUrl;
  final http.Client _http;
  void close() => _http.close();

  /// 单轮只访问所选付款网络；未验真不能标为已支付，11轮调度归App。
  Future<TopupProof> verifyPayment(
    TopupRecord record, {
    bool Function()? isActive,
    int? now,
  }) async {
    if (record.progress != TopupProgress.pending ||
        record.txid == null ||
        record.terminal) {
      throw StateError('只有钱包已提交的原付款可以验款');
    }
    record.payment.validateCatalog(TopupConfig.local());
    Future<Object?> rpc(String method, List<Object?> params) async {
      if (isActive != null && !isActive()) throw const TopupDeletedException();
      final result = await paymentRpc(record.payment.network, method, params);
      if (isActive != null && !isActive()) throw const TopupDeletedException();
      return result;
    }

    final payment = record.payment;
    final proof = await verifyErc20Payment(
      payment,
      record.payer,
      record.txid!,
      rpc,
      binding: record.binding,
      now: now,
    );
    if (!proof.matches(payment, proof.payer, record.txid!) ||
        record.payer != null && record.payer != proof.payer) {
      throw const FormatException('付款证据不属于原充值订单');
    }
    return proof;
  }

  /// 生产调用只接受固定网络/闭集方法，不接收网页给出的URL。
  Future<Object?> paymentRpc(
    TopupNetwork network,
    String method,
    List<Object?> params,
  ) async {
    const allowed = {
      'eth_chainId',
      'eth_getTransactionReceipt',
      'eth_getTransactionByHash',
      'eth_getBlockByNumber',
    };
    if (!allowed.contains(method)) throw const FormatException('未允许的付款节点请求');
    final endpoint = TopupRpcConfig.endpoint(network);
    final response = await _http
        .post(
          Uri.parse(endpoint),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 || response.bodyBytes.length > 1024 * 1024) {
      throw const TopupApiException('付款网络未返回可核实结果');
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('付款网络返回结构无效');
    }
    if (value['jsonrpc'] != '2.0' ||
        value['id'] != 1 ||
        value.containsKey('error') ||
        !value.containsKey('result')) {
      throw const TopupApiException('付款网络暂未返回可核实结果');
    }
    return value['result'];
  }

  /// 保存已支付后的单次请求能力只能由TopupStore生成，阻止未落库已支付数据上报。
  /// 用户指定仅发送一次；超时、拒绝及进程退出都不自动重发。
  Future<TopupReceipt> requestIssuance(
    PaidTopupOrder saved, {
    Map<String, Object?>? notify,
  }) async {
    final body = saved.take(notify: notify);
    if (!saved.record.isPaid ||
        saved.record.origin != Uri.parse(baseUrl).origin) {
      throw StateError('未保存已支付或服务来源不一致');
    }
    return _sendReceipt('confirm', body, saved.record);
  }

  /// 只读取已支付原单的持久快照；ACK不创建订单，不重验付款或触发发币。
  Future<TopupReceipt> recover(
    TopupRecord record, {
    bool acknowledge = false,
    Map<String, Object?>? notify,
  }) {
    if (!record.isPaid ||
        record.requestAt == null ||
        record.origin != Uri.parse(baseUrl).origin) {
      throw StateError('禁止恢复未支付原单');
    }
    if (acknowledge &&
        (!const {
              TopupProgress.completed,
              TopupProgress.paid,
            }.contains(record.progress) ||
            record.receipt?.sealed != true)) {
      throw StateError('结果落库前禁止ACK');
    }
    return _sendReceipt('status', {
      'order_id': record.payment.orderId,
      'recovery_token': record.recoveryToken,
      'ack_rev': acknowledge ? record.receipt!.revision : null,
      'notify': notify,
    }, record);
  }

  Future<TopupReceipt> _sendReceipt(
    String path,
    Map<String, Object?> body,
    TopupRecord record,
  ) async {
    final response = await _http
        .post(
          Uri.parse('$baseUrl/topup/$path'),
          headers: const {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.bodyBytes.length > 65536) {
      throw const TopupApiException('发币服务响应过大，原付款保留');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map<String, dynamic> ||
        data['is_ok'] != true ||
        data['order_id'] != record.payment.orderId ||
        data['payment_txid'] != record.txid) {
      throw const TopupApiException('发币请求未确认，已支付订单保留');
    }
    final receipt = TopupReceipt.fromJson(data);
    receipt.matches(record.payment, record.txid!);
    // 只确认请求受理；不得由普通HTTP回执宣称公民币到账。
    return receipt;
  }
}

/// App持有付款链11轮验款及发币结果；独立于付款页、会员和CID，不重新付款。
class TopupUpdates {
  TopupUpdates({
    TopupApi? api,
    TopupStore? store,
    int Function()? now,
    Timer Function(Duration, void Function())? timer,
  }) : api = api ?? TopupApi(),
       store = store ?? TopupStore.shared,
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       _timer = timer ?? ((delay, callback) => Timer(delay, callback));
  final TopupApi api;
  final TopupStore store;
  final int Function() _now;
  final Timer Function(Duration, void Function()) _timer;
  final _timers = <String, Timer>{};
  final _payments = <String, Future<void>>{};
  final _records = <String, TopupRecord>{},
      _deleted = <String>{},
      _acknowledging = <String>{};
  StreamSubscription<TopupChange>? _changes;
  Future<void> _tail = Future<void>.value();
  Future<void>? _loading, _restoring;
  bool _loaded = false, _active = true;
  Map<String, Object?>? notify;
  void start() {
    _changes ??= TopupStore.changes.listen((change) {
      final key = '${change.origin}|${change.orderId}';
      if (change.record == null) {
        _records.remove(key);
        _deleted.add(key);
        _timers.remove(key)?.cancel();
        return;
      }
      try {
        final record = TopupStore.fromEntry(change.record!);
        _records[key] = record;
        if (record.terminal) _timers.remove(key)?.cancel();
        if (record.isPaid &&
            record.receipt?.sealed == true &&
            record.receipt?.acknowledged == false &&
            const {
              TopupProgress.completed,
              TopupProgress.paid,
            }.contains(record.progress)) {
          _ack(key);
        }
      } on Object {
        _records.remove(key);
      }
    });
  }

  Future<void> _load() => _loaded
      ? Future<void>.value()
      : _loading ??= () async {
          start();
          final rows = await store.all();
          if (!_active) return;
          for (final record in rows) {
            if (!_deleted.contains(record.key)) {
              _records.putIfAbsent(record.key, () => record);
            }
          }
          _loaded = true;
        }().whenComplete(() => _loading = null);
  Future<void> _queue(Future<void> Function() operation) {
    final next = _tail.then((_) async {
      if (_active) await operation();
    });
    _tail = next.catchError((Object _) {
      AppLog.d('topup_result_unavailable');
    });
    return _tail;
  }

  /// 付款回执只交给App；网页不声明已支付，返回账户页面后仍按原单验款。
  void verifyPayment(TopupRecord record) {
    start();
    if (_deleted.contains(record.key)) return;
    _records.putIfAbsent(record.key, () => record);
    _schedulePayment(_records[record.key]!);
  }

  void _schedulePayment(TopupRecord record) {
    final key = record.key;
    _timers.remove(key)?.cancel();
    if (!_active ||
        _deleted.contains(key) ||
        _payments.containsKey(key) ||
        record.terminal ||
        record.txid == null ||
        record.wire == null) {
      return;
    }
    final delay = (record.checkAt ?? _now()) - _now();
    if (delay > 0) {
      _timers[key] = _timer(Duration(milliseconds: delay), () {
        _timers.remove(key);
        final current = _records[key];
        if (current != null) _startPayment(current);
      });
    } else {
      _startPayment(record);
    }
  }

  void _startPayment(TopupRecord record) {
    if (!_active || _payments.containsKey(record.key)) return;
    final task = _checkPayment(record).catchError((Object _) {
      AppLog.d('topup_payment_unavailable');
    });
    _payments[record.key] = task;
    unawaited(
      task.whenComplete(() {
        _payments.remove(record.key);
        final current = _records[record.key];
        if (current != null) _schedulePayment(current);
      }),
    );
  }

  Future<void> _checkPayment(TopupRecord before) async {
    if (before.checkCount >= 11) {
      // 进程在最后一轮退出也不追加第12轮，保留三种业务状态和失败原因。
      await store.save(
        before.update(failureCode: 'payment_failed'),
        before: before,
      );
      return;
    }
    final count = before.checkCount + 1;
    final record = before.update(
      checkCount: count,
      checkAt: _now() + (count < 11 ? 20000 * (1 << (count - 1)) : 0),
    );
    // 每轮先持久消费次数及下一到期时间；退出/回前台不能重置预算。
    await store.save(record, before: before);
    try {
      final proof = await api.verifyPayment(
        record,
        isActive: () => _active && !_deleted.contains(record.key),
      );
      if (!_active || _deleted.contains(record.key)) return;
      final paid = await store.markPaid(record, proof);
      await issue(paid);
    } on Object {
      if (!_active || _deleted.contains(record.key)) return;
      if (count == 11) {
        await store.save(
          record.update(failureCode: 'payment_failed'),
          before: record,
        );
      } else {
        // 失败返回后才开始完整退避，不能扣掉本轮RPC消耗的时间。
        await store.save(
          record.update(checkAt: _now() + 20000 * (1 << (count - 1))),
          before: record,
        );
      }
    }
  }

  /// 已支付请求归App所有；调用即消费唯一能力并发送，不受付款页销毁影响。
  Future<void> issue(PaidTopupOrder paid) async {
    final record = paid.record;
    try {
      final receipt = await api.requestIssuance(paid, notify: notify);
      await _queue(() async {
        if (_deleted.contains(record.key)) return;
        await store.acceptReceipt(_records[record.key] ?? record, receipt);
      });
    } on Object {
      await _queue(() async {
        final current = _records[record.key] ?? record;
        if (_deleted.contains(record.key) ||
            current.progress != TopupProgress.paid ||
            current.receipt != null) {
          return;
        }
        await store.save(
          current.update(failureCode: 'issuance_request_unresolved'),
          before: current,
        );
      });
    }
  }

  Future<bool> receive(Map<String, dynamic> payload) async {
    if (payload['kind'] != 'topup_result') return false;
    await _queue(() async {
      await _load();
      if (!_active) return;
      final result = payload['result'];
      if (result is! Map) return;
      final key = '${result['service_origin']}|${result['order_id']}',
          record =
              _records['${result['service_origin']}|${result['order_id']}'];
      if (record == null || !record.isPaid || record.receipt == null) return;
      final receipt = TopupReceipt.notification(payload, record.receipt!);
      if (!_active) return;
      await store.acceptReceipt(record, receipt);
      _ack(key);
    });
    return true;
  }

  void _ack(String key) {
    if (!_active || !_acknowledging.add(key)) return;
    unawaited(
      _queue(() async {
        try {
          final record = _records[key];
          if (record == null ||
              !record.isPaid ||
              record.receipt?.sealed != true ||
              record.receipt?.acknowledged == true) {
            return;
          }
          final receipt = await api.recover(
            record,
            acknowledge: true,
            notify: notify,
          );
          if (!_active) return;
          if (!receipt.acknowledged) throw const FormatException('服务端未确认ACK');
          await store.acceptReceipt(record, receipt);
        } finally {
          _acknowledging.remove(key);
        }
      }),
    );
  }

  /// 回前台按已存次数/到期时间续查付款链；已支付原单一次恢复，完成后只补ACK。
  Future<void> resume() => _restoring ??= _queue(() async {
    await _load();
    if (!_active) return;
    for (final key in _records.keys.toList()) {
      final record = _records[key];
      if (record == null) continue;
      if (record.progress == TopupProgress.pending) {
        _schedulePayment(record);
        continue;
      }
      if (!record.isPaid || record.requestAt == null) continue;
      if (record.receipt?.sealed == true &&
          const {
            TopupProgress.completed,
            TopupProgress.paid,
          }.contains(record.progress)) {
        if (record.receipt?.acknowledged == false) _ack(key);
        continue;
      }
      try {
        final receipt = await api.recover(record, notify: notify);
        if (!_active) return;
        await store.acceptReceipt(record, receipt);
      } on Object {
        AppLog.d('topup_restore_unavailable');
      }
    }
  }).whenComplete(() => _restoring = null);
  Future<void> settle() async {
    await Future.wait(_payments.values.toList());
    await _tail;
  }

  Future<void> close() async {
    _active = false;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    api.close();
    await _changes?.cancel();
    await Future.wait(_payments.values.toList());
    await _tail;
  }
}
