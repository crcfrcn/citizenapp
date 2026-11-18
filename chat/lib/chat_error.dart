import 'transport/attachment_transfer.dart';
import 'package:citizen_network/mls_authentication.dart';
import 'package:citizen_user/square_api_client.dart';

/// 公民聊天 对App公开的稳定错误分类；产品文案由App应用映射。
enum ChatErrorCode {
  invalidContent,
  contentTooLarge,
  invalidMessage,
  routeMismatch,
  expired,
  recipientKeyUnavailable,
  encryptionFailed,
  decryptionFailed,
  protocolRejected,
  storageRequired,
  transportFailed,
}

/// 通用 公民聊天 异常不得包含明文、密钥或产品身份信息。
final class ChatException implements Exception {
  const ChatException(this.code, this.message);

  final ChatErrorCode code;
  final String message;

  @override
  String toString() => 'ChatException(${code.name}: $message)';
}

/// 聊天诊断只输出已知固定码；底层动态异常、正文和凭证不进入日志。
String chatDiagnosticCode(Object error) {
  if (error is MlsException) {
    return error.diagnosticCode;
  }
  if (error is ChatConnectionException) {
    return error.code;
  }
  if (error is SquarePreflightException) {
    return const {
          'resource_limit',
          'session_expired',
          'identity_changed',
          'invalid_resource_cost',
        }.contains(error.code)
        ? error.code
        : 'preflight_failed';
  }
  if (error is SquareApiException) {
    final code = error.errorCode;
    if (const {
      'cid_not_bound',
      'identity_unregistered',
      'device_not_registered',
      'chat_device_not_registered',
      'invalid_mls_signature',
      'invalid_mls_proof',
      'cid_binding_changed',
      'missing_session',
      'invalid_session',
      'session_expired',
      'chat_server_not_configured',
      'chain_rpc_budget_exceeded',
    }.contains(code)) {
      return code!;
    }
    return switch (error.statusCode) {
      401 => 'service_unauthorized',
      403 => 'service_forbidden',
      429 => 'resource_limit',
      _ => 'service_unavailable',
    };
  }
  if (error is ChatException) {
    return error.code.name;
  }
  return 'operation_failed';
}

String chatUserErrorMessage(
  Object error, {
  String fallback = '聊天暂时无法使用，请稍后重试',
}) {
  if (error is SquarePreflightException) {
    return error.message;
  }
  if (error is SquareApiException) {
    return switch (error.errorCode) {
      'cid_not_bound' => '公民身份同步失败，请重试',
      'identity_unregistered' => '当前默认账户尚未注册公民号，无法使用聊天',
      'device_not_registered' ||
      'chat_device_not_registered' ||
      'invalid_mls_signature' ||
      'invalid_mls_proof' => '聊天设备身份尚未就绪，请重试',
      'cid_binding_changed' => '当前登录用户已切换，请重新进入聊天',
      'missing_session' ||
      'invalid_session' ||
      'session_expired' => '聊天会话已失效，请重试',
      'attachment_membergate_required' => '非会员禁止使用聊天附件',
      'chat_server_not_configured' => '聊天服务尚未配置',
      _ =>
        error.statusCode == null || error.statusCode! >= 500
            ? '聊天服务暂时无法连接，请稍后重试'
            : fallback,
    };
  }
  return chatErrorMessage(error, fallback: fallback);
}
