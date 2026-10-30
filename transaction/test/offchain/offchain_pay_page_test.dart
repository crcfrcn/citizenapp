import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';
import 'package:citizen_transaction/offchain/offchain_clearing_rpc.dart';
import 'package:citizen_transaction/offchain/offchain_pay_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart' show Keyring;
import 'package:provider/provider.dart';

class Rpc extends OffchainClearingBankRpc {
  Rpc(this.mode) : super('wss://clearing.example:9944');
  final String mode;
  int submissions = 0;
  @override
  Future<dynamic> call(String method, List<dynamic> params) async {
    switch (method) {
      case 'offchain_queryUserBank':
        return 'BANK';
      case 'offchain_queryFeeRate':
        return {'rate_bp': 10, 'min_fee_fen': 1};
      case 'offchain_queryNextNonce':
        return 1;
      case 'offchain_submitPayment':
        submissions++;
        if (mode == 'transport') throw TimeoutException('合成响应丢失');
        if (mode == 'rpcerror') throw StateError('合成远端失败');
        return {
          'tx_id': mode == 'wrong'
              ? '0x${'ff' * 32}'
              : (params[0] as String).substring(0, 66),
          if (mode != 'missing') 'l2_ack_sig': '0x${'02' * 64}',
          'accepted_at': 10,
        };
      default:
        throw StateError('未配置清算方法');
    }
  }
}

void main() {
  var signFails = false;
  final harness = TestCitizenSdkHarness(
    handlers: {
      'getFinalizedHead': (_) => [
        ['0x${'ab' * 32}', '50', 'finalized'],
      ],
      'getBestHead': (_) => [
        ['0x${'ab' * 32}', '50', 'best'],
      ],
      'getStorage': (_) {
        List<int> text(String value) => [
          utf8.encode(value).length << 2,
          ...utf8.encode(value),
        ];
        return [
          Uint8List.fromList([
            ...text('peer'),
            ...text('clearing.example'),
            216,
            38,
            1,
            0,
            0,
            0,
            ...List.filled(32, 3),
          ]),
        ];
      },
      'beginSigning': (fields) {
        if (signFails) throw StateError('合成签名取消');
        return [
          [
            'completed',
            fields[0],
            '0x${'00' * 32}',
            Uint8List(64),
            null,
            null,
            null,
          ],
        ];
      },
    },
  );
  setUp(() {
    signFails = false;
  }); // SDK纯编码仍走真实Core，不在App复制签名或SCALE算法。
  final address = Keyring().encodeAddress(List.filled(32, 2), 42);
  final wallet = CitizenWalletStateAccount(
    signMode: CitizenWalletSignMode.hot,
    walletIndex: 0,
    accountIndex: 0,
    name: '合成账户',
    ss58Address: address,
    accountId: '0x${'01' * 32}',
    createdAtMillis: BigInt.zero,
    isDefault: true,
  );
  Future<void> open(WidgetTester tester, Rpc rpc) async {
    await tester.pumpWidget(
      Provider<CitizenSdk>.value(
        value: harness.sdk,
        child: MaterialApp(
          home: OffchainClearingPayPage(
            wallet: wallet,
            toAddress: address,
            recipientBankCidNumber: 'BANK',
            clearingNodeWssUrl: rpc.wssUrl,
            initialAmountYuan: '1',
            nodeRpc: rpc,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('确认并签名付款'), findsOneWidget);
    await tester.ensureVisible(find.text('确认并签名付款'));
    await tester.tap(find.text('确认并签名付款'));
    await tester.pumpAndSettle();
  }

  for (final mode in ['match', 'wrong', 'missing', 'transport', 'rpcerror']) {
    testWidgets('付款发送后$mode均不能假报成功或允许再次付款', (tester) async {
      final rpc = Rpc(mode);
      await open(tester, rpc);
      expect(rpc.submissions, 1);
      expect(find.text('付款结果未核实，请勿重复付款。请核对本笔交易记录。'), findsOneWidget);
      expect(find.textContaining('支付已受理'), findsNothing);
      expect(find.text('确认并签名付款'), findsNothing);
      await tester.pumpAndSettle();
      expect(rpc.submissions, 1);
    });
  }
  testWidgets('发送前签名取消属于未提交失败，不伪造已发送', (tester) async {
    final rpc = Rpc('match');
    signFails = true;
    await open(tester, rpc);
    expect(rpc.submissions, 0);
    expect(find.textContaining('提交失败'), findsOneWidget);
    expect(find.textContaining('付款结果未核实'), findsNothing);
  });
}
