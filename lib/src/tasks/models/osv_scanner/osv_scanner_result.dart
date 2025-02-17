import 'package:freezed_annotation/freezed_annotation.dart';

import 'result.dart';

part 'osv_scanner_result.freezed.dart';
part 'osv_scanner_result.g.dart';

/// @nodoc
@internal
@freezed
sealed class OsvScannerResult with _$OsvScannerResult {
  /// @nodoc
  const factory OsvScannerResult({required List<Result> results}) =
      _OsvScannerResult;

  /// @nodoc
  factory OsvScannerResult.fromJson(Map<String, dynamic> json) =>
      _$OsvScannerResultFromJson(json);
}
