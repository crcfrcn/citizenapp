import 'dart:async';
import 'dart:convert';

import 'package:citizen_citizen/governance/governance_tab.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/legislation/legislation_tab.dart';
import 'package:citizen_citizen/public/admin_division_bundle_loader.dart';
import 'package:citizen_citizen/public/public_institution_bundle_loader.dart';
import 'package:citizen_citizen/public/public_institution_repository.dart';
import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/institution/fake_admin_division_store.dart';
import 'package:citizen_testing/institution/fake_data_version_kv.dart';
import 'package:citizen_testing/institution/fake_public_institution_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
      expect(find.text('正在读取${label}机构'), findsOneWidget);
      expect(find.text(governance ? '合成省储委会' : '合成省立法院'), findsNothing);
      bundle.release();
      await proposalSync;
      await tester.pumpAndSettle();
      expect(find.text(governance ? '合成省储委会' : '合成省立法院'), findsOneWidget);
      expect(find.text('正在读取${label}机构'), findsNothing);
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
      expect(find.text('${label}机构读取失败，请重试'), findsOneWidget);
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
