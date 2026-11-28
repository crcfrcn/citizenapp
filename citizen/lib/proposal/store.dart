// 提案及详情本地存储。

import 'package:isar_community/isar.dart';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_storage/user.dart' as wallet_store show Proposal, ProposalList, Summary;
import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_citizen/institution/data.dart' show InstitutionInfo, formatProposalId;
import 'package:citizen_citizen/proposal/data.dart' show EligibleVoterTicket, ProposalDisplayMeta, ProposalMeta, ProposalWithDetail;
import 'package:citizen_storage/user.dart' hide Group;
import 'package:citizen_multisig/data.dart' show MultisigTransferProposalDetailKeys, SafetyFundProposalInfo, SweepProposalInfo, TransferProposalInfo;

import 'dart:async';

// 按编号和机构持久保存提案列表摘要及扫描进度。

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
        summaries
            .where((summary) => kept.contains(summary.proposalId))
            .toList(),
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
      final row = await isar
          .collection<wallet_store.ProposalList>()
          .getByCidNumber(key);
      if (row == null ||
          row.finalizedHash != block.hash ||
          row.finalizedHeight != block.number.toString() ||
          !row.proposalIds.contains(summary.proposalId)) {
        return false;
      }
      final record = await isar
          .collection<wallet_store.Summary>()
          .filter()
          .proposalIdTextEqualTo(summary.proposalId.toString())
          .findFirst();
      if (LocalProposalSummary.fromJsonString(
            record?.bodyData,
            proposalId: summary.proposalId,
          )?.detailPending !=
          true) {
        return false;
      }
      await _writeSummaries(isar, [summary]);
      if (detail != null) {
        await ProposalDetailLocalStore.instance.putIn(isar, detail);
      }
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
          await isar
                  .collection<wallet_store.ProposalList>()
                  .filter()
                  .cidNumberStartsWith('feed:')
                  .proposalIdTextsElementEqualTo(summary.proposalId.toString())
                  .findFirst() !=
              null) {
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
        trackTallies:
            (decoded['track_tallies'] as Map<String, dynamic>?)?.map(
              (name, value) => MapEntry(name, value as int),
            ) ??
            const {},
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

// 持久保存详情首屏快照和冻结票据，操作授权仍须查链。

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
        if (row is Map<String, dynamic>)
          EligibleVoterTicket(
            voterAccountId: row['account_id'] as String?,
            personCid: row['person_cid'] as String?,
            cidNumber: row['cid_number'] as String?,
            voterRoleCode: row['role_code'] as String?,
            voterRoleName: row['role_name'] as String?,
          ),
    ];
  }

  /// 机构详情与事件增量复用同一票据序列化合同，人员CID和缺失钱包均原样保留。
  static List<Map<String, Object?>> encodeTickets(
    Iterable<EligibleVoterTicket> tickets,
  ) => [
    for (final ticket in tickets)
      {
        'account_id': ticket.voterAccountId,
        'person_cid': ticket.personCid,
        'cid_number': ticket.cidNumber,
        'role_code': ticket.voterRoleCode,
        'role_name': ticket.voterRoleName,
      },
  ];

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
        if (tickets != null) 'voter_tickets': encodeTickets(tickets),
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
    } else if (transfer is TransferProposalInfo) {
      kind = 'transfer';
      detail = {
        'kind': kind,
        'actor_cid_number': transfer.actorCidNumber,
        'funding_account_id': citizenAccountIdFromBytes(
          transfer.fundingAccountId,
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
      final extra = _objectMap(decoded['extra']);
      final tickets = extra['voter_tickets'];
      if (tickets != null) {
        if (tickets is! List) return null;
        for (final row in tickets) {
          if (row is! Map<String, dynamic>) return null;
          final institution = row['cid_number'];
          final role = row['role_code'];
          final person = row['person_cid'];
          final account = row['account_id'];
          if (institution != null || role != null) {
            if (institution is! String ||
                institution.isEmpty ||
                role is! String ||
                role.isEmpty ||
                person is! String ||
                person.isEmpty ||
                (account != null && account is! String)) {
              return null;
            }
          } else if (account is! String || account.isEmpty || person != null) {
            return null;
          }
        }
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
        extra: extra,
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
