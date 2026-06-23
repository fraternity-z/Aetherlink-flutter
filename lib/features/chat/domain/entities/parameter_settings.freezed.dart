// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'parameter_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ParameterSettings {

/// Parameter values keyed by [ParameterMeta.key]. Absent entries fall back
/// to the metadata default.
 Map<String, dynamic> get values;/// Enabled flags keyed by [ParameterMeta.key]. Absent entries fall back to
/// [ParameterMeta.defaultEnabled].
 Map<String, bool> get enabledFlags;/// Custom user-defined parameters as a list of `{name, value, type}` maps.
 List<Map<String, dynamic>> get customParameters;
/// Create a copy of ParameterSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParameterSettingsCopyWith<ParameterSettings> get copyWith => _$ParameterSettingsCopyWithImpl<ParameterSettings>(this as ParameterSettings, _$identity);

  /// Serializes this ParameterSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParameterSettings&&const DeepCollectionEquality().equals(other.values, values)&&const DeepCollectionEquality().equals(other.enabledFlags, enabledFlags)&&const DeepCollectionEquality().equals(other.customParameters, customParameters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(values),const DeepCollectionEquality().hash(enabledFlags),const DeepCollectionEquality().hash(customParameters));

@override
String toString() {
  return 'ParameterSettings(values: $values, enabledFlags: $enabledFlags, customParameters: $customParameters)';
}


}

/// @nodoc
abstract mixin class $ParameterSettingsCopyWith<$Res>  {
  factory $ParameterSettingsCopyWith(ParameterSettings value, $Res Function(ParameterSettings) _then) = _$ParameterSettingsCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> values, Map<String, bool> enabledFlags, List<Map<String, dynamic>> customParameters
});




}
/// @nodoc
class _$ParameterSettingsCopyWithImpl<$Res>
    implements $ParameterSettingsCopyWith<$Res> {
  _$ParameterSettingsCopyWithImpl(this._self, this._then);

  final ParameterSettings _self;
  final $Res Function(ParameterSettings) _then;

/// Create a copy of ParameterSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? values = null,Object? enabledFlags = null,Object? customParameters = null,}) {
  return _then(_self.copyWith(
values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,enabledFlags: null == enabledFlags ? _self.enabledFlags : enabledFlags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,customParameters: null == customParameters ? _self.customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [ParameterSettings].
extension ParameterSettingsPatterns on ParameterSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParameterSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParameterSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParameterSettings value)  $default,){
final _that = this;
switch (_that) {
case _ParameterSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParameterSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ParameterSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic> values,  Map<String, bool> enabledFlags,  List<Map<String, dynamic>> customParameters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParameterSettings() when $default != null:
return $default(_that.values,_that.enabledFlags,_that.customParameters);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic> values,  Map<String, bool> enabledFlags,  List<Map<String, dynamic>> customParameters)  $default,) {final _that = this;
switch (_that) {
case _ParameterSettings():
return $default(_that.values,_that.enabledFlags,_that.customParameters);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic> values,  Map<String, bool> enabledFlags,  List<Map<String, dynamic>> customParameters)?  $default,) {final _that = this;
switch (_that) {
case _ParameterSettings() when $default != null:
return $default(_that.values,_that.enabledFlags,_that.customParameters);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ParameterSettings extends ParameterSettings {
  const _ParameterSettings({final  Map<String, dynamic> values = const <String, dynamic>{}, final  Map<String, bool> enabledFlags = const <String, bool>{}, final  List<Map<String, dynamic>> customParameters = const <Map<String, dynamic>>[]}): _values = values,_enabledFlags = enabledFlags,_customParameters = customParameters,super._();
  factory _ParameterSettings.fromJson(Map<String, dynamic> json) => _$ParameterSettingsFromJson(json);

/// Parameter values keyed by [ParameterMeta.key]. Absent entries fall back
/// to the metadata default.
 final  Map<String, dynamic> _values;
/// Parameter values keyed by [ParameterMeta.key]. Absent entries fall back
/// to the metadata default.
@override@JsonKey() Map<String, dynamic> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

/// Enabled flags keyed by [ParameterMeta.key]. Absent entries fall back to
/// [ParameterMeta.defaultEnabled].
 final  Map<String, bool> _enabledFlags;
/// Enabled flags keyed by [ParameterMeta.key]. Absent entries fall back to
/// [ParameterMeta.defaultEnabled].
@override@JsonKey() Map<String, bool> get enabledFlags {
  if (_enabledFlags is EqualUnmodifiableMapView) return _enabledFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_enabledFlags);
}

/// Custom user-defined parameters as a list of `{name, value, type}` maps.
 final  List<Map<String, dynamic>> _customParameters;
/// Custom user-defined parameters as a list of `{name, value, type}` maps.
@override@JsonKey() List<Map<String, dynamic>> get customParameters {
  if (_customParameters is EqualUnmodifiableListView) return _customParameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_customParameters);
}


/// Create a copy of ParameterSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParameterSettingsCopyWith<_ParameterSettings> get copyWith => __$ParameterSettingsCopyWithImpl<_ParameterSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParameterSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParameterSettings&&const DeepCollectionEquality().equals(other._values, _values)&&const DeepCollectionEquality().equals(other._enabledFlags, _enabledFlags)&&const DeepCollectionEquality().equals(other._customParameters, _customParameters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_values),const DeepCollectionEquality().hash(_enabledFlags),const DeepCollectionEquality().hash(_customParameters));

@override
String toString() {
  return 'ParameterSettings(values: $values, enabledFlags: $enabledFlags, customParameters: $customParameters)';
}


}

/// @nodoc
abstract mixin class _$ParameterSettingsCopyWith<$Res> implements $ParameterSettingsCopyWith<$Res> {
  factory _$ParameterSettingsCopyWith(_ParameterSettings value, $Res Function(_ParameterSettings) _then) = __$ParameterSettingsCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic> values, Map<String, bool> enabledFlags, List<Map<String, dynamic>> customParameters
});




}
/// @nodoc
class __$ParameterSettingsCopyWithImpl<$Res>
    implements _$ParameterSettingsCopyWith<$Res> {
  __$ParameterSettingsCopyWithImpl(this._self, this._then);

  final _ParameterSettings _self;
  final $Res Function(_ParameterSettings) _then;

/// Create a copy of ParameterSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? values = null,Object? enabledFlags = null,Object? customParameters = null,}) {
  return _then(_ParameterSettings(
values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,enabledFlags: null == enabledFlags ? _self._enabledFlags : enabledFlags // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,customParameters: null == customParameters ? _self._customParameters : customParameters // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
