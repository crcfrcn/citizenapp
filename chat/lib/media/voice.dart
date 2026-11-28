// 保留聊天语音录制、播放及资源生命周期。

import 'dart:async';
import 'dart:io';

import 'package:chat/models.dart';
import 'package:citizen_system/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// 播放本机已解密语音，缺失时触发原附件下载。

/// 本机已解密语音文件播放器。未到达时只触发既有附件下载，不读取远程明文 URL。
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.onRequestDownload,
  });

  final AudioMessage message;
  final bool isSentByMe;
  final Future<void> Function() onRequestDownload;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  bool _loaded = false;
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(
        () => _playing =
            state.playing && state.processingState != ProcessingState.completed,
      );
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.source != widget.message.source) {
      _loaded = false;
      _position = Duration.zero;
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_loading) return;
    if (widget.message.source.isEmpty) {
      setState(() => _loading = true);
      try {
        await widget.onRequestDownload();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    try {
      if (!_loaded) {
        await _player.setFilePath(widget.message.source);
        _loaded = true;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('语音无法播放，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.message.duration.inMilliseconds <= 0
        ? const Duration(seconds: 1)
        : widget.message.duration;
    final progress = (_position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final color = widget.isSentByMe
        ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.surface;
    return Semantics(
      button: true,
      label: '${widget.message.duration.inSeconds}秒语音消息',
      child: InkWell(
        key: ValueKey('chat-audio-${widget.message.id}'),
        borderRadius: BorderRadius.circular(AppLayout.scaled(context, 18)),
        onTap: _handleTap,
        child: Container(
          width: AppLayout.scaled(
            context,
            126 + widget.message.duration.inSeconds.clamp(0, 60) * 1.4,
          ),
          constraints: BoxConstraints(
            minWidth: AppLayout.scaled(context, 126),
            maxWidth: MediaQuery.sizeOf(context).width * 0.68,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.scaled(context, 13),
            vertical: AppLayout.scaled(context, 11),
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppLayout.scaled(context, 18)),
          ),
          child: Row(
            children: [
              if (_loading)
                SizedBox.square(
                  dimension: AppLayout.scaled(context, 22),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  widget.message.source.isEmpty
                      ? Icons.download_rounded
                      : _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              SizedBox(width: AppLayout.scaled(context, 8)),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: AppLayout.scaled(context, 3),
                  borderRadius: BorderRadius.circular(
                    AppLayout.scaled(context, 2),
                  ),
                  color: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.18),
                ),
              ),
              SizedBox(width: AppLayout.scaled(context, 8)),
              Text(
                '${widget.message.duration.inSeconds.clamp(1, 180)}″',
                style: TextStyle(
                  fontSize: AppLayout.scaled(context, 12),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 录制限时单声道AAC语音，自动停止并在取消后删除临时明文。

class VoiceRecordingResult {
  const VoiceRecordingResult({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

class VoiceRecordingState {
  const VoiceRecordingState({required this.recording, required this.duration});

  static const idle = VoiceRecordingState(
    recording: false,
    duration: Duration.zero,
  );

  final bool recording;
  final Duration duration;
}

class VoicePermissionDeniedException implements Exception {
  const VoicePermissionDeniedException();

  @override
  String toString() => '请在系统设置中允许麦克风权限';
}

/// Chat 语音录制唯一控制器：AAC-LC 单声道、三分钟自动停止、取消即删临时明文。
class VoiceRecorder {
  VoiceRecorder({
    AudioRecorder? recorder,
    this.maximumDuration = defaultMaximumDuration,
    this.onMaximumReached,
  }) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  static const defaultMaximumDuration = chatMessageMaximumDuration;
  final Duration maximumDuration;
  final Future<void> Function(VoiceRecordingResult result)? onMaximumReached;
  final ValueNotifier<VoiceRecordingState> state = ValueNotifier(
    VoiceRecordingState.idle,
  );

  Timer? _timer;
  Stopwatch? _stopwatch;
  String? _path;
  Future<void>? _startOperation;
  bool _finishing = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed ||
        state.value.recording ||
        _finishing ||
        _startOperation != null) {
      return;
    }
    late final Future<void> created;
    created = _startInternal();
    _startOperation = created;
    try {
      await created;
    } finally {
      if (identical(_startOperation, created)) _startOperation = null;
    }
  }

  Future<void> _startInternal() async {
    if (!await _recorder.hasPermission()) {
      throw const VoicePermissionDeniedException();
    }
    if (_disposed) return;
    final directory = await getTemporaryDirectory();
    if (_disposed) return;
    final path =
        '${directory.path}/chat-voice-'
        '${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    if (_disposed) {
      await _recorder.cancel();
      await _deleteIfPresent(path);
      return;
    }
    _path = path;
    _stopwatch = Stopwatch()..start();
    state.value = const VoiceRecordingState(
      recording: true,
      duration: Duration.zero,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed = _stopwatch?.elapsed ?? Duration.zero;
      state.value = VoiceRecordingState(
        recording: true,
        duration: elapsed > maximumDuration ? maximumDuration : elapsed,
      );
      if (elapsed >= maximumDuration) unawaited(_finishAtLimit());
    });
  }

  Future<VoiceRecordingResult?> stop({bool cancel = false}) async {
    if (!state.value.recording || _finishing) return null;
    _finishing = true;
    _timer?.cancel();
    _stopwatch?.stop();
    final duration = _stopwatch?.elapsed ?? Duration.zero;
    final expectedPath = _path;
    try {
      if (cancel) {
        await _recorder.cancel();
        await _deleteIfPresent(expectedPath);
        return null;
      }
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? expectedPath;
      if (path == null || !await File(path).exists()) {
        throw StateError('语音录制文件不存在');
      }
      return VoiceRecordingResult(
        path: path,
        duration: duration > maximumDuration ? maximumDuration : duration,
      );
    } finally {
      _timer = null;
      _stopwatch = null;
      _path = null;
      _finishing = false;
      state.value = VoiceRecordingState.idle;
    }
  }

  Future<void> cancel() async {
    await stop(cancel: true);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _startOperation;
    } catch (_) {
      // 启动失败仍必须继续释放原生录音器。
    }
    await cancel();
    await _recorder.dispose();
    state.dispose();
  }

  Future<void> _finishAtLimit() async {
    final result = await stop();
    if (result != null) await onMaximumReached?.call(result);
  }
}

Future<void> _deleteIfPresent(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
