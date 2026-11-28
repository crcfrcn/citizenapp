// 选择发布媒体，展示添加、移除和视频预览组件。

import 'dart:io';

import 'package:citizen_square/post/models.dart';
import 'package:citizen_system/theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

// 封装设备相册选择，向编辑器交付已确定类型的文件和选择状态。

/// 发布页相册返回值：文件与资源类型在离开相册前已经确定。
class ComposePickedMedia {
  const ComposePickedMedia({
    required this.file,
    required this.mediaKind,
    this.assetId,
  });

  final XFile file;
  final SquareMediaKind mediaKind;
  final String? assetId;
}

/// 已确认的纯图片选择；无法在相册恢复的既有资源由调用方继续保留。
class ComposeImageSelection {
  const ComposeImageSelection({
    required this.selected,
    this.missingAssetIds = const <String>[],
  });

  final List<ComposePickedMedia> selected;
  final List<String> missingAssetIds;
}

/// 公文与文章共用的设备相册边界，测试可注入假实现而不唤起系统权限。
abstract class ComposeMediaPicker {
  const ComposeMediaPicker();

  /// 只允许选择图片，[maxImages] 是当前编辑器剩余可选数量。
  Future<List<XFile>> pickImages(BuildContext context, int maxImages);

  /// 带既有相册资源预选的纯图片选择。返回 null 表示用户取消。
  Future<ComposeImageSelection?> pickImagesWithSelection(
    BuildContext context,
    int maxImages, {
    List<String> selectedPhotoManagerAssetIds = const <String>[],
  }) async {
    final files = await pickImages(context, maxImages);
    if (files.isEmpty) return null;
    return ComposeImageSelection(
      selected: [
        for (final file in files)
          ComposePickedMedia(file: file, mediaKind: SquareMediaKind.image),
      ],
    );
  }

  /// 第一个选中项决定类型：一次返回最多九张图片或一个视频，两者不能混选。
  Future<List<ComposePickedMedia>> pickArticleMedia(BuildContext context);
}

/// 发布页唯一相册实现。Android 与 iOS 都使用同一 Flutter 相册网格，避免 Android
/// 回落到文件管理器，也避免平台系统选择器忽略数量或允许图片/视频混选。
class DeviceComposeMediaPicker extends ComposeMediaPicker {
  const DeviceComposeMediaPicker();

  @override
  Future<List<XFile>> pickImages(BuildContext context, int maxImages) async {
    if (maxImages <= 0) return const <XFile>[];
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxImages,
        requestType: RequestType.image,
        themeColor: AppTheme.primary,
        textDelegate: const AssetPickerTextDelegate(),
      ),
    );
    if (assets == null || assets.isEmpty) return const <XFile>[];
    final files = <XFile>[];
    for (final asset in assets.take(maxImages)) {
      final file = await asset.file;
      if (file == null) continue;
      files.add(await _toXFile(asset, file.path));
    }
    return files;
  }

  @override
  Future<ComposeImageSelection?> pickImagesWithSelection(
    BuildContext context,
    int maxImages, {
    List<String> selectedPhotoManagerAssetIds = const <String>[],
  }) async {
    if (maxImages <= 0) return null;
    final selectedAssets = <AssetEntity>[];
    final unavailableIds = <String>[];
    for (final id in selectedPhotoManagerAssetIds) {
      final asset = await AssetEntity.fromId(id);
      if (asset == null || asset.type != AssetType.image) {
        unavailableIds.add(id);
      } else {
        selectedAssets.add(asset);
      }
    }
    final pickerMaximum = maxImages - unavailableIds.length;
    if (pickerMaximum <= 0) {
      throw const FormatException('现有照片已达到9张，请先删除一张再增加');
    }
    if (!context.mounted) return null;
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        selectedAssets: selectedAssets,
        maxAssets: pickerMaximum,
        requestType: RequestType.image,
        themeColor: AppTheme.primary,
        textDelegate: const AssetPickerTextDelegate(),
      ),
    );
    if (assets == null) return null;
    final selected = <ComposePickedMedia>[];
    for (final asset in assets.take(pickerMaximum)) {
      final file = await asset.file;
      if (file == null) continue;
      selected.add(
        ComposePickedMedia(
          file: await _toXFile(asset, file.path),
          mediaKind: SquareMediaKind.image,
          assetId: asset.id,
        ),
      );
    }
    return ComposeImageSelection(
      selected: selected,
      missingAssetIds: unavailableIds,
    );
  }

  @override
  Future<List<ComposePickedMedia>> pickArticleMedia(
    BuildContext context,
  ) async {
    final assets = await AssetPicker.pickAssets(
      context,
      // wechat_assets_picker 的 const assert 会触发 Dart 3.11 非原始相等限制，运行值保持不变。
      // ignore: prefer_const_constructors
      pickerConfig: AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.common,
        specialPickerType: SpecialPickerType.wechatMoment,
        themeColor: AppTheme.primary,
        textDelegate: const AssetPickerTextDelegate(),
      ),
    );
    if (assets == null || assets.isEmpty) {
      return const <ComposePickedMedia>[];
    }
    final selectedKind = assets.first.type;
    // 组件已在选择界面内互斥；返回边界仍失败关闭，避免异常平台数据进入编辑器。
    if ((selectedKind != AssetType.image && selectedKind != AssetType.video) ||
        assets.any((asset) => asset.type != selectedKind) ||
        (selectedKind == AssetType.video && assets.length != 1) ||
        (selectedKind == AssetType.image && assets.length > 9)) {
      throw const FormatException('一次只能选择 1 个视频，或 1–9 张图片');
    }
    final files = <ComposePickedMedia>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;
      files.add(
        ComposePickedMedia(
          file: await _toXFile(asset, file.path),
          mediaKind: asset.type == AssetType.video
              ? SquareMediaKind.video
              : SquareMediaKind.image,
          assetId: asset.id,
        ),
      );
    }
    return files;
  }

  Future<XFile> _toXFile(AssetEntity asset, String filePath) async {
    final title = await asset.titleAsync;
    return XFile(
      filePath,
      name: title.isEmpty ? null : title,
      mimeType: await asset.mimeTypeAsync,
    );
  }
}

// 提供共用媒体添加删除按钮、视频预览和缩略图选择控件。

/// 公文、文章、视频共用的无外框媒体入口；禁用时保留位置并显示灰色。
class ComposeMediaAddButton extends StatelessWidget {
  const ComposeMediaAddButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 34,
    this.iconSize,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// 图形自身留白不同时可独立校准视觉尺寸，按钮点击区域仍由 [size] 统一控制。
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      iconSize: iconSize ?? size * 0.66,
      color: AppTheme.primary,
      disabledColor: AppTheme.textTertiary,
      icon: Icon(icon),
    );
  }
}

/// 所有发布媒体统一使用的圆形叉号，禁止各编辑器另造删除按钮。
class ComposeMediaRemoveButton extends StatelessWidget {
  const ComposeMediaRemoveButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = 28,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.black.withAlpha(0x99),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.close_rounded,
              size: size * 0.64,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 本地视频真实画面组件。使用仓库现有 video_player，不生成第二份封面文件。
/// [interactive] 为 true 时点击切换播放；缩略图模式固定停在首帧。
class ComposeLocalVideoPreview extends StatefulWidget {
  const ComposeLocalVideoPreview({
    super.key,
    required this.path,
    this.interactive = false,
    this.fit = BoxFit.cover,
  });

  final String path;
  final bool interactive;
  final BoxFit fit;

  @override
  State<ComposeLocalVideoPreview> createState() =>
      _ComposeLocalVideoPreviewState();
}

class _ComposeLocalVideoPreviewState extends State<ComposeLocalVideoPreview> {
  VideoPlayerController? _controller;
  Object? _error;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant ComposeLocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_initializationGeneration;
    final previous = _controller;
    _controller = null;
    if (previous != null) await previous.dispose();
    if (!mounted || generation != _initializationGeneration) return;
    setState(() => _error = null);
    final file = File(widget.path);
    if (!file.existsSync()) {
      setState(() => _error = const FormatException('视频文件不存在'));
      return;
    }
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      if (!mounted || generation != _initializationGeneration) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Object catch (error) {
      await controller.dispose();
      if (mounted && generation == _initializationGeneration) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    _initializationGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (!widget.interactive || controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(
        color: AppTheme.surfaceElevated,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: AppTheme.textTertiary,
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.interactive ? _togglePlayback : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (widget.interactive)
            Center(
              child: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 46,
                color: Colors.white.withAlpha(0xDD),
              ),
            ),
        ],
      ),
    );
  }
}

/// 视频选中后占用原视频图标位置，显示同一文件首帧；点击可重新选择。
class ComposeVideoThumbnailButton extends StatelessWidget {
  const ComposeVideoThumbnailButton({
    super.key,
    required this.path,
    required this.onPressed,
    this.size = 34,
  });

  final String path;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '重新选择视频',
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: ComposeLocalVideoPreview(path: path),
          ),
        ),
      ),
    );
  }
}
