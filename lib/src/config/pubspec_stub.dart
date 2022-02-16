import 'package:freezed_annotation/freezed_annotation.dart';

import 'config.dart';

part 'pubspec_stub.freezed.dart';
part 'pubspec_stub.g.dart';

/// @nodoc
@freezed
@internal
class PubspecStub with _$PubspecStub {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(
    anyMap: true,
    checked: true,
    disallowUnrecognizedKeys: false,
  )
  const factory PubspecStub({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'dart_pre_commit') @Default(Config()) Config dartPreCommit,
  }) = _PubspecStub;

  /// @nodoc
  factory PubspecStub.fromJson(Map<String, dynamic> json) =>
      _$PubspecStubFromJson(json);
}
