// 认证文案、异常及原生安全保护。

import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter/services.dart';

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

// 按系统语言提供统一中英文生物识别弹窗文案。

// AuthMessages 基类由 local_auth_android 一并导出,无需再单独引 platform_interface。

/// 生物识别系统对话框的文案单源。
///
/// **口径(全端统一)**:默认中文;只有手机系统语言是英文时才显示英文,其余语言
/// (日、法、德…)一律回落中文。与 iOS `zh-Hans.lproj`/`en.lproj`、Android
/// `values/`(中文默认)+ `values-en/` 的回落规则完全一致。
///
/// **为什么需要它**:`localizedReason` 只是对话框中间那句解释,而标题、提示、
/// 取消按钮等**框架文字由 local_auth 插件提供,默认是英文硬编码串** —— 不传
/// [messages] 就会出现"中文解释 + 英文标题/按钮"的混排。
///
/// 语言判定用 [PlatformDispatcher.instance.locale](设备当前语言),不依赖
/// `BuildContext`：部分非 Widget 业务层也要复用平台认证文案。
class BiometricAuthText {
  const BiometricAuthText._();

  /// 语言判定的唯一规则:**只有英文为真**,其余语言(日、法、德…)一律按中文处理。
  /// 抽成纯函数,便于逐语言钉死回落行为。
  static bool isEnglishLocale(Locale locale) => locale.languageCode == 'en';

  /// 设备语言来源。生产恒为 [PlatformDispatcher.instance] 的当前语言;
  /// 测试注入用(与仓库 `debugXxx` 惯例一致),`tearDown` 里置 null 复位。
  ///
  /// 之所以需要这个接缝:生产直读 `PlatformDispatcher.instance` 时,
  /// `TestPlatformDispatcher.localeTestValue` 覆写的是测试包装器而非真单例,
  /// 覆盖不到本类 —— 不留接缝这段逻辑就完全不可测。
  @visibleForTesting
  static Locale Function()? debugLocale;

  static Locale get _locale =>
      debugLocale?.call() ?? PlatformDispatcher.instance.locale;

  /// 仅英文手机为真;其余语言一律按中文处理(默认语言)。
  static bool get isEnglish => isEnglishLocale(_locale);

  /// 按当前语言二选一。调用方用它给 `localizedReason` 取值。
  static String pick({required String zh, required String en}) =>
      isEnglish ? en : zh;

  /// 传给 `LocalAuthentication.authenticate(authMessages: ...)`。
  ///
  /// local_auth 3.x 的 Android 文案字段已收敛为标题、提示和取消按钮；iOS
  /// 继续显式提供设备密码回退标题，保持 CitizenApp 既有 `biometricOnly: false`
  /// 行为，不把依赖升级误改成冷钱包的纯生物识别策略。
  static List<AuthMessages> messages() => <AuthMessages>[
        AndroidAuthMessages(
          signInTitle: pick(zh: '身份验证', en: 'Authentication required'),
          signInHint: pick(zh: '验证您的身份', en: 'Verify your identity'),
          cancelButton: pick(zh: '取消', en: 'Cancel'),
        ),
        IOSAuthMessages(
          cancelButton: pick(zh: '取消', en: 'Cancel'),
          localizedFallbackTitle: pick(zh: '使用设备密码', en: 'Use passcode'),
        ),
      ];
}

// 桥接原生后台生命周期以协助完成已触发的数据擦除。

/// 防共匪擦除期间的原生生命周期桥。
///
/// Android 会把任务移到后台但保留 Flutter 引擎；iOS 只申请系统允许的有限后台
/// 执行时间。平台桥只是提高本进程完成概率，真正的不可逆保证仍由持久门闩提供。
final class EmergencyWipePlatform {
  EmergencyWipePlatform._();

  static const MethodChannel _wipeChannel = MethodChannel('citizenapp/security');

  static Future<void> beginProtectedExecution() =>
      _bestEffort('beginEmergencyWipe');

  static Future<void> finishProtectedExecution() =>
      _bestEffort('finishEmergencyWipe');

  static Future<void> _bestEffort(String method) async {
    try {
      await _wipeChannel.invokeMethod<void>(method);
    } on MissingPluginException {
      // 测试、桌面端或旧原生壳没有桥时仍必须在当前 isolate 完成擦除。
    } on PlatformException {
      // 门闩已经落盘；平台生命周期加固失败不能取消不可逆擦除。
    }
  }
}

// 按引用计数管理屏幕保护，统一监听截屏和录屏事件。

/// 截屏保护工具（进程级全局资源，引用计数管理）。
///
/// - Android: 通过 FLAG_SECURE 阻止截屏和屏幕录制。
/// - iOS: 进入后台时添加模糊遮罩，检测截屏事件。
///
/// 敏感页面可能嵌套打开；每个页面各持有一次引用，只有最后一个页面退出时才关闭
/// 原生保护，避免子页面退出后误把父页面仍需的保护一并关闭。
class ScreenshotGuard {
  const ScreenshotGuard._();

  static const MethodChannel _screenChannel = MethodChannel('citizenapp/security');

  static int _refCount = 0;

  /// 启用截屏保护。每次调用持有一个引用，首次持有时才切换原生开关。
  static Future<void> enable() async {
    _refCount++;
    if (_refCount != 1) return;
    try {
      await _screenChannel.invokeMethod('enableScreenshotProtection');
    } on PlatformException {
      // 平台不支持，忽略。
    } on MissingPluginException {
      // 非移动端测试环境没有原生实现，忽略。
    }
  }

  /// 释放一次截屏保护引用；引用归零时才关闭原生开关。
  static Future<void> disable() async {
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount != 0) return;
    try {
      await _screenChannel.invokeMethod('disableScreenshotProtection');
    } on PlatformException {
      // 平台不支持，忽略。
    } on MissingPluginException {
      // 非移动端测试环境没有原生实现，忽略。
    }
  }

  /// 检测设备是否已 root（Android）或越狱（iOS）。
  static Future<bool> isDeviceRooted() async {
    try {
      final result = await _screenChannel.invokeMethod<bool>('isDeviceRooted');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
