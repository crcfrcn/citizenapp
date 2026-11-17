import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';

import 'package:citizen_citizen/institution/institution_role_models.dart';

import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';

/// 机构管理员人员卡；姓名与账户来自 admins，岗位任职来自 entity。
class InstitutionAssignmentCard extends StatelessWidget {
  const InstitutionAssignmentCard({
    super.key,
    required this.adminView,
    this.index,
    this.balanceFen,
    this.trailing,
  });

  final InstitutionAdminView adminView;
  final int? index;
  final BigInt? balanceFen;
  final Widget? trailing;
  static const double actionHeight = 30;

  String _summary(String Function(InstitutionAdminAssignment) format) {
    if (!adminView.assignmentsLoaded) return '—';
    final assignments = adminView.assignments;
    if (assignments.isEmpty) return '没有任职';
    final values = assignments.map(format).toList();
    if (values.toSet().length == 1) return values.first;
    return [
      for (var i = 0; i < assignments.length; i++)
        '${assignments[i].roleName} ${values[i]}',
    ].join('；');
  }

  Widget _field(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 12),
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(width: AppLayout.scaled(context, 6)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 12),
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = adminView.admin;
    final name = '${admin.familyName}${admin.givenName}'.trim();
    final personName = name.isEmpty ? '没有任职' : name;
    // 岗位未知时不展示旧资料，也不把未知状态写成“暂无岗位”。
    final roleName = !adminView.assignmentsLoaded
        ? '—'
        : adminView.assignments.isEmpty
        ? '没有任职'
        : adminView.assignments
              .map((assignment) => assignment.roleName)
              .join('、');
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (index != null) ...[
                  // 与票据明细现有圆圈数字的尺寸、配色和字体保持一致。
                  CircleAvatar(
                    radius: AppLayout.scaled(context, 16),
                    backgroundColor: AppTheme.primaryDark.withValues(
                      alpha: 0.08,
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: AppLayout.scaled(context, 12),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  SizedBox(width: AppLayout.scaled(context, 8)),
                ],
                Expanded(
                  child: Row(
                    children: [
                      if (roleName.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            roleName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (personName.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppLayout.scaled(context, 6),
                            ),
                            // 几何圆点不依赖字形基线，始终在两侧文字间居中。
                            child: Container(
                              width: AppLayout.scaled(context, 3),
                              height: AppLayout.scaled(context, 3),
                              decoration: const BoxDecoration(
                                color: AppTheme.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                      Flexible(
                        child: Text(
                          personName,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            const Divider(height: 1),
            SizedBox(height: AppLayout.scaled(context, 10)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    context,
                    '来源',
                    _summary(
                      (assignment) => assignment.sourceRef.isEmpty
                          ? assignment.source.label
                          : '${assignment.source.label}（依据：${assignment.sourceRef}）',
                    ),
                  ),
                ),
                SizedBox(width: AppLayout.scaled(context, 8)),
                Expanded(
                  flex: 2,
                  child: _field(
                    context,
                    '任期',
                    _summary((assignment) => assignment.termLabel),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppLayout.scaled(context, 10)),
            _field(
              context,
              '账户余额',
              balanceFen == null ? '' : '${formatFen(balanceFen!)} 元',
            ),
            SizedBox(height: AppLayout.scaled(context, 10)),
            _field(context, '管理员账户', citizenSs58FromAccountId(admin.accountId)),
          ],
        ),
      ),
    );
  }
}
