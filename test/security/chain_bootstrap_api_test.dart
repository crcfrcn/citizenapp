import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizenapp/network/chain_bootstrap_api.dart';

const _bootnodeA =
    '/dns4/nrcgch.crcfrcn.com/tcp/30333/wss/p2p/12D3KooWHepcMGD3h9VC1XNWmrac3pXo63RimV5jhTU2nC2TLAyS';
const _bootnodeB =
    '/dns4/prczss.crcfrcn.com/tcp/30333/wss/p2p/12D3KooWPjWNXvCzPv6PPuiGnF3J5uToW3ySfaB7rKkwUrN2CALv';
// 启动清单协议夹具使用合成状态根，避免复制真实冻结锚点。
const _stateRoot =
    '0x4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  _httpTimingTests();
  test('共用 HTTPS Client 在发送前拒绝明文并禁止重定向', () async {
    var sent = 0;
    final client = HttpsOnlyClient(
      MockClient((request) async {
        sent++;
        expect(request.followRedirects, isFalse);
        return http.Response('{}', 200);
      }),
    );
    try {
      await client.get(Uri.parse('https://example.invalid'));
      expect(sent, 1);
      for (final scheme in ['http', 'ws']) {
        await expectLater(
          () => client.get(Uri.parse('$scheme://localhost')),
          throwsUnsupportedError,
        );
      }
      expect(sent, 1);
    } finally {
      client.close();
    }
  });

  test('ChainBootstrapApi 拉取并解析安全启动清单', () async {
    final api = ChainBootstrapApi(
      baseUrl: 'https://127.0.0.1:8787/api',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/chain/bootstrap');
        return http.Response(
          jsonEncode(_manifest()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final manifest = await api.fetchManifest();

    expect(manifest.chain.chainId, 'citizenchain');
    expect(manifest.chain.ss58Format, 2027);
    expect(manifest.lightClient.apiIsTruth, isFalse);
    expect(manifest.lightClient.bundledAssetsRequired, [
      'assets/chainspec.json',
      'assets/light_sync_state.json',
    ]);
    expect(manifest.security.rpcProxy, isFalse);
    expect(manifest.services.signedExtrinsicRelayEnabled, isFalse);
    expect(manifest.p2p.bootnodes, [_bootnodeA, _bootnodeB]);
  });

  test('ChainBootstrapApi 拒绝 API-only 或 RPC proxy 清单', () {
    final apiTruth = _manifest();
    (apiTruth['light_client'] as Map<String, dynamic>)['api_is_truth'] = true;

    expect(
      () => ChainBootstrapManifest.fromJson(apiTruth),
      throwsA(isA<ChainBootstrapApiException>()),
    );

    final rpcProxy = _manifest();
    (rpcProxy['security'] as Map<String, dynamic>)['rpc_proxy'] = true;

    expect(
      () => ChainBootstrapManifest.fromJson(rpcProxy),
      throwsA(isA<ChainBootstrapApiException>()),
    );
  });

  test('ChainBootstrapApi 拒绝任何 RPC URL 字段', () {
    final data = _manifest()
      ..['archive_rpc_url'] = 'https://rpc.example.invalid';

    expect(
      () => ChainBootstrapManifest.fromJson(data),
      throwsA(isA<ChainBootstrapApiException>()),
    );
  });

  test('ChainBootstrapApi 拒绝非法 schema 和任何远端 checkpoint 字段', () {
    final invalidManifest = _manifest()
      ..['schema'] = 'citizenapp.chain.bootstrap.invalid';
    expect(
      () => ChainBootstrapManifest.fromJson(invalidManifest),
      throwsA(isA<ChainBootstrapApiException>()),
    );

    final checkpoint = _manifest();
    (checkpoint['light_client'] as Map<String, dynamic>)['checkpoint'] = {
      'source': 'remote_url',
      'light_sync_state_url': 'https://api.example/light-sync-state.json',
      'light_sync_state_sha256': 'ab' * 32,
    };
    expect(
      () => ChainBootstrapManifest.fromJson(checkpoint),
      throwsA(isA<ChainBootstrapApiException>()),
    );
  });

  test('ChainBootstrapApi 只接受固定 signed extrinsic relay path', () {
    final enabled = _manifest();
    (enabled['services'] as Map<String, dynamic>)['signed_extrinsic_relay'] = {
      'enabled': true,
      'path': '/chain/extrinsics',
    };

    final parsed = ChainBootstrapManifest.fromJson(enabled);
    expect(parsed.services.signedExtrinsicRelayEnabled, isTrue);
    expect(parsed.services.signedExtrinsicRelayPath, '/chain/extrinsics');

    final badPath = _manifest();
    (badPath['services'] as Map<String, dynamic>)['signed_extrinsic_relay'] = {
      'enabled': true,
      'path': '/chain/rpc',
    };

    expect(
      () => ChainBootstrapManifest.fromJson(badPath),
      throwsA(isA<ChainBootstrapApiException>()),
    );
  });

  test('ChainBootstrapApiConfig 仅允许 HTTPS，包括本机', () {
    expect(
      ChainBootstrapApiConfig.normalizeBaseUrl('https://api.onchina.org/'),
      'https://api.onchina.org',
    );
    expect(
      ChainBootstrapApiConfig.normalizeBaseUrl('https://127.0.0.1:8787/'),
      'https://127.0.0.1:8787',
    );
    expect(
      () => ChainBootstrapApiConfig.normalizeBaseUrl('http://api.onchina.org'),
      throwsUnsupportedError,
    );
    for (final scheme in ['http', 'ws']) {
      expect(
        () => ChainBootstrapApiConfig.normalizeBaseUrl(
          '$scheme://localhost:8787',
        ),
        throwsUnsupportedError,
      );
    }
  });
}

// 内存端口验证消费时机及取消、背压、异常，不把测试等待当成生产延迟。
class _TimingClient extends http.BaseClient {
  _TimingClient(this.reply);
  final Future<http.StreamedResponse> Function(http.BaseRequest) reply;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      reply(request);
  @override
  void close() => closed = true;
}

void _httpTimingTests() {
  const canary = 'synthetic-private-http-detail';
  test('实际业务路径只输出固定功能类别，不输出动态路径或查询', () async {
    const paths = {
      '/api/chain/bootstrap': 'bootstrap',
      '/api/user/sessions': 'session',
      '/api/user/contacts': 'contacts',
      '/api/membergate/creator/tiers': 'creator',
      '/api/membergate': 'membergate',
      '/api/user/profiles/synthetic': 'profile',
      '/api/user/cards/synthetic': 'card',
      '/api/8964/follows': 'follows',
      '/api/8964/feed': 'feed',
      '/api/8964/posts/synthetic/comments': 'comments',
      '/api/notifications': 'notifications',
      '/api/topup/config': 'topup_config',
      '/api/topup/status': 'topup_status',
      '/api/tatachat/access': 'chat_access',
    };
    for (final entry in paths.entries) {
      final lines = <String>[];
      final client = HttpsOnlyClient(
        _TimingClient(
          (_) async => http.StreamedResponse(Stream.value([1]), 200),
        ),
      );
      await runZoned(
        () async {
          await client.get(
            Uri.parse('https://www.crcfrcn.com${entry.key}?q=$canary'),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      client.close();
      expect(lines, hasLength(2));
      expect(lines.last, contains('stage=${entry.value} http=200'));
      expect(lines.last, endsWith('phase=complete'));
      expect(lines.join(), isNot(contains(canary)));
      expect(lines.join(), isNot(contains(entry.key)));
    }
  });
  final uri = Uri.parse(
    'https://www.crcfrcn.com/api/user/challenges?q=$canary',
  );
  Future<List<String>> capture(Future<void> Function() action) async {
    final lines = <String>[];
    await runZoned(
      action,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
    expect(lines.join(), isNot(contains(canary)));
    return lines;
  }

  test('HTTP计时不预读，保留元数据、背压、正文和关闭', () async {
    final source = StreamController<List<int>>();
    final request = http.Request('POST', uri)
      ..headers['authorization'] = canary
      ..body = canary;
    final inner = _TimingClient((sent) async {
      expect(sent, same(request));
      expect(sent.followRedirects, isFalse);
      return http.StreamedResponse(
        source.stream,
        206,
        request: sent,
        contentLength: 3,
        headers: {'x-test': 'kept'},
        reasonPhrase: 'Partial Content',
        persistentConnection: false,
      );
    });
    final client = HttpsOnlyClient(inner);
    final lines = await capture(() async {
      final response = await client.send(request);
      expect(source.hasListener, isFalse);
      expect(response.request, same(request));
      expect(response.contentLength, 3);
      expect(response.headers['x-test'], 'kept');
      expect(response.reasonPhrase, 'Partial Content');
      expect(response.persistentConnection, isFalse);
      final bytes = <int>[];
      final done = Completer<void>();
      final subscription = response.stream.listen(
        bytes.addAll,
        onDone: done.complete,
      );
      await Future<void>.delayed(Duration.zero);
      expect(source.hasListener, isTrue);
      subscription.pause();
      await Future<void>.delayed(Duration.zero);
      expect(source.isPaused, isTrue);
      subscription.resume();
      source.add([1, 2, 3]);
      await source.close();
      await done.future;
      expect(bytes, [1, 2, 3]);
      client.close();
      expect(inner.closed, isTrue);
    });
    expect(lines.length, 2);
    expect(lines.first, contains('stage=challenge http=206'));
    expect(lines.first, endsWith('phase=headers'));
    expect(lines.last, endsWith('phase=complete'));
    final timing = RegExp(r'headers_us=(\d+) total_us=(\d+)')
        .firstMatch(lines.last)!;
    expect(int.parse(timing[2]!), greaterThanOrEqualTo(int.parse(timing[1]!)));
  });
  test('HTTP取消透传且不宣告正文完成', () async {
    var cancelled = 0;
    final source = StreamController<List<int>>(
      onCancel: () {
        cancelled++;
      },
    );
    final client = HttpsOnlyClient(
      _TimingClient((_) async => http.StreamedResponse(source.stream, 200)),
    );
    final lines = await capture(() async {
      final response = await client.send(http.Request('GET', uri));
      final subscription = response.stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      client.close();
    });
    expect(cancelled, 1);
    expect(lines.length, 2);
    expect(lines.last, endsWith('phase=cancelled'));
  });
  for (final body in [false, true]) {
    test('HTTP错误$body保留原异常且只结束一次', () async {
      final failure = StateError(canary);
      final client = HttpsOnlyClient(
        _TimingClient((_) async {
          if (!body) throw failure;
          return http.StreamedResponse(Stream<List<int>>.error(failure), 200);
        }),
      );
      final lines = await capture(() async {
        await expectLater(client.get(uri), throwsA(same(failure)));
        client.close();
      });
      expect(lines.where((line) => line.endsWith('phase=error')).length, 1);
      expect(lines.join(), isNot(contains('phase=complete')));
    });
  }
  test('非所属源保持原响应对象且不输出正式服务计时', () async {
    final original = http.StreamedResponse(Stream.value([1]), 200);
    final client = HttpsOnlyClient(_TimingClient((_) async => original));
    final lines = await capture(() async {
      final response = await client.send(
        http.Request(
          'GET',
          Uri.parse('https://other.invalid/api/user/challenges'),
        ),
      );
      expect(response, same(original));
      await response.stream.drain<void>();
      client.close();
    });
    expect(lines, isEmpty);
  });
}

Map<String, dynamic> _manifest() => {
  'ok': true,
  'schema': 'citizenapp.chain.bootstrap',
  'generated_at': 1800000000000,
  'cache_ttl_seconds': 300,
  'chain': {
    'chain_id': 'citizenchain',
    'chain_name': 'CitizenChain',
    'chain_type': 'Live',
    'protocol_id': 'citizenchain',
    // 协议解析夹具使用合成哈希，不复制真实创世锚点。
    'genesis_hash':
        '0x2222222222222222222222222222222222222222222222222222222222222222',
    'state_root': _stateRoot,
    'ss58_format': 2027,
    'token_symbol': 'GMB',
    'token_decimals': 2,
  },
  'light_client': {
    'mode': 'smoldot',
    'truth_source': 'p2p_finalized_storage',
    'api_is_truth': false,
    'bundled_assets_required': [
      'assets/chainspec.json',
      'assets/light_sync_state.json',
    ],
  },
  'p2p': {
    'bootnodes': [_bootnodeA, _bootnodeB],
    'bootnodes_source': 'worker_config',
    'min_peer_count_hint': 1,
  },
  'services': {
    'square_base_url': 'https://api.onchina.org/square',
    'media_base_url': 'https://api.onchina.org/square/media',
    'signed_extrinsic_relay': {'enabled': false, 'path': null},
  },
  'security': {
    'exposes_rpc_url': false,
    'rpc_proxy': false,
    'exposes_private_key_material': false,
    'validator_rpc_public': false,
  },
  'degradation': {
    'p2p_unavailable': 'services_continue_chain_state_degraded',
    'chain_success_source': 'finalized_runtime_storage_or_events',
  },
};
