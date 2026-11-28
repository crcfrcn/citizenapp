// 验证链进度顶栏的状态、失败恢复、布局及订阅清理。

import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_widgets/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 验证交易顶栏无障碍布局及其他页面不显示连接状态。

void _registerLayout() {
  testWidgets('交易顶栏在极大字体下不反向缩字且保留完整无障碍语义', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(53 / 17)),
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
    expect(find.bySemanticsLabel('公民链连接正常，最终区块 33'), findsOneWidget);
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
      find.byKey(const ValueKey<String>('transaction-chain-status-inline')),
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
    expect(received.map((snapshot) => snapshot?.isUsable), [
      false,
      false,
      true,
      true,
    ]);
  });
}

// 验证高度更新、失败保留、状态配色及迟到订阅撤销。

void _registerProgress() {
  testWidgets('已验证最终高度持续更新，失败保留高度，恢复后仍按原状态呈现', (tester) async {
    final progress = StreamController<CitizenChainSyncStatus>();
    addTearDown(progress.close);
    CitizenChainSyncStatus snapshot(int height) {
      final original = chainSnapshot(isSyncing: false, isUsable: true);
      return CitizenChainSyncStatus(
        peerCount: original.peerCount,
        isSyncing: false,
        isUsable: true,
        best: CitizenBlockRef(
          hash: original.best.hash,
          number: BigInt.from(999),
          finality: CitizenBlockFinality.best,
        ),
        finalized: CitizenBlockRef(
          hash: original.finalized.hash,
          number: BigInt.from(height),
          finality: CitizenBlockFinality.finalized,
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChainProgressBanner(
            showInlineStatus: true,
            progress: progress.stream,
          ),
        ),
      ),
    );
    progress.add(snapshot(33));
    await tester.pump();
    expect(find.text('最终区块 33'), findsOneWidget);
    expect(find.text('最终区块 999'), findsNothing);
    progress.addError(StateError('合成断开'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('最终区块 33')).style?.color,
      AppTheme.danger,
    );
    progress.add(snapshot(34));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('最终区块 34')).style?.color,
      AppTheme.success,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(progress.hasListener, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('轻节点状态退出后才到达，订阅已经取消', (tester) async {
    final progress = StreamController<CitizenChainSyncStatus>();
    addTearDown(progress.close);
    var callbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChainProgressBanner(
          showInlineStatus: true,
          progress: progress.stream,
          onProgressChanged: (_) => callbacks++,
          onErrorChanged: (_) => callbacks++,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    progress.add(chainSnapshot(isSyncing: false, isUsable: true));
    await tester.pump();
    expect(progress.hasListener, isFalse);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('交易顶栏只用整组颜色表达连接状态', (tester) async {
    final progress = StreamController<CitizenChainSyncStatus>();
    addTearDown(progress.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            showInlineStatus: true,
            progress: progress.stream,
          ),
        ),
      ),
    );
    progress.add(chainSnapshot(isSyncing: true, isUsable: false));
    await tester.pump();
    await tester.pump();

    var chainLabel = tester.widget<Text>(find.text('公民链'));
    var finalizedLabel = tester.widget<Text>(find.text('最终区块 0'));
    expect(chainLabel.style?.color, AppTheme.info);
    expect(finalizedLabel.style?.color, AppTheme.info);
    expect(find.textContaining('更新中'), findsNothing);

    progress.add(chainSnapshot(isSyncing: false, isUsable: true));
    await tester.pump();
    await tester.pump();
    chainLabel = tester.widget<Text>(find.text('公民链'));
    finalizedLabel = tester.widget<Text>(find.text('最终区块 33'));
    expect(chainLabel.style?.color, AppTheme.success);
    expect(finalizedLabel.style?.color, AppTheme.success);
    expect(find.textContaining('已更新'), findsNothing);
  });

  testWidgets('交易顶栏读取失败时整组变红但不显示失败文字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            showInlineStatus: true,
            progress: Stream<CitizenChainSyncStatus>.error(
              StateError('offline'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final chainLabel = tester.widget<Text>(find.text('公民链'));
    final finalizedLabel = tester.widget<Text>(find.text('最终区块 —'));
    expect(chainLabel.style?.color, AppTheme.danger);
    expect(finalizedLabel.style?.color, AppTheme.danger);
    expect(find.textContaining('连接失败'), findsNothing);
  });
}

// 提供不绑定真实创世版本的链状态界面测试夹具。

CitizenChainSyncStatus chainSnapshot({
  required bool isSyncing,
  required bool isUsable,
}) {
  const finalizedHash =
      '0xe3985a35f8668d74f1552be80e1e4c5c01fcce7f7c757cc0cf254ec21a1d2d9c';
  // UI 状态夹具使用合成哈希，不绑定任何真实创世版本。
  final finalizedNumber = isUsable ? BigInt.from(33) : BigInt.zero;
  return CitizenChainSyncStatus(
    peerCount: BigInt.from(5),
    isSyncing: isSyncing,
    isUsable: isUsable,
    best: CitizenBlockRef(
      hash: finalizedHash,
      number: BigInt.from(33),
      finality: CitizenBlockFinality.best,
    ),
    finalized: CitizenBlockRef(
      hash: finalizedHash,
      number: finalizedNumber,
      finality: CitizenBlockFinality.finalized,
    ),
  );
}

void main() {
  group('布局', _registerLayout);
  group('状态', _registerProgress);
}
