import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

part 'package.freezed.dart';
part 'package.g.dart';

/// @nodoc
@internal
@freezed
class Package with _$Package {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: false,
  )
  const factory Package({
    required String dependency,
    // ignore: invalid_annotation_target
    @JsonKey(
      toJson: Package._versionToJson,
      fromJson: Package._versionFromJson,
    )
        required Version version,
  }) = _Package;

  /// @nodoc
  factory Package.fromJson(Map<String, dynamic> json) =>
      _$PackageFromJson(json);

  static Version _versionFromJson(String json) => Version.parse(json);

  static String _versionToJson(Version version) => version.toString();
}
