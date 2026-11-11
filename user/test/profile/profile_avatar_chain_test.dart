import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_user/identity/identity_badge.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
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
      head = f.block(104);
      await source.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityBadge>(find.byType(IdentityBadge)).style.checked,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
