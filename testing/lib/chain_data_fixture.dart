import 'package:citizen_chain/citizen_chain.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

const cidA = 'CN220-CTZN2-100000001-2026', cidB = 'CN220-CTZN2-100000002-2026';
String account(int byte) => '0x${byte.toRadixString(16).padLeft(2, '0') * 32}';
String hash(int n) => '0x${n.toRadixString(16).padLeft(64, '0')}';
CitizenBlockRef block(int n) => CitizenBlockRef(
  hash: hash(n),
  number: BigInt.from(n),
  finality: CitizenBlockFinality.finalized,
);
ChainDataSnapshot snapshot(
  CitizenBlockRef b,
  String owner, {
  Set<String> citizens = const {},
  Set<String> creators = const {},
  int paidUntil = 100000,
  int? now,
  String? cidNumber,
  bool hasMembership = true,
  List<ChainCreatorTier> creatorTiers = const [],
  bool ownCreator = false,
  String memberLevel = 'freedom',
  String subState = 'active',
  int bindRev = 1,
  String? genesisHash,
  int runtimeSpecVersion = 1,
  int runtimeTransactionVersion = 4,
  Map<String, int> priceValues = const {
    'freedom': 100,
    'democracy': 200,
    'spark': 300,
  },
}) {
  final cid = cidNumber ?? (owner == account(1) ? cidA : cidB);
  ChainCitizenData person(String key) => ChainCitizenData(
    cidNumber: key,
    identity: CitizenIdentityChainSnapshot(
      cidNumber: key,
      accountId: citizenAccountIdBytes(owner),
      bindRev: bindRev,
      votingIdentity: null,
    ),
    platform: hasMembership
        ? ChainSubscriptionState(
            plan: ChainSubscriptionPlan.platform(memberLevel),
            startedAt: 1,
            chargeAt: 1,
            chargeFen: BigInt.from(100),
            paidUntil: paidUntil,
            subState: subState,
            priceFen: BigInt.from(100),
            suspendReason: null,
          )
        : null,
    creatorTiers: creators.contains(key) || ownCreator && key == cid
        ? creatorTiers
        : null,
  );
  return ChainDataSnapshot(
    genesisHash: genesisHash ?? hash(0),
    accountId: owner,
    block: b,
    chainNowMs: now ?? 1000 + b.number.toInt(),
    ownCid: cid,
    citizens: {
      for (final key in {...citizens, ...creators, cid}) key: person(key),
    },
    subscriptions: {for (final key in creators) key: null},
    prices: priceValues,
    runtimeSpecVersion: runtimeSpecVersion,
    runtimeTransactionVersion: runtimeTransactionVersion,
  );
}

class Reader extends ChainDataReader {
  Reader()
    : super(
        getRuntimeContext: (_) async => throw StateError('unused'),
        getStorageBatch: (_, _) async => throw StateError('unused'),
      );
  final calls = <(String, int)>[];
  final priceCalls = <(String, int)>[];
  Future<ChainDataSnapshot> Function(
    String,
    CitizenBlockRef,
    Set<String>,
    Set<String>,
  )?
  behavior;
  Future<ChainDataSnapshot> Function(
    String,
    CitizenBlockRef,
    Set<String>,
    Set<String>,
    bool,
  )?
  ownBehavior;
  @override
  Future<ChainDataSnapshot> read({
    required String genesisHash,
    required String accountId,
    required CitizenBlockRef block,
    Set<String> citizens = const {},
    Set<String> creators = const {},
    bool ownCreator = false,
    bool prices = false,
  }) async {
    calls.add((accountId, block.number.toInt()));
    if (prices) priceCalls.add((accountId, block.number.toInt()));
    final data = ownBehavior != null
        ? await ownBehavior!(accountId, block, citizens, creators, ownCreator)
        : behavior != null
        ? await behavior!(accountId, block, citizens, creators)
        : snapshot(
            block,
            accountId,
            citizens: citizens,
            creators: creators,
            ownCreator: ownCreator,
            genesisHash: genesisHash,
          );
    return ChainDataSnapshot(
      genesisHash: data.genesisHash,
      accountId: data.accountId,
      block: data.block,
      chainNowMs: data.chainNowMs,
      ownCid: data.ownCid,
      citizens: data.citizens,
      subscriptions: data.subscriptions,
      prices: prices ? data.prices : {},
      pricesLoaded: prices,
      runtimeSpecVersion: data.runtimeSpecVersion,
      runtimeTransactionVersion: data.runtimeTransactionVersion,
    );
  }
}

class Store implements ChainDataStore {
  final writes = <ChainDataSnapshot>[];
  ChainDataSnapshot? cached;
  ChainPriceSnapshot? cachedPrices;
  final priceWrites = <ChainPriceSnapshot>[];
  @override
  Future<ChainPriceSnapshot?> readPrices(String genesis) async =>
      cachedPrices?.genesisHash == genesis ? cachedPrices : null;
  @override
  Future<void> writePrices(
    ChainPriceSnapshot value,
    bool Function() current,
  ) async {
    if (current()) priceWrites.add(value);
  }

  @override
  Future<ChainDataSnapshot?> read(String genesis, String account) async =>
      cached?.accountId == account && cached?.genesisHash == genesis
      ? cached
      : null;
  @override
  Future<void> write(ChainDataSnapshot value, bool Function() current) async {
    if (current()) {
      writes.add(value);
    }
  }
}

Future<void> flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
