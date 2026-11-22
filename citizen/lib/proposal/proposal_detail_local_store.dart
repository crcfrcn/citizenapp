// 持久保存详情首屏快照和冻结票据，操作授权仍须查链。

import 'package:isar_community/isar.dart';
import 'package:citizen_storage/user_isar.dart' as wallet_store show Proposal;

import 'dart:async';
import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_multisig/multisig_transfer_models.dart';

import 'package:citizen_storage/user_isar.dart' hide Group;

/// 提案详情本地持久化读库。
///
/// 这里保存的是详情页首屏展示快照，降低页面进入时对链上 storage
/// 的同步等待；投票、执行和提交前复核仍必须重新读取链上真值。
class ProposalDetailLocalStore {
  ProposalDetailLocalStore._();

  static final ProposalDetailLocalStore instance = ProposalDetailLocalStore._();

  static const Duration activeTtl = Duration(seconds: 60);
  Future<ProposalDetailSnapshot?> read(String proposalKind, BigInt proposalId) {
    return UserIsar.instance.read((isar) async {
      final entity = await isar
          .collection<wallet_store.Proposal>()
          .filter()
          .proposalKindEqualTo(proposalKind)
          .proposalIdTextEqualTo(proposalId.toString())
          .findFirst();
      return entity == null
          ? null
          : ProposalDetailSnapshot.fromJsonString(
              entity.bodyData,
              proposalKind: entity.proposalKind,
              proposalId: entity.proposalId,
            );
    });
  }

  final _changes = StreamController<Set<BigInt>>.broadcast();
  Stream<Set<BigInt>> get changes => _changes.stream;
  void notifyFeedChanged(Set<BigInt> ids) =>
      _changes.add(Set.unmodifiable(ids));

  Future<void> put(ProposalDetailSnapshot snapshot) =>
      UserIsar.instance.writeTxn((isar) => putIn(isar, snapshot));

  Future<void> putIn(Isar isar, ProposalDetailSnapshot snapshot) async {
    final rows = isar.collection<wallet_store.Proposal>();
    final entity =
        await rows
            .filter()
            .proposalKindEqualTo(snapshot.proposalKind)
            .proposalIdTextEqualTo(snapshot.proposalId.toString())
            .findFirst() ??
        wallet_store.Proposal();
    entity
      ..proposalKind = snapshot.proposalKind
      ..proposalId = snapshot.proposalId
      ..bodyData = jsonEncode(snapshot.toJson());
    await rows.put(entity);
  }

  Future<ProposalDetailSnapshot?> readForFeed(BigInt id) async {
    return UserIsar.instance.read((isar) async {
      final row = await isar
          .collection<wallet_store.Proposal>()
          .filter()
          .proposalIdTextEqualTo(id.toString())
          .findFirst();
      return row == null
          ? null
          : ProposalDetailSnapshot.fromJsonString(
              row.bodyData,
              proposalKind: row.proposalKind,
              proposalId: id,
            );
    });
  }

  Future<void> clearAllForTest() async {
    await UserIsar.instance.writeTxn((isar) async {
      await isar.collection<wallet_store.Proposal>().clear();
    });
  }
}

class ProposalDetailSnapshot {
  const ProposalDetailSnapshot({
    required this.proposalId,
    required this.proposalKind,
    required this.updatedAt,
    this.status,
    this.yesCount = 0,
    this.noCount = 0,
    this.threshold,
    this.admins = const [],
    this.adminVotes = const {},
    this.pendingPublicKeys = const [],
    this.detail = const {},
    this.extra = const {},
  });

  final BigInt proposalId;
  final String proposalKind;
  final int updatedAt;
  final int? status;
  final int yesCount;
  final int noCount;
  final int? threshold;
  final List<String> admins;
  final Map<String, bool?> adminVotes;
  final List<String> pendingPublicKeys;
  final Map<String, Object?> detail;
  final Map<String, Object?> extra;

  bool get isFinal => status != null && status != 0;

  bool isFresh(Duration ttl) {
    if (isFinal) return true;
    return DateTime.now().millisecondsSinceEpoch - updatedAt <
        ttl.inMilliseconds;
  }

  List<EligibleVoterTicket> get voterTickets {
    final rows = extra['voter_tickets'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row case {'account_id': final String account})
          EligibleVoterTicket(
            voterAccountId: account,
            cidNumber: row['cid_number'] as String?,
            voterRoleCode: row['role_code'] as String?,
            voterRoleName: row['role_name'] as String?,
          ),
    ];
  }

  /// 只更新事件影响的字段，保留已经落盘的业务正文。
  ProposalDetailSnapshot withState(
    ProposalMeta meta, {
    ({int yes, int no})? tally,
    ({int yes, int no})? referendum,
    ({bool? result, ({int yes, int no}) tally})? institution,
    List<String>? eligibleAccounts,
    Map<String, bool?>? votes,
    List<EligibleVoterTicket>? tickets,
    int? thresholdSnapshot,
  }) {
    return ProposalDetailSnapshot(
      proposalId: proposalId,
      proposalKind: proposalKind,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: meta.status,
      yesCount: tally?.yes ?? yesCount,
      noCount: tally?.no ?? noCount,
      threshold: thresholdSnapshot ?? threshold,
      admins: eligibleAccounts ?? admins,
      adminVotes: votes ?? adminVotes,
      pendingPublicKeys: pendingPublicKeys,
      detail: detail,
      extra: {
        ...extra,
        if (tickets != null)
          'voter_tickets': [
            for (final ticket in tickets)
              {
                'account_id': ticket.voterAccountId,
                'cid_number': ticket.cidNumber,
                'role_code': ticket.voterRoleCode,
                'role_name': ticket.voterRoleName,
              },
          ],
        'meta_status': meta.status,
        'meta_stage': meta.stage,
        if (tally != null && proposalKind == 'runtime_upgrade') ...{
          'joint_yes': tally.yes,
          'joint_no': tally.no,
        },
        if (referendum != null) ...{
          'referendum_yes': referendum.yes,
          'referendum_no': referendum.no,
        },
        if (institution != null) ...{
          'institution_vote': institution.result,
          'institution_yes': institution.tally.yes,
          'institution_no': institution.tally.no,
        },
      },
    );
  }

  static ProposalDetailSnapshot? fromProposal(ProposalWithDetail proposal) {
    final meta = proposal.meta;
    final upgrade = proposal.runtimeUpgradeDetail;
    final create = proposal.createMultisigDetail;
    final close = proposal.closeMultisigDetail;
    final business = proposal.businessDetails;
    final transfer = business[MultisigTransferProposalDetailKeys.transfer];
    final fund = business[MultisigTransferProposalDetailKeys.safetyFund];
    final sweep = business[MultisigTransferProposalDetailKeys.sweep];
    final String kind;
    final Map<String, Object?> detail;
    if (upgrade != null) {
      kind = 'runtime_upgrade';
      detail = {
        'actor_cid_number': upgrade.actorCidNumber,
        'proposer': upgrade.proposer,
        'reason': upgrade.reason,
        'code_hash_hex': upgrade.codeHashHex,
        'expected_pow_params_hash_hex': upgrade.expectedPowParamsHashHex,
        'params_version': upgrade.paramsVersion,
        'algorithm_version': upgrade.algorithmVersion,
        'target_block_time_ms': upgrade.targetBlockTimeMs,
        'adjustment_interval': upgrade.adjustmentInterval,
        'max_adjust_up_factor': upgrade.maxAdjustUpFactor,
        'max_adjust_down_divisor': upgrade.maxAdjustDownDivisor,
      };
    } else if (create != null) {
      kind = 'institution_multisig';
      detail = {
        'kind': 'create',
        'account_id': create.accountId,
        'proposer_ss58_address': create.proposerSs58Address,
        'amount_fen': create.amountFen.toString(),
        'fee_fen': create.feeAmount.toString(),
        'status': create.status,
      };
    } else if (close != null) {
      kind = 'institution_multisig';
      detail = {
        'kind': 'close',
        'account_id': close.accountId,
        'beneficiary_ss58_address': close.beneficiarySs58Address,
        'proposer_ss58_address': close.proposerSs58Address,
        'status': close.status,
      };
    } else if (transfer is TransferProposalInfo) {
      kind = 'transfer';
      detail = {
        'kind': kind,
        'actor_cid_number': transfer.actorCidNumber,
        'institution_account_id': citizenAccountIdFromBytes(
          transfer.institutionAccountId,
        ),
        'beneficiary': transfer.beneficiary,
        'amount_fen': transfer.amountFen.toString(),
        'remark': transfer.remark,
        'proposer': transfer.proposer,
        'status': transfer.status,
      };
    } else if (fund is SafetyFundProposalInfo) {
      kind = 'safety_fund';
      detail = {
        'kind': kind,
        'actor_cid_number': fund.actorCidNumber,
        'institution_account_id': citizenAccountIdFromBytes(
          fund.institutionAccountId,
        ),
        'beneficiary': fund.beneficiary,
        'amount_fen': fund.amountFen.toString(),
        'remark': fund.remark,
        'proposer': fund.proposer,
        'status': fund.status,
      };
    } else if (sweep is SweepProposalInfo) {
      kind = 'sweep';
      detail = {
        'kind': kind,
        'actor_cid_number': sweep.actorCidNumber,
        'institution_account_id': citizenAccountIdFromBytes(
          sweep.institutionAccountId,
        ),
        'amount_fen': sweep.amountFen.toString(),
        'proposer': sweep.proposer,
        'status': sweep.status,
      };
    } else {
      return null;
    }
    return ProposalDetailSnapshot(
      proposalId: meta.proposalId,
      proposalKind: kind,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      status: meta.status,
      detail: detail,
      extra: {
        'meta_kind': meta.kind,
        'meta_stage': meta.stage,
        'meta_status': meta.status,
        'meta_internal_code': meta.internalCode,
        'meta_subject_cid_numbers': meta.subjectCidNumbers,
        'meta_actor_cid_number': meta.actorCidNumber,
        'meta_execution_account_id': meta.executionAccountId == null
            ? null
            : citizenAccountIdFromBytes(meta.executionAccountId!),
      },
    );
  }

  Map<String, Object?> toJson() => {
    'updated_at': updatedAt,
    'status': status,
    'yes_count': yesCount,
    'no_count': noCount,
    'threshold': threshold,
    'admins': admins,
    'admin_votes': adminVotes.map((key, value) => MapEntry(key, value)),
    'pending_public_keys': pendingPublicKeys,
    'detail': detail,
    'extra': extra,
  };

  static ProposalDetailSnapshot? fromJsonString(
    String? raw, {
    required String proposalKind,
    required BigInt proposalId,
  }) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final updatedAt = _toInt(decoded['updated_at']);
      if (decoded.containsKey('proposal_id') ||
          decoded.containsKey('proposal_kind') ||
          proposalKind.isEmpty ||
          updatedAt == null) {
        return null;
      }
      return ProposalDetailSnapshot(
        proposalId: proposalId,
        proposalKind: proposalKind,
        updatedAt: updatedAt,
        status: _toInt(decoded['status']),
        yesCount: _toInt(decoded['yes_count']) ?? 0,
        noCount: _toInt(decoded['no_count']) ?? 0,
        threshold: _toInt(decoded['threshold']),
        admins: _stringList(decoded['admins']),
        adminVotes: _voteMap(decoded['admin_votes']),
        pendingPublicKeys: _stringList(decoded['pending_public_keys']),
        detail: _objectMap(decoded['detail']),
        extra: _objectMap(decoded['extra']),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, bool?> _voteMap(Object? value) {
    if (value is! Map) return const {};
    final result = <String, bool?>{};
    for (final entry in value.entries) {
      // 岗位票据键区分CID/岗位码大小写，禁止按地址规则改写。
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      final raw = entry.value;
      if (raw is bool) {
        result[key] = raw;
      } else if (raw == null) {
        result[key] = null;
      } else if (raw.toString() == 'true') {
        result[key] = true;
      } else if (raw.toString() == 'false') {
        result[key] = false;
      }
    }
    return result;
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
