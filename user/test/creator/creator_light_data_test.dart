import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_testing/chain_data_fixture.dart' as f;
import 'package:citizen_user/creator/creator_page.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/identity/cid_business_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Gate extends Fake implements CidBusinessGate {
  @override
  Future<CidBusinessDecision> resolve() async =>
      const CidBusinessDecision(CidBusinessStatus.ready, cidNumber: f.cidA);
}

class _Service extends Fake implements CreatorService {
  int calls = 0;
  @override
  Future<CreatorPageData> load({String? expectedCidNumber}) async {
    calls++;
    throw const CreatorException('云端统计不可用');
  }
}

void main() {
  testWidgets('创作者链上档位直接展示，云端概览故障保留档位且不伪造统计', (tester) async {
    final reader = f.Reader(), service = _Service();
    reader.behavior = (a, b, c, d) async => f.snapshot(
      b,
      a,
      citizens: c,
      creators: d,
      creatorTiers: [
        ChainCreatorTier(
          tierId: 'tier1',
          tierName: '链上铁杆',
          pricesFen: {'monthly': BigInt.from(990)},
        ),
      ],
    );
    final source = ChainDataService(
      reader: reader,
      getFinalizedHead: () async => f.block(103),
      getGenesisHash: () async => f.hash(0),
      getAccount: () async => f.account(1),
    );
    addTearDown(source.close);
    await source.start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChainDataService>.value(value: source),
          Provider<CidBusinessGate>.value(value: _Gate()),
        ],
        child: MaterialApp(home: CreatorPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('链上铁杆'), findsOneWidget);
    expect(service.calls, 0);
    expect(find.text('已开通'), findsNothing);
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('链上铁杆'), findsOneWidget);
    expect(find.text('云端统计不可用'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
