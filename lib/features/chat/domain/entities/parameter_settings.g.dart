// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parameter_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ParameterSettings _$ParameterSettingsFromJson(Map<String, dynamic> json) =>
    _ParameterSettings(
      values:
          json['values'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      enabledFlags:
          (json['enabledFlags'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const <String, bool>{},
      customParameters:
          (json['customParameters'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const <Map<String, dynamic>>[],
    );

Map<String, dynamic> _$ParameterSettingsToJson(_ParameterSettings instance) =>
    <String, dynamic>{
      'values': instance.values,
      'enabledFlags': instance.enabledFlags,
      'customParameters': instance.customParameters,
    };
