import 'dart:convert';
import 'identity_binding.dart';
import 'system_protected_storage.dart';

/// 这里只允许公开绑定和钱包授权签名回执；不是秘密或密钥存储。
abstract interface class PublicIdentityRecordStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  });
}

final class SystemPublicIdentityRecordStore
    implements PublicIdentityRecordStore {
  SystemPublicIdentityRecordStore([SystemProtectedRecordStore? records])
    : _records = records ?? SystemProtectedRecordStore.identity;
  final SystemProtectedRecordStore _records;
  @override
  Future<String?> read(String key) => _records.read(key);
  @override
  Future<void> write(String key, String value) => _records.write(key, value);
  @override
  Future<void> delete(String key) => _records.delete(key);
  @override
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) => _records.compareAndSet(key, expected: expected, next: next);
}

String deviceRegistrationProofKey(
  String cidNumber,
  int revision,
  String accountId,
) => 'mls.registration:${Uri.encodeComponent(cidNumber)}:$revision:$accountId';

/// 所有CID公开绑定在同一个原子记录中提交，版本不回退且不借用活动钱包指针。
final class PublicIdentityStore {
  PublicIdentityStore(this._records);
  final PublicIdentityRecordStore _records;
  static const _bindings = 'identity.bindings';
  Future<Map<String, IdentityBinding>> _read() async {
    final raw = await _records.read(_bindings);
    if (raw == null) return {};
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) throw const FormatException('公开绑定记录损坏');
    final result = <String, IdentityBinding>{};
    for (final entry in value.entries) {
      final binding = IdentityBinding.fromJson(jsonEncode(entry.value));
      if (binding == null || entry.key != binding.cidNumber) {
        throw const FormatException('公开绑定属主不一致');
      }
      result[entry.key] = binding;
    }
    return result;
  }

  Future<IdentityBinding?> readForCid(String cid) async => (await _read())[cid];
  Future<IdentityBinding?> readForAccountId(String accountId) async {
    final values = (await _read()).values
        .where((b) => b.accountId == accountId)
        .toList();
    if (values.length > 1) throw StateError('账户绑定多个CID');
    return values.isEmpty ? null : values.single;
  }

  Future<List<IdentityBinding>> readAll() async =>
      (await _read()).values.toList(growable: false);
  Future<void> _update(void Function(Map<String, dynamic>) mutate) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final raw = await _records.read(_bindings);
      final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('公开绑定记录损坏');
      }
      for (final e in decoded.entries) {
        final b = IdentityBinding.fromJson(jsonEncode(e.value));
        if (b == null || b.cidNumber != e.key) {
          throw const FormatException('公开绑定记录损坏');
        }
      }
      mutate(decoded);
      if (await _records.compareAndSet(
        _bindings,
        expected: raw,
        next: jsonEncode(decoded),
      )) {
        return;
      }
    }
    throw StateError('公开绑定并发提交失败');
  }

  Future<void> activate(IdentityBinding next) async {
    next.validate();
    await _update((values) {
      final value = values[next.cidNumber];
      if (value != null) {
        final current = IdentityBinding.fromJson(jsonEncode(value))!;
        if (current.genesisHash != next.genesisHash ||
            current.bindingRevision > next.bindingRevision ||
            (current.bindingRevision == next.bindingRevision &&
                current.accountId != next.accountId)) {
          throw StateError('公开绑定版本或链不一致');
        }
      }
      values[next.cidNumber] = next.toJson();
    });
  }

  Future<void> clearForCid(String cid) => _update((values) {
    values.remove(cid);
  });
}
