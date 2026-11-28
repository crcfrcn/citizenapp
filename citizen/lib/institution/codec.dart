// 机构提案及角色存储编解码。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/data.dart' show CloseProposalInfo, InstitutionChangeInfo, InstitutionDetailRow, InstitutionProposalInfo;
import 'package:citizen_citizen/institution/data.dart' show InstitutionCodeLabel;
import 'package:citizen_citizen/institution/data.dart' show AuthorizationSubject, BusinessActionId, InstitutionAssignment, InstitutionAssignmentSource, InstitutionRole, InstitutionRoleStatus, RoleBusinessPermission, RolePermissionOperation, RoleSubject, VotePlan, VotingEngineKind;

// 严格解码机构管理冻结载荷；底层SCALE读取复用SDK，不从当前任职倒推提案内容。

class InstitutionProposalCodec {
  InstitutionProposalCodec._();

  static InstitutionProposalInfo? decode(BigInt id, Uint8List raw) {
    try {
      final outer = _Reader(raw);
      final length = outer.count(102400);
      final data = outer.take(length);
      outer.finish();
      final read = _Reader(data);
      final tag = utf8.decode(read.take(8));
      if (tag != 'pub-mgmt' && tag != 'pri-mgmt') {
        throw const FormatException('机构管理域无效');
      }
      final action = read.byte();
      if (action == 2) {
        final cid = read.text(32);
        final account = citizenAccountIdFromBytes(read.take(32)).substring(2);
        final beneficiary = citizenSs58FromAccountIdBytes(read.take(32));
        final proposer = citizenSs58FromAccountIdBytes(read.take(32));
        read.finish();
        return CloseProposalInfo(
          proposalId: id,
          actorCidNumber: cid,
          institutionAccountId: account,
          beneficiary: beneficiary,
          proposer: proposer,
        );
      }
      final rows = <InstitutionDetailRow>[];
      String cid;
      if (action == 3 || action == 5) {
        final codeBytes = read.take(4);
        final code = InstitutionCodeLabel.codeToString(codeBytes);
        cid = read.text(32);
        final parts = cid.split('-');
        final canonical = InstitutionCodeLabel.codeBytes(code);
        if (code.isEmpty ||
            !List.generate(
              4,
              (i) => canonical[i] == codeBytes[i],
            ).every((v) => v) ||
            parts.length != 4 ||
            parts[1].length != 5 ||
            parts[1].substring(0, 4) != code.padRight(4, '0')) {
          throw const FormatException('机构码与CID不一致');
        }
        if (action == 3) {
          _governance(read, rows, tag == 'pub-mgmt');
        } else {
          final changes = read.count(64);
          final roles = <String>{};
          for (var i = 0; i < changes; i++) {
            final role = read.text(64);
            if (!role.startsWith('R_') || !roles.add(role)) {
              throw const FormatException('政策岗位无效或重复');
            }
            rows.add(InstitutionDetailRow('完整替换原生权限', role));
            _permissions(read, rows);
          }
          final threshold = read.option();
          if (!threshold && changes == 0) throw const FormatException('政策为空');
          if (threshold) {
            final value = read.u32();
            if (value < 2) throw const FormatException('共同阈值无效');
            rows.add(
              InstitutionDetailRow('目标共同阈值', '$value（由原阈值批准，执行后影响后续提案）'),
            );
          } else {
            rows.add(const InstitutionDetailRow('共同阈值', '保持不变'));
          }
          rows.add(
            InstitutionDetailRow(
              '期望机构状态指纹',
              _hex(read.take(32)),
              copyable: true,
            ),
          );
        }
      } else if (action == 4) {
        cid = read.text(32);
        final count = read.count(1989);
        if (count == 0) throw const FormatException('账户集合为空');
        final names = <String>{}, accounts = <String>{};
        for (var i = 0; i < count; i++) {
          final name = read.text(128),
              bytes = read.take(32),
              account = _hex(bytes);
          if (!names.add(name) || !accounts.add(account)) {
            throw const FormatException('账户重复');
          }
          rows.add(
            InstitutionDetailRow(
              '新增账户：$name',
              citizenSs58FromAccountIdBytes(bytes),
              copyable: true,
            ),
          );
        }
        rows.add(
          InstitutionDetailRow(
            '发起账户',
            citizenSs58FromAccountIdBytes(read.take(32)),
            copyable: true,
          ),
        );
      } else {
        throw const FormatException('未知机构管理动作');
      }
      read.finish();
      return InstitutionChangeInfo(
        proposalId: id,
        actorCidNumber: cid,
        action: action,
        rows: rows,
      );
    } on Object {
      return null;
    }
  }

  static void _governance(
    _Reader read,
    List<InstitutionDetailRow> rows,
    bool public,
  ) {
    final mutations = read.count(1989), seen = <String>{};
    for (var i = 0; i < mutations; i++) {
      final kind = read.byte();
      if (kind == 0) {
        final name = read.text(128), term = read.boolean(), seats = read.u32();
        if (seats == 0 || seats > 1989) throw const FormatException('席位无效');
        rows.add(
          InstitutionDetailRow(
            '创建岗位',
            '$name；席位$seats；${term ? '要求任期' : '无任期'}；岗位码由执行时生成',
          ),
        );
        _permissions(read, rows);
        final count = _assignments(read, rows, public, term: term);
        if (count > seats) throw const FormatException('任职超过席位');
      } else if ([1, 2, 3].contains(kind)) {
        final code = read.text(64);
        if (!seen.add(code)) throw const FormatException('岗位操作重复');
        if (kind == 1) {
          rows.add(InstitutionDetailRow('岗位改名：$code', read.text(128)));
        } else if (kind == 2) {
          rows.add(InstitutionDetailRow('删除岗位', '$code；同时删除当前权限及任职，岗位码不复用'));
        } else {
          final term = read.boolean(), seats = read.u32(), status = read.byte();
          if (!code.startsWith('R_') ||
              seats == 0 ||
              seats > 1989 ||
              status > 1) {
            throw const FormatException('岗位属性无效');
          }
          rows.add(
            InstitutionDetailRow(
              '配置岗位：$code',
              '席位$seats；${term ? '要求任期' : '无任期'}；${status == 0 ? '启用' : '停用'}',
            ),
          );
        }
      } else {
        throw const FormatException('未知岗位操作');
      }
    }
    final changes = read.count(1989), roles = <String>{};
    for (var i = 0; i < changes; i++) {
      final code = read.text(64);
      if (!roles.add(code)) throw const FormatException('任职集合重复');
      rows.add(InstitutionDetailRow('完整替换岗位任职', code));
      final count = _assignments(read, rows, public);
      if (count == 0) rows.add(const InstitutionDetailRow('目标任职', '清空'));
    }
    final representative = read.option();
    if (representative) {
      final kind = read.byte();
      if (kind == 0) {
        final family = read.text(128),
            given = read.text(128),
            person = _person(read, public);
        rows.add(InstitutionDetailRow('任命法定代表人', '$family$given；$person'));
      } else if (kind == 1) {
        rows.add(const InstitutionDetailRow('法定代表人', '解除'));
      } else {
        throw const FormatException('法代操作无效');
      }
    }
    if (mutations == 0 && changes == 0 && !representative) {
      throw const FormatException('治理内容为空');
    }
  }

  static void _permissions(_Reader read, List<InstitutionDetailRow> rows) {
    final count = read.count(256), seen = <String>{};
    if (count == 0) throw const FormatException('链上岗位权限为空');
    for (var i = 0; i < count; i++) {
      final module = read.text(32),
          action = read.u32(),
          operation = read.byte();
      if (operation > 1 || !seen.add('$module:$action:$operation')) {
        throw const FormatException('权限无效或重复');
      }
      rows.add(
        InstitutionDetailRow(
          '原生权限',
          '$module / $action / ${operation == 0 ? '发起' : '表决'}',
        ),
      );
    }
  }

  static int _assignments(
    _Reader read,
    List<InstitutionDetailRow> rows,
    bool public, {
    bool? term,
  }) {
    final count = read.count(1989), seen = <String>{};
    for (var i = 0; i < count; i++) {
      final person = _person(read, public),
          start = read.u32(),
          end = read.u32(),
          source = read.byte();
      final reference = read.bytes(128), status = read.byte();
      if (!seen.add(person) ||
          source > 5 ||
          status > 1 ||
          !((start == 0 && end == 0) || (start > 0 && end >= start)) ||
          (term == true && start == 0) ||
          (term == false && start != 0)) {
        throw const FormatException('任职数据无效');
      }
      const origins = ['创世', '注册局', '普选', '互选', '提名任免', '机构治理'];
      rows.add(
        InstitutionDetailRow(
          '任职人员',
          '$person；日序$start—$end；${origins[source]}；${status == 0 ? '有效' : '停用'}；来源引用${reference.isEmpty ? '由本次业务生成' : _hex(reference)}',
        ),
      );
    }
    return count;
  }

  static String _person(_Reader read, bool public) {
    final person = read.text(32);
    if (!InstitutionRoleStorageCodec.isPersonCid(person) ||
        (public && !person.split('-')[1].startsWith('CTZN'))) {
      throw const FormatException('人员CID无效');
    }
    return person;
  }

  static String _hex(List<int> data) =>
      '0x${data.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
}

/// 仅集中业务边界和游标检查，整数及compact编码由SDK唯一实现读取。
class _Reader {
  _Reader(this.data);
  final Uint8List data;
  int offset = 0;
  Uint8List take(int length) {
    if (length < 0 || offset + length > data.length) {
      throw const FormatException('载荷截断');
    }
    final value = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    return value;
  }

  int byte() => take(1)[0];
  int u32() => CitizenScale.readUnsigned(take(4), 0, 4).toInt();
  bool boolean() {
    final value = byte();
    if (value > 1) throw const FormatException('bool无效');
    return value == 1;
  }

  bool option() => boolean();
  int count(int maximum) {
    final (value, size) = CitizenScale.readCompact(data, offset);
    if (size <= 0 || value < 0 || value > maximum) {
      throw const FormatException('集合长度无效');
    }
    offset += size;
    return value;
  }

  Uint8List bytes(int maximum) => take(count(maximum));
  String text(int maximum) {
    final value = utf8.decode(bytes(maximum));
    if (value.isEmpty) throw const FormatException('文本为空');
    return value;
  }

  void finish() {
    if (offset != data.length) throw const FormatException('载荷有尾随字节');
  }
}

// 严格解码机构岗位、人员CID任职及投票计划的SCALE布局。

/// 机构岗位和人员任职的严格SCALE解码器。
class InstitutionRoleStorageCodec {
  InstitutionRoleStorageCodec._();

  static InstitutionRole? decodeRole(Uint8List data) {
    try {
      var offset = 0;
      final cid = _readBytes(data, offset, minLength: 1, maxLength: 32);
      if (cid == null) return null;
      offset = cid.$2;
      final code = _readBytes(data, offset, minLength: 1, maxLength: 64);
      if (code == null) return null;
      offset = code.$2;
      final name = _readBytes(data, offset, minLength: 1, maxLength: 128);
      if (name == null) return null;
      offset = name.$2;
      if (offset + 6 != data.length ||
          data[offset] > 1 ||
          data[offset + 1] > 1 ||
          CitizenScale.readUnsigned(data, offset + 2, 4) == BigInt.zero) {
        return null;
      }
      return InstitutionRole(
        cidNumber: utf8.decode(cid.$1),
        roleCode: utf8.decode(code.$1),
        roleName: utf8.decode(name.$1),
        termRequired: data[offset] == 1,
        status: InstitutionRoleStatus.values[data[offset + 1]],
        seats: CitizenScale.readUnsigned(data, offset + 2, 4).toInt(),
      );
    } on FormatException {
      return null;
    }
  }

  static List<InstitutionAssignment>? decodeAssignments(Uint8List data) {
    var offset = 0;
    final count = _readCompact(data, offset);
    if (count == null) return null;
    offset += count.$2;
    final out = <InstitutionAssignment>[];
    final seats = <String>{};
    for (var i = 0; i < count.$1; i++) {
      final cid = _readBytes(data, offset, minLength: 1, maxLength: 32);
      if (cid == null) return null;
      offset = cid.$2;
      final person = _readUtf8(data, offset, minLength: 1, maxLength: 32);
      if (person == null || !isPersonCid(person.$1)) return null;
      offset = person.$2;
      final code = _readBytes(data, offset, minLength: 1, maxLength: 64);
      if (code == null) return null;
      offset = code.$2;
      if (offset + 9 > data.length) return null;
      final termStart = CitizenScale.readUnsigned(data, offset, 4).toInt();
      offset += 4;
      final termEnd = CitizenScale.readUnsigned(data, offset, 4).toInt();
      offset += 4;
      final source = data[offset++];
      final sourceRef = _readBytes(data, offset, maxLength: 128);
      if (sourceRef == null) return null;
      offset = sourceRef.$2;
      if (offset >= data.length ||
          source >= InstitutionAssignmentSource.values.length) {
        return null;
      }
      final status = data[offset++];
      if (status > 1) return null;
      try {
        if (!seats.add(
          '${utf8.decode(cid.$1)}:${utf8.decode(code.$1)}:${person.$1}',
        )) {
          return null;
        }
        out.add(
          InstitutionAssignment(
            cidNumber: utf8.decode(cid.$1),
            personCid: person.$1,
            roleCode: utf8.decode(code.$1),
            termStart: termStart,
            termEnd: termEnd,
            source: InstitutionAssignmentSource.values[source],
            sourceRef: _displaySourceRef(sourceRef.$1),
            active: status == 0,
          ),
        );
      } on FormatException {
        return null;
      }
    }
    return offset == data.length ? out : null;
  }

  /// 公权只允许CTZN；私权还允许NATP，机构码必须取完整CID中的四位类型。
  static bool isPersonCid(String cid, {bool private = true}) {
    final parts = cid.split('-');
    if (parts.length != 4 ||
        !RegExp(r'^[A-Z]{2}[0-9]{3}$').hasMatch(parts[0]) ||
        !RegExp(r'^[0-9]{9}$').hasMatch(parts[2]) ||
        !RegExp(r'^[0-9]{4}$').hasMatch(parts[3]) ||
        !RegExp(r'^(CTZN|NATP)[0-9A-Z]$').hasMatch(parts[1])) {
      return false;
    }
    return parts[1].startsWith('CTZN') ||
        (private && parts[1].startsWith('NATP'));
  }

  /// 冻结选民按人员CID解码，同一岗位重复人员和尾随字节均拒绝。
  static List<String>? decodePersons(Uint8List data) {
    final count = _readCompact(data, 0);
    if (count == null || count.$1 > data.length) return null;
    var offset = count.$2;
    final persons = <String>[];
    for (var i = 0; i < count.$1; i++) {
      final person = _readUtf8(data, offset, minLength: 1, maxLength: 32);
      if (person == null ||
          !isPersonCid(person.$1) ||
          persons.contains(person.$1)) {
        return null;
      }
      offset = person.$2;
      persons.add(person.$1);
    }
    return offset == data.length ? persons : null;
  }

  /// 来源引用是业务字节：可读文本原样显示，其余与 Node 一样展示完整十六进制。
  /// 仅此字段允许二进制；CID、岗位码及其余 SCALE 边界仍严格解码。
  static String _displaySourceRef(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      if (!RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(text)) return text;
    } on FormatException {
      // 合法来源引用可以是提案编号等二进制数据，不属于结构解码错误。
    }
    return '0x${_hex(bytes)}';
  }

  /// 严格解码完整机构岗位授权主体。
  static RoleSubject? decodeRoleSubject(Uint8List data) {
    final decoded = _decodeRoleSubjectAt(data, 0);
    return decoded != null && decoded.$2 == data.length ? decoded.$1 : null;
  }

  /// 严格解码业务动作标识。
  static BusinessActionId? decodeBusinessActionId(Uint8List data) {
    final decoded = _decodeBusinessActionIdAt(data, 0);
    return decoded != null && decoded.$2 == data.length ? decoded.$1 : null;
  }

  /// 严格解码岗位业务权限。
  static RoleBusinessPermission? decodeRoleBusinessPermission(Uint8List data) {
    final decoded = _decodeRoleBusinessPermissionAt(data, 0);
    return decoded != null && decoded.$2 == data.length ? decoded.$1 : null;
  }

  /// 严格解码 `InstitutionRolePermissions[(cid, role_code)]` 的完整向量值。
  static List<RoleBusinessPermission>? decodeRolePermissions(Uint8List data) {
    final count = _readCompact(data, 0);
    if (count == null || count.$1 > 256) return null;
    var offset = count.$2;
    final permissions = <RoleBusinessPermission>[];
    final seen = <String>{};
    for (var index = 0; index < count.$1; index++) {
      final permission = _decodeRoleBusinessPermissionAt(data, offset);
      if (permission == null) return null;
      offset = permission.$2;
      final item = permission.$1;
      final key =
          '${item.roleSubject.cidNumber}:${item.roleSubject.roleCode}:'
          '${item.businessActionId.moduleTag}:${item.businessActionId.actionCode}:'
          '${item.operation.index}';
      if (!seen.add(key)) return null;
      permissions.add(item);
    }
    return offset == data.length ? List.unmodifiable(permissions) : null;
  }

  static (RoleBusinessPermission, int)? _decodeRoleBusinessPermissionAt(
    Uint8List data,
    int offset,
  ) {
    final role = _decodeRoleSubjectAt(data, offset);
    if (role == null) return null;
    final action = _decodeBusinessActionIdAt(data, role.$2);
    if (action == null || action.$2 >= data.length) return null;
    final operation = data[action.$2];
    if (operation >= RolePermissionOperation.values.length) return null;
    return (
      RoleBusinessPermission(
        roleSubject: role.$1,
        businessActionId: action.$1,
        operation: RolePermissionOperation.values[operation],
      ),
      action.$2 + 1,
    );
  }

  /// 严格解码机构岗位或个人多签授权主体。
  static AuthorizationSubject? decodeAuthorizationSubject(Uint8List data) {
    final decoded = _decodeAuthorizationSubjectAt(data, 0);
    return decoded != null && decoded.$2 == data.length ? decoded.$1 : null;
  }

  /// 严格解码业务模块绑定的投票计划。
  static VotePlan? decodeVotePlan(Uint8List data) {
    final action = _decodeBusinessActionIdAt(data, 0);
    if (action == null) return null;
    final accountId = _readUtf8(data, action.$2, minLength: 1, maxLength: 32);
    if (accountId == null || accountId.$1 != action.$1.moduleTag) return null;
    final proposer = _decodeAuthorizationSubjectAt(data, accountId.$2);
    if (proposer == null) return null;
    final count = _readCompact(data, proposer.$2);
    if (count == null || count.$1 < 1 || count.$1 > 256) return null;
    var offset = proposer.$2 + count.$2;
    final voters = <AuthorizationSubject>[];
    final voterKeys = <String>{};
    for (var index = 0; index < count.$1; index++) {
      final voter = _decodeAuthorizationSubjectAt(data, offset);
      if (voter == null) return null;
      offset = voter.$2;
      final key = voter.$1.isInstitution
          ? 'i:${voter.$1.roleSubject!.cidNumber}:${voter.$1.roleSubject!.roleCode}'
          : 'p:${voter.$1.accountId}';
      if (!voterKeys.add(key)) return null;
      voters.add(voter.$1);
    }
    if (offset >= data.length) return null;
    final engine = data[offset++];
    if (engine >= VotingEngineKind.values.length ||
        offset + 32 != data.length) {
      return null;
    }
    if (proposer.$1.isInstitution) {
      if (voters.any((voter) => !voter.isInstitution)) return null;
    } else {
      if (voters.length != 1 ||
          voters.single.isInstitution ||
          voters.single.accountId != proposer.$1.accountId) {
        return null;
      }
    }
    return VotePlan(
      businessActionId: action.$1,
      proposalOwner: accountId.$1,
      proposerSubject: proposer.$1,
      voterSubjects: List.unmodifiable(voters),
      votingEngine: VotingEngineKind.values[engine],
      businessObjectHash: _hex(data.sublist(offset, offset + 32)),
    );
  }

  static (RoleSubject, int)? _decodeRoleSubjectAt(Uint8List data, int offset) {
    final cid = _readUtf8(data, offset, minLength: 1, maxLength: 32);
    if (cid == null) return null;
    final roleCode = _readUtf8(data, cid.$2, minLength: 1, maxLength: 64);
    if (roleCode == null) return null;
    return (RoleSubject(cidNumber: cid.$1, roleCode: roleCode.$1), roleCode.$2);
  }

  static (BusinessActionId, int)? _decodeBusinessActionIdAt(
    Uint8List data,
    int offset,
  ) {
    final moduleTag = _readUtf8(data, offset, minLength: 1, maxLength: 32);
    if (moduleTag == null || moduleTag.$2 + 4 > data.length) return null;
    final actionCode = CitizenScale.readUnsigned(data, moduleTag.$2, 4).toInt();
    return (
      BusinessActionId(moduleTag: moduleTag.$1, actionCode: actionCode),
      moduleTag.$2 + 4,
    );
  }

  static (AuthorizationSubject, int)? _decodeAuthorizationSubjectAt(
    Uint8List data,
    int offset,
  ) {
    if (offset >= data.length) return null;
    final kind = data[offset++];
    if (kind == 0) {
      final role = _decodeRoleSubjectAt(data, offset);
      return role == null
          ? null
          : (AuthorizationSubject.institution(role.$1), role.$2);
    }
    if (kind == 1 && offset + 32 <= data.length) {
      return (
        AuthorizationSubject.personalMultisig(
          _hex(data.sublist(offset, offset + 32)),
        ),
        offset + 32,
      );
    }
    return null;
  }

  static (String, int)? _readUtf8(
    Uint8List data,
    int offset, {
    required int minLength,
    required int maxLength,
  }) {
    final value = _readBytes(
      data,
      offset,
      minLength: minLength,
      maxLength: maxLength,
    );
    if (value == null) return null;
    try {
      return (utf8.decode(value.$1), value.$2);
    } on FormatException {
      return null;
    }
  }

  static (Uint8List, int)? _readBytes(
    Uint8List data,
    int offset, {
    int minLength = 0,
    required int maxLength,
  }) {
    final compact = _readCompact(data, offset);
    if (compact == null) return null;
    if (compact.$1 < minLength || compact.$1 > maxLength) return null;
    final start = offset + compact.$2;
    final end = start + compact.$1;
    if (end > data.length) return null;
    return (Uint8List.sublistView(data, start, end), end);
  }

  static (int, int)? _readCompact(Uint8List data, int offset) {
    try {
      final decoded = CitizenScale.readCompact(data, offset);
      return decoded.$2 <= 4 ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
