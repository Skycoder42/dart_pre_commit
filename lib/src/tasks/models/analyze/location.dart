import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

@internal
@freezed
class RangePosition with _$RangePosition {
  const factory RangePosition({
    required int offset,
    required int line,
    required int column,
  }) = _RangePosition;

  factory RangePosition.fromJson(Map<String, dynamic> json) =>
      _$RangePositionFromJson(json);
}

@internal
@freezed
class Range with _$Range {
  const factory Range({
    required RangePosition start,
    required RangePosition end,
  }) = _Range;

  factory Range.fromJson(Map<String, dynamic> json) => _$RangeFromJson(json);
}

@internal
@freezed
class Location with _$Location {
  const Location._();

  // ignore: sort_unnamed_constructors_first
  const factory Location({
    required String file,
    required Range range,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  @override
  String toString() => '$file:${range.start.line}:${range.start.column}';
}
