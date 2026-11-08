import 'dart:convert';

import 'package:citizen_storage/user_isar.dart' as app_store;
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  useIsolatedIsar();

  test('原名 UserIsar 保存目录状态后连续关闭重开，不触发旧版本键冲突', () async {
    final first = await app_store.UserIsar.instance.db();
    expect(first.name, 'citizenapp_user');
    await first.writeTxn(() async {
      await first.versions.putByDataKind(
        app_store.Version()
          ..dataKind = 'public_institution'
          ..globalVersion = 'synthetic-snapshot'
          ..provinceData = '{"ZS":"synthetic-shard"}',
      );
    });
    await first.close();

    for (var round = 0; round < 3; round++) {
      final reopened = await app_store.UserIsar.instance.db();
      expect(reopened.name, 'citizenapp_user');
      final saved = await reopened.versions.getByDataKind('public_institution');
      expect(saved?.globalVersion, 'synthetic-snapshot');
      expect(saved?.provinceData, '{"ZS":"synthetic-shard"}');
      await reopened.close();
    }
  });

  test('原余额正文中的两类快照独立更新和删除', () async {
    final store = app_store.UserIsar.instance;
    final id = '0x${'11' * 32}';
    const wss = 'wss://clearing.example';
    final chain = {
      'block_hash': '0x${'22' * 32}',
      'block_number': '10',
      'free_fen': '100',
      'reserved_fen': '7',
    };
    await store.writeTxn((isar) async {
      await isar.balances.putByAccountId(
        app_store.Balance()
          ..accountId = id
          ..bodyData = jsonEncode({
            'chain': chain,
            'clearing_balances': {wss: '10'},
          }),
      );
    });
    final next = {...chain, 'free_fen': '102'};
    await Future.wait<void>([
      store.writeBalance(id, (old) {
        expect(jsonDecode(old!), {'chain': chain});
        return jsonEncode({'chain': next});
      }),
      store.writeClearingBalance(id, wss, BigInt.from(15)),
    ]);
    final row = await store.read(
      (isar) => isar.balances.getByAccountId(id),
    );
    expect(jsonDecode(row!.bodyData), {
      'chain': next,
      'clearing_balances': {wss: '15'},
    });

    await store.writeBalance(id, (_) => null);
    expect(await store.readBalance(id), isNull);
    expect(await store.readClearingBalance(id, wss), BigInt.from(15));
    await store.removeClearingBalances(id);
    expect(
      await store.read((isar) => isar.balances.getByAccountId(id)),
      isNull,
    );
  });
}
