import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
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

  /// 钱包门禁失败只记录SDK枚举和精确命中的固定原因；未知文本绝不回显。
  /// 同一安全行供设备日志及门禁诊断页使用，不读取或保存钱包记录。
  static String walletFailure(Object error) {
    const reasons = <(CitizenSdkErrorCode, String), String>{
      (
        CitizenSdkErrorCode.integrity,
        'integrity: SQLite resource operation failed',
      ): 'sqlite_operation',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: SQLite job was not executed',
      ): 'sqlite_job',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: host wallet profile load failed',
      ): 'host_wallet_load',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: host encrypted blob load failed',
      ): 'host_secret_load',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: wallet profile revision disagrees with its typed payload',
      ): 'wallet_revision',
      (
        CitizenSdkErrorCode.integrity,
        'CitizenSDK native operation failed',
      ): 'native_unspecified',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database schema version differs',
      ): 'schema_version',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database object set differs',
      ): 'schema_objects',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database schema differs',
      ): 'schema_definition',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database auto-vacuum differs',
      ): 'schema_vacuum',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database durability setting differs',
      ): 'schema_durability',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: public database trusted-schema setting differs',
      ): 'schema_trust',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: embedded public schema is invalid',
      ): 'schema_embedded',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: host record corruption digest does not match',
      ): 'record_digest',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: host record belongs to a different typed store',
      ): 'record_domain',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: persisted wallet identity is invalid',
      ): 'wallet_identity',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: persisted cold identity is invalid',
      ): 'cold_identity',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: persisted wallet order is duplicated',
      ): 'wallet_order',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: persisted wallet state is invalid',
      ): 'wallet_state',
      (
        CitizenSdkErrorCode.integrity,
        'integrity: persisted wallet profile is invalid',
      ): 'wallet_profile',
      (CitizenSdkErrorCode.busy, 'wallet read is draining'): 'read_pending',
    };
    final String code, stage, reason;
    if (error is CitizenSdkException) {
      code = error.code.name;
      stage = error.stage.name;
      reason = reasons[(error.code, error.message)] ?? 'other';
    } else if (error is TimeoutException) {
      code = 'timeout';
      stage = 'provider';
      reason = 'read_timeout';
    } else {
      code = stage = reason = 'other';
    }
    final line =
        '[CitizenWallet] method=getWalletState code=$code stage=$stage reason=$reason';
    try {
      debugPrintSynchronously(line);
    } on Object {
      // 观察出口失败不能替换钱包读取错误，也不能改变原重试状态。
    }
    return line;
  }

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
      'proposal_institutions',
      'proposal_feed',
      'proposal_year',
      'proposal_index',
      'proposal_details',
      'proposal_context',
      'proposal_votes',
      'proposal_display',
      'proposal_summary',
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
      // 只接受SDK公开枚举的固定名称，不输出message/method/session等动态字段。
      'sdk_invalidArgument',
      'sdk_invalidHandle',
      'sdk_invalidState',
      'sdk_unsupported',
      'sdk_unavailable',
      'sdk_notReady',
      'sdk_notFound',
      'sdk_conflict',
      'sdk_integrity',
      'sdk_authenticationCancelled',
      'sdk_authenticationRequired',
      'sdk_keyInvalidated',
      'sdk_permissionDenied',
      'sdk_storage',
      'sdk_network',
      'sdk_decode',
      'sdk_timeout',
      'sdk_busy',
      'sdk_queueFull',
      'sdk_internal',
      'sdk_panic',
      'sdk_cancelled',
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

  /// HTTP仅输出固定类别、状态和单调计时；headers不是正文完成，取消不算成功。
  static void http({
    required String stage,
    required int elapsedMicros,
    required String phase,
    int? statusCode,
    int? headersMicros,
  }) {
    const stages = {
      'bootstrap',
      'challenge',
      'session',
      'registration',
      'membergate',
      'creator',
      'profile',
      'card',
      'feed',
      'follows',
      'notifications',
      'comments',
      'contacts',
      'topup_config',
      'topup_status',
      'chat_access',
      'media',
    };
    const phases = {'headers', 'complete', 'error', 'cancelled'};
    String micros(int? value) =>
        value != null && value >= 0 && value <= 9007199254740991
        ? '$value'
        : 'none';
    final safeStage = stages.contains(stage) ? stage : 'other';
    final safePhase = phases.contains(phase) ? phase : 'other';
    final status = statusCode != null && statusCode >= 100 && statusCode <= 599
        ? '$statusCode'
        : 'none';
    final header = headersMicros != null && headersMicros <= elapsedMicros
        ? micros(headersMicros)
        : 'none';
    try {
      debugPrintSynchronously(
        '[CitizenHttp] stage=$safeStage http=$status '
        'headers_us=$header total_us=${micros(elapsedMicros)} phase=$safePhase',
      );
    } on Object {
      // 出口故障不得改变原HTTP结果、原异常或流的生命周期。
    }
  }

  /// 提案读取只报告固定阶段和类别；不得读取异常原文或改变调用方的异常。
  static void proposalFailure({required String stage, required Object error}) {
    final code = switch (error) {
      CitizenSdkException() => 'sdk_${error.code.name}',
      FormatException() => 'format',
      TypeError() => 'type',
      StateError() => 'state',
      _ => 'other',
    };
    failure(stage: stage, code: code);
  }

  /// 原提案首批/刷新仅输出闭集状态；不接收代次、身份、提案或异常内容。
  static void proposalRead({required String state}) {
    const states = {'waiting', 'started', 'empty', 'nonempty'};
    final safeState = states.contains(state) ? state : 'other';
    try {
      debugPrintSynchronously('[CitizenRead] stage=proposal_first state=$safeState');
    } on Object {
      // 完成回执出口失败不得改变真实读取结果。
    }
  }

  /// 充值只接受精确字段和固定阶段；URI、会话及异常内容不能进入日志门面。
  /// Release也可输出闭集行，不启用自由文本或诊断文件；出口失败不影响连接。
  static bool topupConnection(Object? value) {
    const stages = {'start', 'connect', 'uri', 'modal', 'end'};
    const flags = [
      'listening', 'connecting', 'emitted', 'provider_uri',
      'modal_uri', 'matched', 'baseline', 'complete',
    ];
    if (value is! Map ||
        value.length != flags.length + 1 ||
        !stages.contains(value['stage']) ||
        flags.any((key) => value[key] is! bool)) {
      return false;
    }
    try {
      final fields = flags.map((key) => '$key=${value[key] == true ? 1 : 0}');
      debugPrintSynchronously(
        '[CitizenTopup] stage=${value['stage']} ${fields.join(' ')}',
      );
    } on Object {
      // 观察出口故障不得改变原连接或付款流程。
    }
    return true;
  }

  /// SDK错误与连接竞赛只接收精确闭集，不接收message、topic、URI或原始日志参数。
  static bool topupConnectTrace(Object? value) {
    const events = {
      'ready', 'connect', 'pairing', 'relay_open', 'relay_closed', 'relay_error',
      'subscribed', 'published', 'attempt', 'sdk_error', 'socket_close', 'end',
      'provider_resolved', 'provider_rejected', 'modal_closed',
      'modal_open_failed', 'setup_rejected',
    };
    const winners = {
      'pending', 'provider_resolved', 'provider_rejected', 'modal_closed',
      'modal_open_failed', 'setup_rejected',
    };
    const errors = {
      'none', 'other', 'type', 'offline', 'socket_interrupted',
      'subscribe_interrupted', 'socket_closed', 'socket_missing',
      'proposal_expired', 'client_missing', 'publish_failed', 'http_401',
      'http_403', 'http_429', 'http_503', 'socket_stalled', 'socket_failed',
      'user_closed', 'origin_denied', 'invalid_key', 'project_missing',
      'relay_unauthorized',
    };
    const codes = {
      'none', '0', '401', '403', '429', '503', '1000', '1001', '1006',
      '1008', '1011', '1013', '3000', '-32600', '-32601', '-32602', '-32603',
    };
    const flags = [
      'pairing', 'subscribed', 'published', 'relay_connected',
      'relay_connecting', 'complete',
    ];
    if (value is! Map || value.length != 13 || value['stage'] != 'trace' ||
        !events.contains(value['event']) || !winners.contains(value['winner']) ||
        !errors.contains(value['error']) || !codes.contains(value['code']) ||
        flags.any((key) => value[key] is! bool) ||
        ['attempts', 'stalls'].any((key) => value[key] is! int ||
            (value[key] as int) < 0 || (value[key] as int) > 20)) {
      return false;
    }
    try {
      final fields = flags.map((key) => '$key=${value[key] == true ? 1 : 0}');
      debugPrintSynchronously('[CitizenTopup] stage=trace event=${value['event']} '
          'winner=${value['winner']} error=${value['error']} code=${value['code']} '
          '${fields.join(' ')} attempts=${value['attempts']} stalls=${value['stalls']}');
    } on Object {
      // 取证失败不能改变原Promise或付款结果。
    }
    return true;
  }

  /// 原生打开仅报告闭集结果，系统返回成功仍须独立验证钱包前台。
  static void topupWallet(String state) {
    const states = {'requested', 'busy', 'opened', 'rejected'};
    final safeState = states.contains(state) ? state : 'other';
    try {
      debugPrintSynchronously('[CitizenTopup] stage=native state=$safeState');
    } on Object {
      // 观察出口故障不得改变原生打开结果。
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
