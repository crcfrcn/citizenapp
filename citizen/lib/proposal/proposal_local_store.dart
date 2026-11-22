// 按编号和机构持久保存提案列表摘要及扫描进度。

import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user_isar.dart'
    as wallet_store
    show Proposal, ProposalList, Summary;

import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_multisig/multisig_transfer_models.dart';

import 'proposal_detail_local_store.dart';

/// 提案列表本地持久化读库。
///
/// typed collection 只服务治理机构详情页和公民-提案列表展示；投票、执行、提交前
/// 仍必须重查链上真值。
class ProposalLocalStore {
  ProposalLocalStore._();

  static final ProposalLocalStore instance = ProposalLocalStore._();

  static const Duration institutionIndexTtl = Duration(minutes: 5);

  /// 公民 Tab 的索引与机构 CID 索引分属不同命名空间。
  static String feedKey(String genesis, String? account) =>
      'feed:$genesis:${account ?? ''}';

  Future<ProposalLocalIndex?> readFeed(String key) => _readIndex(key);

  /// 摘要、索引、已处理区块一起提交，空索引同样标记为已同步。
  Future<void> saveFeed({
    required String key,
    required CitizenBlockRef block,
    required List<LocalProposalSummary> summaries,
    List<ProposalDetailSnapshot> details = const [],
    List<BigInt> added = const [],
    Set<BigInt> deleted = const {},
  }) async {
    if (block.finality != CitizenBlockFinality.finalized) {
      throw ArgumentError('提案同步进度必须来自最终区块');
    }
    final committed = await UserIsar.instance.writeTxn((isar) async {
      final indexes = isar.collection<wallet_store.ProposalList>();
      final row =
          await indexes.getByCidNumber(key) ??
          (wallet_store.ProposalList()..cidNumber = key);
      final previous = BigInt.tryParse(row.finalizedHeight ?? '');
      if (previous == block.number && row.finalizedHash != block.hash) {
        throw StateError('提案同步进度在同高度遇到不同最终块');
      }
      if (previous != null && previous >= block.number) return false;
      var nextIds = row.proposalIds;
      if (previous == null) {
        nextIds = summaries.map((summary) => summary.proposalId).toList();
      } else if (added.isNotEmpty) {
        nextIds = {...nextIds, ...added}.toList()
          ..sort((a, b) => b.compareTo(a));
      }
      final kept = nextIds.where((id) => !deleted.contains(id)).toSet();
      await _writeSummaries(
        isar,
        summaries.where((summary) => kept.contains(summary.proposalId)).toList(),
      );
      for (final snapshot in details) {
        if (kept.contains(snapshot.proposalId)) {
          await ProposalDetailLocalStore.instance.putIn(isar, snapshot);
        }
      }
      await _deleteProposals(isar, deleted);
      row
        ..proposalIds = kept.toList()
        ..syncedAt = DateTime.now().millisecondsSinceEpoch
        ..finalizedHeight = block.number.toString()
        ..finalizedHash = block.hash;
      await indexes.putByCidNumber(row);
      return true;
    });
    if (committed && (details.isNotEmpty || deleted.isNotEmpty)) {
      ProposalDetailLocalStore.instance.notifyFeedChanged({
        ...details.map((detail) => detail.proposalId),
        ...deleted,
      });
    }
  }

  /// 删除核验独立提交，不修改已经处理的最终块进度。
  Future<void> removeConfirmed(Set<BigInt> ids) async {
    if (ids.isEmpty) return;
    await UserIsar.instance.writeTxn((isar) => _deleteProposals(isar, ids));
    ProposalDetailLocalStore.instance.notifyFeedChanged(ids);
  }

  Future<void> _deleteProposals(Isar isar, Set<BigInt> deleted) async {
    final indexes = isar.collection<wallet_store.ProposalList>();
      for (final id in deleted) {
        final text = id.toString();
        final indexesContaining = await indexes
            .filter()
            .proposalIdTextsElementEqualTo(text)
            .findAll();
        for (final index in indexesContaining) {
          index.proposalIds = index.proposalIds
              .where((value) => value != id)
              .toList();
          await indexes.putByCidNumber(index);
        }
        await isar
            .collection<wallet_store.Summary>()
            .filter()
            .proposalIdTextEqualTo(text)
            .deleteAll();
        await isar
            .collection<wallet_store.Proposal>()
            .filter()
            .proposalIdTextEqualTo(text)
            .deleteAll();
      }
  }

  /// 仅对仍在当前索引中的待补项写入正文，防止迟到结果覆盖较新的状态。
  Future<bool> saveRepairedDetail({
    required String key,
    required CitizenBlockRef block,
    required LocalProposalSummary summary,
    required ProposalDetailSnapshot? detail,
  }) async {
    final committed = await UserIsar.instance.writeTxn((isar) async {
      final row = await isar.collection<wallet_store.ProposalList>()
          .getByCidNumber(key);
      if (row == null ||
          row.finalizedHash != block.hash ||
          row.finalizedHeight != block.number.toString() ||
          !row.proposalIds.contains(summary.proposalId)) return false;
      final record = await isar.collection<wallet_store.Summary>()
          .filter().proposalIdTextEqualTo(summary.proposalId.toString()).findFirst();
      if (LocalProposalSummary.fromJsonString(record?.bodyData,
              proposalId: summary.proposalId)?.detailPending != true) return false;
      await _writeSummaries(isar, [summary]);
      if (detail != null) await ProposalDetailLocalStore.instance.putIn(isar, detail);
      return true;
    });
    if (committed) {
      ProposalDetailLocalStore.instance.notifyFeedChanged({summary.proposalId});
    }
    return committed;
  }

  Future<ProposalLocalIndex?> readInstitutionIndex(String cidNumber) {
    return _readIndex(cidNumber);
  }

  Future<bool> isInstitutionIndexFresh(String cidNumber) async {
    final index = await readInstitutionIndex(cidNumber);
    return index != null && index.isFresh(institutionIndexTtl);
  }

  Future<List<LocalProposalSummary>> readInstitutionSummaries(
    String cidNumber,
  ) async {
    final index = await readInstitutionIndex(cidNumber);
    if (index == null || index.ids.isEmpty) return const [];
    return readSummariesForIds(index.ids);
  }

  Future<List<LocalProposalSummary>> readSummariesForIds(List<BigInt> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return UserIsar.instance.read((isar) async {
      final result = <LocalProposalSummary>[];
      for (final id in ids) {
        final entity = await isar
            .collection<wallet_store.Summary>()
            .filter()
            .proposalIdTextEqualTo(id.toString())
            .findFirst();
        final summary = entity == null
            ? null
            : LocalProposalSummary.fromJsonString(
                entity.bodyData,
                proposalId: entity.proposalId,
              );
        if (summary != null) {
          result.add(summary);
        }
      }
      return result;
    });
  }

  Future<void> putInstitutionIndex(String cidNumber, List<BigInt> ids) {
    return _putIndex(cidNumber, ids);
  }

  Future<void> upsertSummaries(List<LocalProposalSummary> summaries) async {
    if (summaries.isEmpty) return;
    await UserIsar.instance.writeTxn(
      (isar) => _writeSummaries(isar, summaries, preserveFeed: true),
    );
  }

  Future<void> _writeSummaries(
    Isar isar,
    List<LocalProposalSummary> summaries, {
    bool preserveFeed = false,
  }) async {
    for (final summary in summaries) {
      if (preserveFeed &&
          await isar.collection<wallet_store.ProposalList>().filter()
              .cidNumberStartsWith('feed:')
              .proposalIdTextsElementEqualTo(summary.proposalId.toString())
              .findFirst() != null) {
        continue;
      }
      final entity =
          await isar
              .collection<wallet_store.Summary>()
              .filter()
              .proposalIdTextEqualTo(summary.proposalId.toString())
              .findFirst() ??
          (wallet_store.Summary()..proposalId = summary.proposalId);
      entity.bodyData = jsonEncode(summary.toJson());
      await isar.collection<wallet_store.Summary>().put(entity);
    }
  }

  Future<void> clearAllForTest() async {
    await UserIsar.instance.writeTxn((isar) async {
      await isar.collection<wallet_store.Summary>().clear();
      await isar.collection<wallet_store.ProposalList>().clear();
    });
  }

  Future<ProposalLocalIndex?> _readIndex(String cidNumber) {
    return UserIsar.instance.read((isar) async {
      final entity = await isar
          .collection<wallet_store.ProposalList>()
          .getByCidNumber(cidNumber);
      return entity == null
          ? null
          : ProposalLocalIndex(
              ids: List<BigInt>.unmodifiable(entity.proposalIds),
              syncedAt: entity.syncedAt,
              finalizedHeight: BigInt.tryParse(entity.finalizedHeight ?? ''),
              finalizedHash: entity.finalizedHash,
            );
    });
  }

  Future<void> _putIndex(String cidNumber, List<BigInt> ids) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final proposalIds = List<BigInt>.unmodifiable(ids);
    await UserIsar.instance.writeTxn((isar) async {
      final entity =
          await isar.collection<wallet_store.ProposalList>().getByCidNumber(
            cidNumber,
          ) ??
          (wallet_store.ProposalList()..cidNumber = cidNumber);
      entity
        ..proposalIds = proposalIds
        ..syncedAt = now;
      await isar.collection<wallet_store.ProposalList>().putByCidNumber(entity);
    });
  }
}

class ProposalLocalIndex {
  const ProposalLocalIndex({
    required this.ids,
    required this.syncedAt,
    this.finalizedHeight,
    this.finalizedHash,
  });

  final List<BigInt> ids;
  final int syncedAt;
  final BigInt? finalizedHeight;
  final String? finalizedHash;

  bool isFresh(Duration ttl) {
    final age = DateTime.now().millisecondsSinceEpoch - syncedAt;
    return age >= 0 && age < ttl.inMilliseconds;
  }
}

class LocalProposalSummary {
  const LocalProposalSummary({
    required this.proposalId,
    required this.kind,
    required this.stage,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.listSubtitle,
    required this.iconKind,
    required this.updatedAt,
    this.internalCode,
    this.actorCidNumber,
    this.executionAccountId,
    this.subjectCidNumbers = const [],
    this.displayYear,
    this.displaySeqInYear,
    this.cidNumber,
    this.fullName,
    this.cleanupHeight,
    this.detailPending = false,
    this.trackTallies = const {},
  });

  final BigInt proposalId;
  final int kind;
  final int stage;
  final int status;
  final String? internalCode;
  final String? actorCidNumber;
  final String? executionAccountId;
  final List<String> subjectCidNumbers;
  final int? displayYear;
  final BigInt? displaySeqInYear;
  final String? cidNumber;
  final String? fullName;
  final BigInt? cleanupHeight;
  final bool detailPending;
  final Map<String, int> trackTallies;
  final String title;
  final String subtitle;
  final String listSubtitle;
  final String iconKind;
  final int updatedAt;

  ProposalDisplayMeta? get displayMeta {
    final year = displayYear;
    final seq = displaySeqInYear;
    if (year == null || seq == null) return null;
    return ProposalDisplayMeta(year: year, seqInYear: seq);
  }

  String get displayId => formatProposalId(displayMeta);

  ProposalMeta get meta => ProposalMeta(
    proposalId: proposalId,
    kind: kind,
    stage: stage,
    status: status,
    internalCode: internalCode,
    actorCidNumber: actorCidNumber,
    executionAccountId: _executionAccount(executionAccountId),
    subjectCidNumbers: subjectCidNumbers,
    displayMeta: displayMeta,
  );

  LocalProposalSummary withChainState(
    ProposalMeta meta, {
    BigInt? cleanupHeight,
    Map<String, int> trackTallies = const {},
  }) {
    final data = toJson()
      ..['stage'] = meta.stage
      ..['status'] = meta.status
      ..['internal_code'] = meta.internalCode
      ..['subject_cid_numbers'] = meta.subjectCidNumbers
      ..['track_tallies'] = {...this.trackTallies, ...trackTallies}
      ..['cleanup_height'] = (cleanupHeight ?? this.cleanupHeight)?.toString();
    final separator = subtitle.lastIndexOf(' · ');
    if (separator >= 0) {
      data['subtitle'] =
          '${subtitle.substring(0, separator)} · ${_statusLabel(meta.status)}';
    }
    return fromJsonString(jsonEncode(data), proposalId: proposalId)!;
  }

  LocalProposalSummary withRepairedDetail(ProposalWithDetail? proposal) {
    final data = toJson()..remove('detail_pending');
    if (proposal != null) {
      final display = LocalProposalSummary.fromProposal(proposal);
      data['title'] = display.title;
      data['subtitle'] = display.subtitle;
      data['list_subtitle'] = display.listSubtitle;
      data['icon_kind'] = display.iconKind;
    }
    return fromJsonString(jsonEncode(data), proposalId: proposalId)!;
  }

  static LocalProposalSummary fromProposal(
    ProposalWithDetail proposal, {
    InstitutionInfo? institution,
    int? nowMillis,
    bool detailPending = false,
  }) {
    final meta = proposal.meta;
    final displayId = formatProposalId(meta.displayMeta);
    final status = _statusLabel(meta.status);
    final transfer =
        proposal.businessDetails[MultisigTransferProposalDetailKeys.transfer];
    final safetyFund =
        proposal.businessDetails[MultisigTransferProposalDetailKeys.safetyFund];
    final sweep =
        proposal.businessDetails[MultisigTransferProposalDetailKeys.sweep];

    String title;
    String subtitle;
    String listSubtitle;
    String iconKind;

    if (transfer is TransferProposalInfo) {
      title = '转账提案 $displayId';
      listSubtitle = '转账 ${formatFen(transfer.amountFen)} 元';
      subtitle = '$listSubtitle · $status';
      iconKind = 'transfer';
    } else if (safetyFund is SafetyFundProposalInfo) {
      title = '安全基金转账 $displayId';
      listSubtitle = '安全基金转账 ${formatFen(safetyFund.amountFen)} 元';
      subtitle = '$listSubtitle · $status';
      iconKind = 'safety_fund';
    } else if (sweep is SweepProposalInfo) {
      title = '手续费划转 $displayId';
      listSubtitle = '手续费划转 ${formatFen(sweep.amountFen)} 元';
      subtitle = '$listSubtitle · $status';
      iconKind = 'sweep';
    } else if (proposal.createMultisigDetail != null) {
      title = '创建多签 $displayId';
      listSubtitle = '创建个人多签';
      subtitle = '创建个人多签账户 · $status';
      iconKind = 'create_multisig';
    } else if (proposal.closeMultisigDetail != null) {
      title = '关闭多签 $displayId';
      listSubtitle = '关闭多签';
      subtitle = '关闭多签账户 · $status';
      iconKind = 'close_multisig';
    } else if (proposal.runtimeUpgradeDetail != null) {
      title = '协议升级 $displayId';
      listSubtitle = '协议升级';
      subtitle = '协议升级 · $status';
      iconKind = 'runtime_upgrade';
    } else if (proposal.resolutionIssuanceSummary != null) {
      title = '联合投票提案 $displayId';
      listSubtitle = '决议发行';
      subtitle = '决议发行 · $status';
      iconKind = 'resolution_issuance';
    } else if (proposal.resolutionDestroySummary != null) {
      title = '联合投票提案 $displayId';
      listSubtitle = '决议销毁';
      subtitle = '决议销毁 · $status';
      iconKind = 'resolution_destroy';
    } else if (meta.kind == 1) {
      title = '联合投票提案 $displayId';
      listSubtitle = '联合投票提案';
      subtitle = '联合投票 · $status';
      iconKind = 'joint';
    } else {
      title = '提案 $displayId';
      listSubtitle = '提案 ${_kindLabel(meta.kind)}';
      subtitle = '提案事件 · $status';
      iconKind = 'proposal';
    }

    return LocalProposalSummary(
      proposalId: meta.proposalId,
      kind: meta.kind,
      stage: meta.stage,
      status: meta.status,
      internalCode: meta.internalCode,
      actorCidNumber: meta.actorCidNumber,
      executionAccountId: meta.executionAccountId == null
          ? null
          : citizenAccountIdFromBytes(meta.executionAccountId!),
      subjectCidNumbers: meta.subjectCidNumbers,
      displayYear: meta.displayMeta?.year,
      displaySeqInYear: meta.displayMeta?.seqInYear,
      cidNumber: institution?.cidNumber,
      fullName: institution?.fullName,
      title: title,
      subtitle: subtitle,
      listSubtitle: listSubtitle,
      iconKind: iconKind,
      detailPending: detailPending,
      updatedAt: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'stage': stage,
    'status': status,
    'internal_code': internalCode,
    'actor_cid_number': actorCidNumber,
    'execution_account_id': executionAccountId,
    'subject_cid_numbers': subjectCidNumbers,
    'display_year': displayYear,
    'display_seq_in_year': displaySeqInYear?.toString(),
    'cid_number': cidNumber,
    'cid_full_name': fullName,
    'title': title,
    'subtitle': subtitle,
    'list_subtitle': listSubtitle,
    'icon_kind': iconKind,
    'updated_at': updatedAt,
    'cleanup_height': cleanupHeight?.toString(),
    if (detailPending) 'detail_pending': true,
    if (trackTallies.isNotEmpty) 'track_tallies': trackTallies,
  };

  static LocalProposalSummary? fromJsonString(
    String? raw, {
    required BigInt proposalId,
  }) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final kind = _toInt(decoded['kind']);
      final stage = _toInt(decoded['stage']);
      final status = _toInt(decoded['status']);
      final title = decoded['title']?.toString();
      final subtitle = decoded['subtitle']?.toString();
      final listSubtitle = decoded['list_subtitle']?.toString();
      final iconKind = decoded['icon_kind']?.toString();
      final updatedAt = _toInt(decoded['updated_at']);
      if (decoded.containsKey('proposal_id') ||
          kind == null ||
          stage == null ||
          status == null ||
          title == null ||
          subtitle == null ||
          listSubtitle == null ||
          iconKind == null ||
          updatedAt == null) {
        return null;
      }
      return LocalProposalSummary(
        proposalId: proposalId,
        kind: kind,
        stage: stage,
        status: status,
        internalCode: _toNullableString(decoded['internal_code']),
        actorCidNumber: _toNullableString(decoded['actor_cid_number']),
        executionAccountId: _toNullableString(decoded['execution_account_id']),
        subjectCidNumbers: _toStringList(decoded['subject_cid_numbers']),
        displayYear: _toInt(decoded['display_year']),
        displaySeqInYear: BigInt.tryParse(
          decoded['display_seq_in_year'].toString(),
        ),
        cidNumber: _toNullableString(decoded['cid_number']),
        fullName: _toNullableString(decoded['cid_full_name']),
        title: title,
        subtitle: subtitle,
        listSubtitle: listSubtitle,
        iconKind: iconKind,
        updatedAt: updatedAt,
        detailPending: decoded['detail_pending'] == true,
        trackTallies: (decoded['track_tallies'] as Map<String, dynamic>?)
            ?.map((name, value) => MapEntry(name, value as int)) ?? const {},
        cleanupHeight: BigInt.tryParse(
          decoded['cleanup_height']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

String _statusLabel(int status) {
  switch (status) {
    case 0:
      return '投票中';
    case 1:
      return '已通过';
    case 2:
      return '已拒绝';
    case 3:
      return '已执行';
    case 4:
      return '执行失败';
    default:
      return '未知';
  }
}

String _kindLabel(int kind) {
  switch (kind) {
    case 0:
      return '内部投票';
    case 1:
      return '联合投票';
    default:
      return '';
  }
}

Uint8List? _executionAccount(String? accountId) {
  if (accountId == null) return null;
  try {
    return citizenAccountIdBytes(accountId);
  } on FormatException {
    return null;
  }
}

int? _toInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String? _toNullableString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

List<String> _toStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString())
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
