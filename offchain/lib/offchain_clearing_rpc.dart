import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:flutter/foundation.dart';

/// 清算行所属JSON-RPC客户端；方法与字段直接沿用节点公开合同。
class OffchainClearingBankRpc {
  OffchainClearingBankRpc(
    this.wssUrl, {
    Future<WebSocket> Function(String)? connect,
  }) : _connect = connect ?? WebSocket.connect {
    final uri = Uri.tryParse(wssUrl);
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ArgumentError('清算端点必须为有效WSS地址');
    }
  }
  final String wssUrl;
  final Future<WebSocket> Function(String) _connect;

  Future<BigInt> queryBalance(String accountAddress) async {
    final raw = await call('offchain_queryBalance', [accountAddress]);
    final value = raw is int
        ? BigInt.from(raw)
        : raw is String
        ? BigInt.tryParse(raw)
        : null;
    if (value == null || value.isNegative) {
      throw const FormatException('清算行余额必须为非负整数分');
    }
    return value;
  }

  Future<int> queryNextNonce(String userAccountId) async =>
      _integer(await call('offchain_queryNextNonce', [userAccountId]), min: 1);

  Future<int> queryPendingCount() async =>
      _integer(await call('offchain_queryPendingCount', const []));

  Future<String?> queryUserBank(String userAccountId) async {
    final result = await call('offchain_queryUserBank', [userAccountId]);
    if (result == null) return null;
    if (result is! String || result.isEmpty) {
      throw const FormatException('清算行CID响应无效');
    }
    return result;
  }

  Future<({int rateBp, int minFeeFen})> queryFeeRate(String bankCid) async {
    final value = _object(await call('offchain_queryFeeRate', [bankCid]));
    final rate = _integer(value['rate_bp']);
    if (rate > 0xffffffff) throw const FormatException('清算费率超出u32');
    return (rateBp: rate, minFeeFen: _integer(value['min_fee_fen'], min: 1));
  }

  Future<({String txId, String l2AckSig, int acceptedAt})> submitPayment({
    required String expectedTxId,
    required String intentHex,
    required String payerSigHex,
  }) async {
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(expectedTxId)) {
      throw ArgumentError('本次付款交易标识无效');
    }
    final value = _object(
      await call('offchain_submitPayment', [intentHex, payerSigHex]),
    );
    final txId = value['tx_id'], signature = value['l2_ack_sig'];
    if (txId is! String ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(txId) ||
        txId != expectedTxId ||
        signature is! String ||
        !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(signature)) {
      throw const FormatException('清算付款ACK交易标识不匹配或签名格式无效');
    }
    return (
      txId: txId,
      l2AckSig: signature,
      acceptedAt: _integer(value['accepted_at']),
    );
  }

  /// 每次调用独占WSS连接；验证JSON-RPC身份、响应ID与互斥结果，所有出口关闭连接。
  Future<dynamic> call(String method, List<dynamic> params) async {
    final connecting = _connect(wssUrl);
    final ws = await connecting.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        // 超时后才建立的连接也属于本次调用，关闭它且绝不发送迟到请求。
        unawaited(
          connecting.then<void>((late) async {
            try {
              await late.close();
            } catch (_) {}
          }, onError: (Object _) {}),
        );
        throw TimeoutException('清算行连接超时');
      },
    );
    try {
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': params,
        }),
      );
      final frame = await ws.first.timeout(const Duration(seconds: 15));
      if (frame is! String) throw const FormatException('清算RPC必须返回JSON文本');
      final value = _object(jsonDecode(frame));
      if (value['jsonrpc'] != '2.0' ||
          value['id'] != 1 ||
          value['id'] is! int ||
          value.containsKey('result') == value.containsKey('error')) {
        throw const FormatException('清算JSON-RPC响应不匹配');
      }
      if (value.containsKey('error')) {
        final error = _object(value['error']);
        if (error['code'] is! int || error['message'] is! String) {
          throw const FormatException('清算RPC错误格式无效');
        }
        // 不将付款参数或任意远端正文交给日志出口。
        throw StateError('清算行RPC失败：${error['code']}');
      }
      return value['result'];
    } finally {
      await ws.close();
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('清算RPC对象格式无效');
    }
    return value;
  }

  static int _integer(Object? value, {int min = 0}) {
    final int? number = value is int
        ? value
        : value is String && RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)
        ? int.tryParse(value)
        : null;
    if (number == null || number < min) {
      throw const FormatException('清算RPC整数无效');
    }
    return number;
  }
}

/// 零钱包、提现和钱包操作卡共用同一账户与清算行端点的余额状态。
final class ClearingBalances {
  ClearingBalances({OffchainClearingBankRpc Function(String)? rpc})
    : _rpc = rpc ?? OffchainClearingBankRpc.new;

  static final instance = ClearingBalances();
  final OffchainClearingBankRpc Function(String) _rpc;
  final _states = <(String, String), ClearingBalance>{};
  final _removals = <String, Future<void>>{};

  ClearingBalance state({required String accountId, required String wssUrl}) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写十六进制账户');
    }
    if (_removals.containsKey(accountId)) {
      return ClearingBalance._(accountId, wssUrl, _rpc).._invalidate();
    }
    return _states.putIfAbsent(
      (accountId, wssUrl),
      () => ClearingBalance._(accountId, wssUrl, _rpc),
    );
  }

  Future<void> remove(Iterable<String> accountIds) async {
    await Future.wait(accountIds.toSet().map(_remove));
  }

  Future<void> _remove(String accountId) => _removals.putIfAbsent(
    accountId,
    () => Future<void>.microtask(() async {
      try {
        final keys = _states.keys.where((key) => key.$1 == accountId).toList();
        for (final key in keys) {
          _states.remove(key)?._invalidate();
        }
        // 先禁用旧状态，再将清理排在已入队的余额写入之后。
        await UserIsar.instance.removeClearingBalances(accountId);
      } finally {
        _removals.remove(accountId);
      }
    }),
  );

  /// 整库擦除沿用 UserIsar 关闭流程。尚未入队的旧响应立即失效。
  void invalidateAll() {
    final states = _states.values.toList();
    _states.clear();
    for (final state in states) {
      state._invalidate();
    }
  }
}

final class ClearingBalance extends ChangeNotifier {
  ClearingBalance._(this._accountId, this._wssUrl, this._rpc);

  final String _accountId;
  final String _wssUrl;
  final OffchainClearingBankRpc Function(String) _rpc;
  BigInt? _value;
  bool _hasError = false;
  bool _valid = true;
  bool _forceRefresh = false;
  Future<BigInt>? _loading;

  BigInt? get value => _value;
  bool get hasError => _hasError;

  Future<void> load({bool forceRefresh = false}) async {
    try {
      await _read(forceRefresh: forceRefresh);
    } catch (_) {
      // 展示通过 hasError 提示失败，保留最后一次成功金额。
    }
  }

  /// 提现预检必须取得本次节点结果。失败直接交给提交方。
  Future<BigInt> refresh() => _read(forceRefresh: true);

  Future<BigInt> _read({required bool forceRefresh}) {
    if (!_valid) return Future.error(StateError('清算余额已失效'));
    final cached = _value;
    if (!forceRefresh && cached != null) return Future.value(cached);
    final loading = _loading;
    if (loading != null) {
      // 提现可能加入正在读磁盘的首屏任务。该轮必须继续查询节点。
      if (forceRefresh) _forceRefresh = true;
      return loading;
    }
    _forceRefresh = forceRefresh;
    return _loading = Future<BigInt>.microtask(() async {
      try {
        _requireValid();
        _hasError = false;
        notifyListeners();
        final rpc = _rpc(_wssUrl);
        final store = UserIsar.instance;
        var fen = _forceRefresh
            ? null
            : await store.readClearingBalance(_accountId, _wssUrl);
        _requireValid();
        if (_forceRefresh || fen == null) {
          fen = await rpc.queryBalance(citizenSs58FromAccountId(_accountId));
          _requireValid();
          await store.writeClearingBalance(_accountId, _wssUrl, fen);
        }
        _requireValid();
        _value = fen;
        return fen;
      } catch (_) {
        if (_valid) _hasError = true;
        rethrow;
      } finally {
        _loading = null;
        if (_valid) notifyListeners();
      }
    });
  }

  void _requireValid() {
    if (!_valid) throw StateError('清算余额已失效');
  }

  void _invalidate() {
    _valid = false;
    _value = null;
    _hasError = false;
    notifyListeners();
  }
}
