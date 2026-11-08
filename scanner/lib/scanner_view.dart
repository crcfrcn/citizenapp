import 'dart:async';

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/widgets.dart';

import 'package:citizen_scanner/scanner_failure.dart';

/// 原扫码页面的预览承载；相机、识别和权限完全由SDK资源提供。
/// 这里只绘制Texture、转发前后台和页面资源关闭，不实现摄像或二维码解析。
class ScannerView extends StatefulWidget {
  const ScannerView({
    super.key,
    required this.qr,
    required this.purpose,
    required this.onResult,
    this.onFailure,
    this.onCapture,
  });
  final CitizenSdk qr;
  final CitizenQrScanPurpose purpose;
  final ValueChanged<CitizenQrScanResult> onResult;
  final ValueChanged<ScannerFailure>? onFailure;
  final ValueChanged<CitizenQrCapture?>? onCapture;
  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> with WidgetsBindingObserver {
  CitizenQrCapture? _capture;
  Future<void>? _opening;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _generation = 0;
  int _lifecycle = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleOpen();
  }

  @override
  void didUpdateWidget(covariant ScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.qr, widget.qr) ||
        oldWidget.purpose != widget.purpose) {
      _scheduleOpen();
    }
  }

  void _scheduleOpen() {
    ++_lifecycle;
    final generation = ++_generation;
    final previous = _opening;
    final qr = widget.qr;
    final purpose = widget.purpose;
    _opening = () async {
      if (previous != null) await previous;
      await _release();
      if (!mounted || generation != _generation) return;
      try {
        final capture = await qr.openQrCapture(purpose);
        if (!mounted || generation != _generation) {
          await capture.close();
          return;
        }
        _capture = capture;
        _subscriptions.add(
          capture.results.listen((result) {
            if (mounted && generation == _generation) {
              widget.onResult(result);
            }
          }, onError: (Object error) => _failure(error, generation)),
        );
        _subscriptions.add(
          capture.errors.listen(
            (error) => _failure(error, generation),
            onError: (Object error) => _failure(error, generation),
          ),
        );
        _subscriptions.add(
          capture.previewChanges.listen((_) {
            if (mounted && generation == _generation) setState(() {});
          }, onError: (Object error) => _failure(error, generation)),
        );
        widget.onCapture?.call(capture);
        if (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          await _updateLifecycle(
            capture,
            WidgetsBinding.instance.lifecycleState!,
            generation,
          );
        }
        if (mounted && generation == _generation) setState(() {});
      } catch (error) {
        _failure(error, generation);
      }
    }().catchError((Object error) => _failure(error, generation));
  }

  void _failure(Object error, int generation) {
    if (mounted && generation == _generation) {
      widget.onFailure?.call(
        ScannerFailure.fromDeviceError(error, operation: '扫码'),
      );
    }
  }

  Future<void> _release() async {
    if (mounted) widget.onCapture?.call(null);
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    final capture = _capture;
    // 同轮撤销监听与关闭真实采集均立即发起，并等待两者排空；不让流取消延后设备关闭。
    await Future.wait<void>([
      for (final subscription in subscriptions) subscription.cancel(),
      if (capture != null) capture.close(),
    ]);
    if (capture != null) {
      // close成功前不丢弃资源所有权；失败仍由SDK会话持有并报告。
      if (identical(capture, _capture)) {
        _capture = null;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final capture = _capture;
    if (capture == null) {
      ++_lifecycle;
      return;
    }
    unawaited(_updateLifecycle(capture, state, _generation));
  }

  Future<void> _updateLifecycle(
    CitizenQrCapture capture,
    AppLifecycleState state,
    int generation,
  ) async {
    final operation = ++_lifecycle;
    try {
      await (state == AppLifecycleState.resumed
          ? capture.resume()
          : capture.pause());
    } on Object catch (error) {
      // 同一资源的旧暂停/恢复失败，也不能污染后续已发起的生命周期操作。
      if (operation == _lifecycle && identical(capture, _capture)) {
        _failure(error, generation);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    ++_lifecycle;
    WidgetsBinding.instance.removeObserver(this);
    // Flutter dispose不能await；SDK仍拥有真实排空，绝不在此伪造资源已关闭。
    final opening = _opening;
    unawaited(() async {
      try {
        if (opening != null) await opening;
        await _release();
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'citizenapp QR preview',
            context: ErrorDescription('关闭SDK摄像资源'),
          ),
        );
      }
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    if (capture == null) return const SizedBox.expand();
    final preview = capture.preview;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: RotatedBox(
            quarterTurns: preview.rotationDegrees ~/ 90,
            child: SizedBox(
              width: preview.width.toDouble(),
              height: preview.height.toDouble(),
              child: Texture(textureId: capture.textureId),
            ),
          ),
        ),
      ),
    );
  }
}
