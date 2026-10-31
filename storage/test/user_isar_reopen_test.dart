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
}
