// 按最终块读取机构人员任职及当前身份绑定，解码机构管理提案。

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:citizen_citizen/institution/institution_models.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_role_models.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';

/// 机构管理提案解码服务（公权/私权共用）。
///
/// 机构身份只能由 `cid_number` 表示；具体命名账户只是提案的
/// `institution_account_id` 参数，不反向作为机构主键。
///
/// 任职人员投票一律走 `InternalVote::cast`（经 InternalVoteService），不在本服务。
class InstitutionChainService {
  InstitutionChainService({
    CitizenSdk? chain,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<CitizenRuntimeContext> Function(CitizenBlockRef)? getRuntimeContext,
    Future<Uint8List?> Function(CitizenBlockRef, Uint8List)? getStorage,
    Future<List<Uint8List?>> Function(CitizenBlockRef, List<Uint8List>)?
    getStorageBatch,
    Future<List<Uint8List>> Function(
      CitizenBlockRef,
      Uint8List, {
      Uint8List? startKey,
      int limit,
    })?
    getStorageKeysPaged,
  }) : _head =
           getFinalizedHead ??
           chain?.getFinalizedHead ??
           (() => throw StateError('未配置最终块读取')),
       _runtime =
           getRuntimeContext ??
           chain?.getRuntimeContext ??
           ((_) => throw StateError('未配置metadata读取')),
       _storage =
           getStorage ??
           chain?.getStorage ??
           ((_, _) => throw StateError('未配置链存储读取')),
       _batch =
           getStorageBatch ??
           chain?.getStorageBatch ??
           ((_, _) => throw StateError('未配置链批读')),
       _keys =
           getStorageKeysPaged ??
           chain?.getStorageKeysPaged ??
           ((_, _, {Uint8List? startKey, int limit = 256}) =>
               throw StateError('未配置链键分页'));
  final Future<CitizenBlockRef> Function() _head;
  final Future<CitizenRuntimeContext> Function(CitizenBlockRef) _runtime;
  final Future<Uint8List?> Function(CitizenBlockRef, Uint8List) _storage;
  final Future<List<Uint8List?>> Function(CitizenBlockRef, List<Uint8List>)
  _batch;
  final Future<List<Uint8List>> Function(
    CitizenBlockRef,
    Uint8List, {
    Uint8List? startKey,
    int limit,
  })
  _keys;

  Future<CitizenRuntimeContext> finalizedRuntime() async {
    final block = await _head();
    if (block.finality != CitizenBlockFinality.finalized) {
      throw StateError('机构资格必须读取最终块');
    }
    return _runtime(block);
  }

  Future<InstitutionIdentity> _resolveIdentity(
    InstitutionIdentity identity,
    CitizenRuntimeContext runtime,
  ) async {
    if (identity.kind != null) return identity;
    final cid = Uint8List.fromList(utf8.encode(identity.cidNumber));
    final rows = await _batch(runtime.block, [
      runtime.storageKey('PublicEntity', 'Institutions', [cid]),
      runtime.storageKey('PrivateEntity', 'Institutions', [cid]),
    ]);
    if (rows.length != 2 || (rows[0] == null) == (rows[1] == null)) {
      throw const FormatException('非法人机构所属公私权模块缺失或重复');
    }
    return InstitutionIdentity(
      cidNumber: identity.cidNumber,
      orgCode: identity.orgCode,
      kind: rows[0] != null ? 0 : 1,
      accountLabel: identity.accountLabel,
    );
  }

  /// 当前有效双向绑定与登记状态全部来自同一最终块；不消费本机激活记录。
  Future<String?> personCid(
    String accountId,
    CitizenRuntimeContext runtime,
  ) async {
    final raw = await _storage(
      runtime.block,
      runtime.storageKey('Identity', 'CidByAccountId', [
        citizenAccountIdBytes(accountId),
      ]),
    );
    if (raw == null) return null;
    final (length, offset) = CitizenScale.readCompact(raw, 0);
    if (offset + length != raw.length || length > 32) {
      throw const FormatException('人员反向绑定编码无效');
    }
    final cid = utf8.decode(raw.sublist(offset));
    if (!InstitutionRoleStorageCodec.isPersonCid(cid)) return null;
    return await personAccount(cid, runtime) == accountId ? cid : null;
  }

  /// 正向绑定、登记状态及钱包反向绑定必须同时有效。
  Future<String?> personAccount(
    String personCid,
    CitizenRuntimeContext runtime,
  ) async {
    if (!InstitutionRoleStorageCodec.isPersonCid(personCid)) return null;
    final cid = Uint8List.fromList(utf8.encode(personCid));
    final entries = ['AccountIdByCid', 'BindingRevisionByCid', 'CidRegistry'];
    final rows = await _batch(runtime.block, [
      for (final entry in entries) runtime.storageKey('Identity', entry, [cid]),
    ]);
    if (rows.length != 3) throw const FormatException('人员绑定批读不完整');
    final account = rows[0], revision = rows[1], record = rows[2];
    if (account == null || revision == null || record == null) return null;
    if (account.length != 32 ||
        revision.length != 8 ||
        CitizenScale.readUnsigned(revision, 0, 8) == BigInt.zero) {
      throw const FormatException('人员绑定记录无效');
    }
    final decoded = runtime.decodeStorage('Identity', 'CidRegistry', record);
    if (decoded is! Map<String, dynamic> ||
        decoded['status'] is! Map ||
        (decoded['status'] as Map)['variant'] != 'Active') {
      return null;
    }
    final reverse = await _storage(
      runtime.block,
      runtime.storageKey('Identity', 'CidByAccountId', [account]),
    );
    if (reverse == null) return null;
    final (count, prefix) = CitizenScale.readCompact(reverse, 0);
    if (prefix + count != reverse.length ||
        utf8.decode(reverse.sublist(prefix)) != personCid) {
      return null;
    }
    return citizenAccountIdFromBytes(account);
  }

  /// 从机构岗位直接读取任职，不读取已删除的独立管理员名册。
  Future<List<InstitutionAssignment>> fetchAssignments(
    InstitutionIdentity identity, {
    CitizenRuntimeContext? at,
  }) async {
    final runtime = at ?? await finalizedRuntime();
    identity = await _resolveIdentity(identity, runtime);
    final cid = Uint8List.fromList(utf8.encode(identity.cidNumber));
    final prefix = runtime.storageKey(identity.pallet, 'InstitutionRoles', [
      cid,
    ]);
    final keys = <Uint8List>[];
    Uint8List? start;
    while (true) {
      final page = await _keys(
        runtime.block,
        prefix,
        startKey: start,
        limit: 256,
      );
      if (page.isEmpty) break;
      for (final key in page) {
        if (key.length < prefix.length ||
            !_same(key.sublist(0, prefix.length), prefix) ||
            (keys.isNotEmpty && _compare(keys.last, key) >= 0)) {
          throw const FormatException('机构岗位分页键无效或重复');
        }
        keys.add(key);
      }
      if (page.length < 256) break;
      start = page.last;
    }
    final roles = <InstitutionRole>[];
    for (var offset = 0; offset < keys.length; offset += 100) {
      final slice = keys.sublist(offset, (offset + 100).clamp(0, keys.length));
      final values = await _batch(runtime.block, slice);
      if (values.length != slice.length) throw const FormatException('岗位批读不完整');
      for (var index = 0; index < values.length; index++) {
        final value = values[index];
        final role = value == null
            ? null
            : InstitutionRoleStorageCodec.decodeRole(value);
        if (role == null ||
            role.cidNumber != identity.cidNumber ||
            role.seats < 1 ||
            !_same(
              slice[index],
              runtime.storageKey(identity.pallet, 'InstitutionRoles', [
                cid,
                Uint8List.fromList(utf8.encode(role.roleCode)),
              ]),
            )) {
          throw const FormatException('岗位值与存储键不一致');
        }
        if (role.status == InstitutionRoleStatus.active) roles.add(role);
      }
    }
    final now = await _storage(
      runtime.block,
      runtime.storageKey('Timestamp', 'Now'),
    );
    if (now == null || now.length != 8) throw const FormatException('最终块时间无效');
    final day =
        CitizenScale.readUnsigned(now, 0, 8).toInt() ~/
        Duration.millisecondsPerDay;
    final assignments = <InstitutionAssignment>[];
    for (final role in roles) {
      final value = await _storage(
        runtime.block,
        runtime.storageKey(identity.pallet, 'InstitutionRoleAssignments', [
          cid,
          Uint8List.fromList(utf8.encode(role.roleCode)),
        ]),
      );
      if (value == null) continue;
      final decoded = InstitutionRoleStorageCodec.decodeAssignments(value);
      if (decoded == null || decoded.length > role.seats) {
        throw const FormatException('任职资料或席位数量无效');
      }
      for (final assignment in decoded) {
        if (assignment.cidNumber != identity.cidNumber ||
            assignment.roleCode != role.roleCode ||
            !InstitutionRoleStorageCodec.isPersonCid(
              assignment.personCid,
              private: identity.kind == 1,
            )) {
          throw const FormatException('任职人员类型或主体不一致');
        }
        final effective = assignment.withRole(role);
        if (effective.isEffectiveOnDay(day)) assignments.add(effective);
      }
    }
    return assignments;
  }

  Future<List<InstitutionPersonView>> fetchPersonViews(
    InstitutionIdentity identity, {
    CitizenRuntimeContext? at,
  }) async {
    final runtime = at ?? await finalizedRuntime();
    final groups = <String, List<InstitutionAssignment>>{};
    for (final assignment in await fetchAssignments(identity, at: runtime)) {
      groups.putIfAbsent(assignment.personCid, () => []).add(assignment);
    }
    final views = <InstitutionPersonView>[];
    for (final person in groups.entries) {
      views.add(
        InstitutionPersonView(
          personCid: person.key,
          accountId: await personAccount(person.key, runtime),
          assignments: List.unmodifiable(person.value),
        ),
      );
    }
    return views;
  }

  Future<Map<String, List<InstitutionAssignment>>> walletAssignments(
    InstitutionIdentity identity,
    Iterable<String> accounts, {
    CitizenRuntimeContext? at,
  }) async {
    final local = accounts.toSet();
    final runtime = at ?? await finalizedRuntime();
    return {
      for (final view in await fetchPersonViews(identity, at: runtime))
        if (view.accountId != null && local.contains(view.accountId))
          view.accountId!: view.assignments,
    };
  }

  Future<int?> fetchThreshold(InstitutionIdentity identity) async {
    final runtime = await finalizedRuntime();
    identity = await _resolveIdentity(identity, runtime);
    final data = await _storage(
      runtime.block,
      runtime.storageKey(identity.pallet, 'InstitutionGovernanceThresholds', [
        Uint8List.fromList(utf8.encode(identity.cidNumber)),
      ]),
    );
    if (data == null) return null;
    if (data.length != 4) throw const FormatException('机构治理阈值无效');
    return CitizenScale.readUnsigned(data, 0, 4).toInt();
  }

  Future<Map<String, String>> fetchRoleNames(
    InstitutionIdentity identity,
    Iterable<String> codes, {
    CitizenRuntimeContext? at,
  }) async {
    final unique = codes.toSet().toList();
    if (unique.isEmpty) return const {};
    final runtime = at ?? await finalizedRuntime();
    identity = await _resolveIdentity(identity, runtime);
    final names = <String, String>{};
    for (var start = 0; start < unique.length; start += 100) {
      final group = unique.sublist(start, min(start + 100, unique.length));
      final rows = await _batch(runtime.block, [
        for (final code in group)
          runtime.storageKey(identity.pallet, 'InstitutionRoles', [
            Uint8List.fromList(utf8.encode(identity.cidNumber)),
            Uint8List.fromList(utf8.encode(code)),
          ]),
      ]);
      if (rows.length != group.length) throw const FormatException('岗位名称批读不完整');
      for (var index = 0; index < group.length; index++) {
        final code = group[index], data = rows[index];
        if (data == null) continue;
        final role = InstitutionRoleStorageCodec.decodeRole(data);
        if (role == null ||
            role.cidNumber != identity.cidNumber ||
            role.roleCode != code) {
          throw const FormatException('岗位名称资料无效');
        }
        names[code] = role.roleName;
      }
    }
    return names;
  }

  /// 节点访问仍签原0x18载荷；任职资格来自当前链读，不写激活缓存。
  Future<Uint8List> buildRoleAccessPayload({
    required InstitutionIdentity identity,
    required String accountId,
  }) async {
    if (!(await walletAssignments(identity, [
      accountId,
    ])).containsKey(accountId)) {
      throw StateError('当前钱包没有有效人员任职');
    }
    identity = await _resolveIdentity(identity, await finalizedRuntime());
    final random = Random.secure();
    return CitizenSdk.encodePayload(
      CitizenSigningPayload.roleAccess(
        cidNumber: identity.cidNumber,
        institutionCode: Uint8List.fromList(
          InstitutionCodeLabel.codeBytes(identity.orgCode),
        ),
        kind: identity.kind!,
        signerPublicKey: citizenAccountIdBytes(accountId),
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        nonce: Uint8List.fromList(
          List.generate(kBinaryNonceLength, (_) => random.nextInt(256)),
        ),
      ),
    );
  }

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }

  // ──── 常量 ────

  /// ProposalData 中机构管理提案的 action 类型:ACTION_CLOSE=2(关闭机构多签)。
  static const actionClose = 2;

  /// 从 ProposalData 解码机构多签管理(关闭)提案,供提案列表/详情只读展示。
  ///
  /// ProposalData = `BoundedVec<u8>(Compact<len> + bytes)`;机构管理提案以 MODULE_TAG 前缀认领,
  /// 公权=`pub-mgmt`、私权=`pri-mgmt`(取代旧 `org-mgmt`),其后 ACTION_CLOSE(2):
  /// actor_cid_number + institution_account_id(32) + beneficiary(32) + proposer(32)。
  /// 个人提案解码归 `personal/chain.dart`，本服务只处理机构。
  static const _publicManageTag = [
    0x70, 0x75, 0x62, 0x2d, 0x6d, 0x67, 0x6d, 0x74, // "pub-mgmt"
  ];
  static const _privateManageTag = [
    0x70, 0x72, 0x69, 0x2d, 0x6d, 0x67, 0x6d, 0x74, // "pri-mgmt"
  ];

  Object? decodeManageProposalData(BigInt proposalId, Uint8List raw) {
    try {
      var offset = 0;

      // BoundedVec<u8> 外层：Compact<len> + bytes
      final (vecLen, lenBytes) = CitizenScale.readCompact(raw, offset);
      offset += lenBytes;
      if (offset + vecLen != raw.length) return null;
      final data = raw.sublist(offset, offset + vecLen);

      // 公权/私权机构管理提案各自 MODULE_TAG(8 字节)。
      const tagLen = 8;
      final tag =
          _startsWith(data, _publicManageTag) ||
          _startsWith(data, _privateManageTag);
      if (!tag) return null;
      final actionType = data[tagLen];
      final payload = data.sublist(tagLen + 1);
      if (actionType == actionClose) {
        return _decodeCloseAction(proposalId, payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  CloseProposalInfo? _decodeCloseAction(BigInt proposalId, Uint8List data) {
    var offset = 0;

    final (cidLen, cidLenBytes) = CitizenScale.readCompact(data, offset);
    offset += cidLenBytes;
    if (cidLen <= 0 || cidLen > 32 || offset + cidLen + 96 != data.length) {
      return null;
    }
    final actorCidNumber = utf8.decode(
      data.sublist(offset, offset + cidLen),
      allowMalformed: false,
    );
    offset += cidLen;

    final accountId = citizenAccountIdFromBytes(
      data.sublist(offset, offset + 32),
    ).substring(2);
    offset += 32;

    final beneficiaryBytes = data.sublist(offset, offset + 32);
    final beneficiarySs58 = citizenSs58FromAccountIdBytes(beneficiaryBytes);
    offset += 32;

    final proposerBytes = data.sublist(offset, offset + 32);
    final proposerSs58 = citizenSs58FromAccountIdBytes(proposerBytes);

    return CloseProposalInfo(
      proposalId: proposalId,
      actorCidNumber: actorCidNumber,
      institutionAccountId: accountId,
      beneficiary: beneficiarySs58,
      proposer: proposerSs58,
    );
  }

  // ──── 内部：解码工具 ────

  bool _startsWith(Uint8List data, List<int> prefix) {
    if (data.length < prefix.length + 1) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }
}
