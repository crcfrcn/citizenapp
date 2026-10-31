import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_wallet/import_wallet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('citizenapp/security'),
          (_) async => null,
        ),
  );

  for (final leave in [false, true]) {
    testWidgets('导入${leave ? '退出后迟到结果不导航' : '成功清输入并返回true'}', (tester) async {
      final pending = Completer<CitizenWalletProfile>();
      final core = await openTestSdk();
      final sdk = core.sdk;
      var imports = 0, cancels = 0;
      CitizenSdkOperation<CitizenWalletProfile> importAction({
        required String mnemonic,
        String password = '',
      }) {
        imports++;
        return CitizenSdkOperation(
          operationId: 'import',
          result: pending.future,
          cancel: () async {
            cancels++;
            return true;
          },
        );
      }

      bool? result;
      await tester.pumpWidget(
        Provider<CitizenSdk>.value(
          value: sdk,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ImportWalletPage(importWallet: importAction),
                      ),
                    );
                  },
                  child: const Text('打开导入'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开导入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'synthetic mnemonic input',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认导入'));
      await tester.pump();
      expect(imports, 1);
      if (leave) {
        Navigator.of(tester.element(find.byType(ImportWalletPage))).pop();
        await tester.pumpAndSettle();
        expect(cancels, 1);
      }
      pending.complete(testCitizenWalletProfile());
      await tester.pumpAndSettle();
      expect(result, leave ? isNull : isTrue);
      expect(find.text('打开导入'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await sdk.close();
    });
  }

  testWidgets('导入失败使用原弹窗，重试后仍留页并保留输入', (tester) async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    CitizenSdkOperation<CitizenWalletProfile> importAction({
      required String mnemonic,
      String password = '',
    }) => testCitizenOperation(
      () => throw const CitizenSdkException(
        code: CitizenSdkErrorCode.invalidArgument,
        message: '合成助记词错误',
      ),
    );
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ImportWalletPage(importWallet: importAction),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'synthetic mnemonic input',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();
    expect(find.text('导入失败'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportWalletPage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'synthetic mnemonic input',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await sdk.close();
  });

  testWidgets('取消原密码确认不调用导入，也不清空助记词输入', (tester) async {
    final core = await openTestSdk();
    final sdk = core.sdk;
    var imports = 0;
    CitizenSdkOperation<CitizenWalletProfile> importAction({
      required String mnemonic,
      String password = '',
    }) {
      imports++;
      throw StateError('取消后不得导入');
    }

    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: sdk,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ImportWalletPage(importWallet: importAction),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'synthetic mnemonic input',
    );
    await tester.enterText(find.byType(TextField).last, 'Test123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();
    expect(find.text('确认钱包密码'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(imports, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'synthetic mnemonic input',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await sdk.close();
  });
}
