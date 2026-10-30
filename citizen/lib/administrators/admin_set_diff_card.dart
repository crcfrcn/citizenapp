import 'package:flutter/material.dart';

import 'package:citizen_citizen/administrators/account_id_codec.dart';
import 'package:citizen_citizen/administrators/admin_account.dart';
import 'package:citizen_citizen/account_derivation.dart';
import 'package:citizen_transaction/amount_format.dart';
import 'package:citizen_system/theme/app_layout.dart';

class AdminSetDiffCard extends StatelessWidget {
  const AdminSetDiffCard({
    super.key,
    required this.currentAdmins,
    required this.admins,
    this.balances = const {},
  });

  final List<AdminPerson> currentAdmins;
  final List<AdminPerson> admins;
  final Map<String, double> balances;

  @override
  Widget build(BuildContext context) {
    final current = {
      for (final admin in currentAdmins)
        AdminAccountIdCodec.requireAccountId(admin.accountId): admin,
    };
    final next = {
      for (final admin in admins)
        AdminAccountIdCodec.requireAccountId(admin.accountId): admin,
    };
    final added = next.entries
        .where((entry) => !current.containsKey(entry.key))
        .map((entry) => entry.value)
        .toList();
    final removed = current.entries
        .where((entry) => !next.containsKey(entry.key))
        .map((entry) => entry.value)
        .toList();
    final renamed = next.entries
        .where((entry) {
          final old = current[entry.key];
          return old != null &&
              (old.familyName != entry.value.familyName ||
                  old.givenName != entry.value.givenName);
        })
        .map((entry) => entry.value)
        .toList();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppLayout.scaled(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '变更差异',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 15),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('新增', added),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('移除', removed),
            SizedBox(height: AppLayout.scaled(context, 8)),
            _buildAccountList('姓名调整', renamed),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(String title, List<AdminPerson> admins) {
    if (admins.isEmpty) return Text('$title：无');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title：'),
        SizedBox(height: AppLayout.scaledValue(6)),
        for (final admin in admins) ...[
          ListTile(
            dense: true,
            title: Text('${admin.familyName}${admin.givenName}'),
            subtitle: Text(
              '${ss58FromAccountIdText(admin.accountId)}\n'
              '余额：${AmountFormat.formatThousands(balances[AdminAccountIdCodec.requireAccountId(admin.accountId)])} 元',
            ),
          ),
          SizedBox(height: AppLayout.scaledValue(6)),
        ],
      ],
    );
  }
}
