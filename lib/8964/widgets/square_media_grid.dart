import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:citizenapp/8964/services/square_media_store.dart';
import 'package:citizenapp/8964/services/square_media_policy.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:citizenapp/8964/square_models.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/8964/services/square_media_processor.dart';
import 'package:citizenapp/8964/widgets/square_media_carousel.dart';
import 'package:citizenapp/theme/app_theme.dart';
import 'package:citizenapp/theme/app_layout.dart';

/// 广场卡片媒体区（单块 / 2 个及以上取前两个）。
///
/// 公文照片只有一套动态流规则：单张固定 16:9；两张及以上只显示前两张，
/// 每张都是 16:9 横向长方形，左右等宽、外侧圆角、中缝直角、2px 细缝；
/// 超过两张时在第二张右下角显示 `+N`（N = 总数 - 2）。视频只允许单个，
/// 继续按自身横竖方向使用 16:9 或 3:4 封面，不受公文照片收口影响。
class SquareMediaGrid extends StatelessWidget {
  const SquareMediaGrid({
    super.key,
    required this.mediaItems,
    this.enableVideoPlayback = false,
  });

  final List<SquareMediaItem> mediaItems;
  final bool enableVideoPlayback;

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    const r = AppTheme.radiusMd;

    // 详情按顺序展示全部原图；列表仍只读缩略图并保留既定两图布局。
    if (enableVideoPlayback && mediaItems.length > 1) {
      return SquareMediaCarousel(
        children: [
          for (final item in mediaItems)
            SquareMediaTile(
              item: item,
              radius: BorderRadius.circular(r),
              enableVideoPlayback: true,
            ),
        ],
      );
    }

    if (mediaItems.length == 1) {
      final item = mediaItems.first;
      final isPortraitVideo =
          item.mediaKind == SquareMediaKind.video && item.isPortrait;
      return AspectRatio(
        aspectRatio: isPortraitVideo ? 3 / 4 : 16 / 9,
        child: SquareMediaTile(
          item: item,
          radius: BorderRadius.circular(r),
          enableVideoPlayback: enableVideoPlayback,
        ),
      );
    }

    // 两个 16:9 横向长方形左右相接，整组比例为 32:9；2px 中缝由 Row 单独占用，
    // 不参与任一照片的圆角，保证四个外角为圆角、相接处始终为直角。
    final hidden = mediaItems.length - 2;
    return AspectRatio(
      aspectRatio: 32 / 9,
      child: Row(
        children: [
          Expanded(
            child: SquareMediaTile(
              item: mediaItems[0],
              radius: const BorderRadius.only(
                topLeft: Radius.circular(r),
                bottomLeft: Radius.circular(r),
              ),
            ),
          ),
          // 视觉规范要求中缝固定为 2 逻辑像素，不跟随设备宽度缩放。
          const SizedBox(width: 2),
          Expanded(
            child: SquareMediaTile(
              item: mediaItems[1],
              radius: const BorderRadius.only(
                topRight: Radius.circular(r),
                bottomRight: Radius.circular(r),
              ),
              overlayCount: hidden > 0 ? hidden : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个媒体块：图片/视频封面 + 视频播放键 + 右下角 `+N` 角标。
/// 所有动态流媒体统一由 [SquareMediaGrid] 组合，本组件只负责单块裁切和角标。
class SquareMediaTile extends StatelessWidget {
  const SquareMediaTile({
    super.key,
    required this.item,
    required this.radius,
    this.enableVideoPlayback = false,
    this.overlayCount,
  });

  final SquareMediaItem item;
  final BorderRadius radius;
  final bool enableVideoPlayback;

  /// 非空时在右下角显示 `+N`，表示还有 N 张未展开。
  final int? overlayCount;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.mediaKind == SquareMediaKind.video;
    return ClipRRect(
      borderRadius: radius,
      child: isVideo && enableVideoPlayback
          ? SquareVideo(url: item.url, thumbnailUrl: item.coverUrl, item: item)
          : _buildCover(context, isVideo),
    );
  }

  Widget _buildCover(BuildContext context, bool isVideo) => DecoratedBox(
    decoration: const BoxDecoration(color: AppTheme.surfaceElevated),
    child: Stack(
      fit: StackFit.expand,
      children: [
        SquareMediaImage(item: item, preview: !enableVideoPlayback),
        if (isVideo)
          Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: AppLayout.scaled(context, 42),
              color: Colors.white70,
            ),
          ),
        if (overlayCount != null)
          Positioned(
            right: AppLayout.scaled(context, 8),
            bottom: AppLayout.scaled(context, 8),
            child: _CountBadge(count: overlayCount!),
          ),
      ],
    ),
  );
}

/// 广场单版本HEVC播放器，本地来源只通过受保护的临时文件读取。
///
/// Feed 只渲染封面；详情页点击后才检查设备解码能力并初始化。本地来源逐块校验后写入受保护文件，
/// 他人公开来源使用HTTPS；两者均不生成或切换不存在的多清晰度版本。
class SquareVideo extends StatefulWidget {
  const SquareVideo({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.item,
  });

  final String url;
  final String? thumbnailUrl;
  final SquareMediaItem? item;

  @override
  State<SquareVideo> createState() => _SquareVideoState();
}

class _SquareVideoState extends State<SquareVideo> {
  VideoPlayerController? _controller;
  SquareLocalVideoSource? _localSource;
  Future<void>? _initializationInProgress;
  Future<bool>? _resetInProgress;
  int _initializationGeneration = 0;
  bool _initializing = false;
  bool _isBuffering = false;
  String? _failureMessage;

  @override
  void didUpdateWidget(covariant SquareVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.item?.cidNumber != widget.item?.cidNumber ||
        oldWidget.item?.postId != widget.item?.postId ||
        oldWidget.item?.mediaIndex != widget.item?.mediaIndex) {
      _reset();
    }
  }

  Future<bool> _reset() {
    _initializationGeneration++;
    _initializing = true;
    return _resetInProgress ??= _resetResources();
  }

  Future<bool> _resetResources() async {
    // 初始化自己持有资源；等它响应取消并清理后，再处理已就绪的播放器。
    await _initializationInProgress;
    final previous = _controller;
    final source = _localSource;
    previous?.removeListener(_handleControllerValueChanged);
    _controller = null;
    _isBuffering = false;
    _failureMessage = null;
    var released = false;
    try {
      await previous?.dispose();
      await source?.close();
      _localSource = null;
      released = true;
    } on Object {
      _controller = previous;
      _failureMessage = '本地视频资源清理失败';
    } finally {
      _resetInProgress = null;
      _initializing = false;
    }
    if (mounted) setState(() {});
    return released;
  }

  Future<void> _initializeAndPlay() {
    if (_initializing) return Future<void>.value();
    final operation = _runInitialization();
    _initializationInProgress = operation;
    return operation.whenComplete(() {
      if (identical(_initializationInProgress, operation)) {
        _initializationInProgress = null;
      }
    });
  }

  Future<void> _runInitialization() async {
    if (_initializing) return;
    final generation = ++_initializationGeneration;
    final uri = Uri.tryParse(widget.url);
    if (!mounted ||
        (widget.item?.isLocal != true &&
            (uri == null || uri.scheme != 'https'))) {
      return;
    }
    setState(() {
      _initializing = true;
      _failureMessage = null;
    });
    VideoPlayerController? controller;
    SquareLocalVideoSource? source;
    try {
      if (_localSource != null) throw StateError('上次本地视频资源尚未清理');
      final capability = await const MethodChannelSquareVideoBridge()
          .capabilities();
      if (!capability.canDecodeHevc) {
        throw const SquareApiException('当前设备不支持播放 HEVC 视频');
      }
      if (widget.item?.isLocal == true) {
        source = await SquareLocalVideoSource.open(
          widget.item!,
          isCurrent: () => mounted && generation == _initializationGeneration,
        );
      }
      if (!mounted || generation != _initializationGeneration) {
        await source?.close();
        return;
      }
      // 原生文件播放器不经过任何HTTP服务；初始化期间资源由本次操作持有。
      controller = source == null
          ? VideoPlayerController.networkUrl(uri!)
          : VideoPlayerController.file(source.file);
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      if (!mounted || generation != _initializationGeneration) {
        await controller.dispose();
        await source?.close();
        return;
      }
      _controller = controller;
      _localSource = source;
      controller.addListener(_handleControllerValueChanged);
      _isBuffering = controller.value.isBuffering;
      await controller.play();
    } on Object catch (error) {
      var cleanupFailed = false;
      try {
        await controller?.dispose();
        await source?.close();
      } on Object {
        cleanupFailed = true;
        _controller = controller;
        if (source != null) _localSource = source;
        if (!mounted) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: StateError('本地视频资源清理失败'),
              library: '公民广场视频',
            ),
          );
        }
      }
      if (mounted && generation == _initializationGeneration) {
        if (!cleanupFailed) _controller = null;
        if (!cleanupFailed && identical(_localSource, source)) {
          _localSource = null;
        }
        _isBuffering = false;
        _failureMessage = cleanupFailed
            ? '本地视频资源清理失败'
            : error is SquareApiException
            ? error.message
            : widget.item?.isLocal == true
            ? '本地视频读取失败'
            : '加载失败，点击重试';
      }
    } finally {
      if (mounted && generation == _initializationGeneration) {
        setState(() => _initializing = false);
      }
    }
  }

  @override
  void dispose() {
    _initializationGeneration++;
    _controller?.removeListener(_handleControllerValueChanged);
    _releaseOnDispose();
    super.dispose();
  }

  // 必须先完成播放器释放，再删除其正在读取的文件。
  Future<void> _releaseOnDispose() async {
    try {
      await _initializationInProgress;
      await _resetInProgress;
      final controller = _controller;
      final source = _localSource;
      await controller?.dispose();
      await source?.close();
    } on Object {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('本地视频资源清理失败'),
          library: '公民广场视频',
        ),
      );
    }
  }

  void _handleControllerValueChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final value = controller.value;
    final nextFailure = value.hasError
        ? (widget.item?.isLocal == true ? '本地视频读取失败' : '加载失败，点击重试')
        : _failureMessage;
    if (_isBuffering == value.isBuffering && nextFailure == _failureMessage) {
      return;
    }
    setState(() {
      _isBuffering = value.isBuffering;
      _failureMessage = nextFailure;
    });
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Future<void> _handleTap() async {
    if (_initializing) return;
    if (_failureMessage != null) {
      if (!await _reset()) return;
      await _initializeAndPlay();
      return;
    }
    if (_controller == null) {
      await _initializeAndPlay();
    } else {
      _togglePlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _initializing ? null : _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (widget.item?.isLocal == true)
            SquareMediaImage(item: widget.item!, preview: true)
          else if (Uri.tryParse(widget.thumbnailUrl ?? '')?.scheme == 'https')
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppTheme.surfaceElevated),
            )
          else
            const ColoredBox(color: AppTheme.surfaceElevated),
          if (initialized)
            Align(
              alignment: Alignment.bottomCenter,
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
              ),
            ),
          Center(
            child: _initializing || _isBuffering
                ? const CircularProgressIndicator(color: Colors.white)
                : _failureMessage != null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        _failureMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : Icon(
                    controller?.value.isPlaying == true
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 按CID、帖子、槽位查找数据库媒体，实际字节不来自URL。
Future<SquareStoredMedia?> _localMedia(
  SquareMediaItem item,
  String role,
) async {
  if (!item.isLocal) throw ArgumentError('缺少本地媒体归属');
  const store = SquareMediaStore();
  final refs = await store.referencesForContent(
    cidNumber: item.cidNumber!,
    contentKind: 'post',
    contentId: item.postId!,
  );
  final selected = refs
      .where((r) => r.mediaIndex == item.mediaIndex && r.mediaRole == role)
      .toList();
  if (selected.isEmpty) return null;
  if (selected.length != 1) throw StateError('媒体槽位重复');
  final media = await store.get(
    cidNumber: item.cidNumber!,
    mediaId: selected.single.mediaId,
  );
  if (media == null || !media.complete) return null;
  if (media.mediaKind !=
      (role == 'main' && item.mediaKind == SquareMediaKind.video
          ? 'video'
          : 'image')) {
    throw StateError('媒体类型不一致');
  }
  return media;
}

/// 图片统一展示适配。本地来源缺失或损坏时不隐式联网。
class SquareMediaImage extends StatefulWidget {
  const SquareMediaImage({
    super.key,
    required this.item,
    this.preview = false,
    this.fit = BoxFit.cover,
  });
  final SquareMediaItem item;
  final bool preview;
  final BoxFit fit;
  @override
  State<SquareMediaImage> createState() => _SquareMediaImageState();
}

class _SquareMediaImageState extends State<SquareMediaImage> {
  Future<Uint8List?>? _bytes;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant SquareMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item || oldWidget.preview != widget.preview) {
      _reload();
    }
  }

  void _reload() {
    _bytes = widget.item.isLocal ? _read(widget.item, widget.preview) : null;
  }

  Future<Uint8List?> _read(SquareMediaItem item, bool preview) async {
    final role = item.mediaKind == SquareMediaKind.video
        ? 'cover'
        : preview
        ? 'thumbnail'
        : 'main';
    final media = await _localMedia(item, role);
    if (media == null) return null;
    final limit = role == 'main'
        ? SquareMediaPolicy.spark.imageMaxBytes
        : 4 * 1024 * 1024; // 与显式同步的衍生图接收上限一致。
    if (media.byteSize > limit) throw StateError('图片大小无效');
    final bytes = BytesBuilder(copy: false);
    for (
      var offset = 0;
      offset < media.byteSize;
      offset += SquareMediaStore.chunkSize
    ) {
      bytes.add(
        await const SquareMediaStore().readRange(
          cidNumber: media.cidNumber,
          mediaId: media.mediaId,
          offset: offset,
          length: math.min(SquareMediaStore.chunkSize, media.byteSize - offset),
        ),
      );
    }
    return bytes.takeBytes();
  }

  Widget _message(String text) => ColoredBox(
    color: AppTheme.surfaceElevated,
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (widget.item.isLocal) {
      return FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _message('本地媒体读取失败');
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(color: AppTheme.surfaceElevated);
          }
          final bytes = snapshot.data;
          if (bytes == null) return _message('本地尚未保存媒体');
          return Image.memory(
            bytes,
            fit: widget.fit,
            errorBuilder: (_, _, _) => _message('本地媒体读取失败'),
          );
        },
      );
    }
    final url = widget.item.mediaKind == SquareMediaKind.video
        ? widget.item.coverUrl
        : widget.item.url;
    if (url == null || Uri.tryParse(url)?.scheme != 'https') {
      return _message('媒体不可用');
    }
    return Image.network(
      url,
      fit: widget.fit,
      errorBuilder: (_, _, _) => _message('媒体加载失败'),
    );
  }
}

/// 本地视频逐块校验后写入原生预先保护的临时文件，不开启网络监听。
class SquareLocalVideoSource {
  SquareLocalVideoSource._(this.file, this._bridge);
  final File file;
  final MethodChannelSquareVideoBridge _bridge;
  bool _closed = false;
  Future<void>? _closing;
  static final _failedCleanup = <SquareLocalVideoSource>{};

  static Future<SquareLocalVideoSource> open(
    SquareMediaItem item, {
    bool Function()? isCurrent,
  }) async {
    if (item.mediaKind != SquareMediaKind.video) throw ArgumentError('不是视频');
    for (final pending in _failedCleanup.toList()) {
      await pending.close();
    }
    final media = await _localMedia(item, 'main');
    if (media == null) throw StateError('本地尚未保存视频');
    void checkCurrent() {
      if (isCurrent?.call() == false) throw StateError('本地视频播放已取消');
    }

    checkCurrent();
    const bridge = MethodChannelSquareVideoBridge();
    final file = await bridge.preparePlaybackFile(media.byteSize);
    final source = SquareLocalVideoSource._(file, bridge);
    RandomAccessFile? output;
    try {
      checkCurrent();
      output = await file.open(mode: FileMode.writeOnly);
      for (var offset = 0; offset < media.byteSize;) {
        checkCurrent();
        final length = math.min(
          SquareMediaStore.chunkSize,
          media.byteSize - offset,
        );
        final bytes = await const SquareMediaStore().readRange(
          cidNumber: media.cidNumber,
          mediaId: media.mediaId,
          offset: offset,
          length: length,
        );
        try {
          checkCurrent();
          if (bytes.length != length) throw StateError('本地视频长度不一致');
          await output.writeFrom(bytes);
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
        offset += length;
      }
      await output.flush();
      await output.close();
      output = null;
      checkCurrent();
      await bridge.verifyPlaybackFile(file, media.byteSize);
      checkCurrent();
      return source;
    } on Object {
      try {
        await output?.close();
      } finally {
        await source.close();
      }
      rethrow;
    }
  }

  Future<void> close() {
    if (_closed) return Future<void>.value();
    return _closing ??= _delete();
  }

  Future<void> _delete() async {
    try {
      await _bridge.deletePlaybackFile(file);
      _closed = true;
      _failedCleanup.remove(this);
    } on Object {
      _failedCleanup.add(this);
      rethrow;
    } finally {
      _closing = null;
    }
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.scaled(context, 8),
        vertical: AppLayout.scaled(context, 2),
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(0x80),
        borderRadius: BorderRadius.circular(AppLayout.scaledValue(20)),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: AppLayout.scaled(context, 12),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
