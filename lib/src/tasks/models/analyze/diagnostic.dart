import 'package:freezed_annotation/freezed_annotation.dart';

import 'location.dart';

part 'diagnostic.freezed.dart';
part 'diagnostic.g.dart';

@internal
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum DiagnosticSeverity { none, info, warning, error }

@internal
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum DiagnosticType {
  todo,
  hint,
  compileTimeError,
  checkedModeCompileTimeError,
  staticWarning,
  staticTypeWarning,
  syntacticError,
  lint,
}

@internal
@freezed
class Diagnostic with _$Diagnostic {
  const Diagnostic._();

  // ignore: sort_unnamed_constructors_first
  const factory Diagnostic({
    required String code,
    required DiagnosticSeverity severity,
    required DiagnosticType type,
    required Location location,
    required String problemMessage,
    required String? correctionMessage,
    required Uri? documentation,
  }) = _Diagnostic;

  factory Diagnostic.fromJson(Map<String, dynamic> json) =>
      _$DiagnosticFromJson(json);

  @override
  String toString() => '${severity.name} - $location - $_description - $code';

  String get _description => correctionMessage != null
      ? '$problemMessage $correctionMessage'
      : problemMessage;
}
