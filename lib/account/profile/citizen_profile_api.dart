import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/account/profile/citizen_profile.dart';
import 'package:citizenapp/account/profile/citizen_profile_cache.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/8964/feed/square_post_store.dart';

/// 用户主页数据层门面：把主页资料、按作者拉帖、更新资料收敛到一个入口。
///
/// 网络细节（登录态、解析、Worker 地址）复用 [SquareApiClient]，本类只做语义聚合。
class CitizenProfileApi {
  CitizenProfileApi({SquareApiClient? client, SquarePostStore? localPostStore})
    : _client = client ?? SquareApiClient(),
      _localPostStore = localPostStore ?? const SquarePostStore();

  final SquareApiClient _client;
  final SquarePostStore _localPostStore;
  static final Map<String, Future<CitizenProfile>> _refreshes = {};
  static final Map<String, String> _refreshBindings = {};

  /// 页面显式刷新专用；普通页面读取只调用本地仓库。跨实例合并同CID、同绑定请求。
  Future<CitizenProfile> refreshProfile(
    String cidNumber, {
    required SquareSession session,
    required bool userInitiated,
    bool Function()? isCurrent,
  }) {
    if (!userInitiated) throw StateError('普通加载不得刷新远端资料');
    final binding =
        '${session.cidNumber}:${session.accountId}:${session.bindingRevision}';
    void check() {
      if (!session.isUsable || !(isCurrent?.call() ?? true)) {
        throw StateError('资料刷新身份已变化');
      }
    }

    check();
    final running = _refreshes[cidNumber];
    if (running != null) {
      if (_refreshBindings[cidNumber] != binding) {
        throw StateError('不能共用旧身份的资料刷新');
      }
      return running;
    }
    _refreshBindings[cidNumber] = binding;
    late final Future<CitizenProfile> task;
    task = Future<CitizenProfile>.microtask(() async {
      try {
        final profile = await fetchProfile(cidNumber, session: session);
        check();
        if (profile.cidNumber != cidNumber) throw StateError('远端资料归属不一致');
        final mediaClient = _client.profileMediaClient(session);
        try {
          await CitizenProfileMediaCache(client: mediaClient).refresh(
            profile: profile,
            avatarUrl: profile.avatarObjectKey == null
                ? null
                : mediaUrl(
                    profile.avatarObjectKey!,
                    updatedAt: profile.updatedAt,
                  ),
            bannerUrl: profile.bannerObjectKey == null
                ? null
                : mediaUrl(
                    profile.bannerObjectKey!,
                    updatedAt: profile.updatedAt,
                  ),
            headers: null,
          );
        } finally {
          mediaClient.close();
        }
        check();
        await const CitizenProfileCache().write(profile);
        return profile;
      } finally {
        if (identical(_refreshes[cidNumber], task)) {
          _refreshes.remove(cidNumber);
          _refreshBindings.remove(cidNumber);
        }
      }
    });
    _refreshes[cidNumber] = task;
    return task;
  }

  /// R2 object_key → 钱包 session 保护的资料媒体 URL。
  String mediaUrl(String objectKey, {int? updatedAt}) =>
      _client.mediaUrl(objectKey, updatedAt: updatedAt);

  /// 只替换完整资料图片的数据获取；每次实际加载都经逐请求签名传输。
  /// 缓存键按当前会话对象隔离，证明/会话令牌不进入键的诊断文本。
  ImageProvider mediaImage(
    String objectKey, {
    required SquareSession session,
    int? updatedAt,
  }) {
    final url = mediaUrl(objectKey, updatedAt: updatedAt);
    return _SignedProfileMediaImage(
      _client,
      session,
      url,
      objectKey.split('/').last,
      updatedAt,
    );
  }

  Future<CitizenProfileCard> fetchCard(
    String cidNumber, {
    SquareSession? session,
  }) => _client.fetchUserCard(cidNumber: cidNumber, session: session);

  String cardMediaUrl(String objectKey, {int? updatedAt}) {
    final parts = objectKey.split('/');
    if (parts.length != 3 || parts[0] != 'profile' || parts[2] != 'avatar') {
      throw const SquareApiException('聊天资料卡只能读取头像');
    }
    return _client.cardAvatarUrl(parts[1]);
  }

  /// 拉取主页资料（按身份主键 cid_number）；[session] 存在时响应附带 is_following。
  Future<CitizenProfile> fetchProfile(
    String cidNumber, {
    SquareSession? session,
  }) {
    return _client.fetchUserProfile(cidNumber: cidNumber, session: session);
  }

  /// 按作者身份主键 cid_number 分页拉帖；[postType] 由 Worker 在分页前过滤。
  Future<({List<SquarePost> posts, int? nextCursor})> fetchAuthorPosts(
    String cidNumber, {
    SquarePostCategory? category,
    SquarePostType? postType,
    int limit = 20,
    int? cursor,
    SquareSession? session,
  }) {
    return _client.fetchAuthorPosts(
      cidNumber: cidNumber,
      category: category,
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
    required String followedCidNumber,
  }) {
    return _client.followUser(
      session: session,
      followedCidNumber: followedCidNumber,
    );
  }

  /// 取消关注一个身份（目标身份主键 cid_number）。
  Future<void> unfollowUser({
    required SquareSession session,
    required String followedCidNumber,
  }) {
    return _client.unfollowUser(
      session: session,
      followedCidNumber: followedCidNumber,
    );
  }

  /// 开/关对某关注的发帖通知（须已关注；目标身份主键 cid_number）。
  Future<void> setNotify({
    required SquareSession session,
    required String followedCidNumber,
    required bool enabled,
  }) {
    return _client.setNotify(
      session: session,
      followedCidNumber: followedCidNumber,
      enabled: enabled,
    );
  }

  /// 拉取关注、关注者或互关列表（目标身份主键 cid_number；列表项也是 cid_number）。
  Future<({List<SquareFollowEntry> entries, int? nextCursor})> fetchFollows(
    String cidNumber, {
    required String type,
    int limit = 20,
    int? cursor,
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
    String? bio,
    String? avatarObjectKey,
    String? avatarContentHash,
    String? bannerObjectKey,
    String? bannerContentHash,
  }) {
    return _client.updateProfile(
      session: session,
      displayName: displayName,
      bio: bio,
      avatarObjectKey: avatarObjectKey,
      avatarContentHash: avatarContentHash,
      bannerObjectKey: bannerObjectKey,
      bannerContentHash: bannerContentHash,
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
    this.version,
  );
  final SquareApiClient client;
  final SquareSession session;
  final String url;
  final String role;
  final int? version;
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
      final response = await client.openProfileMedia(url, session: session);
      final limit = CitizenProfileMediaCache.maxBytesFor(role);
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
      url == other.url &&
      version == other.version;
  @override
  int get hashCode => Object.hash(session, url, version);
  @override
  String toString() => '公民资料图片';
}
