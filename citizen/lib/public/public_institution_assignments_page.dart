// 展示公权机构人员任职，复用同一链上绑定与节点访问授权入口。
import 'package:flutter/material.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_assignments_page.dart';

class PublicInstitutionAssignmentsPage extends StatelessWidget {
  const PublicInstitutionAssignmentsPage({
    super.key,
    required this.persons,
    this.identity,
  });
  final List<InstitutionPersonView> persons;
  final InstitutionIdentity? identity;
  @override
  Widget build(BuildContext context) =>
      InstitutionAssignmentsPage(persons: persons, identity: identity);
}
