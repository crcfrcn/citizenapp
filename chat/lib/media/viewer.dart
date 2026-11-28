// 展示聊天图片和视频，并保留系统相册保存入口。

import 'dart:io';

import 'package:citizen_system/theme.dart';
import 'package:flutter/material.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:video_player/video_player.dart';

// 将已接收的本机图片或视频保存到系统相册。

/// 把已收到的本机媒体文件保存到系统相册。相册写入权限已在采集步骤声明。
typedef GallerySaveFn = Future<bool> Function({
  required String filePath,
  required String fileName,
});

class MediaGallerySaver {
  const MediaGallerySaver();

  /// 保存成功返回 true。图片与视频统一走 saveFile(按 mime 归相册)。
  Future<bool> saveToGallery({
    required String filePath,
    required String fileName,
  }) async {
    final result = await SaverGallery.saveFile(
      filePath: filePath,
      fileName: fileName,
      skipIfExists: false,
    );
    return result.isSuccess;
  }
}

// 全屏缩放查看图片，按屏幕尺寸解码并提供相册保存。

/// 图片全屏查看:捏合缩放(InteractiveViewer)+ 保存到相册。
///
/// 用屏幕物理像素做 `cacheWidth` 降采样解码——即便原图 100MB,也只解码到屏幕
/// 尺寸的位图,不整解码。保存动作可注入以便测试。
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({
    super.key,
    required this.filePath,
    required this.fileName,
    GallerySaveFn? onSaveToGallery,
  }) : _onSaveToGallery = onSaveToGallery;

  final String filePath;
  final String fileName;
  final GallerySaveFn? _onSaveToGallery;

  Future<void> _save(BuildContext context) async {
    final saver = _onSaveToGallery ?? const MediaGallerySaver().saveToGallery;
    final ok = await saver(filePath: filePath, fileName: fileName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')));
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (MediaQuery.of(context).size.width * ratio).round();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '保存到相册',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _save(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_rounded,
              color: Colors.white54,
              size: AppLayout.scaled(context, 48),
            ),
          ),
        ),
      ),
    );
  }
}

// 播放本机视频并提供保存到相册操作。

/// 视频播放页:video_player 播放 + 保存到相册。
///
/// 视频播放依赖 native 平台通道,以真机/集成验证为准(单测不驱动 native controller)。
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.filePath,
    required this.fileName,
    this.onSaveToGallery,
  });

  final String filePath;
  final String fileName;
  final GallerySaveFn? onSaveToGallery;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _startPlayback();
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() => _error = '无法播放该视频');
        });
  }

  void _startPlayback() {
    _controller.setLooping(true);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saver =
        widget.onSaveToGallery ?? const MediaGallerySaver().saveToGallery;
    final ok = await saver(
      filePath: widget.filePath,
      fileName: widget.fileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')));
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '保存到相册',
            icon: const Icon(Icons.download_rounded),
            onPressed: _save,
          ),
        ],
      ),
      body: Center(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.white70));
    }
    if (!_ready) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
