import 'package:citizen_testing/fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citizen_transaction/topup/topup_models.dart';
import 'package:citizen_transaction/topup/topup_api.dart';
import 'package:citizen_transaction/topup/topup_webview_page.dart';
import 'package:citizen_transaction/topup/topup_erc20.dart';
import 'package:citizen_transaction/topup/tron.dart';
import 'package:citizen_transaction/topup/solana.dart';
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_system/app_log.dart';

TopupPayment payment(TopupNetwork network, {String? token}) =>
    TopupPayment.signed(
      TopupDraft.create(
        TopupSelection(
          token:
              token ??
              (network == TopupNetwork.base || network == TopupNetwork.solana
                  ? 'USDC'
                  : 'USDT'),
          package: TopupConfig.local().packages.first,
          network: network,
        ),
        '0x${'04' * 32}',
      ),
      '0x${'01' * 64}',
      now: 1000000,
    );
Map<String, dynamic> evmFacts(
  TopupPayment p,
  String payer,
  String tx, {
  String amount = '10000000',
  bool finalized = true,
}) {
  final hash = '0x${'07' * 32}';
  return {
    'transaction': {
      'hash': tx,
      'from': payer,
      'to': p.asset,
      'value': '0x0',
      'input': encodeErc20Transfer(
        p.recvAddress,
        BigInt.parse(amount),
        '0b' * 32,
      ),
      'blockHash': hash,
      'blockNumber': '0xa',
      'transactionIndex': '0x0',
    },
    'receipt': {
      'transactionHash': tx,
      'status': '0x1',
      'blockNumber': '0xa',
      'blockHash': hash,
      'transactionIndex': '0x0',
      'logs': [
        {
          'address': p.asset,
          'removed': false,
          'topics': [
            '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
            '0x${payer.substring(2).padLeft(64, '0')}',
            '0x${p.recvAddress.substring(2).padLeft(64, '0')}',
          ],
          'data':
              '0x${BigInt.parse(amount).toRadixString(16).padLeft(64, '0')}',
          'transactionHash': tx,
          'blockHash': hash,
          'blockNumber': '0xa',
          'transactionIndex': '0x0',
          'logIndex': '0x0',
        },
      ],
    },
    'block': {
      'hash': hash,
      'number': '0xa',
      'timestamp': '0x3e8',
      'transactions': [tx],
    },
    'head': {'hash': hash, 'number': finalized ? '0xb' : '0x9'},
  };
}

void main() {
  _connectionDiagnosticsTests();
  _documentTests();
  _protocolTests();
  test('失败日志仅保留新流程固定阶段，旧意图/授权及异常正文零输出', () {
    final lines = <String>[];
    runZoned(
      () {
        expect(AppLog.topupFailure('create_order', 'other'), true);
        expect(AppLog.topupFailure('submitted', 'request_timeout'), true);
        for (final step in ['intent', 'authorization', 'synthetic-private']) {
          expect(AppLog.topupFailure(step, 'other'), false);
        }
        expect(AppLog.topupFailure('submitted', 'synthetic-private'), false);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.length, 2);
    expect(lines.join(), isNot(contains('synthetic-private')));
  });
  test('配置指纹逐字匹配服务端公开21行规范，JSON/显示顺序不影响结果', () {
    final fixture =
        jsonDecode(
              fixtureFile(
                'citizen_transaction',
                'topup/contract.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final value = TopupConfig.fromJson(
      fixture['config'] as Map<String, dynamic>,
    );
    expect(value.hash, fixture['config_hash']);
    expect(value.fingerprint.split('\n').length, 22);
    expect(value.fingerprint.endsWith('\n'), true);
    final reordered = TopupConfig(
      ready: false,
      rails: value.rails.reversed.toList(),
      packages: value.packages.reversed.toList(),
    );
    expect(reordered.hash, value.hash);
  });
  test('本地六币轨与两套餐完整，任意金额或收款更换均拒绝', () {
    final catalog = TopupConfig.local();
    expect(catalog.rails.length, 6);
    expect(catalog.packages.length, 2);
    for (final rail in catalog.rails) {
      for (final pack in catalog.packages) {
        final p = TopupPayment.signed(
          TopupDraft.create(
            TopupSelection(
              token: rail.token,
              package: pack,
              network: rail.network,
            ),
            '0x${'04' * 32}',
          ),
          '0x${'01' * 64}',
          now: 1000000,
        );
        p.validateCatalog(catalog);
        expect(TopupPayment.fromJson(p.toJson()).toJson(), p.toJson());
        for (final field in ['pay_amount', 'coin_fen']) {
          final j = Map<String, dynamic>.from(p.toJson())..[field] = '1';
          expect(
            () => TopupPayment.fromJson(j).validateCatalog(catalog),
            throwsFormatException,
          );
        }
      }
    }
  });
  test('签后身份由摘要派生，无服务端意图，钱包必须在闭集', () {
    final p = payment(TopupNetwork.base), q = payment(TopupNetwork.base);
    expect(p.orderId, isNot(q.orderId));
    final record = TopupRecord.signed(
      TopupDraft.create(
        TopupSelection.fromPayment(p, TopupConfig.local()),
        p.accountId,
      ),
      TopupWallets.ids.first,
      '0x${'01' * 64}',
      now: 1000000,
    );
    expect(record.progress, TopupProgress.pending);
    expect(record.toJson().containsKey('intent'), false);
    expect(() => record.request(), throwsStateError);
    expect(
      () => TopupRecord.signed(
        TopupDraft.create(
          TopupSelection.fromPayment(p, TopupConfig.local()),
          p.accountId,
        ),
        'outside',
        '0x${'01' * 64}',
      ),
      throwsFormatException,
    );
  });
  for (final network in [
    TopupNetwork.ethereum,
    TopupNetwork.base,
    TopupNetwork.bnb,
  ]) {
    test('${network.wire}一轮成功准确6次RPC，不读取服务端或公民链', () async {
      final p = payment(network),
          payer = '0x${'01' * 20}',
          tx = '0x${'02' * 32}',
          facts = evmFacts(
            payment(network),
            '0x${'01' * 20}',
            '0x${'02' * 32}',
            amount: network == TopupNetwork.bnb
                ? '10000000000000000000'
                : '10000000',
          ),
          calls = <String>[];
      final proof = await verifyErc20Payment(
        p,
        payer,
        tx,
        (method, params) async {
          calls.add(method);
          return switch (method) {
            'eth_chainId' => '0x${network.evmId!.toRadixString(16)}',
            'eth_getTransactionReceipt' => facts['receipt'],
            'eth_getTransactionByHash' => facts['transaction'],
            _ => params.first == 'finalized' ? facts['head'] : facts['block'],
          };
        },
        now: 1000000,
        binding: '0b' * 32,
      );
      expect(proof.matches(p, payer, tx), true);
      expect(calls, [
        'eth_chainId',
        'eth_getTransactionReceipt',
        'eth_getTransactionByHash',
        'eth_getBlockByNumber',
        'eth_getBlockByNumber',
        'eth_getBlockByNumber',
      ]);
    });
  }
  for (final kind in [
    'pending',
    'failed',
    'amount',
    'receiver',
    'payer',
    'asset',
    'removed',
    'duplicate',
    'membership',
    'reorg',
    'time',
    'network',
    'binding',
    'caller',
    'call_to',
    'native_value',
  ]) {
    test('EVM拒绝$kind，不补查不重试', () async {
      final p = payment(TopupNetwork.base),
          payer = '0x${'01' * 20}',
          tx = '0x${'02' * 32}',
          facts = evmFacts(
            payment(TopupNetwork.base),
            '0x${'01' * 20}',
            '0x${'02' * 32}',
          );
      final receipt = facts['receipt'] as Map<String, dynamic>,
          block = facts['block'] as Map<String, dynamic>,
          log = (receipt['logs'] as List).first as Map<String, dynamic>;
      switch (kind) {
        case 'failed':
          receipt['status'] = '0x0';
        case 'amount':
          log['data'] =
              '0x${BigInt.from(10000001).toRadixString(16).padLeft(64, '0')}';
        case 'receiver':
          (log['topics'] as List)[2] = '0x${'0' * 64}';
        case 'payer':
          (log['topics'] as List)[1] = '0x${'0' * 64}';
        case 'asset':
          log['address'] = '0x${'03' * 20}';
        case 'removed':
          log['removed'] = true;
        case 'duplicate':
          (receipt['logs'] as List).add(log);
        case 'membership':
          block['transactions'] = [];
        case 'time':
          block['timestamp'] = '0x3e7';
      }
      final actual = facts['transaction'] as Map<String, dynamic>;
      if (kind == 'binding') {
        actual['input'] = encodeErc20Transfer(
          p.recvAddress,
          BigInt.parse(p.payAmount),
          '0c' * 32,
        );
      }
      if (kind == 'caller') actual['from'] = '0x${'06' * 20}';
      if (kind == 'call_to') actual['to'] = '0x${'07' * 20}';
      if (kind == 'native_value') actual['value'] = '0x1';
      var count = 0;
      await expectLater(
        verifyErc20Payment(
          p,
          payer,
          tx,
          (method, params) async {
            count++;
            if (method == 'eth_chainId') {
              return kind == 'network' ? '0x1' : '0x2105';
            }
            if (method == 'eth_getTransactionReceipt') {
              return kind == 'pending' ? null : receipt;
            }
            if (method == 'eth_getTransactionByHash') return actual;
            if (params.first == 'finalized') return facts['head'];
            if (kind == 'reorg' && count == 6) {
              return {...block, 'hash': '0x${'08' * 32}'};
            }
            return block;
          },
          now: 1000000,
          binding: '0b' * 32,
        ),
        throwsFormatException,
      );
      expect(count, lessThanOrEqualTo(6));
    });
  }
  test('付款回跳及网页paid布尔值不能构造已支付证据', () {
    final p = payment(TopupNetwork.base);
    final record = TopupRecord(
      payment: p,
      walletId: TopupWallets.ids.first,
      accountSignature: '0x${'01' * 64}',
      recoveryToken: randomTopupHex(32),
      progress: TopupProgress.paid,
      payer: '0x${'01' * 20}',
      txid: '0x${'02' * 32}',
    );
    expect(() => TopupRecord.decode(record.encode()), throwsFormatException);
  });
  test('HTTP付款节点失败只一次，任意方法/非HTTPS服务地址在出站前拒绝', () async {
    var requests = 0;
    final api = TopupApi(
      httpClient: MockClient((r) async {
        requests++;
        expect(r.url.host, 'mainnet.base.org');
        return http.Response('{}', 503);
      }),
    );
    await expectLater(
      api.paymentRpc(TopupNetwork.base, 'eth_getTransactionReceipt', [
        '0x${'02' * 32}',
      ]),
      throwsA(isA<TopupApiException>()),
    );
    expect(requests, 1);
    await expectLater(
      api.paymentRpc(TopupNetwork.base, 'author_submitExtrinsic', []),
      throwsFormatException,
    );
    expect(requests, 1);
    api.close();
    expect(
      () => TopupApi(baseUrl: 'http://example.test/api'),
      throwsFormatException,
    );
  });
  test('原生验款只接受已提交原付款，取消/创建/失败阶段零HTTP', () async {
    var requests = 0;
    final api = TopupApi(
      httpClient: MockClient((r) async {
        requests++;
        throw StateError('unexpected');
      }),
    );
    final p = payment(TopupNetwork.base);
    for (final reason in [null, 'payment_cancelled', 'payment_failed']) {
      await expectLater(
        api.verifyPayment(
          TopupRecord(
            payment: p,
            walletId: TopupWallets.ids.first,
            accountSignature: '0x${'01' * 64}',
            recoveryToken: randomTopupHex(32),
            failureCode: reason,
          ),
        ),
        throwsStateError,
      );
    }
    expect(requests, 0);
    api.close();
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
        for (final phase in [
          'account',
          'create_order',
          'transaction',
          'submitting',
          'submitted',
          'complete',
          'failure',
        ]) {
          expect(
            AppLog.topupConnectTrace({
              ...value,
              'event': phase,
              'error': 'request_timeout',
            }),
            true,
          );
        }
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
    expect(lines.length, 9);
    expect(
      lines.first,
      contains('winner=provider_rejected error=socket_stalled'),
    );
    expect(lines[1], contains('error=origin_denied code=3000'));
    expect(lines.last, contains('event=failure'));
    expect(lines.last, contains('error=request_timeout'));
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

/// 只用合成标记和脚本；不保存或打印运行时文档nonce、URI或钱包资料。
void _documentTests() {
  const nonce = 'syntheticDocumentNonce0001';
  String template() =>
      File('transaction/web/walletconnect.html').readAsStringSync();
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
    final script = File(
      'transaction/web/walletconnect.bundle.js',
    ).readAsBytesSync();
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

// 固定公开结构的合成节点回执，不连接网络，不使用环境钱包。
void _protocolTests() {
  for (final mode in ['success', 'pending', 'failed', 'amount', 'reorg']) {
    test('Tron固化验款$mode，一轮最多5次RPC', () async {
      final p = payment(TopupNetwork.tron),
          payer = 'TA9pkx4DFxrEw8JZzUtyDrh2uAat1LDuJL',
          tx = '02' * 32;
      String address(String a) => base58Bytes(
        a,
      ).take(21).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      final transaction = {
        'txID': tx,
        'ret': [
          {'contractRet': 'SUCCESS'},
        ],
        'raw_data': {
          'data': utf8
              .encode('topup:${'0b' * 32}')
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
          'contract': [
            {
              'type': 'TriggerSmartContract',
              'parameter': {
                'type_url': 'type.googleapis.com/protocol.TriggerSmartContract',
                'value': {
                  'owner_address': address(payer),
                  'contract_address': address(p.asset),
                },
              },
            },
          ],
        },
      };
      final receipt = {
        'id': tx,
        'receipt': {'result': mode == 'failed' ? 'FAILED' : 'SUCCESS'},
        'blockNumber': 10,
        'blockTimeStamp': 1000000,
        'log': [
          {
            'address': address(p.asset).substring(2),
            'topics': [
              'ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
              address(payer).substring(2).padLeft(64, '0'),
              address(p.recvAddress).substring(2).padLeft(64, '0'),
            ],
            'data': BigInt.parse(
              mode == 'amount' ? '10000001' : p.payAmount,
            ).toRadixString(16).padLeft(64, '0'),
          },
        ],
      };
      final block = {
        'blockID': '03' * 32,
        'block_header': {
          'raw_data': {'number': 10, 'timestamp': 1000000},
        },
        'transactions': [transaction],
      };
      var count = 0;
      final operation = verifyTronPayment(
        p,
        payer,
        tx,
        (method, params) async {
          count++;
          if (method.endsWith('gettransactionbyid')) {
            return mode == 'pending' ? <String, dynamic>{} : transaction;
          }
          if (method.endsWith('gettransactioninfobyid')) return receipt;
          if ((params.single as Map)['num'] == 0) {
            return {
              'blockID':
                  '00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc',
            };
          }
          if (mode == 'reorg' && count == 5) {
            return {...block, 'blockID': '04' * 32};
          }
          return block;
        },
        now: 1000000,
        binding: '0b' * 32,
      );
      if (mode == 'success') {
        expect((await operation).matches(p, payer, tx), true);
        expect(count, 5);
      } else {
        await expectLater(operation, throwsFormatException);
        expect(count, lessThanOrEqualTo(5));
      }
    });
  }
  for (final mode in [
    'success',
    'pending',
    'failed',
    'amount',
    'membership',
    'owner',
  ]) {
    test('Solana最终验款$mode，一轮最多3次RPC', () async {
      final p = payment(TopupNetwork.solana),
          payer = '11111111111111111111111111111111',
          tx = '1' * 64;
      const program = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
      final balances = [
        {
          'accountIndex': 1,
          'mint': p.asset,
          'owner': payer,
          'programId': program,
          'uiTokenAmount': {'decimals': 6},
        },
        {
          'accountIndex': 2,
          'mint': p.asset,
          'owner': mode == 'owner' ? payer : p.recvAddress,
          'programId': program,
          'uiTokenAmount': {'decimals': 6},
        },
      ];
      final transaction = {
        'version': 'legacy',
        'slot': 10,
        'blockTime': 1000,
        'transaction': {
          'signatures': [tx],
          'message': {
            'accountKeys': [
              {'pubkey': payer, 'signer': true},
              {'pubkey': p.asset},
              {'pubkey': p.recvAddress},
            ],
            'instructions': [
              {
                'programId': 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr',
                'parsed': 'topup:${'0b' * 32}',
              },
              {
                'programId': program,
                'parsed': {
                  'type': 'transferChecked',
                  'info': {
                    'authority': payer,
                    'source': p.asset,
                    'destination': p.recvAddress,
                    'mint': p.asset,
                    'tokenAmount': {
                      'amount': mode == 'amount' ? '10000001' : p.payAmount,
                      'decimals': 6,
                    },
                  },
                },
              },
            ],
          },
        },
        'meta': {
          'err': mode == 'failed'
              ? {
                  'InstructionError': [
                    1,
                    {'Custom': 1},
                  ],
                }
              : null,
          'preTokenBalances': balances,
          'postTokenBalances': balances,
          'innerInstructions': [],
        },
      };
      var count = 0;
      final operation = verifySolanaPayment(
        p,
        payer,
        tx,
        (method, params) async {
          count++;
          return switch (method) {
            'getGenesisHash' => '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
            'getTransaction' => mode == 'pending' ? null : transaction,
            _ => {
              'blockTime': 1000,
              'blockhash': '11111111111111111111111111111111',
              'signatures': mode == 'membership' ? [] : [tx],
            },
          };
        },
        now: 1000000,
        binding: '0b' * 32,
      );
      if (mode == 'success') {
        expect((await operation).matches(p, payer, tx), true);
        expect(count, 3);
      } else {
        await expectLater(operation, throwsFormatException);
        expect(count, lessThanOrEqualTo(3));
      }
    });
  }
}
