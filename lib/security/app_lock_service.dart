import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_offchain/offchain_clearing_rpc.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:citizen_square/draft/compose_draft_media.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_storage/social_isar.dart';

import 'package:citizen_user/identity/mls_authentication.dart';

import 'package:citizen_storage/user_isar.dart';

import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_system/security/system_protected_storage.dart';

/// 全量本机数据擦除没有完整成功。
///
/// [failures] 会保留每个失败数据域，调用方不得把部分擦除当成成功退出。
class AppDataWipeException implements Exception {
  AppDataWipeException(List<String> failures)
    : failures = List<String>.unmodifiable(failures);

  final List<String> failures;

  @override
  String toString() => 'AppDataWipeException(${failures.join('; ')})';
}

/// PIN 验证的显式终态，避免把“已擦除”误当成普通密码错误继续操作。
enum AppPinVerificationResult {
  verified,
  duressMode,
  rejected,
  locked,
  dataWiped,
}

/// `main()` 在任何业务运行时初始化前的持久擦除预检结果。
enum AppDataWipeStartupResult {
  ready,
  dataWiped,
  retryRequired,
  preflightBlocked,
}

/// 应用锁（6 位 PIN）服务。
///
/// 普通 PIN 以 10 万次、`duress_mode` PIN 以 1 万次
/// PBKDF2-HMAC-SHA256(pin + salt) 形式存储在系统保护记录中。
/// 连续 5 次验证错误锁定 24 小时，累计 3 次锁定则清空全部应用数据。
class AppLockService {
  /// 普通应用锁与公民钱包统一使用 10 万次派生。
  static const int appLockPinHashIterations = 100000;

  /// 防共匪密码与公民钱包统一使用 1 万次派生。
  static const int duressModePinHashIterations = 10000;
  static const String _keyPinHash = 'pin_hash';
  static const String _keyPinSalt = 'pin_salt';
  static const String _keyFailCount = 'pin_fail_count';
  static const String _keyLockUntil = 'pin_lock_until';
  static const String _keyLockCount = 'pin_lock_count';
  static const String _keyDuressModePinHash = 'duress_mode_pin_hash';
  static const String _keyDuressModePinSalt = 'duress_mode_pin_salt';
  static const String _keyDuressModeEnabled = 'duress_mode_enabled';

  static const int maxFailAttempts = 5;
  static const int maxLockCount = 3;
  static const Duration lockDuration = Duration(hours: 24);
  static const Duration _wipeStepTimeout = Duration(seconds: 6);
  static Future<AppPinVerificationResult> Function(String)?
  _debugVerifyPinForTest;
  static Future<bool> Function()? _debugIsLockedForTest;
  static Future<void> Function()? _debugRemovePinForTest;
  static Future<void> Function()? _debugWipeAllDataForTest;
  static Future<void> Function()? _debugLatchPersistentWipeForTest;
  static bool _walletHardwareSecretsDeletedInProcess = false;

  /// Widget 测试只注入 PIN 终态，非 `flutter test` 进程一律拒绝。
  @visibleForTesting
  static void debugConfigureForTest({
    Future<AppPinVerificationResult> Function(String)? verifyPin,
    Future<bool> Function()? isLocked,
    Future<void> Function()? removePin,
    Future<void> Function()? wipeAllData,
    Future<void> Function()? latchPersistentWipe,
  }) {
    _requireFlutterTest();
    _debugVerifyPinForTest = verifyPin;
    _debugIsLockedForTest = isLocked;
    _debugRemovePinForTest = removePin;
    _debugWipeAllDataForTest = wipeAllData;
    _debugLatchPersistentWipeForTest = latchPersistentWipe;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _requireFlutterTest();
    _debugVerifyPinForTest = null;
    _debugIsLockedForTest = null;
    _debugRemovePinForTest = null;
    _debugWipeAllDataForTest = null;
    _debugLatchPersistentWipeForTest = null;
    _walletHardwareSecretsDeletedInProcess = false;
  }

  // PIN 管理
  /// 设置 6 位 PIN。
  static Future<void> setPin(String pin) async {
    _requireSixDigitPin(pin);
    final salt = _generateSalt();
    final hash = await _hash(pin, salt, iterations: appLockPinHashIterations);
    await SystemProtectedRecordStore.lock.write(_keyPinSalt, salt);
    await SystemProtectedRecordStore.lock.write(_keyPinHash, hash);
    // 重置错误计数
    await SystemProtectedRecordStore.lock.write(_keyFailCount, '0');
    await SystemProtectedRecordStore.lock.delete(_keyLockUntil);
    await SystemProtectedRecordStore.lock.write(_keyLockCount, '0');
  }

  /// 验证 PIN。
  ///
  /// 返回可区分验证通过、密码错误、24h 锁定和数据已擦除的终态。
  /// 错误达到 [maxFailAttempts] 次时自动触发 24h 锁定。
  /// 锁定达到 [maxLockCount] 次时调用 [wipeAllData] 清空数据。
  static Future<AppPinVerificationResult> verifyPin(
    String pin, {
    required CitizenSdk? wallet,
    required AccountSecurityService? accountSecurity,
  }) async {
    final debugVerify = _debugVerifyPinForTest;
    if (debugVerify != null) {
      _requireFlutterTest();
      return debugVerify(pin);
    }
    // 锁定中不允许验证
    if (await isLocked()) return AppPinVerificationResult.locked;

    final normalHash = await SystemProtectedRecordStore.lock.read(_keyPinHash);
    final normalSalt = await SystemProtectedRecordStore.lock.read(_keyPinSalt);
    if (normalHash == null || normalSalt == null) {
      return AppPinVerificationResult.rejected;
    }

    // 普通密码是高频路径，一次派生即可进入；未命中时才继续识别防共匪密码。
    final inputNormalHash = await _hash(
      pin,
      normalSalt,
      iterations: appLockPinHashIterations,
    );
    if (inputNormalHash == normalHash) {
      await SystemProtectedRecordStore.lock.write(_keyFailCount, '0');
      return AppPinVerificationResult.verified;
    }

    // 防共匪密码命中时不改动普通密码错误计数。
    if (await _matchesDuressModePin(pin)) {
      return AppPinVerificationResult.duressMode;
    }
    return _recordRejectedPin(wallet, accountSecurity);
  }

  /// 只验证普通应用锁密码，供关闭应用锁使用；该入口永不触发防共匪模式。
  static Future<AppPinVerificationResult> verifyNormalPin(
    String pin, {
    required CitizenSdk? wallet,
    required AccountSecurityService? accountSecurity,
  }) async {
    final debugVerify = _debugVerifyPinForTest;
    if (debugVerify != null) {
      _requireFlutterTest();
      return debugVerify(pin);
    }
    if (await isLocked()) return AppPinVerificationResult.locked;
    return _verifyNormalPin(
      pin,
      wallet: wallet,
      accountSecurity: accountSecurity,
    );
  }

  static Future<AppPinVerificationResult> _verifyNormalPin(
    String pin, {
    required CitizenSdk? wallet,
    required AccountSecurityService? accountSecurity,
  }) async {
    final storedHash = await SystemProtectedRecordStore.lock.read(_keyPinHash);
    final storedSalt = await SystemProtectedRecordStore.lock.read(_keyPinSalt);
    if (storedHash == null || storedSalt == null) {
      return AppPinVerificationResult.rejected;
    }

    final inputHash = await _hash(
      pin,
      storedSalt,
      iterations: appLockPinHashIterations,
    );
    if (inputHash == storedHash) {
      // 验证成功，重置错误计数
      await SystemProtectedRecordStore.lock.write(_keyFailCount, '0');
      return AppPinVerificationResult.verified;
    }

    return _recordRejectedPin(wallet, accountSecurity);
  }

  static Future<AppPinVerificationResult> _recordRejectedPin(
    CitizenSdk? wallet,
    AccountSecurityService? accountSecurity,
  ) async {
    // 两类密码均未命中后，才累计一次普通应用锁错误。
    final failCount = await _readInt(_keyFailCount) + 1;
    await SystemProtectedRecordStore.lock.write(
      _keyFailCount,
      failCount.toString(),
    );

    if (failCount >= maxFailAttempts) {
      final lockCount = await _readInt(_keyLockCount) + 1;
      await SystemProtectedRecordStore.lock.write(
        _keyLockCount,
        lockCount.toString(),
      );
      await SystemProtectedRecordStore.lock.write(_keyFailCount, '0');

      if (lockCount >= maxLockCount) {
        await wipeAllData(wallet: wallet, accountSecurity: accountSecurity);
        return AppPinVerificationResult.dataWiped;
      }

      // 锁定 24 小时
      final lockUntil = DateTime.now().add(lockDuration).millisecondsSinceEpoch;
      await SystemProtectedRecordStore.lock.write(
        _keyLockUntil,
        lockUntil.toString(),
      );
      return AppPinVerificationResult.locked;
    }

    return AppPinVerificationResult.rejected;
  }

  /// 关闭应用锁（验证后调用）。
  static Future<void> removePin() async {
    final debugRemove = _debugRemovePinForTest;
    if (debugRemove != null) {
      _requireFlutterTest();
      return debugRemove();
    }
    await SystemProtectedRecordStore.lock.delete(_keyPinHash);
    await SystemProtectedRecordStore.lock.delete(_keyPinSalt);
    await SystemProtectedRecordStore.lock.delete(_keyFailCount);
    await SystemProtectedRecordStore.lock.delete(_keyLockUntil);
    await SystemProtectedRecordStore.lock.delete(_keyLockCount);
    await removeDuressMode();
  }

  /// 设置独立的 6 位防共匪密码。与普通应用锁密码相同则拒绝保存。
  static Future<bool> setDuressModePin(String pin) async {
    _requireSixDigitPin(pin);
    final normalHash = await SystemProtectedRecordStore.lock.read(_keyPinHash);
    final normalSalt = await SystemProtectedRecordStore.lock.read(_keyPinSalt);
    if (normalHash == null || normalSalt == null) return false;
    if (await _hash(pin, normalSalt, iterations: appLockPinHashIterations) ==
        normalHash) {
      return false;
    }

    final salt = _generateSalt();
    await SystemProtectedRecordStore.lock.write(_keyDuressModePinSalt, salt);
    await SystemProtectedRecordStore.lock.write(
      _keyDuressModePinHash,
      await _hash(pin, salt, iterations: duressModePinHashIterations),
    );
    await SystemProtectedRecordStore.lock.write(_keyDuressModeEnabled, 'true');
    return isDuressModeEnabled();
  }

  /// 防共匪模式只有在普通应用锁存在且三项状态完整时才视为开启。
  static Future<bool> isDuressModeEnabled() async {
    if (!await isPinSet()) return false;
    final enabled = await SystemProtectedRecordStore.lock.read(
      _keyDuressModeEnabled,
    );
    final hash = await SystemProtectedRecordStore.lock.read(
      _keyDuressModePinHash,
    );
    final salt = await SystemProtectedRecordStore.lock.read(
      _keyDuressModePinSalt,
    );
    return enabled == 'true' &&
        hash != null &&
        hash.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty;
  }

  static Future<void> removeDuressMode() async {
    await SystemProtectedRecordStore.lock.delete(_keyDuressModePinHash);
    await SystemProtectedRecordStore.lock.delete(_keyDuressModePinSalt);
    await SystemProtectedRecordStore.lock.delete(_keyDuressModeEnabled);
  }

  static Future<bool> _matchesDuressModePin(String pin) async {
    final enabled = await SystemProtectedRecordStore.lock.read(
      _keyDuressModeEnabled,
    );
    if (enabled != 'true') return false;
    final hash = await SystemProtectedRecordStore.lock.read(
      _keyDuressModePinHash,
    );
    final salt = await SystemProtectedRecordStore.lock.read(
      _keyDuressModePinSalt,
    );
    return hash != null &&
        salt != null &&
        await _hash(pin, salt, iterations: duressModePinHashIterations) == hash;
  }

  /// 是否已设置 PIN。
  static Future<bool> isPinSet() async {
    final hash = await SystemProtectedRecordStore.lock.read(_keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  // 锁定状态
  /// 当前是否处于 24h 锁定期。
  static Future<bool> isLocked() async {
    final debugLocked = _debugIsLockedForTest;
    if (debugLocked != null) {
      _requireFlutterTest();
      return debugLocked();
    }
    final lockUntilStr = await SystemProtectedRecordStore.lock.read(
      _keyLockUntil,
    );
    if (lockUntilStr == null) return false;
    final lockUntil = int.tryParse(lockUntilStr);
    if (lockUntil == null) return false;
    return DateTime.now().millisecondsSinceEpoch < lockUntil;
  }

  /// 剩余锁定秒数（未锁定返回 0）。
  static Future<int> getRemainingLockSeconds() async {
    final lockUntilStr = await SystemProtectedRecordStore.lock.read(
      _keyLockUntil,
    );
    if (lockUntilStr == null) return 0;
    final lockUntil = int.tryParse(lockUntilStr);
    if (lockUntil == null) return 0;
    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining ~/ 1000 : 0;
  }

  /// 当前连续错误次数。
  static Future<int> getFailCount() async => _readInt(_keyFailCount);

  /// 当前累计锁定次数。
  static Future<int> getLockCount() async => _readInt(_keyLockCount);

  /// 启动时仅判定持久擦除状态。不能读取状态时关闭业务入口。
  static Future<AppDataWipeStartupResult> recoverPersistentWipeAtStartup({
    required CitizenSdk? wallet,
    required AccountSecurityService? accountSecurity,
    Future<void> Function()? debugDeleteCitizenSdkWallet,
    Future<void> Function()? debugDeleteProtectedRecords,
    Future<void> Function()? debugClearSharedPreferences,
    Future<Directory> Function()? debugWipeDirectoryProvider,
  }) async {
    if (debugDeleteProtectedRecords != null ||
        debugClearSharedPreferences != null ||
        debugWipeDirectoryProvider != null) {
      _requireFlutterTest();
    }
    try {
      final root = await _wipeDirectory(debugWipeDirectoryProvider);
      final marker = File('${root.path}/$_wipeMarker');
      final complete = File('${root.path}/$_wipeComplete');
      final markerType = await FileSystemEntity.type(
        marker.path,
        followLinks: false,
      );
      final completeType = await FileSystemEntity.type(
        complete.path,
        followLinks: false,
      );
      if (markerType == FileSystemEntityType.notFound &&
          completeType == FileSystemEntityType.notFound) {
        return AppDataWipeStartupResult.ready;
      }
      if (markerType != FileSystemEntityType.file ||
          (completeType != FileSystemEntityType.file &&
              completeType != FileSystemEntityType.notFound)) {
        return AppDataWipeStartupResult.preflightBlocked;
      }
      if (completeType == FileSystemEntityType.file &&
          await complete.readAsString() == 'complete\n') {
        // 中途退出仍会留下待恢复标记。
        await complete.delete();
        if (debugWipeDirectoryProvider == null) {
          await SystemProtectedStorage.syncWipeLayout();
        }
        await marker.delete();
        if (debugWipeDirectoryProvider == null) {
          await SystemProtectedStorage.syncWipeLayout();
        }
        return AppDataWipeStartupResult.ready;
      }
      try {
        await wipeAllData(
          wallet: wallet,
          accountSecurity: accountSecurity,
          debugDeleteCitizenSdkWallet: debugDeleteCitizenSdkWallet,
          debugDeleteProtectedRecords: debugDeleteProtectedRecords,
          debugClearSharedPreferences: debugClearSharedPreferences,
          debugWipeDirectoryProvider: debugWipeDirectoryProvider,
        );
        return AppDataWipeStartupResult.dataWiped;
      } catch (_) {
        return AppDataWipeStartupResult.retryRequired;
      }
    } catch (error) {
      debugPrint('wipe_preflight:blocked:${error.runtimeType}');
      return AppDataWipeStartupResult.preflightBlocked;
    }
  }

  static const _wipeMarker = SystemProtectedStorage.wipePending;
  static const _wipeComplete = SystemProtectedStorage.wipeComplete;

  static Future<Directory> _wipeDirectory(
    Future<Directory> Function()? provider,
  ) async {
    final directory =
        await (provider ?? SystemProtectedStorage.wipeDirectory)();
    if (!directory.isAbsolute ||
        await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw StateError('全量擦除记录目录不可用');
    }
    return Directory(await directory.resolveSymbolicLinks());
  }

  static Future<void> _writeWipeMarker(
    Future<Directory> Function()? provider,
    String name,
    String value,
  ) async {
    final root = await _wipeDirectory(provider);
    final target = File('${root.path}/$name');
    final type = await FileSystemEntity.type(target.path, followLinks: false);
    if (type == FileSystemEntityType.file &&
        await target.readAsString() == value) {
      return;
    }
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw StateError('全量擦除标记路径异常');
    }
    final stage = await root.createTemp('wipe-');
    try {
      final file = File('${stage.path}/state');
      await file.writeAsString(value, flush: true);
      await file.rename(target.path);
      if (provider == null) await SystemProtectedStorage.syncWipeLayout();
    } finally {
      await stage.delete(recursive: true);
    }
  }

  /// 在退出前先把跨重启擦除意图落盘；未成功落盘时调用方不得退出。
  static Future<void> latchPersistentWipe({
    Future<Directory> Function()? debugWipeDirectoryProvider,
  }) {
    final debugLatch = _debugLatchPersistentWipeForTest;
    if (debugLatch != null) {
      _requireFlutterTest();
      if (debugWipeDirectoryProvider != null) {
        throw StateError('禁止同时使用两组 AppLock 测试注入');
      }
      return debugLatch();
    }
    if (debugWipeDirectoryProvider != null) _requireFlutterTest();
    MlsAuthentication.blockDeviceAccess();
    return _writeWipeMarker(
      debugWipeDirectoryProvider,
      _wipeMarker,
      'pending\n',
    ).timeout(_wipeStepTimeout);
  }

  // 数据清空
  /// 先封住设备签名，再逐域清理；任何失败均保留持久恢复状态。
  /// 全部尝试结束后通过 [AppDataWipeException] 聚合暴露失败。
  static Future<void> wipeAllData({
    required CitizenSdk? wallet,
    required AccountSecurityService? accountSecurity,
    Future<void> Function()? debugDeleteCitizenSdkWallet,
    Future<void> Function()? debugDeleteProtectedRecords,
    Future<void> Function()? debugClearSharedPreferences,
    Future<Directory> Function()? debugWipeDirectoryProvider,
  }) async {
    final debugWipe = _debugWipeAllDataForTest;
    if (debugWipe != null) {
      _requireFlutterTest();
      if (debugDeleteProtectedRecords != null ||
          debugClearSharedPreferences != null ||
          debugWipeDirectoryProvider != null) {
        throw StateError('禁止同时使用两组 AppLock 测试注入');
      }
      return debugWipe();
    }
    if (debugDeleteProtectedRecords != null ||
        debugClearSharedPreferences != null ||
        debugWipeDirectoryProvider != null) {
      _requireFlutterTest();
    }
    final failures = <String>[];
    final deleteProtectedRecords =
        debugDeleteProtectedRecords ?? _deleteAndVerifyProtectedRecords;
    final clearSharedPreferences =
        debugClearSharedPreferences ?? _clearAndVerifySharedPreferences;

    var persistentGateReady = false;
    Object? persistentGateError;
    try {
      await latchPersistentWipe(
        debugWipeDirectoryProvider: debugWipeDirectoryProvider,
      );
      persistentGateReady = true;
    } catch (error) {
      persistentGateError = error;
    }

    if (debugWipeDirectoryProvider == null) {
      await _attemptWipe(
        'DeviceIdentity',
        SystemProtectedStorage.eraseDeviceStorage,
        failures,
      );
    }
    var walletSecretsDeleted = _walletHardwareSecretsDeletedInProcess;
    if (!walletSecretsDeleted) {
      final walletFailureCountBefore = failures.length;
      await _attemptWipe('CitizenSdk', () async {
        final debugDelete = debugDeleteCitizenSdkWallet;
        if (debugDelete != null) {
          _requireFlutterTest();
          await debugDelete();
          return;
        }
        final sdkWallet = wallet;
        final security = accountSecurity;
        if (sdkWallet == null || security == null) {
          throw StateError('CitizenSDK 钱包擦除依赖未提供');
        }
        await _wipeCitizenSdkWallet(sdkWallet, security);
      }, failures);
      walletSecretsDeleted = failures.length == walletFailureCountBefore;
      if (walletSecretsDeleted) {
        _walletHardwareSecretsDeletedInProcess = true;
      }
    }
    // begin 调用超时不代表原子 marker 没有完成落盘；读取持久态后再决定是否允许
    // 删除平台安全存储，避免把一次迟到的成功错误降级成跳过密钥清理。
    if (!persistentGateReady) {
      try {
        final root = await _wipeDirectory(
          debugWipeDirectoryProvider,
        ).timeout(_wipeStepTimeout);
        persistentGateReady =
            await FileSystemEntity.type(
              '${root.path}/$_wipeMarker',
              followLinks: false,
            ) ==
            FileSystemEntityType.file;
      } catch (error) {
        persistentGateError ??= error;
      }
    }
    if (persistentGateReady && walletSecretsDeleted) {
      await _attemptWipe('ProtectedRecords', deleteProtectedRecords, failures);
    } else if (!persistentGateReady) {
      failures.add('持久擦除门闩：${persistentGateError ?? '未能落盘'}');
      failures.add('ProtectedRecords：持久擦除门闩未就绪，已安全跳过');
    } else {
      failures.add('ProtectedRecords：硬件密钥未全部确认删除，已安全保留重试索引');
    }
    if (walletSecretsDeleted) {
      await _attemptWipe('UserIsar', () {
        ClearingBalances.instance.invalidateAll();
        return UserIsar.instance.closeAndDeleteFromDisk();
      }, failures);
    } else {
      failures.add('UserIsar：硬件密钥未全部确认删除，已安全保留重试索引');
    }
    await _attemptWipe(
      'SocialIsar',
      SocialIsar.instance.closeAndDeleteFromDisk,
      failures,
    );
    await _attemptWipe(
      'UserProfileFiles',
      CitizenProfileMediaCache(
        // 测试复用同一临时根目录，避免调用未注册的平台 path_provider；生产为 null
        // 时分别清理旧 Application Support/user/profile_media 与临时展示目录；字节已由 UserIsar 擦除。
        supportDirectoryProvider: debugWipeDirectoryProvider,
      ).closeAndDeleteAll,
      failures,
    );
    await _attemptWipe(
      'SocialFiles',
      () => ComposeDraftMedia.closeAndDeleteAll(
        documentsDirectoryProvider: debugWipeDirectoryProvider,
      ),
      failures,
    );

    if (persistentGateReady && walletSecretsDeleted) {
      await _attemptWipe('SharedPreferences', clearSharedPreferences, failures);
    } else {
      failures.add('SharedPreferences：关键擦除前置条件未完成，已安全跳过');
    }

    if (failures.isEmpty) {
      await _attemptWipe(
        '持久擦除完成态',
        () => _writeWipeMarker(
          debugWipeDirectoryProvider,
          _wipeComplete,
          'complete\n',
        ),
        failures,
      );
    }

    if (failures.isNotEmpty) {
      throw AppDataWipeException(failures);
    }
  }

  static Future<void> _wipeCitizenSdkWallet(
    CitizenSdk wallet,
    AccountSecurityService accountSecurity,
  ) async {
    final receipt = await wallet.deleteWallet().result;
    if (receipt.cleanupPending) {
      throw StateError('SDK 钱包擦除仍待清理');
    }
    await accountSecurity.wipeAllDeviceMaterial();
  }

  static Future<void> _deleteAndVerifyProtectedRecords() async {
    await SystemProtectedRecordStore.registration.deleteAll();
    await SystemProtectedRecordStore.identity.deleteAll();
    await SystemProtectedRecordStore.lock.deleteAll();
    if ((await SystemProtectedRecordStore.registration.readAll()).isNotEmpty ||
        (await SystemProtectedRecordStore.identity.readAll()).isNotEmpty ||
        (await SystemProtectedRecordStore.lock.readAll()).isNotEmpty) {
      throw StateError('安全存储仍有残留');
    }
  }

  static Future<void> _clearAndVerifySharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.clear() || prefs.getKeys().isNotEmpty) {
      throw StateError('偏好设置仍有残留');
    }
  }

  static Future<void> _attemptWipe(
    String dataDomain,
    Future<void> Function() operation,
    List<String> failures,
  ) async {
    try {
      await Future<void>.sync(operation).timeout(_wipeStepTimeout);
    } catch (error) {
      failures.add('$dataDomain：$error');
    }
  }

  static void _requireFlutterTest() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('AppLock 测试注入仅允许 flutter test 进程');
    }
  }

  // 内部工具
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 按密码用途执行固定次数的 PBKDF2-HMAC-SHA256，并在辅助 isolate 中派生。
  ///
  /// 密集计算不得占用 Flutter 主 isolate，否则第六位输入后会阻塞触控和绘制。
  static Future<String> _hash(
    String pin,
    String salt, {
    required int iterations,
  }) {
    return Isolate.run(() {
      final pinBytes = Uint8List.fromList(utf8.encode(pin));
      final saltBytes = Uint8List.fromList(utf8.encode(salt));
      final output = Uint8List(32);
      try {
        final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
          ..init(Pbkdf2Parameters(saltBytes, iterations, output.length));
        derivator.deriveKey(pinBytes, 0, output, 0);
        return output
            .map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join();
      } finally {
        pinBytes.fillRange(0, pinBytes.length, 0);
        saltBytes.fillRange(0, saltBytes.length, 0);
        output.fillRange(0, output.length, 0);
      }
    });
  }

  static Future<int> _readInt(String key) async {
    final str = await SystemProtectedRecordStore.lock.read(key);
    if (str == null) return 0;
    return int.tryParse(str) ?? 0;
  }

  static void _requireSixDigitPin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', '必须是 6 位数字密码');
    }
  }
}
