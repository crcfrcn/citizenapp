import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';

import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_network/citizen_serve_api_config.dart';

class RegistrationException implements Exception {
  const RegistrationException(
    this.message, {
    this.code = 'registration_unavailable',
  });
  final String message, code;
  @override
  String toString() => message;
}

/// 原SDK执行尚未开始，不能用此异常处理未知广播。
class RegistrationBeforeBroadcastException extends RegistrationException {
  const RegistrationBeforeBroadcastException()
    : super('注册交易尚未开始，可主动重试', code: 'before_broadcast');
}

void registrationFields(Map<String, dynamic> value, Set<String> fields) {
  if (value.length != fields.length || !value.keys.every(fields.contains)) {
    throw const FormatException('注册数据字段无效');
  }
}

String registrationText(Map<String, dynamic> value, String name) {
  final text = value[name];
  if (text is! String || text.isEmpty || text.length > 8192) {
    throw const FormatException('注册数据无效');
  }
  return text;
}

/// 当前选择账户及链；自然键只定位本机交易，不生成登记摘要或服务端任务。
class RegistrationContext {
  RegistrationContext({
    required this.accountId,
    required this.orgCode,
    required this.chainScope,
    String? baseUrl,
  }) : baseUrl = CitizenServeApiConfig.normalize(
         baseUrl ?? CitizenServeApiConfig.baseUrl,
       ) {
    if (!isCitizenAccountId(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainScope) ||
        !{'CTZN', 'NATP'}.contains(orgCode)) {
      throw const FormatException('注册账户或链无效');
    }
  }
  final String accountId, orgCode, chainScope, baseUrl;
  String get recordKey => jsonEncode([chainScope, accountId]);
  Map<String, Object> toRecord() => {
    'base_url': baseUrl,
    'chain_scope': chainScope,
    'account_id': accountId,
    'org_code': orgCode,
  };
  factory RegistrationContext.fromRecord(Map<String, dynamic> value) {
    registrationFields(value, {
      'base_url',
      'chain_scope',
      'account_id',
      'org_code',
    });
    return RegistrationContext(
      baseUrl: registrationText(value, 'base_url'),
      chainScope: registrationText(value, 'chain_scope'),
      accountId: registrationText(value, 'account_id'),
      orgCode: registrationText(value, 'org_code'),
    );
  }
}

/// Cloudflare本次挑战的瞬时结果；只供Siteverify，不进入任何存储或链结果报告。
class RegistrationVerification {
  RegistrationVerification({required this.checkId, required this.token}) {
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(checkId) ||
        token.isEmpty ||
        token.length > 2048 ||
        token.trim() != token) {
      throw const FormatException('真人验证结果无效');
    }
  }
  final String checkId, token;
  Map<String, Object> toJson() => {
    'check_id': checkId,
    'turnstile_token': token,
  };
}

/// 原SDK已确认的链结果；区块事实保留在本机，报告只发送绑定中的公民号和账户。
class FinalizedRegistration {
  const FinalizedRegistration({
    required this.binding,
    required this.blockHash,
    this.txHash,
  });
  final IdentityBinding binding;
  final String blockHash;
  final String? txHash;
  Map<String, Object?> toJson() => {
    'binding': binding.toJson(),
    'block_hash': blockHash,
    'tx_hash': txHash,
  };
  factory FinalizedRegistration.fromJson(Map<String, dynamic> value) {
    registrationFields(value, {'binding', 'block_hash', 'tx_hash'});
    final block = registrationText(value, 'block_hash'), tx = value['tx_hash'];
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(block) ||
        (tx != null &&
            (tx is! String || !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(tx))) ||
        value['binding'] is! Map<String, dynamic>) {
      throw const FormatException('链注册结果无效');
    }
    final binding = IdentityBinding.fromJson(jsonEncode(value['binding']));
    if (binding == null) throw const FormatException('链绑定无效');
    binding.validate();
    return FinalizedRegistration(
      binding: binding,
      blockHash: block,
      txHash: tx as String?,
    );
  }
}

/// 仅保存原链交易检查点和真实最终结果；不保存人验、服务端状态或恢复秘密。
class RegistrationRecord {
  const RegistrationRecord({
    required this.context,
    this.checkpoint,
    this.finalized,
  });
  final RegistrationContext context;
  final Map<String, dynamic>? checkpoint;
  final FinalizedRegistration? finalized;
  RegistrationRecord next({
    Map<String, dynamic>? checkpoint,
    FinalizedRegistration? finalized,
  }) => RegistrationRecord(
    context: context,
    checkpoint: checkpoint ?? this.checkpoint,
    finalized: finalized ?? this.finalized,
  );
  String encode() => jsonEncode({
    'context': context.toRecord(),
    'checkpoint': checkpoint,
    'finalized': finalized?.toJson(),
  });
  factory RegistrationRecord.decode(String text) {
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic>) throw const FormatException('链注册记录无效');
    registrationFields(raw, {'context', 'checkpoint', 'finalized'});
    if (raw['context'] is! Map<String, dynamic>) {
      throw const FormatException('链注册属主无效');
    }
    final context = RegistrationContext.fromRecord(
      raw['context'] as Map<String, dynamic>,
    );
    if (raw['finalized'] != null && raw['finalized'] is! Map<String, dynamic>) {
      throw const FormatException('链注册结果结构无效');
    }
    final finalized = raw['finalized'] == null
        ? null
        : FinalizedRegistration.fromJson(
            raw['finalized'] as Map<String, dynamic>,
          );
    if (finalized != null &&
        (finalized.binding.accountId != context.accountId ||
            finalized.binding.genesisHash != context.chainScope)) {
      throw const FormatException('链注册结果属主不一致');
    }
    final checkpoint = raw['checkpoint'];
    if (checkpoint != null) {
      const fields = {
        'preparation_id',
        'account_id',
        'call_data_hash',
        'state',
        'execution_id',
        'tx_hash',
      };
      if (checkpoint is! Map<String, dynamic> ||
          !checkpoint.keys.every(fields.contains) ||
          checkpoint.values.any((v) => v is! String || v.length > 200) ||
          checkpoint['account_id'] != context.accountId ||
          checkpoint['call_data_hash'] is! String ||
          !RegExp(r'^0x[0-9a-f]{64}$')
              .hasMatch(checkpoint['call_data_hash'] as String) ||
          !{
            'prepared',
            'executing',
            'awaiting_qr',
            'cancelled_before_broadcast',
            'finalizedSuccess',
            'finalizedFailed',
            'poolRejected',
          }.contains(checkpoint['state'])) {
        throw const FormatException('SDK链交易检查点无效');
      }
    }
    return RegistrationRecord(
      context: context,
      checkpoint: checkpoint as Map<String, dynamic>?,
      finalized: finalized,
    );
  }
}
