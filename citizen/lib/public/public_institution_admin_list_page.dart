import 'package:citizen_widgets/chain_balance_scope.dart';
import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_citizen/institution/institution_admin_list_page.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 公权机构管理员列表；与机构列表复用同一本地钱包状态和激活控件。
class PublicInstitutionAdminListPage extends StatefulWidget {
  const PublicInstitutionAdminListPage({
    super.key,
    required this.admins,
    this.accountIdentity,
  });

  final List<InstitutionAdminView> admins;
  final AdminAccountIdentity? accountIdentity;

  @override
  State<PublicInstitutionAdminListPage> createState() =>
      _PublicInstitutionAdminListPageState();
}

class _PublicInstitutionAdminListPageState
    extends State<PublicInstitutionAdminListPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data != null) return;
    _data = AdminListState(
      admins: widget.admins,
      identity: widget.accountIdentity,
      sdk: context.read<CitizenSdk?>(),
    )..addListener(_changed);
    unawaited(_data!.load());
  }

  AdminListState? _data;
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data?.removeListener(_changed);
    _data?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: _data!.admins.map((view) => view.admin.accountId),
    builder: _buildBalanceView,
  );

  Widget _buildBalanceView(BuildContext context, CitizenBalances balances) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          '管理员列表',
          style: TextStyle(
            fontSize: AppLayout.scaled(context, 17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _data!.admins.isEmpty
          ? _emptyState()
          : ListView.separated(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              itemCount: _data!.admins.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: AppLayout.scaled(context, 10)),
              itemBuilder: (context, i) {
                final adminView = _data!.admins[i];
                final id = adminView.admin.accountId;
                return InstitutionAdminTile(
                  adminView: adminView,
                  index: i + 1,
                  accountIdentity: widget.accountIdentity,
                  isImported:
                      _data!.walletsReady && _data!.coldAccountIds.contains(id),
                  isActivated: _data!.activatedAccountIds.contains(id),
                  onActivated: () => _data!.markActivated(id),
                  balanceFen: balances
                      .accountState(adminView.admin.accountId)
                      .value
                      ?.freeFen,
                );
              },
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaledValue(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_outlined,
              size: AppLayout.scaledValue(44),
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: AppLayout.scaledValue(12)),
            Text(
              '暂无管理员',
              style: TextStyle(
                fontSize: AppLayout.scaledValue(14),
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppLayout.scaledValue(6)),
            Text(
              '该机构链上暂无管理员',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppLayout.scaledValue(12.5),
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
