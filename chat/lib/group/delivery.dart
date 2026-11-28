// 编码群控制消息，保留顺序缓冲与成员投递扇出。

import 'dart:convert';

import 'package:chat/message/content.dart';
import 'package:chat/mls/protocol.dart';
import 'package:citizen_network/message.dart';

// 严格编解码经现有端到端通道传输的群控制消息。

// 群控制消息(走既有 E2E application 通道,不改 proto、不进 ChatMessageKind)。
//
// 用户载荷以 `kind` 为唯一判别字段，控制载荷以 `op` 为唯一判别字段；
// 两者都没有额外 type/version 别名。出现 `op` 后必须精确匹配目标结构，
// 坏数据或未知操作失败关闭，绝不伪装成普通消息。

/// 群控制操作。
enum GroupControlOp {
  /// 创建者/管理员广播群名(补 Welcome 不带名的缺口)。
  rename('rename'),

  /// 退群者请求群 admin 代提交移除(密码学后向保密由 admin 的 removeMembers 保证)。
  leaveRequest('leave_request');

  const GroupControlOp(this.wireName);

  final String wireName;

  static GroupControlOp? fromWireName(String value) {
    for (final op in values) {
      if (op.wireName == value) {
        return op;
      }
    }
    return null;
  }
}

/// 群控制消息。
class GroupControl {
  const GroupControl._(this.op, this.groupName);

  factory GroupControl.rename(String name) =>
      GroupControl._(GroupControlOp.rename, name);

  const GroupControl.leaveRequest() : this._(GroupControlOp.leaveRequest, null);

  final GroupControlOp op;

  /// op=rename 携带的群名。
  final String? groupName;
}

class GroupControlCodec {
  GroupControlCodec._();

  static String encode(GroupControl control) {
    final map = <String, Object?>{'op': control.op.wireName};
    if (control.op == GroupControlOp.rename) {
      map['name'] = control.groupName ?? '';
    }
    final encoded = jsonEncode(map);
    tryDecode(encoded);
    return encoded;
  }

  /// 用户消息（无 `op`）返回 null 交给 [ChatPayloadCodec]；一旦存在
  /// `op`，未知操作、多字段、缺字段和类型错误都抛 [FormatException]。
  static GroupControl? tryDecode(String raw) {
    // 公民聊天 第一类消息是 protobuf 的规范 base64url；只有 JSON 对象前缀才可能
    // 是群控制或媒体载荷，避免控制解码器抢先拒绝合法 basic 消息。
    if (!raw.startsWith('{')) return null;
    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('群消息载荷必须是完整 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('群消息载荷必须是 JSON 对象');
    }
    if (!decoded.containsKey('op')) return null;
    final opRaw = decoded['op'];
    if (opRaw is! String) {
      throw const FormatException('群控制 op 必须是字符串');
    }
    final op = GroupControlOp.fromWireName(opRaw);
    if (op == null) {
      throw FormatException('未知群控制 op：$opRaw');
    }
    return switch (op) {
      GroupControlOp.rename => _decodeRename(decoded),
      GroupControlOp.leaveRequest => _decodeLeaveRequest(decoded),
    };
  }

  static GroupControl _decodeRename(Map<String, dynamic> map) {
    _requireExactFieldSet(map, const <String>{'op', 'name'});
    final name = map['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('群改名 name 必须是非空字符串');
    }
    return GroupControl.rename(name);
  }

  static GroupControl _decodeLeaveRequest(Map<String, dynamic> map) {
    _requireExactFieldSet(map, const <String>{'op'});
    return const GroupControl.leaveRequest();
  }

  // 严格要求群控制载荷字段集合完全一致，拒绝缺失字段和未声明字段。
  static void _requireExactFieldSet(
    Map<String, dynamic> map,
    Set<String> expected,
  ) {
    if (map.length != expected.length ||
        !map.keys.toSet().containsAll(expected)) {
      throw const FormatException('群控制载荷字段集不匹配');
    }
  }
}

// 按MLS epoch缓冲和回放乱序Commit，维持群解密顺序。

// epoch 有序处理:乱序 Commit 缓冲 + 回放(纯逻辑,注入 process/buffer seam,可测)。
//
// MLS 群解密链要求 Commit 按 epoch 顺序应用;零存储瞬时中转不保证到达序。
// 规则(Rust `group_process` 已给出 status 判定):
//   applied    + welcome/commit → 成功应用,epoch 前进;回放缓冲中"下一个 epoch"的项
//   out_of_order        → 该消息 epoch > 当前 epoch,缓冲待补
//   stale               → epoch 已过(密钥已 ratchet),丢弃
// epoch 状态机由本模块测试固定。

/// 处理一条 wire,返回 [GroupInbound]。
typedef GroupProcessSeam = Future<GroupInbound> Function(MlsWireMessage wire);

/// 缓冲一条乱序 message(键:groupId + messageEpoch)。
typedef GroupBufferPut = Future<void> Function(
  String groupId,
  int messageEpoch,
  EncryptedMessage message,
);

/// 读取某 (groupId, messageEpoch) 下本轮尚未处理的最早密文。
typedef GroupBufferTake = Future<EncryptedMessage?> Function(
  String groupId,
  int messageEpoch,
);

/// 从 message 还原 wire(用于回放)。
typedef WireFromMessage = MlsWireMessage Function(EncryptedMessage message);

/// 每条 message 完成 epoch 判定后的串行回调；调用方只对 applied 内容落库，
/// 并可把 applied/stale 记录为已处理以回复内部设备确认。
typedef GroupProcessedCallback = Future<void> Function(
  EncryptedMessage message,
  GroupInbound result,
);

class GroupEpochOrdering {
  const GroupEpochOrdering._();

  /// 有序处理一条入站 message:
  /// - out_of_order → 缓冲,返回该结果(调用方据此提示"等待前序")
  /// - applied 且是 Commit → 应用后回放缓冲(填补 epoch 缺口)
  /// - 其余 → 直接返回
  static Future<GroupInbound> processOrdered({
    required MlsWireMessage wire,
    required EncryptedMessage message,
    required GroupProcessSeam process,
    required GroupBufferPut bufferPut,
    required GroupBufferTake bufferTake,
    required WireFromMessage wireFromMessage,
    GroupProcessedCallback? onProcessed,
  }) async {
    final result = await process(wire);
    if (result.status == GroupProcessStatus.outOfOrder) {
      await bufferPut(result.groupId, result.messageEpoch, message);
      await onProcessed?.call(message, result);
      return result;
    }
    await onProcessed?.call(message, result);
    if (result.isApplied &&
        !result.selfRemoved &&
        (result.kind == GroupInboundKind.welcome ||
            result.kind == GroupInboundKind.commit)) {
      await _drain(
        groupId: result.groupId,
        fromEpoch: result.groupEpoch,
        process: process,
        bufferPut: bufferPut,
        bufferTake: bufferTake,
        wireFromMessage: wireFromMessage,
        onProcessed: onProcessed,
      );
    }
    return result;
  }

  /// 回放缓冲:从 [fromEpoch] 起,取该 epoch 下缓冲项依次重放。
  /// application 应用后 epoch 不变(继续取同 epoch);Commit 应用后 epoch+1
  /// (移到下一 epoch 继续)。调用方在处理成功后确认原缓冲。
  static Future<void> _drain({
    required String groupId,
    required int fromEpoch,
    required GroupProcessSeam process,
    required GroupBufferPut bufferPut,
    required GroupBufferTake bufferTake,
    required WireFromMessage wireFromMessage,
    GroupProcessedCallback? onProcessed,
  }) async {
    var current = fromEpoch;
    while (true) {
      final buffered = await bufferTake(groupId, current);
      if (buffered == null) {
        break;
      }
      final GroupInbound result;
      try {
        result = await process(wireFromMessage(buffered));
      } catch (_) {
        // 失败密文仍由原队列保留，同 epoch 的其他密文可以继续。
        continue;
      }
      switch (result.status) {
        case GroupProcessStatus.applied:
          await onProcessed?.call(buffered, result);
          // Commit 前进 epoch;application 不变。
          current = result.groupEpoch;
        case GroupProcessStatus.outOfOrder:
          // 理论上不会发生(取的就是当前 epoch);稳妥起见放回并停止,避免丢失。
          await bufferPut(result.groupId, result.messageEpoch, buffered);
          await onProcessed?.call(buffered, result);
          return;
        case GroupProcessStatus.stale:
          await onProcessed?.call(buffered, result);
          continue;
        case GroupProcessStatus.unknown:
          // 丢弃,继续取同 epoch 下一条。
          await onProcessed?.call(buffered, result);
          break;
      }
    }
  }
}

// 将同一群OpenMLS密文分配为每成员独立投递路由。

/// 一份群 OpenMLS 密文按成员生成独立路由消息，密文绝不重复加密。
final class GroupMessageFanout {
  GroupMessageFanout._();

  static List<EncryptedMessage> fanOut({
    required MlsWireMessage wire,
    required Iterable<MlsMemberIdentity> recipients,
    required String senderUserId,
    required String senderDeviceId,
    required int createdAtMillis,
  }) {
    if (senderUserId.isEmpty || senderDeviceId.isEmpty) {
      throw ArgumentError('群消息发送身份不完整');
    }
    final unique = <String, MlsMemberIdentity>{};
    for (final recipient in recipients) {
      if (recipient.userId.isEmpty ||
          recipient.deviceId.isEmpty ||
          (recipient.userId == senderUserId &&
              recipient.deviceId == senderDeviceId)) {
        continue;
      }
      unique[recipient.wireValue] = recipient;
    }
    return unique.values
        .map((recipient) {
          final messageId = MessageId.derive(
            conversationId: wire.conversationId,
            senderUserId: senderUserId,
            recipientUserId: '${recipient.userId}:${recipient.deviceId}',
            createdAtMillis: createdAtMillis,
            encryptedMessage: wire.wireBytes,
          );
          return wire.toEncryptedMessage(
            messageId: messageId,
            senderUserId: senderUserId,
            recipientUserId: recipient.userId,
            senderDeviceId: senderDeviceId,
            recipientDeviceId: recipient.deviceId,
            createdAtMillis: createdAtMillis,
          );
        })
        .toList(growable: false);
  }
}
