import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/shared/domain/parameter_metadata.dart';

part 'parameter_settings.freezed.dart';
part 'parameter_settings.g.dart';

/// Persisted parameter configuration — stores both values and enabled flags for
/// every parameter key. A port of the web's `ParameterSyncService` cache.
///
/// Values and enabled flags live in two `Map`s so that adding new parameters to
/// [kParameterMetadata] does not require touching this class. Defaults are
/// resolved at read-time via [getParameterValue] / [isParameterEnabled] falling
/// back to the metadata table.
@freezed
abstract class ParameterSettings with _$ParameterSettings {
  const ParameterSettings._();

  const factory ParameterSettings({
    /// Parameter values keyed by [ParameterMeta.key]. Absent entries fall back
    /// to the metadata default.
    @Default(<String, dynamic>{}) Map<String, dynamic> values,

    /// Enabled flags keyed by [ParameterMeta.key]. Absent entries fall back to
    /// [ParameterMeta.defaultEnabled].
    @Default(<String, bool>{}) Map<String, bool> enabledFlags,

    /// Custom user-defined parameters as a list of `{name, value, type}` maps.
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> customParameters,
  }) = _ParameterSettings;

  factory ParameterSettings.fromJson(Map<String, dynamic> json) =>
      _$ParameterSettingsFromJson(json);

  // ── Convenience accessors ─────────────────────────────────────────────────

  /// Returns the current value for [key], falling back to the metadata default.
  Object? getParameterValue(String key) {
    if (values.containsKey(key)) return values[key];
    final meta = _metaFor(key);
    return meta?.defaultValue;
  }

  /// Whether [key] is enabled. Falls back to [ParameterMeta.defaultEnabled].
  bool isParameterEnabled(String key) {
    if (enabledFlags.containsKey(key)) return enabledFlags[key]!;
    final meta = _metaFor(key);
    return meta?.defaultEnabled ?? false;
  }

  static ParameterMeta? _metaFor(String key) {
    for (final m in kParameterMetadata) {
      if (m.key == key) return m;
    }
    return null;
  }
}
