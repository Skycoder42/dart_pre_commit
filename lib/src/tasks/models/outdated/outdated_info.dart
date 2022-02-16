import 'package:freezed_annotation/freezed_annotation.dart';

import 'package_info.dart';

part 'outdated_info.freezed.dart';
part 'outdated_info.g.dart';

/// @nodoc
@freezed
@internal
class OutdatedInfo with _$OutdatedInfo {
  /// @nodoc
  const factory OutdatedInfo({
    required List<PackageInfo> packages,
  }) = _OutdatedInfo;

  /// @nodoc
  factory OutdatedInfo.fromJson(Map<String, dynamic> json) =>
      _$OutdatedInfoFromJson(json);
}
