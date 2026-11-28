// 验证付款页面及意图编码金标。

import 'package:citizen_offchain/bank.dart' show ClearingBankDirectory;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_sdk/test/platform/fixture.dart';
import 'package:citizen_testing/sdk.dart';
import 'package:citizen_offchain/rpc.dart' show OffchainClearingBankRpc;
import 'package:citizen_offchain/payment.dart' show OffchainClearingPayPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:citizen_offchain/data.dart' show NodePaymentIntent;

void main() {
  group('offchain_pay_page_test', _registerPayment);
  group('payment_intent_golden_test', _registerIntent);
}

// 验证付款发送后的未知状态及发送前取消不被误判成功。

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

void _registerPayment() {
  var signFails = false;
  final harness = TestCitizenSdkHarness();
  final directory = ClearingBankDirectory(
    getRuntimeContext: CitizenSdkTestFixture.runtimeContext,
    getFinalizedHead: () async => CitizenBlockRef(
      hash: '0x${'ab' * 32}',
      number: BigInt.from(50),
      finality: CitizenBlockFinality.finalized,
    ),
    getStorage: (block, key) async {
      List<int> text(String value) => [
        utf8.encode(value).length << 2,
        ...utf8.encode(value),
      ];
      return Uint8List.fromList([
        ...text('peer'),
        ...text('clearing.example'),
        216,
        38,
        1,
        0,
        0,
        0,
        ...List.filled(32, 3),
      ]);
    },
  );
  setUp(() {
    signFails = false;
  }); // SDK纯编码仍走真实Core，不在App复制签名或SCALE算法。
  final address = citizenSs58FromAccountIdBytes(List.filled(32, 2));
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
            directory: directory,
            bestHeadReader: () async => CitizenBlockRef(
              hash: '0x${'ab' * 32}',
              number: BigInt.from(50),
              finality: CitizenBlockFinality.best,
            ),
            payloadSigner: (id, payload, action, context) async {
              if (signFails) throw StateError('合成签名取消');
              return Uint8List(64);
            },
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

// 以跨端黄金向量核对支付意图SCALE和操作域摘要。

/// 扫码支付跨端 golden vectors。
///
/// 与 `citizenchain/runtime/transaction/offchain/src/batch_item.rs::tests`
/// 的 `golden_fixture1/2/3` **逐字节同步**:相同输入(含清算行 **CID**)→ 相同
/// SCALE 编码 → 相同 `signing_hash`。任一端漂移(字段顺序 / 字节序 / 签名域
/// 前缀 / 哈希算法 / CID 布局)都会立即断言失败。
///
/// **锁定的不变量(CID 主键)**:
/// - `NodePaymentIntent` 变长 SCALE 布局:bank 字段为 CID = `Compact(len)||bytes`
///   (与 runtime `InstitutionCidNumber = BoundedVec<u8>` 逐字节等价)
/// - 签名经统一原语 `signingMessage(OP_SIGN_L3_PAY=0x15, ...)`(ADR-026)
/// - `signingHash()` = `blake2b_256(GMB(3B) || 0x15 || scaleEncode())`

void _registerIntent() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestCitizenSdkHarness();

  group('PaymentIntent golden vectors (cross-Rust, CID 主键)', () {
    test('fixture 1: simple same-bank payment', () async {
      final intent = NodePaymentIntent(
        txId: _filledBytes(32, 0x00),
        payer: _filledBytes(32, 0x01),
        payerBankCid: _cid('LN001-NRC0G-944805165-2026'),
        recipient: _filledBytes(32, 0x03),
        recipientBankCid: _cid('LN001-NRC0G-944805165-2026'),
        amount: BigInt.from(10000),
        fee: BigInt.from(5),
        nonce: BigInt.from(1),
        expiresAt: 100,
      );
      _assertHexEq(
        'fixture1 signing_hash',
        await intent.signingHash(),
        '4c0c52528976ee38e101769c27ee57a0e30e18939503271fb12a59b58df886fe',
      );
    });

    test('fixture 2: cross-bank with u128/u64/u32 max values', () async {
      final intent = NodePaymentIntent(
        txId: _filledBytes(32, 0xFF),
        payer: _filledBytes(32, 0x11),
        payerBankCid: _cid('GD001-SFGF0-201206100-2026'),
        recipient: _filledBytes(32, 0x22),
        recipientBankCid: _cid('AH001-SFGF0-111111111-2026'),
        amount: _uMax(16), // u128::MAX
        fee: _uMax(16),
        nonce: _uMax(8), // u64::MAX
        expiresAt: 0xFFFFFFFF, // u32::MAX
      );
      _assertHexEq(
        'fixture2 signing_hash',
        await intent.signingHash(),
        '38ba8205abb84ec9121b65c3ee618626972710063e8e6c48cec29b1121460e72',
      );
    });

    test('fixture 3: zero amount / fee, incrementing tx_id bytes', () async {
      final txBytes = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        txBytes[i] = i; // 0x00..0x1F
      }
      final intent = NodePaymentIntent(
        txId: txBytes,
        payer: _filledBytes(32, 0x55),
        payerBankCid: _cid('BJ001-SFGF0-222222222-2026'),
        recipient: _filledBytes(32, 0x66),
        recipientBankCid: _cid('BJ001-SFGF0-222222222-2026'),
        amount: BigInt.zero,
        fee: BigInt.zero,
        nonce: BigInt.zero,
        expiresAt: 0,
      );
      _assertHexEq(
        'fixture3 signing_hash',
        await intent.signingHash(),
        '62405346ffba9e0a4b9d785cf399bfdfcdc1033270dbc8a7b4cbc9ba4e052c9f',
      );
    });

    test('signingHash 经统一原语 signingMessage(OP_SIGN_L3_PAY)', () async {
      final intent = NodePaymentIntent(
        txId: _filledBytes(32, 0x00),
        payer: _filledBytes(32, 0x01),
        payerBankCid: _cid('LN001-NRC0G-944805165-2026'),
        recipient: _filledBytes(32, 0x03),
        recipientBankCid: _cid('LN001-NRC0G-944805165-2026'),
        amount: BigInt.from(10000),
        fee: BigInt.from(5),
        nonce: BigInt.from(1),
        expiresAt: 100,
      );
      final viaPrimitive = (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignL3Pay,
          scalePayload: intent.scaleEncode(),
        ),
      ));
      expect(_hexLower(await intent.signingHash()), _hexLower(viaPrimitive));
    });

    test('相同 PaymentIntent 在其它操作码下生成不同签名消息', () async {
      final intent = NodePaymentIntent(
        txId: _filledBytes(32, 0x00),
        payer: _filledBytes(32, 0x01),
        payerBankCid: _cid('LN001-NRC0G-944805165-2026'),
        recipient: _filledBytes(32, 0x03),
        recipientBankCid: _cid('LN001-NRC0G-944805165-2026'),
        amount: BigInt.from(10000),
        fee: BigInt.from(5),
        nonce: BigInt.from(1),
        expiresAt: 100,
      );
      final batchOperationMessage = (await CitizenSdk.encodePayload(
        CitizenSigningPayload.message(
          opTag: kOpSignOffchainBatch,
          scalePayload: intent.scaleEncode(),
        ),
      ));
      expect(
        _hexLower(await intent.signingHash()),
        isNot(_hexLower(batchOperationMessage)),
      );
    });

    test('scaleEncode bank 字段用 Compact(len)||bytes(变长)', () async {
      final cid = _cid('LN001-NRC0G-944805165-2026'); // 26 字节
      final intent = NodePaymentIntent(
        txId: _filledBytes(32, 0),
        payer: _filledBytes(32, 0),
        payerBankCid: cid,
        recipient: _filledBytes(32, 0),
        recipientBankCid: cid,
        amount: BigInt.zero,
        fee: BigInt.zero,
        nonce: BigInt.zero,
        expiresAt: 0,
      );
      // 32(tx)+32(payer)+(1+26)+32(recipient)+(1+26)+16+16+8+4 = 194。
      expect(
        intent.scaleEncode().length,
        32 + 32 + (1 + 26) + 32 + (1 + 26) + 16 + 16 + 8 + 4,
      );
    });
  });
}

Uint8List _cid(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _filledBytes(int len, int byte) {
  final out = Uint8List(len);
  for (var i = 0; i < len; i++) {
    out[i] = byte;
  }
  return out;
}

/// (1 << (bytes*8)) - 1,跨越 int64 溢出用 BigInt。
BigInt _uMax(int bytes) => (BigInt.one << (bytes * 8)) - BigInt.one;

String _hexLower(Uint8List bytes) {
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

void _assertHexEq(String label, Uint8List actual, String expected) {
  final got = _hexLower(actual);
  expect(got, equals(expected), reason: '$label mismatch');
}
