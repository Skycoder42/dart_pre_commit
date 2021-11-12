import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

part 'version_info.freezed.dart';
part 'version_info.g.dart';

@freezed
@internal
class VersionInfo with _$VersionInfo {
  const factory VersionInfo({
    // ignore: invalid_annotation_target
    @JsonKey(
      fromJson: VersionInfo._versionFromJson,
      toJson: VersionInfo._versionToJson,
    )
        required Version? version,
    bool? nullSafety,
  }) = _VersionInfo;

  factory VersionInfo.fromJson(Map<String, dynamic> json) =>
      _$VersionInfoFromJson(json);

  static String? _versionToJson(Version? version) => version?.toString();

  static Version? _versionFromJson(String? version) =>
      version != null ? Version.parse(version) : null;
}
