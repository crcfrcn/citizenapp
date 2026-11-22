// 展示我的资料和设置，管理隐私、黑名单、首页偏好及账户相关导航。

import 'package:citizen_system/identity_cid_display.dart';
import 'package:citizen_chain/citizen_chain.dart';
import 'package:provider/provider.dart';

import 'package:citizen_sdk/citizen_sdk.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:citizen_system/app_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:citizen_user/profile/citizen_profile.dart';
import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_user/profile/citizen_profile_api.dart';
import 'package:citizen_user/profile/citizen_profile_cache.dart';
import 'package:citizen_user/identity/square_session_provider.dart';
import 'package:citizen_user/profile/user_qr_page.dart';
import 'package:citizen_user/profile/user_profile_page.dart';
import 'package:citizen_user/profile/profile_avatar.dart';
import 'package:citizen_user/square_api_client.dart';
import 'package:citizen_user/identity/current_user_context.dart';
import 'package:citizen_user/identity/finalized_identity_resolver.dart';
import 'package:citizen_user/identity/identity_badge_snapshot_store.dart';
import 'package:citizen_user/creator/creator_page.dart';
import 'package:citizen_user/creator/creator_service.dart';
import 'package:citizen_user/membership/membership_page.dart';
import 'package:citizen_user/membership/subscription_service.dart';
import 'package:citizen_user/identity/myid_page.dart';
import 'package:citizen_storage/user_isar.dart';
import 'package:citizenapp/security/app_lock_service.dart';
import 'package:citizenapp/security/pin_input_page.dart';
import 'package:citizen_system/security/system_protected_storage.dart';
import 'package:citizen_user/identity/account_security_service.dart';
import 'package:citizen_user/contacts/contact_book_page.dart';
import 'package:citizen_system/theme/app_layout.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/security/biometric_auth_text.dart';
import 'package:citizen_system/update/app_update.dart';
import 'package:citizen_system/update/update_badge.dart';
import 'package:citizen_wallet/account/wallet_page.dart';

class MyTab extends StatefulWidget {
  const MyTab({
    super.key,
    this.showSettingsUpdateDot = false,
    this.wallet,
    this.walletStateReader,
    this.badgeSnapshotStore,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
    this.squareApi,
    this.subscriptionService,
    this.creatorService,
    this.currentUserContext,
  });

  final bool showSettingsUpdateDot;
  final CitizenSdk? wallet;
  final CitizenSdkOperation<CitizenWalletState> Function()? walletStateReader;
  final IdentityBadgeSnapshotStore? badgeSnapshotStore;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;
  final SquareApiClient? squareApi;
  final SubscriptionService? subscriptionService;
  final CreatorService? creatorService;
  final CurrentUserContext? currentUserContext;

  @override
  State<MyTab> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<MyTab> {
  late final CitizenSdk _wallet;
  late final IdentityBadgeSnapshotStore _badgeSnapshotStore;
  late final CitizenProfileApi _profileApi;
  late final CitizenProfileCache _profileCache;
  late final CitizenProfileMediaCache _profileMediaCache;
  late final SquareSessionProvider _sessionProvider;

  CitizenWalletStateAccount? _defaultWallet;
  String? _defaultWalletIdentityLevel;
  CitizenProfile? _publicProfile;
  CitizenProfileMediaSnapshot _publicProfileMedia =
      const CitizenProfileMediaSnapshot();

  /// 云端业务资源预检与交易确认。
  late final SubscriptionService _subscriptionService;
  late final CurrentUserContext _currentUserContext;
  AccountSecurityService? _accountSecurity;
  bool _dependenciesReady = false;

  /// _loadState 世代号：本地钱包、资料和徽章快照并发重载时，旧结果
  /// 不得覆盖新默认钱包。
  int _loadGeneration = 0;

  /// 身份账户 ID 来自当前默认账户的本机绑定；普通“我的”页面不读取链。
  String _identityAccountId = '';

  /// 当前身份永久 CID；徽章、公开资料和业务数据都以它作为归属主键。
  String _identityCidNumber = '';

  /// 用户身份账户 ID（展示口径）= 当前身份账户（CID 绑定账户，非恒账户0）。
  String get _communicationAccountId => _identityAccountId;

  /// 公开昵称唯一真源是 CID 资料的 display_name；资料尚未缓存时稳定兜底。
  /// 本机 walletName 只用于钱包列表，绝不进入此展示链路。
  String get _nickname => ProfilePresentation.forIdentityKey(
    _publicProfile?.cidNumber ?? _communicationAccountId,
  ).resolveDisplayName(publicName: _publicProfile?.displayName);

  String get _identityLabel => switch (_defaultWalletIdentityLevel) {
    'candidate' => '竞选身份',
    'voting' => '投票身份',
    _ => '匿名访客',
  };

  @override
  void initState() {
    super.initState();
    _badgeSnapshotStore =
        widget.badgeSnapshotStore ?? IdentityBadgeSnapshotStore();
    _profileApi = widget.profileApi ?? CitizenProfileApi();
    _profileCache = widget.profileCache ?? const CitizenProfileCache();
    _profileMediaCache = widget.profileMediaCache ?? CitizenProfileMediaCache();
    CitizenProfileCache.revision.addListener(_onPublicProfileChanged);
    IdentityBadgeSnapshotStore.revision.addListener(_onIdentitySnapshotChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    final injectedWallet = widget.wallet;
    final injectedSession = widget.sessionProvider;
    final injectedSubscription = widget.subscriptionService;
    final injectedCurrentUser = widget.currentUserContext;
    if ((injectedWallet != null || widget.walletStateReader != null) &&
        injectedSession != null &&
        injectedSubscription != null &&
        injectedCurrentUser != null) {
      _wallet = injectedWallet ?? context.read<CitizenSdk>();
      _sessionProvider = injectedSession;
      _subscriptionService = injectedSubscription;
      _currentUserContext = injectedCurrentUser;
      _dependenciesReady = true;
      _loadState();
      return;
    }
    final sdk = context.read<CitizenSdk>();
    final accountSecurity = context.read<AccountSecurityService>();
    _wallet = widget.wallet ?? sdk;
    _currentUserContext =
        widget.currentUserContext ?? context.read<CurrentUserContext>();
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider>();
    _subscriptionService =
        widget.subscriptionService ??
        SubscriptionService(
          chainData: context.read<ChainDataService?>(),
          wallet: _wallet,
          chain: sdk,
          transactions: sdk,
          identityResolver: context.read<FinalizedIdentityResolver>(),
          api: widget.squareApi ?? SquareApiClient(),
        );
    // 本页常驻 IndexedStack；SDK 账户目录或 finalized CID 绑定变化后重读身份。
    _accountSecurity = accountSecurity;
    accountSecurity.revision.addListener(_onWalletsChanged);
    _dependenciesReady = true;
    _loadState();
  }

  @override
  void dispose() {
    _accountSecurity?.revision.removeListener(_onWalletsChanged);
    CitizenProfileCache.revision.removeListener(_onPublicProfileChanged);
    IdentityBadgeSnapshotStore.revision.removeListener(
      _onIdentitySnapshotChanged,
    );
    super.dispose();
  }

  /// 编辑资料成功后缓存会先于路由返回提交。MyTab 常驻 IndexedStack，按 CID 定向
  /// 重读即可原地更新头像、背景和昵称，不等待页面重建或再次请求 Worker。
  void _onPublicProfileChanged() {
    final event = CitizenProfileCache.revision.value;
    if (!mounted || event == null || event.cidNumber != _identityCidNumber) {
      return;
    }
    unawaited(_reloadCachedPublicProfile(event.cidNumber, _loadGeneration));
  }

  Future<void> _onWalletsChanged() async {
    // revision 同时覆盖钱包列表与 finalized CID 绑定。注册前后默认账户可能完全相同，
    // 不能只比钱包 account_id；必须重读并比较 cid_number + 身份账户。
    final wallet =
        (await (widget.walletStateReader?.call() ?? _wallet.getWalletState())
                .result)
            .defaultAccount;
    final identity = await _currentUserContext.resolve();
    if (!mounted) return;
    final identityAccountId = identity?.accountId ?? wallet?.accountId ?? '';
    final identityCidNumber = identity?.cidNumber ?? '';
    if (wallet?.accountId == _defaultWallet?.accountId &&
        identityAccountId == _identityAccountId &&
        identityCidNumber == _identityCidNumber) {
      return;
    }
    await _loadState();
  }

  void _onIdentitySnapshotChanged() {
    if (_dependenciesReady) _loadState(refreshRemote: false);
  }

  Future<void> _loadState({bool refreshRemote = false}) async {
    final generation = ++_loadGeneration;
    final defaultWallet =
        (await (widget.walletStateReader?.call() ?? _wallet.getWalletState())
                .result)
            .defaultAccount;
    // CID 是快照归属主键；当前绑定账户只负责链读和签名。
    final identity = await _currentUserContext.resolve();
    final identityAccountId =
        identity?.accountId ?? defaultWallet?.accountId ?? '';
    final saved = identityAccountId.isEmpty
        ? null
        : await _badgeSnapshotStore.readForAccountId(identityAccountId);
    final identityCidNumber = saved?.verified == true
        ? saved!.identity?.cidNumber ?? ''
        : identity?.cidNumber ?? '';
    String? cidLevel;
    try {
      final snapshot = identityCidNumber.isEmpty
          ? null
          : await _badgeSnapshotStore.read(identityCidNumber);
      cidLevel = switch (snapshot?.cidLevel) {
        'voting' || 'candidate' => snapshot!.cidLevel,
        _ => null,
      };
    } catch (e) {
      AppLog.d('profile badge snapshot load failed: $e');
    }
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    final identityChanged =
        identityAccountId != _identityAccountId ||
        identityCidNumber != _identityCidNumber;
    setState(() {
      _defaultWallet = defaultWallet;
      _identityAccountId = identityAccountId;
      _identityCidNumber = identityCidNumber;
      _defaultWalletIdentityLevel = cidLevel;
      if (identityChanged) {
        _publicProfile = null;
        _publicProfileMedia = const CitizenProfileMediaSnapshot();
      }
    });
    // 昵称、头像和背景继续从本机业务资料缓存读取。
    if (refreshRemote) {
      await _refreshRemoteState(generation);
    } else if (identityCidNumber.isNotEmpty) {
      unawaited(_reloadCachedPublicProfile(identityCidNumber, generation));
    }
  }

  Future<void> _refreshRemoteState(int generation) async {
    final SquareSession? session;
    try {
      session = await _sessionProvider.ensureSession();
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('刷新失败，已保留本地资料')));
      }
      return;
    }
    if (session == null ||
        session.cidNumber.trim() != _identityCidNumber ||
        generation != _loadGeneration) {
      return;
    }

    try {
      await _loadPublicProfile(session, generation);
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('刷新失败，已保留本地资料')));
      }
      return;
    }
  }

  /// 仅用户下拉刷新时读取远端；统一接收结果保留较新的本机资料并如实提示保存状态。
  Future<void> _loadPublicProfile(SquareSession session, int generation) async {
    final result = await _profileApi.refreshProfile(
      session.cidNumber,
      session: session,
      userInitiated: true,
      cache: _profileCache,
      mediaCache: _profileMediaCache,
      isCurrent: () =>
          mounted &&
          generation == _loadGeneration &&
          session.cidNumber == _identityCidNumber,
    );
    if (!mounted ||
        generation != _loadGeneration ||
        session.cidNumber != _identityCidNumber)
      return;
    setState(() => _publicProfile = result.profile);
    await _loadPublicProfileMedia(result.profile, generation: generation);
    if (mounted && generation == _loadGeneration && result.hasWarning) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.refreshMessage!)));
    }
  }

  Future<void> _reloadCachedPublicProfile(
    String cidNumber,
    int generation,
  ) async {
    final CitizenProfile? profile;
    try {
      profile = await _profileCache.read(cidNumber);
    } catch (_) {
      // 本地读取失败保留当前显示，不能以隐式联网掩盖数据库错误。
      return;
    }
    if (profile == null ||
        profile.cidNumber != cidNumber ||
        !mounted ||
        generation != _loadGeneration ||
        cidNumber != _identityCidNumber) {
      return;
    }
    setState(() => _publicProfile = profile);
    await _loadPublicProfileMedia(profile, generation: generation);
  }

  Future<void> _loadPublicProfileMedia(
    CitizenProfile profile, {
    required int generation,
  }) async {
    try {
      final local = await _profileMediaCache.read(profile);
      if (mounted &&
          generation == _loadGeneration &&
          _publicProfile?.cidNumber == profile.cidNumber &&
          _publicProfile?.profileAt == profile.profileAt) {
        setState(() => _publicProfileMedia = local);
      }
    } catch (_) {
      /* 读取失败保留既有显示，不发起下载。 */
    }
  }

  Future<void> _openContacts() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ContactBookPage()));
    await _loadState();
  }

  /// 展示入口只读取当前账户的本地身份；此结果不用于写操作授权。
  /// 与页头一致，优先采用该账户已验真的持久快照，再读取本地绑定。
  Future<({String accountId, String cidNumber})?>
  _resolveOwnedIdentity() async {
    final address = _communicationAccountId;
    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在「我的 → 我的钱包」添加钱包账户')));
      return null;
    }
    try {
      final identity = await _currentUserContext.resolve();
      if (identity == null) return null;
      final saved = await _badgeSnapshotStore.readForAccountId(
        identity.accountId,
      );
      if (!mounted || identity.accountId != _communicationAccountId) {
        return null;
      }
      final cidNumber =
          (saved?.verified == true
                  ? saved?.identity?.cidNumber ?? ''
                  : identity.cidNumber)
              .trim();
      if (cidNumber.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地尚未保存身份CID号，请主动刷新身份')));
        return null;
      }
      return (accountId: identity.accountId, cidNumber: cidNumber);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地用户资料读取失败，请重试')));
      return null;
    }
  }

  Future<void> _openMyProfile() async {
    final identity = await _resolveOwnedIdentity();
    if (!mounted || identity == null) return;
    final cid = identity.cidNumber;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          cidNumber: cid,
          isSelf: true,
          currentUserContext: _currentUserContext,
          initialProfile: _publicProfile?.cidNumber == cid
              ? _publicProfile
              : null,
          initialProfileMedia: _publicProfile?.cidNumber == cid
              ? _publicProfileMedia
              : null,
          api: _profileApi,
          sessionProvider: _sessionProvider,
          cache: _profileCache,
          mediaCache: _profileMediaCache,
          subscriptionService: _subscriptionService,
        ),
      ),
    );
    if (mounted) await _loadState();
  }

  Future<void> _openMyUserCode() async {
    final identity = await _resolveOwnedIdentity();
    if (!mounted || identity == null) return;
    final document = await context.read<CitizenSdk>().encodeDocument(
      CitizenQrContent.userContact(
        cidNumber: identity.cidNumber.trim(),
        accountId: identity.accountId,
      ),
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UserQrPage(
          qrData: document.canonicalText,
          cidNumber: identity.cidNumber.trim(),
          displayName: _nickname,
          accountId: identity.accountId,
          isSelf: true,
        ),
      ),
    );
  }

  Future<void> _openMembership() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MembershipPage(
          currentUserContext: _currentUserContext,
          sessionProvider: _sessionProvider,
          subscriptionService: _subscriptionService,
        ),
      ),
    );
    await _loadState();
  }

  void _openCreator() {
    // 创作者页通过当前用户单源核对账户绑定，再复用共享链缓存。
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CreatorPage(
          service: widget.creatorService,
          currentUserContext: _currentUserContext,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            imagePath: _publicProfileMedia.avatarPath,
            imageUrl: null,

            userImageSet: _publicProfile?.avatarKey?.trim().isNotEmpty == true,
            // 与用户主页统一为 80 逻辑像素；主页的 4px 边框会让默认徽章视觉上多
            // 外露约 4px，“我的”无边框，因此在这里补偿同等右下外溢距离。
            size: 80,
            badgeOverflow: 6,
            seed: _identityCidNumber.isEmpty
                ? _communicationAccountId
                : _identityCidNumber,
            cidLevel: _defaultWalletIdentityLevel,
            memberLevel: null,
            membergateActive: false,
          ),
          SizedBox(width: AppLayout.scaledValue(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppLayout.scaledValue(20),
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: const Color(0x80000000),
                        blurRadius: AppLayout.scaledValue(10),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppLayout.scaledValue(6)),
                Text(
                  _identityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppLayout.scaledValue(14),
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: const Color(0x99000000),
                        blurRadius: AppLayout.scaledValue(8),
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 80,
            child: Center(
              child: InkWell(
                key: const ValueKey('my-profile-chevron'),
                onTap: _openMyProfile,
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
                child: Padding(
                  padding: EdgeInsets.all(AppLayout.scaledValue(4)),
                  child: Icon(
                    Icons.chevron_right,
                    size: AppLayout.scaledValue(24),
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: const Color(0x80000000),
                        blurRadius: AppLayout.scaledValue(10),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryEntry({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      key: ValueKey<String>('my-primary-entry-$title'),
      height: AppLayout.primaryEntryCardHeight(context),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.scaledValue(12),
                vertical: AppLayout.scaledValue(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: AppLayout.primaryEntryIconBox,
                    height: AppLayout.primaryEntryIconBox,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(14),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(child: leading),
                  ),
                  SizedBox(width: AppLayout.scaledValue(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: AppLayout.scaledValue(15),
                            color: AppTheme.textPrimary,
                            height: AppLayout.compactLineHeight,
                          ),
                        ),
                        SizedBox(height: AppLayout.scaledValue(3)),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppLayout.scaledValue(12),
                            color: AppTheme.textSecondary,
                            height: AppLayout.subtitleLineHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: AppLayout.iconSmall,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceEntry({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return SizedBox(
      key: ValueKey<String>('my-service-entry-$title'),
      height: AppLayout.serviceEntryHeight(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.scaledValue(14),
              vertical: AppLayout.scaledValue(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: AppLayout.scaledValue(36),
                  height: AppLayout.scaledValue(36),
                  child: Center(child: leading),
                ),
                SizedBox(width: AppLayout.scaledValue(12)),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppLayout.scaledValue(15),
                      color: AppTheme.textPrimary,
                      height: AppLayout.compactLineHeight,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      size: AppLayout.scaledValue(20),
                      color: AppTheme.textTertiary,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 260.0;
    final myTitleStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        color: Colors.white,
        fontSize: AppLayout.scaled(context, 20),
        fontWeight: FontWeight.w700,
        // 显式锁定页面原有 1.4 行高，使定位测量和 Scaffold 内真实 Text 完全一致。
        height: AppLayout.bodyLineHeight,
        shadows: [
          Shadow(
            color: const Color(0x66000000),
            blurRadius: AppLayout.scaled(context, 12),
            offset: Offset(0, AppLayout.scaledValue(2)),
          ),
        ],
      ),
    );
    final myTitlePainter = TextPainter(
      text: TextSpan(text: '我的', style: myTitleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final userCodeButtonSize = AppLayout.scaled(context, 44);
    final userCodeIconSize = AppLayout.scaled(context, 22);
    // 可见图标位于点击区正中；按标题实际行高计算按钮顶部，使二维码顶部
    // 始终落在“我的”文字底部之后，系统文字倍率变化时也不重新重叠。
    final userCodeButtonTop =
        topPadding +
        AppLayout.scaled(context, 10) +
        myTitlePainter.height -
        (userCodeButtonSize - userCodeIconSize) / 2 +
        AppLayout.scaled(context, 1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _loadState(refreshRemote: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: headerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      key: const ValueKey('my-profile-background'),
                      onTap: _openMyProfile,
                      child: _HeaderBackground(
                        path: _publicProfileMedia.bannerPath,

                        userImageSet:
                            _publicProfile?.bannerKey?.trim().isNotEmpty ==
                            true,
                        height: headerHeight,
                        seed: _identityCidNumber.isEmpty
                            ? _communicationAccountId
                            : _identityCidNumber,
                      ),
                    ),
                    // 用户可选任意明暗的背景图；状态栏区域固定叠加暗色渐隐，保证白色
                    // 时间、信号和电池图标不会落在浅色天空或高光区域后失去对比度。
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topPadding + 72,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          key: ValueKey('my-header-status-bar-scrim'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x66000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: topPadding + 10,
                      left: 0,
                      right: 0,
                      child: Center(child: Text('我的', style: myTitleStyle)),
                    ),
                    Positioned(
                      // 整个点击区随可见二维码下移；不能只挪图标造成点击位置错位。
                      // 右边距使其中心与下方资料卡右箭头严格垂直对齐。
                      top: userCodeButtonTop,
                      right: AppLayout.scaled(context, 24),
                      child: SizedBox(
                        width: userCodeButtonSize,
                        height: userCodeButtonSize,
                        child: IconButton(
                          key: const ValueKey('my-header-user-code-button'),
                          tooltip: '我的用户码',
                          padding: EdgeInsets.zero,
                          onPressed: _openMyUserCode,
                          icon: Icon(
                            Icons.qr_code_2_rounded,
                            size: userCodeIconSize,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: const Color(0x80000000),
                                blurRadius: AppLayout.scaled(context, 10),
                                offset: Offset(0, AppLayout.scaledValue(2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppLayout.scaled(context, 16),
                      right: AppLayout.scaled(context, 16),
                      bottom: AppLayout.scaled(context, 22),
                      child: _buildProfileCard(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPrimaryEntry(
                        leading: SvgPicture.asset(
                          'packages/citizen_assets/icons/wallet.svg',
                          width: AppLayout.scaled(context, 24),
                          height: AppLayout.scaled(context, 24),
                          colorFilter: const ColorFilter.mode(
                            AppTheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: '钱包',
                        subtitle: '管理账户',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WalletTab(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: AppLayout.scaled(context, 10)),
                    Expanded(
                      child: _buildPrimaryEntry(
                        leading: Icon(
                          Icons.badge_outlined,
                          color: AppTheme.primary,
                          size: AppLayout.scaled(context, 24),
                        ),
                        title: '身份',
                        subtitle: '注册与查看',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyIdPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Text(
                  '个人服务',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: AppLayout.scaled(context, 17),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 16),
                ),
                child: Container(
                  decoration: AppTheme.cardDecoration(
                    radius: AppTheme.radiusLg,
                  ),
                  child: Column(
                    children: [
                      _buildServiceEntry(
                        leading: Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primary,
                          size: AppLayout.scaled(context, 22),
                        ),
                        title: '创作者',
                        onTap: _openCreator,
                      ),
                      Divider(
                        height: 1,
                        indent: AppLayout.scaled(context, 62),
                        endIndent: AppLayout.scaled(context, 14),
                      ),
                      _buildServiceEntry(
                        leading: SvgPicture.asset(
                          'packages/citizen_assets/icons/contact-round.svg',
                          width: AppLayout.scaled(context, 22),
                          height: AppLayout.scaled(context, 22),
                          colorFilter: const ColorFilter.mode(
                            AppTheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: '通讯录',
                        onTap: _openContacts,
                      ),
                      Divider(
                        height: 1,
                        indent: AppLayout.scaled(context, 62),
                        endIndent: AppLayout.scaled(context, 14),
                      ),
                      _buildServiceEntry(
                        leading: Icon(
                          Icons.workspace_premium_outlined,
                          color: AppTheme.primary,
                          size: AppLayout.scaled(context, 22),
                        ),
                        title: '会员｜订阅',
                        onTap: _openMembership,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 16)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.scaled(context, 16),
                ),
                child: Container(
                  decoration: AppTheme.cardDecoration(
                    radius: AppTheme.radiusLg,
                  ),
                  child: _buildServiceEntry(
                    leading: UpdateDotBadge(
                      show: widget.showSettingsUpdateDot,
                      dotKey: const Key('settings-entry-update-dot'),
                      child: Icon(
                        Icons.settings_outlined,
                        color: AppTheme.textSecondary,
                        size: AppLayout.scaled(context, 22),
                      ),
                    ),
                    title: '设置',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: AppLayout.scaled(context, 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({
    required this.path,
    required this.userImageSet,
    required this.height,
    required this.seed,
  });

  final String? path;
  final bool userImageSet;
  final double height;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final hasImage = path != null && path!.trim().isNotEmpty;
    final file = hasImage ? File(path!) : null;
    final validImage = file != null && file.existsSync();

    final Widget background;
    if (validImage) {
      background = Image.file(file, fit: BoxFit.cover);
    } else if (userImageSet) {
      background = const ColoredBox(color: AppTheme.surfaceMuted);
    } else {
      background = Image.asset(
        ProfilePresentation.forIdentityKey(seed).bannerAsset,
        fit: BoxFit.cover,
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.18),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.homeTabPreferenceReader,
    this.homeTabPreferenceWriter,
    this.privacyApi,
    this.privacySessionProvider,
    this.privacyUserContext,
    this.privacyRevision,
  });

  /// 测试只替换 UserIsar 读写；产品运行始终使用 UserIsar 唯一真源。
  @visibleForTesting
  final Future<bool> Function()? homeTabPreferenceReader;

  @visibleForTesting
  final Future<void> Function(bool value)? homeTabPreferenceWriter;

  final SquareApiClient? privacyApi;
  final SquareSessionProvider? privacySessionProvider;
  final CurrentUserContext? privacyUserContext;
  final Listenable? privacyRevision;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _deviceLockKey = 'device_lock_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AppUpdateController _updateController = AppUpdateController.instance;
  bool _deviceLockEnabled = false;
  bool _pinLockEnabled = false;
  bool _duressModeEnabled = false;
  bool _openChatOnLaunch = false;
  bool _savingHomeTab = false;
  bool _loading = true;
  SquareApiClient? _ownedPrivacyApi;
  SquareApiClient get _privacyApi =>
      widget.privacyApi ?? context.read<SquareApiClient?>() ??
      (_ownedPrivacyApi ??= SquareApiClient());
  Listenable? _privacyRevision;
  bool _privacyInitialized = false;
  bool _privacyLoading = true;
  bool _privacyFailed = false;
  bool _privacySaving = false;
  DmPolicy _dmPolicy = DmPolicy.all;
  ProfileVisibility _profileVisibility = ProfileVisibility.public;
  int _privacyGeneration = 0;
  ({String cid, String account, int revision})? _privacyOwner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_privacyInitialized) return;
    _privacyInitialized = true;
    _privacyRevision =
        widget.privacyRevision ??
        context.read<AccountSecurityService?>()?.revision;
    _privacyRevision?.addListener(_loadPrivacy);
    unawaited(_loadPrivacy());
  }

  Future<SquareSession> _privacySession({bool refresh = false}) async {
    final user =
        await (widget.privacyUserContext ?? context.read<CurrentUserContext>())
            .resolve();
    if (user?.binding == null) throw StateError('没有当前公民身份');
    final resolution =
        await (widget.privacySessionProvider ??
                context.read<SquareSessionProvider>())
            .resolveSession(refresh: refresh);
    final session = resolution.session;
    if (session == null ||
        session.cidNumber != user!.cidNumber ||
        session.accountId != user.accountId ||
        session.bindRev != user.bindRev) {
      throw StateError('隐私会话与当前身份不一致');
    }
    return session;
  }

  Future<void> _loadPrivacy() async {
    final generation = ++_privacyGeneration;
    if (mounted)
      setState(() {
        _dmPolicy = DmPolicy.all;
        _profileVisibility = ProfileVisibility.public;
        _privacyOwner = null;
        _privacyLoading = true;
        _privacyFailed = false;
        _privacySaving = false;
      });
    try {
      final session = await _privacySession();
      final privacy = await _privacyApi.fetchPrivacy(session);
      if (!mounted || generation != _privacyGeneration) return;
      final current = await _privacySession();
      if (!mounted || generation != _privacyGeneration) return;
      if (current.cidNumber != session.cidNumber ||
          current.accountId != session.accountId ||
          current.bindRev != session.bindRev)
        throw StateError('隐私身份已变化');
      setState(() {
        _dmPolicy = privacy.dmPolicy;
        _profileVisibility = privacy.profileVisibility;
        _privacyOwner = (
          cid: session.cidNumber,
          account: session.accountId,
          revision: session.bindRev,
        );
        _privacyLoading = false;
      });
    } on Object {
      if (mounted && generation == _privacyGeneration)
        setState(() {
          _privacyFailed = true;
          _privacyLoading = false;
        });
      if (mounted && generation == _privacyGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('隐私设置读取失败，点击选项可重试')),
        );
      }
    }
  }

  TextStyle get _settingValueStyle => TextStyle(
    fontSize: AppLayout.scaledValue(13),
    color: AppTheme.textSecondary,
  );

  Future<void> _chooseDmPolicy() async {
    if (_privacyLoading || _privacySaving) return;
    if (_privacyFailed) {
      await _loadPrivacy();
      return;
    }
    final generation = _privacyGeneration, owner = _privacyOwner;
    final policy = await showDialog<DmPolicy>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('私信权限'),
        children: [
          RadioGroup<DmPolicy>(
            groupValue: _dmPolicy,
            onChanged: (value) {
              if (value != null) Navigator.of(dialog).pop(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in DmPolicy.values)
                  RadioListTile<DmPolicy>(
                    title: Text(value.label, style: _settingValueStyle),
                    value: value,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted ||
        generation != _privacyGeneration ||
        policy == null ||
        policy == _dmPolicy)
      return;
    await _savePrivacy(generation, owner, dmPolicy: policy);
  }

  Future<void> _chooseProfileVisibility() async {
    if (_privacyLoading || _privacySaving) return;
    if (_privacyFailed) {
      await _loadPrivacy();
      return;
    }
    final generation = _privacyGeneration, owner = _privacyOwner;
    final selected = await showDialog<ProfileVisibility>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('主页可见'),
        children: [
          RadioGroup<ProfileVisibility>(
            groupValue: _profileVisibility,
            onChanged: (value) {
              if (value != null) Navigator.of(dialog).pop(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in ProfileVisibility.values)
                  RadioListTile<ProfileVisibility>(
                    title: Text(value.label, style: _settingValueStyle),
                    value: value,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted ||
        generation != _privacyGeneration ||
        selected == null ||
        selected == _profileVisibility)
      return;
    await _savePrivacy(generation, owner, profileVisibility: selected);
  }

  // 两项隐私共用身份校验；仅云端确认后更新，部分提交不覆盖另一项。
  Future<void> _savePrivacy(
    int generation,
    ({String cid, String account, int revision})? owner, {
    DmPolicy? dmPolicy,
    ProfileVisibility? profileVisibility,
  }) async {
    setState(() => _privacySaving = true);
    try {
      final session = await _privacySession();
      if (!mounted || generation != _privacyGeneration) return;
      if (owner !=
          (
            cid: session.cidNumber,
            account: session.accountId,
            revision: session.bindRev,
          )) {
        throw StateError('隐私身份已变化');
      }
      final saved = await _privacyApi.savePrivacy(
        session,
        dmPolicy: dmPolicy,
        profileVisibility: profileVisibility,
      );
      if (!mounted || generation != _privacyGeneration) return;
      final current = await _privacySession();
      if (!mounted || generation != _privacyGeneration) return;
      if (owner !=
          (
            cid: current.cidNumber,
            account: current.accountId,
            revision: current.bindRev,
          )) {
        await _loadPrivacy();
        return;
      }
      setState(() {
        _dmPolicy = saved.dmPolicy;
        _profileVisibility = saved.profileVisibility;
      });
    } on Object {
      if (mounted && generation == _privacyGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileVisibility == null ? '私信权限保存失败，请重试' : '主页可见保存失败，请重试',
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _privacyGeneration)
        setState(() => _privacySaving = false);
    }
  }

  Future<void> _openBlocks() async {
    try {
      await _privacySession();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => _BlockedUsersPage(
          api: _privacyApi, resolveSession: _privacySession, revision: _privacyRevision,
        ),
      ));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('黑名单读取失败，请重试')),
        );
      }
    }
  }

  Widget _privacyIcon(IconData icon) => Container(
    width: AppLayout.scaledValue(36),
    height: AppLayout.scaledValue(36),
    decoration: BoxDecoration(
      color: AppTheme.primary.withAlpha(20),
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
    ),
    child: Icon(icon, size: AppLayout.scaledValue(20), color: AppTheme.primary),
  );

  Widget _buildPrivacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(
          left: AppLayout.scaled(context, 4),
          bottom: AppLayout.scaled(context, 10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: AppLayout.scaled(context, 16),
              color: AppTheme.primary,
            ),
            SizedBox(width: AppLayout.scaled(context, 8)),
            Text(
              '隐私',
              style: TextStyle(
                fontSize: AppLayout.scaled(context, 13),
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
      Container(
        decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              ListTile(
                key: const ValueKey('blocked-users-setting'),
                leading: _privacyIcon(Icons.block_outlined),
                title: const Text('黑名单'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openBlocks,
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              ListTile(
                key: const ValueKey('dm-policy-setting'),
                leading: _privacyIcon(Icons.textsms_outlined),
                title: const Text('私信权限'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _privacySaving ? '保存中' : _dmPolicy.label,
                      style: _settingValueStyle,
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _privacyLoading || _privacySaving
                    ? null
                    : _chooseDmPolicy,
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              ListTile(
                key: const ValueKey('profile-visibility-setting'),
                leading: _privacyIcon(Icons.public),
                title: const Text('主页可见'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _privacySaving ? '保存中' : _profileVisibility.label,
                      style: _settingValueStyle,
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _privacyLoading || _privacySaving
                    ? null
                    : _chooseProfileVisibility,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _updateController.addListener(_handleUpdateStateChanged);
    _loadSettings();
    _updateController.check();
  }

  @override
  void dispose() {
    _privacyGeneration++;
    _privacyRevision?.removeListener(_loadPrivacy);
    _ownedPrivacyApi?.close();
    _updateController.removeListener(_handleUpdateStateChanged);
    super.dispose();
  }

  void _handleUpdateStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadSettings() async {
    // 四项读取先同时启动，新增首页偏好不能延长原有三项安全设置的串行等待。
    final values = await Future.wait<Object?>([
      SystemProtectedRecordStore.lock.read(_deviceLockKey),
      AppLockService.isPinSet(),
      AppLockService.isDuressModeEnabled(),
      (widget.homeTabPreferenceReader ??
          UserIsar.instance.readOpenChatOnLaunch)(),
    ]);
    if (!mounted) return;
    setState(() {
      _deviceLockEnabled = values[0] == 'true';
      _pinLockEnabled = values[1]! as bool;
      _duressModeEnabled = values[2]! as bool;
      _openChatOnLaunch = values[3]! as bool;
      _loading = false;
    });
  }

  Future<void> _toggleHomeTab(bool value) async {
    if (_savingHomeTab) return;
    setState(() => _savingHomeTab = true);
    try {
      await (widget.homeTabPreferenceWriter ??
          UserIsar.instance.writeOpenChatOnLaunch)(value);
      if (!mounted) return;
      setState(() => _openChatOnLaunch = value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('首页设置保存失败，请重试')));
    } finally {
      if (mounted) setState(() => _savingHomeTab = false);
    }
  }

  Future<void> _toggleDeviceLock(bool value) async {
    if (value) {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('您的设备不支持生物识别或设备密码，无法开启设备锁')),
        );
        return;
      }

      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: BiometricAuthText.pick(
            zh: '验证身份以开启设备锁',
            en: 'Verify your identity to enable the device lock',
          ),
          authMessages: BiometricAuthText.messages(),
          biometricOnly: false,
          persistAcrossBackgrounding: true,
          sensitiveTransaction: true,
        );
        if (!authenticated) return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('身份验证失败：$e')));
        return;
      }
    }

    await SystemProtectedRecordStore.lock.write(
      _deviceLockKey,
      value.toString(),
    );
    if (!mounted) return;
    setState(() => _deviceLockEnabled = value);
  }

  Future<void> _togglePinLock(bool value) async {
    if (value) {
      // 开启：进入设置 PIN 页面
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinInputPage(mode: PinInputMode.setup),
        ),
      );
      if (result == true && mounted) {
        setState(() {
          _pinLockEnabled = true;
          _duressModeEnabled = false;
        });
      }
    } else {
      // 关闭：进入验证 PIN 页面（验证通过后删除）
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinInputPage(mode: PinInputMode.remove),
        ),
      );
      if (result == true && mounted) {
        setState(() {
          _pinLockEnabled = false;
          _duressModeEnabled = false;
        });
      }
    }
  }

  Future<void> _handlePinLockAreaTap() async {
    if (_deviceLockEnabled || _duressModeEnabled) return;
    if (!_pinLockEnabled) {
      await _togglePinLock(true);
      return;
    }
    final saved = await showDuressModeSetupDialog(context);
    if (saved && mounted) setState(() => _duressModeEnabled = true);
  }

  Future<void> _openUpdateStore() async {
    final started = await _updateController.openStore();
    if (!mounted) return;

    final error = _updateController.state.errorMessage;
    if (!started) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已打开应用商店，请在商店中更新')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : ListView(
              padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
              children: [
                // 安全区标题
                Padding(
                  padding: EdgeInsets.only(
                    left: AppLayout.scaled(context, 4),
                    bottom: AppLayout.scaled(context, 10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: AppLayout.scaled(context, 16),
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 8)),
                      Text(
                        '安全',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 13),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: AppTheme.cardDecoration(
                    radius: AppTheme.radiusLg,
                  ),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        icon: Icons.fingerprint_rounded,
                        title: '设备锁',
                        subtitle: _pinLockEnabled
                            ? '请先关闭应用锁'
                            : '启动应用时需要生物识别或设备密码',
                        value: _deviceLockEnabled,
                        onChanged: _pinLockEnabled ? null : _toggleDeviceLock,
                      ),
                      Divider(
                        height: 1,
                        indent: AppLayout.scaled(context, 56),
                        endIndent: AppLayout.scaled(context, 16),
                      ),
                      _buildSettingTile(
                        icon: Icons.pin_outlined,
                        title: _pinLockEnabled && _duressModeEnabled
                            ? '应用锁（防共匪模式）'
                            : '应用锁（防共匪锁）',
                        subtitle: _deviceLockEnabled
                            ? '请先关闭设备锁'
                            : !_pinLockEnabled
                            ? '启动应用时需要输入 6 位数字密码'
                            : _duressModeEnabled
                            ? '防共匪模式已开启'
                            : '点击设置防共匪密码',
                        value: _pinLockEnabled,
                        onChanged: _deviceLockEnabled ? null : _togglePinLock,
                        onTap: _deviceLockEnabled
                            ? null
                            : _handlePinLockAreaTap,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppLayout.scaled(context, 28)),
                _buildPrivacy(),
                SizedBox(height: AppLayout.scaled(context, 28)),
                _buildHomeTabTile(),
                SizedBox(height: AppLayout.scaled(context, 28)),
                // 关于区标题
                Padding(
                  padding: EdgeInsets.only(
                    left: AppLayout.scaled(context, 4),
                    bottom: AppLayout.scaled(context, 10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: AppLayout.scaled(context, 16),
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: AppLayout.scaled(context, 8)),
                      Text(
                        '关于',
                        style: TextStyle(
                          fontSize: AppLayout.scaled(context, 13),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(AppLayout.scaled(context, 16)),
                  decoration: AppTheme.cardDecoration(
                    radius: AppTheme.radiusLg,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: AppLayout.scaled(context, 36),
                            height: AppLayout.scaled(context, 36),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppLayout.scaledValue(8),
                              ),
                            ),
                            child: Icon(
                              Icons.how_to_vote_rounded,
                              color: Colors.white,
                              size: AppLayout.scaled(context, 18),
                            ),
                          ),
                          SizedBox(width: AppLayout.scaled(context, 12)),
                          Text(
                            '公民',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: AppLayout.scaled(context, 16),
                            ),
                          ),
                          const Spacer(),
                          _buildUpdateButton(),
                          SizedBox(width: AppLayout.scaled(context, 8)),
                          Text(
                            _updateController.state.versionLabel,
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: AppLayout.scaled(context, 13),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppLayout.scaled(context, 10)),
                      Row(
                        children: [
                          SizedBox(width: AppLayout.scaled(context, 48)),
                          Text(
                            '公民治理，链上投票',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: AppLayout.scaled(context, 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    VoidCallback? onTap,
  }) {
    final disabled = onChanged == null && onTap == null;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaledValue(16),
        vertical: AppLayout.scaledValue(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
              child: Row(
                children: [
                  Container(
                    width: AppLayout.scaledValue(36),
                    height: AppLayout.scaledValue(36),
                    decoration: BoxDecoration(
                      color: disabled
                          ? AppTheme.surfaceElevated
                          : AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(
                        AppLayout.scaledValue(8),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: AppLayout.scaledValue(20),
                      color: disabled
                          ? AppTheme.textTertiary
                          : AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: AppLayout.scaledValue(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppLayout.scaledValue(15),
                            fontWeight: FontWeight.w500,
                            color: disabled
                                ? AppTheme.textTertiary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppLayout.scaledValue(2)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: AppLayout.scaledValue(12),
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 首页偏好是一行展示设置：标题、当前首页和与安全设置同款的 Switch 同行显示。
  Widget _buildHomeTabTile() {
    return Container(
      key: const ValueKey('home-tab-setting-tile'),
      // 与“我的”主页的“设置”入口复用同一高度令牌，禁止两处随屏幕缩放后分叉。
      height: AppLayout.serviceEntryHeight(context),
      decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.scaledValue(16),
          // Switch 保持与安全设置同款视觉和触控区；少量上下留白只负责内部居中，
          // 卡片最终行高统一由 serviceEntryHeight 控制。
          vertical: AppLayout.scaledValue(4),
        ),
        child: Row(
          children: [
            Container(
              width: AppLayout.scaledValue(36),
              height: AppLayout.scaledValue(36),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(AppLayout.scaledValue(8)),
              ),
              child: Icon(
                Icons.home_outlined,
                size: AppLayout.scaledValue(20),
                color: AppTheme.primary,
              ),
            ),
            SizedBox(width: AppLayout.scaledValue(14)),
            Expanded(
              child: Text(
                '首页设置',
                style: TextStyle(
                  fontSize: AppLayout.scaledValue(15),
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              _openChatOnLaunch ? '聊天' : '广场',
              key: const ValueKey('home-tab-setting-value'),
              style: _settingValueStyle,
            ),
            SizedBox(width: AppLayout.scaledValue(8)),
            Switch(
              key: const ValueKey('home-tab-setting-switch'),
              value: _openChatOnLaunch,
              onChanged: _savingHomeTab ? null : _toggleHomeTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    final state = _updateController.state;
    if (!state.hasUpdate) {
      return const SizedBox.shrink();
    }

    final opening = state.status == AppUpdateStatus.opening;

    return SizedBox(
      height: AppLayout.scaledValue(30),
      child: FilledButton.icon(
        onPressed: opening ? null : _openUpdateStore,
        icon: const Icon(Icons.system_update_alt_rounded),
        label: Text(opening ? '打开中' : '更新'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: AppLayout.scaledValue(10)),
          textStyle: TextStyle(
            fontSize: AppLayout.scaledValue(12),
            fontWeight: FontWeight.w600,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}


class _BlockedUsersPage extends StatefulWidget {
  const _BlockedUsersPage({required this.api, required this.resolveSession, this.revision});
  final SquareApiClient api;
  final Future<SquareSession> Function({bool refresh}) resolveSession;
  final Listenable? revision;

  @override
  State<_BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<_BlockedUsersPage> {
  List<String>? _users;
  bool _failed = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    widget.revision?.addListener(_identityChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.revision?.removeListener(_identityChanged);
    super.dispose();
  }

  void _identityChanged() {
    setState(() {
      _changed = true;
      _users = null;
    });
  }

  Future<void> _load() async {
    if (_changed) return;
    setState(() => _failed = false);
    try {
      var session = await widget.resolveSession();
      if (!mounted || _changed) return;
      Set<String> rows;
      try {
        rows = await widget.api.blockedUsers(session, refresh: true);
      } on SquareApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        // 仅明确401刷新一次；503和普通失败保留原重试入口，不反复握手。
        session = await widget.resolveSession(refresh: true);
        if (!mounted || _changed) return;
        rows = await widget.api.blockedUsers(session, refresh: true);
      }
      if (mounted && !_changed) setState(() => _users = rows.toList());
    } on Object {
      if (mounted && !_changed) setState(() => _failed = true);
    }
  }

  Future<bool> _unblock(String cid) async {
    if (_changed) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('解除拉黑'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('解除拉黑')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _changed) return false;
    try {
      final session = await widget.resolveSession();
      if (!mounted || _changed) return false;
      await widget.api.setBlocked(session, cid, false);
      return mounted && !_changed;
    } on Object {
      if (mounted && !_changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('解除拉黑失败，请重试')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text('黑名单')),
      body: _changed
          ? const Center(child: Text('身份已切换，请返回'))
          : _failed
          ? Center(child: TextButton(onPressed: _load, child: const Text('读取失败，重试')))
          : users == null
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text('黑名单为空'))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, index) {
                final cid = users[index];
                return Dismissible(
                  key: ValueKey(cid),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppTheme.danger,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('解除拉黑', style: TextStyle(color: Colors.white)),
                  ),
                  confirmDismiss: (_) => _unblock(cid),
                  onDismissed: (_) => setState(() => _users?.remove(cid)),
                  child: ListTile(title: Text(formatIdentityCidText(cid))),
                );
              },
            ),
    );
  }
}
