// 提供固定治理机构目录、制度账户、联合投票常量及反向查找。

library;

import 'package:citizen_citizen/institution/institution_info.dart';

part 'governance_registry.generated.dart';

/// 链上联合投票总票数。
int get jointVoteTotal => 19 + kPrcs.length + kProvincialBanks.length;

/// 链上联合投票立即通过阈值。
const int jointVotePassThreshold = 105;

/// 通过机构唯一 CID 查找内置治理机构。
InstitutionInfo? findInstitutionByCidNumber(String cidNumber) {
  for (final inst in [
    ...kNrc,
    ...kPrcs,
    ...kProvincialBanks,
    ...kFixedGovernanceInstitutions,
  ]) {
    if (inst.cidNumber == cidNumber) return inst;
  }
  return null;
}

/// 把明确属于个人多签的 32 字节执行账户包装为个人多签上下文。
///
/// 机构提案禁止调用本函数；机构只能按 `actor_cid_number` 查找，不能从
/// execution account、主账户或管理员钱包回落反推身份。
