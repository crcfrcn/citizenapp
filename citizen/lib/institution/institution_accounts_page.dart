import 'package:citizen_widgets/chain_balance_scope.dart';
import 'package:flutter/material.dart';

import 'package:citizen_citizen/institution/institution.dart';
import 'package:citizen_citizen/institution/institution_accounts.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 统一机构「全部账户」页(ADR-028 决策 2)——替代公权/治理两套账户页。
///
/// 账户行由 [institutionAccountIdRows] 统一构造(固定治理档用 china 固定
/// 账户、普通机构本地派生);余额由 SDK 统一订阅服务批量读取(ADR-018 R2 精确整键批量)。
class InstitutionAccountsPage extends StatefulWidget {
  const InstitutionAccountsPage({super.key, required this.institution});

  final Institution institution;

  @override
  State<InstitutionAccountsPage> createState() =>
      _InstitutionAccountsPageState();
}

class _InstitutionAccountsPageState extends State<InstitutionAccountsPage> {
  late List<InstitutionAccountRow> _rows = institutionAccountIdRows(
    widget.institution,
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('全部账户'),
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
        itemCount: _rows.length,
        separatorBuilder: (_, _) =>
            SizedBox(height: AppLayout.scaled(context, 10)),
        itemBuilder: (context, i) => _AccountCard(row: _rows[i]),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.row});

  final InstitutionAccountRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(12)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              ChainBalanceText(
                accountId: row.accountId,
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 13.5),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.scaled(context, 6)),
          Text(
            row.accountAddress,
            style: TextStyle(
              fontSize: AppLayout.scaled(context, 11.5),
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
