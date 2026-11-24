// 验证人员CID任职、同块当前钱包绑定、岗位席位及失败闭环。
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';

const institution = 'LN001-NRC0G-944805165-2026';
const person = 'CN220-CTZN2-198805200-2026';
const resident = 'CN220-NATP2-198805200-2026';
Uint8List text(String value) => Uint8List.fromList(utf8.encode(value));
List<int> vec(String value) => [
  ...CitizenScale.compact(utf8.encode(value).length),
  ...utf8.encode(value),
];
List<int> uint(int value, int length) =>
    List.generate(length, (i) => (value >> (i * 8)) & 255);
String hex(List<int> value) =>
    value.map((v) => v.toRadixString(16).padLeft(2, '0')).join();

class Chain extends TestChainReads {
  final block = CitizenBlockRef(
    hash: '0x${'11' * 32}',
    number: BigInt.one,
    finality: CitizenBlockFinality.finalized,
  );
  final rows = <String, Uint8List>{};
  final calls = <CitizenBlockRef>[];
  final roles = <Uint8List>[];
  int heads = 0;
  bool shortBatch = false, duplicatePage = false;
  late CitizenRuntimeContext runtime;
  String pallet = 'PublicEntity';
  Future<void> seed({
    String who = person,
    bool private = false,
    int owner = 1,
    int termEnd = 0,
    bool term = false,
  }) async {
    runtime = await CitizenSdkTestFixture.runtimeContext(block);
    pallet = private ? 'PrivateEntity' : 'PublicEntity';
    roles.clear();
    rows.clear();
    role('MEMBER', who: who, term: term, termEnd: termEnd);
    binding(who, owner);
    put('Timestamp', 'Now', [], uint(100 * Duration.millisecondsPerDay, 8));
  }

  Uint8List key(String pallet, String name, List<Object> fields) =>
      runtime.storageKey(pallet, name, fields);
  void put(String pallet, String name, List<Object> fields, List<int> value) =>
      rows[hex(key(pallet, name, fields))] = Uint8List.fromList(value);
  void role(
    String code, {
    String who = person,
    bool term = false,
    int termEnd = 0,
  }) {
    final k = key(pallet, 'InstitutionRoles', [text(institution), text(code)]);
    roles.add(k);
    rows[hex(k)] = Uint8List.fromList([
      ...vec(institution),
      ...vec(code),
      ...vec('岗位'),
      term ? 1 : 0,
      0,
      ...uint(1, 4),
    ]);
    put(
      pallet,
      'InstitutionRoleAssignments',
      [text(institution), text(code)],
      [
        4,
        ...vec(institution),
        ...vec(who),
        ...vec(code),
        ...uint(term ? 90 : 0, 4),
        ...uint(termEnd, 4),
        0,
        0,
        0,
      ],
    );
  }

  void binding(
    String who,
    int owner, {
    bool reverse = true,
    bool active = true,
  }) {
    final account = Uint8List.fromList(List.filled(32, owner));
    put('Identity', 'AccountIdByCid', [text(who)], account);
    put('Identity', 'BindingRevisionByCid', [text(who)], uint(owner, 8));
    put(
      'Identity',
      'CidRegistry',
      [text(who)],
      [
        ...vec(institution),
        ...List.filled(32, 0),
        0,
        0,
        active ? 0 : 1,
        ...uint(0, 4),
        0,
      ],
    );
    if (reverse) put('Identity', 'CidByAccountId', [account], vec(who));
  }

  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    heads++;
    return block;
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef at, Uint8List key) async {
    calls.add(at);
    return rows[hex(key)];
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef at,
    List<Uint8List> keys,
  ) async {
    calls.add(at);
    return shortBatch ? [] : [for (final key in keys) rows[hex(key)]];
  }

  @override
  Future<List<Uint8List>> getStorageKeysPaged(
    CitizenBlockRef at,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit = 1000,
  }) async {
    calls.add(at);
    final sorted = roles.toList()..sort((a, b) => hex(a).compareTo(hex(b)));
    return duplicatePage && sorted.isNotEmpty
        ? [sorted.first, sorted.first]
        : sorted;
  }

  InstitutionChainService service() => InstitutionChainService(
    getFinalizedHead: getFinalizedHead,
    getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
    getStorage: getStorage,
    getStorageBatch: getStorageBatch,
    getStorageKeysPaged: getStorageKeysPaged,
  );
  InstitutionIdentity get identity => InstitutionIdentity(
    cidNumber: institution,
    orgCode: pallet == 'PublicEntity' ? 'NRC' : 'SFGQ',
    kind: pallet == 'PublicEntity' ? 0 : 1,
  );
}

void main() {
  TestCitizenSdkHarness();
  test('当前链上人员绑定匹配任职，所有读固定同一最终块', () async {
    final c = Chain();
    await c.seed();
    final views = await c.service().fetchPersonViews(c.identity);
    expect(views.single.personCid, person);
    expect(views.single.accountId, '0x${'01' * 32}');
    expect(views.single.assignments.single.roleCode, 'MEMBER');
    expect(c.heads, 1);
    expect(c.calls.every((at) => identical(at, c.block)), true);
  });
  test('人员换绑后旧钱包失去资格，新钱包承接同一人员任职', () async {
    final c = Chain();
    await c.seed();
    final service = c.service();
    c.binding(person, 2);
    final matches = await service.walletAssignments(c.identity, [
      '0x${'01' * 32}',
      '0x${'02' * 32}',
    ]);
    expect(matches.keys, ['0x${'02' * 32}']);
    expect(matches.values.single.single.personCid, person);
  });
  test('同人跨岗位各占一席，不合并或重复创建机构人员', () async {
    final c = Chain();
    await c.seed();
    c.role('DIRECTOR');
    final views = await c.service().fetchPersonViews(c.identity);
    expect(views, hasLength(1));
    expect(views.single.assignments, hasLength(2));
  });
  for (final private in [false, true]) {
    test('居民任职只允许私权：$private', () async {
      final c = Chain();
      await c.seed(who: resident, private: private);
      if (private) {
        expect(
          (await c.service().fetchPersonViews(c.identity)).single.personCid,
          resident,
        );
      } else {
        await expectLater(
          c.service().fetchPersonViews(c.identity),
          throwsFormatException,
        );
      }
    });
  }
  for (final missing in [
    'AccountIdByCid',
    'BindingRevisionByCid',
    'CidRegistry',
  ]) {
    test('缺少$missing不授予钱包资格', () async {
      final c = Chain();
      await c.seed();
      c.rows.remove(hex(c.key('Identity', missing, [text(person)])));
      expect(
        await c.service().walletAssignments(c.identity, ['0x${'01' * 32}']),
        isEmpty,
      );
    });
  }
  test('反向错配及撤销状态不授予资格', () async {
    final c = Chain();
    await c.seed();
    c.put('Identity', 'CidByAccountId', [
      Uint8List.fromList(List.filled(32, 1)),
    ], vec(resident));
    expect(
      await c.service().walletAssignments(c.identity, ['0x${'01' * 32}']),
      isEmpty,
    );
    c.binding(person, 1, active: false);
    expect(
      await c.service().walletAssignments(c.identity, ['0x${'01' * 32}']),
      isEmpty,
    );
  });
  test('岗位资料与键主体不符、重复分页及不完整批读均失败', () async {
    final c = Chain();
    await c.seed();
    c.shortBatch = true;
    await expectLater(
      c.service().fetchAssignments(c.identity),
      throwsFormatException,
    );
    c.shortBatch = false;
    c.duplicatePage = true;
    await expectLater(
      c.service().fetchAssignments(c.identity),
      throwsFormatException,
    );
    c.duplicatePage = false;
    c.rows[hex(c.roles.single)] = Uint8List.fromList([
      ...vec(institution),
      ...vec('OTHER'),
      ...vec('岗位'),
      0,
      0,
      ...uint(1, 4),
    ]);
    await expectLater(
      c.service().fetchAssignments(c.identity),
      throwsFormatException,
    );
  });
  test('任期依据最终块Timestamp，不使用设备日期', () async {
    final c = Chain();
    await c.seed(term: true, termEnd: 100);
    expect(await c.service().fetchAssignments(c.identity), hasLength(1));
    await c.seed(term: true, termEnd: 99);
    expect(await c.service().fetchAssignments(c.identity), isEmpty);
  });
}
