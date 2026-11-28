// 更新状态、徽标及公开入口。

export 'package:citizen_system/update/service.dart';
import 'package:citizen_system/log.dart';
import 'package:citizen_system/update/service.dart';
import 'package:flutter/material.dart';
import 'package:citizen_system/theme.dart';

// 导出应用商店更新相关接口和模型。

// 维护设备版本和商店更新状态，保留查询失败及重试。

enum AppUpdateStatus { idle, checking, available, opening, error }

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    this.currentVersion,
    this.update,
    this.errorMessage,
  });
  const AppUpdateState.idle()
    : status = AppUpdateStatus.idle,
      currentVersion = null,
      update = null,
      errorMessage = null;
  final AppUpdateStatus status;
  final AppVersionInfo? currentVersion;
  final AppUpdateInfo? update;
  final String? errorMessage;
  bool get hasUpdate => update != null;
  String get versionLabel => currentVersion?.label ?? 'v...';
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController._({AppUpdateService? service})
    : _service = service ?? AppUpdateService();
  @visibleForTesting
  factory AppUpdateController.forTesting({required AppUpdateService service}) =>
      AppUpdateController._(service: service);
  static final AppUpdateController instance = AppUpdateController._();
  final AppUpdateService _service;
  AppUpdateState _state = const AppUpdateState.idle();
  AppUpdateState get state => _state;

  Future<void> check({bool force = false}) async {
    if (_state.status == AppUpdateStatus.opening ||
        (!force && _state.status == AppUpdateStatus.checking)) {
      return;
    }
    var current = _state.currentVersion;
    var knownUpdate = _state.update;
    _setState(
      AppUpdateState(
        status: AppUpdateStatus.checking,
        currentVersion: current,
        update: knownUpdate,
      ),
    );
    try {
      final installed = await _service.readCurrentVersion();
      if (installed.versionName != current?.versionName ||
          installed.versionCode != current?.versionCode) {
        knownUpdate = null;
      }
      current = installed;
      // 先显示设备版本，商店断网或尚未上架不会改变它。
      _setState(
        AppUpdateState(
          status: AppUpdateStatus.checking,
          currentVersion: current,
          update: knownUpdate,
        ),
      );
      final update = await _service.checkUpdate(current);
      _setState(
        AppUpdateState(
          status: update == null
              ? AppUpdateStatus.idle
              : AppUpdateStatus.available,
          currentVersion: current,
          update: update,
        ),
      );
    } catch (error) {
      AppLog.d('[AppUpdate] 商店检查失败: $error');
      _setState(
        AppUpdateState(
          status: AppUpdateStatus.error,
          currentVersion: current,
          update: knownUpdate,
          errorMessage: '检查商店更新失败：$error',
        ),
      );
    }
  }

  Future<bool> openStore() async {
    if (!_state.hasUpdate || _state.status == AppUpdateStatus.opening) {
      return false;
    }
    final update = _state.update;
    _setState(
      AppUpdateState(
        status: AppUpdateStatus.opening,
        currentVersion: _state.currentVersion,
        update: update,
      ),
    );
    try {
      final opened = await _service.openStore();
      _setState(
        AppUpdateState(
          status: opened ? AppUpdateStatus.available : AppUpdateStatus.error,
          currentVersion: _state.currentVersion,
          update: update,
          errorMessage: opened ? null : '无法打开应用商店',
        ),
      );
      return opened;
    } catch (error) {
      _setState(
        AppUpdateState(
          status: AppUpdateStatus.error,
          currentVersion: _state.currentVersion,
          update: update,
          errorMessage: '无法打开应用商店：$error',
        ),
      );
      return false;
    }
  }

  void _setState(AppUpdateState state) {
    _state = state;
    notifyListeners();
  }
}

// 根据当前可安装更新状态显示提醒红点。

/// 更新提醒红点，只表达“当前仍有可安装更新”。
///
/// 红点不承担已读状态；是否显示完全由更新检查结果驱动。
class UpdateDotBadge extends StatelessWidget {
  const UpdateDotBadge({
    super.key,
    required this.show,
    required this.child,
    this.dotKey,
  });

  final bool show;
  final Widget child;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            key: dotKey,
            width: AppLayout.scaled(context, 8),
            height: AppLayout.scaled(context, 8),
            decoration: BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.surfaceCard, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
