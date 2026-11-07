/// 本机 Chat 设备身份。
class ChatDevice {
  const ChatDevice({
    required this.userId,
    required this.deviceId,
    this.publicKey,
  });

  /// Chat 永久用户身份主键，由宿主产品注入。
  final String userId;

  /// 同一用户下唯一设备标识。
  final String deviceId;

  /// 已初始化原生MLS签名公钥；只读公开值，不是独立设备认证钥。
  final String? publicKey;

  String? validate() {
    if (userId.trim().isEmpty || userId.contains(':')) {
      return 'Chat 用户身份不能为空且不能包含冒号';
    }
    if (deviceId.trim().isEmpty || deviceId.contains(':')) {
      return 'Chat 设备 ID 不能为空且不能包含冒号';
    }
    return null;
  }
}

/// 同一MLS身份的应用认证请求；不接受用户、设备、密钥或自选签名域。
///
/// 目标路径和正文必须与实际HTTPS请求逐字相同。调用方只能构造这一固定结构，
/// 不能用它获得普通MLS协议标签或其他任意字节的签名。
class MlsAuthenticationRequest {
  MlsAuthenticationRequest({
    required this.serviceOrigin,
    required this.nonceId,
    required this.expiresAt,
    required this.httpMethod,
    required this.requestTarget,
    required List<int> bodyBytes,
  }) : bodyBytes = List<int>.unmodifiable(bodyBytes);

  final String serviceOrigin;
  final String nonceId;
  final int expiresAt;
  final String httpMethod;
  final String requestTarget;
  final List<int> bodyBytes;

  static const maxBodyBytes = 1024 * 1024;
  static const maxJsonInteger = 9007199254740991;
  static final _hex32 = RegExp(r'^0x[0-9a-f]{64}$');
  static const _methods = {
    'GET',
    'HEAD',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'OPTIONS',
  };

  /// Dart提前拒绝无效结构；原生重复校验，FFI直接调用也不能绕过。
  void validate() {
    final origin = Uri.tryParse(serviceOrigin);
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        origin.path.isNotEmpty ||
        origin.port <= 0 ||
        origin.port > 65535 ||
        origin.origin != serviceOrigin ||
        serviceOrigin.length > 268 ||
        !serviceOrigin.codeUnits.every((byte) => byte >= 33 && byte <= 126) ||
        serviceOrigin.contains(r'\') ||
        !_hex32.hasMatch(nonceId) ||
        !_methods.contains(httpMethod) ||
        requestTarget.length > 8192 ||
        !requestTarget.startsWith('/') ||
        requestTarget.startsWith('//') ||
        requestTarget.contains('#') ||
        requestTarget.contains(r'\') ||
        !requestTarget.codeUnits.every((byte) => byte >= 33 && byte <= 126) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(requestTarget) ||
        bodyBytes.length > maxBodyBytes ||
        !bodyBytes.every((byte) => byte >= 0 && byte <= 255)) {
      throw ArgumentError('MLS认证请求结构无效');
    }
    validateExpiry(expiresAt);
  }

  static void validateExpiry(int expiry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry > maxJsonInteger || expiry <= now || expiry - now > 300000) {
      throw ArgumentError('MLS认证挑战已过期或有效期非法');
    }
  }

  /// 仅供固定身份JSON入口消费；不接收签名标签或原始待签内容。
  Map<String, Object> toJson() => {
    'service_origin': serviceOrigin,
    'nonce_id': nonceId,
    'expires_at': expiresAt,
    'http_method': httpMethod,
    'request_target': requestTarget,
    'body_hex': _bytesToHex(bodyBytes),
  };
}

/// 公开认证证明直接持有原生Serde输出的唯一字段集；不再逐字段回抄。
/// 私钥、正文与MLS内部状态不进入本对象。
class MlsAuthenticationProof {
  MlsAuthenticationProof.fromJson(Map<String, Object> fields)
    : _fields = Map<String, Object>.unmodifiable(fields) {
    const names = {
      'user_id',
      'device_id',
      'public_key',
      'account_id',
      'bind_rev',
      'service_origin',
      'nonce_id',
      'expires_at',
      'http_method',
      'request_target',
      'body_hash',
      'signature',
    };
    if (_fields.length != names.length ||
        !_fields.keys.every(names.contains) ||
        _fields.entries.any(
          (entry) =>
              entry.key != 'bind_rev' &&
              entry.key != 'expires_at' &&
              entry.value is! String,
        ) ||
        _fields['bind_rev'] is! int ||
        _fields['expires_at'] is! int) {
      throw const FormatException('MLS认证证明字段无效');
    }
  }

  final Map<String, Object> _fields;

  /// JSON键与原生合同完全相同，不创建旧名或第二份证明。
  Map<String, Object> toJson() => _fields;
}

String _bytesToHex(List<int> value) =>
    value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

enum MlsErrorCode {
  directoryInvalid,
  directoryUnavailable,
  stateMissing,
  stateOwnerMismatch,
  storageReadFailed,
  stateInvalid,
  signerMissing,
  libraryUnavailable,
  invalidRequest,
  invalidResponse,
  requestConflict,
  pendingFull,
  keyPackageFailed,
  operationFailed,
}

/// 公开诊断只携带固定FFI操作，不暴露路径、身份或请求内容。
enum MlsOperation {
  unknown,
  identity,
  store,
  keyPackage,
  groupCreate,
  groupAdd,
  groupRemove,
  groupMessage,
  groupProcess,
  groupState,
}

class MlsException implements Exception {
  const MlsException(
    this.code,
    this.technicalMessage, {
    this.operation = MlsOperation.unknown,
  });

  factory MlsException.fromTechnicalMessage(
    String message, {
    MlsOperation operation = MlsOperation.unknown,
  }) {
    final classified = _classify(message);
    return MlsException(classified, message, operation: operation);
  }

  static MlsErrorCode _classify(String message) {
    if (message == '解析request_json失败，字段或结构非法') {
      return MlsErrorCode.invalidRequest;
    }
    if (message.startsWith('CHAT_MLS_STATE_MISSING:')) {
      return MlsErrorCode.stateMissing;
    }
    if (message.contains('CHAT_MLS_STATE_OWNER_MISMATCH')) {
      return MlsErrorCode.stateOwnerMismatch;
    }
    if (message.contains('CHAT_MLS_STORAGE_READ_FAILED')) {
      return MlsErrorCode.storageReadFailed;
    }
    if (message.contains('CHAT_MLS_STATE_INVALID')) {
      return MlsErrorCode.stateInvalid;
    }
    if (message.contains('CHAT_MLS_SIGNER_MISSING')) {
      return MlsErrorCode.signerMissing;
    }
    if (message.startsWith('CHAT_MLS_REQUEST_CONFLICT:')) {
      return MlsErrorCode.requestConflict;
    }
    if (message.startsWith('CHAT_MLS_PENDING_FULL:')) {
      return MlsErrorCode.pendingFull;
    }
    if (message.startsWith('生成 OpenMLS KeyPackage 失败:')) {
      return MlsErrorCode.keyPackageFailed;
    }
    return MlsErrorCode.operationFailed;
  }

  final MlsErrorCode code;
  final String technicalMessage;
  final MlsOperation operation;

  String get diagnosticOperation => switch (operation) {
    MlsOperation.unknown => 'unknown',
    MlsOperation.identity => 'identity',
    MlsOperation.store => 'store',
    MlsOperation.keyPackage => 'key_package',
    MlsOperation.groupCreate => 'group_create',
    MlsOperation.groupAdd => 'group_add',
    MlsOperation.groupRemove => 'group_remove',
    MlsOperation.groupMessage => 'group_message',
    MlsOperation.groupProcess => 'group_process',
    MlsOperation.groupState => 'group_state',
  };

  /// 脱敏诊断只记录该稳定码，不记录用户、账户、路径、密钥或底层文本。
  String get diagnosticCode => switch (code) {
    MlsErrorCode.directoryInvalid => 'directory_invalid',
    MlsErrorCode.directoryUnavailable => 'directory_unavailable',
    MlsErrorCode.stateMissing => 'state_missing',
    MlsErrorCode.stateOwnerMismatch => 'state_owner_mismatch',
    MlsErrorCode.storageReadFailed => 'storage_read_failed',
    MlsErrorCode.stateInvalid => 'state_invalid',
    MlsErrorCode.signerMissing => 'signer_missing',
    MlsErrorCode.libraryUnavailable => 'library_unavailable',
    MlsErrorCode.invalidRequest => 'invalid_request',
    MlsErrorCode.invalidResponse => 'invalid_response',
    MlsErrorCode.requestConflict => 'request_conflict',
    MlsErrorCode.pendingFull => 'pending_full',
    MlsErrorCode.keyPackageFailed => 'key_package_failed',
    MlsErrorCode.operationFailed => 'operation_failed',
  };

  String get userMessage => switch (code) {
    MlsErrorCode.directoryInvalid => '本机聊天存储路径校验失败',
    MlsErrorCode.directoryUnavailable => '本机聊天存储暂时不可读取，请稍后重试',
    MlsErrorCode.stateMissing => '本机聊天身份文件缺失，聊天暂时无法使用',
    MlsErrorCode.stateOwnerMismatch => '当前用户身份的聊天设备状态属于其他用户，请重新切换账户后再试',
    MlsErrorCode.storageReadFailed ||
    MlsErrorCode.stateInvalid ||
    MlsErrorCode.signerMissing => '当前用户身份的聊天加密状态无法恢复，请重新进入宿主',
    MlsErrorCode.libraryUnavailable => '聊天安全组件加载失败，请重新安装当前版本',
    MlsErrorCode.invalidRequest ||
    MlsErrorCode.invalidResponse ||
    MlsErrorCode.requestConflict ||
    MlsErrorCode.pendingFull ||
    MlsErrorCode.keyPackageFailed ||
    MlsErrorCode.operationFailed => '聊天安全组件暂时无法使用，请稍后重试',
  };

  @override
  String toString() => technicalMessage;
}

/// 返回可持久记录的脱敏错误码；非 native 错误统一收敛，不读取异常原文。
String chatDiagnosticCode(Object error) =>
    error is MlsException ? error.diagnosticCode : 'operation_failed';

/// 将聊天MLS异常收敛为可公开展示的固定中文文案。
///
/// 未列入白名单的底层异常统一返回 [fallback]；禁止把 `Bad state`、动态库路径、native
/// 调试文本或损坏字节直接渲染到 Android/iOS 页面。
String chatErrorMessage(Object error, {String fallback = '聊天暂时无法使用，请稍后重试'}) {
  if (error is MlsException) return error.userMessage;
  final technical = error.toString();
  if (technical.contains('当前默认账户尚未注册用户身份')) {
    return '当前默认账户尚未注册用户身份，无法使用聊天';
  }
  if (technical.contains('身份账户已切换') ||
      technical.contains('用户身份当前绑定已切换') ||
      technical.contains('当前用户投影不一致')) {
    return '当前登录用户已切换，请重新进入聊天';
  }
  if (technical.contains('key_package_not_available') ||
      technical.contains('对方没有可用 Chat KeyPackage') ||
      technical.contains('没有可用 Chat KeyPackage')) {
    return '对方暂时无法接收加密消息，请稍后重试';
  }
  if (technical.contains('invalid_key_package_lifetime') ||
      technical.contains('key_package_write_rejected')) {
    return '聊天安全材料更新失败，请稍后重试';
  }
  if (technical.contains('对方尚未绑定身份（用户身份）')) {
    return '对方尚未绑定身份（用户身份）';
  }
  if (technical.contains('对方 用户身份 当前没有有效钱包绑定')) {
    return '对方 用户身份 当前没有有效钱包绑定';
  }
  if (technical.contains('允许麦克风权限')) {
    return '请在系统设置中允许麦克风权限';
  }
  if (technical.contains('已退出该群')) {
    return '已退出该群，无法继续操作';
  }
  if (technical.contains('群不存在')) {
    return '该群聊已不存在';
  }
  return fallback;
}
