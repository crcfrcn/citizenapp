import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizenapp/transaction/topup/topup_models.dart';
import 'package:citizenapp/transaction/topup/topup_api.dart';
import 'package:citizenapp/transaction/topup/topup_webview_page.dart';
import 'package:citizenapp/transaction/topup/topup_erc20.dart';
import 'package:citizenapp/transaction/topup/wallet_link_dispatcher.dart';
import 'package:citizenapp/app_log.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/transaction/topup/contract.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  _configDiagnosticsTests();
  _connectionDiagnosticsTests();
  _documentTests();
  TopupPaymentIntent solanaIntent() {
    final value = fixture()['native']['solana'] as Map<String, dynamic>;
    return TopupPaymentIntent.fromJson({
      'ok': true,
      'order_id':
          'top_${(value['intent']['intent_id'] as String).substring(4)}',
      'payment_intent': value['token'],
      'intent': value['intent'],
      'wallet_authorization_message': value['message'],
    });
  }

  test('五条主网只有固定公开入口，不读取节点Key或环境地址', () {
    expect(TopupNetwork.values.map(TopupRpcConfig.endpoint).toList(), [
      'https://ethereum-rpc.publicnode.com',
      'https://mainnet.base.org',
      'https://bsc-dataseed.bnbchain.org',
      'https://tron-rpc.publicnode.com',
      'https://api.mainnet.solana.com',
    ]);
    for (final network in TopupNetwork.values) {
      final url = Uri.parse(TopupRpcConfig.endpoint(network));
      expect(url.scheme, 'https');
      expect(url.path, '');
      expect(url.hasQuery, false);
      expect(url.userInfo, '');
    }
  });
  test('Solana只向固定官方入口发出必要请求，匿名且禁止重定向', () async {
    final intent = solanaIntent(), methods = <String>[];
    final api = TopupApi(
      httpClient: MockClient((request) async {
        expect(request.url.toString(), TopupRpcConfig.solana);
        expect(request.followRedirects, false);
        expect(
          request.headers.keys.where(
            (key) => key.toLowerCase() != 'content-type',
          ),
          isEmpty,
        );
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        methods.add(input['method'] as String);
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'result': input['method'] == 'getGenesisHash'
                ? 'mainnet'
                : {
                    'value': {
                      'blockhash': 'block',
                      'lastValidBlockHeight': 100,
                    },
                  },
          }),
          200,
        );
      }),
    );
    expect(
      await api.solanaRpc(
        intent: intent,
        method: 'getGenesisHash',
        params: [],
        now: intent.expiresAt - 1,
      ),
      'mainnet',
    );
    await api.solanaRpc(
      intent: intent,
      method: 'getLatestBlockhash',
      params: [
        {'commitment': 'finalized'},
      ],
      now: intent.expiresAt - 1,
    );
    expect(methods, ['getGenesisHash', 'getLatestBlockhash']);
    api.close();
  });
  test('Solana错链、过期、任意方法和未冻结广播在HTTP前拒绝', () async {
    var calls = 0;
    final api = TopupApi(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final intent = solanaIntent();
    for (final request in [
      ('requestAirdrop', <Object?>[]),
      ('https://other.example.test', <Object?>[]),
      ('getGenesisHash', <Object?>[1]),
      (
        'getLatestBlockhash',
        <Object?>[
          {'commitment': 'processed'},
        ],
      ),
      (
        'sendTransaction',
        <Object?>[
          'unsigned',
          {'skipPreflight': true},
        ],
      ),
    ]) {
      await expectLater(
        api.solanaRpc(
          intent: intent,
          method: request.$1,
          params: request.$2,
          now: intent.expiresAt - 1,
        ),
        throwsFormatException,
      );
    }
    await expectLater(
      api.solanaRpc(
        intent: intent,
        method: 'getGenesisHash',
        params: [],
        now: intent.expiresAt,
      ),
      throwsFormatException,
    );
    final evm = TopupPaymentIntent.fromJson(
      fixture()['intent'] as Map<String, dynamic>,
    );
    await expectLater(
      api.solanaRpc(
        intent: evm,
        method: 'getGenesisHash',
        params: [],
        now: evm.expiresAt - 1,
      ),
      throwsFormatException,
    );
    expect(calls, 0);
    api.close();
  });
  test('Solana仅广播原字节，未知响应不重试或声称未付款', () async {
    final intent = solanaIntent(),
        txid = fixture()['native']['solana']['txid'] as String;
    final wire = base64Encode(List<int>.filled(100, 1));
    final options = {
      'encoding': 'base64',
      'skipPreflight': false,
      'preflightCommitment': 'confirmed',
      'maxRetries': 3,
    };
    for (final mode in [
      'ok',
      '429',
      'redirect',
      'bad-json',
      'wrong-id',
      'wrong-tx',
      'rpc-error',
    ]) {
      var calls = 0;
      final api = TopupApi(
        httpClient: MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['params'], [wire, options]);
          if (mode == '429') return http.Response('{}', 429);
          if (mode == 'redirect') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://other.example.test'},
            );
          }
          if (mode == 'bad-json') return http.Response('bad', 200);
          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': mode == 'wrong-id' ? 2 : 1,
              if (mode == 'rpc-error') 'error': {'code': -1},
              'result': mode == 'wrong-tx' ? 'different' : txid,
            }),
            200,
          );
        }),
      );
      final future = api.solanaRpc(
        intent: intent,
        method: 'sendTransaction',
        params: [wire, options],
        wire: wire,
        txid: txid,
        now: intent.expiresAt - 1,
      );
      if (mode == 'ok') {
        expect(await future, txid);
      } else {
        await expectLater(
          future,
          throwsA(
            isA<TopupApiException>().having(
              (e) => e.message,
              '未知结果',
              contains('待核实'),
            ),
          ),
        );
      }
      expect(calls, 1);
      api.close();
    }
    var calls = 0;
    final api = TopupApi(
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.solanaRpc(
        intent: intent,
        method: 'sendTransaction',
        params: [wire, options],
        wire: base64Encode(List<int>.filled(100, 2)),
        txid: txid,
        now: intent.expiresAt - 1,
      ),
      throwsFormatException,
    );
    expect(calls, 0);
    api.close();
  });
  test('Solana请求返回时付款已取消，不交付迟到结果', () async {
    final intent = solanaIntent();
    var active = true, calls = 0;
    final api = TopupApi(
      httpClient: MockClient((_) async {
        calls++;
        active = false;
        return http.Response(
          '{"jsonrpc":"2.0","id":1,"result":"mainnet"}',
          200,
        );
      }),
    );
    await expectLater(
      api.solanaRpc(
        intent: intent,
        method: 'getGenesisHash',
        params: [],
        now: intent.expiresAt - 1,
        isActive: () => active,
      ),
      throwsA(
        isA<TopupApiException>().having((e) => e.message, '取消', contains('取消')),
      ),
    );
    expect(calls, 1);
    api.close();
  });
  test('ready必须明确为布尔值，不接受旧响应或默认开放', () {
    for (final value in [null, 'true', 1]) {
      final j = fixture()['config'] as Map<String, dynamic>;
      j['ready'] = value;
      expect(() => TopupConfig.fromJson(j), throwsFormatException);
    }
    final j = fixture()['config'] as Map<String, dynamic>;
    j['ready'] = false;
    expect(TopupConfig.fromJson(j).ready, false);
  });
  test('组合选择绑定准确网络、套餐和整数金额，不能静默换链或价格', () {
    final c = TopupConfig.fromJson(fixture()['config'] as Map<String, dynamic>);
    for (final token in ['USDC', 'USDT']) {
      for (final network in TopupNetwork.values) {
        if (!allowedPair(token, network)) {
          expect(
            () => TopupSelection(
              token: token,
              package: c.packages.first,
              network: network,
            ),
            throwsFormatException,
          );
          continue;
        }
        final selection = TopupSelection(
          token: token,
          package: c.packages.last,
          network: network,
        );
        selection.validate(c, TopupContext(network, 'payer'));
        expect(selection.toJson(), {
          'token': token,
          'package_id': 'pkg_1400',
          'network': network.wire,
        });
        expect(
          () => selection.validate(
            c,
            TopupContext(
              network == TopupNetwork.base
                  ? TopupNetwork.ethereum
                  : TopupNetwork.base,
              'payer',
            ),
          ),
          throwsFormatException,
        );
      }
    }
  });
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
        if (!allowedPair(t, n)) {
          expect(() => c.rail(t, n), throwsFormatException);
        }
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
        if (r.url.path.endsWith('/config')) {
          return http.Response(jsonEncode(f['config']), 200);
        }
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
  test('新付款重新取配置，未就绪、所选错链及关闭页面均不能创建意图', () async {
    final f = fixture(),
        c = TopupConfig.fromJson(f['config'] as Map<String, dynamic>),
        i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    final choice = TopupSelection(
      token: 'USDC',
      package: c.packages.first,
      network: TopupNetwork.base,
    );
    for (final mode in ['unready', 'wrong-network', 'closed']) {
      var active = true, created = 0, calls = 0;
      final api = TopupApi(
        httpClient: MockClient((request) async {
          calls++;
          if (request.url.path.endsWith('/intent')) {
            created++;
            return http.Response(jsonEncode(f['intent']), 200);
          }
          final config = Map<String, dynamic>.from(f['config'] as Map);
          if (mode == 'unready') config['ready'] = false;
          if (mode == 'closed') active = false;
          return http.Response(jsonEncode(config), 200);
        }),
      );
      await expectLater(
        api.preparePayment(
          selection: choice,
          accountId: i.accountId,
          payer: TopupContext(
            mode == 'wrong-network' ? TopupNetwork.ethereum : TopupNetwork.base,
            i.payer,
          ),
          chainGenesisHash: '0x${'00' * 32}',
          now: 1005000,
          isActive: () => active,
        ),
        throwsA(anyOf(isA<TopupApiException>(), isA<FormatException>())),
      );
      expect(created, 0);
      if (mode == 'wrong-network') expect(calls, 0);
      api.close();
    }
  });
  test('恢复先向服务端核验原凭据，地址更换只影响新订单且不重建原意图', () async {
    final f = fixture(),
        c = TopupConfig.fromJson(f['config'] as Map<String, dynamic>),
        i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    final choice = TopupSelection.fromIntent(i, c);
    for (final accepted in [true, false]) {
      final paths = <String>[];
      final api = TopupApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/config')) {
            final config =
                jsonDecode(jsonEncode(f['config'])) as Map<String, dynamic>;
            for (final r in config['rails'] as List) {
              if (TopupNetwork.parse(r['network']).evmId != null) {
                r['recv_address'] = '0x${'77' * 20}';
              }
            }
            return http.Response(jsonEncode(config), 200);
          }
          expect(request.url.path.endsWith('/status'), true);
          expect((jsonDecode(request.body) as Map)['payment_intent'], i.token);
          if (!accepted) {
            return http.Response(
              '{"ok":false,"error":"topup_order_not_found"}',
              404,
            );
          }
          return http.Response(
            jsonEncode({
              'ok': true,
              'order_id': i.order,
              'status': 'pending',
              'phase': 'awaiting',
              'coin_fen': i.coinFen,
              'payment_txid': null,
              'gmb_tx_hash': null,
              'reason': null,
            }),
            200,
          );
        }),
      );
      final result = api.preparePayment(
        selection: choice,
        accountId: i.accountId,
        payer: TopupContext(i.network, i.payer),
        chainGenesisHash: '0x${'00' * 32}',
        original: i,
        now: 1005000,
      );
      if (accepted) {
        final prepared = await result;
        expect(prepared.rail.recvAddress, i.intent['recv_address']);
        expect(prepared.intent.token, i.token);
      } else {
        await expectLater(result, throwsA(isA<TopupApiException>()));
      }
      expect(paths, ['/api/topup/config', '/api/topup/status']);
      api.close();
    }
  });
  test('已有付款定位或服务端已进入核验阶段时，不再恢复成一笔新付款', () async {
    final f = fixture(),
        c = TopupConfig.fromJson(f['config'] as Map<String, dynamic>),
        i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    final api = TopupApi(
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/config')
                ? f['config']
                : {
                    'ok': true,
                    'order_id': i.order,
                    'status': 'pending',
                    'phase': 'verifying',
                    'coin_fen': i.coinFen,
                    'payment_txid': '0x${'09' * 32}',
                    'gmb_tx_hash': null,
                    'reason': null,
                  },
          ),
          200,
        ),
      ),
    );
    await expectLater(
      api.preparePayment(
        selection: TopupSelection.fromIntent(i, c),
        accountId: i.accountId,
        payer: TopupContext(i.network, i.payer),
        chainGenesisHash: '0x${'00' * 32}',
        original: i,
        now: 1005000,
      ),
      throwsA(isA<TopupApiException>()),
    );
    api.close();
  });
  test('网络尚未开放的服务端错误保留准确代码并显示未发起付款', () async {
    final f = fixture(),
        i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    final api = TopupApi(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"ok":false,"error":"topup_network_unconfigured"}',
          503,
        ),
      ),
    );
    await expectLater(
      api.createIntent(
        token: 'USDC',
        packageId: 'pkg_15',
        accountId: i.accountId,
        payer: TopupContext(i.network, i.payer),
      ),
      throwsA(
        isA<TopupApiException>()
            .having((e) => e.message, 'message', '所选网络尚未开放，未发起付款')
            .having((e) => e.errorCode, 'code', 'topup_network_unconfigured'),
      ),
    );
    await expectLater(
      api.status(i),
      throwsA(
        isA<TopupApiException>().having(
          (e) => e.message,
          'message',
          '暂时无法核实原订单，请稍后重试，勿重复付款',
        ),
      ),
    );
    await expectLater(
      api.confirm(
        intent: i,
        paymentTxid: '0x${'09' * 32}',
        payerSignature: f['signature'] as String,
      ),
      throwsA(
        isA<TopupApiException>().having(
          (e) => e.message,
          'message',
          '暂时无法核实原订单，请稍后重试，勿重复付款',
        ),
      ),
    );
    api.close();
  });
  test('新付款按所选元组取得新报价，错误网络的服务端报价在签名前拒绝', () async {
    final f = fixture(),
        c = TopupConfig.fromJson(f['config'] as Map<String, dynamic>),
        i = TopupPaymentIntent.fromJson(f['intent'] as Map<String, dynamic>);
    for (final network in [TopupNetwork.base, TopupNetwork.ethereum]) {
      final paths = <String>[];
      final api = TopupApi(
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/config')) {
            return http.Response(jsonEncode(f['config']), 200);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'USDC');
          expect(body['package_id'], 'pkg_15');
          expect(body['network'], network.wire);
          expect(body['account_id'], i.accountId);
          return http.Response(jsonEncode(f['intent']), 200);
        }),
      );
      final future = api.preparePayment(
        selection: TopupSelection(
          token: 'USDC',
          package: c.packages.first,
          network: network,
        ),
        accountId: i.accountId,
        payer: TopupContext(network, i.payer),
        chainGenesisHash: '0x${'00' * 32}',
        now: 1005000,
      );
      if (network == TopupNetwork.base) {
        final payment = await future;
        expect(payment.intent.token, i.token);
        expect(payment.rail.network, network);
      } else {
        await expectLater(future, throwsFormatException);
      }
      expect(paths, ['/api/topup/config', '/api/topup/intent']);
      api.close();
    }
  });
  test('原字节续播只接受服务端仍等待同一交易的阶段，过期和终态拒绝', () async {
    final f = fixture(),
        c = TopupConfig.fromJson(f['config'] as Map<String, dynamic>),
        n = f['native']['tron'] as Map<String, dynamic>;
    final i = TopupPaymentIntent.fromJson({
      'ok': true,
      'order_id': 'top_${(n['intent']['intent_id'] as String).substring(4)}',
      'payment_intent': n['token'],
      'wallet_authorization_message': n['message'],
      'intent': n['intent'],
    });
    final choice = TopupSelection.fromIntent(i, c), tx = n['txid'] as String;
    for (final phase in [
      'awaiting',
      'verifying',
      'received',
      'paid',
      'exception',
      'expired',
    ]) {
      final state = phase == 'expired' ? 'verifying' : phase;
      final api = TopupApi(
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/config')
                  ? f['config']
                  : {
                      'ok': true,
                      'order_id': i.order,
                      'status': state == 'paid'
                          ? 'paid'
                          : state == 'exception'
                          ? 'exception'
                          : 'pending',
                      'phase': state,
                      'coin_fen': i.coinFen,
                      'payment_txid': state == 'awaiting' ? null : tx,
                      'gmb_tx_hash': state == 'paid' ? '0x${'09' * 32}' : null,
                      'reason': null,
                    },
            ),
            200,
          ),
        ),
      );
      final result = api.authorizeReplay(
        intent: i,
        txid: tx,
        selection: choice,
        accountId: i.accountId,
        now: phase == 'expired' ? i.expiresAt : 1005000,
      );
      if (phase == 'awaiting' || phase == 'verifying') {
        await result;
      } else {
        await expectLater(result, throwsA(isA<TopupApiException>()));
      }
      api.close();
    }
  });
}

void _connectionDiagnosticsTests() {
  test('连接原因只接受完整闭集，URI/异常原文/未知码和计数越界均拒绝', () {
    final lines = <String>[];
    final value = <String, Object>{
      'stage': 'trace',
      'event': 'provider_rejected',
      'winner': 'provider_rejected',
      'error': 'socket_stalled',
      'code': 'none',
      'pairing': true,
      'subscribed': false,
      'published': false,
      'relay_connected': false,
      'relay_connecting': false,
      'complete': true,
      'attempts': 5,
      'stalls': 5,
    };
    runZoned(
      () {
        expect(AppLog.topupConnectTrace(value), true);
        expect(
          AppLog.topupConnectTrace({
            ...value,
            'event': 'socket_close',
            'error': 'origin_denied',
            'code': '3000',
          }),
          true,
        );
        for (final invalid in [
          {...value, 'uri': 'synthetic-private'},
          {...value, 'error': 'synthetic-private'},
          {...value, 'code': '987654'},
          {...value, 'attempts': 21},
          {...value, 'pairing': 'synthetic-private'},
        ]) {
          expect(AppLog.topupConnectTrace(invalid), false);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.length, 2);
    expect(
      lines.first,
      contains('winner=provider_rejected error=socket_stalled'),
    );
    expect(lines.last, contains('error=origin_denied code=3000'));
    expect(lines.join(), isNot(contains('synthetic-private')));
  });
  Map<String, Object> observation(String stage) => {
    'stage': stage,
    'listening': true,
    'connecting': true,
    'emitted': false,
    'provider_uri': false,
    'modal_uri': false,
    'matched': false,
    'baseline': false,
    'complete': true,
  };
  test('充值观察只输出固定阶段与布尔值，拒绝额外字段和非布尔输入', () {
    final lines = <String>[];
    runZoned(
      () {
        for (final stage in ['start', 'connect', 'uri', 'modal', 'end']) {
          expect(AppLog.topupConnection(observation(stage)), true);
        }
        for (final value in [
          null,
          'synthetic-private-value',
          observation('synthetic-private-value'),
          {...observation('end'), 'uri': 'synthetic-private-value'},
          {...observation('end'), 'emitted': 'synthetic-private-value'},
          {...observation('end')}..remove('complete'),
        ]) {
          expect(AppLog.topupConnection(value), false);
        }
        for (final state in ['requested', 'busy', 'opened', 'rejected']) {
          AppLog.topupWallet(state);
        }
        AppLog.topupWallet('synthetic-private-value');
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.length, 10);
    expect(
      lines.first,
      '[CitizenTopup] stage=start listening=1 connecting=1 emitted=0 provider_uri=0 modal_uri=0 matched=0 baseline=0 complete=1',
    );
    expect(lines.last, '[CitizenTopup] stage=native state=other');
    expect(lines.join(), isNot(contains('synthetic-private-value')));
  });
  test('充值观察出口失败不改变原流程，也不启用自由文本诊断', () {
    runZoned(
      () {
        expect(AppLog.topupConnection(observation('end')), true);
        AppLog.topupWallet('opened');
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, _) => throw StateError('synthetic outlet failure'),
      ),
    );
  });
}

void _configDiagnosticsTests() {
  const canary = 'synthetic-private-topup';
  for (final status in [401, 403, 404, 429, 503]) {
    for (final known in [true, false]) {
      test('充值配置HTTP$status/${known ? "已知" : "未知"}码安全分类且零付款请求', () async {
        final lines = <String>[];
        var calls = 0;
        final code = known ? 'topup_unconfigured' : '$canary\nforged';
        final api = TopupApi(
          baseUrl: 'https://worker.test/api',
          httpClient: MockClient((request) async {
            calls++;
            expect(request.method, 'GET');
            expect(request.url.path, '/api/topup/config');
            return http.Response(
              jsonEncode({'error': code, 'message': canary, 'amount': canary}),
              status,
            );
          }),
        );
        addTearDown(api.close);
        await runZoned(
          () async {
            await expectLater(
              api.fetchConfig(),
              throwsA(
                isA<TopupApiException>()
                    .having((e) => e.statusCode, 'HTTP', status)
                    .having((e) => e.errorCode, '原码不改写', code),
              ),
            );
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lines.add(line),
          ),
        );
        expect(calls, 1);
        expect(lines, [
          '[CitizenFailure] stage=topup_config http=$status code=${known ? 'topup_unconfigured' : 'other'}',
        ]);
        expect(lines.join(), isNot(contains(canary)));
      });
    }
  }
  for (final shape in ['json', 'shape', 'schema', 'network']) {
    test('充值配置$shape失败分类不读取异常正文或创建意图', () async {
      final lines = <String>[];
      var calls = 0;
      final api = TopupApi(
        httpClient: MockClient((request) async {
          calls++;
          expect(request.method, 'GET');
          if (shape == 'network') throw http.ClientException(canary);
          return http.Response(switch (shape) {
            'json' => '{$canary',
            'shape' => jsonEncode([canary]),
            _ => jsonEncode({'ready': canary}),
          }, 200);
        }),
      );
      addTearDown(api.close);
      await runZoned(
        () async {
          await expectLater(
            api.fetchConfig(),
            throwsA(
              anyOf(
                isA<TopupApiException>(),
                isA<FormatException>(),
                isA<http.ClientException>(),
              ),
            ),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      final code = shape == 'network'
          ? 'network_unavailable'
          : shape == 'schema'
          ? 'format'
          : 'response_invalid';
      expect(calls, 1);
      expect(lines, [
        '[CitizenFailure] stage=topup_config http=${shape == 'network' ? 'none' : '200'} code=$code',
      ]);
      expect(lines.join(), isNot(contains(canary)));
    });
  }
  test('正常未开放配置保留ready=false且不产生失败事件或付款', () async {
    final lines = <String>[];
    var calls = 0;
    final config = Map<String, dynamic>.from(fixture()['config'] as Map)
      ..['ready'] = false;
    final api = TopupApi(
      httpClient: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        return http.Response(jsonEncode(config), 200);
      }),
    );
    addTearDown(api.close);
    await runZoned(
      () async => expect((await api.fetchConfig()).ready, false),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(calls, 1);
    expect(lines, isEmpty);
  });
}

/// 只用合成标记和脚本；不保存或打印运行时文档nonce、URI或钱包资料。
void _documentTests() {
  const nonce = 'syntheticDocumentNonce0001';
  String template() =>
      File('assets/topup/walletconnect.html').readAsStringSync();
  TopupDocument document() =>
      TopupDocument(template(), utf8.encode('void 0;'), nonce);

  test('HTTPS文档仅嵌入原随包字节，脚本中的HTML结束符不会截断文档', () {
    final script = utf8.encode('/* </script><!-- 中文 */ void 0;');
    final doc = TopupDocument(template(), script, nonce);
    expect(TopupDocument.baseUrl, 'https://www.crcfrcn.com/');
    expect(doc.html, isNot(contains('{{TOPUP_')));
    expect(doc.html, contains("script-src 'nonce-$nonce'"));
    expect(doc.html, contains('data-topup-document="$nonce"'));
    final tag = RegExp(
      r'<script nonce="([^"]+)" src="data:application/javascript;base64,([^"]+)"></script>',
    ).firstMatch(doc.html)!;
    expect(tag.group(1), nonce);
    expect(base64Decode(tag.group(2)!), script);
    expect(doc.html, isNot(contains('<script src="walletconnect.bundle.js"')));
    expect(doc.html, isNot(contains('/* </script>')));
    expect(doc.check, contains('window.origin === "https://www.crcfrcn.com"'));
    expect(doc.check, contains('window === window.top'));
    expect(doc.check, contains('data-topup-document'));
    expect(doc.check, contains('CitizenTopup?.start'));
  });
  test('实际构建JS完整装入文档，不访问网站同名脚本', () {
    final script = File('assets/topup/walletconnect.bundle.js')
        .readAsBytesSync();
    final doc = TopupDocument(template(), script, nonce);
    // 数MB的真实bundle不使用无界捕获正则，避免测试引擎递归栈溢出。
    const prefix = 'src="data:application/javascript;base64,';
    final start = doc.html.indexOf(prefix);
    expect(start, greaterThanOrEqualTo(0));
    final from = start + prefix.length;
    final encoded = doc.html.substring(from, doc.html.indexOf('"', from));
    expect(base64Decode(encoded), script);
    expect(RegExp(r'<script\b').allMatches(doc.html).length, 2);
  });
  test('来源/文档证明缺失、导航中地址变化和外部地址均不能启动连接', () {
    for (final url in [
      'file:///assets/topup/walletconnect.html',
      'https://other.example/',
      'https://www.crcfrcn.com/remote',
      'https://www.crcfrcn.com/?q=1',
      'https://www.crcfrcn.com/#x',
      'https://www.crcfrcn.com:444/',
      'https://user@www.crcfrcn.com/',
    ]) {
      final doc = document();
      expect(doc.mayNavigate(url, mainFrame: true), false);
      expect(doc.begin(url, url, true), false);
      expect(doc.accepts(url, true), false);
    }
    for (final proof in [false, 'true', 1]) {
      final doc = document();
      expect(
        doc.begin(TopupDocument.baseUrl, TopupDocument.baseUrl, proof),
        false,
      );
      expect(doc.started, false);
    }
    final doc = document();
    expect(doc.begin(TopupDocument.baseUrl, 'about:blank', true), false);
    expect(doc.accepts(TopupDocument.baseUrl, true), false);
  });
  test('两端内存文档地址均须通过实际证明，仅启动一次，完成后禁止主框架导航', () {
    for (final url in [TopupDocument.baseUrl, 'about:blank']) {
      final doc = document();
      expect(doc.begin(url, url, true), true);
      expect(doc.started, true);
      expect(doc.begin(url, url, true), false);
      expect(doc.mayNavigate(url, mainFrame: true), false);
      expect(doc.mayNavigate('https://other.example/', mainFrame: true), false);
      expect(doc.accepts(url, true), true);
      expect(doc.accepts(url, false), false);
      expect(doc.accepts(url, 'true'), false);
      expect(doc.accepts('https://www.crcfrcn.com/remote', true), false);
      expect(doc.accepts(null, true), false);
    }
  });
  test('随包脚本就绪消息只接受本次nonce及精确字段，不以旧文档或字符串布尔启动', () {
    final doc = document();
    final ready = <String, dynamic>{
      'kind': 'document_ready',
      'nonce': nonce,
      'ready': true,
    };
    expect(doc.ownsReady(ready), true);
    expect(doc.ownsReady({...ready, 'ready': false}), true);
    expect(
      doc.ownsReady({...ready, 'nonce': 'syntheticPreviousNonce001'}),
      false,
    );
    expect(doc.ownsReady({...ready, 'ready': 'true'}), false);
    expect(doc.ownsReady({...ready, 'kind': 'connected'}), false);
    expect(doc.ownsReady({...ready, 'extra': true}), false);
  });
  test('不完整资产和不安全nonce在加载前失败', () {
    for (final bad in ['', 'short', 'syntheticNonce" injection']) {
      expect(() => TopupDocument(template(), [1], bad), throwsFormatException);
    }
    expect(() => TopupDocument(template(), [], nonce), throwsFormatException);
    expect(
      () => TopupDocument(template().replaceFirst('{{TOPUP_NONCE}}', ''), [
        1,
      ], nonce),
      throwsFormatException,
    );
    expect(
      () => TopupDocument(template().replaceFirst('{{TOPUP_SCRIPT}}', ''), [
        1,
      ], nonce),
      throwsFormatException,
    );
  });
}
