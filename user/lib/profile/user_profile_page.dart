import 'package:citizen_chain/citizen_chain.dart';
import 'dart:async';
import 'dart:io';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:citizen_square/post/square_models.dart';
import 'package:citizen_square/article/square_article_detail_page.dart';
import 'package:citizen_square/post/square_post_detail_page.dart';
import 'package:citizen_user/profile/follows_list_page.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_user/profile/profile_edit_page.dart';
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/user_qr_page.dart';
import 'package:citizen_user/profile/collapsible_header.dart';
import 'package:citizen_user/creator/creator_subscribe_button.dart';
import 'package:citizen_user/profile/profile_action_icons.dart';
import 'package:citizen_user/profile/profile_category_tabs.dart';
import 'package:citizen_user/profile/profile_header_card.dart';
import 'package:citizen_user/profile/profile_kebab_menu.dart';
import 'package:citizen_user/profile/profile_posts_list.dart';
import 'package:citizen_user/profile/square_account_deletion_service.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/identity_register_guide.dart';
import 'package:citizen_square/post/square_post_sync_service.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/identity_binding.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/membership/membership_revision.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_scanner/qr_sign_session_page.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_network/hex_codec.dart' show bytesToHex;

/// 推特式用户主页。
///
/// 折叠虚化头部 + 圆角方形头像/背景 + 认证勾 + 展示名/地址/签名/计数 +
/// 主页操作+ ⋮（用户码/编辑资料）+
/// 公文/竞选/视频/文章四个互斥 Tab（“公文”底层仍为 posts）。身份主键 = CID 号
/// （cid_number）；本人和他人资料先读本地，进入后台校准遵守十分钟限速。
/// 关注复用登录 session 静默签名；资料远端存储不上链。链上订阅/
/// 用户码与注销只消费本机已验证的当前公民号绑定。
class UserProfilePage extends StatefulWidget {
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
    this.currentUserContext,
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

  final CurrentUserContext? currentUserContext;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  /// 顶部头图高度（不含状态栏）。
  static const double _bannerHeight = 128;

  late final CitizenProfileApi _api;
  late final CitizenProfileCache _cache;
  late final CitizenProfileMediaCache _mediaCache;
  late final SquareSessionProvider _sessionProvider;
  SubscriptionService? _subscriptionService;
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

  /// 「他人视角」下识别本人；本人只开放通用关注操作。
  bool _relationsReady = false;
  CurrentUserContext? _currentUser;
  bool _accessAllowed = false;
  bool _verifiedSelf = false;
  bool get _isSelf => widget.isSelf || _verifiedSelf;
  String? _viewerCid;
  int _accessGeneration = 0;
  AccountSecurityService? _profileSecurity;
  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? CitizenProfileApi();
    _cache = widget.cache ?? const CitizenProfileCache();
    _mediaCache = widget.mediaCache ?? CitizenProfileMediaCache();
    _membershipDecision = widget.initialMembershipDecision;
    _membershipState = widget.initialMembershipState;
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

  void _invalidatePageAccess() {
    _accessGeneration++;
    _profileLoadGeneration++;
    if (!mounted) return;
    setState(() {
      _accessAllowed = false;
      _relationsReady = false;
      _verifiedSelf = false;
      _session = null;
      _sessionFuture = null;
      _sessionResolved = false;
    });
    unawaited(_resolvePageAccess());
  }

  Future<void> _resolvePageAccess({bool refreshOnEntry = true}) async {
    final generation = ++_accessGeneration;
    final revision = _profileSecurity?.revision.value;
    bool current() =>
        mounted &&
        generation == _accessGeneration &&
        revision == _profileSecurity?.revision.value;
    try {
      final local = await _currentUser?.resolve();
      final citizen =
          local?.cidNumber ?? await _sessionProvider.currentCitizenId();
      if (!current()) return;
      if (citizen == null || citizen.isEmpty) throw StateError('当前公民身份尚未就绪');
      _viewerCid = citizen;
      setState(() {
        _verifiedSelf = citizen == widget.cidNumber;
        _accessAllowed = true;
      });
      if (!refreshOnEntry) return;
      var binding = local?.binding;
      if (binding == null) {
        // 独立页面/注入依赖仍可使用既有会话边界；正式App优先本地绑定并先检查限速。
        final session = await _ensureSession();
        if (!current() || session == null || session.cidNumber != citizen)
          throw StateError('当前公民会话不可用');
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
      final result = await _api.refreshOnEntry(
        widget.cidNumber,
        binding: owner,
        sessions: _sessionProvider,
        cache: _cache,
        mediaCache: _mediaCache,
        isCurrentIdentity: () => revision == security?.revision.value,
      );
      if (!current()) return;
      if (result != null) {
        ++_profileLoadGeneration;
        setState(() {
          _session = result.session;
          _sessionStatus = SquareSessionStatus.ready;
          _sessionResolved = true;
          _profile = result.profile.profile;
          _relationsReady = true;
        });
        await _loadProfileMedia(result.profile.profile);
      } else {
        setState(() => _sessionResolved = true);
      }
    } on Object catch (error, stackTrace) {
      if (!current()) return;
      AppLog.profileLoadFailure(
        stage: 'background',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _sessionResolved = true;
        _relationsReady = false;
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
    _accessGeneration++;
    _profileSecurity?.revision.removeListener(_invalidatePageAccess);
    _profileLoadGeneration++;
    MembershipRevision.instance.listenable.removeListener(_onMembershipChanged);
    CitizenProfileCache.revision.removeListener(_onProfileChanged);
    super.dispose();
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
      } on Exception {
        // 写入已经成功，资料回读失败不能反向撤销用户的关注/取关。
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
        content: const Text('注销将立即硬删除你在公民广场的全部数据，无冷静期、不可恢复，链上数据不受注销影响。'),
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

      await SquareAccountDeletionService().deleteAccount(
        binding: binding,
        requireCurrent: requireDeletionBinding,
        // 账户注销签名统一交给 CitizenSDK，冷热模式不在页面分支。
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

  /// 他人主页的创作者订阅入口：SquarePost 以公民 CID 为创作者唯一主键。
  /// 本人主页不显示；CID 不因换绑改变，因此换绑不会重建或丢失订阅态。
  Widget? _creatorSubscribeButton() {
    if (_isSelf || !_accessAllowed || !_relationsReady || _session == null)
      return null;
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
    final session = _session;
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
          isSelf: _verifiedSelf,
          refreshFailed: _contentRefreshFailed,
          onOpenPost: _openArticle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          onUserCode: _accessAllowed ? _openUserCode : null,
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
