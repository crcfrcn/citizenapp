import 'dart:async';
import 'dart:io' show Platform;

import 'package:citizen_sdk/citizen_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:citizen_system/theme/app_theme.dart';
import 'package:citizen_system/theme/app_layout.dart';

/// 公民链状态读取与交易顶栏唯一可见状态。
///
/// 所有调用方订阅同一 SDK 会话状态；只有交易 Tab 设置
/// [showInlineStatus] 后可见，其他页面只读取状态，不渲染连接状态 UI。
class ChainProgressBanner extends StatefulWidget {
  const ChainProgressBanner({
    super.key,
    this.margin = EdgeInsets.zero,
    this.busy = false,
    this.showInlineStatus = false,
    this.onProgressChanged,
    this.onErrorChanged,
    this.progress,
  });

  final EdgeInsetsGeometry margin;
  final bool busy;

  /// 是否在交易 Tab 顶栏显示唯一的全局链状态。
  ///
  /// 默认关闭；不可见调用方仍会读取链状态并回传给业务门禁。
  final bool showInlineStatus;
  final ValueChanged<CitizenChainSyncStatus?>? onProgressChanged;
  final ValueChanged<String?>? onErrorChanged;

  /// 专项测试注入；生产订阅 [CitizenSdk.watchSyncStatus]。
  final Stream<CitizenChainSyncStatus>? progress;

  @override
  State<ChainProgressBanner> createState() => _ChainProgressBannerState();
}

class _ChainProgressBannerState extends State<ChainProgressBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathingController;
  CitizenChainSyncStatus? _progress;
  String? _error;
  StreamSubscription<CitizenChainSyncStatus>? _subscription;
  CitizenSdk? _sdk;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.35,
      upperBound: 1,
    );
    // Widget test 中不启动无限动画，避免 pumpAndSettle 无法稳定；真机保持呼吸效果。
    if (widget.showInlineStatus && !_isTestProcess) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sdk = context.watch<CitizenSdk?>();
    if (sdk != _sdk || _subscription == null) {
      _sdk = sdk;
      _subscribe();
    }
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = (widget.progress ?? _sdk?.watchSyncStatus())?.listen(
      (progress) {
        if (!mounted) return;
        setState(() { _progress = progress; _error = null; });
        widget.onProgressChanged?.call(progress);
        widget.onErrorChanged?.call(null);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _error = _chainErrorMessage(error));
        widget.onProgressChanged?.call(_progress);
        widget.onErrorChanged?.call(_error);
      },
    );
  }

  @override
  void didUpdateWidget(covariant ChainProgressBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showInlineStatus != oldWidget.showInlineStatus &&
        !_isTestProcess) {
      if (widget.showInlineStatus) {
        _breathingController.repeat(reverse: true);
      } else {
        _breathingController.stop();
      }
    }
    if (oldWidget.progress != widget.progress) _subscribe();
    if (widget.busy && !oldWidget.busy) unawaited(_sdk?.refreshSyncStatus());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showInlineStatus) return const SizedBox.shrink();
    return _buildInlineStatus(progress: _progress, error: _error);
  }

  bool get _isTestProcess => Platform.environment.containsKey('FLUTTER_TEST');

  ({Color color, String semanticsStatus}) _resolveState({
    required CitizenChainSyncStatus? progress,
    required String? error,
  }) {
    if (error != null) {
      return (color: AppTheme.danger, semanticsStatus: '连接失败');
    }
    if (progress?.isUsable == true) {
      return (color: AppTheme.success, semanticsStatus: '连接正常');
    }
    return (color: AppTheme.info, semanticsStatus: '正在连接');
  }

  Widget _buildInlineStatus({
    required CitizenChainSyncStatus? progress,
    required String? error,
  }) {
    final state = _resolveState(progress: progress, error: error);
    final finalizedBlockNumber = progress?.finalized.number;
    final detail = '最终区块 ${finalizedBlockNumber ?? '—'}';

    return Semantics(
      key: const ValueKey<String>('transaction-chain-status-inline'),
      excludeSemantics: true,
      label: '公民链${state.semanticsStatus}，$detail',
      child: Padding(
        padding: widget.margin,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _breathingController,
                      builder: (context, _) {
                        final opacity =
                            _isTestProcess ? 1.0 : _breathingController.value;
                        return SizedBox(
                          width: AppLayout.scaled(context, 18),
                          height: AppLayout.scaled(context, 18),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: opacity * 0.22,
                                child: Container(
                                  width: AppLayout.scaled(context, 16),
                                  height: AppLayout.scaled(context, 16),
                                  decoration: BoxDecoration(
                                    color: state.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Container(
                                width: AppLayout.scaled(context, 8),
                                height: AppLayout.scaled(context, 8),
                                decoration: BoxDecoration(
                                  color: state.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(width: AppLayout.scaledValue(6)),
                    Flexible(
                      child: Text(
                        '公民链',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: state.color,
                          fontSize: AppLayout.scaledValue(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 两段之间的固定空隙以顶栏几何中心为中点，确保视觉轴线落在屏幕中央。
            SizedBox(
              key:
                  const ValueKey<String>('transaction-chain-status-center-gap'),
              width: AppLayout.scaledValue(10),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                // 状态栏保持中心轴线不变；极端大字体下截断视觉副本，完整信息仍由
                // 外层 Semantics.label 提供，禁止反向缩小系统文字。
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: state.color,
                    fontSize: AppLayout.scaledValue(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _chainErrorMessage(Object error) {
    if (error is CitizenSdkException && error.message.isNotEmpty) {
      return error.message;
    }
    return '公民链状态暂时不可用';
  }
}
