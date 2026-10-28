import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:citizenapp/network/citizen_serve_api_config.dart';

class RegistrationException implements Exception {
  const RegistrationException(
    this.message, {
    this.code = 'registration_unavailable',
  });
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// 原交易入口确认尚未进入execute；只能恢复验证阶段，不可用于未知广播。
class RegistrationBeforeBroadcastException extends RegistrationException {
  const RegistrationBeforeBroadcastException()
    : super('注册交易尚未开始，可重试本次已验证登记', code: 'before_broadcast');
}

void registrationFields(Map<String, dynamic> json, Set<String> fields) {
  if (json.length != fields.length || !json.keys.every(fields.contains)) {
    throw const FormatException('登记响应字段不完整或含未知字段');
  }
}

String registrationText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.length > 8192) {
    throw const FormatException('登记字符串无效');
  }
  return value;
}

int registrationInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0 || value > 9007199254740991) {
    throw const FormatException('登记整数无效');
  }
  return value;
}

/// 只含验证前已存在的账户、机构、创世和服务范围，没有CID或年份。
class RegistrationContext {
  RegistrationContext({
    required this.accountId,
    required this.orgCode,
    required this.chainScope,
    String? baseUrl,
    this.regScope = CitizenServeApiConfig.registrationScope,
  }) : baseUrl = CitizenServeApiConfig.normalize(
         baseUrl ?? CitizenServeApiConfig.baseUrl,
       ) {
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(accountId) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainScope) ||
        !{'CTZN', 'NATP'}.contains(orgCode) ||
        !RegExp(r'^citizenserve:[a-z][a-z0-9-]{0,31}$').hasMatch(regScope)) {
      throw const FormatException('登记上下文无效');
    }
  }
  final String accountId, orgCode, chainScope, baseUrl, regScope;
  String get serviceOrigin => Uri.parse(baseUrl).origin;
  String get contextHash => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            1,
            'CitizenCidRegistration',
            regScope,
            serviceOrigin,
            chainScope,
            accountId,
            orgCode,
          ]),
        ),
      )
      .toString();
  Map<String, Object?> toJson() => {
    'protocol_version': 1,
    'chain_scope': chainScope,
    'account_id': accountId,
    'org_code': orgCode,
  };
  Map<String, Object?> toRecord() => {
    ...toJson(),
    'base_url': baseUrl,
    'reg_scope': regScope,
  };
  factory RegistrationContext.fromRecord(Map<String, dynamic> value) {
    registrationFields(value, {
      'protocol_version',
      'chain_scope',
      'account_id',
      'org_code',
      'base_url',
      'reg_scope',
    });
    if (value['protocol_version'] != 1) throw const FormatException('登记协议版本无效');
    return RegistrationContext(
      accountId: registrationText(value, 'account_id'),
      orgCode: registrationText(value, 'org_code'),
      chainScope: registrationText(value, 'chain_scope'),
      baseUrl: registrationText(value, 'base_url'),
      regScope: registrationText(value, 'reg_scope'),
    );
  }
}

class RegistrationCapabilities {
  const RegistrationCapabilities(this.regId, this.recoveryToken);
  final String regId, recoveryToken;
  Map<String, Object?> toJson() => {
    'protocol_version': 1,
    'reg_id': regId,
    'recovery_token': recoveryToken,
  };
}

class RegistrationVerification {
  const RegistrationVerification(
    this.checkId,
    this.pageUrl,
    this.pageExpiresAt,
  );
  final String checkId;
  final Uri pageUrl;
  final int pageExpiresAt;
}

enum RegistrationState {
  prepared,
  humanVerified,
  activated,
  expired,
  cancelled,
}

enum RegistrationPhase {
  verification,
  verified,
  chainPending,
  finalized,
  activation,
  ready,
}

class RegistrationResponse {
  RegistrationResponse._(this.json, this.jobState, this.verification);
  final Map<String, dynamic> json;
  final RegistrationState jobState;
  final RegistrationVerification? verification;
  String get regId => registrationText(json, 'reg_id');
  factory RegistrationResponse.parse(
    Map<String, dynamic> json,
    RegistrationContext context, {
    RegistrationCapabilities? capabilities,
    bool initial = false,
  }) {
    registrationFields(json, {
      'is_ok',
      'protocol_version',
      'reg_id',
      'reg_scope',
      'service_origin',
      'context_hash',
      'job_state',
      'created_at',
      'expires_at',
      'human_at',
      'activation',
      'verification',
      if (initial) 'recovery_token',
    });
    if (json['is_ok'] != true ||
        json['protocol_version'] != 1 ||
        json['reg_scope'] != context.regScope ||
        json['service_origin'] != context.serviceOrigin ||
        json['context_hash'] != '0x${context.contextHash}' ||
        (capabilities != null && json['reg_id'] != capabilities.regId)) {
      throw const FormatException('登记响应上下文不一致');
    }
    registrationText(json, 'reg_id');
    if (initial) registrationText(json, 'recovery_token');
    final jobState = switch (json['job_state']) {
      'prepared' => RegistrationState.prepared,
      'human_verified' => RegistrationState.humanVerified,
      'activated' => RegistrationState.activated,
      'expired' => RegistrationState.expired,
      'cancelled' => RegistrationState.cancelled,
      _ => throw const FormatException('登记状态无效'),
    };
    final created = registrationInt(json, 'created_at');
    if (registrationInt(json, 'expires_at') <= created) {
      throw const FormatException('登记期限无效');
    }
    final verified = json['human_at'];
    if ((jobState == RegistrationState.humanVerified ||
            jobState == RegistrationState.activated) &&
        (verified is! int || verified < created)) {
      throw const FormatException('登记缺少服务器通过事实');
    }
    if (verified != null &&
        (verified is! int ||
            verified < created ||
            verified > 9007199254740991)) {
      throw const FormatException('登记验证时间无效');
    }
    RegistrationVerification? verification;
    final raw = json['verification'];
    if (raw != null) {
      if (raw is! Map<String, dynamic>) throw const FormatException('登记页面无效');
      registrationFields(raw, {
        'check_id',
        'page_url',
        'page_expires_at',
        'action',
        'hostname',
      });
      final page = CitizenServeApiConfig.capability(
        context.baseUrl,
        registrationText(raw, 'page_url'),
        '/user/registration/page',
        query: true,
      );
      final id = registrationText(raw, 'check_id');
      if (raw['action'] != 'cid_register' ||
          raw['hostname'] != page.host ||
          page.queryParametersAll.length != 2 ||
          page.queryParametersAll.values.any((v) => v.length != 1) ||
          page.queryParameters['check_id'] != id ||
          (page.queryParameters['page_token'] ?? '').isEmpty) {
        throw const FormatException('登记页面能力无效');
      }
      verification = RegistrationVerification(
        id,
        page,
        registrationInt(raw, 'page_expires_at'),
      );
    }
    final activation = json['activation'];
    if (jobState == RegistrationState.activated) {
      if (activation is! Map<String, dynamic>) {
        throw const FormatException('登记激活回执无效');
      }
      registrationFields(activation, {
        'cid_number',
        'account_id',
        'bind_rev',
        'device_id',
        'public_key',
      });
      if (activation['account_id'] != context.accountId ||
          !RegExp(r'^0x[0-9a-f]{64}$')
              .hasMatch(registrationText(activation, 'public_key')) ||
          activation['device_id'] !=
              (activation['public_key'] as String).substring(2)) {
        throw const FormatException('登记激活设备无效');
      }
      registrationText(activation, 'cid_number');
      registrationInt(activation, 'bind_rev');
    } else if (activation != null) {
      throw const FormatException('登记激活状态不一致');
    }
    if (jobState == RegistrationState.prepared && verification == null) {
      throw const FormatException('登记缺少验证页面');
    }
    return RegistrationResponse._(
      Map.unmodifiable(json),
      jobState,
      verification,
    );
  }
}

class FinalizedRegistration {
  const FinalizedRegistration({
    required this.binding,
    required this.chainHash,
    this.txHash,
  });
  final IdentityBinding binding;
  final String chainHash;
  final String? txHash;
  Map<String, Object?> toJson() => {
    'binding': binding.toJson(),
    'block_hash': chainHash,
    'tx_hash': txHash,
  };
  factory FinalizedRegistration.fromJson(Map<String, dynamic> json) {
    registrationFields(json, {'binding', 'block_hash', 'tx_hash'});
    final block = registrationText(json, 'block_hash');
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(block) ||
        json['binding'] is! Map<String, dynamic> ||
        (json['tx_hash'] != null &&
            !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(json['tx_hash'] as String))) {
      throw const FormatException('finalized记录无效');
    }
    return FinalizedRegistration(
      binding:
          (IdentityBinding.fromJson(jsonEncode(json['binding'])) ??
          (throw const FormatException('finalized绑定无效'))),
      chainHash: block,
      txHash: json['tx_hash'] as String?,
    );
  }
}

class RegistrationRecord {
  const RegistrationRecord({
    required this.context,
    required this.capabilities,
    required this.response,
    this.phase = RegistrationPhase.verification,
    this.finalized,
    this.checkpoint,
  });
  final RegistrationContext context;
  final RegistrationCapabilities capabilities;
  final RegistrationResponse response;
  final RegistrationPhase phase;
  final FinalizedRegistration? finalized;
  final Map<String, dynamic>? checkpoint;
  RegistrationRecord next({
    RegistrationResponse? response,
    RegistrationPhase? phase,
    FinalizedRegistration? finalized,
    Map<String, dynamic>? checkpoint,
  }) => RegistrationRecord(
    context: context,
    capabilities: capabilities,
    response: response ?? this.response,
    phase: phase ?? this.phase,
    finalized: finalized ?? this.finalized,
    checkpoint: checkpoint ?? this.checkpoint,
  );
  String encode() {
    if (capabilities.regId != response.regId) {
      throw const FormatException('登记恢复能力归属不一致');
    }
    return jsonEncode({
      'context': context.toRecord(),
      'recovery_token': capabilities.recoveryToken,
      'response': {...response.json}..remove('recovery_token'),
      'phase': phase.name,
      'finalized': finalized?.toJson(),
      'checkpoint': checkpoint,
    });
  }

  factory RegistrationRecord.decode(String text) {
    final raw = jsonDecode(text) as Map<String, dynamic>;
    registrationFields(raw, {
      'context',
      'recovery_token',
      'response',
      'phase',
      'finalized',
      'checkpoint',
    });
    final context = RegistrationContext.fromRecord(
      raw['context'] as Map<String, dynamic>,
    );
    final response = raw['response'] as Map<String, dynamic>;
    final capabilities = RegistrationCapabilities(
      registrationText(response, 'reg_id'),
      registrationText(raw, 'recovery_token'),
    );
    final finalized = raw['finalized'] == null
        ? null
        : FinalizedRegistration.fromJson(
            raw['finalized'] as Map<String, dynamic>,
          );
    if (finalized != null &&
        (finalized.binding.accountId != context.accountId ||
            finalized.binding.genesisHash != context.chainScope)) {
      throw const FormatException('登记finalized属主不一致');
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
        throw const FormatException('SDK公开检查点无效');
      }
    }
    return RegistrationRecord(
      context: context,
      capabilities: capabilities,
      response: RegistrationResponse.parse(
        response,
        context,
        capabilities: capabilities,
      ),
      phase: RegistrationPhase.values.byName(raw['phase'] as String),
      finalized: finalized,
      checkpoint: raw['checkpoint'] as Map<String, dynamic>?,
    );
  }
}
