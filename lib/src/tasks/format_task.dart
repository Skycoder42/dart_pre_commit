import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../repo_entry.dart';
import '../task_base.dart';
import '../util/program_runner.dart';

part 'format_task.freezed.dart';
part 'format_task.g.dart';

/// @nodoc
@freezed
@internal
sealed class FormatConfig with _$FormatConfig {
  /// @nodoc
  // ignore: invalid_annotation_target
  @JsonSerializable(anyMap: true, checked: true, disallowUnrecognizedKeys: true)
  const factory FormatConfig({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'line-length') int? lineLength,
  }) = _FormatConfig;

  /// @nodoc
  factory FormatConfig.fromJson(Map<String, dynamic> json) =>
      _$FormatConfigFromJson(json);
}

/// @nodoc
@internal
@injectable
class FormatTask with PatternTaskMixin implements FileTask {
  static const name = 'format';

  final ProgramRunner _programRunner;

  final FormatConfig _config;

  /// @nodoc
  const FormatTask(this._programRunner, @factoryParam this._config);

  @override
  String get taskName => name;

  @override
  Pattern get filePattern => RegExp(r'^.*\.dart$');

  @override
  Future<TaskResult> call(RepoEntry entry) async {
    const program = 'dart';
    final arguments = [
      'format',
      '--set-exit-if-changed',
      if (_config.lineLength != null) ...[
        '--line-length',
        _config.lineLength!.toString(),
      ],
      entry.file.path,
    ];
    final exitCode = await _programRunner.run(program, arguments);
    switch (exitCode) {
      case 0:
        return TaskResult.accepted;
      case 1:
        return TaskResult.modified;
      default:
        throw ProgramExitException(exitCode, program, arguments);
    }
  }
}
