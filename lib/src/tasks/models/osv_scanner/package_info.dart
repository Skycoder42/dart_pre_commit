import 'package:freezed_annotation/freezed_annotation.dart';

part 'package_info.freezed.dart';
part 'package_info.g.dart';

/// @nodoc
@internal
@freezed
sealed class PackageInfo with _$PackageInfo {
  /// @nodoc
  const factory PackageInfo({
    required String name,
    required String version,
    required String ecosystem,
  }) = _PackageInfo;

  /// @nodoc
  factory PackageInfo.fromJson(Map<String, dynamic> json) =>
      _$PackageInfoFromJson(json);
}
