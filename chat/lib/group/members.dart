// 定义群成员、角色、上限及成员校验。

library;

// 定义以MLS名册为真源的群、成员及角色镜像。

enum GroupMemberRole {
  admin('admin'),
  member('member');

  const GroupMemberRole(this.wireName);

  final String wireName;

  static GroupMemberRole fromName(String value) {
    for (final role in values) {
      if (role.wireName == value) {
        return role;
      }
    }
    return GroupMemberRole.member;
  }
}

/// 群成员镜像（user ID + 角色）。
class GroupMember {
  const GroupMember({required this.userId, this.role = GroupMemberRole.member});

  final String userId;
  final GroupMemberRole role;

  bool get isAdmin => role == GroupMemberRole.admin;
}

/// 群会话镜像。
class ChatGroup {
  const ChatGroup({
    required this.groupId,
    required this.name,
    required this.creatorUserId,
    required this.epoch,
    required this.roster,
    this.leftLocally = false,
  });

  /// 群 ID = conversation_id,形如 `grp:<creator>:<nonce>`。
  final String groupId;
  final String name;
  final String creatorUserId;

  /// MLS 当前 epoch 的本地镜像(UI/调试用)。
  final int epoch;

  /// 名册镜像(以 MLS `group_state` 对账)。
  final List<GroupMember> roster;

  /// 本机是否已退群/被移除。
  final bool leftLocally;

  /// admin user ID 集合。
  Set<String> get adminSet => roster
      .where((member) => member.isAdmin)
      .map((member) => member.userId)
      .toSet();

  /// 全体成员 user ID（去重）。
  List<String> get memberUserIds =>
      roster.map((member) => member.userId).toList(growable: false);
}

// 声明Dart与原生MLS共同约束的单群成员上限。

const int kMaxGroupMembers = 1989;

// 校验群成员容量及仅管理员可执行的增删操作。

// 名册守卫:≤1989 上限 + 权限(仅 admin 加/删),纯函数可测。
//
// 上限双拦的 Dart 一侧;另一侧在 Rust `group_add_members`(以 MLS 实际成员数为准)。

/// 群成员操作被拒。
class GroupMembershipException implements Exception {
  const GroupMembershipException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GroupMembership {
  const GroupMembership._();

  /// 建群:创建者 + 邀请数不得超上限。
  static void ensureCanCreate({required int inviteeCount}) {
    if (inviteeCount < 0) {
      throw const GroupMembershipException('邀请人数不能为负');
    }
    if (1 + inviteeCount > kMaxGroupMembers) {
      throw GroupMembershipException(
        '群成员将达 ${1 + inviteeCount}，超过上限 $kMaxGroupMembers',
      );
    }
  }

  /// 加人:当前成员数 + 新增数不得超上限;至少加一人。
  static void ensureCanAdd({
    required int currentCount,
    required int addingCount,
  }) {
    if (addingCount <= 0) {
      throw const GroupMembershipException('至少添加一名成员');
    }
    if (currentCount + addingCount > kMaxGroupMembers) {
      throw GroupMembershipException(
        '群成员将达 ${currentCount + addingCount}，超过上限 $kMaxGroupMembers',
      );
    }
  }

  /// 加/删成员权限:仅 admin。
  static void ensureAdmin({
    required Set<String> adminSet,
    required String actorUserId,
  }) {
    if (!adminSet.contains(actorUserId)) {
      throw const GroupMembershipException('只有群管理员可以添加或移除成员');
    }
  }
}
