import 'package:citizen_sdk/citizen_sdk.dart';

CitizenChainSyncStatus chainSnapshot({
  required bool isSyncing,
  required bool isUsable,
}) {
  const finalizedHash =
      '0xe3985a35f8668d74f1552be80e1e4c5c01fcce7f7c757cc0cf254ec21a1d2d9c';
  // UI 状态夹具使用合成哈希，不绑定任何真实创世版本。
  final finalizedNumber = isUsable ? BigInt.from(33) : BigInt.zero;
  return CitizenChainSyncStatus(
    peerCount: BigInt.from(5),
    isSyncing: isSyncing,
    isUsable: isUsable,
    best: CitizenBlockRef(
      hash: finalizedHash,
      number: BigInt.from(33),
      finality: CitizenBlockFinality.best,
    ),
    finalized: CitizenBlockRef(
      hash: finalizedHash,
      number: finalizedNumber,
      finality: CitizenBlockFinality.finalized,
    ),
  );
}
