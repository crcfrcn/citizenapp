// 验证机构详情、人员任职及当前钱包展示，保留账户、余额和关注回归。
import 'dart:async';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_citizen/institution/institution_models.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/institution_manage_detail_page.dart';
import 'package:citizen_citizen/proposal/proposal_detail_local_store.dart';
import 'package:citizen_citizen/proposal/proposal_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart' as app_store show Entity;
import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_accounts_page.dart';
import 'package:citizen_citizen/institution/institution_chain_state.dart';
import 'package:citizen_citizen/institution/institution_detail_page.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/institution/institution_assignment_card.dart';
import 'package:citizen_citizen/institution/institution_assignments_page.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/public/public_institution_dto.dart';
import 'package:citizen_citizen/public/public_institution_assignments_page.dart';
import 'package:citizen_citizen/proposal/proposal_vote_widgets.dart';
import 'package:citizen_citizen/reserved_account_names.dart';
import 'package:citizen_testing/institution/public_nav_harness.dart';

const _cid = 'LN001-CREG0-944805165-2026';
const _adminAccountId =
    '0xabababababababababababababababababababababababababababababababab';
const _fscCid = 'ZS001-FSC0W-434172688-2026';
const _fcsfAccountId =
    '0xc0e4ce3c11401ad661ae139081bbc797db51d0efe71df3ffb107f3dcb0064802';

InstitutionPersonView _person(
  String? wallet, {
  List<String> roles = const ['MEMBER'],
}) => InstitutionPersonView(
  personCid: 'CN220-CTZN2-198805200-2026',
  accountId: wallet,
  assignments: [
    for (final role in roles)
      InstitutionAssignment(
        cidNumber: _cid,
        personCid: 'CN220-CTZN2-198805200-2026',
        roleCode: role,
        roleName: role == 'MEMBER' ? '委员' : '主任',
        termStart: 0,
        termEnd: 0,
        source: InstitutionAssignmentSource.genesis,
        sourceRef: '',
        active: true,
      ),
  ],
);

class _FakeChainState implements InstitutionChainState {
  _FakeChainState({
    this.wallets = const [],
    this.proposalList = const [],
    this.balanceByAccountId = const {},
  });
  List<String> wallets;
  Future<List<InstitutionPersonView>> Function(Institution)? reader;
  final List<InstitutionProposalSummary> proposalList;
  final Map<String, BigInt> balanceByAccountId;
  CitizenBalances? _balances;
  CitizenBalances get balances => _balances ??= CitizenBalances(
    getAccountBalances: (ids) async => [
      for (final id in ids)
        CitizenAccountBalance(
          accountId: id,
          block: CitizenBlockRef(
            hash: '0x${'11' * 32}',
            number: BigInt.one,
            finality: CitizenBlockFinality.finalized,
          ),
          freeFen: balanceByAccountId[id] ?? BigInt.from(1250),
          reservedFen: BigInt.zero,
          totalFen: balanceByAccountId[id] ?? BigInt.from(1250),
        ),
    ],
  );
  @override
  Future<List<InstitutionPersonView>> personViews(
    Institution institution,
  ) async => reader == null
      ? wallets.map((wallet) => _person(wallet)).toList()
      : reader!(institution);
  @override
  Future<List<InstitutionProposalSummary>> proposals(
    Institution institution,
  ) async => proposalList;
}

app_store.Entity _fscEntity() =>
    PublicInstitutionDto.fromJson(<String, dynamic>{
      'cid_number': _fscCid,
      'cid_full_name': '总统府联邦安全局',
      'cid_short_name': '联邦安全局',
      'province_code': 'ZS',
      'city_code': '001',
      'institution_code': 'FSC',
      'account_count': 3,
      'custom_account_names': [kReservedNameFcsf],
    }).toEntity();

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    Provider<CitizenBalances>.value(
      value: _FakeChainState(
        balanceByAccountId: {_fcsfAccountId: BigInt.from(1000000000000)},
      ).balances,
    ),
  ],
  child: MaterialApp(home: child),
);

Future<void> _openDetails(WidgetTester tester, _FakeChainState chain) async {
  final directory = await buildSeededRepo(
    provinceOrder: const ['LN'],
    institutions: [
      PublicInstitutionDto.fromJson({
        'cid_number': _cid,
        'cid_full_name': '合成机构',
        'province_code': 'LN',
        'city_code': '001',
        'institution_code': 'CREG',
        'account_count': 2,
      }),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<CitizenBalances>.value(value: chain.balances)],
      child: MaterialApp(
        home: InstitutionDetailPage(
          cidNumber: _cid,
          repository: InstitutionRepository(directory: directory),
          chainState: chain,
          subscriberCidNumberProvider: () async => null,
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  useIsolatedIsar();
  testWidgets('政策缓存展示完整权限及指纹，错误机构正文不能出现投票按钮', (tester) async {
    final institution = InstitutionInfo(
      fullName: '测试机构',
      shortName: '测试',
      cidFullNameEn: 'Test',
      cidShortNameEn: 'Test',
      cidNumber: _cid,
      orgType: OrgType.institution,
      adminCode: 'CREG',
      accounts: const InstitutionAccounts(
        mainAccountId: _adminAccountId,
        feeAccountId: _fcsfAccountId,
      ),
      internalThresholdOverride: 2,
    );
    final id = BigInt.from(9901);
    Future<void> seed(String cid) async {
      final info = InstitutionChangeInfo(
        proposalId: id,
        actorCidNumber: cid,
        action: 5,
        rows: [
          const InstitutionDetailRow('完整替换原生权限', 'R_POLICY；multisig / 0 / 表决'),
          InstitutionDetailRow('期望机构状态指纹', '0x${'09' * 32}', copyable: true),
        ],
      );
      await ProposalDetailLocalStore.instance.put(
        ProposalDetailSnapshot(
          proposalId: id,
          proposalKind: 'institution_multisig',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          status: 0,
          threshold: 2,
          detail: info.toJson(),
          extra: {
            'voter_tickets': [
              {
                'account_id': null,
                'person_cid': 'CN220-CTZN2-198805200-2026',
                'cid_number': _cid,
                'role_code': 'R_POLICY',
                'role_name': '业务岗位',
              },
            ],
          },
        ),
      );
    }

    Widget page() => _wrap(
      MultisigProposalDetailPage(
        institution: institution,
        proposalId: id,
        proposalContext: ProposalContext(institution: institution),
        resolveVoteContext: () async =>
            ProposalContext(institution: institution),
      ),
    );
    Future<void> waitFor(Finder result) async {
      // Isar通过原生异步回调读取；模拟时钟推进不能代替真实I/O完成。
      for (var i = 0; i < 50 && result.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(result, findsOneWidget);
      await tester.pumpAndSettle();
    }

    await tester.runAsync(() => seed(_cid));
    await tester.pumpWidget(page());
    await waitFor(find.text('原生权限与共同阈值政策'));
    expect(find.text('原生权限与共同阈值政策'), findsOneWidget);
    expect(find.text('R_POLICY；multisig / 0 / 表决'), findsOneWidget);
    expect(find.text('0x${'09' * 32}'), findsOneWidget);
    expect(find.text('关闭多签提案信息'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() => seed('another-institution'));
    await tester.pumpWidget(page());
    await waitFor(find.text('该提案的本机记录已不可用'));
    expect(find.text('该提案的本机记录已不可用'), findsOneWidget);
    expect(find.byType(ProposalVoteActions), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('同一人员多个岗位在卡片独立显示，不以钱包冒充人员CID', (tester) async {
    final person = _person(_adminAccountId, roles: ['MEMBER', 'DIRECTOR']);
    await tester.pumpWidget(_wrap(InstitutionAssignmentCard(person: person)));
    expect(find.text(person.personCid), findsOneWidget);
    expect(find.text('委员 · 无固定任期'), findsOneWidget);
    expect(find.text('主任 · 无固定任期'), findsOneWidget);
    expect(find.textContaining('来源：创世'), findsNWidgets(2));
  });
  testWidgets('人员缺当前绑定仍显示任职，但不能发起节点访问授权', (tester) async {
    final person = _person(null);
    await tester.pumpWidget(
      _wrap(
        InstitutionAssignmentsPage(
          persons: [person],
          identity: const InstitutionIdentity(
            cidNumber: _cid,
            orgCode: 'CREG',
            kind: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(person.personCid), findsOneWidget);
    expect(find.text('共 1 位人员'), findsOneWidget);
    expect(find.text('节点访问授权'), findsNothing);
    expect(find.text('激活'), findsNothing);
  });
  testWidgets('公开机构列表复用同一人员任职卡', (tester) async {
    await tester.pumpWidget(
      _wrap(PublicInstitutionAssignmentsPage(persons: [_person(null)])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InstitutionAssignmentCard), findsOneWidget);
    expect(find.text('共 1 位人员'), findsOneWidget);
  });
  testWidgets('任职未完成时不伪造0人，完成后才显示真实空集', (tester) async {
    final result = Completer<List<InstitutionPersonView>>();
    final chain = _FakeChainState()..reader = (_) => result.future;
    await _openDetails(tester, chain);
    expect(find.text('正在读取任职'), findsOneWidget);
    expect(find.text('共 0 位人员'), findsNothing);
    result.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('共 0 位人员'), findsOneWidget);
  });
  testWidgets('任职读失败保留机构资料，不以失败冒充0人', (tester) async {
    final chain = _FakeChainState()
      ..reader = (_) async => throw StateError('人员链读失败');
    await _openDetails(tester, chain);
    await tester.pumpAndSettle();
    expect(find.text('人员任职暂不可用'), findsOneWidget);
    expect(find.text('共 0 位人员'), findsNothing);
    expect(find.text('合成机构'), findsWidgets);
  });
  testWidgets('退出详情后迟到任职不回填已销毁页面', (tester) async {
    final result = Completer<List<InstitutionPersonView>>();
    final chain = _FakeChainState()..reader = (_) => result.future;
    await _openDetails(tester, chain);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    result.complete([_person(null)]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('联邦安全局全部账户页显示 FCSF 正确余额', (tester) async {
    final institution = Institution.fromPublicEntity(_fscEntity());
    await tester.pumpWidget(
      _wrap(InstitutionAccountsPage(institution: institution)),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部账户'), findsOneWidget);
    expect(find.text(kReservedNameFcsf), findsOneWidget);
    expect(find.text('10,000,000,000.00 元'), findsOneWidget);
  });

  testWidgets('详情页展示机构资料、账户、人员任职与提案列表', (tester) async {
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
          'cid_short_name': '辽省注册局',
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
      wallets: const [_adminAccountId],
      proposalList: [
        InstitutionProposalSummary(
          proposalId: BigInt.from(7),
          idLabel: '提案 #7',
          status: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      _wrap(
        InstitutionDetailPage(
          cidNumber: _cid,
          repository: InstitutionRepository(directory: repo),
          chainState: chain,
          subscriberCidNumberProvider: () async => 'CID-USER',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('辽宁省身份注册局'), findsWidgets); // AppBar 简称回退全称 + 全称行
    expect(find.text('LN001-CREG0-944805165'), findsOneWidget);
    expect(find.text(_cid), findsNothing);
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
    // 人员任职入口。
    expect(find.text('人员任职'), findsOneWidget);
    expect(find.text('共 1 位人员'), findsOneWidget);
    // 提案列表。
    expect(find.text('提案列表'), findsOneWidget);
    expect(find.text('提案 #7'), findsOneWidget);
    final header = find.byType(ProposalCardHeader);
    expect(header, findsOneWidget);
    final name = find.descendant(of: header, matching: find.text('辽省注册局'));
    expect(name, findsOneWidget);
    expect(
      tester.getRect(name).right,
      lessThan(tester.getRect(find.text('提案 #7')).left),
    );
  });

  testWidgets('人员任职入口进入统一人员列表页', (tester) async {
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
    await tester.pumpWidget(
      _wrap(
        InstitutionDetailPage(
          cidNumber: _cid,
          repository: InstitutionRepository(directory: repo),
          chainState: _FakeChainState(wallets: const [_adminAccountId]),
          subscriberCidNumberProvider: () async => 'CID-USER',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('人员任职'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('人员任职'));
    await tester.pumpAndSettle();
    expect(find.text('人员任职'), findsOneWidget);
    expect(find.textContaining('共 1 位人员'), findsOneWidget);
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
    await tester.pumpWidget(
      _wrap(
        InstitutionDetailPage(
          cidNumber: _cid,
          repository: InstitutionRepository(directory: repo),
          chainState: _FakeChainState(),
          subscriberCidNumberProvider: () async => 'CID-USER',
        ),
      ),
    );
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
