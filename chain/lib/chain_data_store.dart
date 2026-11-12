import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:citizen_storage/chain_state.dart';
import 'package:citizen_storage/user_isar.dart';
import 'chain_data.dart';

abstract interface class ChainDataStore {
  Future<ChainDataSnapshot?> read(String genesis, String account);
  Future<void> write(ChainDataSnapshot value, bool Function() isCurrent);
}

final class IsarChainDataStore implements ChainDataStore {
  @override
  Future<ChainDataSnapshot?> read(String genesis, String account) async {
    final raw = await UserIsar.instance.read(
      (db) async => (await db.collection<ChainState>().getByKey(
        '$genesis:$account',
      ))?.data,
    );
    if (raw == null) {
      return null;
    }
    try {
      return ChainDataSnapshot.decode(raw, genesis, account);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(ChainDataSnapshot value, bool Function() isCurrent) =>
      UserIsar.instance.writeTxn((db) async {
        if (!isCurrent()) {
          return;
        }
        final key = '${value.genesisHash}:${value.accountId}';
        final IsarCollection<ChainState> rows = db.collection<ChainState>();
        final old = await rows.getByKey(key);
        ChainDataSnapshot? cached;
        if (old != null) {
          try {
            cached = ChainDataSnapshot.decode(
              old.data,
              value.genesisHash,
              value.accountId,
            );
          } on Object {
            /* 损坏缓存由本次已验证结果替换。 */
          }
        }
        if (cached != null) {
          if (cached.block.number > value.block.number) {
            return;
          }
          if (cached.block.number == value.block.number &&
              cached.block.hash != value.block.hash) {
            throw StateError('最终区块冲突');
          }
        }
        if (!isCurrent()) {
          return;
        }
        await rows.putByKey(
          ChainState()
            ..key = key
            ..data = jsonEncode(value.toJson()),
        );
        if (!isCurrent()) {
          throw StateError('链上读模型归属已变化');
        }
      });
}
