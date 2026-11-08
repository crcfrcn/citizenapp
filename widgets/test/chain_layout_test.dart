import 'dart:async';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_widgets/chain_progress_banner.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chain_fixture.dart';

void main() {
  testWidgets('交易顶栏在极大字体下不反向缩字且保留完整无障碍语义', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(53 / 17),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ChainProgressBanner(
            showInlineStatus: true,
            progress: Stream.value(
              chainSnapshot(isSyncing: false, isUsable: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final banner = find.byKey(
      const ValueKey<String>('transaction-chain-status-inline'),
    );
    expect(
      find.descendant(of: banner, matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('公民链连接正常，最终区块 33'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('其他页面只读取状态且不渲染任何连接状态', (tester) async {
    CitizenChainSyncStatus? receivedProgress;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            progress: Stream.value(
              chainSnapshot(isSyncing: false, isUsable: true),
            ),
            onProgressChanged: (progress) => receivedProgress = progress,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(receivedProgress?.finalized.number, BigInt.from(33));
    expect(
      find.byKey(
        const ValueKey<String>('transaction-chain-status-inline'),
      ),
      findsNothing,
    );
    expect(find.text('公民链'), findsNothing);
    expect(find.textContaining('最终区块'), findsNothing);
  });

  testWidgets('不可见状态订阅在链就绪后继续接收链尖', (tester) async {
    final progress = StreamController<CitizenChainSyncStatus>();
    addTearDown(progress.close);
    final received = <CitizenChainSyncStatus?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            progress: progress.stream,
            onProgressChanged: received.add,
          ),
        ),
      ),
    );
    for (final snapshot in [
      chainSnapshot(isSyncing: false, isUsable: false),
      chainSnapshot(isSyncing: true, isUsable: false),
      chainSnapshot(isSyncing: false, isUsable: true),
      chainSnapshot(isSyncing: false, isUsable: true),
    ]) {
      progress.add(snapshot);
      await tester.pump();
      expect(find.textContaining('轻节点'), findsNothing);
    }
    expect(received.map((snapshot) => snapshot?.isUsable), [false, false, true, true]);
  });
}
