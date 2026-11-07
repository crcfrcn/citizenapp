import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_storage/user_isar.dart' as app_store show Entity;
import 'package:citizen_citizen/public/isar_public_institution_store.dart';
import 'package:citizen_citizen/public/public_institution_dto.dart';
import 'package:citizen_testing/isar_test_env.dart';

const _ownerCidNumber = 'CN220-CTZN2-198805200-2026';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  test('公权机构关注按订阅者 CID 持久化，钱包换绑不产生新分区', () async {
    const peerCid = 'GD001-CGOV0-000000001-2026';
    final isar = await UserIsar.instance.db();
    await isar.writeTxn(() async {
      await isar.collection<app_store.Entity>().clear();
    });
    final store = IsarPublicInstitutionStore(isar: isar);
    await store.upsertInstitutions([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': peerCid,
        'cid_full_name': '广东省人民政府',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'CGOV',
        'account_count': 2,
      }),
    ]);

    await store.subscribe(_ownerCidNumber, peerCid);

    expect(
      (await store.listSubscribed(_ownerCidNumber)).map((row) => row.cidNumber),
      [peerCid],
      reason: '关注归属永久 CID，不接收或存储当前钱包账户作为分区键',
    );
    expect(await store.listSubscribed('CN220-CTZN2-OTHER-2026'), isEmpty);
  });
}
