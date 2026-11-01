import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart' as storage;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fixture.dart';
import 'package:citizen_transaction/history/local_tx_store.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/topup_api.dart';

// 显式测试端口只驱动App调度；三协议真实解析另由付款链夹具回归覆盖。
class PaymentApi extends TopupApi {
  PaymentApi(this.verify, {required super.httpClient});
  final Future<TopupProof> Function(TopupRecord) verify;
  @override
  Future<TopupProof> verifyPayment(
    TopupRecord record, {
    bool Function()? isActive,
    int? now,
  }) => verify(record);
}

class PaymentTimer implements Timer {
  PaymentTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int get tick => isActive ? 0 : 1;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (isActive) {
      isActive = false;
      callback();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late TopupRecord record;
  late TopupStore store;
  setUp(() {
    store = TopupStore();
    final catalog = TopupConfig.local();
    record = TopupRecord.signed(
      TopupDraft.create(
        TopupSelection(
          token: 'USDC',
          package: catalog.packages.first,
          network: TopupNetwork.base,
        ),
        '0x${'04' * 32}',
      ),
      TopupWallets.ids.first,
      '0x${'01' * 64}',
      now: 1000000,
    );
  });
  TopupProof proof(TopupRecord value) => TopupProof.fromJson({
    'network': value.payment.network.wire,
    'payment_txid': value.txid,
    'payer_address': value.payer,
    'asset': value.payment.asset,
    'recv_address': value.payment.recvAddress,
    'pay_amount': value.payment.payAmount,
    'binding_hash': value.binding,
    'block_hash': '0x${'03' * 32}',
    'block_number': 10,
    'block_at': 1000000,
    'transfer_index': 0,
    'checked_at': 1000000,
    'finalized': true,
    'succeeded': true,
  });
  Future<TopupRecord> submitted() async {
    await store.save(record);
    final connected = record.update(
      progress: TopupProgress.pending,
      payer: '0x${'01' * 20}',
    );
    await store.save(connected, before: record);
    final sending = connected.update(
      wire: 'synthetic original EVM transaction',
    );
    await store.save(sending, before: connected);
    final sent = sending.update(
      progress: TopupProgress.pending,
      txid: '0x${'02' * 32}',
    );
    await store.save(sent, before: sending);
    return sent;
  }

  Map<String, dynamic> response(TopupRecord paid, {String? publicKey}) => {
    'is_ok': true,
    'order_id': paid.payment.orderId,
    'order_rev': 1,
    'order_state': 'verifying',
    'payment_txid': paid.txid,
    'gmb_tx_hash': null,
    'coin_fen': paid.payment.coinFen,
    'exception_reason': null,
    'is_reused': false,
    'auto_final': false,
    'chain_state': 'unverified',
    'result_ack': false,
    'result_publickey': publicKey ?? '0x${'03' * 32}',
    'result': null,
    'result_signature': null,
  };
  Future<TopupReceipt> sealed(TopupRecord paid, {String state = 'paid'}) async {
    // 官方公开开发向量；不连接网络，不使用任何环境签名账户。
    final pair = await Keyring().fromUri('//Alice');
    String hex(List<int> bytes) =>
        '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final key = hex(pair.publicKey.bytes),
        result = <String, dynamic>{
          'service_origin': paid.origin,
          'order_id': paid.payment.orderId,
          'result_rev': 4,
          'account_id': paid.payment.accountId,
          'payment_txid': paid.txid,
          'gmb_tx_hash': state == 'paid' ? '0x${'09' * 32}' : null,
          'coin_fen': paid.payment.coinFen,
          'order_state': state,
          'chain_state': state == 'paid' ? 'finalized_success' : 'unverified',
          'exception_reason': state == 'paid'
              ? null
              : 'topup_gmb_confirmation_timeout',
          'finished_at': 1001000,
        };
    final body = {
      ...response(paid, publicKey: key),
      'order_rev': 4,
      'order_state': state,
      'auto_final': true,
      'chain_state': result['chain_state'],
      'gmb_tx_hash': result['gmb_tx_hash'],
      'exception_reason': result['exception_reason'],
      'result': result,
      'result_signature': '0x${'00' * 64}',
    };
    final draft = TopupReceipt.fromJson(body);
    body['result_signature'] = hex(
      pair.sign(Uint8List.fromList(utf8.encode(draft.signedText))),
    );
    return TopupReceipt.fromJson(body);
  }

  Future<TopupRecord> accepted(TopupRecord sent, TopupReceipt result) async {
    final saved = await store.markPaid(sent, proof(sent));
    return store.acceptReceipt(
      saved.record,
      TopupReceipt.fromJson(
        response(saved.record, publicKey: result.publicKey),
      ),
    );
  }

  test('真实SDK验真结果后更新原行再ACK，重复通知零重复收入和零额外ACK', () async {
    final sent = await submitted(),
        result = await sealed(await Future.value(sent));
    final paid = await accepted(sent, result);
    var calls = 0;
    final api = TopupApi(
      httpClient: MockClient((r) async {
        calls++;
        expect(r.url.path, '/api/topup/status');
        final body = jsonDecode(r.body) as Map;
        expect(body.keys.toSet(), {
          'order_id',
          'recovery_token',
          'ack_rev',
          'notify',
        });
        expect(body['ack_rev'], 4);
        expect(
          (await LocalTxStore.queryByAccountId(
            record.payment.accountId,
          )).single.entryState,
          'completed',
        );
        return http.Response(
          jsonEncode({...result.toJson(), 'result_ack': true}),
          200,
        );
      }),
    );
    final updates = TopupUpdates(api: api, store: store)..start();
    final payload = <String, dynamic>{
      'kind': 'topup_result',
      'result': result.toJson()['result'],
      'result_signature': result.resultSignature,
    };
    try {
      expect(await updates.receive(payload), true);
      await updates.settle();
      var rows = await LocalTxStore.queryByAccountId(record.payment.accountId);
      expect(rows.length, 1);
      expect(rows.single.entryState, 'completed');
      expect(rows.single.amountDelta, paid.payment.coinFen);
      expect(TopupStore.fromEntry(rows.single).receipt!.acknowledged, true);
      expect(calls, 1);
      await updates.receive(payload);
      await updates.settle();
      await updates.resume();
      await updates.settle();
      rows = await LocalTxStore.queryByAccountId(record.payment.accountId);
      expect(rows.length, 1);
      expect(calls, 1);
    } finally {
      await updates.close();
    }
  });
  test('伪签名、换目标、推送自带公钥和旧修订均不落库、不ACK', () async {
    final sent = await submitted(),
        result = await sealed(await Future.value(sent));
    await accepted(sent, result);
    var calls = 0;
    final updates = TopupUpdates(
      api: TopupApi(
        httpClient: MockClient((r) async {
          calls++;
          throw StateError('unexpected');
        }),
      ),
      store: store,
    )..start();
    final raw = result.toJson()['result'] as Map<String, dynamic>;
    try {
      for (final payload in <Map<String, dynamic>>[
        {
          'kind': 'topup_result',
          'result': raw,
          'result_signature': '0x${'00' * 64}',
        },
        {
          'kind': 'topup_result',
          'result': {...raw, 'account_id': '0x${'08' * 32}'},
          'result_signature': result.resultSignature,
        },
        {
          'kind': 'topup_result',
          'result': raw,
          'result_signature': result.resultSignature,
          'result_publickey': result.publicKey,
        },
        {
          'kind': 'topup_result',
          'result': {...raw, 'result_rev': 0},
          'result_signature': result.resultSignature,
        },
      ]) {
        await updates.receive(payload);
        await updates.settle();
      }
      expect(calls, 0);
      expect(
        (await LocalTxStore.queryByAccountId(
          record.payment.accountId,
        )).single.entryState,
        'paid',
      );
    } finally {
      await updates.close();
    }
  });
  test('服务端确认超时的签名结果保留已支付事实，不伪造链上失败', () async {
    final sent = await submitted(),
        result = await sealed(await Future.value(sent), state: 'exception');
    final paid = await accepted(sent, result);
    final end = await store.acceptReceipt(paid, result);
    expect(end.progress, TopupProgress.paid);
    expect(end.isPaid, true);
    final row = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single;
    expect(row.amountDelta, '0');
    expect(end.receipt!.toJson()['chain_state'], 'unverified');
  });
  test('回前台只恢复已支付原单，同轮并发恢复合并且不发第二次发币请求', () async {
    var calls = 0;
    final gate = Completer<void>();
    TopupRecord? sent;
    final updates = TopupUpdates(
      api: TopupApi(
        httpClient: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/topup/status');
          await gate.future;
          return http.Response(jsonEncode(response(sent!)), 200);
        }),
      ),
      store: store,
    )..start();
    try {
      await store.save(record);
      await updates.resume();
      expect(calls, 0);
      sent = await submitted();
      await store.markPaid(sent, proof(sent));
      final first = updates.resume(), second = updates.resume();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([first, second]);
      await updates.settle();
      expect(calls, 1);
    } finally {
      await updates.close();
    }
  });
  test('删除后的合法通知不能重建原单或发送ACK', () async {
    final sent = await submitted(),
        result = await sealed(await Future.value(sent));
    await accepted(sent, result);
    var calls = 0;
    final updates = TopupUpdates(
      api: TopupApi(
        httpClient: MockClient((r) async {
          calls++;
          throw StateError('unexpected');
        }),
      ),
      store: store,
    )..start();
    try {
      await store.delete(
        (await LocalTxStore.queryByAccountId(record.payment.accountId)).single,
      );
      await updates.receive({
        'kind': 'topup_result',
        'result': result.toJson()['result'],
        'result_signature': result.resultSignature,
      });
      await updates.settle();
      expect(calls, 0);
      expect(
        await LocalTxStore.queryByAccountId(record.payment.accountId),
        isEmpty,
      );
    } finally {
      await updates.close();
    }
  });
  test('到账事件先到时一事务合并，保留原订单主键并只显示一次收入', () async {
    final sent = await submitted(),
        result = await sealed(await Future.value(sent));
    final paid = await accepted(sent, result);
    final original = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single;
    final event = storage.Entry()
      ..accountId = record.payment.accountId
      ..entryKind = 'transfer'
      ..entrySource = 'sdk_finalized_event'
      ..entryState = 'finalized'
      ..txHash = result.gmbTxHash
      ..transferAmount = record.payment.coinFen
      ..amountDelta = record.payment.coinFen
      ..createdAt = 1001000
      ..confirmedAt = 1001000
      ..blockHash = '0x${'05' * 32}'
      ..blockNumber = 10
      ..eventIndex = 0
      ..extrinsicIndex = 0;
    await LocalTxStore.upsert(event);
    await store.acceptReceipt(paid, result);
    final rows = await LocalTxStore.queryByAccountId(record.payment.accountId);
    expect(rows.length, 1);
    expect(rows.single.rowId, original.rowId);
    expect(rows.single.confirmedAt, 1001000);
  });
  test('公民签名失败或离页不创建订单；成功才生成短ID并保留完整绑定', () async {
    final config = TopupConfig.local();
    final selection = TopupSelection(
      token: 'USDC',
      package: config.packages.first,
      network: TopupNetwork.base,
    );
    final pair = await Keyring().fromUri('//Alice');
    final account =
        '0x${pair.publicKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final draft = TopupDraft.create(selection, account);
    expect(draft.signText.split('\n').length, 14);
    expect(draft.signText, isNot(contains('order_id=')));
    expect(draft.signText, isNot(contains('created_at=')));
    expect(TopupProgress.values.map((v) => v.name), [
      'pending',
      'paid',
      'completed',
    ]);
    var calls = 0;
    await expectLater(
      store.signOrder(draft, TopupWallets.ids.first, (payload) async {
        calls++;
        throw StateError('synthetic cancelled');
      }),
      throwsStateError,
    );
    expect(await LocalTxStore.queryByAccountId(account), isEmpty);
    await expectLater(
      store.signOrder(
        draft,
        TopupWallets.ids.first,
        (payload) async => pair.sign(payload),
        active: () => false,
      ),
      throwsA(isA<TopupDeletedException>()),
    );
    expect(await LocalTxStore.queryByAccountId(account), isEmpty);
    final signed = await store.signOrder(
      draft,
      TopupWallets.ids.first,
      (payload) async => pair.sign(payload),
      now: 1000000,
    );
    expect(calls, 1);
    expect(signed.progress, TopupProgress.pending);
    expect(signed.payment.orderId, 'top_${signed.binding.substring(0, 32)}');
    expect(signed.binding.length, 64);
    expect(
      await CitizenSdk.verify(
        accountId: account,
        signature: topupSignatureBytes(signed.accountSignature),
        payload: Uint8List.fromList(utf8.encode(draft.signText)),
      ),
      true,
    );
    expect((await LocalTxStore.queryByAccountId(account)).length, 1);
  });
  test('本地创建即出现在既有entry，原子提交后只发一份同一快照，重复保存不发事件', () async {
    final changes = <TopupChange>[],
        sub = TopupStore.changes.listen(changes.add);
    try {
      await store.save(record);
      final rows = await LocalTxStore.queryByAccountId(
        record.payment.accountId,
      );
      expect(rows.length, 1);
      expect(changes.length, 1);
      expect(changes.single.record!.rowId, rows.single.rowId);
      expect(TopupStore.fromEntry(rows.single).encode(), record.encode());
      expect(rows.single.amountDelta, '0');
      await store.save(record, before: record);
      expect(changes.length, 1);
    } finally {
      await sub.cancel();
    }
  });
  test('订单正文不能覆盖entry原行的来源或状态', () {
    for (final field in ['origin', 'progress']) {
      final row = TopupStore.toEntry(record);
      final body = jsonDecode(row.orderData!) as Map<String, dynamic>;
      body[field] = field == 'origin' ? record.origin : 'paid';
      row.orderData = jsonEncode(body);
      expect(() => TopupStore.fromEntry(row), throwsFormatException);
    }
  });
  test('付款链立即一次加20秒指数退避十次，11轮未验真零服务端请求', () async {
    final sent = await submitted();
    final fixture =
        jsonDecode(
              fixtureFile(
                'citizen_transaction',
                'topup/contract.json',
              ).readAsStringSync(),
            )
            as Map;
    final policy = fixture['payment_checks'] as Map;
    final intervals = (policy['intervals_seconds'] as List).cast<int>();
    final timers = <PaymentTimer>[];
    var now = 1000000, checks = 0, requests = 0;
    final api = PaymentApi(
      (record) async {
        checks++;
        expect(record.progress, TopupProgress.pending);
        expect(record.checkCount, checks);
        now += 7000; // 每轮模拟真实查询耗时，退避不能少等这7秒。
        throw const FormatException('synthetic not finalized');
      },
      httpClient: MockClient((r) async {
        requests++;
        throw StateError('unexpected service');
      }),
    );
    final updates = TopupUpdates(
      api: api,
      store: store,
      now: () => now,
      timer: (delay, callback) {
        final timer = PaymentTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    try {
      updates.verifyPayment(sent);
      updates.verifyPayment(sent);
      await updates.settle();
      expect(checks, 1);
      for (final seconds in intervals) {
        final timer = timers.last;
        expect(timer.isActive, true);
        expect(timer.delay, Duration(seconds: seconds));
        now += seconds * 1000;
        timer.fire();
        await updates.settle();
      }
      expect(checks, policy['max_rounds']);
      expect(requests, 0);
      expect(timers.where((t) => t.isActive), isEmpty);
      final failed = (await store.all()).single;
      expect(failed.progress, TopupProgress.pending);
      expect(failed.failureCode, 'payment_failed');
      expect(failed.checkCount, 11);
      expect(failed.requestAt, isNull);
      await updates.resume();
      await updates.settle();
      expect(checks, 11);
      expect(requests, 0);
    } finally {
      await updates.close();
    }
  });
  test('未最终确认后成功即保存已支付并只发一次；前台恢复不重置到期时间', () async {
    final sent = await submitted();
    final timers = <PaymentTimer>[];
    var now = 1000000, checks = 0, requests = 0;
    PaymentApi api() => PaymentApi(
      (record) async {
        checks++;
        if (checks == 1) throw const FormatException('synthetic not finalized');
        return proof(record);
      },
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/topup/confirm');
        final current = (await store.all()).single;
        expect(current.progress, TopupProgress.paid);
        expect(current.proof, isNotNull);
        expect((jsonDecode(request.body) as Map).length, 16);
        return http.Response(jsonEncode(response(current)), 200);
      }),
    );
    TopupUpdates updates() => TopupUpdates(
      api: api(),
      store: store,
      now: () => now,
      timer: (delay, callback) {
        final timer = PaymentTimer(delay, callback);
        timers.add(timer);
        return timer;
      },
    );
    final first = updates();
    first.verifyPayment(sent);
    await first.settle();
    expect(checks, 1);
    await first.close();
    now += 5000;
    final resumed = updates();
    try {
      await resumed.resume();
      expect(timers.last.delay, const Duration(seconds: 15));
      await resumed.resume();
      expect(timers.last.delay, const Duration(seconds: 15));
      now += 15000;
      timers.last.fire();
      await resumed.settle();
      expect(checks, 2);
      expect(requests, 1);
      final paid = (await store.all()).single;
      expect(paid.progress, TopupProgress.paid);
      expect(paid.checkCount, 2);
      expect(paid.receipt, isNotNull);
      expect(timers.where((t) => t.isActive), isEmpty);
    } finally {
      await resumed.close();
    }
  });
  test('删除待验款订单会取消退避，迟到回执不重建或请求发币', () async {
    final sent = await submitted(), pending = Completer<TopupProof>();
    var requests = 0;
    final api = PaymentApi(
      (_) => pending.future,
      httpClient: MockClient((r) async {
        requests++;
        throw StateError('unexpected service');
      }),
    );
    final updates = TopupUpdates(api: api, store: store);
    try {
      updates.verifyPayment(sent);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final row = (await LocalTxStore.queryByAccountId(
        record.payment.accountId,
      )).single;
      await store.delete(row);
      pending.complete(proof(sent));
      await updates.settle();
      expect(await store.all(), isEmpty);
      expect(requests, 0);
    } finally {
      if (!pending.isCompleted) pending.complete(proof(sent));
      await updates.close();
    }
  });
  test('付款页客户端关闭不取消App已支付请求；重复能力零额外HTTP', () async {
    final sent = await submitted();
    final paid = await store.markPaid(sent, proof(sent));
    final release = Completer<void>();
    var requests = 0;
    final pageApi = TopupApi();
    final api = TopupApi(
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/topup/confirm');
        final row = (await LocalTxStore.queryByAccountId(
          record.payment.accountId,
        )).single;
        expect(row.entryState, 'paid');
        expect(TopupStore.fromEntry(row).proof, isNotNull);
        await release.future;
        return http.Response(jsonEncode(response(paid.record)), 200);
      }),
    );
    final updates = TopupUpdates(api: api, store: store)..start();
    try {
      pageApi.close();
      final sending = updates.issue(paid);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      release.complete();
      await sending;
      await updates.issue(paid);
      expect(requests, 1);
      final current = (await store.all()).single;
      expect(current.progress, TopupProgress.paid);
      expect(current.receipt, isNotNull);
    } finally {
      if (!release.isCompleted) release.complete();
      await updates.close();
    }
  });
  test('已支付快照不能再次生成发币请求能力', () async {
    final sent = await submitted();
    await store.markPaid(sent, proof(sent));
    await expectLater(store.markPaid(sent, proof(sent)), throwsStateError);
  });
  test('完整阶段更新保留同一主键；已支付证据和请求占位一起持久化', () async {
    final sent = await submitted();
    final before = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single;
    final saved = await store.markPaid(sent, proof(sent));
    final row = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single;
    expect(row.rowId, before.rowId);
    expect(row.entryState, 'paid');
    expect(row.amountDelta, '0');
    expect(row.txHash, isNull);
    expect(TopupStore.fromEntry(row).isPaid, true);
    expect(saved.record.requestAt, isNotNull);
  });
  test('HTTP仅在已支付实际落库后发送一次，重复使用能力零额外HTTP', () async {
    final sent = await submitted(),
        saved = await store.markPaid(await Future.value(sent), proof(sent));
    var requests = 0;
    final api = TopupApi(
      httpClient: MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/topup/confirm');
        final rows = await LocalTxStore.queryByAccountId(
          record.payment.accountId,
        );
        expect(TopupStore.fromEntry(rows.single).isPaid, true);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {
          ...record.payment.toJson().keys,
          'payer_address',
          'payment_txid',
          'recovery_token',
          'notify',
          'account_signature',
        });
        expect(body['notify'], isNull);
        expect(body['recovery_token'], saved.record.recoveryToken);
        expect(body['account_signature'], record.accountSignature);
        expect(body['account_id'], record.payment.accountId);
        return http.Response(jsonEncode(response(saved.record)), 200);
      }),
    );
    try {
      await api.requestIssuance(saved);
      await expectLater(api.requestIssuance(saved), throwsStateError);
      expect(requests, 1);
    } finally {
      api.close();
    }
  });
  test('受理公钥与原恢复凭据随同一原单保存，之后不得被替换', () async {
    final sent = await submitted(),
        saved = await store.markPaid(await Future.value(sent), proof(sent));
    final receipt = TopupReceipt.fromJson(response(saved.record));
    final accepted = saved.record.update(receipt: receipt);
    await store.save(accepted, before: saved.record);
    final row = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single;
    final loaded = TopupStore.fromEntry(row);
    expect(loaded.receipt!.publicKey, receipt.publicKey);
    expect(loaded.recoveryToken, saved.record.recoveryToken);
    expect(loaded.isPaid, true);
    expect(row.amountDelta, '0');
    final replaced = TopupReceipt.fromJson(
      response(accepted, publicKey: '0x${'04' * 32}'),
    );
    await expectLater(
      store.save(accepted.update(receipt: replaced), before: accepted),
      throwsStateError,
    );
  });
  test('服务端返回异常仍保留已支付，不新增业务状态', () async {
    final sent = await submitted(),
        saved = await store.markPaid(await Future.value(sent), proof(sent));
    final receipt = TopupReceipt.fromJson({
      ...response(saved.record),
      'order_state': 'exception',
      'auto_final': true,
      'exception_reason': 'topup_gmb_confirmation_timeout',
    });
    await store.save(
      saved.record.update(receipt: receipt),
      before: saved.record,
    );
    final loaded = TopupStore.fromEntry(
      (await LocalTxStore.queryByAccountId(record.payment.accountId)).single,
    );
    expect(loaded.progress, TopupProgress.paid);
    expect(loaded.receipt!.message, '充值处理异常，请核实原订单');
  });
  for (final mode in ['http', 'unknown', 'mismatch']) {
    test('发币请求$mode不重试，已支付真实事实继续保存在本机', () async {
      final sent = await submitted(),
          saved = await store.markPaid(await Future.value(sent), proof(sent));
      var requests = 0;
      final api = TopupApi(
        httpClient: MockClient((r) async {
          requests++;
          if (mode == 'unknown') {
            throw const SocketException('synthetic unavailable');
          }
          return http.Response(
            jsonEncode({
              'is_ok': mode == 'mismatch',
              'order_id': 'other',
              'payment_txid': sent.txid,
            }),
            mode == 'http' ? 503 : 200,
          );
        }),
      );
      try {
        await expectLater(
          api.requestIssuance(saved),
          throwsA(isA<Exception>()),
        );
        await expectLater(api.requestIssuance(saved), throwsStateError);
        expect(requests, 1);
        expect(
          TopupStore.fromEntry(
            (await LocalTxStore.queryByAccountId(
              record.payment.accountId,
            )).single,
          ).isPaid,
          true,
        );
      } finally {
        api.close();
      }
    });
  }
  test('未验款订单不能取得单次发币能力或伪造已支付', () async {
    await store.save(record);
    final sent = record.update(
      progress: TopupProgress.pending,
      payer: '0x${'01' * 20}',
      txid: '0x${'02' * 32}',
    );
    await expectLater(store.markPaid(sent, proof(sent)), throwsStateError);
    expect(
      (await store.list(
        record.origin,
        record.payment.accountId,
      )).single.progress,
      TopupProgress.pending,
    );
    await expectLater(store.save(sent, before: record), throwsFormatException);
  });
  test('取消失败未知均本地终态；重充是新订单，不修改原单', () async {
    for (final code in ['payment_cancelled', 'payment_failed']) {
      final catalog = TopupConfig.local();
      final fresh = TopupRecord.signed(
        TopupDraft.create(
          TopupSelection(
            token: 'USDC',
            package: catalog.packages.first,
            network: TopupNetwork.base,
          ),
          record.payment.accountId,
        ),
        TopupWallets.ids.first,
        '0x${'01' * 64}',
      );
      await store.save(fresh);
      final end = fresh.update(failureCode: code);
      await store.save(end, before: fresh);
      await expectLater(store.save(fresh, before: end), throwsStateError);
      expect(end.isPaid, false);
      expect(() => end.request(), throwsStateError);
    }
    expect(
      (await store.list(record.origin, record.payment.accountId)).length,
      2,
    );
  });
  test('付款人、原交易、原签名字节与付款证据不可覆盖', () async {
    final sent = await submitted();
    await expectLater(
      store.save(sent.update(payer: '0x${'08' * 20}'), before: sent),
      throwsStateError,
    );
    await expectLater(
      store.save(sent.update(txid: '0x${'09' * 32}'), before: sent),
      throwsStateError,
    );
    final saved = await store.markPaid(sent, proof(sent));
    await expectLater(
      store.save(
        saved.record.update(progress: TopupProgress.pending),
        before: saved.record,
      ),
      throwsFormatException,
    );
  });
  test('删除后晚到验款/保存均不能复活订单，也不能取得请求能力', () async {
    final sent = await submitted(),
        row = (await LocalTxStore.queryByAccountId(
          record.payment.accountId,
        )).single;
    await store.delete(row);
    await expectLater(
      store.markPaid(sent, proof(sent)),
      throwsA(isA<TopupDeletedException>()),
    );
    await expectLater(
      store.save(sent, before: sent),
      throwsA(isA<TopupDeletedException>()),
    );
    expect(
      await LocalTxStore.queryByAccountId(record.payment.accountId),
      isEmpty,
    );
  });
  test('损坏明细仍按精确本地身份删除，删除事件直接移除原行', () async {
    await store.save(record);
    final row = (await LocalTxStore.queryByAccountId(
      record.payment.accountId,
    )).single..orderData = '{';
    final changes = <TopupChange>[],
        sub = TopupStore.changes.listen(changes.add);
    try {
      await store.delete(row);
      expect(changes.single.apply([row], limit: 20), isEmpty);
    } finally {
      await sub.cancel();
    }
  });
  test('到账关联只接受同一公民币交易、账户、金额和SDK最终事件', () {
    final row = TopupStore.toEntry(record)..txHash = '0x${'09' * 32}';
    final event = TopupStore.toEntry(record)
      ..entryKind = 'transfer'
      ..entrySource = 'sdk_finalized_event'
      ..entryState = 'finalized'
      ..txHash = row.txHash
      ..amountDelta = record.payment.coinFen
      ..confirmedAt = 2000000;
    expect(TopupStore.matchesPayment(row, event), true);
    TopupStore.attachPayment(row, event);
    expect(row.confirmedAt, 2000000);
    event.txHash = '0x${'08' * 32}';
    expect(TopupStore.matchesPayment(row, event), false);
  });
}
