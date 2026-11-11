import 'package:citizen_chain/citizen_chain.dart';
import 'package:provider/provider.dart';

import 'package:citizen_user/profile/citizen_profile_api.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:citizen_user/profile/profile_presentation.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_user/identity/identity_badge.dart';

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
    if (widget.showBadge &&
        RegExp(
          r'^[A-Z0-9]+-[A-Z0-9]+-[0-9]{9}-[0-9]{4}$',
        ).hasMatch(widget.seed)) {
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
    final badge = identityBadgeStyle(
      cidLevel: _source == null ? widget.cidLevel : snapshot?.identityLevel(widget.seed),
      memberLevel: _source == null
          ? widget.memberLevel
          : snapshot?.memberLevel(widget.seed),
      membergateActive: _source == null
          ? widget.membergateActive
          : snapshot?.memberActive(widget.seed) == true,
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
                cidLevel: widget.cidLevel,
                memberLevel: widget.memberLevel,
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
