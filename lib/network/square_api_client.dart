import 'package:citizenapp/network/citizen_serve_api_config.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:citizenapp/app_log.dart';
import 'package:citizenapp/network/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'package:citizenapp/8964/feed/square_models.dart';
import 'package:citizenapp/account/profile/citizen_profile.dart';
import 'package:citizenapp/8964/feed/square_post_store.dart';
import 'package:citizenapp/network/hex_codec.dart' show bytesToHex, hexToBytes;
import 'package:citizenapp/account/identity/mls_authentication.dart';
import 'package:citizenapp/account/identity/identity_binding.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:crypto/crypto.dart' show sha256;
import 'package:citizenapp/network/square_request_signer.dart';
import 'package:citizenapp/system/notifications/app_push_token.dart';

/// 仅记录产品固定请求阶段，禁止将URL、账户或请求正文当成诊断字段。
enum SquareApiStage {
  identity,
  challenge,
  proof,
  registration,
  session,
  request,
}

class SquareApiException implements Exception {
  const SquareApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.stage,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final SquareApiStage? stage;

  @override
  String toString() => message;
}

class SquareAccountDeletionPendingException extends SquareApiException {
  const SquareAccountDeletionPendingException()
    : super(
        '注销已受理，云端仍在清理；稍后再次确认可查询进度',
        statusCode: 202,
        errorCode: 'account_deletion_pending',
      );
}

/// 本地预检失败没有HTTP状态；服务端仍对每次实际请求独立校验。
class SquarePreflightException implements Exception {
  const SquarePreflightException(this.message, this.code);
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// 由会员模块拥有实现；网络层只交付真实请求和响应事实。
abstract interface class SquareResourceGate {
  Future<SquareResourceLease> reserve({
    required String origin,
    required SquareSession session,
    required String operation,
    String? target,
    String? operationId,
    Map<String, int> costs = const {},
    Map<String, Map<String, int>> actions = const {},
  });
  void observe(
    String origin,
    SquareSession session,
    Map<String, dynamic> data, {
    String? path,
    int? sample,
  });
  int sample(String origin, SquareSession session);
  void invalidate(String accountId);
}

abstract interface class SquareResourceLease {
  void sent();
  void finish({
    Map<String, String>? headers,
    Map<String, dynamic>? receipt,
    bool accepted = true,
    bool uncertain = false,
  });
  void cancel();
}

class SquareSession {
  const SquareSession({
    required this.sessionToken,
    required this.cidNumber,
    required this.bindRev,
    required this.accountId,
    required this.deviceId,
    required this.expiresAt,
    this.authenticateRequest,
    this.requireCurrent,
  });

  final String sessionToken;

  /// 本会话的身份主键 CID 号（Worker 登录响应下发；广场/聊天一切归属与寻址的主键）。
  final String cidNumber;

  /// 本会话签发时的 finalized 绑定版本；与 CID、账户共同锁定当前授权。
  final int bindRev;

  /// 本会话当前绑定的钱包账户 account_id（签名/链上交易用；换绑后由新账户重新登录）。
  final String accountId;
  final int expiresAt;
  final String deviceId;
  final MlsRequestAuthenticator? authenticateRequest;
  final Future<void> Function()? requireCurrent;

  /// 当前用户变化或运行实例关闭时，任何迟到业务结果均不得消费。
  Future<void> validateCurrent() async {
    await requireCurrent?.call();
  }

  bool get isUsable => expiresAt > DateTime.now().millisecondsSinceEpoch;
}

/// CitizenServe 签发的短期聊天服务访问结果；登录态和 HTTP 合同只属于服务客户端。
class CitizenServeChatAccess {
  const CitizenServeChatAccess({
    required this.realtimeUrl,
    required this.accessToken,
    required this.expiresAt,
  });

  final Uri realtimeUrl;
  final String accessToken;
  final int expiresAt;
}

class _FinalizedSessionBinding {
  const _FinalizedSessionBinding({
    required this.cidNumber,
    required this.bindRev,
    required this.accountId,
  });

  final String cidNumber;
  final int bindRev;
  final String accountId;

  bool matches(SquareSession session) =>
      session.cidNumber == cidNumber &&
      session.bindRev == bindRev &&
      session.accountId == accountId;
}

/// 会员订阅态（ADR-037：与身份彻底解耦）。只描述付费订阅本身，不含任何链上身份信息；
/// 身份展示由身份页（myid）单独负责。
class SquareMembershipState {
  const SquareMembershipState({
    required this.active,
    required this.paidUntil,
    this.memberLevel,
    this.subState,
    this.chargeAt = 0,
    this.plans = const <SquareMembershipPlan>[],
    this.usageState,
  });

  final bool active;
  final int paidUntil;
  final String? memberLevel;

  /// 订阅生命周期态（链上单源镜像）：`active`=自动续费授权有效 /
  /// `terminated`=到期扣款失败并终止 / `cancelled`=用户已签名取消。
  /// 按钮双态与横幅文案据此判定。
  final String? subState;

  /// 最近一次真实扣款时间（毫秒）；与 [paidUntil] 组成会员卡当前已付周期展示。
  final int chargeAt;

  final List<SquareMembershipPlan> plans;
  final SquareMembershipUsageState? usageState;

  SquareMembershipPlan? planForLevel(String? level) {
    if (level == null) return null;
    for (final plan in plans) {
      if (plan.memberLevel == level) return plan;
    }
    return null;
  }

  SquareMembershipPlan? get activePlan =>
      active ? planForLevel(memberLevel) : null;

  /// 有可展示的订阅起止窗口（已支付且起止时间齐备）。
  bool get hasSubscriptionWindow => active && chargeAt > 0 && paidUntil > 0;
}

class SquareMembershipPlan {
  const SquareMembershipPlan({
    required this.memberLevel,
    required this.displayName,
    required this.fileLimit,
    required this.chat,
    required this.document,
    required this.video,
    required this.article,
    required this.usage,
    this.imageBytes = 0,
    this.imageDimension = 0,
    this.media = const {},
    this.resources = const {},
    this.dailyLimits = const {},
    this.priceFen,
  });

  final String memberLevel;
  final String displayName;

  /// 聊天文件大小上限（字节，会员权益之一，ADR-037）：自由 10MiB / 民主 100MiB / 薪火 5GiB。
  final int fileLimit;
  final SquareChatQuota chat;
  final SquareDocumentQuota document;
  final SquareVideoQuota video;
  final SquareArticleQuota article;
  final SquareMembershipUsageQuota usage;
  final int imageBytes;
  final int imageDimension;

  /// 服务端下发的成品规格及资源额度；空值表示尚未取得，不能授予默认权益。
  final Map<String, int> media;
  final Map<String, int> resources;
  final Map<String, int> dailyLimits;

  Map<String, dynamic> toJson() => {
    'member_level': memberLevel,
    'price_fen': priceFen,
    'plan': {
      'member_level': memberLevel,
      'file_limit': fileLimit,
      'video_max_seconds': video.videoMaxSeconds,
      'video_max_bytes': video.videoMaxBytes,
      'article_max_images': article.maxImages,
      'article_max_videos': article.maxVideos,
    },
    'limits': {
      ...media,
      'image_bytes': imageBytes,
      'image_dimension': imageDimension,
      'storage_bytes': usage.storageBytes,
    },
    'resources': resources,
    'daily_limits': dailyLimits,
  };

  /// 原服务端真实价格；未知保持null，不能以0代替。
  final int? priceFen;

  /// 提炼展示用短串（卡片与详情页共用，杜绝口径漂移）。
  String get fileSizeLabel => formatBytes(fileLimit);
  String get chatVoiceLabel => _duration(chat.voiceSecs);
  String get chatVideoLabel => _duration(chat.videoSecs);
  String get documentImageLabel => document.imageQuality;
  String get imageBytesLabel => formatBytes(imageBytes);
  String get videoQualityLabel => video.videoQuality;
  String get videoDurationLabel => _duration(video.videoMaxSeconds);
  String get videoBytesLabel => formatBytes(video.videoMaxBytes);
  String get articleImageLabel => article.imageQuality;
  String get articleCoverLabel => article.coverQuality;

  String get storageSizeLabel => formatBytes(usage.storageBytes);

  String get chatFileLabel => '聊天附件：单个 ≤ ${formatBytes(fileLimit)}';

  String get documentLabel =>
      '公文：${document.textMaxChars} 字、${document.maxImages} 张${document.imageQuality}图片';

  String get videoLabel =>
      '视频：${video.textMaxChars} 字配文、1 个${_duration(video.videoMaxSeconds)}${video.videoQuality}视频';

  String get articleLabel =>
      '文章：${article.bodyMaxChars} 字、${article.maxImages} 张${article.imageQuality}图片（含首图）、${article.maxVideos} 个视频、标题 ${article.titleMinChars}-${article.titleMaxChars} 字';

  static String _duration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600} 小时';
    if (seconds >= 60) return '${seconds ~/ 60} 分钟';
    return '$seconds 秒';
  }

  /// 文件、流量、存储共用1024进制显示；整数额度不以四舍五入改变上限。
  static String formatBytes(int bytes) {
    const units = {
      'TiB': 1024 * 1024 * 1024 * 1024,
      'GiB': 1024 * 1024 * 1024,
      'MiB': 1024 * 1024,
      'KiB': 1024,
    };
    for (final entry in units.entries) {
      if (bytes >= entry.value && bytes % entry.value == 0) {
        return '${bytes ~/ entry.value} ${entry.key}';
      }
    }
    for (final entry in units.entries) {
      if (bytes >= entry.value) {
        return '${(bytes / entry.value).toStringAsFixed(2)} ${entry.key}';
      }
    }
    return '$bytes B';
  }
}

/// CitizenServe 下发的聊天权益。只有 [SquareMembershipState.activePlan] 存在时才可使用；
/// 无会员不会构造虚假的自由会员权益。
class SquareChatQuota {
  const SquareChatQuota({
    required this.textEnabled,
    required this.emojiEnabled,
    required this.stickerEnabled,
    required this.imageEnabled,
    required this.voiceSecs,
    required this.videoSecs,
    required this.voiceCallEnabled,
    required this.videoCallEnabled,
  });

  final bool textEnabled;
  final bool emojiEnabled;
  final bool stickerEnabled;
  final bool imageEnabled;
  final int voiceSecs;
  final int videoSecs;
  final bool voiceCallEnabled;
  final bool videoCallEnabled;
}

/// 公文额度结构与 Worker `document` 对象逐字段对应。
class SquareDocumentQuota {
  const SquareDocumentQuota({
    required this.textMaxChars,
    required this.imageQuality,
    required this.maxImages,
  });

  final int textMaxChars;
  final String imageQuality;
  final int maxImages;
}

/// 视频额度结构与 Worker `video` 对象逐字段对应。
class SquareVideoQuota {
  const SquareVideoQuota({
    required this.textMaxChars,
    required this.videoQuality,
    required this.videoMaxSeconds,
    required this.videoMaxBytes,
  });

  final int textMaxChars;
  final String videoQuality;
  final int videoMaxSeconds;

  /// 单个发布视频体积上限（整数字节，1024进制展示）：自由 12MiB / 民主 200MiB / 薪火 1800MiB。
  final int videoMaxBytes;
}

/// 文章额度结构与 Worker `article` 对象逐字段对应。
class SquareArticleQuota {
  const SquareArticleQuota({
    required this.titleMinChars,
    required this.titleMaxChars,
    required this.bodyMaxChars,
    required this.coverQuality,
    required this.imageQuality,
    required this.maxImages,
    required this.maxVideos,
  });

  final int titleMinChars;
  final int titleMaxChars;
  final int bodyMaxChars;
  final String coverQuality;
  final String imageQuality;
  final int maxImages;
  final int maxVideos;
}

/// 服务端唯一广场空间上限；不再包含周期或并发额度。
class SquareMembershipUsageQuota {
  const SquareMembershipUsageQuota({required this.storageBytes});

  /// 当前档位允许占用的总存储空间（整数字节，1024进制展示），不随订阅周期重置。
  final int storageBytes;
}

/// 当前会员已用量与未过期上传预留的合计；手机端只用于发布前预检。
class SquareMembershipUsageState {
  const SquareMembershipUsageState({
    this.usedBytes = 0,
    this.reservedBytes = 0,
    this.dayStart = 0,
    this.daily = const {},
    this.publishedCount = 0,
    this.observedAt = 0,
    this.attachment,
  });

  final int usedBytes;
  final int reservedBytes;
  final int dayStart;
  final Map<String, int> daily;
  final int publishedCount;
  final int observedAt;
  final Map<String, dynamic>? attachment;

  Map<String, dynamic> toJson() => {
    'used_bytes': usedBytes,
    'reserved_bytes': reservedBytes,
    'day_start': dayStart,
    'daily': daily,
    'published_count': publishedCount,
    'observed_at': observedAt,
    if (attachment != null) 'attachment': attachment,
  };
}

class SquareUploadMediaRequest {
  const SquareUploadMediaRequest({
    required this.mediaKind,
    required this.byteSize,
    required this.bodyHash,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.previewBytes,
    required this.previewHash,
    this.videoSecs,
  });

  final SquareMediaKind mediaKind;
  final int byteSize;
  final String bodyHash;
  final int pixelWidth;
  final int pixelHeight;
  final int previewBytes;
  final String previewHash;
  final int? videoSecs;

  Map<String, Object?> toJson() => {
    'media_kind': mediaKind.workerValue,
    'byte_size': byteSize,
    'body_hash': bodyHash,
    'pixel_width': pixelWidth,
    'pixel_height': pixelHeight,
    'preview_bytes': previewBytes,
    'preview_hash': previewHash,
    if (videoSecs != null) 'video_secs': videoSecs,
  };
}

/// 服务端签发的单个对象上传目标；主文件与预览各有一个目标，不重复媒体声明。
class SquarePreparedMediaUpload {
  const SquarePreparedMediaUpload({
    required this.mediaIndex,
    required this.objectRole,
    required this.objectKey,
    required this.url,
    required this.httpMethod,
    required this.headers,
    required this.expiresAt,
  });
  final int mediaIndex;
  final String objectRole;
  final String objectKey;
  final String url;
  final String httpMethod;
  final Map<String, String> headers;
  final int expiresAt;
}

class SquarePreparedUpload {
  const SquarePreparedUpload({
    required this.uploadId,
    required this.postId,
    required this.receiptId,
    required this.expiresAt,
    required this.byteSize,
    required this.manifestObjectKey,
    required this.manifestUploadUrl,
    required this.mediaUploads,
  });

  final String uploadId;
  final String postId;
  final String receiptId;
  final int expiresAt;
  final int byteSize;
  final String manifestObjectKey;
  final String manifestUploadUrl;
  final List<SquarePreparedMediaUpload> mediaUploads;
}

class SquareCompletedUpload {
  const SquareCompletedUpload({
    required this.uploadId,
    required this.postId,
    required this.contentHash,
    required this.receiptId,
  });

  final String uploadId;
  final String postId;
  final String contentHash;
  final String receiptId;
}

/// 公民业务 HTTPS 服务地址，拒绝明文或降级连接。
// 保留既有业务接口；MLS改造只替换普通认证，不删除广场业务能力。
abstract class SquareFeedSource {
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit,
    SquareSession? session,
  });
}

abstract class SquarePublicationConfirmer {
  /// 仅查询已发布事实；未知结果必须保留本机恢复记录，不得重新发交易。
  Future<({SquarePost post, String blockHash, String transactionHash})>
  readPublishedProof({required SquareSession session, required String postId});
  Future<SquarePost> confirmPublishedPost({
    required SquareSession session,
    required String postId,
    required String blockHashHex,
    required String txHash,
  });

  /// 删除没有形成 finalized 发布事实的当前 CID 上传；服务端必须再次查链后决定。
  Future<void> abortUpload({
    required SquareSession session,
    required String uploadId,
  });
}

abstract class SquarePostDeletionService {
  Future<void> deletePost({
    required SquareSession session,
    required String postId,
  });
}

// 钱包敏感动作保持既有签名器合同与流程，普通请求认证不使用该入口。
typedef SquareActionSigner = Future<String> Function(Uint8List actionMessage);

/// 保留调用方名称，所有CitizenServe客户端共用一个受信配置。
class SquareApiConfig {
  static const baseUrlDefineName = 'SQUARE_API_URL';
  static const prodBaseUrl = CitizenServeApiConfig.production;
  static String get defaultBaseUrl => CitizenServeApiConfig.baseUrl;
  static String normalizeBaseUrl(String value) =>
      CitizenServeApiConfig.normalize(value);
}

class SquareApiClient
    implements
        SquareFeedSource,
        SquarePublicationConfirmer,
        SquarePostDeletionService {
  SquareApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = SquareApiConfig.normalizeBaseUrl(
        baseUrl ?? SquareApiConfig.defaultBaseUrl,
      ),
      _http = HttpsOnlyClient(httpClient ?? http.Client()) {
    _liveClients.add(WeakReference<SquareApiClient>(this));
  }

  // 所有客户端实例消费同一宿主预检，正式启动时由组合根注入。
  static SquareResourceGate? resourceGate;
  static const int _r2UploadAttempts = 3;

  static final List<WeakReference<SquareApiClient>> _liveClients =
      <WeakReference<SquareApiClient>>[];
  static _FinalizedSessionBinding? _finalizedSessionBinding;
  // 仅合并同一会话和完整URL的在途GET，响应结束即移除；不保存证明或结果缓存。
  static final Map<(SquareSession, Uri), Future<http.Response>> _reads = {};

  /// finalized 绑定切换后立即清除所有现存 API 客户端中的非当前 Session。
  ///
  /// WeakReference 不延长页面级客户端生命周期；仍在进行的此前账户握手即使稍后返回，
  /// 也会在落入缓存前再次核对本绑定并失败关闭。
  static void activateFinalizedBinding({
    required String cidNumber,
    required int bindRev,
    required String accountId,
  }) {
    final previous = _finalizedSessionBinding;
    if (previous?.cidNumber == cidNumber &&
        previous?.bindRev == bindRev &&
        previous?.accountId == accountId) {
      return;
    }
    final binding = _FinalizedSessionBinding(
      cidNumber: cidNumber,
      bindRev: bindRev,
      accountId: accountId,
    );
    _finalizedSessionBinding = binding;
    for (var index = _liveClients.length - 1; index >= 0; index--) {
      final client = _liveClients[index].target;
      if (client == null) {
        _liveClients.removeAt(index);
        continue;
      }
      for (final accountId in {
        ...client._sessions.keys,
        ...client._sessionGenerations.keys,
      }) {
        final cached = client._sessions[accountId];
        if (accountId != binding.accountId ||
            (cached != null && !binding.matches(cached))) {
          client._sessionGenerations[accountId] =
              (client._sessionGenerations[accountId] ?? 0) + 1;
        }
      }
      client._sessions.removeWhere((_, session) => !binding.matches(session));
      client._inflightSessions.clear();
    }
  }

  static String get defaultBaseUrl => SquareApiConfig.defaultBaseUrl;

  final String baseUrl;
  final http.Client _http;
  bool _closed = false;
  final Map<String, SquareSession> _sessions = {};
  // 进行中的握手：同账户并发调用共享同一 Future，杜绝冷启动握手风暴。
  final Map<String, Future<SquareSession>> _inflightSessions = {};
  final Map<String, int> _sessionGenerations = {};

  /// CitizenServe API 根地址；聊天模块只复用该会话请求短期服务授权。
  Uri get baseUri => Uri.parse(baseUrl);

  /// 会话缓存和在途任务固定CID、账户、代次及同一MLS设备。
  Future<SquareSession> ensureSession({
    required String accountId,
    required MlsAuthenticationSource authentication,
    Future<void> Function(MlsAuthenticationIdentity identity)?
    onDeviceNotRegistered,
  }) async {
    if (_closed) {
      throw const MlsAuthenticationException(
        "服务客户端已关闭",
        code: "identityChanged",
      );
    }
    final identity = await authentication.readIdentity();
    if (identity.accountId != accountId) {
      throw const MlsAuthenticationException(
        '当前账户与请求账户不一致',
        code: 'identityChanged',
      );
    }
    final generation = _sessionGenerations.putIfAbsent(accountId, () => 0);
    final cached = _sessions[accountId];
    if (cached != null &&
        cached.isUsable &&
        cached.cidNumber == identity.cidNumber &&
        cached.bindRev == identity.bindRev &&
        cached.deviceId == identity.deviceId &&
        (_finalizedSessionBinding == null ||
            _finalizedSessionBinding!.matches(cached))) {
      await authentication.requireCurrent(identity);
      return cached;
    }
    resourceGate?.invalidate(accountId);
    _sessions.remove(accountId);
    final key = identity.cacheKey;
    final pending = _inflightSessions[key];
    if (pending != null) return pending;
    late final Future<SquareSession> future;
    future = () async {
      try {
        return await _establishSession(identity, authentication, generation);
      } on SquareApiException catch (error) {
        // 服务不可用必须保留原失败，即使响应携带未登记码也不能触发设备登记。
        if (error.statusCode == 503 ||
            error.errorCode != 'device_not_registered' ||
            onDeviceNotRegistered == null) {
          rethrow;
        }
        await _requireAuthenticationCurrent(
          identity,
          authentication,
          generation,
        );
        await onDeviceNotRegistered(identity);
        await _requireAuthenticationCurrent(
          identity,
          authentication,
          generation,
        );
        return _establishSession(identity, authentication, generation);
      }
    }();
    _inflightSessions[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightSessions[key], future)) {
        _inflightSessions.remove(key);
      }
    }
  }

  Future<void> _requireAuthenticationCurrent(
    MlsAuthenticationIdentity identity,
    MlsAuthenticationSource authentication,
    int generation,
  ) async {
    await authentication.requireCurrent(identity);
    if (_closed ||
        (_sessionGenerations[identity.accountId] ?? 0) != generation) {
      throw const MlsAuthenticationException(
        'MLS会话已失效',
        code: 'identityChanged',
      );
    }
  }

  Future<Map<String, String>> _authenticationHeaders({
    required MlsAuthenticationIdentity identity,
    required MlsAuthenticationSource authentication,
    required int generation,
    required String purpose,
    required String method,
    required Uri uri,
    required List<int> body,
    String? sessionToken,
  }) async {
    var stage = 'identity';
    try {
      if (uri.origin != baseUri.origin) {
        throw const MlsAuthenticationException('MLS认证目标服务不一致');
      }
      final bytes = List<int>.unmodifiable(body);
      await _requireAuthenticationCurrent(identity, authentication, generation);
      stage = 'challenge';
      final challenge = await _postAuthentication(
        '/user/challenges',
        jsonEncode({
          'account_id': identity.accountId,
          'public_key': identity.publicKey,
          'token_purpose': purpose,
          'http_method': method,
          'request_target': uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
          'body_hash': '0x${sha256.convert(bytes)}',
        }),
        sessionToken: sessionToken,
      );
      await _requireAuthenticationCurrent(identity, authentication, generation);
      final nonce = challenge['nonce_id'];
      final expiry = challenge['expires_at'];
      if (nonce is! String || expiry is! int) {
        throw const MlsAuthenticationException('MLS挑战响应不完整');
      }
      final request = sdk.MlsAuthenticationRequest(
        serviceOrigin: uri.origin,
        challenge: nonce,
        expiresAtMillis: expiry,
        method: method,
        requestTarget: uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
        bodyBytes: bytes,
      );
      validateMlsChallenge(identity, request, challenge);
      stage = 'proof';
      final proof = await authentication.createProof(
        identity: identity,
        request: request,
        challenge: challenge,
      );
      await _requireAuthenticationCurrent(identity, authentication, generation);
      validateMlsProofMatches(identity, request, challenge, proof);
      return mlsProofHeaders(proof);
    } on SquareApiException {
      // HTTP和传输失败已在实际发送边界分类，不重复读取或输出正文。
      rethrow;
    } on Object catch (error) {
      AppLog.failure(
        stage: stage,
        code: error is MlsAuthenticationException
            ? error.code
            : error is sdk.MlsNativeException
            ? 'mls_${error.diagnosticCode}'
            : error is FormatException
            ? 'format'
            : 'response_invalid',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postAuthentication(
    String path,
    String body, {
    String? sessionToken,
    Map<String, String> proofHeaders = const {},
  }) async {
    final stage = switch (path) {
      '/user/challenges' => SquareApiStage.challenge,
      '/user/sessions' => SquareApiStage.session,
      '/user/devices' => SquareApiStage.registration,
      _ => SquareApiStage.request,
    };
    try {
      final response = await _http
          .post(
            _uri(path),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              if (sessionToken != null) 'authorization': 'Bearer $sessionToken',
              ...proofHeaders,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      return _decodeResponse(response, stage: stage);
    } on SocketException {
      AppLog.failure(stage: stage.name, code: 'network_unavailable');
      throw SquareApiException(
        '网络连接失败',
        errorCode: 'network_unavailable',
        stage: stage,
      );
    } on TimeoutException {
      AppLog.failure(stage: stage.name, code: 'network_unavailable');
      throw SquareApiException(
        '网络请求超时',
        errorCode: 'network_unavailable',
        stage: stage,
      );
    } on http.ClientException {
      AppLog.failure(stage: stage.name, code: 'network_unavailable');
      // 传输失败保留固定阶段；不保存客户端异常中的URL或服务响应正文。
      throw SquareApiException(
        '网络传输失败',
        errorCode: 'network_unavailable',
        stage: stage,
      );
    }
  }

  Future<SquareSession> _establishSession(
    MlsAuthenticationIdentity identity,
    MlsAuthenticationSource authentication,
    int generation,
  ) async {
    final body = jsonEncode({'account_id': identity.accountId});
    final headers = await _authenticationHeaders(
      identity: identity,
      authentication: authentication,
      generation: generation,
      purpose: 'session',
      method: 'POST',
      uri: _uri('/user/sessions'),
      body: utf8.encode(body),
    );
    final response = await _postAuthentication(
      '/user/sessions',
      body,
      proofHeaders: headers,
    );
    await _requireAuthenticationCurrent(identity, authentication, generation);
    const fields = {
      'is_ok',
      'session_token',
      'cid_number',
      'device_id',
      'bind_rev',
      'account_id',
      'expires_at',
      'gate',
      'usage',
    };
    final token = response['session_token'];
    final expiry = response['expires_at'];
    if (!response.keys.every(fields.contains) ||
        response['is_ok'] != true ||
        token is! String ||
        token.isEmpty ||
        expiry is! int ||
        expiry <= DateTime.now().millisecondsSinceEpoch ||
        expiry > sdk.MlsAuthenticationRequest.maxJsonInteger ||
        response['cid_number'] != identity.cidNumber ||
        response['device_id'] != identity.deviceId ||
        response['account_id'] != identity.accountId ||
        response['bind_rev'] != identity.bindRev) {
      AppLog.failure(stage: 'session', code: 'response_invalid');
      throw const MlsAuthenticationException('MLS会话响应与当前身份不一致');
    }
    final next = SquareSession(
      sessionToken: token,
      cidNumber: identity.cidNumber,
      deviceId: identity.deviceId,
      bindRev: identity.bindRev,
      accountId: identity.accountId,
      expiresAt: expiry,
      requireCurrent: () =>
          _requireAuthenticationCurrent(identity, authentication, generation),
      authenticateRequest:
          ({
            required method,
            required uri,
            required body,
            required sessionToken,
          }) {
            if (sessionToken != token) {
              throw const MlsAuthenticationException('请求会话与认证设备不一致');
            }
            return _authenticationHeaders(
              identity: identity,
              authentication: authentication,
              generation: generation,
              purpose: 'request',
              method: method,
              uri: uri,
              body: body,
              sessionToken: token,
            );
          },
    );
    if (_finalizedSessionBinding != null &&
        !_finalizedSessionBinding!.matches(next)) {
      throw const MlsAuthenticationException(
        '当前CID绑定已切换',
        code: 'identityChanged',
      );
    }
    resourceGate?.observe(baseUri.origin, next, response);
    _sessions[identity.accountId] = next;
    return next;
  }

  /// 清除某账户的本地会话缓存（注销后调用，配合 Worker 端会话失效实现零残留）。
  void clearSession(String accountId) {
    resourceGate?.invalidate(accountId);
    _sessions.remove(accountId);
    _sessionGenerations[accountId] = (_sessionGenerations[accountId] ?? 0) + 1;
    _inflightSessions.clear();
  }

  /// 钱包注销意图与只读恢复意图分域；只有真实complete回执才能清本地。
  Future<void> deleteAccount({
    required IdentityBinding binding,
    required SquareActionSigner signAction,
    Future<void> Function()? requireCurrent,
  }) async {
    binding.validate();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$')
        .hasMatch(binding.cidNumber)) {
      throw const SquareApiException('注销身份绑定无效');
    }
    final generation = _sessionGenerations[binding.accountId] ?? 0;
    Future<void> check() async {
      await requireCurrent?.call();
      final current = _finalizedSessionBinding;
      if ((_sessionGenerations[binding.accountId] ?? 0) != generation ||
          (current != null &&
              (current.cidNumber != binding.cidNumber ||
                  current.accountId != binding.accountId ||
                  current.bindRev != binding.bindRev))) {
        throw const SquareApiException('当前身份已变化，请重新打开本人主页');
      }
    }

    await check();
    final cached = _sessions[binding.accountId];
    final session = cached != null && cached.isUsable ? cached : null;
    if (session != null &&
        (session.cidNumber != binding.cidNumber ||
            session.bindRev != binding.bindRev)) {
      throw const SquareApiException('注销会话与当前绑定不一致');
    }
    var purpose = session == null ? 'status' : 'delete';
    Map<String, dynamic> challenge;
    if (session != null) {
      try {
        challenge = await _postJson(
          '/user/deletion/challenges',
          {},
          session: session,
        );
      } on SquareApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        purpose = 'status';
        challenge = await _postJson('/user/deletion/status/challenges', {
          'cid_number': binding.cidNumber,
          'account_id': binding.accountId,
        });
      }
    } else {
      challenge = await _postJson('/user/deletion/status/challenges', {
        'cid_number': binding.cidNumber,
        'account_id': binding.accountId,
      });
    }
    await check();
    final payload = _accountDeletionPayload(challenge, binding, purpose);
    final message = await CitizenSigning.encodePayload(
      CitizenSigningPayload.message(
        opTag: kOpSignSquareAction,
        scalePayload: payload,
      ),
    );
    await check();
    final signature = await signAction(message);
    await check();
    _accountDeletionPayload(challenge, binding, purpose);
    final receipt = await _postJson(
      purpose == 'delete' ? '/user/deletion' : '/user/deletion/status',
      {'nonce_id': challenge['nonce_id'], 'signature': signature},
      session: purpose == 'delete' ? session : null,
    );
    await check();
    const fields = {
      'is_ok',
      'cid_number',
      'account_id',
      'bind_rev',
      'deletion_id',
      'state',
    };
    final state = receipt['state'];
    final id = receipt['deletion_id'];
    if (receipt.length != fields.length ||
        !receipt.keys.every(fields.contains) ||
        receipt['is_ok'] != true ||
        receipt['cid_number'] != binding.cidNumber ||
        receipt['account_id'] != binding.accountId ||
        receipt['bind_rev'] != binding.bindRev ||
        !const {'absent', 'pending', 'complete'}.contains(state) ||
        (state == 'absent'
            ? id != null
            : id is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(id))) {
      throw const SquareApiException('注销回执与当前身份不一致');
    }
    if (state == 'absent') {
      throw const SquareApiException('没有待恢复的注销任务，请先完成登录再注销');
    }
    if (state == 'pending') {
      clearSession(binding.accountId);
      throw const SquareAccountDeletionPendingException();
    }
  }

  Uint8List _accountDeletionPayload(
    Map<String, dynamic> challenge,
    IdentityBinding binding,
    String purpose,
  ) {
    const fields = {
      'is_ok',
      'token_purpose',
      'nonce_id',
      'cid_number',
      'account_id',
      'bind_rev',
      'chain_scope',
      'service_origin',
      'expires_at',
      'sign_hex',
    };
    final id = challenge['nonce_id'];
    final expiry = challenge['expires_at'];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (challenge.length != fields.length ||
        !challenge.keys.every(fields.contains) ||
        challenge['is_ok'] != true ||
        challenge['token_purpose'] != purpose ||
        challenge['cid_number'] != binding.cidNumber ||
        challenge['account_id'] != binding.accountId ||
        challenge['bind_rev'] != binding.bindRev ||
        challenge['chain_scope'] != binding.genesisHash ||
        challenge['service_origin'] != baseUri.origin ||
        id is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        expiry is! int ||
        expiry <= now ||
        expiry > now + 300000 ||
        expiry > 9007199254740991) {
      throw const SquareApiException('注销挑战与当前身份不一致或已过期');
    }
    final bytes = BytesBuilder(copy: false);
    void string(String value) {
      final raw = utf8.encode(value);
      if (raw.length >= 16384) throw const SquareApiException('注销签名范围无效');
      if (raw.length < 64) {
        bytes.addByte(raw.length << 2);
      } else {
        final compact = (raw.length << 2) | 1;
        bytes.add([compact & 255, compact >> 8]);
      }
      bytes.add(raw);
    }

    void u64(int value) {
      final data = ByteData(8)..setUint64(0, value, Endian.little);
      bytes.add(data.buffer.asUint8List());
    }

    string('citizenserve.account_deletion');
    string(baseUri.origin);
    bytes.add(hexToBytes(binding.genesisHash));
    string(binding.cidNumber);
    bytes.add(hexToBytes(binding.accountId));
    u64(binding.bindRev);
    bytes.addByte(purpose == 'delete' ? 0 : 1);
    bytes.add(hexToBytes(id));
    u64(expiry);
    final payload = bytes.takeBytes();
    if (challenge['sign_hex'] != '0x${bytesToHex(payload)}') {
      throw const SquareApiException('注销签名内容与本地合同不一致');
    }
    return payload;
  }

  /// 钱包授权已持久保存；每次登记提交仍使用同一MLS身份的新鲜挑战。
  Future<void> registerMlsDevice({
    required MlsAuthenticationIdentity identity,
    required MlsAuthenticationSource authentication,
    required int issuedAt,
    required String bindingSignatureHex,
    required String? regId,
    required String? recoveryToken,
  }) async {
    final generation = _sessionGenerations.putIfAbsent(
      identity.accountId,
      () => 0,
    );
    final body = jsonEncode({
      'account_id': identity.accountId,
      'public_key': identity.publicKey,
      'issued_at': issuedAt,
      'binding_signature': bindingSignatureHex,
      'reg_id': regId,
      'recovery_token': recoveryToken,
    });
    final headers = await _authenticationHeaders(
      identity: identity,
      authentication: authentication,
      generation: generation,
      purpose: 'registration',
      method: 'POST',
      uri: _uri('/user/devices'),
      body: utf8.encode(body),
    );
    final response = await _postAuthentication(
      '/user/devices',
      body,
      proofHeaders: headers,
    );
    await _requireAuthenticationCurrent(identity, authentication, generation);
    const fields = {'is_ok', 'cid_number', 'bind_rev', 'device_id'};
    if (!response.keys.every(fields.contains) ||
        response['is_ok'] != true ||
        response['cid_number'] != identity.cidNumber ||
        response['device_id'] != identity.deviceId ||
        response['bind_rev'] != identity.bindRev) {
      AppLog.failure(stage: 'registration', code: 'response_invalid');
      throw const MlsAuthenticationException('MLS登记回执与当前身份不一致');
    }
  }

  /// 读取 CitizenServe 的平台会员快照。该方法只解析响应，不修改页面或聊天全局状态；
  /// 会话级去重、本地缓存和刷新广播统一由 SubscriptionService 负责。
  Future<SquareMembershipState> fetchMembership(SquareSession session) async {
    const membershipPath = '/membergate';
    final data = await _getJson(membershipPath, session: session);
    return decodeMembership(data);
  }

  /// 许可由宿主当前会话签发；传输可用性仍由聊天适配交付验收。
  Future<CitizenServeChatAccess> fetchChatAccess({
    required SquareSession session,
    required String deviceId,
  }) async {
    if (deviceId != session.deviceId) {
      throw const SquareApiException('聊天许可设备不一致');
    }
    final data = await _postJson('/tatachat/access', {}, session: session);
    final realtimeValue = _requireString(data, 'realtime_url');
    final realtime = Uri.tryParse(realtimeValue);
    // Dart未定义WSS默认端口，还会把显式:0规范化掉；从原文按安全443计算，
    // 保留显式端口（包括0）的同源拒绝，不改变实际WSS许可地址。
    final realtimePort = realtime?.scheme == 'wss'
        ? Uri.tryParse(
            'https${realtimeValue.substring(realtimeValue.indexOf(':'))}',
          )?.port
        : null;
    final token = _requireString(data, 'access_token');
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = data['expires_at'];
    final recheck = data['recheck_at'];
    if (data['is_ok'] != true ||
        data.keys.any(
          (key) => !const {
            'is_ok',
            'realtime_url',
            'access_token',
            'expires_at',
            'recheck_at',
            'gate',
            'usage',
          }.contains(key),
        ) ||
        realtime == null ||
        realtime.scheme != 'wss' ||
        realtime.host != baseUri.host ||
        realtimePort != baseUri.port ||
        realtime.userInfo.isNotEmpty ||
        realtime.path != '/api/tatachat/realtime' ||
        realtime.pathSegments.join('/') != 'api/tatachat/realtime' ||
        realtime.hasQuery ||
        realtime.hasFragment ||
        expiry is! int ||
        recheck is! int ||
        token.length > 16 * 1024 ||
        token.codeUnits.any((unit) => unit <= 32 || unit >= 127) ||
        expiry <= now + 60000 ||
        expiry > session.expiresAt ||
        recheck <= now ||
        recheck > expiry) {
      throw const SquareApiException('聊天许可回执无效');
    }
    return CitizenServeChatAccess(
      realtimeUrl: realtime,
      accessToken: token,
      expiresAt: expiry,
    );
  }

  /// finalized投影是公开链证据，不接收客户端自报CID或账户。
  Future<void> projectFinalizedIdentity(String chainHash) async {
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(chainHash)) {
      throw const SquareApiException('finalized块无效');
    }
    final data = await _postJson('/user/identity', {'block_hash': chainHash});
    if (data['is_ok'] != true) throw const SquareApiException('身份投影尚未完成');
  }

  /// 幂等登记CitizenServe普通应用通知端点；设备身份只由已验签Session决定。
  Future<void> registerPushEndpoint({
    required SquareSession session,
    required AppPushToken endpoint,
  }) async {
    final provider = endpoint.provider;
    final token = endpoint.token.trim();
    final environment = endpoint.apnsEnvironment;
    if ((provider != 'apns' && provider != 'fcm') ||
        token.length < 16 ||
        token.length > 4096 ||
        (provider == 'apns' &&
            environment != 'sandbox' &&
            environment != 'production') ||
        (provider == 'fcm' && environment != null)) {
      throw const SquareApiException('应用推送端点不合法');
    }
    final expiresAt = DateTime.now()
        .add(const Duration(days: 90))
        .millisecondsSinceEpoch;
    final data = await _putJson('/notifications/endpoint', <String, Object?>{
      'push_provider': provider,
      'push_token': token,
      'apns_env': environment,
      'expires_at': expiresAt,
    }, session: session);
    if (data['is_ok'] != true || data['expires_at'] is! num) {
      throw const SquareApiException('应用推送端点响应不合法');
    }
  }

  static SquareMembershipState decodeMembership(Map<String, dynamic> data) {
    final membership = data['membergate'];
    // GET与确认只接受同一份完整快照；读取失败不能冒充未订阅或清空原事实。
    if (data['is_ok'] != true ||
        data['membergate_active'] is! bool ||
        !data.containsKey('membergate') ||
        (membership != null && membership is! Map<String, dynamic>) ||
        (data['membergate_active'] == true && membership == null) ||
        data['plans'] is! List ||
        data['usage'] is! Map<String, dynamic>) {
      throw const SquareApiException('会员快照不完整');
    }
    if (membership is Map<String, dynamic> &&
        (membership['member_level'] is! String ||
            membership['sub_state'] is! String ||
            membership['paid_until'] is! int ||
            (membership['paid_until'] as int) < 0 ||
            membership['charge_at'] is! int ||
            (membership['charge_at'] as int) < 0)) {
      throw const SquareApiException('会员快照字段无效');
    }
    final active = data['membergate_active'] == true;
    final plans = decodeMembershipPlans(data['plans']);
    final usageState = decodeMembershipUsage(data['usage']);
    // 会员与身份解耦（ADR-037）：响应只含订阅与套餐，无身份/冻结字段。
    if (membership is! Map<String, dynamic>) {
      return SquareMembershipState(
        active: false,
        paidUntil: 0,
        plans: plans,
        usageState: usageState,
      );
    }
    final memberLevel = membership['member_level']?.toString();
    return SquareMembershipState(
      active: active,
      paidUntil: _asInt(membership['paid_until']),
      memberLevel: memberLevel,
      subState: membership['sub_state']?.toString(),

      chargeAt: _asInt(membership['charge_at']),
      plans: plans,
      usageState: usageState,
    );
  }

  /// 确认请求携带原MLS正文证明，一次取得回执和真实快照，不再额外GET会员。
  /// 回执或快照失败保留原证明；不能再次签名或付款。
  Future<SquareMembershipState> confirmPlatformSubscription({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    final hash = RegExp(r'^0x[0-9a-f]{64}$');
    if (!hash.hasMatch(txHash) || !hash.hasMatch(blockHashHex)) {
      throw const SquareApiException('会员确认交易或块无效');
    }
    final data = await _postJson('/membergate/confirm', {
      'tx_hash': txHash,
      'block_hash': blockHashHex,
      'include_state': true,
    }, session: session);
    if (data.length != 4 ||
        data['is_ok'] != true ||
        data['tx_hash'] != txHash ||
        data['block_hash'] != blockHashHex) {
      throw const SquareApiException('会员确认回执与本次交易不一致');
    }
    final snapshot = data['membergate_state'];
    if (snapshot is! Map<String, dynamic>) {
      throw const SquareApiException('会员确认快照不完整');
    }
    return decodeMembership(snapshot);
  }

  /// 同 CID 的真实 MLS 传递；请求内没有属主、联系人或钱包数据密钥。
  Future<Map<String, dynamic>> exchangeContactMls({
    required SquareSession session,
    required Map<String, Object?> request,
  }) => _postJson('/user/contacts', request, session: session);

  Future<SquarePreparedUpload> prepareUpload({
    required SquareSession session,
    required SquarePostType postType,
    required int titleLength,
    required int textLength,
    required String contentHash,
    required int manifestBytes,
    required List<SquareUploadMediaRequest> mediaItems,
  }) async {
    final data = await _postJson('/8964/uploads', {
      'post_type': postType.workerValue,
      'title_length': titleLength,
      'text_length': textLength,
      'content_hash': contentHash,
      'manifest_bytes': manifestBytes,
      'media_items': mediaItems.map((item) => item.toJson()).toList(),
    }, session: session);
    final rawMediaItems = data['media_uploads'];
    final manifest = data['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw const SquareApiException('上传准备响应缺少manifest');
    }
    if (data['is_ok'] != true ||
        rawMediaItems is! List ||
        rawMediaItems.length != mediaItems.length * 2 ||
        rawMediaItems.any((item) => item is! Map<String, dynamic>) ||
        data['byte_size'] is! int ||
        (data['byte_size'] as int) < manifestBytes ||
        data['expires_at'] is! int) {
      throw const SquareApiException('上传准备响应缺少媒体对象列表');
    }
    final prepared = SquarePreparedUpload(
      uploadId: _requireString(data, 'upload_id'),
      postId: _requireString(data, 'post_id'),
      receiptId: _requireString(data, 'receipt_id'),
      expiresAt: _asInt(data['expires_at']),
      byteSize: _asInt(data['byte_size']),
      manifestObjectKey: _requireString(manifest, 'object_key'),
      manifestUploadUrl: CitizenServeApiConfig.capability(
        baseUrl,
        _requireString(manifest, 'upload_url'),
        '/8964/uploads/${Uri.encodeComponent(_requireString(data, 'upload_id'))}/manifest',
      ).toString(),
      mediaUploads: rawMediaItems
          .map((item) => _parsePreparedMedia(item as Map<String, dynamic>))
          .toList(growable: false),
    );
    final slots = <(int, String)>{};
    for (final upload in prepared.mediaUploads) {
      final index = upload.mediaIndex;
      if (index < 0 ||
          index >= mediaItems.length ||
          !slots.add((index, upload.objectRole)) ||
          !{
            'source',
            mediaItems[index].mediaKind == SquareMediaKind.video
                ? 'cover'
                : 'thumbnail',
          }.contains(upload.objectRole)) {
        throw const SquareApiException('媒体上传目标与请求槽位不一致');
      }
    }
    return prepared;
  }

  Future<void> uploadObject({
    required String uploadUrl,
    required String contentType,
    required Uint8List body,
    required SquareSession session,
  }) async {
    await uploadBytesTo(uploadUrl, body, contentType, session: session);
  }

  /// 主文件与预览共用同一有界上传/重试实现；长度来自已经持有的本地声明。
  Future<void> uploadMedia({
    required SquareSession session,
    required SquarePreparedMediaUpload upload,
    required String filePath,
    required int byteSize,
  }) async {
    final uri = Uri.tryParse(upload.url);
    if (upload.httpMethod != 'PUT' ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        upload.expiresAt <= DateTime.now().millisecondsSinceEpoch ||
        (upload.headers.containsKey('content-length') &&
            upload.headers['content-length'] != '$byteSize')) {
      throw const SquareApiException('媒体上传目标无效');
    }
    await _retryR2Upload<void>(
      () => _uploadFileToR2(
        session: session,
        uploadUrl: upload.url,
        filePath: filePath,
        contentLength: byteSize,
        headers: upload.headers,
      ),
    );
  }

  Future<SquareCompletedUpload> completeUpload({
    required SquareSession session,
    required String uploadId,
    required String contentHash,
  }) async {
    final data = await _postJson(
      '/8964/uploads/${Uri.encodeComponent(uploadId)}/complete',
      {'content_hash': contentHash},
      session: session,
    );
    if (data['content_hash'] != contentHash || data['upload_id'] != uploadId) {
      throw const SquareApiException('上传完成摘要不一致');
    }
    return SquareCompletedUpload(
      uploadId: _requireString(data, 'upload_id'),
      postId: _requireString(data, 'post_id'),
      contentHash: _requireString(data, 'content_hash'),
      receiptId: _requireString(data, 'receipt_id'),
    );
  }

  @override
  Future<SquarePost> confirmPublishedPost({
    required SquareSession session,
    required String postId,
    required String blockHashHex,
    required String txHash,
  }) async {
    final data = await _postJson('/8964/posts/confirm', {
      'post_id': postId,
      'block_hash': blockHashHex,
      'tx_hash': txHash,
    }, session: session);
    final hash = data['content_hash'];
    final postCategory = data['post_category'];
    if (data['is_ok'] != true ||
        data['post_id'] != postId ||
        hash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
        !const {'normal', 'campaign'}.contains(postCategory)) {
      throw const SquareApiException('发布确认回执不一致');
    }
    // 原确认只返回事实回执；沿既有详情入口读回一次，不猜造旧post结构或重发链交易。
    final proof = await readPublishedProof(session: session, postId: postId);
    if (proof.blockHash != blockHashHex ||
        proof.transactionHash != txHash ||
        proof.post.contentHash != hash ||
        proof.post.postCategory.name != postCategory) {
      throw const SquareApiException('发布确认与实际证明不一致');
    }
    return proof.post;
  }

  @override
  Future<void> abortUpload({
    required SquareSession session,
    required String uploadId,
  }) async {
    await _deleteJson(
      '/8964/uploads/${Uri.encodeComponent(uploadId)}',
      session: session,
    );
  }

  /// 拉取本人已发布内容的规范 manifest 原始字节。
  ///
  /// 请求沿用 [_getJson] 的 Bearer + MLS设备证明；响应逐字段严格解析，任何一项
  /// 缺失、类型漂移或 CID 越界都会拒绝整页，不把部分结果交给本地仓库。
  Future<SquareLocalPostPage> fetchSelfPublishedPostCopies({
    required SquareSession session,
    String? cursor,
    int limit = 5,
  }) async {
    if (limit < 1 || limit > 5) {
      throw const SquareApiException('本人副本回灌 limit 必须为 1..5');
    }
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) {
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(cursor)) {
        throw const SquareApiException('本人副本回灌 cursor 不合法');
      }
      params['cursor'] = cursor;
    }
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final data = await _getJson('/8964/posts/self?$query', session: session);
    final rawItems = data['posts'];
    if (data['is_ok'] != true || rawItems is! List || rawItems.length > limit) {
      throw const SquareApiException('本人副本回灌 posts 不合法');
    }
    final items = <SquareLocalPost>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const SquareApiException('本人副本回灌条目不合法');
      }
      final post = rawItem['post'];
      if (post is! Map<String, dynamic> ||
          rawItem['content_hash'] != post['content_hash']) {
        throw const SquareApiException('本人副本回灌元数据与原始内容摘要不一致');
      }
      final cidNumber = _requireExactString(post, 'cid_number');
      if (cidNumber != session.cidNumber) {
        throw const SquareApiException('本人副本回灌 CID 与当前会话不一致');
      }
      final chainBlockValue = post['chain_block'];
      final publishedAt = post['published_at'];
      if ((chainBlockValue != null && chainBlockValue is! int) ||
          publishedAt is! int) {
        throw const SquareApiException('本人副本回灌区块或时间类型不合法');
      }
      final contentHash = _requireExactString(post, 'content_hash');
      try {
        items.add(
          SquarePostStore.validate(
            SquareLocalPost(
              postId: _requireExactString(post, 'post_id'),
              cidNumber: cidNumber,
              accountId: _requireExactString(post, 'account_id'),
              postCategory: _requireExactString(post, 'post_category'),
              postType: _requireExactString(post, 'post_type'),
              manifestBytes: _decodeManifest(
                _requireExactString(rawItem, 'manifest_bytes_base64url'),
              ),
              contentHash: contentHash,
              receiptId: _requireExactString(post, 'receipt_id'),
              chainBlock: chainBlockValue as int?,
              publishedAt: publishedAt,
              postState: _requireExactString(post, 'post_state'),
            ),
          ),
        );
      } on SquarePostStoreException {
        throw const SquareApiException('本人副本回灌内容校验失败');
      }
    }

    final rawNextCursor = data['next_cursor'];
    if (rawNextCursor != null &&
        (rawNextCursor is! String ||
            !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(rawNextCursor))) {
      throw const SquareApiException('本人副本回灌 next_cursor 不合法');
    }
    return SquareLocalPostPage(
      items: List<SquareLocalPost>.unmodifiable(items),
      nextCursor: rawNextCursor as String?,
    );
  }

  @override
  Future<void> deletePost({
    required SquareSession session,
    required String postId,
  }) async {
    await _deleteJson(
      '/8964/posts/${Uri.encodeComponent(postId)}',
      session: session,
    );
  }

  /// 详情接口在确认 D1 可见状态后读取并校验 R2 manifest；Feed 只携带摘要。
  Future<SquarePost> fetchPostDetail({
    required SquareSession session,
    SquarePost? summary,
    String? postId,
  }) async {
    final target = postId ?? summary?.postId;
    if (target == null ||
        (postId != null && summary != null && postId != summary.postId)) {
      throw const SquareApiException('内容ID不一致');
    }
    final data = await _getJson(
      '/8964/posts/${Uri.encodeComponent(target)}',
      session: session,
    );
    final post = data['post'];
    final manifest = data['manifest'];
    if (post is! Map<String, dynamic> ||
        post['post_id'] != target ||
        manifest is! Map<String, dynamic>) {
      throw const SquareApiException('内容详情响应不完整，请重试');
    }
    return _parsePost(
      post,
      manifest: manifest,
      fallbackAuthor: summary?.author,
    );
  }

  /// 显式恢复读取服务器已确认的发布证明，不签名、不重新提交交易。
  @override
  Future<({SquarePost post, String blockHash, String transactionHash})>
  readPublishedProof({
    required SquareSession session,
    required String postId,
  }) async {
    final data = await _getJson(
      '/8964/posts/${Uri.encodeComponent(postId)}',
      session: session,
    );
    final raw = data['post'];
    if (raw is! Map<String, dynamic> ||
        raw['post_id'] != postId ||
        raw['cid_number'] != session.cidNumber ||
        raw['post_state'] != 'published') {
      throw const SquareApiException('发布证明归属或状态不一致');
    }
    final block = raw['chain_hash'];
    final tx = raw['tx_hash'];
    if (block is! String ||
        tx is! String ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(block) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(tx)) {
      throw const SquareApiException('发布证明缺少区块或交易哈希');
    }
    final manifest = data['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw const SquareApiException('发布证明缺少清单');
    }
    return (
      post: _parsePost(raw, manifest: manifest),
      blockHash: block,
      transactionHash: tx,
    );
  }

  /// 正文已由原始manifest验真；详情只提供下载位置，媒体声明仍必须逐项匹配manifest。
  Future<List<Map<String, dynamic>>> fetchPostMedia({
    required SquareSession session,
    required SquareLocalPost post,
  }) async {
    final data = await _getJson(
      '/8964/posts/${Uri.encodeComponent(post.postId)}',
      session: session,
    );
    final raw = data['post'];
    if (raw is! Map<String, dynamic> ||
        raw['post_id'] != post.postId ||
        raw['cid_number'] != post.cidNumber ||
        raw['content_hash'] != post.contentHash ||
        raw['media_items'] is! List) {
      throw const SquareApiException('媒体详情与本人发布事实不一致');
    }
    return (raw['media_items'] as List)
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const SquareApiException('媒体详情条目损坏');
          }
          return item;
        })
        .toList(growable: false);
  }

  /// 帖子媒体只向批准来源交付当前会话，服务端在CID之后核验会员，拒绝重定向。
  Future<http.StreamedResponse> openPostMedia(
    String url, {
    required SquareSession session,
    String? range,
    int? expectedBytes,
  }) async {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri)..followRedirects = false;
    if (range != null) request.headers['range'] = range;
    final response = await _sendProtected(
      request,
      session,
      expectedBytes: expectedBytes,
    );
    if (response.statusCode != (range == null ? 200 : 206)) {
      await response.stream.listen(null).cancel();
      throw SquareApiException('媒体读取失败', statusCode: response.statusCode);
    }
    return response;
  }

  @override
  Future<List<SquarePost>> fetchFeed({
    required SquareFeedKind feedKind,
    int limit = 20,
    SquareSession? session,
  }) async {
    final data = await _getJson(
      '/8964/feed/${feedKind.workerValue}?limit=$limit',
      session: session,
    );
    final posts = data['posts'];
    if (posts is! List) {
      throw const SquareApiException('广场 feed 响应缺少内容列表');
    }
    return posts
        .whereType<Map<String, dynamic>>()
        .map(_parsePost)
        .toList(growable: false);
  }

  /// 把私有头像、背景的 R2 object_key 拼成 Worker 会话门禁 URL。
  /// 广场帖子媒体由 Worker 返回受公民号及会员门禁保护的 HTTPS 绝对地址，不经过本方法。
  String mediaUrl(String objectKey, {int? updatedAt}) {
    final parts = objectKey.split('/');
    if (parts.length != 3 ||
        parts[0] != 'profile' ||
        !{'avatar', 'banner'}.contains(parts[2]) ||
        !RegExp(r'^[A-Za-z0-9-]{1,32}$').hasMatch(parts[1])) {
      throw const SquareApiException('资料资源必须属于准确CID和类型');
    }
    return '$baseUrl/user/profiles/${Uri.encodeComponent(parts[1])}/assets/${parts[2]}';
  }

  /// 拉取某身份（cid_number）的用户主页资料；钱包 Session 决定双向关注状态。
  /// 响应 profile 含 `account_id`（该身份当前绑定钱包账户，展示用，可能空串）+ `cid_number`。
  Future<CitizenProfileCard> fetchUserCard({
    required String cidNumber,
    SquareSession? session,
  }) async {
    final data = await _getJson(
      '/user/cards/${Uri.encodeComponent(cidNumber)}',
      session: session,
    );
    final card = data['card'];
    if (data['is_ok'] != true ||
        card is! Map<String, dynamic> ||
        card['cid_number'] != cidNumber ||
        card['account_id'] is! String ||
        card['display_name'] is! String ||
        card['profile_at'] is! int) {
      throw const SquareApiException('聊天资料卡响应无效');
    }
    return CitizenProfileCard(card);
  }

  String cardAvatarUrl(String cidNumber) =>
      '$baseUrl/user/cards/${Uri.encodeComponent(cidNumber)}/avatar';

  Future<CitizenProfile> fetchUserProfile({
    required String cidNumber,
    SquareSession? session,
  }) async {
    final data = await _getJson(
      '/user/profiles/${Uri.encodeComponent(cidNumber)}',
      session: session,
    );
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const SquareApiException('用户主页响应缺少资料数据');
    }
    return CitizenProfile.fromJson(profile);
  }

  /// 按作者身份主键 cid_number 分页拉帖。[postCategory]/[postType]
  /// 为空表示不过滤；[cursor] 为上一页 nextCursor。
  Future<({List<SquarePost> posts, int? nextCursor})> fetchAuthorPosts({
    required String cidNumber,
    SquarePostCategory? postCategory,
    SquarePostType? postType,
    int limit = 20,
    int? cursor,
    SquareSession? session,
  }) async {
    final params = <String, String>{'cid_number': cidNumber, 'limit': '$limit'};
    if (postCategory != null) {
      params['post_category'] = postCategory.workerValue;
    }
    if (postType != null) {
      params['post_type'] = postType.workerValue;
    }
    if (cursor != null) {
      params['cursor'] = '$cursor';
    }
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final data = await _getJson('/8964/posts?$query', session: session);
    final posts = data['posts'];
    if (posts is! List) {
      throw const SquareApiException('用户主页响应缺少内容列表');
    }
    return (
      posts: posts
          .whereType<Map<String, dynamic>>()
          .map(_parsePost)
          .toList(growable: false),
      nextCursor: _nullableInt(data['next_cursor']),
    );
  }

  /// 申请头像/背景上传授权：返回object_key与短期上传URL；请求摘要只有原成品一份。
  Future<({String objectKey, String uploadUrl})> prepareProfileAsset({
    required SquareSession session,
    required String uploadKind,
    required String contentType,
    required int byteSize,
    required String contentHash,
  }) async {
    final data = await _postJson('/user/profile/assets', {
      'upload_kind': uploadKind,
      'content_type': contentType,
      'byte_size': byteSize,
      'content_hash': contentHash,
    }, session: session);
    return (
      objectKey: _requireString(data, 'object_key'),
      uploadUrl: _profileUploadUrl(data),
    );
  }

  String _profileUploadUrl(Map<String, dynamic> data) {
    final id = _requireString(data, 'upload_id');
    if (data['http_method'] != 'PUT' ||
        _asInt(data['expires_at']) <= DateTime.now().millisecondsSinceEpoch) {
      throw const SquareApiException('资料上传授权无效或过期');
    }
    return CitizenServeApiConfig.capability(
      baseUrl,
      _requireString(data, 'upload_url'),
      '/user/profile/assets/${Uri.encodeComponent(id)}',
    ).toString();
  }

  /// 仅完整资料头像/背景的只读传输。读取器不持有证明头；外层每次重试都会重新send。
  /// 底层沿用本客户端的HTTPS传输，重试包装须放在此读取器外层以逐次获取证明。
  http.Client profileMediaClient(SquareSession session) =>
      _ProfileMediaClient(this, session);

  /// 每次GET（含Range/条件请求）现签实际方法、原始路径及空正文，不复用证明。
  Future<http.StreamedResponse> openProfileMedia(
    String url, {
    required SquareSession session,
    String? range,
    String? ifRange,
    String? ifNoneMatch,
  }) async {
    final uri = Uri.tryParse(url);
    final prefix = '${baseUri.path}/user/profiles/';
    final tail = uri?.path.startsWith(prefix) == true
        ? uri!.path.substring(prefix.length)
        : '';
    final target = RegExp(
      r'^([A-Za-z0-9][A-Za-z0-9-]{0,31})/assets/(avatar|banner)$',
    ).firstMatch(tail);
    if (uri == null ||
        target == null ||
        uri.scheme != 'https' ||
        uri.origin != baseUri.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.toString() !=
            _uri('/user/profiles/${target.group(1)}/assets/${target.group(2)}')
                .toString()) {
      throw const SquareApiException('资料媒体地址必须是当前服务的准确头像或背景路径');
    }
    if (!session.isUsable) {
      throw const SquareApiException('资料媒体会话已失效', errorCode: 'session_expired');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    if (range != null) request.headers['range'] = range;
    if (ifRange != null) request.headers['if-range'] = ifRange;
    if (ifNoneMatch != null) request.headers['if-none-match'] = ifNoneMatch;
    final response = await _sendProtected(request, session);
    return response;
  }

  Future<http.StreamedResponse> openCardMedia(
    String url, {
    required SquareSession session,
  }) async {
    final uri = Uri.parse(url);
    if (uri.origin != baseUri.origin ||
        !RegExp(r'^/api/user/cards/[A-Za-z0-9-]+/avatar$').hasMatch(uri.path) ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const SquareApiException('名片图片地址无效');
    }
    return _sendProtected(
      http.Request('GET', uri)..followRedirects = false,
      session,
    );
  }

  /// 用户小文件只允许 PUT 到同域 Worker，并对原始字节生成设备请求签名。
  Future<void> uploadBytesTo(
    String uploadUrl,
    List<int> bytes,
    String contentType, {
    SquareSession? session,
  }) async {
    final uri = baseUri.resolve(uploadUrl);
    if (session == null || uri.origin != baseUri.origin) {
      throw const SquareApiException('资源上传地址必须是当前 Worker 且携带钱包会话');
    }
    final body = Uint8List.fromList(bytes);
    final request = http.Request('PUT', uri)
      ..headers['content-type'] = contentType
      ..bodyBytes = body;
    final response = await http.Response.fromStream(
      await _sendProtected(request, session),
    );
    await session.validateCurrent();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SquareApiException(
        '资源上传失败：${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (uri.path.startsWith('/api/user/profile/assets/')) {
      final receipt = _decodeResponse(response);
      if (receipt['content_hash'] != sha256.convert(body).toString()) {
        throw const SquareApiException('资料上传内容回执不一致');
      }
    }
  }

  /// 更新本人公开资料（仅传要改的字段；account_id 由 Worker 从 session 派生）。
  Future<CitizenProfile> updateProfile({
    required SquareSession session,
    String? displayName,
    String? profileBio,
    String? avatarKey,
    String? avatarHash,
    String? bannerKey,
    String? bannerHash,
  }) async {
    final body = <String, Object?>{
      'display_name': ?displayName,
      'profile_bio': ?profileBio,
      'avatar_key': ?avatarKey,
      'avatar_hash': ?avatarHash,
      'banner_key': ?bannerKey,
      'banner_hash': ?bannerHash,
    };
    final data = await _putJson('/user/profile', body, session: session);
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) {
      throw const SquareApiException('更新资料响应缺少资料数据');
    }
    return CitizenProfile.fromJson(profile);
  }

  /// 关注一个身份（写接口带 session；关注者 cid 由 Worker 从 session 派生，
  /// 请求体只带目标身份主键 followed_cid_number）。
  Future<void> followUser({
    required SquareSession session,
    required String followedCidNumber,
  }) async {
    await _postJson('/8964/follows', {
      'followed_cid_number': followedCidNumber,
    }, session: session);
  }

  /// 取消关注一个身份（路径末段 = 目标身份主键 cid_number）。
  Future<void> unfollowUser({
    required SquareSession session,
    required String followedCidNumber,
  }) async {
    await _deleteJson(
      '/8964/follows/${Uri.encodeComponent(followedCidNumber)}',
      session: session,
    );
  }

  /// 开/关对某关注的发帖通知（通知归属挂在关注关系上；须已关注，未关注 Worker 回 409）。
  /// 路径前段 = 目标身份主键 cid_number。
  Future<void> setNotify({
    required SquareSession session,
    required String followedCidNumber,
    required bool enabled,
  }) async {
    await _putJson(
      '/8964/follows/${Uri.encodeComponent(followedCidNumber)}/notifications',
      {'enabled': enabled},
      session: session,
    );
  }

  /// 仅启动、重连、切身份或缺失基线时校准；没有周期轮询。
  Future<Map<String, dynamic>> fetchNotificationState({
    required SquareSession session,
  }) => _getJson('/notifications/unread', session: session);
  Future<Map<String, dynamic>> fetchNotifications({
    required SquareSession session,
    int? cursor,
  }) => _getJson(
    '/notifications?limit=20${cursor == null ? '' : '&cursor=$cursor'}',
    session: session,
  );
  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) => _postJson('/notifications/read', {
    'scope': scope,
    'ids': ids,
    'through': through,
    'post_ids': postIds,
    'comment_ids': commentIds,
  }, session: session);
  Future<Map<String, dynamic>> fetchComments({
    required SquareSession session,
    required String postId,
    int? cursor,
    String? target,
  }) => _getJson(
    '/8964/posts/${Uri.encodeComponent(postId)}/comments?limit=20${cursor == null ? '' : '&cursor=$cursor'}${target == null ? '' : '&target=${Uri.encodeComponent(target)}'}',
    session: session,
  );
  Future<Map<String, dynamic>> createComment({
    required SquareSession session,
    required String postId,
    required String operationId,
    required String replyText,
    String? replyTo,
  }) => _postJson('/8964/posts/${Uri.encodeComponent(postId)}/comments', {
    'operation_id': operationId,
    'reply_text': replyText,
    'reply_to': replyTo,
  }, session: session);
  Future<void> deleteComment({
    required SquareSession session,
    required String postId,
    required String commentId,
  }) async {
    final uri = _uri(
      '/8964/posts/${Uri.encodeComponent(postId)}/comments/${Uri.encodeComponent(commentId)}',
    );
    final response = await _protectedJsonRequest(
      http.Request('DELETE', uri),
      session,
    );
    await session.validateCurrent();
    _decodeResponse(response);
  }

  /// 拉取关注、关注者或互关列表（路由末段 = 目标身份主键 cid_number；列表项为
  /// 身份主键 cid_number）。
  Future<({List<SquareFollowEntry> entries, int? nextCursor})> fetchFollows({
    required String cidNumber,
    required String type,
    int limit = 20,
    int? cursor,
    SquareSession? session,
  }) async {
    final params = <String, String>{
      'cid_number': cidNumber,
      'type': type,
      'limit': '$limit',
    };
    if (cursor != null) {
      params['cursor'] = '$cursor';
    }
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final data = await _getJson('/8964/follows?$query', session: session);
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      throw const SquareApiException('关注列表响应缺少 entries 列表');
    }
    return (
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(SquareFollowEntry.fromJson)
          .toList(growable: false),
      nextCursor: _nullableInt(data['next_cursor']),
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    SquareSession? session,
  }) async {
    // 本客户端所有 GET 均是受保护的公民服务业务；没有公民号会话时不得发出请求。
    if (session == null) {
      throw const SquareApiException(
        '公民服务请求需要已注册身份会话',
        errorCode: 'missing_session',
      );
    }
    final uri = _uri(path);
    if (_closed) {
      throw http.ClientException('服务客户端已关闭');
    }
    final key = (session, uri);
    var pending = _reads[key];
    if (pending != null) {
      await session.validateCurrent();
    } else {
      pending = () async {
        try {
          return await _protectedJsonRequest(http.Request('GET', uri), session);
        } finally {
          _reads.remove(key);
        }
      }();
      _reads[key] = pending;
    }
    final response = await pending;
    if (_closed) {
      throw http.ClientException('服务客户端已关闭');
    }
    await session.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    SquareSession? session,
  }) async {
    final encoded = jsonEncode(body);
    await session?.validateCurrent();
    final uri = _uri(path);
    final response = await _protectedJsonRequest(
      http.Request('POST', uri)
        ..followRedirects = false
        ..body = encoded,
      session,
    );
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, Object?> body, {
    SquareSession? session,
  }) async {
    final encoded = jsonEncode(body);
    final uri = _uri(path);
    final response = await _protectedJsonRequest(
      http.Request('PUT', uri)..body = encoded,
      session,
    );
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _deleteJson(
    String path, {
    SquareSession? session,
  }) async {
    final uri = _uri(path);
    final response = await _protectedJsonRequest(
      http.Request('DELETE', uri),
      session,
    );
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// 先预留再申请MLS证明；证明完成后重查身份，响应头到达即释放短期预留。
  /// 不把下载正文放进计量互斥区，网络无回执时保留已发送的不确定消耗。
  Future<http.StreamedResponse> _sendProtected(
    http.Request request,
    SquareSession? session, {
    int? expectedBytes,
  }) async {
    SquareResourceLease? lease;
    var connectionPreview = false;
    try {
      if (session != null) {
        final uri = request.url;
        final media =
            uri.origin == CitizenServeApiConfig.mediaOrigin &&
            uri.path.startsWith('/square/');
        if (uri.scheme != 'https' || (!media && uri.origin != baseUri.origin)) {
          throw const SquareApiException('受保护请求来源不一致');
        }
        await session.validateCurrent();
        if (media &&
            CitizenServeApiConfig.mediaHeaders(uri.toString(), {
              'authorization': 'Bearer ${session.sessionToken}',
            }).isEmpty) {
          throw const SquareApiException('媒体来源或会话无效');
        }
        final path = media ? uri.path : uri.path.substring(baseUri.path.length);
        var operation = 'account';
        String? target;
        final actions = <String, Map<String, int>>{};
        final costs = <String, int>{};
        if (path == '/tatachat/access') {
          operation = 'chat';
          actions['chat_connect'] = const {};
          connectionPreview = true; // 仅预留后续连接，实际扣量由WS握手回执确认。
        } else if (path.startsWith('/membergate')) {
          operation = path == '/membergate/overview'
              ? 'creator_overview'
              : 'membergate';
        } else if (path.startsWith('/user/cards/')) {
          target = path.split('/')[3];
          operation = path.endsWith('/avatar') ? 'card_avatar' : 'card';
        } else if (path.startsWith('/user/profiles/')) {
          target = path.split('/')[3];
          operation = path.contains('/assets/') ? 'profile_asset' : 'profile';
        } else if (media) {
          operation = 'media';
          actions['media_request'] = const {};
          if (request.method != 'HEAD') {
            actions['media_body'] = {'bytes': expectedBytes ?? 1};
          }
        } else if (path.startsWith('/8964/')) {
          operation =
              path.contains('/feed/') ||
                  path == '/8964/posts' && request.method == 'GET'
              ? 'square_feed'
              : RegExp(r'^/8964/posts/[^/]+$').hasMatch(path) &&
                    request.method == 'GET'
              ? 'square_post'
              : path.endsWith('/confirm')
              ? 'square_publish'
              : 'square';
        }
        if (path == '/8964/uploads' && request.method == 'POST') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          final media = data['media_items'] as List;
          costs['storage_bytes'] =
              (data['manifest_bytes'] as int) +
              media.fold<int>(
                0,
                (n, v) =>
                    n + (v['byte_size'] as int) + (v['preview_bytes'] as int),
              );
        }
        if (operation == 'profile_asset' || operation == 'card_avatar') {
          actions['profile_read'] = const {};
          if (request.method != 'HEAD') {
            actions['media_body'] = {'bytes': expectedBytes ?? 1};
          }
        }
        lease = await resourceGate?.reserve(
          origin: baseUri.origin,
          session: session,
          operation: operation,
          target: target,
          costs: costs,
          actions: actions,
        );
        final signer = session.authenticateRequest;
        if (!media && signer == null) {
          throw const SquareApiException('MLS请求认证未接入，请重新登录');
        }
        request.headers['authorization'] = 'Bearer ${session.sessionToken}';
        if (!media) {
          request.headers.addAll(
            await squareRequestHeadersForBytes(
              method: request.method,
              uri: uri,
              body: request.bodyBytes,
              sessionToken: session.sessionToken,
              authenticate: signer!,
            ),
          );
        }
        await session.validateCurrent();
        if (!session.isUsable || _closed) {
          throw const SquareApiException(
            '当前公民会话不可用',
            errorCode: 'invalid_session',
          );
        }
      }
      request.followRedirects = false;
      request.headers.putIfAbsent(
        'content-type',
        () => 'application/json; charset=utf-8',
      );
      if (!connectionPreview) lease?.sent();
      final abort = Completer<void>();
      final actual =
          http.AbortableRequest(
              request.method,
              request.url,
              abortTrigger: abort.future,
            )
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes
            ..followRedirects = request.followRedirects
            ..maxRedirects = request.maxRedirects
            ..persistentConnection = request.persistentConnection;
      final response = await _http
          .send(actual)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              if (!abort.isCompleted) {
                abort.complete();
              }
              throw TimeoutException('公民服务请求超时');
            },
          );
      lease?.finish(
        headers: response.headers,
        accepted: response.statusCode >= 200 && response.statusCode < 300,
        uncertain: response.statusCode >= 500,
      );
      try {
        await session?.validateCurrent();
      } on Object {
        await response.stream.listen(null).cancel();
        rethrow;
      }
      Stream<List<int>> guarded() async* {
        await for (final chunk in response.stream) {
          await session?.validateCurrent();
          if (_closed || session != null && !session.isUsable) {
            throw const SquareApiException(
              '当前公民会话不可用',
              errorCode: 'session_expired',
            );
          }
          yield chunk;
        }
        await session?.validateCurrent();
      }

      return http.StreamedResponse(
        guarded(),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on Object {
      lease?.cancel();
      rethrow;
    }
  }

  Future<http.Response> _protectedJsonRequest(
    http.Request request,
    SquareSession? session,
  ) async {
    final sample = session == null
        ? null
        : resourceGate?.sample(baseUri.origin, session);
    final response = await http.Response.fromStream(
      await _sendProtected(request, session),
    ).timeout(const Duration(seconds: 20));
    if (session != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (resourceGate != null) await session.validateCurrent();
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          resourceGate?.observe(
            baseUri.origin,
            session,
            data,
            path: request.url.path,
            sample: sample,
          );
          if (data['membergate_state'] is Map<String, dynamic>) {
            resourceGate?.observe(
              baseUri.origin,
              session,
              data['membergate_state'] as Map<String, dynamic>,
              sample: sample,
            );
          }
        }
      } on FormatException {
        /* 正式解码器负责报告损坏响应。 */
      }
    }
    return response;
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    SquareApiStage stage = SquareApiStage.request,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      AppLog.failure(
        stage: stage.name,
        statusCode: response.statusCode,
        code: 'json',
      );
      throw SquareApiException(
        '广场服务响应不是 JSON：${response.statusCode}',
        statusCode: response.statusCode,
        stage: stage,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      AppLog.failure(
        stage: stage.name,
        statusCode: response.statusCode,
        code: 'shape',
      );
      throw SquareApiException(
        '广场服务响应结构不合法：${response.statusCode}',
        statusCode: response.statusCode,
        stage: stage,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLog.failure(
        stage: stage.name,
        statusCode: response.statusCode,
        code: decoded['error_code'] is String
            ? decoded['error_code'] as String
            : null,
      );
      throw SquareApiException(
        decoded['message']?.toString() ?? '广场服务请求失败',
        statusCode: response.statusCode,
        // CitizenServe错误码只来自真实error字符串；未知结构保持失败关闭。
        errorCode: decoded['error_code'] is String
            ? decoded['error_code'] as String
            : null,
        stage: stage,
      );
    }
    return decoded;
  }

  SquarePreparedMediaUpload _parsePreparedMedia(Map<String, dynamic> item) {
    final upload = item['upload'];
    if (upload is! Map<String, dynamic> ||
        item['media_index'] is! int ||
        upload['expires_at'] is! int ||
        upload['headers'] is! Map ||
        (upload['headers'] as Map).entries.any(
          (e) => e.key is! String || e.value is! String,
        )) {
      throw const SquareApiException('媒体上传目标签发不完整');
    }
    return SquarePreparedMediaUpload(
      mediaIndex: item['media_index'] as int,
      objectRole: _requireString(item, 'object_role'),
      objectKey: _requireString(item, 'object_key'),
      url: _requireString(upload, 'url'),
      httpMethod: _requireString(upload, 'http_method'),
      headers: Map<String, String>.from(upload['headers'] as Map),
      expiresAt: upload['expires_at'] as int,
    );
  }

  static List<SquareMembershipPlan> decodeMembershipPlans(Object? value) {
    if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
      throw const SquareApiException("会员档位响应不完整");
    }
    final plans = value
        .whereType<Map<String, dynamic>>()
        .map(_parseMembershipPlan)
        .toList(growable: false);
    if (plans.length != 3 ||
        plans.map((p) => p.memberLevel).toSet().length != 3) {
      throw const SquareApiException('会员三档额度响应不完整');
    }
    return List.unmodifiable(plans);
  }

  static Map<String, int> _quotaMap(Object? value, List<String> fields) {
    if (value is! Map<String, dynamic> ||
        fields.any((key) => !value.containsKey(key))) {
      throw const SquareApiException('会员额度或用量响应不完整');
    }
    final result = <String, int>{};
    for (final entry in value.entries) {
      if (entry.value is! int ||
          entry.value < 0 ||
          entry.value > 9007199254740991) {
        throw const SquareApiException('会员额度或用量无效');
      }
      result[entry.key] = entry.value as int;
    }
    return Map.unmodifiable(result);
  }

  static SquareMembershipPlan _parseMembershipPlan(Map<String, dynamic> data) {
    final level = _requireString(data, 'member_level');
    final name = switch (level) {
      'freedom' => '自由会员',
      'democracy' => '民主会员',
      'spark' => '薪火会员',
      _ => throw const SquareApiException('会员档位未知'),
    };
    final plan = data['plan'], limits = data['limits'];
    const planKeys = {
      'member_level',
      'file_limit',
      'video_max_seconds',
      'video_max_bytes',
      'article_max_images',
      'article_max_videos',
    };
    if (plan is Map &&
        (plan.length != planKeys.length ||
            !plan.keys.every(planKeys.contains))) {
      throw const SquareApiException('会员规格版本不一致');
    }

    if (plan is! Map<String, dynamic> ||
        limits is! Map<String, dynamic> ||
        plan['member_level'] != level) {
      throw const SquareApiException('会员额度响应不完整');
    }
    int quota(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw const SquareApiException('会员额度无效');
      }
      return value;
    }

    final media = _quotaMap(limits, const [
      'image_bytes',
      'image_dimension',
      'storage_bytes',
      'image_quality',
      'thumbnail_bytes',
      'thumbnail_dimension',
      'thumbnail_quality',
      'cover_bytes',
      'cover_dimension',
      'cover_quality',
      'video_width',
      'video_height',
      'video_total_bitrate',
      'video_peak_bitrate',
      'audio_bitrate',
      'video_frame_rate',
      'keyframe_secs',
      'audio_sample_rate',
    ]);
    final resources = _quotaMap(data['resources'], const ['attachment_bytes']);
    final dailyLimits = _quotaMap(
      data['daily_limits'],
      data['daily_limits'] is Map
          ? (data['daily_limits'] as Map).keys.cast<String>().toList()
          : const [],
    );
    if (dailyLimits.isEmpty || dailyLimits.values.any((v) => v <= 0)) {
      throw const SquareApiException('每日资源额度无效');
    }
    final imageQuality = '${quota(limits, 'image_dimension')}px';
    final videoQuality = '${quota(limits, 'video_height')}p';
    return SquareMembershipPlan(
      memberLevel: level,
      displayName: name,
      priceFen: data['price_fen'] == null ? null : quota(data, 'price_fen'),
      fileLimit: quota(plan, 'file_limit'),
      imageBytes: quota(limits, 'image_bytes'),
      imageDimension: quota(limits, 'image_dimension'),
      media: media,
      resources: resources,
      dailyLimits: dailyLimits,
      // 保留既有三档聊天展示能力；授权仍由实际会话和宿主聊天许可决定。
      chat: const SquareChatQuota(
        textEnabled: true,
        emojiEnabled: true,
        stickerEnabled: true,
        imageEnabled: true,
        voiceSecs: 180,
        videoSecs: 180,
        voiceCallEnabled: true,
        videoCallEnabled: true,
      ),
      // 文本/标题上限来自既有发布协议，动态媒体/周期/存储额度只读服务器plan/limits。
      document: SquareDocumentQuota(
        textMaxChars: 300,
        imageQuality: imageQuality,
        maxImages: 9,
      ),
      video: SquareVideoQuota(
        textMaxChars: 300,
        videoQuality: videoQuality,
        videoMaxSeconds: quota(plan, 'video_max_seconds'),
        videoMaxBytes: quota(plan, 'video_max_bytes'),
      ),
      article: SquareArticleQuota(
        titleMinChars: 10,
        titleMaxChars: 50,
        bodyMaxChars: 30000,
        coverQuality: '${quota(limits, 'cover_dimension')}px',
        imageQuality: imageQuality,
        maxImages: quota(plan, 'article_max_images'),
        maxVideos: quota(plan, 'article_max_videos'),
      ),
      usage: SquareMembershipUsageQuota(
        storageBytes: quota(limits, 'storage_bytes'),
      ),
    );
  }

  static SquareMembershipUsageState decodeMembershipUsage(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const SquareApiException('会员用量响应缺失');
    }
    for (final field in [
      'used_bytes',
      'reserved_bytes',
      'day_start',
      'published_count',
      'observed_at',
    ]) {
      final count = value[field];
      if (count is! int || count < 0 || count > 9007199254740991) {
        throw const SquareApiException('会员用量响应无效');
      }
    }
    final attachment = value['attachment'];
    if (attachment != null) {
      if (attachment is! Map<String, dynamic> ||
          !const {'available', 'unavailable'}.contains(attachment['status'])) {
        throw const SquareApiException('聊天存量状态无效');
      }
      if (attachment['status'] == 'available') {
        for (final key in ['observed_at', 'bytes']) {
          final n = attachment[key];
          if (n is! int || n < 0 || n > 9007199254740991) {
            throw const SquareApiException('聊天存量无效');
          }
        }
      }
    }
    return SquareMembershipUsageState(
      usedBytes: _asInt(value['used_bytes']),
      reservedBytes: _asInt(value['reserved_bytes']),
      dayStart: _asInt(value['day_start']),
      daily: _quotaMap(
        value['daily'],
        value['daily'] is Map
            ? (value['daily'] as Map).keys.cast<String>().toList()
            : const [],
      ),
      publishedCount: _asInt(value['published_count']),
      observedAt: value['observed_at'] as int,
      attachment: attachment == null
          ? null
          : Map<String, dynamic>.unmodifiable(
              attachment as Map<String, dynamic>,
            ),
    );
  }

  SquarePost _parsePost(
    Map<String, dynamic> data, {
    Map<String, dynamic>? manifest,
    SquareAuthor? fallbackAuthor,
  }) {
    if (manifest != null &&
        (manifest['schema'] != SquarePostStore.manifestSchema ||
            manifest['cid_number'] != data['cid_number'] ||
            manifest['post_type'] != data['post_type'] ||
            manifest['text'] is! String)) {
      throw const SquareApiException('内容详情核验失败，请重试');
    }
    final postType = _parsePostType(data['post_type']);
    final rawMediaItems = data['media_items'];
    final mediaItems = rawMediaItems is List
        ? rawMediaItems
              .whereType<Map<String, dynamic>>()
              .map(_parseMediaItem)
              .toList(growable: false)
        : const <SquareMediaItem>[];
    // 文章首图是发布协议的必填项。Worker 已在 prepare/complete 两次校验，客户端
    // 仍需对 Feed/详情响应失败关闭，禁止把损坏数据伪装成“无首图文章”正常展示。
    if (postType == SquarePostType.article &&
        (mediaItems.isEmpty ||
            mediaItems.first.mediaKind != SquareMediaKind.image ||
            mediaItems.first.url.isEmpty)) {
      throw const SquareApiException('文章首图缺失');
    }
    return SquarePost(
      postId: _requireString(data, 'post_id'),
      author: SquareAuthor(
        accountId: _requireString(data, 'account_id'),
        cidNumber: data['cid_number']?.toString(),
        // 昵称与头像引用来自Worker的user_data作者投影；缺失时
        // Flutter 优先按作者永久 CID 稳定选择本地默认昵称和照片；纯访客才按账户兜底。
        displayName:
            (data['display_name']?.toString().trim().isNotEmpty ?? false)
            ? data['display_name'].toString().trim()
            : fallbackAuthor?.displayName,
        avatarKey: (data['avatar_key']?.toString().isNotEmpty ?? false)
            ? data['avatar_key'].toString()
            : fallbackAuthor?.avatarKey,
        // 作者徽章信号（Worker feed 已按去重作者读链身份+会员回填）。
        cidLevel: data['cid_level']?.toString() ?? fallbackAuthor?.cidLevel,
        memberLevel:
            data['member_level']?.toString() ?? fallbackAuthor?.memberLevel,
        membergateActive: data.containsKey('membergate_active')
            ? data['membergate_active'] == true
            : fallbackAuthor?.membergateActive ?? false,
      ),
      postCategory: _parseCategory(data['post_category']),
      postType: postType,
      title:
          ((manifest == null ? data['post_title'] : manifest['post_title'])
                  ?.toString()
                  .trim()
                  .isNotEmpty ??
              false)
          ? (manifest == null ? data['post_title'] : manifest['post_title'])
                .toString()
                .trim()
          : null,
      contentSections: manifest != null
          ? parseArticleContentSections(manifest['content_sections'])
          : const <ArticleContentSection>[],
      text:
          (manifest == null ? data['post_excerpt'] : manifest['text'])
              ?.toString() ??
          '',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(
        _asInt(data['published_at']),
      ),
      mediaItems: mediaItems,
      contentHash: data['content_hash']?.toString(),
      receiptId: data['receipt_id']?.toString(),
      chainBlock: _nullableInt(data['chain_block']),
      // 竞选目标（预留）：Worker 暂未返回，待公民身份上链落地后填充。
      campaignInstitutionCid: data['campaign_institution_cid']?.toString(),
      campaignPosition: data['campaign_position']?.toString(),
    );
  }

  SquareMediaItem _parseMediaItem(Map<String, dynamic> data) {
    final url = _requireString(data, 'url');
    final previewUrl = data['preview_url']?.toString() ?? '';
    return SquareMediaItem(
      mediaKind: data['media_kind'] == 'video'
          ? SquareMediaKind.video
          : SquareMediaKind.image,
      url: _resolveMediaUrl(url),
      previewUrl: previewUrl.isEmpty ? null : _resolveMediaUrl(previewUrl),
      byteSize: _nullableInt(data['byte_size']),
      // 横竖屏判定所需原始尺寸；Worker feed 已随 media_items 回传。
      pixelWidth: _nullableInt(data['pixel_width']),
      pixelHeight: _nullableInt(data['pixel_height']),
    );
  }

  static SquarePostType _parsePostType(Object? value) {
    for (final postType in SquarePostType.values) {
      if (value == postType.workerValue) return postType;
    }
    throw const SquareApiException('post_type 不合法');
  }

  Future<void> _uploadFileToR2({
    required SquareSession session,
    required String uploadUrl,
    required String filePath,
    required int contentLength,
    required Map<String, String> headers,
  }) async {
    final file = File(filePath);
    if (contentLength <= 0 || await file.length() != contentLength) {
      throw const SquareApiException('媒体实际大小与上传授权不一致');
    }
    final uri = Uri.parse(uploadUrl);
    await session.validateCurrent();
    final lease = await resourceGate?.reserve(
      origin: baseUri.origin,
      session: session,
      operation: 'square',
    );
    final abort = Completer<void>();
    final request =
        http.AbortableStreamedRequest('PUT', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll(headers)
          ..contentLength = contentLength;
    try {
      await session.validateCurrent();
      if (!session.isUsable) {
        throw const SquarePreflightException('上传会话已失效', 'session_expired');
      }
      lease?.sent();
      final responseFuture = _http
          .send(request)
          .timeout(
            const Duration(hours: 4),
            onTimeout: () {
              if (!abort.isCompleted) {
                abort.complete();
              }
              throw TimeoutException('媒体上传超时');
            },
          );
      unawaited(
        responseFuture.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await request.sink.addStream(
        file.openRead().asyncMap((bytes) async {
          await session.validateCurrent();
          return bytes;
        }),
      );
      await request.sink.close();
      final response = await responseFuture;
      lease?.finish(
        headers: response.headers,
        accepted: response.statusCode >= 200 && response.statusCode < 300,
      );
      await session.validateCurrent();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw SquareApiException('媒体上传失败', statusCode: response.statusCode);
      }
      await response.stream.drain<void>();
    } on Object {
      if (!abort.isCompleted) {
        abort.complete();
      }
      lease?.cancel();
      rethrow;
    }
  }

  Future<T> _retryR2Upload<T>(Future<T> Function() operation) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _r2UploadAttempts; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        if (attempt == _r2UploadAttempts || !_isRetryableR2Error(error)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw SquareApiException('R2 上传失败：$lastError');
  }

  bool _isRetryableR2Error(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return true;
    }
    if (error is SquareApiException) {
      final status = error.statusCode;
      return status == 408 ||
          status == 429 ||
          (status != null && status >= 500);
    }
    return false;
  }

  String _resolveMediaUrl(String value) {
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return value;
    }
    return mediaUrl(value);
  }

  SquarePostCategory _parseCategory(Object? value) {
    return value == 'campaign'
        ? SquarePostCategory.campaign
        : SquarePostCategory.normal;
  }

  static String _requireString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    throw SquareApiException('广场服务响应缺少 $key');
  }

  static String _requireExactString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty && value.trim() == value) {
      return value;
    }
    throw SquareApiException('广场服务响应字段 $key 不合法');
  }

  /// 只接受服务端规范的无填充Base64URL，原始manifest字节不改写。
  static Uint8List _decodeManifest(String value) {
    if (value.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const SquareApiException('manifest_bytes_base64url 不合法');
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (bytes.isEmpty ||
          bytes.length > 256 * 1024 ||
          base64Url.encode(bytes).replaceAll('=', '') != value) {
        throw const SquareApiException('manifest_bytes_base64url 不合法');
      }
      return bytes;
    } on SquareApiException {
      rethrow;
    } on Object {
      throw const SquareApiException('manifest_bytes_base64url 不合法');
    }
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    return _asInt(value);
  }

  void close() {
    _closed = true;
    _sessions.clear();
    _inflightSessions.clear();
    _http.close();
  }
}

/// 同一个请求对象再次send也重建实际GET；旧authorization/证明头永不透传。
/// close只关闭此轻量读取器，不关闭SquareApiClient持有的共享HTTPS客户端。
final class _ProfileMediaClient extends http.BaseClient {
  _ProfileMediaClient(this.api, this.session);
  final SquareApiClient api;
  final SquareSession session;
  bool _closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed || request.method != 'GET' || request.contentLength != 0) {
      throw http.ClientException('资料媒体读取器只接受无正文GET');
    }
    if (request.url.path.startsWith('/api/user/cards/')) {
      return api.openCardMedia(request.url.toString(), session: session);
    }
    return api.openProfileMedia(
      request.url.toString(),
      session: session,
      range: request.headers['range'],
      ifRange: request.headers['if-range'],
      ifNoneMatch: request.headers['if-none-match'],
    );
  }

  @override
  void close() {
    _closed = true;
  }
}
