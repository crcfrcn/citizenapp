// 充值接口、订单查询及付款事实校验。

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:citizen_network/http.dart';
import 'package:citizen_system/log.dart';
import 'package:citizen_topup/data.dart';
import 'package:citizen_topup/store.dart';

// 访问固定付款网络及发币服务，核验单轮链事实和签名通知。

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

  /// 单轮只访问所选付款网络；未验真不能标为已支付，30轮调度归App。
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

/// 每阶段最多30轮；付款核验和结果读取串行，已确认阶段不再查询。
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
  static const limit = 30;
  static int delay(int count) => count == 1
      ? 15000
      : count == 2
      ? 30000
      : 60000;
  final TopupApi api;
  final TopupStore store;
  final int Function() _now;
  final Timer Function(Duration, void Function()) _timer;
  final _timers = <String, Timer>{};
  final _checks = <String, Future<void>>{};
  final _records = <String, TopupRecord>{};
  final _deleted = <String>{},
      _acknowledging = <String>{},
      _recovering = <String>{};
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
        if (record.receipt?.sealed == true ||
            record.progress == TopupProgress.completed ||
            record.progress == TopupProgress.pending && record.terminal) {
          _timers.remove(key)?.cancel();
        }
        if (record.isPaid &&
            record.receipt?.sealed == true &&
            record.receipt?.acknowledged == false) {
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
          for (final record in await store.all()) {
            if (_active && !_deleted.contains(record.key)) {
              _records.putIfAbsent(record.key, () => record);
            }
          }
          _loaded = true;
        }().whenComplete(() => _loading = null);
  Future<void> _queue(Future<void> Function() operation) {
    final next = _tail.then((_) async {
      if (_active) {
        await operation();
      }
    });
    _tail = next.catchError((Object _) {
      AppLog.d('topup_result_unavailable');
    });
    return _tail;
  }

  void verifyPayment(TopupRecord record) {
    start();
    if (_deleted.contains(record.key)) {
      return;
    }
    _records.putIfAbsent(record.key, () => record);
    _schedule(_records[record.key]!);
  }

  /// 哈希仅是定位：先匹配原冻结交易，再沿原单独立验款，绝不调用钱包付款。
  Future<void> recoverPayment(TopupRecord original, String input) async {
    await _load();
    final key = original.key, record = _records[original.key] ?? original;
    final hash = input.trim().toLowerCase();
    if (!_active || _deleted.contains(key) || !_recovering.add(key)) {
      throw StateError('原付款正在核验或已结束');
    }
    try {
      if (record.progress != TopupProgress.pending ||
          record.terminal ||
          record.txid != null ||
          record.wire == null ||
          !record.payment.network.transaction(hash)) {
        throw const FormatException('原付款不可恢复或交易哈希无效');
      }
      final value = await api.paymentRpc(
        record.payment.network,
        'eth_getTransactionByHash',
        [hash],
      );
      final expected = erc20Transaction(record.payment, record.binding);
      if (value is! Map ||
          value['hash'] != hash ||
          value['to'] is! String ||
          (value['to'] as String).toLowerCase() != expected['to'] ||
          value['input'] is! String ||
          (value['input'] as String).toLowerCase() != expected['data'] ||
          value['value'] != '0x0' ||
          value['from'] is! String) {
        throw const FormatException('交易不属于原充值订单');
      }
      final payer = record.payment.network.address(value['from'] as String);
      if (!_active ||
          _deleted.contains(key) ||
          record.payer != null && record.payer != payer) {
        throw const FormatException('原付款已变化');
      }
      final located = record.update(
        txid: hash,
        payer: payer,
        clearFailure: true,
      );
      await store.save(located, before: record);
      _records[key] = located;
      _schedule(located);
    } finally {
      _recovering.remove(key);
    }
  }

  void _schedule(TopupRecord record) {
    final key = record.key;
    _timers.remove(key)?.cancel();
    if (!_active ||
        _deleted.contains(key) ||
        _checks.containsKey(key) ||
        record.txid == null ||
        record.wire == null ||
        record.progress == TopupProgress.completed ||
        record.receipt?.sealed == true ||
        record.progress == TopupProgress.pending && record.terminal ||
        record.progress == TopupProgress.paid && !record.isPaid) {
      return;
    }
    if (record.checkCount >= limit) {
      if (record.progress == TopupProgress.paid) {
        unawaited(_unresolved(key));
      } else {
        unawaited(
          _queue(() async {
            final current = _records[key];
            if (current == null || current.terminal || _deleted.contains(key)) {
              return;
            }
            final next = current.update(failureCode: 'payment_failed');
            await store.save(next, before: current);
            _records[key] = next;
          }),
        );
      }
      return;
    }
    final waiting = (record.checkAt ?? _now()) - _now();
    if (waiting > 0) {
      _timers[key] = _timer(Duration(milliseconds: waiting), () {
        _timers.remove(key);
        final current = _records[key];
        if (current != null) {
          _startCheck(current);
        }
      });
    } else {
      _startCheck(record);
    }
  }

  void _startCheck(TopupRecord record) {
    if (!_active || _checks.containsKey(record.key)) {
      return;
    }
    var continueChecking = true;
    final task =
        (record.progress == TopupProgress.pending
                ? _checkPayment(record)
                : _checkResult(record))
            .catchError((Object _) {
              continueChecking = false;
              AppLog.d('topup_check_unavailable');
            });
    _checks[record.key] = task;
    unawaited(
      task.whenComplete(() {
        _checks.remove(record.key);
        final current = _records[record.key];
        if (continueChecking && current != null) {
          _schedule(current);
        }
      }),
    );
  }

  Future<void> _checkPayment(TopupRecord before) async {
    if (before.checkCount >= limit) {
      return;
    }
    final count = before.checkCount + 1;
    final record = before.update(
      checkCount: count,
      checkAt: _now() + delay(count),
    );
    // 先持久消费次数；最后一轮进程退出也不追加第31轮。
    await store.save(record, before: before);
    _records[record.key] = record;
    try {
      final proof = await api.verifyPayment(
        record,
        isActive: () => _active && !_deleted.contains(record.key),
      );
      if (!_active || _deleted.contains(record.key)) {
        return;
      }
      final paid = await store.markPaid(record, proof);
      _records[record.key] = paid.record;
      await issue(paid);
    } on Object {
      if (!_active || _deleted.contains(record.key)) {
        return;
      }
      final current = _records[record.key] ?? record;
      if (current.progress != TopupProgress.pending ||
          current.txid != record.txid) {
        return;
      }
      final next = current.update(
        checkAt: _now() + delay(count),
        failureCode: count == limit ? 'payment_failed' : null,
      );
      await store.save(next, before: current);
      _records[record.key] = next;
    }
  }

  /// 唯一confirm能力仅消费一次，之后只读取原订单status。
  Future<void> issue(PaidTopupOrder paid) async {
    final record = paid.record;
    start();
    _records.putIfAbsent(record.key, () => record);
    try {
      final receipt = await api.requestIssuance(paid, notify: notify);
      await _accept(record.key, receipt);
    } on Object {
      if (_records[record.key]?.receipt == null) {
        await _unresolved(record.key);
      }
    } finally {
      final current = _records[record.key];
      if (current != null) {
        _schedule(current);
      }
    }
  }

  Future<void> _accept(String key, TopupReceipt receipt) => _queue(() async {
    final current = _records[key];
    if (_deleted.contains(key) ||
        current == null ||
        current.receipt?.sealed == true) {
      return;
    }
    _records[key] = await store.acceptReceipt(current, receipt);
    if (_records[key]?.receipt?.sealed == true) {
      _ack(key);
    }
  });
  Future<void> _unresolved(String key) => _queue(() async {
    final current = _records[key];
    if (_deleted.contains(key) ||
        current == null ||
        current.progress != TopupProgress.paid ||
        current.receipt?.sealed == true ||
        current.failureCode == 'issuance_request_unresolved') {
      return;
    }
    final next = current.update(failureCode: 'issuance_request_unresolved');
    await store.save(next, before: current);
    _records[key] = next;
  });
  Future<void> _checkResult(TopupRecord before) async {
    if (before.checkCount >= limit ||
        !before.isPaid ||
        before.receipt?.sealed == true) {
      return;
    }
    final count = before.checkCount + 1;
    final record = before.update(
      checkCount: count,
      checkAt: _now() + delay(count),
    );
    await store.save(record, before: before);
    _records[record.key] = record;
    try {
      await _accept(record.key, await api.recover(record, notify: notify));
    } on Object {
      AppLog.d('topup_restore_unavailable');
    }
    final current = _records[record.key];
    if (!_active ||
        _deleted.contains(record.key) ||
        current == null ||
        current.receipt?.sealed == true) {
      return;
    }
    if (count == limit) {
      await _unresolved(record.key);
    } else {
      final next = current.update(checkAt: _now() + delay(count));
      await store.save(next, before: current);
      _records[record.key] = next;
    }
  }

  Future<bool> receive(Map<String, dynamic> payload) async {
    if (payload['kind'] != 'topup_result') {
      return false;
    }
    await _queue(() async {
      await _load();
      final result = payload['result'];
      if (result is! Map) {
        return;
      }
      final key = '${result['service_origin']}|${result['order_id']}',
          record =
              _records['${result['service_origin']}|${result['order_id']}'];
      if (record == null || !record.isPaid || record.receipt == null) {
        return;
      }
      _records[key] = await store.acceptReceipt(
        record,
        TopupReceipt.notification(payload, record.receipt!),
      );
      _ack(key);
    });
    return true;
  }

  void _ack(String key) {
    if (!_active || !_acknowledging.add(key)) {
      return;
    }
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
          if (!_active || _deleted.contains(key)) {
            return;
          }
          if (!receipt.acknowledged) {
            throw const FormatException('服务端未确认ACK');
          }
          _records[key] = await store.acceptReceipt(record, receipt);
        } finally {
          _acknowledging.remove(key);
        }
      }),
    );
  }

  /// 恢复只续用持久次数和到期时刻；已验真阶段不重查。
  Future<void> resume() => _restoring ??=
      () async {
            await _load();
            if (!_active) {
              return;
            }
            for (final record in _records.values.toList()) {
              if (record.receipt?.sealed == true) {
                if (record.isPaid && record.receipt?.acknowledged == false) {
                  _ack(record.key);
                }
              } else {
                _schedule(record);
              }
            }
            await Future.wait(_checks.values.toList());
            await _tail;
          }()
          .catchError((Object _) {
            AppLog.d('topup_restore_unavailable');
          })
          .whenComplete(() => _restoring = null);
  Future<void> settle() async {
    do {
      await Future.wait(_checks.values.toList());
      await _tail;
    } while (_checks.isNotEmpty);
  }

  Future<void> close() async {
    _active = false;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    api.close();
    await _changes?.cancel();
    await Future.wait(_checks.values.toList());
    await _tail;
  }
}
