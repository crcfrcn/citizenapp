import 'dart:collection';

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
            progressLoader: () async => chainSnapshot(
              isSyncing: false,
              isUsable: true,
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
            progressLoader: () async => chainSnapshot(
              isSyncing: false,
              isUsable: true,
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

  testWidgets('不可见状态读取常驻轮询,regular 后仍继续跟进链尖', (tester) async {
    final snapshots = Queue<CitizenChainSyncStatus>.from([
      chainSnapshot(
        isSyncing: false,
        isUsable: false,
      ),
      chainSnapshot(
        isSyncing: true,
        isUsable: false,
      ),
      chainSnapshot(
        isSyncing: false,
        isUsable: true,
      ),
    ]);
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            pollInterval: const Duration(milliseconds: 10),
            progressLoader: () async {
              loadCount += 1;
              // 队列耗尽后复用最后一份 regular 快照,模拟链稳定期持续轮询。
              return snapshots.length > 1
                  ? snapshots.removeFirst()
                  : snapshots.first;
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('轻节点'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.textContaining('轻节点'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.textContaining('轻节点'), findsNothing);
    expect(loadCount, 3);

    // 轮询常驻:regular(isUsable)后仍按 pollInterval 继续跟进,
    // 顶部最终区块高度才能自动更新、不依赖下拉刷新。
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(loadCount, greaterThan(3));
  });
}
