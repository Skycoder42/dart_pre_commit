import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

/// The configuration for various hooks
@freezed
class Config with _$Config {
  /// Default constructor
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: true,
  )
  const factory Config({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'allow_outdated')
    @Default(<String>[])
        List<String> allowOutdated,
  }) = _Config;

  /// Create a [Config] from JSON or YAML data
  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
}
