import 'package:freezed_annotation/freezed_annotation.dart';

import 'diagnostic.dart';

part 'analyze_result.freezed.dart';
part 'analyze_result.g.dart';

@internal
@freezed
class AnalyzeResult with _$AnalyzeResult {
  @Assert(
    'version == 1',
    'Only version 1 of the analyzer json format is supported',
  )
  const factory AnalyzeResult({
    required int version,
    required List<Diagnostic> diagnostics,
  }) = _AnalyzeResult;

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) =>
      _$AnalyzeResultFromJson(json);
}
