import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_repository.dart';
import 'package:citizen_citizen/legislation/law_models.dart';
import 'package:citizen_citizen/legislation/legislation_api.dart';
import 'package:citizen_citizen/legislation/law_list_page.dart';
import 'package:citizen_citizen/legislation/law_reader_page.dart';
import 'package:citizen_citizen/legislation/legislation_tab.dart';
import 'package:citizen_citizen/public/public_institution_repository.dart';

import 'package:citizen_testing/institution/public_nav_harness.dart';

class _PendingInstitutionRepository extends InstitutionRepository {
  _PendingInstitutionRepository(PublicInstitutionRepository directory)
    : super(directory: directory);

  final Completer<List<Institution>> completer = Completer<List<Institution>>();

  @override
  Future<List<Institution>> listByCodes(Set<String> institutionCodes) =>
      completer.future;
}

class _PendingLawListApi extends LegislationApi {
  _PendingLawListApi() : super();

  final Completer<List<int>> completer = Completer<List<int>>();

  @override
  Future<List<int>> listLaws(LawTier tier, LawRegion region) =>
      completer.future;
}

class _PendingLawReaderApi extends LegislationApi {
  _PendingLawReaderApi() : super();

  final Completer<Law?> completer = Completer<Law?>();

  @override
  Future<Law?> localLaw(int lawId) => completer.future;
}

/// 全部正文为合成数据；仅控制读取终态，不访问真实链或设备资料。
Law _law({int? effective = 2, int latest = 2, int? pending}) => Law(
  lawId: 0,
  tier: LawTier.constitution,
  region: LawRegion.national,
  houses: const [],
  effectiveVersion: effective,
  latestVersion: latest,
  pendingVersion: pending,
  status: pending == null ? LawStatus.effective : LawStatus.pending,
);
LawVersion _version(int value) => LawVersion(
  lawId: 0,
  version: value,
  title: '合成宪法$value',
  titleEn: 'Synthetic law $value',
  chapters: [LawChapter(number: 1, title: '合成章节$value', sections: const [])],
  contentHash: '0x${'01' * 32}',
  voteType: 0,
  proposalId: 0,
  publishedAt: 1,
  effectiveAt: value * 1000,
);

class _ReaderApi extends LegislationApi {
  _ReaderApi() : super();
  Law? local;
  Law? remote = _law();
  final localVersions = <int, LawVersion>{};
  final versions = <int, LawVersion>{2: _version(2)};
  bool localFailure = false, failure = false;
  Completer<Law?>? background;
  final pending = <int, Completer<LawVersion?>>{};
  final requested = <int>[];
  int lawReads = 0;
  @override
  Future<Law?> localLaw(int id) async {
    if (localFailure) throw StateError('合成本机读取失败');
    return local;
  }

  @override
  Future<LawVersion?> localLawVersion(int id, int version) async =>
      localVersions[version];
  @override
  Future<LawVersionLabel?> localLawVersionLabel(int id, int version) async =>
      null;
  @override
  Future<ImmutableManifest?> localImmutableManifest() async =>
      const ImmutableManifest(articleNumbers: [], articleHashes: []);
  @override
  Future<Law?> law(int id, {bool forceRefresh = false}) async {
    expectSync(forceRefresh, isTrue);
    lawReads++;
    if (background != null) return background!.future;
    if (failure) throw StateError('合成链读取失败');
    return remote;
  }

  @override
  Future<LawVersion?> lawVersion(
    int id,
    int version, {
    bool forceRefresh = false,
  }) async {
    expectSync(forceRefresh, isTrue);
    requested.add(version);
    if (pending[version] case final value?) return value.future;
    return versions[version];
  }

  @override
  Future<LawVersionLabel?> lawVersionLabel(
    int id,
    int version, {
    bool forceRefresh = false,
  }) async => null;
  @override
  Future<ImmutableManifest?> immutableManifest({
    bool forceRefresh = false,
  }) async => const ImmutableManifest(articleNumbers: [], articleHashes: []);
}

Future<void> _openReader(WidgetTester tester, _ReaderApi api) async {
  await tester.pumpWidget(MaterialApp(home: LawReaderPage(lawId: 0, api: api)));
  await tester.pumpAndSettle();
}

Future<void> _selectVersion(WidgetTester tester, int version) async {
  // 调用实际版本菜单的用户动作回调，不读取私有State或另写读取实现。
  tester
      .widget<PopupMenuButton<int>>(find.byType(PopupMenuButton<int>))
      .onSelected!(version);
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('无本机缓存读取生效正文，待生效版仅提供时间提示', (tester) async {
    final api = _ReaderApi()..remote = _law(latest: 3, pending: 3);
    api.versions[3] = _version(3);
    await _openReader(tester, api);
    expect(find.text('合成宪法2'), findsOneWidget);
    expect(find.text('合成章节2'), findsOneWidget);
    expect(find.text('合成章节3'), findsNothing);
    expect(find.textContaining('待生效修订'), findsOneWidget);
    expect(api.requested, [2, 3]);
  });
  testWidgets('无缓存链失败后原按钮可强制重试并清除错误', (tester) async {
    final api = _ReaderApi()..failure = true;
    await _openReader(tester, api);
    expect(find.text('法律读取失败，请检查网络后重试'), findsOneWidget);
    api.failure = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('合成章节2'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(api.lawReads, 2);
  });
  testWidgets('本机读取异常仍可查询链正文，不停在忙状态', (tester) async {
    final api = _ReaderApi()..localFailure = true;
    await _openReader(tester, api);
    expect(api.lawReads, 1);
    expect(find.text('合成章节2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  for (final missing in ['law', 'version', 'body']) {
    testWidgets('无缓存缺失$missing明确失败，不能呈现空白成功', (tester) async {
      final api = _ReaderApi();
      if (missing == 'law') api.remote = null;
      if (missing == 'version') api.remote = _law(effective: null, latest: 0);
      if (missing == 'body') api.versions.clear();
      await _openReader(tester, api);
      expect(
        find.text(switch (missing) {
          'law' => '未找到该法律',
          'version' => '该法律暂无可读版本',
          _ => '法律正文缺失，请重试',
        }),
        findsOneWidget,
      );
      expect(find.text('暂无正文'), findsNothing);
      api.remote = _law();
      api.versions[2] = _version(2);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('合成章节2'), findsOneWidget);
    });
  }
  for (final missing in [false, true]) {
    testWidgets('已有正文，后台${missing ? '正文缺失' : '读取失败'}保留内容并可重试', (tester) async {
      final api = _ReaderApi()
        ..local = _law()
        ..failure = !missing;
      api.localVersions[2] = _version(2);
      if (missing) api.versions.clear();
      await _openReader(tester, api);
      expect(find.text('合成章节2'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      api.failure = false;
      api.versions[2] = _version(2);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('合成章节2'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
    });
  }
  for (final fail in [false, true]) {
    testWidgets('用户选择历史版后，迟到后台${fail ? '失败' : '成功'}不能覆盖', (tester) async {
      final delayed = Completer<Law?>();
      final api = _ReaderApi()
        ..local = _law()
        ..background = delayed;
      api.localVersions[2] = _version(2);
      api.versions[1] = _version(1);
      await _openReader(tester, api);
      await _selectVersion(tester, 1);
      await tester.pumpAndSettle();
      expect(find.text('合成章节1'), findsOneWidget);
      if (fail) {
        delayed.completeError(StateError('合成迟到失败'));
      } else {
        delayed.complete(_law());
      }
      await tester.pumpAndSettle();
      expect(find.text('合成章节1'), findsOneWidget);
      expect(find.text('合成章节2'), findsNothing);
      expect(find.text('重试'), findsNothing);
    });
    testWidgets('连续选择版本，迟到旧版本${fail ? '失败' : '成功'}不能覆盖新选择', (tester) async {
      final api = _ReaderApi()..remote = _law(latest: 3);
      final delayed = Completer<LawVersion?>();
      api.pending[1] = delayed;
      api.versions[3] = _version(3);
      await _openReader(tester, api);
      await _selectVersion(tester, 1);
      await tester.pumpAndSettle();
      await _selectVersion(tester, 3);
      await tester.pumpAndSettle();
      if (fail) {
        delayed.completeError(StateError('合成旧版失败'));
      } else {
        delayed.complete(_version(1));
      }
      await tester.pumpAndSettle();
      expect(find.text('合成章节3'), findsOneWidget);
      expect(find.text('合成章节1'), findsNothing);
      expect(find.text('重试'), findsNothing);
    });
  }
  testWidgets('历史正文缺失保留原文，重试仍读目标版而非生效版', (tester) async {
    final api = _ReaderApi();
    await _openReader(tester, api);
    await _selectVersion(tester, 1);
    await tester.pumpAndSettle();
    expect(api.requested, [2, 1]);
    expect(find.text('版本正文缺失，请重试'), findsOneWidget);
    expect(find.text('合成章节2'), findsOneWidget);
    api.versions[1] = _version(1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(api.requested, [2, 1, 1]);
    expect(find.text('合成章节1'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('立法目录未返回时直接显示卡片和省导航且不使用整页转圈', (tester) async {
    final directory = await buildSeededRepo(
      provinceOrder: const [],
      institutions: const [],
    );
    final repository = _PendingInstitutionRepository(directory);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 900,
            child: LegislationTab(repository: repository),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('《公民宪法》'), findsOneWidget);
    expect(find.text('国家立法院'), findsOneWidget);
    expect(find.text('省市立法机构'), findsOneWidget);
    expect(find.text('中枢'), findsOneWidget);
    expect(find.text('正在读取立法机构'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('legislation-load-progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('法律列表未返回时直接显示标题和内容区且不使用整页转圈', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LawListPage(
          tier: LawTier.national,
          region: LawRegion.national,
          title: '国家法律原文',
          api: _PendingLawListApi(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('国家法律原文'), findsOneWidget);
    expect(find.text('正在读取法律列表'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('law-list-load-progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('法律正文未返回时直接显示阅读壳且不使用整页转圈', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LawReaderPage(lawId: 0, api: _PendingLawReaderApi())),
    );
    await tester.pump();

    expect(find.text('法律'), findsOneWidget);
    expect(find.text('正在读取法律正文'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('law-reader-loading-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('law-reader-load-progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
