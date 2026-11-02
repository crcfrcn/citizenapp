import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_account/identity/registration_models.dart';

/// 原子保存真实链交易事实；复用原保护通道，不处理任何服务端登记能力。
class RegistrationStore {
  RegistrationStore({SystemProtectedRecordStore? records})
    : _records = records ?? SystemProtectedRecordStore.registration;
  final SystemProtectedRecordStore _records;
  Future<RegistrationRecord?> read(RegistrationContext context) async {
    final raw = await _records.read(context.recordKey);
    if (raw == null) return null;
    final record = RegistrationRecord.decode(raw);
    if (record.context.recordKey != context.recordKey) {
      throw StateError('链交易记录归属不一致');
    }
    return record;
  }

  Future<void> save(
    RegistrationRecord? previous,
    RegistrationRecord next,
  ) async {
    if (previous != null &&
        previous.context.recordKey != next.context.recordKey) {
      throw StateError('链交易记录不可换属主');
    }
    final value = next.encode();
    RegistrationRecord.decode(value);
    if (!await _records.compareAndSet(
          next.context.recordKey,
          expected: previous?.encode(),
          next: value,
        ) ||
        await _records.read(next.context.recordKey) != value) {
      throw StateError('链交易检查点未保存');
    }
  }
}
