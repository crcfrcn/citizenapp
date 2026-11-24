// 展示机构人员CID、有效岗位任职及当前链上绑定钱包。
import 'package:flutter/material.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_system/theme/app_layout.dart';

class InstitutionAssignmentCard extends StatelessWidget {
  const InstitutionAssignmentCard({
    super.key,
    required this.person,
    this.index,
    this.balanceFen,
    this.trailing,
  });
  final InstitutionPersonView person;
  final int? index;
  final BigInt? balanceFen;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: index == null ? null : CircleAvatar(child: Text('$index')),
            title: Text(person.personCid),
            subtitle: Text(person.assignments.map((a) => a.roleName).join('、')),
            trailing: trailing,
          ),
          for (final assignment in person.assignments) ...[
            Text('${assignment.roleName} · ${assignment.termLabel}'),
            Text(
              '来源：${assignment.source.label}${assignment.sourceRef.isEmpty ? '' : '（${assignment.sourceRef}）'}',
            ),
          ],
          const Divider(),
          Text(
            '当前绑定钱包：${person.accountId == null ? '—' : citizenSs58FromAccountId(person.accountId!)}',
          ),
          if (balanceFen != null) Text('账户余额：${formatFen(balanceFen!)} 元'),
        ],
      ),
    ),
  );
}
