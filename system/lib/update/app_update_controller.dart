import 'package:flutter/foundation.dart';
import 'package:citizen_system/app_log.dart';
import 'package:citizen_system/update/app_update_manifest.dart';
import 'package:citizen_system/update/app_update_service.dart';

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
