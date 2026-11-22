// 聚合主页、作者帖子和资料更新，按每次入口独立检查访问权限。

import 'package:citizen_square/media/square_media_policy.dart';

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_system/app_log.dart';

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
            now - previous < entryRefreshInterval.inMilliseconds)
          return null;
        if (!(isCurrentIdentity?.call() ?? true)) return null;
        if (!await prefs.setInt(key, now)) throw StateError('自动刷新限速记录保存失败');
        final resolution = await sessions.resolveSession();
        final session = resolution.session;
        if (!(isCurrentIdentity?.call() ?? true) ||
            session == null ||
            session.cidNumber != binding.cidNumber ||
            session.accountId != binding.accountId ||
            session.bindRev != binding.bindRev)
          throw StateError('主页刷新身份尚未就绪');
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
      result = await target.receiveRemote(remote, expectedCid: cidNumber, assertCurrent: checkRead);
    } catch (_) {
      check();
      if (CitizenProfileCache.acceptsRead(cidNumber, order)) rethrow;
      final local = await target.read(cidNumber);
      await session.validateCurrent();
      check();
      if (local == null) rethrow;
      // 迟到结果只返回当前本地快照，不落盘、不刷新旧图片或新增提示。
      return CitizenProfileLoadResult(local, CitizenProfileLoadStatus.unchanged, usedLocal: true);
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
