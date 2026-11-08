import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_info.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';
import 'package:citizen_citizen/proposal/internal_vote_query_service.dart';

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
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getStorageRuntimeContext,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _block = block,
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
             readEvents: getSystemEvents ?? chain?.getSystemEvents ??
                 ((_) => throw StateError('未配置事件读取')),
             readRuntime: getRuntimeContext ?? chain?.getRuntimeContext ??
                 ((_) => throw StateError('未配置事件 metadata')),
           )),
       _getStorageRuntimeContext = getStorageRuntimeContext ?? getRuntimeContext ??
           chain?.getRuntimeContext ?? ((block) => throw StateError('未配置getRuntimeContext')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<List<CitizenSystemEvent>> Function(CitizenBlockRef) _getFinalizedEvents;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _getStorageRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  final CitizenBlockRef? _block;
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
    return events.where((event) =>
        event.extrinsicIndex == execution.extrinsicIndex).toList();
  }

  /// 比较业务期待的原字节与 SDK 交付的 metadata 字段。
  static bool eventBytesEqual(Object? value, List<int> expected) {
    while (value is List<Object?> && value.length == 1 &&
        value.single is List<Object?>) {
      value = value.single;
    }
    if (value is! List<Object?> || value.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (value[i] != expected[i].toString()) return false;
    }
    return true;
  }

  /// 当前业务的可选 CID／岗位文本使用 metadata 给出的精确 Option 分支。
  static bool eventOptionalText(Object? value, String? expected) => switch (value) {
    {'variant': 'None', 'fields': []} => expected == null,
    {'variant': 'Some', 'fields': [final payload]} =>
      expected != null && eventBytesEqual(payload, utf8.encode(expected)),
    _ => false,
  };

  /// 查询 NextProposalId（投票引擎全局递增 ID）。
  Future<int> fetchNextProposalId() async {
    final data = await _readStorage('VotingEngine', 'NextProposalId');
    if (data == null) return 0;
    if (data.length != 8) throw const FormatException('NextProposalId长度无效');
    return _decodeU64(data);
  }

  /// 查询提案状态。返回 status（0投票中、1通过、2否决、3已执行、4执行失败），null 表示不存在。
  Future<int?> fetchProposalStatus(int proposalId) async {
    final data = await _readStorage('VotingEngine', 'Proposals', [proposalId]);
    if (data == null) return null;
    final meta = decodeProposalMeta(proposalId, data);
    if (meta == null) throw const FormatException('Proposals编码无效');
    return meta.status;
  }

  /// 查询并严格解码投票引擎提案元数据。
  Future<ProposalMeta?> fetchProposalMeta(int proposalId) async {
    final data = await _readStorage('VotingEngine', 'Proposals', [proposalId]);
    if (data == null) return null;
    final meta = decodeProposalMeta(proposalId, data);
    if (meta == null) throw const FormatException('Proposals编码无效');
    return meta;
  }

  /// 读取 `VotingEngine::ProposalData` 的 opaque 业务字节。
  ///
  /// 具体 PersonalManage／机构治理语义仍由各 App 业务解码器负责；本服务仅统一
  /// App 侧 storage key，底层 finalized 读取继续由 CitizenSDK 执行。
  Future<Uint8List?> fetchProposalData(int proposalId) {
    return _readStorage('VotingEngine', 'ProposalData', [proposalId]);
  }

  /// 查询并严格解码提案绑定的 VotePlan。
  Future<VotePlan?> fetchVotePlan(int proposalId) async {
    final data = await _readStorage('VotingEngine', 'ProposalVotePlans', [proposalId]);
    return data == null
        ? null
        : InstitutionRoleStorageCodec.decodeVotePlan(data);
  }

  /// `VotingEngine::Proposal` SCALE 解码唯一真源。
  ///
  /// 任何业务服务需要提案元数据时必须调用本方法，禁止复制字段布局。
  static ProposalMeta? decodeProposalMeta(int proposalId, Uint8List data) {
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
  Future<({int yes, int no})> fetchVoteTally(int proposalId) async {
    final data = await _readStorage('InternalVote', 'InternalTallies', [proposalId]);
    if (data == null) return (yes: 0, no: 0);
    if (data.length != 8) throw const FormatException('InternalTallies长度无效');
    return (yes: _decodeU32(data, 0), no: _decodeU32(data, 4));
  }

  /// 查询内部投票阈值快照。
  Future<int?> fetchInternalThresholdSnapshot(int proposalId) async {
    final data = await _readStorage('InternalVote', 'InternalThresholdSnapshot', [proposalId]);
    if (data == null) return null;
    if (data.length != 4) {
      throw const FormatException('InternalThresholdSnapshot长度无效');
    }
    return _decodeU32(data, 0);
  }

  /// 查询提案创建时锁定的管理员快照。
  Future<List<String>> fetchAdminSnapshot(
    int proposalId,
    InstitutionInfo institution,
  ) async {
    final data = await _readStorage('VotingEngine', 'AdminSnapshot', [
      proposalId,
      (scale: proposalSubjectKey(institution)),
    ]);
    if (data == null) {
      throw StateError('提案 $proposalId 缺少 VotingEngine::AdminSnapshot');
    }
    final decoded = decodeAdminSnapshot(data);
    if (decoded == null || decoded.isEmpty) {
      throw const FormatException('VotingEngine::AdminSnapshot SCALE 数据无效');
    }
    return decoded;
  }

  /// 查询提案创建时锁定的实际投票账户快照。
  ///
  /// 个人多签读取 `AdminSnapshot`；机构提案必须按完整岗位主体读取
  /// `VoterSnapshot`。禁止把多个岗位按钱包合并，也禁止回落当前 admins。
  Future<List<String>> fetchEligibleVoterSnapshot(
    int proposalId,
    InstitutionInfo institution,
  ) async {
    if (isPersonalAccountIdentity(institution.cidNumber)) {
      return fetchAdminSnapshot(proposalId, institution);
    }
    throw StateError('机构提案必须按明确岗位调用 fetchRoleVoterSnapshot');
  }

  /// 查询一个完整机构岗位主体在提案创建时冻结的任职钱包。
  Future<List<String>> fetchRoleVoterSnapshot(
    int proposalId,
    String cidNumber,
    String voterRoleCode,
  ) async {
    final subject = BytesBuilder(copy: false)
      ..addByte(0) // AuthorizationSubject::Institution
      ..add(_encodeBoundedText(cidNumber, 32, 'cid_number'))
      ..add(_encodeBoundedText(voterRoleCode, 64, 'voter_role_code'));
    final data = await _readStorage('VotingEngine', 'VoterSnapshot', [
      proposalId,
      (scale: subject.toBytes()),
    ]);
    if (data == null) {
      throw StateError('提案 $proposalId 缺少岗位 $voterRoleCode 的 VoterSnapshot');
    }
    final decoded = decodeAdminSnapshot(data);
    if (decoded == null || decoded.isEmpty) {
      throw const FormatException('VotingEngine::VoterSnapshot SCALE 数据无效');
    }
    return decoded;
  }

  /// 返回提案全部冻结票据；同一钱包在多个岗位中会出现多次，禁止按账户去重。
  Future<List<EligibleVoterTicket>> fetchEligibleVoterTickets(
    int proposalId,
    InstitutionInfo institution,
  ) async {
    if (isPersonalAccountIdentity(institution.cidNumber)) {
      final accountIds = await fetchAdminSnapshot(proposalId, institution);
      return accountIds
          .map((accountId) => EligibleVoterTicket(voterAccountId: accountId))
          .toList(growable: false);
    }
    final plan = await fetchVotePlan(proposalId);
    if (plan == null) {
      throw StateError('提案 $proposalId 缺少有效 VotePlan');
    }
    final tickets = <EligibleVoterTicket>[];
    for (final subject in plan.voterSubjects) {
      final role = subject.roleSubject;
      if (role == null || role.cidNumber != institution.cidNumber) continue;
      final accountIds = await fetchRoleVoterSnapshot(
        proposalId,
        role.cidNumber,
        role.roleCode,
      );
      for (final accountId in accountIds) {
        tickets.add(
          EligibleVoterTicket(
            voterAccountId: accountId,
            cidNumber: role.cidNumber,
            voterRoleCode: role.roleCode,
          ),
        );
      }
    }
    if (tickets.isEmpty) {
      throw StateError('提案 $proposalId 没有当前机构的冻结岗位票据');
    }
    return tickets;
  }

  Uint8List _encodeBoundedText(String value, int maxBytes, String field) {
    final bytes = utf8.encode(value.trim());
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('$field 长度不合法');
    }
    return Uint8List.fromList([...CitizenScale.compact(bytes.length), ...bytes]);
  }

  /// 查询某个提案主体当前的活跃提案 ID。
  Future<List<int>> fetchActiveProposalIds(InstitutionInfo institution) async {
    return _fetchActiveProposalIdsBySubjectKey(proposalSubjectKey(institution));
  }

  /// 个人多签历史同步入口；个人多签没有 CID，只能以 AccountId 为主体。
  Future<List<int>> fetchActivePersonalProposalIds(String accountId) {
    return _fetchActiveProposalIdsBySubjectKey(
      personalAccountSubjectKey(accountId),
    );
  }

  Future<List<int>> _fetchActiveProposalIdsBySubjectKey(
    Uint8List subjectKey,
  ) async {
    final data = await _readStorage('VotingEngine', 'ActiveProposalsBySubject', [
      (scale: subjectKey),
    ]);
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
  Future<bool?> fetchAdminVote(int proposalId, String accountId) {
    return _internalVoteQuery.fetchAdminVote(proposalId, accountId);
  }

  /// 批量查询内部投票管理员记录。
  ///
  /// 详情页和待投票红点通过本方法合并 storage 读取，避免
  /// 按管理员逐条访问轻节点。
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    int proposalId,
    Iterable<String> accountIds,
  ) {
    return _internalVoteQuery.fetchAdminVotesBatch(proposalId, accountIds);
  }

  Future<Map<String, bool?>> fetchTicketVotesBatch(
    int proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) {
    return _internalVoteQuery.fetchTicketVotesBatch(proposalId, tickets);
  }

  Future<Uint8List?> _readStorage(
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
  static Uint8List proposalSubjectKey(InstitutionInfo institution) {
    if (isPersonalAccountIdentity(institution.cidNumber)) {
      return personalAccountSubjectKey(institution.accountId);
    }

    return institutionCidSubjectKey(institution.cidNumber);
  }

  /// `ProposalSubject::InstitutionCid` 编码；只接受机构 CID。
  static Uint8List institutionCidSubjectKey(String cidNumber) {
    final normalized = cidNumber.trim();
    if (isPersonalAccountIdentity(normalized)) {
      throw ArgumentError('个人多签身份不得编码为 InstitutionCid');
    }
    final cidBytes = Uint8List.fromList(utf8.encode(normalized));
    if (cidBytes.isEmpty || cidBytes.length > 32) {
      throw ArgumentError('机构 CID 的 UTF-8 长度必须为 1..32 字节');
    }
    final length = CitizenScale.compact(cidBytes.length);
    return Uint8List.fromList([0, ...length, ...cidBytes]);
  }

  /// `ProposalSubject::PersonalAccount` 编码；AccountId 必须恰好 32 字节。
  static Uint8List personalAccountSubjectKey(String accountId) {
    return Uint8List.fromList([1, ...citizenAccountIdBytes(accountId)]);
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

  /// 严格解码 `BoundedVec<u64, MaxActiveProposals>`。
  static List<int>? decodeActiveProposalIds(Uint8List data) {
    try {
      final (count, lenSize) = _decodeCompact(data, 0);
      if (count > maxActiveProposalsPerSubject ||
          lenSize + count * 8 != data.length) {
        return null;
      }
      return List<int>.unmodifiable([
        for (var offset = lenSize; offset < data.length; offset += 8)
          CitizenScale.readUnsigned(data, offset, 8).toInt(),
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

  int _decodeU64(Uint8List data) => CitizenScale.readUnsigned(data, 0, 8).toInt();

  int _decodeU32(Uint8List data, int offset) =>
      CitizenScale.readUnsigned(data, offset, 4).toInt();
}
