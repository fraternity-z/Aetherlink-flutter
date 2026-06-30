import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'perf_monitor_controller.g.dart';

/// Storage key for the 显示性能监控 toggle (外观设置 → 开发者工具). A scalar
/// `'true' | 'false'` flag, mirroring the web's `settings.showPerformanceMonitor`.
const String kPerfMonitorSettingKey = 'showPerformanceMonitor';

/// Holds whether the in-app performance overlay is enabled, so the appearance
/// page stays a pure view and the app shell can react to the flag.
///
/// Defaults to off. Hydrated from the Drift key/value store on first build and
/// written through on every change, so the choice survives a restart.
///
/// `keepAlive: true`: an app-level preference read by both the settings page and
/// the app shell (which starts/stops [PerfMonitor] and mounts the overlay), so
/// it must outlive the settings page being disposed.
@Riverpod(keepAlive: true)
class PerfMonitorController extends _$PerfMonitorController {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kPerfMonitorSettingKey);
    if (stored == 'true') state = true;
  }

  /// Toggles the performance overlay; the 显示性能监控 switch calls this.
  void set(bool value) {
    state = value;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kPerfMonitorSettingKey, value.toString());
  }
}
