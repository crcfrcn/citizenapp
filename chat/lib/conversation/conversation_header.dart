part of '../chat.dart';

/// 公民资料标题只负责产品资料读取和主页入口，不持有消息运行逻辑。
class _CitizenChatHeader extends StatefulWidget {
  const _CitizenChatHeader({
    required this.peerUserId,
    required this.title,
    required this.isGroup,
    this.initialProfile,
    this.initialProfileMedia,
    this.profileApi,
    this.profileCache,
    this.profileMediaCache,
    this.sessionProvider,
  });

  final String peerUserId;
  final String title;
  final bool isGroup;
  final CitizenProfile? initialProfile;
  final CitizenProfileMediaSnapshot? initialProfileMedia;
  final CitizenProfileApi? profileApi;
  final CitizenProfileCache? profileCache;
  final CitizenProfileMediaCache? profileMediaCache;
  final SquareSessionProvider? sessionProvider;

  @override
  State<_CitizenChatHeader> createState() => _CitizenChatHeaderState();
}

class _CitizenChatHeaderState extends State<_CitizenChatHeader> {
  late final CitizenProfileApi _profileApi =
      widget.profileApi ?? CitizenProfileApi();
  late final CitizenProfileCache _profileCache =
      widget.profileCache ?? const CitizenProfileCache();
  late final CitizenProfileMediaCache _profileMediaCache =
      widget.profileMediaCache ?? CitizenProfileMediaCache();
  late final SquareSessionProvider? _sessionProvider;
  CitizenProfile? _profile;
  CitizenProfileMediaSnapshot _media = const CitizenProfileMediaSnapshot();
  bool _resolved = false;
  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile?.cidNumber == widget.peerUserId
        ? widget.initialProfile
        : null;
    _media = _profile == null
        ? const CitizenProfileMediaSnapshot()
        : (widget.initialProfileMedia ?? const CitizenProfileMediaSnapshot());
    _resolved = _profile != null;
    CitizenProfileCache.revision.addListener(_onRevision);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;
    _sessionProvider =
        widget.sessionProvider ?? context.read<SquareSessionProvider?>();
    _dependenciesReady = true;
    if (!widget.isGroup) unawaited(_readCache());
  }

  @override
  void dispose() {
    CitizenProfileCache.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    final event = CitizenProfileCache.revision.value;
    if (event?.cidNumber == widget.peerUserId) unawaited(_readCache());
  }

  int _cacheGeneration = 0;
  @override
  void didUpdateWidget(covariant _CitizenChatHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerUserId != widget.peerUserId ||
        oldWidget.isGroup != widget.isGroup ||
        oldWidget.initialProfile != widget.initialProfile ||
        oldWidget.initialProfileMedia != widget.initialProfileMedia ||
        oldWidget.profileCache != widget.profileCache ||
        oldWidget.profileMediaCache != widget.profileMediaCache) {
      _cacheGeneration++;
      _profile = widget.initialProfile?.cidNumber == widget.peerUserId
          ? widget.initialProfile
          : null;
      _media = _profile == null
          ? const CitizenProfileMediaSnapshot()
          : (widget.initialProfileMedia ?? const CitizenProfileMediaSnapshot());
      _resolved = _profile != null;
      if (!widget.isGroup) unawaited(_readCache());
    }
  }

  Future<void> _readCache() async {
    final generation = ++_cacheGeneration, peer = widget.peerUserId;
    final profiles = widget.profileCache ?? _profileCache;
    final mediaCache = widget.profileMediaCache ?? _profileMediaCache;
    bool current() =>
        mounted && generation == _cacheGeneration && peer == widget.peerUserId;
    try {
      final profile = await profiles.read(peer);
      if (profile == null || profile.cidNumber != peer || !current()) return;
      final media = await mediaCache.read(profile);
      if (!current()) return;
      if (_profile != null && _profile!.profileAt > profile.profileAt) return;
      setState(() {
        _profile = profile;
        _media = media;
        _resolved = true;
      });
    } on Object {
      /* 资料缓存失败不影响本机历史，继续使用已知资料或中性占位。 */
    }
  }

  Future<void> _openProfile() async {
    if (widget.isGroup || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CitizenServiceGate(
          title: '用户主页',
          description: '注册后即可查看用户主页。',
          child: UserProfilePage(
            cidNumber: widget.peerUserId,
            isSelf: false,
            initialProfile: _profile,
            initialProfileMedia: _media,
            api: widget.profileApi ?? _profileApi,
            cache: widget.profileCache ?? _profileCache,
            mediaCache: widget.profileMediaCache ?? _profileMediaCache,
            sessionProvider: widget.sessionProvider ?? _sessionProvider,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGroup) {
      return Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final name = ProfilePresentation.forIdentityKey(
      widget.peerUserId,
    ).resolveDisplayName(publicName: _profile?.displayName ?? widget.title);
    return InkWell(
      key: const ValueKey('chat-peer-profile-entry'),
      borderRadius: BorderRadius.circular(AppLayout.scaledValue(10)),
      onTap: _openProfile,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(
            seed: widget.peerUserId,
            size: AppLayout.scaled(context, 36),
            imagePath: _media.avatarPath,
            userImageSet: _resolved
                ? _profile?.avatarKey?.trim().isNotEmpty == true
                : true,
            cidLevel: _profile?.cidLevel,
            memberLevel: _profile?.memberLevel,
            membergateActive: _profile?.membergateActive ?? false,
            showBadge: _resolved,
          ),
          SizedBox(width: AppLayout.scaled(context, 9)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 17),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _shortAccount(widget.peerUserId),
                  style: TextStyle(
                    fontSize: AppLayout.scaled(context, 12),
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _shortAccount(String value) {
  if (value.length <= 16) {
    return value;
  }
  return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
}
