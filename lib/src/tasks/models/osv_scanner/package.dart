import 'package:freezed_annotation/freezed_annotation.dart';

import 'package_info.dart';
import 'vulnerability.dart';

part 'package.freezed.dart';
part 'package.g.dart';

/// @nodoc
@internal
@freezed
sealed class Package with _$Package {
  /// @nodoc
  const factory Package({
    required PackageInfo package,
    required List<Vulnerability> vulnerabilities,
  }) = _Package;

  /// @nodoc
  factory Package.fromJson(Map<String, dynamic> json) =>
      _$PackageFromJson(json);
}
