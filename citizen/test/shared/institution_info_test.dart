// 验证机构CID和个人多签身份、真实名称及提案能力。

import 'package:flutter_test/flutter_test.dart';
import 'package:citizen_citizen/proposal/proposal_registry.dart';
import 'package:citizen_citizen/institution/institution_info.dart';

void main() {
  test('注册机构以 CID 为身份，主/费账户只作为其账户集合', () {
    final address = '0x${'11' * 32}';
    const cidNumber = 'GD001-CGOV0-123456789-2026';
    final institution = InstitutionInfo(
      fullName: '机构',
      shortName: '机构',
      cidFullNameEn: 'Institution',
      cidShortNameEn: 'Institution',
      cidNumber: cidNumber,
      orgType: OrgType.institution,
      adminCode: 'CGOV',
      accounts: InstitutionAccounts(
        mainAccountId: address,
        feeAccountId: '0x${'12' * 32}',
      ),
    );
    expect(institution.cidNumber, cidNumber);
    expect(institution.mainAccountId, address);
    expect(institution.isRegisteredInstitution, isTrue);
  });

  test('FRG/NJD 是固定治理机构且使用制度阈值，不误判为注册机构', () {
    InstitutionInfo fixed(String code) => InstitutionInfo(
      fullName: code,
      shortName: code,
      cidFullNameEn: code,
      cidShortNameEn: code,
      cidNumber: 'ZS001-${code}00-123456789-2026',
      orgType: OrgType.institution,
      adminCode: code,
      accounts: InstitutionAccounts(
        mainAccountId: '0x${'31' * 32}',
        feeAccountId: '0x${'32' * 32}',
      ),
    );

    final frg = fixed('FRG');
    final njd = fixed('NJD');
    expect(frg.internalThreshold, 3);
    expect(njd.internalThreshold, 8);
    expect(frg.isRegisteredInstitution, isFalse);
    expect(njd.isRegisteredInstitution, isFalse);
  });

  group('ProposalCapabilityRegistry', () {
    InstitutionInfo info({
      required String code,
      required String accountId,
      int orgType = OrgType.institution,
      String? cidNumber,
    }) {
      return InstitutionInfo(
        fullName: code,
        shortName: code,
        cidFullNameEn: code,
        cidShortNameEn: code,
        cidNumber: cidNumber ?? 'GD001-${code}0-123456789-2026',
        orgType: orgType,
        adminCode: code,
        accounts: InstitutionAccounts(
          mainAccountId: accountId,
          feeAccountId: '0x${'fe' * 32}',
        ),
      );
    }

    Set<ProposalKind> kinds(ProposalSubject subject) {
      return ProposalCapabilityRegistry.capabilitiesForSubject(
        subject,
      ).map((capability) => capability.kind).toSet();
    }

    test('NRC exposes governance-only proposal capabilities', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(
          code: 'NRC',
          accountId: '0x${'33' * 32}',
          orgType: OrgType.nrc,
          cidNumber: 'LN001-NRC0G-944805165-2026',
        ),
        orgCode: 'NRC',
      );
      final result = kinds(subject);
      expect(subject.cidNumber, 'LN001-NRC0G-944805165-2026');
      expect(result, contains(ProposalKind.transfer));
      expect(result, contains(ProposalKind.feeTransfer));
      expect(result, contains(ProposalKind.safetyFundTransfer));
      expect(result, contains(ProposalKind.resolutionIssuance));
      expect(result, contains(ProposalKind.runtimeUpgrade));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
    });

    test('city registry is public institution, not governance', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(code: 'CREG', accountId: '0x${'44' * 32}'),
        orgCode: 'CREG',
      );
      final result = kinds(subject);
      expect(subject.cidNumber, 'GD001-CREG0-123456789-2026');
      expect(result, contains(ProposalKind.transfer));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
      expect(result, isNot(contains(ProposalKind.feeTransfer)));
      expect(result, isNot(contains(ProposalKind.runtimeUpgrade)));
    });

    test(
      'private institution gets only generic active-account capabilities',
      () {
        final subject = ProposalSubject.fromInstitution(
          institution: info(code: 'SFGQ', accountId: '0x${'55' * 32}'),
          orgCode: 'SFGQ',
        );
        final result = kinds(subject);
        expect(subject.cidNumber, 'GD001-SFGQ0-123456789-2026');
        expect(result, contains(ProposalKind.transfer));
        expect(result, isNot(contains(ProposalKind.adminsChange)));
        expect(result, isNot(contains(ProposalKind.resolutionIssuance)));
      },
    );

    test('unincorporated code does not auto-enable admins change', () {
      final subject = ProposalSubject.fromInstitution(
        institution: info(code: 'UNIN', accountId: '0x${'66' * 32}'),
        orgCode: 'UNIN',
      );
      final result = kinds(subject);
      expect(result, contains(ProposalKind.transfer));
      expect(result, isNot(contains(ProposalKind.adminsChange)));
    });
  });
}
