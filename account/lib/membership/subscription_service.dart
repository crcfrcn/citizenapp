import 'package:citizen_storage/user_isar.dart' as wallet_store show Member;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart' as chat_sdk;
import 'package:citizen_account/identity/account_security_service.dart';
import 'package:citizen_account/identity/square_session_provider.dart';
import 'package:citizen_account/identity/identity_register_guide.dart';
import 'package:citizen_account/identity/register_identity_flow.dart';
import 'package:citizen_account/square_api_client.dart';
import 'package:citizen_account/membership/membership_revision.dart';
import 'package:citizen_account/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_account/membership/subscription_chain.dart';
import 'package:citizen_network/hex_codec.dart' show hexToBytes;

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 会员页持久化展示快照：只缓存 CitizenServe 已确认的订阅态与三档链上价格。
///
/// 套餐和权益缓存服务端真实定义；订阅或支付动作仍在提交前
/// 使用 CitizenServe D1 鉴权并由链上交易最终执行，展示缓存不构成服务端授权真源。
class MembershipDisplaySnapshot {
  const MembershipDisplaySnapshot({
    required this.state,
    required this.prices,
    required this.memberAt,
    required this.priceAt,
  });

  final SquareMembershipState state;
  final Map<String, int> prices;
  final int memberAt;
  final int priceAt;

  MembershipDisplayDecision get decision {
    return state.active
        ? MembershipDisplayDecision.activeConfirmed
        : MembershipDisplayDecision.inactiveConfirmed;
  }

  bool pricesAreFresh(int nowMs, Duration ttl) =>
      priceAt > 0 && nowMs >= priceAt && nowMs - priceAt <= ttl.inMilliseconds;
}

/// 平台会员订阅编排：在「我的 → 会员」页订阅 / 取消平台会员（自由/民主/薪火）。
///
/// 用户签名订阅、取消和换档；首次扣款、真实公历到期时间与后续自动扣款由 runtime
/// 根据共识时间戳完成。CitizenApp 不提交续费或周期确认。
class SubscriptionService {
  SubscriptionService({
    CitizenSdk? wallet,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    required FinalizedIdentityResolver identityResolver,
    required SquareSessionProvider sessionProvider,
    SubscriptionChain? subscriptionChain,
    SquareApiClient? api,
    bool resumePendingTransactions = true,
    CitizenSdkOperation<CitizenWalletState> Function()? getWalletState,
    Future<CitizenBlockRef> Function()? getFinalizedHead,
    Future<List<Uint8List?>> Function(
      CitizenBlockRef block,
      List<Uint8List> keys,
    )?
    getStorageBatch,
    Future<Uint8List?> Function(CitizenBlockRef block, Uint8List key)?
    getStorage,
    Future<CitizenPreparedTransaction> Function(
      Uint8List sourceAccountId,
      Uint8List callData,
    )?
    prepareTransaction,
    Future<CitizenTransactionExecution> Function(String preparationId)?
    executePreparedTransaction,
    Future<void> Function(String executionId)?
    cancelPreparedTransactionExecution,
    Future<CitizenTransactionExecutionCompleted> Function(
      String executionId,
      String response,
    )?
    consumePreparedTransactionQrResponse,
  }) : _subscriptionChain =
           subscriptionChain ??
           SubscriptionChain(
             chain: chain,
             transactions: transactions,
             getFinalizedHead: getFinalizedHead,
             getStorageBatch: getStorageBatch,
             getStorage: getStorage,
             prepareTransaction: prepareTransaction,
             executePreparedTransaction: executePreparedTransaction,
             cancelPreparedTransactionExecution:
                 cancelPreparedTransactionExecution,
             consumePreparedTransactionQrResponse:
                 consumePreparedTransactionQrResponse,
           ),
       _identityResolver = identityResolver,
       _session = sessionProvider,
       _api = api ?? SquareApiClient(),
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState')) {
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
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareSessionProvider _session;
  final SquareApiClient _api;

  /// 唯一预检实例：规则/用量来自服务端，未决预留只在本进程存活。
  static final MembershipResourceGate resourceGate = MembershipResourceGate();
  bool _mirrorSyncPending = false;

  /// 全 App 按 CID 共享一份内存会员快照；UserIsar 只是跨进程重启的持久化副本。
  static final Map<String, MembershipDisplaySnapshot> _memorySnapshots =
      <String, MembershipDisplaySnapshot>{};

  /// 唯一请求/权限缓存；离线展示快照不参与授权。所有消费者共用同一个进行中Future。
  static final Map<String, _MembershipAuthorization> _authorizations = {};
  static String? _currentAuthorizedCidNumber;
  static final Map<String, SquareSession> _citizenSessions = {};

  /// 图片渲染只读取已有会话，不触发登录、设备登记、PIN或会员请求。
  static SquareSession? get currentSession {
    final session = _citizenSessions[_currentAuthorizedCidNumber];
    return session?.isUsable == true ? session : null;
  }

  static int _cacheGeneration = 0;

  @visibleForTesting
  static int Function()? nowForTesting;
  static int displayPaidUntilFor(String cid) =>
      _memorySnapshots[cid]?.state.paidUntil ?? 0;
  static int _now() =>
      nowForTesting?.call() ?? DateTime.now().millisecondsSinceEpoch;

  static bool _sameSession(SquareSession left, SquareSession right) =>
      left.cidNumber.trim() == right.cidNumber.trim() &&
      left.accountId == right.accountId &&
      left.bindRev == right.bindRev &&
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

  /// 服务端推送只推进展示；旧请求权限缓存失效，业务执行仍由原服务端门禁判断。
  static Future<void> applyPushedDisplay(
    String cid,
    Map<String, dynamic> data, {
    required bool Function() isCurrent,
    required int receivedAt,
  }) async {
    if (data['active'] is! bool ||
        data['paid_until'] is! int ||
        (data['paid_until'] as int) < 0 ||
        !isCurrent()) {
      return;
    }
    final previous = await _readDisplaySnapshot(cid, isCurrent: isCurrent);
    if (!isCurrent()) return;
    final prices = <String, int>{...?(previous?.prices)};
    var receivedPrices = 0;
    final raw = data['prices'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String &&
            ['freedom', 'democracy', 'spark'].contains(entry.key) &&
            entry.value is int &&
            (entry.value as int) >= 0 &&
            (entry.value as int) <= 9007199254740991) {
          prices[entry.key as String] = entry.value as int;
          receivedPrices++;
        }
      }
    }
    final state = SquareMembershipState(
      active: data['active'] as bool,
      paidUntil: data['paid_until'] as int,
      memberLevel: data['member_level'] as String?,
      subState: data['sub_state'] as String?,

      chargeAt: (data['charge_at'] as int?) ?? 0,
      plans: previous?.state.plans ?? const [],
      usageState:
          previous?.state.chargeAt == data['charge_at'] &&
              previous?.state.paidUntil == data['paid_until']
          ? previous?.state.usageState
          : null,
    );
    if (!_sameMembership(previous?.state, state)) {
      resourceGate.expireMember(cid);
      _authorizations.remove(cid);
    }
    await _writeDisplaySnapshot(
      cid,
      MembershipDisplaySnapshot(
        state: state,
        prices: prices,
        memberAt: receivedAt,
        priceAt: receivedPrices == 3 ? receivedAt : previous?.priceAt ?? 0,
      ),
      isCurrent: isCurrent,
    );
  }

  /// 普通业务直接请求原接口，由服务端门禁决定；这里不前置GET会员。
  static Future<void> requireSquareSession(
    SquareSession session, {
    SquareApiClient? client,
  }) async {
    await _validateSession(session);
    rememberCitizenSession(session);
  }

  /// 全部业务共享当前公民会话引用；切账户/令牌/设备后旧Future不得写回。
  static void rememberCitizenSession(SquareSession session) {
    final cid = session.cidNumber.trim();
    if (cid.isEmpty) return;
    final old = _citizenSessions[cid];
    if ((_currentAuthorizedCidNumber != null &&
            _currentAuthorizedCidNumber != cid) ||
        (old != null && !_sameSession(old, session))) {
      _cacheGeneration++;
      _authorizations.clear();
    }
    _citizenSessions.removeWhere((key, _) => key != cid);
    _citizenSessions[cid] = session;
    _currentAuthorizedCidNumber = cid;
  }

  static void invalidateCitizenAccount(String accountId) {
    resourceGate.invalidate(accountId);
    _cacheGeneration++;
    _authorizations.clear();
    _citizenSessions.removeWhere((_, value) => value.accountId == accountId);
  }

  /// 只有明确失效路径调用；MembershipRevision表示缓存已推进，不能反向删除它。
  static void invalidateBusinessMembership(String? cidNumber) {
    resourceGate.expireMember(cidNumber);
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
      _citizenSessions.containsKey(cidNumber.trim());
  static bool chatAuthorizedFor(String cidNumber) {
    final session = _citizenSessions[cidNumber.trim()];
    return session != null && session.expiresAt > _now();
  }

  static bool _activeBusinessMembership(SquareMembershipState state) =>
      state.active && state.paidUntil > _now();

  static int chatFileMaxBytesFor(String cidNumber) {
    final cid = cidNumber.trim(),
        entry = _authorizations[cid],
        session = _citizenSessions[cid];
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
        ? state.activePlan?.fileLimit ?? 0
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
        (state.activePlan?.fileLimit ?? 0) <= 0) {
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
    required int bindRev,
    String? expectedDeviceId,
  }) async {
    final entry = _authorizations[cidNumber.trim()];
    bool current() =>
        entry != null &&
        _currentEntry(entry) &&
        !entry.pending &&
        !entry.failed &&
        entry.session.accountId == accountId &&
        entry.session.bindRev == bindRev &&
        (expectedDeviceId == null ||
            entry.session.deviceId == expectedDeviceId) &&
        chatFileMaxBytesFor(cidNumber) > 0;
    if (!current()) return false;
    await _validateSession(entry!.session);
    return current();
  }

  @visibleForTesting
  static void setChatAuthorizationForTesting(String cidNumber, int? fileLimit) {
    final cid = cidNumber.trim();
    _authorizations.remove(cid);
    _memorySnapshots.remove(cid);
    if (fileLimit == null) return;
    final now = _now(), end = now + 60000;
    final session =
        _citizenSessions[cid] ??
        SquareSession(
          deviceId: 'test-device',
          sessionToken: 'test-session',
          cidNumber: cid,
          bindRev: 1,
          accountId: 'test-account',
          expiresAt: end,
        );
    rememberCitizenSession(session);
    final state = SquareMembershipState(
      active: fileLimit > 0,
      paidUntil: end,
      memberLevel: 'freedom',
      subState: 'active',

      plans: [
        SquareMembershipPlan(
          memberLevel: 'freedom',
          displayName: '测试夹具',
          fileLimit: fileLimit,
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
          document: const SquareDocumentQuota(
            textMaxChars: 300,
            imageQuality: 'sd',
            maxImages: 1,
          ),
          video: const SquareVideoQuota(
            textMaxChars: 300,
            videoQuality: 'sd',
            videoMaxSeconds: 180,
            videoMaxBytes: 1,
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
          usage: const SquareMembershipUsageQuota(storageBytes: 1),
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
      memberAt: now,
      priceAt: 0,
    );
  }

  static String _chatFileSizeLabel(int bytes) =>
      SquareMembershipPlan.formatBytes(bytes);

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
    final cid = entry.session.cidNumber.trim(), session = _citizenSessions[cid];
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
    final raw = await wallet_store.Member.readState(normalized, 'display');
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
      final memberLevel = decoded['member_level'];
      final subState = decoded['sub_state'];
      final snapshot = MembershipDisplaySnapshot(
        state: SquareMembershipState(
          active: decoded['active'] == true,
          paidUntil: decoded['paid_until'] is int
              ? decoded['paid_until'] as int
              : 0,
          memberLevel: memberLevel is String ? memberLevel : null,
          subState: subState is String ? subState : null,

          chargeAt: decoded['charge_at'] is int
              ? decoded['charge_at'] as int
              : 0,
          plans: decoded['plans'] == null
              ? const []
              : SquareApiClient.decodeMembershipPlans(decoded['plans']),
          usageState: decoded['usage'] == null
              ? null
              : SquareApiClient.decodeMembershipUsage(decoded['usage']),
        ),
        prices: prices,
        memberAt: decoded['member_at'] is int ? decoded['member_at'] as int : 0,
        priceAt: decoded['price_at'] is int ? decoded['price_at'] as int : 0,
      );
      return _rememberInMemory(normalized, snapshot, notify: false);
    } on Object {
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
    await wallet_store.Member.writeState(
      wallet_store.Member()
        ..cidNumber = normalized
        ..stateKind = 'display'
        ..bodyData = jsonEncode({
          'active': effective.state.active,
          'paid_until': effective.state.paidUntil,
          'member_level': effective.state.memberLevel,
          'sub_state': effective.state.subState,
          'charge_at': effective.state.chargeAt,
          'plans': effective.state.plans.map((plan) => plan.toJson()).toList(),
          'usage': effective.state.usageState?.toJson(),
          'prices': effective.prices,
          'member_at': effective.memberAt,
          'price_at': effective.priceAt,
        }),
      isCurrent: isCurrent,
      staleError: const SubscriptionException('会员会话已变化'),
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
            memberLevel: state.memberLevel,
            subState: state.subState,

            chargeAt: state.chargeAt,
            plans: state.plans,
            usageState: state.usageState,
          )
        : state;
    final effective = identical(effectiveState, state)
        ? snapshot
        : MembershipDisplaySnapshot(
            state: effectiveState,
            prices: snapshot.prices,
            memberAt: snapshot.memberAt,
            priceAt: snapshot.priceAt,
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
      left?.memberLevel == right.memberLevel &&
      left?.subState == right.subState &&
      left?.chargeAt == right.chargeAt;

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
        if (plan.priceFen != null) plan.memberLevel: plan.priceFen!,
    };
    final snapshot = MembershipDisplaySnapshot(
      state: state,
      prices: prices.length == 3 ? prices : previous?.prices ?? const {},
      memberAt: _now(),
      priceAt: prices.length == 3 ? _now() : previous?.priceAt ?? 0,
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
        cidNumber: cidNumber,
        txHash: result.txHash,
        blockHash: result.blockHash,
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
        cidNumber: cidNumber,
        txHash: result.txHash,
        blockHash: result.blockHash,
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
        cidNumber: cidNumber,
        txHash: result.txHash,
        blockHash: result.blockHash,
      );
    } on Exception catch (e) {
      throw SubscriptionException('更换订阅失败：$e');
    }
  }

  Future<CitizenWalletStateAccount> _requireSigningAccount(
    String accountId,
  ) async {
    final account = (await _getWalletState().result).defaultAccount;
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

  /// finalized 定位按永久 CID 落本地，只保存 tx_hash 与 block_hash。HTTP 失败只重试
  /// 同一链上交易确认，不再签名，也不根据旧 D1 状态猜测同步成功。
  Future<void> _confirm({
    required String cidNumber,
    required String txHash,
    required String blockHash,
  }) async {
    final proof = <String, dynamic>{'tx_hash': txHash, 'block_hash': blockHash};
    try {
      await wallet_store.Member.storeProof(
        cidNumber,
        proof,
        pendingKind: 'member',
      );
    } on Exception {
      // 链上已 finalized；本地缓存异常不能让用户重新签名。
    }
    _mirrorSyncPending = !await _syncProof(cidNumber: cidNumber, proof: proof);
  }

  Future<void> _retryPendingMirrorsForCurrentSession() async {
    try {
      final session = await _session.ensureSession();
      if (session == null) return;
      final cidNumber = session.cidNumber;
      final pending = await wallet_store.Member.readProofs(
        cidNumber,
        pendingKind: 'member',
      );
      for (final proof in List<Map<String, dynamic>>.from(pending)) {
        await _syncProof(cidNumber: cidNumber, proof: proof);
      }
      _mirrorSyncPending = (await wallet_store.Member.readProofs(
        cidNumber,
        pendingKind: 'member',
      )).isNotEmpty;
    } on Exception {
      // 保留未完成证明；链上订阅与自动续费不依赖 Cloudflare。
    }
  }

  /// 用已 finalized 的交易证明推进 Worker 会员记录；失败只保留本地证明并重试，
  /// 发布与资料读取不承担链上重建职责，也不产生第二次签名。
  Future<bool> _syncProof({
    required String cidNumber,
    required Map<String, dynamic> proof,
  }) async {
    final txHash = proof['tx_hash'];
    final blockHash = proof['block_hash'];
    if (txHash is! String || blockHash is! String) {
      return false;
    }

    final SquareSession? session;
    try {
      session = await _session.ensureSession();
    } on Exception {
      return false;
    }
    if (session == null || session.cidNumber.trim() != cidNumber.trim()) {
      return false;
    }

    final generation = _cacheGeneration;
    final previousEntry = _authorizations[cidNumber];
    try {
      final confirmed = await _api.confirmPlatformSubscription(
        session: session,
        txHash: txHash,
        blockHash: blockHash,
      );
      await _validateSession(session);
      final current = _citizenSessions[cidNumber];
      if (generation != _cacheGeneration ||
          !identical(_authorizations[cidNumber], previousEntry) ||
          (current != null && !_sameSession(current, session))) {
        return false;
      }
      rememberCitizenSession(session);
      // 先替换条目，再更新展示/广播，旧读取和旧确认不能覆盖新状态。
      _cacheGeneration++;
      final entry = _MembershipAuthorization(session, _cacheGeneration);
      _authorizations[cidNumber] = entry;
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
      await wallet_store.Member.finishProof(cidNumber, txHash, 'member');
    } on Exception {
      // Worker 镜像已经确认；本地删除失败只会导致后续幂等重试，不能撤销成功事实。
    }
    return true;
  }
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

/// 服务端规则的本地执行器。原账本是确认值，预留是尚未确认的本机请求；两者不互相冒充。
/// 所有数值上限均消费gate/plan，不按会员名称推导，不持久化授权或另建用量表。
final class MembershipResourceGate implements SquareResourceGate {
  static const _stockMetrics = {'storage_bytes', 'attachment_bytes'};
  final Map<String, _ResourceScope> _scopes = {};
  final Map<String, Future<void>> _refreshes = {};
  final Map<String, int> _retryAt = {};
  String _key(String origin, SquareSession s) =>
      jsonEncode([origin, s.cidNumber, s.accountId, s.bindRev, s.deviceId]);

  @override
  void invalidate(String accountId) {
    _scopes.removeWhere((_, scope) => scope.session.accountId == accountId);
    SubscriptionService._citizenSessions.removeWhere(
      (_, session) => session.accountId == accountId,
    );
    SubscriptionService._authorizations.removeWhere(
      (_, entry) => entry.session.accountId == accountId,
    );
  }

  void expireMember(String? cid) {
    for (final scope in _scopes.values) {
      if (scope.session.cidNumber == cid) {
        scope.invalidateStock();
      }
    }
  }

  @override
  int sample(String origin, SquareSession session) =>
      _scopes[_key(origin, session)]?.stockRevision ?? 0;

  /// 用真实服务端时间锚定单调时钟；手机系统时间跳变不能延长服务端许可。
  @override
  void observe(
    String origin,
    SquareSession session,
    Map<String, dynamic> data, {
    String? path,
    int? sample,
  }) {
    if (path != null &&
        (RegExp(r'^/api/8964/uploads/[^/]+/(complete|abort)$').hasMatch(path) ||
            RegExp(r'^/api/8964/posts/[^/]+/delete$').hasMatch(path))) {
      expireMember(session.cidNumber);
      SubscriptionService._authorizations.remove(session.cidNumber);
    }
    final raw = data['gate'];
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 2 ||
        raw['cid_number'] != session.cidNumber ||
        raw['account_id'] != session.accountId ||
        raw['bind_rev'] != session.bindRev ||
        raw['device_id'] != session.deviceId) {
      return;
    }
    final now = raw['server_time'],
        end = raw['valid_until'],
        day = raw['day_millis'];
    if (!_number(now) ||
        !_number(end) ||
        !_number(day) ||
        day == 0 ||
        end <= now ||
        raw['rules'] is! Map ||
        raw['resource_actions'] is! Map ||
        raw['daily_limits'] is! Map ||
        raw['device_limits'] is! Map ||
        raw['profile_media'] is! Map) {
      return;
    }
    final key = _key(origin, session);
    var scope = _scopes[key];
    if (scope != null && now < scope.anchor) {
      return;
    }
    SubscriptionService.rememberCitizenSession(session);
    scope ??= _ResourceScope(session);
    _scopes[key] = scope;
    scope.session = session;
    scope.anchor = now as int;
    scope.clock = Stopwatch()..start();
    scope.receivedAt = DateTime.now().millisecondsSinceEpoch;
    scope.deadline = end as int;
    scope.gate = raw;
    final usage = data['usage'];
    if (usage is Map && _number(usage['day_start']) && usage['daily'] is Map) {
      final window = usage['day_start'] as int;
      for (final entry in (usage['daily'] as Map).entries) {
        if (entry.key is String && _number(entry.value)) {
          scope.confirm(entry.key as String, window, entry.value as int);
        }
      }
    }
    if (data['membergate_active'] is bool) {
      try {
        final member = SquareApiClient.decodeMembership(data);
        scope.member = member;
        scope.memberDeadline = end;
        final u = member.usageState;
        // 在途变更可能已经包含在快照中，不能把快照再与其预留相加。
        // 变更结束前继续使用原基线；结束后只接受本代次发起的新采样。
        final currentSample = sample == null || sample == scope.stockRevision;
        final pendingStock = scope.holds.any(
          (h) => h.amounts.keys.any((k) => _stockMetrics.contains(k.$1)),
        );
        if (!currentSample) scope.memberDeadline = 0;
        if (u != null && currentSample && !pendingStock) {
          scope.gauges = {'storage_bytes': u.usedBytes + u.reservedBytes};
        }
        final attachment = currentSample && !pendingStock && usage is Map
            ? usage['attachment']
            : null;
        scope.attachmentAvailable =
            attachment is Map && attachment['status'] == 'available';
        if (scope.attachmentAvailable) {
          for (final entry in const {'bytes': 'attachment_bytes'}.entries) {
            if (_number(attachment[entry.key])) {
              scope.gauges[entry.value] = attachment[entry.key] as int;
            }
          }
        }
      } on Object {
        scope.memberDeadline = 0;
      }
    }
  }

  Future<void> _refresh(String origin, SquareSession session) async {
    final key = _key(origin, session);
    final existing = _refreshes[key];
    if (existing != null) return existing;
    if ((_retryAt[key] ?? 0) > DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    late final Future<void> work;
    work = () async {
      final client = SquareApiClient(baseUrl: '$origin/api');
      try {
        await client.fetchMembership(session);
        final scope = _scopes[key];
        if (scope == null || scope.memberDeadline <= scope.now) {
          _retryAt[key] = DateTime.now().millisecondsSinceEpoch + 5000;
        }
      } on Object {
        _retryAt[key] = DateTime.now().millisecondsSinceEpoch + 5000;
      } finally {
        client.close();
        if (identical(_refreshes[key], work)) {
          _refreshes.remove(key);
        }
      }
    }();
    _refreshes[key] = work;
    return work;
  }

  /// 规则未知时不伪造会员或零用量；普通操作仍到原服务端校验。
  /// 只有需要付费规则且缓存失效时合并一次按需刷新，基础聊天不依赖价格。
  @override
  Future<SquareResourceLease> reserve({
    required String origin,
    required SquareSession session,
    required String operation,
    String? target,
    String? operationId,
    Map<String, int> costs = const {},
    Map<String, Map<String, int>> actions = const {},
  }) async {
    await session.validateCurrent();
    final key = _key(origin, session);
    var scope = _scopes[key];
    final own = target == null || target == session.cidNumber;
    Map? rule() => scope?.gate['rules'] is Map
        ? (scope!.gate['rules'] as Map)[operation] as Map?
        : null;
    if ((rule()?[own ? 'self' : 'other'] == 'member' ||
            (scope?.member?.active == true &&
                actions.containsKey('profile_read'))) &&
        scope != null &&
        scope.now >= scope.memberDeadline) {
      await _refresh(origin, session);
      await session.validateCurrent();
      scope = _scopes[key];
    }
    if (!session.isUsable) {
      throw const SquarePreflightException('当前公民会话已失效', 'session_expired');
    }
    if (scope == null || scope.now >= scope.deadline) {
      return _LocalResourceLease(null, const {}, null);
    }
    final current = scope;
    final requiresMember = rule()?[own ? 'self' : 'other'] == 'member';
    if (requiresMember &&
        current.memberDeadline > current.now &&
        current.member?.active != true) {
      throw const SquarePreflightException('此操作需要有效会员', 'membergate_required');
    }
    final plan = current.memberDeadline > current.now
        ? current.member?.activePlan
        : null;
    final limits = <String, int>{};
    _copyNumbers(current.gate['daily_limits'], limits);
    if (plan != null) {
      limits.addAll(plan.dailyLimits);
    }
    final device = current.gate['device_limits'] as Map;
    final minute = device['window_millis'];
    if (_number(minute) && minute > 0) {
      for (final e in const {
        'frames': 'device_frames',
        'frame_bytes': 'device_frame_bytes',
        'pings': 'device_pings',
      }.entries) {
        if (_number(device[e.key])) {
          limits[e.value] = device[e.key] as int;
        }
      }
    }
    if (plan != null) {
      limits.addAll({'storage_bytes': plan.usage.storageBytes});
      limits.addAll(plan.resources);
    }
    final amounts = <String, int>{...costs};
    final actionRules = current.gate['resource_actions'] as Map;
    for (final action in actions.entries) {
      final rules = actionRules[action.key];
      if (rules is! List) {
        continue;
      }
      for (final raw in rules) {
        if (raw is! Map ||
            raw['metric'] is! String ||
            raw['amount'] is! String) {
          continue;
        }
        if (raw['when'] == 'begin_attachment' &&
            action.value['begin_attachment'] != 1) {
          continue;
        }
        final amount = raw['amount'] == 'one' ? 1 : action.value[raw['amount']];
        if (amount == null || amount == 0 && raw['when'] == 'positive') {
          continue;
        }
        if (amount < 0) {
          throw const SquarePreflightException(
            '资源请求不合法',
            'invalid_resource_cost',
          );
        }
        amounts.update(
          raw['metric'] as String,
          (v) => v + amount,
          ifAbsent: () => amount,
        );
      }
    }
    final day = current.gate['day_millis'] as int;
    final reserved = <(String, int), int>{};
    final chargeAt = current.now;
    // 同一附件许可仅有一份本地预留；重试仍逐次检查设备帧并交服务端核对指纹。
    final previous = operationId == null
        ? null
        : current.operations[operationId];
    for (final entry in amounts.entries) {
      if (entry.value < 0 || entry.value > 9007199254740991) {
        throw const SquarePreflightException(
          '资源请求不合法',
          'invalid_resource_cost',
        );
      }
      final metric = entry.key;
      if (previous != null &&
          (metric == 'attachment_begins' ||
              metric == 'attachment_bytes' &&
                  !previous._done &&
                  previous.amounts.keys.any((k) => k.$1 == metric))) {
        continue;
      }
      final gauge = _stockMetrics.contains(metric);
      final window = gauge
          ? -1
          : chargeAt ~/
                (metric.startsWith('device_') && _number(minute) && minute > 0
                    ? minute as int
                    : day) *
                (metric.startsWith('device_') && _number(minute) && minute > 0
                    ? minute as int
                    : day);
      final id = (metric, window);
      final used = gauge
          ? current.gauges[metric] ?? 0
          : current.confirmed[id] ?? 0;
      final pending = current.holds.fold<int>(
        0,
        (v, hold) => v + (hold.amounts[id] ?? 0),
      );
      final limit = limits[metric];
      if (limit != null && used + pending + entry.value > limit) {
        throw SquarePreflightException('当前资源用量已达上限，请查看会员用量', 'resource_limit');
      }
      reserved[id] = entry.value;
    }
    final lease = _LocalResourceLease(
      current,
      reserved,
      () =>
          identical(_scopes[key], current) &&
          SubscriptionService._sameSession(current.session, session),
    );
    lease.previous = previous;
    if (operationId != null && previous == null) {
      current.operations[operationId] = lease;
    }
    if (reserved.keys.any((k) => _stockMetrics.contains(k.$1))) {
      current.stockRevision++;
    }
    current.holds.add(lease);
    return lease;
  }

  Map<String, dynamic>? profileMedia(String origin, SquareSession session) {
    final scope = _scopes[_key(origin, session)];
    return scope != null
        ? Map<String, dynamic>.from(scope.gate['profile_media'] as Map)
        : null;
  }

  static bool _number(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
  static void _copyNumbers(Object? source, Map<String, int> to) {
    if (source is Map) {
      for (final e in source.entries) {
        if (e.key is String && _number(e.value)) {
          to[e.key as String] = e.value as int;
        }
      }
    }
  }
}

final class _ResourceScope {
  _ResourceScope(this.session);
  SquareSession session;
  int anchor = 0, deadline = 0, memberDeadline = 0;
  Stopwatch clock = Stopwatch();
  int receivedAt = DateTime.now().millisecondsSinceEpoch;
  int get now {
    final wall = DateTime.now().millisecondsSinceEpoch - receivedAt;
    return anchor +
        (wall > clock.elapsedMilliseconds ? wall : clock.elapsedMilliseconds);
  }

  Map<String, dynamic> gate = {};
  SquareMembershipState? member;
  bool attachmentAvailable = false;
  Map<String, int> gauges = {};
  final Map<(String, int), int> confirmed = {};
  final List<_LocalResourceLease> holds = [];
  final Map<String, _LocalResourceLease> operations = {};
  int stockRevision = 0;
  void invalidateStock() {
    stockRevision++;
    gauges.clear();
    memberDeadline = 0;
    SubscriptionService._authorizations.remove(session.cidNumber);
  }

  void confirm(String metric, int window, int used) {
    final key = (metric, window);
    if (used > (confirmed[key] ?? -1)) {
      confirmed[key] = used;
    }
  }
}

final class _LocalResourceLease implements SquareResourceLease {
  _LocalResourceLease(this.scope, this.amounts, this.current);
  final _ResourceScope? scope;
  final Map<(String, int), int> amounts;
  final bool Function()? current;
  _LocalResourceLease? previous;
  bool _sent = false, _done = false;
  void _unknownStock() {
    final s = scope;
    if (s == null) return;
    var changed = false;
    for (final key in amounts.keys.toList()) {
      if (MembershipResourceGate._stockMetrics.contains(key.$1)) {
        s.gauges.remove(key.$1);
        amounts.remove(key);
        changed = true;
      }
    }
    // 存量不是不可逆日扣量。未知存量明确失效，下一次按需采样或交服务端判定；日扣量仍保留。
    if (changed) {
      s.invalidateStock();
    }
  }

  @override
  void sent() {
    if (current?.call() == false) {
      throw const SquarePreflightException('当前用户已变化', 'identity_changed');
    }
    _sent = true;
  }

  @override
  void cancel() {
    if (_sent && !_done) _unknownStock();
    if (!_sent && !_done) {
      _done = true;
      scope?.holds.remove(this);
      scope?.operations.removeWhere((_, value) => identical(value, this));
    }
  }

  @override
  void finish({
    Map<String, String>? headers,
    chat_sdk.ResourceUsage? receipt,
    bool accepted = true,
    bool uncertain = false,
  }) {
    if (_done || current?.call() == false) {
      return;
    }
    final raw = headers?['x-citizenserve-usage'];
    if (receipt == null && raw != null && raw.length <= 8192) {
      try {
        final v = jsonDecode(raw);
        if (v is Map<String, dynamic> &&
            MembershipResourceGate._number(v['server_time_millis']) &&
            v['counters'] is List &&
            (v['counters'] as List).every(
              (c) =>
                  c is Map &&
                  c['metric'] is String &&
                  MembershipResourceGate._number(c['window_start_millis']) &&
                  MembershipResourceGate._number(c['used']) &&
                  MembershipResourceGate._number(c['charged']),
            )) {
          // 官方Proto解析直接进入WSS使用的同一类型，不逐字段回抄。
          receipt = chat_sdk.ResourceUsage()..mergeFromProto3Json(v);
        }
      } on FormatException {
        /* 损坏回执不退款。 */
      }
    }
    final s = scope;
    if (s != null && receipt != null) {
      if (receipt.userId != s.session.cidNumber ||
          receipt.deviceId != s.session.deviceId ||
          receipt.accountId != s.session.accountId ||
          receipt.bindingRevision.toInt() != s.session.bindRev ||
          !MembershipResourceGate._number(receipt.serverTimeMillis.toInt())) {
        return;
      }
      for (final c in receipt.counters) {
        if (c.metric.isEmpty ||
            !MembershipResourceGate._number(c.windowStartMillis.toInt()) ||
            !MembershipResourceGate._number(c.used.toInt()) ||
            !MembershipResourceGate._number(c.charged.toInt()) ||
            c.charged > c.used) {
          return;
        }
      }
      final counters = receipt.counters;
      for (final c in counters) {
        s.confirm(c.metric, c.windowStartMillis.toInt(), c.used.toInt());
      }
      if (uncertain) {
        // 部分回执只结算其准确窗口；未知剩余继续预留，不重复累计已确认成本。
        amounts.removeWhere(
          (key, _) => counters.any(
            (c) => c.metric == key.$1 && c.windowStartMillis.toInt() == key.$2,
          ),
        );
        _unknownStock();
        if (amounts.isNotEmpty) return;
      }
    } else if (raw != null || uncertain && _sent) {
      _unknownStock();
      if (amounts.isNotEmpty) return;
    }
    // 重试回执结算原许可，不把同一操作的未知日扣量留成第二份消耗。
    final licensed =
        accepted ||
        receipt != null &&
            receipt.counters.any((c) => c.metric == 'attachment_begins');
    final prior = previous;
    if (licensed &&
        prior != null &&
        !prior._done &&
        identical(prior.scope, s)) {
      // 新会话的真实同身份回执也能结算旧令牌的未知预留；旧令牌本身仍不可发送。
      prior._unknownStock();
      prior._done = true;
      s?.holds.remove(prior);
    }
    if (amounts.keys.any(
      (k) => MembershipResourceGate._stockMetrics.contains(k.$1),
    )) {
      _unknownStock();
    }
    if (!licensed && !uncertain) {
      s?.operations.removeWhere((_, value) => identical(value, this));
    }
    _done = true;
    s?.holds.remove(this);
  }
}
