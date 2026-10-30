import 'package:citizen_testing/mls_authentication_fixture.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_account/square_api_client.dart'
    show SquareMembershipState, SquareSession;
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/creator/creator_api.dart';
import 'package:citizen_account/creator/creator_service.dart';
import 'package:citizen_account/creator/creator_overview.dart';
import 'package:citizen_account/creator/creator_plan.dart';
import 'package:citizen_account/membership/subscription_service.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_account/identity/citizen_identity_chain_reader.dart';
import 'package:citizen_account/membership/subscription_chain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:citizen_testing/isar_test_env.dart';
import 'package:citizen_testing/fake_citizen_sdk.dart';

void main() {
  test('本人概览creator_rev条件读取与他人真实平面价格报文一致，不回填属主', () async {
    var ownReads = 0;
    var target = testMlsCidNumber;
    final row = {
      'tier_id': 't',
      'tier_name': '支持者',
      'month_fen': 101,
      'quarter_fen': 8,
      'year_fen': 25,
    };
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test/api',
      httpClient: MockClient((request) async {
        expect(request.headers['x-mls-proof'], isNotEmpty);
        final Map<String, Object?> body;
        if (request.url.path.endsWith('/overview')) {
          ownReads++;
          if (ownReads == 1) {
            body = {
              'is_ok': true,
              'creator_rev': 7,
              'plan': {
                'tiers': [row],
              },
              'overview': {
                'subscriber_count': 1,
                'monthly_income_fen': 101,
                'tier_count': 1,
              },
            };
          } else {
            expect(request.url.queryParameters, {'creator_rev': '7'});
            body = {'is_ok': true, 'unchanged': true, 'creator_rev': 7};
          }
        } else {
          body = {
            'is_ok': true,
            'creator_cid': target,
            'tiers': [row],
            'membergate_active': true,
            'subscription': {
              'tier_id': 't',
              'billing_period': 'monthly',
              'sub_state': 'active',
              'paid_until': 9999999999999,
            },
          };
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final current = SquareSession(
      deviceId: testMlsDeviceId,
      sessionToken: 't',
      cidNumber: testMlsCidNumber,
      bindRev: 1,
      accountId: testMlsAccountId,
      expiresAt: 9999999999999,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final own = await api.fetchMyPlan(current);
    await api.fetchOverview(current);
    final other = await api.fetchViewOf(current, target);
    expect(own!.toJson(), {
      'tiers': [row],
    });
    expect(other.plan!.toJson(), own.toJson());
    expect(other.subscription!.subState, 'active');
    expect(other.plan!.tiers.single.priceFenOf(BillingPeriod.quarterly), 8);
    target = 'CN220-CTZN2-100000002-2026';
    await expectLater(
      api.fetchViewOf(current, testMlsCidNumber),
      throwsA(isA<CreatorApiException>()),
    );
  });

  useIsolatedIsar();
  const session = SquareSession(
    deviceId: testMlsDeviceId,
    sessionToken: 't',
    cidNumber: "CN220-CTZN2-198805200-2026",
    bindRev: 1,
    accountId:
        '0x7777777777777777777777777777777777777777777777777777777777777777',
    expiresAt: 9999999999999,
  );

  const tier = CreatorTier(
    tierId: 't1',
    tierName: '铁杆粉丝',
    monthFen: 990,
    quarterFen: null,
    yearFen: null,
  );

  test('FakeCreatorApi 只接收已 finalized 交易哈希，不再触发第二次业务签名', () async {
    final api = FakeCreatorApi();

    final plan = await api.saveMyPlan(
      session: session,
      txHash: '0x${List.filled(64, 'a').join()}',
      blockHash: '0x${List.filled(64, 'b').join()}',
    );

    expect(api.lastSaveTxHash, '0x${List.filled(64, 'a').join()}');
    expect(plan.toJson(), {'tiers': []});
    expect(plan.tiers, isEmpty);
    expect(await api.fetchMyPlan(session), isNotNull);
  });

  test('finalized确认用实际/api请求MLS证明；确认后同CID重读tiers', () async {
    final requests = <http.Request>[];
    final tx = '0x${'aa' * 32}', block = '0x${'bb' * 32}';
    final api = CreatorApiHttp(
      baseUrl: 'https://creator.test/api',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.headers['x-mls-proof'], isNotEmpty);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'tx_hash': tx,
            'block_hash': block,
          });
          return http.Response(
            jsonEncode({'is_ok': true, 'tx_hash': tx, 'block_hash': block}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'is_ok': true,
            'creator_rev': 1,
            'plan': {
              'tiers': [
                {
                  'tier_id': 't1',
                  'tier_name': '铁杆粉丝',
                  'month_fen': 990,
                  'quarter_fen': null,
                  'year_fen': null,
                },
              ],
            },
            'overview': {
              'subscriber_count': 0,
              'monthly_income_fen': 0,
              'tier_count': 1,
            },
          }),
          200,
          headers: {"content-type": "application/json; charset=utf-8"},
        );
      }),
    );
    final authorized = SquareSession(
      deviceId: session.deviceId,
      sessionToken: session.sessionToken,
      cidNumber: session.cidNumber,
      bindRev: 1,
      accountId: session.accountId,
      expiresAt: session.expiresAt,
      authenticateRequest: fakeMlsRequestHeaders,
    );
    final plan = await api.saveMyPlan(
      session: authorized,
      txHash: tx,
      blockHash: block,
    );
    expect(plan.tiers.single.priceFenOf(BillingPeriod.monthly), 990);
    expect(requests.map((r) => r.url.path), [
      '/api/membergate/creators/plans',
      '/api/membergate/creator/overview',
    ]);
    await api.confirmCreatorSubscription(
      session: authorized,
      creatorCid: 'CN220-CTZN2-100000001-2026',
      txHash: tx,
      blockHash: block,
    );
    expect(
      requests.last.url.path,
      '/api/membergate/creators/CN220-CTZN2-100000001-2026/subscription/confirm',
    );
  });

  test('FakeCreatorApi 概览默认按档位数', () async {
    final api = FakeCreatorApi(initialPlan: const CreatorPlan(tiers: [tier]));
    final overview = await api.fetchOverview(session);
    expect(overview.tierCount, 1);
    expect(overview.subscriberCount, 0);
  });

  test('创作者展示快照按 CID 持久化并完整往返', () async {
    final service = CreatorService(
      chain: TestCitizenChain(),
      transactions: TestCitizenTransactions(),
      api: FakeCreatorApi(),
      subscriptionChain: _FakeSubscriptionChain(),
      wallet: _FakeWallet(),
      identityResolver: _FakeIdentityCache(),
      sessionProvider: _FakeSessionProvider(),
      subscriptionService: _ActiveMembershipService(),
    );
    final display = CreatorPageData.active(
      plan: const CreatorPlan(tiers: [tier]),
      overview: const CreatorOverview(
        subscriberCount: 7,
        monthlyIncomeFen: 8800,
        tierCount: 1,
      ),
    );
    await service.rememberDisplayData(
      cidNumber: _creatorCid,
      data: display,
      memberAt: 1000,
      creatorAt: 2000,
    );

    final snapshot = await service.readDisplaySnapshot(_creatorCid);
    expect(snapshot, isNotNull);
    expect(snapshot!.cidNumber, _creatorCid);
    expect(snapshot.data.gated, isFalse);
    expect(snapshot.data.plan!.tiers.single.tierName, '铁杆粉丝');
    expect(snapshot.data.overview!.subscriberCount, 7);
    expect(snapshot.memberAt, 1000);
    expect(snapshot.creatorAt, 2000);
  });

  test('链上 finalized 后 Cloudflare 失败只重试投影确认，不产生第二次链上签名', () async {
    final api = _FlakyCreatorApi()..failSave = true;
    final rpc = _FakeSubscriptionChain();
    final sessionProvider = _FakeSessionProvider();
    final service = CreatorService(
      chain: TestCitizenChain(),
      transactions: TestCitizenTransactions(),
      api: api,
      subscriptionChain: rpc,
      wallet: _FakeWallet(),
      identityResolver: _FakeIdentityCache(),
      sessionProvider: sessionProvider,
      subscriptionService: _ActiveMembershipService(),
    );

    final saved = await service.saveTiers(const [tier]);
    expect(saved.tiers.single.tierName, '铁杆粉丝');
    expect(rpc.setPlansCount, 1);
    expect(rpc.signCount, 1);
    expect(api.saveCount, 1);

    // 同一 CID 已换绑到新钱包账户；待提交证明仍必须由新会话接续处理。
    sessionProvider.accountId = _reboundAccountId;
    api.failSave = false;
    await service.load();
    expect(api.saveCount, 2, reason: '再次进入页面只重试 Cloudflare 查询投影');
    expect(rpc.setPlansCount, 1, reason: '同一业务不得再次提交链上交易');
    expect(rpc.signCount, 1, reason: '同一业务不得再次账户签名');
  });

  test('创作者刷新只使用 CitizenServe 会员与档位投影', () async {
    final rpc = _FakeSubscriptionChain();
    final service = CreatorService(
      chain: TestCitizenChain(),
      transactions: TestCitizenTransactions(),
      api: FakeCreatorApi(),
      subscriptionChain: rpc,
      wallet: _FakeWallet(),
      identityResolver: _FakeIdentityCache(),
      sessionProvider: _FakeSessionProvider(),
      subscriptionService: _ActiveMembershipService(),
    );

    final data = await service.load(expectedCidNumber: _creatorCid);

    expect(data.gated, isFalse);
    expect(rpc.lastPlansBlockHash, isNull, reason: '页面展示不得再直接读取链上创作者档位');
  });

  test('仅改档位名只提交 call_index 6，不重写价格计划', () async {
    final rpc = _FakeSubscriptionChain();
    final api = FakeCreatorApi(
      initialPlan: CreatorPlan(tiers: [tier.copyWith(tierName: '核心支持者')]),
    );
    final service = CreatorService(
      chain: TestCitizenChain(),
      transactions: TestCitizenTransactions(),
      api: api,
      subscriptionChain: rpc,
      wallet: _FakeWallet(),
      identityResolver: _FakeIdentityCache(),
      sessionProvider: _FakeSessionProvider(),
      subscriptionService: _ActiveMembershipService(),
    );

    final plan = await service.updateTierName(
      currentTiers: const [tier],
      tierId: 't1',
      tierName: '核心支持者',
    );

    expect(rpc.renameCount, 1);
    expect(rpc.setPlansCount, 0);
    expect(rpc.signCount, 1);
    expect(api.lastSaveTxHash, '0x${List.filled(64, 'e').join()}');
    expect(plan.tiers.single.tierName, '核心支持者');
    expect(plan.tiers.single.priceFenOf(BillingPeriod.monthly), 990);
  });
}

const _signerSs58Address = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
const _accountId =
    '0x0000000000000000000000000000000000000000000000000000000000000000';
const _reboundAccountId =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
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

class _FakeWallet implements CitizenSdkWallet {
  @override
  CitizenSdkOperation<CitizenWalletState> getState() => testCitizenOperation(
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActiveMembershipService implements SubscriptionService {
  @override
  Future<MembershipDisplaySnapshot?> readDisplaySnapshot(
    String cidNumber,
  ) async => null;

  @override
  Future<SquareMembershipState> authorizeMembership(
    SquareSession session, {
    bool forceRefresh = false,
  }) async => const SquareMembershipState(
    active: true,
    paidUntil: 9999999999999,
    memberLevel: 'freedom',
    subState: 'active',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptionChain extends SubscriptionChain {
  _FakeSubscriptionChain()
    : super(chain: TestCitizenChain(), transactions: TestCitizenTransactions());

  int setPlansCount = 0;
  int renameCount = 0;
  int signCount = 0;
  String currentTierName = '铁杆粉丝';
  String? lastPlansBlockHash;

  @override
  Future<FinalizedSubscriptionSnapshot> fetchSubscriptionSnapshot({
    required String cidNumber,
    String? creatorCid,
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
      usedNonce: 2,
      blockHash: '0x${List.filled(64, 'f').join()}',
    );
  }

  @override
  Future<List<ChainCreatorTier>> fetchCreatorPlans(String creatorCid) async => [
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

class _FlakyCreatorApi extends FakeCreatorApi {
  bool failSave = false;
  int saveCount = 0;

  @override
  Future<CreatorPlan> saveMyPlan({
    required SquareSession session,
    required String txHash,
    required String blockHash,
  }) async {
    saveCount++;
    if (failSave) throw const CreatorApiException('temporary');
    return super.saveMyPlan(
      session: session,
      txHash: txHash,
      blockHash: blockHash,
    );
  }
}
