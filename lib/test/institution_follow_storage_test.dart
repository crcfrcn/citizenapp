import 'package:citizen_citizen/public/isar_public_institution_store.dart';
import 'package:citizen_citizen/public/public_institution_dto.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  useIsolatedIsar();
  test('机构关注只按两个自然CID隔离，重复关注不重写且取消不串用户', () async {
    final store = IsarPublicInstitutionStore();
    const owner = 'R5-K3P1C1-N9-D4';
    const other = 'R5-K3P1C1-N8-D5';
    const target = 'R5-K3P1C1-N7-D6';
    await store.subscribe(owner, target);
    await store.subscribe(owner, target);
    await store.subscribe(other, target);
    expect(await store.isSubscribed(owner, target), isTrue);
    expect(await store.isSubscribed(other, target), isTrue);
    expect(await store.isSubscribed(target, owner), isFalse);
    await store.unsubscribe(owner, target);
    expect(await store.isSubscribed(owner, target), isFalse);
    expect(await store.isSubscribed(other, target), isTrue);
  });

  test('合库后机构与关注在同一读取回调中完成关联，不发生重入', () async {
    final store = IsarPublicInstitutionStore();
    await store.upsertInstitutions([
      const PublicInstitutionDto(
        cidNumber: 'synthetic-institution',
        fullName: '合成机构',
        cidState: 'ACTIVE',
        provinceCode: 'ZS',
        cityCode: '001',
        orgCode: 'NRC',
        accountCount: 2,
      ),
    ]);
    await store.subscribe('synthetic-owner', 'synthetic-institution');
    final rows = await store.listSubscribed('synthetic-owner');
    expect(rows.map((row) => row.cidNumber), ['synthetic-institution']);
    expect(await store.listSubscribed('synthetic-other'), isEmpty);
  });
}
