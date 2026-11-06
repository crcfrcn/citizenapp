import 'dart:async';

import 'package:citizen_square/draft/compose_draft.dart';
import 'package:citizen_square/draft/compose_draft_store.dart';
import 'package:citizen_square/draft/drafts_page.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingDraftStore implements SquareComposeDraftRepository {
  final Completer<List<SquareComposeDraft>> completer =
      Completer<List<SquareComposeDraft>>();

  @override
  Future<List<SquareComposeDraft>> list(String cidNumber) => completer.future;

  @override
  Future<void> delete(String cidNumber, String draftId) async {}

  @override
  Future<void> save(SquareComposeDraft draft) async {}

  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {}
}

class _CleanupFailureDraftStore implements SquareComposeDraftRepository {
  bool deleted = false;
  int retryCalls = 0;

  static const draft = SquareComposeDraft(
    draftId: 'draft-cleanup',
    cidNumber: 'CN220-CTZN2-100000001-2026',
    postType: SquarePostType.document,
    text: '待删除草稿',
    media: <SquareLocalMediaDraft>[],
    updatedAt: 1,
  );

  @override
  Future<List<SquareComposeDraft>> list(String cidNumber) async => deleted
      ? const <SquareComposeDraft>[]
      : const <SquareComposeDraft>[draft];

  @override
  Future<void> delete(String cidNumber, String draftId) async {
    deleted = true;
    throw const SquareComposeDraftStoreException('媒体清理失败');
  }

  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {
    retryCalls += 1;
  }

  @override
  Future<void> save(SquareComposeDraft draft) async {}
}

void main() {
  const cidA = 'CN220-CTZN2-100000001-2026',
      cidB = 'CN220-CTZN2-100000002-2026';
  SquareComposeDraft row(
    String cid,
    String text, {
    SquarePostType type = SquarePostType.document,
  }) => SquareComposeDraft(
    cidNumber: cid,
    draftId: 'same-id',
    postType: type,
    text: text,
    media: const [],
    updatedAt: 1,
  );
  Widget page(
    String cid,
    SquarePostType type,
    SquareComposeDraftRepository store,
  ) => MaterialApp(
    home: DraftsPage(
      key: const ValueKey('box'),
      cidNumber: cid,
      postType: type,
      store: store,
    ),
  );
  testWidgets('切换CID立即撤下旧列表，旧加载不能覆盖新CID', (tester) async {
    final store = _ScopedStore(),
        old = Completer<List<SquareComposeDraft>>(),
        next = Completer<List<SquareComposeDraft>>();
    store.onList = (cid) => cid == cidA ? old.future : next.future;
    await tester.pumpWidget(page(cidA, SquarePostType.document, store));
    await tester.pump();
    await tester.pumpWidget(page(cidB, SquarePostType.document, store));
    await tester.pump();
    old.complete([row(cidA, '旧身份草稿')]);
    await tester.pump();
    expect(find.text('旧身份草稿'), findsNothing);
    next.complete([row(cidB, '新身份草稿'), row(cidA, '混入的旧草稿')]);
    await tester.pumpAndSettle();
    expect(find.text('新身份草稿'), findsOneWidget);
    expect(find.text('混入的旧草稿'), findsNothing);
    expect(store.listed, [cidA, cidB]);
  });
  testWidgets('类型和仓库切换重新加载，等待新仓库时不显示旧数据', (tester) async {
    final store = _ScopedStore()
      ..rows.addAll([
        row(cidA, '公文内容'),
        row(cidA, '文章内容', type: SquarePostType.article),
      ]);
    await tester.pumpWidget(page(cidA, SquarePostType.document, store));
    await tester.pumpAndSettle();
    expect(find.text('公文内容'), findsOneWidget);
    await tester.pumpWidget(page(cidA, SquarePostType.article, store));
    await tester.pumpAndSettle();
    expect(find.text('文章内容'), findsOneWidget);
    expect(find.text('公文内容'), findsNothing);
    final replacement = _ScopedStore(),
        pending = Completer<List<SquareComposeDraft>>();
    replacement.onList = (_) => pending.future;
    await tester.pumpWidget(page(cidA, SquarePostType.article, replacement));
    await tester.pump();
    expect(find.text('文章内容'), findsNothing);
    pending.complete([row(cidA, '新仓库', type: SquarePostType.article)]);
    await tester.pumpAndSettle();
    expect(find.text('新仓库'), findsOneWidget);
  });
  for (final failure in [false, true]) {
    testWidgets('旧CID删除迟到${failure ? '失败' : '成功'}不影响新CID的同ID草稿', (
      tester,
    ) async {
      final store = _ScopedStore()
        ..rows.addAll([row(cidA, '旧草稿'), row(cidB, '新草稿')])
        ..deleteGate = Completer<void>()
        ..failDelete = failure;
      await tester.pumpWidget(page(cidA, SquarePostType.document, store));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(store.deleted, [(cidA, 'same-id')]);
      await tester.pumpWidget(page(cidB, SquarePostType.document, store));
      await tester.pumpAndSettle();
      store.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('新草稿'), findsOneWidget);
      expect(find.text('草稿已删除，但本地媒体仍待清理'), findsNothing);
      expect(store.rows.where((r) => r.cidNumber == cidB), hasLength(1));
    });
  }
  testWidgets('本地草稿未返回时直接显示草稿箱且不使用整页转圈', (tester) async {
    final store = _PendingDraftStore();
    await tester.pumpWidget(
      MaterialApp(
        home: DraftsPage(
          cidNumber: 'CN220-CTZN2-100000001-2026',
          postType: SquarePostType.document,
          store: store,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('草稿箱'), findsOneWidget);
    expect(find.text('正在读取本地草稿'), findsOneWidget);
    expect(find.byKey(const ValueKey('drafts-load-progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    store.completer.complete(const <SquareComposeDraft>[]);
    await tester.pumpAndSettle();
    expect(find.text('还没有草稿'), findsOneWidget);
    expect(find.byKey(const ValueKey('drafts-load-progress')), findsNothing);
  });

  testWidgets('草稿事实已删但媒体失败时显示可重试终态', (tester) async {
    final store = _CleanupFailureDraftStore();
    await tester.pumpWidget(
      MaterialApp(
        home: DraftsPage(
          cidNumber: _CleanupFailureDraftStore.draft.cidNumber,
          postType: SquarePostType.document,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('待删除草稿'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('草稿已删除，但本地媒体仍待清理'), findsOneWidget);
    expect(find.text('待删除草稿'), findsNothing);
    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();
    expect(store.retryCalls, 1);
    expect(find.text('本地媒体清理完成'), findsOneWidget);
  });
}

class _ScopedStore implements SquareComposeDraftRepository {
  final rows = <SquareComposeDraft>[];
  final listed = <String>[];
  final deleted = <(String, String)>[];
  Future<List<SquareComposeDraft>> Function(String)? onList;
  Completer<void>? deleteGate;
  bool failDelete = false;
  @override
  Future<List<SquareComposeDraft>> list(String cid) {
    listed.add(cid);
    return onList?.call(cid) ??
        Future.value(rows.where((r) => r.cidNumber == cid).toList());
  }

  @override
  Future<void> save(SquareComposeDraft draft) async {
    rows.add(draft);
  }

  @override
  Future<void> delete(String cid, String id) async {
    deleted.add((cid, id));
    await deleteGate?.future;
    if (failDelete) throw const SquareComposeDraftStoreException('synthetic');
    rows.removeWhere((r) => r.cidNumber == cid && r.draftId == id);
  }

  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {}
}
