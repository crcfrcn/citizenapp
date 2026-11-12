import 'package:citizen_network/protocol/chat_frame.pb.dart' as wire;
import 'package:citizen_network/citizen_serve_api_config.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:citizen_system/app_log.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_square/post/square_post_store.dart';
import 'package:citizen_network/hex_codec.dart' show bytesToHex, hexToBytes;
import 'package:citizen_user/identity/mls_authentication.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_network/mls_authentication.dart' as mls;
import 'package:crypto/crypto.dart' show sha256;
import 'package:citizen_network/square_request_signer.dart';
import 'package:citizen_system/notifications/app_push_token.dart';

/// 仅记录产品固定请求阶段，禁止将URL、账户或请求正文当成诊断字段。
enum SquareApiStage { identity, proof, registration, session, request }

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
    wire.ResourceUsage? receipt,
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

/// 仅用于服务端资源预检，不作为链上会员展示状态。
class SquareResourceAuthorization {
  const SquareResourceAuthorization({
    required this.allowed,
    required this.validUntil,
    this.plan,
    this.plans = const [],
    this.usageState,
    this.cleanupAfter,
  });
  final bool allowed;
  final int validUntil;
  final SquareMembershipPlan? plan;
  final List<SquareMembershipPlan> plans;
  final SquareMembershipUsageState? usageState;
  final int? cleanupAfter;
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
    this.cleanupAfter,
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
  final int? cleanupAfter;

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
    this.observedAt = 0,
    this.attachment,
  });

  final int usedBytes;
  final int reservedBytes;
  final int dayStart;
  final Map<String, int> daily;
  final int observedAt;
  final Map<String, dynamic>? attachment;

  Map<String, dynamic> toJson() => {
    'used_bytes': usedBytes,
    'reserved_bytes': reservedBytes,
    'day_start': dayStart,
    'daily': daily,
    'observed_at': observedAt,
    if (attachment != null) 'attachment': attachment,
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
  Future<({SquarePost post, String blockHash, String txHash})>
  readPublishedProof({required SquareSession session, required String postId});
  Future<SquarePost> confirmPublishedPost({
    required SquareSession session,
    required String postId,
    required String blockHash,
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
      final random = Random.secure();
      final request = mls.MlsAuthenticationRequest(
        serviceOrigin: uri.origin,
        tokenPurpose: purpose,
        sessionHash: purpose == 'request'
            ? sha256.convert(utf8.encode(sessionToken!)).toString()
            : null,
        nonceId:
            '0x${bytesToHex(List<int>.generate(32, (_) => random.nextInt(256)))}',
        expiresAt: DateTime.now().millisecondsSinceEpoch + 30000,
        httpMethod: method,
        requestTarget: uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
        bodyBytes: bytes,
      );
      stage = 'proof';
      final proof = await authentication.createProof(
        identity: identity,
        request: request,
      );
      await _requireAuthenticationCurrent(identity, authentication, generation);
      validateMlsProofMatches(identity, request, proof);
      return mlsProofHeaders(proof);
    } on SquareApiException {
      // HTTP和传输失败已在实际发送边界分类，不重复读取或输出正文。
      rethrow;
    } on Object catch (error) {
      AppLog.failure(
        stage: stage,
        code: error is MlsAuthenticationException
            ? error.code
            : error is mls.MlsException
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
        expiry > mls.MlsAuthenticationRequest.maxJsonInteger ||
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
    if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$',
    ).hasMatch(binding.cidNumber)) {
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
    final message = await CitizenSdk.encodePayload(
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
      bytes.add(CitizenScale.compact(raw.length));
      bytes.add(raw);
    }

    void u64(int value) {
      bytes.add(CitizenScale.unsigned(BigInt.from(value), 8));
    }

    string('citizenserve.account_deletion');
    string(baseUri.origin);
    bytes.add(hexToBytes(binding.genesisHash));
    string(binding.cidNumber);
    bytes.add(citizenAccountIdBytes(binding.accountId));
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

  /// 钱包授权已持久保存；每次登记直接使用同一MLS身份签署带随机nonce的真实请求。
  Future<void> registerMlsDevice({
    required MlsAuthenticationIdentity identity,
    required MlsAuthenticationSource authentication,
    required int issuedAt,
    required String bindingSignatureHex,
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
    });
    final headers = await _authenticationHeaders(
      identity: identity,
      authentication: authentication,
      generation: generation,
      purpose: 'device',
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

  /// 服务端只交付本次资源许可、规则和实际用量。
  Future<SquareResourceAuthorization> fetchResourceAuthorization(
    SquareSession session,
  ) async {
    return decodeResourceAuthorization(
      await _getJson('/membergate', session: session),
    );
  }

  /// 许可由宿主当前会话签发；传输可用性仍由聊天适配交付验收。
  Future<CitizenServeChatAccess> fetchChatAccess({
    required SquareSession session,
    required String deviceId,
  }) async {
    if (deviceId != session.deviceId) {
      throw const SquareApiException('聊天许可设备不一致');
    }
    final data = await _postJson('/chat/access', {}, session: session);
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
        realtime.path != '/api/chat/realtime' ||
        realtime.pathSegments.join('/') != 'api/chat/realtime' ||
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

  static SquareResourceAuthorization decodeResourceAuthorization(
    Map<String, dynamic> data,
  ) {
    final authorization = data['authorization'];
    final gate = data['gate'];
    if (data['is_ok'] != true ||
        authorization is! Map<String, dynamic> ||
        authorization['allowed'] is! bool ||
        gate is! Map<String, dynamic> ||
        gate['valid_until'] is! int ||
        (gate['valid_until'] as int) <= 0 ||
        (gate['valid_until'] as int) > 9007199254740991 ||
        data['usage'] is! Map<String, dynamic> ||
        data.containsKey('membergate') ||
        data.containsKey('membergate_active') ||
        data.containsKey('final_hash')) {
      throw const SquareApiException('资源授权响应不完整');
    }
    final plans = decodeMembershipPlans(data['plans']);
    final raw = authorization['plan'];
    if (authorization['allowed'] == true && raw is! Map<String, dynamic> ||
        authorization['allowed'] == false && raw != null) {
      throw const SquareApiException('资源授权档位无效');
    }
    return SquareResourceAuthorization(
      allowed: authorization['allowed'] as bool,
      validUntil: gate['valid_until'] as int,
      plan: raw == null
          ? null
          : _parseMembershipPlan(raw as Map<String, dynamic>),
      plans: plans,
      usageState: decodeMembershipUsage(data['usage']),
      cleanupAfter: decodeCleanupNotice(data['storage_cleanup_notice']),
    );
  }

  static int? decodeCleanupNotice(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic> ||
        value['notified_at'] is! int ||
        value['cleanup_after'] is! int ||
        value['storage_limit_bytes'] is! int ||
        (value['storage_limit_bytes'] as int) <= 0 ||
        (value['notified_at'] as int) <= 0 ||
        value['cleanup_after'] != (value['notified_at'] as int) + 86400000) {
      throw const SquareApiException('会员存储清理提醒无效');
    }
    return value['cleanup_after'] as int;
  }

  /// 联系人逐条备份；完整分页列表只用于明确下拉同步。
  Future<Map<String, dynamic>> fetchUserContacts({
    required SquareSession session,
    String? cursor,
  }) => _getJson(
    '/user/contacts${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    session: session,
  );
  Future<Map<String, dynamic>> saveUserContact({
    required SquareSession session,
    required String cidNumber,
    required String contactRemark,
  }) => _putJson('/user/contacts/${Uri.encodeComponent(cidNumber)}', {
    'contact_remark': contactRemark,
  }, session: session);
  Future<Map<String, dynamic>> deleteUserContact({
    required SquareSession session,
    required String cidNumber,
  }) async {
    await session.validateCurrent();
    final response = await _protectedJsonRequest(
      http.Request(
        'DELETE',
        _uri('/user/contacts/${Uri.encodeComponent(cidNumber)}'),
      )..followRedirects = false,
      session,
    );
    await session.validateCurrent();
    return _decodeResponse(response);
  }

  Future<List<SquarePreparedMediaUpload>> beginUpload({
    required SquareSession session,
    required String postId,
    required String txHash,
    required Uint8List manifest,
  }) async {
    final request =
        http.Request(
            'PUT',
            _uri(
              '/8964/uploads/${Uri.encodeComponent(postId)}/manifest?tx_hash=$txHash',
            ),
          )
          ..followRedirects = false
          ..headers['content-type'] = 'application/json'
          ..bodyBytes = manifest;
    final result = _decodeResponse(
      await _protectedJsonRequest(request, session),
    );
    final targets = result['uploads'];
    if (targets is! List || targets.length > 220) {
      throw const SquareApiException('上传授权不完整');
    }
    return [
      for (final target in targets)
        _parsePreparedMedia(target as Map<String, dynamic>),
    ];
  }

  Future<SquarePreparedMediaUpload?> refreshUpload({
    required SquareSession session,
    required String postId,
    required SquarePreparedMediaUpload target,
  }) async {
    final result = await _postJson('/8964/uploads', {
      'post_id': postId,
      'media_index': target.mediaIndex,
      'preview': target.objectRole != 'source',
    }, session: session);
    final value = result['upload'];
    if (value == null) return null;
    final next = _parsePreparedMedia(value as Map<String, dynamic>);
    if (next.objectKey != target.objectKey ||
        next.mediaIndex != target.mediaIndex ||
        next.objectRole != target.objectRole) {
      throw const SquareApiException('补传目标与原对象不一致');
    }
    return next;
  }

  /// 主文件与预览共用同一有界上传/重试实现；长度来自已经持有的本地声明。
  Future<void> uploadMedia({
    required SquareSession session,
    required SquarePreparedMediaUpload upload,
    required Stream<List<int>> Function() body,
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
        body: body,
        contentLength: byteSize,
        headers: upload.headers,
      ),
    );
  }

  Future<bool> completeUpload({
    required SquareSession session,
    required String postId,
  }) async {
    final response = await _protectedJsonRequest(
      http.Request(
        'POST',
        _uri('/8964/uploads/${Uri.encodeComponent(postId)}/complete'),
      )..followRedirects = false,
      session,
    );
    final state = _decodeResponse(response)['state'];
    if (state != 'complete' && state != 'pending') {
      throw const SquareApiException('上传完成响应无效');
    }
    return state == 'complete';
  }

  @override
  Future<SquarePost> confirmPublishedPost({
    required SquareSession session,
    required String postId,
    required String blockHash,
    required String txHash,
  }) async {
    final data = await _postJson('/8964/posts/confirm', {
      'post_id': postId,
      'block_hash': blockHash,
      'tx_hash': txHash,
    }, session: session);
    if (data['state'] == 'failed') {
      throw const SquareApiException(
        '发布交易最终失败，服务端正在清理本次上传',
        errorCode: 'post_chain_failed',
      );
    }
    return _publishedProof(
      data,
      postId,
      session,
      txHash: txHash,
      blockHash: blockHash,
    ).post;
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
    final rawItems = data['items'];
    if (data['is_ok'] != true || rawItems is! List || rawItems.length > limit) {
      throw const SquareApiException('本人帖子分页无效');
    }
    final items = <SquareLocalPost>[];
    for (final post in rawItems) {
      if (post is! Map<String, dynamic> ||
          post['cid_number'] != session.cidNumber) {
        throw const SquareApiException('本人帖子归属不一致');
      }
      final postId = _requireExactString(post, 'post_id');
      final request = http.Request(
        'GET',
        _uri('/8964/posts/${Uri.encodeComponent(postId)}/manifest'),
      )..followRedirects = false;
      final response = await _sendProtected(request, session);
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw SquareApiException('原始正文读取失败', statusCode: response.statusCode);
      }
      final manifest = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (manifest.length + chunk.length > 256 * 1024) {
          throw const SquareApiException('原始正文大小超限');
        }
        manifest.add(chunk);
      }
      items.add(
        SquarePostStore.validate(
          SquareLocalPost(
            postId: postId,
            cidNumber: session.cidNumber,
            accountId: _requireExactString(post, 'account_id'),
            postCategory: _requireExactString(post, 'post_category'),
            postType: _requireExactString(post, 'post_type'),
            manifestBytes: manifest.takeBytes(),
            contentHash: _requireExactString(post, 'content_hash'),
            receiptId: _requireExactString(post, 'receipt_id'),
            chainBlock: _nullableInt(post['chain_block']),
            publishedAt: _asInt(post['published_at']),
            postState: _requireExactString(post, 'post_state'),
          ),
        ),
      );
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
  Future<({SquarePost post, String blockHash, String txHash})>
  readPublishedProof({
    required SquareSession session,
    required String postId,
  }) async {
    final data = await _getJson(
      '/8964/posts/${Uri.encodeComponent(postId)}',
      session: session,
    );
    return _publishedProof(data, postId, session);
  }

  ({SquarePost post, String blockHash, String txHash}) _publishedProof(
    Map<String, dynamic> data,
    String postId,
    SquareSession session, {
    String? txHash,
    String? blockHash,
  }) {
    final raw = data['post'];
    if (raw is! Map<String, dynamic> ||
        raw['post_id'] != postId ||
        raw['cid_number'] != session.cidNumber ||
        raw['post_state'] != 'published') {
      throw const SquareApiException('发布证明归属或状态不一致');
    }
    final block = raw['block_hash'];
    final tx = raw['tx_hash'];
    if (block is! String ||
        tx is! String ||
        (blockHash != null && blockHash != block) ||
        (txHash != null && txHash != tx) ||
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
      txHash: tx,
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
          return {
            ...item,
            'url': _resolveMediaUrl(_requireString(item, 'url')),
            'preview_url': _resolveMediaUrl(
              _requireString(item, 'preview_url'),
            ),
          };
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
    final posts = data['items'];
    if (posts is! List) {
      throw const SquareApiException('广场 feed 响应缺少内容列表');
    }
    return posts
        .whereType<Map<String, dynamic>>()
        .map(_parsePost)
        .toList(growable: false);
  }

  /// 一次解析私有资料图片键，取得门禁 URL、媒体用途和内容哈希。
  /// 广场帖子媒体由 Worker 返回受公民号及会员门禁保护的 HTTPS 绝对地址，不经过本方法。
  ({String url, String kind, String hash}) resolveProfileMedia(
    String objectKey,
  ) {
    final asset = CitizenProfile.parseAssetKey(objectKey);
    if (asset == null) {
      throw const SquareApiException('资料资源必须属于准确CID和类型');
    }
    return (
      url: '$baseUrl/user/profiles/${asset.cid}/assets/${asset.kind}',
      kind: asset.kind,
      hash: asset.hash,
    );
  }

  /// 拉取某身份（cid_number）的用户主页资料；钱包 Session 决定双向关注状态。
  /// 资料响应只包含永久公民号及业务资料，链上绑定由本机已验证状态提供。
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
  Future<({List<SquarePost> posts, String? nextCursor})> fetchAuthorPosts({
    required String cidNumber,
    SquarePostCategory? postCategory,
    SquarePostType? postType,
    int limit = 20,
    String? cursor,
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
      params['cursor'] = cursor;
    }
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final data = await _getJson('/8964/posts?$query', session: session);
    final posts = data['items'];
    if (posts is! List) {
      throw const SquareApiException('用户主页响应缺少内容列表');
    }
    return (
      posts: posts
          .whereType<Map<String, dynamic>>()
          .map(_parsePost)
          .toList(growable: false),
      nextCursor: data['next_cursor'] as String?,
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
    final key = _requireString(data, 'object_key');
    if (key != 'i/${session.cidNumber}/$uploadKind/$contentHash') {
      throw const SquareApiException('资料上传授权与请求不一致');
    }
    return (objectKey: key, uploadUrl: _profileUploadUrl(data));
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
            _uri(
              '/user/profiles/${target.group(1)}/assets/${target.group(2)}',
            ).toString()) {
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
  Future<void> uploadProfileAsset(
    String uploadUrl,
    Uint8List bytes,
    String contentType, {
    required SquareSession session,
    required String objectKey,
  }) async {
    final uri = baseUri.resolve(uploadUrl);
    if (uri.origin != baseUri.origin ||
        !uri.path.startsWith('${baseUri.path}/user/profile/assets/')) {
      throw const SquareApiException('资源上传地址必须是当前 Worker 的资料上传入口');
    }
    final request = http.Request('PUT', uri)
      ..followRedirects = false
      ..headers['content-type'] = contentType
      ..bodyBytes = bytes;
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
    if (_decodeResponse(response)['object_key'] != objectKey) {
      throw const SquareApiException('资料上传内容回执不一致');
    }
  }

  /// 更新本人公开资料（仅传要改的字段；account_id 由 Worker 从 session 派生）。
  Future<CitizenProfile> updateProfile({
    required SquareSession session,
    String? displayName,
    String? profileBio,
    String? avatarHash,
    String? bannerHash,
  }) async {
    final body = <String, Object?>{
      'display_name': ?displayName,
      'profile_bio': ?profileBio,
      'avatar_hash': ?avatarHash,
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
  /// 请求体只带目标身份主键 peer_cid）。
  Future<void> followUser({
    required SquareSession session,
    required String peerCid,
  }) async {
    await _postJson('/8964/follows', {'peer_cid': peerCid}, session: session);
  }

  /// 取消关注一个身份（路径末段 = 目标身份主键 cid_number）。
  Future<void> unfollowUser({
    required SquareSession session,
    required String peerCid,
  }) async {
    await _deleteJson(
      '/8964/follows/${Uri.encodeComponent(peerCid)}',
      session: session,
    );
  }

  /// 开/关对某关注的发帖通知（通知归属挂在关注关系上；须已关注，未关注 Worker 回 409）。
  /// 路径前段 = 目标身份主键 cid_number。
  Future<void> setNotify({
    required SquareSession session,
    required String peerCid,
    required bool enabled,
  }) async {
    await _putJson(
      '/8964/follows/${Uri.encodeComponent(peerCid)}/notifications',
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
    String? cursor,
    bool groupByPost = false,
    int? through,
  }) {
    final params = <String, String>{
      'limit': '20',
      'cursor': ?cursor,
      if (groupByPost) 'group': 'post',
      if (cursor == null && through != null && through != 0)
        'through': '$through',
    };
    return _getJson(
      '/notifications?${Uri(queryParameters: params).query}',
      session: session,
    );
  }

  Future<Map<String, dynamic>> markNotifyRead({
    required SquareSession session,
    String scope = 'square',
    String? postId,
    List<int> ids = const [],
    int? through,
    List<String> postIds = const [],
    List<String> commentIds = const [],
  }) => _postJson('/notifications/read', {
    'scope': scope,
    'post_id': postId,
    'ids': ids,
    'through': through,
    'post_ids': postIds,
    'comment_ids': commentIds,
  }, session: session);
  Future<Map<String, dynamic>> fetchComments({
    required SquareSession session,
    required String postId,
    String? cursor,
    String? target,
    String? mode,
    String? thread,
    int? through,
  }) {
    final params = <String, String>{
      'limit': '20',
      'cursor': ?cursor,
      'target': ?target,
      'mode': ?mode,
      'thread': ?thread,
      if (through != null) 'through': '$through',
    };
    return _getJson(
      '/8964/posts/${Uri.encodeComponent(postId)}/comments?${Uri(queryParameters: params).query}',
      session: session,
    );
  }

  Future<Map<String, dynamic>> fetchPostInteractions({
    required SquareSession session,
    required List<String> postIds,
  }) => _postJson('/8964/posts/interactions', {
    'post_ids': postIds,
  }, session: session);
  Future<Map<String, dynamic>> fetchLikes({
    required SquareSession session,
    required String postId,
    String? cursor,
    int limit = 20,
  }) => _getJson(
    '/8964/posts/${Uri.encodeComponent(postId)}/likes?limit=$limit${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
    session: session,
  );
  Future<Map<String, dynamic>> setLike({
    required SquareSession session,
    required String postId,
    required bool liked,
  }) async {
    final path = '/8964/posts/${Uri.encodeComponent(postId)}/like';
    if (liked) return _putJson(path, {}, session: session);
    final response = await _protectedJsonRequest(
      http.Request('DELETE', _uri(path)),
      session,
    );
    await session.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> createComment({
    required SquareSession session,
    required String postId,
    required String opId,
    required String replyText,
    String? replyTo,
  }) => _postJson('/8964/posts/${Uri.encodeComponent(postId)}/comments', {
    'op_id': opId,
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
  /// 目标身份主键 peer_cid）。
  Future<({List<SquareFollowEntry> entries, String? nextCursor})> fetchFollows({
    required String cidNumber,
    required String type,
    int limit = 20,
    String? cursor,
    SquareSession? session,
  }) async {
    final params = <String, String>{
      'cid_number': cidNumber,
      'type': type,
      'limit': '$limit',
    };
    if (cursor != null) {
      params['cursor'] = cursor;
    }
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final data = await _getJson('/8964/follows?$query', session: session);
    final rawEntries = data['items'];
    if (rawEntries is! List) {
      throw const SquareApiException('关注列表响应缺少 entries 列表');
    }
    return (
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(SquareFollowEntry.fromJson)
          .toList(growable: false),
      nextCursor: data['next_cursor'] as String?,
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
        if (path == '/chat/access') {
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
    required Stream<List<int>> Function() body,
    required int contentLength,
    required Map<String, String> headers,
  }) async {
    if (contentLength <= 0) {
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
        body().asyncMap((bytes) async {
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
      // 条件写回执可能丢失。原键已有对象时交给 complete 验证原大小和哈希。
      if (response.statusCode != 412 &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
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
    if (value.startsWith('/square/')) {
      return '${CitizenServeApiConfig.mediaOrigin}$value';
    }
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return value;
    }
    return resolveProfileMedia(value).url;
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
