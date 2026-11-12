// 统一机构账户行(ADR-028 决策 2)——合并公权「派生账户」与治理「固定账户」两套。
//
//
// - 创世治理机构:账户是 china 创世固定 hex,由 [Institution.builtinAccounts] 承载,不可派生。
// - 普通机构:主/费用/附加账户一律按名称路由本地派生(account_derivation 卡0,零网络)；
//   附加账户既可能是制度协议账户，也可能是普通自定义命名账户。
// - 余额另由链态服务批量补(ADR-018 R2 精确整键批量,不逐条)。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_citizen/reserved_account_names.dart';

/// 单个机构账户行（标签 + AccountId + SS58 + 可选余额）。
class InstitutionAccountRow {
  const InstitutionAccountRow({
    required this.label,
    required this.accountId,
    required this.accountAddress,
  });

  final String label;
  final String accountId;
  final String accountAddress;
}

/// 由机构构造全部账户行:固定治理档用 china 固定账户,普通机构本地派生。
List<InstitutionAccountRow> institutionAccountIdRows(Institution inst) {
  final baked = inst.builtinAccounts;
  if (baked != null) {
    final rows = <InstitutionAccountRow>[
      _rowFromAccountId(kReservedNameMain, baked.mainAccountId),
      _rowFromAccountId(kReservedNameFee, baked.feeAccountId),
    ];
    final safety = baked.safetyFundAccountId;
    if (safety != null) {
      rows.add(_rowFromAccountId(kReservedNameSafetyFund, safety));
    }
    final he = baked.heAccountId;
    if (he != null) rows.add(_rowFromAccountId(kReservedNameHe, he));
    final stake = baked.stakeAccountId;
    if (stake != null) rows.add(_rowFromAccountId(kReservedNameStake, stake));
    return rows;
  }

  // 普通机构:主 + 费用 + 链快照列出的附加账户(本地派生)。
  // custom_account_names 是快照字段名，不代表其中每项都允许用户自定义注册：
  // 制度账户必须先按保留名路由到专用 op_tag，普通名称才回落 OP_NAME。
  final rows = <InstitutionAccountRow>[];
  final main = deriveInstitutionMainAccountId(inst.cidNumber);
  rows.add(
    InstitutionAccountRow(
      label: kReservedNameMain,
      accountId: citizenAccountIdFromBytes(main),
      accountAddress: citizenSs58FromAccountIdBytes(main),
    ),
  );
  final feeId = deriveInstitutionFeeAccountId(inst.cidNumber);
  rows.add(
    InstitutionAccountRow(
      label: kReservedNameFee,
      accountId: citizenAccountIdFromBytes(feeId),
      accountAddress: citizenSs58FromAccountIdBytes(feeId),
    ),
  );
  for (final name in inst.accountNames) {
    if (name.isEmpty || name == kReservedNameMain || name == kReservedNameFee) {
      continue;
    }
    final id = deriveInstitutionAccountIdByName(inst.cidNumber, name);
    rows.add(
      InstitutionAccountRow(
        label: name,
        accountId: citizenAccountIdFromBytes(id),
        accountAddress: citizenSs58FromAccountIdBytes(id),
      ),
    );
  }
  return rows;
}

InstitutionAccountRow _rowFromAccountId(String label, String accountId) {
  return InstitutionAccountRow(
    label: label,
    accountId: accountId,
    accountAddress: citizenSs58FromAccountId(accountId),
  );
}
