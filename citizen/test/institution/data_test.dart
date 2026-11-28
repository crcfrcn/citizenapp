// 验证机构模型、角色及编解码。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/data.dart' show ProposalCapabilityRegistry, ProposalKind, ProposalSubject;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAccounts, InstitutionInfo, OrgType;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:citizen_citizen/institution/data.dart' show InstitutionAssignment, InstitutionAssignmentSource, RolePermissionOperation, VotingEngineKind;
import 'package:citizen_citizen/institution/codec.dart' show InstitutionRoleStorageCodec;
import 'package:citizen_citizen/institution/service.dart' show InstitutionChainService;
import 'package:citizen_citizen/institution/data.dart' show CloseProposalInfo, InstitutionProposalInfo;
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/codec.dart' show InstitutionProposalCodec;

void main() {
  group('institution_info_test', _registerInfo);
  group('institution_role_storage_codec_test', _registerRoles);
  group('institution_proposal_test', _registerProposal);
}

// 验证机构CID和个人多签身份、真实名称及提案能力。

void _registerInfo() {
  test('注册机构以 CID 为身份，主/费账户只作为其账户集合', () {
    final address = '0x${'11' * 32}';
    const cidNumber = 'GD001-CGOV0-123456789-2026';
    final institution = InstitutionInfo(
      fullName: '机构',
      shortName: '机构',
      cidFullNameEn: 'Institution',
      cidShortNameEn: 'Institution',
      cidNumber: cidNumber,
      orgType: OrgType.institution,
      adminCode: 'CGOV',
      accounts: InstitutionAccounts(
        mainAccountId: address,
        feeAccountId: '0x${'12' * 32}',
      ),
    );
    expect(institution.cidNumber, cidNumber);
    expect(institution.mainAccountId, address);
    expect(institution.isRegisteredInstitution, isTrue);
  });

  test('FRG/NJD 是固定治理机构且使用制度阈值，不误判为注册机构', () {
    InstitutionInfo fixed(String code) => InstitutionInfo(
      fullName: code,
      shortName: code,
      cidFullNameEn: code,
      cidShortNameEn: code,
      cidNumber: 'ZS001-${code}00-123456789-2026',
      orgType: OrgType.institution,
      adminCode: code,
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'31' * 32}',
        feeAccountId: '0x${'32' * 32}',
      ),
    );

    final frg = fixed('FRG');
    final njd = fixed('NJD');
    expect(frg.internalThreshold, 3);
    expect(njd.internalThreshold, 8);
    expect(frg.isRegisteredInstitution, isFalse);
    expect(njd.isRegisteredInstitution, isFalse);
  });

  group('ProposalCapabilityRegistry', () {
    InstitutionInfo info({
      required String code,
      required String accountId,
      int orgType = OrgType.institution,
      String? cidNumber,
    }) {
      return InstitutionInfo(
        fullName: code,
        shortName: code,
        cidFullNameEn: code,
        cidShortNameEn: code,
        cidNumber: cidNumber ?? 'GD001-${code}0-123456789-2026',
        orgType: orgType,
        adminCode: code,
        accounts: InstitutionAccounts(
          mainAccountId: accountId,
          feeAccountId: '0x${'fe' * 32}',
        ),
      );
    }

    Set<ProposalKind> kinds(ProposalSubject subject) {
      return ProposalCapabilityRegistry.capabilitiesForSubject(
        subject,
      ).map((capability) => capability.kind).toSet();
    }

    test('NRC exposes governance-only proposal capabilities', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(
          code: 'NRC',
          accountId: '0x${'33' * 32}',
          orgType: OrgType.nrc,
          cidNumber: 'LN001-NRC0G-944805165-2026',
        ),
        orgCode: 'NRC',
      );
      final result = kinds(subject);
      expect(subject.cidNumber, 'LN001-NRC0G-944805165-2026');
      expect(result, contains(ProposalKind.transfer));
      expect(result, contains(ProposalKind.feeTransfer));
      expect(result, contains(ProposalKind.safetyFundTransfer));
      expect(result, contains(ProposalKind.resolutionIssuance));
      expect(result, contains(ProposalKind.runtimeUpgrade));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
    });

    test('city registry is public institution, not governance', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(code: 'CREG', accountId: '0x${'44' * 32}'),
        orgCode: 'CREG',
      );
      final result = kinds(subject);
      expect(subject.cidNumber, 'GD001-CREG0-123456789-2026');
      expect(result, contains(ProposalKind.transfer));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
      expect(result, isNot(contains(ProposalKind.feeTransfer)));
      expect(result, isNot(contains(ProposalKind.runtimeUpgrade)));
    });

    test(
      'private institution gets only generic active-account capabilities',
      () {
        final subject = ProposalSubject.fromInstitution(
          institution: info(code: 'SFGQ', accountId: '0x${'55' * 32}'),
          orgCode: 'SFGQ',
        );
        final result = kinds(subject);
        expect(subject.cidNumber, 'GD001-SFGQ0-123456789-2026');
        expect(result, contains(ProposalKind.transfer));
        expect(result, isNot(contains(ProposalKind.adminsChange)));
        expect(result, isNot(contains(ProposalKind.resolutionIssuance)));
      },
    );

    test('unincorporated code does not auto-enable admins change', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(code: 'UNIN', accountId: '0x${'66' * 32}'),
        orgCode: 'UNIN',
      );
      final result = kinds(subject);
      expect(result, contains(ProposalKind.transfer));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
    });
  });
}

// 验证岗位、任职、管理员及投票计划的严格SCALE布局。

void _registerRoles() {
  List<int> bytes(String text) => [
    (utf8.encode(text).length << 2),
    ...utf8.encode(text),
  ];

  List<int> compact(int value) {
    if (value < 64) return [value << 2];
    final encoded = (value << 2) | 1;
    return [encoded & 0xff, (encoded >> 8) & 0xff];
  }

  Map<String, dynamic> readRolePermissionFixture() {
    // 只读实际仓库的单一金标位置，不受本端中央工作根影响。
    final root = Platform.environment['CITIZENCHAIN_ROOT'];
    if (root == null || !root.startsWith('/')) {
      throw StateError('岗位金标检查缺少准确 CITIZENCHAIN_ROOT');
    }
    final file = File(
      '$root/runtime/primitives/tests/fixtures/role_permission.json',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Uint8List fixtureBytes(Map<String, dynamic> fixture, String name) {
    final cases = fixture['cases']! as List<dynamic>;
    final entry = cases.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['name'] == name,
    );
    final hex = entry['encoded_hex']! as String;
    return Uint8List.fromList([
      for (var index = 0; index < hex.length; index += 2)
        int.parse(hex.substring(index, index + 2), radix: 16),
    ]);
  }

  test('岗位权限与 VotePlan 严格解码统一 SCALE fixture', () {
    final fixture = readRolePermissionFixture();
    final role = InstitutionRoleStorageCodec.decodeRoleSubject(
      fixtureBytes(fixture, 'role_subject_nrc_committee'),
    )!;
    expect(role.cidNumber, 'LN001-NRC0G-944805165-2026');
    expect(role.roleCode, 'COMMITTEE_MEMBER');

    final action = InstitutionRoleStorageCodec.decodeBusinessActionId(
      fixtureBytes(fixture, 'business_action_resolution_issuance'),
    )!;
    expect(action.moduleTag, 'res-iss');
    expect(action.actionCode, 0);

    final permission = InstitutionRoleStorageCodec.decodeRoleBusinessPermission(
      fixtureBytes(fixture, 'permission_resolution_issuance_propose'),
    )!;
    expect(permission.operation, RolePermissionOperation.propose);
    expect(permission.roleSubject.roleCode, 'COMMITTEE_MEMBER');

    final personal = InstitutionRoleStorageCodec.decodeAuthorizationSubject(
      fixtureBytes(fixture, 'authorization_personal_multisig'),
    )!;
    expect(personal.isInstitution, isFalse);
    expect(personal.accountId, '07' * 32);

    final plan = InstitutionRoleStorageCodec.decodeVotePlan(
      fixtureBytes(fixture, 'vote_plan_resolution_issuance_joint'),
    )!;
    expect(plan.businessActionId.moduleTag, 'res-iss');
    expect(plan.proposalOwner, 'res-iss');
    expect(plan.proposerSubject.roleSubject!.roleCode, 'COMMITTEE_MEMBER');
    expect(plan.voterSubjects, hasLength(3));
    expect(plan.voterSubjects.last.roleSubject!.roleCode, 'DIRECTOR');
    expect(plan.votingEngine, VotingEngineKind.joint);
    expect(plan.businessObjectHash, 'ab' * 32);

    final withTrailingByte = Uint8List.fromList([
      ...fixtureBytes(fixture, 'vote_plan_resolution_issuance_joint'),
      0,
    ]);
    expect(
      InstitutionRoleStorageCodec.decodeVotePlan(withTrailingByte),
      isNull,
    );
  });

  test('岗位权限 storage 向量严格解码并拒绝重复项', () {
    final fixture = readRolePermissionFixture();
    final permission = fixtureBytes(
      fixture,
      'permission_resolution_issuance_propose',
    );
    final decoded = InstitutionRoleStorageCodec.decodeRolePermissions(
      Uint8List.fromList([4, ...permission]),
    )!;
    expect(decoded, hasLength(1));
    expect(decoded.single.businessActionId.moduleTag, 'res-iss');

    expect(
      InstitutionRoleStorageCodec.decodeRolePermissions(
        Uint8List.fromList([8, ...permission, ...permission]),
      ),
      isNull,
    );
  });

  test('人员CID快照拒绝旧钱包名册、合并姓名、重复和尾随布局', () {
    const person = 'CN220-CTZN2-198805200-2026';
    final encoded = Uint8List.fromList([4, ...bytes(person)]);
    expect(InstitutionRoleStorageCodec.decodePersons(encoded), [person]);
    for (final raw in [
      [...utf8.encode('CGOV'), 4, ...List.filled(32, 7)],
      [4, ...bytes('管理员'), ...List.filled(32, 7)],
      [8, ...bytes(person), ...bytes(person)],
      [...encoded, 0],
      [4, 4, 0xff],
    ]) {
      expect(
        InstitutionRoleStorageCodec.decodePersons(Uint8List.fromList(raw)),
        isNull,
      );
    }
    for (var length = 0; length < encoded.length; length++) {
      expect(
        InstitutionRoleStorageCodec.decodePersons(
          Uint8List.sublistView(encoded, 0, length),
        ),
        isNull,
      );
    }
    expect(
      InstitutionRoleStorageCodec.isPersonCid(person, private: false),
      true,
    );
    const resident = 'CN220-NATP2-198805200-2026';
    expect(InstitutionRoleStorageCodec.isPersonCid(resident), true);
    expect(
      InstitutionRoleStorageCodec.isPersonCid(resident, private: false),
      false,
    );
  });

  test('岗位和任职分别按 entity 布局解码', () {
    final role = InstitutionRoleStorageCodec.decodeRole(
      Uint8List.fromList([
        ...bytes('CID-1'),
        ...bytes('DIRECTOR'),
        ...bytes('董事'),
        1,
        0,
        1,
        0,
        0,
        0,
      ]),
    )!;
    expect(role.roleName, '董事');
    expect(role.termRequired, isTrue);

    final assignment = InstitutionRoleStorageCodec.decodeAssignments(
      Uint8List.fromList([
        4,
        ...bytes('CID-1'),
        ...bytes('CN220-CTZN2-198805200-2026'),
        ...bytes('DIRECTOR'),
        10,
        0,
        0,
        0,
        20,
        0,
        0,
        0,
        1,
        ...bytes('REG-1'),
        0,
      ]),
    )!.single;
    expect(assignment.source, InstitutionAssignmentSource.registry);
    expect(assignment.personCid, 'CN220-CTZN2-198805200-2026');
  });

  test('任职向量允许已核实空集，截断或尾随字节必须拒绝', () {
    final encoded = Uint8List.fromList([
      4,
      ...bytes('CID-1'),
      ...bytes('CN220-CTZN2-198805200-2026'),
      ...bytes('MEMBER'),
      ...List.filled(8, 0),
      0,
      ...bytes(''),
      0,
    ]);
    expect(
      InstitutionRoleStorageCodec.decodeAssignments(Uint8List.fromList([0])),
      isEmpty,
    );
    for (var length = 0; length < encoded.length; length++) {
      expect(
        InstitutionRoleStorageCodec.decodeAssignments(
          Uint8List.sublistView(encoded, 0, length),
        ),
        isNull,
        reason: '截断任职不得被当作空岗位',
      );
    }
    expect(
      InstitutionRoleStorageCodec.decodeAssignments(
        Uint8List.fromList([...encoded, 0]),
      ),
      isNull,
    );
    expect(
      InstitutionRoleStorageCodec.decodeAssignments(encoded)!.single.personCid,
      'CN220-CTZN2-198805200-2026',
    );
  });

  for (final value in <(List<int>, String)>[
    ([], ''),
    (utf8.encode('登记-甲'), '登记-甲'),
    ([0x80, 0, 0, 0, 0, 0, 0, 0], '0x8000000000000000'),
    ([0x0a], '0x0a'),
    ([0x7f], '0x7f'),
    ([0xc2, 0x85], '0xc285'),
  ]) {
    test('任职来源引用按可读文本或完整二进制显示：${value.$2}', () {
      final raw = Uint8List.fromList([
        4,
        ...bytes('CID-1'),
        ...bytes('CN220-CTZN2-198805200-2026'),
        ...bytes('MEMBER'),
        ...List.filled(8, 0),
        0,
        ...compact(value.$1.length),
        ...value.$1,
        0,
      ]);
      final decoded = InstitutionRoleStorageCodec.decodeAssignments(raw)!;
      expect(decoded.single.sourceRef, value.$2);
      expect(decoded.single.personCid, 'CN220-CTZN2-198805200-2026');
      expect(decoded.single.roleCode, 'MEMBER');
      expect(
        InstitutionRoleStorageCodec.decodeAssignments(
          Uint8List.fromList([...raw, 0]),
        ),
        isNull,
      );
    });
  }

  test('任期窗口包含起止日且无任期岗位只接受零值', () {
    final base = InstitutionAssignment(
      cidNumber: 'CID-1',
      personCid: 'CN220-CTZN2-198805200-2026',
      roleCode: 'ROLE-1',
      termStart: 10,
      termEnd: 20,
      source: InstitutionAssignmentSource.institutionGovernance,
      sourceRef: 'proposal',
      active: true,
      termRequired: true,
    );
    expect(base.isEffectiveOnDay(10), isTrue);
    expect(base.isEffectiveOnDay(20), isTrue);
    expect(base.isEffectiveOnDay(21), isFalse);
    expect(base.termLabel, '1970/01/11-1970/01/21');
    final nonTerm = InstitutionAssignment(
      cidNumber: 'CID-1',
      personCid: 'CN220-CTZN2-198805200-2026',
      roleCode: 'ROLE-2',
      termStart: 0,
      termEnd: 0,
      source: InstitutionAssignmentSource.institutionGovernance,
      sourceRef: 'proposal',
      active: true,
    );
    expect(nonTerm.isEffectiveOnDay(20), isTrue);
    expect(nonTerm.termLabel, '无固定任期');
  });

  test('任期显示使用UTC日期并正确处理闰日和未写入端点', () {
    String label(int start, int end) => InstitutionAssignment(
      cidNumber: 'CID-1',
      personCid: 'CN220-CTZN2-198805200-2026',
      roleCode: 'MEMBER',
      termStart: start,
      termEnd: end,
      termRequired: true,
      source: InstitutionAssignmentSource.genesis,
      sourceRef: '',
      active: true,
    ).termLabel;
    final leap =
        DateTime.utc(2028, 2, 29).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    expect(label(leap, leap + 1), '2028/02/29-2028/03/01');
    expect(label(0, 0), '待写入');
    expect(label(0, leap), '—-2028/02/29');
  });

  test('岗位身份文本拒绝畸形 UTF-8 和非法 bool', () {
    final malformedCid = Uint8List.fromList([
      4,
      0xff,
      ...bytes('DIRECTOR'),
      ...bytes('董事'),
      1,
      0,
    ]);
    expect(InstitutionRoleStorageCodec.decodeRole(malformedCid), isNull);

    final invalidBool = Uint8List.fromList([
      ...bytes('CID-1'),
      ...bytes('DIRECTOR'),
      ...bytes('董事'),
      2,
      0,
    ]);
    expect(InstitutionRoleStorageCodec.decodeRole(invalidBool), isNull);
  });

  test('机构命名账户关闭动作保留 actor CID 与具体机构账户', () {
    const actorCidNumber = 'GD001-CGOV0-123456789-2026';
    final actorCidBytes = utf8.encode(actorCidNumber);
    final body = <int>[
      ...utf8.encode('pub-mgmt'),
      InstitutionChainService.actionClose,
      ...compact(actorCidBytes.length),
      ...actorCidBytes,
      ...List.filled(32, 0x21),
      ...List.filled(32, 0x22),
      ...List.filled(32, 0x23),
    ];
    final raw = Uint8List.fromList([...compact(body.length), ...body]);
    final decoded = InstitutionChainService().decodeManageProposalData(
      BigInt.from(7),
      raw,
    );
    expect(decoded, isA<CloseProposalInfo>());
    final close = decoded! as CloseProposalInfo;
    expect(close.actorCidNumber, actorCidNumber);
    expect(close.institutionAccountId, '21' * 32);

    expect(
      InstitutionChainService().decodeManageProposalData(
        BigInt.from(7),
        Uint8List.fromList([...raw, 0]),
      ),
      isNull,
    );
  });
}

// 核对Runtime真实编码金标、四类详情及未知/损坏数据的拒绝边界。

Uint8List raw(Map<String, dynamic> row) {
  final text = row['encoded_hex'] as String;
  return Uint8List.fromList([
    for (var i = 0; i < text.length; i += 2)
      int.parse(text.substring(i, i + 2), radix: 16),
  ]);
}

void _registerProposal() {
  final source =
      jsonDecode(
            File(
              'citizen/test/institution/institution_proposals.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (source['cases'] as List).cast<Map<String, dynamic>>();
  test('八个公私权管理载荷完整解码，保留原始内容及缓存回读', () {
    expect(cases, hasLength(8));
    for (final row in cases) {
      final bytes = raw(row),
          info = InstitutionProposalCodec.decode(BigInt.one, raw(row));
      expect(bytes.length, row['byte_length']);
      expect(info, isNotNull, reason: row['name'] as String);
      expect(info!.actorCidNumber, row['cid_number']);
      expect(info.rows, isNotEmpty);
      final saved =
          jsonDecode(jsonEncode(info.toJson())) as Map<String, dynamic>;
      final restored = InstitutionProposalInfo.fromJson(BigInt.one, saved);
      expect(restored?.toJson(), info.toJson());
      final values = info.rows.map((r) => r.value).join('；');
      if (row['action'] == 3) {
        for (final value in [
          '财务岗',
          'R_CONFIG',
          '新名称',
          'R_DELETE',
          '日序100—200',
          'CN220-CTZN2-198805200-2026',
        ]) {
          expect(values, contains(value));
        }
      }
      if (row['action'] == 5) {
        expect(values, contains('multisig / 0 / 发起'));
        expect(values, contains('multisig / 0 / 表决'));
        expect(values, contains('原阈值批准'));
        expect(values, contains('09' * 32));
      }
      if (row['action'] == 2) expect(info, isA<CloseProposalInfo>());
    }
  });
  test('每一截断位置、尾随及错误命名空间都拒绝，不降级成关闭', () {
    for (final row in cases) {
      final bytes = raw(row);
      for (var length = 0; length < bytes.length; length++) {
        expect(
          InstitutionProposalCodec.decode(
            BigInt.one,
            Uint8List.sublistView(bytes, 0, length),
          ),
          isNull,
        );
      }
      expect(
        InstitutionProposalCodec.decode(
          BigInt.one,
          Uint8List.fromList([...bytes, 0]),
        ),
        isNull,
      );
      final bad = Uint8List.fromList(bytes),
          offset = CitizenScale.readCompact(bytes, 0).$2;
      bad[offset] = 0;
      expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
      bad.setAll(0, bytes);
      bad[offset + 8] = 255;
      expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    }
  });
  test('治理未知枚举和机构码错配拒绝；缓存未知类型不成为权限', () {
    final bytes = raw(cases.firstWhere((r) => r['action'] == 3));
    final offset = CitizenScale.readCompact(bytes, 0).$2;
    final bad = Uint8List.fromList(bytes);
    bad[offset + 9] = 0;
    expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    bad.setAll(0, bytes);
    var cursor = offset + 13;
    final (length, size) = CitizenScale.readCompact(bytes, cursor);
    cursor += length + size;
    cursor += CitizenScale.readCompact(bytes, cursor).$2;
    bad[cursor] = 4;
    expect(InstitutionProposalCodec.decode(BigInt.one, bad), isNull);
    expect(
      InstitutionProposalInfo.fromJson(BigInt.one, {
        'kind': 'unknown',
        'actor_cid_number': 'somewhere',
      }),
      isNull,
    );
    expect(
      InstitutionProposalInfo.fromJson(BigInt.one, {
        'kind': 'institution_change',
        'action': 5,
        'actor_cid_number': 'somewhere',
        'rows': [
          {'label': '权限', 'value': 1, 'copyable': true},
        ],
      }),
      isNull,
    );
  });
}
