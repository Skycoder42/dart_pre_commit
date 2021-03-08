import 'package:freezed_annotation/freezed_annotation.dart';

import 'version_info.dart';

part 'package_info.freezed.dart';
part 'package_info.g.dart';

@freezed
@internal
class PackageInfo with _$PackageInfo {
  const factory PackageInfo({
    required String package,
    VersionInfo? current,
    VersionInfo? upgradable,
    VersionInfo? resolvable,
    VersionInfo? latest,
  }) = _PackageInfo;

  factory PackageInfo.fromJson(Map<String, dynamic> json) =>
      _$PackageInfoFromJson(json);
}
