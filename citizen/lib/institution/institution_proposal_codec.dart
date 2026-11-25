// 严格解码机构管理冻结载荷；底层SCALE读取复用SDK，不从当前任职倒推提案内容。

import 'dart:convert';
import 'dart:typed_data';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:citizen_citizen/institution/institution_models.dart';
import 'package:citizen_citizen/institution/institution_code_label.dart';
import 'package:citizen_citizen/institution/institution_role_storage_codec.dart';

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
