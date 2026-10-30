import 'package:citizen_network/citizen_serve_api_config.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_account/identity/mls_authentication.dart';

import 'package:citizen_account/identity/registration_models.dart';

/// CAS后必须读回同一完整记录；写失败时任何后继签名/上链均被阻断。
class RegistrationStore {
  RegistrationStore({SystemProtectedRecordStore? records})
    : _records = records ?? SystemProtectedRecordStore.registration;
  final SystemProtectedRecordStore _records;
  Future<RegistrationRecord?> read(RegistrationContext context) async {
    final raw = await _records.read(context.contextHash);
    return raw == null ? null : _readRecord(context.contextHash, raw);
  }

  /// 只读解码当前完整记录；失败保留原值，不能在读取时升级或改写。
  RegistrationRecord _readRecord(String key, String raw) {
    final record = RegistrationRecord.decode(raw);
    if (record.context.contextHash != key) throw StateError('登记恢复记录归属不一致');
    return record;
  }

  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (previous != null &&
        (previous.context.contextHash != next.context.contextHash ||
            (previous.capabilities.regId != next.capabilities.regId &&
                previous.response.jobState != RegistrationState.expired &&
                previous.response.jobState != RegistrationState.cancelled))) {
      throw StateError('登记记录不可换属主');
    }
    final value = next.encode();
    // 写入前同样执行恢复白名单校验，禁止额外秘密字段进入系统记录。
    RegistrationRecord.decode(value);
    if (!await _records.compareAndSet(
          next.context.contextHash,
          expected: previous?.encode(),
          next: value,
        ) ||
        await _records.read(next.context.contextHash) != value) {
      throw StateError('登记恢复记录未持久保存');
    }
  }

  Future<RegistrationCapabilities?> forDevice(
    MlsAuthenticationIdentity identity, {
    required String chainScope,
  }) async {
    final matches = <RegistrationRecord>[];
    for (final entry in (await _records.readAll()).entries) {
      final record = _readRecord(entry.key, entry.value);
      final binding = record.finalized?.binding;
      if (record.context.baseUrl == identityServiceBase &&
          record.context.chainScope == chainScope &&
          record.context.regScope == CitizenServeApiConfig.registrationScope &&
          binding?.cidNumber == identity.cidNumber &&
          binding?.accountId == identity.accountId &&
          binding?.bindRev == identity.bindRev &&
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
      final record = _readRecord(entry.key, entry.value);
      if (record.context.baseUrl == identityServiceBase &&
          record.context.regScope == CitizenServeApiConfig.registrationScope &&
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
