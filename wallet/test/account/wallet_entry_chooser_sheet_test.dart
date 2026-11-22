// 验证多种字体尺寸下五项钱包菜单可滚动和点击。

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_wallet/account/wallet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = ['添加经典账户', '指定经典账户', '添加量子账户', '指定量子账户', '导入冷钱包'];
  const icons = [
    Icons.person_add_alt_1_outlined,
    Icons.tag_rounded,
    Icons.memory_outlined,
    Icons.radar_rounded,
    Icons.shield_outlined,
  ];
  for (final scenario in [
    (const Size(800, 300), 1.0),
    (const Size(360, 640), 2.0),
  ]) {
    testWidgets('五项底部菜单在 ${scenario.$1}、${scenario.$2} 倍字号下可滚动点击', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => WalletEntryChooserSheet(
                        canAddAccount: true,
                        derivations: CitizenAccountDerivation.values,
                        onAddNextAccount: () => calls.add(labels[0]),
                        onAddSpecifyAccount: () => calls.add(labels[1]),
                        onAddNextQuantumAccount: () => calls.add(labels[2]),
                        onAddSpecifyQuantumAccount: () => calls.add(labels[3]),
                        onImportCold: () => calls.add(labels[4]),
                      ),
                    ),
                  ),
                  child: const Text('添加账户'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('添加账户'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final handle = find.byKey(const ValueKey('wallet-entry-drag-handle'));
      expect(handle, findsOneWidget);
      expect(
        tester.getCenter(handle).dx,
        closeTo(tester.getCenter(find.byType(WalletEntryChooserSheet)).dx, 0.1),
      );
      // 使用真实底部弹层限制，逐项滚动并点击，防止只在整页容器中验证菜单。
      for (final label in labels) {
        final option = find.text(label);
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        final index = labels.indexOf(label);
        if (index < icons.length) {
          final card = find.ancestor(
            of: option,
            matching: find.byType(ListTile),
          );
          final icon = find.descendant(
            of: card,
            matching: find.byIcon(icons[index]),
          );
          expect(icon, findsOneWidget);
          expect(
            tester.getCenter(icon).dx,
            lessThan(tester.getTopLeft(option).dx),
          );
        }
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(calls, labels);
      Navigator.of(tester.element(find.text(labels.last))).pop();
      await tester.pumpAndSettle();
    });
  }
}
