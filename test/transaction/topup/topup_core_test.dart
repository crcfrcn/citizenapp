import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/transaction/topup/topup_models.dart';
import 'package:citizenapp/transaction/topup/topup_api.dart';
import 'package:citizenapp/transaction/topup/topup_erc20.dart';
import 'package:citizenapp/transaction/topup/wallet_link_dispatcher.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/transaction/topup/contract.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  test('六条准确币轨、两个套餐和18位金额不丢精度', () {
    final c = TopupConfig.fromJson(fixture()['config'] as Map<String, dynamic>);
    expect(c.rails.length, 6);
    expect(c.packages.length, 2);
    expect(c.rail('USDT', TopupNetwork.bnb).decimals, 18);
    expect(
      c.packages[1].amount(c.rail('USDT', TopupNetwork.bnb)),
      '1400000000000000000000',
    );
    for (final n in TopupNetwork.values) {
      for (final t in ['USDC', 'USDT']) {
        if (!allowedPair(t, n))
          expect(() => c.rail(t, n), throwsFormatException);
      }
    }
    final bad = fixture()['config'] as Map<String, dynamic>;
    bad['packages'].add(bad['packages'][0]);
    expect(() => TopupConfig.fromJson(bad), throwsFormatException);
  });
  test('缺失、假金额、错误精度、重复币轨和不支持的资产组合均拒绝', () {
    for (var n = 0; n < 5; n++) {
      final j = fixture()['config'] as Map<String, dynamic>;
      switch (n) {
        case 0:
          j['rails'][0]['decimals'] = 18;
        case 1:
          j['rails'][0]['token'] = 'OTHER';
        case 2:
          j['packages'][0]['payments'][0]['pay_amount'] = '15.0';
        case 3:
          j['rails'][1] = j['rails'][0];
        case 4:
          j['packages'][0]['package_id'] = 'custom';
      }
      expect(() => TopupConfig.fromJson(j), throwsFormatException);
    }
  });
  test('付款意图、HMAC原文及钱包消息逐字段对齐服务端金标', () {
    final j = fixture();
    final i = TopupPaymentIntent.fromJson(j['intent'] as Map<String, dynamic>);
    final c = TopupConfig.fromJson(j['config'] as Map<String, dynamic>);
    i.validatePayment(
      rail: c.rail('USDC', TopupNetwork.base),
      package: c.packages[0],
      accountId: i.accountId,
      payerAddress: i.payer,
      chainGenesisHash: '0x${'00' * 32}',
      serviceOrigin: 'https://www.crcfrcn.com',
      now: 1005000,
    );
    expect(
      () => i.validatePayment(
        rail: c.rail('USDC', TopupNetwork.base),
        package: c.packages[0],
        accountId: '0x${'05' * 32}',
        payerAddress: i.payer,
        chainGenesisHash: '0x${'00' * 32}',
        serviceOrigin: 'https://www.crcfrcn.com',
        now: 1005000,
      ),
      throwsFormatException,
    );
    expect(
      () => i.validatePayment(
        rail: c.rail('USDC', TopupNetwork.base),
        package: c.packages[0],
        accountId: i.accountId,
        payerAddress: i.payer,
        chainGenesisHash: '0x${'00' * 32}',
        serviceOrigin: 'https://www.crcfrcn.com',
        now: i.expiresAt,
      ),
      throwsFormatException,
    );
    final bad = fixture()['intent'] as Map<String, dynamic>;
    bad['intent']['pay_amount'] = '16000000';
    expect(() => TopupPaymentIntent.fromJson(bad), throwsFormatException);
  });
  test('三协议地址及交易格式独立，Solana大小写不能转小写', () {
    final f = fixture();
    for (final name in ['tron', 'solana']) {
      final j = f['native'][name] as Map<String, dynamic>;
      final n = TopupNetwork.parse(name);
      expect(
        n.address(j['intent']['payer_address'] as String),
        j['intent']['payer_address'],
      );
      expect(n.transaction(j['txid'] as String), true);
      n.signature(j['signature'] as String);
    }
    expect(TopupNetwork.solana.transaction('0x${'11' * 32}'), false);
    expect(TopupNetwork.tron.transaction('0x${'11' * 32}'), false);
    expect(TopupNetwork.base.transaction('11' * 32), false);
  });
  test('ERC20严格uint256整数字符串编码，负值/溢出/错误地址拒绝', () {
    final data = encodeErc20Transfer(
      '0x${'22' * 20}',
      BigInt.parse('1400000000000000000000'),
    );
    expect(data.length, 138);
    expect(
      data.endsWith(
        BigInt.parse('1400000000000000000000')
            .toRadixString(16)
            .padLeft(64, '0'),
      ),
      true,
    );
    expect(() => encodeErc20Transfer('bad', BigInt.one), throwsArgumentError);
    expect(
      () => encodeErc20Transfer('0x${'22' * 20}', BigInt.from(-1)),
      throwsArgumentError,
    );
    expect(
      () => encodeErc20Transfer('0x${'22' * 20}', BigInt.one << 256),
      throwsArgumentError,
    );
  });
  test('钱包唤起保留scheme和HTTPS桥接，远端主框架及危险协议拒绝', () async {
    for (final s in [
      'http://bad',
      'javascript:alert(1)',
      'data:text/html,bad',
      'mailto:test@test',
    ]) {
      expect(
        WalletLinkDispatcher.classify(
          s,
          source: WalletLinkSource.walletOpenBridge,
        ).disposition,
        WalletLinkDisposition.blocked,
      );
    }
    expect(
      WalletLinkDispatcher.classify(
        'https://wallet.example/',
        source: WalletLinkSource.webViewNavigation,
      ).disposition,
      WalletLinkDisposition.blocked,
    );
    expect(
      WalletLinkDispatcher.classify(
        'https://wallet.example/',
        source: WalletLinkSource.walletOpenBridge,
      ).disposition,
      WalletLinkDisposition.openExternalWallet,
    );
    final called = <String>[];
    final links = WalletLinkDispatcher(
      launcher: (u) async {
        called.add(u.toString());
        return true;
      },
    );
    expect(
      await links.open(
        'wallet://wc?uri=wc%3Atest',
        source: WalletLinkSource.walletOpenBridge,
      ),
      WalletLinkOpenResult.opened,
    );
    expect(called.length, 1);
    expect(
      await WalletLinkDispatcher(launcher: (_) async => false)
          .open('wallet://connect', source: WalletLinkSource.walletOpenBridge),
      WalletLinkOpenResult.failed,
    );
    expect(
      await WalletLinkDispatcher(
        launcher: (_) async => throw StateError('test'),
      ).open('wallet://connect', source: WalletLinkSource.walletOpenBridge),
      WalletLinkOpenResult.failed,
    );
  });
  test('API使用当前network和payment_txid合同，不带普通会话或把凭证放URL', () async {
    final f = fixture();
    final i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    var calls = 0;
    final api = TopupApi(
      baseUrl: 'https://www.crcfrcn.com/api',
      httpClient: MockClient((r) async {
        calls++;
        expect(r.headers.containsKey('authorization'), false);
        expect(r.url.query, isEmpty);
        if (r.url.path.endsWith('/config'))
          return http.Response(jsonEncode(f['config']), 200);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        if (r.url.path.endsWith('/intent')) {
          expect(body['network'], 'base');
          expect(body.containsKey('cid_number'), false);
          return http.Response(jsonEncode(f['intent']), 200);
        }
        if (r.url.path.endsWith('/confirm')) {
          expect(body.keys.toSet(), {
            'payment_intent',
            'payment_txid',
            'payer_signature',
          });
          expect(body['payer_signature'], f['signature']);
        }
        return http.Response(
          jsonEncode({
            'ok': true,
            'order_id': i.order,
            'status': 'pending',
            'phase': 'verifying',
            'coin_fen': i.coinFen,
            'payment_txid': '0x${'09' * 32}',
            'gmb_tx_hash': null,
            'reason': null,
          }),
          200,
        );
      }),
    );
    await api.fetchConfig();
    await api.createIntent(
      token: 'USDC',
      packageId: 'pkg_15',
      accountId: i.accountId,
      payer: TopupContext(TopupNetwork.base, i.payer),
    );
    await api.confirm(
      intent: i,
      paymentTxid: '0x${'09' * 32}',
      payerSignature: f['signature'] as String,
    );
    expect((await api.status(i)).phase, TopupPhase.verifying);
    expect(calls, 4);
    api.close();
  });
  test('API准确读取error字段，未知/矛盾/缺证明的到账状态不能成功', () async {
    final i = TopupPaymentIntent.fromJson(
      fixture()['intent'] as Map<String, dynamic>,
    );
    final api = TopupApi(
      httpClient: MockClient(
        (_) async =>
            http.Response('{"ok":false,"error":"topup_payment_conflict"}', 409),
      ),
    );
    await expectLater(
      api.status(i),
      throwsA(
        isA<TopupApiException>().having(
          (e) => e.errorCode,
          'error',
          'topup_payment_conflict',
        ),
      ),
    );
    api.close();
    for (final j in [
      {'ok': true, 'status': 'paid', 'phase': 'broadcast'},
      {'ok': true, 'status': 'other', 'phase': 'paid'},
      {
        'ok': true,
        'status': 'paid',
        'phase': 'paid',
        'order_id': i.order,
        'coin_fen': i.coinFen,
      },
    ]) {
      expect(() => TopupOrder.fromJson(j), throwsFormatException);
    }
  });
}
