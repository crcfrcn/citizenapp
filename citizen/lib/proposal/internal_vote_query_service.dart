// 读取统一内部投票票据、计票及准确主体资格。

import 'dart:typed_data';
import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/proposal/proposal_models.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';

/// InternalVote 通用查询服务。
///
/// 内部投票记录属于投票引擎通用状态，不放进具体业务模块，
/// 避免 proposal 共享层依赖业务 service。
class InternalVoteQueryService {
  InternalVoteQueryService({
    CitizenSdk? chain,
    CitizenBlockRef? block,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _block = block,
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getRuntimeContext =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((block) => throw StateError('未配置getRuntimeContext')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage')),
       _getStorageBatch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((CitizenBlockRef block, List<Uint8List> keys) =>
               throw StateError('未配置getStorageBatch'));
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef)
  _getRuntimeContext;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;
  final Future<List<Uint8List?>> Function(
    CitizenBlockRef block,
    List<Uint8List> keys,
  )
  _getStorageBatch;

  final CitizenBlockRef? _block;

  /// 查询某管理员对某提案的投票记录。null=未投票，true=赞成，false=反对。
  Future<bool?> fetchAdminVote(BigInt proposalId, String accountId) async {
    final data = await readVoteFields(_ticketVoteFields(proposalId, accountId));
    return decodeVote(data);
  }

  /// 查询一张机构岗位票据；CID、岗位码、钱包三者共同确定唯一票。
  Future<bool?> fetchInstitutionTicketVote(
    BigInt proposalId,
    String cidNumber,
    String voterRoleCode,
    String personCid,
  ) async {
    final data = await readVoteFields(
      _ticketVoteFields(
        proposalId,
        personCid,
        cidNumber: cidNumber,
        voterRoleCode: voterRoleCode,
      ),
    );
    return decodeVote(data);
  }

  /// 批量查询管理员投票记录。
  ///
  /// 详情页和红点判断不能再按管理员逐条 RPC；这里统一拼好
  /// `InternalVotesByTicket` 的个人票据 storage key 后分块读取。
  Future<Map<String, bool?>> fetchAdminVotesBatch(
    BigInt proposalId,
    Iterable<String> accountIds,
  ) async {
    final keyByAccountId = <String, List<Object>>{};
    for (final accountId in accountIds) {
      final normalizedAccountId = _requireAccountId(accountId);
      keyByAccountId[normalizedAccountId] = _ticketVoteFields(
        proposalId,
        normalizedAccountId,
      );
    }
    if (keyByAccountId.isEmpty) return const {};

    final values = await readVoteFieldsBatch(keyByAccountId.values.toList());
    return {
      for (var index = 0; index < keyByAccountId.length; index++)
        keyByAccountId.keys.elementAt(index): decodeVote(values[index]),
    };
  }

  /// 批量查询完整票据；返回键为 [EligibleVoterTicket.ticketKey]。
  Future<Map<String, bool?>> fetchTicketVotesBatch(
    BigInt proposalId,
    Iterable<EligibleVoterTicket> tickets,
  ) async {
    final storageByTicket = <String, List<Object>>{};
    for (final ticket in tickets) {
      storageByTicket[ticket.ticketKey] = _ticketVoteFields(
        proposalId,
        ticket.isInstitution ? ticket.personCid! : ticket.voterAccountId!,
        cidNumber: ticket.cidNumber,
        voterRoleCode: ticket.voterRoleCode,
      );
    }
    final values = await readVoteFieldsBatch(storageByTicket.values.toList());
    return {
      for (var index = 0; index < storageByTicket.length; index++)
        storageByTicket.keys.elementAt(index): decodeVote(values[index]),
    };
  }

  /// 跨提案批量查询内部投票:输入 `{proposal_id: [account_id]}`,一次链查返回
  /// `{proposal_id: {account_id: vote?}}`。
  ///
  /// (ADR-018 R2):公民-提案列表原来每个提案各发一次批量 RPC(P 个提案
  /// = P 次往返),这里把所有 (proposal_id, admin) 的 storage key 一次拼齐、单次
  /// 分块读取,P 次往返降为 1 次。
  Future<Map<BigInt, Map<String, bool?>>> fetchAdminVotesForProposals(
    Map<BigInt, List<String>> accountIdsByProposal,
  ) async {
    final keys = <List<Object>>[];
    final coordinates = <({BigInt pid, String accountId})>[];
    for (final entry in accountIdsByProposal.entries) {
      for (final accountId in entry.value) {
        final normalizedAccountId = _requireAccountId(accountId);
        keys.add(_ticketVoteFields(entry.key, normalizedAccountId));
        coordinates.add((pid: entry.key, accountId: normalizedAccountId));
      }
    }
    if (keys.isEmpty) return const {};
    final values = await readVoteFieldsBatch(keys);
    final result = <BigInt, Map<String, bool?>>{};
    for (var index = 0; index < coordinates.length; index++) {
      final coord = coordinates[index];
      (result[coord.pid] ??= <String, bool?>{})[coord.accountId] = decodeVote(
        values[index],
      );
    }
    return result;
  }

  /// 跨提案批量查询完整票据；机构岗位票据和个人票据共用一次分块读取。
  Future<Map<BigInt, Map<String, bool?>>> fetchTicketVotesForProposals(
    Map<BigInt, List<EligibleVoterTicket>> ticketsByProposal,
  ) async {
    final keys = <List<Object>>[];
    final coordinates = <({BigInt pid, String ticketKey})>[];
    for (final entry in ticketsByProposal.entries) {
      for (final ticket in entry.value) {
        final storageKey = _ticketVoteFields(
          entry.key,
          ticket.isInstitution ? ticket.personCid! : ticket.voterAccountId!,
          cidNumber: ticket.cidNumber,
          voterRoleCode: ticket.voterRoleCode,
        );
        keys.add(storageKey);
        coordinates.add((pid: entry.key, ticketKey: ticket.ticketKey));
      }
    }
    if (keys.isEmpty) return const {};
    final values = await readVoteFieldsBatch(keys);
    final result = <BigInt, Map<String, bool?>>{};
    for (var index = 0; index < coordinates.length; index++) {
      final coord = coordinates[index];
      (result[coord.pid] ??= <String, bool?>{})[coord.ticketKey] = decodeVote(
        values[index],
      );
    }
    return result;
  }

  List<Object> _ticketVoteFields(
    BigInt proposalId,
    String accountId, {
    String? cidNumber,
    String? voterRoleCode,
  }) {
    if (proposalId.isNegative) throw ArgumentError('proposal_id不得为负');
    final CitizenScaleVariant ticket;
    if (cidNumber == null && voterRoleCode == null) {
      ticket = (
        variant: 'Personal',
        fields: [citizenAccountIdBytes(accountId)],
      );
    } else if (cidNumber != null && voterRoleCode != null) {
      if (!InstitutionRoleStorageCodec.isPersonCid(accountId)) {
        throw ArgumentError('机构票据必须使用人员CID');
      }
      ticket = (
        variant: 'Institution',
        fields: [
          [
            [
              _boundedText(cidNumber, 32, 'cid_number'),
              _boundedText(voterRoleCode, 64, 'voter_role_code'),
            ],
            _boundedText(accountId, 32, 'person_cid'),
          ],
        ],
      );
    } else {
      throw ArgumentError('机构票据查询必须同时提供 cid_number 和 voter_role_code');
    }
    return [proposalId, ticket];
  }

  Future<CitizenRuntimeContext> _finalizedRuntime() async {
    final finalized = _block ?? await _getFinalizedHead();
    if (finalized.finality != CitizenBlockFinality.finalized) {
      throw StateError('投票查询需要finalized块');
    }
    return _getRuntimeContext(finalized);
  }

  Future<Uint8List?> readVoteFields(List<Object> fields) async {
    final runtime = await _finalizedRuntime();
    return _getStorage(
      runtime.block,
      runtime.storageKey('InternalVote', 'InternalVotesByTicket', fields),
    );
  }

  Future<List<Uint8List?>> readVoteFieldsBatch(
    List<List<Object>> fields,
  ) async {
    if (fields.isEmpty) return const <Uint8List?>[];
    final runtime = await _finalizedRuntime();
    final keys = [
      for (final key in fields)
        runtime.storageKey('InternalVote', 'InternalVotesByTicket', key),
    ];
    final result = <Uint8List?>[];
    for (var offset = 0; offset < keys.length; offset += 100) {
      final end = (offset + 100).clamp(0, keys.length);
      final values = await _getStorageBatch(
        runtime.block,
        keys.sublist(offset, end),
      );
      if (values.length != end - offset) {
        throw const FormatException('投票批量响应数量不符');
      }
      result.addAll(values);
    }
    return result;
  }

  bool? decodeVote(Uint8List? data) {
    if (data == null) return null;
    if (data.length != 1 || (data[0] != 0 && data[0] != 1)) {
      throw const FormatException('InternalVotesByTicket 必须是严格的 SCALE bool');
    }
    return data[0] == 1;
  }

  Uint8List _boundedText(String value, int maxBytes, String field) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    if (value != value.trim() || bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('$field 长度不合法');
    }
    return bytes;
  }

  String _requireAccountId(String accountId) {
    if (!isCitizenAccountId(accountId)) {
      throw const FormatException('account_id 必须为小写 0x + 64 位十六进制');
    }
    return accountId;
  }
}
