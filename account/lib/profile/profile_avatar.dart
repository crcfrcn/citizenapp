import 'package:citizen_account/profile/citizen_profile_api.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:citizen_account/profile/profile_presentation.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_account/identity/identity_badge.dart';

/// 用户公开资料统一头像。用户主页与通讯录共用同一套圆角、默认头像和身份徽章，
/// 避免不同入口把同一个用户展示成两套视觉身份。
class ProfileAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    final badge = identityBadgeStyle(
      cidLevel: cidLevel,
      memberLevel: memberLevel,
      membergateActive: membergateActive,
    );
    final path = imagePath?.trim();
    final file = path == null || path.isEmpty ? null : File(path);
    final validFile = file?.existsSync() == true;
    final url = imageUrl?.trim();
    final hasUserImage =
        userImageSet ??
        validFile || imageProvider != null || (url != null && url.isNotEmpty);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius + borderWidth),
            border: borderWidth <= 0
                ? null
                : Border.all(
                    color: borderColor ?? AppTheme.surfaceCard,
                    width: borderWidth,
                  ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: validFile
                ? Image.file(
                    file!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  )
                : imageProvider != null || (url != null && url.isNotEmpty)
                ? imageProvider == null
                      ? CitizenRemoteImage(
                          url: url!,
                          role: Uri.parse(url).path.contains('/cards/')
                              ? 'card'
                              : 'avatar',
                          width: size,
                          height: size,
                        )
                      : Image(
                          image: imageProvider!,
                          fit: BoxFit.cover,
                          width: size,
                          height: size,
                          frameBuilder: (context, child, frame, syncLoaded) =>
                              syncLoaded || frame != null
                              ? child
                              : const _UserImagePlaceholder(),
                          errorBuilder: (_, _, _) =>
                              const _UserImagePlaceholder(),
                        )
                : hasUserImage
                ? const _UserImagePlaceholder()
                : _StableDefaultAvatar(seed: seed, size: size),
          ),
        ),
        if (showBadge && badge != null)
          Positioned(
            right: -badgeOverflow,
            bottom: -badgeOverflow,
            child: IdentityBadge(
              style: badge,
              size: (size * 0.34).clamp(18, 28),
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
