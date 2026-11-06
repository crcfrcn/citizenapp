import 'package:citizen_storage/user_isar.dart' as wallet_store show Action;
// 个人多签提案历史聚合服务(req 5)。
//
// 双轨制数据源:
// 1. 链上 `votingengine.ActiveProposalsBySubject[PersonalAccount(personal_account_id)]`
//    返回当前活跃(STATUS_VOTING)的提案 ID 列表。
// 2. 本机 Isar `action_kind` 永久保留所有历史快照,覆盖
//    链上 90 天后已清理的终态提案。
//
// `fetchAll` 把两条数据合并去重(以 proposal_id 为 key),并把链上活跃提案的
// 最新状态 upsert 到 Isar(同步缓存,防止其他设备发起的提案漏记)。

import 'dart:convert';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:polkadart/polkadart.dart' show Hasher;

import 'package:citizen_storage/user_isar.dart' hide Group;
import 'package:citizen_citizen/proposal/proposal_query_service.dart';

/// 提案动作类型常量(对齐 Isar entity action_kind 字段)。
class PersonalProposalAction {
  static const String create = 'create';
  static const String transfer = 'transfer';
  static const String close = 'close';
}

/// 提案状态字符串(对齐 votingengine 链上枚举,但用人类可读字符串持久化)。
class PersonalProposalStatus {
  static const String voting = 'voting';
  static const String passed = 'passed';
  static const String rejected = 'rejected';
  static const String executed = 'executed';
  static const String executionFailed = 'execution_failed';
}

/// 链上 votingengine status u8 → Isar 字符串。
String mapChainStatus(int? chainStatus) {
  switch (chainStatus) {
    case 0:
      return PersonalProposalStatus.voting;
    case 1:
      return PersonalProposalStatus.passed;
    case 2:
      return PersonalProposalStatus.rejected;
    case 3:
      return PersonalProposalStatus.executed;
    case 4:
      return PersonalProposalStatus.executionFailed;
    default:
      return PersonalProposalStatus.voting;
  }
}

/// 详情页提案列表渲染所需的视图模型。
class PersonalAccountProposalView {
  const PersonalAccountProposalView({
    required this.proposalId,
    required this.actionKind,
    required this.proposalState,
    required this.yesCount,
    required this.noCount,
    required this.createdAt,
    this.finalAt,
    this.snapshot,
  });

  final int proposalId;
  final String actionKind;
  final String proposalState;
  final int yesCount;
  final int noCount;
  final int createdAt;
  final int? finalAt;
  final Map<String, dynamic>? snapshot;

  bool get isActive => proposalState == PersonalProposalStatus.voting;
  bool get isFinal => !isActive;
}

class PersonalProposalHistoryService {
  PersonalProposalHistoryService({
    CitizenSdk? chain,
    ProposalQueryService? proposalService,
    Future<CitizenChainSyncStatus> Function()? getSyncStatus,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<Uint8List?> Function(CitizenBlockRef block)? getSystemEvents,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef block)?
    getRuntimeContext,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
  }) : _proposalService =
           proposalService ??
           ProposalQueryService(
             chain: chain,
             getFinalizedHead: getFinalizedHead,
             getStorage: getStorage,
             getSystemEvents: getSystemEvents,
             getRuntimeContext: getRuntimeContext,
             getStorageBatch: getStorageBatch,
           ),
       _getSyncStatus =
           getSyncStatus ??
           chain?.getSyncStatus ??
           (() => throw StateError('未配置getSyncStatus')),
       _getFinalizedHead =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置getFinalizedHead')),
       _getStorage =
           getStorage ??
           chain?.getStorage ??
           ((CitizenBlockRef block, Uint8List key) =>
               throw StateError('未配置getStorage'));
  final Future<CitizenChainSyncStatus> Function() _getSyncStatus;
  final Future<CitizenBlockRef> Function() _getFinalizedHead;
  final Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)
  _getStorage;

  final ProposalQueryService _proposalService;

  /// 拉取该多签的全部提案(活跃 + 历史),按 created_at desc 排序。
  ///
  /// 容错:链上失败仅回退 Isar;Isar 失败仅回退链上;两者都失败返回空列表。
  ///
  /// 状态新鲜度策略:
  /// 1. 链上 ActiveProposalsBySubject 同步活跃提案到 Isar(防其他设备漏记)
  /// 2. **额外**:遍历 Isar 中本机已知 status='voting' 的 entity,挨个查链上
  ///    Proposals[id] 拿最新 status + tally。这步必须独立于 active 列表,
  ///    因为提案一旦终态(passed/executed/rejected)就从 active 列表移除,
  ///    本机 Isar 永远停在 voting 状态,UI 卡片显示"投票中"是假数据。
  Future<List<PersonalAccountProposalView>> fetchAll(String accountId) async {
    final activeIds = await _safeFetchActiveProposalIds(accountId);

    // 链可达性正向探针:只有确认链已同步可达时,才允许把「链上查不到」判为幽灵
    // 并清理本机记录;离线/未同步一律保留本机 Isar 历史(容错回退→仅返回 Isar)。
    final chainReachable = (await _getSyncStatus()).isUsable;

    // Step 1: 链上活跃提案逐个同步到 Isar(防止其他设备发起的提案在本机无记录)。
    for (final pid in activeIds) {
      await _syncActiveProposalToIsar(accountId, pid);
    }

    // Step 2: 重查本机 Isar 中 status='voting' 的 entity,即使它们已不在 active 列表
    // (提案终态后就从 active 列表移除,但本机 entity 还停在 voting)。
    await _refreshLocalVotingEntities(accountId, chainReachable);

    return _readAllFromIsar(accountId);
  }

  /// 判断本机是否存在“创建提案仍是 voting，但链上 Proposals[id] 从未存在”的快照。
  ///
  /// 这类记录通常来自旧版本把 tx_hash 当成功后提前落库；它不是
  /// 正常注销历史，列表页可据此删除本地幽灵多签。
  Future<bool> hasUnchainedVotingCreateProposal(String accountId) async {
    try {
      // 离线/未同步无法确认提案是否真在链上,一律不判幽灵,避免误删本机记录。
      if (!(await _getSyncStatus()).isUsable) return false;
      final entities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .actionKindEqualTo(PersonalProposalAction.create)
            .proposalStateEqualTo(PersonalProposalStatus.voting)
            .findAll();
      });
      for (final e in entities) {
        final chainStatus = await _proposalService.fetchProposalStatus(
          e.proposalId,
        );
        if (chainStatus == null) return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// 遍历本机 Isar 中所有 status='voting' 的 entity,查链上 `Proposals[id]` 拿最新状态。
  /// 链上若已终态(passed/executed/rejected/execution_failed),upsert 为终态;
  /// 链上仍 voting 则只刷新 yes_count/no_count;链上 storage 不存在(已被 90 天清理)
  /// 也只刷新 vote tally(取现有值)— 不强制覆盖为终态,等本机其他渠道写入历史。
  Future<void> _refreshLocalVotingEntities(
    String accountId,
    bool chainReachable,
  ) async {
    try {
      final votingEntities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .proposalStateEqualTo(PersonalProposalStatus.voting)
            .findAll();
      });

      for (final e in votingEntities) {
        try {
          final chainStatus = await _proposalService.fetchProposalStatus(
            e.proposalId,
          );
          if (chainStatus == null) {
            // 仅当链确认可达却查不到该提案时,才判为「本机幽灵创建提案」并清理;
            // 离线/未同步则保留本机记录,避免误删待投票提案(数据丢失)。
            if (chainReachable &&
                e.actionKind == PersonalProposalAction.create) {
              await _deleteProposalEntity(
                accountId: accountId,
                proposalId: e.proposalId,
              );
            }
            continue;
          }
          final tally = await _proposalService.fetchVoteTally(e.proposalId);
          await recordOrUpdate(
            accountId: accountId,
            proposalId: e.proposalId,
            actionKind: e.actionKind,
            status: mapChainStatus(chainStatus),
            yesCount: tally.yes,
            noCount: tally.no,
          );
        } catch (_) {
          // 单条刷新失败不阻断其他 entity
        }
      }
    } catch (_) {
      // 整个刷新失败也不阻断主流程
    }
  }

  Future<void> _deleteProposalEntity({
    required String accountId,
    required int proposalId,
  }) async {
    await UserIsar.instance.writeTxn((isar) async {
      await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .proposalIdEqualTo(proposalId)
          .deleteAll();
    });
  }

  /// 写入或更新 Isar 提案 entity。
  ///
  /// [snapshot] 若非空将以 JSON 形式持久化(转账金额 / beneficiary / account_name 等)。
  Future<void> recordOrUpdate({
    required String accountId,
    required int proposalId,
    required String actionKind,
    required String status,
    required int yesCount,
    required int noCount,
    Map<String, dynamic>? snapshot,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await UserIsar.instance.writeTxn((isar) async {
      final existing = await isar
          .collection<wallet_store.Action>()
          .filter()
          .accountIdEqualTo(accountId)
          .proposalIdEqualTo(proposalId)
          .findFirst();

      final isFinal = status != PersonalProposalStatus.voting;

      final entity = existing ?? wallet_store.Action()
        ..accountId = accountId
        ..proposalId = proposalId
        ..createdAt = existing?.createdAt ?? now;

      entity.actionKind = actionKind;
      entity.proposalState = status;
      entity.yesCount = yesCount;
      entity.noCount = noCount;
      entity.finalAt = isFinal ? (existing?.finalAt ?? now) : null;
      if (snapshot != null) {
        entity.snapshotData = jsonEncode(snapshot);
      } else if (existing != null) {
        entity.snapshotData = existing.snapshotData;
      }

      await isar.collection<wallet_store.Action>().put(entity);
    });
  }

  // ──── 内部 ─────────────────────────────────────────────

  Future<List<int>> _safeFetchActiveProposalIds(String accountId) async {
    try {
      return await _proposalService.fetchActivePersonalProposalIds(accountId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _syncActiveProposalToIsar(
    String accountId,
    int proposalId,
  ) async {
    try {
      final chainStatus = await _proposalService.fetchProposalStatus(
        proposalId,
      );
      final tally = await _proposalService.fetchVoteTally(proposalId);
      final statusStr = mapChainStatus(chainStatus);

      final existing = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .proposalIdEqualTo(proposalId)
            .findFirst();
      });

      // 本机已有记录沿用其真实动作；首次发现则必须从当前链上
      // ProposalData 严格识别，禁止把缺失/未知载荷伪装成 create。
      String? actionKind = existing?.actionKind;
      if (existing == null) {
        final raw = await _fetchProposalDataRaw(proposalId);
        if (raw == null) return;
        actionKind = _decodeActionFromProposalData(raw);
        if (actionKind == null) return;
      }

      await recordOrUpdate(
        accountId: accountId,
        proposalId: proposalId,
        actionKind: actionKind!,
        status: statusStr,
        yesCount: tally.yes,
        noCount: tally.no,
      );
    } catch (_) {
      // 单条同步失败不阻断其他提案同步。
    }
  }

  /// 从链上 `VotingEngine.ProposalData[id]` 原始字节解码 `PersonalProposalAction`。
  ///
  /// ProposalData 是 `BoundedVec<u8>:Compact<len> + bytes`。
  ///
  /// 个人多签提案能命中的映射:
  /// - per-mgmt + 0 → create (PersonalAdmins::propose_create)
  /// - per-mgmt + 1 → close  (PersonalAdmins::propose_close)
  /// - multisig → transfer (MultisigTransfer::propose_transfer)
  /// 个人多签不会触发 safety_fund/sweep,无需识别。
  String? _decodeActionFromProposalData(Uint8List raw) {
    try {
      final (length, lenSize) = _decodeCompact(raw, 0);
      if (lenSize + length != raw.length) return null;
      final data = Uint8List.sublistView(raw, lenSize);

      // per-mgmt = b"per-mgmt" 8 字节，后接 action_kind byte。
      const perMgmt = [0x70, 0x65, 0x72, 0x2d, 0x6d, 0x67, 0x6d, 0x74];
      if (_startsWithAt(data, perMgmt, 0)) {
        if (perMgmt.length >= data.length) return null;
        final actionKind = data[perMgmt.length];
        if (actionKind == 0) return PersonalProposalAction.create;
        if (actionKind == 1) return PersonalProposalAction.close;
        return null;
      }

      // 当前 multisig ProposalData 不含 action_kind byte；tag 本身唯一表示转账。
      final multisig = 'multisig'.codeUnits;
      if (_startsWithAt(data, multisig, 0) &&
          data.length >= multisig.length + 1 + 32 + 32 + 16 + 1 + 32 &&
          (data[multisig.length] == 0 || data[multisig.length] == 1)) {
        return PersonalProposalAction.transfer;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 测试入口：锁定当前投票引擎 ProposalData 模块标签。
  @visibleForTesting
  String? debugDecodeActionFromProposalData(Uint8List raw) {
    return _decodeActionFromProposalData(raw);
  }

  bool _startsWithAt(Uint8List data, List<int> prefix, int offset) {
    if (offset + prefix.length > data.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  /// 读取 `VotingEngine.ProposalData[id]` 原始字节(`BoundedVec<u8>` SCALE 编码)。
  Future<Uint8List?> _fetchProposalDataRaw(int proposalId) async {
    try {
      final key = _buildStorageKey(
        'VotingEngine',
        'ProposalData',
        _u64ToLeBytes(proposalId),
      );
      final finalized = await _getFinalizedHead();
      return await _getStorage(finalized, key);
    } catch (_) {
      return null;
    }
  }

  Uint8List _u64ToLeBytes(int value) {
    final bytes = Uint8List(8);
    ByteData.sublistView(bytes).setUint64(0, value, Endian.little);
    return bytes;
  }

  Future<List<PersonalAccountProposalView>> _readAllFromIsar(
    String accountId,
  ) async {
    try {
      final entities = await UserIsar.instance.read((isar) {
        return isar
            .collection<wallet_store.Action>()
            .filter()
            .accountIdEqualTo(accountId)
            .sortByCreatedAtDesc()
            .findAll();
      });
      return entities.map(_entityToView).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  PersonalAccountProposalView _entityToView(wallet_store.Action e) {
    Map<String, dynamic>? snapshot;
    if (e.snapshotData != null && e.snapshotData!.isNotEmpty) {
      try {
        snapshot = jsonDecode(e.snapshotData!) as Map<String, dynamic>;
      } catch (_) {
        snapshot = null;
      }
    }
    return PersonalAccountProposalView(
      proposalId: e.proposalId,
      actionKind: e.actionKind,
      proposalState: e.proposalState,
      yesCount: e.yesCount,
      noCount: e.noCount,
      createdAt: e.createdAt,
      finalAt: e.finalAt,
      snapshot: snapshot,
    );
  }

  // ──── 编码 / 哈希工具(对齐 votingengine storage key) ────

  Uint8List _buildStorageKey(String pallet, String storage, Uint8List keyData) {
    final palletHash = Hasher.twoxx128.hashString(pallet);
    final storageHash = Hasher.twoxx128.hashString(storage);
    final keyHash = Hasher.blake2b128.hash(keyData);
    final result = Uint8List(
      palletHash.length + storageHash.length + keyHash.length + keyData.length,
    );
    var offset = 0;
    result.setAll(offset, palletHash);
    offset += palletHash.length;
    result.setAll(offset, storageHash);
    offset += storageHash.length;
    result.setAll(offset, keyHash);
    offset += keyHash.length;
    result.setAll(offset, keyData);
    return result;
  }

  (int, int) _decodeCompact(Uint8List data, int offset) {
    if (offset < 0 || offset >= data.length) {
      throw const FormatException('Compact<u32> offset 越界');
    }
    final first = data[offset];
    final mode = first & 0x03;
    if (mode == 0) return (first >> 2, 1);
    if (mode == 1) {
      if (offset + 1 >= data.length) {
        throw const FormatException('Compact<u32> mode1 长度不足');
      }
      return ((first | data[offset + 1] << 8) >> 2, 2);
    }
    if (mode == 2) {
      if (offset + 3 >= data.length) {
        throw const FormatException('Compact<u32> mode2 长度不足');
      }
      return (
        (first |
                data[offset + 1] << 8 |
                data[offset + 2] << 16 |
                data[offset + 3] << 24) >>
            2,
        4,
      );
    }
    throw const FormatException('Compact<u32> big-integer 模式不支持');
  }
}
