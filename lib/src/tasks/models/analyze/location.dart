import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

/// @nodoc
@internal
@freezed
sealed class RangePosition with _$RangePosition {
  /// @nodoc
  const factory RangePosition({
    required int offset,
    required int line,
    required int column,
  }) = _RangePosition;

  /// @nodoc
  factory RangePosition.fromJson(Map<String, dynamic> json) =>
      _$RangePositionFromJson(json);
}

/// @nodoc
@internal
@freezed
sealed class Range with _$Range {
  /// @nodoc
  const factory Range({
    required RangePosition start,
    required RangePosition end,
  }) = _Range;

  /// @nodoc
  factory Range.fromJson(Map<String, dynamic> json) => _$RangeFromJson(json);
}

/// @nodoc
@internal
@freezed
sealed class Location with _$Location {
  const Location._();

  /// @nodoc
  // ignore: sort_unnamed_constructors_first
  const factory Location({required String file, required Range range}) =
      _Location;

  /// @nodoc
  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  @override
  String toString() => '$file:${range.start.line}:${range.start.column}';
}
