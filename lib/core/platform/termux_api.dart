/// How Termux was installed, which decides whether the one-tap setup can work
/// (设计文档 §10.5 坑：必须 F-Droid/GitHub 版，Play 版已废弃跑不通).
enum TermuxVariant {
  /// Not installed (or not an Android device).
  absent,

  /// Installed from F-Droid (`org.fdroid.fdroid`) — supported.
  fdroid,

  /// Installed from Google Play (`com.android.vending`) — the **deprecated**
  /// build; package management / RUN_COMMAND don't work, so we warn the user.
  play,

  /// Installed but the installer source is unknown — typically a GitHub /
  /// sideloaded APK, which is the supported case (treated as OK with a hint).
  unknown,
}

/// The result of probing for a Termux install.
class TermuxInstallStatus {
  const TermuxInstallStatus({
    required this.installed,
    required this.variant,
    this.installer,
  });

  /// Whether `com.termux` is present on the device.
  final bool installed;

  /// Best guess at the install source (see [TermuxVariant]).
  final TermuxVariant variant;

  /// The raw installer package name (e.g. `org.fdroid.fdroid`), or null.
  final String? installer;

  /// True when the install is the deprecated Play build that can't run the
  /// setup script.
  bool get isUnsupportedPlayBuild => variant == TermuxVariant.play;
}

/// Detects whether (and how) Termux is installed, so the Termux one-tap flow can
/// guide the user (设计文档 §10.5 / Termux-A 步骤 a).
///
/// Android-only via a platform channel; implementations live under `impl/`. The
/// interface stays pure Dart so callers depend on the abstraction and tests can
/// substitute a fake (ADR-0007).
abstract interface class TermuxApi {
  Future<TermuxInstallStatus> detect();
}
