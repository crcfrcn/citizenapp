import 'package:citizen_account/profile/profile_presentation.dart';

/// 用户主页公开资料模型（对应 Worker `UserProfileResponse`）。
///
/// 头像/背景/签名/展示名是链下 R2 资料；计数与认证是 D1/链上派生。
/// App 侧只读展示，写入走 `PUT /api/user/profile`。
class CitizenProfile {
  const CitizenProfile({
    required this.accountId,
    required this.displayName,
    required this.profileBio,
    required this.avatarKey,
    required this.bannerKey,
    required this.cidNumber,
    required this.isCertified,
    required this.cidLevel,
    required this.memberLevel,
    required this.membergateActive,
    required this.following,
    required this.followers,
    required this.mutualFollowing,
    required this.posts,
    required this.campaigns,
    required this.videos,
    required this.articles,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isNotifying,
    required this.profileAt,
  });

  final String accountId;
  final String displayName;
  final String profileBio;
  final String? avatarKey;
  final String? bannerKey;
  final String? cidNumber;
  final bool isCertified;

  /// 链上身份档位：visitor 未认证 / voting 认证投票公民 / candidate 认证竞选公民。
  /// 认证真源=链上；无有效会员时，徽章据此分色（访客金/投票蓝/竞选红）。
  final String cidLevel;

  /// 已购买的会员档位（公开）：freedom/democracy/spark/null（未购买）。
  /// ADR-037 规定与链上身份档彻底解耦；有效会员徽章按本字段分色并显示对勾。
  final String? memberLevel;

  /// 会员是否当前有效。
  final bool membergateActive;

  final int following;
  final int followers;
  final int mutualFollowing;
  final int posts;
  final int campaigns;
  final int videos;
  final int articles;
  final bool isFollowing;

  /// 主页用户是否关注当前登录者；只用于准确计算当前操作是否形成或解除互关。
  final bool isFollowedBy;

  /// 当前登录者是否对该账户开启发帖通知（= 已关注且未静音）。本人视角恒为 false。
  final bool isNotifying;
  final int profileAt;

  /// `display_name` 是公开昵称唯一真源；缺失时按 CID（无 CID 才按账户）
  /// 生成稳定默认昵称，绝不把钱包名、完整账户或截断账户当昵称。
  String get resolvedDisplayName {
    return ProfilePresentation.forIdentityKey(cidNumber ?? accountId)
        .resolveDisplayName(publicName: displayName);
  }

  factory CitizenProfile.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'];
    if (json['profile_bio'] is! String ||
        counts is! Map<String, dynamic> ||
        !counts.containsKey('following') ||
        !counts.containsKey('followers') ||
        !counts.containsKey('mutual_following') ||
        !counts.containsKey('posts') ||
        !counts.containsKey('campaigns') ||
        !counts.containsKey('videos') ||
        !counts.containsKey('articles') ||
        json['is_followed_by'] is! bool) {
      throw const FormatException('用户主页响应缺少关系、内容分类统计或互关状态');
    }
    final countsMap = counts;
    return CitizenProfile(
      accountId: _asString(json['account_id']),
      displayName: _asString(json['display_name']),
      profileBio: _asString(json['profile_bio']),
      avatarKey: _asNullableString(json['avatar_key']),
      bannerKey: _asNullableString(json['banner_key']),
      cidNumber: _asNullableString(json['cid_number']),
      isCertified: json['is_certified'] == true,
      cidLevel: _asIdentityLevel(json['cid_level']),
      memberLevel: _asMembershipLevel(json['member_level']),
      membergateActive: json['membergate_active'] == true,
      following: _asInt(countsMap['following']),
      followers: _asInt(countsMap['followers']),
      mutualFollowing: _asInt(countsMap['mutual_following']),
      posts: _asInt(countsMap['posts']),
      campaigns: _asInt(countsMap['campaigns']),
      videos: _asInt(countsMap['videos']),
      articles: _asInt(countsMap['articles']),
      isFollowing: json['is_following'] == true,
      isFollowedBy: json['is_followed_by'] == true,
      isNotifying: json['is_notifying'] == true,
      profileAt: _asInt(json['profile_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'account_id': accountId,
    'display_name': displayName,
    'profile_bio': profileBio,
    'avatar_key': avatarKey,
    'banner_key': bannerKey,
    'cid_number': cidNumber,
    'is_certified': isCertified,
    'cid_level': cidLevel,
    'member_level': memberLevel,
    'membergate_active': membergateActive,
    'counts': <String, dynamic>{
      'following': following,
      'followers': followers,
      'mutual_following': mutualFollowing,
      'posts': posts,
      'campaigns': campaigns,
      'videos': videos,
      'articles': articles,
    },
    'is_following': isFollowing,
    'is_followed_by': isFollowedBy,
    'is_notifying': isNotifying,
    'profile_at': profileAt,
  };

  CitizenProfile copyWith({
    String? displayName,
    String? profileBio,
    Object? avatarKey = _sentinel,
    Object? bannerKey = _sentinel,
    Object? memberLevel = _sentinel,
    bool? membergateActive,
    bool? isFollowing,
    bool? isFollowedBy,
    bool? isNotifying,
    int? followers,
    int? mutualFollowing,
    int? profileAt,
  }) {
    return CitizenProfile(
      accountId: accountId,
      displayName: displayName ?? this.displayName,
      profileBio: profileBio ?? this.profileBio,
      avatarKey: identical(avatarKey, _sentinel)
          ? this.avatarKey
          : avatarKey as String?,
      bannerKey: identical(bannerKey, _sentinel)
          ? this.bannerKey
          : bannerKey as String?,
      cidNumber: cidNumber,
      isCertified: isCertified,
      cidLevel: cidLevel,
      memberLevel: identical(memberLevel, _sentinel)
          ? this.memberLevel
          : memberLevel as String?,
      membergateActive: membergateActive ?? this.membergateActive,
      following: following,
      followers: followers ?? this.followers,
      mutualFollowing: mutualFollowing ?? this.mutualFollowing,
      posts: posts,
      campaigns: campaigns,
      videos: videos,
      articles: articles,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      isNotifying: isNotifying ?? this.isNotifying,
      profileAt: profileAt ?? this.profileAt,
    );
  }
}

/// 关注、关注者或互关列表的一行（对应 Worker follows 列表项 `entries`，项 = 身份主键
/// peer_cid + created_at）。
class SquareFollowEntry {
  const SquareFollowEntry({required this.peerCid, required this.createdAt});

  final String peerCid;
  final int createdAt;

  factory SquareFollowEntry.fromJson(Map<String, dynamic> json) {
    final peerCid = json['peer_cid'];
    final createdAt = json['created_at'];
    if (peerCid is! String ||
        peerCid.isEmpty ||
        createdAt is! int ||
        createdAt < 0) {
      throw const FormatException('关注列表字段无效');
    }
    return SquareFollowEntry(peerCid: peerCid, createdAt: createdAt);
  }
}

const Object _sentinel = Object();

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

/// 归一化链上身份档位；未知/缺失一律 visitor（fail-closed，不误判认证）。
String _asIdentityLevel(Object? value) {
  final normalized = value?.toString().trim();
  return (normalized == 'voting' || normalized == 'candidate')
      ? normalized!
      : 'visitor';
}

/// 归一化会员档位；未知/缺失/未购买 → null（不给勾）。
/// 会员三档 = freedom / democracy / spark；ADR-037 规定会员与链上身份档彻底解耦，
/// voting / candidate 是身份档（cid_level），绝不能出现在会员白名单里。
String? _asMembershipLevel(Object? value) {
  final normalized = value?.toString().trim();
  return (normalized == 'freedom' ||
          normalized == 'democracy' ||
          normalized == 'spark')
      ? normalized
      : null;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// 聊天显示模型，不代表完整主页，也不能写入完整主页缓存。
final class CitizenProfileCard extends CitizenProfile {
  CitizenProfileCard(Map<String, dynamic> card)
    : super(
        accountId: card['account_id'] as String,
        cidNumber: card['cid_number'] as String,
        displayName: card['display_name'] as String,
        avatarKey: card['avatar_key'] as String?,
        profileAt: card['profile_at'] as int,
        profileBio: '',
        bannerKey: null,
        isCertified: card['is_certified'] == true,
        cidLevel: card['cid_level'] as String? ?? 'visitor',
        memberLevel: card['member_level'] as String?,
        membergateActive: card['membergate_active'] == true,
        following: 0,
        followers: 0,
        mutualFollowing: 0,
        posts: 0,
        campaigns: 0,
        videos: 0,
        articles: 0,
        isFollowing: false,
        isFollowedBy: false,
        isNotifying: false,
      );
}
