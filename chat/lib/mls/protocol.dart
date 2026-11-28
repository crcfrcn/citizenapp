// 定义MLS密钥包、线消息、群状态及原持久化接口。

import 'dart:io';

import 'package:citizen_network/auth.dart' hide bytesToHex, hexToBytes;
import 'package:citizen_network/message.dart';
import 'package:fixnum/fixnum.dart';
export 'package:citizen_network/auth.dart' hide bytesToHex, hexToBytes;

// 定义MLS身份、密钥包、线格式及受限认证请求的Dart边界。

// 公民聊天 的 RFC 9420 MLS 边界模型。
//
// Dart 只传递身份、KeyPackage、MLS wire bytes和受限认证请求。签名唯一由
// Rust OpenMLS 完成，禁止另建原始 HPKE 直聊协议或应用层密钥编号。

/// OpenMLS 生成的 RFC 9420 KeyPackage。
class MlsKeyPackage {
  const MlsKeyPackage({
    required this.userId,
    required this.deviceId,
    required this.keyPackageRef,
    required this.keyPackageBytes,
    required this.cipherSuite,
    required this.notBeforeMillis,
    required this.notAfterMillis,
    required this.lastResort,
  });

  final String userId;
  final String deviceId;

  /// OpenMLS 根据标准 KeyPackage 计算的 KeyPackageRef 十六进制值。
  final String keyPackageRef;

  final List<int> keyPackageBytes;
  final String cipherSuite;
  final int notBeforeMillis;
  final int notAfterMillis;
  final bool lastResort;

  String get keyPackageHex => _bytesToHex(keyPackageBytes);
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

// 定义群成员、Commit、处理状态及OpenMLS群操作接口。

// 私密小群(MLS 群)的 Dart 侧边界模型与接口。
//
// 只定义可测的数据边界与注入点;真正的 OpenMLS 群加解密由 Rust native
// (chat/mls/src/mls.rs 的群接口)实现,这里禁止自研密码学。
// 行为由本边界测试和 Rust FFI 接口共同固定。

/// MLS BasicCredential 中的标准 公民聊天 设备身份。
class MlsMemberIdentity {
  const MlsMemberIdentity({required this.userId, required this.deviceId});

  final String userId;
  final String deviceId;

  String get wireValue => '$userId:$deviceId';

  static MlsMemberIdentity parse(String identity) {
    final index = identity.indexOf(':');
    if (index <= 0 || index == identity.length - 1) {
      throw const FormatException('MLS 成员身份格式不合法');
    }
    return MlsMemberIdentity(
      userId: identity.substring(0, index),
      deviceId: identity.substring(index + 1),
    );
  }
}

/// 群成员标识 = "user_id:device_id"（MLS BasicCredential 内容）。
/// 扇出/名册以 用户身份 为单位，故从标识取 用户身份 段。
String userIdFromMemberIdentity(String identity) {
  return MlsMemberIdentity.parse(identity).userId;
}

List<MlsMemberIdentity> membersFromMemberIdentities(
  Iterable<String> identities,
) => identities.map(MlsMemberIdentity.parse).toList(growable: false);

/// 一批成员标识 → 去重 用户身份 集合（可选排除自己）。
List<String> userIdsFromMemberIdentities(
  Iterable<String> identities, {
  String? excludeUserId,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final identity in identities) {
    final userId = userIdFromMemberIdentity(identity);
    if (userId.isEmpty || userId == excludeUserId) {
      continue;
    }
    if (seen.add(userId)) {
      result.add(userId);
    }
  }
  return result;
}

/// `group_process` 返回的 epoch 判定状态。
enum GroupProcessStatus {
  applied('applied'),
  outOfOrder('out_of_order'),
  stale('stale'),
  unknown('unknown');

  const GroupProcessStatus(this.wireName);

  final String wireName;

  static GroupProcessStatus fromWireName(String value) {
    for (final status in values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return GroupProcessStatus.unknown;
  }
}

/// 入站群消息的内容类型。
enum GroupInboundKind {
  welcome('welcome'),
  commit('commit'),
  application('application'),
  unknown('unknown');

  const GroupInboundKind(this.wireName);

  final String wireName;

  static GroupInboundKind fromWireName(String value) {
    for (final kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return GroupInboundKind.unknown;
  }
}

/// 建群结果。
class GroupCreated {
  const GroupCreated({required this.groupId, required this.epoch});

  final String groupId;
  final int epoch;
}

/// 加人/删人产生的 Commit 束。
///
/// add:`commit` 发给现有成员,`welcome` 发给全部新人(单条覆盖 N 人)。
/// remove:仅 `commit`,发给剩余成员 + 被删者;`removedMemberIdentities` 为被删 用户身份。
class GroupCommitBundle {
  const GroupCommitBundle({
    required this.groupId,
    required this.epoch,
    required this.commit,
    this.welcome,
    this.removedMemberIdentities = const [],
    this.priorMemberIdentities = const [],
    this.welcomeMemberIdentities = const [],
    required this.createdAtMillis,
  });

  final String groupId;
  final int epoch;
  final MlsWireMessage commit;
  final MlsWireMessage? welcome;
  final List<String> removedMemberIdentities;
  final List<String> priorMemberIdentities;
  final List<String> welcomeMemberIdentities;
  final int createdAtMillis;
}

/// 分发服务接收每类原始握手密文各一份，并按该密文的完整设备名单路由。
List<EncryptedMessage> mlsCommitMessages({
  required String operationId,
  required String conversationId,
  required List<int> groupId,
  required String senderUserId,
  required String senderDeviceId,
  required int createdAtMillis,
  required List<int> commit,
  required Iterable<String> priorMembers,
  List<int>? welcome,
  Iterable<String> invitees = const [],
}) {
  EncryptedMessage? envelope(
    String kind,
    List<int> wire,
    Iterable<String> roster,
  ) {
    final deliveries = [
      for (final member in membersFromMemberIdentities(roster))
        if (member.userId != senderUserId || member.deviceId != senderDeviceId)
          EncryptedDelivery(
            recipient: Recipient(
              userId: member.userId,
              deviceId: member.deviceId,
            ),
            openmlsCiphertext: wire,
          ),
    ];
    if (deliveries.isEmpty) return null;
    return EncryptedMessage(
      messageId: '$operationId-$kind',
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      groupId: groupId,
      createdAtMillis: Int64(createdAtMillis),
      deliveries: deliveries,
    );
  }

  return [
    ?envelope('commit', commit, priorMembers),
    if (welcome != null) ?envelope('welcome', welcome, invitees),
  ];
}

/// `group_process` 处理入站群消息的结果。
class GroupInbound {
  const GroupInbound({
    required this.groupId,
    required this.kind,
    required this.status,
    required this.messageEpoch,
    required this.groupEpoch,
    required this.selfRemoved,
    this.plaintext,
    this.memberIdentities,
    this.senderMemberIdentity,
    this.committed = false,
  });

  final String groupId;
  final GroupInboundKind kind;
  final GroupProcessStatus status;
  final int messageEpoch;
  final int groupEpoch;

  /// 本机是否在该 Commit 中被移除(被删/退群生效)。
  final bool selfRemoved;

  /// application 明文(仅 application applied 非空)。
  final List<int>? plaintext;

  /// 应用 Commit / 入群 Welcome 后的 MLS 权威名册(标识,含设备段)。
  final List<String>? memberIdentities;

  /// 由OpenMLS验签后的真实发送设备，不能用传输层自报值替代。
  final String? senderMemberIdentity;

  /// 原生已提交精确处理收据，不能由stale状态推定。
  final bool committed;

  bool get isApplied => status == GroupProcessStatus.applied;

  bool get isOutOfOrder => status == GroupProcessStatus.outOfOrder;
}

/// 只读群状态(名册对账 + 上限守)。
class GroupState {
  const GroupState({
    required this.groupId,
    required this.epoch,
    required this.memberIdentities,
  });

  final String groupId;
  final int epoch;
  final List<String> memberIdentities;

  int get memberCount => memberIdentities.length;
}

/// OpenMLS 群 FFI 边界接口(可注入,单测用 fake)。
///
/// 实现必须调用成熟 OpenMLS native,不允许在 Dart 中自研群密码学。
abstract class MlsGroupCrypto {
  /// 为当前设备生成一枚由 OpenMLS 保存私有材料的 Last Resort KeyPackage。
  Future<MlsKeyPackage> createKeyPackage(
    ChatDevice identity, {
    bool lastResort = true,
  });

  /// 建群,创建者为唯一成员。
  Future<GroupCreated> createGroup(String groupId);

  /// 批量加人:1 Commit(现有成员)+ 1 Welcome(全部新人)。
  Future<GroupCommitBundle> addMembers(
    String groupId,
    List<MlsKeyPackage> keyPackages,
  );

  /// 精确移除user_id:device_id设备叶子；用户级移除由调用方先展开当前名册。
  Future<GroupCommitBundle> removeMembers(
    String groupId,
    List<String> memberIdentities,
  );

  /// 群 application message(单次加密,Dart 侧扇出)。
  Future<MlsWireMessage> groupCreateMessage(
    String groupId,
    List<int> plaintext,
  );

  /// 处理入站群消息(Welcome / Commit / Application)。
  Future<GroupInbound> groupProcess(MlsWireMessage wire);

  /// 只读群状态(epoch + 名册)。
  Future<GroupState> groupState(String groupId);
}

/// 只有分发层明确选择或拒绝同一 Commit 后，才可结清 OpenMLS pending 状态。
abstract interface class MlsCommitControl {
  Future<void> finishCommit(String operationId, {required bool accepted});
}

/// 持久化实现的事务能力；复用现有message_id，不扩展密码协议。
abstract interface class MlsPersistentCrypto {
  Future<T> withMessage<T>(String messageId, Future<T> Function() operation);
  Future<void> acknowledgeMessage(String messageId);
  Future<List<Map<String, dynamic>>> pendingMessageResults(String? messageId);
}

/// 生产必须接入持久化实现；非持久化替身只允许合成测试。
extension MlsPersistentOperations on MlsGroupCrypto {
  Future<void> settlePendingCommit(
    String operationId, {
    required bool accepted,
  }) {
    final current = this;
    if (current is! MlsCommitControl) {
      throw StateError('MLS实现缺少待确认Commit接口');
    }
    return (current as MlsCommitControl).finishCommit(
      operationId,
      accepted: accepted,
    );
  }

  Future<T> withMessage<T>(String messageId, Future<T> Function() operation) {
    final current = this;
    if (current is MlsPersistentCrypto) {
      // 显式接口调用避免交叉类型解析再次进入同名extension。
      return (current as MlsPersistentCrypto).withMessage(messageId, operation);
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('MLS实现缺少持久化事务');
    }
    return operation();
  }

  Future<void> acknowledgeMessage(String messageId) async {
    final current = this;
    if (current is MlsPersistentCrypto) {
      await (current as MlsPersistentCrypto).acknowledgeMessage(messageId);
      return;
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('MLS实现缺少落库确认');
    }
  }

  Future<List<Map<String, dynamic>>> pendingMessageResults(
    String? messageId,
  ) async {
    final current = this;
    if (current is MlsPersistentCrypto) {
      return (current as MlsPersistentCrypto).pendingMessageResults(messageId);
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('MLS实现缺少恢复接口');
    }
    return [];
  }

  /// 扇出使用该密文提交时的成员集合，重试期间当前epoch可能已经前进。
  Future<List<String>> messageMemberIdentities(
    String groupId,
    String messageId,
  ) async {
    for (final entry in await pendingMessageResults(messageId)) {
      final result = (entry['result'] as Map).cast<String, dynamic>();
      if (result['application_wire_hex'] is String) {
        return (result['member_identities'] as List).cast<String>();
      }
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      throw StateError('MLS发送结果缺失');
    }
    return (await groupState(groupId)).memberIdentities;
  }
}

// 表示MLS线消息和发送语义，接收类型交由OpenMLS判断。

/// 发送端已知的 MLS wire 语义；接收端由 OpenMLS 解析真实类型。
enum MlsMessageKind { welcome, commit, application, unknown }

/// 一条标准 MLS wire message。
class MlsWireMessage {
  const MlsWireMessage({
    required this.wireBytes,
    required this.conversationId,
    this.groupIdBytes = const [],
    this.senderMemberIdentity,
    this.messageKind = MlsMessageKind.unknown,
  });

  final List<int> wireBytes;
  final String conversationId;
  final List<int> groupIdBytes;
  final String? senderMemberIdentity;

  String get groupId =>
      groupIdBytes.isEmpty ? conversationId : mlsGroupId(groupIdBytes);
  final MlsMessageKind messageKind;

  String get wireHex =>
      wireBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  EncryptedMessage toEncryptedMessage({
    required String messageId,
    required String senderUserId,
    required String recipientUserId,
    required String senderDeviceId,
    required String recipientDeviceId,
    required int createdAtMillis,
  }) {
    return EncryptedMessage(
      messageId: messageId,
      conversationId: conversationId,
      groupId: groupIdBytes,
      senderUserId: senderUserId,
      senderDeviceId: senderDeviceId,
      deliveries: <EncryptedDelivery>[
        EncryptedDelivery(
          recipient: Recipient(
            userId: recipientUserId,
            deviceId: recipientDeviceId,
          ),
          openmlsCiphertext: wireBytes,
        ),
      ],
      createdAtMillis: Int64(createdAtMillis),
    );
  }
}

String mlsGroupId(List<int> bytes) =>
    'mls:${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

List<int> mlsGroupIdBytes(String id) {
  if (!RegExp(r'^mls:[0-9a-f]{32}$').hasMatch(id)) {
    throw const FormatException('MLS组标识无效');
  }
  return [
    for (var i = 4; i < id.length; i += 2)
      int.parse(id.substring(i, i + 2), radix: 16),
  ];
}

/// 从服务端不透明消息恢复 wire bytes；消息类型必须交给 OpenMLS 判断。
MlsWireMessage mlsWireMessageFromEncryptedMessage(EncryptedMessage message) {
  return MlsWireMessage(
    wireBytes: List<int>.from(message.openmlsCiphertext),
    conversationId: message.conversationId,
    groupIdBytes: List<int>.unmodifiable(message.groupId),
    senderMemberIdentity: message.groupId.isEmpty
        ? null
        : '${message.senderUserId}:${message.senderDeviceId}',
  );
}

/// 私聊和群聊信封形状的唯一App校验；必须在进入native或业务写入前调用。
void validateChatEnvelope(EncryptedMessage message) {
  final parts = message.conversationId.split(':');
  bool cid(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(value);
  if (parts.length != 3 ||
      message.conversationId.length > 256 ||
      !cid(parts[1])) {
    throw const FormatException('聊天会话标识无效');
  }
  if (!cid(message.senderUserId) ||
      message.deliveries.isEmpty ||
      message.deliveries.any(
        (delivery) =>
            !delivery.hasRecipient() || !cid(delivery.recipient.userId),
      )) {
    throw const FormatException('聊天信封身份无效');
  }
  if (parts[0] == 'dm') {
    if (!cid(parts[2]) ||
        parts[1].compareTo(parts[2]) >= 0 ||
        message.groupId.length != 16 ||
        !parts.skip(1).contains(message.senderUserId) ||
        message.deliveries.any(
          (delivery) =>
              !delivery.hasRecipient() ||
              !parts.skip(1).contains(delivery.recipient.userId),
        )) {
      throw const FormatException('私聊信封与双方或MLS组不一致');
    }
  } else if (parts[0] == 'grp') {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(parts[2]) ||
        message.groupId.isNotEmpty) {
      throw const FormatException('群聊信封不得携带私聊MLS组');
    }
  } else {
    throw const FormatException('聊天会话类型无效');
  }
}
