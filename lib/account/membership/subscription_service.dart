import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizenapp/account/identity/account_security_service.dart';
import 'package:citizenapp/account/identity/square_session_provider.dart';
import 'package:citizenapp/account/identity/identity_register_guide.dart';
import 'package:citizenapp/account/identity/register_identity_flow.dart';
import 'package:citizenapp/network/square_api_client.dart';
import 'package:citizenapp/account/membership/membership_revision.dart';
import 'package:citizenapp/account/identity/finalized_identity_resolver.dart';
import 'package:citizenapp/scanner/qr_sign_session_page.dart';
import 'package:citizenapp/account/membership/subscription_chain.dart';
import 'package:citizenapp/network/hex_codec.dart' show hexToBytes;
import 'package:citizenapp/storage/wallet_isar.dart';

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 会员页持久化展示快照：只缓存 CitizenServe 已确认的订阅态与三档链上价格。
///
/// 套餐名称和权益不进入缓存，始终使用 App 内置静态定义；订阅或支付动作仍在提交前
/// 使用 CitizenServe D1 鉴权并由链上交易最终执行，展示缓存不构成服务端授权真源。
class MembershipDisplaySnapshot {
  const MembershipDisplaySnapshot({
    required this.state,
    required this.prices,
    required this.subscriptionFetchedAtMs,
    required this.pricesFetchedAtMs,
  });

  final SquareMembershipState state;
  final Map<String, int> prices;
  final int subscriptionFetchedAtMs;
  final int pricesFetchedAtMs;

  MembershipDisplayDecision get decision {
    return state.active
        ? MembershipDisplayDecision.activeConfirmed
        : MembershipDisplayDecision.inactiveConfirmed;
  }

  bool pricesAreFresh(int nowMs, Duration ttl) =>
      pricesFetchedAtMs > 0 &&
      nowMs >= pricesFetchedAtMs &&
      nowMs - pricesFetchedAtMs <= ttl.inMilliseconds;
}

/// 平台会员订阅编排：在「我的 → 会员」页订阅 / 取消平台会员（自由/民主/薪火）。
///
/// 用户签名订阅、取消和换档；首次扣款、真实公历到期时间与后续自动扣款由 runtime
/// 根据共识时间戳完成。CitizenApp 不提交续费或周期确认。
class SubscriptionService {
  SubscriptionService({
    required CitizenSdkWallet wallet,
    required CitizenChain chain,
    required CitizenTransactions transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    SubscriptionChain? subscriptionChain,
    SquareApiClient? api,
    bool resumePendingTransactions = true,
  }) : _subscriptionChain =
           subscriptionChain ??
           SubscriptionChain(chain: chain, transactions: transactions),
       _wallet = wallet,
       _identityResolver = identityResolver,
       _session = sessionProvider,
       _api = api ?? SquareApiClient() {
    // 会员调用方保留原交易恢复；聊天明确关闭构造期补发，不能间接触发服务端查链。
    if (resumePendingTransactions) {
      // 获准的会员调用方建立服务时恢复finalized待同步交易；失败仍留在原tx_hash队列，
      // 后续状态刷新再次重试，不把恢复职责塞进广场发布流程。
      unawaited(
        _retryPendingMirrorsForCurrentSession().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          // 构造期恢复是后台收敛，不得把暂时关闭的本地库等错误泄漏成未处理异常；
          // 原 tx_hash 队列保持不变，下一次状态刷新仍会重试。
          debugPrint(
            '[Membership] pending mirror recovery deferred: $error\n$stackTrace',
          );
        }),
      );
    }
  }

  final SubscriptionChain _subscriptionChain;
  final CitizenSdkWallet _wallet;
  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final SquareApiClient _api;

  bool _mirrorSyncPending = false;

  /// 全 App 按 CID 共享一份内存会员快照；WalletIsar 只是跨进程重启的持久化副本。
  static final Map<String, MembershipDisplaySnapshot> _memorySnapshots =
      <String, MembershipDisplaySnapshot>{};

  /// 唯一请求/权限缓存；离线展示快照不参与授权。所有消费者共用同一个进行中Future。
  static final Map<String, _MembershipAuthorization> _authorizations = {};
  static String? _currentAuthorizedCidNumber;
  static final Map<String, SquareSession> _citizenChatSessions = {};
  static int _cacheGeneration = 0;

  @visibleForTesting
  static int Function()? nowForTesting;
  static int _now() =>
      nowForTesting?.call() ?? DateTime.now().millisecondsSinceEpoch;

  static bool _sameSession(SquareSession left, SquareSession right) =>
      left.cidNumber.trim() == right.cidNumber.trim() &&
      left.accountId == right.accountId &&
      left.bindingRevision == right.bindingRevision &&
      left.deviceId == right.deviceId &&
      left.expiresAt == right.expiresAt &&
      left.sessionToken == right.sessionToken;

  static Future<void> _validateSession(SquareSession session) async {
    await session.validateCurrent();
    if (session.cidNumber.trim().isEmpty ||
        session.sessionToken.isEmpty ||
        session.expiresAt <= _now()) {
      throw const SquareApiException(
        '当前公民会话不可用',
        statusCode: 401,
        errorCode: 'invalid_session',
      );
    }
  }

  /// 普通业务直接请求原接口，由服务端门禁决定；这里不前置GET会员。
  static Future<void> requireSquareSession(
    SquareSession session, {
    SquareApiClient? client,
  }) async {
    await _validateSession(session);
    rememberCitizenSession(session);
  }

  /// 基础聊天只需要公民会话；切账户/令牌/设备后，旧Future不得写回。
  static void rememberCitizenSession(SquareSession session) {
    final cid = session.cidNumber.trim();
    if (cid.isEmpty) return;
    final old = _citizenChatSessions[cid];
    if ((_currentAuthorizedCidNumber != null &&
            _currentAuthorizedCidNumber != cid) ||
        (old != null && !_sameSession(old, session))) {
      _cacheGeneration++;
      _authorizations.clear();
    }
    _citizenChatSessions.removeWhere((key, _) => key != cid);
    _citizenChatSessions[cid] = session;
    _currentAuthorizedCidNumber = cid;
  }

  static void invalidateCitizenAccount(String accountId) {
    _cacheGeneration++;
    _authorizations.clear();
    _citizenChatSessions.removeWhere(
      (_, value) => value.accountId == accountId,
    );
  }

  /// 只有明确失效路径调用；MembershipRevision表示缓存已推进，不能反向删除它。
  static void invalidateBusinessMembership(String? cidNumber) {
    if (cidNumber == null) return;
    _cacheGeneration++;
    _authorizations.remove(cidNumber.trim());
  }

  Future<void> requireProfileAccess(SquareSession session, String targetCid) =>
      requireSquareSession(session);
  Future<void> requireSquareAccess(SquareSession session) =>
      requireSquareSession(session);

  static bool membershipResolvedFor(String cidNumber) =>
      _memorySnapshots.containsKey(cidNumber.trim());
  static bool chatAuthorizationResolvedFor(String cidNumber) =>
      _citizenChatSessions.containsKey(cidNumber.trim());
  static bool chatAuthorizedFor(String cidNumber) {
    final session = _citizenChatSessions[cidNumber.trim()];
    return session != null && session.expiresAt > _now();
  }

  static bool _activeBusinessMembership(SquareMembershipState state) =>
      state.active && state.paidUntil > _now();

  static int chatFileMaxBytesFor(String cidNumber) {
    final cid = cidNumber.trim(),
        entry = _authorizations[cid],
        session = _citizenChatSessions[cid];
    if (entry == null ||
        session == null ||
        !_sameSession(entry.session, session) ||
        !_currentEntry(entry) ||
        entry.failed ||
        _now() < entry.checkedAt ||
        _now() >= entry.deadline ||
        entry.resolved == null) {
      return 0;
    }
    final state = entry.resolved!;
    return _activeBusinessMembership(state)
        ? state.activePlan?.chatFileMaxBytes ?? 0
        : 0;
  }

  static int get currentChatFileMaxBytes => _currentAuthorizedCidNumber == null
      ? 0
      : chatFileMaxBytesFor(_currentAuthorizedCidNumber!);
  static String get currentChatFileSizeLabel =>
      _chatFileSizeLabel(currentChatFileMaxBytes);
  static String chatFileSizeLabelFor(String cidNumber) =>
      _chatFileSizeLabel(chatFileMaxBytesFor(cidNumber));
  static void markAttachmentAuthorizationUnavailable(String cidNumber) {
    _currentAuthorizedCidNumber = cidNumber.trim();
    invalidateBusinessMembership(cidNumber);
  }

  /// SDK异步附件钩子使用同一入口；文字/表情/打开聊天不调用。
  static Future<void> prepareAttachment(
    SquareSession session, {
    SubscriptionService? service,
  }) async {
    final SquareMembershipState state;
    if (service != null) {
      state = await service.authorizeMembership(session);
    } else {
      final client = SquareApiClient();
      try {
        state = await _authorizeSession(session, client: client);
      } finally {
        client.close();
      }
    }
    await _validateSession(session);
    if (!_activeBusinessMembership(state) ||
        (state.activePlan?.chatFileMaxBytes ?? 0) <= 0) {
      throw const SquareApiException(
        '需要有效会员才能发送附件',
        statusCode: 403,
        errorCode: 'attachment_membergate_required',
      );
    }
  }

  /// 自动补发只派生唯一缓存；不建立会话、不查询会员、不把展示快照当授权。
  static Future<bool> cachedAttachmentAuthorized({
    required String cidNumber,
    required String accountId,
    required int bindingRevision,
    String? expectedDeviceId,
  }) async {
    final entry = _authorizations[cidNumber.trim()];
    bool current() =>
        entry != null &&
        _currentEntry(entry) &&
        !entry.pending &&
        !entry.failed &&
        entry.session.accountId == accountId &&
        entry.session.bindingRevision == bindingRevision &&
        (expectedDeviceId == null ||
            entry.session.deviceId == expectedDeviceId) &&
        chatFileMaxBytesFor(cidNumber) > 0;
    if (!current()) return false;
    await _validateSession(entry!.session);
    return current();
  }

  @visibleForTesting
  static void setChatAuthorizationForTesting(
    String cidNumber,
    int? chatFileMaxBytes,
  ) {
    final cid = cidNumber.trim();
    _authorizations.remove(cid);
    _memorySnapshots.remove(cid);
    if (chatFileMaxBytes == null) return;
    final now = _now(), end = now + 60000;
    final session =
        _citizenChatSessions[cid] ??
        SquareSession(
          deviceId: 'test-device',
          sessionToken: 'test-session',
          cidNumber: cid,
          bindingRevision: 1,
          accountId: 'test-account',
          expiresAt: end,
        );
    rememberCitizenSession(session);
    final state = SquareMembershipState(
      active: chatFileMaxBytes > 0,
      paidUntil: end,
      membershipLevel: 'freedom',
      subscriptionStatus: 'active',
      subscriptionActive: chatFileMaxBytes > 0,
      plans: [
        SquareMembershipPlan(
          membershipLevel: 'freedom',
          displayName: '测试夹具',
          chatFileMaxBytes: chatFileMaxBytes,
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
          document: const SquareDocumentQuota(
            textMaxChars: 300,
            imageQuality: 'sd',
            maxImages: 1,
          ),
          video: const SquareVideoQuota(
            textMaxChars: 300,
            videoQuality: 'sd',
            maxVideoSeconds: 180,
            maxVideoBytes: 1,
          ),
          article: const SquareArticleQuota(
            titleMinChars: 1,
            titleMaxChars: 80,
            bodyMaxChars: 1,
            coverQuality: 'sd',
            imageQuality: 'sd',
            maxImages: 1,
            maxVideos: 0,
          ),
          usage: const SquareMembershipUsageQuota(
            monthlyImages: 1,
            monthlyVideoSeconds: 1,
            activeUploads: 1,
            storageBytes: 1,
          ),
        ),
      ],
    );
    final entry = _MembershipAuthorization(session, _cacheGeneration);
    _authorizations[cid] = entry;
    _install(entry, state);
    entry.pending = false;
    entry.state = Future.value(state);
    _memorySnapshots[cid] = MembershipDisplaySnapshot(
      state: state,
      prices: const {},
      subscriptionFetchedAtMs: now,
      pricesFetchedAtMs: 0,
    );
  }

  static String _chatFileSizeLabel(int bytes) {
    const mib = 1024 * 1024;
    if (bytes >= 1024 * mib) {
      final gib = bytes / (1024 * mib);
      return gib == gib.roundToDouble()
          ? '${gib.round()}GB'
          : '${gib.toStringAsFixed(1)}GB';
    }
    return '${(bytes / mib).round()}MB';
  }

  /// 最近一次平台订阅动作已经 finalized，但 Worker 镜像仍等待确认。
  ///
  /// 该状态只供会员页显示同步提示；会员资格以 CitizenServe D1 与本机统一缓存为准。
  bool get mirrorSyncPending => _mirrorSyncPending;

  /// 会员页、附件、上传共用此入口；强刷也必须合并进行中请求并尊重失败退避。
  Future<SquareMembershipState> authorizeMembership(
    SquareSession session, {
    bool forceRefresh = false,
  }) => _authorizeSession(session, client: _api, forceRefresh: forceRefresh);

  static bool _currentEntry(_MembershipAuthorization entry) {
    final cid = entry.session.cidNumber.trim(),
        session = _citizenChatSessions[cid];
    return identical(_authorizations[cid], entry) &&
        entry.generation == _cacheGeneration &&
        session != null &&
        _sameSession(session, entry.session) &&
        entry.session.expiresAt > _now();
  }

  static void _install(
    _MembershipAuthorization entry,
    SquareMembershipState state,
  ) {
    final now = _now();
    entry.checkedAt = now;
    entry.resolved = state;
    entry.failed = false;
    final active = _activeBusinessMembership(state);
    var end = now + (active ? 60000 : 30000);
    if (active && state.paidUntil < end) end = state.paidUntil;
    if (entry.session.expiresAt < end) end = entry.session.expiresAt;
    entry.deadline = end;
  }

  static Future<SquareMembershipState> _authorizeSession(
    SquareSession session, {
    required SquareApiClient client,
    bool forceRefresh = false,
  }) async {
    await _validateSession(session);
    rememberCitizenSession(session);
    final cid = session.cidNumber.trim(), now = _now();
    final existing = _authorizations[cid];
    if (existing != null &&
        _currentEntry(existing) &&
        _sameSession(existing.session, session) &&
        (existing.pending ||
            ((!forceRefresh || existing.failed) &&
                now >= existing.checkedAt &&
                now < existing.deadline))) {
      final state = await existing.state;
      await _validateSession(session);
      if (!_currentEntry(existing)) {
        throw const SubscriptionException('会员会话已变化');
      }
      return state;
    }
    final entry = _MembershipAuthorization(session, _cacheGeneration);
    _authorizations[cid] = entry;
    entry.state = () async {
      try {
        final state = await client.fetchMembership(session);
        await _validateSession(session);
        if (!_currentEntry(entry)) throw const SubscriptionException('会员会话已变化');
        _install(entry, state);
        await _rememberServerState(
          session,
          state,
          isCurrent: () => _currentEntry(entry),
        );
        if (!_currentEntry(entry)) throw const SubscriptionException('会员会话已变化');
        entry.pending = false;
        return state;
      } on Object catch (error) {
        if (_currentEntry(entry)) {
          entry.pending = false;
          entry.failed = true;
          entry.resolved = null;
          entry.checkedAt = _now();
          final retry = _now() + 5000;
          entry.deadline = retry < session.expiresAt
              ? retry
              : session.expiresAt;
          // 限流、全部服务端临时故障及无HTTP响应沿用同一5秒失败Future。
          if (error is SquareApiException &&
              error.statusCode != null &&
              error.statusCode != 429 &&
              (error.statusCode! < 500 || error.statusCode! > 599)) {
            _authorizations.remove(cid);
          }
        }
        rethrow;
      }
    }();
    return entry.state;
  }

  static String _displaySnapshotKey(String cidNumber) =>
      'platform_membergate_display_snapshot:$cidNumber';

  /// 读取当前账户上一次成功同步的展示快照；损坏缓存只忽略展示，读取路径不删除事实。
  Future<MembershipDisplaySnapshot?> readDisplaySnapshot(String cidNumber) =>
      _readDisplaySnapshot(cidNumber);
  static Future<MembershipDisplaySnapshot?> _readDisplaySnapshot(
    String cidNumber, {
    bool Function()? isCurrent,
  }) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty || (isCurrent != null && !isCurrent())) return null;
    final memory = _memorySnapshots[normalized];
    if (memory != null) return _rememberInMemory(normalized, memory);
    final key = _displaySnapshotKey(normalized);
    final raw = await _readState(key);
    if (raw == null || raw.isEmpty || (isCurrent != null && !isCurrent())) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final pricesRaw = decoded['prices'];
      final prices = <String, int>{};
      if (pricesRaw is Map<String, dynamic>) {
        for (final level in const ['freedom', 'democracy', 'spark']) {
          final value = pricesRaw[level];
          if (value is int && value >= 0) prices[level] = value;
        }
      }
      final membershipLevel = decoded['membergate_level'];
      final subscriptionStatus = decoded['subscription_status'];
      final snapshot = MembershipDisplaySnapshot(
        state: SquareMembershipState(
          active: decoded['active'] == true,
          paidUntil: decoded['paid_until'] is int
              ? decoded['paid_until'] as int
              : 0,
          membershipLevel: membershipLevel is String ? membershipLevel : null,
          subscriptionStatus: subscriptionStatus is String
              ? subscriptionStatus
              : null,
          subscriptionActive: decoded['subscription_active'] == true,
          lastChargedAt: decoded['last_charged_at'] is int
              ? decoded['last_charged_at'] as int
              : 0,
        ),
        prices: prices,
        subscriptionFetchedAtMs: decoded['subscription_fetched_at_ms'] is int
            ? decoded['subscription_fetched_at_ms'] as int
            : 0,
        pricesFetchedAtMs: decoded['prices_fetched_at_ms'] is int
            ? decoded['prices_fetched_at_ms'] as int
            : 0,
      );
      return _rememberInMemory(normalized, snapshot, notify: false);
    } on FormatException {
      // 损坏展示快照不参与授权；读取路径保留事实供显式诊断。
      return null;
    }
  }

  /// 原子覆盖当前账户展示快照；只有真实服务端或公开价格结果才推进时间戳。
  Future<void> writeDisplaySnapshot(
    String cidNumber,
    MembershipDisplaySnapshot snapshot,
  ) => _writeDisplaySnapshot(cidNumber, snapshot);
  static Future<void> _writeDisplaySnapshot(
    String cidNumber,
    MembershipDisplaySnapshot snapshot, {
    bool Function()? isCurrent,
  }) async {
    final normalized = cidNumber.trim();
    if (normalized.isEmpty || (isCurrent != null && !isCurrent())) return;
    final effective = _rememberInMemory(normalized, snapshot);
    await _writeState(
      _displaySnapshotKey(normalized),
      jsonEncode({
        'active': effective.state.active,
        'paid_until': effective.state.paidUntil,
        'membergate_level': effective.state.membershipLevel,
        'subscription_status': effective.state.subscriptionStatus,
        'subscription_active': effective.state.subscriptionActive,
        'last_charged_at': effective.state.lastChargedAt,
        'prices': effective.prices,
        'subscription_fetched_at_ms': effective.subscriptionFetchedAtMs,
        'prices_fetched_at_ms': effective.pricesFetchedAtMs,
      }),
      isCurrent: isCurrent,
    );
  }

  static MembershipDisplaySnapshot _rememberInMemory(
    String cidNumber,
    MembershipDisplaySnapshot snapshot, {
    bool notify = true,
  }) {
    final now = _now();
    final state = snapshot.state;
    final effectiveState =
        state.active && (state.paidUntil <= 0 || now >= state.paidUntil)
        ? SquareMembershipState(
            active: false,
            paidUntil: state.paidUntil,
            membershipLevel: state.membershipLevel,
            subscriptionStatus: state.subscriptionStatus,
            subscriptionActive: false,
            lastChargedAt: state.lastChargedAt,
            plans: state.plans,
            usageState: state.usageState,
          )
        : state;
    final effective = identical(effectiveState, state)
        ? snapshot
        : MembershipDisplaySnapshot(
            state: effectiveState,
            prices: snapshot.prices,
            subscriptionFetchedAtMs: snapshot.subscriptionFetchedAtMs,
            pricesFetchedAtMs: snapshot.pricesFetchedAtMs,
          );
    final previous = _memorySnapshots[cidNumber];
    _memorySnapshots[cidNumber] = effective;
    if (notify && !_sameMembership(previous?.state, effective.state)) {
      MembershipRevision.instance.notifyChanged(cidNumber);
    }
    return effective;
  }

  static bool _sameMembership(
    SquareMembershipState? left,
    SquareMembershipState right,
  ) =>
      left?.active == right.active &&
      left?.paidUntil == right.paidUntil &&
      left?.membershipLevel == right.membershipLevel &&
      left?.subscriptionStatus == right.subscriptionStatus &&
      left?.subscriptionActive == right.subscriptionActive &&
      left?.lastChargedAt == right.lastChargedAt;

  static Future<void> _rememberServerState(
    SquareSession session,
    SquareMembershipState state, {
    required bool Function() isCurrent,
  }) async {
    MembershipDisplaySnapshot? previous;
    try {
      previous = await _readDisplaySnapshot(
        session.cidNumber,
        isCurrent: isCurrent,
      );
    } on Object {
      // 展示持久化暂不可用时仍保留服务端已确认权限。
    }
    if (!isCurrent()) return;
    final prices = {
      for (final plan in state.plans)
        if (plan.priceFen != null) plan.membershipLevel: plan.priceFen!,
    };
    final snapshot = MembershipDisplaySnapshot(
      state: state,
      prices: prices.length == 3 ? prices : previous?.prices ?? const {},
      subscriptionFetchedAtMs: _now(),
      pricesFetchedAtMs: prices.length == 3
          ? _now()
          : previous?.pricesFetchedAtMs ?? 0,
    );
    try {
      await _writeDisplaySnapshot(
        session.cidNumber,
        snapshot,
        isCurrent: isCurrent,
      );
    } on Object {
      // 磁盘失败不撤销已经确认的内存事实；迟到写入仍由事务内检查拒绝。
    }
  }

  /// 订阅平台会员某档（level=freedom/democracy/spark）。
  Future<void> subscribe(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _subscriptionChain.subscribePlatform(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
      );
    } on Exception catch (e) {
      throw SubscriptionException('订阅失败：$e');
    }
  }

  /// 取消平台会员（撤销按月扣款授权）。
  Future<void> cancel({BuildContext? context}) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _subscriptionChain.cancelPlatform(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
      );
    } on Exception catch (e) {
      throw SubscriptionException('取消失败：$e');
    }
  }

  /// 更换平台会员档。当前已付周期内仅登记待切换档位，具体生效时间由 runtime 决定。
  Future<void> changePlan(
    String level,
    int expectedPriceFen, {
    BuildContext? context,
  }) async {
    final identity = await _requireIdentity();
    await _requireSigningAccount(identity.accountId);
    final cidNumber = identity.snapshot!.cidNumber;
    try {
      final result = await _subscriptionChain.changePlatformPlan(
        signerPublicKey: Uint8List.fromList(hexToBytes(identity.accountId)),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      await _confirm(
        subscriberCidNumber: cidNumber,
        txHash: result.txHash,
        blockHashHex: result.blockHashHex,
      );
    } on Exception catch (e) {
      throw SubscriptionException('更换订阅失败：$e');
    }
  }

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _wallet.getState().result).defaultAccount;
    if (account == null || account.accountId != accountId) {
      throw const SubscriptionException('当前身份与默认钱包账户不一致，已拒绝签名');
    }
    return account;
  }

  Future<String?> _showExternalSigning(
    BuildContext? context,
    CitizenTransactionExternalSigningPending pending,
  ) {
    if (context == null || !context.mounted) return Future<String?>.value();
    return showCitizenSdkQrResponse(
      context,
      request: pending.qrRequest,
      expiresAt: BigInt.from(pending.expiresAt.millisecondsSinceEpoch ~/ 1000),
    );
  }

  /// 当前默认账户经 finalized 闭环验证后，才可成为链上订阅交易签名者。
  Future<FinalizedIdentity> _requireIdentity() async {
    final identity = await _identityResolver.resolve();
    if (identity == null || !identity.isRegistered) {
      throw const SubscriptionException('请先注册并绑定公民 CID');
    }
    return identity;
  }

  String _pendingKey(String subscriberCidNumber) =>
      'platform_subscription_mirror_pending_by_cid:$subscriberCidNumber';

  /// finalized 定位按永久 CID 落本地，只保存 tx_hash 与 block_hash。HTTP 失败只重试
  /// 同一链上交易确认，不再签名，也不根据旧 D1 状态猜测同步成功。
  Future<void> _confirm({
    required String subscriberCidNumber,
    required String txHash,
    required String blockHashHex,
  }) async {
    final proof = <String, dynamic>{
      'tx_hash': txHash,
      'block_hash': blockHashHex,
    };
    try {
      await _storeLocalProof(subscriberCidNumber, proof);
    } on Exception {
      // 链上已 finalized；本地缓存异常不能让用户重新签名。
    }
    _mirrorSyncPending = !await _syncProof(
      subscriberCidNumber: subscriberCidNumber,
      proof: proof,
    );
  }

  Future<void> _retryPendingMirrorsForCurrentSession() async {
    try {
      final session = await _session.ensureSession();
      if (session == null) return;
      final subscriberCidNumber = session.cidNumber;
      final pending = await _readList(_pendingKey(subscriberCidNumber));
      for (final proof in List<Map<String, dynamic>>.from(pending)) {
        await _syncProof(
          subscriberCidNumber: subscriberCidNumber,
          proof: proof,
        );
      }
      _mirrorSyncPending = (await _readList(_pendingKey(subscriberCidNumber)))
          .isNotEmpty;
    } on Exception {
      // 保留未完成证明；链上订阅与自动续费不依赖 Cloudflare。
    }
  }

  /// 用已 finalized 的交易证明推进 Worker 会员记录；失败只保留本地证明并重试，
  /// 发布与资料读取不承担链上重建职责，也不产生第二次签名。
  Future<bool> _syncProof({
    required String subscriberCidNumber,
    required Map<String, dynamic> proof,
  }) async {
    final txHash = proof['tx_hash'];
    final blockHashHex = proof['block_hash'];
    if (txHash is! String || blockHashHex is! String) {
      return false;
    }

    final SquareSession? session;
    try {
      session = await _session.ensureSession();
    } on Exception {
      return false;
    }
    if (session == null ||
        session.cidNumber.trim() != subscriberCidNumber.trim()) {
      return false;
    }

    final generation = _cacheGeneration;
    final previousEntry = _authorizations[subscriberCidNumber];
    try {
      final confirmed = await _api.confirmPlatformSubscription(
        session: session,
        txHash: txHash,
        blockHashHex: blockHashHex,
      );
      await _validateSession(session);
      final current = _citizenChatSessions[subscriberCidNumber];
      if (generation != _cacheGeneration ||
          !identical(_authorizations[subscriberCidNumber], previousEntry) ||
          (current != null && !_sameSession(current, session))) {
        return false;
      }
      rememberCitizenSession(session);
      // 先替换条目，再更新展示/广播，旧读取和旧确认不能覆盖新状态。
      _cacheGeneration++;
      final entry = _MembershipAuthorization(session, _cacheGeneration);
      _authorizations[subscriberCidNumber] = entry;
      _install(entry, confirmed);
      entry.pending = false;
      entry.state = Future.value(confirmed);
      await _rememberServerState(
        session,
        confirmed,
        isCurrent: () => _currentEntry(entry),
      );
      if (!_currentEntry(entry)) return false;
    } on Exception {
      return false;
    }

    try {
      await _removePendingProof(subscriberCidNumber, txHash);
    } on Exception {
      // Worker 镜像已经确认；本地删除失败只会导致后续幂等重试，不能撤销成功事实。
    }
    return true;
  }

  Future<void> _storeLocalProof(
    String subscriberCidNumber,
    Map<String, dynamic> proof,
  ) async {
    final pending = await _readList(_pendingKey(subscriberCidNumber));
    pending.removeWhere((item) => item['tx_hash'] == proof['tx_hash']);
    pending.add(proof);
    await _writeState(_pendingKey(subscriberCidNumber), jsonEncode(pending));

    final historyKey = 'subscription_tx_history_by_cid:$subscriberCidNumber';
    final history = await _readList(historyKey);
    history.removeWhere((item) => item['tx_hash'] == proof['tx_hash']);
    history.add(proof);
    if (history.length > 50) history.removeRange(0, history.length - 50);
    await _writeState(historyKey, jsonEncode(history));
  }

  Future<void> _removePendingProof(
    String subscriberCidNumber,
    String txHash,
  ) async {
    final pending = await _readList(_pendingKey(subscriberCidNumber));
    pending.removeWhere((item) => item['tx_hash'] == txHash);
    if (pending.isEmpty) {
      await _deleteState(_pendingKey(subscriberCidNumber));
    } else {
      await _writeState(_pendingKey(subscriberCidNumber), jsonEncode(pending));
    }
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final raw = await _readState(key);
    if (raw == null) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    return decoded is List
        ? decoded.whereType<Map<String, dynamic>>().toList(growable: true)
        : <Map<String, dynamic>>[];
  }

  static Future<String?> _readState(String key) => WalletIsar.instance.read(
    (isar) async =>
        (await isar.walletMembershipStateEntitys.getByStateKey(key))
            ?.payloadJson,
  );

  static Future<void> _writeState(
    String key,
    String payloadJson, {
    bool Function()? isCurrent,
  }) => WalletIsar.instance.writeTxn((isar) async {
    final row =
        await isar.walletMembershipStateEntitys.getByStateKey(key) ??
        WalletMembershipStateEntity();
    row
      ..stateKey = key
      ..payloadJson = payloadJson;
    if (isCurrent != null && !isCurrent()) return;
    await isar.walletMembershipStateEntitys.put(row);
    if (isCurrent != null && !isCurrent()) {
      throw const SubscriptionException('会员会话已变化'); // 抛出使原事务回滚。
    }
  });

  static Future<void> _deleteState(String key) =>
      WalletIsar.instance.writeTxn((isar) async {
        await isar.walletMembershipStateEntitys.deleteByStateKey(key);
      });
}

enum MembershipDisplayDecision { activeConfirmed, inactiveConfirmed }

class _MembershipAuthorization {
  _MembershipAuthorization(this.session, this.generation);
  final SquareSession session;
  final int generation;
  late final Future<SquareMembershipState> state;
  int checkedAt = 0;
  int deadline = 0;
  bool pending = true;
  bool failed = false;
  SquareMembershipState? resolved;
}

/// 广场及云端详情的共同显示门禁；已校验的本人本地副本保持原离线呈现。
class MembershipBusinessGate extends StatefulWidget {
  const MembershipBusinessGate({
    super.key,
    required this.child,
    this.localContent = false,
    this.sessionProvider,
    this.client,
  });
  final Widget child;
  final bool localContent;
  final SquareSessionProvider? sessionProvider;
  final SquareApiClient? client;
  @override
  State<MembershipBusinessGate> createState() => _MembershipBusinessGateState();
}

class _MembershipBusinessGateState extends State<MembershipBusinessGate> {
  bool _unregistered = false;
  int _generation = 0;
  bool _ready = false;
  String? _error;
  Future<void>? _actionFlight;
  AccountSecurityService? _security;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_generation != 0) return;
    _security = context.read<AccountSecurityService?>();
    _security?.revision.addListener(_changed);
    MembershipRevision.instance.listenable.addListener(_changed);
    _check();
  }

  void _changed() {
    _generation++;
    if (mounted) {
      setState(() {
        _ready = false;
        _error = null;
      });
    }
    _check();
  }

  Future<void> _retry() {
    final existing = _actionFlight;
    if (existing != null) return existing;
    late final Future<void> task;
    task = _check(userInitiated: true).whenComplete(() {
      if (identical(_actionFlight, task)) _actionFlight = null;
    });
    _actionFlight = task;
    return task;
  }

  Future<void> _check({bool userInitiated = false}) async {
    final generation = ++_generation;
    _unregistered = false;
    final revision = _security?.revision.value;
    try {
      if (!widget.localContent) {
        final provider =
            widget.sessionProvider ?? context.read<SquareSessionProvider?>();
        final resolution = provider == null
            ? const SquareSessionResolution(SquareSessionStatus.noWallet)
            : userInitiated
            ? await resolveCitizenSessionForAction(context, provider: provider)
            : await provider.resolveSession();
        if (!mounted ||
            generation != _generation ||
            revision != _security?.revision.value) {
          return;
        }
        final session = resolution.session;
        if (session == null) {
          setState(() {
            _ready = false;
            _error = resolution.message;
            _unregistered = resolution.errorCode == 'identity_unregistered';
          });
          return;
        }
        await SubscriptionService.requireSquareSession(
          session,
          client: widget.client,
        );
      }
      if (!mounted ||
          generation != _generation ||
          revision != _security?.revision.value) {
        return;
      }
      setState(() {
        _ready = true;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted ||
          generation != _generation ||
          revision != _security?.revision.value) {
        return;
      }
      setState(() {
        _ready = false;
        _error = SquareSessionResolution.fromError(error).message;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _security?.revision.removeListener(_changed);
    MembershipRevision.instance.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    if (_unregistered) {
      return Scaffold(
        body: IdentityRegisterGuide(
          description: '注册后即可使用公民服务。',
          onRegistered: _changed,
        ),
      );
    }
    return Scaffold(
      body: _error == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                onRefresh: _retry,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: Center(
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
