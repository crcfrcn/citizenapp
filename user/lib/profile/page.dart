// 展示用户主页、头部、头像、用户码及关系操作。

import 'package:citizen_chain/service.dart';
import 'dart:async';
import 'dart:io';
import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/chat.dart';
import 'package:citizen_square/post/models.dart';
import 'package:citizen_square/article/page.dart';
import 'package:citizen_square/post/page.dart';
import 'package:citizen_user/profile/list.dart' show FollowsListPage, FollowsType, ProfilePostsTab;
import 'package:citizen_user/profile/data.dart' show CitizenProfile, CitizenProfileApi, CitizenProfileCache, CitizenProfileCard, CitizenProfileLoadResult, CitizenProfileMediaCache, CitizenProfileMediaSnapshot, CitizenRemoteImage, ProfileEntryRefreshResult, ProfilePresentation, SquareAccountDeletionService, SquareAccountLocalCleanupException;
import 'package:citizen_user/profile/edit.dart' show CitizenProfileEditPage;
import 'package:citizen_user/identity/session.dart' show SquareSessionProvider, SquareSessionStatus, SquareSessionStatusText;
import 'package:citizen_user/creator/button.dart' show CreatorSubscribeButton;
import 'package:citizen_user/api.dart' show SquareAccountDeletionPendingException, SquareApiException, SquareMembershipState, SquareSession;
import 'package:citizen_user/identity/badge.dart' show CitizenServiceGate, IdentityBadge, identityBadgeLabel, identityBadgeStyle;
import 'package:citizen_square/post/sync.dart';
import 'package:citizen_user/context.dart' show CurrentUserContext, DirectChatOpener, IdentityBinding, UserNavigation;
import 'package:citizen_user/identity/state.dart' show FinalizedIdentityResolver, IdentityBadgeSnapshotStore;
import 'package:citizen_user/security.dart' show AccountSecurityService;
import 'package:citizen_user/membership/service.dart' show MembershipDisplayDecision, MembershipRevision, SubscriptionService;
import 'package:citizen_scanner/sign.dart';
import 'package:citizen_system/theme.dart';
import 'package:citizen_system/log.dart';
import 'package:citizen_network/auth.dart' show bytesToHex;
import 'package:citizen_system/format.dart';
import 'dart:ui';
import 'package:citizen_scanner/display.dart';

// 按当前身份和访问结果呈现用户主页、分类内容及关系操作。

/// 推特式用户主页。
///
/// 折叠虚化头部 + 圆角方形头像/背景 + 认证勾 + 展示名/地址/签名/计数 +
/// 三图标（本人 通知/聊天/关注 · 他人 关注/消息）+ ⋮（用户码/编辑资料）+
/// 公文/竞选/视频/文章四个互斥 Tab（“公文”底层仍为 posts）。身份主键 = CID 号
/// （cid_number）；本人可读本地，他人须先通过当前主页隐私检查。
/// 资料后台校准遵守十分钟限速，访问检查不使用该窗口。
/// 关注复用登录 session 静默签名；资料远端存储不上链。链上订阅/私信/
/// 用户码与注销只消费本机已验证的当前公民号绑定。
class UserProfilePage extends StatefulWidget {
  /// 全部头像/联系人入口共用；拒绝时留在原页，不打开目标主页。
  static Future<void> open(BuildContext context, UserProfilePage page) async {
    final security = context.read<AccountSecurityService?>();
    final revision = security?.revision.value;
    try {
      bool Function(SquareSession, int?)? consumeEntry;
      ProfileEntryRefreshResult? entryProfile;
      final sessions =
          page.sessionProvider ?? context.read<SquareSessionProvider>();
      final identity =
          await (page.currentUserContext ?? context.read<CurrentUserContext?>())
              ?.resolve();
      final viewer = identity?.cidNumber ?? await sessions.currentCitizenId();
      if (viewer != page.cidNumber) {
        final session = await sessions.ensureSession();
        if (session == null) throw StateError('当前会话不可用');
        if (viewer != null && session.cidNumber != viewer) {
          throw StateError('当前身份已变化');
        }
        final api = page.api ?? CitizenProfileApi();
        final binding = identity?.binding;
        if (binding != null) {
          try {
            entryProfile = await api.refreshOnEntry(
              page.cidNumber,
              binding: binding,
              sessions: sessions,
              cache: page.cache,
              mediaCache: page.mediaCache,
              isCurrentIdentity: () => revision == security?.revision.value,
            );
          } on Object catch (error) {
            // 会员资料读取失败时，主页是否允许进入仍由单独的隐私入口判断。
            if (_privacyDenied(error)) rethrow;
          }
        }
        if (entryProfile == null) {
          await api.requireProfileAccess(page.cidNumber, session);
        }
        await session.validateCurrent();
        if (revision != security?.revision.value) throw StateError('当前身份已变化');
        var consumed = false;
        consumeEntry = (current, currentRevision) {
          final available = !consumed;
          consumed = true;
          return available &&
              session.isUsable &&
              currentRevision == revision &&
              revision == security?.revision.value &&
              current.cidNumber == session.cidNumber &&
              current.accountId == session.accountId &&
              current.bindRev == session.bindRev;
        };
      }
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => consumeEntry == null
              ? page
              : _ProfileEntry(
                  consume: consumeEntry,
                  profile: entryProfile,
                  child: page,
                ),
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!context.mounted ||
          revision != security?.revision.value ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _showAccessNotice(context, error);
      if (!_privacyDenied(error)) {
        AppLog.profileLoadFailure(
          stage: 'access',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  static String _accessMessage(Object error) => switch (error) {
    SquareApiException(
      statusCode: 403,
      errorCode: 'profile_private' ||
          'profile_followers_required' ||
          'profile_mutual_required',
    ) =>
      '用户尚未开放主页访问，请稍后重试。',
    SquareApiException(statusCode: 404, errorCode: 'user_not_found') =>
      '用户主页暂不可用',
    _ => '内容加载失败，请下拉刷新',
  };

  static bool _privacyDenied(Object error) =>
      error is SquareApiException &&
      (error.statusCode == 403 &&
              const [
                'profile_private',
                'profile_followers_required',
                'profile_mutual_required',
              ].contains(error.errorCode) ||
          error.statusCode == 404 && error.errorCode == 'user_not_found');

  /// 只有明确的主页隐私拒绝才短暂提示；404及服务故障不能冒充权限结论。
  static void _showAccessNotice(BuildContext context, Object error) {
    if (error is! SquareApiException ||
        error.statusCode != 403 ||
        !_privacyDenied(error)) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_accessMessage(error)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  const UserProfilePage({
    super.key,
    required this.cidNumber,
    required this.isSelf,
    this.initialProfile,
    this.initialProfileMedia,
    this.api,
    this.cache,
    this.mediaCache,
    this.sessionProvider,
    this.subscriptionService,
    this.initialMembershipDecision =
        MembershipDisplayDecision.inactiveConfirmed,
    this.initialMembershipState,
    this.onOpenDirectChat,
    this.currentUserContext,
    this.badgeSnapshotStore,
  });

  /// 主页身份主键 = CID 号（cid_number）。资料/关注/帖子全按此 cid 寻址。
  final String cidNumber;

  /// 本人主页（可编辑资料）还是他人主页。
  final bool isSelf;

  /// 当前浏览者账户加载器（测试可注入）；默认取本机默认热钱包地址。
  /// 用于判定「他人视角看的其实是自己账户」时把动作按钮置灰。

  /// 首屏可选注入的资料（缓存或上层已拉到的）。
  final CitizenProfile? initialProfile;
  final CitizenProfileMediaSnapshot? initialProfileMedia;

  /// 数据入口，测试可注入替身。
  final CitizenProfileApi? api;
  final CitizenProfileCache? cache;
  final CitizenProfileMediaCache? mediaCache;
  final SquareSessionProvider? sessionProvider;
  final SubscriptionService? subscriptionService;

  /// “我的”页已经持有的会员二元首帧；他人主页不使用该覆盖值。
  final MembershipDisplayDecision initialMembershipDecision;
  final SquareMembershipState? initialMembershipState;

  /// 私聊入口，测试可注入 spy；默认交给本地 chat。
  final DirectChatOpener? onOpenDirectChat;
  final CurrentUserContext? currentUserContext;
  /// 仅用于核对本人缓存展示，不能恢复绑定或授予业务操作资格。
  final IdentityBadgeSnapshotStore? badgeSnapshotStore;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

/// 仅本次导航内部消费一次预检；不写入权限缓存，也不向页面公开放行参数。
class _ProfileEntry extends InheritedWidget {
  const _ProfileEntry({
    required this.consume,
    required this.profile,
    required super.child,
  });
  final bool Function(SquareSession, int?) consume;
  final ProfileEntryRefreshResult? profile;
  @override
  bool updateShouldNotify(_ProfileEntry oldWidget) => false;
}

enum _SelfStatus { other, cached, verified }

class _UserProfilePageState extends State<UserProfilePage>
    with WidgetsBindingObserver {
  /// 顶部头图高度（不含状态栏）。
  static const double _bannerHeight = 128;

  late final CitizenProfileApi _api;
  late final CitizenProfileCache _cache;
  late final CitizenProfileMediaCache _mediaCache;
  late final SquareSessionProvider _sessionProvider;
  SubscriptionService? _subscriptionService;
  late final DirectChatOpener _directChat;
  CitizenProfile? _profile;
  CitizenProfileMediaSnapshot _profileMedia =
      const CitizenProfileMediaSnapshot();
  SquareSession? _session;
  SquareSessionStatus? _sessionStatus;
  Future<SquareSession?>? _sessionFuture;
  bool _sessionResolved = false;
  int _postsRevision = 0;
  bool _refreshing = false;
  bool _followBusy = false;
  bool _contentRefreshFailed = false;
  int _profileLoadGeneration = 0;
  int _mediaLoadGeneration = 0;
  late MembershipDisplayDecision _membershipDecision;
  SquareMembershipState? _membershipState;

  /// 本人缓存展示与已验证绑定分开，展示快照不能授予操作资格。
  bool _relationsReady = false;
  CurrentUserContext? _currentUser;
  bool _accessAllowed = false;
  _SelfStatus _selfStatus = _SelfStatus.other;
  bool get _verifiedSelf => _selfStatus == _SelfStatus.verified;
  bool get _isSelf => _selfStatus != _SelfStatus.other;
  String? _accessError;
  bool _denyingAccess = false;
  String? _viewerCid;
  int _accessGeneration = 0;
  AccountSecurityService? _profileSecurity;
  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? CitizenProfileApi();
    _cache = widget.cache ?? const CitizenProfileCache();
    _mediaCache = widget.mediaCache ?? CitizenProfileMediaCache();
    _membershipDecision = widget.initialMembershipDecision;
    _membershipState = widget.initialMembershipState;
    _directChat =
        widget.onOpenDirectChat ??
        (context, {required peerUserId, required title}) => context
            .read<UserNavigation>()
            .openDirectChat(context, peerUserId: peerUserId, title: title);
    _profile = widget.initialProfile?.cidNumber == widget.cidNumber
        ? widget.initialProfile
        : null;
    _profileMedia = _profile == null
        ? const CitizenProfileMediaSnapshot()
        : widget.initialProfileMedia ?? const CitizenProfileMediaSnapshot();
    MembershipRevision.instance.listenable.addListener(_onMembershipChanged);
    CitizenProfileCache.revision.addListener(_onProfileChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) {
      return;
    }
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    final injectedSubscription = widget.subscriptionService;
    if (injectedSubscription != null) {
      _subscriptionService = injectedSubscription;
    } else {
      final sdk = context.read<CitizenSdk?>();
      final identityResolver = context.read<FinalizedIdentityResolver?>();
      if (sdk != null && identityResolver != null) {
        _subscriptionService = SubscriptionService(
          chainData: context.read<ChainDataService?>(),
          wallet: sdk,
          chain: sdk,
          transactions: sdk,
          identityResolver: identityResolver,
        );
      }
    }
    _currentUser =
        widget.currentUserContext ?? context.read<CurrentUserContext?>();
    _dependenciesReady = true;
    _profileSecurity = context.read<AccountSecurityService?>();
    _profileSecurity?.revision.addListener(_invalidatePageAccess);
    unawaited(_load());
    unawaited(_resolvePageAccess());
  }

  void _invalidatePageAccess({bool refreshOnEntry = true}) {
    _accessGeneration++;
    _profileLoadGeneration++;
    if (!mounted) return;
    setState(() {
      _accessAllowed = false;
      if (refreshOnEntry) _relationsReady = false;
      _selfStatus = _SelfStatus.other;
      _session = null;
      _sessionFuture = null;
      _sessionResolved = false;
    });
    unawaited(_resolvePageAccess(refreshOnEntry: refreshOnEntry));
  }

  Future<void> _resolvePageAccess({bool refreshOnEntry = true}) async {
    final generation = ++_accessGeneration;
    final revision = _profileSecurity?.revision.value;
    final entry = context.getInheritedWidgetOfExactType<_ProfileEntry>();
    bool current() =>
        mounted &&
        generation == _accessGeneration &&
        revision == _profileSecurity?.revision.value;
    try {
      final local = await _currentUser?.resolve();
      var citizen = local?.cidNumber;
      var cachedSelf = false;
      if (local != null && local.binding == null && !local.isUnregistered) {
        // 展示快照只能开放该账户本人的本地资料，不能补造绑定、会话或操作资格。
        final saved = await (widget.badgeSnapshotStore ?? IdentityBadgeSnapshotStore()).readForAccountId(local.accountId);
        final identity = saved?.identity;
        if (saved?.verified == true && saved?.accountId == local.accountId &&
            identity != null && identity.cidNumber == widget.cidNumber &&
            citizenAccountIdFromBytes(identity.accountId) == local.accountId) {
          citizen = identity.cidNumber;
          cachedSelf = true;
        }
      } else if (local == null) {
        citizen = await _sessionProvider.currentCitizenId();
      }
      if (!current()) return;
      if (citizen == null || citizen.isEmpty) throw StateError('当前公民身份尚未就绪');
      _viewerCid = citizen;
      final isSelf = citizen == widget.cidNumber;
      ProfileEntryRefreshResult? result;
      if (!isSelf) {
        final session = await _ensureSession();
        if (!current() ||
            session == null ||
            session.cidNumber != citizen ||
            local != null &&
                local.binding != null &&
                (session.accountId != local.accountId ||
                    session.bindRev != local.bindRev)) {
          throw StateError('当前公民会话不可用');
        }
        if (entry?.consume(session, revision) == true) {
          result = entry?.profile;
        } else {
          await _api.requireProfileAccess(widget.cidNumber, session);
        }
        await session.validateCurrent();
        if (!current()) return;
      }
      setState(() {
        _selfStatus = isSelf ? (cachedSelf ? _SelfStatus.cached : _SelfStatus.verified) : _SelfStatus.other;
        _accessAllowed = true;
        _accessError = null;
      });
      if (cachedSelf) {
        setState(() { _sessionResolved = true; _relationsReady = false; });
        return;
      }
      if (!refreshOnEntry) return;
      if (result == null) {
        var binding = local?.binding;
        if (binding == null) {
          // 独立页面/注入依赖仍可使用既有会话边界；正式App优先本地绑定并先检查限速。
          final session = await _ensureSession();
          if (!current() || session == null || session.cidNumber != citizen) {
            throw StateError('当前公民会话不可用');
          }
          binding = IdentityBinding(
            genesisHash: '',
            cidNumber: session.cidNumber,
            accountId: session.accountId,
            bindRev: session.bindRev,
          );
        }
        final owner = binding;
        final security = _profileSecurity;
        // 与页面mounted解耦，退出首个页面不取消其他同身份等待者的共享任务。
        result = await _api.refreshOnEntry(
          widget.cidNumber,
          binding: owner,
          sessions: _sessionProvider,
          cache: _cache,
          mediaCache: _mediaCache,
          isCurrentIdentity: () => revision == security?.revision.value,
        );
      }
      if (!current()) return;
      final authorized = result;
      if (authorized != null) {
        ++_profileLoadGeneration;
        setState(() {
          _session = authorized.session;
          _sessionStatus = SquareSessionStatus.ready;
          _sessionResolved = true;
          _profile = authorized.profile.profile;
          _relationsReady = true;
        });
        await _loadProfileMedia(authorized.profile.profile);
      } else {
        setState(() => _sessionResolved = true);
      }
    } on Object catch (error, stackTrace) {
      if (!current()) return;
      if (UserProfilePage._privacyDenied(error)) {
        await _denyAccess(error);
        return;
      }
      AppLog.profileLoadFailure(
        stage: 'background',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _sessionResolved = true;
        _relationsReady = false;
        if (!_accessAllowed) {
          _accessError = UserProfilePage._accessMessage(error);
        }
      });
    }
  }

  String _profileFailureMessage(Object error) {
    if (error is SquareApiException) {
      if (error.errorCode == 'profile_membergate_required') {
        return '非会员禁止访问用户主页';
      }
      if (error.statusCode == 404) return '该用户不存在';
      if (error.statusCode == 401) return '会话已失效，请下拉重试';
      if (error.statusCode == 403) return '当前用户主页不可访问';
    }
    return '内容加载失败，请下拉刷新';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessGeneration++;
    _profileSecurity?.revision.removeListener(_invalidatePageAccess);
    _profileLoadGeneration++;
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    CitizenProfileCache.revision.removeListener(_onProfileChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_verifiedSelf &&
        !_denyingAccess) {
      _invalidatePageAccess(refreshOnEntry: false);
    }
  }

  Future<void> _denyAccess(Object error) async {
    if (!mounted || _denyingAccess) return;
    _denyingAccess = true;
    final message = UserProfilePage._accessMessage(error);
    setState(() {
      _accessAllowed = false;
      _accessError = message;
      _selfStatus = _SelfStatus.other;
      _relationsReady = false;
      _profile = null;
      _profileMedia = const CitizenProfileMediaSnapshot();
      _accessGeneration++;
      _profileLoadGeneration++;
      _mediaLoadGeneration++;
    });
    final navigator = Navigator.of(context);
    if (ModalRoute.of(context)?.isCurrent == false) {
      _denyingAccess = false;
      return;
    }
    if (navigator.canPop()) navigator.pop();
    UserProfilePage._showAccessNotice(navigator.context, error);
    if (mounted) setState(() => _denyingAccess = false);
  }

  /// 当前主页 CID 的会员镜像变化时重读资料，并重建当前内容 Tab 的作者徽章。
  void _onMembershipChanged() {
    if (!mounted) return;
    if (MembershipRevision.instance.listenable.value?.cidNumber == _viewerCid) {
      setState(() => _relationsReady = false);
      unawaited(_load());
      return;
    }

    final event = MembershipRevision.instance.listenable.value;
    if (!mounted || event == null || event.cidNumber != widget.cidNumber) {
      return;
    }
    setState(() => _postsRevision += 1);

    unawaited(_load());
  }

  bool? get _confirmedMembershipActive {
    if (!_isSelf) {
      return null;
    }
    return switch (_membershipDecision) {
      MembershipDisplayDecision.activeConfirmed => true,
      MembershipDisplayDecision.inactiveConfirmed => false,
    };
  }

  void _onProfileChanged() {
    if (CitizenProfileCache.revision.value?.cidNumber == widget.cidNumber) {
      unawaited(_load());
    }
  }

  /// 首屏与revision通知只读本地；不触发远端刷新或清除已有展示。
  Future<void> _load() async {
    final generation = ++_profileLoadGeneration;
    try {
      final local = await _cache.read(widget.cidNumber);
      if (!mounted || generation != _profileLoadGeneration) return;
      if (local != null &&
          local.cidNumber == widget.cidNumber &&
          (_profile == null ||
              _profile is CitizenProfileCard ||
              local.profileAt >= _profile!.profileAt)) {
        final relationship = _profile;
        setState(
          () => _profile = local.copyWith(
            isFollowing: _relationsReady
                ? relationship?.isFollowing ?? false
                : false,
            isFollowedBy: _relationsReady
                ? relationship?.isFollowedBy ?? false
                : false,
            isNotifying: _relationsReady
                ? relationship?.isNotifying ?? false
                : false,
          ),
        );
        await _loadProfileMedia(_profile!);
      } else if (_profile != null) {
        await _loadProfileMedia(_profile!);
      }
    } on Object catch (error, stackTrace) {
      AppLog.profileLoadFailure(
        stage: 'local_read',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 主动刷新同时覆盖本地读取和远端同步；页面拥有完整操作状态，不随Tab重建消失。
  Future<void> _syncMemberCloudPosts(
    SquareSession session,
    bool Function() current,
  ) async {
    try {
      await _subscriptionService!.requireSquareAccess(session);
      if (!current()) {
        return;
      }
      await SquarePostSyncService().sync(
        session,
        userInitiated: true,
        isCurrent: current,
      );
    } on SquareApiException catch (error) {
      if (error.errorCode != 'square_membergate_required') {
        rethrow;
      }
    }
  }

  bool Function() _identityCurrentFor(SquareSession session) {
    final security = _profileSecurity;
    final revision = security?.revision.value;
    return () => session.isUsable && revision == security?.revision.value;
  }

  Future<void> _refresh() async {
    // 资料刷新与关系写入互斥，避免复用写入前已发出的旧资料请求。
    if (_refreshing || _followBusy) {
      return;
    }
    if (!_accessAllowed) {
      // 错误页也可重试；他人访问的原业务请求完成后无需再发第二遍资料GET。
      await _resolvePageAccess(refreshOnEntry: false);
      if (!_accessAllowed) return;
    }
    setState(() {
      _refreshing = true;
      _contentRefreshFailed = false;
      _postsRevision++;
    });
    try {
      // 手动刷新先恢复本地，再独立校准云端；失败不清空缓存UI。
      await _load();
      final session = await _ensureSession(refresh: true);
      if (session == null) {
        throw StateError('当前无法建立服务会话');
      }
      if (_isSelf && session.cidNumber != widget.cidNumber) {
        throw StateError('当前用户已变化');
      }
      final accessGeneration = _accessGeneration;
      final revision = _profileSecurity?.revision.value;
      bool current() =>
          mounted &&
          accessGeneration == _accessGeneration &&
          revision == _profileSecurity?.revision.value &&
          _session?.cidNumber == session.cidNumber &&
          _session?.accountId == session.accountId &&
          _session?.bindRev == session.bindRev;
      CitizenProfileLoadResult? profileResult;
      await Future.wait<void>([
        _api
            .refreshProfile(
              widget.cidNumber,
              session: session,
              userInitiated: true,
              isCurrent: _identityCurrentFor(session),
              cache: _cache,
              mediaCache: _mediaCache,
            )
            .then<void>((result) {
              profileResult = result;
            }),
        if (_isSelf && _subscriptionService != null)
          _syncMemberCloudPosts(session, current),
      ]);
      if (!current()) {
        return;
      }
      final result = profileResult!;
      ++_profileLoadGeneration;
      setState(() {
        _profile = result.profile;

        _relationsReady = true;
      });
      await _loadProfileMedia(result.profile);
      if (_isSelf) {
        await _api.fetchLocalPublishedPosts(widget.cidNumber);
      }
      if (!current()) {
        return;
      }
      if (mounted) {
        setState(() => _postsRevision++);
        final message = result.refreshMessage;
        if (message != null) _snack(message);
      }
    } catch (error) {
      if (mounted) {
        if (UserProfilePage._privacyDenied(error)) {
          await _denyAccess(error);
          return;
        }
        setState(() {
          _contentRefreshFailed = true;
          _relationsReady = false;
        });
        _snack(_profileFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _loadProfileMedia(CitizenProfile profile) async {
    final generation = ++_mediaLoadGeneration;
    try {
      final local = await _mediaCache.read(profile);
      if (mounted &&
          generation == _mediaLoadGeneration &&
          _profile?.cidNumber == profile.cidNumber &&
          _profile?.profileAt == profile.profileAt &&
          _profile?.avatarKey == profile.avatarKey &&
          _profile?.bannerKey == profile.bannerKey) {
        setState(
          () => _profileMedia = CitizenProfileMediaSnapshot(
            avatarPath: profile.avatarKey == null
                ? null
                : local.avatarPath ?? _profileMedia.avatarPath,
            bannerPath: profile.bannerKey == null
                ? null
                : local.bannerPath ?? _profileMedia.bannerPath,
          ),
        );
      }
    } catch (_) {
      /* 读取失败不触发下载，也不丢弃已保存图片。 */
    }
  }

  /// 默认热钱包静默登录换 Session；同一时刻只允许一个握手。首次结果落地前
  /// [_sessionResolved] 保持 false，让帖子 Tab 等待而不是用 null 抢跑请求 Worker。
  Future<SquareSession?> _ensureSession({bool refresh = false}) {
    final pending = _sessionFuture;
    if (pending != null) {
      return pending;
    }
    if (refresh && mounted) {
      setState(() => _sessionResolved = false);
    }
    late final Future<SquareSession?> future;
    future = _resolveSession(refresh).whenComplete(() {
      if (identical(_sessionFuture, future)) {
        _sessionFuture = null;
      }
    });
    _sessionFuture = future;
    return future;
  }

  /// 首次握手仍由本页统一持有，但失败原因必须保留给内容区，禁止把远端故障伪装成无钱包。
  Future<SquareSession?> _resolveSession(bool refresh) async {
    final generation = _accessGeneration;
    final revision = _profileSecurity?.revision.value;
    final resolution = await _sessionProvider.resolveSession(refresh: refresh);
    if (!mounted ||
        generation != _accessGeneration ||
        revision != _profileSecurity?.revision.value) {
      return null;
    }
    if (mounted) {
      setState(() {
        _session = resolution.session;
        _sessionStatus = resolution.status;
        _sessionResolved = true;
      });
    }
    return resolution.session;
  }

  /// 帖子请求收到 401 时清缓存并只重新握手一次；新 Session 仍由本页统一持有。
  Future<SquareSession?> _refreshSessionAfterUnauthorized() =>
      _ensureSession(refresh: true);

  Future<void> _toggleFollow() async {
    final before = _profile;
    if (!_accessAllowed ||
        !_relationsReady ||
        before == null ||
        _followBusy ||
        _refreshing) {
      return;
    }
    final target = widget.cidNumber;
    setState(() => _followBusy = true);
    try {
      final session = _session ?? await _ensureSession();
      if (!mounted) {
        return;
      }
      if (session == null) {
        _snack(_sessionStatus?.message ?? '公民服务暂时不可用，请稍后重试');
        return;
      }
      if (_isSelf && session.cidNumber != target) {
        _snack('当前用户已变化，请重新进入主页');
        return;
      }
      bool current() =>
          mounted &&
          widget.cidNumber == target &&
          _session?.cidNumber == session.cidNumber &&
          _session?.accountId == session.accountId &&
          _session?.bindRev == session.bindRev;
      if (!current()) {
        return;
      }
      final wasFollowing = before.isFollowing;
      // 只即时切换关系图标；三项计数不手算，等待同一次服务端资料确认。
      setState(
        () => _profile = before.copyWith(
          isFollowing: !wasFollowing,
          isNotifying: !wasFollowing,
        ),
      );
      try {
        if (wasFollowing) {
          await _api.unfollowUser(session: session, peerCid: target);
        } else {
          await _api.followUser(session: session, peerCid: target);
        }
      } on Exception {
        if (current()) {
          setState(() => _profile = before);
          _snack('操作失败，请重试');
        }
        return;
      }
      // 写入成功立即废弃旧关系下的列表，不等待资料回读成功。
      if (!current()) return;
      setState(() => _postsRevision++);
      try {
        final fresh = await _api.refreshProfile(
          target,
          session: session,
          userInitiated: true,
          isCurrent: _identityCurrentFor(session),
          cache: _cache,
          mediaCache: _mediaCache,
        );
        if (current()) {
          setState(() {
            _profile = fresh.profile;
          });
          await _loadProfileMedia(fresh.profile);
          if (current() && fresh.hasWarning) _snack(fresh.refreshMessage!);
        }
      } on Exception catch (error) {
        // 写入已经成功，资料回读失败不能反向撤销用户的关注/取关。
        if (UserProfilePage._privacyDenied(error)) {
          await _denyAccess(error);
          return;
        }
        if (current()) {
          _snack('关注已更新，资料刷新失败，请下拉刷新');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _followBusy = false);
      }
    }
  }

  /// 开/关该用户的发帖通知（红点+声音）。通知归属挂在关注关系上：未关注先提示去关注；
  /// 关注后铃铛按用户静音/取消静音，静音不影响其内容在关注流展示。
  Future<void> _toggleNotify() async {
    if (!_accessAllowed || !_relationsReady) return;
    final current = _profile;
    if (current == null) {
      return;
    }
    if (!current.isFollowing) {
      _snack('请先关注 TA 再开启通知');
      return;
    }
    final session = _session ?? await _ensureSession();
    if (!mounted) {
      return;
    }
    if (session == null) {
      _snack(_sessionStatus?.message ?? '公民服务暂时不可用，请稍后重试');
      return;
    }
    final wasNotifying = current.isNotifying;
    // 乐观更新。
    setState(() {
      _profile = current.copyWith(isNotifying: !wasNotifying);
    });
    try {
      await _api.setNotify(
        session: session,
        peerCid: widget.cidNumber,
        enabled: !wasNotifying,
      );
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _profile = current); // 失败回滚。
      _snack('操作失败，请重试');
    }
  }

  Future<void> _openEditProfile() async {
    if (!_accessAllowed || !_verifiedSelf) return;
    final updated = await Navigator.of(context).push<CitizenProfile>(
      MaterialPageRoute<CitizenProfile>(
        builder: (_) => CitizenProfileEditPage(
          cidNumber: widget.cidNumber,
          initialProfile: _profile,
          api: _api,
          cache: _cache,
          sessionProvider: _sessionProvider,
        ),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() => _profile = updated);
    await _loadProfileMedia(updated);
  }

  /// 注销用户（仅本人）：二次确认 → 主钥签名(生物识别) → 服务端硬删 → 清本地 → 回落空态。
  /// 无冷静期、硬删不可逆；链上数据与本地钱包不受影响。
  Future<void> _openDeleteAccount() async {
    // 注销目标始终是页面永久 CID；本机已验证绑定账户完成
    // 会话与主钥签名授权，Worker 会再用 finalized 链双向绑定复核，不能决定删除范围。
    final local = await context.read<CurrentUserContext?>()?.resolve();
    if (!mounted) {
      return;
    }
    final selfAccountId = local?.cidNumber == widget.cidNumber
        ? local?.binding?.accountId ?? ''
        : '';
    if (selfAccountId.isEmpty) {
      _snack('轻节点绑定尚未核验，请刷新重试');
      return;
    }
    final sdk = context.read<CitizenSdk>();
    final walletState = await sdk.getWalletState().result;
    if (!mounted) {
      return;
    }
    if (!walletState.accounts.any(
      (account) => account.accountId == selfAccountId,
    )) {
      _snack('未找到当前身份钱包账户，无法注销');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('注销用户'),
        content: const Text('注销将立即硬删除你在公民广场/私信的全部数据，无冷静期、不可恢复，链上数据不受注销影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final users = context.read<CurrentUserContext>();
      final binding = (await users.resolve())?.binding;
      if (!mounted) {
        return;
      }
      if (binding == null ||
          binding.cidNumber != widget.cidNumber ||
          binding.accountId != selfAccountId) {
        _snack('当前身份与本人主页不一致，请刷新后重试');
        return;
      }
      Future<void> requireDeletionBinding() async {
        final current = (await users.resolve())?.binding;
        if (current == null ||
            current.cidNumber != binding.cidNumber ||
            current.accountId != binding.accountId ||
            current.bindRev != binding.bindRev ||
            current.genesisHash != binding.genesisHash) {
          throw const SquareApiException('当前身份已变化，请重新打开本人主页');
        }
      }

      await SquareAccountDeletionService(
        clearChatHistory: (context.read<ChatRuntime>()).clearAllForUserId,
      ).deleteAccount(
        binding: binding,
        requireCurrent: requireDeletionBinding,
        // 账户注销签名统一交给 CitizenSDK，冷热模式不在页面分支。
        // 聊天MLS状态按cid_number精确清理，不进入钱包签名模式。
        signAction: (message) async =>
            '0x${bytesToHex(await signCitizenPayload(signing: sdk, context: context, accountId: selfAccountId, payload: message, action: CitizenQrActions.squareAccountAction))}',
      );
    } on SquareAccountDeletionPendingException catch (e) {
      if (mounted) {
        _snack(e.message);
      }
      return;
    } on SquareAccountLocalCleanupException catch (e) {
      // Worker 已经完成不可逆注销；此时不能误报“注销失败”诱导用户重复提交。
      if (mounted) {
        _snack(e.toString());
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    } on SquareApiException catch (e) {
      if (mounted) {
        _snack('注销失败：${e.message}');
      }
      return;
    } on CitizenSdkException catch (e) {
      if (mounted) {
        _snack('注销已取消：${e.message}');
      }
      return;
    } on Exception catch (e) {
      // 兜底：注销签名的任何异常都必须有反馈，永不静默。
      if (mounted) {
        _snack('注销失败：$e');
      }
      return;
    }

    if (!mounted) {
      return;
    }
    _snack('账户已注销');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openUserCode() async {
    // 用户码载荷取该永久公民号当前绑定的 account_id，供加联系人和转账使用。
    final source = context.read<ChainDataService?>();
    String accountId = '';
    try {
      final data = await source?.ensureCitizen(widget.cidNumber);
      final identity = data?.citizens[widget.cidNumber]?.identity;
      if (identity != null) {
        accountId = citizenAccountIdFromBytes(identity.accountId);
      }
    } on Object {
      /* 不用缓存或服务端资料补填当前绑定。 */
    }
    if (!mounted) {
      return;
    }
    if (accountId.isEmpty) {
      _snack('轻节点绑定尚未核验，请刷新重试');
      return;
    }
    final document = await context.read<CitizenSdk>().encodeDocument(
      CitizenQrContent.userContact(
        cidNumber: widget.cidNumber,
        accountId: accountId,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserQrPage(
          qrData: document.canonicalText,
          cidNumber: widget.cidNumber,
          displayName: _displayName,
          accountId: accountId,
          isSelf: _isSelf,
        ),
      ),
    );
  }

  void _openChatWithUser() {
    final peerCidNumber = widget.cidNumber.trim();
    if (peerCidNumber.isEmpty) {
      _snack('轻节点绑定尚未核验，请刷新重试');
      return;
    }
    _directChat(context, peerUserId: peerCidNumber, title: _displayName);
  }

  Future<void> _openFollows(FollowsType type) async {
    final session = await _ensureSession();
    if (!mounted) {
      return;
    }
    if (session == null) {
      _snack(
        _sessionStatus == SquareSessionStatus.noWallet
            ? '需要钱包账户才能浏览关注列表'
            : _sessionStatus?.message ?? '公民服务暂时不可用，请稍后重试',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FollowsListPage(
          cidNumber: widget.cidNumber,
          type: type,
          session: session,
          api: _api,
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 公开昵称只取后端 `display_name`；缺失时按 CID 稳定生成本地占位昵称。
  String get _displayName {
    return ProfilePresentation.forIdentityKey(
      widget.cidNumber,
    ).resolveDisplayName(publicName: _profile?.displayName);
  }

  String get _title => _displayName;

  Widget _bannerWidget() {
    final fallback = Image.asset(
      ProfilePresentation.forIdentityKey(widget.cidNumber).bannerAsset,
      fit: BoxFit.cover,
    );
    final objectKey = _profile?.bannerKey?.trim();
    if (objectKey == null || objectKey.isEmpty) {
      return fallback;
    }
    final path = _profileMedia.bannerPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return const ColoredBox(color: AppTheme.surfaceMuted);
  }

  /// 他人主页的创作者订阅入口：Square 以公民 CID 为创作者唯一主键。
  /// 本人主页不显示；CID 不因换绑改变，因此换绑不会重建或丢失订阅态。
  Widget? _creatorSubscribeButton() {
    if (_isSelf || !_accessAllowed || !_relationsReady || _session == null) {
      return null;
    }
    final creatorCid = widget.cidNumber.trim();
    if (creatorCid.isEmpty) {
      return null;
    }
    return CreatorSubscribeButton(
      key: ValueKey<String>('creator-subscribe:$creatorCid'),
      creatorCid: creatorCid,
      enabled: !_verifiedSelf,
      sessionProvider: _sessionProvider,
    );
  }

  Future<void> _openPost(SquarePost post) async {
    final result = await Navigator.of(context).push<SquarePostDetailResult>(
      MaterialPageRoute<SquarePostDetailResult>(
        builder: (_) => CitizenServiceGate(
          title: '内容详情',
          description: '注册后即可查看广场内容。',
          child: SquarePostDetailPage(post: post),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _postsRevision += 1);
    }
  }

  Future<void> _openArticle(SquarePost post) async {
    final result = await Navigator.of(context).push<SquarePostDetailResult>(
      MaterialPageRoute<SquarePostDetailResult>(
        builder: (_) => CitizenServiceGate(
          title: '内容详情',
          description: '注册后即可查看广场内容。',
          child: SquareArticleDetailPage(post: post),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _postsRevision += 1);
    }
  }

  Widget _tabBody(ProfileTab tab) {
    if (_selfStatus == _SelfStatus.cached) {
      return const Center(child: Text('身份核验完成后显示动态'));
    }
    final session = _session;
    final revision = _postsRevision;
    void accessDenied(SquareApiException error) {
      // 关系写入后旧列表的迟到拒绝不能关闭新关系下的主页。
      if (revision == _postsRevision && UserProfilePage._privacyDenied(error)) {
        unawaited(_denyAccess(error));
      }
    }

    switch (tab) {
      case ProfileTab.posts:
        return ProfilePostsTab(
          key: ValueKey('posts:$_postsRevision'),
          cidNumber: widget.cidNumber,
          api: _api,
          category: SquarePostCategory.normal,
          postType: SquarePostType.document,
          emptyLabel: '暂无公文内容，请在广场发布',
          session: session,
          sessionReady: _sessionResolved,
          onSessionExpired: _refreshSessionAfterUnauthorized,
          onAccessDenied: accessDenied,
          isSelf: _verifiedSelf,
          refreshFailed: _contentRefreshFailed,
          onOpenPost: _openPost,
        );
      case ProfileTab.campaign:
        return ProfilePostsTab(
          key: ValueKey('campaign:$_postsRevision'),
          cidNumber: widget.cidNumber,
          api: _api,
          category: SquarePostCategory.campaign,
          emptyLabel: '暂无竞选内容，请在广场发布',
          session: session,
          sessionReady: _sessionResolved,
          onSessionExpired: _refreshSessionAfterUnauthorized,
          onAccessDenied: accessDenied,
          isSelf: _verifiedSelf,
          refreshFailed: _contentRefreshFailed,
          onOpenPost: _openPost,
        );
      case ProfileTab.videos:
        return ProfilePostsTab(
          key: ValueKey('videos:$_postsRevision'),
          cidNumber: widget.cidNumber,
          api: _api,
          category: SquarePostCategory.normal,
          postType: SquarePostType.video,
          mediaKind: SquareMediaKind.video,
          emptyLabel: '暂无视频内容，请在广场发布',
          session: session,
          sessionReady: _sessionResolved,
          onSessionExpired: _refreshSessionAfterUnauthorized,
          onAccessDenied: accessDenied,
          isSelf: _verifiedSelf,
          refreshFailed: _contentRefreshFailed,
          onOpenPost: _openPost,
        );
      case ProfileTab.articles:
        return ProfilePostsTab(
          key: ValueKey('articles:$_postsRevision'),
          cidNumber: widget.cidNumber,
          api: _api,
          category: SquarePostCategory.normal,
          postType: SquarePostType.article,
          emptyLabel: '暂无文章内容，请在广场发布',
          session: session,
          sessionReady: _sessionResolved,
          onSessionExpired: _refreshSessionAfterUnauthorized,
          onAccessDenied: accessDenied,
          isSelf: _verifiedSelf,
          refreshFailed: _contentRefreshFailed,
          onOpenPost: _openArticle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 他人缓存不能作为访问许可；直接构造页面也必须经过同一服务端检查。
    if (!_accessAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户主页')),
        body: Center(
          child: _accessError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_accessError!),
                    TextButton(
                      onPressed: () => _resolvePageAccess(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
        ),
      );
    }
    final expandedHeight =
        _bannerHeight +
        ProfileCategoryTabs.height +
        ProfileHeaderCard.requiredHeight(
          context,
          profileBio: _profile?.profileBio ?? '',
        );
    return DefaultTabController(
      length: ProfileTab.values.length,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          // 外层与当前内层的纵向通知均由页面接收，刷新图标绘制在头图之上。
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical &&
              notification.depth <= 2,
          child: Stack(
            children: [
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverAppBar(
                      pinned: true,
                      expandedHeight: expandedHeight,
                      // 品牌色只作为所有图片均失败时的最底层兜底；完全折叠态由
                      // CollapsibleHeader 明确绘制真实背景，不再依赖透明 Material 透出页面。
                      backgroundColor: AppTheme.primaryDark,
                      surfaceTintColor: Colors.transparent,
                      scrolledUnderElevation: 0,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.chevron_left),
                        // 背景图明暗不定：加半透明深色圆形底衬保证白色返回箭头始终可读。
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.32),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      actions: [
                        ProfileKebabMenu(
                          isSelf: _isSelf,
                          onUserCode: _accessAllowed && _verifiedSelf ? _openUserCode : null,
                          onEditProfile: _accessAllowed && _verifiedSelf
                              ? _openEditProfile
                              : null,
                          onDeleteAccount: _accessAllowed && _verifiedSelf
                              ? _openDeleteAccount
                              : null,
                        ),
                      ],
                      // 展开头图和固定折叠头图各自明确渲染；不能再以透明背景替代真实图片。
                      flexibleSpace: CollapsibleHeader(
                        expandedHeight: expandedHeight,
                        bannerHeight: _bannerHeight,
                        bottomHeight: ProfileCategoryTabs.height,
                        collapsedTitle: _title,
                        banner: _bannerWidget(),
                        collapsedBanner: _bannerWidget(),
                        foreground: ProfileHeaderCard(
                          cidNumber: widget.cidNumber,
                          profile: _profile,
                          avatarPath: _profileMedia.avatarPath,
                          avatarImage: null,
                          confirmedMembershipLevel:
                              _membershipState?.memberLevel,
                          confirmedMembershipActive: _confirmedMembershipActive,
                          onFollowing: () =>
                              _openFollows(FollowsType.following),
                          onFollowers: () =>
                              _openFollows(FollowsType.followers),
                          onMutualFollowing: () =>
                              _openFollows(FollowsType.mutualFollowing),
                          actions: ProfileActionIcons(
                            isSelf: _isSelf,
                            enabled:
                                _accessAllowed &&
                                _relationsReady &&
                                !_refreshing,
                            isFollowing:
                                _relationsReady &&
                                (_profile?.isFollowing ?? false),
                            isNotifying:
                                _relationsReady &&
                                (_profile?.isNotifying ?? false),
                            // 有有效创作者计划时在通知左侧就地出现；不存在时完全不占位。
                            leading: _creatorSubscribeButton(),
                            onNotify: _toggleNotify,
                            onChat: _openChatWithUser,
                            onToggleFollow:
                                _followBusy || _refreshing || _profile == null
                                ? null
                                : _toggleFollow,
                          ),
                        ),
                      ),
                      bottom: ProfileCategoryTabs(
                        posts: _profile?.posts ?? 0,
                        campaigns: _profile?.campaigns ?? 0,
                        videos: _profile?.videos ?? 0,
                        articles: _profile?.articles ?? 0,
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    for (final tab in ProfileTab.values) _tabBody(tab),
                  ],
                ),
              ),
              if (_refreshing)
                Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: const LinearProgressIndicator(
                    key: ValueKey('profile-refresh-progress'),
                    semanticsLabel: '正在刷新内容',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 展示头图、头像、身份、昵称、签名及统计和主页动作。

/// 推特式资料卡：头图下方白底，圆角方形头像跨压头图下缘 + 认证勾 +
/// 展示名/身份CID号/签名/计数 + 右上三图标。
///
/// 头像用 [Positioned] 上移半个身位跨到头图上；文字为深色（落在白底）；
/// 数据来自已加载的 [profile]（可空 → 占位）。
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.cidNumber,
    required this.profile,
    required this.actions,
    this.avatarPath,
    this.avatarUrl,

    this.avatarImage,
    this.confirmedMembershipLevel,
    this.confirmedMembershipActive,
    this.onFollowing,
    this.onFollowers,
    this.onMutualFollowing,
  });

  /// 主页身份主键 cid_number（默认昵称/头像的稳定派生种子）。展示用的当前绑定
  /// 钱包账户从 [profile].account_id 取。
  final String cidNumber;
  final CitizenProfile? profile;

  /// 已校验的本机用户头像缓存；存在时优先于网络 URL。
  final String? avatarPath;

  /// 头像图片 URL（object_key 解析后的公开媒体地址）；为空显示占位。
  final String? avatarUrl;

  /// 完整资料媒体的签名读取器；不携带可复用的一次性证明头。
  final ImageProvider? avatarImage;

  /// 页面可传入已核验的本机会员展示提示，正式App头像订阅统一轻节点读模型。
  /// null 表示尚未确认；提示不授予业务权限，也不从公开资料恢复链上状态。
  final String? confirmedMembershipLevel;
  final bool? confirmedMembershipActive;

  /// 右上三图标（[ProfileActionIcons]）。
  final Widget actions;

  final VoidCallback? onFollowing;
  final VoidCallback? onFollowers;
  final VoidCallback? onMutualFollowing;

  /// 头像尺寸；上移半个身位跨压头图。
  static const double _avatarSize = 80;
  static const double _avatarOverlap = 40;

  /// 统计文字底部到分类文字顶部的产品视觉间距。
  static const double statsToCategoryVisualGap = 15;

  /// 资料主体在展开态需要的最小高度。
  ///
  /// SliverAppBar 不能从 FlexibleSpaceBar 的子项反向取得自然高度，因此这里按
  /// 与真实 Column 完全相同的文字样式测量。头像操作带、各段间距、统计与底部留白
  /// 均固定，个性签名按完整文字的实际行数计算高度。
  static double requiredHeight(
    BuildContext context, {
    required String profileBio,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final baseStyle = Theme.of(context).textTheme.bodyMedium!;
    double textHeight(
      String text,
      TextStyle style, {
      int? maxLines = 1,
      double maxWidth = double.infinity,
      bool rich = false,
    }) {
      final painter = TextPainter(
        // 测量在Scaffold外调用，显式使用Material正文样式，并保持统计Text.rich的根样式。
        text: rich
            ? TextSpan(
                style: baseStyle,
                children: [TextSpan(text: text, style: style)],
              )
            : TextSpan(text: text, style: baseStyle.merge(style)),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);
      return painter.height;
    }

    final nameStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 18),
      fontWeight: FontWeight.w600,
    );
    final cidStyle = TextStyle(fontSize: AppLayout.scaled(context, 12));
    final bioStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 13),
      height: 1.45,
    );
    final statStyle = TextStyle(
      fontSize: AppLayout.scaled(context, 13),
      fontWeight: FontWeight.w600,
    );
    final normalizedBio = profileBio.trim();
    final bioHeight = normalizedBio.isEmpty
        ? 0.0
        : 8 +
              textHeight(
                normalizedBio,
                bioStyle,
                maxLines: null,
                maxWidth: MediaQuery.sizeOf(context).width - 32,
              );
    // SliverAppBar.bottom 与 flexible space 叠层会吃掉约 2.5px；外部高度需同时
    // 扣除分类文字内部顶部间距并补回叠层，才能得到产品定义的 15px 视觉间距。
    const statsToCategoryOuterGap =
        statsToCategoryVisualGap - ProfileCategoryTabs.labelTopPadding + 2.5;
    return 44 +
        8 +
        textHeight('昵称', nameStyle) +
        3 +
        textHeight('身份CID号', cidStyle) +
        bioHeight +
        12 +
        textHeight('0 关注者', statStyle, rich: true) +
        statsToCategoryOuterGap;
  }

  /// 链上身份档位；无有效会员时徽章据此分色（访客金/投票蓝/竞选红）。
  String? get _identityLevel => profile?.cidLevel;

  /// 会员信号；有效态与合法档位共同决定会员徽章的档位色和对勾。
  String? get _membershipLevel => confirmedMembershipActive == true
      ? confirmedMembershipLevel
      : profile?.memberLevel;
  bool get _membershipActive =>
      confirmedMembershipActive ?? profile?.membergateActive ?? false;

  String get _name {
    return ProfilePresentation.forIdentityKey(
      cidNumber,
    ).resolveDisplayName(publicName: profile?.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final profileBio = profile?.profileBio.trim() ?? '';
    return ColoredBox(
      color: AppTheme.surfaceCard,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像下半部与右上三图标同处一带；头像另由 Positioned 跨压头图。
                SizedBox(
                  height: _avatarOverlap + 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: AppLayout.scaled(context, 10),
                      ),
                      child: actions,
                    ),
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 8)),
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: AppLayout.scaled(context, 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 3)),
                _IdentityDetails(cidNumber: cidNumber),
                if (profileBio.isNotEmpty) ...[
                  SizedBox(height: AppLayout.scaled(context, 8)),
                  Text(
                    profileBio,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppLayout.scaled(context, 13),
                      height: 1.45,
                    ),
                  ),
                ],
                SizedBox(height: AppLayout.scaled(context, 12)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Stat(
                        value: profile?.mutualFollowing ?? 0,
                        label: '互关',
                        onTap: onMutualFollowing,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 18)),
                      _Stat(
                        value: profile?.following ?? 0,
                        label: '关注',
                        onTap: onFollowing,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 18)),
                      _Stat(
                        value: profile?.followers ?? 0,
                        label: '关注者',
                        onTap: onFollowers,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppLayout.scaled(context, 16),
            top: -_avatarOverlap,
            child: ProfileAvatar(
              size: _avatarSize,
              cidLevel: _identityLevel,
              memberLevel: _membershipLevel,
              membergateActive: _membershipActive,
              imagePath: avatarPath,
              imageUrl: avatarUrl,

              imageProvider: avatarImage,
              userImageSet: profile?.avatarKey?.trim().isNotEmpty == true,
              seed: cidNumber,
              borderColor: AppTheme.surfaceCard,
              borderWidth: 4,
              borderRadius: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityDetails extends StatelessWidget {
  const _IdentityDetails({required this.cidNumber});

  final String cidNumber;

  @override
  Widget build(BuildContext context) {
    final cid = formatIdentityCidText(cidNumber.trim());
    return Text(
      cid.isEmpty ? '身份CID号：暂不可用' : '身份CID号：$cid',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppTheme.textTertiary,
        fontSize: AppLayout.scaled(context, 12),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // 三项关系统计必须保持同一行；大字体下允许横向查看完整内容，不能把
      // 系统已经放大的文字再缩回去。
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppLayout.scaled(context, 13),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppLayout.scaled(context, 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 绘制折叠虚化头图和渐变资料区及居中标题。

/// 推特式折叠头部：顶部短头图（折叠时渐进虚化）+ 头图下方白底资料区。
///
/// 展开态呈「短头图在上、白底资料在下、头像跨压头图下缘」的推特结构；上滑时
/// 头图渐进虚化、资料区淡出，折叠满时浮现居中标题（分类标签由外层 SliverAppBar
/// 的 bottom 固定吸顶）。虚化只作用于头图单图层（[ImageFiltered]），不使用全屏
/// [BackdropFilter]，避免每帧重算整屏。
class CollapsibleHeader extends StatelessWidget {
  const CollapsibleHeader({
    super.key,
    required this.expandedHeight,
    required this.bannerHeight,
    required this.bottomHeight,
    required this.foreground,
    required this.collapsedTitle,
    this.banner,
    this.collapsedBanner,
  });

  /// SliverAppBar 的 expandedHeight（不含状态栏），用于换算折叠比例。
  final double expandedHeight;

  /// 顶部头图高度（不含状态栏）；资料区从头图下缘开始。
  final double bannerHeight;

  /// SliverAppBar 底部分类栏高度；折叠比例必须把它计入最小高度。
  final double bottomHeight;

  /// 头图下方的白底资料主体（头像/名/计数等），随折叠淡出。
  final Widget foreground;

  /// 折叠满时浮现的居中标题。
  final String collapsedTitle;

  /// 头图图层；为空时纯品牌色平铺。
  final Widget? banner;

  /// 完全折叠后固定铺在状态栏安全区和工具栏下方的同一真实背景图。
  ///
  /// 该图层不参与展开头图的强模糊，也不依赖 AppBar 透明色“透出”页面。
  final Widget? collapsedBanner;

  static const double _maxBlurSigma = 18;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final toolbarExtent = kToolbarHeight + topPadding;
    final minHeight = toolbarExtent + bottomHeight;
    final maxHeight = expandedHeight + topPadding;
    final bannerBottom = topPadding + bannerHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = (maxHeight - minHeight).clamp(1.0, double.infinity);
        final scroll = (maxHeight - constraints.maxHeight).clamp(0.0, span);
        final collapse = scroll / span;
        // 长资料先滚动完超屏部分，再按原规则淡出；普通高度的位移仍为0。
        final viewport =
            MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).bottom;
        final overflow = (maxHeight - viewport).clamp(0.0, span - 1);
        final offset = scroll.clamp(0.0, overflow);
        final foregroundCollapse = ((scroll - overflow) / (span - overflow))
            .clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // 白底铺满，头图下方即为白色资料区。
            const Positioned.fill(
              child: ColoredBox(color: AppTheme.surfaceCard),
            ),
            // 顶部短头图：折叠时渐进虚化。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bannerBottom,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _maxBlurSigma * collapse,
                  sigmaY: _maxBlurSigma * collapse,
                  tileMode: TileMode.decal,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 品牌色平铺兜底：无背景图或加载失败时透出。
                    const ColoredBox(color: AppTheme.primaryDark),
                    if (banner != null) Positioned.fill(child: banner!),
                    // 压暗层保证返回/菜单/标题白字在头图上可读。
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x22000000), Color(0x38000000)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 完全折叠态必须明确绘制真实背景，不能把“Material 透明”等同于“显示背景”。
            // 独立固定层只覆盖状态栏安全区和工具栏，分类栏仍由外层保持白底。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: toolbarExtent,
              child: Opacity(
                key: const ValueKey('profile-collapsed-background-opacity'),
                opacity: collapse,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppTheme.primaryDark),
                    if (collapsedBanner != null)
                      Positioned.fill(child: collapsedBanner!),
                  ],
                ),
              ),
            ),
            // 折叠满时浮现的居中标题。
            Positioned(
              top: topPadding,
              left: AppLayout.scaled(context, 56),
              right: AppLayout.scaled(context, 56),
              height: kToolbarHeight,
              child: Opacity(
                opacity: collapse,
                child: Center(
                  child: Text(
                    collapsedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppLayout.scaled(context, 16),
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 资料区：超屏时先随原页面上移，读完后淡出；头像仍跨压头图下缘。
            Positioned(
              top: bannerBottom - offset,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 1 - foregroundCollapse,
                child: IgnorePointer(
                  ignoring: foregroundCollapse > 0.5,
                  child: foreground,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 按帖子语义展示竞选、文章、视频和公文互斥分类。

/// 用户主页四类互斥内容：竞选优先，普通文章归文章，普通视频归视频，
/// 其余普通公文（纯文字或图片）归公文。底层使用
/// posts 数据语义，避免展示文案调整污染 API 与存储契约。
enum ProfileTab {
  posts('公文'),
  campaign('竞选'),
  videos('视频'),
  articles('文章');

  const ProfileTab(this.label);

  final String label;
}

/// 折叠头下方固定的分类标签栏（挂在 SliverAppBar.bottom，折叠后固定）。
///
/// 屏幕边缘到首尾文字、相邻分类文字之间共五段视觉空隙必须相等。间距按当前
/// 可用宽度、平台字体和系统文字倍率动态计算，不能依赖等宽 Tab 或固定像素。
class ProfileCategoryTabs extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfileCategoryTabs({
    super.key,
    this.controller,
    this.posts = 0,
    this.campaigns = 0,
    this.videos = 0,
    this.articles = 0,
  });

  final TabController? controller;
  final int posts;
  final int campaigns;
  final int videos;
  final int articles;

  /// 分类栏保持紧凑，避免 Tab 默认高度在统计文字下方制造假空白。
  static const double height = 36;

  /// 增高后的分类栏上下留白保持均衡，不恢复 Material 默认的过高 Tab。
  static const double labelTopPadding = 8;

  static final TextStyle _labelStyle = TextStyle(
    fontSize: AppLayout.scaledValue(16),
    fontWeight: FontWeight.w700,
  );

  /// 数量作为分类名称的次级信息，字号和字重必须明显更轻，不与分类名称争夺层级。
  static final TextStyle _countStyle = TextStyle(
    color: AppTheme.textTertiary,
    fontSize: AppLayout.scaledValue(11),
    fontWeight: FontWeight.w400,
  );

  /// Flutter 可滚动 TabBar 对混合字号 TextSpan 的实际取整宽度比 TextPainter 汇总值
  /// 多 2.2px；计算间距时先扣除，避免仅最右侧空隙比其余四段更窄。
  static const double _trailingLayoutBoundary = 2.2;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  int _countOf(ProfileTab tab) => switch (tab) {
        ProfileTab.posts => posts,
        ProfileTab.campaign => campaigns,
        ProfileTab.videos => videos,
        ProfileTab.articles => articles,
      };

  TextSpan _labelSpan(ProfileTab tab) => TextSpan(
        children: [
          TextSpan(text: tab.label, style: _labelStyle),
          TextSpan(text: '{${_countOf(tab)}}', style: _countStyle),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textDirection = Directionality.of(context);
          final textScaler = MediaQuery.textScalerOf(context);
          final labelsWidth = ProfileTab.values.fold<double>(0, (sum, tab) {
            final painter = TextPainter(
              text: _labelSpan(tab),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            )..layout();
            return sum + painter.width;
          });
          // 四项复合文字形成左外侧、三段内部、右外侧共五段空隙。TabBar 的外部
          // padding 与每个标签的单侧 padding 各取空隙的一半，组合后恰好相等。
          final visualGap =
              ((constraints.maxWidth - labelsWidth - _trailingLayoutBoundary) /
                      (ProfileTab.values.length + 1))
                  .clamp(0.0, double.infinity)
                  .toDouble();
          final halfGap = visualGap / 2;
          final gapInsets = EdgeInsetsDirectional.symmetric(
            horizontal: halfGap,
          );
          return TabBar(
            controller: controller,
            isScrollable: true,
            // 显式使用 start，禁止 Material 3 默认 startOffset 再注入 52px。
            tabAlignment: TabAlignment.start,
            padding: gapInsets,
            labelPadding: gapInsets,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textPrimary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppTheme.divider,
            labelStyle: _labelStyle,
            unselectedLabelStyle: _labelStyle,
            tabs: [
              for (final tab in ProfileTab.values)
                Tab(
                  height: height,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: labelTopPadding),
                      child: Text.rich(
                        _labelSpan(tab),
                        key: ValueKey<String>('profile-tab-${tab.name}'),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// 呈现关注、私信及发帖通知开关，协调当前关系动作。

/// 头像行右上角对主页主人的操作；本人仅显示通用关注/取关入口。
///
/// 通知 = 关注后收其发帖通知（红点+声音）、聊天 = 给该用户发消息、关注 = 关注/取关该用户。
/// 通知归属挂在关注关系上：关注即默认开通知，铃铛按用户静音/取消静音；未关注时点铃铛提示先关注。
/// 本人不显示通知、私信和订阅入口；编辑资料仍在右上 ⋮ 菜单。
class ProfileActionIcons extends StatelessWidget {
  const ProfileActionIcons({
    super.key,
    required this.isSelf,
    required this.isFollowing,
    this.isNotifying = false,
    this.enabled = true,
    this.leading,
    this.onNotify,
    this.onChat,
    this.onToggleFollow,
  });

  final bool isSelf;
  final bool isFollowing;

  /// 是否已开启该用户的发帖通知（= 已关注且未静音）；铃铛据此高亮/实心。
  final bool isNotifying;

  /// false=操作暂不可用；本人关系由isSelf控制，不禁止自关注。
  final bool enabled;

  /// 可选的创作者订阅入口；有有效创作者计划才构建，固定在通知图标左侧。
  /// 入口只占本操作行的横向空间，不得改变主页资料区高度。
  final Widget? leading;

  /// 通知：开/关该用户发帖通知（须已关注）。
  final VoidCallback? onNotify;

  /// 聊天：给该用户发消息。
  final VoidCallback? onChat;

  /// 关注：关注/取关该用户。
  final VoidCallback? onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (!isSelf)
        _CircleIcon(
          icon: isNotifying
              ? Icons.notifications_active
              : Icons.notifications_outlined,
          tooltip: isNotifying ? '已开启通知' : '通知',
          active: enabled && isNotifying,
          onTap: enabled ? onNotify : null,
        ),
      if (!isSelf)
        _CircleIcon(
          icon: Icons.chat_bubble_outline,
          tooltip: '发消息',
          onTap: enabled ? onChat : null,
        ),
      _CircleIcon(
        icon: isFollowing ? Icons.how_to_reg : Icons.person_add_alt,
        tooltip: isFollowing ? '已关注' : '关注',
        active: enabled && isFollowing,
        onTap: enabled ? onToggleFollow : null,
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isSelf) ?leading,
        for (final button in buttons)
          Padding(
            padding: EdgeInsets.only(left: AppLayout.scaled(context, 8)),
            child: button,
          ),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// 激活态（如已关注）用品牌色描边与图标高亮。
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // onTap==null 视为禁用：图标与描边转灰，不可点。
    final disabled = onTap == null;
    final color = disabled
        ? AppTheme.textTertiary
        : (active ? AppTheme.primary : AppTheme.textSecondary);
    return Material(
      color: AppTheme.surfaceCard,
      shape: CircleBorder(
        side: BorderSide(
          color: disabled
              ? AppTheme.border
              : (active ? AppTheme.primary : AppTheme.border),
          width: active ? 1 : 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppLayout.scaled(context, 7)),
          child: Icon(
            icon,
            color: color,
            size: AppLayout.scaled(context, 20),
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

// 展示用户码及按本人权限提供的资料编辑和注销菜单。

enum ProfileMenuAction { userCode, editProfile, deleteAccount }

/// 右上角竖三点菜单：用户码常驻；编辑资料和注销用户仅本人。
class ProfileKebabMenu extends StatelessWidget {
  const ProfileKebabMenu({
    super.key,
    required this.isSelf,
    this.onUserCode,
    this.onEditProfile,
    this.onDeleteAccount,
  });

  final bool isSelf;
  final VoidCallback? onUserCode;
  final VoidCallback? onEditProfile;

  /// 注销用户（仅本人，破坏性）：硬删除该用户在 Cloudflare 的全部数据。
  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProfileMenuAction>(
      // 背景图明暗不定：三点图标套一枚半透明深色圆形底衬，保证白色图标始终可读。
      padding: EdgeInsets.zero,
      icon: CircleAvatar(
        radius: AppLayout.scaled(context, 18),
        backgroundColor: Colors.black.withValues(alpha: 0.32),
        child: Icon(
          Icons.more_vert,
          size: AppLayout.scaled(context, 22),
          color: Colors.white,
        ),
      ),
      onSelected: (action) {
        switch (action) {
          case ProfileMenuAction.userCode:
            onUserCode?.call();
            break;
          case ProfileMenuAction.editProfile:
            onEditProfile?.call();
            break;
          case ProfileMenuAction.deleteAccount:
            onDeleteAccount?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: onUserCode != null,
          value: ProfileMenuAction.userCode,
          child: _MenuRow(icon: Icons.qr_code_2, label: '用户码'),
        ),
        if (isSelf)
          PopupMenuItem(
            enabled: onEditProfile != null,
            value: ProfileMenuAction.editProfile,
            child: _MenuRow(icon: Icons.edit_outlined, label: '编辑资料'),
          ),
        // 注销放末位（破坏性），仅本人可见，红色区分。
        if (isSelf)
          PopupMenuItem(
            enabled: onDeleteAccount != null,
            value: ProfileMenuAction.deleteAccount,
            child: _MenuRow(
              icon: Icons.no_accounts,
              label: '注销用户',
              color: AppTheme.danger,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;

  /// 行主色；破坏性项传 [AppTheme.danger]，其余用默认次要色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? AppTheme.textSecondary;
    return Row(
      children: [
        Icon(icon, size: AppLayout.scaled(context, 20), color: rowColor),
        SizedBox(width: AppLayout.scaled(context, 12)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

// 统一显示受保护头像、默认图形和身份徽章。

/// 用户公开资料统一头像。用户主页与通讯录共用同一套圆角、默认头像和身份徽章，
/// 避免不同入口把同一个用户展示成两套视觉身份。
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.imagePath,
    this.imageUrl,

    this.imageProvider,
    this.userImageSet,
    this.cidLevel,
    this.memberLevel,
    this.membergateActive = false,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius,
    this.showBadge = true,
    this.badgeOverflow = 2,
  });

  final String seed;
  final double size;
  final String? imagePath;
  final String? imageUrl;

  /// 资料和名片图片统一使用当前会话的受保护读取器。
  final ImageProvider? imageProvider;

  /// null 时按 imagePath/imageUrl/imageProvider 推导。明确为 true 表示用户已经设置图片；即使本机
  /// 缓存和网络暂不可用，也只能显示中性占位，不能冒充“从未设置”回退内置随机图。
  final bool? userImageSet;
  final String? cidLevel;
  final String? memberLevel;
  final bool membergateActive;
  final Color? borderColor;
  final double borderWidth;
  final double? borderRadius;
  final bool showBadge;

  /// 徽章向头像右下角外溢的逻辑像素。默认值保持各公共列表现状；需要抵消头像边框或
  /// 特殊头部视觉边界时，由调用入口明确覆盖，徽章样式和身份判断仍只有一套实现。
  final double badgeOverflow;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  ChainDataService? _source;
  VoidCallback? _release;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = context.read<ChainDataService?>();
    if (!identical(source, _source)) {
      _source?.removeListener(_changed);
      _release?.call();
      _source = source;
      _source?.addListener(_changed);
      _bind();
    }
  }

  @override
  void didUpdateWidget(ProfileAvatar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed || old.showBadge != widget.showBadge) _bind();
  }

  void _bind() {
    _release?.call();
    _release = null;
    final yearText = widget.seed.split('-').last;
    final year = int.tryParse(yearText);
    if (widget.showBadge &&
        RegExp(
          r'^[A-Z0-9]+-[A-Z0-9]+-[0-9]{9}-[0-9]{4,10}$',
        ).hasMatch(widget.seed) &&
        // CID 年份采用 u32 的规范十进制，旧四位年份保持不变。
        year != null && year <= 0xffffffff &&
        year.toString().padLeft(4, '0') == yearText) {
      _release = _source?.watchCitizen(widget.seed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _release?.call();
    _source?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _source?.snapshot;
    final radius = widget.borderRadius ?? widget.size * 0.22;
    final cidLevel = _source == null
        ? widget.cidLevel
        : snapshot?.identityLevel(widget.seed);
    final memberLevel = _source == null
        ? widget.memberLevel
        : snapshot?.memberLevel(widget.seed);
    final membergateActive = _source == null
        ? widget.membergateActive
        : snapshot?.memberActive(widget.seed) == true;
    final badge = cidLevel == null && !membergateActive
        ? null
        : identityBadgeStyle(
            cidLevel: cidLevel,
            memberLevel: memberLevel,
            membergateActive: membergateActive,
          );
    final path = widget.imagePath?.trim();
    final file = path == null || path.isEmpty ? null : File(path);
    final validFile = file?.existsSync() == true;
    final url = widget.imageUrl?.trim();
    final hasUserImage =
        widget.userImageSet ??
        validFile ||
            widget.imageProvider != null ||
            (url != null && url.isNotEmpty);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius + widget.borderWidth),
            border: widget.borderWidth <= 0
                ? null
                : Border.all(
                    color: widget.borderColor ?? AppTheme.surfaceCard,
                    width: widget.borderWidth,
                  ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: validFile
                ? Image.file(
                    file!,
                    fit: BoxFit.cover,
                    width: widget.size,
                    height: widget.size,
                  )
                : widget.imageProvider != null ||
                      (url != null && url.isNotEmpty)
                ? widget.imageProvider == null
                      ? CitizenRemoteImage(
                          url: url!,
                          role: Uri.parse(url).path.contains('/cards/')
                              ? 'card'
                              : 'avatar',
                          width: widget.size,
                          height: widget.size,
                        )
                      : Image(
                          image: widget.imageProvider!,
                          fit: BoxFit.cover,
                          width: widget.size,
                          height: widget.size,
                          frameBuilder: (context, child, frame, syncLoaded) =>
                              syncLoaded || frame != null
                              ? child
                              : const _UserImagePlaceholder(),
                          errorBuilder: (_, _, _) =>
                              const _UserImagePlaceholder(),
                        )
                : hasUserImage
                ? const _UserImagePlaceholder()
                : _StableDefaultAvatar(seed: widget.seed, size: widget.size),
          ),
        ),
        if (widget.showBadge && badge != null)
          Positioned(
            right: -widget.badgeOverflow,
            bottom: -widget.badgeOverflow,
            child: IdentityBadge(
              style: badge,
              size: (widget.size * 0.34).clamp(18, 28),
              tooltip: identityBadgeLabel(
                cidLevel: cidLevel,
                memberLevel: memberLevel,
                checked: badge.checked,
              ),
            ),
          ),
      ],
    );
  }
}

class _UserImagePlaceholder extends StatelessWidget {
  const _UserImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppTheme.surfaceMuted);
  }
}

class _StableDefaultAvatar extends StatelessWidget {
  const _StableDefaultAvatar({required this.seed, required this.size});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ProfilePresentation.forIdentityKey(seed).avatarAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

// 统一展示含永久CID及当前账户的固定用户码。

/// 用户码展示页(`QR_V1 k=3 user_contact`,固定码)。
///
/// 用户码表达「人」——永久 CID 与其当前绑定账户(码内不含昵称)。本人可从
/// “我的”背景图或用户主页进入，他人从其用户主页进入；所有入口复用本页。
/// 只有链上 CID↔AccountId 闭环命中的身份账户才能出这张码。账户维度的展示走账户码
/// (`lib/wallet/wallet_qr_dialog.dart`),一笔收款请求走收款码;三者按入口分类,
/// 本页不做任何「该出哪种码」的运行时判断。
///
/// 用户码是唯一能写入通讯录的码:通讯录关系必须锚永久 CID,不能锚会换绑的账户。
class UserQrPage extends StatelessWidget {
  const UserQrPage({
    super.key,
    required this.cidNumber,
    required this.displayName,
    required this.accountId,
    required this.qrData,
    this.isSelf = false,
  });

  /// SDK已编码的用户码；页面只展示，不解析或构造QR_V1。
  final String qrData;

  /// 永久公民身份号,身份主键。
  final String cidNumber;

  /// 公开昵称,只作展示。
  final String displayName;

  /// CID 当前绑定的钱包账户(0x + 64hex)。
  final String accountId;

  /// 本人用户码显式标记“我的”；他人页面不得冒充本人。
  final bool isSelf;

  /// 展示态 SS58 地址(account_id 为授权真源,ss58 仅用于展示与二维码载荷)。
  String get _ss58Address => citizenSs58FromAccountId(accountId);

  @override
  Widget build(BuildContext context) {
    return QrDisplayScaffold(
      title: isSelf ? '我的用户码' : '用户码',
      headline: displayName,
      qrData: qrData,
      accountAddress: _ss58Address,
      footerText: '扫描此二维码可加为联系人，或向其转账',
    );
  }
}
