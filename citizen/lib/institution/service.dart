// 机构链状态读取及仓库接口。

import 'package:citizen_sdk/citizen_sdk.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:citizen_citizen/institution/data.dart' show InstitutionProposalInfo;
import 'package:citizen_citizen/institution/codec.dart' show InstitutionProposalCodec;
import 'package:citizen_citizen/institution/data.dart' show InstitutionCodeLabel;
import 'package:citizen_citizen/institution/data.dart' show InstitutionAssignment, InstitutionIdentity, InstitutionPersonView, InstitutionRole, InstitutionRoleStatus, InstitutionRoster;
import 'package:citizen_citizen/institution/codec.dart' show InstitutionRoleStorageCodec;
import 'package:citizen_storage/user.dart' as app_store show Entity;
import 'package:citizen_citizen/institution/data.dart' show Institution;
import 'package:citizen_citizen/public/data.dart' show formatAreaPath;
import 'package:citizen_citizen/public/service.dart' show PublicInstitutionRepository;
import 'package:citizen_citizen/public/data.dart' show provinceFullNameByCode;
import 'package:citizen_citizen/institution/data.dart' show kFixedGovernanceInstitutions, kNrc, kPrcs, kProvincialBanks;
import 'package:citizen_citizen/institution/data.dart' show InstitutionInfo;

// 按最终块读取机构人员任职及当前身份绑定，解码机构管理提案。

/// 机构管理提案解码服务（公权/私权共用）。
///
/// 机构身份只能由 `cid_number` 表示；具体命名账户只是提案的
/// `institution_account_id` 参数，不反向作为机构主键。
///
/// 任职人员投票一律走 `InternalVote::cast`（经 InternalVoteService），不在本服务。
class InstitutionChainService {
  /// 现行关闭账户动作，仍供机构管理调用方使用。
  static const actionClose = 2;

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
  }) async => (await _readAssignments(identity, at: at)).assignments;

  Future<
    ({List<InstitutionRole> roles, List<InstitutionAssignment> assignments})
  >
  _readAssignments(
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
    return (roles: roles, assignments: assignments);
  }

  Future<List<InstitutionPersonView>> fetchPersonViews(
    InstitutionIdentity identity, {
    CitizenRuntimeContext? at,
  }) async => (await fetchRoster(identity, at: at)).persons;

  Future<InstitutionRoster> fetchRoster(
    InstitutionIdentity identity, {
    CitizenRuntimeContext? at,
  }) async {
    final runtime = at ?? await finalizedRuntime();
    final groups = <String, List<InstitutionAssignment>>{};
    final roster = await _readAssignments(identity, at: runtime);
    for (final assignment in roster.assignments) {
      groups.putIfAbsent(assignment.personCid, () => []).add(assignment);
    }
    final views = <InstitutionPersonView>[];
    for (final person in groups.entries) {
      final key = runtime.storageKey('Identity', 'CandidateIdentityByCid', [
        Uint8List.fromList(utf8.encode(person.key)),
      ]);
      final raw = await _storage(runtime.block, key);
      final profile = raw == null
          ? null
          : runtime.decodeStorage('Identity', 'CandidateIdentityByCid', raw);
      if (profile != null && profile is! Map<String, dynamic>) throw const FormatException('人员姓名资料无效');
      // SDK元数据解码保留BoundedVec的单字段包装，整数按十进制字符串交付。
      String name(String field) {
        dynamic value = (profile as Map<String, dynamic>?)?[field];
        if (value == null) return '';
        while (value is List && value.length == 1 && value.first is List) {
          value = value.first;
        }
        if (value is! List) throw const FormatException('人员姓名编码无效');
        final bytes = <int>[];
        for (final item in value) {
          final byte = item is String ? int.tryParse(item) : null;
          if (byte == null || byte < 0 || byte > 255) throw const FormatException('人员姓名字节无效');
          bytes.add(byte);
        }
        return utf8.decode(bytes);
      }

      views.add(
        InstitutionPersonView(
          personCid: person.key,
          familyName: name('family_name'),
          givenName: name('given_name'),
          accountId: await personAccount(person.key, runtime),
          assignments: List.unmodifiable(person.value),
        ),
      );
    }
    return InstitutionRoster(
      roles: List.unmodifiable(roster.roles),
      persons: List.unmodifiable(views),
    );
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

  /// 仅委托本包唯一的机构管理载荷解码器；未知或损坏内容不伪装为关闭。
  InstitutionProposalInfo? decodeManageProposalData(
    BigInt proposalId,
    Uint8List raw,
  ) => InstitutionProposalCodec.decode(proposalId, raw);
}

// 从本地最终链目录构造统一机构，并附加创世固定账户。

// 统一机构仓库门面(ADR-028 决策 2)——finalized 链快照 + Isar 产出统一 [Institution];
// 为创世治理机构附 china 固定账户。
//
//
// - 包装现有 [PublicInstitutionRepository](已是本地优先秒开的目录仓库),逐步替代
//   公权/治理两套并行数据源。
// - 静态表只保留「创世固定账户来源」一职:china 固定账户 hex 不可派生,
//   必须附到对应机构上;列表仍由目录决定。
// - 订阅、行政区所属地 join 等读路径直接复用底层 [directory],不另造。

class InstitutionRepository {
  InstitutionRepository({PublicInstitutionRepository? directory})
    : directory = directory ?? PublicInstitutionRepository();

  /// 底层目录仓库(订阅 / 行政区所属地 join / 后台同步 直接复用)。
  final PublicInstitutionRepository directory;

  /// 创世治理机构按 cid_number 索引的静态账户项(构建一次)。
  /// 用途:① 取 china 固定账户附到统一机构上;② 发起提案/管理员页需要 `InstitutionInfo`。
  static final Map<String, InstitutionInfo> _governanceInfo = {
    for (final i in <InstitutionInfo>[
      ...kNrc,
      ...kPrcs,
      ...kProvincialBanks,
      ...kFixedGovernanceInstitutions,
    ])
      i.cidNumber: i,
  };

  /// 固定治理机构的静态账户项;非固定治理机构返回 null。
  InstitutionInfo? governanceInfo(String cidNumber) =>
      _governanceInfo[cidNumber];

  /// 按 CID 号取统一机构(目录身份 + 固定治理档附 china 账户)。
  /// 目录未命中时,治理机构回退静态注册表,保证治理 tab 不丢机构(行为保持)。
  Future<Institution?> getByCid(String cidNumber) async {
    final entity = await directory.getByCid(cidNumber);
    if (entity != null) return _toInstitution(entity);
    final gov = _governanceInfo[cidNumber];
    if (gov != null) return Institution.fromGovernanceInfo(gov);
    return null;
  }

  /// 某市机构列表(统一 Institution)。
  Future<List<Institution>> listInstitutionsByCity(
    String provinceCode,
    String cityCode,
  ) async {
    final rows = await directory.listInstitutionsByCity(provinceCode, cityCode);
    return rows.map(_toInstitution).toList(growable: false);
  }

  /// 按机构码集合取统一机构列表(治理/立法 tab 视图过滤入口,ADR-028 P2)。
  Future<List<Institution>> listByCodes(Set<String> institutionCodes) async {
    final rows = await directory.listByInstitutionCodes(institutionCodes);
    return rows.map(_toInstitution).toList(growable: false);
  }

  /// 某省内按机构码集合取统一机构列表(立法 tab 省导航,ADR-028 P3)。
  Future<List<Institution>> listByProvinceAndCodes(
    String provinceCode,
    Set<String> institutionCodes,
  ) async {
    final rows = await directory.listByProvinceAndCodes(
      provinceCode,
      institutionCodes,
    );
    return rows.map(_toInstitution).toList(growable: false);
  }

  /// 某公民 CID 关注的机构列表（统一 Institution）。
  Future<List<Institution>> listSubscribed(String cidNumber) async {
    final rows = await directory.listSubscribed(cidNumber);
    return rows.map(_toInstitution).toList(growable: false);
  }

  // ── 订阅(关注)passthrough ──
  Future<bool> isSubscribed(String cidNumber, String peerCid) =>
      directory.isSubscribed(cidNumber, peerCid);
  Future<void> subscribe(String cidNumber, String peerCid) =>
      directory.subscribe(cidNumber, peerCid);
  Future<void> unsubscribe(String cidNumber, String peerCid) =>
      directory.unsubscribe(cidNumber, peerCid);

  /// 机构所属地显示路径(详情页 所属地行;省名带"省"全名 + 字典市/镇名,ADR-021)。
  Future<String> institutionAreaPath(Institution inst) {
    return formatAreaPath(
      directory.divisionStore,
      provinceName: provinceFullNameByCode(inst.provinceCode),
      provinceCode: inst.provinceCode,
      cityCode: inst.cityCode,
      townCode: inst.townCode,
    );
  }

  Institution _toInstitution(app_store.Entity e) {
    final inst = Institution.fromPublicEntity(e);
    if (inst.isFixedGovernance) {
      final baked = _governanceInfo[inst.cidNumber]?.accounts;
      if (baked != null) return inst.withBuiltinAccounts(baked);
    }
    return inst;
  }
}
