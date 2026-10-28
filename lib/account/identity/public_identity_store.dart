import 'dart:convert';

import 'identity_binding.dart';
import '../../system/security/system_protected_storage.dart';

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

/// 同绑定只保存当前实际设备回执；替换必须CAS，旧设备签名不能用于新公钥。
String deviceRegistrationProofKey(
  String cidNumber,
  int revision,
  String accountId,
) => 'mls.registration:${Uri.encodeComponent(cidNumber)}:$revision:$accountId';

/// 同一严格六字段解码供登记及尝试归属核对复用，损坏记录不授予重新签署。
Map<String, dynamic> decodeDeviceRegistrationProof(
  String raw, {
  required String cidNumber,
  required int bindRev,
  required String accountId,
}) {
  final proof = jsonDecode(raw);
  const fields = {
    'cid_number',
    'bind_rev',
    'account_id',
    'public_key',
    'issued_at',
    'signature',
  };
  if (proof is! Map<String, dynamic> ||
      proof.length != fields.length ||
      !proof.keys.every(fields.contains) ||
      proof['cid_number'] != cidNumber ||
      proof['bind_rev'] != bindRev ||
      proof['account_id'] != accountId ||
      proof['public_key'] is! String ||
      !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(proof['public_key']) ||
      proof['issued_at'] is! int ||
      proof['issued_at'] <= 0 ||
      proof['issued_at'] > 9007199254740991 ||
      proof['signature'] is! String ||
      !RegExp(r'^0x[0-9a-f]{128}$').hasMatch(proof['signature'])) {
    throw const FormatException();
  }
  return proof;
}

/// 所有CID公开绑定在同一个原子数组中提交；CID不再同时出现在对象键和正文。
final class PublicIdentityStore {
  PublicIdentityStore(this._records);
  final PublicIdentityRecordStore _records;
  static const _bindings = 'identity.bindings';
  static Map<String, IdentityBinding> _decode(String? raw) {
    if (raw == null) return {};
    final value = jsonDecode(raw);
    if (value is! List) throw const FormatException('公开绑定记录损坏');
    final result = <String, IdentityBinding>{};
    for (final item in value) {
      final binding = IdentityBinding.fromJson(jsonEncode(item));
      if (binding == null || result.containsKey(binding.cidNumber)) {
        throw const FormatException('公开绑定属主不一致');
      }
      result[binding.cidNumber] = binding;
    }
    return result;
  }

  Future<Map<String, IdentityBinding>> _read() async =>
      _decode(await _records.read(_bindings));

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
  Future<void> _update(
    void Function(Map<String, IdentityBinding>) mutate,
  ) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final raw = await _records.read(_bindings);
      final decoded = _decode(raw);
      mutate(decoded);
      if (await _records.compareAndSet(
        _bindings,
        expected: raw,
        next: jsonEncode(decoded.values.map((b) => b.toJson()).toList()),
      )) {
        return;
      }
    }
    throw StateError('公开绑定并发提交失败');
  }

  Future<void> activate(IdentityBinding next) async {
    next.validate();
    await _update((values) {
      final current = values[next.cidNumber];
      if (current != null) {
        if (current.genesisHash != next.genesisHash ||
            current.bindRev > next.bindRev ||
            (current.bindRev == next.bindRev &&
                current.accountId != next.accountId)) {
          throw StateError('公开绑定版本或链不一致');
        }
      }
      values[next.cidNumber] = next;
    });
  }

  Future<void> clearForCid(String cid) => _update((values) {
    values.remove(cid);
  });
}
