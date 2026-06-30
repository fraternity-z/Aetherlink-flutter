import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'dev_tools_button_controller.g.dart';

/// Storage key for the 显示开发者工具悬浮按钮 toggle (外观设置 → 开发者工具).
/// A scalar `'true' | 'false'` flag, mirroring the web's
/// `settings.showDevToolsFloatingButton`.
const String kDevToolsButtonSettingKey = 'showDevToolsFloatingButton';

/// Holds whether the draggable developer-tools entry button is shown, so the
/// appearance page stays a pure view and the app shell can mount/remove it.
///
/// Defaults to off. Hydrated from the Drift key/value store on first build and
/// written through on every change, so the choice survives a restart.
///
/// `keepAlive: true`: an app-level preference read by both the settings page and
/// the app shell (which mounts the floating button), so it must outlive the
/// settings page being disposed — same lifecycle as [PerfMonitorController].
@Riverpod(keepAlive: true)
class DevToolsButtonController extends _$DevToolsButtonController {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kDevToolsButtonSettingKey);
    if (stored == 'true') state = true;
  }

  /// Toggles the floating button; the 显示开发者工具悬浮按钮 switch calls this.
  void set(bool value) {
    state = value;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kDevToolsButtonSettingKey, value.toString());
  }
}
