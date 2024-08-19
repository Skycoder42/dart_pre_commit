import 'package:freezed_annotation/freezed_annotation.dart';

import 'package.dart';

part 'result.freezed.dart';
part 'result.g.dart';

/// @nodoc
@internal
@freezed
sealed class Result with _$Result {
  /// @nodoc
  const factory Result({
    required List<Package> packages,
  }) = _Result;

  /// @nodoc
  factory Result.fromJson(Map<String, dynamic> json) => _$ResultFromJson(json);
}
