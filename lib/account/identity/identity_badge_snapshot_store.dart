import 'package:citizenapp/storage/user_isar.dart' as user_store show Identity;

import 'dart:convert';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:citizenapp/storage/user_isar.dart';

import 'citizen_identity_chain_reader.dart';

/// 身份的持久展示快照；完整链数据只供卡片显示，不能用作当前操作的授权结果。
class IdentityBadgeSnapshot {
  const IdentityBadgeSnapshot({
    required this.cidNumber,
    required this.cidLevel,
    required this.updatedAt,
    this.accountId,
    this.identity,
    this.verified = false,
  });

  final String cidNumber;
  final String cidLevel;
  final int updatedAt;
  final String? accountId;
  final CitizenIdentityChainSnapshot? identity;

  /// 已完整读取过身份；true 且 identity 为 null 明确表示已验证未注册。
  final bool verified;
}

/// 身份页、我的及广场唯一展示存储；读取永远不联网。
class IdentityBadgeSnapshotStore {
  IdentityBadgeSnapshotStore({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  static const _allowedLevels = {'visitor', 'voting', 'candidate'};
  static final revision = ValueNotifier<int>(0);
  final DateTime Function() _nowProvider;

  Future<IdentityBadgeSnapshot?> read(String cidNumber) async {
    final cid = cidNumber.trim();
    if (cid.isEmpty) return null;
    final row = await UserIsar.instance.read(
      (isar) async => isar
          .collection<user_store.Identity>()
          .filter()
          .cidNumberEqualTo(cid)
          .sortByUpdatedAtDesc()
          .findFirst(),
    );
    return _decode(row);
  }

  Future<IdentityBadgeSnapshot?> readForAccountId(String accountId) async {
    final row = await UserIsar.instance.read(
      (isar) async => isar
          .collection<user_store.Identity>()
          .filter()
          .accountIdEqualTo(accountId)
          .sortByUpdatedAtDesc()
          .findFirst(),
    );
    return _decode(row);
  }

  IdentityBadgeSnapshot? _decode(user_store.Identity? row) {
    if (row == null || row.updatedAt < 0 || row.identityData == null) {
      return null;
    }
    CitizenIdentityChainSnapshot? identity;
    late String cidLevel;
    final raw = row.identityData;
    try {
      final value = jsonDecode(raw!);
      if (row.accountId == null) {
        if (value is! Map<String, dynamic> ||
            value.length != 1 ||
            !_allowedLevels.contains(value['cid_level']) ||
            row.cidNumber.isEmpty) {
          return null;
        }
        cidLevel = value['cid_level'] as String;
      } else {
        final account = row.accountId;
        if (account == null || !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(account)) {
          return null;
        }
        if (value == null) {
          if (row.cidNumber.isNotEmpty) return null;
        } else {
          const fields = {'bind_rev', 'voting_identity', 'candidate_identity'};
          if (value is! Map<String, dynamic> ||
              row.cidNumber.isEmpty ||
              value.length != fields.length ||
              !value.keys.every(fields.contains)) {
            return null;
          }
          final version = value['bind_rev'];
          if (version is! int || version <= 0) return null;
          Uint8List? bytes(String field) {
            final input = value[field];
            if (input == null) return null;
            if (input is! List ||
                input.any((v) => v is! int || v < 0 || v > 255)) {
              throw const FormatException('身份展示数据损坏');
            }
            return Uint8List.fromList(input.cast<int>());
          }

          final voting = bytes('voting_identity');
          final candidate = bytes('candidate_identity');
          if ((voting != null &&
                  !CitizenIdentityChainReader.votingIdentityLayoutIsValid(
                    voting,
                  )) ||
              (candidate != null &&
                  (voting == null ||
                      !CitizenIdentityChainReader.candidateIdentityLayoutIsValid(
                        candidate,
                      )))) {
            return null;
          }
          identity = CitizenIdentityChainSnapshot(
            cidNumber: row.cidNumber,
            accountId: Uint8List.fromList([
              for (var i = 2; i < account.length; i += 2)
                int.parse(account.substring(i, i + 2), radix: 16),
            ]),
            bindRev: version,
            votingIdentity: voting,
            candidateIdentity: candidate,
          );
        }
        cidLevel = identity?.votingIdentity == null
            ? 'visitor'
            : identity?.candidateIdentity == null
            ? 'voting'
            : 'candidate';
      }
      return IdentityBadgeSnapshot(
        cidNumber: row.cidNumber,
        cidLevel: cidLevel,
        updatedAt: row.updatedAt,
        accountId: row.accountId,
        identity: identity,
        verified: row.accountId != null,
      );
    } on FormatException {
      // 缓存损坏只表示未知，读取不得清库、查链或冒充未注册。
      return null;
    }
  }

  /// 徽章生产者写入同一行；已有完整身份不能被局部徽章覆盖。
  Future<void> write({
    required String cidNumber,
    required String cidLevel,
  }) async {
    final cid = cidNumber.trim();
    if (cid.isEmpty || !_allowedLevels.contains(cidLevel)) {
      throw ArgumentError('公民号或身份档无效');
    }
    await UserIsar.instance.writeTxn((isar) async {
      final collection = isar.collection<user_store.Identity>();
      final existing = await collection
          .filter()
          .cidNumberEqualTo(cid)
          .findFirst();
      if (existing?.accountId != null) return;
      final row = existing ?? user_store.Identity();
      row
        ..cidNumber = cid
        ..identityData = jsonEncode({'cid_level': cidLevel})
        ..updatedAt = _nowProvider().millisecondsSinceEpoch;
      await collection.put(row);
    });
    revision.value++;
  }

  /// 成功的完整验真是唯一完整快照写入者；无身份也保存账户事实，避免重进后误用旧CID。
  Future<void> writeVerified({
    required String accountId,
    required CitizenIdentityChainSnapshot? identity,
    required bool Function() isCurrent,
  }) async {
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId)) {
      throw ArgumentError('account_id 无效');
    }
    if (identity != null &&
        CitizenIdentityChainReader.hexEncode(identity.accountId) != accountId) {
      throw StateError('身份快照与账户不一致');
    }
    await UserIsar.instance.writeTxn((isar) async {
      if (!isCurrent()) throw StateError('身份上下文已变化');
      final rows = isar.collection<user_store.Identity>();
      final row =
          await rows.filter().accountIdEqualTo(accountId).findFirst() ??
          user_store.Identity();
      // 同一个CID的旧账户或旧徽章一并收敛；保留旧账户已失去绑定的事实，禁止双重归属。
      if (identity != null) {
        final previous = await rows
            .filter()
            .cidNumberEqualTo(identity.cidNumber)
            .findAll();
        for (final old in previous) {
          final known = _decode(old)?.identity;
          if (known != null &&
              (known.bindRev > identity.bindRev ||
                  (known.bindRev == identity.bindRev &&
                      old.accountId != accountId))) {
            throw StateError('身份绑定版本禁止回退或改写');
          }
          if (old.rowId == row.rowId) continue;
          if (old.accountId == null) {
            await rows.delete(old.rowId);
          } else {
            old
              ..cidNumber = ''
              ..identityData = 'null'
              ..updatedAt = _nowProvider().millisecondsSinceEpoch;
            await rows.put(old);
          }
        }
      }
      row
        ..accountId = accountId
        ..cidNumber = identity?.cidNumber ?? ''
        ..identityData = jsonEncode(
          identity == null
              ? null
              : {
                  'bind_rev': identity.bindRev,
                  'voting_identity': identity.votingIdentity?.toList(),
                  'candidate_identity': identity.candidateIdentity?.toList(),
                },
        )
        ..updatedAt = _nowProvider().millisecondsSinceEpoch;
      if (!isCurrent()) throw StateError('身份上下文已变化');
      await rows.put(row);
    });
    revision.value++;
  }

  Future<void> remove(String cidNumber) async {
    final cid = cidNumber.trim();
    if (cid.isEmpty) return;
    await UserIsar.instance.writeTxn((isar) async {
      await isar
          .collection<user_store.Identity>()
          .filter()
          .cidNumberEqualTo(cid)
          .deleteAll();
    });
    revision.value++;
  }
}
