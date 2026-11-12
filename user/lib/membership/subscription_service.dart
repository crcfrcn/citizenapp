import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_network/protocol/chat_frame.pb.dart' as chat_protocol;
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/identity/identity_register_guide.dart';
import 'package:citizen_user/identity/register_identity_flow.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_chain/citizen_chain.dart';

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 平台会员订阅编排：在「我的 → 会员」页订阅 / 取消平台会员（自由/民主/薪火）。
///
/// 用户签名订阅、取消和换档；首次扣款、真实公历到期时间与后续自动扣款由 runtime
/// 根据共识时间戳完成。CitizenApp 不提交续费或周期确认。
class SubscriptionService {
  SubscriptionService({
    ChainDataService? chainData,
    CitizenSdk? wallet,
    CitizenSdk? chain,
    CitizenSdk? transactions,
    required FinalizedIdentityResolver identityResolver,
    SubscriptionChain? subscriptionChain,
    SquareApiClient? api,
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
       _api = api ?? SquareApiClient(),
       _getWalletState =
           getWalletState ??
           wallet?.getWalletState ??
           (() => throw StateError('未配置getWalletState')) {
    if (chainData != null) _chainSource = chainData;
  }
  final CitizenSdkOperation<CitizenWalletState> Function() _getWalletState;

  final SubscriptionChain _subscriptionChain;

  final FinalizedIdentityResolver _identityResolver;
  final SquareApiClient _api;

  /// 唯一预检实例：规则/用量来自服务端，未决预留只在本进程存活。
  static final MembershipResourceGate resourceGate = MembershipResourceGate();

  /// 唯一请求/权限缓存；离线展示快照不参与授权。所有消费者共用同一个进行中Future。
  static final Map<String, _ResourceAuthorization> _authorizations = {};
  static String? _currentAuthorizedCidNumber;
  static final Map<String, SquareSession> _citizenSessions = {};
  static ChainDataService? _chainSource;
  static final Map<String, Map<String, SquareMembershipPlan>> _plans = {};

  /// 图片渲染只读取已有会话，不触发登录、设备登记、PIN或会员请求。
  static SquareSession? get currentSession {
    final session = _citizenSessions[_currentAuthorizedCidNumber];
    return session?.isUsable == true ? session : null;
  }

  static int _cacheGeneration = 0;

  @visibleForTesting
  static int Function()? nowForTesting;
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
      _plans.clear();
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

  static bool chatAuthorizationResolvedFor(String cidNumber) =>
      _citizenSessions.containsKey(cidNumber.trim());
  static bool chatAuthorizedFor(String cidNumber) {
    final session = _citizenSessions[cidNumber.trim()];
    return session != null && session.expiresAt > _now();
  }

  static bool _activeBusinessMembership(SquareResourceAuthorization state) =>
      state.allowed && state.validUntil > _now();

  static SquareMembershipPlan? _lightPlan(SquareSession session) {
    final source = _chainSource, data = source?.snapshot;
    if (source == null ||
        source.isStale ||
        data == null ||
        !session.isUsable ||
        data.accountId != session.accountId ||
        data.ownCid != session.cidNumber ||
        data.own?.identity?.bindRev != session.bindRev)
      return null;
    if (data.own?.platform?.isEffectiveAt(_now()) != true) return null;
    final level = data.memberLevel(session.cidNumber);
    return level == null ? null : _plans[session.cidNumber]?[level];
  }

  static int chatFileMaxBytesFor(String cidNumber) {
    final session = _citizenSessions[cidNumber];
    return session == null ? 0 : _lightPlan(session)?.fileLimit ?? 0;
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
    _plans.remove(cidNumber);
  }

  /// SDK异步附件钩子使用同一入口；文字/表情/打开聊天不调用。
  static Future<void> prepareAttachment(
    SquareSession session, {
    SubscriptionService? service,
  }) async {
    await _validateSession(session);
    rememberCitizenSession(session);
    // 明确附件动作复用同一轻节点读模型；不建立云端会员预检请求。
    await _chainSource?.refresh();
    await _validateSession(session);
    if (currentChatFileMaxBytes <= 0) {
      throw const SquareApiException(
        '附件规则尚未取得',
        errorCode: 'resource_rules_unknown',
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
    final s = _citizenSessions[cidNumber];
    if (s == null ||
        s.accountId != accountId ||
        s.bindRev != bindRev ||
        expectedDeviceId != null && s.deviceId != expectedDeviceId ||
        chatFileMaxBytesFor(cidNumber) <= 0)
      return false;
    await _validateSession(s);
    return chatFileMaxBytesFor(cidNumber) > 0;
  }

  static String _chatFileSizeLabel(int bytes) =>
      SquareMembershipPlan.formatBytes(bytes);

  /// 会员页、附件、上传共用此入口；强刷也必须合并进行中请求并尊重失败退避。
  Future<SquareResourceAuthorization> authorizeResources(
    SquareSession session, {
    bool forceRefresh = false,
  }) => _authorizeSession(session, client: _api, forceRefresh: forceRefresh);

  static bool _currentEntry(_ResourceAuthorization entry) {
    final cid = entry.session.cidNumber.trim(), session = _citizenSessions[cid];
    return identical(_authorizations[cid], entry) &&
        entry.generation == _cacheGeneration &&
        session != null &&
        _sameSession(session, entry.session) &&
        entry.session.expiresAt > _now();
  }

  static void _install(
    _ResourceAuthorization entry,
    SquareResourceAuthorization state,
  ) {
    final now = _now();
    entry.checkedAt = now;
    entry.resolved = state;
    entry.failed = false;
    final active = _activeBusinessMembership(state);
    var end = now + (active ? 60000 : 30000);
    if (state.validUntil < end) end = state.validUntil;
    if (entry.session.expiresAt < end) end = entry.session.expiresAt;
    entry.deadline = end;
  }

  static Future<SquareResourceAuthorization> _authorizeSession(
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
    final entry = _ResourceAuthorization(session, _cacheGeneration);
    _authorizations[cid] = entry;
    entry.state = () async {
      try {
        final state = await client.fetchResourceAuthorization(session);
        await _validateSession(session);
        if (!_currentEntry(entry)) throw const SubscriptionException('会员会话已变化');
        _install(entry, state);
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
      await _subscriptionChain.subscribePlatform(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      MembershipRevision.instance.notifyChanged(cidNumber);
      invalidateBusinessMembership(cidNumber);
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
      await _subscriptionChain.cancelPlatform(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      MembershipRevision.instance.notifyChanged(cidNumber);
      invalidateBusinessMembership(cidNumber);
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
      await _subscriptionChain.changePlatformPlan(
        signerPublicKey: citizenAccountIdBytes(identity.accountId),
        level: level,
        expectedPriceFen: BigInt.from(expectedPriceFen),
        externalSigning: (pending) => _showExternalSigning(context, pending),
      );
      MembershipRevision.instance.notifyChanged(cidNumber);
      invalidateBusinessMembership(cidNumber);
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
}

enum MembershipDisplayDecision { activeConfirmed, inactiveConfirmed }

class _ResourceAuthorization {
  _ResourceAuthorization(this.session, this.generation);
  final SquareSession session;
  final int generation;
  late final Future<SquareResourceAuthorization> state;
  int checkedAt = 0;
  int deadline = 0;
  bool pending = true;
  bool failed = false;
  SquareResourceAuthorization? resolved;
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
    SubscriptionService.rememberCitizenSession(session);
    if (raw['plans'] is List) {
      final plans = SquareApiClient.decodeMembershipPlans(raw['plans']);
      SubscriptionService._plans[session.cidNumber] = {
        for (final p in plans) p.memberLevel: p,
      };
    }
    final key = _key(origin, session);
    var scope = _scopes[key];
    if (scope != null && now < scope.anchor) {
      return;
    }
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
    if (data['authorization'] is Map) {
      try {
        final member = SquareApiClient.decodeResourceAuthorization(data);
        final u = member.usageState;
        // 在途变更可能已经包含在快照中，不能把快照再与其预留相加。
        // 变更结束前继续使用原基线；结束后只接受本代次发起的新采样。
        final currentSample = sample == null || sample == scope.stockRevision;
        final pendingStock = scope.holds.any(
          (h) => h.amounts.keys.any((k) => _stockMetrics.contains(k.$1)),
        );
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
        scope.gauges.clear();
      }
    }
  }

  /// 规则未知时不伪造会员或零用量；普通操作仍到原服务端校验。
  /// 会员规则来自同一轻节点快照和静态规则；未知用量仍交真实接口核验。
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
    final scope = _scopes[key];
    if (!session.isUsable) {
      throw const SquarePreflightException('当前公民会话已失效', 'session_expired');
    }
    if (scope == null || scope.now >= scope.deadline) {
      return _LocalResourceLease(null, const {}, null);
    }
    final current = scope;
    final plan = SubscriptionService._lightPlan(session);
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
  int anchor = 0, deadline = 0;
  Stopwatch clock = Stopwatch();
  int receivedAt = DateTime.now().millisecondsSinceEpoch;
  int get now {
    final wall = DateTime.now().millisecondsSinceEpoch - receivedAt;
    return anchor +
        (wall > clock.elapsedMilliseconds ? wall : clock.elapsedMilliseconds);
  }

  Map<String, dynamic> gate = {};
  bool attachmentAvailable = false;
  Map<String, int> gauges = {};
  final Map<(String, int), int> confirmed = {};
  final List<_LocalResourceLease> holds = [];
  final Map<String, _LocalResourceLease> operations = {};
  int stockRevision = 0;
  void invalidateStock() {
    stockRevision++;
    gauges.clear();
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
    chat_protocol.ResourceUsage? receipt,
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
          receipt = chat_protocol.ResourceUsage()..mergeFromProto3Json(v);
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
