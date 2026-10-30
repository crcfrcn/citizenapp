import 'dart:async';
import 'dart:collection';

import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_widgets/chain_progress_banner.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chain_fixture.dart';

void main() {
  testWidgets('已验证最终高度持续更新，失败保留高度，恢复后仍按原状态呈现', (tester) async {
    var fail = false;
    var height = 33;
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ChainProgressBanner(
        showInlineStatus: true,
        pollInterval: const Duration(milliseconds: 10),
        progressLoader: () async {
          calls++;
          if (fail) throw StateError('合成断开');
          final original = chainSnapshot(isSyncing: false, isUsable: true);
          return CitizenChainSyncStatus(
            peerCount: original.peerCount, isSyncing: false, isUsable: true,
            best: CitizenBlockRef(hash: original.best.hash,
                number: BigInt.from(999), finality: CitizenBlockFinality.best),
            finalized: CitizenBlockRef(hash: original.finalized.hash,
                number: BigInt.from(height), finality: CitizenBlockFinality.finalized),
          );
        },
      ),
    )));
    await tester.pump();
    expect(find.text('最终区块 33'), findsOneWidget);
    expect(find.text('最终区块 999'), findsNothing);
    fail = true;
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(tester.widget<Text>(find.text('最终区块 33')).style?.color, AppTheme.danger);
    fail = false;
    height = 34;
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(tester.widget<Text>(find.text('最终区块 34')).style?.color, AppTheme.success);
    await tester.pumpWidget(const SizedBox.shrink());
    final callsAtExit = calls;
    await tester.pump(const Duration(seconds: 1));
    expect(calls, callsAtExit);
    expect(tester.takeException(), isNull);
  });

  testWidgets('轻节点读取退出后才完成，不回调页面也不恢复轮询', (tester) async {
    final pending = Completer<CitizenChainSyncStatus>();
    var calls = 0;
    var callbacks = 0;
    await tester.pumpWidget(MaterialApp(home: ChainProgressBanner(
      showInlineStatus: true,
      pollInterval: const Duration(milliseconds: 10),
      progressLoader: () { calls++; return pending.future; },
      onProgressChanged: (_) => callbacks++,
      onErrorChanged: (_) => callbacks++,
    )));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(chainSnapshot(isSyncing: false, isUsable: true));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('交易顶栏只用整组颜色表达连接状态', (tester) async {
    final snapshots = Queue<CitizenChainSyncStatus>.from([
      chainSnapshot(
        isSyncing: true,
        isUsable: false,
      ),
      chainSnapshot(
        isSyncing: false,
        isUsable: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChainProgressBanner(
            showInlineStatus: true,
            pollInterval: const Duration(milliseconds: 10),
            // 轮询常驻:队列耗尽后复用最后一份快照,模拟链稳定期。
            progressLoader: () async => snapshots.length > 1
                ? snapshots.removeFirst()
                : snapshots.first,
          ),
        ),
      ),
    );
    await tester.pump();

    var chainLabel = tester.widget<Text>(find.text('公民链'));
    var finalizedLabel = tester.widget<Text>(find.text('最终区块 0'));
    expect(chainLabel.style?.color, AppTheme.info);
    expect(finalizedLabel.style?.color, AppTheme.info);
    expect(find.textContaining('更新中'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));
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
            progressLoader: () async => throw StateError('offline'),
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
