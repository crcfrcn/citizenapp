import 'dart:async';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_user/identity/identity_badge.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('轻节点尚无该公民数据时不把旧参数显示成身份或会员徽章', (tester) async {
    final reader = f.Reader();
    final reading = Completer<void>();
    reader.behavior = (account, block, citizens, creators) async {
      if (citizens.contains(f.cidB)) await reading.future;
      return f.snapshot(block, account, citizens: citizens, creators: creators);
    };
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => f.block(103),
      getGenesisHash: () async => f.hash(0),
      getAccount: () async => f.account(1),
    );
    addTearDown(source.close);
    await source.start();
    await tester.pumpWidget(
      ChangeNotifierProvider<ChainDataService>.value(
        value: source,
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              seed: f.cidB,
              size: 80,
              cidLevel: 'candidate',
              memberLevel: 'spark',
              membergateActive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IdentityBadge), findsNothing);
    reading.complete();
    await tester.pumpAndSettle();
    final badge = tester.widget<IdentityBadge>(find.byType(IdentityBadge));
    expect(badge.style.checked, isTrue);
    expect(badge.tooltip, '访客 · 自由会员');
    await tester.pumpWidget(const SizedBox());
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform头像随最终块会员变更，不接受旧展示参数覆盖', (tester) async {
      final reader = f.Reader();
      var head = f.block(103);
      reader.behavior = (a, b, c, d) async => f.snapshot(
        b,
        a,
        citizens: c,
        creators: d,
        hasMembership: b.number < BigInt.from(104),
      );
      final source = ChainDataService(
        reader: reader,
        getFinalizedHead: () async => head,
        getGenesisHash: () async => f.hash(0),
        getAccount: () async => f.account(1),
      );
      addTearDown(source.close);
      await source.start();
      await tester.pumpWidget(
        ChangeNotifierProvider<ChainDataService>.value(
          value: source,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(
              body: ProfileAvatar(
                seed: f.cidA,
                size: 80,
                cidLevel: 'candidate',
                membergateActive: true,
                memberLevel: 'spark',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).style.checked,
        isTrue,
      );
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).tooltip,
        '访客 · 自由会员',
      );
      head = f.block(104);
      await source.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).style.checked,
        isFalse,
      );
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).tooltip,
        '访客',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
