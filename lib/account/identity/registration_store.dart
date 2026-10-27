import 'package:citizenapp/network/citizen_serve_api_config.dart';
import 'package:citizenapp/system/security/system_protected_storage.dart';
import 'package:citizenapp/account/identity/mls_authentication.dart';

import 'registration_models.dart';

/// CAS后必须读回同一完整记录；写失败时任何后继签名/上链均被阻断。
class RegistrationStore {
  RegistrationStore({SystemProtectedRecordStore? records})
    : _records = records ?? SystemProtectedRecordStore.registration;
  final SystemProtectedRecordStore _records;
  Future<RegistrationRecord?> read(RegistrationContext context) async {
    final raw = await _records.read(context.hash);
    final record = raw == null ? null : await _readRecord(context.hash, raw);
    if (record != null && record.context.hash != context.hash) {
      throw const FormatException('登记恢复上下文不一致');
    }
    return record;
  }

  /// 完整旧快照CAS成功并准确读回后才允许后续签名或链恢复。
  Future<RegistrationRecord> _readRecord(String key, String raw) async {
    final upgraded = RegistrationRecord.upgrade(raw);
    final record = RegistrationRecord.decode(upgraded);
    if (record.context.hash != key) throw StateError('登记恢复记录归属不一致');
    if (upgraded != raw &&
        (!await _records.compareAndSet(key, expected: raw, next: upgraded) ||
            await _records.read(key) != upgraded)) {
      throw StateError('登记恢复记录升级未确认，原操作未继续');
    }
    return record;
  }

  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (previous != null &&
        (previous.context.hash != next.context.hash ||
            (previous.capabilities.enrollmentId !=
                    next.capabilities.enrollmentId &&
                previous.response.jobState != RegistrationState.expired &&
                previous.response.jobState != RegistrationState.cancelled))) {
      throw StateError('登记记录不可换属主');
    }
    final value = next.encode();
    // 写入前同样执行恢复白名单校验，禁止额外秘密字段进入系统记录。
    RegistrationRecord.decode(value);
    if (!await _records.compareAndSet(
          next.context.hash,
          expected: previous?.encode(),
          next: value,
        ) ||
        await _records.read(next.context.hash) != value) {
      throw StateError('登记恢复记录未持久保存');
    }
  }

  Future<RegistrationCapabilities?> forDevice(
    MlsAuthenticationIdentity identity, {
    required String chainScope,
  }) async {
    final matches = <RegistrationRecord>[];
    for (final entry in (await _records.readAll()).entries) {
      final record = await _readRecord(entry.key, entry.value);
      final binding = record.finalized?.binding;
      if (record.context.baseUrl == identityServiceBase &&
          record.context.chainScope == chainScope &&
          record.context.registrationScope ==
              CitizenServeApiConfig.registrationScope &&
          binding?.cidNumber == identity.cidNumber &&
          binding?.accountId == identity.accountId &&
          binding?.bindingRevision == identity.bindingRevision &&
          record.response.jobState == RegistrationState.humanVerified &&
          record.phase != RegistrationPhase.ready &&
          registrationInt(record.response.json, 'expires_at') >
              DateTime.now().millisecondsSinceEpoch) {
        matches.add(record);
      }
    }
    if (matches.length > 1) throw StateError('设备登记能力上下文不唯一');
    return matches.isEmpty ? null : matches.single.capabilities;
  }

  /// 只判断本机是否有同链同账户的未完成流程，不授予业务权限。
  Future<bool> hasPendingAccount(String accountId, String chainScope) async {
    for (final entry in (await _records.readAll()).entries) {
      final record = await _readRecord(entry.key, entry.value);
      if (record.context.baseUrl == identityServiceBase &&
          record.context.registrationScope ==
              CitizenServeApiConfig.registrationScope &&
          record.context.chainScope == chainScope &&
          record.context.accountId == accountId &&
          record.phase != RegistrationPhase.ready) {
        return true;
      }
    }
    return false;
  }

  String get identityServiceBase => CitizenServeApiConfig.baseUrl;
}
