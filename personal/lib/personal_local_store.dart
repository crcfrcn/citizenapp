import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/account_derivation.dart';

// 个人多签业务快照由交易包拥有，存储包只提供原实体和事务。
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
  final List<AdminPerson> admins;
  final int? threshold;
  final int? syncedAt;

  Map<String, dynamic> toJson() => {
    'group_state': groupState,
    'admins': admins
        .map(
          (admin) => {
            'account_id': admin.accountId,
            'cid_number': admin.cidNumber,
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
      final admins = <AdminPerson>[];
      final accountIds = <String>{};
      for (final item in adminRaw) {
        if (item is! Map) return null;
        final accountId = item['account_id'];
        final cidNumber = item['cid_number'];
        final familyName = item['family_name'];
        final givenName = item['given_name'];
        if (accountId is! String ||
            cidNumber is! String ||
            familyName is! String ||
            givenName is! String ||
            accountId.isEmpty ||
            familyName.isEmpty ||
            givenName.isEmpty ||
            !isAccountIdText(accountId) ||
            !accountIds.add(accountId)) {
          return null;
        }
        admins.add(
          AdminPerson(
            accountId: accountId,
            cidNumber: cidNumber,
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
        (Group()..accountId = accountId);
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
        (Group()..accountId = accountId);
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
    if (!isAccountIdText(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}

