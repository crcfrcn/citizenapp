// 个人状态快照、名称、提案持久化及缓存。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:async';
import 'dart:convert';
import 'members.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store;
import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:isar_community/isar.dart';
import 'proposals.dart';

// 按账户持久化个人多签状态、详情及已有名称。

/// 按规范账户ID批量读已有名称；空集合不访问数据库，不查链或生成占位名称。
Future<Map<String, String>> readMultisigNames(
  Iterable<String> accountIds,
) async {
  final ids = accountIds.toSet().toList(growable: false);
  if (ids.isEmpty) return const {};
  if (ids.any((id) => !isCitizenAccountId(id))) {
    throw const FormatException('个人多签名称查询需要规范account_id');
  }
  return UserIsar.instance.read((isar) async {
    final rows = await isar.accounts.getAllByAccountId(ids);
    return {
      for (final row in rows)
        if (row != null && row.accountName.trim().isNotEmpty)
          row.accountId: row.accountName,
    };
  });
}

// 个人多签业务快照归本包，存储包提供原实体和事务。
/// 多签账户本地状态快照。
///
/// groupState负责UI展示，syncedAt负责判断是否需要再次查链。
class MultisigLocalStatusSnapshot {
  const MultisigLocalStatusSnapshot({
    required this.groupState,
    required this.syncedAt,
  });

  final String groupState;
  final int? syncedAt;
}

/// 多签详情页本地持久化快照。
///
/// 这不是短期内存缓存，而是详情页首屏可直接使用的本机状态。
/// 链上刷新成功后覆盖写入；链上失败时保留旧值，避免进详情页被 RPC 卡住。
class MultisigLocalDetailSnapshot {
  const MultisigLocalDetailSnapshot({
    required this.groupState,
    required this.admins,
    this.threshold,
    this.syncedAt,
  });

  final String groupState;
  final List<PersonalMember> admins;
  final int? threshold;
  final int? syncedAt;

  Map<String, dynamic> toJson() => {
    'group_state': groupState,
    'admins': admins
        .map(
          (admin) => {
            'account_id': admin.accountId,
            'family_name': admin.familyName,
            'given_name': admin.givenName,
          },
        )
        .toList(growable: false),
    'threshold': threshold,
    'synced_at': syncedAt,
  };

  static MultisigLocalDetailSnapshot? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final adminRaw = decoded['admins'];
      if (adminRaw is! List) return null;
      final admins = <PersonalMember>[];
      final accountIds = <String>{};
      for (final item in adminRaw) {
        if (item is! Map ||
            item.length != 3 ||
            item.keys.any(
              (key) => !const {
                'account_id',
                'family_name',
                'given_name',
              }.contains(key),
            )) {
          return null;
        }
        final accountId = item['account_id'];
        final familyName = item['family_name'];
        final givenName = item['given_name'];
        if (accountId is! String ||
            familyName is! String ||
            givenName is! String ||
            accountId.isEmpty ||
            familyName.isEmpty ||
            givenName.isEmpty ||
            !isCitizenAccountId(accountId) ||
            !accountIds.add(accountId)) {
          return null;
        }
        admins.add(
          PersonalMember(
            accountId: accountId,
            familyName: familyName,
            givenName: givenName,
          ),
        );
      }
      final groupState = decoded['group_state']?.toString();
      if (groupState == null || groupState.isEmpty) return null;
      return MultisigLocalDetailSnapshot(
        groupState: groupState,
        admins: admins,
        threshold: _toInt(decoded['threshold']),
        syncedAt: _toInt(decoded['synced_at']),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// 个人多签本地生命周期状态。
///
/// 链上注销后账户主体可能已经不存在，但用户本机仍要在账户列表
/// 显示“已注销”，直到用户主动点“删除”清空本地数据。
class PersonalMultisigLocalState {
  static const statusPending = 'pending';
  static const statusActive = 'active';
  static const statusClosed = 'closed';

  static Future<Map<String, String>> readStatuses(
    Isar isar,
    Iterable<String> personalAccountIds,
  ) async {
    final snapshots = await readStatusSnapshots(isar, personalAccountIds);
    return snapshots.map((key, value) => MapEntry(key, value.groupState));
  }

  static Future<Map<String, MultisigLocalStatusSnapshot>> readStatusSnapshots(
    Isar isar,
    Iterable<String> personalAccountIds,
  ) async {
    final result = <String, MultisigLocalStatusSnapshot>{};
    for (final accountId in personalAccountIds) {
      final normalizedAccountId = _requireAccountId(accountId);
      final entity = await isar.groups.getByAccountId(normalizedAccountId);
      final groupState = entity?.groupState;
      if (groupState != null && groupState.isNotEmpty) {
        result[normalizedAccountId] = MultisigLocalStatusSnapshot(
          groupState: groupState,
          syncedAt: entity?.syncedAt,
        );
      }
    }
    return result;
  }

  static Future<MultisigLocalDetailSnapshot?> readDetail(
    Isar isar,
    String accountId,
  ) async {
    final entity = await isar.groups.getByAccountId(
      _requireAccountId(accountId),
    );
    return MultisigLocalDetailSnapshot.fromJsonString(entity?.detailData);
  }

  /// 写入个人多签详情快照；调用方必须处在 Isar writeTxn 内。
  static Future<void> putDetailInTxn(
    Isar isar,
    String accountId,
    MultisigLocalDetailSnapshot snapshot,
  ) async {
    _requireAccountId(accountId);
    final entity =
        await isar.groups.getByAccountId(accountId) ??
        (wallet_store.Group()..accountId = accountId);
    entity.detailData = jsonEncode(snapshot.toJson());
    await isar.groups.putByAccountId(entity);
  }

  /// 写入个人多签本地状态；调用方必须处在 Isar writeTxn 内。
  static Future<void> putStatusInTxn(
    Isar isar,
    String accountId,
    String groupState,
  ) async {
    _requireAccountId(accountId);
    final entity =
        await isar.groups.getByAccountId(accountId) ??
        (wallet_store.Group()..accountId = accountId);
    entity
      ..groupState = groupState
      ..syncedAt = DateTime.now().millisecondsSinceEpoch;
    await isar.groups.putByAccountId(entity);
  }

  /// 删除个人多签本地状态；调用方必须处在 Isar writeTxn 内。
  static Future<void> deleteStatusInTxn(Isar isar, String accountId) async {
    _requireAccountId(accountId);
    final entity = await isar.groups.getByAccountId(accountId);
    if (entity == null) return;
    entity
      ..groupState = null
      ..syncedAt = null;
    if (entity.detailData == null) {
      await isar.groups.delete(entity.rowId);
    } else {
      await isar.groups.put(entity);
    }
  }

  /// 删除个人多签详情快照；调用方必须处在 Isar writeTxn 内。
  static Future<void> deleteDetailInTxn(Isar isar, String accountId) async {
    _requireAccountId(accountId);
    final entity = await isar.groups.getByAccountId(accountId);
    if (entity == null) return;
    entity.detailData = null;
    if (entity.groupState == null) {
      await isar.groups.delete(entity.rowId);
    } else {
      await isar.groups.put(entity);
    }
  }

  static String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}

// 从本地已同步提案反查指定账户的待激活创建提案。

// 个人多签待激活创建提案反查(req 2 依赖)。
//
// 数据源选择:Isar 而非链上 state_getKeys。
//
// 详情页 mount 时已经通过 `PersonalProposalHistoryService.fetchAll` 把链上活跃提案
// 同步到 Isar。因此从详情页跳转进入管理员子页时,Isar 必然已包含该多签
// 当前活跃创建提案的 entity(若存在),无需再次调链上 prefix iteration。
//
// 这避免了无边界整表扫描，并且查询成本是
// O(1) 级 Isar 索引读取。

class PersonalPendingCreateLookup {
  /// 查找该地址当前在投票中的创建提案 ID。
  ///
  /// 返回 null 表示无活跃创建提案 — 可能因为:
  /// 1. 多签已激活(创建提案已 EXECUTED,Account 已转 Active);
  /// 2. 创建提案被否决(Account 已删除);
  /// 3. 详情页未触发过历史服务同步,Isar 尚未填充(异常态,管理员子页应回退提示)。
  Future<BigInt?> findActiveCreate(String accountId) async {
    final entity = await UserIsar.instance.read((isar) {
      return isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .actionKindEqualTo(PersonalProposalAction.create)
          .proposalStateEqualTo(PersonalProposalStatus.voting)
          .findFirst();
    });
    return entity?.proposalId;
  }
}
