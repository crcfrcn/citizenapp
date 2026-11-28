// 验证CID查找及目录就绪。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/public/data.dart' show PublicInstitutionDto;
import 'package:citizen_citizen/public/service.dart' show CidDirectoryLookup;
import 'package:citizen_testing/institution/navigation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:citizen_citizen/governance/page.dart' show GovernanceInstitutionOrder, GovernanceInstitutionOrderStore, GovernanceTab;
import 'package:citizen_citizen/institution/service.dart' show InstitutionRepository;
import 'package:citizen_citizen/legislation/page.dart' show LegislationTab;
import 'package:citizen_citizen/public/loader.dart' show AdminDivisionBundleLoader;
import 'package:citizen_citizen/public/loader.dart' show PublicInstitutionBundleLoader;
import 'package:citizen_citizen/public/service.dart' show PublicInstitutionRepository;
import 'package:citizen_testing/database.dart';
import 'package:citizen_testing/institution/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  group('cid_directory_lookup_test', _registerLookup);
  group('directory_readiness_test', _registerReady);
}

// 验证按CID反查机构省市和代表人及缺失结果。

void _registerLookup() {
  const cid = 'GD001-GCB08-067440774-2026';

  Future<CidDirectoryLookup> seedLookup(List<PublicInstitutionDto> rows) async {
    final repo = await buildSeededRepo(
      provinceOrder: const ['GD'],
      institutions: rows,
      cityNames: const {'GD|001': '广州市'},
    );
    return CidDirectoryLookup(repository: repo);
  }

  test('命中:反查出省/市/法定代表人(省名链上常量、市名字典 join)', () async {
    final lookup = await seedLookup([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': cid,
        'cid_full_name': '广东省公民储备委员会',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'GCB',
        'account_count': 2,
        'legal_representative': {
          'family_name': '程',
          'given_name': '伟',
          'cid_number': 'CID-1',
          'account': '11',
        },
      }),
    ]);
    final info = await lookup.lookup(cid);
    expect(info, isNotNull);
    expect(info!.provinceName, '广东省');
    expect(info.cityName, '广州市');
    expect(info.familyName, '程');
    expect(info.givenName, '伟');
  });

  test('命中但无法定代表人:familyName/givenName 为 null', () async {
    final lookup = await seedLookup([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': cid,
        'cid_full_name': '广东省公民储备委员会',
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'GCB',
        'account_count': 2,
      }),
    ]);
    final info = await lookup.lookup(cid);
    expect(info?.familyName, isNull);
    expect(info?.givenName, isNull);
    expect(info?.provinceName, '广东省');
  });

  test('反查不到未知机构 CID 时返回 null', () async {
    final lookup = await seedLookup([
      PublicInstitutionDto.fromJson(<String, dynamic>{
        'cid_number': cid,
        'province_code': 'GD',
        'city_code': '001',
        'institution_code': 'GCB',
        'account_count': 2,
      }),
    ]);
    final info = await lookup.lookup('GD001-CGOV0-000000000-2026');
    expect(info, isNull);
  });
}

// 验证目录导入并发合并、后台完成就地呈现和失败重试。

const _institutionDir = 'packages/citizen_assets/institutions';

class _HeldBundle extends AssetBundle {
  Completer<String> manifest = Completer<String>();
  int manifestReads = 0;

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == '$_institutionDir/manifest.json') {
      manifestReads++;
      return manifest.future;
    }
    if (key == '$_institutionDir/中枢省.json') {
      return jsonEncode({
        'province_name': '中枢省',
        'manifest_version': 'synthetic-shard',
        'institutions': [
          {
            'cid_number': 'synthetic-nrc',
            'cid_full_name': '合成国家储委会',
            'institution_code': 'NRC',
            'province_code': 'ZS',
            'account_count': 2,
          },
          {
            'cid_number': 'synthetic-prc',
            'cid_full_name': '合成省储委会',
            'institution_code': 'PRC',
            'province_code': 'ZS',
            'account_count': 2,
          },
          {
            'cid_number': 'synthetic-nlg',
            'cid_full_name': '合成国家立法院',
            'institution_code': 'NLG',
            'province_code': 'ZS',
            'account_count': 2,
          },
          {
            'cid_number': 'synthetic-plg',
            'cid_full_name': '合成省立法院',
            'institution_code': 'PLG',
            'province_code': 'ZS',
            'account_count': 2,
          },
        ],
      });
    }
    throw FlutterError('synthetic asset missing');
  }

  void release() => manifest.complete(
    jsonEncode({
      'version': 'synthetic-snapshot',
      'provinces': [
        {
          'province_name': '中枢省',
          'manifest_version': 'synthetic-shard',
          'count': 4,
        },
      ],
    }),
  );
}

class _ReadyDivisions extends AdminDivisionBundleLoader {
  _ReadyDivisions()
    : super(store: FakeAdminDivisionStore(), versionKv: FakeDataVersionKv());

  @override
  Future<bool> ensureSynced() async => false;
}

class _MemoryOrder extends GovernanceInstitutionOrderStore {
  @override
  Future<GovernanceInstitutionOrder> read() async =>
      const GovernanceInstitutionOrder();
}

PublicInstitutionRepository _directory(_HeldBundle bundle) {
  final store = FakePublicInstitutionStore();
  final divisions = FakeAdminDivisionStore();
  return PublicInstitutionRepository(
    store: store,
    divisionStore: divisions,
    loader: PublicInstitutionBundleLoader(
      store: store,
      divisionStore: divisions,
      divisionLoader: _ReadyDivisions(),
      versionKv: FakeDataVersionKv(),
      bundle: bundle,
    ),
  );
}

void _registerReady() {
  group('实际默认目录消费者', () {
    useIsolatedIsar();
    test('独立默认仓储共享同一个导入中的Future及真实目录结果', () async {
      final first = PublicInstitutionRepository(),
          second = PublicInstitutionRepository();
      expect(identical(first, second), isFalse);
      final a = first.ensureSynced(), b = second.ensureSynced();
      expect(identical(a, b), isTrue);
      await Future.wait([a, b]);
      expect(await first.store.institutionCount(), 49593);
      expect(await second.store.institutionCount(), 49593);
      expect(await first.ensureSynced(), isFalse);
    });
  });

  test('并发目录同步合并导入，完成后仍按省级游标对账', () async {
    final bundle = _HeldBundle();
    final directory = _directory(bundle);
    final first = directory.ensureSynced();
    final second = directory.ensureSynced();
    expect(identical(first, second), isTrue);
    bundle.release();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(bundle.manifestReads, 1);
    expect(await directory.store.institutionCount(), 4);
    expect(await directory.ensureSynced(), isFalse);
    expect(bundle.manifestReads, 2);
  });

  for (final governance in [true, false]) {
    final label = governance ? '治理' : '立法';
    Widget page(PublicInstitutionRepository directory) => governance
        ? GovernanceTab(
            repository: InstitutionRepository(directory: directory),
            orderStore: _MemoryOrder(),
          )
        : LegislationTab(
            repository: InstitutionRepository(directory: directory),
          );

    testWidgets('$label 在后台导入完成后显示机构，无需重新进入页面', (tester) async {
      final bundle = _HeldBundle();
      final directory = _directory(bundle);
      // 提案页已启动导入，切到另一个页面时复用同一任务。
      final proposalSync = directory.ensureSynced();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: page(directory))),
      );
      await tester.pump();
      expect(find.text('正在读取$label机构'), findsOneWidget);
      expect(find.text(governance ? '合成省储委会' : '合成省立法院'), findsNothing);
      bundle.release();
      await proposalSync;
      await tester.pumpAndSettle();
      expect(find.text(governance ? '合成省储委会' : '合成省立法院'), findsOneWidget);
      expect(find.text('正在读取$label机构'), findsNothing);
      expect(bundle.manifestReads, 1);
    });

    testWidgets('$label 同步失败后可用原重试按钮恢复', (tester) async {
      final bundle = _HeldBundle();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: page(_directory(bundle)))),
      );
      await tester.pump();
      bundle.manifest.completeError(StateError('synthetic import failure'));
      await tester.pumpAndSettle();
      expect(find.text('$label机构读取失败，请重试'), findsOneWidget);
      bundle.manifest = Completer<String>();
      await tester.tap(find.text('重试'));
      await tester.pump();
      bundle.release();
      await tester.pumpAndSettle();
      expect(find.text(governance ? '合成省储委会' : '合成省立法院'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
    });
  }
}
