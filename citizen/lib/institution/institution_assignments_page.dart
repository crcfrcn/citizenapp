// 展示机构人员任职，节点访问授权独立验真且不保存本机资格。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_citizen/institution/institution_assignment_card.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_widgets/chain_balance_scope.dart';

class InstitutionAssignmentsPage extends StatelessWidget {
  const InstitutionAssignmentsPage({
    super.key,
    required this.persons,
    this.identity,
    this.institution,
  });
  final List<InstitutionPersonView> persons;
  final InstitutionIdentity? identity;
  final InstitutionInfo? institution;

  Future<void> _roleAccess(
    BuildContext context,
    InstitutionPersonView person,
  ) async {
    final subject = identity, account = person.accountId;
    if (subject == null || account == null) return;
    final sdk = context.read<CitizenSdk>();
    final wallets = (await sdk.getWalletState().result).accounts;
    if (!wallets.any((wallet) => wallet.accountId == account)) return;
    final payload = await InstitutionChainService(
      chain: sdk,
    ).buildRoleAccessPayload(identity: subject, accountId: account);
    if (!context.mounted) return;
    await signCitizenPayload(
      signing: sdk,
      context: context,
      accountId: account,
      payload: payload,
      action: CitizenQrActions.roleAccess,
    );
  }

  @override
  Widget build(BuildContext context) => ChainBalanceScope(
    accountIds: persons.map((p) => p.accountId).whereType<String>(),
    builder: (context, balances) => Scaffold(
      appBar: AppBar(title: const Text('人员任职')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (institution != null) Text(institution!.fullName),
          Text('共 ${persons.length} 位人员'),
          for (var index = 0; index < persons.length; index++)
            InstitutionAssignmentCard(
              person: persons[index],
              index: index + 1,
              balanceFen: persons[index].accountId == null
                  ? null
                  : balances
                        .accountState(persons[index].accountId!)
                        .value
                        ?.freeFen,
              trailing: identity == null || persons[index].accountId == null
                  ? null
                  : TextButton(
                      onPressed: () =>
                          unawaited(_roleAccess(context, persons[index])),
                      child: const Text('节点访问授权'),
                    ),
            ),
        ],
      ),
    ),
  );
}
