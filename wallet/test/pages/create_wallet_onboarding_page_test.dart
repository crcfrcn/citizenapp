import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_wallet/create_wallet_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

// 准备、提交和资源全部来自真实Core；只控制App读取/交付的时序，不读取或记录助记词内容。
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: '等待真实Core及页面终态');
}

void _background(WidgetTester t) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
}

void _foreground(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (t.binding.lifecycleState == AppLifecycleState.hidden) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _tapCreate(WidgetTester t) async {
  final button = find.widgetWithText(FilledButton, '创建钱包');
  await t.scrollUntilVisible(
    button,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.tap(button);
  await t.pump();
}

Widget _host(CitizenSdk sdk, CreateWalletOnboardingPage page) =>
    Provider<CitizenSdk>.value(
      value: sdk,
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('citizenapp/security'),
          (_) async => null,
        ),
  );
  for (final reject in [false, true]) {
    testWidgets('校验期间退出，迟到${reject ? '失败' : '成功'}不更新页面或创建钱包', (t) async {
      final core = await openTestSdk();
      final validation = Completer<void>();
      var prepares = 0;
      await t.pumpWidget(
        _host(
          core.sdk,
          CreateWalletOnboardingPage(
            onCreated: () => fail('退出后不得放行'),
            deviceSecureProbe: () async => true,
            passwordValidator: (_) => validation.future,
            prepareWallet: ({required wordCount, password = ''}) {
              prepares++;
              throw StateError('退出后不得准备');
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await _tapCreate(t);
      await t.pumpWidget(const SizedBox.shrink());
      if (reject) {
        validation.completeError(StateError('合成校验失败'));
      } else {
        validation.complete();
      }
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(prepares, 0);
    });
  }
  testWidgets('校验等待期间连续点击只校验一次，取消确认后可以重新发起', (t) async {
    final core = await openTestSdk();
    final validation = Completer<void>();
    var validates = 0, prepares = 0;
    await t.pumpWidget(
      _host(
        core.sdk,
        CreateWalletOnboardingPage(
          onCreated: () {},
          deviceSecureProbe: () async => true,
          passwordValidator: (_) {
            validates++;
            return validates == 1 ? validation.future : Future.value();
          },
          prepareWallet: ({required wordCount, password = ''}) {
            prepares++;
            throw StateError('取消后不得准备');
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Test123');
    await _tapCreate(t);
    await _tapCreate(t);
    expect(validates, 1);
    expect(find.text('创建中…'), findsNothing);
    validation.complete();
    await t.pumpAndSettle();
    expect(find.text('确认钱包密码'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(prepares, 0);
    await _tapCreate(t);
    await t.pumpAndSettle();
    expect(validates, 2);
    expect(find.text('确认钱包密码'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    expect(prepares, 0);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('原12和24词选项保留，18词为已批准增量，冷导入不受热设备门禁影响', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CreateWalletOnboardingPage(
          onCreated: () {},
          deviceSecureProbe: () async => false,
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final count in [12, 18, 24]) {
      expect(find.text('$count 个助记词'), findsOneWidget);
    }
    final button = find.widgetWithText(FilledButton, '创建钱包');
    await t.scrollUntilVisible(
      button,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    final cold = find.widgetWithText(TextButton, '导入冷钱包');
    await t.scrollUntilVisible(
      cold,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(t.widget<TextButton>(cold).onPressed, isNotNull);
  });
  testWidgets('18词准确传到SDK，失败保留原创建失败弹窗且不放行', (t) async {
    final core = await openTestSdk();
    CitizenWalletWordCount? requested;
    var created = 0;
    await t.pumpWidget(
      _host(
        core.sdk,
        CreateWalletOnboardingPage(
          onCreated: () => created++,
          deviceSecureProbe: () async => true,
          prepareWallet: ({required wordCount, password = ''}) {
            requested = wordCount;
            throw StateError('合成创建失败');
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('18 个助记词'));
    await _tapCreate(t);
    await t.pumpAndSettle();
    expect(
      requested,
      CitizenWalletWordCount.values.singleWhere((v) => v.value == 18),
    );
    expect(find.text('创建钱包失败'), findsOneWidget);
    expect(created, 0);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('提交成功后显示原备份框，关闭备份才放行并释放资源', (t) async {
    final core = await openTestSdk(
      modules:
          CitizenSdkModules.wallet |
          CitizenSdkModules.signing |
          CitizenSdkModules.qr,
      vaultMode: 1,
    );
    CitizenSdkPreparedWallet? prepared;
    var created = 0;
    CitizenSdkOperation<CitizenSdkPreparedWallet> prepare({
      required CitizenWalletWordCount wordCount,
      String password = '',
    }) {
      final op = core.sdk.prepareWalletCreation(
        wordCount: wordCount,
        password: password,
      );
      return CitizenSdkOperation(
        operationId: op.operationId,
        result: op.result.then((p) {
          prepared = p;
          return p;
        }),
        cancel: op.cancel,
      );
    }

    await t.pumpWidget(
      _host(
        core.sdk,
        CreateWalletOnboardingPage(
          onCreated: () => created++,
          deviceSecureProbe: () async => true,
          prepareWallet: prepare,
        ),
      ),
    );
    await t.pumpAndSettle();
    await _tapCreate(t);
    await _until(t, () => find.text('请备份助记词').evaluate().isNotEmpty);
    expect(created, 0);
    expect(
      (await t.runAsync(() => core.sdk.getWalletState().result))!.hotProfile,
      isNotNull,
    );
    // SDK提交已消费准备资源；仍能显示备份证明词副本在提交前取得，不能从已提交资源补读。
    await t.runAsync(
      () => expectLater(
        prepared!.recoveryPhrase(),
        throwsA(isA<CitizenSdkException>()),
      ),
    );
    await t.tap(find.text('我已备份'));
    await _until(t, () => created == 1);
    expect(find.text('请备份助记词'), findsNothing);
    await t.runAsync(
      () => expectLater(
        prepared!.recoveryPhrase(),
        throwsA(isA<CitizenSdkException>()),
      ),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
  for (final reason in ['后台', '目录变更', '读取失败']) {
    testWidgets('原备份框$reason立即清屏，返回前台或迟到事件不重开', (t) async {
      addTearDown(() => _foreground(t));
      final core = await openTestSdk(
        modules:
            CitizenSdkModules.wallet |
            CitizenSdkModules.signing |
            CitizenSdkModules.qr,
        vaultMode: 1,
      );
      var created = 0, failRead = false;
      await t.pumpWidget(
        _host(
          core.sdk,
          CreateWalletOnboardingPage(
            onCreated: () => created++,
            deviceSecureProbe: () async => true,
            stateReader: () {
              if (failRead) throw StateError('合成读取失败');
              return core.sdk.getWalletState().result;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await _tapCreate(t);
      await _until(t, () => find.text('请备份助记词').evaluate().isNotEmpty);
      if (reason == '后台') {
        _background(t);
      } else {
        failRead = reason == '读取失败';
        await t.runAsync(() async {
          final state = await core.sdk.getWalletState().result;
          return core.sdk
              .renameWallet(
                expectedRevision: state.revision,
                walletIndex: 0,
                name: 'fixture changed',
              )
              .result;
        });
      }
      await _until(t, () => find.text('请备份助记词').evaluate().isEmpty);
      await _until(t, () => created == 1);
      _foreground(t);
      await t.pumpAndSettle();
      expect(find.text('请备份助记词'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('提交期间进入后台，迟到成功不显示备份并归还准备资源', (t) async {
    addTearDown(() => _foreground(t));
    final core = await openTestSdk(
      modules:
          CitizenSdkModules.wallet |
          CitizenSdkModules.signing |
          CitizenSdkModules.qr,
      vaultMode: 1,
    );
    final delivery = Completer<CitizenWalletProfile>();
    CitizenSdkPreparedWallet? prepared;
    CitizenWalletProfile? committed;
    var created = 0;
    await t.pumpWidget(
      _host(
        core.sdk,
        CreateWalletOnboardingPage(
          onCreated: () => created++,
          deviceSecureProbe: () async => true,
          commitWallet: (p) async {
            prepared = p;
            committed = await p.commit().result;
            return delivery.future;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await _tapCreate(t);
    await _until(t, () => committed != null);
    _background(t);
    delivery.complete(committed!);
    await _until(t, () => created == 1);
    expect(find.text('请备份助记词'), findsNothing);
    await t.runAsync(
      () => expectLater(
        prepared!.recoveryPhrase(),
        throwsA(isA<CitizenSdkException>()),
      ),
    );
    _foreground(t);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
