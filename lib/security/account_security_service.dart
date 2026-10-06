import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:citizenapp/security/hex_codec.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:citizenapp/security/public_identity_store.dart';
import 'package:citizenapp/security/system_protected_storage.dart';
import 'package:citizenapp/transaction/history/local_tx_store.dart';
import 'package:citizenapp/transaction/offchain-transaction/services/clearing_bank_prefs.dart';

/// 身份/登记编排失败；不吞掉SDK原始失败，也不自动重复钱包授权。
class AccountSecurityException implements Exception {
  const AccountSecurityException(
    this.message, {
    this.code = 'accountSecurityFailed',
    this.stage,
  });
  final String message;
  final String code;
  final String? stage;
  @override
  String toString() => 'AccountSecurityException: $message';
}

typedef AccountMlsDeviceRegistrar = Future<void> Function({
  required String cidNumber,
  required int bindingRevision,
  required String accountId,
  required Future<String> Function({
    required Uint8List payload,
    required Uint8List signingMessage,
    required String publicKey,
    required int issuedAtMillis,
  })
  signBinding,
});
typedef ColdMlsDeviceBindingSigner = Future<String> Function({
  required IdentityBinding binding,
  required Uint8List payload,
  required Uint8List signingMessage,
  required String publicKey,
  required int issuedAtMillis,
});

/// 只协调公开身份、首次MLS登记授权与所属记录清理。钱包能力仍归CitizenSDK。
interface class AccountSecurityService {
  AccountSecurityService({
    required CitizenSdkWallet wallet,
    required CitizenSigning signing,
    required AccountMlsDeviceRegistrar mlsDeviceRegistrar,
    required ColdMlsDeviceBindingSigner coldMlsDeviceBindingSigner,
    PublicIdentityRecordStore? blobStore,
  }) : _wallet = wallet,
       _signing = signing,
       _mlsDeviceRegistrar = mlsDeviceRegistrar,
       _coldMlsDeviceBindingSigner = coldMlsDeviceBindingSigner,
       _records = blobStore ?? SystemPublicIdentityRecordStore() {
    _bindings = PublicIdentityStore(_records);
  }
  final CitizenSdkWallet _wallet;
  final CitizenSigning _signing;
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
    for (final account in (await _wallet.getState().result).accounts) {
      if (account.accountId == accountId) return account;
    }
    return null;
  }

  Future<void> activateIdentityBinding({
    required String genesisHash,
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) async {
    final next = IdentityBinding(
      genesisHash: genesisHash,
      cidNumber: cidNumber,
      bindingRevision: bindingRevision,
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
    notifyIdentityBindingChanged();
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

  /// 仅明确未登记的设备使用此入口；并发调用共用同一登记，不派生其他材料。
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
      bindingRevision: binding.bindingRevision,
      accountId: binding.accountId,
      signBinding:
          ({
            required payload,
            required signingMessage,
            required publicKey,
            required issuedAtMillis,
          }) async {
            await _requireCurrent(binding, generation);
            // 钱包回调只在没有持久登记授权时执行；CAS在真实授权之前占用唯一尝试。
            final attempt = 'mls.registration.attempt:${_owner(binding)}';
            if (!await _records.compareAndSet(
                  attempt,
                  expected: null,
                  next: 'attempted',
                ) ||
                await _records.read(attempt) != 'attempted') {
              throw const AccountSecurityException(
                '首次登记授权已尝试，不能自动重复',
                code: 'authenticationRequired',
              );
            }
            await _requireCurrent(binding, generation);
            final String signature;
            if (account.signMode == CitizenWalletSignMode.hot) {
              // 使用既有钱包签署接口完成已批准的0x1C MLS设备登记授权。
              final result = await _signing
                  .begin(
                    CitizenSigningIntent(
                      accountId: binding.accountId,
                      payload: signingMessage,
                      transform: CitizenSigningTransform.raw(),
                    ),
                  )
                  .result;
              if (result is! CitizenSigningCompleted ||
                  result.accountId != binding.accountId ||
                  !await CitizenSigning.verify(
                    accountId: binding.accountId,
                    signature: result.signature,
                    payload: signingMessage,
                  )) {
                throw const AccountSecurityException(
                  'MLS登记钱包授权无效',
                  code: 'integrity',
                );
              }
              signature = '0x${bytesToHex(result.signature)}';
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
  Future<void> reconcileAccountCleanup() async {
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
    final state = await _wallet.getState().result;
    if (state.cleanupPending ||
        state.accounts.any((a) => ids.contains(a.accountId)) ||
        state.diagnostics.any((r) => indexes.contains(r.walletIndex))) {
      throw const AccountSecurityException('钱包安全清理尚未完成');
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
        binding.bindingRevision,
        binding.accountId,
      ),
    );
    await _records.delete('mls.registration.attempt:${_owner(binding)}');
    await _bindings.clearForCid(binding.cidNumber);
  }

  /// 既有全量擦除仅清App所属公开记录；真正MLS状态由SDK已有擦除入口承担。
  Future<void> wipeAllDeviceMaterial(Iterable<int> walletIndexes) async {
    for (final binding in await _bindings.readAll()) {
      await _clearPublicBinding(binding);
    }
    await _records.delete(_pendingCleanup);
    await SystemProtectedStorage.eraseObsoleteDataMaterial();
    notifyIdentityBindingChanged();
  }

  void dispose() => revision.dispose();
}
