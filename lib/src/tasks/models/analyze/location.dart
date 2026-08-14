import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

/// @nodoc
@internal
@freezed
sealed class RangePosition with _$RangePosition {
  /// @nodoc
  const factory({required int offset, required int line, required int column}) =
      _RangePosition;

  /// @nodoc
  factory fromJson(Map<String, dynamic> json) => _$RangePositionFromJson(json);
}

/// @nodoc
@internal
@freezed
sealed class Range with _$Range {
  /// @nodoc
  const factory({required RangePosition start, required RangePosition end}) =
      _Range;

  /// @nodoc
  factory fromJson(Map<String, dynamic> json) => _$RangeFromJson(json);
}

/// @nodoc
@internal
@freezed
sealed class Location with _$Location {
  const new _();

  /// @nodoc
  // ignore: sort_unnamed_constructors_first
  const factory({required String file, required Range range}) = _Location;

  /// @nodoc
  factory fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

  @override
  String toString() => '$file:${range.start.line}:${range.start.column}';
}
