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
}) {
  final cid = cidNumber ?? (owner == account(1) ? cidA : cidB);
  ChainCitizenData person(String key) => ChainCitizenData(
    cidNumber: key,
    identity: CitizenIdentityChainSnapshot(
      cidNumber: key,
      accountId: citizenAccountIdBytes(owner),
      bindRev: 1,
      votingIdentity: null,
    ),
    platform: hasMembership
        ? ChainSubscriptionState(
            plan: const ChainSubscriptionPlan.platform('freedom'),
            startedAt: 1,
            chargeAt: 1,
            chargeFen: BigInt.from(100),
            paidUntil: paidUntil,
            subState: 'active',
            priceFen: BigInt.from(100),
            suspendReason: null,
          )
        : null,
    creatorTiers: creatorTiers,
  );
  return ChainDataSnapshot(
    genesisHash: hash(0),
    accountId: owner,
    block: b,
    chainNowMs: now ?? 1000 + b.number.toInt(),
    ownCid: cid,
    citizens: {
      for (final key in {...citizens, ...creators, cid}) key: person(key),
    },
    subscriptions: {for (final key in creators) key: null},
    prices: const {'freedom': 100, 'democracy': 200, 'spark': 300},
  );
}

class Reader extends ChainDataReader {
  Reader()
    : super(
        getRuntimeContext: (_) async => throw StateError('unused'),
        getStorageBatch: (_, __) async => throw StateError('unused'),
      );
  final calls = <(String, int)>[];
  Future<ChainDataSnapshot> Function(
    String,
    CitizenBlockRef,
    Set<String>,
    Set<String>,
  )?
  behavior;
  @override
  Future<ChainDataSnapshot> read({
    required String genesisHash,
    required String accountId,
    required CitizenBlockRef block,
    Set<String> citizens = const {},
    Set<String> creators = const {},
  }) async {
    calls.add((accountId, block.number.toInt()));
    return behavior == null
        ? snapshot(block, accountId, citizens: citizens, creators: creators)
        : behavior!(accountId, block, citizens, creators);
  }
}

class Store implements ChainDataStore {
  final writes = <ChainDataSnapshot>[];
  ChainDataSnapshot? cached;
  @override
  Future<ChainDataSnapshot?> read(String genesis, String account) async =>
      cached?.accountId == account ? cached : null;
  @override
  Future<void> write(ChainDataSnapshot value, bool Function() current) async {
    if (current()) writes.add(value);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 20; i++) await Future<void>.delayed(Duration.zero);
}
