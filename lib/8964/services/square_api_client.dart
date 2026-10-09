import 'package:citizenapp/security/citizen_serve_api_config.dart';
import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:citizenapp/security/chain_bootstrap_api.dart'
    show HttpsOnlyClient;

import 'package:citizenapp/8964/square_models.dart';
import 'package:citizenapp/8964/profile/citizen_profile.dart';
import 'package:citizenapp/8964/services/square_post_store.dart';
import 'package:citizenapp/security/hex_codec.dart' show bytesToHex, hexToBytes;
import 'package:citizenapp/security/mls_authentication.dart';
import 'package:citizenapp/security/identity_binding.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as sdk;
import 'package:crypto/crypto.dart' show sha256;
import 'package:citizenapp/8964/services/square_request_signer.dart';
import 'package:citizenapp/notifications/app_push_token.dart';

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
      : super('注销已受理，云端仍在清理；稍后再次确认可查询进度',
          statusCode: 202, errorCode: 'account_deletion_pending');
}

class SquareSession {
  const SquareSession({
    required this.sessionToken,
    required this.cidNumber,
    required this.bindingRevision,
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
  final int bindingRevision;

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
    required this.expiresAtMillis,
  });

  final Uri realtimeUrl;
  final String accessToken;
  final int expiresAtMillis;
}

class _FinalizedSessionBinding {
  const _FinalizedSessionBinding({
    required this.cidNumber,
    required this.bindingRevision,
    required this.accountId,
  });

  final String cidNumber;
  final int bindingRevision;
  final String accountId;

  bool matches(SquareSession session) =>
      session.cidNumber == cidNumber &&
      session.bindingRevision == bindingRevision &&
      session.accountId == accountId;
}

/// 会员订阅态（ADR-037：与身份彻底解耦）。只描述付费订阅本身，不含任何链上身份信息；
/// 身份展示由身份页（myid）单独负责。
class SquareMembershipState {
  const SquareMembershipState({
    required this.active,
    required this.paidUntil,
    this.membershipLevel,
    this.subscriptionStatus,
    this.subscriptionActive = false,
    this.lastChargedAt = 0,
    this.plans = const <SquareMembershipPlan>[],
    this.usageState,
  });

  final bool active;
  final int paidUntil;
  final String? membershipLevel;

  /// 订阅生命周期态（链上单源镜像）：`active`=自动续费授权有效 /
  /// `terminated`=到期扣款失败并终止 / `cancelled`=用户已签名取消。
  /// 按钮双态与横幅文案据此判定。
  final String? subscriptionStatus;

  /// 订阅是否已支付且未过期（worker `subscription_active`）。解耦后权益态即订阅态，
  /// [active] 与本字段等值；按钮双态与徽章勾均据此判定。
  final bool subscriptionActive;

  /// 最近一次真实扣款时间（毫秒）；与 [paidUntil] 组成会员卡当前已付周期展示。
  final int lastChargedAt;

  final List<SquareMembershipPlan> plans;
  final SquareMembershipUsageState? usageState;

  SquareMembershipPlan? planForLevel(String? level) {
    if (level == null) return null;
    for (final plan in plans) {
      if (plan.membershipLevel == level) return plan;
    }
    return null;
  }

  SquareMembershipPlan? get activePlan =>
      active ? planForLevel(membershipLevel) : null;

  /// 有可展示的订阅起止窗口（已支付且起止时间齐备）。
  bool get hasSubscriptionWindow =>
      subscriptionActive && lastChargedAt > 0 && paidUntil > 0;
}

class SquareMembershipPlan {
  const SquareMembershipPlan({
    required this.membershipLevel,
    required this.displayName,
    required this.chatFileMaxBytes,
    required this.chat,
    required this.document,
    required this.video,
    required this.article,
    required this.usage,
  });

  final String membershipLevel;
  final String displayName;

  /// 聊天文件大小上限（字节，会员权益之一，ADR-037）：自由 10MB / 民主 100MB / 薪火 5GB。
  final int chatFileMaxBytes;
  final SquareChatQuota chat;
  final SquareDocumentQuota document;
  final SquareVideoQuota video;
  final SquareArticleQuota article;
  final SquareMembershipUsageQuota usage;

  /// 提炼展示用短串（卡片与详情页共用，杜绝口径漂移）。
  String get chatFileSizeLabel => _fileSize(chatFileMaxBytes);
  String get chatVoiceDurationLabel => _duration(chat.voiceMessageMaxSeconds);
  String get chatVideoDurationLabel => _duration(chat.videoMessageMaxSeconds);
  String get documentImageQualityLabel => _quality(document.imageQuality);
  String get videoQualityLabel => _quality(video.videoQuality);
  String get videoDurationLabel => _duration(video.maxVideoSeconds);
  String get videoBytesLabel => _decimalFileSize(video.maxVideoBytes);
  String get articleImageQualityLabel => _quality(article.imageQuality);
  String get articleCoverQualityLabel => _quality(article.coverQuality);

  /// 周期额度以服务端定义的完整分钟数展示，不能折算整小时后丢失余下分钟。
  String get monthlyVideoDurationLabel =>
      '${_thousands(usage.monthlyVideoSeconds ~/ 60)} 分钟';
  String get storageSizeLabel => _decimalFileSize(usage.storageBytes);

  String get chatFileLabel => '聊天附件：单个 ≤ ${_fileSize(chatFileMaxBytes)}';

  String get documentLabel =>
      '公文：${document.textMaxChars} 字、${document.maxImages} 张${_quality(document.imageQuality)}图片';

  String get videoLabel =>
      '视频：${video.textMaxChars} 字配文、1 个${_duration(video.maxVideoSeconds)}${_quality(video.videoQuality)}视频';

  String get articleLabel =>
      '文章：${article.bodyMaxChars} 字、${article.maxImages} 张${_quality(article.imageQuality)}图片（含首图）、${article.maxVideos} 个视频、标题 ${article.titleMinChars}-${article.titleMaxChars} 字';

  static String _quality(String value) => value == 'hd' ? '高清' : '标清';

  static String _thousands(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  static String _duration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600} 小时';
    if (seconds >= 60) return '${seconds ~/ 60} 分钟';
    return '$seconds 秒';
  }

  static String _fileSize(int bytes) {
    const mib = 1024 * 1024;
    if (bytes >= 1024 * mib) {
      // 非整 GB 保留一位小数，避免聊天文件额度被取整成失真的整数 GB。
      final gb = bytes / (1024 * mib);
      return gb == gb.roundToDouble()
          ? '${gb.round()}GB'
          : '${gb.toStringAsFixed(1)}GB';
    }
    return '${(bytes / mib).round()}MB';
  }

  /// 广场媒体与存储额度按服务端资源表的十进制字节展示，避免把 300MB 误显为 286MB。
  static String _decimalFileSize(int bytes) {
    const mb = 1000 * 1000;
    const gb = 1000 * mb;
    const tb = 1000 * gb;
    if (bytes >= tb && bytes % tb == 0) return '${bytes ~/ tb}TB';
    if (bytes >= gb && bytes % gb == 0) return '${bytes ~/ gb}GB';
    if (bytes >= mb && bytes % mb == 0) return '${bytes ~/ mb}MB';
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
    required this.voiceMessageMaxSeconds,
    required this.videoMessageMaxSeconds,
    required this.voiceCallEnabled,
    required this.videoCallEnabled,
  });

  final bool textEnabled;
  final bool emojiEnabled;
  final bool stickerEnabled;
  final bool imageEnabled;
  final int voiceMessageMaxSeconds;
  final int videoMessageMaxSeconds;
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
    required this.maxVideoSeconds,
    required this.maxVideoBytes,
  });

  final int textMaxChars;
  final String videoQuality;
  final int maxVideoSeconds;

  /// 单个发布视频体积上限（十进制字节）：自由 16MB / 民主 300MB / 薪火 3GB。
  final int maxVideoBytes;
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

/// 会员用量额度结构与 Worker `usage` 对象逐字段对应。
class SquareMembershipUsageQuota {
  const SquareMembershipUsageQuota({
    required this.monthlyImages,
    required this.monthlyVideoSeconds,
    required this.activeUploads,
    required this.storageBytes,
  });

  final int monthlyImages;
  final int monthlyVideoSeconds;
  final int activeUploads;

  /// 当前档位允许占用的总存储空间（十进制字节），不随订阅周期重置。
  final int storageBytes;
}

/// 当前会员已用量与未过期上传预留的合计；手机端只用于发布前预检。
class SquareMembershipUsageState {
  const SquareMembershipUsageState({
    required this.periodStart,
    required this.periodEnd,
    required this.imageCount,
    required this.videoSeconds,
    required this.activeUploads,
  });

  final int periodStart;
  final int periodEnd;
  final int imageCount;
  final int videoSeconds;
  final int activeUploads;
}

class SquareUploadMediaRequest {
  const SquareUploadMediaRequest({
    required this.mediaKind,
    required this.contentType,
    required this.byteSize,
    required this.sha256,
    required this.width,
    required this.height,
    required this.derivativeKind,
    required this.derivativeContentType,
    required this.derivativeByteSize,
    required this.derivativeSha256,
    this.durationSeconds,
  });

  final SquareMediaKind mediaKind;
  final String contentType;
  final int byteSize;
  final String sha256;
  final int width;
  final int height;
  final String derivativeKind;
  final String derivativeContentType;
  final int derivativeByteSize;
  final String derivativeSha256;
  final int? durationSeconds;

  Map<String, Object?> toJson() => {
    'media_kind': mediaKind.workerValue,
    'content_type': contentType,
    'byte_size': byteSize,
    'sha256': sha256,
    'width': width,
    'height': height,
    'derivative_kind': derivativeKind,
    'derivative_content_type': derivativeContentType,
    'derivative_byte_size': derivativeByteSize,
    'derivative_sha256': derivativeSha256,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
  };
}

class SquarePreparedMediaUpload {
  const SquarePreparedMediaUpload({
    required this.mediaKind,
    required this.contentType,
    required this.byteSize,
    required this.objectKey,
    required this.uploadMethod,
    required this.uploadUrl,
    required this.uploadHeaders,
    required this.derivativeKind,
    required this.derivativeByteSize,
    required this.derivativeObjectKey,
    required this.derivativeUploadUrl,
    required this.derivativeUploadHeaders,
  });

  final SquareMediaKind mediaKind;
  final String contentType;
  final int byteSize;
  final String objectKey;
  final String uploadMethod;
  final String uploadUrl;
  final Map<String, String> uploadHeaders;
  final String derivativeKind;
  final int derivativeByteSize;
  final String derivativeObjectKey;
  final String derivativeUploadUrl;
  final Map<String, String> derivativeUploadHeaders;
}

class SquarePreparedUpload {
  const SquarePreparedUpload({
    required this.uploadId,
    required this.postId,
    required this.storageReceiptId,
    required this.expiresAt,
    required this.estimatedBytes,
    required this.manifestObjectKey,
    required this.manifestUploadUrl,
    required this.mediaItems,
  });

  final String uploadId;
  final String postId;
  final String storageReceiptId;
  final int expiresAt;
  final int estimatedBytes;
  final String manifestObjectKey;
  final String manifestUploadUrl;
  final List<SquarePreparedMediaUpload> mediaItems;
}

class SquareCompletedUpload {
  const SquareCompletedUpload({
    required this.uploadId,
    required this.postId,
    required this.contentHash,
    required this.storageReceiptId,
    required this.storageState,
  });

  final String uploadId;
  final String postId;
  final String contentHash;
  final String storageReceiptId;
  final String storageState;
}

class SquareBrowseState {
  const SquareBrowseState({
    required this.browseDay,
    required this.browseCount,
    required this.browseLimit,
    required this.browseLeft,
  });

  final String browseDay;
  final int browseCount;
  final int? browseLimit;
  final int? browseLeft;
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

  static const int _r2UploadAttempts = 3;

  static final List<WeakReference<SquareApiClient>> _liveClients =
      <WeakReference<SquareApiClient>>[];
  static _FinalizedSessionBinding? _finalizedSessionBinding;

  /// finalized 绑定切换后立即清除所有现存 API 客户端中的非当前 Session。
  ///
  /// WeakReference 不延长页面级客户端生命周期；仍在进行的此前账户握手即使稍后返回，
  /// 也会在落入缓存前再次核对本绑定并失败关闭。
  static void activateFinalizedBinding({
    required String cidNumber,
    required int bindingRevision,
    required String accountId,
  }) {
    final previous = _finalizedSessionBinding;
    if (previous?.cidNumber == cidNumber &&
        previous?.bindingRevision == bindingRevision &&
        previous?.accountId == accountId) {
      return;
    }
    final binding = _FinalizedSessionBinding(
      cidNumber: cidNumber,
      bindingRevision: bindingRevision,
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
  SquareBrowseState? lastBrowseState;
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
        cached.bindingRevision == identity.bindingRevision &&
        cached.deviceId == identity.deviceId &&
        (_finalizedSessionBinding == null ||
            _finalizedSessionBinding!.matches(cached))) {
      await authentication.requireCurrent(identity);
      return cached;
    }
    _sessions.remove(accountId);
    final key = identity.cacheKey;
    final pending = _inflightSessions[key];
    if (pending != null) return pending;
    late final Future<SquareSession> future;
    future = () async {
      try {
        return await _establishSession(identity, authentication, generation);
      } on SquareApiException catch (error) {
        if (error.errorCode != 'device_not_registered' ||
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
    if (uri.origin != baseUri.origin) {
      throw const MlsAuthenticationException('MLS认证目标服务不一致');
    }
    final bytes = List<int>.unmodifiable(body);
    await _requireAuthenticationCurrent(identity, authentication, generation);
    final challenge = await _postAuthentication(
      '/user/challenges',
      jsonEncode({
        'account_id': identity.accountId,
        'public_key': identity.publicKey,
        'purpose': purpose,
        'method': method,
        'request_target': uri.path + (uri.hasQuery ? '?${uri.query}' : ''),
        'body_sha256': '0x${sha256.convert(bytes)}',
      }),
      sessionToken: sessionToken,
    );
    await _requireAuthenticationCurrent(identity, authentication, generation);
    final nonce = challenge['challenge'];
    final expiry = challenge['expires_at_millis'];
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
    final proof = await authentication.createProof(
      identity: identity,
      request: request,
      challenge: challenge,
    );
    await _requireAuthenticationCurrent(identity, authentication, generation);
    validateMlsProofMatches(identity, request, challenge, proof);
    return mlsProofHeaders(proof);
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
      throw SquareApiException(
        '网络连接失败',
        errorCode: 'network_unavailable',
        stage: stage,
      );
    } on TimeoutException {
      throw SquareApiException(
        '网络请求超时',
        errorCode: 'network_unavailable',
        stage: stage,
      );
    } on http.ClientException {
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
      'ok',
      'session_token',
      'cid_number',
      'device_id',
      'binding_revision',
      'account_id',
      'expires_at',
    };
    final token = response['session_token'];
    final expiry = response['expires_at'];
    if (response.length != fields.length ||
        !response.keys.every(fields.contains) ||
        response['ok'] != true ||
        token is! String ||
        token.isEmpty ||
        expiry is! int ||
        expiry <= DateTime.now().millisecondsSinceEpoch ||
        expiry > sdk.MlsAuthenticationRequest.maxJsonInteger ||
        response['cid_number'] != identity.cidNumber ||
        response['device_id'] != identity.deviceId ||
        response['account_id'] != identity.accountId ||
        response['binding_revision'] != identity.bindingRevision) {
      throw const MlsAuthenticationException('MLS会话响应与当前身份不一致');
    }
    final next = SquareSession(
      sessionToken: token,
      cidNumber: identity.cidNumber,
      deviceId: identity.deviceId,
      bindingRevision: identity.bindingRevision,
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
    _sessions[identity.accountId] = next;
    return next;
  }

  /// 清除某账户的本地会话缓存（注销后调用，配合 Worker 端会话失效实现零残留）。
  void clearSession(String accountId) {
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
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,31}$').hasMatch(binding.cidNumber)) {
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
               current.bindingRevision != binding.bindingRevision))) {
        throw const SquareApiException('当前身份已变化，请重新打开本人主页');
      }
    }
    await check();
    final cached = _sessions[binding.accountId];
    final session = cached != null && cached.isUsable ? cached : null;
    if (session != null &&
        (session.cidNumber != binding.cidNumber ||
         session.bindingRevision != binding.bindingRevision)) {
      throw const SquareApiException('注销会话与当前绑定不一致');
    }
    var purpose = session == null ? 'status' : 'delete';
    Map<String, dynamic> challenge;
    if (session != null) {
      try {
        challenge = await _postJson('/user/deletion/challenges', {}, session: session, rejectRedirects: true);
      } on SquareApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        purpose = 'status';
        challenge = await _postJson('/user/deletion/status/challenges', {
          'cid_number': binding.cidNumber, 'account_id': binding.accountId,
        }, rejectRedirects: true);
      }
    } else {
      challenge = await _postJson('/user/deletion/status/challenges', {
        'cid_number': binding.cidNumber, 'account_id': binding.accountId,
      }, rejectRedirects: true);
    }
    await check();
    final payload = _accountDeletionPayload(challenge, binding, purpose);
    final message = await CitizenSigning.encodePayload(CitizenSigningPayload.message(
      opTag: kOpSignSquareAction, scalePayload: payload,
    ));
    await check();
    final signature = await signAction(message);
    await check();
    _accountDeletionPayload(challenge, binding, purpose);
    final receipt = await _postJson(
      purpose == 'delete' ? '/user/deletion' : '/user/deletion/status',
      {'challenge_id': challenge['challenge_id'], 'signature': signature},
      session: purpose == 'delete' ? session : null,
      rejectRedirects: true,
    );
    await check();
    const fields = {'ok','cid_number','account_id','binding_revision','deletion_id','state'};
    final state = receipt['state'];
    final id = receipt['deletion_id'];
    if (receipt.length != fields.length || !receipt.keys.every(fields.contains) ||
        receipt['ok'] != true || receipt['cid_number'] != binding.cidNumber ||
        receipt['account_id'] != binding.accountId ||
        receipt['binding_revision'] != binding.bindingRevision ||
        !const {'absent','pending','complete'}.contains(state) ||
        (state == 'absent' ? id != null : id is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(id))) {
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
    Map<String, dynamic> challenge, IdentityBinding binding, String purpose,
  ) {
    const fields = {'ok','purpose','challenge_id','cid_number','account_id','binding_revision',
      'chain_scope','service_origin','expires_at_millis','signing_payload_hex'};
    final id = challenge['challenge_id'];
    final expiry = challenge['expires_at_millis'];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (challenge.length != fields.length || !challenge.keys.every(fields.contains) ||
        challenge['ok'] != true || challenge['purpose'] != purpose ||
        challenge['cid_number'] != binding.cidNumber ||
        challenge['account_id'] != binding.accountId ||
        challenge['binding_revision'] != binding.bindingRevision ||
        challenge['chain_scope'] != binding.genesisHash ||
        challenge['service_origin'] != baseUri.origin ||
        id is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        expiry is! int || expiry <= now || expiry > now + 300000 ||
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
    u64(binding.bindingRevision);
    bytes.addByte(purpose == 'delete' ? 0 : 1);
    bytes.add(hexToBytes(id));
    u64(expiry);
    final payload = bytes.takeBytes();
    if (challenge['signing_payload_hex'] != '0x' + bytesToHex(payload)) {
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
    required String? enrollmentId,
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
      'enrollment_id': enrollmentId,
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
    const fields = {'ok', 'cid_number', 'binding_revision', 'device_id'};
    if (response.length != fields.length ||
        !response.keys.every(fields.contains) ||
        response['ok'] != true ||
        response['cid_number'] != identity.cidNumber ||
        response['device_id'] != identity.deviceId ||
        response['binding_revision'] != identity.bindingRevision) {
      throw const MlsAuthenticationException('MLS登记回执与当前身份不一致');
    }
  }

  /// 读取 CitizenServe 的平台会员快照。该方法只解析响应，不修改页面或聊天全局状态；
  /// 会话级去重、本地缓存和刷新广播统一由 SubscriptionService 负责。
  Future<SquareMembershipState> fetchMembership(SquareSession session) async {
    const membershipPath = '/membership';
    final data = await _getJson(membershipPath, session: session);
    return _parseMembershipState(data);
  }

  /// 许可由宿主当前会话签发；传输可用性仍由聊天适配交付验收。
  Future<CitizenServeChatAccess> fetchChatAccess({
    required SquareSession session,
    required String deviceId,
  }) async {
    if (deviceId != session.deviceId) {
      throw const SquareApiException('聊天许可设备不一致');
    }
    final data = await _postJson(
      '/tatachat/access',
      {},
      session: session,
      rejectRedirects: true,
    );
    final realtime = Uri.tryParse(_requireString(data, 'realtime_url'));
    final token = _requireString(data, 'access_token');
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = data['expires_at'];
    final recheck = data['recheck_at'];
    if (data['ok'] != true ||
        data.length != 5 ||
        realtime == null ||
        realtime.scheme != 'wss' ||
        realtime.host != baseUri.host ||
        realtime.port != baseUri.port ||
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
      expiresAtMillis: expiry,
    );
  }

  /// finalized投影是公开链证据，不接收客户端自报CID或账户。
  Future<void> projectFinalizedIdentity(String blockHash) async {
    if (!RegExp(r'^0x[0-9a-f]{64}$').hasMatch(blockHash)) {
      throw const SquareApiException('finalized块无效');
    }
    final data = await _postJson('/user/identity', {'block_hash': blockHash});
    if (data['ok'] != true) throw const SquareApiException('身份投影尚未完成');
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
      'apns_environment': environment,
      'expires_at': expiresAt,
    }, session: session);
    if (data['ok'] != true || data['expires_at'] is! num) {
      throw const SquareApiException('应用推送端点响应不合法');
    }
  }

  SquareMembershipState _parseMembershipState(Map<String, dynamic> data) {
    final membership = data['membership'];
    final active = data['membership_active'] == true;
    final subscriptionActive = data['membership_active'] == true;
    final plans = _parseMembershipPlans(data['plans']);
    final usageState = _parseMembershipUsageState(
      data['usage'],
      data['membership'],
    );
    // 会员与身份解耦（ADR-037）：响应只含订阅与套餐，无身份/冻结字段。
    if (membership is! Map<String, dynamic>) {
      return SquareMembershipState(
        active: false,
        paidUntil: 0,
        plans: plans,
        usageState: usageState,
      );
    }
    final membershipLevel = membership['membership_level']?.toString();
    return SquareMembershipState(
      active: active,
      paidUntil: _asInt(membership['paid_until']),
      membershipLevel: membershipLevel,
      subscriptionStatus: membership['subscription_status']?.toString(),
      subscriptionActive: subscriptionActive,
      lastChargedAt: _asInt(membership['last_charged_at']),
      plans: plans,
      usageState: usageState,
    );
  }

  /// 平台会员变更 finalized 后先核对交易/块回执，再读取同一会话的真实会员快照。
  /// 两次请求都使用各自新鲜的MLS证明；回执或快照失败时保留原交易恢复记录。
  Future<SquareMembershipState> confirmPlatformSubscription({
    required SquareSession session,
    required String txHash,
    required String blockHashHex,
  }) async {
    final hash = RegExp(r'^0x[0-9a-f]{64}$');
    if (!hash.hasMatch(txHash) || !hash.hasMatch(blockHashHex)) {
      throw const SquareApiException('会员确认交易或块无效');
    }
    final data = await _postJson(
      '/membership/confirm',
      {'tx_hash': txHash, 'block_hash': blockHashHex},
      session: session,
    );
    if (data.length != 3 ||
        data['ok'] != true ||
        data['tx_hash'] != txHash ||
        data['block_hash'] != blockHashHex) {
      throw const SquareApiException('会员确认回执与本次交易不一致');
    }
    return fetchMembership(session);
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
    required String manifestHash,
    required int manifestByteSize,
    required List<SquareUploadMediaRequest> mediaItems,
  }) async {
    final data = await _postJson('/8964/uploads', {
      'post_type': postType.workerValue,
      'title_length': titleLength,
      'text_length': textLength,
      'manifest_hash': manifestHash,
      'manifest_byte_size': manifestByteSize,
      'media_items': mediaItems.map((item) => item.toJson()).toList(),
    }, session: session);
    final rawMediaItems = data['media_uploads'];
    final manifest = data['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw const SquareApiException('上传准备响应缺少manifest');
    }
    if (rawMediaItems is! List) {
      throw const SquareApiException('上传准备响应缺少媒体对象列表');
    }
    return SquarePreparedUpload(
      uploadId: _requireString(data, 'upload_id'),
      postId: _requireString(data, 'post_id'),
      storageReceiptId: _requireString(data, 'storage_receipt_id'),
      expiresAt: _asInt(data['expires_at']),
      estimatedBytes: _asInt(data['estimated_bytes']),
      manifestObjectKey: _requireString(manifest, 'object_key'),
      manifestUploadUrl: CitizenServeApiConfig.capability(
        baseUrl,
        _requireString(manifest, 'upload_url'),
        '/8964/uploads/${Uri.encodeComponent(_requireString(data, 'upload_id'))}/manifest',
      ).toString(),
      mediaItems: rawMediaItems
          .map((item) => _parsePreparedMedia(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Future<void> uploadObject({
    required String uploadUrl,
    required String contentType,
    required Uint8List body,
    required SquareSession session,
  }) async {
    await uploadBytesTo(uploadUrl, body, contentType, session: session);
  }

  Future<void> uploadMediaAsset({
    required SquarePreparedMediaUpload upload,
    required String filePath,
  }) async {
    if (upload.uploadMethod != 'r2_put') {
      throw const SquareApiException('媒体上传方式不受支持');
    }
    await _retryR2Upload<void>(
      () => _uploadFileToR2(
        uploadUrl: upload.uploadUrl,
        filePath: filePath,
        contentLength: upload.byteSize,
        headers: upload.uploadHeaders,
      ),
    );
  }

  Future<void> uploadMediaDerivative({
    required SquarePreparedMediaUpload upload,
    required String filePath,
  }) => _retryR2Upload<void>(
    () => _uploadFileToR2(
      uploadUrl: upload.derivativeUploadUrl,
      filePath: filePath,
      contentLength: upload.derivativeByteSize,
      headers: upload.derivativeUploadHeaders,
    ),
  );

  Future<SquareCompletedUpload> completeUpload({
    required SquareSession session,
    required String uploadId,
    required String manifestHash,
    required String contentHash,
  }) async {
    final data = await _postJson(
      '/8964/uploads/${Uri.encodeComponent(uploadId)}/complete',
      {'manifest_hash': manifestHash, 'content_hash': contentHash},
      session: session,
    );
    return SquareCompletedUpload(
      uploadId: _requireString(data, 'upload_id'),
      postId: _requireString(data, 'post_id'),
      contentHash: _requireString(data, 'content_hash'),
      storageReceiptId: _requireString(data, 'storage_receipt_id'),
      storageState: _requireString(data, 'storage_state'),
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
    final post = data['post'];
    if (post is! Map<String, dynamic>) {
      throw const SquareApiException('广场确认发布响应缺少内容数据');
    }
    return _parsePost(post);
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
    if (rawItems is! List || rawItems.length > limit) {
      throw const SquareApiException('本人副本回灌 items 不合法');
    }
    final items = <SquareLocalPost>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const SquareApiException('本人副本回灌条目不合法');
      }
      final cidNumber = _requireExactString(rawItem, 'cid_number');
      if (cidNumber != session.cidNumber) {
        throw const SquareApiException('本人副本回灌 CID 与当前会话不一致');
      }
      final postCategory = _requireExactString(rawItem, 'post_category');
      if (postCategory != 'normal' && postCategory != 'campaign') {
        throw const SquareApiException('本人副本回灌 post_category 不合法');
      }
      final postType = _requireExactString(rawItem, 'post_type');
      if (postType != 'document' &&
          postType != 'article' &&
          postType != 'video') {
        throw const SquareApiException('本人副本回灌 post_type 不合法');
      }
      final contentHash = _requireExactString(rawItem, 'content_hash');
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
        throw const SquareApiException('本人副本回灌 content_hash 不合法');
      }
      final postState = _requireExactString(rawItem, 'post_state');
      if (postState != SquarePostStore.publishedState) {
        throw const SquareApiException('本人副本回灌只允许 published');
      }
      final chainBlockValue = rawItem['chain_block'];
      if (chainBlockValue != null &&
          (chainBlockValue is! int || chainBlockValue < 0)) {
        throw const SquareApiException('本人副本回灌 chain_block 不合法');
      }
      final createdAt = rawItem['created_at'];
      if (createdAt is! int || createdAt <= 0) {
        throw const SquareApiException('本人副本回灌 created_at 不合法');
      }
      items.add(
        SquareLocalPost(
          postId: _requireExactString(rawItem, 'post_id'),
          cidNumber: cidNumber,
          accountId: _requireExactString(rawItem, 'account_id'),
          postCategory: postCategory,
          postType: postType,
          manifestBytes: _decodeManifestBase64(
            _requireExactString(rawItem, 'manifest_bytes_base64'),
          ),
          contentHash: contentHash,
          storageReceiptId: _requireExactString(rawItem, 'storage_receipt_id'),
          chainBlock: chainBlockValue as int?,
          createdAt: createdAt,
          postState: postState,
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

  /// 详情接口在确认 D1 可见状态后读取并校验 R2 manifest；Feed 只携带摘要。
  Future<SquarePost> fetchPostDetail({
    required SquareSession session,
    required SquarePost summary,
  }) async {
    final data = await _getJson(
      '/8964/posts/${Uri.encodeComponent(summary.postId)}',
      session: session,
    );
    final post = data['post'];
    if (post is! Map<String, dynamic>) {
      throw const SquareApiException('内容详情响应缺少内容数据');
    }
    return _parsePost(post, isDetail: true, fallbackAuthor: summary.author);
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
    final block = raw['chain_block_hash'];
    final tx = raw['tx_hash'];
    if (block is! String ||
        tx is! String ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(block) ||
        !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(tx)) {
      throw const SquareApiException('发布证明缺少区块或交易哈希');
    }
    return (
      post: _parsePost(raw, isDetail: true),
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

  /// 公开帖子媒体流不携带会话凭据，拒绝重定向及非HTTPS地址。
  Future<http.StreamedResponse> openPostMedia(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const SquareApiException('媒体地址必须使用HTTPS');
    }
    final response = await _http
        .send(http.Request('GET', uri)..followRedirects = false)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
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
    lastBrowseState = _parseBrowseState(data);
    return posts
        .whereType<Map<String, dynamic>>()
        .map(_parsePost)
        .toList(growable: false);
  }

  /// 把私有头像、背景的 R2 object_key 拼成 Worker 会话门禁 URL。
  /// 广场帖子媒体由 Worker 直接返回公开 CDN 绝对地址，不经过本方法。
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

  /// 按作者身份主键 cid_number 分页拉帖。[category]/[postType]
  /// 为空表示不过滤；[cursor] 为上一页 nextCursor。
  Future<({List<SquarePost> posts, int? nextCursor})> fetchAuthorPosts({
    required String cidNumber,
    SquarePostCategory? category,
    SquarePostType? postType,
    int limit = 20,
    int? cursor,
    SquareSession? session,
  }) async {
    final params = <String, String>{'cid_number': cidNumber, 'limit': '$limit'};
    if (category != null) {
      params['category'] = category.workerValue;
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
    lastBrowseState = _parseBrowseState(data);
    return (
      posts: posts
          .whereType<Map<String, dynamic>>()
          .map(_parsePost)
          .toList(growable: false),
      nextCursor: _nullableInt(data['next_cursor']),
    );
  }

  /// 申请头像/背景上传授权：返回 object_key、内容哈希与短期上传 URL。
  Future<({String objectKey, String contentHash, String uploadUrl})>
  prepareProfileAsset({
    required SquareSession session,
    required String kind,
    required String contentType,
    required int byteSize,
    required String sha256Hex,
  }) async {
    final data = await _postJson('/user/profile/assets', {
      'kind': kind,
      'content_type': contentType,
      'byte_size': byteSize,
      'sha256': sha256Hex,
    }, session: session);
    return (
      objectKey: _requireString(data, 'object_key'),
      contentHash: sha256Hex,
      uploadUrl: _profileUploadUrl(data),
    );
  }

  String _profileUploadUrl(Map<String, dynamic> data) {
    final id = _requireString(data, 'upload_id');
    if (data['method'] != 'PUT' ||
        _asInt(data['expires_at']) <= DateTime.now().millisecondsSinceEpoch) {
      throw const SquareApiException('资料上传授权无效或过期');
    }
    return CitizenServeApiConfig.capability(
      baseUrl,
      _requireString(data, 'upload_url'),
      '/user/profile/assets/${Uri.encodeComponent(id)}',
    ).toString();
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
    final signer = session.authenticateRequest;
    if (signer == null) {
      throw const SquareApiException('MLS请求认证未接入，请重新登录');
    }
    await session.validateCurrent();
    final body = Uint8List.fromList(bytes);
    final headers = <String, String>{
      'content-type': contentType,
      'authorization': 'Bearer ${session.sessionToken}',
      ...await squareRequestHeadersForBytes(
        method: 'PUT',
        uri: uri,
        body: body,
        sessionToken: session.sessionToken,
        authenticate: signer,
      ),
    };
    final response = await _http
        .put(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 60));
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

  /// 更新本人公开资料（仅传要改的字段；accountId 由 Worker 从 session 派生）。
  Future<CitizenProfile> updateProfile({
    required SquareSession session,
    String? displayName,
    String? bio,
    String? avatarObjectKey,
    String? avatarContentHash,
    String? bannerObjectKey,
    String? bannerContentHash,
  }) async {
    final body = <String, Object?>{
      'display_name': ?displayName,
      'bio': ?bio,
      'avatar_object_key': ?avatarObjectKey,
      'avatar_content_hash': ?avatarContentHash,
      'banner_object_key': ?bannerObjectKey,
      'banner_content_hash': ?bannerContentHash,
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

  /// 拉取发帖通知双游标红点计数：广场底部 tab 与关注子 tab 各一。
  Future<({int squareUnread, int followingUnread})> fetchNotifyUnread({
    required SquareSession session,
  }) async {
    final data = await _getJson('/notifications/unread', session: session);
    return (
      squareUnread: (data['square_unread'] as num?)?.toInt() ?? 0,
      followingUnread: (data['following_unread'] as num?)?.toInt() ?? 0,
    );
  }

  /// 推进某作用域的已读游标（`square` 进广场清、`following` 进关注子 tab 清），红点归零。
  Future<void> markNotifyRead({
    required SquareSession session,
    required String scope,
  }) async {
    await _postJson('/notifications/read', {'scope': scope}, session: session);
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
    final uri = _uri(path);
    final response = await _http
        .get(uri, headers: await _headers('GET', uri, '', session))
        .timeout(const Duration(seconds: 20));
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    SquareSession? session,
    bool rejectRedirects = false,
  }) async {
    final encoded = jsonEncode(body);
    await session?.validateCurrent();
    final uri = _uri(path);
    final headers = await _headers('POST', uri, encoded, session);
    final response =
        await (rejectRedirects
                ? () async {
                    final request = http.Request('POST', uri)
                      ..followRedirects = false
                      ..headers.addAll(headers)
                      ..body = encoded;
                    return http.Response.fromStream(await _http.send(request));
                  }()
                : _http.post(uri, headers: headers, body: encoded))
            .timeout(const Duration(seconds: 20));
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
    final response = await _http
        .put(
          uri,
          headers: await _headers('PUT', uri, encoded, session),
          body: encoded,
        )
        .timeout(const Duration(seconds: 20));
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _deleteJson(
    String path, {
    SquareSession? session,
  }) async {
    final uri = _uri(path);
    final response = await _http
        .delete(uri, headers: await _headers('DELETE', uri, '', session))
        .timeout(const Duration(seconds: 20));
    await session?.validateCurrent();
    return _decodeResponse(response);
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, String>> _headers(
    String method,
    Uri uri,
    String body,
    SquareSession? session,
  ) async {
    final headers = <String, String>{
      'content-type': 'application/json; charset=utf-8',
    };
    if (session == null) return headers;
    await session.validateCurrent();
    headers['authorization'] = 'Bearer ${session.sessionToken}';
    final signer = session.authenticateRequest;
    if (signer == null) {
      throw const SquareApiException('MLS请求认证未接入，请重新登录');
    }
    headers.addAll(
      await squareRequestHeaders(
        method: method,
        uri: uri,
        body: body,
        sessionToken: session.sessionToken,
        authenticate: signer,
      ),
    );
    return headers;
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    SquareApiStage stage = SquareApiStage.request,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw SquareApiException(
        '广场服务响应不是 JSON：${response.statusCode}',
        statusCode: response.statusCode,
        stage: stage,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw SquareApiException(
        '广场服务响应结构不合法：${response.statusCode}',
        statusCode: response.statusCode,
        stage: stage,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SquareApiException(
        decoded['message']?.toString() ?? '广场服务请求失败',
        statusCode: response.statusCode,
        errorCode: decoded['error_code']?.toString(),
        stage: stage,
      );
    }
    return decoded;
  }

  SquarePreparedMediaUpload _parsePreparedMedia(Map<String, dynamic> item) {
    final mediaKind = switch (_requireString(item, 'media_kind')) {
      'video' => SquareMediaKind.video,
      _ => SquareMediaKind.image,
    };
    return SquarePreparedMediaUpload(
      mediaKind: mediaKind,
      contentType: _requireString(item, 'content_type'),
      byteSize: _asInt(item['byte_size']),
      objectKey: _requireString(item, 'object_key'),
      uploadMethod: _requireString(item, 'upload_method'),
      uploadUrl: _requireString(item, 'upload_url'),
      uploadHeaders: _stringMap(item['upload_headers']),
      derivativeKind: _requireString(item, 'derivative_kind'),
      derivativeByteSize: _asInt(item['derivative_byte_size']),
      derivativeObjectKey: _requireString(item, 'derivative_object_key'),
      derivativeUploadUrl: _requireString(item, 'derivative_upload_url'),
      derivativeUploadHeaders: _stringMap(item['derivative_upload_headers']),
    );
  }

  List<SquareMembershipPlan> _parseMembershipPlans(Object? value) {
    if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
      throw const SquareApiException("会员档位响应不完整");
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(_parseMembershipPlan)
        .toList(growable: false);
  }

  SquareMembershipPlan _parseMembershipPlan(Map<String, dynamic> data) {
    final level = _requireString(data, 'membership_level');
    final name = switch (level) {
      'freedom' => '自由',
      'democracy' => '民主',
      'spark' => '薪火',
      _ => throw const SquareApiException('会员档位未知'),
    };
    final plan = data['plan'], limits = data['limits'];
    if (plan is! Map<String, dynamic> ||
        limits is! Map<String, dynamic> ||
        plan['membership_level'] != level) {
      throw const SquareApiException('会员额度响应不完整');
    }
    int quota(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw const SquareApiException('会员额度无效');
      }
      return value;
    }

    final quality = quota(limits, 'image_dimension') >= 1920 ? 'hd' : 'sd';
    return SquareMembershipPlan(
      membershipLevel: level,
      displayName: name,
      chatFileMaxBytes: quota(plan, 'chat_file_max_bytes'),
      // 保留既有三档聊天展示能力；授权仍由实际会话和宿主聊天许可决定。
      chat: const SquareChatQuota(
        textEnabled: true,
        emojiEnabled: true,
        stickerEnabled: true,
        imageEnabled: true,
        voiceMessageMaxSeconds: 180,
        videoMessageMaxSeconds: 180,
        voiceCallEnabled: true,
        videoCallEnabled: true,
      ),
      // 文本/标题上限来自既有发布协议，动态媒体/周期/存储额度只读服务器plan/limits。
      document: SquareDocumentQuota(
        textMaxChars: 300,
        imageQuality: quality,
        maxImages: 9,
      ),
      video: SquareVideoQuota(
        textMaxChars: 300,
        videoQuality: quality,
        maxVideoSeconds: quota(plan, 'video_max_seconds'),
        maxVideoBytes: quota(plan, 'video_max_bytes'),
      ),
      article: SquareArticleQuota(
        titleMinChars: 10,
        titleMaxChars: 50,
        bodyMaxChars: 30000,
        coverQuality: 'hd',
        imageQuality: quality,
        maxImages: quota(plan, 'article_max_images'),
        maxVideos: quota(plan, 'article_max_videos'),
      ),
      usage: SquareMembershipUsageQuota(
        monthlyImages: quota(plan, 'monthly_images'),
        monthlyVideoSeconds: quota(plan, 'monthly_video_seconds'),
        activeUploads: quota(plan, 'active_uploads'),
        storageBytes: quota(limits, 'storage_bytes'),
      ),
    );
  }

  SquareMembershipUsageState? _parseMembershipUsageState(
    Object? value,
    Object? membership,
  ) {
    if (value is! Map<String, dynamic>) {
      throw const SquareApiException('会员用量响应缺失');
    }
    final period = membership is Map<String, dynamic>
        ? membership
        : const <String, dynamic>{};
    return SquareMembershipUsageState(
      periodStart: _asInt(period['last_charged_at']),
      periodEnd: _asInt(period['paid_until']),
      imageCount:
          _asInt(value['used_images']) + _asInt(value['reserved_images']),
      videoSeconds:
          _asInt(value['used_video_seconds']) +
          _asInt(value['reserved_video_seconds']),
      activeUploads: _asInt(value['active_uploads']),
    );
  }

  SquarePost _parsePost(
    Map<String, dynamic> data, {
    bool isDetail = false,
    SquareAuthor? fallbackAuthor,
  }) {
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
        // 昵称与头像来自作者 profile.json（Worker feed 按去重作者回填）；缺失时
        // Flutter 优先按作者永久 CID 稳定选择本地默认昵称和照片；纯访客才按账户兜底。
        displayName:
            (data['display_name']?.toString().trim().isNotEmpty ?? false)
            ? data['display_name'].toString().trim()
            : fallbackAuthor?.displayName,
        avatarObjectKey:
            (data['avatar_object_key']?.toString().isNotEmpty ?? false)
            ? data['avatar_object_key'].toString()
            : fallbackAuthor?.avatarObjectKey,
        // 作者徽章信号（Worker feed 已按去重作者读链身份+会员回填）。
        identityLevel:
            data['identity_level']?.toString() ?? fallbackAuthor?.identityLevel,
        membershipLevel:
            data['membership_level']?.toString() ??
            fallbackAuthor?.membershipLevel,
        membershipActive: data.containsKey('membership_active')
            ? data['membership_active'] == true
            : fallbackAuthor?.membershipActive ?? false,
      ),
      postCategory: _parseCategory(data['post_category']),
      postType: postType,
      title: (data['title']?.toString().trim().isNotEmpty ?? false)
          ? data['title'].toString().trim()
          : null,
      contentSections: isDetail
          ? parseArticleContentSections(data['content_sections'])
          : const <ArticleContentSection>[],
      text: (isDetail ? data['text'] : data['excerpt'])?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _asInt(data['created_at']),
      ),
      mediaItems: mediaItems,
      contentHash: data['content_hash']?.toString(),
      storageReceiptId: data['storage_receipt_id']?.toString(),
      chainBlock: _nullableInt(data['chain_block']),
      // 竞选目标（预留）：Worker 暂未返回，待公民身份上链落地后填充。
      campaignInstitutionCid: data['campaign_institution_cid']?.toString(),
      campaignPosition: data['campaign_position']?.toString(),
    );
  }

  SquareMediaItem _parseMediaItem(Map<String, dynamic> data) {
    final url = data['url']?.toString() ?? data['object_key']?.toString() ?? '';
    final coverUrl = data['thumbnail_url']?.toString() ?? '';
    return SquareMediaItem(
      mediaKind: data['media_kind'] == 'video'
          ? SquareMediaKind.video
          : SquareMediaKind.image,
      url: _resolveMediaUrl(url),
      coverUrl: coverUrl.isEmpty ? null : _resolveMediaUrl(coverUrl),
      byteSize: _nullableInt(data['byte_size']),
      assetState: data['asset_state']?.toString(),
      // 横竖屏判定所需原始尺寸；Worker feed 已随 media_items 回传。
      width: _nullableInt(data['width']),
      height: _nullableInt(data['height']),
    );
  }

  static SquarePostType _parsePostType(Object? value) {
    for (final postType in SquarePostType.values) {
      if (value == postType.workerValue) return postType;
    }
    throw const SquareApiException('post_type 不合法');
  }

  Future<void> _uploadFileToR2({
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
    final request = http.StreamedRequest('PUT', uri)
      ..headers.addAll(headers)
      ..contentLength = contentLength;
    // 先让 Client 订阅请求流，再泵入文件；反向等待会因无人消费 StreamedRequest 而死锁。
    final responseFuture = _http
        .send(request)
        .timeout(const Duration(hours: 4));
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final response = await responseFuture;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      throw SquareApiException(
        'R2 上传失败：${response.statusCode} $text',
        statusCode: response.statusCode,
      );
    }
    await response.stream.drain<void>();
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

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) throw const SquareApiException('上传请求头不合法');
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static String _requireExactString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty && value.trim() == value) {
      return value;
    }
    throw SquareApiException('广场服务响应字段 $key 不合法');
  }

  static Uint8List _decodeManifestBase64(String value) {
    if (value.isEmpty ||
        !RegExp(
          r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
        ).hasMatch(value)) {
      throw const SquareApiException('manifest_bytes_base64 不合法');
    }
    try {
      final bytes = base64Decode(value);
      if (bytes.isEmpty ||
          bytes.length > 256 * 1024 ||
          base64Encode(bytes) != value) {
        throw const SquareApiException('manifest_bytes_base64 不合法');
      }
      return Uint8List.fromList(bytes);
    } on SquareApiException {
      rethrow;
    } on Object {
      throw const SquareApiException('manifest_bytes_base64 不合法');
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

  static SquareBrowseState? _parseBrowseState(Map<String, dynamic> data) {
    final day = data['browse_day'];
    if (day is! String || day.isEmpty) return null;
    return SquareBrowseState(
      browseDay: day,
      browseCount: _asInt(data['browse_count']),
      browseLimit: _nullableInt(data['browse_limit']),
      browseLeft: _nullableInt(data['browse_left']),
    );
  }

  void close() {
    _closed = true;
    _sessions.clear();
    _inflightSessions.clear();
    _http.close();
  }
}
