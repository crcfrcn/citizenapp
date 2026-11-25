// 定义机构内部管理提案的完整展示内容；不以本机详情授予投票资格。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:typed_data';

/// 一行冻结业务内容。原始值完整保存，页面可另行决定布局和复制方式。
class InstitutionDetailRow {
  const InstitutionDetailRow(this.label, this.value, {this.copyable = false});
  final String label;
  final String value;
  final bool copyable;
  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    'copyable': copyable,
  };
}

/// 机构管理共用详情接口；状态、票据和阈值快照仍由投票引擎提供。
abstract interface class InstitutionProposalInfo {
  BigInt get proposalId;
  String get actorCidNumber;
  String get title;
  List<InstitutionDetailRow> get rows;
  Map<String, Object?> toJson();

  static InstitutionProposalInfo? fromJson(
    BigInt id,
    Map<String, Object?> json,
  ) {
    try {
      final cid = json['actor_cid_number'];
      if (cid is! String || cid.isEmpty) return null;
      if (json['kind'] == 'institution_close') {
        final account = json['institution_account_id'],
            beneficiary = json['beneficiary'],
            proposer = json['proposer'];
        if (account is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(account) ||
            beneficiary is! String ||
            beneficiary.isEmpty ||
            proposer is! String ||
            proposer.isEmpty) {
          return null;
        }
        return CloseProposalInfo(
          proposalId: id,
          actorCidNumber: cid,
          institutionAccountId: account,
          beneficiary: beneficiary,
          proposer: proposer,
        );
      }
      final action = json['action'], values = json['rows'];
      if (json['kind'] != 'institution_change' ||
          action is! int ||
          ![3, 4, 5].contains(action) ||
          values is! List ||
          values.isEmpty ||
          values.length > 8192) {
        return null;
      }
      final rows = <InstitutionDetailRow>[];
      for (final row in values) {
        if (row is! Map ||
            row['label'] is! String ||
            (row['label'] as String).isEmpty ||
            row['value'] is! String ||
            row['copyable'] is! bool) {
          return null;
        }
        rows.add(
          InstitutionDetailRow(
            row['label'] as String,
            row['value'] as String,
            copyable: row['copyable'] as bool,
          ),
        );
      }
      return InstitutionChangeInfo(
        proposalId: id,
        actorCidNumber: cid,
        action: action,
        rows: rows,
      );
    } on Object {
      return null;
    }
  }
}

/// 岗位、账户新增和原生政策只保存载荷中真实存在的目标内容，不倒推历史人员。
class InstitutionChangeInfo implements InstitutionProposalInfo {
  InstitutionChangeInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.action,
    required List<InstitutionDetailRow> rows,
  }) : rows = List.unmodifiable(rows);
  @override
  final BigInt proposalId;
  @override
  final String actorCidNumber;
  final int action;
  @override
  final List<InstitutionDetailRow> rows;
  @override
  String get title => switch (action) {
    3 => '岗位与任职治理',
    4 => '新增机构账户',
    5 => '原生权限与共同阈值政策',
    _ => throw StateError('未知机构管理动作'),
  };
  @override
  Map<String, Object?> toJson() => {
    'kind': 'institution_change',
    'actor_cid_number': actorCidNumber,
    'action': action,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}

/// 公权/私权机构 关闭机构多签账户提案详情（从链上 ProposalData 解码）。
///
/// 链上 SCALE 布局（`pub-mgmt`/`pri-mgmt` + ACTION_CLOSE = 2 前缀之后）：
///   actor_cid_number + institution_account_id: AccountId32(32)
///   + beneficiary: AccountId32(32) + proposer: AccountId32(32)
class CloseProposalInfo implements InstitutionProposalInfo {
  const CloseProposalInfo({
    required this.proposalId,
    required this.actorCidNumber,
    required this.institutionAccountId,
    required this.beneficiary,
    required this.proposer,
    this.status,
  });

  @override
  final BigInt proposalId;
  @override
  final String actorCidNumber;

  /// 销户提案的公开结果及快照使用 64 位小写十六进制正文。
  final String institutionAccountId;

  /// 受益人 SS58 地址。
  final String beneficiary;

  /// 发起人 SS58 地址。
  final String proposer;

  /// 0=voting, 1=passed, 2=rejected, null=unknown。
  final int? status;

  @override
  String get title => '关闭机构账户';
  @override
  List<InstitutionDetailRow> get rows => [
    InstitutionDetailRow(
      '机构账户',
      citizenSs58FromAccountIdBytes(institutionBytes),
      copyable: true,
    ),
    InstitutionDetailRow('受益账户', beneficiary, copyable: true),
    InstitutionDetailRow('发起账户', proposer, copyable: true),
  ];
  @override
  Map<String, Object?> toJson() => {
    'kind': 'institution_close',
    'actor_cid_number': actorCidNumber,
    'institution_account_id': institutionAccountId,
    'beneficiary': beneficiary,
    'proposer': proposer,
  };

  /// 机构多签 AccountId32。
  Uint8List get institutionBytes =>
      citizenAccountIdBytes('0x$institutionAccountId');

  CloseProposalInfo copyWithStatus(int? newStatus) {
    return CloseProposalInfo(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      institutionAccountId: institutionAccountId,
      beneficiary: beneficiary,
      proposer: proposer,
      status: newStatus,
    );
  }
}
