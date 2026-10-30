import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_transaction/offchain/offchain_clearing_rpc.dart';

class Rpc extends OffchainClearingBankRpc {
  Rpc(this.value) : super('wss://clearing.example');
  final Object? value;
  final calls = <String>[];
  @override
  Future<dynamic> call(String method, List<dynamic> params) async {
    calls.add(method);
    return value;
  }
}

class Socket extends Stream<dynamic> implements WebSocket {
  Socket(this.frames);
  final Stream<dynamic> frames;
  final sent = <String>[];
  bool closed = false;
  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => frames.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void add(dynamic value) {
    sent.add(value as String);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('未配置WebSocket能力');
}

void main() {
  test('RPC拒绝缺失、非整数和负nonce，不用默认1冒充真实响应', () async {
    for (final value in [null, 'invalid', 1.5, -1]) {
      await expectLater(
        Rpc(value).queryNextNonce('synthetic-account'),
        throwsFormatException,
      );
    }
  });
  test('费率只消费所属RPC的snake_case字段，不接受缺失或损坏数据', () async {
    for (final value in [
      {},
      {'rateBp': 10, 'minFeeFen': 1},
      {'rate_bp': -1, 'min_fee_fen': 1},
    ]) {
      await expectLater(
        Rpc(value).queryFeeRate('synthetic-bank'),
        throwsFormatException,
      );
    }
  });
  test('付款ACK缺少签名或接受时间必须拒绝', () async {
    await expectLater(
      Rpc({'tx_id': '0x${'01' * 32}'}).submitPayment(
        expectedTxId: '0x${'01' * 32}',
        intentHex: '0x00',
        payerSigHex: '0x00',
      ),
      throwsFormatException,
    );
  });
  test('别笔有效ACK不能冒充本笔付款，坏本地标识在发送前拒绝', () async {
    final rpc = Rpc({
      'tx_id': '0x${'02' * 32}',
      'l2_ack_sig': '0x${'03' * 64}',
      'accepted_at': 10,
    });
    await expectLater(
      rpc.submitPayment(
        expectedTxId: '0x${'01' * 32}',
        intentHex: '0x00',
        payerSigHex: '0x00',
      ),
      throwsFormatException,
    );
    final unsent = Rpc(null);
    await expectLater(
      unsent.submitPayment(
        expectedTxId: 'bad',
        intentHex: '0x00',
        payerSigHex: '0x00',
      ),
      throwsArgumentError,
    );
    expect(unsent.calls, isEmpty);
  });
  test('构造时拒绝明文或无效清算端点', () {
    for (final url in [
      'ws://clearing.example',
      'https://clearing.example',
      'wss:',
      'invalid',
    ]) {
      expect(() => OffchainClearingBankRpc(url), throwsArgumentError);
    }
  });
  test('真实方法名和snake_case响应，规范整数不取默认值', () async {
    expect(await Rpc(3).queryNextNonce('account'), 3);
    expect(await Rpc('0').queryPendingCount(), 0);
    expect(await Rpc(null).queryUserBank('account'), null);
    expect(await Rpc({'rate_bp': 0, 'min_fee_fen': '1'}).queryFeeRate('bank'), (
      rateBp: 0,
      minFeeFen: 1,
    ));
    final receipt =
        await Rpc({
          'tx_id': '0x${'01' * 32}',
          'l2_ack_sig': '0x${'02' * 64}',
          'accepted_at': 10,
        }).submitPayment(
          expectedTxId: '0x${'01' * 32}',
          intentHex: '0x00',
          payerSigHex: '0x00',
        );
    expect(receipt.acceptedAt, 10);
  });
  test('WSS传输请求及响应ID一致，成功和协议/远端/流失败均关闭连接', () async {
    for (final mode in [
      'ok',
      'id',
      'jsonrpc',
      'missing',
      'both',
      'error',
      'binary',
      'json',
      'stream',
    ]) {
      final response = <String, dynamic>{
        'jsonrpc': mode == 'jsonrpc' ? '1.0' : '2.0',
        'id': mode == 'id' ? 2 : 1,
        'result': 3,
      };
      if (mode == 'missing') response.remove('result');
      if (mode == 'both' || mode == 'error') {
        response['error'] = {'code': -1, 'message': '合成远端错误'};
        if (mode == 'error') response.remove('result');
      }
      final socket = Socket(
        mode == 'stream'
            ? Stream.error(StateError('合成断流'))
            : Stream.value(
                mode == 'binary'
                    ? <int>[0]
                    : mode == 'json'
                    ? 'invalid'
                    : jsonEncode(response),
              ),
      );
      final rpc = OffchainClearingBankRpc(
        'wss://clearing.example',
        connect: (url) async {
          expect(url, 'wss://clearing.example');
          return socket;
        },
      );
      if (mode == 'ok') {
        expect(await rpc.queryNextNonce('account'), 3);
      } else {
        await expectLater(rpc.queryNextNonce('account'), throwsA(anything));
      }
      expect(socket.closed, true);
      expect(jsonDecode(socket.sent.single), {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'offchain_queryNextNonce',
        'params': ['account'],
      });
    }
  });
  test('连接失败原样传播，没有自动重试付款', () async {
    var calls = 0;
    final failure = StateError('合成连接失败');
    final rpc = OffchainClearingBankRpc(
      'wss://clearing.example',
      connect: (_) async {
        calls++;
        throw failure;
      },
    );
    await expectLater(
      rpc.submitPayment(
        expectedTxId: '0x${'01' * 32}',
        intentHex: '0x00',
        payerSigHex: '0x00',
      ),
      throwsA(same(failure)),
    );
    expect(calls, 1);
  });
  testWidgets('响应超时关闭本次连接，不自动重发', (tester) async {
    final frames = StreamController<dynamic>();
    final hanging = Socket(frames.stream);
    final rpc = OffchainClearingBankRpc(
      'wss://clearing.example',
      connect: (_) async => hanging,
    );
    final result = expectLater(
      rpc.queryPendingCount(),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await result;
    expect(hanging.closed, true);
    expect(hanging.sent.length, 1);
    await frames.close();
  });
  testWidgets('连接超时后的迟到socket关闭，零付款请求', (tester) async {
    final connection = Completer<WebSocket>(),
        socket = Socket(const Stream.empty());
    final rpc = OffchainClearingBankRpc(
      'wss://clearing.example',
      connect: (_) => connection.future,
    );
    final result = expectLater(
      rpc.queryPendingCount(),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await result;
    connection.complete(socket);
    await tester.pump();
    expect(socket.closed, true);
    expect(socket.sent, isEmpty);
  });
}
