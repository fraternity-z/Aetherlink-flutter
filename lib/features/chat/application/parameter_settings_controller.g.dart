// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parameter_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the user's parameter configuration — values, enabled flags and
/// custom parameters. Mirrors the web `ParameterSyncService` with Riverpod
/// reactive state + Drift key/value persistence.

@ProviderFor(ParameterSettingsController)
final parameterSettingsControllerProvider =
    ParameterSettingsControllerProvider._();

/// Manages the user's parameter configuration — values, enabled flags and
/// custom parameters. Mirrors the web `ParameterSyncService` with Riverpod
/// reactive state + Drift key/value persistence.
final class ParameterSettingsControllerProvider
    extends $NotifierProvider<ParameterSettingsController, ParameterSettings> {
  /// Manages the user's parameter configuration — values, enabled flags and
  /// custom parameters. Mirrors the web `ParameterSyncService` with Riverpod
  /// reactive state + Drift key/value persistence.
  ParameterSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parameterSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parameterSettingsControllerHash();

  @$internal
  @override
  ParameterSettingsController create() => ParameterSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParameterSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParameterSettings>(value),
    );
  }
}

String _$parameterSettingsControllerHash() =>
    r'ef1888559ec8680146885812a73c9ea486270c86';

/// Manages the user's parameter configuration — values, enabled flags and
/// custom parameters. Mirrors the web `ParameterSyncService` with Riverpod
/// reactive state + Drift key/value persistence.

abstract class _$ParameterSettingsController
    extends $Notifier<ParameterSettings> {
  ParameterSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ParameterSettings, ParameterSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ParameterSettings, ParameterSettings>,
              ParameterSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
