import 'package:freezed_annotation/freezed_annotation.dart';

import 'config.dart';

part 'pubspec_stub.freezed.dart';
part 'pubspec_stub.g.dart';

@freezed
@internal
class PubspecStub with _$PubspecStub {
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

  factory PubspecStub.fromJson(Map<String, dynamic> json) =>
      _$PubspecStubFromJson(json);
}
