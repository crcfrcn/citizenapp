import 'package:provider/provider.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_square/compose/square_publish_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/identity/square_identity_state.dart';
import 'package:citizen_square/compose/compose_page.dart';
import 'package:citizen_square/draft/compose_draft.dart';
import 'package:citizen_square/draft/compose_draft_store.dart';
import 'package:citizen_square/draft/drafts_page.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_testing/isar_test_env.dart';

const cidA = 'CN220-CTZN2-100000001-2026', cidB = 'CN220-CTZN2-100000002-2026';
SquareIdentityState identity(String cid) => SquareIdentityState(
  accountId: '0x${(cid == cidA ? '11' : '22') * 32}',
  cidNumber: cid,
  signMode: CitizenWalletSignMode.hot,
);

class LocalIdentity implements SquareIdentityService {
  SquareIdentityState current = identity(cidA);
  final held = <Completer<SquareIdentityState>>[];
  int calls = 0;
  @override
  Future<SquareIdentityState> loadCurrent() {
    final number = calls++;
    return number < held.length ? held[number].future : Future.value(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected identity operation');
}

class LocalDrafts implements SquareComposeDraftRepository {
  final rows = <(String, String), SquareComposeDraft>{};
  final writes = <SquareComposeDraft>[],
      listed = <String>[],
      deleted = <(String, String)>[];
  Completer<void>? saveGate;
  @override
  Future<void> save(SquareComposeDraft draft) async {
    writes.add(draft);
    await saveGate?.future;
    rows[(draft.cidNumber, draft.draftId)] = draft;
  }

  @override
  Future<List<SquareComposeDraft>> list(String cid) async {
    listed.add(cid);
    return rows.values.where((r) => r.cidNumber == cid).toList();
  }

  @override
  Future<void> delete(String cid, String id) async {
    deleted.add((cid, id));
    rows.remove((cid, id));
  }

  @override
  Future<void> retryPendingFileCleanup({String? cidNumber}) async {}
}

Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();
  late LocalIdentity local;
  late LocalDrafts drafts;
  late ValueNotifier<int> revision;
  setUp(() {
    local = LocalIdentity();
    drafts = LocalDrafts();
    revision = ValueNotifier(0);
  });
  tearDown(() => revision.dispose());
  Widget page({
    SquarePostType type = SquarePostType.document,
    LocalDrafts? store,
    String? initial,
    SquarePublishService? publisher,
  }) => MaterialApp(
    home: SquareComposePage(
      key: const ValueKey('compose'),
      postType: type,
      identityService: local,
      identityRevision: revision,
      draftStore: store ?? drafts,
      publishService: publisher,
      initialText: initial,
    ),
  );
  testWidgets('切CID保存原内容到原CID，编辑器清空且新内容归属新CID', (tester) async {
    await tester.pumpWidget(page(initial: '初始内容'));
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '甲的草稿',
    );
    local.current = identity(cidB);
    revision.value++;
    await drain(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('document-text-field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(
      drafts.writes.any((r) => r.cidNumber == cidA && r.text == '甲的草稿'),
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '乙的草稿',
    );
    await tester.pump(const Duration(milliseconds: 850));
    await drain(tester);
    expect(
      drafts.writes
          .where((r) => r.cidNumber == cidB)
          .every((r) => r.text == '乙的草稿'),
      isTrue,
    );
    expect(
      drafts.writes.any((r) => r.cidNumber == cidB && r.text == '乙的草稿'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
  testWidgets('草稿箱打开期间跟随CID切换，选中的内容回到正确编辑身份', (tester) async {
    for (final (cid, text) in [(cidA, '甲已有草稿'), (cidB, '乙已有草稿')]) {
      drafts.rows[(cid, 'saved')] = SquareComposeDraft(
        cidNumber: cid,
        draftId: 'saved',
        postType: SquarePostType.document,
        text: text,
        media: const [],
        updatedAt: 1,
      );
    }
    await tester.pumpWidget(page());
    await drain(tester);
    await tester.tap(find.text('草稿'));
    await drain(tester);
    expect(find.text('甲已有草稿'), findsOneWidget);
    local.current = identity(cidB);
    revision.value++;
    await drain(tester);
    expect(find.text('甲已有草稿'), findsNothing);
    expect(find.text('乙已有草稿'), findsOneWidget);
    await tester.tap(find.text('乙已有草稿'));
    await drain(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('document-text-field')),
    );
    expect(field.controller!.text, '乙已有草稿');
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    expect(
      drafts.writes
          .where((r) => r.text == '乙已有草稿')
          .every((r) => r.cidNumber == cidB),
      isTrue,
    );
  });
  testWidgets('迟到保存只更新原草稿标记，不删除新CID空草稿', (tester) async {
    drafts.saveGate = Completer<void>();
    await tester.pumpWidget(page());
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '慢保存',
    );
    await tester.pump(const Duration(milliseconds: 850));
    await drain(tester);
    expect(drafts.writes, hasLength(1));
    local.current = identity(cidB);
    revision.value++;
    await drain(tester);
    await tester.tap(find.text('草稿'));
    await tester.pump();
    drafts.saveGate!.complete();
    await drain(tester);
    expect(find.byType(DraftsPage), findsOneWidget);
    expect(drafts.listed.last, cidB);
    expect(drafts.deleted, isEmpty);
    expect(drafts.writes.every((r) => r.cidNumber == cidA), isTrue);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
  testWidgets('旧本地身份迟到只补存原CID，不覆盖新CID编辑器', (tester) async {
    local.held.add(Completer<SquareIdentityState>());
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '等待甲身份的文字',
    );
    local.current = identity(cidB);
    revision.value++;
    await drain(tester);
    local.held[0].complete(identity(cidA));
    await drain(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('document-text-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      drafts.writes.any((r) => r.cidNumber == cidA && r.text == '等待甲身份的文字'),
      isTrue,
    );
    expect(drafts.writes.any((r) => r.cidNumber == cidB), isFalse);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
  testWidgets('发布回执迟到不关闭新CID编辑器，也不清除新CID草稿', (tester) async {
    final publishing = _HeldPublisher();
    await tester.pumpWidget(
      Provider<SquareSessionProvider>.value(
        value: _NoSessions(),
        child: page(publisher: publishing),
      ),
    );
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '甲发布的内容',
    );
    await drain(tester);
    await tester.tap(find.text('发布'));
    await drain(tester);
    expect(publishing.calls, 1);
    local.current = identity(cidB);
    revision.value++;
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '乙未发布的草稿',
    );
    await tester.tap(find.text('草稿'));
    await drain(tester);
    expect(find.byType(DraftsPage), findsOneWidget);
    expect(drafts.listed.last, cidB);
    Navigator.of(tester.element(find.byType(DraftsPage))).pop();
    await drain(tester);
    publishing.result.complete(
      SquarePublishResult(
        post: _PublishedPost(),
        txHash: '0x1',
        blockHash: '0x2',
      ),
    );
    await drain(tester);
    expect(find.byType(SquareComposePage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('document-text-field')))
          .controller!
          .text,
      '乙未发布的草稿',
    );
    await tester.pump(const Duration(milliseconds: 850));
    await drain(tester);
    expect(
      drafts.writes.any((r) => r.cidNumber == cidB && r.text == '乙未发布的草稿'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
  testWidgets('同CID本地身份更新保留正在编辑的文字', (tester) async {
    await tester.pumpWidget(page());
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '同一身份的内容',
    );
    revision.value++;
    await drain(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('document-text-field')))
          .controller!
          .text,
      '同一身份的内容',
    );
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
  testWidgets('切仓库旧保存仍写原仓库，新仓库不接收旧内容', (tester) async {
    final other = LocalDrafts();
    await tester.pumpWidget(page());
    await drain(tester);
    await tester.enterText(
      find.byKey(const ValueKey('document-text-field')),
      '原仓库内容',
    );
    await tester.pumpWidget(page(store: other));
    await drain(tester);
    expect(drafts.writes.any((r) => r.text == '原仓库内容'), isTrue);
    expect(other.writes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
  });
}

class _HeldPublisher implements SquarePublishService {
  final result = Completer<SquarePublishResult>();
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #publish) {
      calls++;
      return result.future;
    }
    throw StateError('unexpected publish operation');
  }
}

class _NoSessions implements SquareSessionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected session operation');
}

class _PublishedPost implements SquarePost {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('stale result must not be rendered');
}
