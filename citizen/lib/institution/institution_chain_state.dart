// 按机构CID组合链上名册和提案状态，余额交由SDK独立管理。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_multisig/multisig_transfer_proposal_adapter.dart';
import 'package:citizen_multisig/multisig_transfer_service.dart';

/// 机构提案摘要(详情页提案列表用)。
class InstitutionProposalSummary {
  const InstitutionProposalSummary({
    required this.proposalId,
    required this.idLabel,
    required this.status,
  });

  final BigInt proposalId;
  final String idLabel;

  /// 0=表决中 1=通过 2=否决 3=已执行 4=执行失败。
  final int status;

  String get statusLabel => switch (status) {
    1 => '已通过',
    2 => '已否决',
    3 => '已执行',
    4 => '执行失败',
    _ => '表决中',
  };
}

/// 统一机构链态读服务接口(可注入 fake 单测)。
abstract interface class InstitutionChainState {
  /// 完整管理员人员集合左连接岗位任职；无岗位管理员仍保留。
  Future<List<InstitutionPersonView>> personViews(Institution institution);

  /// 该机构当年提案(按 subject_cid_numbers 包含机构 CID 过滤当年缓存)。
  Future<List<InstitutionProposalSummary>> proposals(Institution institution);
}

/// 生产实现:复用既有链读基础设施。链读需联网,真机验证。
class LiveInstitutionChainState implements InstitutionChainState {
  LiveInstitutionChainState({
    required CitizenSdk chain,
    required CitizenSdk transactions,
    InstitutionChainService? adminService,
    MultisigTransferProposalFeed? feed,
  }) : _adminService = adminService ?? InstitutionChainService(chain: chain),
       _feed =
           feed ??
           MultisigTransferProposalFeed(
             service: MultisigTransferService(
               chain: chain,
               transactions: transactions,
             ),
           );

  final InstitutionChainService _adminService;
  final MultisigTransferProposalFeed _feed;

  @override
  Future<List<InstitutionPersonView>> personViews(Institution institution) {
    return _adminService.fetchPersonViews(institutionIdentityOf(institution));
  }

  @override
  Future<List<InstitutionProposalSummary>> proposals(
    Institution institution,
  ) async {
    final all = await _feed.currentYearProposals();
    final out = <InstitutionProposalSummary>[];
    for (final p in all) {
      if (p.meta.subjectCidNumbers.contains(institution.cidNumber)) {
        out.add(
          InstitutionProposalSummary(
            proposalId: p.meta.proposalId,
            idLabel: '提案 #${p.meta.proposalId}',
            status: p.meta.status,
          ),
        );
      }
    }
    return out;
  }
}

/// 机构 → 管理员账户身份(单一路由,机构码决定):
/// 所有机构统一以 CID 构造管理员主体，具体账户不进入授权身份。
InstitutionIdentity institutionIdentityOf(Institution institution) {
  return InstitutionIdentity(
    cidNumber: institution.cidNumber,
    orgCode: institution.orgCode,
    kind: InstitutionCodeLabel.isUnincorporated(institution.orgCode)
        ? null
        : InstitutionCodeLabel.entityKind(institution.orgCode),
    accountLabel: institution.fullName,
  );
}
