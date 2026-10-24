import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizenapp/citizen/administrators/account_id_codec.dart';
import 'package:citizenapp/citizen/administrators/admin_account.dart';
import 'package:citizenapp/citizen/administrators/admin_account_service.dart';
import 'package:citizenapp/citizen/administrators/admin_activation_service.dart';
import 'package:citizenapp/citizen/administrators/institution_admin_service.dart';
import 'package:citizenapp/citizen/institution/institution_info.dart';
import 'package:citizenapp/citizen/institution/institution_role_models.dart';
import 'package:citizenapp/storage/wallet_isar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

import '../../support/isar_test_env.dart';
import '../../support/fake_citizen_sdk.dart';

class FakeChain extends TestCitizenChain {
  final Map<String, Uint8List?> responses = {};
  final List<String> requestedKeys = [];
  final Set<String> failedKeys = {};
  final Map<String, List<Uint8List>> scanKeys = {};
  final queued = <String, List<Future<Uint8List?> Function()>>{};
  int scans = 0;
  int finalizedReads = 0;
  bool advanceHeads = false;
  bool scanFailure = false;
  bool batchFailure = false;
  final scanBlocks = <String>[];
  final batchBlocks = <String>[];
  final batchSizes = <int>[];

  @override
  Future<CitizenBlockRef> getFinalizedHead() async {
    finalizedReads++;
    return CitizenBlockRef(
      hash: advanceHeads
          ? '0x${finalizedReads.toRadixString(16).padLeft(64, '0')}'
          : '0x${'11' * 32}',
      number: advanceHeads ? BigInt.from(finalizedReads) : BigInt.one,
      finality: CitizenBlockFinality.finalized,
    );
  }

  @override
  Future<Uint8List?> getStorage(CitizenBlockRef block, Uint8List key) async {
    final storageKeyHex =
        '0x${key.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    requestedKeys.add(storageKeyHex);
    if (queued[storageKeyHex]?.isNotEmpty == true) {
      return queued[storageKeyHex]!.removeAt(0)();
    }
    if (failedKeys.contains(storageKeyHex)) throw StateError('合成人员/阈值读取失败');
    return responses[storageKeyHex];
  }

  @override
  Future<List<Uint8List>> getStorageKeysPaged(
    CitizenBlockRef block,
    Uint8List prefix, {
    Uint8List? startKey,
    int limit = 256,
  }) async {
    scans++;
    scanBlocks.add(block.hash);
    if (scanFailure) throw StateError('合成岗位读取失败');
    int compare(Uint8List a, Uint8List b) {
      for (var i = 0; i < a.length && i < b.length; i++) {
        if (a[i] != b[i]) return a[i].compareTo(b[i]);
      }
      return a.length.compareTo(b.length);
    }

    final keys = [
      ...?scanKeys['0x${prefix.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'],
    ]..sort(compare);
    return keys
        .where((key) => startKey == null || compare(key, startKey) > 0)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Uint8List?>> getStorageBatch(
    CitizenBlockRef block,
    List<Uint8List> keys,
  ) async {
    batchBlocks.add(block.hash);
    batchSizes.add(keys.length);
    if (batchFailure) throw StateError('合成岗位批取失败');
    return [
      for (final key in keys)
        responses['0x${key.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'],
    ];
  }
}

class FakeAdminService extends InstitutionAdminService {
  FakeAdminService({required this.admins}) : super(chain: TestCitizenChain());

  final List<AdminPerson> admins;

  @override
  Future<List<AdminPerson>> fetchAdmins(AdminAccountIdentity identity) async =>
      admins;
}

/// 合成只读人员和岗位结果，不构造钱包签名或真实管理员授权。
class _ViewService extends InstitutionAdminService {
  _ViewService(this.people) : super(chain: TestCitizenChain());
  final List<AdminPerson> people;
  List<InstitutionAdminAssignment> assignments = [];
  bool peopleFailure = false, assignmentFailure = false;
  int assignmentReads = 0;
  @override
  Future<List<AdminPerson>> fetchAdmins(AdminAccountIdentity identity) async {
    if (peopleFailure) throw StateError('合成人员失败');
    return people;
  }

  @override
  Future<List<InstitutionAdminAssignment>> fetchAssignments(
    AdminAccountIdentity identity,
    String cid,
  ) async {
    assignmentReads++;
    if (assignmentFailure) throw StateError('合成岗位失败');
    return assignments;
  }
}

void main() {
  useIsolatedIsar();
  setUp(() => AdminAccountService(chain: TestCitizenChain()).clearCache());
  String hexOf(Iterable<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  List<int> codeBytes(String code) => [
    ...code.codeUnits,
    ...List.filled(4 - code.length, 0),
  ];

  List<int> u32Le(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];

  Uint8List institutionAdminBytes({
    required String institutionCode,
    required List<int> admin,
    String cidNumber = '',
    String familyName = '管理',
    String givenName = '员',
  }) {
    final cidBytes = utf8.encode(cidNumber);
    final familyBytes = utf8.encode(familyName);
    final givenBytes = utf8.encode(givenName);
    return Uint8List.fromList([
      ...codeBytes(institutionCode),
      4,
      ...admin,
      // 统一 Admin 恒带 cid：私权为空 CID（Compact(0)），公权为真实 CID。
      cidBytes.length << 2,
      ...cidBytes,
      familyBytes.length << 2,
      ...familyBytes,
      givenBytes.length << 2,
      ...givenBytes,
    ]);
  }

  Uint8List personalAdminBytes({required List<int> admin}) {
    final familyBytes = utf8.encode('管理');
    final givenBytes = utf8.encode('员');
    return Uint8List.fromList([
      0,
      ...codeBytes('PMUL'),
      2,
      4,
      ...admin,
      0, // 空公民 CID（Compact(0)）
      familyBytes.length << 2,
      ...familyBytes,
      givenBytes.length << 2,
      ...givenBytes,
      ...List<int>.filled(32, 0xcc),
      ...u32Le(1),
      ...u32Le(2),
      1,
    ]);
  }

  String thresholdKey({
    required String palletName,
    required String storageName,
    required Uint8List keyData,
  }) {
    final bytes = <int>[
      ...Hasher.twoxx128.hashString(palletName),
      ...Hasher.twoxx128.hashString(storageName),
      ...AdminAccountIdCodec.blake2128Concat(keyData),
    ];
    return '0x${hexOf(bytes)}';
  }

  // 合成 SCALE 值经过生产解码和人员关联，不直接注入已拼好的视图。
  Uint8List roleBytes(String cid, String code) => Uint8List.fromList([
    ...AdminAccountIdCodec.scaleBytes(utf8.encode(cid)),
    ...AdminAccountIdCodec.scaleBytes(utf8.encode(code)),
    ...AdminAccountIdCodec.scaleBytes(utf8.encode('合成委员')),
    0,
    0,
  ]);

  Uint8List assignmentBytes(String cid, String code, int accountByte) =>
      Uint8List.fromList([
        4,
        ...AdminAccountIdCodec.scaleBytes(utf8.encode(cid)),
        ...List.filled(32, accountByte),
        ...AdminAccountIdCodec.scaleBytes(utf8.encode(code)),
        ...u32Le(0),
        ...u32Le(0),
        0,
        0,
        0,
      ]);

  void seedAssignments(
    FakeChain rpc,
    AdminAccountIdentity identity, {
    int count = 1,
    int firstByte = 0xaa,
  }) {
    final cid = identity.cidNumber!;
    final pallet = identity.kind == 1 ? 'PrivateManage' : 'PublicManage';
    const code = 'MEMBER';
    for (final storage in ['InstitutionRoles', 'InstitutionRoleAssignments']) {
      final prefix = Uint8List.fromList([
        ...Hasher.twoxx128.hashString(pallet),
        ...Hasher.twoxx128.hashString(storage),
        ...AdminAccountIdCodec.blake2128Concat(
          AdminAccountIdCodec.scaleBytes(utf8.encode(cid)),
        ),
      ]);
      final key = Uint8List.fromList([
        ...prefix,
        ...AdminAccountIdCodec.blake2128Concat(
          AdminAccountIdCodec.scaleBytes(utf8.encode(code)),
        ),
      ]);
      rpc.scanKeys['0x${hexOf(prefix)}'] = [key];
      rpc.responses['0x${hexOf(key)}'] = storage == 'InstitutionRoles'
          ? roleBytes(cid, code)
          : Uint8List.fromList([
              count << 2,
              for (var i = 0; i < count; i++)
                ...assignmentBytes(cid, code, firstByte + i).skip(1),
            ]);
    }
  }

  final displayIdentity = AdminAccountIdentity.institution(
    cidNumber: 'LN001-NRC0G-944805165-2026',
    institutionCode: 'NRC',
    accountLabel: '合成机构',
  );
  final people = [
    for (final byte in ['aa', 'bb'])
      AdminPerson(
        account_id: '0x${byte * 32}',
        family_name: '合成',
        given_name: byte,
      ),
  ];
  InstitutionAdminAssignment assignment(String role) =>
      InstitutionAdminAssignment(
        cidNumber: displayIdentity.cidNumber!,
        account_id: people.first.account_id,
        roleCode: role,
        roleName: role,
        termStart: 0,
        termEnd: 0,
        source: InstitutionAssignmentSource.genesis,
        sourceRef: '',
        active: true,
      );

  test('人员成功且岗位失败保留完整顺序，重试后区分无岗位与多岗位', () async {
    final service = _ViewService(people)..assignmentFailure = true;
    final unknown = await service.fetchAdminViews(
      displayIdentity,
      displayIdentity.cidNumber!,
    );
    expect(
      unknown.map((v) => v.admin.account_id),
      people.map((p) => p.account_id),
    );
    expect(
      unknown.every((v) => !v.assignmentsLoaded && v.assignments.isEmpty),
      isTrue,
    );
    service.assignmentFailure = false;
    service.assignments = [assignment('FIRST'), assignment('SECOND')];
    final loaded = await service.fetchAdminViews(
      displayIdentity,
      displayIdentity.cidNumber!,
    );
    expect(loaded.every((v) => v.assignmentsLoaded), isTrue);
    expect(loaded.first.assignments.map((v) => v.roleCode), [
      'FIRST',
      'SECOND',
    ]);
    expect(loaded.last.assignments, isEmpty);
  });
  test('人员失败不伪造零人，后续重试仍可成功', () async {
    final service = _ViewService(people)..peopleFailure = true;
    await expectLater(
      service.fetchAdminViews(displayIdentity, displayIdentity.cidNumber!),
      throwsStateError,
    );
    expect(service.assignmentReads, 0);
    service.peopleFailure = false;
    expect(
      await service.fetchAdminViews(
        displayIdentity,
        displayIdentity.cidNumber!,
      ),
      hasLength(2),
    );
  });
  test('完整核实零人不等待附加岗位查询', () async {
    final service = _ViewService([])..assignmentFailure = true;
    expect(
      await service.fetchAdminViews(
        displayIdentity,
        displayIdentity.cidNumber!,
      ),
      isEmpty,
    );
    expect(service.assignmentReads, 0);
  });
  test('人员视图拒绝CID不一致及个人账户，不进入未知岗位分支', () async {
    final service = _ViewService(people);
    await expectLater(
      service.fetchAdminViews(displayIdentity, 'OTHER'),
      throwsArgumentError,
    );
    await expectLater(
      service.fetchAdminViews(
        AdminAccountIdentity.personalAccount(
          personalAccountId: '0x${'01' * 32}',
          accountLabel: '合成个人',
        ),
        displayIdentity.cidNumber!,
      ),
      throwsArgumentError,
    );
    expect(service.assignmentReads, 0);
  });
  for (final code in ['NRC', 'FRG', 'UNIN']) {
    test('真实人员读取按$code精确主体路由，岗位失败不丢人', () async {
      final rpc = FakeChain()..scanFailure = true;
      final identity = AdminAccountIdentity.institution(
        cidNumber: 'GD001-${code}00-123456789-2026',
        institutionCode: code,
        accountLabel: '合成机构',
        kind: code == 'UNIN' ? 1 : 0,
      );
      final key =
          '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: code, adminKind: identity.kind))}';
      rpc.responses[key] = institutionAdminBytes(
        institutionCode: code,
        admin: List.filled(32, 0xaa),
      );
      final service = InstitutionAdminService(chain: rpc);
      final views = await service.fetchAdminViews(
        identity,
        identity.cidNumber!,
      );
      expect(views.single.admin.account_id, '0x${'aa' * 32}');
      expect(views.single.assignmentsLoaded, isFalse);
      expect(rpc.requestedKeys.first, key);
      rpc.scanFailure = false;
      final retried = await service.fetchAdminViews(
        identity,
        identity.cidNumber!,
      );
      expect(retried.single.assignmentsLoaded, isTrue);
      expect(retried.single.assignments, isEmpty);
    });
  }
  for (final malformed in [false, true]) {
    test('扫描到岗位键但${malformed ? '解码无效' : '值缺失'}时不能显示暂无岗位', () async {
      final rpc = FakeChain();
      final identity = displayIdentity;
      final key =
          '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
      rpc.responses[key] = institutionAdminBytes(
        institutionCode: 'NRC',
        admin: List.filled(32, 0xaa),
      );
      final cidBytes = AdminAccountIdCodec.scaleBytes(
        utf8.encode(identity.cidNumber!),
      );
      final prefix = Uint8List.fromList([
        ...Hasher.twoxx128.hashString('PublicManage'),
        ...Hasher.twoxx128.hashString('InstitutionRoles'),
        ...AdminAccountIdCodec.blake2128Concat(cidBytes),
      ]);
      final roleKey = Uint8List.fromList([...prefix, 1]);
      rpc.scanKeys['0x${hexOf(prefix)}'] = [roleKey];
      if (malformed) {
        rpc.responses['0x${hexOf(roleKey)}'] = Uint8List.fromList([255]);
      }
      final views = await InstitutionAdminService(chain: rpc)
          .fetchAdminViews(identity, identity.cidNumber!);
      expect(views.single.assignmentsLoaded, isFalse);
    });
  }

  test('十九名合成人员经SCALE解码关联全部任职，岗位分页与批取固定同块', () async {
    final rpc = FakeChain()..advanceHeads = true;
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    rpc.responses[key] = Uint8List.fromList([
      ...codeBytes('NRC'),
      19 << 2,
      for (var i = 1; i <= 19; i++)
        ...institutionAdminBytes(
          institutionCode: 'NRC',
          admin: List.filled(32, i),
        ).skip(5),
    ]);
    seedAssignments(rpc, identity, count: 19, firstByte: 1);
    final views = await InstitutionAdminService(chain: rpc)
        .fetchAdminViews(identity, identity.cidNumber!);
    expect(views, hasLength(19));
    for (final view in views) {
      expect(view.assignmentsLoaded, isTrue);
      expect(view.assignments.single.account_id, view.admin.account_id);
      expect(view.assignments.single.roleName, '合成委员');
    }
    expect(rpc.requestedKeys, [key]); // 展示不读取治理阈值。
    expect(rpc.scans, 2);
    expect(rpc.batchBlocks, hasLength(2));
    expect({...rpc.scanBlocks, ...rpc.batchBlocks}, hasLength(1));
    expect(rpc.finalizedReads, 2); // 名册一次，岗位与任职共用另一次。
  });

  test('岗位满256键翻页和100条分批仍固定同一finalized块', () async {
    final rpc = FakeChain()..advanceHeads = true;
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    rpc.responses[key] = institutionAdminBytes(
      institutionCode: 'NRC',
      admin: List.filled(32, 0xaa),
    );
    seedAssignments(rpc, identity);
    final prefix = Uint8List.fromList([
      ...Hasher.twoxx128.hashString('PublicManage'),
      ...Hasher.twoxx128.hashString('InstitutionRoles'),
      ...AdminAccountIdCodec.blake2128Concat(
        AdminAccountIdCodec.scaleBytes(utf8.encode(identity.cidNumber!)),
      ),
    ]);
    final page = rpc.scanKeys['0x${hexOf(prefix)}']!;
    for (var i = 1; i < 256; i++) {
      final code = 'EXTRA_$i';
      final roleKey = Uint8List.fromList([
        ...prefix,
        ...AdminAccountIdCodec.blake2128Concat(
          AdminAccountIdCodec.scaleBytes(utf8.encode(code)),
        ),
      ]);
      page.add(roleKey);
      rpc.responses['0x${hexOf(roleKey)}'] = roleBytes(
        identity.cidNumber!,
        code,
      );
    }
    final views = await InstitutionAdminService(chain: rpc)
        .fetchAdminViews(identity, identity.cidNumber!);
    expect(views.single.assignments.single.roleCode, 'MEMBER');
    expect(rpc.scans, 3); // 岗位满页后的终止页，加任职页。
    expect(rpc.batchSizes, [100, 100, 56, 1]);
    expect({...rpc.scanBlocks, ...rpc.batchBlocks}, hasLength(1));
    expect(rpc.finalizedReads, 2);
  });

  for (final failure in ['扫描', '批取', '岗位解码', '任职解码']) {
    test('附加资料$failure失败保留人员且重读恢复真实岗位', () async {
      final rpc = FakeChain();
      final identity = displayIdentity;
      final key =
          '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
      rpc.responses[key] = institutionAdminBytes(
        institutionCode: 'NRC',
        admin: List.filled(32, 0xaa),
      );
      seedAssignments(rpc, identity);
      rpc.scanFailure = failure == '扫描';
      rpc.batchFailure = failure == '批取';
      if (failure.endsWith('解码')) {
        final storage = failure == '岗位解码'
            ? 'InstitutionRoles'
            : 'InstitutionRoleAssignments';
        final prefix = Uint8List.fromList([
          ...Hasher.twoxx128.hashString('PublicManage'),
          ...Hasher.twoxx128.hashString(storage),
          ...AdminAccountIdCodec.blake2128Concat(
            AdminAccountIdCodec.scaleBytes(utf8.encode(identity.cidNumber!)),
          ),
        ]);
        final badKey = rpc.scanKeys['0x${hexOf(prefix)}']!.single;
        rpc.responses['0x${hexOf(badKey)}'] = Uint8List.fromList([255]);
      }
      final service = InstitutionAdminService(chain: rpc);
      final failed = await service.fetchAdminViews(
        identity,
        identity.cidNumber!,
      );
      expect(failed.single.admin.account_id, '0x${'aa' * 32}');
      expect(failed.single.assignmentsLoaded, isFalse);
      expect(failed.single.assignments, isEmpty);
      rpc.scanFailure = false;
      rpc.batchFailure = false;
      seedAssignments(rpc, identity);
      final restored = await service.fetchAdminViews(
        identity,
        identity.cidNumber!,
      );
      expect(restored.single.assignmentsLoaded, isTrue);
      expect(
        restored.single.assignments.single.account_id,
        restored.single.admin.account_id,
      );
    });
  }

  test('阈值失败仍可展示人员及岗位，完整权限失败且重试不冒认成功', () async {
    final rpc = FakeChain();
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    final threshold = thresholdKey(
      palletName: 'PublicManage',
      storageName: 'InstitutionGovernanceThresholds',
      keyData: AdminAccountIdCodec.scaleBytes(utf8.encode(identity.cidNumber!)),
    );
    rpc.responses[key] = institutionAdminBytes(
      institutionCode: 'NRC',
      admin: List.filled(32, 0xaa),
    );
    rpc.responses[threshold] = Uint8List.fromList(u32Le(2));
    rpc.failedKeys.add(threshold);
    seedAssignments(rpc, identity);
    final source = AdminAccountService(chain: rpc);
    final service = InstitutionAdminService(chain: rpc);
    final views = await service.fetchAdminViews(identity, identity.cidNumber!);
    expect(views.single.admin.account_id, '0x${'aa' * 32}');
    expect(views.single.assignmentsLoaded, isTrue);
    expect(
      views.single.assignments.single.account_id,
      views.single.admin.account_id,
    );
    expect(rpc.requestedKeys, [key]);
    await expectLater(source.fetchByIdentity(identity), throwsStateError);
    await expectLater(
      service.fetchState(identity, cidNumber: identity.cidNumber!),
      throwsStateError,
    );
    await expectLater(
      source.isAdmin('0x${'aa' * 32}', identity),
      throwsStateError,
    );
    await expectLater(
      service.isAdmin('0x${'aa' * 32}', identity),
      throwsStateError,
    );
    expect(await source.fetchAdmins(identity), hasLength(1));
    expect(rpc.requestedKeys.where((v) => v == key), hasLength(1));
    rpc.failedKeys.clear();
    expect((await source.fetchByIdentity(identity))?.threshold, 2);
    expect(await source.isAdmin('0x${'aa' * 32}', identity), isTrue);
    expect(
      (await service.fetchAdminViews(
        identity,
        identity.cidNumber!,
      )).single.assignmentsLoaded,
      isTrue,
    );
  });
  test('真实零人员记录只读取名册，不查询阈值或岗位', () async {
    final rpc = FakeChain();
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    rpc.responses[key] = Uint8List.fromList([...codeBytes('NRC'), 0]);
    final views = await InstitutionAdminService(chain: rpc)
        .fetchAdminViews(identity, identity.cidNumber!);
    expect(views, isEmpty);
    expect(rpc.requestedKeys, [key]);
    expect(rpc.scans, 0);
  });
  test('损坏人员记录失败不能伪造成零人，失败后可重新读取', () async {
    final rpc = FakeChain();
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    rpc.responses[key] = Uint8List.fromList([255]);
    final service = InstitutionAdminService(chain: rpc);
    await expectLater(
      service.fetchAdminViews(identity, identity.cidNumber!),
      throwsFormatException,
    );
    expect(rpc.scans, 0);
    rpc.responses[key] = institutionAdminBytes(
      institutionCode: 'NRC',
      admin: List.filled(32, 0xaa),
    );
    expect(
      await service.fetchAdminViews(identity, identity.cidNumber!),
      hasLength(1),
    );
  });
  test('人员和完整状态并发复用同一次读取与finalized块，不复制名册缓存', () async {
    final rpc = FakeChain();
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    final threshold = thresholdKey(
      palletName: 'PublicManage',
      storageName: 'InstitutionGovernanceThresholds',
      keyData: AdminAccountIdCodec.scaleBytes(utf8.encode(identity.cidNumber!)),
    );
    final delayed = Completer<Uint8List?>();
    rpc.queued[key] = [() => delayed.future];
    rpc.responses[threshold] = Uint8List.fromList(u32Le(3));
    final source = AdminAccountService(chain: rpc);
    final peopleRead = source.fetchAdmins(identity),
        fullRead = source.fetchByIdentity(identity);
    await Future<void>.delayed(Duration.zero);
    expect(rpc.requestedKeys, [key]);
    delayed.complete(
      institutionAdminBytes(
        institutionCode: 'NRC',
        admin: List.filled(32, 0xaa),
      ),
    );
    expect(await peopleRead, hasLength(1));
    expect((await fullRead)?.threshold, 3);
    expect(rpc.requestedKeys, [key, threshold]);
    expect(await source.fetchAdmins(identity), hasLength(1));
    expect(rpc.requestedKeys, [key, threshold]);
  });
  test('清缓存后的旧人员读取不能覆盖新名册', () async {
    final rpc = FakeChain();
    final identity = displayIdentity;
    final key =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(identity.cidNumber!, institutionCode: 'NRC', adminKind: 0))}';
    final delayed = Completer<Uint8List?>();
    rpc.queued[key] = [() => delayed.future];
    rpc.responses[key] = institutionAdminBytes(
      institutionCode: 'NRC',
      admin: List.filled(32, 0xbb),
    );
    final source = AdminAccountService(chain: rpc);
    final old = source.fetchAdmins(identity);
    await Future<void>.delayed(Duration.zero);
    source.clearCache(identity);
    expect(
      (await source.fetchAdmins(identity)).single.account_id,
      '0x${'bb' * 32}',
    );
    delayed.complete(
      institutionAdminBytes(
        institutionCode: 'NRC',
        admin: List.filled(32, 0xaa),
      ),
    );
    await old;
    expect(
      (await source.fetchAdmins(identity)).single.account_id,
      '0x${'bb' * 32}',
    );
    expect(rpc.requestedKeys, [key, key]);
  });

  test('私权非法人机构按 CID 与显式 kind 路由', () async {
    const cidNumber = 'GD001-UNIN0-123456789-2026';
    final rpc = FakeChain();
    final service = InstitutionAdminService(chain: rpc);
    final accountKey =
        '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(cidNumber, institutionCode: 'UNIN', adminKind: 1))}';
    final thresholdStorageKey = thresholdKey(
      palletName: 'PrivateManage',
      storageName: 'InstitutionGovernanceThresholds',
      keyData: AdminAccountIdCodec.scaleBytes(utf8.encode(cidNumber)),
    );
    rpc.responses[accountKey] = institutionAdminBytes(
      institutionCode: 'UNIN',
      admin: List<int>.filled(32, 0xaa),
    );
    rpc.responses[thresholdStorageKey] = Uint8List.fromList(u32Le(2));

    final identity = AdminAccountIdentity.institution(
      cidNumber: cidNumber,
      institutionCode: 'UNIN',
      accountLabel: '机构账户',
      kind: 1,
    );
    expect(
      (await service.fetchAdmins(identity)).map((admin) => admin.account_id),
      ['0x${'aa' * 32}'],
    );
    expect(await service.fetchThreshold(identity), 2);
    expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);
  });

  test('个人多签严格按 personal_account_id 路由', () async {
    final rpc = FakeChain();
    final service = InstitutionAdminService(chain: rpc);
    final personalAccountId = '0x${'22' * 32}';
    final accountIdBytes = AdminAccountIdCodec.fromAccountIdText(
      personalAccountId,
    );
    final accountKey =
        '0x${hexOf(AdminAccountIdCodec.personalAdminStorageKey(accountIdBytes))}';
    final thresholdStorageKey = thresholdKey(
      palletName: 'InternalVote',
      storageName: 'ActivePersonalThresholds',
      keyData: accountIdBytes,
    );
    rpc.responses[accountKey] = personalAdminBytes(
      admin: List<int>.filled(32, 0xbb),
    );
    rpc.responses[thresholdStorageKey] = Uint8List.fromList(u32Le(2));

    final identity = AdminAccountIdentity.personalAccount(
      personalAccountId: personalAccountId,
      accountLabel: '个人多签',
    );
    expect(
      (await service.fetchAdmins(identity)).map((admin) => admin.account_id),
      ['0x${'bb' * 32}'],
    );
    expect(await service.fetchThreshold(identity), 2);
    expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);
  });

  test('公权机构从 PublicManage 读取机构阈值', () async {
    for (final entry in const {'FRG': 3, 'NJD': 8}.entries) {
      final cidNumber = 'ZS001-${entry.key}00-123456789-2026';
      final rpc = FakeChain();
      final service = AdminAccountService(chain: rpc);
      final identity = AdminAccountIdentity.institution(
        cidNumber: cidNumber,
        institutionCode: entry.key,
        accountLabel: entry.key,
      );
      final accountKey =
          '0x${hexOf(AdminAccountIdCodec.institutionAdminStorageKey(cidNumber, institutionCode: entry.key, adminKind: 0))}';
      rpc.responses[accountKey] = institutionAdminBytes(
        institutionCode: entry.key,
        admin: List<int>.filled(32, 0xee),
        cidNumber: 'CN220-CTZN2-198805200-2026',
        familyName: '',
        givenName: '',
      );
      final thresholdStorageKey = thresholdKey(
        palletName: 'PublicManage',
        storageName: 'InstitutionGovernanceThresholds',
        keyData: AdminAccountIdCodec.scaleBytes(utf8.encode(cidNumber)),
      );
      rpc.responses[thresholdStorageKey] = Uint8List.fromList(
        u32Le(entry.value),
      );

      expect((await service.fetchByIdentity(identity))?.threshold, entry.value);
      final state = await service.fetchByIdentity(identity);
      expect(state?.admins.single.cid_number, 'CN220-CTZN2-198805200-2026');
      expect(state?.admins.single.family_name, isEmpty);
      expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);
    }
  });

  test('管理员缓存按明确 identity key 隔离并可清除', () async {
    final rpc = FakeChain();
    final service = AdminAccountService(chain: rpc);
    final personalAccountId = '0x${'33' * 32}';
    final accountIdBytes = AdminAccountIdCodec.fromAccountIdText(
      personalAccountId,
    );
    final identity = AdminAccountIdentity.personalAccount(
      personalAccountId: personalAccountId,
      accountLabel: '个人多签',
    );
    final accountKey =
        '0x${hexOf(AdminAccountIdCodec.personalAdminStorageKey(accountIdBytes))}';
    final thresholdStorageKey = thresholdKey(
      palletName: 'InternalVote',
      storageName: 'ActivePersonalThresholds',
      keyData: accountIdBytes,
    );
    rpc.responses[accountKey] = personalAdminBytes(
      admin: List<int>.filled(32, 0xdd),
    );
    rpc.responses[thresholdStorageKey] = Uint8List.fromList(u32Le(2));

    await service.fetchByIdentity(identity);
    await service.fetchByIdentity(identity);
    expect(rpc.requestedKeys, [accountKey, thresholdStorageKey]);

    service.clearCache(identity);
    await service.fetchByIdentity(identity);
    expect(rpc.requestedKeys, [
      accountKey,
      thresholdStorageKey,
      accountKey,
      thresholdStorageKey,
    ]);
  });

  test('InstitutionInfo 解析为 CID 机构或个人多签明确身份', () {
    final personalAccount = '0x${'44' * 32}';
    final personal = AdminAccountIdentity.fromInstitution(
      InstitutionInfo(
        cidFullName: '个人账户',
        cidShortName: '个人账户',
        cidFullNameEn: 'Personal Account',
        cidShortNameEn: 'Personal Account',
        cidNumber: 'personal-account:$personalAccount',
        orgType: OrgType.personalMultisig,
        personalAccountId: personalAccount,
      ),
    );
    expect(personal.type, AdminAccountIdentityType.personalAccount);
    expect(personal.personalAccountId, personalAccount);

    const institutionCid = 'GD001-CGOV0-123456789-2026';
    final institution = AdminAccountIdentity.fromInstitution(
      InstitutionInfo(
        cidFullName: '机构账户',
        cidShortName: '机构账户',
        cidFullNameEn: 'Institution Account',
        cidShortNameEn: 'Institution Account',
        cidNumber: institutionCid,
        orgType: OrgType.institution,
        adminAccountCode: 'CGOV',
        accounts: InstitutionAccounts(
          mainAccountId: '55' * 32,
          feeAccountId: '56' * 32,
        ),
      ),
    );
    expect(institution.type, AdminAccountIdentityType.institution);
    expect(institution.cidNumber, institutionCid);

    final privateOwnedInstitution = AdminAccountIdentity.institution(
      cidNumber: 'GD001-UNIN0-223456789-2026',
      institutionCode: 'UNIN',
      accountLabel: '私权非法人机构',
      kind: 1,
    );
    expect(privateOwnedInstitution.type, AdminAccountIdentityType.institution);
    expect(privateOwnedInstitution.kind, 1);

    final governance = AdminAccountIdentity.fromInstitution(
      InstitutionInfo(
        cidFullName: '中枢省公民储备银行',
        cidShortName: '中枢省储行',
        cidFullNameEn: 'Zhongshu Provincial Citizen Reserve Bank',
        cidShortNameEn: 'Zhongshu Provincial Reserve Bank',
        cidNumber: 'ZS001-PRB08-233384677-2026',
        orgType: OrgType.prb,
        accounts: InstitutionAccounts(
          mainAccountId: '77' * 32,
          feeAccountId: '78' * 32,
        ),
      ),
    );
    expect(governance.type, AdminAccountIdentityType.institution);
    expect(governance.institutionCode, 'PRB');
  });

  test('管理员激活记录只以机构 CID 归属和去重', () async {
    const cidNumber = 'GD001-CGOV0-323456789-2026';
    final identity = AdminAccountIdentity.institution(
      cidNumber: cidNumber,
      institutionCode: 'CGOV',
      accountLabel: '公权机构',
    );
    const otherCidNumber = 'GD001-UNIN0-423456789-2026';
    final otherIdentity = AdminAccountIdentity.institution(
      cidNumber: otherCidNumber,
      institutionCode: 'UNIN',
      accountLabel: '私权机构',
      kind: 1,
    );
    final active = ActivatedAdmin(
      accountId: '0x${'aa' * 32}',
      cidNumber: cidNumber,
      institutionCode: identity.institutionCode,
      kind: identity.kind,
      activatedAtMs: 1,
    );
    final stale = ActivatedAdmin(
      accountId: '0x${'bb' * 32}',
      cidNumber: cidNumber,
      institutionCode: identity.institutionCode,
      kind: identity.kind,
      activatedAtMs: 2,
    );
    final unrelated = ActivatedAdmin(
      accountId: '0x${'cc' * 32}',
      cidNumber: otherCidNumber,
      institutionCode: otherIdentity.institutionCode,
      kind: otherIdentity.kind,
      activatedAtMs: 3,
    );

    await WalletIsar.instance.writeTxn((isar) async {
      await isar.walletAdminActivationStateEntitys.put(
        WalletAdminActivationStateEntity()
          ..id = 0
          ..payloadJson = jsonEncode(
            [active, stale, unrelated].map((item) => item.toJson()).toList(),
          ),
      );
    });
    final service = ActivationService(
      adminService: FakeAdminService(
        admins: [
          AdminPerson(
            account_id: '0x${'aa' * 32}',
            family_name: '管理',
            given_name: '员',
          ),
        ],
      ),
    );

    final records = await service.getActivatedAdmins(identity);
    expect(records.map((item) => item.accountId), ['0x${'aa' * 32}']);
    expect(records.single.toJson()['cid_number'], cidNumber);
    expect((await service.loadAll()).map((item) => item.accountId).toSet(), {
      '0x${'aa' * 32}',
      '0x${'cc' * 32}',
    });
  });

  test('管理员人员左连接岗位且无岗位人员不丢失', () {
    final first = AdminPerson(
      account_id: 'aa' * 32,
      family_name: '张',
      given_name: '三',
    );
    final second = AdminPerson(
      account_id: 'bb' * 32,
      family_name: '李',
      given_name: '四',
    );
    final assignment = InstitutionAdminAssignment(
      cidNumber: 'CID-1',
      account_id: first.account_id,
      roleCode: 'DIRECTOR',
      roleName: '负责人',
      termStart: 0,
      termEnd: 0,
      source: InstitutionAssignmentSource.genesis,
      sourceRef: '',
      active: true,
    );

    final views = InstitutionAdminService.mergeAdminViews(
      [first, second],
      [assignment],
    );

    expect(views, hasLength(2));
    expect(views.first.assignments, [assignment]);
    expect(views.last.admin.account_id, second.account_id);
    expect(views.last.assignments, isEmpty);
  });
}
