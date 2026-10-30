import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:citizen_account/identity/cid_generator.dart';
import 'package:citizen_account/identity/register_identity_sheet.dart';
import 'package:citizen_transaction/topup/onchain_topup_page.dart';

CitizenWalletStateAccount _account({int index = 0, String? id}) =>
    CitizenWalletStateAccount(
      signMode: CitizenWalletSignMode.hot,
      walletIndex: 0,
      accountIndex: index,
      accountId: id ?? '0x${index.toRadixString(16).padLeft(64, '0')}',
      ss58Address: 'w5BekTimvtfYZvFpkDzy7ypqUntPgTbjRFCt9weR8vMgf7o8E',
      name: '账户$index',
      createdAtMillis: BigInt.zero,
      isDefault: index == 0,
    );

void main() {
  // 面板提交回调读取选择；成功后才关闭，失败会留在当前面板。
  Future<void> openSheet(
    WidgetTester tester,
    void Function(RegisterChoice) sink, {
    List<CitizenWalletStateAccount>? accounts,
    RegistrationSubmitOutcome outcome = const RegistrationSubmitOutcome.success(
      '已注册',
    ),
    Future<RegistrationSubmitOutcome> Function(BuildContext, RegisterChoice)?
    submit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showRegisterIdentitySheet(
                    context,
                    accounts: accounts ?? [_account()],
                    onSubmit: (sheetContext, choice) async {
                      sink(choice);
                      if (submit != null) {
                        return await submit(sheetContext, choice);
                      }
                      return outcome;
                    },
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('默认选公民 + 默认绑账户0,确认返回 CTZN', (tester) async {
    RegisterChoice? picked;
    await openSheet(tester, (v) => picked = v);

    expect(find.text('公民'), findsOneWidget);
    expect(find.text('居民'), findsOneWidget);
    // 单账户不露出绑定账户选择。
    expect(find.text('绑定钱包账户'), findsNothing);

    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.institution, kCidInstitutionCitizen);
    expect(picked?.bindAccountId, _account().accountId);
  });

  testWidgets('确认按钮连续点击只提交一个选择', (tester) async {
    var calls = 0;
    await openSheet(tester, (_) => calls++);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认注册'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('选居民后确认返回 NATP', (tester) async {
    RegisterChoice? picked;
    await openSheet(tester, (v) => picked = v);

    await tester.tap(find.text('居民'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.institution, kCidInstitutionResident);
  });

  testWidgets('注册失败仍停留身份面板并展示准确原因', (tester) async {
    await openSheet(
      tester,
      (_) {},
      outcome: const RegistrationSubmitOutcome.failure('余额读取失败，请重试'),
    );
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.text('余额读取失败，请重试'), findsOneWidget);
  });

  testWidgets('提交期间系统返回与遮罩点击不关闭面板，结束后可主动取消', (tester) async {
    final pending = Completer<RegistrationSubmitOutcome>();
    await openSheet(tester, (_) {}, submit: (_, _) => pending.future);
    await tester.tap(find.text('确认注册'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );

    pending.complete(const RegistrationSubmitOutcome.failure('注册服务超时，请重试'));
    await tester.pumpAndSettle();
    expect(find.text('注册服务超时，请重试'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsNothing);
  });

  testWidgets('余额不足默认路由进入所选账户链上充值，返回仍保留注册面板', (tester) async {
    final target = _account(index: 5);
    await openSheet(
      tester,
      (_) {},
      accounts: [_account(), target],
      outcome: const RegistrationSubmitOutcome.failure(
        '注册失败：钱包余额不足',
        recharge: true,
      ),
    );
    await tester.tap(find.text('账户5'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pump();
    final topup = tester.widget<OnchainTopupPage>(
      find.byType(OnchainTopupPage),
    );
    expect(topup.accountId, target.accountId);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RegisterIdentitySheet), findsOneWidget);
    expect(find.textContaining('钱包余额不足'), findsOneWidget);
  });

  testWidgets('多账户时露出绑定账户选择,可选非0账户', (tester) async {
    RegisterChoice? picked;
    final a0 = _account(index: 0);
    final a5 = _account(
      index: 5,
      id: '0x5555555555555555555555555555555555555555555555555555555555555555',
    );
    await openSheet(tester, (v) => picked = v, accounts: [a0, a5]);

    expect(find.text('绑定钱包账户'), findsOneWidget);
    await tester.tap(find.text('账户5'));
    await tester.pump();
    await tester.tap(find.text('确认注册'));
    await tester.pumpAndSettle();
    expect(picked?.bindAccountId, a5.accountId);
  });

  testWidgets('含「投票/竞选须去注册局」的风险提示', (tester) async {
    await openSheet(tester, (_) {});
    expect(find.textContaining('投票公民、竞选公民只能在对应注册局'), findsOneWidget);
  });
}
