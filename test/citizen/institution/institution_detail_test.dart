// 统一机构详情页(ADR-028)widget 测试 —— 公权路径(信息卡/账户/提案占位/管理员/
// 提案列表/订阅)+ 统一账户行派生。替代旧 public_institution_detail_test。

import 'dart:async';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:citizenapp/citizen/administrators/institution_admin_service.dart';
import 'package:citizenapp/citizen/administrators/admin_activation_service.dart';
import 'package:citizenapp/citizen/proposal/proposal_context.dart';
import 'package:citizenapp/citizen/proposal/proposal_entry_page.dart';
import 'package:citizenapp/citizen/institution/institution_info.dart';
import 'package:citizenapp/citizen/institution/institution_assignment_card.dart';
import '../../support/fake_citizen_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizenapp/citizen/institution/institution.dart';
import 'package:citizenapp/citizen/institution/institution_accounts.dart';
import 'package:citizenapp/citizen/institution/institution_accounts_page.dart';
import 'package:citizenapp/citizen/institution/institution_chain_state.dart';
import 'package:citizenapp/citizen/institution/institution_detail_page.dart';
import 'package:citizenapp/citizen/institution/institution_repository.dart';
import 'package:citizenapp/citizen/public/public_institution_dto.dart';
import 'package:citizenapp/citizen/institution/institution_role_models.dart';
import 'package:citizenapp/citizen/administrators/admin_account.dart';
import 'package:citizenapp/citizen/account_derivation.dart';
import 'package:citizenapp/citizen/reserved_account_names.dart';
import 'package:citizenapp/storage/app_isar.dart';

import '../public/public_nav_harness.dart';

const _cid = 'LN001-CREG0-944805165-2026';
const _adminAccountId =
    '0xabababababababababababababababababababababababababababababababab';
const _fscCid = 'ZS001-FSC0W-434172688-2026';
const _fcsfAccountId =
    '0xc0e4ce3c11401ad661ae139081bbc797db51d0efe71df3ffb107f3dcb0064802';

class _FakeChainState implements InstitutionChainState {
  _FakeChainState({
    this.adminList = const [],
    this.proposalList = const [],
    this.balanceByAccountId = const {},
  });
  List<String> adminList;
  Future<List<InstitutionAdminView>> Function(Institution)? reader;
  Future<Map<String, double>>? balanceFuture;
  bool proposalsFail = false;
  int adminReads = 0;
  final List<InstitutionProposalSummary> proposalList;
  final Map<String, double> balanceByAccountId;

  @override
  Future<Map<String, double>> balances(List<String> publicKeyes) async =>
      balanceFuture ?? {for (final h in publicKeyes) h: balanceByAccountId[h] ?? 12.5};

  @override
  Future<List<InstitutionAdminView>> adminViews(
          Institution institution) async {
    adminReads++;
    if (reader != null) return reader!(institution);
    return adminList
          .map((account) => InstitutionAdminView(
                admin: AdminPerson(
                  account_id: account,
                  family_name: '管理',
                  given_name: '员',
                ),
                assignments: [
                  InstitutionAdminAssignment(
                    cidNumber: institution.cidNumber,
                    account_id: account,
                    roleCode: 'MEMBER',
                    roleName: '委员',
                    termStart: 0,
                    termEnd: 0,
                    source: InstitutionAssignmentSource.genesis,
                    sourceRef: '',
                    active: true,
                  ),
                ],
              ))
          .toList();
  }

  @override
  Future<List<InstitutionProposalSummary>> proposals(
    Institution institution,
  ) async {
    if (proposalsFail) throw StateError('合成提案读取失败');
    return proposalList;
  }
}

PublicInstitutionEntity _entity() => PublicInstitutionDto.fromJson(
      <String, dynamic>{
        'cid_number': _cid,
        'cid_full_name': '辽宁省身份注册局',
        'province_code': 'LN',
        'city_code': '001',
        'institution_code': 'CREG',
        'account_count': 4,
        'custom_account_names': ['业务专户'],
      },
    ).toEntity(catalogVersion: 'v', updatedAtMillis: 0);

PublicInstitutionEntity _fscEntity() => PublicInstitutionDto.fromJson(
      <String, dynamic>{
        'cid_number': _fscCid,
        'cid_full_name': '总统府联邦安全局',
        'cid_short_name': '联邦安全局',
        'province_code': 'ZS',
        'city_code': '001',
        'institution_code': 'FSC',
        'account_count': 3,
        'custom_account_names': [kReservedNameFcsf],
      },
    ).toEntity(catalogVersion: 'v', updatedAtMillis: 0);

Widget _wrap(Widget child) => MaterialApp(home: child);

/// 合成名册和权限时序，测试不打开设备钱包、激活存储或实际链会话。
List<InstitutionAdminView> _rows(int count, {bool loaded = true}) => [
  for (var i = 0; i < count; i++) InstitutionAdminView(
    admin: AdminPerson(account_id: i == 0 ? _adminAccountId : '0x${'bb' * 32}',
      family_name: '合成', given_name: '管理员$i'), assignmentsLoaded: loaded,
  )
];
class _RoleReader extends ProposalContextResolver {
  _RoleReader() : super(wallet: TestCitizenSdkWallet(),
    adminService: InstitutionAdminService(chain: TestCitizenChain()),
    activationService: ActivationService(adminService: InstitutionAdminService(chain: TestCitizenChain())));
  Future<ProposalContext> Function() read = () async => const ProposalContext();
  final cids = <String?>[];
  @override
  Future<ProposalContext> resolve({String? actorCidNumber, List<int>? executionAccountId,
      String? internalCode, InstitutionInfo? knownInstitution}) async {
    cids.add(actorCidNumber);
    expectSync(actorCidNumber, knownInstitution?.cidNumber);
    return read();
  }
}
class _ActivationReader extends ActivationService {
  _ActivationReader() : super(adminService: InstitutionAdminService(chain: TestCitizenChain()));
  bool failed = false;
  @override
  Future<List<ActivatedAdmin>> getActivatedAdmins(AdminAccountIdentity identity) async {
    if (failed) throw StateError('合成激活读取失败');
    return [];
  }
}
Future<void> _openDetails(WidgetTester tester, _FakeChainState chain,
    {_RoleReader? roles, _ActivationReader? activation, bool governance = false}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cid = governance ? 'LN001-NRC0G-944805165-2026' : _cid;
  final directory = await buildSeededRepo(provinceOrder: const ['LN'], institutions: [
    PublicInstitutionDto.fromJson({'cid_number': cid, 'cid_full_name': '合成机构',
      'province_code': 'LN', 'city_code': '001', 'institution_code': governance ? 'NRC' : 'CREG', 'account_count': 2}),
  ]);
  Widget app = MaterialApp(home: InstitutionDetailPage(cidNumber: cid,
    repository: InstitutionRepository(directory: directory), chainState: chain,
    contextResolver: roles, activationService: activation,
    subscriberCidNumberProvider: () async => null));
  if (roles != null || activation != null) {
    final transport = TestCitizenSdkTransport({'getWalletState': (_) => [testCitizenWalletState()]});
    final sdk = await transport.open();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await sdk.close(); await transport.dispose();
    });
    app = Provider<CitizenSdk>.value(value: sdk, child: app);
  }
  await tester.pumpWidget(app);
  for (var i = 0; i < 5; i++) { await tester.pump(); }
}
Future<void> _refreshAdmins(WidgetTester tester) async {
  await tester.tap(find.byTooltip('刷新管理员'));
  for (var i = 0; i < 5; i++) { await tester.pump(); }
}

void main() {
  testWidgets('名册加载中不显示0人，余额未完成也不阻塞人员', (tester) async {
    final people = Completer<List<InstitutionAdminView>>();
    final balance = Completer<Map<String, double>>();
    final chain = _FakeChainState()..reader = ((_) => people.future)..balanceFuture = balance.future;
    await _openDetails(tester, chain);
    expect(find.text('正在读取管理员'), findsOneWidget);
    expect(find.text('共 0 位管理员'), findsNothing);
    await tester.tap(find.text('管理员')); await tester.pump();
    expect(find.text('管理员列表'), findsNothing);
    people.complete(_rows(2)); await tester.pumpAndSettle();
    expect(find.text('共 2 位管理员'), findsOneWidget);
    expect(chain.adminReads, 1);
    balance.complete({}); await tester.pumpAndSettle();
  });
  testWidgets('首次人员读取失败显示重试，成功空集合才显示0', (tester) async {
    final chain = _FakeChainState()..reader = (_) async => throw StateError('合成人员失败');
    await _openDetails(tester, chain);
    expect(find.text('管理员读取失败，请重试'), findsOneWidget);
    expect(find.text('共 0 位管理员'), findsNothing);
    chain.reader = (_) async => [];
    await tester.tap(find.byKey(const ValueKey('admins-retry'))); await tester.pumpAndSettle();
    expect(find.text('共 0 位管理员'), findsOneWidget);
    expect(find.text('管理员读取失败'), findsNothing);
    expect(chain.adminReads, 2);
  });
  testWidgets('刷新名册失败保留人数，局部重试不重读余额或提案', (tester) async {
    final chain = _FakeChainState()..reader = (_) async => _rows(2);
    await _openDetails(tester, chain);
    chain.reader = (_) async => throw StateError('合成刷新失败');
    await _refreshAdmins(tester);
    expect(find.text('共 2 位管理员'), findsOneWidget);
    expect(find.text('管理员刷新失败，已保留名单'), findsOneWidget);
    chain.reader = (_) async => _rows(1);
    await tester.tap(find.byKey(const ValueKey('admins-retry'))); await tester.pumpAndSettle();
    expect(find.text('共 1 位管理员'), findsOneWidget);
    expect(find.text('管理员刷新失败，已保留名单'), findsNothing);
  });
  testWidgets('岗位未知不丢人员，可局部重试补齐岗位状态', (tester) async {
    final chain = _FakeChainState()..reader = (_) async => _rows(1, loaded: false);
    await _openDetails(tester, chain);
    expect(find.text('共 1 位管理员'), findsOneWidget);
    expect(find.text('岗位信息暂不可用'), findsOneWidget);
    chain.reader = (_) async => _rows(1);
    await tester.tap(find.byKey(const ValueKey('admins-retry'))); await tester.pumpAndSettle();
    expect(find.text('岗位信息暂不可用'), findsNothing);
    expect(find.text('共 1 位管理员'), findsOneWidget);
  });
  for (final fail in [false, true]) {
    testWidgets('迟到名册${fail ? '失败' : '成功'}不覆盖新刷新', (tester) async {
      final chain = _FakeChainState()..reader = (_) async => _rows(1);
      await _openDetails(tester, chain);
      final delayed = Completer<List<InstitutionAdminView>>(); chain.reader = (_) => delayed.future;
      await _refreshAdmins(tester);
      chain.reader = (_) async => _rows(2); await _refreshAdmins(tester);
      if (fail) { delayed.completeError(StateError('合成旧结果失败')); }
      else { delayed.complete([]); }
      await tester.pumpAndSettle();
      expect(find.text('共 2 位管理员'), findsOneWidget);
      expect(find.text('共 0 位管理员'), findsNothing);
      expect(find.byKey(const ValueKey('admins-retry')), findsNothing);
    });
  }
  for (final roleFailure in [true, false]) {
    testWidgets('${roleFailure ? '角色' : '激活'}读取失败不丢名册，不开放提案动作', (tester) async {
      final roles = _RoleReader(); final activation = _ActivationReader()..failed = !roleFailure;
      if (roleFailure) roles.read = () async => throw StateError('合成角色失败');
      final chain = _FakeChainState()..reader = ((_) async => _rows(1))..proposalsFail = true;
      await _openDetails(tester, chain, roles: roles, activation: activation);
      await tester.pumpAndSettle();
      expect(find.text('共 1 位管理员'), findsOneWidget);
      expect(find.text('当前钱包权限暂不可用'), findsOneWidget);
      expect(roles.cids, [_cid]); expect(chain.adminReads, 1);
      await tester.tap(find.text('发起提案')); await tester.pumpAndSettle();
      expect(tester.widget<ProposalEntryPage>(find.byType(ProposalEntryPage)).isActivated, isFalse);
    });
  }
  testWidgets('角色失败后重试可核实，名册不用重复读取', (tester) async {
    final roles = _RoleReader()..read = () async => throw StateError('合成角色失败');
    final chain = _FakeChainState()..reader = (_) async => _rows(1);
    await _openDetails(tester, chain, roles: roles, activation: _ActivationReader());
    roles.read = () async => const ProposalContext();
    await tester.tap(find.byKey(const ValueKey('admin-role-retry'))); await tester.pumpAndSettle();
    expect(find.text('当前钱包权限暂不可用'), findsNothing);
    expect(find.text('共 1 位管理员'), findsOneWidget);
    expect(chain.adminReads, 1); expect(roles.cids, [_cid, _cid]);
  });
  testWidgets('旧角色成功不能恢复刷新后已撤销的操作状态', (tester) async {
    final delayed = Completer<ProposalContext>();
    final roles = _RoleReader()..read = () => delayed.future;
    final chain = _FakeChainState()..reader = (_) async => _rows(1);
    await _openDetails(tester, chain, roles: roles, activation: _ActivationReader());
    roles.read = () async => const ProposalContext(); await _refreshAdmins(tester);
    delayed.complete(const ProposalContext(role: ProposalRole.admin)); await tester.pumpAndSettle();
    await tester.tap(find.text('发起提案')); await tester.pumpAndSettle();
    expect(tester.widget<ProposalEntryPage>(find.byType(ProposalEntryPage)).isActivated, isFalse);
  });
  testWidgets('固定治理机构也走唯一名册路径，角色失败不影响人数', (tester) async {
    final roles = _RoleReader()..read = () async => throw StateError('合成治理角色失败');
    final chain = _FakeChainState()..reader = (_) async => _rows(2);
    await _openDetails(tester, chain, roles: roles, activation: _ActivationReader(), governance: true);
    await tester.pumpAndSettle();
    expect(find.text('共 2 位管理员'), findsOneWidget);
    expect(find.text('当前钱包权限暂不可用'), findsOneWidget);
    expect(roles.cids, ['LN001-NRC0G-944805165-2026']); expect(chain.adminReads, 1);
  });
  testWidgets('旧角色失败不能污染新核对成功结果', (tester) async {
    final delayed = Completer<ProposalContext>(); final roles = _RoleReader()..read = () => delayed.future;
    final chain = _FakeChainState()..reader = (_) async => _rows(1);
    await _openDetails(tester, chain, roles: roles, activation: _ActivationReader());
    roles.read = () async => const ProposalContext(); await _refreshAdmins(tester);
    delayed.completeError(StateError('合成旧角色失败')); await tester.pumpAndSettle();
    expect(find.text('当前钱包权限暂不可用'), findsNothing);
    expect(find.text('共 1 位管理员'), findsOneWidget);
  });
  for (final loaded in [false, true]) {
    testWidgets('共用人员卡区分${loaded ? '已核实无岗位' : '岗位未知'}并保留姓名账户', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: InstitutionAssignmentCard(
        adminView: _rows(1, loaded: loaded).single))));
      expect(find.text('合成管理员0'), findsOneWidget);
      expect(find.text(loaded ? '岗位：暂无岗位' : '岗位信息暂不可用'), findsOneWidget);
      expect(find.text(loaded ? '岗位信息暂不可用' : '岗位：暂无岗位'), findsNothing);
      expect(find.textContaining('管理员账户：'), findsOneWidget);
    });
  }

  group('institutionAccountIdRows(公权派生)', () {
    test('主/费/自定义三行,地址与卡0 派生吻合', () {
      final rows =
          institutionAccountIdRows(Institution.fromPublicEntity(_entity()));
      expect(rows.map((r) => r.label), ['主账户', '费用账户', '业务专户']);
      expect(rows.first.accountId,
          accountIdText(deriveInstitutionMainAccountId(_cid)));
      expect(
        rows.last.accountId,
        accountIdText(deriveInstitutionCustomAccountId(_cid, '业务专户')),
      );
    });

    test('联邦安全局第三行走 OP_FCSF，不回落普通 OP_NAME', () {
      final rows = institutionAccountIdRows(
        Institution.fromPublicEntity(_fscEntity()),
      );
      expect(
        rows.map((r) => r.label),
        [kReservedNameMain, kReservedNameFee, kReservedNameFcsf],
      );
      expect(rows, hasLength(3));
      expect(rows.last.accountId, _fcsfAccountId);
      expect(
        rows.last.accountId,
        isNot(
          '0x1f5f77852f56e6d97b7f300d0ee883909e7ebbcd5b68d2a59c38a5520fcd1204',
        ),
      );
    });
  });

  testWidgets('联邦安全局全部账户页显示 FCSF 正确余额', (tester) async {
    final institution = Institution.fromPublicEntity(_fscEntity());
    await tester.pumpWidget(
      _wrap(
        InstitutionAccountsPage(
          institution: institution,
          chainState: _FakeChainState(
            balanceByAccountId: const {_fcsfAccountId: 10000000000.0},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部账户'), findsOneWidget);
    expect(find.text(kReservedNameFcsf), findsOneWidget);
    expect(find.text('10,000,000,000.00 元'), findsOneWidget);
  });

  testWidgets('详情页:全称/ID/主账户/余额/法代/所属地 + 账户/提案占位/管理员/提案列表', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await buildSeededRepo(
      provinceOrder: const ['GD'],
      institutions: [
        PublicInstitutionDto.fromJson(<String, dynamic>{
          'cid_number': _cid,
          'cid_full_name': '辽宁省身份注册局',
          'province_code': 'GD',
          'city_code': '001',
          'institution_code': 'CREG',
          'account_count': 4,
          'legal_representative': {
            'family_name': '王',
            'given_name': '法人',
            'cid_number': 'CID-1',
            'account': '11',
          },
          'custom_account_names': ['业务专户'],
        }),
      ],
      cityNames: const {'GD|001': '中央'},
    );
    final chain = _FakeChainState(
      adminList: const [_adminAccountId],
      proposalList: const [
        InstitutionProposalSummary(proposalId: 7, idLabel: '提案 #7', status: 1),
      ],
    );
    await tester.pumpWidget(_wrap(InstitutionDetailPage(
      cidNumber: _cid,
      repository: InstitutionRepository(directory: repo),
      chainState: chain,
      subscriberCidNumberProvider: () async => 'CID-USER',
    )));
    await tester.pumpAndSettle();

    expect(find.text('辽宁省身份注册局'), findsWidgets); // AppBar 简称回退全称 + 全称行
    expect(find.text(_cid), findsOneWidget);
    expect(find.text('全称'), findsOneWidget);
    expect(find.text('身份CID号'), findsOneWidget);
    expect(find.text('身份ID'), findsNothing);
    expect(find.text('主账户'), findsOneWidget);
    expect(find.text('主账户余额'), findsOneWidget);
    expect(find.text('12.50 元'), findsOneWidget);
    expect(find.text('法定代表人'), findsOneWidget);
    expect(find.text('王法人'), findsOneWidget);
    expect(find.text('所属地'), findsOneWidget);
    expect(find.text('广东省 · 中央'), findsOneWidget);
    // 机构账户入口:主+费+1自定义=3。
    expect(find.text('机构账户'), findsOneWidget);
    expect(find.text('共 3 个账户'), findsOneWidget);
    // 提案入口(公权占位)。
    expect(find.text('发起提案'), findsOneWidget);
    // 管理员入口。
    expect(find.text('管理员'), findsOneWidget);
    expect(find.text('共 1 位管理员'), findsOneWidget);
    // 提案列表。
    expect(find.text('提案列表'), findsOneWidget);
    expect(find.text('提案 #7'), findsOneWidget);
  });

  testWidgets('管理员入口点击进入可激活管理员列表页', (tester) async {
    final repo = await buildSeededRepo(
      provinceOrder: const ['LN'],
      institutions: [
        PublicInstitutionDto.fromJson(<String, dynamic>{
          'cid_number': _cid,
          'cid_full_name': '辽宁省身份注册局',
          'province_code': 'LN',
          'city_code': '001',
          'institution_code': 'CREG',
          'account_count': 2,
        }),
      ],
      cityNames: const {'LN|001': '中央'},
    );
    await tester.pumpWidget(_wrap(InstitutionDetailPage(
      cidNumber: _cid,
      repository: InstitutionRepository(directory: repo),
      chainState: _FakeChainState(adminList: const [_adminAccountId]),
      subscriberCidNumberProvider: () async => 'CID-USER',
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('管理员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理员'));
    await tester.pumpAndSettle();
    expect(find.text('管理员列表'), findsOneWidget);
    expect(find.textContaining('共 1 位管理员'), findsOneWidget);
  });

  testWidgets('订阅按钮切换写入 store', (tester) async {
    final repo = await buildSeededRepo(
      provinceOrder: const ['LN'],
      institutions: [
        PublicInstitutionDto.fromJson(<String, dynamic>{
          'cid_number': _cid,
          'cid_full_name': '辽宁省身份注册局',
          'province_code': 'LN',
          'city_code': '001',
          'institution_code': 'CREG',
          'account_count': 2,
        }),
      ],
      cityNames: const {'LN|001': '中央'},
    );
    await tester.pumpWidget(_wrap(InstitutionDetailPage(
      cidNumber: _cid,
      repository: InstitutionRepository(directory: repo),
      chainState: _FakeChainState(),
      subscriberCidNumberProvider: () async => 'CID-USER',
    )));
    await tester.pumpAndSettle();

    expect(await repo.isSubscribed('CID-USER', _cid), isFalse);
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    expect(await repo.isSubscribed('CID-USER', _cid), isTrue);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();
    expect(await repo.isSubscribed('CID-USER', _cid), isFalse);
  });
}
