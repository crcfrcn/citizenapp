import 'package:citizen_testing/fixture.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/topup_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late TopupStore store;
  late TopupRecord record;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('topup_store_');
    store = TopupStore(
      records: SystemProtectedRecordStore(
        'topup.json',
        directory: () => dir.resolveSymbolicLinks(),
      ),
    );
    final f = jsonDecode(
      fixtureFile(
        'citizen_transaction',
        'topup/contract.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    record = TopupRecord(
      origin: 'https://www.crcfrcn.com',
      intent: TopupPaymentIntent.fromJson(
        f['intent_data'] as Map<String, dynamic>,
      ),
    );
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test('订单七阶段只保存order_state，缺定位和非法类型拒绝', () {
    final tx = '0x${'09' * 32}';
    final base = <String, dynamic>{
      'is_ok': true,
      'order_id': record.intent.orderId,
      'coin_fen': record.intent.coinFen,
      'payment_txid': tx,
      'gmb_tx_hash': tx,
      'exception_reason': null,
    };
    for (final phase in TopupPhase.values) {
      final order = TopupOrder.fromJson({...base, 'order_state': phase.name});
      expect(order.orderState, phase);
      expect(
        order.terminal,
        phase == TopupPhase.paid || phase == TopupPhase.exception,
      );
      expect(order.toJson().keys.toSet(), {
        'is_ok',
        'order_id',
        'order_state',
        'coin_fen',
        'payment_txid',
        'gmb_tx_hash',
        'exception_reason',
      });
    }
    for (final bad in [
      {...base, 'order_state': 'unknown'},
      {...base, 'order_state': 'paid', 'gmb_tx_hash': null},
      {...base, 'order_state': 'paid', 'payment_txid': null},
      {...base, 'order_state': 'broadcast', 'order_id': null},
      {...base, 'order_state': 'awaiting', 'payment_txid': 1},
    ]) {
      expect(() => TopupOrder.fromJson(bad), throwsFormatException);
    }
  });
  test('原子记录重开恢复，按origin与目标账户隔离', () async {
    await store.save(record);
    final reopened = TopupStore(
      records: SystemProtectedRecordStore(
        'topup.json',
        directory: () => dir.resolveSymbolicLinks(),
      ),
    );
    expect(
      (await reopened.list(
        record.origin,
        record.intent.accountId,
      )).single.encode(),
      record.encode(),
    );
    expect(
      await reopened.list('https://other.example', record.intent.accountId),
      isEmpty,
    );
    expect(await reopened.list(record.origin, '0x${'55' * 32}'), isEmpty);
  });
  test('先存授权再存提交，原付款签名/定位/阶段不可替换', () async {
    final sig = '0x${'aa' * 65}';
    await store.save(record);
    final auth = record.update(
      progress: TopupProgress.authorized,
      signature: sig,
    );
    await store.save(auth, before: record);
    final sent = auth.update(
      progress: TopupProgress.submitting,
      txid: '0x${'09' * 32}',
    );
    await store.save(sent, before: auth);
    await expectLater(
      store.save(sent.update(txid: '0x${'08' * 32}'), before: sent),
      throwsFormatException,
    );
    await expectLater(
      store.save(sent.update(signature: '0x${'bb' * 65}'), before: sent),
      throwsFormatException,
    );
    await expectLater(store.save(auth, before: sent), throwsFormatException);
    expect(
      (await store.list(
        record.origin,
        record.intent.accountId,
      )).single.progress,
      TopupProgress.submitting,
    );
  });
  test('重复写幂等，旧写者不能覆盖另一阶段；记录损坏不继续付款', () async {
    await store.save(record);
    await store.save(record);
    final next = record.update(
      progress: TopupProgress.authorized,
      signature: '0x${'aa' * 65}',
    );
    await store.save(next, before: record);
    await expectLater(
      store.save(
        record.update(
          progress: TopupProgress.authorized,
          signature: '0x${'bb' * 65}',
        ),
        before: record,
      ),
      throwsStateError,
    );
    await File('${dir.path}/topup.json').writeAsString('{');
    await expectLater(
      store.list(record.origin, record.intent.accountId),
      throwsFormatException,
    );
  });
  test('缺授权/交易的阶段和订单归属错误不落盘', () async {
    await expectLater(
      store.save(record.update(progress: TopupProgress.authorized)),
      throwsFormatException,
    );
    await expectLater(
      store.save(
        record.update(
          progress: TopupProgress.submitted,
          signature: '0x${'aa' * 65}',
        ),
      ),
      throwsFormatException,
    );
    final order = TopupOrder(
      orderId: record.intent.orderId,
      orderState: TopupPhase.verifying,
      coinFen: record.intent.coinFen,
      paymentTxid: '0x${'08' * 32}',
    );
    await expectLater(
      store.save(record.update(order: order)),
      throwsFormatException,
    );
  });
  test('恢复组合只取原意图，不增加字段或允许换币、换链、换套餐', () async {
    await store.save(record);
    final f = jsonDecode(
      fixtureFile(
        'citizen_transaction',
        'topup/contract.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    final config = TopupConfig.fromJson(f['config'] as Map<String, dynamic>);
    final restored = (await store.list(
      record.origin,
      record.intent.accountId,
    )).single;
    final selection = TopupSelection.fromIntent(restored.intent, config);
    expect(selection.toJson(), {
      'token': 'USDC',
      'package_id': 'pkg_10',
      'network': 'base',
    });
    expect(jsonDecode(restored.encode()).containsKey('selection'), false);
    for (final field in ['token', 'network', 'package_id']) {
      final changed = jsonDecode(record.encode()) as Map<String, dynamic>;
      changed['intent']['intent_data'][field] = field == 'token'
          ? 'USDT'
          : field == 'network'
          ? 'ethereum'
          : 'pkg_900';
      expect(
        () => TopupRecord.decode(jsonEncode(changed)),
        throwsFormatException,
      );
    }
  });
  test('旧充值记录拒绝读取且付款token、签名、交易与Intent字节原样保留', () async {
    final before = record.update(
      progress: TopupProgress.submitted,
      signature: '0x${'11' * 64}1b',
      txid: '0x${'aa' * 32}',
    );
    final value = jsonDecode(before.encode()) as Map<String, dynamic>;
    value.remove('record_version');
    final intent = value['intent'] as Map<String, dynamic>;
    for (final entry in {
      'is_ok': 'ok',
      'intent_token': 'payment_intent',
      'sign_message': 'wallet_authorization_message',
      'intent_data': 'intent',
    }.entries) {
      intent[entry.value] = intent.remove(entry.key);
    }
    final raw = jsonEncode(value);
    final records = SystemProtectedRecordStore(
      'topup.json',
      directory: () => dir.resolveSymbolicLinks(),
    );
    expect(
      await records.compareAndSet(before.key, expected: null, next: raw),
      true,
    );
    await expectLater(
      store.list(before.origin, before.intent.accountId),
      throwsFormatException,
    );
    expect(await records.read(before.key), raw);
    intent['intent_token'] = before.intent.intentToken;
    final mixed = jsonEncode(value);
    expect(
      await records.compareAndSet(before.key, expected: raw, next: mixed),
      true,
    );
    await expectLater(
      store.list(before.origin, before.intent.accountId),
      throwsFormatException,
    );
    expect(await records.read(before.key), mixed);
  });
  for (final kind in [
    'root-extra',
    'order-extra',
    'order-mixed',
    'order-missing',
    'legacy-order-extra',
    'version',
  ]) {
    test('充值恢复$kind拒绝读取，原完整记录保持', () async {
      final original = record.update(
        order: TopupOrder(
          orderId: record.intent.orderId,
          orderState: TopupPhase.awaiting,
          coinFen: record.intent.coinFen,
        ),
      );
      final value = jsonDecode(original.encode()) as Map<String, dynamic>;
      final order = value['order'] as Map<String, dynamic>;
      switch (kind) {
        case 'root-extra':
          value['unexpected'] = 'retained';
        case 'order-extra':
          order['unexpected'] = 'retained';
        case 'order-mixed':
          order['phase'] = 'paid';
        case 'order-missing':
          order.remove('exception_reason');
        case 'legacy-order-extra':
          value.remove('record_version');
          final intent = value['intent'] as Map<String, dynamic>;
          for (final entry in {
            'is_ok': 'ok',
            'intent_token': 'payment_intent',
            'sign_message': 'wallet_authorization_message',
            'intent_data': 'intent',
          }.entries) {
            intent[entry.value] = intent.remove(entry.key);
          }
          for (final entry in {
            'is_ok': 'ok',
            'order_state': 'phase',
            'exception_reason': 'reason',
          }.entries) {
            order[entry.value] = order.remove(entry.key);
          }
          order['unexpected'] = 'retained';
        case 'version':
          value['record_version'] = 99;
      }
      final raw = jsonEncode(value);
      final records = SystemProtectedRecordStore(
        'topup.json',
        directory: () => dir.resolveSymbolicLinks(),
      );
      expect(
        await records.compareAndSet(original.key, expected: null, next: raw),
        true,
      );
      await expectLater(
        store.list(original.origin, original.intent.accountId),
        throwsFormatException,
      );
      expect(await records.read(original.key), raw);
    });
  }
}
