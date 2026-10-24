import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:citizenapp/system/security/system_protected_storage.dart';
import 'package:citizenapp/transaction/topup/store.dart';
import 'package:citizenapp/transaction/topup/topup_models.dart';

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
    final f =
        jsonDecode(
              File('test/transaction/topup/contract.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    record = TopupRecord(
      origin: 'https://www.crcfrcn.com',
      intent: TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>),
    );
  });
  tearDown(() async {
    await dir.delete(recursive: true);
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
      id: record.intent.order,
      status: TopupOrderStatus.pending,
      phase: TopupPhase.verifying,
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
    final f =
        jsonDecode(
              File('test/transaction/topup/contract.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final config = TopupConfig.fromJson(f['config'] as Map<String, dynamic>);
    final restored = (await store.list(
      record.origin,
      record.intent.accountId,
    )).single;
    final selection = TopupSelection.fromIntent(restored.intent, config);
    expect(selection.toJson(), {
      'token': 'USDC',
      'package_id': 'pkg_15',
      'network': 'base',
    });
    expect(jsonDecode(restored.encode()).containsKey('selection'), false);
    for (final field in ['token', 'network', 'package_id']) {
      final changed = jsonDecode(record.encode()) as Map<String, dynamic>;
      changed['intent']['intent'][field] = field == 'token'
          ? 'USDT'
          : field == 'network'
          ? 'ethereum'
          : 'pkg_1400';
      expect(
        () => TopupRecord.decode(jsonEncode(changed)),
        throwsFormatException,
      );
    }
  });
}
