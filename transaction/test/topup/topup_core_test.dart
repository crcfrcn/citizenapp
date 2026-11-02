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
import 'package:citizen_transaction/topup/store.dart';
import 'package:citizen_transaction/topup/wallet_link_dispatcher.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_sdk/citizen_sdk.dart' show CitizenSdkErrorCode;

TopupPayment payment(TopupNetwork network, {String? token}) =>
    TopupPayment.signed(
      TopupDraft.create(
        TopupSelection(
          token: token ?? (network == TopupNetwork.base ? 'USDC' : 'USDT'),
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
  _documentTests();
  test('失败日志仅保留新流程固定阶段，旧意图/授权及异常正文零输出', () {
    final lines = <String>[];
    runZoned(
      () {
        expect(AppLog.topupFailure('create_order', 'other'), true);
        expect(AppLog.topupFailure('submitted', 'user_rejected'), true);
        expect(AppLog.topupFailure('submitted', 'payment_failed'), true);
        expect(
          AppLog.topupFailure('submitted', 'other', rpcCode: -32602),
          true,
        );
        expect(
          AppLog.topupFailure('submitted', 'other', detail: 'sdk_update_limit'),
          true,
        );
        expect(
          AppLog.topupFailure('submitted', 'other', rpcCode: 12345678),
          false,
        );
        expect(
          AppLog.topupFailure(
            'submitted',
            'other',
            detail: 'synthetic-private',
          ),
          false,
        );
        for (final step in ['intent', 'authorization', 'synthetic-private']) {
          expect(AppLog.topupFailure(step, 'other'), false);
        }
        expect(AppLog.topupFailure('submitted', 'synthetic-private'), false);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.length, 5);
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
  test('本地六条EVM币轨与两套餐完整，任意金额或收款更换均拒绝', () {
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
      TopupWallet.id,
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
            'eth_chainId' => '0x${network.evmId.toRadixString(16)}',
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
  test('六条币轨两套餐均可由真实付款交易确定付款人，仍准确6次RPC', () async {
    final catalog = TopupConfig.local();
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
        final payer = '0x${'01' * 20}',
            tx = '0x${'02' * 32}',
            facts = evmFacts(p, payer, tx, amount: p.payAmount);
        var calls = 0;
        final proof = await verifyErc20Payment(
          p,
          null,
          tx,
          (method, params) async {
            calls++;
            return switch (method) {
              'eth_chainId' => '0x${rail.network.evmId.toRadixString(16)}',
              'eth_getTransactionReceipt' => facts['receipt'],
              'eth_getTransactionByHash' => facts['transaction'],
              _ => params.first == 'finalized' ? facts['head'] : facts['block'],
            };
          },
          binding: '0b' * 32,
          now: 1000000,
        );
        expect(proof.payer, payer);
        expect(proof.matches(p, payer, tx), true);
        expect(calls, 6);
      }
    }
  });
  test('首次连接仅允许本产品元数据，不在链接中放明文交易', () async {
    const channel = '00000000-0000-4000-8000-000000000001';
    const base = 'metamask://connect?channelId=$channel&v=2&comm=socket';
    var opened = 0;
    final dispatcher = WalletLinkDispatcher(
      launcher: (_) async {
        opened++;
        return true;
      },
    );
    final info = {
      'url': 'https://www.crcfrcn.com',
      'title': 'CitizenApp',
      'scheme': 'citizenapp://topup',
    };
    String link(Map<String, String> value) =>
        '$base&originatorInfo=${Uri.encodeComponent(base64Encode(utf8.encode(jsonEncode(value))))}';
    expect(await dispatcher.open(link(info)), false);
    dispatcher.restore(
      jsonEncode({
        'channelId': channel,
        'validUntil': DateTime.now().millisecondsSinceEpoch + 60000,
      }),
    );
    expect(await dispatcher.open(link(info)), true);
    for (final value in [
      {...info, 'url': 'https://example.test'},
      {...info, 'scheme': 'other://topup'},
      {...info, 'title': 'Other'},
    ]) {
      expect(await dispatcher.open(link(value)), false);
    }
    expect(
      await dispatcher.open(
        '$base&rpc=${base64Encode(utf8.encode('{"method":"eth_sendTransaction"}'))}',
      ),
      false,
    );
    expect(opened, 1);
  });
  test('只接受保护区有效会话的SDK唤起；错误频道、重复参数、网站和明文任意RPC均拒绝', () async {
    var opened = 0;
    final dispatcher = WalletLinkDispatcher(
      launcher: (_) async {
        opened++;
        return true;
      },
    );
    const channel = '00000000-0000-4000-8000-000000000001';
    const resume = 'metamask://connect?channelId=$channel&v=2&comm=socket&t=d';
    expect(await dispatcher.open(resume), false);
    dispatcher.restore(
      jsonEncode({
        'channelId': channel,
        'validUntil': DateTime.now().millisecondsSinceEpoch + 60000,
      }),
    );
    expect(await dispatcher.open(resume), true);
    final cipher = base64Encode(
      utf8.encode(base64Encode([4, ...List.filled(100, 0)])),
    );
    expect(
      await dispatcher.open('$resume&rpc=${Uri.encodeComponent(cipher)}'),
      true,
    );
    for (final bad in [
      resume.replaceFirst(channel, '00000000-0000-4000-8000-000000000002'),
      '$resume&channelId=duplicate',
      '$resume&redirect=https://example.test',
      '$resume&rpc=${Uri.encodeComponent(base64Encode(utf8.encode('{"method":"personal_sign"}')))}',
      resume.replaceFirst('metamask:', 'other:'),
      '$resume#fragment',
    ]) {
      expect(await dispatcher.open(bad), false);
    }
    dispatcher.restore(jsonEncode({'channelId': channel, 'validUntil': 0}));
    expect(await dispatcher.open(resume), false);
    dispatcher.restore('invalid');
    expect(await dispatcher.open(resume), false);
    expect(opened, 2);
  });
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
      walletId: TopupWallet.id,
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
            walletId: TopupWallet.id,
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

void _documentTests() {
  const nonce = 'syntheticDocumentNonce0001';
  String template() =>
      File('transaction/web/walletconnect.html').readAsStringSync();
  TopupDocument document() =>
      TopupDocument(template(), utf8.encode('void 0;'), nonce)
        ..loaded(TopupDocument.baseUrl)
        ..ready({'kind': 'document_ready', 'nonce': nonce, 'ready': true});

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
  test('脚本和页面加载事件任意先后，只有两者到齐才开始，不在早到消息时静默丢失入口', () {
    for (final scriptFirst in [false, true]) {
      final doc = TopupDocument(template(), utf8.encode('void 0;'), nonce);
      final ready = <String, dynamic>{
        'kind': 'document_ready',
        'nonce': nonce,
        'ready': true,
      };
      expect(
        doc.begin(TopupDocument.baseUrl, TopupDocument.baseUrl, true),
        false,
      );
      if (scriptFirst) {
        doc.ready(ready);
      } else {
        doc.loaded(TopupDocument.baseUrl);
      }
      expect(doc.canBegin, false);
      if (scriptFirst) {
        doc.loaded(TopupDocument.baseUrl);
      } else {
        doc.ready(ready);
      }
      expect(doc.canBegin, true);
      expect(
        doc.begin(TopupDocument.baseUrl, TopupDocument.baseUrl, true),
        true,
      );
      expect(doc.canBegin, false);
    }
  });
  test('本地组件阶段诊断不接受异常、地址或其他自由文本', () {
    expect(AppLog.topupReadiness('ready'), true);
    expect(AppLog.topupReadiness('synthetic-private'), false);
    expect(AppLog.topupOrder('signing'), true);
    expect(
      AppLog.topupOrder('failed', sdkCode: CitizenSdkErrorCode.integrity),
      true,
    );
    expect(AppLog.topupOrder('synthetic-private'), false);
    expect(AppLog.topupOrder('failed', sdkCode: 'synthetic-private'), false);
    expect(AppLog.topupReadiness({'nonce': 'synthetic-private'}), false);
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
