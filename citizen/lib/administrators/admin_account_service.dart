import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/administrators/admin_account_storage_codec.dart';
import 'package:citizen_citizen/administrators/admin_account_codec.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';

/// 分类管理员链读门面。
///
/// 机构严格读取 `AdminAccounts[cid_number]` 与对应 entity 的
/// `InstitutionGovernanceThresholds[cid_number]`；个人多签严格读取
/// `AdminAccounts[personal_account]` 与 `ActivePersonalThresholds[personal_account]`。
class AdminAccountService {
  AdminAccountService({
    CitizenSdk? chain,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
  }) : _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext = getRuntimeContext ?? chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, _AdminAccountCacheEntry> _cache = {};
  static final Map<String, Future<AdminAccountState?>> _inFlight = {};
  static final Map<String, Future<_AdminAccountCacheEntry?>> _accountReads = {};

  Future<AdminAccountState?> fetchByIdentity(
    AdminAccountIdentity identity,
  ) async {
    final cacheKey = identity.identityKey;
    final cached = _cache[cacheKey];
    if (cached != null && cached.isFresh(_cacheTtl) && cached.thresholdLoaded) {
      return cached.state;
    }
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final future = _fetchUncached(identity);
    _inFlight[cacheKey] = future;
    return future.whenComplete(() {
      if (_inFlight[cacheKey] == future) _inFlight.remove(cacheKey);
    });
  }

  Future<AdminAccountState?> _fetchUncached(
    AdminAccountIdentity identity,
  ) async {
    final account = await _loadAccount(identity);
    if (account == null) return null;
    // 完整权限仍要求同一 finalized 块的阈值读取成功，失败不把名册当权限快照。
    final threshold = await _resolveThreshold(identity, account.runtime);
    account.state = account.state.copyWith(threshold: threshold ?? 0);
    account.thresholdLoaded = true;
    return account.state;
  }

  Future<_AdminAccountCacheEntry?> _loadAccount(AdminAccountIdentity identity) {
    final key = identity.identityKey;
    final cached = _cache[key];
    if (cached != null && cached.isFresh(_cacheTtl)) {
      return Future.value(cached);
    }
    final existing = _accountReads[key];
    if (existing != null) return existing;
    late final Future<_AdminAccountCacheEntry?> pending;
    pending = _readAccount(identity)
        .then((account) {
          // clearCache之后的迟到读取不重新填入已作废的缓存。
          if (account != null && identical(_accountReads[key], pending)) {
            _cache[key] = account;
          }
          return account;
        })
        .whenComplete(() {
          if (identical(_accountReads[key], pending)) _accountReads.remove(key);
        });
    _accountReads[key] = pending;
    return pending;
  }

  /// 人员和完整状态共用唯一整键读取与公开解码；不复制机构/个人布局。
  Future<_AdminAccountCacheEntry?> _readAccount(
    AdminAccountIdentity identity,
  ) async {
    final finalized = await _getFinalizedHead();
    final runtime = await _getRuntimeContext(finalized);
    final Uint8List key;
    if (identity.type == AdminAccountIdentityType.institution) {
      key = AdminAccountStorageCodec.institutionAdminStorageKey(
        identity.cidNumber!,
        runtime: runtime,
        orgCode: identity.orgCode,
        adminKind: identity.kind,
      );
    } else {
      key = AdminAccountStorageCodec.personalAdminStorageKey(
        citizenAccountIdBytes(identity.accountId!),
        runtime: runtime,
      );
    }
    final data = await _getStorage(finalized, key);
    if (data == null) return null;
    final decoded = identity.type == AdminAccountIdentityType.institution
        ? AdminAccountCodec.decodeInstitution(
            cidNumber: identity.cidNumber!,
            data: data,
            institutionKind: identity.kind,
          )
        : AdminAccountCodec.decodePersonal(
            citizenAccountIdBytes(identity.accountId!),
            data,
          );
    if (decoded == null) throw const FormatException('管理员人员记录无效');
    return _AdminAccountCacheEntry(decoded, runtime);
  }

  /// 名册只消费人员；阈值失败不会丢弃同一缓存中已核实的人员集合。
  Future<List<AdminPerson>> fetchAdmins(AdminAccountIdentity identity) async =>
      (await _loadAccount(identity))?.state.admins ?? const [];

  Future<int?> fetchThreshold(AdminAccountIdentity identity) async =>
      (await fetchByIdentity(identity))?.threshold;

  Future<bool> isAdmin(String accountId, AdminAccountIdentity identity) async {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('管理员账户标识无效');
    }
    // 此入口仍是完整状态门禁，不能因只读名册解耦而跳过阈值故障。
    return ((await fetchByIdentity(identity))?.admins ?? const <AdminPerson>[])
        .any((admin) => admin.accountId == accountId);
  }

  void clearCache([AdminAccountIdentity? identity]) {
    if (identity == null) {
      _cache.clear();
      _inFlight.clear();
      _accountReads.clear();
      return;
    }
    _cache.remove(identity.identityKey);
    _inFlight.remove(identity.identityKey);
    _accountReads.remove(identity.identityKey);
  }

  void clearPersonalAccountCache(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('管理员账户标识无效');
    }
    final key = 'personal-account:$accountId';
    _cache.remove(key);
    _inFlight.remove(key);
    _accountReads.remove(key);
  }

  Future<int?> _resolveThreshold(
    AdminAccountIdentity identity,
    CitizenRuntimeContext runtime,
  ) async {
    if (identity.type == AdminAccountIdentityType.institution) {
      return _fetchThresholdStorage(
        palletName: identity.kind == 1 ? 'PrivateManage' : 'PublicManage',
        storageName: 'InstitutionGovernanceThresholds',
        runtime: runtime,
        keyData: Uint8List.fromList(utf8.encode(identity.cidNumber!)),
      );
    }
    return _fetchThresholdStorage(
      palletName: 'InternalVote',
      storageName: 'ActivePersonalThresholds',
      runtime: runtime,
      keyData: citizenAccountIdBytes(identity.accountId!),
    );
  }

  Future<int?> _fetchThresholdStorage({
    required String palletName,
    required String storageName,
    required Uint8List keyData,
    required CitizenRuntimeContext runtime,
  }) async {
    final key = runtime.storageKey(palletName, storageName, [keyData]);
    final data = await _getStorage(runtime.block, key);
    if (data == null || data.length != 4) return null;
    return CitizenScale.readUnsigned(data, 0, 4).toInt();
  }
}

class _AdminAccountCacheEntry {
  _AdminAccountCacheEntry(this.state, this.runtime)
    : createdAt = DateTime.now();

  AdminAccountState state;
  final CitizenRuntimeContext runtime;
  bool thresholdLoaded = false;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}
