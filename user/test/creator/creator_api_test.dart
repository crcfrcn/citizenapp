import 'package:citizen_testing/mls_authentication_fixture.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_user/square_api_client.dart' show SquareSession;
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/creator/creator_api.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/creator/creator_plan.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

void main() {
  useIsolatedIsar();
  const tier = CreatorTier(
    tierId: 't1',
    tierName: '铁杆粉丝',
    monthFen: 990,
    quarterFen: null,
    yearFen: null,
  );

  test('关系登记只发送最低最终高度，不发送交易或会员镜像', () async {
    final sent = <http.Request>[];
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test/api',
      httpClient: MockClient((r) async {
        sent.add(r);
        return http.Response(
          jsonEncode(
            r.method == 'GET'
                ? {
                    'is_ok': true,
                    'cid_numbers': [_creatorCid],
                    'next_cursor': null,
                  }
                : {'is_ok': true},
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final owner = fakeSquareSession(_accountId, cidNumber: _creatorCid);
    await api.registerSubscription(
      session: owner,
      creatorCid: 'CID2',
      finalBlock: 103,
    );
    expect(jsonDecode(sent.single.body), {'final_block': 103});
    expect(sent.single.method, 'PUT');
    expect(sent.single.url.path, '/api/membergate/creators/CID2/subscription');
    final page = await api.fetchSubscribers(owner);
    expect(page.cidNumbers, [_creatorCid]);
    expect(sent.last.url.path, '/api/membergate/creator/subscribers');
    expect(sent.last.headers['x-mls-proof'], isNotEmpty);
  });
  test('登记列表拒绝畸形数据和服务端失败', () async {
    for (final response in [
      http.Response('{"is_ok":true,"cid_numbers":[42]}', 200),
      http.Response('{"is_ok":false}', 503),
    ]) {
      final api = CreatorApiHttp(
        baseUrl: 'https://creator.test/api',
        httpClient: MockClient((_) async => response),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchSubscribers(
          fakeSquareSession(_accountId, cidNumber: _creatorCid),
        ),
        throwsA(isA<CreatorApiException>()),
      );
    }
  });
  test('仅改档位名只提交 call_index 6，不重写价格计划', () async {
    final rpc = _FakeSubscriptionChain();
    final api = FakeCreatorApi();
    final service = (() {
      final reads0 = _FakeWallet();
      return CreatorService(
        api: api,
        subscriptionChain: rpc,
        getWalletState: reads0.getWalletState,
        identityResolver: _FakeIdentityCache(),
        sessionProvider: _FakeSessionProvider(),
      );
    })();

    final plan = await service.updateTierName(
      currentTiers: const [tier],
      tierId: 't1',
      tierName: '核心支持者',
    );

    expect(plan.tiers.single.tierName, '核心支持者');
    expect(rpc.renameCount, 1);
    expect(rpc.setPlansCount, 0);
    expect(rpc.signCount, 1);
    expect(api.registered, isEmpty);
  });
}

const _signerSs58Address = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
const _accountId =
    '0x0000000000000000000000000000000000000000000000000000000000000000';
const _creatorCid = 'CN220-CTZN2-198805200-2026';

class _FakeSessionProvider implements SquareSessionProvider {
  String accountId = _accountId;

  @override
  Future<SquareSession?> ensureSession() async => SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 'creator-session',
    cidNumber: _creatorCid,
    bindRev: 1,
    accountId: accountId,
    expiresAt: 9999999999999,
  );

  @override
  Future<SquareSessionResolution> resolveSession({bool refresh = false}) async {
    final session = await ensureSession();
    return SquareSessionResolution(SquareSessionStatus.ready, session: session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 身份账户单源 fake：身份=账户0（与钱包/会话同账户），offline、不链读。
class _FakeIdentityCache implements FinalizedIdentityResolver {
  @override
  Future<FinalizedIdentity?> resolve() async => FinalizedIdentity(
    accountId: _accountId,
    accountAddress: _signerSs58Address,
    snapshot: CitizenIdentityChainSnapshot(
      cidNumber: _creatorCid,
      accountId: Uint8List(32),
      bindRev: 1,
      votingIdentity: null,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWallet extends TestWalletReads {
  @override
  CitizenSdkOperation<CitizenWalletState> getWalletState() =>
      testCitizenOperation(
        () async => CitizenWalletState(
          initializationState: CitizenWalletInitializationState.ready,
          cleanupPending: false,
          revision: BigInt.one,
          hotProfile: null,
          accounts: [
            CitizenWalletStateAccount(
              signMode: CitizenWalletSignMode.hot,
              walletIndex: 1,
              accountIndex: 0,
              name: 'creator',
              ss58Address: _signerSs58Address,
              accountId: _accountId,
              createdAtMillis: BigInt.zero,
              isDefault: true,
            ),
          ],
        ),
      );
}

class _FakeSubscriptionChain extends SubscriptionChain {
  _FakeSubscriptionChain() : super();

  int setPlansCount = 0;
  int renameCount = 0;
  int signCount = 0;
  String currentTierName = '铁杆粉丝';
  String? lastPlansBlockHash;

  @override
  Future<FinalizedSubscriptionSnapshot> fetchSubscriptionSnapshot({
    required String cidNumber,
    String? creatorCid,
    CitizenBlockRef? at,
  }) async => FinalizedSubscriptionSnapshot(
    state: ChainSubscriptionState(
      plan: const ChainSubscriptionPlan.platform('freedom'),
      startedAt: 1000,
      chargeAt: 1000,
      chargeFen: BigInt.one,
      paidUntil: 3000,
      subState: 'active',
      priceFen: BigInt.one,
      suspendReason: null,
    ),
    chainNowMs: 2000,
    block: CitizenBlockRef(
      hash: '0x${List.filled(64, '0').join()}',
      number: BigInt.one,
      finality: CitizenBlockFinality.finalized,
    ),
  );

  @override
  Future<FinalizedSubscriptionTransaction> setCreatorPlans({
    required Uint8List signerPublicKey,
    required List<CreatorTierInput> tiers,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    setPlansCount++;
    signCount++;
    return (
      txHash: '0x${List.filled(64, 'c').join()}',
      blockNumber: 103,
      usedNonce: 1,
      blockHash: '0x${List.filled(64, 'd').join()}',
    );
  }

  @override
  Future<FinalizedSubscriptionTransaction> updateCreatorTierName({
    required Uint8List signerPublicKey,
    required String tierId,
    required String tierName,
    required Future<String?> Function(
      CitizenTransactionExternalSigningPending pending,
    )
    externalSigning,
  }) async {
    renameCount++;
    signCount++;
    currentTierName = tierName;
    return (
      txHash: '0x${List.filled(64, 'e').join()}',
      blockNumber: 103,
      usedNonce: 2,
      blockHash: '0x${List.filled(64, 'f').join()}',
    );
  }

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlans(
    String creatorCid, {
    CitizenBlockRef? at,
  }) async => [
    ChainCreatorTier(
      tierId: 't1',
      tierName: currentTierName,
      pricesFen: {'monthly': BigInt.from(990)},
    ),
  ];

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlansAtBlock(
    String creatorCid,
    CitizenBlockRef block,
  ) {
    lastPlansBlockHash = block.hash;
    return fetchCreatorPlans(creatorCid);
  }
}
