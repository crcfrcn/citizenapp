// 协调公开身份存储、设备授权、账户切换及所属记录清理。

import 'package:citizen_scanner/sign.dart' show PayloadSigner;
import 'package:citizen_system/security/access.dart';
import 'dart:convert';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:citizen_network/auth.dart';
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_system/security/storage.dart';
import 'package:citizen_wallet/history/store.dart' show LocalTxStore;
import 'package:citizen_offchain/bank.dart' show ClearingBankPrefs;
import 'package:citizen_offchain/rpc.dart' show ClearingBalances;

// 协调公开身份、换绑后的服务端同步、MLS设备授权及所属记录清理。

typedef AccountMlsDeviceRegistrar =
    Future<void> Function({
      required String cidNumber,
      required int bindRev,
      required String accountId,
      required Future<String> Function({
        required Uint8List payload,
        required Uint8List signingMessage,
        required String publicKey,
        required int issuedAtMillis,
      })
      signBinding,
    });
typedef ColdMlsDeviceBindingSigner =
    Future<String> Function({
      required IdentityBinding binding,
      required Uint8List payload,
      required Uint8List signingMessage,
      required String publicKey,
      required int issuedAtMillis,
    });

/// 协调公开身份、MLS设备绑定同步与所属记录清理；钱包能力仍归CitizenSDK。
interface class AccountSecurityService {
  AccountSecurityService({
    CitizenSdk? wallet,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    CitizenSdk? signing,
    PayloadSigner? payloadSigner,
    required AccountMlsDeviceRegistrar mlsDeviceRegistrar,
    required ColdMlsDeviceBindingSigner coldMlsDeviceBindingSigner,
    PublicIdentityRecordStore? blobStore,
  }) : _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState')),
       _signing = signing ?? wallet,
       _payloadSigner = payloadSigner,
       _mlsDeviceRegistrar = mlsDeviceRegistrar,
       _coldMlsDeviceBindingSigner = coldMlsDeviceBindingSigner,
       _records = blobStore ?? SystemPublicIdentityRecordStore() {
    _bindings = PublicIdentityStore(_records);
  }
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;
  final CitizenSdk? _signing;
  final PayloadSigner? _payloadSigner;
  final AccountMlsDeviceRegistrar _mlsDeviceRegistrar;
  final ColdMlsDeviceBindingSigner _coldMlsDeviceBindingSigner;
  final PublicIdentityRecordStore _records;
  late final PublicIdentityStore _bindings;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, Future<void>> _registrationFlights = {};
  static const _pendingCleanup = 'identity.account_cleanup';

  void notifyIdentityBindingChanged() => revision.value++;
  void notifyDefaultAccountChanged() => revision.value++;
  Future<CitizenWalletStateAccount?> _account(String accountId) async {
    for (final account in (await _getWalletState().result).accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }

  /// 完整公开同步可延后通知，待绑定和展示均收尾后由调用方统一广播一次。
  Future<void> activateIdentityBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindRev,
    required String accountId,
    bool notify = true,
  }) async {
    final next = IdentityBinding(
      genesisHash: genesisHash,
      cidNumber: cidNumber,
      bindRev: bindRev,
      accountId: accountId,
    );
    next.validate();
    if (await _account(accountId) == null) {
      throw const AccountSecurityException('当前绑定账户不在本机钱包中');
    }
    final old = await _bindings.readForCid(cidNumber);
    if (old != null && jsonEncode(old.toJson()) == jsonEncode(next.toJson())) {
      return;
    }
    await _bindings.activate(next);
    if (notify) notifyIdentityBindingChanged();
  }

  Future<IdentityBinding?> readIdentityBindingForCid(String cid) =>
      _bindings.readForCid(cid);
  Future<IdentityBinding?> readIdentityBindingForAccountId(String accountId) =>
      _bindings.readForAccountId(accountId);
  Future<IdentityBinding> identityBindingForAccountId(String accountId) async {
    final value = await readIdentityBindingForAccountId(accountId);
    if (value == null) throw const AccountSecurityException('当前身份公开绑定尚未确认');
    return value;
  }

  String _owner(IdentityBinding b) => jsonEncode(b.toJson());
  Future<void> _requireCurrent(IdentityBinding binding, int generation) async {
    final current = await _bindings.readForCid(binding.cidNumber);
    if (revision.value != generation ||
        current == null ||
        _owner(current) != _owner(binding) ||
        await _account(binding.accountId) == null) {
      throw const AccountSecurityException(
        '登记期间身份已变化',
        code: 'identityChanged',
      );
    }
  }

  /// 换绑后的同一设备复用既有接口；服务端确认后保存本机完成记录。
  Future<bool> synchronizeMlsBinding(IdentityBinding binding) async {
    try {
      binding.validate();
      final generation = revision.value;
      await _requireCurrent(binding, generation);
      final key = 'mls.binding.sync:${Uri.encodeComponent(binding.cidNumber)}';
      final owner = _owner(binding);
      final previous = await _records.read(key);
      if (previous == owner) return true;
      await registerMlsDeviceForBinding(binding);
      await _requireCurrent(binding, generation);
      if (!await _records.compareAndSet(key, expected: previous, next: owner)) {
        return await _records.read(key) == owner;
      }
      return await _records.read(key) == owner;
    } on Object {
      // 未确认不标记成功；后续完整身份同步复用已保存证明，不增加提示。
      return false;
    }
  }

  /// 明确未登记或已确认换绑时复用；并发请求合并，不派生其他材料。
  Future<void> registerMlsDeviceForBinding(IdentityBinding binding) {
    binding.validate();
    final key = _owner(binding);
    final existing = _registrationFlights[key];
    if (existing != null) return existing;
    late final Future<void> created;
    created = _register(binding).whenComplete(() {
      if (identical(_registrationFlights[key], created)) {
        _registrationFlights.remove(key);
      }
    });
    _registrationFlights[key] = created;
    return created;
  }

  Future<void> _register(IdentityBinding binding) async {
    final generation = revision.value;
    await _requireCurrent(binding, generation);
    final account = (await _account(binding.accountId))!;
    await _mlsDeviceRegistrar(
      cidNumber: binding.cidNumber,
      bindRev: binding.bindRev,
      accountId: binding.accountId,
      signBinding:
          ({
            required payload,
            required signingMessage,
            required publicKey,
            required issuedAtMillis,
          }) async {
            await _requireCurrent(binding, generation);
            // 尝试归属实际设备公钥；新设备不能被上一设备的尝试永久阻断。
            final attempt = 'mls.registration.attempt:${_owner(binding)}';
            final previousAttempt = await _records.read(attempt);
            var previousKey = previousAttempt;
            if (previousAttempt == 'attempted') {
              final raw = await _records.read(
                deviceRegistrationProofKey(
                  binding.cidNumber,
                  binding.bindRev,
                  binding.accountId,
                ),
              );
              // 只有完整旧回执才能证明旧尝试属于另一公钥；无回执的未知终态仍禁止重签。
              if (raw != null) {
                previousKey =
                    decodeDeviceRegistrationProof(
                          raw,
                          cidNumber: binding.cidNumber,
                          bindRev: binding.bindRev,
                          accountId: binding.accountId,
                        )['public_key']
                        as String;
              }
            }
            if (previousKey == 'attempted' ||
                previousKey == publicKey ||
                (previousKey != null &&
                    !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(previousKey)) ||
                !await _records.compareAndSet(
                  attempt,
                  expected: previousAttempt,
                  next: publicKey,
                ) ||
                await _records.read(attempt) != publicKey) {
              throw const AccountSecurityException(
                '首次登记授权已尝试，不能自动重复',
                code: 'authenticationRequired',
              );
            }
            await _requireCurrent(binding, generation);
            try {
              final String signature;
              if (account.signMode == CitizenWalletSignMode.hot) {
                // 使用既有钱包签署接口完成已批准的0x1C MLS设备登记授权。
                final Uint8List signed;
                if (_payloadSigner != null) {
                  signed = await _payloadSigner(
                    binding.accountId,
                    signingMessage,
                    CitizenQrActions.mlsDeviceBind,
                    null,
                  );
                } else {
                  final result = await _signing!
                      .beginSigning(
                        CitizenSigningIntent(
                          accountId: binding.accountId,
                          payload: signingMessage,
                          transform: CitizenSigningTransform.raw(),
                        ),
                      )
                      .result;
                  if (result is! CitizenSigningCompleted ||
                      result.accountId != binding.accountId) {
                    throw const AccountSecurityException(
                      'MLS登记钱包授权无效',
                      code: 'integrity',
                    );
                  }
                  signed = result.signature;
                }
                // 无论结果来源，SDK仍核验签名；业务函数不能授予虚假成功权限。
                if (!await CitizenSdk.verify(
                  accountId: binding.accountId,
                  signature: signed,
                  payload: signingMessage,
                )) {
                  throw const AccountSecurityException(
                    'MLS登记钱包授权无效',
                    code: 'integrity',
                  );
                }
                signature = '0x${bytesToHex(signed)}';
              } else {
                signature = await _coldMlsDeviceBindingSigner(
                  binding: binding,
                  payload: payload,
                  signingMessage: signingMessage,
                  publicKey: publicKey,
                  issuedAtMillis: issuedAtMillis,
                );
              }
              await _requireCurrent(binding, generation);
              return signature;
            } on Object catch (error) {
              final cancelled =
                  error is CitizenSdkException &&
                      (error.code ==
                              CitizenSdkErrorCode.authenticationCancelled ||
                          error.code == CitizenSdkErrorCode.cancelled) ||
                  error is AccountSecurityException &&
                      error.code == 'authenticationCancelled';
              // 这里只捕获签名回调尚未交付的明确取消；已签回执和未知失败绝不删除。
              if (cancelled &&
                  !await _records.compareAndSet(
                    attempt,
                    expected: publicKey,
                    next: previousAttempt,
                  )) {
                throw const AccountSecurityException(
                  '设备授权取消状态保存失败，请重试',
                  code: 'device_proof_storage',
                );
              }
              rethrow;
            }
          },
    );
    await _requireCurrent(binding, generation);
  }

  /// 钱包现有删除流程的准备记录；这里只登记公开范围，不删除钱包私钥。
  Future<void> prepareAccountCleanup({
    required List<String> accountIds,
    required Set<int> walletIndexes,
    required bool deleteWalletWideKey,
  }) async {
    if (accountIds.isEmpty) return;
    if (deleteWalletWideKey && walletIndexes.length != 1) {
      throw const AccountSecurityException('整钱包清理必须只包含一个wallet_index');
    }
    final value = jsonEncode({
      'account_ids': accountIds,
      'wallet_indices': walletIndexes.toList()..sort(),
      'delete_wallet_wide_key': deleteWalletWideKey,
    });
    final old = await _records.read(_pendingCleanup);
    if (old != null && old != value) {
      throw const AccountSecurityException('已有其他账户清理未完成');
    }
    if (!await _records.compareAndSet(
      _pendingCleanup,
      expected: old,
      next: value,
    )) {
      throw const AccountSecurityException('账户清理范围并发变化');
    }
  }

  Future<bool> get hasPendingAccountCleanup async =>
      await _records.read(_pendingCleanup) != null;
  Future<void> reconcileAccountCleanup({CitizenWalletState? receipt}) async {
    final raw = await _records.read(_pendingCleanup);
    if (raw == null) return;
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['account_ids'] is! List ||
        value['wallet_indices'] is! List ||
        value['delete_wallet_wide_key'] is! bool) {
      throw const AccountSecurityException('清理范围损坏');
    }
    final ids = (value['account_ids'] as List).cast<String>().toSet();
    final indexes = (value['wallet_indices'] as List).cast<int>().toSet();
    final state = receipt ?? await _getWalletState().result;
    if (!state.isRemovalSettled(ids, indexes)) {
      throw const AccountSecurityException('钱包安全清理尚未完成');
    }
    // 跨重启或清理失败后重试时，SDK 和 App 各清除所属余额。
    if (receipt == null) {
      final signing = _signing;
      await Future.wait<void>([
        if (signing != null) signing.balances.remove(ids),
        ClearingBalances.instance.remove(ids),
      ]);
    }
    for (final binding in await _bindings.readAll()) {
      if (ids.contains(binding.accountId)) {
        await _clearPublicBinding(binding);
      }
    }
    for (final id in ids) {
      await LocalTxStore.deleteWalletLocalHistory(id);
      await ClearingBankPrefs.clear(id);
    }
    if (!await _records.compareAndSet(_pendingCleanup, expected: raw)) {
      throw const AccountSecurityException('清理范围已变化');
    }
    notifyIdentityBindingChanged();
  }

  Future<void> cancelAccountCleanup() => _records.delete(_pendingCleanup);
  Future<void> _clearPublicBinding(IdentityBinding binding) async {
    await _records.delete(
      deviceRegistrationProofKey(
        binding.cidNumber,
        binding.bindRev,
        binding.accountId,
      ),
    );
    await _records.delete('mls.registration.attempt:${_owner(binding)}');
    await _records.delete(
      'mls.binding.sync:${Uri.encodeComponent(binding.cidNumber)}',
    );
    await _bindings.clearForCid(binding.cidNumber);
  }

  /// 既有全量擦除仅清App所属公开记录；真正MLS状态由SDK已有擦除入口承担。
  Future<void> wipeAllDeviceMaterial() async {
    for (final binding in await _bindings.readAll()) {
      await _clearPublicBinding(binding);
    }
    await _records.delete(_pendingCleanup);
    // 全量设备擦除也撤销本机注册恢复能力；删除失败不得继续报告成功。
    await SystemProtectedRecordStore.registration.deleteAll();
    if ((await SystemProtectedRecordStore.registration.readAll()).isNotEmpty) {
      throw StateError("注册恢复记录未完全擦除");
    }
    await SystemProtectedStorage.eraseObsoleteDataMaterial();
    notifyIdentityBindingChanged();
  }

  void dispose() => revision.dispose();
}

// 原子保存公开绑定和当前设备钱包授权回执，校验属主及CAS修订。

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
    : _publicRecords = records ?? SystemProtectedRecordStore.identity;
  final SystemProtectedRecordStore _publicRecords;
  @override
  Future<String?> read(String key) => _publicRecords.read(key);
  @override
  Future<void> write(String key, String value) => _publicRecords.write(key, value);
  @override
  Future<void> delete(String key) => _publicRecords.delete(key);
  @override
  Future<bool> compareAndSet(
    String key, {
    required String? expected,
    String? next,
  }) => _publicRecords.compareAndSet(key, expected: expected, next: next);
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
  PublicIdentityStore(this._publicRecords);
  final PublicIdentityRecordStore _publicRecords;
  static const _publicBindings = 'identity.bindings';
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
      _decode(await _publicRecords.read(_publicBindings));

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
      final raw = await _publicRecords.read(_publicBindings);
      final decoded = _decode(raw);
      mutate(decoded);
      if (await _publicRecords.compareAndSet(
        _publicBindings,
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
