import 'dart:ffi';
import 'dart:io';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_widgets/chain_balance_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const account =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
CitizenBlockRef block(int n) => CitizenBlockRef(
  hash: '0x${n.toRadixString(16).padLeft(64, '0')}',
  number: BigInt.from(n),
  finality: CitizenBlockFinality.finalized,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DynamicLibrary.open(Platform.environment['CITIZENSDK_TEST_LIBRARY']!);
  testWidgets(
    'a retained hidden tab stops balance reads and catches up when visible',
    (tester) async {
      var height = 1, reads = 0;
      var active = true;
      late StateSetter update;
      final store = CitizenBalances(
        getFinalizedHead: () async => block(height),
        getAccountBalances: (ids) async {
          reads++;
          return [
            for (final id in ids)
              CitizenAccountBalance(
                accountId: id,
                block: block(height),
                freeFen: BigInt.from(height),
                reservedFen: BigInt.zero,
                totalFen: BigInt.from(height),
              ),
          ];
        },
      );
      addTearDown(store.close);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [chainBalanceRoutes],
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ChainBalanceVisibility(
                active: active,
                child: ChainBalanceScope(
                  balances: store,
                  accountIds: [account],
                  builder: (_, balances) => Text(
                    balances.accountState(account).value?.freeFen.toString() ??
                        'loading',
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(find.text('1'), findsOneWidget);
      update(() {
        active = false;
      });
      await tester.pump();
      height = 2;
      store.finalized(block(height));
      await tester.pumpAndSettle();
      expect(reads, 1);
      update(() {
        active = true;
      });
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('covering a route releases watches; returning subscribes again', (
    tester,
  ) async {
    var height = 1, reads = 0;
    final store = CitizenBalances(
      getFinalizedHead: () async => block(height),
      getAccountBalances: (ids) async {
        reads++;
        return [
          for (final id in ids)
            CitizenAccountBalance(
              accountId: id,
              block: block(height),
              freeFen: BigInt.from(height),
              reservedFen: BigInt.zero,
              totalFen: BigInt.from(height),
            ),
        ];
      },
    );
    addTearDown(store.close);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [chainBalanceRoutes],
        home: ChainBalanceScope(
          balances: store,
          accountIds: [account],
          builder: (_, balances) => Text(
            balances.accountState(account).value?.freeFen.toString() ??
                'loading',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 1);
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('other')),
      ),
    );
    await tester.pumpAndSettle();
    height = 2;
    store.finalized(block(height));
    await tester.pumpAndSettle();
    expect(reads, 1);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
