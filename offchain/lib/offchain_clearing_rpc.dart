import 'dart:convert';
import 'dart:async';
import 'dart:io';

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
