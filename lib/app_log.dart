import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 全端唯一日志门面。Release默认关闭自由文本日志及诊断文件。
/// 闭集失败事件仅输出固定阶段、HTTP状态和错误类别，不接收业务正文。
/// 只有编译期显式诊断开关可启用既有调试出口。
///
/// debug/profile既有自由文本出口仍走debugPrint及原诊断文件。
/// 安全失败事件单独输出设备固定行，不依赖文件可读或调试包权限。
/// 新增日志一律走 AppLog,禁止再直接调用 debugPrint。
class AppLog {
  const AppLog._();

  // 生产包默认关闭自由文本日志；仅显式传入 dart-define 时临时启用。
  // 该开关是编译期常量，不允许运行时远程开启，也不改变正式发布默认值。
  static const bool _explicitDiagnostics = bool.fromEnvironment(
    'CITIZENAPP_DIAGNOSTICS',
    defaultValue: false,
  );

  static File? _diagFile;
  static bool _diagResolved = false;
  static Future<void> _tail = Future<void>.value();

  /// 供网络层决定是否执行只读诊断预检；正式 Release 默认恒为 false。
  static bool get diagnosticsEnabled => !kReleaseMode || _explicitDiagnostics;

  /// 正式包可用的安全失败事件；未知输入归other，不落自由文本诊断文件。
  /// 白名单必须精确匹配，不能靠截断、前缀或异常toString清洗秘密。
  static void failure({required String stage, int? statusCode, String? code}) {
    const stages = {
      'identity',
      'challenge',
      'proof',
      'registration',
      'session',
      'request',
      'prepare',
      'topup_config',
    };
    const codes = {
      'identity_unregistered',
      'identity_local_missing',
      'cid_not_bound',
      'identity_projection_pending',
      'identity_projection_unavailable',
      'cid_binding_changed',
      'network_unavailable',
      'registration_required',
      'device_not_registered',
      'invalid_mls_signature',
      'invalid_mls_proof',
      'invalid_binding_signature',
      'invalid_device_binding',
      'stale_device_binding',
      'device_proof_invalid',
      'device_proof_storage',
      'mls_challenge_limit_reached',
      'request_rate_exceeded',
      'identityChanged',
      'identityUnavailable',
      'authenticationRequired',
      'authenticationCancelled',
      'integrity',
      'mls_storage_unavailable',
      'mls_directory_invalid',
      'mls_directory_unavailable',
      'mls_state_missing',
      'mls_state_owner_mismatch',
      'mls_storage_read_failed',
      'mls_state_invalid',
      'mls_signer_missing',
      'mls_library_unavailable',
      'mls_invalid_request',
      'mls_invalid_response',
      'mls_operation_failed',
      'topup_unconfigured',
      'topup_network_unconfigured',
      'topup_intent_unconfigured',
      'json',
      'shape',
      'response_invalid',
      'format',
      'type',
      'state',
      'platform',
    };
    final safeStage = stages.contains(stage) ? stage : 'other';
    final safeCode = codes.contains(code) ? code : 'other';
    final status = statusCode != null && statusCode >= 100 && statusCode <= 599
        ? '$statusCode'
        : 'none';
    try {
      debugPrintSynchronously(
        '[CitizenFailure] stage=$safeStage http=$status code=$safeCode',
      );
    } on Object {
      // 诊断出口失败不能替换原业务异常或改变认证、付款结果。
    }
  }

  /// 调试日志。签名与 debugPrint 兼容（String? + wrapWidth），既有调用点可原样迁移。
  static void d(String? message, {int? wrapWidth}) {
    if (!diagnosticsEnabled) return;
    debugPrint(message, wrapWidth: wrapWidth);
    if (message != null) _appendDiag(message);
  }

  // 串行追加,避免并发写交错;首次解析目录失败(如单测无平台通道)后永久空操作。
  static void _appendDiag(String message) {
    // 单测无平台通道(path_provider 不可用),直接跳过文件写。
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _tail = _tail.then((_) async {
      try {
        if (!_diagResolved) {
          _diagResolved = true;
          final dir = await getApplicationSupportDirectory();
          _diagFile = File('${dir.path}/citizenapp_diag.log');
        }
        final f = _diagFile;
        if (f == null) return;
        await f.writeAsString(
          '${DateTime.now().toIso8601String()} $message\n',
          mode: FileMode.append,
        );
      } on Object {
        // 诊断日志失败绝不影响业务
      }
    });
  }
}
