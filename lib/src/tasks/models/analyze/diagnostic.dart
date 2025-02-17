import 'package:freezed_annotation/freezed_annotation.dart';

import 'location.dart';

part 'diagnostic.freezed.dart';
part 'diagnostic.g.dart';

/// @nodoc
@internal
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum DiagnosticSeverity {
  /// @nodoc
  none,

  /// @nodoc
  info,

  /// @nodoc
  warning,

  /// @nodoc
  error,
}

/// @nodoc
@internal
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum DiagnosticType {
  /// @nodoc
  todo,

  /// @nodoc
  hint,

  /// @nodoc
  compileTimeError,

  /// @nodoc
  checkedModeCompileTimeError,

  /// @nodoc
  staticWarning,

  /// @nodoc
  staticTypeWarning,

  /// @nodoc
  syntacticError,

  /// @nodoc
  lint,
}

/// @nodoc
@internal
@freezed
sealed class Diagnostic with _$Diagnostic {
  const Diagnostic._();

  /// @nodoc
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

  /// @nodoc
  factory Diagnostic.fromJson(Map<String, dynamic> json) =>
      _$DiagnosticFromJson(json);

  @override
  String toString() => '${severity.name} - $location - $_description - $code';

  String get _description =>
      correctionMessage != null
          ? '$problemMessage $correctionMessage'
          : problemMessage;
}
