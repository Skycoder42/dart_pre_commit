import 'package:freezed_annotation/freezed_annotation.dart';

import 'package.dart';

part 'pubspec_lock.freezed.dart';
part 'pubspec_lock.g.dart';

/// @nodoc
@internal
@freezed
sealed class PubspecLock with _$PubspecLock {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: false,
  )
  const factory PubspecLock({
    @Default(<String, Package>{}) Map<String, Package> packages,
  }) = _PubspecLock;

  /// @nodoc
  factory PubspecLock.fromJson(Map<String, dynamic> json) =>
      _$PubspecLockFromJson(json);
}
