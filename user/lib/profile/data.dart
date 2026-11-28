// 管理公开资料模型、读取缓存、媒体资产及注销清理。

import 'package:citizen_square/media/processor.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_user/context.dart' show IdentityBinding;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_user/membership/service.dart' show SubscriptionService;
import 'package:citizen_square/post/models.dart';
import 'package:citizen_user/api.dart' show SquareActionSigner, SquareApiClient, SquareApiException, SquarePreflightException, SquareSession;
import 'package:citizen_square/post/store.dart';
import 'package:citizen_system/log.dart';
import 'package:citizen_storage/user.dart' as user_store show Edit, Profile, ProfileMedia;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:citizen_storage/user.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

// 定义公开用户资料、关系条目及资料图片键解析模型。

/// 用户主页公开资料模型（对应 Worker `UserProfileResponse`）。
///
/// App 侧只读展示，写入走 `PUT /api/user/profile`。
class CitizenProfile {
  static final _asset = RegExp(
    r'^i/([A-Za-z0-9][A-Za-z0-9-]{0,31})/(avatar|banner)/([a-f0-9]{64})$',
  );

  /// 解析服务端交付的唯一资料图片键。
  static ({String cid, String kind, String hash})? parseAssetKey(String key) {
    final match = _asset.firstMatch(key);
    if (match == null || match.end != key.length) return null;
    return (cid: match[1]!, kind: match[2]!, hash: match[3]!);
  }

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

  /// 主页用户是否关注当前登录者；关系与三项计数均沿用服务端确认结果。
  final bool isFollowedBy;

  /// 当前登录者是否对该账户开启发帖通知（= 已关注且未静音）；本人不展示通知按钮。
  final bool isNotifying;
  final int profileAt;

  /// `display_name` 是公开昵称唯一真源；缺失时按 CID（无 CID 才按账户）
  /// 生成稳定默认昵称，绝不把钱包名、完整账户或截断账户当昵称。
  String get resolvedDisplayName {
    return ProfilePresentation.forIdentityKey(
      cidNumber ?? accountId,
    ).resolveDisplayName(publicName: displayName);
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
      accountId: '',
      displayName: _asString(json['display_name']),
      profileBio: _asString(json['profile_bio']),
      avatarKey: _asNullableString(json['avatar_key']),
      bannerKey: _asNullableString(json['banner_key']),
      cidNumber: _asNullableString(json['cid_number']),
      isCertified: false,
      cidLevel: 'visitor',
      memberLevel: null,
      membergateActive: false,
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
    'display_name': displayName,
    'profile_bio': profileBio,
    'avatar_key': avatarKey,
    'banner_key': bannerKey,
    'cid_number': cidNumber,
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
    int? following,
    int? followers,
    int? mutualFollowing,
    int? posts,
    int? campaigns,
    int? videos,
    int? articles,
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
      following: following ?? this.following,
      followers: followers ?? this.followers,
      mutualFollowing: mutualFollowing ?? this.mutualFollowing,
      posts: posts ?? this.posts,
      campaigns: campaigns ?? this.campaigns,
      videos: videos ?? this.videos,
      articles: articles ?? this.articles,
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

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// 聊天显示模型，不代表完整主页，也不能写入完整主页缓存。
final class CitizenProfileCard extends CitizenProfile {
  CitizenProfileCard(Map<String, dynamic> card)
    : super(
        accountId: '',
        cidNumber: card['cid_number'] as String,
        displayName: card['display_name'] as String,
        avatarKey: card['avatar_key'] as String?,
        profileAt: card['profile_at'] as int,
        profileBio: '',
        bannerKey: null,
        isCertified: false,
        cidLevel: 'visitor',
        memberLevel: null,
        membergateActive: false,
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

// 聚合主页、作者帖子和资料更新，按每次入口独立检查访问权限。

class ProfileEntryRefreshResult {
  const ProfileEntryRefreshResult(this.profile, this.session);
  final CitizenProfileLoadResult profile;
  final SquareSession session;
}

/// 用户主页数据层门面：把主页资料、按作者拉帖、更新资料收敛到一个入口。
///
/// 网络细节（登录态、解析、Worker 地址）复用 [SquareApiClient]，本类只做语义聚合。
class CitizenProfileApi {
  /// 每次进入主页独立检查，不能使用资料刷新限速或缓存关系授予访问。
  Future<void> requireProfileAccess(String targetCid, SquareSession session) =>
      _client.requireProfileAccess(targetCid, session);
  CitizenProfileApi({
    SquareApiClient? client,
    SquarePostStore? localPostStore,
    DateTime Function()? now,
  }) : _client = client ?? SquareApiClient(),
       _localPostStore = localPostStore ?? const SquarePostStore(),
       _now = now ?? DateTime.now;

  final SquareApiClient _client;
  final SquarePostStore _localPostStore;
  static final Map<String, Future<CitizenProfileLoadResult>> _refreshes = {};
  final DateTime Function() _now;
  static const entryRefreshInterval = Duration(minutes: 10);
  static final Map<String, Future<ProfileEntryRefreshResult?>> _entryRefreshes =
      {};

  @visibleForTesting
  static void resetEntryRefreshMemory() {
    _entryRefreshes.clear();
    _refreshes.clear();
  }

  /// 跨页面、API实例及进程重启限速；失败也占用本次十分钟窗口。
  Future<ProfileEntryRefreshResult?> refreshOnEntry(
    String targetCid, {
    required IdentityBinding binding,
    required SquareSessionProvider sessions,
    CitizenProfileCache? cache,
    CitizenProfileMediaCache? mediaCache,
    bool Function()? isCurrentIdentity,
  }) {
    final key =
        'profile.entry.${sha256.convert(utf8.encode(jsonEncode([_client.baseUrl, binding.genesisHash, binding.cidNumber, binding.accountId, binding.bindRev, targetCid])))}';
    final running = _entryRefreshes[key];
    if (running != null) return running;
    late final Future<ProfileEntryRefreshResult?> task;
    task = Future<ProfileEntryRefreshResult?>.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final now = _now().millisecondsSinceEpoch;
        final previous = prefs.getInt(key);
        if (previous != null &&
            now - previous < entryRefreshInterval.inMilliseconds) {
          return null;
        }
        if (!(isCurrentIdentity?.call() ?? true)) return null;
        if (!await prefs.setInt(key, now)) throw StateError('自动刷新限速记录保存失败');
        final resolution = await sessions.resolveSession();
        final session = resolution.session;
        if (!(isCurrentIdentity?.call() ?? true) ||
            session == null ||
            session.cidNumber != binding.cidNumber ||
            session.accountId != binding.accountId ||
            session.bindRev != binding.bindRev) {
          throw StateError('主页刷新身份尚未就绪');
        }
        final result = await refreshProfile(
          targetCid,
          session: session,
          userInitiated: false,
          cache: cache,
          mediaCache: mediaCache,
          isCurrent: isCurrentIdentity,
        );
        return ProfileEntryRefreshResult(result, session);
      } finally {
        if (identical(_entryRefreshes[key], task)) _entryRefreshes.remove(key);
      }
    });
    _entryRefreshes[key] = task;
    return task;
  }

  /// 云端校准共用入口；进入页须通过refreshOnEntry限速，手动/写入后刷新可主动调用。
  Future<CitizenProfileLoadResult> refreshProfile(
    String cidNumber, {
    required SquareSession session,
    required bool userInitiated,
    bool Function()? isCurrent,
    CitizenProfileCache? cache,
    CitizenProfileMediaCache? mediaCache,
  }) {
    final key = jsonEncode([
      _client.baseUrl,
      cidNumber,
      session.cidNumber,
      session.accountId,
      session.bindRev,
      CitizenProfileCache.readGeneration(cidNumber),
    ]);
    void check() {
      if (!session.isUsable || !(isCurrent?.call() ?? true)) {
        throw StateError('资料刷新身份已变化');
      }
    }

    check();
    final running = _refreshes[key];
    if (running != null) return running;
    late final Future<CitizenProfileLoadResult> task;
    task = Future<CitizenProfileLoadResult>.microtask(() async {
      try {
        return await loadProfile(
          cidNumber,
          session: session,
          cache: cache,
          mediaCache: mediaCache,
          isCurrent: isCurrent,
          refreshMedia: true,
        );
      } finally {
        if (identical(_refreshes[key], task)) _refreshes.remove(key);
      }
    });
    _refreshes[key] = task;
    return task;
  }

  /// 主页访问和显式刷新共用：先完成原始业务鉴权，再接收远端资料并返回有效展示快照。
  Future<CitizenProfileLoadResult> loadProfile(
    String cidNumber, {
    required SquareSession session,
    CitizenProfileCache? cache,
    CitizenProfileMediaCache? mediaCache,
    bool Function()? isCurrent,
    bool refreshMedia = false,
  }) async {
    void check() {
      if (!session.isUsable || !(isCurrent?.call() ?? true)) {
        throw StateError('资料刷新身份已变化');
      }
    }

    check();
    final order = CitizenProfileCache.beginRead(cidNumber);
    final remote = await fetchProfile(cidNumber, session: session);
    await session.validateCurrent();
    check();
    final target = cache ?? const CitizenProfileCache();
    void checkRead() {
      check();
      if (!CitizenProfileCache.acceptsRead(cidNumber, order)) {
        throw StateError('资料读取已被较新操作取代');
      }
    }

    late CitizenProfileLoadResult result;
    try {
      checkRead();
      result = await target.receiveRemote(
        remote,
        expectedCid: cidNumber,
        assertCurrent: checkRead,
      );
    } catch (_) {
      check();
      if (CitizenProfileCache.acceptsRead(cidNumber, order)) rethrow;
      final local = await target.read(cidNumber);
      await session.validateCurrent();
      check();
      if (local == null) rethrow;
      // 迟到结果只返回当前本地快照，不落盘、不刷新旧图片或新增提示。
      return CitizenProfileLoadResult(
        local,
        CitizenProfileLoadStatus.unchanged,
        usedLocal: true,
      );
    }
    await session.validateCurrent();
    check();
    final profile = result.profile;
    if (refreshMedia &&
        result.acceptedRemote &&
        profile.profileAt > 0 &&
        (profile.avatarKey != null || profile.bannerKey != null)) {
      final reader = _client.profileMediaClient(session);
      try {
        await (mediaCache ?? CitizenProfileMediaCache()).refresh(
          client: reader,
          profile: profile,
          avatarUrl: profile.avatarKey == null
              ? null
              : _client.resolveProfileMedia(profile.avatarKey!).url,
          bannerUrl: profile.bannerKey == null
              ? null
              : _client.resolveProfileMedia(profile.bannerKey!).url,
        );
      } catch (error, stackTrace) {
        await session.validateCurrent();
        check();
        AppLog.profileLoadFailure(
          stage: 'cache_write',
          error: error,
          stackTrace: stackTrace,
        );
        return CitizenProfileLoadResult(
          profile,
          CitizenProfileLoadStatus.saveFailed,
        );
      } finally {
        reader.close();
      }
    }
    await session.validateCurrent();
    check();
    return result;
  }

  /// 完整资料图片按对象键中的用途限制读取大小；每次实际加载均逐请求签名。
  /// 缓存键按会话、资料版本和内容哈希隔离，诊断文本省略签名凭据。
  ImageProvider mediaImage(
    String objectKey, {
    required SquareSession session,
    int? updatedAt,
  }) {
    final asset = _client.resolveProfileMedia(objectKey);
    return _SignedProfileMediaImage(
      _client,
      session,
      asset.url,
      asset.kind,
      updatedAt,
      contentHash: asset.hash,
    );
  }

  /// 名片缓存刷新同样使用现签读取器；存储层不再拥有普通HTTP兜底或鉴权头。
  Future<CitizenProfileMediaSnapshot> refreshCardMedia(
    CitizenProfile profile, {
    required SquareSession session,
    required CitizenProfileMediaCache cache,
  }) async {
    final reader = _client.profileMediaClient(session);
    try {
      return await cache.refresh(
        client: reader,
        profile: profile,
        avatarUrl: profile.avatarKey == null
            ? null
            : cardMediaUrl(profile.avatarKey!, updatedAt: profile.profileAt),
        bannerUrl: null,
      );
    } finally {
      reader.close();
    }
  }

  Future<CitizenProfileCard> fetchCard(
    String cidNumber, {
    SquareSession? session,
  }) => _client.fetchUserCard(cidNumber: cidNumber, session: session);

  String cardMediaUrl(String objectKey, {int? updatedAt}) {
    final asset = CitizenProfile.parseAssetKey(objectKey);
    if (asset == null || asset.kind != 'avatar') {
      throw const SquareApiException('聊天资料卡只能读取头像');
    }
    return _client.cardAvatarUrl(asset.cid);
  }

  /// 拉取主页资料（按身份主键 cid_number）；[session] 存在时响应附带 is_following。
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) {
    return _client.fetchUserProfile(cidNumber: cidNumber, session: session);
  }

  /// 按作者身份主键 cid_number 分页拉帖；[postType] 由 Worker 在分页前过滤。
  Future<({List<SquarePost> posts, String? nextCursor})> fetchAuthorPosts(
    String cidNumber, {
    SquarePostCategory? category,
    SquarePostType? postType,
    int limit = 20,
    String? cursor,
    SquareSession? session,
  }) {
    return _client.fetchAuthorPosts(
      cidNumber: cidNumber,
      postCategory: category,
      postType: postType,
      limit: limit,
      cursor: cursor,
      session: session,
    );
  }

  /// 只供“本人主页”读取已校验的本地发布副本。
  ///
  /// 是否属于本人由页面层拿当前 session CID 判定；他人主页和公共信息流禁止调用，
  /// 防止本机私有副本变成第二个公开数据源。
  Future<List<SquareLocalPost>> fetchLocalPublishedPosts(String cidNumber) {
    return _localPostStore.listByCid(cidNumber);
  }

  /// 关注一个身份（目标身份主键 cid_number）。
  Future<void> followUser({
    required SquareSession session,
    required String peerCid,
  }) {
    return _client.followUser(session: session, peerCid: peerCid);
  }

  /// 取消关注一个身份（目标身份主键 cid_number）。
  Future<void> unfollowUser({
    required SquareSession session,
    required String peerCid,
  }) {
    return _client.unfollowUser(session: session, peerCid: peerCid);
  }

  /// 开/关对某关注的发帖通知（须已关注；目标身份主键 cid_number）。
  Future<void> setNotify({
    required SquareSession session,
    required String peerCid,
    required bool enabled,
  }) {
    return _client.setNotify(
      session: session,
      peerCid: peerCid,
      enabled: enabled,
    );
  }

  /// 拉取关注、关注者或互关列表（目标身份主键 cid_number；列表项也是 cid_number）。
  Future<({List<SquareFollowEntry> entries, String? nextCursor})> fetchFollows(
    String cidNumber, {
    required String type,
    int limit = 20,
    String? cursor,
    SquareSession? session,
  }) {
    return _client.fetchFollows(
      cidNumber: cidNumber,
      type: type,
      limit: limit,
      cursor: cursor,
      session: session,
    );
  }

  /// 更新本人公开资料，返回更新后的完整主页资料。
  Future<CitizenProfile> updateProfile({
    required SquareSession session,
    String? displayName,
    String? profileBio,
    String? avatarHash,
    String? bannerHash,
  }) {
    return _client.updateProfile(
      session: session,
      displayName: displayName,
      profileBio: profileBio,
      avatarHash: avatarHash,
      bannerHash: bannerHash,
    );
  }
}

/// 图片缓存保存解码图片而不保存一次性证明；失败后的重新加载会重新现签。
final class _SignedProfileMediaImage
    extends ImageProvider<_SignedProfileMediaImage> {
  const _SignedProfileMediaImage(
    this.client,
    this.session,
    this.url,
    this.role,
    this.version, {
    this.contentHash,
    this.expectedBytes,
  });
  final SquareApiClient client;
  final SquareSession session;
  final String url;
  final String role;
  final int? version;
  final String? contentHash;
  final int? expectedBytes;
  @override
  Future<_SignedProfileMediaImage> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _SignedProfileMediaImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: '公民资料图片',
  );
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      final response = role == 'post'
          ? await client.openPostMedia(
              url,
              session: session,
              expectedBytes: expectedBytes,
            )
          : role == 'card'
          ? await client.openCardMedia(url, session: session)
          : await client.openProfileMedia(url, session: session);
      final limit = role == 'post'
          ? SquareMediaPolicy.localImageBytes
          : CitizenProfileMediaCache.maxBytesFor(
              role == 'card' ? 'avatar' : role,
            );
      if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
        await response.stream.listen(null).cancel();
        throw SquareApiException('资料图片读取失败', statusCode: response.statusCode);
      }
      final bytes = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        await session.validateCurrent();
        length += chunk.length;
        if (length > limit) throw const FormatException('资料图片超出大小限制');
        bytes.add(chunk);
      }
      await session.validateCurrent();
      if (length == 0) throw const FormatException('资料图片为空');
      if (!session.isUsable) {
        throw const SquareApiException(
          '资料媒体会话已失效',
          errorCode: 'session_expired',
        );
      }
      final codec = await decode(
        await ui.ImmutableBuffer.fromUint8List(bytes.takeBytes()),
      );
      try {
        await session.validateCurrent();
        if (!session.isUsable) {
          throw const SquareApiException(
            '资料媒体会话已失效',
            errorCode: 'session_expired',
          );
        }
        return codec;
      } on Object {
        codec.dispose();
        rethrow;
      }
    } on Object {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _SignedProfileMediaImage &&
      identical(session, other.session) &&
      role == other.role &&
      url == other.url &&
      version == other.version &&
      contentHash == other.contentHash;
  @override
  int get hashCode => Object.hash(session, role, url, version, contentHash);
  @override
  String toString() => '公民资料图片';
}

/// 保护媒体统一沿现有会话和图片缓存读取；没有会话时保持占位，不直连网络。
class CitizenRemoteImage extends StatefulWidget {
  const CitizenRemoteImage({
    super.key,
    required this.url,
    this.role = 'post',
    this.expectedBytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });
  final String url, role;
  final int? expectedBytes;
  final BoxFit fit;
  final double? width, height;
  @override
  State<CitizenRemoteImage> createState() => _CitizenRemoteImageState();
}

class _CitizenRemoteImageState extends State<CitizenRemoteImage> {
  SquareApiClient? _client;
  bool _ownsClient = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_client == null) {
      _client = context.read<SquareApiClient?>();
      _ownsClient = _client == null;
      _client ??= SquareApiClient();
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SubscriptionService.currentSession;
    if (session == null) return const ColoredBox(color: Colors.transparent);
    return Image(
      image: _SignedProfileMediaImage(
        _client!,
        session,
        widget.url,
        widget.role,
        null,
        expectedBytes: widget.expectedBytes,
      ),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.transparent),
    );
  }
}

// 持久保存公开资料和媒体展示快照，协调本地读取及版本通知。

enum CitizenProfileLoadStatus {
  updated,
  unchanged,
  remoteMissing,
  remoteOlder,
  saveFailed,
}

/// 远端读取的有效资料与落盘结果；不进入资料正文或数据库表结构。
class CitizenProfileLoadResult {
  const CitizenProfileLoadResult(
    this.profile,
    this.status, {
    this.usedLocal = false,
  });

  final CitizenProfile profile;
  final CitizenProfileLoadStatus status;
  final bool usedLocal;

  bool get acceptedRemote =>
      status == CitizenProfileLoadStatus.updated ||
      status == CitizenProfileLoadStatus.unchanged;

  bool get hasWarning => status == CitizenProfileLoadStatus.saveFailed;

  String? get refreshMessage => switch (status) {
    CitizenProfileLoadStatus.remoteMissing ||
    CitizenProfileLoadStatus.remoteOlder => null,
    CitizenProfileLoadStatus.saveFailed => '资料已加载，本机保存失败，请重试',
    _ => '刷新完成',
  };
}

@immutable
class CitizenProfileRevisionEvent {
  const CitizenProfileRevisionEvent({
    required this.cidNumber,
    required this.revision,
  });
  final String cidNumber;
  final int revision;
}

/// 公开资料唯一持久存储入口。读取只访问本地，缺失不触发下载或身份验真。
/// 既有集合名保留以保存用户数据；记录没有TTL，也不作容量淘汰。
class CitizenProfileCache {
  const CitizenProfileCache();
  static final ValueNotifier<CitizenProfileRevisionEvent?> revision =
      ValueNotifier<CitizenProfileRevisionEvent?>(null);
  static int _revision = 0;
  static int _readSequence = 0;
  static final Map<String, ({int generation, int read})> _reads = {};

  /// 只用于本进程的请求排序；不进入资料正文、HTTP字段或Isar。
  static int readGeneration(String cid) => _reads[cid]?.generation ?? 0;
  static int beginRead(String cid) {
    final order = ++_readSequence;
    _reads[cid] = (generation: readGeneration(cid), read: order);
    return order;
  }

  static bool acceptsRead(String cid, int order) => _reads[cid]?.read == order;
  static void invalidateReads(String cid) {
    final order = ++_readSequence;
    _reads[cid] = (generation: order, read: order);
  }

  static const _updateFields = {
    'display_name',
    'profile_bio',
    'avatar_hash',
    'banner_hash',
  };

  /// 请求与选图先于远端PUT落盘；同CID只允许一个未完成修改。
  Future<void> prepareUpdate(
    String cidNumber, {
    required Map<String, String> request,
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
  }) async {
    final cid = _cid(cidNumber);
    final epoch = CitizenProfileMediaCache._epoch(cid);
    if (request.isEmpty ||
        request.keys.any((key) => !_updateFields.contains(key))) {
      throw ArgumentError('资料修改字段不合法');
    }
    final row = user_store.Edit()
      ..cidNumber = cid
      ..jobState = 'pending'
      ..requestData = jsonEncode(request)
      ..avatarBytes = Uint8List.fromList(avatarBytes ?? [])
      ..bannerBytes = Uint8List.fromList(bannerBytes ?? []);
    for (final role in ['avatar', 'banner']) {
      final bytes = role == 'avatar' ? row.avatarBytes : row.bannerBytes;
      if (bytes.isEmpty) {
        if (request.containsKey('${role}_hash')) {
          throw ArgumentError('修改图片必须持有完整字节');
        }
      } else {
        if (bytes.length > _limit(role) ||
            request['${role}_hash'] != sha256.convert(bytes).toString()) {
          throw ArgumentError('待保存图片声明不一致');
        }
        _contentType(bytes);
      }
    }
    row.contentHash = _updateHash(row);
    await UserIsar.instance.writeTxn((db) async {
      CitizenProfileMediaCache._check(cid, epoch);
      final old = await db.collection<user_store.Edit>().getByCidNumber(cid);
      if (old != null) {
        if (old.contentHash != row.contentHash) throw StateError('请先恢复上次资料修改');
        return;
      }
      await db.collection<user_store.Edit>().put(row);
    });
  }

  static String _updateHash(user_store.Edit row) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            row.cidNumber,
            row.requestData,
            sha256.convert(row.avatarBytes).toString(),
            sha256.convert(row.bannerBytes).toString(),
          ]),
        ),
      )
      .toString();

  Future<user_store.Edit?> readUpdate(String cidNumber) async {
    final cid = _cid(cidNumber);
    final row = await UserIsar.instance.read(
      (db) => db.collection<user_store.Edit>().getByCidNumber(cid),
    );
    if (row != null &&
        (row.cidNumber != cid ||
            row.contentHash != _updateHash(row) ||
            !{'pending', 'confirmed'}.contains(row.jobState) ||
            (row.jobState == 'confirmed' && row.responseData == null))) {
      throw StateError('资料恢复记录损坏');
    }
    if (row != null) {
      final request = jsonDecode(row.requestData);
      if (request is! Map<String, dynamic> ||
          request.isEmpty ||
          request.keys.any((key) => !_updateFields.contains(key))) {
        throw StateError('资料恢复字段无效');
      }
    }
    return row;
  }

  bool updateMatches(user_store.Edit row, CitizenProfile profile) {
    // 版本0是只读占位，不能证明这次修改已经写入R2。
    if (row.cidNumber != profile.cidNumber || profile.profileAt <= 0) {
      return false;
    }
    final request = jsonDecode(row.requestData) as Map<String, dynamic>;
    final actual = profile.toJson();
    return request.entries.every((entry) {
      if (!entry.key.endsWith('_hash')) return actual[entry.key] == entry.value;
      final role = entry.key.split('_').first;
      return actual['${role}_key'] == 'i/${row.cidNumber}/$role/${entry.value}';
    });
  }

  Future<void> confirmUpdate(CitizenProfile profile) async {
    final row = await readUpdate(profile.cidNumber ?? '');
    if (row == null || !updateMatches(row, profile)) {
      throw StateError('远端资料未确认本次修改');
    }
    final response = jsonEncode(profile.toJson());
    await UserIsar.instance.writeTxn((db) async {
      final current = await db.collection<user_store.Edit>().getByCidNumber(
        row.cidNumber,
      );
      if (current == null || current.contentHash != row.contentHash) {
        throw StateError('资料修改上下文已变化');
      }
      current
        ..jobState = 'confirmed'
        ..responseData = response;
      await db.collection<user_store.Edit>().put(current);
    });
  }

  /// 已确认修改只在本地收尾，资料、图片与恢复行删除同事务提交。
  Future<CitizenProfile> finishUpdate(String cidNumber) async {
    final row = await readUpdate(cidNumber);
    if (row == null || row.jobState != 'confirmed') {
      throw StateError('资料修改尚未确认');
    }
    final profile = CitizenProfile.fromJson(
      jsonDecode(row.responseData!) as Map<String, dynamic>,
    );
    if (!updateMatches(row, profile)) throw StateError('资料确认响应与请求不一致');
    final media = <user_store.ProfileMedia>[
      if (row.avatarBytes.isNotEmpty)
        CitizenProfileMediaCache._prepare(
          profile,
          'avatar',
          Uint8List.fromList(row.avatarBytes),
        ),
      if (row.bannerBytes.isNotEmpty)
        CitizenProfileMediaCache._prepare(
          profile,
          'banner',
          Uint8List.fromList(row.bannerBytes),
        ),
    ];
    await _commit(profile, media, completeUpdate: row);
    return profile;
  }

  static void _notify(String cid) {
    revision.value = CitizenProfileRevisionEvent(
      cidNumber: cid,
      revision: ++_revision,
    );
  }

  Future<CitizenProfile?> read(String cidNumber) async {
    if (cidNumber.trim().isEmpty) return null;
    final cid = _cid(cidNumber);
    final raw = await UserIsar.instance.read(
      (db) async => (await db.collection<user_store.Profile>().getByCidNumber(
        cid,
      ))?.profileData,
    );
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      // CID只存自然索引，正文出现第二份归属即拒绝；读取从不改写持久记录。
      if (decoded.containsKey('cid_number')) return null;
      final profile = CitizenProfile.fromJson({'cid_number': cid, ...decoded});
      if (profile.profileAt < 0) return null;
      return profile;
    } on FormatException {
      // 损坏记录保留，不将读取失败推断为注销，也不自动联网修复。
      return null;
    }
  }

  Future<void> write(CitizenProfile profile) async {
    if (profile is CitizenProfileCard) return; // 最小资料不能覆盖完整主页事实。
    if (profile.cidNumber == null || profile.cidNumber!.isEmpty) return;
    final cid = _cid(profile.cidNumber!);
    final epoch = CitizenProfileMediaCache._epoch(cid);
    await _commit(
      profile,
      const [],
      assertCurrent: () => CitizenProfileMediaCache._check(cid, epoch),
    );
  }

  /// 远端缺失/落后只决定展示资料，不是编辑提交成功，也不能删除或降级本地记录。
  static CitizenProfileLoadResult selectRemote(
    CitizenProfile? local,
    CitizenProfile remote,
  ) {
    final cid = _cid(remote.cidNumber ?? '');
    if (remote is CitizenProfileCard || remote.profileAt < 0) {
      throw ArgumentError('远端完整资料或版本无效');
    }
    if (local != null &&
        (local.cidNumber != cid ||
            local.profileAt < 0 ||
            local is CitizenProfileCard)) {
      throw StateError('本地资料归属或版本无效');
    }
    if (remote.profileAt == 0 ||
        local != null && local.profileAt > remote.profileAt) {
      // 资料正文按R2版本保留；SQL计数与关系独立，只取本次已鉴权响应。
      final effective = (local ?? remote).copyWith(
        following: remote.following,
        followers: remote.followers,
        mutualFollowing: remote.mutualFollowing,
        posts: remote.posts,
        campaigns: remote.campaigns,
        videos: remote.videos,
        articles: remote.articles,
        isFollowing: remote.isFollowing,
        isFollowedBy: remote.isFollowedBy,
        isNotifying: remote.isNotifying,
      );
      return CitizenProfileLoadResult(
        effective,
        remote.profileAt == 0
            ? CitizenProfileLoadStatus.remoteMissing
            : CitizenProfileLoadStatus.remoteOlder,
        usedLocal: local != null,
      );
    }
    return CitizenProfileLoadResult(
      remote,
      local != null && jsonEncode(local.toJson()) == jsonEncode(remote.toJson())
          ? CitizenProfileLoadStatus.unchanged
          : CitizenProfileLoadStatus.updated,
    );
  }

  /// 只供已通过服务端访问校验的读取；比较与保存共用一个事务，避免迟到结果覆盖新资料。
  Future<CitizenProfileLoadResult> receiveRemote(
    CitizenProfile remote, {
    required String expectedCid,
    void Function()? assertCurrent,
  }) async {
    final cid = _cid(expectedCid);
    if (remote.cidNumber != cid) throw StateError('远端资料归属不一致');
    selectRemote(null, remote);
    final epoch = CitizenProfileMediaCache._epoch(cid);
    void check() {
      CitizenProfileMediaCache._check(cid, epoch);
      assertCurrent?.call();
    }

    check();
    CitizenProfileLoadResult? selected;
    int? localVersion;
    var saved = false;
    try {
      final result = await UserIsar.instance.writeTxn((db) async {
        check();
        final row = await db.collection<user_store.Profile>().getByCidNumber(
          cid,
        );
        CitizenProfile? local;
        if (row != null) {
          final data = jsonDecode(row.profileData);
          if (data is! Map<String, dynamic> || data.containsKey('cid_number')) {
            throw const FormatException('本地资料记录无效');
          }
          local = CitizenProfile.fromJson({'cid_number': cid, ...data});
          localVersion = local.profileAt;
        }
        final decision = selectRemote(local, remote);
        selected = decision;
        // SQL社交事实独立于资料版本；保存已选择的完整结果，保留较新的正文及图片引用。
        if (decision.status == CitizenProfileLoadStatus.updated ||
            local != null &&
                jsonEncode(local.toJson()) !=
                    jsonEncode(decision.profile.toJson())) {
          saved = true;
          await db.collection<user_store.Profile>().putByCidNumber(
            user_store.Profile()
              ..cidNumber = cid
              ..profileData = jsonEncode(
                decision.profile.toJson()..remove('cid_number'),
              ),
          );
        }
        check();
        return decision;
      });
      check();
      if (saved) _notify(cid);
      AppLog.profileLoadResult(
        state: result.status.name,
        localVersion: localVersion,
        remoteVersion: remote.profileAt,
      );
      return result;
    } catch (error, stackTrace) {
      // 身份失效/显式擦除必须继续失败，不能被“本机保存失败”掩盖。
      check();
      AppLog.profileLoadFailure(
        stage: 'cache_write',
        error: error,
        stackTrace: stackTrace,
      );
      return CitizenProfileLoadResult(
        selected?.profile ?? remote,
        CitizenProfileLoadStatus.saveFailed,
        usedLocal: selected?.usedLocal ?? false,
      );
    }
  }

  /// 资料编辑唯一提交入口；所有字节校验完成后才进入原子事务。
  Future<void> writeWithMedia(
    CitizenProfile profile, {
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
  }) async {
    final cid = _cid(profile.cidNumber ?? '');
    final epoch = CitizenProfileMediaCache._epoch(cid);
    final rows = <user_store.ProfileMedia>[
      if (avatarBytes != null)
        CitizenProfileMediaCache._prepare(profile, 'avatar', avatarBytes),
      if (bannerBytes != null)
        CitizenProfileMediaCache._prepare(profile, 'banner', bannerBytes),
    ];
    await _commit(
      profile,
      rows,
      assertCurrent: () => CitizenProfileMediaCache._check(cid, epoch),
    );
  }

  /// 媒体在事务外校验；完整资料及本次所选图片只提交一次，再通知展示端。
  static Future<void> _commit(
    CitizenProfile profile,
    List<user_store.ProfileMedia> media, {
    void Function()? assertCurrent,
    user_store.Edit? completeUpdate,
  }) async {
    final cid = _cid(profile.cidNumber ?? '');
    if (profile.profileAt < 0) throw ArgumentError('资料版本无效');
    final response = jsonEncode(profile.toJson());
    final body = profile.toJson()..remove('cid_number');
    final payload = jsonEncode(body);
    final changed = await UserIsar.instance.writeTxn((db) async {
      assertCurrent?.call();
      if (completeUpdate != null) {
        final row = await db.collection<user_store.Edit>().getByCidNumber(cid);
        if (row == null ||
            row.contentHash != completeUpdate.contentHash ||
            row.jobState != 'confirmed' ||
            row.responseData != response) {
          throw StateError('资料恢复事实已变化');
        }
      }
      final current = await db.collection<user_store.Profile>().getByCidNumber(
        cid,
      );
      if (current != null) {
        final data = jsonDecode(current.profileData) as Map<String, dynamic>;
        if (data.containsKey('cid_number')) throw StateError('本地资料归属重复');
        final old = CitizenProfile.fromJson({'cid_number': cid, ...data});
        if (old.profileAt > profile.profileAt) {
          final error = StateError('旧资料不能覆盖较新的本地版本');
          AppLog.profileLoadFailure(
            stage: 'cache_version',
            error: error,
            stackTrace: StackTrace.current,
            localVersion: old.profileAt,
            remoteVersion: profile.profileAt,
          );
          throw error;
        }
      }
      var changed = current?.profileData != payload;
      for (final row in media) {
        if (row.cidNumber != cid ||
            row.profileAt != profile.profileAt ||
            row.objectKey != _objectKey(profile, row.mediaRole)) {
          throw StateError('资料媒体与当前资料归属不一致');
        }
        changed = await CitizenProfileMediaCache._put(db, row) || changed;
      }
      if (current?.profileData != payload) {
        await db.collection<user_store.Profile>().putByCidNumber(
          user_store.Profile()
            ..cidNumber = cid
            ..profileData = payload,
        );
      }
      assertCurrent?.call();
      if (completeUpdate != null) {
        await db.collection<user_store.Edit>().delete(completeUpdate.rowId);
      }
      // 与资料提交串行：已有GET即使稍后返回也不能覆盖本次已确认写入。
      invalidateReads(cid);
      return changed;
    });
    if (changed) _notify(cid);
  }

  /// 显式删除只处理指定CID，同时删除所属图片；迟到下载不得复活已删除资料。
  Future<void> clear(String cidNumber) async {
    if (cidNumber.trim().isEmpty) return;
    final cid = _cid(cidNumber);
    CitizenProfileMediaCache._invalidate(cid);
    invalidateReads(cid);
    final changed = await UserIsar.instance.writeTxn((db) async {
      final removed = await db
          .collection<user_store.Profile>()
          .deleteByCidNumber(cid);
      await db.collection<user_store.Edit>().deleteByCidNumber(cid);
      final images = await db
          .collection<user_store.ProfileMedia>()
          .filter()
          .cidNumberEqualTo(cid)
          .deleteAll();
      return removed || images != 0;
    });
    if (changed) _notify(cid);
  }
}

@immutable
class CitizenProfileMediaSnapshot {
  const CitizenProfileMediaSnapshot({this.avatarPath, this.bannerPath});

  /// 当前展示的可再生临时文件，持久字节及归属只在UserIsar。
  final String? avatarPath;
  final String? bannerPath;
}

/// UserIsar资料图片唯一读写入口，按CID、用途、版本分条保存完整字节。
/// 网络、哈希和文件操作均在数据库事务外，普通read绝不联网。
class CitizenProfileMediaCache {
  CitizenProfileMediaCache({
    Future<Directory> Function()? supportDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ??
           supportDirectoryProvider ??
           getTemporaryDirectory;

  final Future<Directory> Function() _supportDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  /// 与持久资料图片复用原大小边界，网络ImageProvider不能另建额度值。
  static int maxBytesFor(String role) => _limit(role);
  static int _generation = 0;
  static final Map<String, int> _cidGenerations = {};
  static void _invalidate(String cid) =>
      _cidGenerations[cid] = (_cidGenerations[cid] ?? 0) + 1;
  static String _epoch(String cid) =>
      '$_generation-${_cidGenerations[cid] ?? 0}';
  static void _check(String cid, String epoch) {
    if (_epoch(cid) != epoch) throw StateError('用户资料已清除，拒绝迟到结果');
  }

  Future<void> clearCid(String cidNumber) async {
    final cid = _cid(cidNumber);
    _invalidate(cid);
    await UserIsar.instance.writeTxn((db) async {
      await db
          .collection<user_store.ProfileMedia>()
          .filter()
          .cidNumberEqualTo(cid)
          .deleteAll();
    });
    await _deleteExactTree(p.join((await _mediaRoot()).path, _cidHash(cid)));
    await _deleteExactTree(p.join((await _workRoot()).path, _cidHash(cid)));
    CitizenProfileCache._notify(cid);
  }

  /// AppLock先关闭并擦除UserIsar，再清除临时域；这里不重新打开数据库。
  /// 代次检查阻止此前下载或文件写入在擦除后复活用户图片。
  Future<void> closeAndDeleteAll() async {
    _generation++;
    await _deleteExactTree((await _mediaRoot()).path);
    await _deleteExactTree((await _workRoot()).path);
  }

  Future<CitizenProfileMediaSnapshot> read(CitizenProfile profile) async {
    if (profile.cidNumber == null || profile.cidNumber!.isEmpty) {
      return const CitizenProfileMediaSnapshot();
    }
    final cid = _cid(profile.cidNumber ?? '');
    final epoch = _epoch(cid);
    final avatar = await _readBest(profile, 'avatar', epoch);
    final banner = await _readBest(profile, 'banner', epoch);
    _check(cid, epoch);
    return CitizenProfileMediaSnapshot(avatarPath: avatar, bannerPath: banner);
  }

  /// 编辑成功已有原始字节，资料和图片同事务提交，不下载已持有的图片。
  Future<CitizenProfileMediaSnapshot> rememberSelected({
    required CitizenProfile profile,
    Uint8List? avatarBytes,
    Uint8List? bannerBytes,
  }) async {
    await const CitizenProfileCache().writeWithMedia(
      profile,
      avatarBytes: avatarBytes,
      bannerBytes: bannerBytes,
    );
    return read(profile);
  }

  /// 只由显式远端操作调用；下载有长度上限，失败保留已有数据库图片。
  Future<CitizenProfileMediaSnapshot> refresh({
    required CitizenProfile profile,
    required String? avatarUrl,
    required String? bannerUrl,
    required http.Client client,
  }) async {
    final cid = _cid(profile.cidNumber ?? '');
    final epoch = _epoch(cid);
    for (final entry in {'avatar': avatarUrl, 'banner': bannerUrl}.entries) {
      final role = entry.key;
      final url = entry.value;
      if (_objectKey(profile, role) == null || url == null || url.isEmpty) {
        continue;
      }
      if (await _exact(profile, role) != null) continue;
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw ArgumentError('资料图片地址必须使用HTTPS');
      }
      try {
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          await response.stream.listen(null).cancel();
          continue;
        }
        final limit = _limit(role);
        if ((response.contentLength ?? 0) > limit) {
          await response.stream.listen(null).cancel();
          continue;
        }
        final output = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          if (output.length + chunk.length > limit) {
            throw const FormatException('资料图片超出大小限制');
          }
          output.add(chunk);
        }
        final row = _prepare(profile, role, output.takeBytes());
        final changed = await UserIsar.instance.writeTxn((db) async {
          _check(cid, epoch);
          return _put(db, row);
        });
        if (changed) CitizenProfileCache._notify(cid);
      } on Exception {
        // 下载失败不修改旧字节，不能由网络错误推断云端已删除。
      }
    }
    _check(cid, epoch);
    return read(profile);
  }

  static user_store.ProfileMedia _prepare(
    CitizenProfile profile,
    String role,
    Uint8List input,
  ) {
    final cid = _cid(profile.cidNumber ?? '');
    final key = _objectKey(profile, role);
    if (key == null || profile.profileAt < 0) {
      throw ArgumentError('资料图片缺少归属或版本');
    }
    // 复制后计算摘要，防止调用方修改缓冲区导致入库字节与哈希不一致。
    final bytes = Uint8List.fromList(input);
    if (bytes.isEmpty || bytes.length > _limit(role)) {
      throw const FormatException('资料图片大小无效');
    }
    _contentType(bytes);
    return user_store.ProfileMedia()
      ..cidNumber = cid
      ..mediaRole = role
      ..objectKey = key
      ..profileAt = profile.profileAt
      ..bodyHash = sha256.convert(bytes).toString()
      ..mediaBytes = bytes;
  }

  /// 已处于User写事务；调用方先在事务外校验字节，同版本只接受完全相同的内容。
  static Future<bool> _put(Isar db, user_store.ProfileMedia row) async {
    final previous = await db
        .collection<user_store.ProfileMedia>()
        .getByCidNumberMediaRoleProfileAt(
          row.cidNumber,
          row.mediaRole,
          row.profileAt,
        );
    if (previous != null) {
      if (previous.bodyHash != row.bodyHash ||
          previous.objectKey != row.objectKey ||
          previous.profileAt != row.profileAt ||
          !listEquals(previous.mediaBytes, row.mediaBytes)) {
        throw StateError('同一资料图片版本的内容冲突，保留原记录');
      }
      return false;
    }
    row.rowId = Isar.autoIncrement;
    await db.collection<user_store.ProfileMedia>().put(row);
    return true;
  }

  Future<user_store.ProfileMedia?> _exact(
    CitizenProfile profile,
    String role,
  ) async {
    final cid = _cid(profile.cidNumber ?? '');
    final row = await UserIsar.instance.read(
      (db) => db
          .collection<user_store.ProfileMedia>()
          .getByCidNumberMediaRoleProfileAt(cid, role, profile.profileAt),
    );
    if (row != null) {
      _validate(row, cid, role);
      if (row.objectKey != _objectKey(profile, role)) {
        throw StateError('同一资料版本的对象归属冲突');
      }
    }
    return row;
  }

  static void _validate(user_store.ProfileMedia row, String cid, String role) {
    if (row.cidNumber != cid ||
        row.mediaRole != role ||
        row.profileAt < 0 ||
        row.mediaBytes.isEmpty ||
        row.mediaBytes.length > _limit(role) ||
        sha256.convert(row.mediaBytes).toString() != row.bodyHash) {
      throw StateError('本地资料图片归属或完整性校验失败');
    }
    _contentType(row.mediaBytes);
  }

  Future<String?> _readBest(
    CitizenProfile profile,
    String role,
    String epoch,
  ) async {
    final cid = _cid(profile.cidNumber ?? '');
    if (_objectKey(profile, role) == null) return null;
    var row = await _exact(profile, role);
    // 刷新失败可显示同CID已有图片，但不把它登记为新版本下载成功。
    row ??= await UserIsar.instance.read(
      (db) => db
          .collection<user_store.ProfileMedia>()
          .filter()
          .cidNumberEqualTo(cid)
          .mediaRoleEqualTo(role)
          .profileAtLessThan(profile.profileAt, include: true)
          .sortByProfileAtDesc()
          .findFirst(),
    );
    if (row == null) return null;
    _validate(row, cid, role);
    _check(cid, epoch);
    final root = await _workRoot(create: true);
    final owner = await _directory(
      p.join(root.path, _cidHash(cid)),
      create: true,
    );
    final dir = await _directory(p.join(owner.path, epoch), create: true);
    final target = File(p.join(dir.path, '${row.mediaRole}_${row.rowId}'));
    Directory? staging;
    try {
      _check(cid, epoch);
      final type = await FileSystemEntity.type(target.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('资料临时文件不是普通文件');
      }
      if (type == FileSystemEntityType.notFound ||
          await target.length() != row.mediaBytes.length ||
          sha256.convert(await target.readAsBytes()).toString() !=
              row.bodyHash) {
        // 同一图片可被多个页面同时读取，用独立临时文件原子替换，避免显示半份字节。
        staging = await dir.createTemp('writing-');
        final temporary = File(p.join(staging.path, 'image'));
        await temporary.writeAsBytes(row.mediaBytes, flush: true);
        _check(cid, epoch);
        await temporary.rename(target.path);
      }
      _check(cid, epoch);
      return target.path;
    } catch (_) {
      if (_epoch(cid) != epoch && await target.exists()) await target.delete();
      rethrow;
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  /// 安全擦除仍覆盖既有持久媒体目录；不读取、导入或改写旧格式。
  Future<Directory> _mediaRoot() async {
    final parent = await _supportDirectoryProvider();
    final user = await _directory(p.join(parent.path, 'user'), create: false);
    return _directory(p.join(user.path, 'profile_media'), create: false);
  }

  Future<Directory> _workRoot({bool create = false}) async {
    final parent = await _temporaryDirectoryProvider();
    return _directory(
      p.join(parent.path, 'profile_media_work'),
      create: create,
    );
  }

  static Future<Directory> _directory(
    String path, {
    required bool create,
  }) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw StateError('资料媒体目录类型异常');
    }
    final dir = Directory(path);
    if (create && type == FileSystemEntityType.notFound) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _deleteExactTree(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  }
}

String _cid(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      utf8.encode(value).length > 32) {
    throw ArgumentError('资料CID无效');
  }
  return value;
}

String _cidHash(String cid) => sha256.convert(utf8.encode(cid)).toString();
int _limit(String role) => switch (role) {
  'avatar' => 512 * 1024,
  'banner' => 1536 * 1024,
  _ => throw ArgumentError('资料媒体用途无效'),
};
String? _objectKey(CitizenProfile profile, String role) {
  _limit(role);
  final key = role == 'avatar' ? profile.avatarKey : profile.bannerKey;
  return key == null || key.trim().isEmpty ? null : key.trim();
}

/// 只接受现有选图链路输出的PNG/JPEG/WebP，类型不取自URL扩展名或响应声明。
String _contentType(List<int> bytes) {
  if (bytes.length >= 8 &&
      listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10])) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  throw const FormatException('资料图片格式不支持');
}

// 计算头像背景摘要，申请上传授权并核对R2对象回执。

class ProfileAssetResult {
  const ProfileAssetResult({required this.contentHash, required this.bytes});

  final String contentHash;
  final Uint8List bytes;
}

/// 头像/背景资产上传编排：算 sha256 → 申请授权 → PUT 字节 → 核对对象键并返回原摘要。
/// 内容只进 R2，不上链。
class ProfileAssetService {
  ProfileAssetService({
    SquareApiClient? client,
    Future<Uint8List> Function(Uint8List, int, int, int)? compress,
  }) : _assetClient = client ?? SquareApiClient(),
       _compress = compress ?? _compressWebp;
  final Future<Uint8List> Function(Uint8List, int, int, int) _compress;
  static Future<Uint8List> _compressWebp(
    Uint8List bytes,
    int width,
    int height,
    int quality,
  ) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: width,
    minHeight: height,
    quality: quality,
    format: CompressFormat.webp,
    keepExif: false,
  );

  final SquareApiClient _assetClient;

  Future<ProfileAssetResult> upload({
    required SquareSession session,
    required String uploadKind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!const {'avatar', 'banner'}.contains(uploadKind)) {
      throw const SquarePreflightException('资料图片类型无效', 'invalid_profile_kind');
    }
    final rules = SubscriptionService.resourceGate.profileMedia(
      _assetClient.baseUri.origin,
      session,
    );
    final maxBytes = rules?['${uploadKind}_bytes'];
    if (maxBytes is! int ||
        maxBytes <= 0 ||
        rules?['content_type'] != 'image/webp') {
      throw const SquarePreflightException(
        '资料媒体规格暂不可用，请稍后重试',
        'profile_media_unavailable',
      );
    }
    if (bytes.isEmpty) {
      throw const SquarePreflightException('资料图片不能为空', 'invalid_profile_media');
    }
    if (contentType != 'image/webp' || bytes.length > maxBytes) {
      final source = bytes;
      Uint8List? compressed;
      for (final quality in [75, 60, 45, 30]) {
        final candidate = await _compress(
          source,
          uploadKind == 'avatar' ? 1024 : 1920,
          uploadKind == 'avatar' ? 1024 : 720,
          quality,
        );
        if (candidate.isNotEmpty && candidate.length <= maxBytes) {
          compressed = candidate;
          break;
        }
      }
      if (compressed == null) {
        throw const SquarePreflightException(
          '资料图片压缩后仍超出上限',
          'profile_media_limit',
        );
      }
      bytes = compressed;
      contentType = 'image/webp';
    }
    await session.validateCurrent();
    final sha = sha256.convert(bytes).toString();
    final prepared = await _assetClient.prepareProfileAsset(
      session: session,
      uploadKind: uploadKind,
      contentType: contentType,
      byteSize: bytes.length,
      contentHash: sha,
    );
    await _assetClient.uploadProfileAsset(
      prepared.uploadUrl,
      bytes,
      contentType,
      session: session,
      objectKey: prepared.objectKey,
    );
    return ProfileAssetResult(contentHash: sha, bytes: bytes);
  }
}

// 从永久CID稳定派生缺失资料的展示值，不用于授权或持久资料。

/// 用户公开资料缺失时的唯一展示规则。
///
/// 默认昵称、头像和背景由永久 CID 稳定派生；无 CID 的访客才用当前账户兜底。
/// 这些展示值不持久化、不上传，也不参与身份或权限判断。
class ProfilePresentation {
  const ProfilePresentation._({
    required this.identityKey,
    required this.fallbackName,
    required this.avatarAsset,
    required this.bannerAsset,
  });

  /// 永久 CID；仅未注册访客允许传当前 `account_id` 作为稳定兜底。
  final String identityKey;
  final String fallbackName;
  final String avatarAsset;
  final String bannerAsset;

  static final RegExp _addressLikePattern = RegExp(
    r'^[1-9A-HJ-NP-Za-km-z]{40,64}$',
  );

  static const List<String> _namePrefixes = <String>[
    '晨光',
    '青松',
    '星河',
    '云海',
    '远山',
    '清风',
    '春雨',
    '秋叶',
    '白露',
    '暖阳',
    '碧海',
    '长空',
    '新月',
    '流云',
    '萤火',
    '曙光',
    '南风',
    '北辰',
    '夏木',
    '冬雪',
  ];

  static const List<String> _nameSuffixes = <String>[
    '旅人',
    '行者',
    '朋友',
    '伙伴',
    '邻居',
    '来客',
    '信使',
    '守望者',
    '探索者',
    '漫游者',
    '远客',
    '听风者',
    '逐光者',
    '观星者',
    '寻路者',
    '拾光者',
    '筑梦者',
    '摆渡人',
    '追云者',
    '望山人',
  ];

  /// 用户指定的本地图片池；头像和背景共用资源，但按不同盐值选图。
  static const List<String> assets = <String>[
    'packages/citizen_assets/profiles/xiserge-silver-gull-7787328_1280.jpg',
    'packages/citizen_assets/profiles/paul_reuss-patagonia-10020972_1280.jpg',
    'packages/citizen_assets/profiles/anneef-meadow-10272037_1280.jpg',
    'packages/citizen_assets/profiles/arweltatty-lonely-tree-10293271_1280.jpg',
    'packages/citizen_assets/profiles/ahmetyuksek-prague-10204909_1280.jpg',
    'packages/citizen_assets/profiles/bluestone-canadian-rockies-9855618_1280.jpg',
    'packages/citizen_assets/profiles/wal_172619-ferris-wheel-10340490_1280.jpg',
    'packages/citizen_assets/profiles/nunziog666-lake-10349715_1280.jpg',
    'packages/citizen_assets/profiles/wj_y2017fufu-mountain-9784922_1280.jpg',
    'packages/citizen_assets/profiles/nunziog666-banff-10349707_1920.jpg',
    'packages/citizen_assets/profiles/couleur-tomatoes-10368988_1280.jpg',
  ];

  factory ProfilePresentation.forIdentityKey(String identityKey) {
    identityKey = identityKey.trim();
    // 空身份键只用于页面尚未完成加载时的稳定占位，不代表真实用户。
    final seed = identityKey.isEmpty
        ? 'citizenapp-default-profile'
        : identityKey;
    final namePrefix = _stableHash(seed, 0x4e414d45) % _namePrefixes.length;
    final nameSuffix = _stableHash(seed, 0x4e49434b) % _nameSuffixes.length;
    final avatarIndex = _stableHash(seed, 0x41564154) % assets.length;
    var bannerIndex = _stableHash(seed, 0x42414e4e) % assets.length;
    if (bannerIndex == avatarIndex) {
      bannerIndex = (bannerIndex + 1) % assets.length;
    }
    return ProfilePresentation._(
      identityKey: identityKey,
      fallbackName: '${_namePrefixes[namePrefix]}${_nameSuffixes[nameSuffix]}',
      avatarAsset: assets[avatarIndex],
      bannerAsset: assets[bannerIndex],
    );
  }

  /// 公开昵称唯一真源是 `display_name`；缺失时使用稳定默认昵称。
  ///
  /// 本机钱包名不得传入本方法。任何账户本身或截断账户也不会被接受为昵称。
  String resolveDisplayName({String? publicName}) {
    final normalized = publicName?.trim() ?? '';
    if (normalized.isNotEmpty && !_isIdentityOrAccountDerived(normalized)) {
      return normalized;
    }
    return fallbackName;
  }

  bool _isIdentityOrAccountDerived(String candidate) {
    if (isCitizenAccountId(candidate) ||
        _addressLikePattern.hasMatch(candidate)) {
      return true;
    }
    if (identityKey.isEmpty) return false;
    if (candidate == identityKey) return true;
    if (identityKey.length <= 12) return false;
    final prefix = identityKey.substring(0, 6);
    final suffix = identityKey.substring(identityKey.length - 6);
    return candidate == '$prefix...$suffix' || candidate == '$prefix…$suffix';
  }

  /// FNV-1a 32 位哈希只用于稳定分桶，不承担密码学安全职责。
  static int _stableHash(String value, int salt) {
    var hash = (0x811c9dc5 ^ salt) & 0xffffffff;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

// 提交或恢复注销，取得云端真实完成后逐项清理本地数据。

/// 注销用户编排：签名提交或恢复查询 → 云端真实完成 → 逐项清理本地。
///
/// 顺序钉死：**先取得服务端完成回执**（op_tag 0x1D 主钥签名；失败即上抛、绝不清本地，
/// 保证「服务端没删就别动本地」的一致性），**成功后再清本地**（资料缓存 / 会话缓存 /
/// 本人广场副本与检查点 / SDK所属MLS身份与私信历史）。
/// 钱包与链上身份不受影响。
class SquareAccountLocalCleanupException implements Exception {
  const SquareAccountLocalCleanupException(this.failures);

  final List<String> failures;

  @override
  String toString() => '服务端已注销，但本机清理未完成：${failures.join('；')}';
}

class SquareAccountDeletionService {
  SquareAccountDeletionService({
    required Future<void> Function({
      required String userId,
      required String accountId,
    })
    clearChatHistory,
    SquareApiClient? apiClient,
    CitizenProfileCache? profileCache,
    CitizenProfileMediaCache? profileMediaCache,
    SquareLocalPostBulkDeletionStore? localPostStore,
  }) : _api = apiClient ?? SquareApiClient(),
       _profileCache = profileCache ?? const CitizenProfileCache(),
       _profileMediaCache = profileMediaCache ?? CitizenProfileMediaCache(),
       _clearChatHistory = clearChatHistory,
       _accountPostStore = localPostStore ?? const SquarePostStore();

  final SquareApiClient _api;
  final CitizenProfileCache _profileCache;
  final CitizenProfileMediaCache _profileMediaCache;
  final Future<void> Function({
    required String userId,
    required String accountId,
  })
  _clearChatHistory;
  final SquareLocalPostBulkDeletionStore _accountPostStore;

  /// [signAction] 对 signing_message(0x1D) 摘要用 sr25519 主钥签名（弹生物识别）。
  Future<void> deleteAccount({
    required IdentityBinding binding,
    Future<void> Function()? requireCurrent,
    required SquareActionSigner signAction,
  }) async {
    // 1. 服务端完成确认（失败或pending上抛 → 本地一律不动，UI/数据保持一致）。
    await _api.deleteAccount(
      binding: binding,
      signAction: signAction,
      requireCurrent: requireCurrent,
    );
    final cidNumber = binding.cidNumber;
    final accountId = binding.accountId;
    // 2. 服务端确认后逐项清本地。单项失败不能阻断后续项，否则会制造更多残留。
    final failures = <String>[];
    Future<void> attempt(String label, Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error) {
        failures.add('$label：$error');
      }
    }

    await attempt('广场本人副本', () async {
      await _accountPostStore.deleteAllByCid(cidNumber);
    });
    // 资料缓存的唯一键是 cid_number；account_id 只清理账户级会话与 Chat 数据。
    await attempt('资料缓存', () => _profileCache.clear(cidNumber));
    await attempt('资料图片缓存', () => _profileMediaCache.clearCid(cidNumber));
    await attempt('会话缓存', () async => _api.clearSession(accountId));
    await attempt(
      '私信历史',
      () => _clearChatHistory(userId: cidNumber, accountId: accountId),
    );

    if (failures.isNotEmpty) {
      throw SquareAccountLocalCleanupException(
        List<String>.unmodifiable(failures),
      );
    }
  }
}
