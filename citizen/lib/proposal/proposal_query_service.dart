// 通过SDK查询提案、索引和计票，区分缺失损坏并等待真实就绪。

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_citizen/institution/institution_chain_service.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';
import 'package:citizen_citizen/runtime/runtime_upgrade_service.dart';
import 'package:citizen_citizen/legislation/legislation_vote_query_service.dart';

/// 详情只等待同一SDK的公开就绪事件；不轮询、不重启、不重试真实读取错误。
/// 先订阅再取能力快照，且作废查询期间迟到的旧快照。
Future<bool> waitForProposalRead({
  required Future<CitizenCapabilitySnapshot> Function() getCapabilities,
  required CitizenSdkLifecycle Function() lifecycle,
  required Stream<CitizenSdkEvent> events,
  required Future<void> cancelled,
}) async {
  var stopped = false;
  var revision = 0;
  Object? streamError;
  Completer<void>? changed;
  void wake() {
    revision++;
    if (changed != null && !changed.isCompleted) changed.complete();
  }

  final subscription = events.listen(
    (event) {
      if (event is CitizenSdkCapabilitiesChanged ||
          event is CitizenSdkLifecycleChanged ||
          event is CitizenSdkFinalizedBlockChanged) {
        wake();
      }
    },
    onError: (Object error) {
      streamError = error;
      wake();
    },
    onDone: () {
      streamError = StateError('提案读链事件流已关闭');
      wake();
    },
  );
  final stop = cancelled.then<CitizenCapabilitySnapshot?>((_) {
    stopped = true;
    wake();
    return null;
  });
  try {
    while (!stopped) {
      if (streamError != null) throw streamError!;
      changed = Completer<void>();
      final before = revision;
      final snapshot = await Future.any<CitizenCapabilitySnapshot?>([
        getCapabilities(),
        stop,
      ]);
      if (stopped || snapshot == null) return false;
      if (revision != before) continue;
      if (lifecycle() == CitizenSdkLifecycle.startFailed ||
          lifecycle() == CitizenSdkLifecycle.stopped ||
          lifecycle() == CitizenSdkLifecycle.disposed) {
        throw StateError('提案读链实例已停止或启动失败');
      }
      final status = snapshot[CitizenCapabilityName.chainRead];
      if (status.supported &&
          status.available &&
          status.enabled &&
          status.ready) {
        return true;
      }
      if (!status.supported ||
          !status.available ||
          !status.enabled ||
          !const {
            CitizenCapabilityReason.engineNotRunning,
            CitizenCapabilityReason.dependencyNotReady,
            CitizenCapabilityReason.chainStarting,
            CitizenCapabilityReason.chainUnsynced,
          }.contains(status.reason)) {
        throw StateError('提案读链能力不可用');
      }
      await Future.any<Object?>([changed.future, stop]);
    }
    return false;
  } finally {
    await subscription.cancel();
  }
}

/// 保留原异常与堆栈，只通过正式包可用的固定阶段报告失败。
Future<T> proposalReadStage<T>(String stage, Future<T> Function() read) async {
  try {
    return await read();
  } on Object catch (error) {
    AppLog.proposalFailure(stage: stage, error: error);
    rethrow;
  }
}

/// 每轮详情只领取一个finalized头，所有业务读取通过原服务固定到该块。
Future<CitizenBlockRef?> readProposalBlock(
  CitizenSdk sdk,
  Future<void> cancelled,
) async {
  final ready = await proposalReadStage(
    'proposal_ready',
    () => waitForProposalRead(
      getCapabilities: sdk.getCapabilities,
      lifecycle: () => sdk.lifecycle,
      events: sdk.events,
      cancelled: cancelled,
    ),
  );
  if (!ready) return null;
  return proposalReadStage('proposal_ready', sdk.getFinalizedHead);
}

/// VotingEngine / InternalVote 通用查询服务。
///
/// 提案状态、投票计数、快照和 NextProposalId 都是投票引擎
/// 通用状态，不能借用具体业务 service 暴露给其他模块。
class ProposalQueryService {
  ProposalQueryService({
    CitizenSdk? chain,
    CitizenBlockRef? block,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)?
    getStorageRuntimeContext,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _block = block,
       _getStorageBatch = getStorageBatch ?? chain?.getStorageBatch,
       _institutionService = InstitutionChainService(
         chain: chain,
         getFinalizedHead: block == null ? getFinalizedHead : () async => block,
         getRuntimeContext: getStorageRuntimeContext ?? getRuntimeContext,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       ),
       _internalVoteQuery = InternalVoteQueryService(
         chain: chain,
         block: block,
         getFinalizedHead: getFinalizedHead,
         getRuntimeContext: getStorageRuntimeContext ?? getRuntimeContext,
         getStorage: getStorage,
         getStorageBatch: getStorageBatch,
       ),
       _getFinalizedEvents = ((block) => readCitizenFinalizedEvents(
         block,
         readEvents:
             getSystemEvents ??
             chain?.getSystemEvents ??
             ((_) => throw StateError('未配置事件读取')),
         readRuntime:
             getRuntimeContext ??
             chain?.getRuntimeContext ??
             ((_) => throw StateError('未配置事件 metadata')),
       )),
       _getStorageRuntimeContext =
           getStorageRuntimeContext ??
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<List<CitizenSystemEvent>> Function(CitizenBlockRef)
  _getFinalizedEvents;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getStorageRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  final Future<List<Uint8List?>> Function(CitizenBlockRef, List<Uint8List>)?
  _getStorageBatch;

  final CitizenBlockRef? _block;
  final InstitutionChainService _institutionService;
  final InternalVoteQueryService _internalVoteQuery;

  /// 与 runtime `MaxActiveProposals = 10` 对齐的提案主体上限。
  static const maxActiveProposalsPerSubject = 10;

  /// 只返回 SDK 已验证区块中归属本次成功执行的事件。
  Future<List<CitizenSystemEvent>> fetchExecutionEvents(
    CitizenExecution execution,
  ) async {
    if (execution.status != CitizenExecutionStatus.success) {
      throw StateError('事件确认需要成功的finalized执行');
    }
    final events = await _getFinalizedEvents(execution.block);
    return events
        .where((event) => event.extrinsicIndex == execution.extrinsicIndex)
        .toList();
  }

  /// 只消费能归到具体提案的治理事件。
  Future<List<CitizenSystemEvent>> proposalEvents(CitizenBlockRef block) async {
    final events = await _getFinalizedEvents(block);
    const pallets = {
      'VotingEngine',
      'InternalVote',
      'JointVote',
      'LegislationVote',
      'ElectionVote',
    };
    return [
      for (final event in events)
        if (pallets.contains(event.pallet) &&
            event.fields is Map &&
            (event.fields as Map).containsKey('proposal_id'))
          event,
    ];
  }

  Future<ProposalMeta?> proposalMetaAt(CitizenBlockRef block, BigInt id) async {
    final runtime = await _getStorageRuntimeContext(block);
    final key = runtime.storageKey('VotingEngine', 'Proposals', [id]);
    final bytes = await _getStorage(block, key);
    if (bytes == null) return null;
    return decodeProposalMeta(id, bytes) ??
        (throw const FormatException('提案元数据编码无效'));
  }

  /// 在事件所属块读取绝对计数，重放区块不会重复累加投票。
  Future<({({int yes, int no}) tally, ({int yes, int no})? referendum})>
  proposalTalliesAt(CitizenBlockRef block, ProposalMeta meta) async {
    final runtime = await _getStorageRuntimeContext(block);
    Future<({int yes, int no})> read(
      String pallet,
      String entry,
      int width,
    ) async {
      final bytes = await _getStorage(
        block,
        runtime.storageKey(pallet, entry, [meta.proposalId]),
      );
      if (bytes == null) return (yes: 0, no: 0);
      if (bytes.length != width * 2) {
        throw FormatException('$entry 长度无效');
      }
      return (
        yes: CitizenScale.readUnsigned(bytes, 0, width).toInt(),
        no: CitizenScale.readUnsigned(bytes, width, width).toInt(),
      );
    }

    if (meta.kind == 1) {
      return (
        tally: await read('JointVote', 'JointTallies', 4),
        referendum: await read('JointVote', 'ReferendumTallies', 8),
      );
    }
    return (
      tally: await read('InternalVote', 'InternalTallies', 4),
      referendum: null,
    );
  }

  /// 立法和选举使用各自的链上计票结构，只处理本块涉及的岗位机构或候选人。
  Future<Map<String, int>> trackTalliesAt(
    CitizenBlockRef block,
    BigInt id,
    List<CitizenSystemEvent> events,
  ) async {
    final representativeBodies = <int>{};
    final candidates = <String>{};
    var referendum = false;
    for (final event in events) {
      if (event.pallet == 'LegislationVote') {
        if (event.name == 'RepresentativeVoteCast') {
          representativeBodies.add(event.fieldUnsigned('body_index').toInt());
        } else if (event.name == 'LegislationReferendumVoteCast' ||
            event.name == 'ReferendumVoteCast') {
          referendum = true;
        }
      } else if (event.pallet == 'ElectionVote' &&
          event.name == 'ElectionVoteCast') {
        final subject = (event.fields as Map)['candidate_subject'];
        final bytes = CitizenSystemEvent(
          eventIndex: event.eventIndex,
          extrinsicIndex: event.extrinsicIndex,
          pallet: event.pallet,
          name: event.name,
          fields: subject,
        ).fieldBytes('cid_number');
        candidates.add(utf8.decode(bytes));
      }
    }
    final counts = <String, int>{};
    final legislation = LegislationVoteQueryService(
      block: block,
      getRuntimeContext: _getStorageRuntimeContext,
      getStorage: _getStorage,
    );
    for (final body in representativeBodies) {
      final tally = await legislation.fetchRepresentativeTally(id, body);
      counts['representative_${body}_yes'] = tally.yes;
      counts['representative_${body}_no'] = tally.no;
    }
    if (referendum) {
      final tally = await legislation.fetchReferendumTally(id);
      counts['referendum_yes'] = tally.yes;
      counts['referendum_no'] = tally.no;
    }
    if (candidates.isNotEmpty) {
      final runtime = await _getStorageRuntimeContext(block);
      Future<int> read(String entry, List<Object> args) async {
        final raw = await _getStorage(
          block,
          runtime.storageKey('ElectionVote', entry, args),
        );
        if (raw == null) return 0;
        if (raw.length != 4) throw FormatException('$entry 长度无效');
        return CitizenScale.readUnsigned(raw, 0, 4).toInt();
      }

      counts['election_casted'] = await read('ElectionTallyStore', [id]);
      for (final candidate in candidates) {
        counts['candidate_$candidate'] = await read(
          'ElectionCandidateTallies',
          [id, utf8.encode(candidate)],
        );
      }
    }
    return counts;
  }

  /// SDK 仅在已验证块成功读取到空值时确认删除。
  Future<Set<BigInt>> deletedProposalIds(
    CitizenBlockRef block,
    Iterable<BigInt> ids,
  ) async {
    if (block.finality != CitizenBlockFinality.finalized) {
      throw ArgumentError('删除核验只接受最终区块');
    }
    final candidates = ids.toList();
    if (candidates.isEmpty) return {};
    final runtime = await _getStorageRuntimeContext(block);
    final deleted = <BigInt>{};
    for (var offset = 0; offset < candidates.length; offset += 128) {
      final batch = candidates.skip(offset).take(128).toList();
      final keys = [
        for (final id in batch)
          runtime.storageKey('VotingEngine', 'Proposals', [id]),
      ];
      final read = _getStorageBatch;
      final values = read == null
          ? await Future.wait(keys.map((key) => _getStorage(block, key)))
          : await read(block, keys);
      if (values.length != batch.length) {
        throw StateError('提案删除核验返回的结果数与请求不符');
      }
      for (var i = 0; i < batch.length; i++) {
        if (values[i] == null) deleted.add(batch[i]);
      }
    }
    return deleted;
  }

  Future<
    ({
      List<EligibleVoterTicket> tickets,
      Map<String, bool?> votes,
      bool? result,
      ({int yes, int no}) tally,
    })
  >
  jointInstitutionAt(
    CitizenBlockRef block,
    ProposalMeta meta,
    InstitutionInfo institution,
    List<EligibleVoterTicket> tickets,
  ) async {
    final cid = institution.cidNumber;
    final role = institution.orgType == OrgType.prb
        ? 'DIRECTOR'
        : 'COMMITTEE_MEMBER';
    final query = ProposalQueryService(
      block: block,
      getStorageRuntimeContext: _getStorageRuntimeContext,
      getStorage: _getStorage,
      getStorageBatch: _getStorageBatch,
    );
    if (meta.status == 0 && meta.stage == 1) {
      tickets = (await query.fetchEligibleVoterTickets(
        meta.proposalId,
        institution,
      )).where((ticket) => ticket.voterRoleCode == role).toList();
    } else if (tickets.isNotEmpty) {
      // 历史保留冻结人员；当前钱包只从本次最终块的有效双向绑定解析。
      final at = await _getStorageRuntimeContext(block);
      tickets = [
        for (final ticket in tickets)
          EligibleVoterTicket(
            voterAccountId: await _institutionService.personAccount(
              ticket.personCid!,
              at,
            ),
            personCid: ticket.personCid,
            cidNumber: ticket.cidNumber,
            voterRoleCode: ticket.voterRoleCode,
            voterRoleName: ticket.voterRoleName,
          ),
      ];
    }
    if (tickets.any(
      (ticket) =>
          ticket.cidNumber != cid ||
          ticket.voterRoleCode != role ||
          ticket.personCid == null,
    )) {
      throw const FormatException('联合投票冻结人员票据无效');
    }
    final runtime = RuntimeUpgradeService(
      getFinalizedHead: () async => block,
      getStorageRuntimeContext: _getStorageRuntimeContext,
      getStorage: _getStorage,
      getStorageBatch: _getStorageBatch,
    );
    final (result, tally, votes) = await (
      runtime.fetchJointVoteByInstitution(meta.proposalId, cid),
      runtime.fetchJointInstitutionTally(meta.proposalId, cid),
      runtime.fetchJointTicketVotesBatch(
        meta.proposalId,
        cid,
        role,
        tickets.map((ticket) => ticket.personCid!),
      ),
    ).wait;
    return (
      tickets: tickets,
      votes: {
        for (final ticket in tickets) ticket.ticketKey: votes[ticket.personCid],
      },
      result: result,
      tally: tally,
    );
  }

  /// 比较业务期待的原字节与 SDK 交付的 metadata 字段。
  static bool eventBytesEqual(Object? value, List<int> expected) {
    while (value is List<Object?> &&
        value.length == 1 &&
        value.single is List<Object?>) {
      value = value.single;
    }
    if (value is! List<Object?> || value.length != expected.length) {
      return false;
    }
    for (var i = 0; i < expected.length; i++) {
      if (value[i] != expected[i].toString()) return false;
    }
    return true;
  }

  /// 当前业务的可选 CID／岗位文本使用 metadata 给出的精确 Option 分支。
  static bool eventOptionalText(Object? value, String? expected) =>
      switch (value) {
        {'variant': 'None', 'fields': []} => expected == null,
        {'variant': 'Some', 'fields': [final payload]} =>
          expected != null && eventBytesEqual(payload, utf8.encode(expected)),
        _ => false,
      };

  /// 查询 NextProposalId（投票引擎全局递增 ID）。
  Future<BigInt> fetchNextProposalId() async {
    final data = await readProposalStorage('VotingEngine', 'NextProposalId');
    if (data == null) return BigInt.zero;
    if (data.length != 16) throw const FormatException('NextProposalId长度无效');
    return _decodeU128(data);
  }

  /// 查询提案状态。返回 status（0投票中、1通过、2否决、3已执行、4执行失败），null 表示不存在。
  Future<int?> fetchProposalStatus(BigInt proposalId) async {
    final data = await readProposalStorage('VotingEngine', 'Proposals', [
      proposalId,
    ]);
    if (data == null) return null;
    final meta = decodeProposalMeta(proposalId, data);
    if (meta == null) throw const FormatException('Proposals编码无效');
    return meta.status;
  }

  /// 查询并严格解码投票引擎提案元数据。
  Future<ProposalMeta?> fetchProposalMeta(BigInt proposalId) async {
    final data = await readProposalStorage('VotingEngine', 'Proposals', [
      proposalId,
    ]);
    if (data == null) return null;
    final meta = decodeProposalMeta(proposalId, data);
    if (meta == null) throw const FormatException('Proposals编码无效');
    return meta;
  }

  /// 读取 `VotingEngine::ProposalData` 的 opaque 业务字节。
  ///
  /// 具体业务治理语义仍由各 App 业务解码器负责；本服务仅统一
  /// App 侧 storage key，底层 finalized 读取继续由 CitizenSDK 执行。
  Future<Uint8List?> fetchProposalData(BigInt proposalId) {
    return readProposalStorage('VotingEngine', 'ProposalData', [proposalId]);
  }

  /// 查询并严格解码提案绑定的 VotePlan。
  Future<VotePlan?> fetchVotePlan(BigInt proposalId) async {
    final data = await readProposalStorage(
      'VotingEngine',
      'ProposalVotePlans',
      [proposalId],
    );
    return data == null
        ? null
        : InstitutionRoleStorageCodec.decodeVotePlan(data);
  }

  /// `VotingEngine::Proposal` SCALE 解码唯一真源。
  ///
  /// 任何业务服务需要提案元数据时必须调用本方法，禁止复制字段布局。
  static ProposalMeta? decodeProposalMeta(BigInt proposalId, Uint8List data) {
    try {
      // Proposal = kind + stage + status + internal_code Option
      //   + actor_cid_number Option + execution_account_id Option
      //   + subject CID 集合 + start(u32) + end(u32)。
      // 公民分母属于投票引擎按 proposal_id 保存的独立人口快照，不在 Proposal 重复存储。
      if (data.length < 3 + 3 + 1 + 4 + 4) return null;
      final kind = data[0];
      final stage = data[1];
      final status = data[2];
      if (kind > 3 ||
          status > 4 ||
          !const [0, 1, 2, 10, 11, 12, 13, 14, 20, 21].contains(stage)) {
        return null;
      }
      var offset = 3;

      String? internalCode;
      final internalCodeTag = data[offset++];
      if (internalCodeTag == 1) {
        if (offset + 4 > data.length) return null;
        internalCode = InstitutionCodeLabel.codeToString(
          data.sublist(offset, offset + 4),
        );
        offset += 4;
      } else if (internalCodeTag != 0) {
        return null;
      }

      String? actorCidNumber;
      if (offset >= data.length) return null;
      final actorCidTag = data[offset++];
      if (actorCidTag == 1) {
        final decoded = _readCidNumber(data, offset);
        if (decoded == null) return null;
        actorCidNumber = decoded.$1;
        offset = decoded.$2;
      } else if (actorCidTag != 0) {
        return null;
      }

      Uint8List? executionAccountId;
      if (offset >= data.length) return null;
      final executionAccountIdTag = data[offset++];
      if (executionAccountIdTag == 1) {
        if (offset + 32 > data.length) return null;
        executionAccountId = Uint8List.fromList(
          data.sublist(offset, offset + 32),
        );
        offset += 32;
      } else if (executionAccountIdTag != 0) {
        return null;
      }

      final subjectCids = _decodeSubjectCidNumbers(data, offset);
      if (subjectCids == null) return null;
      if (subjectCids.$2 + 4 + 4 != data.length) return null;

      return ProposalMeta(
        proposalId: proposalId,
        kind: kind,
        stage: stage,
        status: status,
        internalCode: internalCode,
        actorCidNumber: actorCidNumber,
        executionAccountId: executionAccountId,
        subjectCidNumbers: subjectCids.$1,
      );
    } catch (_) {
      return null;
    }
  }

  /// 查询投票计数。
  Future<({int yes, int no})> fetchVoteTally(BigInt proposalId) async {
    final data = await readProposalStorage('InternalVote', 'InternalTallies', [
      proposalId,
    ]);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 8) throw const FormatException('InternalTallies长度无效');
    return (yes: _decodeU32(data, 0), no: _decodeU32(data, 4));
  }

  /// 查询内部投票阈值快照。
  Future<int?> fetchInternalThresholdSnapshot(BigInt proposalId) async {
    final data = await readProposalStorage(
      'InternalVote',
      'InternalThresholdSnapshot',
      [proposalId],
    );
    if (data == null) return null;
    if (data.length != 4) {
      throw const FormatException('InternalThresholdSnapshot长度无效');
    }
    return _decodeU32(data, 0);
  }

  /// 查询提案创建时锁定的管理员快照。

  /// 查询一个完整机构岗位主体在提案创建时冻结的任职人员CID。
  Future<List<String>> fetchRoleVoters(
    BigInt proposalId,
    String cidNumber,
    String voterRoleCode,
  ) async {
    final subject = BytesBuilder(copy: false)
      ..add(_encodeBoundedText(cidNumber, 32, 'cid_number'))
      ..add(_encodeBoundedText(voterRoleCode, 64, 'voter_role_code'));
    final data = await readProposalStorage('VotingEngine', 'RoleVoters', [
      proposalId,
      (scale: subject.toBytes()),
    ]);
    if (data == null) {
      throw StateError('提案 $proposalId 缺少岗位 $voterRoleCode 的 RoleVoters');
    }
    final decoded = InstitutionRoleStorageCodec.decodePersons(data);
    if (decoded == null || decoded.isEmpty) {
      throw const FormatException('VotingEngine::RoleVoters SCALE 数据无效');
    }
    return decoded;
  }

  /// 返回提案全部冻结票据；同一钱包在多个岗位中会出现多次，禁止按账户去重。
  Future<List<EligibleVoterTicket>> fetchEligibleVoterTickets(
    BigInt proposalId,
    InstitutionInfo institution, {
    bool includeRoleNames = false,
  }) async {
    if (_block == null) {
      final block = await _getFinalizedHead();
      return ProposalQueryService(
        block: block,
        getStorageRuntimeContext: _getStorageRuntimeContext,
        getStorage: _getStorage,
        getStorageBatch: _getStorageBatch,
      ).fetchEligibleVoterTickets(
        proposalId,
        institution,
        includeRoleNames: includeRoleNames,
      );
    }
    final runtime = await _getStorageRuntimeContext(_block);
    final plan = await fetchVotePlan(proposalId);
    if (plan == null) {
      throw StateError('提案 $proposalId 缺少有效 VotePlan');
    }
    final tickets = <EligibleVoterTicket>[];
    for (final subject in plan.voterSubjects) {
      final role = subject.roleSubject;
      if (role == null || role.cidNumber != institution.cidNumber) continue;
      final persons = await fetchRoleVoters(
        proposalId,
        role.cidNumber,
        role.roleCode,
      );
      for (final personCid in persons) {
        final accountId = await _institutionService.personAccount(
          personCid,
          runtime,
        );
        tickets.add(
          EligibleVoterTicket(
            voterAccountId: accountId,
            personCid: personCid,
            cidNumber: role.cidNumber,
            voterRoleCode: role.roleCode,
          ),
        );
      }
    }
    if (tickets.isEmpty) {
      throw StateError('提案 $proposalId 没有当前机构的冻结岗位票据');
    }
    if (!includeRoleNames) return tickets;
    // 名称只作展示，按冻结票据岗位码去重读取；不依赖当前管理员姓名或任职。
    // 仅详情页启用，列表和待投票检查不增加展示资料读取。
    Map<String, String> names = const {};
    try {
      names = await _institutionService.fetchRoleNames(
        InstitutionIdentity.fromInstitution(institution),
        tickets.map((ticket) => ticket.voterRoleCode!),
        at: runtime,
      );
    } on Object catch (error) {
      AppLog.proposalFailure(stage: 'proposal_roles', error: error);
    }
    return [
      for (final ticket in tickets)
        EligibleVoterTicket(
          voterAccountId: ticket.voterAccountId,
          personCid: ticket.personCid,
          cidNumber: ticket.cidNumber,
          voterRoleCode: ticket.voterRoleCode,
          voterRoleName: names[ticket.voterRoleCode],
        ),
    ];
  }

  Uint8List _encodeBoundedText(String value, int maxBytes, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('$field 长度不合法');
    }
    return Uint8List.fromList([
      ...CitizenScale.compact(bytes.length),
      ...bytes,
    ]);
  }

  /// 查询某个提案主体当前的活跃提案 ID。
  Future<List<BigInt>> fetchActiveProposalIds(
    InstitutionInfo institution,
  ) async {
    return fetchActiveProposalIdsBySubjectKey(proposalSubjectKey(institution));
  }

  Future<List<BigInt>> fetchActiveProposalIdsBySubjectKey(
    Uint8List subjectKey,
  ) async {
    final data = await readProposalStorage(
      'VotingEngine',
      'ActiveProposalsBySubject',
      [(scale: subjectKey)],
    );
    if (data == null) return const [];
    final decoded = decodeActiveProposalIds(data);
    if (decoded == null) {
      throw const FormatException(
        'VotingEngine::ActiveProposalsBySubject SCALE 数据无效',
      );
    }
    return decoded;
  }

  /// 查询某管理员对某提案的投票记录。
  Future<bool?> fetchAdminVote(BigInt proposalId, String accountId) {
    return _internalVoteQuery.fetchAdminVote(proposalId, accountId);
  }

  /// 批量查询内部投票管理员记录。
  ///
  /// 详情页和待投票红点通过本方法合并 storage 读取，避免
  /// 按管理员逐条访问轻节点。
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    BigInt proposalId,
    Iterable<String> accountIds,
  ) {
    return _internalVoteQuery.fetchAdminVotesBatch(proposalId, accountIds);
  }

  Future<Map<String, bool?>> fetchTicketVotesBatch(
    BigInt proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) {
    return _internalVoteQuery.fetchTicketVotesBatch(proposalId, tickets);
  }

  Future<Uint8List?> readProposalStorage(
    String pallet,
    String storage, [
    List<Object> keys = const [],
  ]) async {
    final finalized = _block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('提案查询需要finalized块');
    }
    final runtime = await _getStorageRuntimeContext(finalized);
    return _getStorage(finalized, runtime.storageKey(pallet, storage, keys));
  }

  /// `VotingEngine::ProposalSubject` 的唯一 SCALE 编码真源。
  ///
  /// 机构主体固定为 `InstitutionCid(cid_number)`；只有个人多签使用
  /// `PersonalAccount(account_id)`，机构账户绝不能替代机构 CID。
  static Uint8List proposalSubjectKey(InstitutionInfo institution) =>
      institutionCidSubjectKey(institution.cidNumber);

  /// `ProposalSubject::InstitutionCid` 编码；只接受机构 CID。
  static Uint8List institutionCidSubjectKey(String cidNumber) {
    final normalized = cidNumber.trim();

    final cidBytes = Uint8List.fromList(utf8.encode(normalized));
    if (cidBytes.isEmpty || cidBytes.length > 32) {
      throw ArgumentError('机构 CID 的 UTF-8 长度必须为 1..32 字节');
    }
    final length = CitizenScale.compact(cidBytes.length);
    return Uint8List.fromList([0, ...length, ...cidBytes]);
  }

  /// 严格解码 `BoundedVec<AccountId32>` 管理员快照。
  static List<String>? decodeAdminSnapshot(Uint8List data) {
    try {
      final (count, lenSize) = _decodeCompact(data, 0);
      if (lenSize + count * 32 != data.length) return null;
      return List<String>.unmodifiable([
        for (var offset = lenSize; offset < data.length; offset += 32)
          citizenAccountIdFromBytes(data.sublist(offset, offset + 32)),
      ]);
    } catch (_) {
      return null;
    }
  }

  /// 严格解码 `BoundedVec<u128, MaxActiveProposals>`。
  static List<BigInt>? decodeActiveProposalIds(Uint8List data) {
    try {
      final (count, lenSize) = _decodeCompact(data, 0);
      if (count > maxActiveProposalsPerSubject ||
          lenSize + count * 16 != data.length) {
        return null;
      }
      return List<BigInt>.unmodifiable([
        for (var offset = lenSize; offset < data.length; offset += 16)
          CitizenScale.readUnsigned(data, offset, 16),
      ]);
    } catch (_) {
      return null;
    }
  }

  static (int, int) _decodeCompact(Uint8List data, int offset) {
    final result = CitizenScale.readCompact(data, offset);
    if (result.$2 > 4) throw const FormatException('Compact<u32>长度超出范围');
    return result;
  }

  static (String, int)? _readCidNumber(Uint8List data, int offset) {
    final (length, compactSize) = _decodeCompact(data, offset);
    final start = offset + compactSize;
    final end = start + length;
    if (length <= 0 || length > 32 || end > data.length) return null;
    try {
      return (
        utf8.decode(data.sublist(start, end), allowMalformed: false),
        end,
      );
    } on FormatException {
      return null;
    }
  }

  static (List<String>, int)? _decodeSubjectCidNumbers(
    Uint8List data,
    int offset,
  ) {
    final (count, lenSize) = _decodeCompact(data, offset);
    if (count > 256) return null;
    var cursor = offset + lenSize;
    final result = <String>[];
    for (var i = 0; i < count; i++) {
      final decoded = _readCidNumber(data, cursor);
      if (decoded == null) return null;
      result.add(decoded.$1);
      cursor = decoded.$2;
    }
    return (List.unmodifiable(result), cursor);
  }

  BigInt _decodeU128(Uint8List data) => CitizenScale.readUnsigned(data, 0, 16);

  int _decodeU32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();
}
